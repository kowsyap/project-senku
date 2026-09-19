import Foundation
import SenkuCore

// WatchConnectivity exists only on the two platforms that have a counterpart.
// Mac Catalyst reports `os(iOS)` and has no watch to talk to.
#if os(iOS) || os(watchOS)
import WatchConnectivity

/// Carries the profile from the phone to the watch.
///
/// ## Why WatchConnectivity and not iCloud
///
/// iCloud would be the better mechanism — it would cover a second phone, a Mac,
/// and a watch that has not seen its companion in a week. It is also refused
/// outright by a personal development team ("Personal development teams do not
/// support the iCloud capability"), so it is not available to this build at any
/// price below the paid membership.
///
/// WatchConnectivity needs no entitlement, and for the case that actually
/// matters — the two devices on the same body — it is better: an application
/// context arrives in moments rather than minutes.
///
/// ## Why `updateApplicationContext`
///
/// The profile is one small value where only the newest matters. That is
/// precisely what an application context is: the system keeps the latest one,
/// replaces it if a newer arrives before delivery, and hands it over when the
/// counterpart next runs. A message queue would preserve a history of profile
/// edits nobody wants; `sendMessage` would require the watch to be awake and
/// reachable at the moment of saving, which is not a condition the phone should
/// have to meet to save your own numbers.
///
/// ## What travels, and what does not
///
/// The profile goes phone to watch, and weigh-ins come back the other way. The
/// **rest timer is deliberately not synced**: it was, briefly, and a mirrored
/// countdown turns out to be the wrong idea — the two devices are for two
/// different moments, and a rest you started on your wrist appearing on a phone
/// in your bag (or worse, a phone tap resetting the watch mid-set) is
/// interference dressed as a feature. Each device runs its own.
public final class ProfileSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    public static let shared = ProfileSync()

    private static let profileKey = "senku.profile"
    private static let weightKey = "senku.weightSummary"
    private static let weighInKey = "senku.weighIn"
    private static let refreshKey = "senku.refresh"
    private static let waterKey = "senku.waterSummary"
    private static let drinkKey = "senku.waterDrink"
    private static let intakeKey = "senku.intakeSummary"
    private static let mealKey = "senku.intakeMeal"

    /// Called on the main actor with whatever the counterpart last had:
    /// a profile, or nil where it has none.
    private var onReceive: (@MainActor (ProfileStore.Profile?) -> Void)?

    /// Held so the phone can re-send on activation, when the watch app may be
    /// starting up with nothing.
    private var latest: ProfileStore.Profile?

    /// Called on the watch with the phone's latest weight figures.
    private var onWeightSummary: (@MainActor (WeightSummary?) -> Void)?

    /// Called on the phone when the watch logs a weigh-in.
    private var onWeighIn: (@MainActor (WeighIn) -> Void)?

    /// The summary the phone last published, re-sent whenever the link comes
    /// back or the watch asks.
    private var latestWeight: WeightSummary?

    /// Called on the watch with the phone's water figures for today.
    private var onWaterSummary: (@MainActor (WaterSummary?) -> Void)?

    /// Called on the phone when the watch logs a drink.
    private var onDrink: (@MainActor (WaterEntry) -> Void)?

    private var latestWater: WaterSummary?

    /// Called on the watch with the phone's food figures for today.
    private var onIntakeSummary: (@MainActor (IntakeSummary?) -> Void)?

    /// Called on the phone when the watch logs food.
    private var onMeal: (@MainActor (IntakeEntry) -> Void)?

    private var latestIntake: IntakeSummary?

    /// Phone side: how to answer "send me what you have".
    ///
    /// Without this a refresh replayed whatever was last held in memory, which
    /// in a background launch — the case a refresh request *creates* — was
    /// nothing at all. See ``PhoneSync``.
    private var onRefreshRequest: (@MainActor () -> Void)?

    /// Records that arrived before anything was listening for them.
    ///
    /// A queued transfer launches the phone app in the background, and the
    /// delivery can land before the screen that registers these handlers has
    /// run its `task`. Without somewhere to put it, that drink is decoded and
    /// dropped — a glass drunk on the watch and never counted, which is the one
    /// failure this whole path exists to prevent. Held here instead, and handed
    /// over the moment a handler appears.
    private var undeliveredDrinks: [WaterEntry] = []
    private var undeliveredWeighIns: [WeighIn] = []
    private var undeliveredMeals: [IntakeEntry] = []

    private override init() { super.init() }

    private var session: WCSession? {
        WCSession.isSupported() ? .default : nil
    }

    /// Watch → phone: "send me what you have."
    ///
    /// The application context is delivered when the system feels like it, and
    /// a profile saved while the watch app was closed can sit unread for longer
    /// than anyone watching the two screens will believe. A message from the
    /// watch wakes the phone app in the background — the one direction that can
    /// — so asking is both possible and immediate.
    public func requestRefresh() {
        #if os(watchOS)
        guard let session, session.activationState == .activated else { return }

        // Not gated on `isReachable`. That flag is false whenever the phone app
        // is not already running, which is most of the time — and a message is
        // precisely what wakes it. Asking and letting it fail costs nothing;
        // refusing to ask because it *might* fail is how a profile saved on the
        // phone stayed invisible on the watch.
        let request = [Self.refreshKey: true]
        session.sendMessage(request, replyHandler: nil) { _ in
            // Out of range or the phone is off. Queue it instead, so the next
            // time the two are together the watch still gets an answer.
            session.transferUserInfo(request)
        }
        #endif
    }

    /// Watch side: what to do when the phone sends its weight figures.
    @MainActor
    public func onWeightSummaryReceived(_ handler: @escaping @MainActor (WeightSummary?) -> Void) {
        onWeightSummary = handler
    }

    /// Watch side: what to do when the phone's water figures arrive.
    @MainActor
    public func onWaterSummaryReceived(_ handler: @escaping @MainActor (WaterSummary?) -> Void) {
        onWaterSummary = handler
    }

    /// Phone side: what to do when the watch logs a drink.
    @MainActor
    public func onDrinkReceived(_ handler: @escaping @MainActor (WaterEntry) -> Void) {
        onDrink = handler

        let waiting = undeliveredDrinks
        undeliveredDrinks = []
        waiting.forEach(handler)
    }

    /// Phone side: what to publish when the watch asks for a refresh.
    @MainActor
    public func onRefreshRequested(_ handler: @escaping @MainActor () -> Void) {
        onRefreshRequest = handler
    }

    /// Watch side: what to do when the phone's food figures arrive.
    @MainActor
    public func onIntakeSummaryReceived(_ handler: @escaping @MainActor (IntakeSummary?) -> Void) {
        onIntakeSummary = handler
    }

    /// Phone side: what to do when the watch logs food.
    @MainActor
    public func onMealReceived(_ handler: @escaping @MainActor (IntakeEntry) -> Void) {
        onMeal = handler

        let waiting = undeliveredMeals
        undeliveredMeals = []
        waiting.forEach(handler)
    }

    public func send(intake summary: IntakeSummary?) {
        latestIntake = summary
        sendIfSender()
    }

    /// Watch → phone. Food is a record like a drink or a weigh-in, and goes the
    /// same way: a message when the phone is awake, a queued transfer when it
    /// is not.
    public func send(meal: IntakeEntry) {
        guard let session,
              session.activationState == .activated,
              let data = try? JSONEncoder().encode(meal)
        else { return }

        let payload = [Self.mealKey: data]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Phone → watch, in the same context as everything else.
    public func send(water summary: WaterSummary?) {
        latestWater = summary
        sendIfSender()
    }

    /// Watch → phone. A drink is a record rather than a state, so it goes the
    /// same way a weigh-in does: a message when the phone is awake, a queued
    /// transfer when it is not. Losing one would be a glass of water that was
    /// drunk and not counted.
    public func send(drink: WaterEntry) {
        guard let session,
              session.activationState == .activated,
              let data = try? JSONEncoder().encode(drink)
        else { return }

        let payload = [Self.drinkKey: data]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Phone side: what to do when the watch logs a weigh-in.
    @MainActor
    public func onWeighInReceived(_ handler: @escaping @MainActor (WeighIn) -> Void) {
        onWeighIn = handler

        let waiting = undeliveredWeighIns
        undeliveredWeighIns = []
        waiting.forEach(handler)
    }

    /// Phone → watch. Rides in the application context beside the profile, so
    /// a watch that was away catches up on both at once when it wakes.
    public func send(weight summary: WeightSummary?) {
        latestWeight = summary
        sendIfSender()
    }

    /// Watch → phone. A weigh-in is a record, not a state, so it goes as a
    /// message when the phone is awake and a queued transfer when it is not —
    /// `transferUserInfo` keeps every one of them in order, which is exactly
    /// right for something that must not be lost or merged.
    public func send(weighIn: WeighIn) {
        guard let session,
              session.activationState == .activated,
              let data = try? JSONEncoder().encode(weighIn)
        else { return }

        let payload = [Self.weighInKey: data]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                // Unreachable after all — the queue is the fallback, because a
                // weigh-in that is merely late is still correct.
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    /// Starts the session and keeps `store` in step with the counterpart.
    ///
    /// Safe to call more than once; activating an active session is a no-op.
    @MainActor
    public func start(applying store: ProfileStore) {
        onReceive = { [weak store] profile in
            guard let store else { return }
            if let profile {
                store.apply(profile)
            } else {
                store.clear(broadcast: false)
            }
        }
        latest = store.profile

        guard let session else { return }
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        } else {
            sendIfSender()
        }
    }

    /// Publishes a profile. Called by ``ProfileStore`` on every save, so no
    /// screen has to remember to.
    public func send(_ profile: ProfileStore.Profile?) {
        latest = profile

        #if os(iOS)
        guard let session, session.activationState == .activated else { return }
        // Nothing to talk to: no watch paired, or Senku not installed on it.
        guard session.isPaired, session.isWatchAppInstalled else { return }

        // A cleared profile is sent as an *empty value under the key*, never as
        // an empty context. The difference is the whole safety of this: absence
        // of the key has to mean "no news", because an empty context is also
        // what a device that has never sent anything looks like.
        var context: [String: Any] = [
            Self.profileKey: (profile.flatMap { try? JSONEncoder().encode($0) }) ?? Data()
        ]
        if let latestWeight, let data = try? JSONEncoder().encode(latestWeight) {
            context[Self.weightKey] = data
        }

        if let latestWater, let data = try? JSONEncoder().encode(latestWater) {
            context[Self.waterKey] = data
        }

        if let latestIntake, let data = try? JSONEncoder().encode(latestIntake) {
            context[Self.intakeKey] = data
        }

        // Throws only when the payload is not property-list encodable, which
        // `Data` always is, or when the session is not activated, which is
        // checked above. Nothing useful to do with the error either way.
        try? session.updateApplicationContext(context)
        #endif
    }

    /// Rebuild from storage if anyone knows how; otherwise re-send what is
    /// held, which is all an older build could do.
    private func answerRefresh() {
        #if os(iOS)
        Task { @MainActor [onRefreshRequest] in
            if let onRefreshRequest {
                onRefreshRequest()
            } else {
                self.sendIfSender()
            }
        }
        #endif
    }

    /// The phone is the only side that publishes.
    private func sendIfSender() {
        #if os(iOS)
        send(latest)
        #endif
    }

    private func receiveMeal(_ payload: [String: Any]) {
        #if os(iOS)
        guard let data = payload[Self.mealKey] as? Data,
              let meal = try? JSONDecoder().decode(IntakeEntry.self, from: data)
        else { return }

        Task { @MainActor in
            if let onMeal {
                onMeal(meal)
            } else {
                undeliveredMeals.append(meal)
            }
        }
        #endif
    }

    private func receiveDrink(_ payload: [String: Any]) {
        #if os(iOS)
        guard let data = payload[Self.drinkKey] as? Data,
              let drink = try? JSONDecoder().decode(WaterEntry.self, from: data)
        else { return }

        Task { @MainActor in
            if let onDrink {
                onDrink(drink)
            } else {
                undeliveredDrinks.append(drink)
            }
        }
        #endif
    }

    private func receiveWeighIn(_ payload: [String: Any]) {
        #if os(iOS)
        guard let data = payload[Self.weighInKey] as? Data,
              let weighIn = try? JSONDecoder().decode(WeighIn.self, from: data)
        else { return }

        Task { @MainActor in
            if let onWeighIn {
                onWeighIn(weighIn)
            } else {
                undeliveredWeighIns.append(weighIn)
            }
        }
        #endif
    }

    /// Applies an incoming profile — on the watch only.
    ///
    /// ## The bug this guard exists for
    ///
    /// Without it, the *phone* also applied what it found in
    /// `receivedApplicationContext` on activation. That context holds whatever
    /// the **counterpart** last sent, and the watch never sends a profile, so
    /// it was always empty — which the old code read as "the profile was
    /// deleted" and duly deleted it. Every cold launch of the phone app wiped
    /// the user's saved profile.
    ///
    /// Two things now prevent it: the phone does not apply incoming profiles at
    /// all, since it owns them, and a context without the key is treated as no
    /// news rather than as a deletion.
    private func receive(_ context: [String: Any]) {
        #if os(watchOS)
        if let weightData = context[Self.weightKey] as? Data,
           let summary = try? JSONDecoder().decode(WeightSummary.self, from: weightData) {
            Task { @MainActor [onWeightSummary] in
                onWeightSummary?(summary)
            }
        }

        if let waterData = context[Self.waterKey] as? Data,
           let summary = try? JSONDecoder().decode(WaterSummary.self, from: waterData) {
            Task { @MainActor [onWaterSummary] in
                onWaterSummary?(summary)
            }
        }

        if let intakeData = context[Self.intakeKey] as? Data,
           let summary = try? JSONDecoder().decode(IntakeSummary.self, from: intakeData) {
            Task { @MainActor [onIntakeSummary] in
                onIntakeSummary?(summary)
            }
        }

        guard let data = context[Self.profileKey] as? Data else { return }

        let profile = data.isEmpty
            ? nil
            : try? JSONDecoder().decode(ProfileStore.Profile.self, from: data)

        Task { @MainActor [onReceive] in
            onReceive?(profile)
        }
        #endif
    }

    // MARK: - WCSessionDelegate

    public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }

        // Whatever the counterpart last sent is waiting in the context on
        // activation, so a watch that was off when the profile changed still
        // catches up the moment it comes back.
        receive(session.receivedApplicationContext)
        #if os(iOS)
        answerRefresh()
        #else
        // Ask, now that asking is possible.
        //
        // The watch requests a refresh as its first screen appears, which is
        // usually *before* activation finishes — and `requestRefresh` quietly
        // does nothing when the session is not activated yet. So the opening
        // request was routinely thrown away, and the watch relied on a later
        // tab change to try again. This is the retry that was missing.
        requestRefresh()
        #endif
    }

    public func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        receive(context)
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        receiveWeighIn(message)
        receiveDrink(message)
        receiveMeal(message)

        #if os(iOS)
        if message[Self.refreshKey] != nil {
            // Re-publishing costs one delivery: an application context replaces
            // whatever was queued rather than adding to it.
            answerRefresh()
        }
        #endif
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        receiveWeighIn(userInfo)
        receiveDrink(userInfo)
        receiveMeal(userInfo)

        #if os(iOS)
        if userInfo[Self.refreshKey] != nil { answerRefresh() }
        #endif
    }

    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Reactivated immediately: this fires when the user switches to a second
    /// watch, and a session left deactivated would silently stop syncing.
    public func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    #if os(iOS)
    /// A newly paired or freshly installed watch has nothing. Push to it.
    public func sessionWatchStateDidChange(_ session: WCSession) {
        answerRefresh()
    }
    #endif

    #if os(watchOS)
    /// The phone came back into range. Whatever changed while the two were
    /// apart is worth asking for now, rather than at the next tab change.
    public func sessionReachabilityDidChange(_ session: WCSession) {
        guard session.isReachable else { return }
        requestRefresh()
    }
    #endif
}
#endif
