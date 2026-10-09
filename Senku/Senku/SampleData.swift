#if DEBUG
import Foundation
import SenkuCore
import SenkuUI

/// Fills a simulator with a plausible three weeks of use.
///
/// ## Why this exists
///
/// An empty app photographs badly and demonstrates nothing: every screen is an
/// empty state, and the parts worth looking at — a trend line, a coverage ring,
/// a streak — need history behind them before they say anything. This loads
/// `sample-data.json`, which is the same format the app's own "Import Data"
/// takes, through the same importer. So the sample is not a special path into
/// the app: it is a file anybody can open, and if it stops importing cleanly,
/// so has everybody else's backup.
///
/// Debug builds only, and only when asked:
///
/// ```
/// SIMCTL_CHILD_SENKU_SAMPLE=1 xcrun simctl launch <device> pk.Senku
/// ```
///
/// Or a path, for another person's data — the README screenshots are made
/// from `docs/screenshots/make_persona.py` this way:
///
/// ```
/// SIMCTL_CHILD_SENKU_SAMPLE=/path/to/maya.json xcrun simctl launch <device> pk.Senku
/// ```
enum SampleData {
    @MainActor
    static func loadIfAsked() {
        guard let asked = ProcessInfo.processInfo.environment["SENKU_SAMPLE"] else { return }

        let profiles = ProfileStore()
        let intake = IntakeStore()
        // Already filled: loading twice would double every drink and meal,
        // since the importer merges rather than replaces.
        guard profiles.profile == nil || intake.entries.isEmpty else { return }

        let url = asked.hasPrefix("/")
            ? URL(fileURLWithPath: asked)
            : Bundle.main.url(forResource: "sample-data", withExtension: "json")
        let document: SenkuImportDocument
        do {
            guard let url else { throw CocoaError(.fileNoSuchFile) }
            document = try SenkuImportDocument.decode(try Data(contentsOf: url))
        } catch {
            NSLog("SENKU_SAMPLE: \(asked) is missing or will not decode: \(error)")
            return
        }

        let summary = SenkuImporter.apply(
            document,
            profiles: profiles,
            weights: WeightLogStore(),
            records: RecordStore(),
            library: ExerciseLibrary(),
            plans: TrainingPlanStore(),
            workouts: WorkoutStore(),
            cardioRecords: CardioRecordStore(),
            cardioPlans: CardioProtocolStore(),
            anime: AnimeStore(),
            water: WaterStore(),
            intake: intake,
            dueDates: DueDateStore(),
            watchlist: WatchlistName.shared
        )

        NSLog("SENKU_SAMPLE: \(summary.detail ?? "nothing imported")")
    }
}
#endif
