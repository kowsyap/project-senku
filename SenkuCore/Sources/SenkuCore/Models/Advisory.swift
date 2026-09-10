import Foundation

/// A note Senku attaches to a plan when the numbers deserve context.
///
/// These exist so the app never silently hands someone a target that is unwise
/// for their situation. They are shown alongside results, not instead of them.
public struct Advisory: Hashable, Sendable, Identifiable {
    public enum Severity: Int, Comparable, Sendable {
        case info
        case caution
        case warning

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public let id: String
    public let severity: Severity
    public let message: String

    public init(id: String, severity: Severity, message: String) {
        self.id = id
        self.severity = severity
        self.message = message
    }
}
