import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// The format is a contract with a file somebody writes by hand, so the thing
/// worth testing is that the names in `docs/import-example.json` are the names
/// the decoder wants. A field renamed in `Profile` would otherwise break every
/// import in the field and nothing in the build.
@Suite struct SenkuImportTests {
    private let example = """
    {
      "schemaVersion": 1,
      "profile": {
        "name": "Kowsyap",
        "metrics": { "sex": "male", "age": 27, "heightCM": 178, "weightKG": 82.5 },
        "activityLevel": "moderate",
        "goal": "moderateCut",
        "formula": "mifflinStJeor",
        "unitSystem": "metric",
        "goalWeightKG": 75,
        "updatedAt": "2026-09-17T08:00:00Z"
      },
      "weighIns": [
        { "date": "2026-09-14", "weightKG": 83.1 },
        { "date": "2026-09-16T07:20:00Z", "weightKG": 82.5 }
      ],
      "customExercises": [
        { "name": "Landmine press", "equipment": "barbell", "regionIDs": ["shoulder.frontDelts"] }
      ],
      "records": [
        { "exerciseID": "catalogue.bench.flat", "weightKG": 100, "reps": 5, "date": "2026-08-30" }
      ]
    }
    """

    @Test func readsTheDocumentedExample() throws {
        let document = try SenkuImportDocument.decode(Data(example.utf8))

        #expect(document.profile?.name == "Kowsyap")
        #expect(document.profile?.metrics.weightKG == 82.5)
        #expect(document.profile?.goalWeightKG == 75)
        #expect(document.weighIns?.count == 2)
        #expect(document.records?.first?.reps == 5)
        #expect(document.customExercises?.first?.regionIDs == ["shoulder.frontDelts"])
    }

    /// A bare day and a full timestamp in the same file, which is what a
    /// hand-written list and an export look like side by side.
    @Test func acceptsBothDateShapes() throws {
        let document = try SenkuImportDocument.decode(Data(example.utf8))
        let dates = try #require(document.weighIns).map(\.date)

        #expect(dates[0] < dates[1])
    }

    /// Every section optional is the promise that lets a file written for a
    /// later version still load here.
    @Test func acceptsAFileWithOneSection() throws {
        let document = try SenkuImportDocument.decode(
            Data(#"{"weighIns":[{"date":"2026-01-02","weightKG":80}],"water":[{"ml":500}]}"#.utf8)
        )

        #expect(document.profile == nil)
        #expect(document.records == nil)
        #expect(document.weighIns?.count == 1)
    }

    @Test func rejectsAnUnparseableDate() {
        #expect(throws: (any Error).self) {
            try SenkuImportDocument.decode(
                Data(#"{"weighIns":[{"date":"last tuesday","weightKG":80}]}"#.utf8)
            )
        }
    }
}
