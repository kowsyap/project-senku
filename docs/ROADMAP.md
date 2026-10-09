# Roadmap

Milestones in delivery order. Each one ends with something usable on a device.

**Status:** M0–M8 and M11 complete. M10 is done but for the SideStore check.
M9 is the current backlog.

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

- [x] Exercise catalogue: 160 entries, bundled as data, searchable by other names
- [x] Muscle taxonomy: 9 groups, 28 regions, per-exercise contributions; forearms
      a group of their own
- [x] Custom exercises, marked as user-classified, optionally timed
- [x] Personal records per exercise, logged and manual kept distinct
- [x] Estimated 1RM by Epley, sets past 10 reps counted as 10 and shown as a floor
- [x] Cardio records and reusable cardio protocols
- [x] Filter by muscle group (recency and stale filters later replaced by a
      newest-first list, M11)

## M5 — Workout (F3)

- [x] Split editor: named training days, groups, ordered exercises
- [x] Four starting templates
- [x] Coverage per muscle region, with the gap named
- [x] Session checklist in muscle blocks
- [x] Set logger, pre-filled from the last session
- [x] Timed holds logged as seconds, not reps
- [x] Cardio logging
- [x] Rest timer started from the set logger
- [x] Group chosen on a body map (male or female, front and back) or a ring that
      turns by dragging
- [x] A split day's picker can leave its group for any other (later fenced to the
      muscle, with an Other card for the rest, M11)

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
- [x] Customisable navigation bar, under a Settings page in More

## M9 — Backlog

- [x] Set a past day's protein, calories, water and creatine, from Streaks
- [ ] Open a past day's food and water and edit or delete a single entry
      (today's can be; a past day's total can be set from Streaks)
- [ ] User-settable day boundary (default midnight, 03:00 alternative)
- [ ] Sets-per-week volume guidance
- [ ] Watch complications for water and food
- [ ] Weigh-in reminder suppressed on a day already logged
- [ ] Shin region, so a Tibialis Raise can be scored

## M10 — Apple Health (F7)

- [ ] Sideload test: one water sample through SideStore on a free Apple ID
- [x] Water, food and body written as logged, following edits and deletions
- [x] Workouts with confirmed, MET-estimated active energy
- [x] Apple Health section on the Settings page

## M11 — Plans, targets and sharing

- [x] Sets and rep ranges: a week's target and any exercise's own; done at its
      sets, a step up at the top of the range (F3-R17)
- [x] Day editor: target chips, an Other card, a picker that stays in its muscle
- [x] Import a Plan on the Week page, with a preview laid out like the week; the
      long press previews plan files too (F3-R21)
- [x] The plan skill, `/senku-plan`, for any AI, with a standard-library checker;
      and a prompt for any AI chat, both built from the app's own catalogue
- [x] PRs: a story-sized share card, swipe to share, newest first, info beside
      each name, and a record added by hand must beat the best (F2-R11–R13)
- [x] Body heat maps on exercise info, chest heads cut along the muscle; trained
      and missed muscles on the session summary (F3-R18, R19)
- [x] Session clock (F3-R20)
- [x] The rest chime ducks music only for the chime (S2-R6)
- [x] MIT license, and an About page with the license notices in full (S5-R6)
- [x] README screenshots of a generated persona, taken by a UI test

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
| M10 — Apple Health | ✅ but for the SideStore check |
| M11 — Plans, targets and sharing | ✅ |
