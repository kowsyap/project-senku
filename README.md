# Senku

A science-based training and nutrition companion for **iPhone, Mac and Apple
Watch** — one that shows its work.

Most macro calculators hand you a number and no explanation. Senku names the
formula it used, distinguishes what you measured from what it estimated, and
tells you when a target is a bad idea for you specifically.

## Status

Early. The calculation core is built and verified; the apps are not started yet.

| Component | State |
|---|---|
| `SenkuCore` — energy and macro engine | ✅ 64 checks + 33 tests passing |
| `SenkuUI` — SwiftUI screens | ✅ Builds for iOS, macOS and watchOS |
| `senku` CLI, `senku-render` | ✅ Working |
| Xcode app project | ⬜ [One-time manual setup](docs/XCODE_SETUP.md) |

## What the core does

Give it sex, age, height, weight, activity level and a goal, and it returns:

- BMR and resting metabolic rate, via Mifflin-St Jeor, Katch-McArdle or
  Harris-Benedict
- Maintenance calories at all five activity levels
- A calorie target for the goal, floored at a medically safe minimum
- Protein, carbs, fat, fiber and water targets
- BMI, lean mass, fat mass, healthy weight range
- Projected weekly change and time to a target weight
- Advisories when the plan deserves a caveat

## Try it

Requires Swift 6.0+. Xcode is **not** needed for the core.

```sh
cd SenkuCore

# Run the verification suite
swift run senku verify

# Calculate a plan
swift run senku plan --sex male --age 30 --height 180 --weight 80 \
                     --activity moderate --goal moderateCut

# All options
swift run senku --help
```

```
TARGET  (Moderate cut)
  ──────────────────────────────
  Maintenance               2759 kcal
  Daily target              2207 kcal
  Delta                     -552 kcal/day
  Projected change          -0.50 kg/week

MACROS
  ──────────────
  Protein                   176 g  (32%)
  Carbs                     254 g  (46%)
  Fat                       54 g  (22%)
  Fiber                     31 g
  Water                     2800 ml  (+500 training days)
```

## Testing

```sh
cd SenkuCore
swift run senku verify   # 64 checks, no Xcode required
swift test               # 33 XCTest cases, requires Xcode

cd ../SenkuUI
swift build                                                    # macOS
xcodebuild -scheme SenkuUI -destination 'generic/platform=iOS' build
xcodebuild -scheme SenkuUI -destination 'generic/platform=watchOS' build
swift run senku-render /tmp/senku-shots                        # screens as PNG
```

`senku verify` exists because XCTest ships inside Xcode rather than Command Line
Tools — the arithmetic stays checkable on any machine, and in CI without an
Xcode toolchain.

## Documentation

- [Project definition](docs/PROJECT.md) — the idea, the feature set, what is out of scope
- [Xcode setup](docs/XCODE_SETUP.md) — one-time steps to create the app project
- [Architecture](docs/ARCHITECTURE.md) — targets, code sharing, data and sync
- [Roadmap](docs/ROADMAP.md) — phased plan

## Disclaimer

Senku produces estimates from population-level formulas. It is not medical
advice. Talk to a doctor before starting an aggressive deficit.
