import Foundation
import os

/// A running account of what the app did when nobody could watch.
///
/// Written for the rest timer, where the end of a rest happens on a device you
/// cannot attach a debugger to, seconds after you have stopped looking at it,
/// and the failure mode is *silence* — which looks identical whether the sound
/// was refused, the route never opened, or the code never ran. It found a crash
/// that had been hiding for months.
///
/// App Intents have exactly the same shape of problem. Siri runs them in a
/// process you did not start, often with no window, and reports success in its
/// own words whether or not anything happened.
///
/// Everything goes to the unified log under `pk.Senku`, and in a debug build to
/// stdout as well, where `devicectl device process launch --console` can read it
/// off a phone or a watch in real time.
enum Trace {
    private static let restLog = Logger(subsystem: "pk.Senku", category: "rest")
    private static let intentLog = Logger(subsystem: "pk.Senku", category: "intent")

    static func rest(_ message: @autoclosure () -> String) {
        emit(restLog, "rest", message())
    }

    static func intent(_ message: @autoclosure () -> String) {
        emit(intentLog, "intent", message())
    }

    private static func emit(_ log: Logger, _ category: String, _ text: String) {
        log.info("\(text, privacy: .public)")
        #if DEBUG
        print("SENKU/\(category) \(text)")
        #endif
    }
}
