import Foundation
import Testing
import SenkuCore
@testable import SenkuUI

/// A rest started from logging a set is the Rest tab's own timer, at the
/// interval last used there — which has to outlive the rest it came from.
@MainActor
@Suite struct RestStartTests {
    private func suite() -> UserDefaults {
        UserDefaults(suiteName: "senku.reststart.\(UUID().uuidString)")!
    }

    @Test func theLastIntervalOutlivesTheRest() throws {
        let defaults = suite()
        var rest = try RestTimer(duration: 150)
        rest.start(at: .now)
        RestTimerStore.save(rest, to: defaults)

        RestTimerStore.clear(from: defaults)  // the rest ends, or is reset
        #expect(RestTimerStore.load(from: defaults) == nil)
        #expect(RestTimerStore.lastDuration(from: defaults) == 150)
    }

    @Test func aLoggedSetStartsARestAtThatInterval() throws {
        let defaults = suite()
        var rest = try RestTimer(duration: 120)
        rest.start(at: .now)
        RestTimerStore.save(rest, to: defaults)
        RestTimerStore.clear(from: defaults)

        let started = RestTimerStore.startAtLastInterval(defaults: defaults)
        #expect(started.duration == 120)
        #expect(started.isRunning)
        #expect(RestTimerStore.load(from: defaults)?.duration == 120)
    }

    /// On, at ninety seconds, until changed — and a change sticks.
    @Test func restAfterSetDefaultsOnAndRemembers() {
        let defaults = suite()
        #expect(RestAfterSet.load(from: defaults) == RestAfterSet(isOn: true, seconds: 90))

        RestAfterSet(isOn: false, seconds: 180).save(to: defaults)
        #expect(RestAfterSet.load(from: defaults) == RestAfterSet(isOn: false, seconds: 180))
        #expect(SettingsBackup.keys.contains("senku.restAfterSet.v1"))
    }

    @Test func aRestOfAGivenLengthStarts() {
        let started = RestTimerStore.start(seconds: 180, defaults: suite())
        #expect(started.duration == 180)
        #expect(started.isRunning)
    }

    /// Nothing ever rested for: the usual ninety seconds.
    @Test func withNoHistoryItIsNinetySeconds() {
        let started = RestTimerStore.startAtLastInterval(defaults: suite())
        #expect(started.duration == RestPreset.ninetySeconds.duration)
    }
}
