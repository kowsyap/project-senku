# Project overview

## Summary

Senku is a training and nutrition tracker for iPhone and Apple Watch. It
computes an evidence-based calorie and macro plan from a user profile, then
tracks training, body weight, water and food against that plan. Every derived
figure is attributed: the formula that produced it is named on screen, and
measured inputs are kept distinct from estimated ones.

## Goals

1. Produce a complete nutrition plan — energy, macros, fibre, water — from a
   profile, with the method named and unsafe targets refused.
2. Track training in enough detail to maintain personal records automatically.
3. Track intake and body weight well enough to replace the formula's estimate
   with one measured from the user's own data.
4. Keep the common actions to one tap, on the phone, the Home Screen or the
   wrist.
5. Run entirely on-device, with no account and no subscription.

## Non-goals

| Not in scope | Reason |
| --- | --- |
| Social features, feeds, sharing | Single-user application by design |
| A food database | Licensed data; quick-adds cover recurring items |
| Cloud sync | Export and import cover backup and transfer |
| HealthKit integration | Single source of truth for body weight |
| Coaching or automatic plan changes | Every adjustment is user-confirmed |

## Principles

| # | Principle | Consequence in the code |
| --- | --- | --- |
| P1 | Every figure is attributable | A value that cannot be explained is not displayed; `AdaptiveMaintenance` returns `nil` rather than a caveated number |
| P2 | Measured ≠ estimated | Provenance is stored on weigh-ins and personal records and shown in the UI |
| P3 | Absence is not zero | Unlogged days are excluded from streaks and averages |
| P4 | Enter data once | Logged sets produce records; watch entries reach the phone |
| P5 | History is a record | Past entries are not silently rewritten |
| P6 | Safety over silence | Unsafe targets are clamped and the clamp is stated |

## Platforms

| | |
| --- | --- |
| iOS | 26.5 or later |
| watchOS | 26.5 or later |
| Toolchain | Xcode 26, Swift 6 |
| Distribution | Build from source; personal Apple ID is sufficient |

## Scope

| ID | Feature | Status |
| --- | --- | --- |
| F1 | Weight log | Delivered |
| F2 | Personal records | Delivered |
| F3 | Workout and splits | Delivered |
| F4 | Water tracking | Delivered |
| F5 | Protein and macro intake | Delivered |
| F6 | Anime log | Delivered |

Supporting capabilities: rest timer, plate calculator, Home Screen widgets,
Apple Watch app, PDF report, JSON export and import.

## Documents

| Document | Contents |
| --- | --- |
| [REQUIREMENTS.md](REQUIREMENTS.md) | Functional requirements and acceptance criteria |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Structure, storage, sync, testing |
| [ROADMAP.md](ROADMAP.md) | Milestones and backlog |
| [BUILD.md](BUILD.md) | Build, signing and simulator setup |

## Disclaimer

Senku produces estimates from population-level formulas. It is not medical
advice.
