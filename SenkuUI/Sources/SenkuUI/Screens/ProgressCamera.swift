#if os(iOS)
import SwiftUI
import AVFoundation
import SenkuCore

/// The camera for a progress photo, with last time's photo of the same pose
/// laid faintly over the view, so you stand where you stood.
///
/// Its own camera rather than the system's: the system camera cannot show the
/// ghost lined up with what it sees. The view is 3:4, the shape the sensor
/// takes, so the preview, the ghost and the saved photo are the same frame.
struct ProgressCamera: View {
    let pose: ProgressPhoto.Pose
    let onFinish: (CGImage?) -> Void

    @State private var camera = CameraSession()
    @AppStorage("senku.progressCamera.front.v1", store: SenkuStorage.shared) private var usesFront = true
    @AppStorage("senku.progressCamera.timer.v1", store: SenkuStorage.shared) private var timer = 0
    @State private var ghost: CGImage?
    @State private var showsGhost = true
    @State private var countdown: Int?
    @State private var taken: CGImage?
    @State private var isDenied = false
    @Environment(\.openURL) private var openURL

    private static let timers = [0, 3, 10]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                topBar
                Spacer(minLength: 0)
                viewfinder
                Spacer(minLength: 0)
                controls
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .preferredColorScheme(.dark)
        .task {
            guard await CameraSession.authorize() else {
                isDenied = true
                return
            }
            camera.start(front: usesFront)
        }
        .task {
            if let last = ProgressPhotoStore.shared.album.latest(pose) {
                ghost = await ProgressPhotoStore.shared.image(for: last, maxPixel: ProgressPhotoFile.screenPixels)
            }
        }
        .onChange(of: usesFront) { _, front in camera.use(front: front) }
        .onDisappear { camera.stop() }
    }

    private var topBar: some View {
        HStack {
            Button { onFinish(nil) } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Cancel")

            Spacer()
            Text(pose.title)
                .font(.headline)
            Spacer()

            Button { showsGhost.toggle() } label: {
                Image(systemName: showsGhost ? "person.fill.viewfinder" : "viewfinder")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }
            .opacity(ghost == nil || taken != nil ? 0 : 1)
            .disabled(ghost == nil || taken != nil)
            .accessibilityLabel(showsGhost ? "Hide last photo" : "Show last photo")
        }
        .foregroundStyle(.white)
    }

    private var viewfinder: some View {
        Color.black
            .overlay {
                if let taken {
                    Image(decorative: taken, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else if isDenied {
                    VStack(spacing: 12) {
                        Text("Senku needs the camera for this.")
                            .foregroundStyle(.white)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } else {
                    CameraPreview(session: camera.session)
                    if let ghost, showsGhost {
                        Image(decorative: ghost, scale: 1)
                            .resizable()
                            .scaledToFill()
                            .opacity(0.35)
                            .allowsHitTesting(false)
                    }
                    if let countdown {
                        Text("\(countdown)")
                            .font(.system(size: 96, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .shadow(radius: 8)
                            .contentTransition(.numericText(countsDown: true))
                    }
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var controls: some View {
        if let taken {
            HStack {
                Button("Retake") { self.taken = nil }
                    .frame(maxWidth: .infinity)
                Button("Use Photo") { onFinish(taken) }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .font(.title3)
            .foregroundStyle(.white)
            .frame(height: 76)
        } else {
            HStack {
                Button {
                    let next = (Self.timers.firstIndex(of: timer) ?? 0) + 1
                    timer = Self.timers[next % Self.timers.count]
                } label: {
                    Label(timer == 0 ? "Off" : "\(timer)s", systemImage: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(timer == 0 ? .white : .yellow)
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(timer == 0 ? "Timer off" : "Timer \(timer) seconds")

                Button(action: shoot) {
                    Circle()
                        .strokeBorder(.white, lineWidth: 4)
                        .padding(-6)
                        .background(Circle().fill(.white))
                        .frame(width: 64, height: 64)
                }
                .disabled(countdown != nil || isDenied)
                .accessibilityLabel("Take photo")

                Button { usesFront.toggle() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .disabled(countdown != nil)
                .accessibilityLabel("Switch camera")
            }
            .frame(height: 76)
        }
    }

    private func shoot() {
        Task {
            if timer > 0 {
                for left in stride(from: timer, through: 1, by: -1) {
                    withAnimation { countdown = left }
                    Feedback.control()
                    try? await Task.sleep(for: .seconds(1))
                }
                countdown = nil
            }
            let image = await camera.capture()
            Feedback.success()
            taken = image
        }
    }
}

/// The capture session, run on its own queue as AVFoundation asks.
final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "pk.Senku.progressCamera")
    private var input: AVCaptureDeviceInput?
    private var waiting: CheckedContinuation<CGImage?, Never>?

    static func authorize() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    func start(front: Bool) {
        queue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo
            if session.canAddOutput(output) { session.addOutput(output) }
            configure(front: front)
            session.commitConfiguration()
            if !session.isRunning { session.startRunning() }
        }
    }

    func use(front: Bool) {
        queue.async { [self] in
            session.beginConfiguration()
            configure(front: front)
            session.commitConfiguration()
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// The photo, upright and downsized; nil if the camera could not take one.
    func capture() async -> CGImage? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning, output.connection(with: .video) != nil else {
                    continuation.resume(returning: nil)
                    return
                }
                waiting = continuation
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let image = photo.fileDataRepresentation().flatMap { ProgressPhotoFile.upright($0) }
        queue.async { [self] in
            waiting?.resume(returning: image)
            waiting = nil
        }
    }

    private func configure(front: Bool) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: front ? .front : .back),
              let next = try? AVCaptureDeviceInput(device: device)
        else { return }

        if let input { session.removeInput(input) }
        if session.canAddInput(next) {
            session.addInput(next)
            input = next
        } else if let input, session.canAddInput(input) {
            session.addInput(input)
        }

        // Portrait, and the selfie camera mirrored as its preview is, so the
        // photo is the picture you lined up.
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = front
            }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if let connection = view.previewLayer.connection,
           connection.isVideoRotationAngleSupported(90),
           connection.videoRotationAngle != 90 {
            connection.videoRotationAngle = 90
        }
    }
}
#endif
