import Foundation
import Observation
import SenkuCore
#if os(iOS)
@preconcurrency import HealthKit
#endif

/// The kinds of data Senku can write to Apple Health, each switched on by
/// itself and asking for its own permission.
public enum HealthKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case water
    case food
    case body
    case workouts

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .water: "Water"
        case .food: "Food"
        case .body: "Body"
        case .workouts: "Workouts"
        }
    }
}

/// What is switched on for Apple Health, and since when.
///
/// Kept on this device only — never in a backup. Health permission belongs to
/// the phone it was granted on, so a restored "water on" on a new phone would
/// claim a permission that phone has never been asked for.
public struct HealthSettings: Codable, Equatable, Sendable {
    /// When each kind was switched on; absent while it is off. Entries logged
    /// before it stay out of Health: turning a kind on is a decision about from
    /// now, not a request to copy a year of history in.
    public var since: [HealthKind: Date] = [:]

    public init(since: [HealthKind: Date] = [:]) {
        self.since = since
    }

    public func isOn(_ kind: HealthKind) -> Bool { since[kind] != nil }

    private enum CodingKeys: String, CodingKey { case since, water, waterSince }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var since = try container.decodeIfPresent([HealthKind: Date].self, forKey: .since) ?? [:]
        // The first version stored water alone, as a flag and a date.
        if since.isEmpty,
           try container.decodeIfPresent(Bool.self, forKey: .water) == true,
           let waterSince = try container.decodeIfPresent(Date.self, forKey: .waterSince) {
            since[.water] = waterSince
        }
        self.since = since
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(since, forKey: .since)
    }
}

/// What has to change in Health for it to match the log.
///
/// Plain arithmetic on ids and fingerprints, separate from HealthKit so it can
/// be checked on the host.
enum HealthSyncPlan {
    /// One logged thing as the sync sees it: when it happened, and a
    /// fingerprint of what it says, so an edit is noticed.
    struct Item: Equatable {
        let id: UUID
        let date: Date
        let fingerprint: String
    }

    /// Write what is new or edited; remove what has gone, and the old samples
    /// of anything edited, before its new ones go in.
    ///
    /// New means logged since syncing began. Something already written stays
    /// tracked whatever its date, so moving an entry earlier than the switch
    /// still updates it rather than stranding the old version in Health.
    static func diff(
        _ items: [Item],
        since: Date,
        written: [UUID: String]
    ) -> (write: [UUID], remove: Set<UUID>) {
        var write: [UUID] = []
        var remove = Set(written.keys).subtracting(items.map(\.id))

        for item in items {
            if let previous = written[item.id] {
                guard previous != item.fingerprint else { continue }
                remove.insert(item.id)
                write.append(item.id)
            } else if item.date >= since {
                write.append(item.id)
            }
        }
        return (write, remove)
    }

    // MARK: - Fingerprints

    static func item(_ entry: WaterEntry) -> Item {
        Item(id: entry.id, date: entry.date, fingerprint: "\(entry.date.timeIntervalSince1970)|\(entry.millilitres)")
    }

    static func item(_ entry: IntakeEntry) -> Item {
        let parts: [String] = [
            "\(entry.date.timeIntervalSince1970)", entry.name ?? "",
            "\(entry.proteinG)", "\(entry.carbsG)", "\(entry.fatG)",
            entry.fiberG.map { "\($0)" } ?? "-", "\(entry.calories)",
        ]
        return Item(id: entry.id, date: entry.date, fingerprint: parts.joined(separator: "|"))
    }

    static func item(_ weighIn: WeighIn) -> Item {
        Item(id: weighIn.id, date: weighIn.date, fingerprint: "\(weighIn.date.timeIntervalSince1970)|\(weighIn.weightKG)")
    }

    /// Weigh-ins Senku should write: typed or logged here. One that arrived in
    /// a backup is a copy of a measurement already recorded somewhere.
    static func isWritable(_ weighIn: WeighIn) -> Bool {
        weighIn.source == .manual
    }
}

#if os(iOS)
/// Writes what Senku records into Apple Health (F7). Write-only: nothing is
/// read back, so Senku stays the source of record for everything it holds.
///
/// ## Reconciling rather than writing on each log
///
/// A drink can be logged from the app, a widget, a Siri shortcut or the watch,
/// and only the first runs this code. So rather than writing at the moment of
/// logging, each log is compared with what has been written whenever it
/// changes or the app comes forward, and the difference is sent. Every sample
/// carries its entry's id, so deleting or editing an entry can find what it
/// wrote.
@MainActor
@Observable
public final class HealthSync {
    public static let shared = HealthSync()

    static let settingsKey = "senku.health.v1"

