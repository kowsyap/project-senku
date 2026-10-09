import Foundation
import SenkuCore

/// The two ways to turn someone's plan into a file this app imports, handed
/// out from inside the app: a prompt for any AI chat, and the whole skill —
/// instructions, format, exercises and checker — for an AI that reads files.
///
/// Both are built from what this app actually has, at the moment they are
/// asked for: its own catalogue, and the person's own exercises. A copy kept
/// on a website goes stale the day the catalogue grows; this cannot.
///
/// The hand-written parts come from `PlanSkill`, a mirror of
/// `skills/senku-plan` kept by `senku_plan.py sync`. The generated parts
/// — the exercise list, the one-file prompt — are written here the same way
/// the script writes them, and a test holds the two to the same bytes.
public enum PlanConverter {
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

    /// Everything a chat AI needs in one paste: what to do, the format, and
    /// the exercises.
    public static func prompt(catalogue: ExerciseCatalogue = .bundled, own: [Exercise] = []) throws -> String {
        guard let folder = skillFolder else { throw Failure.missingSkill }
        let intro = try String(contentsOf: folder.appendingPathComponent("reference/prompt-intro.md"), encoding: .utf8)
        var format = try String(contentsOf: folder.appendingPathComponent("reference/format.md"), encoding: .utf8)
        if let heading = format.range(of: "# The plan file") {
            format.replaceSubrange(heading, with: "# The file format")
        }
        format = format.replacingOccurrences(
            of: "(`scripts/senku_plan.py regions`)",
            with: "(see the muscle id table at the end)"
        )
        return trimmingNewlines(intro) + "\n\n" + trimmingNewlines(format) + "\n\n"
            + catalogueMarkdown(catalogue, own: own)
    }

    private static func trimmingNewlines(_ text: String) -> String {
        var text = text
        while text.hasSuffix("\n") { text.removeLast() }
        return text
    }

    // MARK: - The skill

    /// The skill as a zip: its own files, plus the catalogue, the exercise
    /// list and the one-file prompt as this app has them.
    public static func skillArchive(catalogue: ExerciseCatalogue = .bundled, own: [Exercise] = []) throws -> Data {
        guard let folder = skillFolder else { throw Failure.missingSkill }
        var zip = ZipWriter()
        let root = "senku-plan/"

        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey])
        var entries: [(String, URL)] = []
        while let url = files?.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let relative = url.standardizedFileURL.path
                .replacingOccurrences(of: folder.standardizedFileURL.path + "/", with: "")
            guard !relative.hasPrefix("."), !relative.contains("__pycache__") else { continue }
            entries.append((relative, url))
        }
        for (relative, url) in entries.sorted(by: { $0.0 < $1.0 }) {
            zip.add(root + relative, data: try Data(contentsOf: url))
        }

        if let catalogueData = ExerciseCatalogue.bundledData {
            zip.add(root + "data/catalogue.json", data: catalogueData)
        }
        zip.add(root + "reference/catalogue.md", data: Data(catalogueMarkdown(catalogue, own: own).utf8))
        zip.add(root + "prompt.md", data: Data(try prompt(catalogue: catalogue, own: own).utf8))
        return zip.finished()
    }

    /// Both, written where the share sheet can hand them on.
    public static func files(own: [Exercise]) throws -> (prompt: URL, skill: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SenkuPlanConverter", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let promptURL = folder.appendingPathComponent("Senku plan prompt.md")
        let skillURL = folder.appendingPathComponent("senku-plan.zip")
        try Data(try prompt(own: own).utf8).write(to: promptURL, options: .atomic)
        try skillArchive(own: own).write(to: skillURL, options: .atomic)
        return (promptURL, skillURL)
    }
}

/// The smallest zip that every unzipper opens: files stored, not compressed.
///
/// The skill is a hundred and fifty kilobytes of text, so compression would
/// save little and cost a dependency or a deflate implementation. Stored
/// entries are the oldest, plainest part of the format.
struct ZipWriter {
    private var body = Data()
    private var directory = Data()
    private var count: UInt16 = 0

    mutating func add(_ path: String, data: Data) {
        let name = Data(path.utf8)
        let crc = Self.crc32(data)
        let offset = UInt32(body.count)
        // 1 January 2026, midnight, in MS-DOS form: a fixed date, so the same
        // contents make the same bytes.
        let time: UInt16 = 0
        let date: UInt16 = UInt16((2026 - 1980) << 9 | 1 << 5 | 1)

        var local = Data()
        local.append(le32: 0x0403_4b50)
        local.append(le16: 20)               // version needed
        local.append(le16: 0x0800)           // UTF-8 names
        local.append(le16: 0)                // stored
        local.append(le16: time)
        local.append(le16: date)
        local.append(le32: crc)
        local.append(le32: UInt32(data.count))
        local.append(le32: UInt32(data.count))
        local.append(le16: UInt16(name.count))
        local.append(le16: 0)
        local.append(name)
        body.append(local)
        body.append(data)

        var entry = Data()
        entry.append(le32: 0x0201_4b50)
        entry.append(le16: 20)               // made by
        entry.append(le16: 20)               // needed
        entry.append(le16: 0x0800)
        entry.append(le16: 0)
        entry.append(le16: time)
        entry.append(le16: date)
        entry.append(le32: crc)
        entry.append(le32: UInt32(data.count))
        entry.append(le32: UInt32(data.count))
        entry.append(le16: UInt16(name.count))
        entry.append(le16: 0)                // extra
        entry.append(le16: 0)                // comment
        entry.append(le16: 0)                // disk
        entry.append(le16: 0)                // internal attributes
        entry.append(le32: 0o100644 << 16)   // a plain readable file
        entry.append(le32: offset)
        entry.append(name)
        directory.append(entry)
        count += 1
    }

    func finished() -> Data {
        var out = body
        out.append(directory)
        out.append(le32: 0x0605_4b50)
        out.append(le16: 0)
        out.append(le16: 0)
        out.append(le16: count)
        out.append(le16: count)
        out.append(le32: UInt32(directory.count))
        out.append(le32: UInt32(body.count))
        out.append(le16: 0)
        return out
    }

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xEDB8_8320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func append(le16 value: UInt16) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(le32 value: UInt32) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}
