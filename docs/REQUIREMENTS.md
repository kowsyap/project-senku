# Requirements

Functional requirements and acceptance criteria for Senku.

**Conventions**

- Requirements are identified as `<feature>-R<n>`, acceptance criteria as
  checklist items under each feature.
- "Must" is binding. Anything not stated is an implementation choice.
- A checked box means the criterion is implemented and covered by a test or by
  a named type in the source.

**Status:** F1–F7 delivered. Three acceptance criteria remain open — two from
F1–F5, tracked in [ROADMAP.md](ROADMAP.md) M9, and F7's SideStore install, M10.
Everything else agreed but not yet built is under [Planned](#planned).

| ID | Feature | Depends on |
| --- | --- | --- |
| [F1](#f1--weight-log) | Weight log | S1 |
| [F2](#f2--personal-records) | Personal records | S1, exercise catalogue |
| [F3](#f3--workout-and-splits) | Workout and splits | F2, muscle map |
| [F4](#f4--water-tracking) | Water tracking | S1, S2 |
| [F5](#f5--protein-and-macro-intake) | Protein and macro intake | S1 |
| [F6](#f6--anime-log) | Anime log | S1 |
| [F7](#f7--apple-health) | Apple Health | F1, F3, F4, F5 |

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
  `senku.weighin.*`, `senku.water.*`, `senku.creatine.*`, `senku.due.*`.
- **S2-R3** Repeating triggers are used in preference to enumerating future
  occurrences.
- **S2-R4** Authorisation is requested before scheduling, not alongside it.
- **S2-R5** Every reminder is individually switchable.

- **S2-R6** The rest chime must not turn other audio down for the length of a
  rest. The session holding the app awake mixes with other audio; it ducks only
  for the chime, and lets go once the chime has sounded.

Budget, declared once in `NotificationBudget` and summed by a test: water 12,
rest 2, weigh-in 1, creatine 1, due dates 42 — 58 allocated, 6 held in reserve.

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
- **S5-R5** Settings that belong to no single screen live on one Settings page
  under More — the navbar editor and Apple Health. Settings tied to a screen
  stay behind that screen's own button — Adjust, with the sliders icon (Week
  on Workout, Rack on the plate calculator) — and the Settings page links to
  each of those pages (Workout, Weight, Water, Food, Plates) rather than holding a
  second copy. The rest that follows a logged set is a Workout setting, on the
  Week page.
- **S5-R6** An About page, from Settings, gives the version, who made the app
  and where to report a problem, where the data goes and the exceptions to "it
  stays on the phone", the medical disclaimer, the license with its artwork
  exclusion, and every third-party license notice in full — the copy MIT asks
  for in each copy of the software. The app's copy of a notice must match
  `THIRD_PARTY_NOTICES.md` word for word, which `PlanConverterTests` checks.

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
- **F1-R5** Adaptive maintenance reads food and weight over the same window:
  the 21 full days ending yesterday. It becomes available only when all of the
  following hold within it: at least 8 weigh-ins spanning at least 14 days,
  food logged on at least 15 of the 21 days, and a difference of at least
  100 kcal from the formula plan.
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
  seconds: TimeInterval?         // a hold
  date: Date
  source: .logged(setID) | .manual
```

### Requirements

- **F2-R1** Logged and manual records are stored separately and never blended.
  The headline is the better of the two, and states which it is.
- **F2-R2** Heaviest weight and best estimated 1RM are reported separately. The
  estimate uses Epley (`w × (1 + reps/30)`) and names it. A set of more than 10
  reps is estimated as 10 reps at its weight and shown as a lower bound (`≥`),
  never discarded and never extrapolated.
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
- **F2-R8** The list is newest first: an exercise's latest record decides its
  place, lifts and cardio together. It can be filtered by muscle group. (The
  recency and stale filters were removed — every row carries its date.)
- **F2-R9** A set is a record if it is heavier than any before, has more reps at
  the heaviest weight, or implies a better estimated single. The reps rule
  holds past the estimate's 10-rep limit, where two sets estimate alike.
- **F2-R10** A logged set and a record of the same lift give the same estimate:
  the formula is written once.
- **F2-R11** A record added by hand must beat the exercise's best: heavier, or
  the same weight for more reps; a hold longer, or as long with more weight.
  Logged sets keep F2-R9, which also accepts a better estimated single.
- **F2-R12** A record can be shared as a picture: a 9:16 card at 1080 × 1920 with
  the lift, what it beat, the estimated 1RM, the records leading to it and the
  muscles it trains on the body. It is drawn on the phone, previewed before the
  share sheet, and only the image leaves. Swiping a row left offers the same.
- **F2-R13** Each row carries an info button beside the exercise's name, opening
  the exercise's sheet (F3-R18).

### Acceptance

- [x] Removing an exercise from every split leaves its record untouched
- [x] A logged set heavier than the stored record updates it —
      `WorkoutStore.log(_:for:records:)`
- [x] A manual record below a logged record is kept but not shown as the
      headline — `PersonalRecordTests`
- [x] Deleting a session preserves its records; deleting one set detaches it —
      `RecordStore.detachRecords(fromSets:)`
- [x] Deleting a referenced custom exercise is refused on both screens
- [x] 35 kg × 10 followed by 40 kg × 15 moves the estimate to ≥ 53.3 kg —
      `PersonalRecordTests`
- [x] 40 kg × 15 is a record over 40 kg × 12 — `PersonalRecordTests`
- [x] A lighter record typed by hand is refused, the same weight for more reps
      accepted — `PersonalRecordTests`
- [x] A record shares as a story-sized card — `RecordShareCard`, `RecordShareSheet`
- [x] The list orders exercises by their latest record, cardio included —
      `RecordsView.shownRows`

---

## F3 — Workout and splits

**Purpose.** Define a training week, run today's session, and log the work.

### Data

```
Exercise                       // catalogue: bundled, read-only
  id, name, equipment
  aliases: [String]                         // other names, for search
  contributions: [MuscleRegion: Double]     // 0…1 per region
  isTimed, isCustom: Bool

RepTarget
  sets: 1…10, reps: 1…50, maxReps?          // "3 × 10" or "3 × 8–12"

TrainingPlan
  days: [SplitDay], target: RepTarget        // the week's target

SplitDay                       // user-defined
  name, groups: [WorkoutGroup], exerciseIDs: [ExerciseID]
  targets: [ExerciseID: RepTarget]           // only where an exercise differs

WorkoutSession
  date, groups
  entries: [(exerciseID, sets: [LoggedSet], target: RepTarget?)]

LoggedSet
  id, weightKG, reps, seconds?, completedAt
```

### The muscle map

A two-level taxonomy, bundled as data in `SenkuCore`:

- **Group** — back, biceps, triceps, forearms, chest, legs, shoulders, abs,
  cardio.
- **Region** — 28 in total; each carries a share of its group, summing to 100%
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
- **F3-R11** Search matches an exercise by its name or any of its other names,
  ignoring case, spacing, hyphens and a trailing plural, and a result found by
  another name shows which one.
- **F3-R12** A custom exercise may be marked timed, and stays timed through a
  backup and restore.
- **F3-R13** Forearms are a group of their own. Adding a group must not change
  the coverage of any existing group, and a week without forearm work is not
  reported as a gap.
- **F3-R14** The exercise picker opened from a muscle's card offers that muscle
  only, and its search looks only there. The day's Other card, always shown,
  holds exercises from outside the day's muscles, and its + opens the picker on
  the groups.
- **F3-R15** A muscle group is chosen either on a body map (the default) or on
  the ring, with a switch between them that is remembered and backed up.
  - The body drawn is the profile's sex, front and back, the other side small in
    the corner and swapped on a tap.
  - Every muscle region is reachable from the map; tapping a muscle chooses its
    group.
  - Cardio, which no body drawing has, is a heart the size of a ring disc, in
    the same corner in both styles, standing on the same line as the figures.
  - Muscles are drawn in their group's colour, the same as the ring's discs.
- **F3-R16** The ring can be turned by dragging. It settles with a group at the
  top, and a tap still chooses a group.
- **F3-R17** Targets. The week has one, and any exercise on a day may have its
  own; an exercise without its own uses the week's, and a week without one uses
  3 × 10.
  - A target is sets and reps, or sets and a rep range.
  - An exercise is done at its target's sets.
  - A step up is earned when every set at one weight reaches the top of the
    range; the next session opens at that weight plus one step, back at the
    bottom of the range. A bodyweight exercise asks for one rep past the top.
  - A session copies each exercise's target when it starts, so a later change
    to the plan does not re-judge old sessions. Sessions from before targets
    finish at three sets.
- **F3-R18** An exercise's info sheet draws what it trains on the body, front and
  back, yellow for a little to red for most; the chest is cut into its three
  heads along the muscle. It opens from the picker, from a session's rows and
  from records.
- **F3-R19** Finishing a session shows the body: green for what was trained,
  red for what the day planned and was not. A muscle counts as trained at half
  coverage or more.
- **F3-R20** A session shows how long it has run, from the moment the day was
  chosen: minutes and seconds, hours added after the first, stopping in red at
  three hours.
- **F3-R21** A plan can be imported from a file, from the Week page.
  - The file may name exercises by id, name or another name, whole and
    forgiving case, spacing and a plural; groups as people say them; and no ids.
    Exercises may carry their own numbers, and what they leave out comes from
    the plan's target.
  - A name that matches nothing, or matches several, is reported and left out,
    never guessed.
  - Only the plan and the custom exercises it needs are taken from the file;
    custom exercises are added first so the plan can name them, and one whose
    name already exists is not added again.
  - Before anything is replaced the week is shown, laid out like the Week page,
    from a dry run of the same import; the long press previews a plan-only
    file the same way.
  - The page hands out a prompt for any AI chat and the plan skill as a zip, both
    built at that moment from the app's own catalogue and the person's own
    exercises. The skill lives in `skills/senku-plan` and is mirrored into the
    app.

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
- [x] "skullcrushers", "dead hangs" and "RDL" each find their exercise —
      `ExerciseSearchTests`
- [x] A barbell curl covers biceps exactly as it did before forearms existed —
      `ForearmTests`
- [x] A timed custom exercise survives a backup — `BackupRoundTripTests`
- [x] Every region except cardio's is on the body, for both sexes, and the heart
      reaches cardio — `BodyMapTests`
- [x] The heart stands on the line the figures do — `BodyMapTests`
- [x] 3 × 8–12 is earned at twelve on every set; a range written as 10–10 is one
      figure; an old target still reads — `RepTargetTests`
- [x] An exercise finishes at its own sets; a session from before targets at
      three — `RepTargetTests`
- [x] Names, aliases and plurals resolve; "RDL" is reported as ambiguous;
      nothing outside the plan changes — `PlanImportTests`
- [x] The documented example and the skill's example both import cleanly —
      `PlanImportTests`
- [x] The preview predicts exactly what Replace does, and touches nothing —
      `PlanConverterTests`
- [x] The app's prompt and skill match the repository's byte for byte —
      `PlanConverterTests`
- [x] Trained and missed muscles follow the half-coverage line — `BodyMapTests`
- [x] Import a Plan is reachable from the Week page, and a plan file opens its
      preview — `PlanImportUITests`
- [x] Dragging round the ring turns it the right way, across the wrap, and not
      at all near the centre — `RingTurnTests`
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

- [x] A past day can be corrected from the streak screen: water's total set by
      amount or container, creatine marked taken or not
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
- [x] A past day's protein, calories, water and creatine can be set from the
      streak screen: the day's total is shown, edited or added to, and saved
      only on OK. Lowering trims quick entries and the latest drinks, never a
      meal — `BackfillTests`. Editing a past meal itself is still open, M9

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

## F7 — Apple Health

**Purpose.** Write what Senku records into Apple Health, so it sits beside what
the phone and watch measure. Senku stays the source of record: nothing is read
back.

### Requirements

- **F7-R1** The first step is a sideloaded build that writes one water sample.
  If HealthKit does not survive SideStore's re-signing on a free Apple ID, the
  feature stops there.
- **F7-R2** Written, each as it is logged: water; each food entry as one food
  correlation of protein, carbohydrate, fat, fibre (when set) and energy; weight;
  body fat when entered rather than estimated; height when changed.
- **F7-R3** Energy is one figure per entry — the packet's if typed, otherwise
  the macros' — never both.
- **F7-R4** A finished session is written as a strength workout, timed from
  its first logged set to its last — or start to finish when the sets were
  logged within 5 minutes of each other — with active energy estimated as
  `(MET − 1) × weight × hours`. Effort is Light (3.5) by default every time, or
  Vigorous (6.0), from the Compendium of Physical Activities; the figure is
  marked as an estimate (≈), and the duration can be corrected. It is written when
  the summary that follows finishing is closed with Done; swiping it away, a
  duration under 5 minutes, or reopening a session from history writes
  nothing.
- **F7-R5** Editing or deleting an entry replaces or removes its Health sample.
- **F7-R6** Never written: restored backups, sample data, BMI, lean or fat mass,
  estimated body fat, sets, reps and records.
- **F7-R7** On and off overall and per category, on the Settings page (S5-R5).
  Permission is asked when it is first turned on, not at launch, and the app
  works unchanged without it.

### Acceptance

- [x] A build installed on a free Apple ID writes a water sample and the
      permission prompt appears — verified on device, 2026-10-07
- [ ] The same through a SideStore install — open, F7; the `.ipa` must carry
      its entitlements first
- [x] Water, food and body are worked out as new, edited or removed before
      anything is sent — `HealthSyncPlanTests`
- [x] Food and body samples appear in Health — verified on device, 2026-10-07
- [x] A finished session writes one workout with its estimated energy, only
      when its summary is closed with Done — `HealthWorkoutDraft`,
      `WorkoutEnergyTests`
- [x] PROJECT.md's HealthKit non-goal reads "write-only; never reads"

---

## Open criteria

| Criterion | Feature | Tracked as |
| --- | --- | --- |
| Reminder suppressed on a day already logged | F1 | M9 |
| A single past entry can be edited or deleted (a past day's total already can be set, from Streaks) | F4, F5 | M9 |
| A SideStore install writes to Health | F7 | M10 |

---

## Planned

Agreed, not started, and not yet specified as features of their own.

| Item | Area | Notes |
| --- | --- | --- |
| Shin region and Tibialis Raise | F3 | Needs a muscle region for the front of the shin before the exercise can be scored honestly |
| Sets-per-week volume guidance | F3 | M9 |
| User-settable day boundary | S3 | M9 — midnight by default, 03:00 as the alternative |
| Watch complications for water and food | F4, F5 | M9 |
| Plan builder in the plan skill | F3 | `/senku-plan` with no file offers to build a plan from goals, days, equipment and experience, using only catalogue exercises, written as the same import file and checked by the same script. Part of `skills/senku-plan`, not a separate skill |
| SBD / powerlifting programmes | F3 | Week-by-week blocks: a top set and back-off sets per lift with prescribed weights, RPE, deload, peak and test week, pre-filled in the set logger. Not needed for now |
| Loan / EMI tracker | new | Amount, rate, tenure, principal and interest split, prepayment effect; arithmetic only |
| Expense tracker | new | Dated entries; receipt reading through the existing Vision pipeline |
| Wardrobe | new | Catalogue the clothes, then suggest outfits by occasion |
