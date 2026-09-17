import Foundation
import AppIntents
import SenkuCore

/// What a watch complication is set to start.
///
/// Defined in the extension rather than in `SenkuUI`, deliberately. A
/// configurable widget is only offered by the system if its intent is present
/// in the extension's own App Intents metadata, and an intent that lives in a
/// package is a cross-module dependency for that extraction to get right. The
/// gallery's way of reporting that it did not is to show nothing at all.
///
/// The complication is configurable rather than fixed because a rest interval
/// is personal — the point of putting one on a watch face is that *your*
/// interval is one press away, not that some default is. The parameter is in
/// whole minutes: a face has room for one number, and a complication set to
/// 1:45 would show something it cannot render legibly.
struct RestComplicationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Rest interval"
    static let description = IntentDescription(
        "Choose how long a press starts a rest for."
    )

    @Parameter(title: "Minutes", default: 2, inclusiveRange: (1, 10))
    var minutes: Int

    init() {}

    init(minutes: Int) {
        self.minutes = minutes
    }

    /// Clamped rather than trusted: a configuration is stored by the system and
    /// can come back from an older build, or from a face set up before the
    /// range was what it is now.
    var seconds: TimeInterval {
        let clamped = min(max(minutes, 1), 10)
        return TimeInterval(clamped * 60)
    }
}
