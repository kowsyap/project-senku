#if !os(watchOS)
import SwiftUI
import PhotosUI
import SenkuCore

/// Your progress photos, and the ways to see the change in them.
///
/// Three views of one pose at a time: a slider wiping from then to now over
/// the same frame, the two side by side, and a flipbook through every photo in
/// order. Then and now start as the first and the latest, and any photo can
/// take either place.
struct ProgressPhotosView: View {
    let unitSystem: UnitSystem

    private var store: ProgressPhotoStore { .shared }

    @State private var pose: ProgressPhoto.Pose = .front
    @State private var mode: Mode = .slider
    @State private var thenID: UUID?
    @State private var nowID: UUID?
    @State private var deleting: ProgressPhoto?
    #if os(iOS)
    @State private var exported: ExportedReport?
    #endif
    @State private var exportFailed = false

    enum Mode: String, CaseIterable, Identifiable {
        case slider = "Slider"
        case sideBySide = "Side by side"
        case flipbook = "Flipbook"
        var id: String { rawValue }
    }

    private var shots: [ProgressPhoto] { store.album.photos(pose) }

    private var then: ProgressPhoto? {
        shots.first { $0.id == thenID } ?? shots.first
    }

    private var now: ProgressPhoto? {
        shots.first { $0.id == nowID } ?? shots.last
    }

