# Roadmap

Phases are ordered so that each one ends with something usable, rather than
saving all the value for the end.

## Phase 0 — Foundations ✅

- [x] Git repository
- [x] `SenkuCore` package: models, BMR formulas, energy, macros, advisories
- [x] Input validation with typed errors
- [x] Verification suite — 61 checks, runs without Xcode
- [x] `senku` CLI for exercising the core
- [x] Project, architecture and roadmap docs

## Phase 1 — Calculator that ships

- [x] `SenkuUI` package, building for iOS, macOS and watchOS
- [x] Input form: sex, age, height, weight, body fat, activity, goal, formula
- [x] Unit switching (metric ↔ imperial) at the presentation layer only
- [x] Results screen: macro ring, energy ladder, advisories, body composition
- [x] Adaptive layout — side by side on wide windows, stacked on phones
- [x] Guest mode and saved profile, split across two tabs
- [x] Profile persistence via `ProfileStore`
- [x] Offscreen PNG renderer for reviewing layout without a simulator
- [x] Xcode project with packages linked — see [XCODE_SETUP.md](XCODE_SETUP.md)
- [x] Runs on the iOS simulator
- [ ] Enable Mac Catalyst
- [ ] Run on a physical device
- [ ] Migrate `SenkuCoreTests` to Swift Testing (now that Xcode is installed)
- [ ] Move `ProfileStore` onto SwiftData once history needs storing

## Phase 2 — Rest timer

- [ ] Timer engine with presets and a custom value
- [ ] Live Activity with Dynamic Island
- [ ] Home Screen widget
- [ ] Control Center control (iOS 18+)
- [ ] Watch app with completion haptics
- [ ] Background audio/notification so it fires with the screen off

## Phase 3 — Watch and Mac

- [ ] Watch: today's targets at a glance
- [ ] Watch complications
- [ ] WatchConnectivity session sync
- [ ] Mac layout pass — the Catalyst default will not be good enough as-is

## Phase 4 — Logging and trends

- [ ] Workout logger, with the rest timer auto-starting on a logged set
- [ ] Weight history with EWMA trend line
- [ ] Adaptive TDEE from observed change
- [ ] HealthKit read/write

## Phase 5 — Polish and ship

- [ ] Plate calculator, 1RM estimator
- [ ] App Intents / Siri
- [ ] Onboarding
- [ ] Accessibility pass: Dynamic Type, VoiceOver, contrast
- [ ] App Store listing, screenshots, privacy nutrition label

## Immediate next step

Enable Mac Catalyst and add the watch target — both in
[XCODE_SETUP.md](XCODE_SETUP.md). After that, Phase 2.
