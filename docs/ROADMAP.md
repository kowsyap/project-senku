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
- [x] Profile tab is a dashboard, not a second copy of the calculator
- [x] Profile persistence via `ProfileStore`
- [x] Offscreen PNG renderer for reviewing layout without a simulator
- [x] Xcode project with packages linked — see [XCODE_SETUP.md](XCODE_SETUP.md)
- [x] Runs on the iOS simulator
- [x] Enable Mac Catalyst
- [ ] Run on a physical device
- [x] Migrate `SenkuCoreTests` to Swift Testing
- [ ] Move `ProfileStore` onto SwiftData once history needs storing

## Phase 2 — Rest timer

- [x] Timer engine with presets and a custom value
- [x] Timer screen: countdown ring, presets, pause/resume, add-30s
- [x] Third tab, reachable in one tap from anywhere
- [x] Live Activity with Dynamic Island
- [x] Home Screen widget
- [x] Control Center control (iOS 18+)
- [x] Watch app with completion haptics
- [x] Local notification so it fires with the screen off

## Phase 3 — Watch and Mac

- [ ] Watch: today's targets at a glance
- [ ] Watch complications
- [ ] WatchConnectivity session sync
- [ ] Mac layout pass — the Catalyst default will not be good enough as-is

## Phase 4 — Logging and trends

Specified in full in [REQUIREMENTS.md](REQUIREMENTS.md), which supersedes this
list: five features, their data models, the rules they have to obey, and the
questions still open.

- [ ] Storage and notification-scheduler foundations (S1, S2)
- [ ] Weight log with reminders and EWMA trend (F1)
- [ ] Exercise catalogue and muscle-coverage maths
- [ ] PR page (F2)
- [ ] Workout page, splits and coverage, with the rest timer auto-starting (F3)
- [ ] Water tracking with rolling reminders (F4)
- [ ] Protein and macro intake (F5)
- [ ] Adaptive TDEE from observed change
- [ ] HealthKit read/write — open question 1

## Phase 5 — Polish and ship

- [ ] Plate calculator, 1RM estimator
- [ ] App Intents / Siri
- [ ] Onboarding
- [ ] Accessibility pass: Dynamic Type, VoiceOver, contrast
- [ ] App Store listing, screenshots, privacy nutrition label

## Immediate next step

Phase 2 is done. All four targets now exist — app, widget extension, watch app,
and the test bundles — so nothing further is blocked on project surgery.

Two things remain from Phase 1, and both need hardware or a decision rather
than code:

- **Run on a physical device.** Everything so far is simulator-verified. The
  haptics in particular *cannot* be checked any other way: the simulator has no
  haptic engine, so `Feedback.restFinished()` is a silent no-op there. The
  signing team is set; the App Group is off by default so a free account can
  build — see [XCODE_SETUP.md](XCODE_SETUP.md).
- **SwiftData.** The roadmap has always said "once history needs storing", and
  nothing stores history yet. `ProfileStore` is still the seam.

After that, Phase 3: the watch layout is a fitting pass, not the rewrite the
architecture doc calls for, and the Mac is still running the iPad layout.
