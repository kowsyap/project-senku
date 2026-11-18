import Foundation
import SenkuCore

/// The prompts that get a plan file out of any AI chat, handed out from
/// inside the app: one to make a plan, one to convert a plan someone has.
///
/// Both are built from what this app actually has, at the moment they are
/// asked for: its own catalogue, the person's own exercises, and — for making
/// one — what the profile already knows about them. The skill itself, for AIs
/// that take skills, is published on its own (``skillPage``).
///
/// The hand-written parts come from `PlanSkill`, a mirror of
/// `skills/senku-plan` kept by `senku_plan.py sync`. The generated parts
/// — the exercise list, the prompts — are written here the same way the
/// script writes them, and a test holds the two to the same bytes.
public enum PlanConverter {
    /// Where the skill is published, with its download and install steps.
    public static let skillPage = URL(string: "https://github.com/kowsyap/senku-plan-skill")!

    public enum Kind: Sendable {
        /// Design a new plan from questions.
        case make
        /// Turn an existing plan into the file.
        case convert
    }

    /// The skill's folder inside the app.
    static var skillFolder: URL? {
        Bundle.module.url(forResource: "PlanSkill", withExtension: nil)
    }

    enum Failure: Error {
        case missingSkill
    }

    // MARK: - The exercise list

    /// Every exercise, by group, then the muscle ids — and, when there are
    /// any, the person's own exercises, ready to copy into `customExercises`.
    public static func catalogueMarkdown(_ catalogue: ExerciseCatalogue, own: [Exercise] = []) -> String {
        var lines = [
            "# Senku exercise catalogue",
            "",
            "Name exercises in a plan by **Name** (an alias works too, unless it is shared).",
            "Anything not listed here goes in `customExercises`.",
            "",
            "Catalogue version: `\(catalogue.version)`. Copy it into the file as `catalogueVersion`.",
            "",
        ]
        for group in catalogue.workoutGroups {
            lines += [
                "## \(group.rawValue)", "",
                "| Name | Also called | Equipment | Notes |",
                "| --- | --- | --- | --- |",
            ]
            let exercises = catalogue.exercises
                .filter { $0.workoutGroup == group }
                .sorted { $0.name.unicodeScalars.lexicographicallyPrecedes($1.name.unicodeScalars) }
            for exercise in exercises {
                let note = exercise.isTimed ? "held (seconds)" : (group == .cardio ? "cardio" : "")
                lines.append(
                    "| \(exercise.name) | \(exercise.aliases.joined(separator: ", ")) | \(exercise.equipment.rawValue) | \(note) |"
                )
            }
            lines.append("")
        }

        if !own.isEmpty {
            lines += [
                "## My own exercises", "",
                "Already in my app. To use one, name it in the plan and copy its entry into `customExercises` unchanged.",
                "",
                "| Name | customExercises entry |",
                "| --- | --- |",
            ]
            for exercise in own.sorted(by: { $0.name < $1.name }) {
                lines.append("| \(exercise.name) | `\(customEntry(for: exercise))` |")
            }
            lines.append("")
        }

        lines += [
            "## Muscle ids (for customExercises.regionIDs)", "",
            "| id | Muscle | Group |",
            "| --- | --- | --- |",
        ]
        for region in catalogue.muscleRegions {
            lines.append("| \(region.id) | \(region.name) | \(region.workoutGroup.rawValue) |")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// An exercise of the person's own, as the `customExercises` line that
    /// makes it again — its own group's muscle first, since the first one
    /// decides the group.
    static func customEntry(for exercise: Exercise) -> String {
        let regions = exercise.contributions.keys.sorted { lhs, rhs in
            let lhsHome = lhs.hasPrefix(exercise.workoutGroup.rawValue + ".")
            let rhsHome = rhs.hasPrefix(exercise.workoutGroup.rawValue + ".")
            return lhsHome != rhsHome ? lhsHome : lhs < rhs
        }
        var entry: [String: Any] = [
            "name": exercise.name,
            "equipment": exercise.equipment.rawValue,
            "regionIDs": regions,
        ]
        if exercise.isTimed { entry["isTimed"] = true }
        let data = (try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - The prompt

    /// The skill's line pointing at its script, swapped for a chat AI that
    /// cannot run it. The script makes the same swap.
    static let volumeLine = """
    Check the week with `python3 scripts/senku_plan.py volume FILE --days-per-week N`.
    It counts weekly sets per muscle from the catalogue's own muscle data and flags
    what is under-trained, over-trained or hit only once.
    """
    static let volumeByHand = "Count the hard sets per muscle for the week yourself before answering."

    /// Everything a chat AI needs in one paste: what to do, the format, and
    /// the exercises — and, for making a plan, how to design one and what the
    /// profile says about the person, ahead of everything else.
    public static func prompt(
        _ kind: Kind = .convert,
        catalogue: ExerciseCatalogue = .bundled,
        own: [Exercise] = [],
        aboutMe: String? = nil
    ) throws -> String {
        guard let folder = skillFolder else { throw Failure.missingSkill }
        func read(_ path: String) throws -> String {
            try String(contentsOf: folder.appendingPathComponent(path), encoding: .utf8)
        }
        let intro = try read(kind == .make ? "reference/prompt-make-intro.md" : "reference/prompt-intro.md")
        var format = try read("reference/format.md")
        if let heading = format.range(of: "# The plan file") {
            format.replaceSubrange(heading, with: "# The file format")
        }
        format = format.replacingOccurrences(
            of: "(`scripts/senku_plan.py regions`)",
            with: "(see the muscle id table at the end)"
        )
        var parts = [trimmingNewlines(intro)]
        if kind == .make {
            let design = try read("reference/design.md").replacingOccurrences(of: volumeLine, with: volumeByHand)
            parts.append(trimmingNewlines(design))
        }
        parts.append(trimmingNewlines(format))
        let text = parts.joined(separator: "\n\n") + "\n\n" + catalogueMarkdown(catalogue, own: own)
        guard let aboutMe, !aboutMe.isEmpty else { return text }
        return aboutMe + "\n\n" + text
    }

    /// What the profile already answers, so the AI need not ask it: put at
    /// the top of the make prompt, in plain sight before it is pasted anywhere.
    public static func aboutMe(_ profile: ProfileStore.Profile?) -> String? {
        guard let profile else { return nil }
        let metrics = profile.metrics
        let weight = Display.mass(metrics.weightKG, in: profile.unitSystem, decimals: 0)
        let aim: String = switch profile.goal {
        case .aggressiveCut, .moderateCut, .mildCut: "losing fat"
        case .maintain: "keeping my weight"
        case .leanBulk, .moderateBulk, .aggressiveBulk: "building muscle"
        }
        return """
        ## About me

        - \(metrics.sex.rawValue.capitalized), \(metrics.age), \(weight).
        - I am \(aim) at the moment.
        - Units: \(profile.unitSystem == .metric ? "kg" : "lb").
        """
    }

    private static func trimmingNewlines(_ text: String) -> String {
        var text = text
        while text.hasSuffix("\n") { text.removeLast() }
        return text
    }

    /// Both prompts, written where the share sheet can hand them on.
    public static func files(own: [Exercise], aboutMe: String?) throws -> (make: URL, convert: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SenkuPlanConverter", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let make = folder.appendingPathComponent("Senku make a plan prompt.md")
        let convert = folder.appendingPathComponent("Senku convert a plan prompt.md")
        try Data(try prompt(.make, own: own, aboutMe: aboutMe).utf8).write(to: make, options: .atomic)
        try Data(try prompt(.convert, own: own).utf8).write(to: convert, options: .atomic)
        return (make, convert)
    }
}
