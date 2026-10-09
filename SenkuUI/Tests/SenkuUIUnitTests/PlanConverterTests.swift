import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The app hands out the plan-import skill and its prompt. These hold them to
/// the repository's copy, so the app can never give out a different skill
/// from the one in `skills/` — and to the importer, so a preview can never
/// promise a different week from the one Replace makes.
@MainActor
@Suite struct PlanConverterTests {
    private static let skill = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()      // SenkuUIUnitTests
        .deletingLastPathComponent()      // Tests
        .deletingLastPathComponent()      // SenkuUI
        .deletingLastPathComponent()      // the repo
        .appendingPathComponent("skills/senku-plan")

    private static let generated: Set<String> = ["prompt.md", "reference/catalogue.md"]

    private func files(in folder: URL) -> [String: Data] {
        var out: [String: Data] = [:]
        let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey])
        while let url = walker?.nextObject() as? URL {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let relative = url.standardizedFileURL.path
                .replacingOccurrences(of: folder.standardizedFileURL.path + "/", with: "")
            guard !relative.hasPrefix("data/"), !relative.contains("__pycache__"),
                  !relative.hasSuffix(".DS_Store"), !Self.generated.contains(relative)
            else { continue }
            out[relative] = try? Data(contentsOf: url)
        }
        return out
    }

    /// Run `python3 skills/senku-plan/scripts/senku_plan.py sync` when
    /// this fails: it mirrors the skill into the app.
    @Test func theAppCarriesTheSkillAsItIsInTheRepository() throws {
        let bundled = try #require(PlanConverter.skillFolder)
        let inApp = files(in: bundled)
        let inRepo = files(in: Self.skill)

        #expect(!inRepo.isEmpty)
        #expect(Set(inApp.keys) == Set(inRepo.keys))
        for (path, data) in inRepo {
            #expect(inApp[path] == data, "\(path) differs — run senku_plan.py sync")
        }
    }

    /// The app writes the exercise list and the prompt itself; the script
    /// writes them for the repository. Same text, or one of them is wrong.
    @Test func theAppWritesTheSameListAndPromptAsTheScript() throws {
        let catalogue = try String(contentsOf: Self.skill.appendingPathComponent("reference/catalogue.md"), encoding: .utf8)
        let prompt = try String(contentsOf: Self.skill.appendingPathComponent("prompt.md"), encoding: .utf8)

        #expect(PlanConverter.catalogueMarkdown(.bundled) == catalogue)
        #expect(try PlanConverter.prompt() == prompt)
    }

    /// Your own exercises go into the prompt as the exact line that brings
    /// them back — which, imported, lands in the same group.
    @Test func ownExercisesComeWithTheLineThatRemakesThem() throws {
        let catalogue = ExerciseCatalogue.bundled
        let regions = ["forearm.flexors", "back.lats"].compactMap { id in catalogue.muscleRegions.first { $0.id == id } }
        let towel = try #require(Exercise.custom(name: "Towel Row", equipment: .bodyweight, regions: regions))
        #expect(towel.workoutGroup == .forearm)

        let text = try PlanConverter.prompt(own: [towel])
        #expect(text.contains("## My own exercises"))

        let entry = PlanConverter.customEntry(for: towel)
        #expect(text.contains(entry))
        let decoded = try JSONDecoder().decode(SenkuImportDocument.CustomExerciseEntry.self, from: Data(entry.utf8))
        #expect(decoded.regionIDs.first == "forearm.flexors")
        #expect(decoded.equipment == "bodyweight")
    }

    /// Opened by the same unzip anyone would use, with everything inside.
    @Test func theSkillZipOpensWithEverythingInIt() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let zip = folder.appendingPathComponent("skill.zip")
        try PlanConverter.skillArchive().write(to: zip)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-q", zip.path, "-d", folder.path]
        try unzip.run()
        unzip.waitUntilExit()
        #expect(unzip.terminationStatus == 0)

        let root = folder.appendingPathComponent("senku-plan")
        for path in ["SKILL.md", "README.md", "prompt.md", "scripts/senku_plan.py", "reference/format.md",
                     "reference/catalogue.md", "data/catalogue.json", "examples/ppl-plan.senku.json"] {
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(path).path), "\(path)")
        }
        let catalogue = try Data(contentsOf: root.appendingPathComponent("data/catalogue.json"))
        #expect(catalogue == ExerciseCatalogue.bundledData)
    }

    @Test func crcIsTheStandardOne() {
        #expect(ZipWriter.crc32(Data("123456789".utf8)) == 0xCBF4_3926)
    }

    // MARK: - Preview

    private func stores() -> (ExerciseLibrary, TrainingPlanStore) {
        let suite = UserDefaults(suiteName: "senku.previewtest.\(UUID().uuidString)")!
        return (ExerciseLibrary(defaults: suite), TrainingPlanStore(defaults: suite))
    }

    private let file = """
    { "customExercises": [ { "name": "Towel Row", "equipment": "bodyweight", "regionIDs": ["back.lats"] } ],
      "records": [ { "exerciseID": "catalogue.bench.flat", "weightKG": 100, "reps": 5, "date": "2026-08-30" } ],
      "plan": { "target": { "sets": 3, "minReps": 8, "maxReps": 12 }, "days": [
        { "name": "Pull", "exercises": [ "Towel Row", { "name": "Lat Pulldown", "sets": 4 }, "Leg Curl" ] },
        { "name": "Cardio", "exercises": [ "Treadmill", "Plank" ] }
      ] } }
    """

    @Test func thePreviewShowsTheWeekWithoutTouchingYours() throws {
        let (library, plans) = stores()
        plans.add(SplitDay(name: "Mine", groups: [.chest], exerciseIDs: ["catalogue.bench.flat"]))

        let preview = try PlanImportPreview.make(from: Data(file.utf8), library: library)

        #expect(plans.days.map(\.name) == ["Mine"])
        #expect(library.custom.isEmpty)

        #expect(preview.plan.days.map(\.name) == ["Pull", "Cardio"])
        #expect(preview.plan.days[0].exerciseIDs.count == 2)
        #expect(preview.newExercises == ["Towel Row"])
        #expect(preview.problems.count == 1)
        #expect(preview.problems.first?.contains("Leg Curl") == true)
        #expect(preview.ignoredSections == ["records"])
        #expect(preview.plan.days[1].exerciseIDs.allSatisfy { preview.held.contains($0) || preview.cardio.contains($0) })
    }

    /// Replace does what the preview said, and nothing from the file's other
    /// sections comes with it.
    @Test func replacingMakesTheWeekThePreviewShowed() throws {
        let (library, plans) = stores()
        let records = RecordStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let preview = try PlanImportPreview.make(from: Data(file.utf8), library: library)

        preview.apply(library: library, plans: plans)

        #expect(plans.days.map(\.name) == preview.plan.days.map(\.name))
        #expect(plans.days.map(\.exerciseIDs.count) == preview.plan.days.map(\.exerciseIDs.count))
        #expect(plans.plan.target == preview.plan.target)
        #expect(library.custom.map(\.name) == ["Towel Row"])
        #expect(records.records.isEmpty)
    }

    @Test func aFileWithoutAPlanOrThatCannotBeReadIsSaidSo() {
        let (library, _) = stores()
        #expect(throws: PlanImportPreview.Failure.self) {
            try PlanImportPreview.make(from: Data(#"{"weighIns":[]}"#.utf8), library: library)
        }

        do {
            _ = try PlanImportPreview.make(
                from: Data(#"{"plan":{"target":{"sets":"3","reps":10},"days":[{"name":"A"}]}}"#.utf8),
                library: library
            )
            Issue.record("A text sets count should not import")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? ""
            #expect(message.contains("plan.target.sets"), "\(message)")
        }
    }

    /// The long press sends a plan-only file to the preview and anything with
    /// more in it — a backup — to the restore, as before.
    @Test func aPlanFileIsToldApartFromABackup() {
        #expect(PlanImportPreview.isPlanOnly(Data(#"{"schemaVersion":1,"plan":{"days":[]},"customExercises":[]}"#.utf8)))
        #expect(!PlanImportPreview.isPlanOnly(Data(#"{"plan":{"days":[]},"workouts":[]}"#.utf8)))
        #expect(!PlanImportPreview.isPlanOnly(Data(#"{"weighIns":[]}"#.utf8)))
        #expect(!PlanImportPreview.isPlanOnly(Data("not json".utf8)))
    }

    /// The preview carries the exercises themselves, new ones included, so a
    /// row can open its info sheet before anything is imported.
    @Test func thePreviewCarriesEveryExerciseItShows() throws {
        let (library, _) = stores()
        let preview = try PlanImportPreview.make(from: Data(file.utf8), library: library)
        let shown = Set(preview.plan.days.flatMap(\.exerciseIDs))

        #expect(Set(preview.exercises.keys) == shown)
        #expect(preview.exercises.values.contains { $0.name == "Towel Row" && $0.isCustom })
    }
}
