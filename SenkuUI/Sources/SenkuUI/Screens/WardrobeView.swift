#if os(iOS)
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

/// Photograph a piece of clothing and see what Apple Intelligence makes of it:
/// type, colours, material, pattern, fit and the rest.
///
/// A first step towards a wardrobe — reading one garment well is what every
/// later outfit suggestion would stand on — so it reads and shows, and keeps
/// nothing yet. On the device: the photo is not sent anywhere.
public struct WardrobeView: View {
    public init() {}

    public var body: some View {
        Group {
            if #available(iOS 27.0, *), GarmentReader.isAvailable {
                GarmentReaderPage()
            } else {
                ContentUnavailableView {
                    Label("Needs Apple Intelligence", systemImage: "tshirt")
                } description: {
                    Text("Reading clothes runs on the device, on iOS 27 with Apple Intelligence switched on.")
                }
            }
        }
        .senkuBottomBarInset()
    }
}

@available(iOS 27.0, *)
private struct GarmentReaderPage: View {
    private enum Phase {
        case idle
        case reading
        case read(GarmentReading)
        case failed(String)
    }

    @State private var image: CGImage?
    @State private var orientation: CGImagePropertyOrientation?
    @State private var prompt = ""
    @State private var phase: Phase = .idle
    @State private var isShowingCamera = false
    @State private var picked: PhotosPickerItem?
    @FocusState private var isTyping: Bool

    private let tint = RootView.Tab.wardrobe.tint

    var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                photoCard
                promptCard
                describeButton
                result
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.background)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { taken, turned in
                isShowingCamera = false
                guard let taken else { return }
                use(taken, turned)
            }
            .ignoresSafeArea()
        }
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    // MARK: - The photo

    private var photoCard: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Senku.Metrics.cardCorner, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
                if let image {
                    Image(decorative: image, scale: 1, orientation: Image.Orientation(orientation))
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Senku.Metrics.cardCorner, style: .continuous))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "tshirt")
                            .font(.system(size: 40))
                            .foregroundStyle(tint)
                        Text("One piece of clothing, laid flat or on a hanger.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 300)

            HStack(spacing: 10) {
                Button {
                    isShowingCamera = true
                } label: {
                    Label("Take a photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $picked, matching: .images, photoLibrary: .shared()) {
                    Label("Choose one", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .tint(tint)
        }
    }

    // MARK: - The prompt

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROMPT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Optional: what to look for, e.g. is it formal enough for work?", text: $prompt, axis: .vertical)
                .lineLimit(2 ... 4)
                .focused($isTyping)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
        }
    }

    private var describeButton: some View {
        Button {
            isTyping = false
            describe()
        } label: {
            Label("Describe", systemImage: "sparkles")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 30)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(image == nil || isReading)
    }

    private var isReading: Bool {
        if case .reading = phase { return true }
        return false
    }

    // MARK: - What it read

    @ViewBuilder
    private var result: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .reading:
            VStack(spacing: 8) {
                ProgressView()
                Text("Reading it on this iPhone…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(Senku.Palette.caution)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .read(let garment):
            readingCard(garment)
        }
    }

    private func readingCard(_ garment: GarmentReading) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(GarmentReading.shown(garment.name) ?? garment.type.capitalized)
                    .font(.title3.weight(.bold))
                if let summary = GarmentReading.shown(garment.summary) {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            let colours = GarmentReading.shown(garment.colours)
            if !colours.isEmpty {
                chips("Colour", colours)
            }

            VStack(spacing: 8) {
                row("Type", garment.type)
                row("Category", garment.category)
                row("Material", garment.material)
                row("Pattern", garment.pattern)
                row("Fit", garment.fit)
                row("Sleeves", garment.sleeves)
                row("Neckline", garment.neckline)
                row("Length", garment.length)
                row("Style", garment.style)
            }

            let occasions = GarmentReading.shown(garment.occasions)
            if !occasions.isEmpty { chips("Occasions", occasions) }
            let seasons = GarmentReading.shown(garment.seasons)
            if !seasons.isEmpty { chips("Seasons", seasons) }
            let details = GarmentReading.shown(garment.details)
            if !details.isEmpty { chips("Details", details) }

            Text("Read by Apple Intelligence on this iPhone. It can be wrong about fabric.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Senku.Metrics.cardCorner, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        if let shown = GarmentReading.shown(value) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(shown.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func chips(_ label: String, _ values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        Text(value.capitalized)
                            .font(.footnote.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(tint.opacity(0.15)))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
    }

    // MARK: - Reading

    private func use(_ taken: CGImage, _ turned: CGImagePropertyOrientation?) {
        image = taken
        orientation = turned
        phase = .idle
    }

    private func load(_ item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let loaded = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            phase = .failed("That photo could not be opened.")
            return
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = properties?[kCGImagePropertyOrientation] as? UInt32
        use(loaded, raw.flatMap(CGImagePropertyOrientation.init(rawValue:)))
    }

    private func describe() {
        guard let image else { return }
        phase = .reading
        Task {
            do {
                let garment = try await GarmentReader.read(image, orientation: orientation, prompt: prompt)
                withAnimation(.snappy) { phase = .read(garment) }
            } catch GarmentReader.Failure.modelUnavailable {
                phase = .failed("Apple Intelligence has to be on, and its model downloaded.")
            } catch GarmentReader.Failure.notClothing {
                phase = .failed("No clothing found in that one. Try a closer shot of one piece.")
            } catch {
                phase = .failed("Could not read that one. Try a clearer, closer shot.")
            }
        }
    }
}

private extension Image.Orientation {
    /// The photo drawn the right way up, as it was taken.
    init(_ orientation: CGImagePropertyOrientation?) {
        switch orientation {
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        default: self = .up
        }
    }
}
#endif
