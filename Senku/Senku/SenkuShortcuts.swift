import AppIntents
import SenkuUI

/// What Siri is allowed to do, and the words that reach it.
///
/// ## Why this exists at all
///
/// Senku had App Intents for a year before it had this, and Siri could not
/// reach a single one of them. An intent is only a *capability*; a provider is
/// what publishes it. Without one, the intents are reachable from the surfaces
/// that name them directly — a widget button, a Control Centre control, the
/// Live Activity — and from nowhere else. Asking Siri about your weight got an
/// answer off the web, because as far as Siri knew, this app had nothing to say.
///
/// ## Why it lives in the app target
///
/// Not in `SenkuUI`, where the intents themselves are. Phrase metadata is
/// extracted per-target at build time, and a provider inside a package is not
/// picked up. The intents can live anywhere; the provider cannot.
///
/// ## Why several phrasings each
///
/// Siri matches phrases rather than meaning, so the way you would actually ask
/// has to be in the list — "what's my weight", "how much do I weigh", "how
/// heavy am I" are three different keys to the same door. Every phrase must
/// contain `\(.applicationName)`; that is Apple's rule, not a house style, and
/// an intent whose phrases omit it is silently dropped.
struct SenkuShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WeightQueryIntent(),
            phrases: [
                "What's my weight in \(.applicationName)",
                "How much do I weigh in \(.applicationName)",
                "Check my weight in \(.applicationName)",
                "\(.applicationName) weight"
            ],
            shortTitle: "My weight",
            systemImageName: "scalemass"
        )

        AppShortcut(
            intent: WaterQueryIntent(),
            phrases: [
                "How much water have I had in \(.applicationName)",
                "How much water have I drunk in \(.applicationName)",
                "Check my water in \(.applicationName)",
                "\(.applicationName) water"
            ],
            shortTitle: "My water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: ProteinQueryIntent(),
            phrases: [
                "How much protein have I had in \(.applicationName)",
                "Check my protein in \(.applicationName)",
                "\(.applicationName) protein"
            ],
            shortTitle: "My protein",
            systemImageName: "fork.knife"
        )

        AppShortcut(
            intent: IntakeQueryIntent(),
            phrases: [
                "What have I eaten in \(.applicationName)",
                "How many calories have I had in \(.applicationName)",
                "Check my food in \(.applicationName)",
                "\(.applicationName) food"
            ],
            shortTitle: "My food",
            systemImageName: "chart.pie.fill"
        )

        AppShortcut(
            intent: LogProteinIntent(),
            phrases: [
                "Log protein in \(.applicationName)",
                "Add protein in \(.applicationName)"
            ],
            shortTitle: "Log protein",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: LogCaloriesIntent(),
            phrases: [
                "Log calories in \(.applicationName)",
                "Add calories in \(.applicationName)"
            ],
            shortTitle: "Log calories",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Log a glass of water in \(.applicationName)",
                "Add water in \(.applicationName)"
            ],
            shortTitle: "Log water",
            systemImageName: "drop.circle.fill"
        )

        AppShortcut(
            intent: StartRestIntent(),
            phrases: [
                "Start a rest in \(.applicationName)",
                "Start my rest timer in \(.applicationName)",
                "\(.applicationName) rest timer"
            ],
            shortTitle: "Start rest",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: StopRestIntent(),
            phrases: [
                "Stop my rest in \(.applicationName)",
                "Stop the rest timer in \(.applicationName)"
            ],
            shortTitle: "Stop rest",
            systemImageName: "stop.circle"
        )
    }
}