    var body: some View {
        ScrollView {
            if store.album.isEmpty {
                ContentUnavailableView(
                    "No photos yet",
                    systemImage: "camera",
                    description: Text("Add them when you log your weight.")
                )
                .padding(.top, 60)
            } else {
                VStack(spacing: Senku.Metrics.stackSpacing) {
                    if store.album.poses.count > 1 {
                        Picker("Pose", selection: $pose) {
                            ForEach(store.album.poses) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if shots.count > 1 {
                        Picker("View", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch mode {
                        case .slider, .sideBySide: compare
                        case .flipbook: Flipbook(shots: shots, unitSystem: unitSystem)
                        }
                    } else if let only = shots.first {
                        ProgressPhotoImage(photo: only)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .frame(maxHeight: 460)
                        Text(caption(only))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    grid
                }
                .padding()
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .background(.background)
        .navigationTitle("Evolution")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                Button(action: export) {
                    StackedActionLabel("Export", symbol: "square.and.arrow.up")
                }
                .disabled(store.album.isEmpty)
            }
            #endif
        }
        #if os(iOS)
        .sheet(item: $exported) { ShareSheet(urls: $0.urls) }
        #endif
        .alert("The photos could not be exported.", isPresented: $exportFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert(
            "Delete this photo?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { store.delete(deleting) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        }
        .onAppear(perform: settlePose)
        .onChange(of: store.album) { _, _ in settlePose() }
        .onChange(of: pose) { _, _ in
            thenID = nil
            nowID = nil
        }
        .senkuBottomBarInset()
    }

    private func settlePose() {
        if !store.album.poses.contains(pose), let first = store.album.poses.first { pose = first }
    }

    // MARK: - Then and now

    @ViewBuilder
    private var compare: some View {
        if let then, let now {
            Group {
                if mode == .slider {
                    WipeCompare(then: then, now: now)
                } else {
                    HStack(spacing: 8) {
                        ProgressPhotoImage(photo: then)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        ProgressPhotoImage(photo: now)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .frame(maxHeight: 460)

            HStack(spacing: 8) {
                // Then is always the earlier of the two: each menu offers only
                // the photos on its side of the other.
                chooser("Then", selected: then, from: shots.filter { $0.date < now.date }) { thenID = $0 }
                chooser("Now", selected: now, from: shots.filter { $0.date > then.date }) { nowID = $0 }
            }

            Text(changeText(from: then, to: now))
                .font(.headline)
                .monospacedDigit()
        }
    }

    private func chooser(
        _ title: String,
        selected: ProgressPhoto,
        from choices: [ProgressPhoto],
        pick: @escaping (UUID) -> Void
    ) -> some View {
        Menu {
            ForEach(choices.reversed()) { photo in
                Button(caption(photo)) { pick(photo.id) }
            }
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(caption(selected))
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )
        }
    }

    private func caption(_ photo: ProgressPhoto) -> String {
        "\(photo.date.formatted(.dateTime.day().month(.abbreviated).year())) · \(Display.mass(photo.weightKG, in: unitSystem))"
    }

    private func changeText(from then: ProgressPhoto, to now: ProgressPhoto) -> String {
        let change = ProgressAlbum.change(from: then, to: now)
        let value = unitSystem == .metric ? change.weightKG : Convert.pounds(fromKilograms: change.weightKG)
        let span = Self.span(days: change.days)
        guard change.days != 0 else { return span }
        guard abs(value) >= 0.05 else { return "Same weight in \(span)" }
        let amount = String(format: "%.1f %@", abs(value), unitSystem.massLabel)
        return "\(amount) \(value < 0 ? "decreased" : "increased") in \(span)"
    }

    static func span(days: Int) -> String {
        let days = abs(days)
        switch days {
        case 0: return "Same day"
        case 1: return "1 day"
        case ..<14: return "\(days) days"
        case ..<91: return "\(Int((Double(days) / 7).rounded())) weeks"
        default:
            let months = Int((Double(days) / 30.44).rounded())
            return months == 1 ? "1 month" : "\(months) months"
        }
    }

    // MARK: - Every photo

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
            ForEach(shots.reversed()) { photo in
                VStack(spacing: 4) {
                    ProgressPhotoImage(photo: photo, maxPixel: ProgressPhotoFile.thumbnailPixels)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if photo.id == then?.id || photo.id == now?.id, mode != .flipbook, shots.count > 1 {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Senku.Palette.protein, lineWidth: 2)
                            }
                        }
                    Text(photo.date.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contextMenu {
                    if shots.count > 1 {
                        if let now, photo.date < now.date {
                            Button("Set as Then", systemImage: "arrow.left.to.line") { thenID = photo.id }
                        }
                        if let then, photo.date > then.date {
                            Button("Set as Now", systemImage: "arrow.right.to.line") { nowID = photo.id }
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { deleting = photo }
                }
            }
        }
    }

    #if os(iOS)
    private func export() {
        do {
            exported = ExportedReport(urls: try store.exportFiles(in: unitSystem))
        } catch {
            exportFailed = true
        }
    }
    #endif
}

/// Then under now, with a line you drag to wipe from one to the other.
private struct WipeCompare: View {
    let then: ProgressPhoto
    let now: ProgressPhoto

    @State private var split = 0.5

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                ProgressPhotoImage(photo: now)
                ProgressPhotoImage(photo: then)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: width * split)
                    }

                Rectangle()
                    .fill(.white)
                    .frame(width: 2)
                    .shadow(radius: 2)
                    .offset(x: width * split - 1)

                Image(systemName: "chevron.left.chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white))
                    .shadow(radius: 3)
                    .offset(x: width * split - 17)
            }
            .overlay(alignment: .top) {
                HStack {
                    tag("Then").opacity(split > 0.15 ? 1 : 0)
                    Spacer()
                    tag("Now").opacity(split < 0.85 ? 1 : 0)
                }
                .padding(8)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { split = min(max($0.location.x / width, 0), 1) }
            )
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Then and now, compared")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: split = min(split + 0.1, 1)
            case .decrement: split = max(split - 0.1, 0)
            @unknown default: break
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.5)))
    }
}

/// Every photo of a pose in order, scrubbed or played.
private struct Flipbook: View {
    let shots: [ProgressPhoto]
    let unitSystem: UnitSystem

    @State private var index = 0.0
    @State private var isPlaying = false

    private var shown: ProgressPhoto { shots[min(Int(index), shots.count - 1)] }

    var body: some View {
        VStack(spacing: 10) {
            ProgressPhotoImage(photo: shown)
                .aspectRatio(3 / 4, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .frame(maxHeight: 460)

            Text("\(shown.date.formatted(.dateTime.day().month(.abbreviated).year())) · \(Display.mass(shown.weightKG, in: unitSystem))")
                .font(.headline)
                .monospacedDigit()

            HStack(spacing: 12) {
                Button {
                    if !isPlaying, Int(index) >= shots.count - 1 { index = 0 }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(isPlaying ? "Pause" : "Play")

                Slider(value: $index, in: 0...Double(shots.count - 1), step: 1) { editing in
                    if editing { isPlaying = false }
                }
            }
        }
        .task(id: isPlaying) {
            while isPlaying {
                try? await Task.sleep(for: .milliseconds(500))
                guard isPlaying, !Task.isCancelled else { return }
                if Int(index) >= shots.count - 1 {
                    isPlaying = false
                } else {
                    index += 1
                }
            }
        }
        .onChange(of: shots.count) { _, count in index = min(index, Double(count - 1)) }
    }
}

/// A progress photo, filling whatever frame it is given.
///
/// The previous picture stays up until the next has loaded, so a flipbook
/// does not flash blank between photos.
struct ProgressPhotoImage: View {
    let photo: ProgressPhoto
    var maxPixel = ProgressPhotoFile.screenPixels

    @State private var image: CGImage?

    var body: some View {
        Color.secondary.opacity(0.12)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: photo.id) {
                image = await ProgressPhotoStore.shared.image(for: photo, maxPixel: maxPixel)
            }
    }
}

/// The weight screen's way in: first and latest, and how many.
struct ProgressPhotosCard: View {
    let action: () -> Void

    private var album: ProgressAlbum { ProgressPhotoStore.shared.album }

    var body: some View {
        Button(action: action) {
            Card("Evolution") {
                HStack(spacing: 10) {
                    let pose = album.poses.first ?? .front
                    let shots = album.photos(pose)
                    ForEach([shots.first, shots.count > 1 ? shots.last : nil].compactMap { $0 }) { photo in
                        ProgressPhotoImage(photo: photo, maxPixel: ProgressPhotoFile.thumbnailPixels)
                            .frame(width: 54, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(album.photos.count == 1 ? "1 photo" : "\(album.photos.count) photos")
                            .font(.subheadline.weight(.semibold))
                        if let first = album.photos.first {
                            Text("Since \(first.date.formatted(.dateTime.day().month(.abbreviated).year()))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// The weigh-in sheet's photos: a slot per pose, each taken or chosen.
struct WeighInPhotoSlots: View {
    @Binding var photos: [ProgressPhoto.Pose: CGImage]

    @State private var shooting: ProgressPhoto.Pose?
    @State private var isChoosing = false
    /// Which slot the library is choosing for; kept after the picker closes,
    /// which can happen before the choice arrives.
    @State private var choosingFor: ProgressPhoto.Pose = .front
    @State private var picked: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ProgressPhoto.Pose.allCases) { pose in
                slot(pose)
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $shooting) { pose in
            ProgressCamera(pose: pose) { image in
                if let image { photos[pose] = image }
                shooting = nil
            }
        }
        #endif
        .photosPicker(
            isPresented: $isChoosing,
            selection: $picked,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: picked) { _, item in
            guard let item else { return }
            let pose = choosingFor
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = ProgressPhotoFile.upright(data) {
                    photos[pose] = image
                }
                picked = nil
            }
        }
    }

    private var hasCamera: Bool {
        #if os(iOS)
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #else
        false
        #endif
    }

    private func slot(_ pose: ProgressPhoto.Pose) -> some View {
        Menu {
            if hasCamera {
                Button("Take Photo", systemImage: "camera") { shooting = pose }
            }
            Button("Choose Photo", systemImage: "photo.on.rectangle") {
                choosingFor = pose
                isChoosing = true
            }
            if photos[pose] != nil {
                Button("Remove", systemImage: "trash", role: .destructive) { photos[pose] = nil }
            }
        } label: {
            VStack(spacing: 4) {
                Color.secondary.opacity(0.12)
                    .overlay {
                        if let image = photos[pose] {
                            Image(decorative: image, scale: 1)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(pose.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photos[pose] == nil ? "Add \(pose.title.lowercased()) photo" : "\(pose.title) photo")
    }
}
#endif
