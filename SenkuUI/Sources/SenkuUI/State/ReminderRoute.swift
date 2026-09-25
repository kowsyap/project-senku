#if !os(watchOS)
import Foundation

/// Where a tapped reminder should land.
///
/// ## Why this exists
///
/// Every reminder this app sends is about a particular screen — a glass of
/// water, a weigh-in, a rest that has finished — and tapping one used to open
/// the app wherever it was last left. That is the worst of both: the tap
/// implies an errand, and then you have to go and find the page yourself.
///
/// The routing was already written for the widgets, which open `senku://water`
/// and friends. What was missing was anything connecting a notification to it,
/// so this names the destinations and ``RestAlertPresenter`` posts one when a
/// notification is tapped.
public enum ReminderRoute: String, Sendable {
    case water
    case weight
    case rest

    /// Posted when a reminder has been tapped, carrying the destination in
    /// `object`. Mirrors ``RestDeepLink/didStart``: a running screen hears it
    /// immediately rather than waiting to reappear.
    public static let didTap = Notification.Name("senku.reminder.didTap")

    /// The destination for a delivered notification, by its identifier.
    ///
    /// Matched on the identifier rather than the category because only water
    /// has a category — it is the one with an action button — and the others
    /// would need one invented purely to be recognised here.
    public static func from(identifier: String) -> ReminderRoute? {
        // Creatine is a water-screen habit: it is logged, settable and
        // reported there, so its reminder belongs on the same page rather
        // than somewhere of its own.
        if identifier == "senku.creatine.reminder" { return .water }
        if identifier.hasPrefix("senku.water.reminder.") { return .water }
        if identifier == "senku.weight.reminder" { return .weight }
        if identifier.hasPrefix("senku.rest.") { return .rest }
        return nil
    }

    public func post() {
        NotificationCenter.default.post(name: Self.didTap, object: self)
    }
}
#endif
