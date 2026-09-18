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
            completion?(false)
            return
        }

        #if os(watchOS)
        // watchOS will not activate an audio session synchronously. It has to
        // route the audio first — to the speaker, or to whatever headphones are
        // connected — and that is asynchronous, which is why `activate` takes a
        // completion handler and `setActive(true)` simply throws here. The
        // throw was being swallowed by a `try?`, so the chime had been mute on
        // the watch for as long as there has been one: the player was told to
        // play into a session that was never live.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        session.activate(options: []) { activated, _ in
            Task { @MainActor in
                guard activated else {
                    completion?(false)
                    return
                }
                player.currentTime = 0
                completion?(player.play())
            }
        }
        #else
        configureSession()
        player.currentTime = 0
        completion?(player.play())
        #endif
    }

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
