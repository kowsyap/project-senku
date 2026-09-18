import Foundation
import Observation
import SenkuCore

/// The cardio protocols, one per exercise.
///
/// No history, by design. A protocol is the thing you are currently following;
/// the record of what you actually did on a given day is the workout log, and
/// keeping revisions of the plan as well would be two histories that disagree.
@Observable
public final class CardioProtocolStore {
    static let storageKey = "senku.cardioProtocols.v1"

    private let defaults: UserDefaults

    public private(set) var protocols: [CardioProtocol] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.protocols = Self.load(from: defaults)
    }

    public func plan(for exerciseID: String) -> CardioProtocol? {
        protocols.first { $0.exerciseID == exerciseID }
    }

    public func save(_ plan: CardioProtocol) {
        if let index = protocols.firstIndex(where: { $0.exerciseID == plan.exerciseID }) {
            protocols[index] = plan
        } else {
            protocols.append(plan)
        }
        persist()
    }

    public func delete(forExercise exerciseID: String) {
        protocols.removeAll { $0.exerciseID == exerciseID }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(protocols) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [CardioProtocol] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([CardioProtocol].self, from: data)
        else { return [] }
        return decoded
    }
}