    public private(set) var settings = HealthSettings()
    /// The last thing that went wrong, said in plain words, until the next try.
    public private(set) var problem: String?

    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private let defaults: UserDefaults
    /// Passes run one after another, never interleaved: two at once would
    /// both see the same entry as unwritten and save it twice.
    @ObservationIgnored private var tail: Task<Void, Never>?

    init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        reload()
    }

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Types

    /// Tags every sample with the entry it came from, for finding it again.
    private static let entryKey = "SenkuEntry"

    private static let water = HKQuantityType(.dietaryWater)
    private static let protein = HKQuantityType(.dietaryProtein)
    private static let carbs = HKQuantityType(.dietaryCarbohydrates)
    private static let fat = HKQuantityType(.dietaryFatTotal)
    private static let fiber = HKQuantityType(.dietaryFiber)
    private static let energy = HKQuantityType(.dietaryEnergyConsumed)
    private static let bodyMass = HKQuantityType(.bodyMass)
    private static let bodyFat = HKQuantityType(.bodyFatPercentage)
    private static let height = HKQuantityType(.height)
    private static let activeEnergy = HKQuantityType(.activeEnergyBurned)
    private static let foodCorrelation = HKCorrelationType(.food)
    private static let workout = HKWorkoutType.workoutType()

    /// What each kind asks permission to write. A food entry is written as a
    /// correlation of these, and the correlation itself is not something
    /// permission can be asked for — only its parts.
    private static func types(_ kind: HealthKind) -> Set<HKSampleType> {
        switch kind {
        case .water: [water]
        case .food: [protein, carbs, fat, fiber, energy]
        case .body: [bodyMass, bodyFat, height]
        case .workouts: [workout, activeEnergy]
        }
    }

    private func allowed(_ type: HKObjectType) -> Bool {
        store.authorizationStatus(for: type) == .sharingAuthorized
    }

    // MARK: - Switching on and off

    /// Switches a kind on or off. On asks for permission the first time — not
    /// at launch, where the question would come from nowhere.
    public func set(_ kind: HealthKind, on: Bool) async {
        problem = nil
        reload()

        guard on else {
            settings.since[kind] = nil
            persist()
            return
        }
        guard isAvailable else {
            problem = "Apple Health is not available on this device."
            return
        }
        do {
            try await store.requestAuthorization(toShare: Self.types(kind), read: [])
        } catch {
            problem = "Could not ask Apple Health for permission: \(error.localizedDescription)"
            return
        }
        guard Self.types(kind).contains(where: allowed) else {
            problem = "Senku is not allowed to save \(kind.title.lowercased()). Allow it in the Health app ▸ your profile ▸ Apps ▸ Senku."
            return
        }
        settings.since[kind] = .now
        persist()
        // The profile's height and body fat are facts already: written when
        // Body goes on, rather than waiting for them to change.
        if kind == .body { writtenProfile = [:] }
    }

    // MARK: - Reconciling

    /// Brings Health in line with everything logged, for whichever kinds are on.
    public func reconcile(
        water: [WaterEntry],
        food: [IntakeEntry],
        weighIns: [WeighIn],
        profile: ProfileStore.Profile?,
        sessions: [WorkoutSession]
    ) async {
        await serially {
            await self.reconcileOnce(water: water, food: food, weighIns: weighIns, profile: profile, sessions: sessions)
        }
    }

    /// Runs `work` after every pass already queued, never alongside one.
    private func serially(_ work: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let pass = Task { @MainActor in
            await previous?.value
            await work()
        }
        tail = pass
        await pass.value
    }

    private func reconcileOnce(
        water: [WaterEntry],
        food: [IntakeEntry],
        weighIns: [WeighIn],
        profile: ProfileStore.Profile?,
        sessions: [WorkoutSession]
    ) async {
        // Re-read first: a reset clears these along with the logs, and a sync
        // still believing itself on would read the emptied logs as everything
        // deleted, and take it all out of Health.
        reload()

        if let since = settings.since[.water] {
            await sync(.water, since: since, items: water.map(HealthSyncPlan.item)) { ids in
                water.filter { ids.contains($0.id) }.compactMap(self.sample(for:))
            }
        }
        if let since = settings.since[.food] {
            let entries = food.filter { !$0.isEmpty }
            await sync(.food, since: since, items: entries.map(HealthSyncPlan.item)) { ids in
                entries.filter { ids.contains($0.id) }.compactMap(self.correlation(for:))
            }
        }
        if let since = settings.since[.body] {
            let writable = weighIns.filter(HealthSyncPlan.isWritable)
            await sync(.body, since: since, items: writable.map(HealthSyncPlan.item)) { ids in
                writable.filter { ids.contains($0.id) }.compactMap(self.sample(for:))
            }
            await syncProfile(profile)
        }
        // Workouts are written only when confirmed on the summary, so the pass
        // only takes back a session that has since been deleted.
        if settings.isOn(.workouts) {
            var written = loadWritten(.workouts)
            let gone = Set(written.keys).subtracting(sessions.map(\.id))
            if !gone.isEmpty {
                do {
                    try await delete(.workouts, ids: gone)
                    for id in gone { written[id] = nil }
                    saveWritten(written, for: .workouts)
                } catch {
                    problem = "Could not remove a workout from Apple Health: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Workouts

    /// Whether a session has already gone to Health.
    public func hasWritten(_ session: WorkoutSession) -> Bool {
        loadWritten(.workouts)[session.id] != nil
    }

    /// Writes one session as a strength workout carrying its estimated active
    /// energy. Called only from the confirmation on the summary — never by a
    /// pass — because the duration and the effort are the user's to settle.
    @discardableResult
    public func write(
        _ session: WorkoutSession,
        start: Date,
        duration: TimeInterval,
        kilocalories: Double
    ) async -> Bool {
        var succeeded = false
        await serially {
            succeeded = await self.writeOnce(session, start: start, duration: duration, kilocalories: kilocalories)
        }
        return succeeded
    }

    private func writeOnce(_ session: WorkoutSession, start: Date, duration: TimeInterval, kilocalories: Double) async -> Bool {
        reload()
        guard settings.isOn(.workouts), allowed(Self.workout), !hasWritten(session) else { return false }

        let tag = Self.entryTag(.workouts, session.id)
        let end = start.addingTimeInterval(duration)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)
            if kilocalories > 0, allowed(Self.activeEnergy) {
                let energy = HKQuantitySample(
                    type: Self.activeEnergy,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kilocalories),
                    start: start,
                    end: end,
                    metadata: [Self.entryKey: tag]
                )
                try await builder.addSamples([energy])
            }
            try await builder.addMetadata([Self.entryKey: tag, HKMetadataKeyIndoorWorkout: true])
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            problem = "Could not save the workout to Apple Health: \(error.localizedDescription)"
            return false
        }

        var written = loadWritten(.workouts)
        written[session.id] = "\(start.timeIntervalSince1970)|\(duration)|\(kilocalories)"
        saveWritten(written, for: .workouts)
        problem = nil
        return true
    }

    /// One kind's pass: take back what has gone or changed, then write what is
    /// new or changed.
    private func sync(
        _ kind: HealthKind,
        since: Date,
        items: [HealthSyncPlan.Item],
        objects: ([UUID]) -> [HKObject]
    ) async {
        var written = loadWritten(kind)
        let plan = HealthSyncPlan.diff(items, since: since, written: written)

        if !plan.remove.isEmpty {
            do {
                try await delete(kind, ids: plan.remove)
                for id in plan.remove { written[id] = nil }
            } catch {
                problem = "Could not remove from Apple Health: \(error.localizedDescription)"
                saveWritten(written, for: kind)
                return
            }
        }

        if !plan.write.isEmpty {
            let toWrite = objects(plan.write)
            do {
                if !toWrite.isEmpty { try await store.save(toWrite) }
                let fingerprints = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0.fingerprint) })
                for id in plan.write { written[id] = fingerprints[id] }
                problem = nil
            } catch {
                problem = "Could not save to Apple Health: \(error.localizedDescription)"
            }
        }

        saveWritten(written, for: kind)
    }

    private func delete(_ kind: HealthKind, ids: Set<UUID>) async throws {
        let keys = ids.map { Self.entryTag(kind, $0) }
        var predicates = [HKQuery.predicateForObjects(withMetadataKey: Self.entryKey, allowedValues: keys)]
        // The first water samples were tagged only with a sync identifier.
        if kind == .water {
            predicates.append(HKQuery.predicateForObjects(
                withMetadataKey: HKMetadataKeySyncIdentifier,
                allowedValues: ids.map { "senku.water.\($0.uuidString)" }
            ))
        }
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)

        var types: [HKSampleType] = Array(Self.types(kind))
        if kind == .food { types.insert(Self.foodCorrelation, at: 0) }
        for type in types {
            _ = try await store.deleteObjects(of: type, predicate: predicate)
        }
    }

    // MARK: - Samples

    private static func entryTag(_ kind: HealthKind, _ id: UUID) -> String {
        "\(kind.rawValue).\(id.uuidString)"
    }

    private func quantity(
        _ type: HKQuantityType, _ unit: HKUnit, _ value: Double, at date: Date, tag: String,
        extra: [String: Any] = [:]
    ) -> HKQuantitySample? {
        guard allowed(type) else { return nil }
        return HKQuantitySample(
            type: type,
            quantity: HKQuantity(unit: unit, doubleValue: value),
            start: date,
            end: date,
            metadata: [Self.entryKey: tag].merging(extra) { a, _ in a }
        )
    }

    private func sample(for entry: WaterEntry) -> HKObject? {
        quantity(Self.water, .literUnit(with: .milli), entry.millilitres, at: entry.date,
                 tag: Self.entryTag(.water, entry.id))
    }

    /// One food entry as Health's food correlation: each nutrient Senku has a
    /// figure for, and nothing for what it does not — a protein-only entry
    /// writes protein and its calories, not a zero for fat.
    private func correlation(for entry: IntakeEntry) -> HKObject? {
        let tag = Self.entryTag(.food, entry.id)
        let date = entry.date
        let gram = HKUnit.gram()
        var parts: [HKSample?] = []
        if entry.proteinG > 0 { parts.append(quantity(Self.protein, gram, entry.proteinG, at: date, tag: tag)) }
        if entry.carbsG > 0 { parts.append(quantity(Self.carbs, gram, entry.carbsG, at: date, tag: tag)) }
        if entry.fatG > 0 { parts.append(quantity(Self.fat, gram, entry.fatG, at: date, tag: tag)) }
        if let fiber = entry.fiberG, fiber > 0 { parts.append(quantity(Self.fiber, gram, fiber, at: date, tag: tag)) }
        // One energy figure: the packet's if typed, otherwise the macros'.
        if entry.calories > 0 { parts.append(quantity(Self.energy, .kilocalorie(), entry.calories, at: date, tag: tag)) }

        let samples = Set(parts.compactMap { $0 })
        guard !samples.isEmpty else { return nil }

        var metadata: [String: Any] = [Self.entryKey: tag]
        if let name = entry.name { metadata[HKMetadataKeyFoodType] = name }
        return HKCorrelation(type: Self.foodCorrelation, start: date, end: date, objects: samples, metadata: metadata)
    }

    private func sample(for weighIn: WeighIn) -> HKObject? {
        quantity(Self.bodyMass, .gramUnit(with: .kilo), weighIn.weightKG, at: weighIn.date,
                 tag: Self.entryTag(.body, weighIn.id))
    }

    // MARK: - Height and body fat

    /// The profile's height and entered body fat, written when they change.
    ///
    /// Measurements rather than entries: a new height is a new sample beside
    /// the old one, not a replacement, because the old one was true when it
    /// was taken. Body fat is written only when entered — the estimate the
    /// app works out from BMI is a formula's, and Health would store it as a
    /// measurement.
    private func syncProfile(_ profile: ProfileStore.Profile?) async {
        guard let metrics = profile?.metrics else { return }
        var last = writtenProfile
        var samples: [HKObject] = []

        if last["heightCM"] != metrics.heightCM,
           let sample = quantity(Self.height, .meterUnit(with: .centi), metrics.heightCM, at: .now, tag: "body.height") {
            samples.append(sample)
            last["heightCM"] = metrics.heightCM
        }
        if let bodyFat = metrics.bodyFatPercentage, last["bodyFat"] != bodyFat,
           let sample = quantity(Self.bodyFat, .percent(), bodyFat / 100, at: .now, tag: "body.fat") {
            samples.append(sample)
            last["bodyFat"] = bodyFat
        }
        guard !samples.isEmpty else { return }
        do {
            try await store.save(samples)
            writtenProfile = last
        } catch {
            problem = "Could not save to Apple Health: \(error.localizedDescription)"
        }
    }

    // MARK: - Storage

    private static func writtenKey(_ kind: HealthKind) -> String { "senku.health.\(kind.rawValue).written.v2" }
    private static let profileKey = "senku.health.body.profile.v1"

    private func reload() {
        if let data = defaults.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(HealthSettings.self, from: data) {
            settings = decoded
        } else {
            settings = HealthSettings()
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.settingsKey)
    }

    private func loadWritten(_ kind: HealthKind) -> [UUID: String] {
        if let data = defaults.data(forKey: Self.writtenKey(kind)),
           let decoded = try? JSONDecoder().decode([UUID: String].self, from: data) {
            return decoded
        }
        // The first water version kept ids alone. With no fingerprint they read
        // as changed, so each is replaced once with an identical sample.
        if kind == .water,
           let data = defaults.data(forKey: "senku.health.water.written.v1"),
           let ids = try? JSONDecoder().decode([UUID].self, from: data) {
            return Dictionary(uniqueKeysWithValues: ids.map { ($0, "") })
        }
        return [:]
    }

    private func saveWritten(_ written: [UUID: String], for kind: HealthKind) {
        guard let data = try? JSONEncoder().encode(written) else { return }
        defaults.set(data, forKey: Self.writtenKey(kind))
    }

    private var writtenProfile: [String: Double] {
        get {
            guard let data = defaults.data(forKey: Self.profileKey),
                  let decoded = try? JSONDecoder().decode([String: Double].self, from: data)
            else { return [:] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Self.profileKey)
        }
    }
}
#endif
