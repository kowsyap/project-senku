import Foundation
import Testing
@testable import SenkuUI

/// Which screen each reminder belongs to.
///
/// Worth pinning: the identifiers are built in four different files, and a
/// prefix changed in one of them would silently stop routing rather than fail
/// anywhere visible.
@Suite struct ReminderRouteTests {
    @Test func waterRemindersGoToWater() {
        #expect(ReminderRoute.from(identifier: "senku.water.reminder.0") == .water)
        #expect(ReminderRoute.from(identifier: "senku.water.reminder.7") == .water)
    }

    /// Creatine is logged, configured and reported on the water screen, so its
    /// reminder lands there rather than anywhere of its own.
    @Test func creatineGoesToWater() {
        #expect(ReminderRoute.from(identifier: "senku.creatine.reminder") == .water)
    }

    @Test func theWeighInReminderGoesToWeight() {
        #expect(ReminderRoute.from(identifier: "senku.weight.reminder") == .weight)
    }

    @Test func aFinishedRestGoesToRest() {
        #expect(ReminderRoute.from(identifier: "senku.rest.finished") == .rest)
    }

    /// Anything unrecognised routes nowhere rather than guessing — opening the
    /// app where it was left is a better failure than opening the wrong page.
    @Test func anythingElseRoutesNowhere() {
        #expect(ReminderRoute.from(identifier: "senku.something.else") == nil)
        #expect(ReminderRoute.from(identifier: "") == nil)
    }
}
