# Requirements

Functional requirements and acceptance criteria for Senku.

**Conventions**

- Requirements are identified as `<feature>-R<n>`, acceptance criteria as
  checklist items under each feature.
- "Must" is binding. Anything not stated is an implementation choice.
- A checked box means the criterion is implemented and covered by a test or by
  a named type in the source.

**Status:** 6 of 6 features delivered. Two acceptance criteria remain open and
are tracked in [ROADMAP.md](ROADMAP.md) M9.

| ID | Feature | Depends on |
| --- | --- | --- |
| [F1](#f1--weight-log) | Weight log | S1 |
| [F2](#f2--personal-records) | Personal records | S1, exercise catalogue |
| [F3](#f3--workout-and-splits) | Workout and splits | F2, muscle map |
| [F4](#f4--water-tracking) | Water tracking | S1, S2 |
| [F5](#f5--protein-and-macro-intake) | Protein and macro intake | S1 |
| [F6](#f6--anime-log) | Anime log | S1 |

---

## Cross-cutting requirements

Every feature inherits these.

**X-R1 — Attribution.** Any derived figure must name its method where it is
displayed: the smoothing behind a trend, the formula behind an estimated 1RM,
the basis of a coverage percentage.

**X-R2 — Provenance.** Measured values and estimated values must be
distinguishable in the model and in the UI. A user-asserted classification must
be labelled as such.

**X-R3 — Advisories.** Unsafe or low-confidence conditions must raise an
`Advisory` rather than be presented without comment.

**X-R4 — Accessibility.** Any figure conveyed by a shape, a ring or a colour
must have a text equivalent.

---

## Shared foundations

### S1 — Storage

- **S1-R1** All persistent data is held in the App Group `group.pk.Senku`, as
  JSON under versioned keys, accessed through `SenkuStorage.shared`.
- **S1-R2** `SenkuCore` must not import a persistence framework. Models are
  plain `Codable` value types.
- **S1-R3** Storage is shared by the app, its widgets and the watch app. Any
  store that can be written from more than one process must re-read before
  mutating.
- **S1-R4** Timestamps are stored as absolute `Date` values and bucketed into
  days at read time. Day strings are not stored.
- **S1-R5** A storage handle must fall back to `.standard` where the entitlement
  is unavailable, so previews and tests run without one.

### S2 — Notification scheduling

- **S2-R1** iOS retains only the 64 soonest pending requests. The total booked
  by the app must stay demonstrably below that ceiling.
- **S2-R2** Identifiers are namespaced per source: `senku.rest.*`,
  `senku.weighin.*`, `senku.water.*`, `senku.creatine.*`.
- **S2-R3** Repeating triggers are used in preference to enumerating future
  occurrences.
- **S2-R4** Authorisation is requested before scheduling, not alongside it.
- **S2-R5** Every reminder is individually switchable.

Current budget: 12 water slots, 1 weigh-in, 1 creatine, 1 rest — 15 at worst.

### S3 — Day boundary

- **S3-R1** A day runs from local midnight to local midnight.
- **S3-R2** Aggregation is performed at read time against the current calendar.

### S4 — Units

- **S4-R1** The core operates in kilograms, centimetres and millilitres.
- **S4-R2** Conversion happens in the presentation layer only, driven by the
  profile's unit system.
- **S4-R3** Water is always displayed in millilitres.

### S5 — Navigation

- **S5-R1** The phone presents four navigation slots on a regular-width device
  and three on a compact one, plus an overflow destination.
- **S5-R2** The user selects which screens occupy the bar, and their order.
- **S5-R3** Screens remain mounted across navigation, so returning to one
  restores its state.
- **S5-R4** A screen that performs work on appearing must not do so while it is
  mounted but not visible.

---

## F1 — Weight log

**Purpose.** Turn the profile's single weight into a series, so the plan can be
checked against outcomes rather than only projected forward.

### Data

```
WeighIn
  id: UUID
  date: Date
  weightKG: Double
  source: .manual | .imported
  note: String?
```

### Requirements

- **F1-R1** Multiple weigh-ins in one day are accepted; the day's value for
  trend purposes is their mean.
- **F1-R2** The trend is fitted by least-squares regression over daily values,
  and the weekly rate is derived from its slope.
- **F1-R3** The chart shows raw readings and the trend, distinguishable from one
  another.
- **F1-R4** The profile weight never changes without explicit user action.
  Adopting the trend is an offered, single-purpose edit.
- **F1-R5** Adaptive maintenance becomes available only when all of the
  following hold: at least 8 weigh-ins across 14 days, food logged on at least
  10 of the last 14 days, and a difference of at least 100 kcal from the
  formula plan.
- **F1-R6** Adaptive maintenance shows its arithmetic — observed change, the
  7,700 kcal/kg assumption, the implied daily delta — and applies only on
  acceptance.
- **F1-R7** A daily reminder can be enabled, and survives relaunch and reboot.

### Acceptance

- [x] Logging three days produces a trend that differs from the last reading —
      `WeightSeriesTests`
- [x] Deleting the only weigh-in of a day removes it from the trend
- [x] The profile weight changes only through the offered edit
- [x] Adaptive maintenance does not appear below the data threshold —
      `MaintenanceCheckTests`
- [x] A weigh-in arriving from the watch is not overwritten by the next one
      logged on the phone — `WeightLogSharingTests`
- [ ] The reminder is suppressed on a day already logged — open, M9

---

## F2 — Personal records

**Purpose.** Every exercise the user has loaded, with the best performance on
it. A record that outlives whatever split is currently being run.

### Data

```
ExerciseID = String              // "catalogue.bench.flat" | "custom.<uuid>"

PersonalRecord
  exerciseID: ExerciseID
  weightKG: Double
  reps: Int
  date: Date
  source: .logged(setID) | .manual
```

### Requirements

- **F2-R1** Logged and manual records are stored separately and never blended.
  The headline is the better of the two, and states which it is.
- **F2-R2** Heaviest weight and best estimated 1RM are reported separately. The
  estimate uses Epley (`w × (1 + reps/30)`) and names it.
- **F2-R3** The records list is a superset of the current splits. Editing a
  split never removes a record.
- **F2-R4** Deleting a workout session must not delete the records it produced.
  Deleting an individual set detaches its record and downgrades its provenance
  to manual.
- **F2-R5** A record may be deleted only by explicit user action, with
  confirmation.
- **F2-R6** Deleting a custom exercise that a split or a record still references
  is refused.
- **F2-R7** Cardio records are held alongside, with reusable protocols.
- **F2-R8** The list can be filtered by muscle group and by recency, including a
  stale filter of no new record in 60 days.

### Acceptance

- [x] Removing an exercise from every split leaves its record untouched
- [x] A logged set heavier than the stored record updates it —
      `WorkoutStore.log(_:for:records:)`
- [x] A manual record below a logged record is kept but not shown as the
      headline — `PersonalRecordTests`
- [x] Deleting a session preserves its records; deleting one set detaches it —
      `RecordStore.detachRecords(fromSets:)`
- [x] Deleting a referenced custom exercise is refused on both screens

---

## F3 — Workout and splits

**Purpose.** Define a training week, run today's session, and log the work.

### Data

```
Exercise                       // catalogue: bundled, read-only
  id, name, equipment
  contributions: [MuscleRegion: Double]     // 0…1 per region
  isCustom: Bool

SplitDay                       // user-defined
  name, groups: [WorkoutGroup], exerciseIDs: [ExerciseID]

WorkoutSession
  date, groups
  entries: [(exerciseID, sets: [LoggedSet])]

LoggedSet
  id, weightKG, reps, seconds?, completedAt
```

### The muscle map

A two-level taxonomy, bundled as data in `SenkuCore`:

- **Group** — back, biceps, triceps, chest, legs, shoulders, abs, cardio.
- **Region** — 25 in total; each carries a share of its group, summing to 100%
  per group.
- **Contribution** — each exercise contributes 0–1 per region, where 1 is a
  primary target.

### Requirements

- **F3-R1** The catalogue ships as data and is read-only.
- **F3-R2** Custom exercises derive contributions from the regions the user
  selects, and are labelled as user-classified wherever they are counted.
- **F3-R3** Coverage is computed as
  `regionCoverage(r) = min(1, Σ contributions)` and
  `splitCoverage = Σ regionCoverage(r) × share(r)` over the day's groups.
- **F3-R4** Coverage is presented with a per-region breakdown and a named gap.
- **F3-R5** Coverage represents breadth, not volume, and must say so.
- **F3-R6** A session presents the day's exercises as a checklist grouped by
  muscle.
- **F3-R7** The set logger opens pre-filled with the previous session's values
  for that exercise, and states when that was.
- **F3-R8** Timed holds are stored as seconds and must not be recorded as reps.
- **F3-R9** Logging a set starts the rest timer without a further action.
- **F3-R10** Starting templates are offered for a new plan.

### Two-way behaviour with F2

| Action | Effect |
| --- | --- |
| Log a set above the stored record | Record updates, source `.logged` |
| Add an exercise to a split | Appears in records as "no record yet" |
| Remove an exercise from a split | Record unchanged |
| Add a manual record for an unscheduled exercise | Permitted |
| Edit a manual record | Logged sets unchanged |
| Delete a referenced custom exercise | Refused |

### Acceptance

- [x] A chest split of flat bench alone reads well under 100% and names the gap
      — `MuscleCoverageTests`
- [x] Adding incline and decline raises it, with each contribution shown
- [x] A custom exercise is marked as user-classified wherever it counts
- [x] Logging a set starts the rest timer without a second tap
- [x] Cardio is a group without muscles: always 100%, logged as time and the
      machine's own metrics
- [x] Every rule above is covered by the `SenkuCore` suite

---

## F4 — Water tracking

**Purpose.** Help the user meet the daily water target the plan already
computes.

### Data

```
WaterEntry    { id, date, millilitres, containerID? }
WaterContainer{ id, name, millilitres }
WaterSettings { containers, goalOverrideML?, takesCreatine, reminder settings }
```

### Requirements

- **F4-R1** The goal is resolved on every read from the profile, whether a
  workout was logged today, and whether creatine is enabled. It is never stored.
- **F4-R2** A manual override is permitted and is displayed as an override.
- **F4-R3** Three configurable containers are offered, each logging in one tap.
- **F4-R4** The bottle visual fills to `consumed / goal`, caps at full, states
  any overage, and carries a text equivalent (X-R4).
- **F4-R5** Reminders repeat on a chosen interval within an active window.
- **F4-R6** Reminders for the remainder of a day stop once the goal is met, and
  are restored at the next launch or foreground.
- **F4-R7** A notification action logs a drink without launching the app.
- **F4-R8** Creatine tracking, when enabled, adds to the goal and maintains a
  streak.
- **F4-R9** A drink logged in the widget or on the watch reaches the app, and
  cannot be overwritten by a subsequent write from another process.

### Acceptance

- [x] A past day can be marked "never logged" but not filled in
- [x] Reminders stop once the goal is met and are restored on foreground —
      `WaterReminders.refresh`, `RootView.restoreWaterReminders()`
- [x] Pending requests stay within the S2-R1 budget: 15 at worst
- [x] The goal follows the profile, being resolved on every read
- [x] Logging from a notification does not launch the app — `LogWaterIntent`
- [x] Drinks logged in the widget and on the watch reach the app —
      `WaterStoreTests`

---

## F5 — Protein and macro intake

**Purpose.** Record what was eaten against the targets the plan sets.

### Data

```
IntakeEntry   { id, date, name?, proteinG, carbsG, fatG, fiberG?, calories? }
FoodFavourite { id, name, macros }
```

### Requirements

- **F5-R1** Targets come from `plan.macros`. No copy is kept.
- **F5-R2** Calories are derived at 4/4/9 per gram. Where the user supplies a
  figure that disagrees, both are shown and identified.
- **F5-R3** Protein is the headline figure; calories are the secondary ring.
- **F5-R4** Quick entry supports protein alone, calories alone, a saved food
  with a servings multiplier, and full macro entry.
- **F5-R5** Entries accept decimal grams.
- **F5-R6** A day with no entries reads as "nothing logged", never as zero.
- **F5-R7** Future days cannot be logged.
- **F5-R8** Two streaks are maintained. Protein is a floor: at or above target
  counts. Calories are a band of ±10% of target; either edge is a miss.
- **F5-R9** Streaks are recomputed against current targets, and an unlogged day
  belongs to neither.
- **F5-R10** Intake feeds F1-R5's adaptive maintenance.

### Acceptance

- [x] Targets change when the profile changes, with no copy kept
- [x] Derived and entered calories are never silently reconciled
- [x] A day with no entries reads as "nothing logged" — `IntakeStoreTests`
- [x] Tomorrow cannot be logged
- [x] A meal logged on the watch reaches the phone
- [ ] A past day can be corrected — open, M9. A day can currently be marked
      "never logged" so a streak survives, but a wrong figure cannot be edited

---

## F6 — Anime log

**Purpose.** A personal watch list: what is in progress, where it is up to, and
what the user thought of it. It shares the storage layer and nothing else.

### Data

```
AnimeEntry
  id, title
  totalEpisodes: Int?
  status: .watching | .completed | .paused | .dropped | .planned
  rating: Int?
  startedAt: Date?, finishedAt: Date?
  note: String?
```

### Requirements

- **F6-R1** Progress is counted in episodes, not percentages.
- **F6-R2** A series with no known total must not display a completion figure.
- **F6-R3** Ratings are optional and are never aggregated into a library score.
- **F6-R4** Re-watches append to the history rather than overwrite it.
- **F6-R5** Status is set explicitly and is never inferred from inactivity.
- **F6-R6** Metadata is entered by the user; no network service is required.
- **F6-R7** Nothing from this feature appears on a training or nutrition screen.

### Acceptance

- [x] A weekly series can be advanced one episode in one tap
- [x] A series with no total never shows a completion percentage — `AnimeTests`
- [x] A re-watch does not erase the first watch
- [x] Nothing appears on the training or nutrition screens

---

## Open criteria

| Criterion | Feature | Tracked as |
| --- | --- | --- |
| Reminder suppressed on a day already logged | F1 | M9 |
| A past day can be corrected | F5 | M9 |
