#if os(iOS)
import ImageIO
import PhotosUI
import SenkuCore
import SwiftUI
import UIKit

/// Photograph a meal or a packet, and hand back what it said.
///
/// ## Why it hands back rather than saves
///
/// This screen reads; it does not log. What it produces goes into the fields
/// of ``IntakeEditor``, where it sits next to a Save button under your eye,
/// because a figure a photograph cannot actually know — see ``FoodEstimate`` —
/// has no business reaching the log on its own.
@available(iOS 27.0, *)
struct FoodPhotoSheet: View {
    /// Handed the finished reading, already scaled to what was eaten.
    let onRead: (FoodEstimate) -> Void
    let onClose: () -> Void

    // Not Equatable any more: it carries a CGImage now, and nothing here
    // compares phases.
    private enum Phase {
        case choosing
        /// Photographed, not yet sent. The one moment where you can tell it
        /// something the picture cannot show.
        case note(CGImage, CGImagePropertyOrientation?)
        case reading
        case failed(title: String, detail: String)
        /// A label has been transcribed, and now needs the one thing a
        /// photograph of a packet cannot tell anybody: how much you ate.
        case quantity(FoodEstimate)
    }

    @State private var phase: Phase = .choosing
    @State private var isShowingCamera = false
    @State private var picked: PhotosPickerItem?
    @State private var servings = 1
    @State private var eaten: Double?
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .choosing: chooser
                case .note(let image, let orientation): noteBody(image, orientation)
                case .reading: reading
                case .failed(let title, let detail): failedBody(title, detail)
                case .quantity(let label): quantityBody(label)
                }
            }
            .navigationTitle("From a Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { image, orientation in
                isShowingCamera = false
                guard let image else { return }
                note = ""
                phase = .note(image, orientation)
            }
            .ignoresSafeArea()
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await readPicked(item) }
        }
    }

    // MARK: - Choosing

    private var chooser: some View {
        VStack(spacing: Senku.Metrics.stackSpacing) {
            Spacer()

            Image(systemName: "text.viewfinder")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Point it at the plate.")
                .font(.headline)

            // Said before the shot rather than after, because somebody who
            // knows the grams are a guess takes a different photo — and, more
            // to the point, reads the result differently.
            Text("The macros come back as a draft you correct. A photograph can tell what a food is, not how much of it is on the plate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take a photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) {
                    Label("Choose one", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Anything it cannot see

    private func noteBody(_ image: CGImage, _ orientation: CGImagePropertyOrientation?) -> some View {
        Form {
            Section {
                TextField("Fried in plenty of oil, cream on top…", text: $note, axis: .vertical)
                    .lineLimit(2 ... 5)
                    .textInputAutocapitalization(.sentences)
            } header: {
                Text("Anything it cannot see")
            } footer: {
                // The genuinely useful things here are the ones no photograph
                // carries: fat absorbed in cooking, butter stirred through,
                // what is underneath. Optional, because most of the time there
                // is nothing to add and a required field would be skipped
                // blank anyway.
                Text("Optional. Cooking fat, hidden ingredients — what the picture leaves out.")
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Read") { read(image, orientation) }
            }
        }
    }

    // MARK: - Reading

    private var reading: some View {
        VStack(spacing: 14) {
            ProgressView()
            Text("Reading the photo…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            // Told the truth for whichever reader is actually running. The
            // local promise is the app's whole position on this, so it is not
            // left standing on a screen where it has stopped being true.
            Text(GeminiAccount.isActive
                 ? "Sending it to Google, because Gemini is switched on."
                 : "On this device. The picture is not sent anywhere.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedBody(_ title: String, _ detail: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "eye.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            HStack {
                Button("Log by hand", action: onClose)
                Button("Try again") { phase = .choosing }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Says which thing went wrong, because the four of them want four
    /// different responses from you: wait, fix the key, retake the shot, or
    /// give up and type it.
    private func describe(_ error: Error) -> (String, String) {
        switch error {
        case FoodPhotoEstimator.Failure.modelUnavailable:
            return ("The model is not ready.",
                    "Apple Intelligence has to be on, and its model downloaded, before this can run.")
        case GeminiFailure.busy:
            return ("Google is busy.",
                    "It answered that it is under load, three times. Nothing is wrong with the photo — wait a moment and try again.")
        case GeminiFailure.rateLimited:
            return ("Too many in a row.",
                    "The free tier allows a few requests a minute. Wait a minute and try again.")
        case GeminiFailure.unauthorized:
            return ("Google refused the key.",
                    "Check it under Photo reading. It has to be a Google AI Studio key.")
        case GeminiFailure.noKey:
            return ("No key saved.",
                    "Add one under Photo reading, or switch Gemini off to read on the phone.")
        case GeminiFailure.http(let code):
            return ("Google could not be reached.",
                    "It answered \(code). Try again, or switch Gemini off to read on the phone.")
        default:
            return ("Could not read that one.",
                    "Try a clearer shot of the plate, or log it by hand.")
        }
    }

    // MARK: - How much of it

    /// The step the first version of this screen did not have.
    ///
    /// A packet states what is in 100 g of something. What went in you is a
    /// different number, and the gap between them is the difference between a
    /// food log and a list of things you have owned.
    private func quantityBody(_ label: FoodEstimate) -> some View {
        Form {
            Section {
                LabeledContent("Protein", value: grams(label.proteinG))
                LabeledContent("Carbs", value: grams(label.carbsG))
                LabeledContent("Fat", value: grams(label.fatG))
                if let fibre = label.fiberG {
                    LabeledContent("Fibre", value: grams(fibre))
                }
                if let calories = label.calories {
                    LabeledContent("Calories", value: "\(Int(calories.rounded())) kcal")
                }
            } header: {
                if label.basis == .per100g {
                    Text("Per 100 g")
                } else if let grams = label.servingGrams {
                    Text("Per serving — about \(Int(grams.rounded())) g")
                } else {
                    Text("Per serving")
                }
            } footer: {
                // The claim is different for each, and the difference is the
                // whole point: a packet's numbers are the packet's, and a
                // plate's are somebody's guess. Saying so is what earns the
                // trust the exact case deserves.
                Text(label.source == .panel
                     ? "Read off the packet, not estimated. Correct anything that came out wrong on the next screen."
                     : "Estimated from the photo, including the serving size. Worth correcting on the next screen.")
            }

            if label.basis == .perServing {
                Section {
                    // The same question the quick-add row asks, asked the same
                    // way: a packet states one serving, and two of them is
                    // multiplication rather than another guess.
                    Stepper(value: $servings, in: 1 ... 20) {
                        HStack {
                            Text("\(servings) serving\(servings == 1 ? "" : "s")")
                                .monospacedDigit()
                            Spacer(minLength: 0)
                            Text(servingDetail(label))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                } header: {
                    Text("How many")
                } footer: {
                    Text(label.servingGrams.map { grams in
                        label.source == .panel
                            ? "One serving is \(Int(grams.rounded())) g on the packet."
                            : "One serving is the portion in the photo, about \(Int(grams.rounded())) g."
                    } ?? "Counted in servings of what was read.")
                }
            } else {
                Section {
                    LabeledContent("You had") {
                        NumericField(value: $eaten, range: 0 ... 5000, unit: "g", width: 86)
                    }
                } header: {
                    Text("How much")
                } footer: {
                    // No per-serving column was printed, so there is no serving
                    // to count and grams is the only honest question left.
                    Text("This packet only gave a per-100 g column, so it needs a weight rather than a count.")
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Next") { confirm(label) }
                    .disabled(label.basis == .per100g && (eaten ?? 0) <= 0)
            }
        }
    }

    private func servingDetail(_ label: FoodEstimate) -> String {
        let total = label.scaled(servings: servings)
        let calories = total.calories ?? total.proposal()?.derivedCalories ?? 0
        return "\(Int(total.proteinG.rounded())) g P · \(Int(calories.rounded())) kcal"
    }

    private func confirm(_ label: FoodEstimate) {
        switch label.basis {
        case .perServing:
            Trace.food("scale: \(servings) serving(s) of \(label.proteinG) g P")
            finish(label.scaled(servings: servings))
        case .per100g:
            guard let eaten, eaten > 0 else { return }
            Trace.food("scale: \(eaten) g from a per-100 g column")
            finish(label.scaled(toGrams: eaten))
        case .plate:
            finish(label)
        }
    }

    /// Hands the reading back and closes. Nothing is logged here — the editor
    /// that opened this sheet is where it becomes an entry, or does not.
    private func finish(_ estimate: FoodEstimate) {
        Feedback.control()
        onRead(estimate)
        onClose()
    }

    private func grams(_ value: Double) -> String {
        "\(Int(value.rounded())) g"
    }

    // MARK: - Work

    private func read(_ image: CGImage, _ orientation: CGImagePropertyOrientation?) {
        phase = .reading
        Task {
            do {
                let estimate = try await FoodPhotoEstimator.estimate(image, orientation: orientation, note: note)
                guard estimate.proposal() != nil else {
                    let (title, detail) = describe(FoodPhotoEstimator.Failure.unreadable)
                    phase = .failed(title: title, detail: detail)
                    return
                }
                Feedback.control()
                // Both kinds stop here now. A packet states a serving and a
                // plate estimates one, so in either case the figures on screen
                // describe one of something and the only open question is how
                // many of them you had.
                servings = 1
                eaten = estimate.servingGrams
                phase = .quantity(estimate)
            } catch {
                Trace.food("sheet: \(error)")
                let (title, detail) = describe(error)
                phase = .failed(title: title, detail: detail)
            }
        }
    }

    private func readPicked(_ item: PhotosPickerItem) async {
        phase = .reading
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            let (title, detail) = describe(FoodPhotoEstimator.Failure.unreadable)
            phase = .failed(title: title, detail: detail)
            return
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32
        note = ""
        phase = .note(image, raw.flatMap(CGImagePropertyOrientation.init(rawValue:)))
    }
}

/// The system camera, as a view.
///
/// `UIImagePickerController` rather than a custom `AVCaptureSession`: this
/// screen needs one still photo and nothing else, and the system camera already
/// knows about the flash, the lenses and the permission prompt.
@available(iOS 27.0, *)
private struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (CGImage?, CGImagePropertyOrientation?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onFinish: (CGImage?, CGImagePropertyOrientation?) -> Void

        init(onFinish: @escaping (CGImage?, CGImagePropertyOrientation?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onFinish(image?.cgImage, image.map { CGImagePropertyOrientation($0.imageOrientation) })
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil, nil)
        }
    }
}

extension CGImagePropertyOrientation {
    /// `UIImage` and Core Graphics number the same eight orientations
    /// differently, and handing the model a sideways plate is a good way to be
    /// told it is looking at a wall.
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
#endif
