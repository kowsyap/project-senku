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

    private static let generated: Set<String> = ["prompt.md", "prompt-make.md", "reference/catalogue.md"]

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

    /// The make prompt carries the design guide, with the script line a chat
    /// AI cannot follow swapped out, and "about me" goes on top.
    @Test func theMakePromptMatchesTheScriptAndPutsYouFirst() throws {
        let prompt = try String(contentsOf: Self.skill.appendingPathComponent("prompt-make.md"), encoding: .utf8)
        #expect(try PlanConverter.prompt(.make) == prompt)
        #expect(prompt.contains("# Designing a plan"))
        #expect(!prompt.contains("senku_plan.py volume"))

        let about = "## About me\n\n- Male, 30, 80 kg."
        #expect(try PlanConverter.prompt(.make, aboutMe: about).hasPrefix(about + "\n\n# Make me a workout plan"))
    }

    /// A file stamped with another exercise list says so in the preview.
    @Test func anOlderExerciseListIsNoticed() throws {
        let (library, _) = stores()
        let stamped = { (version: String) in
            Data("""
            { "catalogueVersion": "\(version)", "plan": { "days": [ { "name": "A", "exercises": ["Barbell Bench Press"] } ] } }
            """.utf8)
        }
        #expect(try PlanImportPreview.make(from: stamped("00000000"), library: library).madeWithOtherCatalogue)
        let current = try PlanImportPreview.make(from: stamped(library.catalogue.version), library: library)
        #expect(!current.madeWithOtherCatalogue)
        #expect(current.ignoredSections.isEmpty)
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

    /// The notice the app shows is the one the library ships — MIT asks for it
    /// word for word in every copy, and the repository's copy is the record.
    @Test func theAboutPageCarriesTheBodyFigureNoticeWordForWord() throws {
        let notices = try String(
            contentsOf: Self.skill.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("THIRD_PARTY_NOTICES.md"),
            encoding: .utf8
        )
        let parts = notices.components(separatedBy: "```")
        #expect(parts.count >= 3)
        let block = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(AboutView.bodyHighlighterNotice == block)
    }
}
