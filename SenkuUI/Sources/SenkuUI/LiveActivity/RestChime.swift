#if os(iOS) && !targetEnvironment(macCatalyst)
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
    }

    /// Gives the session back. Called whenever a rest stops being a rest.
    public static func cancel() {
        chime?.stop()
        chime = nil
        silence?.stop()
        silence = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Mirrors the timer, from the one place every change passes through.
    public static func sync(with timer: RestTimer, at now: Date = .now) {
        guard timer.isRunning, let endsAt = timer.endsAt, endsAt > now else {
            cancel()
            return
        }
        schedule(at: endsAt)
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
