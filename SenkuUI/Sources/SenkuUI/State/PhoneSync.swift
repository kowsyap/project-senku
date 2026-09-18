#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import SenkuCore

/// The phone's side of the link, wired up at launch rather than on screen.
///
/// ## The bug this exists for
///
/// Everything the phone published used to be set up inside the root screen's
/// `task`: the session was activated there, the handlers were registered there,
/// and every summary was built from the stores that screen was holding. All of
/// which requires the phone's *interface* to exist.
///
/// It often does not. When the watch asks for a refresh, iOS launches the phone
/// app **in the background** — no window, no scene, no `task`. So the delegate
/// was never installed, the request went unanswered, and the watch went on
/// showing whatever it had been told days earlier. Opening the phone app fixed
/// it, which made the whole thing look like it worked, because opening the
/// phone app is what anybody does when they notice.
///
/// So this runs from `SenkuApp.init` — before any scene, on every launch
/// including a background one — and answers out of storage rather than out of
/// whatever a view happens to be holding.
@MainActor
public enum PhoneSync {
    public static func start() {
        let profiles = ProfileStore()
        ProfileSync.shared.start(applying: profiles)

        // Records coming the other way. Written straight to storage, because in
        // a background launch there is no screen holding a store to hand them
        // to. Each store re-reads before it writes, so a record landing here
        // while the app is also on screen cannot clobber what the screen did.
        ProfileSync.shared.onWeighInReceived { weighIn in
            WeightLogStore().add(weighIn)
            publish()
        }

        ProfileSync.shared.onDrinkReceived { drink in
            WaterStore().restore(drink)
            publish()
        }

        ProfileSync.shared.onMealReceived { meal in
            IntakeStore().restore(meal)
            publish()
        }

        // "Send me what you have" — answered from storage every time. The old
        // path replayed whatever was last held in memory, which in a background
        // launch was nothing at all: the watch got an empty context and kept
        // its stale figures.
        ProfileSync.shared.onRefreshRequested { publish() }

        publish()
    }

    /// Everything the watch draws, read fresh and sent as one context.
    public static func publish() {
        let profile = ProfileStore().profile
        let workouts = WorkoutStore()

        ProfileSync.shared.send(weight: WeightSummary(log: WeightLogStore(), profile: profile))
        ProfileSync.shared.send(
            water: WaterSummary(store: WaterStore(), profile: profile, workouts: workouts)
        )
        ProfileSync.shared.send(intake: IntakeSummary(store: IntakeStore(), profile: profile))

        // Last, because this is the call that actually puts the context on the
        // wire — the three above only park their summaries for it to carry.
        ProfileSync.shared.send(profile)
    }
}
#endif
