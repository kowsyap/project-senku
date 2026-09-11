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
    public static func restFinished() {
        Chime.shared.play()

        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
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

    func play() {
        guard let player else { return }
        configureSession()
        player.currentTime = 0
        player.play()
    }

    /// `.playback` so the chime is still heard with the ring switch set to
    /// silent, which is how a phone sits in a gym bag. `.duckOthers` drops the
    /// user's music for the length of the chime instead of stopping it.
    ///
    /// There is no audio session to configure on macOS, where the app makes
    /// noise without asking anyone.
    private func configureSession() {
        #if os(iOS) || os(watchOS)
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
    func play() {}
}
#endif
