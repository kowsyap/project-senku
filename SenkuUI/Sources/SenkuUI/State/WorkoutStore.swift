import Foundation
import Observation
import SenkuCore

/// Workouts: the one in progress, and every one before it.
///
/// ## The live session is stored, not held
///
/// A workout lasts an hour and a half, and for most of that the phone is in a
/// pocket with the app long since evicted from memory. So the session in
/// progress is written to disk on every set, exactly like a finished one, and
/// picked up again on launch. Anything less loses the first forty minutes of a
/// session the first time iOS decides it needs the RAM.
///
/// ## Finishing is explicit
///
/// A session with no `finishedAt` is live, however old it is. There is no timer
/// quietly closing it: a workout you walked away from is still the one you come
/// back to, and the only thing that ends it is saying so. ``discardStale``
/// exists for the genuinely abandoned one, and asks first.
@Observable
public final class WorkoutStore {
    static let liveKey = "senku.workout.live.v1"
    static let historyKey = "senku.workout.history.v1"

    private let defaults: UserDefaults

    /// The workout in progress, if there is one.
    public private(set) var live: WorkoutSession?

    /// Finished workouts, newest first.
    public private(set) var history: [WorkoutSession] = []

    public init(defaults: UserDefaults = SenkuStorage.shared) {
        self.defaults = defaults
        self.live = Self.loadLive(from: defaults)
        self.history = Self.loadHistory(from: defaults)
    }

    // MARK: - The live session

    @discardableResult
    public func start(_ day: SplitDay, at date: Date = .now) -> WorkoutSession {
        let session = WorkoutSession(startingFrom: day, at: date)
        live = session
        persistLive()
        return session
    }

    public func update(_ session: WorkoutSession) {
        guard live?.id == session.id else { return }
        live = session
        persistLive()
    }

    /// Logs a set and hands back the PR it made, if it made one.
    ///
    /// The tie to F2 lives here rather than in a view, so that every way of
    /// logging a set — this screen, the watch, a future import — offers the
    /// same set to the record book and none of them can forget to. The record
    /// is `.logged`, carrying the set's id, which is what lets a deleted set
    /// take its record with it.
    @discardableResult
    public func log(
        _ set: LoggedSet,
        for exerciseID: String,
        records: RecordStore
    ) -> PersonalRecord? {
        guard var session = live else { return nil }

        session.add(set, to: exerciseID)
        live = session
        persistLive()

        return records.offer(
            exerciseID: exerciseID,
            weightKG: set.weightKG,
            reps: set.reps,
            at: set.completedAt,
            setID: set.id
        )
    }

    /// Removes a set, and detaches any record that was made from it.
    ///
    /// Detached rather than deleted: the lift was still performed, and a record
    /// that quietly vanished because a typo was corrected elsewhere would be a
    /// worse surprise than one that stays with its provenance downgraded to
    /// manual. That is `RecordStore.detachRecords(fromSets:)`, which already
    /// exists for exactly this.
    public func removeSet(_ setID: UUID, from exerciseID: String, records: RecordStore) {
        guard var session = live else { return }

        session.removeSet(setID, from: exerciseID)
        live = session
        persistLive()

        records.detachRecords(fromSets: [setID])
    }

    /// Records a cardio session, and offers it to the cardio record book.
    ///
    /// The same shape as `log(_:for:records:)` for lifts, and here for the same
    /// reason: every way of logging cardio should reach the PR page by the same
    /// path, so none of them can forget to.
    @discardableResult
    public func logCardio(
        _ effort: CardioEffort?,
        for exerciseID: String,
        records: CardioRecordStore? = nil
    ) -> CardioRecord? {
        guard var session = live else { return nil }

        session.setCardio(effort, for: exerciseID)
        live = session
        persistLive()

        guard let effort, let records else { return nil }
        return records.offer(effort, for: exerciseID, sessionID: session.id)
    }

    public func setMarkedDone(_ done: Bool, for exerciseID: String) {
        guard var session = live else { return }
        session.setMarkedDone(done, for: exerciseID)
        live = session
        persistLive()
    }

    public func setSkipped(_ skipped: Bool, for exerciseID: String) {
        guard var session = live else { return }
        session.setSkipped(skipped, for: exerciseID)
        live = session
        persistLive()
    }

    public func addExercise(_ exerciseID: String) {
        guard var session = live else { return }
        session.addExercise(exerciseID)
        live = session
        persistLive()
    }

    public func removeExercise(_ exerciseID: String) {
        guard var session = live else { return }
        session.removeExercise(exerciseID)
        live = session
        persistLive()
    }

