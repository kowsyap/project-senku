#if !os(watchOS)
import SwiftUI
import SenkuCore
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// The app's entry screen.
///
/// Three tabs. "Me" is a profile that persists and improves over time, while
/// "Quick calc" is for the friend who asks a question in the gym — no account,
/// no onboarding, nothing written down. The two audiences genuinely differ.
///
/// "Rest" sits alongside them rather than inside either, because it is the one
/// screen reached mid-set with a bar waiting: it has to be one tap from
/// anywhere, and it needs no profile to be useful.
///
/// ## Why a tab view and not a drawer
///
/// The destinations are a `sidebarAdaptable` `TabView`, which is the same
/// declaration rendered as a tab bar on iPhone and as a real sidebar on iPad
/// and Mac — and which lets the person using it reorder and pin what matters to
/// them as more sections arrive. A hand-built menu would trade the one-tap
/// guarantee above for a tap, a read and a second tap, and hide every new
/// feature behind a button until someone went looking for it.
public struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    @State private var store: ProfileStore
    @State private var weightLog = WeightLogStore()
    @State private var plans = TrainingPlanStore()
    @State private var workouts = WorkoutStore()
    @State private var cardioPlans = CardioProtocolStore()
    @State private var cardioRecords = CardioRecordStore()
    @State private var anime = AnimeStore()
    @State private var water = WaterStore()
    @State private var intake = IntakeStore()
    @State private var records = RecordStore()
    @State private var library = ExerciseLibrary()
    @State private var selection: Tab

    /// Reset when a profile is saved or cleared, so the calculator rebuilds its
    /// draft from the new state instead of holding a stale one.
    @State private var profileEditionID = UUID()

    /// The hidden importer, opened by a long press on the wordmark.
    @State private var isImporting = false
    @State private var importSummary: ImportSummary?
    @State private var importFailure: String?
    @State private var isShowingDataMenu = false
    @State private var isConfirmingReset = false
    @State private var isConfirmingResetAgain = false
    #if os(iOS)
    @State private var exportedReport: ExportedReport?
    @State private var isChoosingExport = false
    @State private var reportSelection = ReportSelection.load()
    #endif

    /// How much room the scrolling bar needs at the bottom of every page.
    @State private var tabBarHeight: CGFloat = 62

    /// Bumped by a hard reset, and used as the identity of the whole tree.
    ///
    /// ## Why replacing the stores was not enough
    ///
    /// Several screens take a store as an init parameter and keep it in
    /// `@State`. That is the right thing for a screen that owns its store —
    /// but `@State` captures its initial value *once*, when the view is first
    /// created, and ignores anything the parent passes afterwards. So a reset
    /// that built fresh stores up here left the records screen holding the old
    /// object, still full of the records that had just been deleted from disk.
    ///
    /// Changing this id makes SwiftUI treat the whole tree as a different view
    /// and build it again from scratch, which re-runs every one of those
    /// initialisers. It is a blunt instrument and exactly right for the one
    /// action in the app that means "forget everything".
    @State private var generation = UUID()

    /// Which three screens the bar is carrying, and what More is showing.
    @State private var layout = TabLayout()
    @State private var moreDestination: Tab?

    public enum Tab: String, Hashable, Identifiable, Sendable, CaseIterable {
        case me
        case quickCalc
        case rest
        case workout
        case weight
        case water
        case food
        case records
        case anime
        /// Not a screen: the way to the screens the bar has no room for.
        case more

        public var id: String { rawValue }

        /// The colour the tab bar takes while this tab is showing.
        ///
        /// One accent for the whole app makes five destinations look like one
        /// place; a colour each gives the bar a second signal beside the icon,
        /// so you know where you are from the corner of your eye. Each is the
        /// colour that screen already uses — the rest timer's blue, the weight
        /// trend's blue-green, the PR headline's violet — rather than a palette
        /// invented for the bar.
        var title: String {
            switch self {
            case .me: "Me"
            case .quickCalc: "Quick calc"
            case .rest: "Rest"
            case .workout: "Workout"
            case .weight: "Weight"
            case .water: "Water"
            case .food: "Food"
            case .records: "PRs"
            case .anime: "Anime"
            case .more: "More"
            }
        }

        /// An image from the package's assets, where a glyph will not do.
        var mark: String? {
            self == .me ? "GokuMark" : nil
        }

        /// Whether the selected pill goes black rather than taking the tab's
        /// own colour. Only "Me": gold on white glass is a wash, and gold on
        /// black is the thing it is quoting.
        var wantsDarkPill: Bool { self == .me }

        /// What the tab is drawn in while it is the one showing. The same
        /// colour it always was — kept as its own name because the dark pill
        /// once needed a different one, and may again.
        var activeTint: Color { tint }

        var symbol: String {
            switch self {
            case .me: "person.fill"
            case .quickCalc: "function"
            case .rest: "timer"
            case .workout: "figure.strengthtraining.traditional"
            case .weight: "scalemass"
            case .water: "drop.fill"
            case .food: "fork.knife"
            case .records: "trophy"
            case .anime: "sparkles.tv"
            case .more: "ellipsis.circle"
            }
        }

        /// Every screen, in the order they are listed wherever all of them
        /// appear — the sidebar on iPad, and the More list on a phone. "More"
        /// is not in it, because it is not a screen.
        public static let ordered: [Tab] = [.me, .quickCalc, .rest, .workout, .weight, .water, .food, .records, .anime]

        /// One hue each, spread around the wheel.
        ///
        /// Only the tab you are on is coloured — the rest of the bar is grey —
        /// so the test is not whether nine colours look good together but
        /// whether *switching* between two screens changes anything. It did
        /// not: workout and weight were two greens a hair apart, and food and
        /// water two blues, which made half the bar feel like one place.
        ///
        /// These are deliberately not the palette's macro colours. Those mean
        /// something specific inside a screen — protein blue, carbs amber — and
        /// borrowing them for navigation made a tab look like a claim about
        /// nutrition.
        var tint: Color {
            switch self {
            case .me: Senku.Palette.saiyan                              // gold
            case .quickCalc: Color(red: 0.62, green: 0.45, blue: 0.92)  // violet
            case .rest: Color(red: 0.90, green: 0.35, blue: 0.32)       // red
            case .workout: Color(red: 0.94, green: 0.51, blue: 0.16)    // orange
            case .weight: Color(red: 0.28, green: 0.72, blue: 0.43)     // green
            case .food: Color(red: 0.09, green: 0.69, blue: 0.65)       // teal
            case .water: Color(red: 0.25, green: 0.60, blue: 0.94)      // azure
            case .records: Color(red: 0.35, green: 0.39, blue: 0.85)    // indigo
            case .anime: Color(red: 0.95, green: 0.45, blue: 0.75)      // pink
            case .more: Color(red: 0.45, green: 0.50, blue: 0.58)        // slate
            }
        }
    }

    public init(store: ProfileStore = ProfileStore()) {
        _store = State(initialValue: store)
        _selection = State(initialValue: store.hasProfile ? .me : .quickCalc)
    }

    public var body: some View {
        Group {
            #if os(iOS)
            // On a phone the bar scrolls; on an iPad it is the system sidebar,
            // which has the width to show every destination at once and gains
            // nothing from scrolling. `horizontalSizeClass` is the same test
            // `sidebarAdaptable` itself uses to decide between the two.
            if horizontalSizeClass == .compact {
                scrollingTabs
            } else {
                systemTabs
            }
            #else
            systemTabs
            #endif
        }
        .id(generation)
        .tint(selection.tint)
        .animation(.easeInOut(duration: 0.2), value: selection)
        .onOpenURL { url in
            if RestDeepLink.handle(url) != nil {
                show(.rest)
                return
            }

            // The weight widget. It lands on the tab rather than opening the
            // sheet from here, because the sheet belongs to that screen — and a
            // widget that dropped you on the weight page with nothing to do
            // would be a link to a place you were already able to reach.
            switch url.host() {
            case "weigh-in": show(.weight)
            case "water": show(.water)
            case "food": show(.food)
            default: break
            }
        }
        .task {
            // The phone publishes the profile; the watch picks it up whenever
            // it next runs. Started here rather than in the app entry point so
            // that previews and tests, which build their own store, never open
            // a session at all.
            #if os(iOS) && !targetEnvironment(macCatalyst)
            ProfileSync.shared.start(applying: store)

            // A weigh-in typed on the watch lands here, in the log that owns
            // the history. The watch keeps none of its own.
            ProfileSync.shared.onWeighInReceived { weighIn in
                weightLog.add(weighIn)
                publishWeight()
            }

            // A glass logged on the wrist. The phone owns the log, so it lands
            // here and goes back out as a new summary.
            ProfileSync.shared.onDrinkReceived { drink in
                water.restore(drink)
                publishWater()
            }

            // Protein or calories typed on the wrist. The phone owns the log,
            // so it lands here and goes back out as a new summary.
            ProfileSync.shared.onMealReceived { meal in
                intake.restore(meal)
                publishIntake()
            }

            publishWeight()
            publishWater()
            publishIntake()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            // Drinks can be logged from the Home Screen widget, in another
            // process, while the app is in the background — so the water it
            // read at launch is only true until you tap a glass out there.
            if phase == .active {
                water.reload()
                intake.reload()
            }

            // Republished whenever the app comes forward, which is the cheapest
            // honest definition of "regularly": the phone is the source, and
            // the moment you have been looking at it is the moment its numbers
            // are most likely to have changed.
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if phase == .active {
                publishWeight()
                publishWater()
                publishIntake()
            }
            #endif
        }
        .onChange(of: weightLog.weighIns) { _, _ in publishWeight() }
        .onChange(of: water.entries) { _, _ in publishWater() }
        .onChange(of: intake.entries) { _, _ in publishIntake() }
        .onChange(of: profileEditionID) { _, _ in
            publishWeight()
            // A new profile is new targets, and the watch draws its rings
            // against them.
            publishIntake()
        }
        .onReceive(NotificationCenter.default.publisher(for: .senkuImportRequested)) { _ in
            isShowingDataMenu = true
        }
        // The hidden door behind the wordmark. Three things that all concern
        // the app's data as a whole rather than any one screen — and all three
        // rare enough that a permanent control for them would be clutter on
        // every screen in the app.
        .confirmationDialog("Senku data", isPresented: $isShowingDataMenu, titleVisibility: .visible) {
            Button("Import Data") { isImporting = true }
            #if os(iOS)
            Button("Export PDF") { isChoosingExport = true }
            #endif
            Button("Hard Reset", role: .destructive) { isConfirmingReset = true }
            Button("Cancel", role: .cancel) {}
        }
        // Two alerts, not one. The first says what goes; the second is asked
        // after that has been read, and offers the way out that actually helps
        // — taking a copy — rather than only a Cancel. A single tap-through on
        // a destructive action this total is too cheap for what it costs.
        .alert("Delete everything?", isPresented: $isConfirmingReset) {
            Button("Continue", role: .destructive) { isConfirmingResetAgain = true }
            Button("Keep my data", role: .cancel) {}
        } message: {
            Text("Your profile, weight log, records, cardio plans, training plan and every logged workout are erased from this iPhone, and the watch stops being sent them.")
        }
        .alert("This cannot be undone", isPresented: $isConfirmingResetAgain) {
            Button("Yes", role: .destructive) { resetEverything() }
            Button("No", role: .cancel) {}
        } message: {
            Text("There is no backup and no undo. Export a report first if you want a copy.")
        }
        #if os(iOS)
        .sheet(isPresented: $isChoosingExport) {
            ReportOptionsView(selection: $reportSelection) {
                isChoosingExport = false
                // After the sheet is gone: two sheets cannot be presented from
                // the same view at once, and the share sheet is the one that
                // needs to be here.
                DispatchQueue.main.async { exportReport() }
            } onCancel: {
                isChoosingExport = false
            }
        }
        .sheet(item: $exportedReport) { report in
            ShareSheet(urls: report.urls)
        }
        #endif
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importFile(result)
        }
        .alert(
            importSummary?.headline ?? "Could not read that file",
            isPresented: Binding(
                get: { importSummary != nil || importFailure != nil },
                set: { if !$0 { importSummary = nil; importFailure = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            if let detail = importSummary?.detail {
                Text(detail)
            } else if let importFailure {
                Text(importFailure)
            }
        }
    }

    /// Reads the chosen file and hands it to the importer.
    ///
    /// The security-scoped dance is not optional: a file picked from Files or
    /// iCloud Drive lives outside the app's container, and the URL is readable
    /// only between `start` and `stop`. Skipping it works in the simulator with
    /// a file on the desktop and fails on the device, which is the worst shape
    /// a bug can have.
    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }

            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let document = try SenkuImportDocument.decode(try Data(contentsOf: url))
            let summary = SenkuImporter.apply(
                document,
                profiles: store,
                weights: weightLog,
                records: records,
                library: library,
                plans: plans,
                workouts: workouts,
                cardioRecords: cardioRecords,
                cardioPlans: cardioPlans,
                anime: anime,
                water: water,
                intake: intake
            )

            if summary.profileReplaced {
                // The same nudge every other profile edit gives: the watch is
                // told, and the screens that cache an edition redraw.
                profileEditionID = UUID()
            }
            publishWeight()
            importSummary = summary
        } catch is CancellationError {
            return
        } catch {
            importFailure = error.localizedDescription
        }
    }

    /// Everything, gone — and the screens rebuilt around the absence.
    ///
    /// The stores each hold their contents in memory, so wiping the defaults
    /// underneath them would leave every screen showing data that no longer
    /// exists until the app was relaunched. Replacing the store objects is what
    /// makes the reset visible: each one re-reads on construction and finds
    /// nothing.
    private func resetEverything() {
        DataReset.wipe()

        store = ProfileStore()
        weightLog = WeightLogStore()
        records = RecordStore()
        library = ExerciseLibrary()
        plans = TrainingPlanStore()
        workouts = WorkoutStore()
        cardioPlans = CardioProtocolStore()
        cardioRecords = CardioRecordStore()
        anime = AnimeStore()
        water = WaterStore()
        intake = IntakeStore()
        profileEditionID = UUID()
        generation = UUID()
        show(.quickCalc)

        #if os(iOS) && !targetEnvironment(macCatalyst)
        // The watch holds its own copy of the profile and the weight summary.
        // Told explicitly, rather than left to drift: a wiped phone and a watch
        // still showing yesterday's plan is worse than either.
        ProfileSync.shared.start(applying: store)
        publishWeight()
        #endif
    }

    /// Two files, shared together: the report to read and the backup to restore.
    ///
    /// The PDF is for a person — printable, sendable, readable in ten years by
    /// something that has never heard of Senku. The JSON is for the app, and it
    /// is what "Import Data" takes back: profile, weight log, records, custom
    /// exercises, training plan, every workout, cardio records and cardio
    /// plans. Neither can do the other's job, so the export offers both rather
    /// than asking which you meant.
    #if os(iOS)
    private func exportReport() {
        reportSelection.save()

        let pdf = reportSelection.isEmpty ? nil : ReportPDF.build(
            profile: store.profile,
            weights: weightLog,
            records: records,
            library: library,
            plans: plans,
            workouts: workouts,
            anime: anime,
            water: water,
            intake: intake,
            unitSystem: store.profile?.unitSystem ?? UnitPreference.current,
            selection: reportSelection
        )

        if !reportSelection.isEmpty, pdf == nil {
            importFailure = "The report could not be written."
            return
        }

        var files = [pdf].compactMap { $0 }
        if reportSelection.backup, let backup = writeBackup() { files.append(backup) }

        guard !files.isEmpty else {
            importFailure = "Nothing was selected to export."
            return
        }

        exportedReport = ExportedReport(urls: files)
    }

    private func writeBackup() -> URL? {
        let document = SenkuImportDocument.snapshot(
            profile: store.profile,
            weights: weightLog,
            records: records,
            library: library,
            plans: plans,
            workouts: workouts,
            cardioRecords: cardioRecords,
            cardioPlans: cardioPlans,
            anime: anime,
            water: water,
            intake: intake
        )

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Senku backup \(formatter.string(from: .now)).json")

        do {
            try document.encoded().write(to: url)
            return url
        } catch {
            return nil
        }
    }

    #endif

    /// Sends the watch the two figures it shows. Cheap enough to call freely:
    /// an application context replaces the one before it, so calling this three
    /// times in a second costs one delivery.
    private func publishWeight() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        ProfileSync.shared.send(weight: WeightSummary(log: weightLog, profile: store.profile))
        #endif
    }

    /// The watch's bottle, as two numbers.
    private func publishWater() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Read before publishing rather than trusting what is in memory. The
        // watch asks for this while the phone is in a pocket, and a widget tap
        // since the app was last on screen changed the total without anything
        // here noticing — the watch would be told a figure the phone itself no
        // longer believes.
        water.reload()

        ProfileSync.shared.send(
            water: WaterSummary(store: water, profile: store.profile, workouts: workouts)
        )
        #endif
    }

    /// The watch's two rings, as four numbers.
    private func publishIntake() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        // Read before publishing, for the same reason water does — see there.
        intake.reload()

        ProfileSync.shared.send(
            intake: IntakeSummary(store: intake, profile: store.profile)
        )
        #endif
    }

    /// Me, the three you chose, and More — in that order, always five.
    private var barTabs: [Tab] { [.me] + layout.chosen + [.more] }

    /// Opens a screen wherever it happens to live.
    ///
    /// A screen not in the bar is not unreachable — it is under More, and a
    /// deep link or an in-app jump has to land there rather than selecting a
    /// tab that is not on screen. Every `selection =` in this file goes through
    /// here for that reason.
    private func show(_ tab: Tab) {
        if barTabs.contains(tab) {
            moreDestination = nil
            selection = tab
        } else {
            moreDestination = tab
            selection = .more
        }
    }

    // MARK: - The destinations

    /// A screen without its navigation stack, so the same view can be a tab in
    /// the bar or a page pushed from More.
    @ViewBuilder
    private func screen(_ tab: Tab) -> some View {
        switch tab {
        case .me: meScreen
        case .quickCalc: quickCalcScreen
        case .rest: restScreen
        case .workout: workoutScreen
        case .weight: weightScreen
        case .water: waterScreen
        case .food: foodScreen
        case .records: recordsScreen
        case .anime: animeScreen
        case .more: EmptyView()   // the list itself, not a destination
        }
    }

    @ViewBuilder
    private var meScreen: some View {
        profileTab
            .senkuBottomBarInset()
            .navigationTitle(store.hasProfile ? "My plan" : "Senku")
    }

    @ViewBuilder
    private var quickCalcScreen: some View {
        // Saving is offered whether or not a profile exists. It used
        // to be hidden once one did, on the theory that this tab was
        // then only for other people's numbers — which left someone who
        // had just worked out their own new numbers here with no way to
        // keep them.
        CalculatorView(
            draft: PlanDraft(),
            saveTitle: store.hasProfile ? "Update my profile" : "Save as my profile"
        ) { profile in
            store.save(profile)
            profileEditionID = UUID()
            show(.me)
        }
        .senkuBottomBarInset()
            .navigationTitle("Quick calc")
    }

    @ViewBuilder
    private var restScreen: some View {
        RestTimerView()
            .senkuBottomBarInset()
            .navigationTitle("Rest")
    }

    @ViewBuilder
    private var weightScreen: some View {
        WeightLogView(store: weightLog, profile: store.profile) { trend in
            // Adopting the trend edits the one field it measures and leaves
            // the rest of the profile alone.
            guard var updated = store.profile else { return }
            guard let metrics = try? BodyMetrics(
                sex: updated.metrics.sex,
                age: updated.metrics.age,
                heightCM: updated.metrics.heightCM,
                weightKG: trend,
                bodyFatPercentage: updated.metrics.bodyFatPercentage
            ) else { return }

            updated.metrics = metrics
            store.save(updated)
            profileEditionID = UUID()
        }
        .senkuBottomBarInset()
            .navigationTitle("Weight")
    }

    /// The workout tab: today's checklist, and the plan behind it.
    @ViewBuilder
    private var workoutScreen: some View {
        WorkoutView(
            plans: plans,
            workouts: workouts,
            records: records,
            cardioRecords: cardioRecords,
            library: library,
            unitSystem: store.profile?.unitSystem ?? UnitPreference.current
        )
        .senkuBottomBarInset()
            .navigationTitle("Workout")
    }

    /// The target the profile has always computed, finally something to act on.
    @ViewBuilder
    private var waterScreen: some View {
        WaterView(store: water, workouts: workouts, profile: store.profile)
            .navigationTitle("Water")
    }

    @ViewBuilder
    private var foodScreen: some View {
        IntakeView(
            store: intake,
            profile: store.profile,
            weights: weightLog
        ) {
            show(.quickCalc)
        } onAdoptMaintenance: { measured in
            guard var profile = store.profile else { return }
            profile.measuredMaintenanceCalories = measured
            store.save(profile)
            // Every target in the app moves with it, and the watch is
            // holding a copy of the old ones.
            profileEditionID = UUID()
        }
        .navigationTitle("Food")
    }

    /// Nothing to do with training, and deliberately so — see F6.
    @ViewBuilder
    private var animeScreen: some View {
        AnimeView(store: anime)
            .navigationTitle("Anime")
    }

    @ViewBuilder
    private var recordsScreen: some View {
        RecordsView(
            store: records,
            library: library,
            protocols: cardioPlans,
            cardioRecords: cardioRecords,
            unitSystem: store.profile?.unitSystem ?? UnitPreference.current
        )
            // Spelled out where there is room for it. The tab keeps "PRs",
            // which is both what lifters say and all a tab bar slot will
            // hold without truncating.
            .senkuBottomBarInset()
            .navigationTitle("Personal Records")
    }

    /// A screen with its own navigation stack, as a tab needs it.
    private func stack(_ tab: Tab) -> some View {
        NavigationStack {
            screen(tab)
                .senkuWordmark()
        }
    }

    /// The system arrangement: a sidebar on iPad and Mac, a tab bar elsewhere.
    @ViewBuilder
    private var systemTabs: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            AdaptiveTabs(selection: $selection) {
                stack(.me)
            } quickCalc: {
                stack(.quickCalc)
            } rest: {
                stack(.rest)
            } workout: {
                stack(.workout)
            } weight: {
                stack(.weight)
            } water: {
                stack(.water)
            } food: {
                stack(.food)
            } records: {
                stack(.records)
            } anime: {
                stack(.anime)
            }
        } else {
            legacyTabs
        }
    }

    #if os(iOS)
    /// Every tab kept alive, one shown, above a bar that scrolls.
    ///
    /// A `ZStack` rather than a `switch`, and that is the whole trick: a switch
    /// would build the chosen screen and throw away the others, so every tab
    /// change would reset the one you left — its navigation stack popped, its
    /// scroll position lost, a half-typed weight gone. Keeping them all
    /// mounted and hiding five is what `TabView` does, and what makes leaving a
    /// tab and coming back feel like returning rather than starting again.
    private var scrollingTabs: some View {
        // A paging `TabView` rather than the stack it was: the same pages, kept
        // alive the same way, but reachable by swiping as well as by tapping
        // the bar. Every screen here scrolls vertically, so a horizontal drag
        // has nothing to argue with.
        TabView(selection: $selection) {
            ForEach(barTabs) { tab in
                page(tab) {
                    if tab == .more {
                        morePage
                    } else {
                        NavigationStack {
                            screen(tab)
                                .senkuWordmark()
                        }
                    }
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // The bar is the index; two of them would be one too many.
        .ignoresSafeArea(.keyboard)
        // A tick as each page lands, which is what makes a swipe feel like it
        // moved something rather than just animating.
        .onChange(of: selection) { _, _ in Feedback.control() }
        // The bar floats over the pages, and each page reserves room for it
        // from the inside — see `page(_:content:)`. A `safeAreaInset` out here
        // insets the stack, and the stack is not what scrolls: the lists are,
        // several layers down inside their own navigation stacks, and they went
        // on ending underneath the bar with their last rows unreachable.
        .overlay(alignment: .bottom) {
            SenkuTabBar(selection: $selection, tabs: barTabs)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    tabBarHeight = height
                }
        }
    }

    /// The list of everything the bar has no room for.
    private var morePage: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Tab.ordered.filter { !barTabs.contains($0) }) { tab in
                        Button {
                            moreDestination = tab
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tab.symbol)
                                    .foregroundStyle(tab.tint)
                                    .frame(width: 26)

                                Text(tab.title)
                                    .foregroundStyle(Color.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    NavigationLink {
                        TabBarEditor(layout: layout)
                    } label: {
                        Label("Choose what is in the bar", systemImage: "slider.horizontal.3")
                    }
                }
            }
            .senkuBottomBarInset()
            .navigationTitle("More")
            .senkuWordmark()
            .navigationDestination(item: $moreDestination) { tab in
                // The same screen it would be in the bar, one level deeper.
                screen(tab)
            }
        }
    }

    @ViewBuilder
    private func page<Content: View>(
        _ tab: Tab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            // Published, not applied. The screens inside each navigation stack
            // read it and pad themselves — see `senkuBottomBarInset()`, which
            // explains why an inset out here does nothing.
            .environment(\.senkuBottomInset, tabBarHeight)
            .tag(tab)
    }
    #endif

    /// The pre-iOS 18 arrangement: a plain tab bar, no sidebar and no pinning.
    ///
    /// The system's own bar, which means the system's own "More" past the fifth
    /// item — the same shape as the phone's custom bar, arrived at by a
    /// different route.
    private var legacyTabs: some View {
        TabView(selection: $selection) {
            ForEach(Tab.ordered) { tab in
                stack(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private var profileTab: some View {
        if let profile = store.profile {
            ProfileDashboardView(profile: profile) { updated in
                store.save(updated)
                profileEditionID = UUID()
            }
            .id(profileEditionID)
        } else {
            emptyProfile
        }
    }

    private var emptyProfile: some View {
        ContentUnavailableView {
            Label("No profile yet", systemImage: "person.crop.circle.dashed")
        } description: {
            Text("Work out your numbers in Quick calc, then save them here to keep them.")
        } actions: {
            Button("Open quick calc") {
                show(.quickCalc)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

/// The tab view that grows into a sidebar.
///
/// Separate because its customization — the reordering and pinning, remembered
/// across launches — is an iOS 18 type, and a stored property cannot be marked
/// available only from a later system the way a view can.
@available(iOS 18.0, macOS 15.0, *)
private struct AdaptiveTabs<
    Me: View,
    QuickCalc: View,
    Rest: View,
    Workout: View,
    Weight: View,
    Water: View,
    Food: View,
    Records: View,
    Anime: View
>: View {
    @Binding var selection: RootView.Tab

    @ViewBuilder var me: Me
    @ViewBuilder var quickCalc: QuickCalc
    @ViewBuilder var rest: Rest
    @ViewBuilder var workout: Workout
    @ViewBuilder var weight: Weight
    @ViewBuilder var water: Water
    @ViewBuilder var food: Food
    @ViewBuilder var records: Records
    @ViewBuilder var anime: Anime

    /// What the user has moved, pinned or hidden. Versioned, because a stored
    /// customization is keyed by the identifiers below: renaming one silently
    /// drops whatever they had arranged.
    @AppStorage("senku.tabs.v1") private var customization = TabViewCustomization()

    var body: some View {
        TabView(selection: $selection) {
            Tab("Me", systemImage: "person.fill", value: RootView.Tab.me) { me }
                .customizationID("senku.tab.me")

            Tab("Quick calc", systemImage: "function", value: RootView.Tab.quickCalc) { quickCalc }
                .customizationID("senku.tab.quickCalc")

            // Never hideable: this is the screen reached mid-set, and a rest
            // timer behind a customisation menu is a rest timer that is not
            // there when it is needed.
            Tab("Rest", systemImage: "timer", value: RootView.Tab.rest) { rest }
                .customizationID("senku.tab.rest")
                #if os(iOS)
                .customizationBehavior(.disabled, for: .sidebar, .tabBar)
                #endif

            Tab(
                "Workout",
                systemImage: "figure.strengthtraining.traditional",
                value: RootView.Tab.workout
            ) { workout }
                .customizationID("senku.tab.workout")

            Tab("Weight", systemImage: "scalemass", value: RootView.Tab.weight) { weight }
                .customizationID("senku.tab.weight")

            Tab("Water", systemImage: "drop.fill", value: RootView.Tab.water) { water }
                .customizationID("senku.tab.water")

            Tab("Food", systemImage: "fork.knife", value: RootView.Tab.food) { food }
                .customizationID("senku.tab.food")

            Tab("PRs", systemImage: "trophy", value: RootView.Tab.records) { records }
                .customizationID("senku.tab.records")

            Tab("Anime", systemImage: "sparkles.tv", value: RootView.Tab.anime) { anime }
                .customizationID("senku.tab.anime")
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewCustomization($customization)
    }
}

#Preview("Root") {
    RootView(store: ProfileStore(defaults: UserDefaults(suiteName: "senku.preview")!))
}

#if os(iOS)
/// A generated report, waiting to be shared.
struct ExportedReport: Identifiable {
    let urls: [URL]
    var id: String { urls.map(\.path).joined(separator: "|") }
}

/// The system share sheet, which SwiftUI has no native presentation for when
/// the thing being shared is produced on demand rather than known up front.
struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
#endif
