import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Haptic and audible feedback.
///
/// The rest timer is the one place in this app where feedback is the point
/// rather than a nicety: the value of a timer mid-set is that it reaches you
/// when you are not looking at the screen.
///
/// Note that the simulator has no haptic engine, so the haptics below are
/// silent no-ops there and can only be judged on a device. The sound is the
/// part that can be checked in the simulator.
@MainActor
public enum Feedback {
    /// The buzzer: chime plus haptic, on the running→finished edge.
    @discardableResult
    public static func restFinished(onSound: (@MainActor @Sendable (Bool) -> Void)? = nil) -> Bool {
        Chime.shared.play(completion: onSound)

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
        return true
    }

    /// The chime alone, for callers that are handling the haptic themselves.
    public static func chime(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        Chime.shared.play(completion: completion)
    }

    /// Opens the audio route ahead of time, for a sound with a known deadline.
    ///
    /// The watch will not activate an audio session synchronously — it has to
    /// decide where the sound is going, speaker or headphones, and that takes
    /// long enough to matter. Doing it at the deadline means the chime waits on
    /// a route that is still being chosen, which is the wrong moment to start
    /// asking. The rest timer knows minutes in advance that it will want this,
    /// so it says so, and the phone has always done the same thing through
    /// `RestChime`.
    ///
    /// Safe to call more than once; an already-open route is left alone.
    public static func prepareChime() {
        Chime.shared.prepare()
    }

    /// A light tick for starting, pausing and preset taps. Silent on purpose —
    /// a sound on every tap would be intolerable.
    public static func control() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
}

#if canImport(AVFoundation)
/// Plays the completion chime.
///
/// Held as a single prepared instance rather than built on demand: constructing
/// an `AVAudioPlayer` takes long enough to be audible as a delay, and the whole
/// point is that the sound lands on the beat the timer hits zero.
@MainActor
private final class Chime {
    static let shared = Chime()

    private var player: AVAudioPlayer?

    /// Whether the audio session is open and the route decided.
    private var isRouted = false

    private init() {
        guard let url = Bundle.module.url(forResource: "rest-complete", withExtension: "wav") else {
            return
        }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.prepareToPlay()
    }

    /// Plays, and says whether it managed to.
    ///
    /// The answer matters: the rest timer decides whether it still needs the
    /// notification to alert you, and "I made a sound" is the only honest basis
    /// for that. Silently failing and assuming success is how a rest ends with
    /// nothing at all.
    func play(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard let player else {
            RestTrace.note("chime: no player — resource missing?")
            completion?(false)
            return
        }

        #if os(watchOS)
        // The route is usually already open — `prepare()` is called when the
        // rest starts. If it is, play immediately; the whole point of opening
        // it early is that the deadline is not the moment to be negotiating
        // with the audio system.
        if isRouted {
            player.currentTime = 0
            let played = player.play()
            RestTrace.note("chime: route open, play()=\(played) vol=\(player.volume) dur=\(player.duration)")
            completion?(played)
            return
        }

        RestTrace.note("chime: route not open, opening now")
        openRoute { [weak self] opened in
            guard opened, let self, let player = self.player else {
                RestTrace.note("chime: route refused, nothing played")
                completion?(false)
                return
            }
            player.currentTime = 0
            let played = player.play()
            RestTrace.note("chime: late route, play()=\(played)")
            completion?(played)
        }
        #else
        configureSession()
        player.currentTime = 0
        completion?(player.play())
        #endif
    }

    /// Opens the session, and remembers that it is open.
    ///
    /// `.playback` on the watch too, and deliberately without `.duckOthers`:
    /// the option is an iPhone nicety about somebody's podcast, and on a watch
    /// it is one more thing for the activation to refuse over.
    #if os(watchOS)
    func prepare() {
        guard !isRouted else {
            RestTrace.note("prepare: already routed")
            return
        }
        RestTrace.note("prepare: opening audio route")
        openRoute { _ in }
    }

    private func openRoute(_ done: @escaping @MainActor @Sendable (Bool) -> Void) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)

        // watchOS answers asynchronously, and `setActive(true)` simply throws
        // here. That throw used to be swallowed by a `try?`, so the chime was
        // mute for as long as there had been one: the player was told to play
        // into a session that was never live.
        session.activate(options: []) { activated, error in
            let complaint = error.map { String(describing: $0) } ?? "none"
            Task { @MainActor in
                RestTrace.note("openRoute: activated=\(activated) error=\(complaint) route=\(session.currentRoute.outputs.map(\.portType.rawValue))")
                Chime.shared.isRouted = activated
                done(activated)
            }
        }
    }
    #else
    func prepare() {}
    #endif

    /// `.playback` so the chime is still heard with the ring switch set to
    /// silent, which is how a phone sits in a gym bag. `.duckOthers` drops the
    /// user's music for the length of the chime instead of stopping it.
    ///
    /// There is no audio session to configure on macOS, where the app makes
    /// noise without asking anyone.
    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.duckOthers])
        try? session.setActive(true, options: [])
        #endif
    }
}
#else
@MainActor
private final class Chime {
    static let shared = Chime()
    func play(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) { completion?(false) }
}
#endif
