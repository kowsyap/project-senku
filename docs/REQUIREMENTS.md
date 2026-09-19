# Requirements — training, intake, and one thing that is neither

Six features, agreed in outline and specified here before any of them is built.
Nothing in this document is implemented yet. It exists so that when we start,
the arguments have already been had.

These land in [ROADMAP.md](ROADMAP.md) Phase 4, which currently says "workout
logger, weight history, adaptive TDEE" in three lines. This is those three lines
taken seriously, plus water and macro intake.

| # | Feature | Depends on |
|---|---|---|
| F1 | [Weight log with reminders](#f1--weight-log) | Storage |
| F2 | [PR page](#f2--pr-page) | Storage, exercise catalogue |
| F3 | [Workout page and splits](#f3--workout-page-and-splits) | F2, exercise catalogue, muscle map |
| F4 | [Water tracking](#f4--water-tracking) | Storage, notification scheduler |
| F5 | [Protein and macro intake](#f5--protein-and-macro-intake) | Storage |
| F6 | [Anime log](#f6--anime-log) | Storage |
| F7 | [Logging a workout from the watch](#f7--logging-a-workout-from-the-watch) | F3, WatchConnectivity |

---

## The rule that governs them all

Senku's premise is that it **shows its work** — see [PROJECT.md](PROJECT.md).
Every feature below inherits three obligations from it:

1. **Name the method.** A trend line says which smoothing it used. A coverage
   percentage says what it counted. An estimated 1RM says Epley, and shows the
   set it came from.
2. **Distinguish measured from estimated.** A logged weigh-in is not a trend
   value. A PR from a logged set is not a PR you typed in. A coverage figure for
   a *custom* exercise rests on muscles the user picked, and must say so.
3. **Refuse to be dangerous quietly.** A drop of more than 1% body weight a week
   sustained, a protein intake far under target, a water goal never met — these
   get advisories in the existing `Advisory` vocabulary, not silence.

---

## Shared foundations

These are not features. They are the things the rest need, and building any
feature before them means building them badly twice.

### S1 — Storage

`ProfileStore` holds one small value in `UserDefaults` as JSON. Every feature
here stores **many rows, queried by date**, which that cannot do.

- Move history onto **SwiftData**, which the roadmap has always named as the
  point at which `ProfileStore` stops being enough.
- `SenkuCore` stays pure and dependency-free. Models it owns (`BodyMetrics`,
  `RestTimer`, and the new pure types below) must not gain a persistence
  framework import. Persistence lives in a new layer — either the app target or
  a `SenkuData` package that depends on `SenkuCore`.
- Every screen reads through a repository protocol, so tests run against an
  in-memory store and `senku-render` keeps working without a container.
- The single profile stays in `ProfileStore`. Do not migrate it for its own
  sake.

**Widget and watch consequence.** A widget cannot open the app's SwiftData
container without the App Group, which the free build does not have — see
[XCODE_SETUP.md](XCODE_SETUP.md). Anything a widget must show (today's water,
today's protein) needs a small summary written to shared `UserDefaults`
alongside the real store, exactly as `RestTimerStore` already does.

### S2 — Notification scheduling

Rest already owns one identifier and reschedules cleanly (`RestNotifications`).
Two more repeating sources are coming, and iOS allows **64 pending requests per
app**. That cap is a hard design constraint, not a footnote.

- One scheduler owns all identifiers, namespaced: `senku.rest.*`,
  `senku.weighin.*`, `senku.water.*`.
- Water reminders are **rolling**: schedule only the remainder of today plus
  tomorrow, and top up whenever the app comes to the foreground or a background
  refresh fires. Never schedule a week of them.
- Every reminder is individually switchable, and a global "pause reminders"
  exists. A fitness app that cannot be told to be quiet gets deleted.
- Permission is requested **before** scheduling, never alongside it. That bug is
  already fixed once in this codebase; do not reintroduce it.

### S3 — What a day is

These features aggregate by day. Define it once: a day runs from **local
midnight to local midnight**, with a user-settable cutoff (default 00:00,
typical alternative 03:00 for late trainers). Store every timestamp as an
absolute `Date`; bucket at read time. Never store a "day string".

### S4 — Units

Unchanged from today: the core sees kilograms and centimetres only;
`UnitSystem` converts at the presentation layer. Bar weights, plate maths and
water volumes follow the same rule — SI in the model, user's choice on screen.

### S5 — Navigation

The tab view is `sidebarAdaptable` with customisation stored under
`senku.tabs.v1`, so new destinations are added as `Tab`s with stable
`customizationID`s and the user can reorder or pin them. Rest keeps
`.customizationBehavior(.disabled)`.

Proposed destinations after all five ship: **Me**, **Quick calc**, **Rest**,
**Workouts** (F3, with PRs inside it), **Intake** (F4 + F5 on one screen),
**Weight** (F1). That is six, which is past the iPhone tab bar's comfortable
five — expect the last to live in the overflow, and expect pinning to matter.

---

## F1 — Weight log

### Purpose

Turn the profile's single weight into a series, so the plan can be checked
against what actually happened rather than only projected forward.

### Data

```
WeighIn
  id: UUID
  date: Date            // absolute; bucketed per S3
  weightKG: Double      // SI, as everywhere
  source: .manual | .healthKit | .imported
  note: String?
```

### Rules

- **Multiple entries in a day are allowed**; the day's value for trend purposes
  is their mean. Discourage rather than forbid: weighing twice is noise, but
  refusing the entry is worse than absorbing it.
- The **trend** is an EWMA over daily values with a 7-day half-life
  (α ≈ 0.095). The chart shows raw points and the trend line, labelled, in the
  app's existing habit of saying which method ran.
- **The profile does not silently follow the scale.** When the trend differs
  from the profile weight by more than 0.5 kg, the Me tab offers a one-tap
  "Update profile to 78.6 kg (your 7-day trend)". The user's saved profile stays
  something they chose.
- **Adaptive TDEE** becomes available once there are ≥ 14 days of history with
  ≥ 8 weigh-ins. It compares observed weekly change against
  `NutritionPlan.projectedWeeklyChangeKG` and proposes a maintenance correction,
  **showing the arithmetic** — observed change, assumed 7,700 kcal/kg, implied
  daily delta. It is a suggestion with an Accept button, never an automatic
  rewrite of the plan.

### Reminders

- Frequency: daily, specific weekdays, or weekly, at a chosen time.
- The notification carries a **Log weight** action that opens straight into the
  entry field; ideally an `AppIntent` so the common case never needs the app on
  screen. Follow the rest timer's `LiveActivityIntent` precedent — work in the
  app's process, do not launch the UI for a single number.
- Suppressed for the day once a weigh-in exists.

### Screens

- **Weight** — chart (Swift Charts, raw + trend), current vs trend vs goal
  weight, weekly rate, and the goal-weight countdown the profile already
  computes via `projectedWeeksTo`.
- Entry sheet: number field, date, optional note. Swipe to delete, tap to edit.

### Acceptance

- [ ] Logging three days produces a trend that differs from the last reading
- [ ] Deleting the only weigh-in of a day removes it from the trend
- [ ] The profile weight never changes without an explicit tap
- [ ] Reminder does not fire on a day already logged
- [x] Adaptive TDEE refuses to appear under the data threshold (8 weigh-ins
      across 14 days, food logged on 10 of the last 14, and a difference of at
      least 100 kcal). It shows nothing rather than a caveated number, because a
      figure on screen gets believed regardless of the small print beside it.

---

## F2 — PR page

### Purpose

Every exercise you have ever loaded, with the most you have done on it. A
record, not a plan — it outlives whatever split you are currently running.

### Data

```
ExerciseID = String      // "catalogue.bench.flat" or "custom.<uuid>"

PersonalRecord
  exerciseID: ExerciseID
  weightKG: Double
  reps: Int
  date: Date
  source: .logged(setID)   // computed from a workout set
        | .manual          // asserted by the user
```

### Rules

- **Two kinds of PR, never blended.** A *logged* PR is derived from a set you
  recorded; a *manual* PR is one you typed. Both are kept. The headline figure
  is the better of the two, and the row says which it is. This is the measured/
  estimated distinction again, applied to lifting.
- **Heaviest and best e1RM are different questions**, so show both: heaviest
  weight at any rep count, and the best estimated one-rep max by **Epley**
  (`w × (1 + reps/30)`), naming the formula on screen.
- **PR history is append-only in practice.** A PR entry is deleted only by the
  user, from the PR page, with a confirmation.
- **The PR page is a superset of the workout page.** It lists every exercise
  with a record, whether or not any current split contains it. Editing a split
  never removes a record. This is the hard guarantee the feature exists for.
- Per-exercise detail: the PR timeline, the last few logged sets, and the
  muscles it trains (from F3's catalogue).
- Sort and filter: by muscle group, by recency, and a **stale** filter (no new
  PR in 60 days) — useful, and honest about what it means.

### Acceptance

- [ ] Removing an exercise from every split leaves its PR untouched
- [ ] A logged set heavier than the stored PR updates it without asking
- [ ] A manual PR below a logged PR is kept but not shown as the headline
- [ ] Deleting a workout session does not delete PRs it produced (they become
      `.manual`, dated as before — history you deleted is not a record you
      un-lifted). *Open question 4 — confirm this is the behaviour you want.*

---

## F3 — Workout page and splits

### Purpose

Choose today's split, pick the exercises, log the weight. Everything else in
this document exists to be fed by this screen.

### Data

```
Exercise                      // catalogue: bundled, read-only
  id, name
  equipment: .barbell | .dumbbell | .machine | .cable | .bodyweight
  contributions: [MuscleRegion: Double]   // 0…1 per region
  isCustom: Bool

CustomExercise                // user-created, same shape
  name, targetRegions: [MuscleRegion]     // picked from the list
  // contributions derived, and flagged as user-asserted

Split                         // user-defined, e.g. "Chest + triceps"
  name
  focus: [MuscleGroup]
  exerciseIDs: [ExerciseID]   // ordered

WorkoutSession
  date, splitID
  entries: [ (exerciseID, sets: [ (weightKG, reps, rpe?) ]) ]
```

### The muscle map

A two-level taxonomy, bundled as data in `SenkuCore` and testable without a UI:

- **Group** — chest, back, shoulders, biceps, triceps, legs, core.
- **Region** — chest splits into upper (clavicular), mid (sternal), lower
  (costal); back into lats, upper traps, mid traps/rhomboids, lower back; legs
  into quads, hamstrings, glutes, calves; and so on.
- Each region carries a **share** of its group, summing to 100% per group.
- Each exercise carries a **contribution** per region, 0–1, where 1 is "this
  exercise trains that region as its primary target".

### Coverage

For a given split, coverage answers: *if I do these exercises, how much of the
muscle I am training today actually gets trained?*

```
regionCoverage(r)  = min(1, Σ contributions of the split's exercises to r)
splitCoverage      = Σ over regions in focus: regionCoverage(r) × share(r)
```

- Shown as a percentage with a per-region breakdown, and — more usefully — the
  **gap**: "No lower-chest work. Decline press or dips would add 18%."
- The **ⓘ beside each exercise** shows: primary and secondary regions, that
  exercise's contribution figures, and its *marginal* effect on today's coverage
  (what you would lose by dropping it).
- For a **custom exercise**, contributions are derived from the regions the user
  picked (primary split evenly, capped at 1) and the info sheet says plainly
  that the numbers rest on their own classification, not a catalogue entry.
- **Coverage is not volume.** It says every region was touched, not that any of
  them got enough sets. Say so in the sheet, and keep sets-per-week guidance out
  of v1 — it is a separate, well-evidenced feature and deserves its own design.

### Two-way behaviour with F2

Stated exactly, because "two-way updatable" is the part most likely to be built
wrong:

| Action | Effect |
|---|---|
| Log a set heavier than the stored PR | PR updates, `source: .logged` |
| Add an exercise to a split | Appears on the PR page with "no record yet" |
| Remove an exercise from a split | **PR untouched.** Still on the PR page |
| Add a manual PR for an exercise in no split | Allowed. Lives on the PR page alone |
| Edit a manual PR | Never rewrites logged sets. History is immutable |
| Delete a custom exercise still referenced by a PR | Refused, with an explanation |

### Screens

- **Workouts** — today's split (or pick one), its exercises with last-time
  weight beside each, and the coverage bar for the day.
- Logging a set **auto-starts the rest timer** at that exercise's preferred
  interval. The timer already exists and is one tap away; this makes it zero.
- Split editor: rename, reorder, add and remove exercises, pick from the
  catalogue grouped by muscle, search, and "create custom exercise".

### Acceptance

- [ ] A chest split of flat bench alone reads well under 100%, and names the gap
- [ ] Adding incline and decline raises it, and the ⓘ shows each one's share
- [ ] A custom exercise is visibly marked as user-classified wherever it counts
- [ ] Logging a set starts the rest timer without a second tap
- [ ] Every rule in the table above has a test

---

## F4 — Water tracking

### Purpose

The plan already computes a daily water target and a training-day bump. Nothing
yet helps anyone hit it.

### Data

```
WaterEntry   { id, date, millilitres, containerID? }
Container    { id, name, millilitres }      // user-defined; defaults provided
WaterSettings{ goalOverrideML?, containers, reminder: ReminderSettings }
```

### Rules

- The goal comes from `plan.macros` — the existing daily target, plus the
  existing +500 ml on training days. A **training day** is one with a logged
  workout (F3); before F3 ships, it is a manual toggle.
- A manual goal override is allowed and is shown as an override, not as the
  computed number.
- Containers are configurable; ship sensible defaults (250 ml glass, 500 ml
  bottle, 750 ml bottle) and let the user edit them, in their own units.
- The bottle visual fills to `consumed / goal`, capped at full with the overage
  written out. It must have a **text equivalent** for VoiceOver and for anyone
  who cannot read a shape at a glance: "1,450 of 2,450 ml — 59%".

### Reminders

- Frequency: every N minutes or hours, within an active window (default
  08:00–22:00).
- Stop for the day once the goal is met — nagging past success is how a reminder
  gets switched off permanently.
- Snooze, and a per-notification "log a glass" action via `AppIntent` so the
  common case never opens the app.
- Rolling schedule per **S2**. This is the feature that will breach the 64-request
  cap if written naively.

### Acceptance

- [x] A past day can be marked "never logged" but never filled in
- [ ] Reminders stop once the goal is met and resume the next day
- [ ] Pending requests never exceed a documented ceiling well under 64
- [ ] The goal follows the profile when the profile changes
- [ ] Logging from the notification adds without launching the app

---

## F5 — Protein and macro intake

### Purpose

The app already says what to eat. This is whether you did.

### Data

```
IntakeEntry { id, date, name?, proteinG, carbsG, fatG, fiberG?, calories? }
Favourite   { id, name, macros }            // reusable quick-adds
```

### Rules

- Targets come from `plan.macros` — protein, carbs, fat, fiber and the calorie
  total. No second source of truth.
- **Calories are derived, not entered**: 4/4/9 per gram, computed from the
  macros, unless the user supplies a calorie figure that disagrees, in which
  case show both and say which is which.
- **Protein gets top billing.** It is the macro the app pushes hardest on a cut,
  it is what people actually track, and the request was "protein goal and intake
  tracking **along with** macros" — so protein is the headline number and the
  rest are secondary rings.
- Quick-add: favourites, plus a bare "+30 g protein" field. **No food database
  in v1** — that is a licensing and data problem, not an afternoon, and it is
  explicitly out of scope here.
- Advisories in the existing voice, e.g. protein under 80% of target for five
  consecutive days.
- Feeds F1's adaptive TDEE later: observed intake against observed weight change
  is a far better maintenance estimate than any formula. Worth designing for,
  not worth building until both halves exist.

### Acceptance

- [x] Targets change when the profile changes, with no copy kept
- [x] Derived calories and entered calories are never silently reconciled
- [x] A day with no entries reads as "nothing logged", not as "0 g — you failed"
- [ ] Yesterday can be edited; tomorrow cannot be logged

### Streaks

Two of them, protein and calories, because they are different questions — you
can hit protein on a day you ate 3,500 calories, and a single "nutrition" streak
would hide whichever one you are failing.

- **Protein is a floor.** At or above the target counts; over is not a failure.
- **Calories are a band**, ±10% of the target. Both edges are a miss: 900 under
  is not a better day than 100 under, it is the day that costs you the muscle the
  protein was protecting. Ten per cent is about the error in eyeballing a portion
  of rice — tighter and the streak measures your kitchen scales.
- Both are recomputed against current targets rather than recorded at the time,
  and an unlogged day is in neither streak.

---

## F6 — Anime log

### Purpose

What you are watching, where you are up to, and what you thought of it. Nothing
to do with training, and that is fine: this is a personal app, and the thing a
personal app can do that a product cannot is hold two unrelated parts of a life
without either being a compromise.

It is listed last on purpose. It shares the storage layer and nothing else, so
it can be built whenever, without blocking or being blocked by F1–F5.

### Data

```
Series
  id: UUID
  title: String
  totalEpisodes: Int?        // nil while airing, or unknown
  status: .watching | .completed | .paused | .dropped | .planned
  rating: Int?               // 1–10, only once there is an opinion
  startedAt: Date?
  finishedAt: Date?
  note: String?

Progress
  seriesID, episode: Int, watchedAt: Date
```

### Rules

- **Episode count is the unit**, not a percentage. "19 of 24" is what someone
  actually knows about where they are; a progress bar derived from it is
  decoration.
- A **series still airing has no total**, and the app must not invent one — the
  count reads "19" rather than "19 of ?" dressed up as completion.
- **Ratings are optional and never averaged into a score for the library.** A
  personal log is not a review site; the number means "what I thought", and an
  aggregate of your own opinions tells you nothing you did not already know.
- Marking an episode watched stamps it. The **history is the log**: re-watches
  append rather than overwrite, the same rule the PR page follows.
- Status is explicit rather than inferred. An app deciding you have "dropped"
  something because you have not opened it in a month is guessing at a feeling.

### Open questions

- **Where the metadata comes from.** Typing titles and episode counts by hand
  is fine for a personal list and tedious past twenty. AniList and MyAnimeList
  both publish APIs — AniList's is open GraphQL without a key, which makes it
  the obvious first choice — but that turns a local feature into one with a
  network dependency, a rate limit and a cache to invalidate.
- **Whether it belongs in Senku at all**, or is a second app sharing the same
  core. A training app with an anime tab is either charmingly personal or
  confused, depending entirely on who is holding it.

### Acceptance

- [ ] A series airing weekly can be advanced one episode with one tap
- [ ] A series with no known total never displays a completion percentage
- [ ] A re-watch does not erase the first watch
- [ ] Nothing here appears anywhere near the training or nutrition screens

---

## Suggested order

Each step ends with something usable, per the roadmap's own rule.

1. **S1 storage + S2 scheduler.** No UI. Unblocks everything.
2. **F1 weight log.** Smallest feature, exercises the whole storage layer, and
   pays off immediately against the goal weight already in the profile.
3. **Exercise catalogue + muscle map** (data and coverage maths in `SenkuCore`,
   with tests, no UI). The part most likely to be got wrong quietly.
4. **F2 PR page.** Readable value from step 3 with one screen.
5. **F3 workout page.** The big one. Splits, logging, coverage, rest-timer tie-in.
6. **F4 water.** Independent; could slot in earlier if you want a quick win.
7. **F5 macros.** Last of the training features, because it is most useful once
   weight history exists to correlate it against.
8. **F6 anime log.** Whenever. It touches nothing else, which is the whole
   reason it can wait — and the reason it can jump the queue on a slow evening
   without costing anything.

All eight are built. F7 was considered and dropped; see its section.


---

## F7 — Logging a workout from the watch — **dropped**

> **Not being built.** Decided 18 September 2026: the sync it needs is out of
> proportion to the convenience it buys. Two devices writing into one live
> session is the hardest problem in this app, and the phone is already in the
> gym bag. The design below is kept as a record of what was considered, not as
> a plan.

### Purpose

Log a set at the rack, without reaching for the phone. The phone is in a bag two
metres away, your hands are chalked, and the thing you want is one tap.

### Scope

- The watch shows **today's session** — the split already started on the phone,
  as a checklist, in the same muscle blocks the phone uses.
- Each exercise offers **one primary action: log a set**, pre-filled with the
  weight and reps of the previous set (today's, or last session's).
- **Reps are adjustable on the crown.** Weight is read-only.
- **No deleting and no editing** on the watch. Corrections are a phone job.
- Starting and finishing a session stay on the phone in v1. The watch logs into
  a session that already exists; with none, it says so and offers nothing.

### Why reps must be adjustable, though weight need not be

The original sketch for this had no editing at all — one button, last set's
numbers, done. Weight is genuinely stable within a session, so read-only there
costs nothing. **Reps are not.** A working set runs 8, 7, 5, and that fade is
the signal. A watch that could only repeat last time's figure would record 8, 8,
8 — a log of intentions rather than of training.

It is worse than inaccurate, because logged sets feed F2 automatically: a
repeated rep count manufactures personal records that were never hit. The crown
is already the watch's answer to "change a number", it is one gesture, and it
keeps the log honest.

### Sync: append-only, never shared mutable state

"Synced all the time" is not on offer. WatchConnectivity is opportunistic: the
phone app may be suspended, the watch may be off the wrist, and delivery is
eventually. A live workout is the hardest shape to sync — two devices appending
to one list — and it is exactly what the app has avoided so far (weigh-ins go
one way; rest timers are deliberately independent).

The shape that works is to treat **a logged set as an immutable event, not an
edit**:

- Every `LoggedSet` already carries a `UUID`.
- The watch sends *"this set was added to this exercise in this session"* with
  `transferUserInfo`, which is queued, ordered, and survives both apps being
  closed.
- The phone merges by **union of ids**. Re-delivery is harmless; ordering does
  not matter; no conflict is possible, because nothing is ever modified.
- Deletes stay phone-only for the same reason: a delete *is* a mutation, and
  allowing it from both ends brings back every problem this design avoids.

The phone stays the owner of the session and the only thing that writes history.

### Open questions

- Should the watch be able to **start** a session (pick today's split) as well
  as log into one? It is a small addition to this design and a large addition to
  the sync, since two devices could then start different sessions at once.
- What should the watch show when the phone has **no live session** — the day
  list read-only, or nothing?

---

## Open questions

These need your answer before the features they touch are built.

1. ~~**HealthKit.**~~ **Answered: no.** Stay self-contained. The payoff was
   weight arriving from a connected scale, workouts closing the Move ring, and
   real expenditure feeding the calorie target — and the cost was two sources of
   truth for weight, with the dedupe and provenance that implies, plus an
   entitlement a personal team may not even grant. Revisit only if a scale
   turns up.
2. ~~**iCloud sync.**~~ **Answered: no.** CloudKit is refused outright by a
   personal development team, so it is not available to this build at any price
   below a paid membership. The App Group plus the JSON export is the backup
   story. Revisit only if the account changes.
3. **Cutoff hour.** Is a 3 a.m. day boundary worth offering, or is midnight
   fine? (S3)
4. ~~**Deleting a workout session**~~ **Answered: PRs survive.** Already the
   behaviour on both paths — deleting a session leaves `RecordStore` untouched,
   and removing a single set calls `detachRecords(fromSets:)`, which keeps the
   record and downgrades its provenance from "logged" to "manual". The lift was
   still performed.
5. **Sets-per-week volume guidance.** Out of scope here. Do you want it as a
   sixth feature, given it is the thing coverage percentages will make people
   ask for?
6. ~~**Plate calculator**~~ **Built.** A page of its own, reached from the
   workout screen: type a weight and it draws the bar, plates sized and
   coloured by where they sit in your rack, with the per-side list counted
   ("45 ×2 · 25"). It began as a row inside the set logger and moved, because
   the logger is opened *after* a set — by which point the bar is loaded and
   the arithmetic is a fact rather than a question.
