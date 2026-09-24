#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The anime list: what you are watching, what is waiting, what is behind you.
///
/// One search field does titles and genres together, because being asked which
/// kind of thing you are looking for before you look is a question with no good
/// answer — you type "frieren" or you type "fantasy", and the list narrows
/// either way.
public struct AnimeView: View {
    @Bindable private var store: AnimeStore

    @State private var search = ""
    /// Opens on what is airing — the handful of shows with an episode out this
    /// week is the reason to look at a list of 179.
    @State private var status: AnimeStatus? = .airing
    @State private var sort: AnimeSort = .status
    @State private var reversed = false
    @State private var editing: AnimeEntry?
    @State private var isAdding = false
    @State private var deleting: AnimeEntry?

    public init(store: AnimeStore) {
        self.store = store
    }

    private var shown: [AnimeEntry] {
        store.list(search: search, status: status, sort: sort, reversed: reversed)
    }

    public var body: some View {
        Group {
            if store.entries.isEmpty {
                empty
            } else {
                list
            }
        }
        // Under the title, not at the foot of the screen. iOS 26 puts a search
        // field at the bottom by default, which is right for an app using the
        // system tab bar and wrong here: Senku's bar is a floating capsule of
        // its own, and the two landed on top of each other.
        #if os(iOS)
        .searchable(
            text: $search,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search by name or genre"
        )
        #else
        .searchable(text: $search, prompt: "Search by name or genre")
        #endif
        .senkuBottomBarInset()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                sortMenu
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    StackedActionLabel("Add", symbol: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                AnimeEditor(entry: AnimeEntry(title: ""), store: store, isNew: true)
            }
        }
        .sheet(item: $editing) { entry in
            NavigationStack {
                AnimeEditor(entry: entry, store: store)
            }
        }
        .alert(
            "Remove “\(deleting?.title ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Remove", role: .destructive) {
                if let deleting { store.delete(deleting) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        }
    }

    // MARK: - The list

    private var list: some View {
        List {
            summary
            filters

            if shown.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ForEach(shown) { entry in
                    Button {
                        editing = entry
                    } label: {
                        row(entry)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleting = entry
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    // The edit made most often, without opening the form for it.
                    .contextMenu {
                        ForEach(AnimeStatus.allCases) { candidate in
                            Button {
                                store.setStatus(candidate, for: entry.id)
                            } label: {
                                Label(candidate.title, systemImage: candidate.symbol)
                            }
                            .disabled(candidate == entry.status)
                        }
                    }
                }
            }
        }
    }

