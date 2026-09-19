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
enum SampleData {
    @MainActor
    static func loadIfAsked() {
        guard ProcessInfo.processInfo.environment["SENKU_SAMPLE"] != nil else { return }

        let profiles = ProfileStore()
        let intake = IntakeStore()
        // Already filled: loading twice would double every drink and meal,
        // since the importer merges rather than replaces.
        guard profiles.profile == nil || intake.entries.isEmpty else { return }

        guard let url = Bundle.main.url(forResource: "sample-data", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? SenkuImportDocument.decode(data)
        else {
            NSLog("SENKU_SAMPLE: sample-data.json is missing or will not decode")
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
            intake: intake
        )

        NSLog("SENKU_SAMPLE: \(summary.detail)")
    }
}
#endif
