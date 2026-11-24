# Architecture

## Overview

Two Swift packages hold all logic and UI. A thin Xcode project assembles them
into four bundles.

| Bundle | Identifier | Contents |
| --- | --- | --- |
| Senku | `pk.Senku` | iPhone app |
| SenkuWidgets | `pk.Senku.SenkuWidgets` | Home Screen widgets, Live Activity, Control Center |
| SenkuWatch | `pk.Senku.watchkitapp` | watch app |
| SenkuWatchWidgets | `pk.Senku.watchkitapp.widgets` | rest timer complication |

## Repository layout

```
senku/
├── SenkuCore/                   calculations and models — no UI framework
│   └── Sources/
│       ├── SenkuCore/
│       │   ├── Calculations/    BMR, macros, coverage, streaks, adaptive TDEE
│       │   ├── Models/          WeighIn, Exercise, WorkoutSession, Intake…
│       │   └── Resources/       ExerciseCatalogue.json — 162 exercises
│       └── SenkuCLI/            `senku plan …`
├── SenkuUI/                     screens and state
│   ├── Sources/SenkuUI/
│   │   ├── Calculations/        PlateMath
│   │   ├── Components/          cards, rings, numeric field, tab bar
│   │   ├── Formatting/          units and display rules
│   │   ├── Intelligence/        reading food: Vision, on-device model, Gemini
│   │   ├── LiveActivity/        notifications, reminders, chime, App Intents
│   │   ├── PlanSkill/           the plan skill, mirrored from skills/
│   │   ├── Reports/             PDF layout, charts, section picker
│   │   ├── Resources/           BodyMap.json, the chime, artwork
│   │   ├── Screens/             one file per screen, phone and watch
│   │   ├── State/               stores, importer, Apple Health, plan converter
│   │   └── Theme/               palette and metrics
│   └── Tools/                   build_bodymap.py
├── Senku/                       Xcode project
│   ├── Senku/                   app entry point, sample data
│   ├── SenkuWidgets/
│   ├── SenkuWatch/
│   ├── SenkuTests/              bundle-level tests
│   └── SenkuUITests/            UI automation and the README screenshots
├── skills/senku-plan/           the plan-import skill, for any AI
└── docs/                        and docs/screenshots/make_persona.py
```

### Package boundaries

- `SenkuCore` has no UI framework dependency, which is what lets its suite run
  on the host in milliseconds.
- `SenkuUI` holds screens and stores together; a store is view state.
- `PlateMath` lives in `SenkuUI` because it depends on the unit types.
- The Xcode project carries entitlements, Info.plist keys and entry points only.
- The packages declare `.macOS(.v14)` so `swift test` runs on the host. There is
  no Mac app; the `#if !os(macOS)` guards exist to keep that build compiling.

## Data

One App Group — `group.pk.Senku` — holding JSON under versioned keys, accessed
through `SenkuStorage.shared`, which falls back to `.standard` where the
entitlement is absent.

Each feature owns an `@Observable` store with the same shape:

```swift
@Observable final class WaterStore {
    func reload()                  // re-read from the container
    func add(millilitres: …)       // reload, mutate, persist, reload widgets
}
```

**Stores re-read before mutating** (S1-R3). The widgets write to the same keys
from their own process, and `PhoneSync` writes records arriving from the watch
during background launches. A store holding its launch-time copy would both miss
those writes and overwrite them. The rule applies to `WaterStore`, `IntakeStore`
and `WeightLogStore`; all three are also re-read when the app comes forward.

Where positions are involved — a list's swipe-to-delete — they are resolved to
identifiers before re-reading, since a concurrent write shifts rows.

**Progress photos are files, not defaults.** `ProgressPhotoStore` keeps HEIC
files and a `photos.json` index in the app's own Application Support folder
(not the App Group: no widget or watch shows them). Each photo carries its
weigh-in's date and weight. They are never written to the Photos library and
are left out of the JSON backup; Weight ▸ Evolution exports them as files, and the
hard reset deletes the folder.

## Synchronisation

```
      widgets ──────▶  App Group (JSON)  ◀────── app
   (own process)              ▲
                              │ read fresh on every publish
                       ┌──────┴───────┐
                       │  PhoneSync   │ started from SenkuApp.init
                       └──────┬───────┘
                              │ WatchConnectivity
                              │   application context → state
                              │   message / transfer   → records
                       ┌──────▼───────┐
                       │  watch app   │ summary only, no history
                       └──────────────┘
```

- **The phone is the source of record.** The watch holds a `WeightSummary`,
  `WaterSummary` or `IntakeSummary` plus anything it has logged since, and sends
  each record as a value with its own identifier.
- **Sync starts at app launch**, from `SenkuApp.init`, before any scene exists —
  the watch can wake the phone in the background, where no view appears.
- Everything published is read from storage rather than from view state.
- Records are sent by `sendMessage` with a `transferUserInfo` fallback, so an
  unreachable counterpart queues rather than drops. Duplicate identifiers are
  ignored on arrival.

## Apple Health

Write-only (F7). `HealthSync` reconciles rather than appends: each category
works out what is new, changed and gone since the last write
(`HealthSyncPlan`), tags every sample with its Senku entry so an edit replaces
it and a delete removes it, and writes only categories switched on in Settings
and only entries logged since they were. Restores and sample data never reach
Health. A workout is written once, from its summary's Done.

**Dues keep their days at noon.** A saved date is a moment, and which day it
falls on depends on where the phone is: midnight on the 5th in Chicago is the
4th in Los Angeles. `DueItem` stores its first date, last paid and history at noon,
which stays on its day anywhere within eleven hours, and moves items saved
before on load (`moveDaysToNoon`).

