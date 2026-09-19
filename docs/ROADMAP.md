# Roadmap

Milestones in delivery order. Each one ends with something usable on a device.

**Status:** M0–M8 complete. M9 is the current backlog.

---

## M0 — Calculation core

- [x] `SenkuCore` package, no UI framework dependency
- [x] BMR via Mifflin-St Jeor, Katch-McArdle and Harris-Benedict
- [x] Maintenance at all five activity levels
- [x] Goal targets with a safe-minimum floor
- [x] Macro, fibre and water targets
- [x] Body composition: BMI, lean mass, fat mass, healthy range
- [x] Projection: weekly change and time to goal weight
- [x] Advisory vocabulary for unsafe or low-confidence plans
- [x] `senku` CLI over the same engine

## M1 — App shell and profile

- [x] `SenkuUI` package: theme, components, formatting
- [x] Quick calc screen, and a plan the user keeps
- [x] Unit system honoured throughout the presentation layer
- [x] Xcode project with the iOS target
- [x] App Group `group.pk.Senku` as the single storage container

## M2 — Rest timer

- [x] Timer with presets and custom durations
- [x] Live Activity on the Lock Screen and in the Dynamic Island
- [x] Control Center control
- [x] Alert on a locked phone, and in-app while foregrounded
- [x] App Intents: start, stop, extend

## M3 — Weight log (F1)

- [x] Weigh-in records with source provenance
- [x] Trend line by least-squares regression, and weekly rate
- [x] Goal countdown against the profile
- [x] Daily reminder
- [x] History with edit and delete
- [x] Home Screen widget

## M4 — Exercises and records (F2)

- [x] Exercise catalogue: 138 entries, bundled as data
- [x] Muscle taxonomy: 8 groups, 25 regions, per-exercise contributions
- [x] Custom exercises, marked as user-classified
- [x] Personal records per exercise, logged and manual kept distinct
- [x] Estimated 1RM by Epley
- [x] Cardio records and reusable cardio protocols
- [x] Filters: muscle group, recency, stale

## M5 — Workout (F3)

- [x] Split editor: named training days, groups, ordered exercises
- [x] Four starting templates
- [x] Coverage per muscle region, with the gap named
- [x] Session checklist in muscle blocks
- [x] Set logger, pre-filled from the last session
- [x] Timed holds logged as seconds, not reps
- [x] Cardio logging
- [x] Rest timer started from the set logger

## M6 — Water (F4)

- [x] Goal resolved from profile, training day and creatine on every read
- [x] Three configurable containers, one tap each
- [x] Bottle visual with a text equivalent
- [x] Interval reminders inside an active window
- [x] Reminders stop once the goal is met, and resume
- [x] Creatine tracking with its own streak
- [x] Home Screen widget with logging actions
- [x] Watch screen

## M7 — Food (F5)

- [x] Intake entries with full macros
- [x] Protein-only and calorie-only quick entry
- [x] Saved foods with a servings multiplier
- [x] Protein and calorie rings against plan targets
- [x] Separate protein and calorie streaks
- [x] Adaptive maintenance from observed intake against observed weight change
- [x] Home Screen widget
- [x] Watch screen

## M8 — Watch, widgets and export

- [x] WatchConnectivity sync, phone as the source of record
- [x] Sync established at app launch, including background launches
- [x] Watch screens: plan, weight, water, food, rest
- [x] Widget set: targets, weight, water, food, rest
- [x] PDF report with charts and a section picker
- [x] JSON export and import
- [x] Anime log (F6)
- [x] Customisable navigation bar

## M9 — Backlog

- [ ] Edit a past day's food and water
- [ ] User-settable day boundary (default midnight, 03:00 alternative)
- [ ] Sets-per-week volume guidance
- [ ] Watch complications for water and food
- [ ] Weigh-in reminder suppressed on a day already logged

---

## Release history

| Milestone | Delivered |
| --- | --- |
| M0 — Calculation core | ✅ |
| M1 — App shell and profile | ✅ |
| M2 — Rest timer | ✅ |
| M3 — Weight log | ✅ |
| M4 — Exercises and records | ✅ |
| M5 — Workout | ✅ |
| M6 — Water | ✅ |
| M7 — Food | ✅ |
| M8 — Watch, widgets and export | ✅ |
| M9 — Backlog | in progress |
