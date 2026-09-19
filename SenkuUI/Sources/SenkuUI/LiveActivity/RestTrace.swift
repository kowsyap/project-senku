import Foundation
import os

/// A running account of what the rest timer's alert actually did.
///
/// The end of a rest happens on a device you cannot attach a debugger to, in
/// the two seconds after you have stopped looking at it, and the failure mode
/// is *silence* — which looks identical whether the sound was refused, the
/// route was never opened, or the code that plays it never ran at all.
///
/// So it says so. Everything goes to the unified log under `senku.rest`, and in
/// a debug build to stdout as well, where `devicectl device process launch
/// --console` can read it off a watch in real time.
enum RestTrace {
    private static let log = Logger(subsystem: "pk.Senku", category: "rest")

    static func note(_ message: @autoclosure () -> String) {
        let text = message()
        log.info("\(text, privacy: .public)")
        #if DEBUG
        print("SENKU/rest \(text)")
        #endif
    }
}
