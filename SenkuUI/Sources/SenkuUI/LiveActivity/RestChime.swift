#if os(iOS)
import Foundation
import AVFoundation
import SenkuCore

/// Sounds the end of a rest on the phone, with the app off screen.
///
/// ## Why the notification is not enough
///
/// The scheduled notification already carries the chime as its sound, and that
/// works — until the ring switch is set to silent, which is where a phone lives
/// during a workout. Notification sounds obey that switch. Audio an app plays
/// through a `.playback` session does not, which is why the in-app chime has
/// always been audible on a silenced phone and the notification has not.
///
/// ## How it keeps the chime alive
///
/// iOS suspends an app a few seconds after it leaves the screen, and a
/// suspended app plays nothing. The exception is an app that is *currently
/// playing audio* with the `audio` background mode declared — so that is what
/// this does: from the moment a rest starts it plays silence on a loop, and the
/// chime is scheduled on the same session to fire at the deadline.
///
/// That is a real cost and worth naming: the audio session stays active for the
/// length of the rest, which is minutes, and it ducks other audio when the
/// chime lands. It is started only while a rest is actually running and torn
/// down the moment one is not — an idle session earns none of this.
///
/// The notification stays scheduled either way. If iOS takes the session back,
/// or the app is force quit, the alert still arrives; this only makes it louder
/// in the case that matters.
@MainActor
public enum RestChime {
    private static var silence: AVAudioPlayer?
    private static var chime: AVAudioPlayer?

    /// When the chime can be expected to have finished sounding.
    ///
    /// Held because the chime is booked on the audio clock rather than played
    /// on the spot, so at the moment the rest ends it may be a few milliseconds
    /// from starting rather than already playing — and `isPlaying` would say
    /// no. See ``finish()``, which is what needs the answer.
    private static var chimeEndsAt: Date?

    /// Gives the audio session back once the chime has rung out.
    private static var release: Task<Void, Never>?

    /// Starts holding the session, and books the chime for the deadline.
    public static func schedule(at deadline: Date) {
        let delay = deadline.timeIntervalSinceNow
        guard delay > 0 else { return }

        guard let url = Bundle.module.url(forResource: "rest-complete", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url)
        else { return }

        activate()
        holdSession()

        player.prepareToPlay()
        // `deviceCurrentTime` is the audio clock, which is the one that matters
        // here: scheduling against it survives the app being suspended in a way
        // a `Timer` does not.
        player.play(atTime: player.deviceCurrentTime + delay)
        chime = player
        chimeEndsAt = deadline.addingTimeInterval(player.duration)

        release?.cancel()
        release = nil
    }

    /// The rest reached its deadline: let the chime ring out, then let go.
    ///
    /// ## The bug this exists for
    ///
    /// Everything used to route through ``cancel()``, and a rest ending is one
    /// of the things that reaches it — `refresh(at:)` moves the timer to
    /// `.finished`, the view reports the change, and `sync` saw a timer that was
    /// no longer running. So the chime was stopped at the exact instant it was
    /// scheduled to start, and what you heard was the first fraction of it
    /// before silence. The alert was correct, the sound was cut off.
    ///
    /// A finished rest is not a cancelled one. The hold on the session goes
    /// immediately — the chime is itself audio, so it keeps the app alive for
    /// as long as it needs — and the session is handed back once it can have
    /// finished sounding.
    private static func finish() {
        silence?.stop()
        silence = nil

        guard let chimeEndsAt else {
            deactivate()
            return
        }

        let left = max(0, chimeEndsAt.timeIntervalSinceNow)
        release?.cancel()
        release = Task { @MainActor in
            // A little past the end, because the audio clock and the wall clock
            // are not the same clock and cutting the tail is the bug above.
            try? await Task.sleep(for: .seconds(left + 0.25))
            guard !Task.isCancelled else { return }
            cancel()
        }
    }

    /// Stops the chime wherever it has got to and gives the session back.
    ///
    /// This is the *cancelled* case — the rest was stopped, reset or replaced.
    /// A rest that simply ended goes through ``finish()`` instead, so that the
    /// sound it just started is allowed to complete.
    public static func cancel() {
        release?.cancel()
        release = nil

        chime?.stop()
        chime = nil
        chimeEndsAt = nil
        silence?.stop()
        silence = nil

        deactivate()
    }

    /// Mirrors the timer, from the one place every change passes through.
    ///
    /// The decision is `RestChimeAction`, which lives apart from this so it can
    /// be tested without an audio session.
    public static func sync(with timer: RestTimer, at now: Date = .now) {
        switch RestChimeAction(for: timer, at: now) {
        case .schedule(let deadline): schedule(at: deadline)
        case .ringOut: finish()
        case .stop: cancel()
        }
    }

    private static func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private static func activate() {
        let session = AVAudioSession.sharedInstance()
        // `.playback` is what makes this audible on a silenced phone;
        // `.duckOthers` drops a podcast for the length of the chime rather than
        // stopping it.
        try? session.setCategory(.playback, mode: .default, options: [.duckOthers])
        try? session.setActive(true)
    }

    /// A loop of silence, which is what keeps the app running to the deadline.
    private static func holdSession() {
        guard silence == nil else { return }
        guard let player = try? AVAudioPlayer(data: silentWAV()) else { return }

        player.numberOfLoops = -1
        player.volume = 0
        player.play()
        silence = player
    }

    /// Half a second of nothing, built rather than bundled: it is 44 bytes of
    /// header and a few thousand zeroes, and an asset for that is an asset to
    /// keep track of.
    private static func silentWAV() -> Data {
        let sampleRate = 8000
        let samples = sampleRate / 2
        let dataBytes = samples * 2

        var data = Data()
        func append(_ string: String) { data.append(contentsOf: string.utf8) }
        func append32(_ value: Int) { withUnsafeBytes(of: UInt32(value).littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: Int) { withUnsafeBytes(of: UInt16(value).littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF")
        append32(36 + dataBytes)
        append("WAVE")
        append("fmt ")
        append32(16)            // PCM header length
        append16(1)             // PCM
        append16(1)             // mono
        append32(sampleRate)
        append32(sampleRate * 2)  // byte rate
        append16(2)             // block align
        append16(16)            // bits per sample
        append("data")
        append32(dataBytes)
        data.append(Data(count: dataBytes))

        return data
    }
}
#endif
