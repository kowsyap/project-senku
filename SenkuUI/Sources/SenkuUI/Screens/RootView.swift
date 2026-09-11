#if !os(watchOS)
import SwiftUI
import SenkuCore

/// The app's entry screen.
///
/// Three tabs. "Me" is a profile that persists and improves over time, while
/// "Quick calc" is for the friend who asks a question in the gym — no account,
/// no onboarding, nothing written down. The two audiences genuinely differ.
///
/// "Rest" sits alongside them rather than inside either, because it is the one
/// screen reached mid-set with a bar waiting: it has to be one tap from
/// anywhere, and it needs no profile to be useful.
public struct RootView: View {
    @State private var store: ProfileStore
    @State private var selection: Tab
    @State private var isConfirmingReset = false

    /// Reset when a profile is saved or cleared, so the calculator rebuilds its
    /// draft from the new state instead of holding a stale one.
    @State private var profileEditionID = UUID()

    private enum Tab: Hashable {
        case me
        case quickCalc
        case rest
    }

    public init(store: ProfileStore = ProfileStore()) {
        _store = State(initialValue: store)
        _selection = State(initialValue: store.hasProfile ? .me : .quickCalc)
    }

    public var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                profileTab
                    .navigationTitle(store.hasProfile ? "My plan" : "Senku")
                    .toolbar {
                        if store.hasProfile {
                            ToolbarItem {
                                Button("Reset", systemImage: "trash") {
                                    isConfirmingReset = true
                                }
                            }
                        }
                    }
            }
            .tabItem { Label("Me", systemImage: "person.fill") }
            .tag(Tab.me)

            NavigationStack {
                CalculatorView(
                    draft: PlanDraft(),
                    offersSaving: !store.hasProfile
                ) { profile in
                    store.save(profile)
                    profileEditionID = UUID()
                    selection = .me
                }
                .navigationTitle("Quick calc")
            }
            .tabItem { Label("Quick calc", systemImage: "function") }
            .tag(Tab.quickCalc)

            NavigationStack {
                RestTimerView()
                    .navigationTitle("Rest")
            }
            .tabItem { Label("Rest", systemImage: "timer") }
            .tag(Tab.rest)
        }
        .onOpenURL { url in
            if RestDeepLink.handle(url) != nil {
                selection = .rest
            }
        }
        .confirmationDialog(
            "Delete your saved profile?",
            isPresented: $isConfirmingReset,
            titleVisibility: .visible
        ) {
            Button("Delete profile", role: .destructive) {
                store.clear()
                profileEditionID = UUID()
                selection = .quickCalc
            }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text("Your numbers are only on this device, and this cannot be undone.")
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
                selection = .quickCalc
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview("Root") {
    RootView(store: ProfileStore(defaults: UserDefaults(suiteName: "senku.preview")!))
}
#endif
