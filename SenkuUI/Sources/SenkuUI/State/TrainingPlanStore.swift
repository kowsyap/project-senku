import Foundation
import Observation
import SenkuCore

/// The plan: which days exist, and what is in each.
///
/// Same JSON-in-the-App-Group shape as the other stores. Small and read
/// constantly — the workout screen asks it what today could be every time it
/// appears — so it stays wholly in memory and is written on every edit.
@Observable
public final class TrainingPlanStore {
    static let storageKey = "senku.plan.v1"

    private let defaults: UserDefaults

    public private(set) var plan: TrainingPlan

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.plan = Self.load(from: defaults)
    }

    public var days: [SplitDay] { plan.days }
    public var hasPlan: Bool { !plan.isEmpty }

    /// Days with at least one exercise picked — the only ones that can be
    /// started, since a day with nothing in it is a checklist of nothing.
    public var readyDays: [SplitDay] { plan.days.filter { !$0.isEmpty } }

    public func day(_ id: UUID) -> SplitDay? { plan.day(id) }

    // MARK: - Editing

    public func adopt(_ template: SplitTemplate) {
        plan = template.plan
        persist()
    }

    public func add(_ day: SplitDay) {
        plan.days.append(day)
        persist()
    }

    public func update(_ day: SplitDay) {
        guard let index = plan.days.firstIndex(where: { $0.id == day.id }) else { return }
        plan.days[index] = day
        persist()
    }

    public func delete(_ day: SplitDay) {
        plan.days.removeAll { $0.id == day.id }
        persist()
    }

    public func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        plan.days.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    /// Adds an exercise to a day, at the end, once.
    public func add(exercise id: String, to dayID: UUID) {
        guard let index = plan.days.firstIndex(where: { $0.id == dayID }),
              !plan.days[index].exerciseIDs.contains(id)
        else { return }

        plan.days[index].exerciseIDs.append(id)
        persist()
    }

    public func remove(exercise id: String, from dayID: UUID) {
        guard let index = plan.days.firstIndex(where: { $0.id == dayID }) else { return }
        plan.days[index].exerciseIDs.removeAll { $0 == id }
        persist()
    }

    /// Drops an exercise from every day that names it.
    ///
    /// For a custom exercise being deleted: the plan must not keep pointing at
    /// something the library no longer has, or a checklist comes up with a row
    /// that cannot be named. Records are untouched, per F2 — a lift you did
    /// stays on the PR page whether or not you still train it.
    public func removeEverywhere(exercise id: String) {
        var changed = false
        for index in plan.days.indices where plan.days[index].exerciseIDs.contains(id) {
            plan.days[index].exerciseIDs.removeAll { $0 == id }
            changed = true
        }
        guard changed else { return }
        persist()
    }

    public func isUsed(exercise id: String) -> Bool {
        plan.days.contains { $0.exerciseIDs.contains(id) }
    }

    // MARK: - Storage

    private func persist() {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> TrainingPlan {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(TrainingPlan.self, from: data)
        else { return TrainingPlan() }
        return decoded
    }
}
