# Architecture

## Target layout

```
Senku.xcworkspace
├── SenkuCore/                  Swift package — pure logic, no UI, no platform APIs
│   ├── Models/                 BodyMetrics, Goal, ActivityLevel, Sex, Advisory, NutritionPlan
│   ├── Calculations/           BMRFormula, EnergyProfile, MacroTargets
│   └── SenkuCLI/               Dependency-free command line front end
│
├── Senku (iOS)                 iPhone + iPad. Mac Catalyst enabled.
├── Senku Watch                 watchOS app
├── SenkuWidgets                Widget + Live Activity extension
└── SenkuUI/                    Swift package — shared SwiftUI components
```

`SenkuCore` imports only `Foundation`. That constraint is what lets the same
tested arithmetic run unchanged on all three platforms, and it is worth
defending in review.

## Why Mac Catalyst rather than a separate macOS target

Catalyst is a checkbox on the iOS target and gets a working Mac app immediately.
A native macOS target would look more at home but costs a separate UI layer.

Start with Catalyst. Revisit only if the Mac app becomes a primary surface —
for planning diet phases and reviewing history on a big screen, which is the
plausible reason it would.

## Code sharing, realistically

| Layer | iPhone | Mac | Watch |
|---|---|---|---|
| `SenkuCore` | 100% | 100% | 100% |
| View models | 100% | 100% | ~80% |
| SwiftUI views | 100% | ~95% via Catalyst | ~30% |

The watch is the honest exception. Its UI is a rewrite, not a port — a 40 mm
screen used for three seconds between sets has nothing in common with a phone
screen used for three minutes. Plan for it rather than fighting it.

## Data and sync

- **SwiftData** for local persistence (profile, workout log, weight history).
- **CloudKit** via SwiftData's built-in sync for iPhone ↔ Mac.
- **WatchConnectivity** for the Watch, which needs live session state rather than
  eventual consistency — a rest timer that syncs "eventually" is a broken rest
  timer.

Guest mode writes nothing. That is enforced by never constructing a
`ModelContext` on the guest path, not by remembering to delete afterwards.

## Testing

Two layers, deliberately:

- **`SenkuCoreTests`** — the XCTest suite. Requires Xcode.
- **`senku verify`** — 61 dependency-free assertions in the CLI target. Runs with
  Command Line Tools alone, and in CI without an Xcode toolchain.

The overlap is intentional. The core's arithmetic is the part of this app that
must not silently break, and it should stay checkable on any machine.

Once Xcode is installed, `SenkuCoreTests` can migrate from XCTest to Swift
Testing (`@Test` / `#expect`), which ships with Xcode 16+.

## Adding the app targets

Once Xcode is installed:

1. New Xcode project → Multiplatform → App, named `Senku`, in this directory.
2. Add the local package: File → Add Package Dependencies → Add Local →
   select `SenkuCore/`.
3. Target `Senku` → General → check **Mac (Designed for iPad)** or enable Mac
   Catalyst under Supported Destinations.
4. File → New → Target → watchOS → App, named `Senku Watch`.
5. File → New → Target → Widget Extension, named `SenkuWidgets`, with
   **Include Live Activity** checked.
6. Add `SenkuCore` to the "Frameworks and Libraries" of every target.
