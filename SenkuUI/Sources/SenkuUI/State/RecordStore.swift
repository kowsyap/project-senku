import Foundation
import Observation
import SenkuCore

/// Every personal record, kept.
///
/// The same JSON-in-the-App-Group shape as `WeightLogStore`, and the same
/// caveat: it is the seam to swap when SwiftData arrives, not the final home.
///
/// One rule is enforced here rather than in a screen, because more than one
/// screen will eventually want it: **a record is never removed to make room
/// for a better one**. Beating a lift adds a row; the old row stays, which is
/// what makes the per-exercise timeline a history rather than a single figure
/// that silently overwrites itself.
@Observable
public final class RecordStore {
    static let storageKey = "senku.records.v1"

    private let defaults: UserDefaults

    public private(set) var records: [PersonalRecord] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.records = Self.load(from: defaults)
    }

    public var book: RecordBook { RecordBook(records) }

    public func add(_ record: PersonalRecord) {
        records.append(record)
        records.sort { $0.date > $1.date }
        persist()
    }

    /// Records a set, but only when it actually beats what is there.
    ///
    /// This is the hook the workout logger will use: every set is offered, and
    /// the book decides. Returns the record if one was made, so the caller can
    /// say so.
    @discardableResult
    public func offer(
        exerciseID: String,
        weightKG: Double,
        reps: Int,
        at date: Date = .now,
        setID: UUID
    ) -> PersonalRecord? {
        guard book.wouldBeRecord(exerciseID: exerciseID, weightKG: weightKG, reps: reps),
              let record = try? PersonalRecord(
                  exerciseID: exerciseID,
                  weightKG: weightKG,
                  reps: reps,
                  date: date,
                  source: .logged(setID: setID)
              )
        else { return nil }

        add(record)
        return record
    }

    /// Replaces a record with a corrected one, keeping its identity.
    ///
    /// Editing rather than delete-and-re-add on purpose: the row you fix is the
    /// row you mistyped, and a new id would leave the old figure's place in the
    /// history to something that never happened.
    public func update(_ record: PersonalRecord) {
        guard let index = records.firstIndex(where: { $0.id == record.id }) else { return }
        records[index] = record
        records.sort { $0.date > $1.date }
        persist()
    }

    /// Removes every record for one exercise.
    public func deleteAll(forExercise exerciseID: String) {
        records.removeAll { $0.exerciseID == exerciseID }
        persist()
    }

    public func delete(_ record: PersonalRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    /// Detaches records that came from a workout session being deleted.
    ///
    /// They become `.manual` rather than disappearing — open question 4 in the
    /// requirements doc, answered the way the doc proposes: deleting a session
    /// you mislogged is not the same as un-lifting the weight, and a PR history
    /// that quietly loses entries is worse than one with a typo in it.
    public func detachRecords(fromSets setIDs: Set<UUID>) {
        records = records.map { record in
            guard case .logged(let setID) = record.source, setIDs.contains(setID),
                  let detached = try? PersonalRecord(
                      id: record.id,
                      exerciseID: record.exerciseID,
                      weightKG: record.weightKG,
                      reps: record.reps,
                      date: record.date,
                      source: .manual
                  )
            else { return record }
            return detached
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [PersonalRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([PersonalRecord].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }
}