    /// Ends the workout and files it.
    ///
    /// A session with nothing logged is dropped rather than filed: starting a
    /// day, looking at the list and putting the phone away is not a workout,
    /// and a history full of empty ones makes the real ones harder to find.
    @discardableResult
    public func finish(at date: Date = .now) -> WorkoutSession? {
        guard var session = live else { return nil }
        live = nil
        defaults.removeObject(forKey: Self.liveKey)

        guard session.hasAnything else { return nil }

        session.finishedAt = date
        history.insert(session, at: 0)
        persistHistory()
        return session
    }

    public func discardLive() {
        live = nil
        defaults.removeObject(forKey: Self.liveKey)
    }

    // MARK: - History

    /// Puts a session back, exactly as it was. For restoring a backup.
    ///
    /// A session still running goes back to being the live one, so a backup
    /// taken mid-workout restores mid-workout — which is when someone is most
    /// likely to have needed it.
    public func contains(_ id: UUID) -> Bool {
        live?.id == id || history.contains { $0.id == id }
    }

    public func restore(_ session: WorkoutSession) {
        if session.isFinished {
            history.append(session)
            history.sort { $0.date > $1.date }
            persistHistory()
        } else {
            live = session
            persistLive()
        }
    }

    public func delete(_ session: WorkoutSession) {
        history.removeAll { $0.id == session.id }
        persistHistory()
    }

    /// Which days of the plan you have already trained this week.
    ///
    /// The week runs Monday to Sunday and resets on the Monday, whatever state
    /// it was left in — and also resets the moment every day has been trained,
    /// so a plan run twice in a week starts over rather than sitting complete. That is deliberately blunt: a fortnight ago I derived a
    /// "round" that only closed once every day had been trained, and the flaw
    /// showed the first time a week went badly — miss legs, and legs stays
    /// ticked off as outstanding into the next week and the one after, so the
    /// count never reads as a fresh start. Two of three done is a finished
    /// week, not a debt.
    ///
    /// Nothing is stored. The week is computed from the calendar and the
    /// history is filtered by it, so there is no marker to reset, to migrate,
    /// or to fall out of step with what actually happened.
    public func completedDays(
        in plan: TrainingPlan,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Set<UUID> {
        let planned = Set(plan.days.filter { !$0.isEmpty }.map(\.id))
        guard !planned.isEmpty, let week = Self.week(containing: now, calendar: calendar) else {
            return []
        }

        // Two things clear the board, and both have to. The Monday is the
        // outer rule: a week that went badly does not follow you into the next
        // one. Finishing every day is the inner one: someone who trains a
        // three-day plan twice in a week should see it empty out and start
        // again on the Thursday, not sit on "all done" for four days with
        // nothing left to tick.
        var done: Set<UUID> = []
        for session in history.reversed()
        where week.contains(session.date) && planned.contains(session.dayID) {
            done.insert(session.dayID)
            if done == planned { done.removeAll() }
        }
        return done
    }

    /// Monday to Sunday, regardless of where the device's locale starts its
    /// week — a training week is a training week in Riyadh and in Boston.
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval? {
        var weekly = calendar
        weekly.firstWeekday = 2
        return weekly.dateInterval(of: .weekOfYear, for: date)
    }

    /// The last time this day was trained, for "you last did this on Tuesday".
    public func lastSession(forDay dayID: UUID) -> WorkoutSession? {
        history.first { $0.dayID == dayID }
    }

    /// The last time this exercise was performed, in any session.
    ///
    /// What the logging sheet opens on: the weight you used last time is very
    /// nearly always the weight you are about to use, and typing it again is
    /// the tax this removes.
    public func lastEntry(forExercise exerciseID: String) -> (WorkoutSession, WorkoutEntry)? {
        for session in history {
            if let entry = session.entry(exerciseID), entry.hasAnyWork {
                return (session, entry)
            }
        }
        return nil
    }

    public func sessions(since date: Date) -> [WorkoutSession] {
        history.filter { $0.date >= date }
    }

    // MARK: - Storage

    private func persistLive() {
        guard let live, let data = try? JSONEncoder().encode(live) else { return }
        defaults.set(data, forKey: Self.liveKey)
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Self.historyKey)
    }

    private static func loadLive(from defaults: UserDefaults) -> WorkoutSession? {
        guard let data = defaults.data(forKey: liveKey) else { return nil }
        return try? JSONDecoder().decode(WorkoutSession.self, from: data)
    }

    private static func loadHistory(from defaults: UserDefaults) -> [WorkoutSession] {
        guard let data = defaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data)
        else { return [] }
        return decoded.sorted { $0.date > $1.date }
    }
}