    /// Statuses only.
    ///
    /// Genres were pills here too, and the row grew a chip for every genre ever
    /// typed until it was a scrolling wall of them. Searching finds a genre in
    /// one gesture; a permanent pill for each is a filter you pay for on every
    /// visit whether or not you use it.
    private var filters: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All \(store.entries.count)", isOn: status == nil) {
                        status = nil
                    }

                    ForEach(AnimeStatus.allCases) { candidate in
                        chip(
                            "\(candidate.title) \(store.count(candidate))",
                            isOn: status == candidate,
                            tint: tint(for: candidate)
                        ) {
                            status = status == candidate ? nil : candidate
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
    }

    /// What the list adds up to, across the top.
    private var summary: some View {
        let totals = store.totals

        return Section {
            HStack(spacing: 0) {
                total("\(totals.titles)", totals.movies > 0 ? "titles" : "series")
                Divider().frame(height: 28)
                total("\(totals.seasons)", "seasons")
                Divider().frame(height: 28)
                total("\(totals.episodes)", "episodes")
            }
            .padding(.vertical, 4)
        }
    }

    private func total(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(
        _ label: String,
        isOn: Bool,
        tint: Color = Senku.Palette.protein,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tint.opacity(isOn ? 0.25 : 0.10), in: .capsule)
                .foregroundStyle(isOn ? tint : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func row(_ entry: AnimeEntry) -> some View {
        HStack(spacing: 12) {
            AnimePoster(url: entry.posterURL, status: entry.status, tint: tint(for: entry.status))

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.primary)

                if !entry.countSummary.isEmpty {
                    Text(entry.countSummary)
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }

                if !entry.genres.isEmpty {
                    Text(entry.genres.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(entry.status.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint(for: entry.status))
        }
        .padding(.vertical, 2)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(AnimeSort.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            Divider()

            // Direction as its own switch rather than by tapping the chosen
            // field again: a `Picker` cannot tell you that the current
            // selection was picked a second time, so "press it twice to
            // reverse" is a gesture that silently does nothing.
            Toggle(isOn: $reversed) {
                Label("Reverse order", systemImage: "arrow.up.arrow.down")
            }
        } label: {
            StackedActionLabel("Sort", symbol: reversed ? "arrow.up" : "arrow.down")
        }
    }

    private func tint(for status: AnimeStatus) -> Color {
        switch status {
        case .pending: Senku.Palette.info
        case .airing: Senku.Palette.protein
        case .watched: Senku.Palette.carbs
        case .completed: Senku.Palette.surplus
        case .dropped: Senku.Palette.warning
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Nothing on the list", systemImage: "sparkles.tv")
        } description: {
            Text("What you are watching, what you mean to watch, and what you gave up on.")
        } actions: {
            Button("Add a Series") { isAdding = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// A poster, or the status mark when there is not one.
///
/// `AsyncImage` does the fetching and the caching, and falls back to the mark
/// on a bad link or no network — which matters more here than it looks, since
/// the URL is typed by hand and half of them will be wrong the first time.
struct AnimePoster: View {
    let url: URL?
    let status: AnimeStatus
    let tint: Color
    var width: CGFloat = 40

    private var height: CGFloat { width * 1.45 }   // the usual poster shape

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .empty where url != nil:
                ZStack {
                    tint.opacity(0.10)
                    ProgressView().controlSize(.mini)
                }
            default:
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            tint.opacity(0.14)
            Image(systemName: status.symbol)
                .font(.system(size: width * 0.42))
                .foregroundStyle(tint)
        }
    }
}

/// Adding or changing one series.
struct AnimeEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var entry: AnimeEntry
    @State private var genreText: String
    @State private var detailBySeason: Bool
    @Bindable var store: AnimeStore

    private let isNew: Bool

    init(entry: AnimeEntry, store: AnimeStore, isNew: Bool = false) {
        _entry = State(initialValue: entry)
        _genreText = State(initialValue: entry.genres.joined(separator: ", "))
        _detailBySeason = State(initialValue: entry.isDetailed)
        self.store = store
        self.isNew = isNew
    }

    /// The model decides, so an import cannot add what the form would refuse.
    private var canSave: Bool { entry.isComplete }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $entry.title)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif

                TextField("Genres, separated by commas", text: $genreText)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            } header: {
                Text("What it is")
            }

            Section {
                Picker("Kind", selection: $entry.isMovie) {
                    Text("Series").tag(false)
                    Text("Film").tag(true)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Series or film")
            }

            Section {
                Picker("Status", selection: $entry.status) {
                    ForEach(AnimeStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                Text(entry.status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Where you are with it")
            }

            episodeSection

            Section {
                TextField("Notes", text: $entry.note, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Notes")
            }

            // Last, because it is the one field that is decoration. Everything
            // above it changes what the list says; this changes how it looks.
            Section {
                HStack(spacing: 14) {
                    AnimePoster(
                        url: entry.posterURL,
                        status: entry.status,
                        tint: Senku.Palette.protein,
                        width: 62
                    )

                    TextField("Poster image URL", text: imageBinding, axis: .vertical)
                        .lineLimit(1...3)
                        .font(.footnote)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        #endif
                }
                .padding(.vertical, 2)
            } header: {
                Text("Poster")
            }

            if !isNew {
                Section {
                    Button(role: .destructive) {
                        store.delete(entry)
                        dismiss()
                    } label: {
                        Text("Remove from list").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .dismissableKeyboard()
        .navigationTitle(isNew ? "Add a Series" : entry.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
    }

    /// Either a season-by-season breakdown, or one number.
    ///
    /// The toggle is the whole design. Being made to enter four seasons of
    /// episode counts to record "about sixty episodes" is the kind of friction
    /// that stops a list being kept — and being unable to say "season 3 was the
    /// 24-episode one" when you do know it is the kind of omission that makes a
    /// list not worth keeping.
    @ViewBuilder
    private var episodeSection: some View {
        // A film has no seasons to count, so the whole section goes rather than
        // sitting there asking for numbers that do not exist.
        if entry.isMovie {
            EmptyView()
        } else {
        Section {
            Toggle("Count season by season", isOn: $detailBySeason)

            if detailBySeason {
                ForEach($entry.seasons) { $season in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(season.name)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                entry.seasons.removeAll { $0.id == season.id }
                                renumber()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        TextField("Season name (optional)", text: $season.title)

                        LabeledContent("Episodes") {
                            episodeField($season.episodes)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Button {
                    entry.seasons.append(
                        AnimeSeason(number: entry.seasons.count + 1, episodes: 12)
                    )
                } label: {
                    Label("Add a season", systemImage: "plus")
                }
            } else {
                Stepper(value: seasonBinding, in: 0...50) {
                    LabeledContent("Seasons", value: "\(entry.seasonCountOverride ?? 0)")
                }
                LabeledContent("Episodes in total") {
                    episodeField(episodeBinding)
                }
            }
        } header: {
            Text("How much you have watched")
        } footer: {
            if entry.isComplete, !entry.countSummary.isEmpty {
                Text(entry.countSummary)
            }
        }
        }
    }

    /// Typed rather than stepped.
    ///
    /// A stepper is right for a season count and wrong for episodes: One Piece
    /// is past a thousand, and reaching it a tap at a time is not a feature.
    /// The keypad gets you there in four.
    private func episodeField(_ value: Binding<Int>) -> some View {
        TextField(
            "0",
            value: value,
            format: .number
        )
        #if os(iOS)
        .keyboardType(.numberPad)
        #endif
        .multilineTextAlignment(.trailing)
        .frame(maxWidth: 90)
        .monospacedDigit()
    }

    private var seasonBinding: Binding<Int> {
        Binding(
            get: { entry.seasonCountOverride ?? 0 },
            set: { entry.seasonCountOverride = $0 == 0 ? nil : $0 }
        )
    }

    private var episodeBinding: Binding<Int> {
        Binding(
            get: { entry.totalEpisodes ?? 0 },
            set: { entry.totalEpisodes = $0 == 0 ? nil : $0 }
        )
    }

    private var imageBinding: Binding<String> {
        Binding(
            get: { entry.imageURL ?? "" },
            set: { entry.imageURL = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
        )
    }

    private func renumber() {
        for index in entry.seasons.indices {
            entry.seasons[index].number = index + 1
        }
    }

    private func save() {
        entry.title = entry.title.trimmingCharacters(in: .whitespaces)
        entry.genres = genreText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // The toggle decides which count is kept, so the two can never be left
        // disagreeing in storage.
        if detailBySeason {
            entry.totalEpisodes = nil
            entry.seasonCountOverride = nil
        } else {
            entry.seasons = []
        }

        store.save(entry)
        dismiss()
    }
}
#endif
