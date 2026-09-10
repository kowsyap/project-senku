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

*Blocked on: installing Xcode*

- [ ] Xcode project with iOS target, Catalyst enabled
- [ ] Input form: sex, age, height, weight, body fat, activity, goal
- [ ] Unit switching (metric ↔ imperial) at the presentation layer only
- [ ] Results screen: energy ladder, macro rings, advisories
- [ ] Guest mode — calculate and discard
- [ ] Saved profile via SwiftData
- [ ] Migrate `SenkuCoreTests` to Swift Testing

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

Install Xcode from the Mac App Store, then Phase 1.
