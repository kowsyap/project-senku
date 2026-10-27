#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The watch list: what you are watching, what is waiting, what is behind you.
///
/// Anime, K-dramas, films, web series — whatever you keep. It can be split
/// into screens (Anime, Hollywood, Marvel), made under Adjust: the title is the
/// screen you are on, and with two or more it is a menu to switch.
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
    @State private var isAdjusting = false
    @State private var deleting: AnimeEntry?
    /// The screen last looked at, kept across launches.
    @AppStorage("senku.watchlist.screen.v1", store: SenkuStorage.shared) private var screenID = ""

    public init(store: AnimeStore) {
        self.store = store
    }

    /// The screen showing — the one last picked, else the first. None until
    /// screens are made, and then the list is everything.
    private var current: WatchScreen? {
        store.screen(UUID(uuidString: screenID)) ?? store.screens.first
    }

    private var shown: [AnimeEntry] {
        store.list(search: search, status: status, screen: current?.id, sort: sort, reversed: reversed)
    }

    public var body: some View {
        Group {
            if store.entries.isEmpty {
                empty
            } else {
                list
            }
        }
        .senkuBottomBarInset()
        .navigationTitle(current.flatMap { $0.name.isEmpty ? nil : $0.name } ?? "Watchlist")
        #if os(iOS)
        // Small from the start once there is a choice of screens: the picker
        // sits where the title would.
        .navigationBarTitleDisplayMode(store.choices.count > 1 ? .inline : .automatic)
        #endif
        .toolbar {
            if store.choices.count > 1 {
                ToolbarItem(placement: .principal) {
                    ScreenPicker(screens: store.choices, current: current?.id) { screenID = $0.uuidString }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdjusting = true } label: {
                    StackedActionLabel("Adjust", symbol: "slider.horizontal.3")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    StackedActionLabel("Add", symbol: "plus")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                // Added to the collection you are looking at — none, on Other.
                AnimeEditor(
                    entry: AnimeEntry(
                        title: "",
                        screens: current.flatMap { $0.id == WatchScreen.other.id ? nil : [$0.id] } ?? []
                    ),
                    store: store,
                    isNew: true
                )
            }
        }
        .sheet(isPresented: $isAdjusting) {
            NavigationStack {
                WatchlistAdjustView(store: store)
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
            searchRow
            summary
            filters

            if shown.isEmpty {
                if search.isEmpty {
                    Text("Nothing here yet")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                } else {
                    ContentUnavailableView.search(text: search)
                }
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
                        ForEach(AnimeStatus.options(isMovie: entry.isMovie)) { candidate in
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
                HStack(spacing: 6) {
                    chip("All \(store.count(on: current?.id))", isOn: status == nil) {
                        status = nil
                    }

                    ForEach(AnimeStatus.allCases) { candidate in
                        chip(
                            "\(candidate.title) \(store.count(candidate, on: current?.id))",
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

    /// Search, with sort beside it.
    ///
    /// A field of the app's own rather than `.searchable`: the system one
    /// cannot have a button beside it.
    private var searchRow: some View {
        Section {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search by name or genre", text: $search)
                        .submitLabel(.search)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                sortMenu
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
        }
    }

    /// What the list adds up to, across the top.
    private var summary: some View {
        let totals = store.totals(on: current?.id)

        return Section {
            HStack(spacing: 0) {
                total("\(totals.titles)", "titles")
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
                .padding(.horizontal, 9)
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
        // Tappable across its width, not only on the text.
        .contentShape(Rectangle())
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
            Image(systemName: "arrow.up.arrow.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Senku.Palette.protein)
                .frame(width: 36, height: 36)
                .background(Senku.Palette.protein.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityLabel("Sort")
    }

    private func tint(for status: AnimeStatus) -> Color {
        switch status {
        case .pending: Senku.Palette.info
        case .planned: Color(red: 0.62, green: 0.45, blue: 0.92)   // violet
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
            Button("Add a Title") { isAdding = true }
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
    /// In no collection is allowed: it shows under Other.
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
            }

            Section {
                Picker("Kind", selection: $entry.isMovie) {
                    Text("Series").tag(false)
                    Text("Film").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: entry.isMovie) { _, isMovie in
                    if isMovie { entry.status = entry.status.asFilm }
                }
            }

            Section {
                Picker("Status", selection: $entry.status) {
                    ForEach(AnimeStatus.options(isMovie: entry.isMovie)) { status in
                        Text(status.title).tag(status)
                    }
                }
            }

            screensSection

            episodeSection

            Section {
                TextField("Notes", text: $entry.note, axis: .vertical)
                    .lineLimit(2...6)
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
        .navigationTitle(isNew ? "Add a Title" : entry.title)
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
                // Numbered only. A name per season was one more field to fill
                // in for almost no gain; titles saved before are kept in the
                // data, just not shown.
                ForEach($entry.seasons) { $season in
                    HStack(spacing: 12) {
                        Text("Season \(season.number)")
                        Spacer()
                        episodeField($season.episodes)
                        Text("eps")
                            .foregroundStyle(.secondary)
                        Button {
                            entry.seasons.removeAll { $0.id == season.id }
                            renumber()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove season \(season.number)")
                    }
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
        } footer: {
            if entry.isComplete, !entry.countSummary.isEmpty {
                Text(entry.countSummary)
            }
        }
        }
    }

    /// Which screens it shows on — as many as fit it: a film can be Hollywood
    /// and Marvel both.
    @ViewBuilder
    private var screensSection: some View {
        if !store.screens.isEmpty {
            Section {
                // One line however many screens there are: a menu that stays
                // open while you tick, so several can be picked in one go.
                Menu {
                    ForEach(store.screens) { screen in
                        Toggle(screen.name, isOn: Binding(
                            get: { entry.screens.contains(screen.id) },
                            set: { on in
                                if on {
                                    entry.screens.append(screen.id)
                                } else {
                                    entry.screens.removeAll { $0 == screen.id }
                                }
                            }
                        ))
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("Collections")
                            .foregroundStyle(Color.primary)
                        Spacer()
                        Text(chosenScreens)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                #if os(iOS)
                .menuActionDismissBehavior(.disabled)
                #endif
            }
        }
    }

    /// "Hollywood, Marvel", in the order the screens are kept.
    private var chosenScreens: String {
        let names = store.screens.filter { entry.screens.contains($0.id) }.map(\.name)
        return names.isEmpty ? "None" : names.joined(separator: ", ")
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

/// The title as a dropdown of screens, once there are two to choose between.
///
/// A popover of its own rather than the system title menu, so the screen you
/// are on can be shown in colour rather than with a tick.
private struct ScreenPicker: View {
    let screens: [WatchScreen]
    let current: UUID?
    let pick: (UUID) -> Void

    @State private var isOpen = false
    private let tint = RootView.Tab.anime.tint

    private var title: String {
        let name = screens.first { $0.id == current }?.name ?? ""
        return name.isEmpty ? "Watchlist" : name
    }

    var body: some View {
        Button { isOpen.toggle() } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), choose a collection")
        .popover(isPresented: $isOpen) {
            VStack(spacing: 4) {
                ForEach(screens) { screen in
                    let isOn = screen.id == current
                    Button {
                        pick(screen.id)
                        isOpen = false
                    } label: {
                        Text(screen.name.isEmpty ? "Untitled" : screen.name)
                            .font(.body.weight(isOn ? .semibold : .regular))
                            .foregroundStyle(isOn ? tint : Color.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isOn ? tint.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .frame(minWidth: 200)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// The watchlist's settings: the screens it is split into.
struct WatchlistAdjustView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: AnimeStore

    @State private var draft = ""
    @State private var deleting: WatchScreen?

    var body: some View {
        List {
            Section {
                ForEach(store.screens) { screen in
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.stack")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        TextField("Name", text: Binding(
                            get: { store.screen(screen.id)?.name ?? "" },
                            set: { store.renameScreen(screen.id, to: $0) }
                        ))
                        .submitLabel(.done)
                        Text("\(store.count(on: screen.id))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { deleting = screen } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { store.moveScreens(from: $0, to: $1) }

                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Senku.Palette.surplus)
                        .frame(width: 22)
                    TextField("New collection", text: $draft)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Collections")
            } footer: {
                if store.screens.isEmpty {
                    Text("The first collection takes everything already on the list.")
                }
            }
        }
        .navigationTitle("Adjust")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert(
            "Delete \u{201C}\(deleting?.name ?? "")\u{201D}?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { store.deleteScreen(deleting.id) }
                deleting = nil
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        }
    }

    private func add() {
        store.addScreen(draft)
        draft = ""
    }
}
#endif
