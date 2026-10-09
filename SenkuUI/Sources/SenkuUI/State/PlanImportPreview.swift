import Foundation
import SenkuCore

/// What importing a plan file would do, worked out before it is done.
///
/// A dry run of the real import, not a second opinion: the same importer runs
/// against throwaway stores that start with your own exercises, and the plan
/// it leaves behind is the plan the preview shows. So the preview cannot
/// disagree with what Replace then does — the thing a preview most needs.
///
/// Only the plan and the custom exercises are taken from the file. Anything
/// else in it — a whole backup, say — is named and left out: this is the
/// Week page, and its import changes the week.
@MainActor
public struct PlanImportPreview {
    /// The file, trimmed to what this import brings in.
    public let document: SenkuImportDocument
    /// The plan as it will be stored.
    public let plan: TrainingPlan
    /// Every exercise in the plan, new ones included — for names, for
    /// coverage, and for the info sheet a row opens.
    public let exercises: [String: Exercise]

    public var names: [String: String] { exercises.mapValues(\.name) }
    public var held: Set<String> { Set(exercises.values.filter(\.isTimed).map(\.id)) }
    public var cardio: Set<String> { Set(exercises.values.filter(\.isCardio).map(\.id)) }
    /// Custom exercises the import would add.
    public let newExercises: [String]
    /// What would be skipped, in the importer's own words.
    public let problems: [String]
    /// Sections of the file this import leaves alone.
    public let ignoredSections: [String]

    public enum Failure: Error, LocalizedError {
        case unreadable(String)
        case noPlan

        public var errorDescription: String? {
            switch self {
            case .unreadable(let reason):
                "Senku can’t read this file. \(reason)"
            case .noPlan:
                "This file has no plan in it — no days to import."
            }
        }
    }

    private static let planSections: Set<String> = ["schemaVersion", "plan", "customExercises", "unitSystem"]

    /// A file that is a plan and nothing else — what the AI converters make —
    /// as opposed to a backup, which carries a plan among everything else.
    public static func isPlanOnly(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["plan"] != nil
        else { return false }
        return Set(object.keys).isSubset(of: planSections)
    }

    public static func make(from data: Data, library: ExerciseLibrary) throws -> PlanImportPreview {
        let full: SenkuImportDocument
        do {
            full = try SenkuImportDocument.decode(data)
        } catch {
            throw Failure.unreadable(Self.reason(for: error))
        }
        guard let plan = full.plan, !plan.days.isEmpty else { throw Failure.noPlan }

        let keys = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?.keys.map { $0 } ?? []
        var document = SenkuImportDocument()
        document.schemaVersion = full.schemaVersion
        document.plan = plan
        document.customExercises = full.customExercises

        // The dry run: your exercises, a blank week, and the real importer.
        let suiteName = "senku.planPreview.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let scratchLibrary = ExerciseLibrary(defaults: suite)
        for exercise in library.custom { scratchLibrary.add(exercise) }
        let scratchPlans = TrainingPlanStore(defaults: suite)
        let summary = SenkuImporter.applyPlan(document, library: scratchLibrary, plans: scratchPlans)

        let existing = Set(library.custom.map(\.id))
        let ids = Set(scratchPlans.plan.days.flatMap(\.exerciseIDs))
        let exercises = ids.compactMap { scratchLibrary.exercise($0) }

        return PlanImportPreview(
            document: document,
            plan: scratchPlans.plan,
            exercises: Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) }),
            newExercises: scratchLibrary.custom.filter { !existing.contains($0.id) }.map(\.name),
            problems: summary.problems,
            ignoredSections: keys.filter { !planSections.contains($0) }.sorted()
        )
    }

    /// Does it, for real.
    @discardableResult
    public func apply(library: ExerciseLibrary, plans: TrainingPlanStore) -> ImportSummary {
        SenkuImporter.applyPlan(document, library: library, plans: plans)
    }

    /// A decoding error, said so that it can be pasted back to the AI that
    /// wrote the file.
    private static func reason(for error: Error) -> String {
        guard let error = error as? DecodingError else { return error.localizedDescription }
        func path(_ context: DecodingError.Context) -> String {
            let path = context.codingPath.map { $0.intValue.map { "[\($0)]" } ?? ".\($0.stringValue)" }.joined()
            return path.isEmpty ? "the file" : String(path.drop(while: { $0 == "." }))
        }
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context):
            return "At \(path(context)): \(context.debugDescription)"
        case .keyNotFound(let key, let context):
            return "At \(path(context)): “\(key.stringValue)” is missing."
        case .dataCorrupted(let context):
            return "At \(path(context)): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
