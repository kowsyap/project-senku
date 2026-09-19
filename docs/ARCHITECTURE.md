# Architecture

## The shape of it

Two Swift packages and a thin Xcode project. Everything that can be tested
without a screen lives in the packages; the project exists to produce the app,
the widgets and the watch app from them.

```
senku/
├── SenkuCore/                   the arithmetic and the models — no SwiftUI
│   └── Sources/
│       ├── SenkuCore/
│       │   ├── Calculations/    BMR, macros, coverage, streaks, adaptive TDEE
│       │   ├── Models/          the nouns: WeighIn, Exercise, WorkoutSession…
│       │   └── Resources/       ExerciseCatalogue.json — 138 exercises
│       └── SenkuCLI/            `senku plan …` — the maths without an app
├── SenkuUI/                     every screen, and the state behind them
│   └── Sources/SenkuUI/
│       ├── Calculations/        PlateMath — needs the unit types, so it lives here
│       ├── Components/          Card, rings, numeric field, the tab bar
│       ├── Formatting/          units, and how each figure is written
│       ├── LiveActivity/        notifications, reminders, chime, App Intents
│       ├── Reports/             the PDF: layout, charts, section picker
│       ├── Screens/             one file per screen, phone and watch
│       ├── State/               the stores, the importer, the sync
│       └── Theme/               palette and metrics
└── Senku/                       the Xcode project
    ├── Senku/                   app entry point, sample data
    ├── SenkuWidgets/            Home Screen widgets, Live Activity, Control
    ├── SenkuWatch/              watch app entry point
    ├── SenkuTests/              what can only be checked inside the app bundle
    └── SenkuUITests/            launches the app and drives it
```

### Why the split

`SenkuCore` has no UI framework in it at all, which is what makes 171 tests run
in about a hundredth of a second on the host. `SenkuUI` holds the screens *and*
the stores, because a store is a view's state and separating them would be a
third package for no gain.

The Xcode project is deliberately thin: it wires targets to packages, carries
entitlements and Info.plist keys, and contains a few dozen lines of Swift.
Anything with logic in it belongs in a package where it can be tested.

## Where data lives

One App Group — `group.pk.Senku` — holding JSON blobs under versioned keys, read
and written through `UserDefaults`. `SenkuStorage.shared` is the single handle,
and falls back to `.standard` where the entitlement is absent (previews, tests).

That choice is doing real work: the widgets and the app are separate processes,
and the App Group is what lets a tap on a widget and a tap in the app be the same
drink of water. It also set the hardest bug of the project — see below.

Each feature owns a store, and they all look the same:

```swift
@Observable final class WaterStore {
    func reload()                  // re-read from the container
    func add(millilitres: …)       // reload, mutate, persist, reload widgets
}
```

**Every mutation re-reads first.** A widget writes into the same array from its
own process; a store that kept its launch-time copy would both miss those writes
and overwrite them on the next one. This was a real bug — twice. Water and food
first, from the widgets; then the weight log, from the watch, where `PhoneSync`
writes a weigh-in during a background launch with no screen to tell. The rule
now exists in `WaterStore`, `IntakeStore` and `WeightLogStore`, and the app
re-reads all three when it comes forward.

## How the pieces talk

```
                  ┌────────────┐
   widgets ──────▶│ App Group  │◀────── app
  (own process)   │  (JSON)    │
                  └────────────┘
                         ▲
                         │  read fresh on every publish
                  ┌──────┴───────┐
                  │  PhoneSync   │  starts at app launch, not on screen
                  └──────┬───────┘
                         │  WatchConnectivity: application context (state)
                         │                     messages / transfers (records)
                  ┌──────▼───────┐
                  │  watch app   │  holds a summary, keeps no history
                  └──────────────┘
```

**The phone owns the log.** The watch holds a `WeightSummary`, `WaterSummary` or
`IntakeSummary` plus whatever it has logged since, and sends each new record over
as a value with its own id. That avoids two devices holding a list and disagreeing
about it, which is the one genuinely hard problem in syncing.

`PhoneSync.start()` runs from `SenkuApp.init` — *before any scene exists* —
because the watch can wake the phone in the background, where no view ever
appears. Everything it answers with is read from storage rather than from what a
screen happens to be holding.

## Notifications, and the budget

iOS keeps the **64 soonest pending requests** and silently drops the rest, so the
app is deliberate about what it books:

| What | Requests |
| --- | --- |
| Water reminders | up to 12 repeating slots |
| Weigh-in reminder | 1 repeating |
| Creatine reminder | 1 repeating |
| Rest timer | 1, only while a rest is running |

Fifteen of sixty-four, worst case. `RestAlertPresenter` is the
`UNUserNotificationCenterDelegate`, installed at launch, and is what makes an
alert appear while the app is on screen and lets "Log a glass" run in the
background without opening the app.

## The phone's shell

Not a `TabView`. Five or six screens sit in a floating glass bar you can drag a
finger along; the rest live under "More", and which are which is yours to choose
(`TabLayout`, `TabBarEditor`). Every page stays mounted so leaving a tab and
coming back is a return rather than a restart — which is why screens that act on
appearing read `senkuScreenIsVisible` and wait their turn.

The bar is a custom control for one reason: the system gives an iPhone five slots
and buries the rest in a list nobody visits. `SenkuTabBar`'s doc comment carries
the full history, including the two designs that were tried and removed.

## Testing

| Suite | Runs on | What it covers |
| --- | --- | --- |
| `SenkuCore/Tests` | host, `swift test` | every calculation and model rule |
| `SenkuUI/Tests` | host, `swift test` | stores, importer, plate maths, tab layout, the sample file |
| `Senku/SenkuTests` | simulator/device | the app bundle: catalogue resource, App Group |
| `Senku/SenkuUITests` | simulator/device | launches the app and drives the rest timer and calculator |

The packages declare `.macOS(.v14)` **only so `swift test` can run on the host**.
There is no Mac app: the `#if !os(macOS)` guards around notifications exist to
keep that host build compiling, not to support a Mac.

## Conventions worth knowing before editing

- **Comments explain why.** Especially where the obvious approach was tried and
  failed — the tab bar, the rest alerts, the widget's stale array.
- **Models validate in `init` and throw.** `WeighIn`, `IntakeEntry`,
  `WaterEntry` refuse impossible values rather than storing them.
- **Formatting lives in `Display`.** Including the rule that water is always
  millilitres, whatever the profile says, because nobody fills a bottle in fluid
  ounces. There is deliberately no fluid-ounce formatter.
- **Debug-only hooks are named and documented**: `SENKU_SAMPLE` loads the sample
  data through the real importer, `SENKU_SCREEN` opens the app on one screen for
  screenshots. Both are `#if DEBUG`.
