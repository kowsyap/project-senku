import Foundation
import Observation
import SenkuCore

/// Cardio records, kept the same way lifting records are.
///
/// Same rule as `RecordStore`: a new record is added, never substituted for the
/// old one, so each exercise keeps a timeline rather than a single figure that
/// silently overwrites itself.
@Observable
public final class CardioRecordStore {
    static let storageKey = "senku.cardioRecords.v1"

    private let defaults: UserDefaults

    public private(set) var records: [CardioRecord] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.records = Self.load(from: defaults)
    }

    public var book: CardioBook { CardioBook(records) }

    public func add(_ record: CardioRecord) {
        records.append(record)
        records.sort { $0.date > $1.date }
        persist()
    }

    /// Offers a session, and keeps it only if it beats what is there.
    @discardableResult
    public func offer(
        _ effort: CardioEffort,
        for exerciseID: String,
        sessionID: UUID
    ) -> CardioRecord? {
        guard book.wouldBeRecord(
            exerciseID: exerciseID,
            seconds: effort.seconds,
            values: effort.values
        ), let record = try? CardioRecord(effort, exerciseID: exerciseID, sessionID: sessionID)
        else { return nil }

        add(record)
        return record
    }

    public func delete(_ record: CardioRecord) {
        records.removeAll { $0.id == record.id }
        persist()
    }

    public func deleteAll(forExercise exerciseID: String) {
        records.removeAll { $0.exerciseID == exerciseID }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [CardioRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CardioRecord].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }
}
