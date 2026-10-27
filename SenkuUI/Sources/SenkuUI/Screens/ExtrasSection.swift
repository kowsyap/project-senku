#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The features you add and remove, in Settings.
///
/// Adding fills a ring like an app downloading, so it feels like something
/// arrived. Removing deletes the extra's data, so it asks twice: once whether
/// to remove at all, then whether to save a copy first.
struct ExtrasSection: View {
    let extras: ExtraStore
    let layout: TabLayout
    let data: ExtraData

    var body: some View {
        Section {
            ForEach(Extra.allCases) { extra in
                ExtraRow(extra: extra, extras: extras, layout: layout, data: data)
            }
        } header: {
            Text("Extras")
        }
    }
}

private struct ExtraRow: View {
    let extra: Extra
    let extras: ExtraStore
    let layout: TabLayout
    let data: ExtraData

    private enum Phase { case idle, installing, installed }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.idle
    @State private var progress: CGFloat = 0
    @State private var isConfirmingRemove = false
    @State private var isAskingToSave = false
    @State private var saved: SavedFile?
    @State private var failure: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: extra.tab.symbol)
                .foregroundStyle(extra.tab.tint)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(extra.title)
                Text(extra.blurb)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            control
        }
        .alert("Remove \(extra.title)?", isPresented: $isConfirmingRemove) {
            Button("Remove", role: .destructive) {
                // Nothing saved in it, nothing to offer to keep.
                guard extra.hasData(in: data) else { return remove() }
                // After this alert has gone: one presented while another is
                // still leaving is dropped.
                DispatchQueue.main.async { isAskingToSave = true }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if extra.hasData(in: data) { Text("Data will be deleted.") }
        }
        .background {
            // On a view of its own: two alerts on one view can shadow each other.
            Color.clear
                .alert("Save data before remove?", isPresented: $isAskingToSave) {
                    Button("Yes", action: saveThenRemove)
                    Button("No", role: .destructive, action: remove)
                    Button("Cancel", role: .cancel) {}
                }
        }
        .alert("Couldn't save", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(extra.title) was not removed.")
        }
        #if os(iOS)
        .sheet(item: $saved) { file in
            // Removed only once the file has gone somewhere. Closing the sheet
            // without saving leaves everything as it was.
            ShareSheet(urls: [file.url]) { completed in
                saved = nil
                if completed { remove() }
            }
        }
        #endif
    }

    @ViewBuilder
    private var control: some View {
        switch phase {
        case .installing:
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "icloud.and.arrow.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 30, height: 30)
            .transition(.scale.combined(with: .opacity))

        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Senku.Palette.surplus)
                .transition(.scale.combined(with: .opacity))

        case .idle:
            if extras.isInstalled(extra) {
                Button { isConfirmingRemove = true } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(Senku.Palette.warning)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(extra.title)")
            } else {
                Button(action: install) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add \(extra.title)")
            }
        }
    }

    private func install() {
        Feedback.control()
        guard !reduceMotion else { return finishInstall() }

        progress = 0
        withAnimation(.easeOut(duration: 0.2)) { phase = .installing }
        // Stepped by hand rather than animated: the ring is inserted in the
        // same moment, and an animation started then lands on the end value.
        Task {
            let start = Date.now
            while progress < 1 {
                progress = min(1, Date.now.timeIntervalSince(start) / 2)
                try? await Task.sleep(for: .milliseconds(16))
            }
            finishInstall()
        }
    }

    private func finishInstall() {
        extras.install(extra)
        layout.add(extra.tab)
        Feedback.success()

        guard !reduceMotion else { phase = .idle; return }
        withAnimation(.spring(duration: 0.35)) { phase = .installed }
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeInOut(duration: 0.2)) { phase = .idle }
        }
    }

    private func saveThenRemove() {
        do {
            let url = try extra.export(from: data)
            #if os(iOS)
            saved = SavedFile(url: url)
            #else
            _ = url
            remove()
            #endif
        } catch {
            failure = error.localizedDescription
        }
    }

    private func remove() {
        layout.drop(extra.tab)
        extras.remove(extra, data: data)
        Feedback.control()
    }
}

private struct SavedFile: Identifiable {
    let url: URL
    var id: URL { url }
}
#endif