**Dues write to Expenses.** `DueDateStore.expenses`, set by the Dues screen when
Expenses is added, receives a `MoneyEntry` for each payment whose category is a
spend (`DueItem.expenseCategory`: never Credit Card). The completion keeps the
entry's id, so undoing a payment — from any of the three places that can —
removes the spend with it.

## Backup and sample

`SenkuImportDocument` is the one file format: a backup, a hand-written file and
an AI's plan are all it. `docs/import-example.json` is the full format, one of
everything; `ImportExampleTests` imports it whole and checks every key is one
the decoder reads and none is missing. The app carries a copy as the data
menu's *Sample file* (`SampleFile`), held to the same bytes by a test.

A restore that brings settings rebuilds the screens; its summary is raised
after the rebuild, not with it, or it is dropped.

## Plan import

A plan file goes through the same importer as a backup, trimmed to its plan and
custom exercises (`SenkuImporter.applyPlan`). Names are resolved to catalogue
ids on the way in (`ExerciseLibrary.exercise(named:)`); a day's targets follow
their exercises through that resolution.

The preview is a dry run, not a second implementation: the importer runs
against throwaway stores seeded with the person's own exercises, and the week it
leaves behind is what the preview draws (`PlanImportPreview`). It cannot
promise a different week from the one Replace makes.

The prompts are built on the phone (`PlanConverter`): one to make a plan, one
to convert one, each with the exercise list generated from the bundled
catalogue plus the person's own exercises, and the make prompt with what the
profile says about them on top. They are built from `PlanSkill/`, a copy of
`skills/senku-plan` kept by `senku_plan.py sync`; tests hold the copy, the list
and both prompts to the repository's bytes. The skill itself is published to
its own repository and linked, not zipped by the app. Plan files carry
`catalogueVersion` (the catalogue's `version`, a hash of its ids) so the
preview can say a file came from an older exercise list.

## Network

Little by default. Exercise pictures are fetched from RepDB's free tier
(`exercise-dataset.com`) the first time an exercise is opened, and kept in the
caches folder — `ExerciseMedia.json` holds only the paths, never the images,
since their licence allows in-app use with a credit but not redistribution.
The other exceptions are each the person's choice: Gemini reading a food photo
or label (opt-in, with their own key), anime posters loaded from the addresses
they add, and links they tap. Everything else — HealthKit,
WatchConnectivity, widgets — stays on the device.

## Notifications

iOS retains the 64 soonest pending requests (S2-R1). The budget is declared
once, in `NotificationBudget`, and a test sums it:

| Source | Requests |
| --- | --- |
| Water reminders | up to 12 |
| Rest timer | 2, only while a rest runs |
| Weigh-in reminder | 7 one-shots, a day already weighed left out |
| Creatine reminder | 1 repeating, re-booked on return so its wording follows updates |
| Due dates | up to 36 one-shots |
| Reserve | 6 |

`RestAlertPresenter` is the `UNUserNotificationCenterDelegate`, installed at
launch. It presents alerts while the app is foregrounded and allows notification
actions to run in the background.

## Navigation shell

The phone does not use `TabView`. Screens sit in a floating glass bar the user
drags a finger along; the remainder live under an overflow destination, and the
selection and order are user-configurable (`TabLayout`, `TabBarEditor`). The
calculators (`Tab.staysInMore`) are never offered for the bar. `TabLayout` lays
the bar out from the saved choice each time it is measured, so a narrow window
trims it for as long as it is narrow without the trim being saved.

Pages stay mounted, so returning to a tab restores its state. Screens that act
on appearing read the `senkuScreenIsVisible` environment value and wait until
they are on display (S5-R4).

## Testing

| Suite | Runs on | Covers |
| --- | --- | --- |
| `SenkuCore/Tests` | host, `swift test` | calculations and model rules — 285 tests |
| `SenkuUI/Tests` | host, `swift test` | stores, importer, the example file, plan import and preview, the skill's copy, dues to expenses, money export, body map, plate maths, tab layout, sample data — 284 tests |
| `Senku/SenkuTests` | simulator | bundle resources, App Group access |
| `Senku/SenkuUITests` | simulator | launch, rest timer, calculator, Plan Builder, the example file imported and every page it fills; the README screenshots, on request |

## Conventions

- Comments record why a decision was taken, not what the code does.
- Models validate in `init` and throw; invalid values are not stored.
- Formatting lives in `Display`.
- Debug-only hooks are `#if DEBUG` and documented: `SENKU_SAMPLE` loads sample
  data through the production importer (`1` for the bundled file, or a path),
  `SENKU_SCREEN` opens the app on one screen, `SENKU_PLAN_FILE` opens a plan
  file's preview as though it had been picked.

## Key decisions

| # | Decision | Rationale |
| --- | --- | --- |
| A1 | JSON in an App Group rather than SwiftData | Widgets and the watch read the same container; no migration surface |
| A2 | Stores re-read before mutating | Multiple processes write the same keys |
| A3 | Sync started from `SenkuApp.init` | Background launches have no scene |
| A4 | Watch holds a summary, not a history | Avoids two devices diverging on one list |
| A5 | Custom navigation bar | Four configurable slots rather than five fixed ones |
| A6 | PDF drawn with Core Text and Core Graphics | Real pagination and vector charts |
| A7 | Apple Health reconciled by difference, write-only | Edits and deletes follow; nothing read back competes with the app's own record |
| A8 | The plan preview is a dry run of the importer | One implementation, so the preview cannot disagree with the import |
| A9 | The skill mirrored into the app, held by tests, and published on its own | The app's prompts match the skill exactly; the skill has a stable download for any AI |
