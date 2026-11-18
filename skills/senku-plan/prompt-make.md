# Make me a workout plan for the Senku app

Design a training week for me and give it to me as ONE JSON file that the Senku
iPhone app imports. Importing replaces my training plan; nothing else in the app
changes.

## How to do it

1. **Ask me first, one question at a time**, each with numbered options and
   the recommended one first (see "Designing a plan", step 1, below). Wait for
   my answer before asking the next. If I already told you something, don't
   ask it again. If I say "defaults", use the recommended answers for the rest.
2. **Design the week** following "Designing a plan" below: the split I chose,
   the movement patterns, volume, order, sets and reps, and exercises my
   equipment allows.
3. **Use only exercises from the catalogue below**, each written by its
   **Name exactly as listed**, copied character for character. If the catalogue
   lists **my own exercises**, you may use those too: name one in the plan and
   copy its line into `customExercises` unchanged.
4. **Write the file** as described in "The file format" below: `plan.target`
   holds the most common scheme, exercises with other numbers carry their own.
   Whole numbers only. Holds get sets only; cardio gets its name only. Copy the
   catalogue version into `catalogueVersion`.
5. **Check before answering:** every exercise name appears exactly in the
   catalogue (or my own exercises); every number is a whole number, not text;
   the top level has only `schemaVersion`, `catalogueVersion`, `plan` and
   `customExercises`. Count the hard sets each major muscle gets in a week at
   my number of training days; adjust anything far below 10, above 20, or hit
   only once a week when I train 3 or more days (unless I chose a once-a-week
   split).
6. **Answer with** the JSON file (as a downloadable file if you can, otherwise
   one code block), then: which split it is and why, each day with its
   exercises and sets × reps, how to run it (train the days in order, then
   start again), and the short guidance from "Designing a plan", step 8.

# Designing a plan

How to build a week from scratch when there is no plan to convert. The result
is the same file as a conversion, in the same format, with every exercise named
exactly as the catalogue lists it.

These are mainstream, well-tested starting points, not the only right answers.
A sensible plan the person will follow beats a perfect one they will not.

## 1. Ask, one question at a time

Ask **one question per message**, each with numbered options to pick from, the
recommended one first and marked. Wait for the answer, then ask the next. Later
questions depend on earlier answers (the split options depend on the days, the
equipment follow-up on the equipment), so this order matters:

1. **Main goal:** 1. Build muscle *(recommended)* · 2. Get stronger ·
   3. General fitness · 4. Lose fat
2. **Days a week:** 2 · 3 · 4 *(recommended)* · 5 · 6. Number these by the
   day count itself (2. Two days, 3. Three days…), never 1 to 5: a reply of
   "2" must mean two days.
3. **Split:** the options for their number of days, from the table in step 2,
   with *Pick the best for me* first. Give each a few words on what it means
   for them, such as "each muscle twice a week".
4. **Time per session:** 1. 30 min · 2. 45 min · 3. 60 min *(recommended)* ·
   4. 75 min · 5. 90 min or more
5. **Equipment:** 1. Full gym *(recommended)* · 2. Home, with dumbbells ·
   3. Bodyweight only
   - **Only if home:** what else they have, more than one allowed: a bench, a
     pull-up bar, a kettlebell, none of these.
6. **Experience:** 1. Some, 6 months to 2 years *(recommended)* · 2. New, under
   6 months · 3. Lots, over 2 years
7. **Anything to avoid:** 1. Nothing *(recommended)* · 2. Yes
   - **Only if yes:** what, in their words: an injury, a movement, exercises
     they dislike.
8. **Focus:** 1. None, balanced *(recommended)* · or any of: chest, back,
   shoulders, arms, legs, glutes, abs (more than one allowed).
9. **Health check:** 1. None of these apply *(recommended)* · 2. Something
   applies: pain right now, chest pain or dizziness when exercising, a heart or
   other medical condition, pregnancy, or being under 18.
   - **If something applies:** say plainly that they should check with a doctor
     before training hard, and keep the plan conservative.

Rules for asking:

- **Skip** any question already answered in what they said ("a 4-day plan" has
  answered question 2).
- They can answer with the number, the words, or anything in between.
- If they say "defaults", "you choose" or similar, take the recommended answer
  for every question left and go on.
- **Use selectable options whenever the tool you run in can show them** (a
  question the person answers by tapping a choice, such as Claude Code's
  question tool). Only write the numbered list where it cannot.
- Keep each question to one line plus its options. No preamble.

## 2. The split

Senku lists each **distinct** day once and the person picks one each time they
train, cycling through. So a six-day push/pull/legs is three days in the file.

Offer these for question 3, the recommended one first:

| Days a week | Options | Days in the file |
| --- | --- | --- |
| 2 | **Full body A/B** (each muscle twice) · Upper / Lower (each muscle once) | 2 |
| 3 | **Full body A/B/C** (each muscle 2–3 times) · Upper / Lower / Full (about twice) · Push / Pull / Legs (once, longer sessions) · Chest+Back / Arms+Shoulders / Legs (once) | 3 |
| 4 | **Upper / Lower, twice** (each muscle twice) · Push / Pull / Legs / Upper (2 for the upper body, 1 for legs) · Full body A/B, twice (twice, shorter sessions) | 4 |
| 5 | **Upper / Lower + Push / Pull / Legs** (each muscle about twice) · Push / Pull / Legs / Upper / Lower (the same, in another order) · One group a day (once, the most per session) | 5 |
| 6 | **Push / Pull / Legs, twice** (each muscle twice) · Upper / Lower, three times (three times, shorter sessions) · Chest+Back / Arms+Shoulders / Legs, twice (twice) | 3 or 6 |

*Pick the best for me* means the first one. For building muscle, every
muscle twice a week beats once, which is why the first option is first. If they
choose a once-a-week split, make it work: more sets per muscle in that one
session.

Prefer A/B variants over identical repeats when there is room: the same muscles
with different exercises spreads the work across angles.

When handing the plan over, say which split it is and, in a line, why: their
choice, or why it fits their days.

Tell the person how to run it in the app: "Train them in order and start again
at the top."

## 3. Cover the basics every week

Across the week, include at least one of each movement pattern:

- **Squat** (squat, leg press, split squat, lunge)
- **Hinge** (deadlift, Romanian deadlift, hip thrust, back extension)
- **Horizontal push** (bench, push-up, chest press)
- **Horizontal pull** (rows)
- **Vertical push** (overhead press)
- **Vertical pull** (pulldown, pull-up)

Then add isolation work for what those miss: side and rear delts, biceps,
triceps, calves, hamstring curls, abs.

## 4. Volume and frequency

- Aim for each major muscle (chest, back, shoulders, biceps, triceps, quads,
  hamstrings, glutes) to be trained **twice a week** where the days allow.
- Aim for roughly **10–20 hard sets per muscle per week**. Beginners can start
  nearer 8; more is not better past about 20.
- **Exercises per session** from the time available, at about 3 sets of each:

| Time | Exercises |
| --- | --- |
| 30 min | 3–4 |
| 45 min | 4–5 |
| 60 min | 5–6 |
| 75+ min | 6–8 |

Count the hard sets per muscle for the week yourself before answering.

## 5. Order within a day

1. The heaviest compound first (squat, deadlift, bench, row).
2. Other compounds.
3. Isolation.
4. Abs, carries or conditioning last.

Do not put two hard exercises for the same small muscle back to back unless the
day is built around it.

## 6. Sets and reps by goal

| Goal | Big compounds | Other compounds | Isolation |
| --- | --- | --- | --- |
| Build muscle | 3 × 6–10 | 3 × 8–12 | 3 × 10–15 |
| Get stronger | 4 × 3–6 | 3 × 6–8 | 3 × 8–12 |
| General fitness | 3 × 8–12 | 3 × 8–12 | 2–3 × 12–15 |
| Lose fat | as build muscle; keep the heavy work, it keeps the muscle | | |

Put the most common scheme in `plan.target` and give only the others their own
numbers. Ranges suit Senku: when every set reaches the top at one weight, the
app suggests the next weight up and the range starts again. That is the whole
progression, so there is nothing else to write.

Beginners: 2–3 sets per exercise, fewer exercises, and more machines and
dumbbells than heavy barbell lifts.

## 7. Choosing exercises

- **Only from the catalogue**, by full Name, and only ones the equipment allows:

| Equipment answer | Use exercises with equipment |
| --- | --- |
| Full gym | anything |
| Home with dumbbells | `dumbbell`, `bodyweight` (and `kettlebell` if they have one). Bench exercises only if they have a bench. |
| Bodyweight only | `bodyweight` |

- Respect **avoid**: no exercise that loads the injured area, and say what you
  swapped.
- Add one extra exercise (or 2–4 sets) for a **focus** muscle, not a whole day.
- Prefer exercises most gyms have. Don't build a home plan around a pull-up bar
  unless they said they have one; use a row instead.
- Holds (plank, dead hang) and cardio go at the end. Cardio is named only, no
  numbers.

## 8. Hand it over

Besides the file and a list of each day with its exercises and sets × reps,
add short, practical guidance Senku does not store:

- **Rest:** about 2–3 minutes after heavy compounds, 1–2 after the rest. (Senku
  can start a rest timer after each set: Workout → Your Week → Rest.)
- **Effort:** finish most sets with about 1–3 good reps left in the tank.
- **Starting weights:** pick a weight that reaches the bottom of the range with
  good form; the app takes it from there.
- **Stop and see a doctor** for chest pain, fainting, or sharp joint pain.

Keep it to a few lines. This is not medical advice and should not read like it.

# The file format

One JSON object. Two sections, both optional, plus a version:

```json
{
  "schemaVersion": 1,
  "catalogueVersion": "1a2b3c4d",
  "customExercises": [ ... ],
  "plan": { ... }
}
```

`catalogueVersion` is optional: copy it from the top of the exercise catalogue.
If the app's exercise list has changed since, it says so on import, so a name
it no longer knows is explained rather than mysterious.

Unknown keys are ignored. **A wrong type refuses the whole file**: `"3"` where a
number belongs, `3.0` instead of `3`, or a day without a `name`. A name the app
cannot match only skips that one exercise, and the import says so.

## `plan`

```json
"plan": {
  "target": { "sets": 3, "minReps": 8, "maxReps": 12 },
  "days": [ { ... }, { ... } ]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `target` | no | Sets and reps for every exercise without its own. Missing → 3 × 10. |
| `days` | **yes** | The training days, in order. Importing replaces the app's plan with these. |

### A target

| Field | Meaning |
| --- | --- |
| `sets` | Whole number, 1–10. Required in `plan.target`. |
| `reps` | Whole number, 1–50: the single figure, or the bottom of a range. |
| `minReps` | Another name for `reps`, for writing a range clearly. |
| `maxReps` | Top of the range, above `reps`. Leave out for a single figure. |

`{ "sets": 3, "reps": 10 }` is 3 × 10. `{ "sets": 3, "minReps": 8, "maxReps": 12 }` is 3 × 8–12.
Out-of-range numbers are clamped, and `maxReps` at or below `reps` is dropped.

## A day

```json
{
  "name": "Push",
  "groups": ["chest", "shoulder", "tricep"],
  "exercises": [
    "Incline Dumbbell Press",
    { "name": "Barbell Bench Press", "sets": 4, "minReps": 6, "maxReps": 8 },
    { "name": "Dumbbell Lateral Raise", "minReps": 12, "maxReps": 15 }
  ]
}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | **yes** | What the day is called in the app. |
| `groups` | no | Muscle groups the day is for: `chest` `back` `shoulder` `bicep` `tricep` `forearm` `legs` `abs` `cardio`. Plurals and capitals are fine. Missing → taken from the exercises. |
| `exercises` | no | In order. Each is a **name**, or an **object** with `name` and its own numbers. |

An exercise object can give any of `sets`, `reps`/`minReps` and `maxReps`. What it
leaves out comes from `plan.target`:

| Plan target | Exercise says | Exercise gets |
| --- | --- | --- |
| 3 × 8–12 | `"sets": 5, "reps": 5` | 5 × 5 |
| 3 × 8–12 | `"sets": 4` | 4 × 8–12 |
| 3 × 8–12 | `"maxReps": 15` | 3 × 8–15 |
| 3 × 8–12 | `"reps": 6` | 3 × 6 (a single figure, not 6–12) |

Names are matched whole: by catalogue id, by full name, or by an alias, with
capitals, spaces, hyphens and a plural *s* forgiven. "Bench" matches Barbell
Bench Press; "Curl" matches nothing. An alias shared by two exercises ("RDL")
is refused as ambiguous, so **write full names**.

The app's own backups write `exerciseIDs` (a list of ids) and `targets` (an
object of id → target) instead of `exercises`. Both are read; there is no need
to write them.

## `customExercises`

```json
"customExercises": [
  { "name": "Landmine Squeeze Press", "equipment": "barbell",
    "regionIDs": ["chest.mid", "shoulder.frontDelts"] },
  { "name": "Copenhagen Plank", "equipment": "bodyweight",
    "regionIDs": ["legs.adductors"], "isTimed": true }
]
```

| Field | Required | Meaning |
| --- | --- | --- |
| `name` | **yes** | Shown in the app; also how the plan names it. |
| `equipment` | **yes** | `barbell` `dumbbell` `kettlebell` `machine` `cable` `bodyweight`. |
| `regionIDs` | **yes** | Muscle ids (see the muscle id table at the end). The **first** decides its muscle group. Unknown ids are dropped; none left means it is not added. |
| `isTimed` | no | `true` for a hold measured in seconds. |

Custom exercises are added before the plan is read, so the plan can name them.
One whose name already exists (in the catalogue, or made earlier in the app) is
not added again. The existing one is used.

# Senku exercise catalogue

Name exercises in a plan by **Name** (an alias works too, unless it is shared).
Anything not listed here goes in `customExercises`.

Catalogue version: `6af8c6ff`. Copy it into the file as `catalogueVersion`.

## back

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Back Extension | Hyperextension, Roman Chair | bodyweight |  |
| Barbell Bent-Over Row | Barbell Row, BB Row | barbell |  |
| Barbell Shrug |  | barbell |  |
| Cable Shrug |  | cable |  |
| Chest-Supported Dumbbell Row |  | dumbbell |  |
| Chin-Up |  | bodyweight |  |
| Dumbbell Pullover |  | dumbbell |  |
| Dumbbell Shrug |  | dumbbell |  |
| Inverted Row | Australian Pull-Up, Body Row | bodyweight |  |
| Machine Back Extension | Back Extension Machine, Lower Back Machine, Seated Back Extension, Lumbar Extension | machine |  |
| Machine Row |  | machine |  |
| Meadows Row |  | barbell |  |
| Muscle-Up |  | bodyweight |  |
| Neutral-Grip Lat Pulldown | V-Bar Pulldown, Close-Grip Pulldown | cable |  |
| Neutral-Grip Pull-Up |  | bodyweight |  |
| Pendlay Row |  | barbell |  |
| Pull-Up |  | bodyweight |  |
| Rack Pull |  | barbell |  |
| Seal Row | Prone Row, Bench Row | barbell |  |
| Seated Cable Row | Cable Row, Low Row | cable |  |
| Silverback Shrug |  | barbell |  |
| Single-Arm Dumbbell Row |  | dumbbell |  |
| Single-Arm Lat Pulldown | One-Arm Lat Pulldown | cable |  |
| Straight-Arm Cable Pulldown | Straight-Arm Pulldown | cable |  |
| T-Bar Row |  | barbell |  |
| Wide-Grip Lat Pulldown | Lat Pulldown, Pulldown | cable |  |

## bicep

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Barbell Curl |  | barbell |  |
| Bayesian Cable Curl | Bayesian Curl | cable |  |
| Cable Curl |  | cable |  |
| Concentration Curl |  | dumbbell |  |
| Drag Curl |  | barbell |  |
| Dumbbell Curl |  | dumbbell |  |
| EZ-Bar Curl |  | barbell |  |
| Hammer Curl |  | dumbbell |  |
| Incline Dumbbell Curl |  | dumbbell |  |
| Preacher Curl | Scott Curl | barbell |  |
| Spider Curl |  | dumbbell |  |

## tricep

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Bar Triceps Pushdown |  | cable |  |
| Bench Dip |  | bodyweight |  |
| Cable Triceps Kickback |  | cable |  |
| Close-Grip Bench Press | CGBP | barbell |  |
| Diamond Push-Up |  | bodyweight |  |
| Dumbbell Skull Crusher | Lying Dumbbell Triceps Extension | dumbbell |  |
| JM Press |  | barbell |  |
| Lying EZ-Bar Triceps Extension | Skull Crusher, French Press, Lying Triceps Extension | barbell |  |
| Machine Triceps Extension |  | machine |  |
| Overhead Cable Triceps Extension | Cable Overhead Extension | cable |  |
| Overhead Dumbbell Triceps Extension | Dumbbell Overhead Extension, Seated French Press | dumbbell |  |
| Rope Triceps Pushdown | Rope Pushdown | cable |  |
| Tate Press |  | dumbbell |  |
| Triceps-Focused Dip |  | bodyweight |  |

## forearm

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Dead Hang | Bar Hang, Hang | bodyweight | held (seconds) |
| Farmer's Carry | Farmer's Walk, Loaded Carry | dumbbell | held (seconds) |
| Reverse Curl |  | barbell |  |
| Reverse Wrist Curl | Wrist Extension | dumbbell |  |
| Wrist Curl | Forearm Curl | dumbbell |  |
| Zottman Curl |  | dumbbell |  |

## chest

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Barbell Bench Press | Bench, Flat Bench | barbell |  |
| Cable Chest Press |  | cable |  |
| Cable Fly |  | cable |  |
| Chest-Focused Dip |  | bodyweight |  |
| Decline Barbell Bench Press | Decline Bench | barbell |  |
| Deficit Push-Up |  | bodyweight |  |
| Dumbbell Bench Press | DB Bench, Dumbbell Press | dumbbell |  |
| Dumbbell Fly |  | dumbbell |  |
| High-to-Low Cable Fly |  | cable |  |
| Incline Barbell Bench Press | Incline Bench | barbell |  |
| Incline Dumbbell Press | Incline DB Press | dumbbell |  |
| Incline Machine Press |  | machine |  |
| Low-to-High Cable Fly |  | cable |  |
| Machine Chest Press |  | machine |  |
| Pec Deck Fly | Machine Fly, Butterfly | machine |  |
| Push-Up | Press-Up | bodyweight |  |

## legs

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Barbell Back Squat | Squat, Back Squat | barbell |  |
| Barbell Front Squat |  | barbell |  |
| Barbell Hip Thrust |  | barbell |  |
| Barbell Romanian Deadlift | RDL, Romanian Deadlift | barbell |  |
| Belt Squat |  | machine |  |
| Box Jump |  | bodyweight |  |
| Bulgarian Split Squat | BSS, Rear-Foot-Elevated Split Squat | dumbbell |  |
| Cable Glute Kickback | Glute Kickback, Donkey Kick | cable |  |
| Cable Pull-Through |  | cable |  |
| Conventional Deadlift |  | barbell |  |
| Dumbbell Romanian Deadlift | DB RDL, RDL | dumbbell |  |
| Glute Bridge |  | bodyweight |  |
| Goblet Squat |  | dumbbell |  |
| Good Morning |  | barbell |  |
| Hack Squat |  | machine |  |
| Hip Abduction Machine | Abductor Machine | machine |  |
| Hip Adduction Machine | Adductor Machine | machine |  |
| Kettlebell Swing | KB Swing, Russian Swing | kettlebell |  |
| Leg Extension | Quad Extension | machine |  |
| Leg Press |  | machine |  |
| Leg Press Calf Raise |  | machine |  |
| Lying Leg Curl | Hamstring Curl | machine |  |
| Nordic Hamstring Curl |  | bodyweight |  |
| Pendulum Squat |  | machine |  |
| Reverse Lunge |  | dumbbell |  |
| Seated Calf Raise |  | machine |  |
| Seated Leg Curl | Hamstring Curl | machine |  |
| Single-Leg Press |  | machine |  |
| Sissy Squat |  | bodyweight |  |
| Smith Machine Squat |  | machine |  |
| Standing Calf Raise |  | machine |  |
| Step-Up |  | dumbbell |  |
| Sumo Deadlift |  | barbell |  |
| Tibialis Raise | Tib Raise, Tib Bar Raise, Tibialis Curl | bodyweight |  |
| Trap Bar Deadlift | Hex Bar Deadlift | barbell |  |
| Walking Lunge |  | dumbbell |  |
| Wall Sit |  | bodyweight | held (seconds) |

## shoulder

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Arnold Press |  | dumbbell |  |
| Barbell Overhead Press | OHP, Military Press, Standing Press | barbell |  |
| Cable Lateral Raise |  | cable |  |
| Cable Rear Delt Fly |  | cable |  |
| Dumbbell Front Raise |  | dumbbell |  |
| Dumbbell Lateral Raise | Side Raise, Side Lateral Raise, Lat Raise | dumbbell |  |
| Dumbbell Reverse Fly |  | dumbbell |  |
| Dumbbell Shoulder Press | Seated Dumbbell Press, DB Shoulder Press | dumbbell |  |
| Face Pull |  | cable |  |
| Landmine Press |  | barbell |  |
| Machine Lateral Raise |  | machine |  |
| Machine Shoulder Press |  | machine |  |
| Push Press |  | barbell |  |
| Reverse Pec Deck | Rear Delt Machine, Rear Delt Fly | machine |  |
| Upright Row |  | barbell |  |

## abs

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Ab Wheel Rollout | Ab Roller | bodyweight |  |
| Bicycle Crunch |  | bodyweight |  |
| Cable Crunch |  | cable |  |
| Cable Side Bend |  | cable |  |
| Cable Woodchop |  | cable |  |
| Crunch |  | bodyweight |  |
| Dead Bug |  | bodyweight |  |
| Dragon Flag |  | bodyweight |  |
| Flutter Kick |  | bodyweight |  |
| Hanging Knee Raise |  | bodyweight |  |
| Hanging Leg Raise |  | bodyweight |  |
| Hollow Hold |  | bodyweight | held (seconds) |
| Lying Leg Raise |  | bodyweight |  |
| Machine Crunch |  | machine |  |
| Mountain Climber |  | bodyweight |  |
| Pallof Press | Anti-Rotation Press | cable |  |
| Plank |  | bodyweight | held (seconds) |
| Reverse Crunch |  | bodyweight |  |
| Russian Twist |  | bodyweight |  |
| Side Plank |  | bodyweight | held (seconds) |
| Sit-Up |  | bodyweight |  |
| V-Up | Jackknife | bodyweight |  |

## cardio

| Name | Also called | Equipment | Notes |
| --- | --- | --- | --- |
| Air Bike | Assault Bike, Echo Bike, Fan Bike | machine | cardio |
| Battle Ropes | Battle Rope | bodyweight | cardio |
| Cycling |  | machine | cardio |
| Elliptical | Cross Trainer | machine | cardio |
| HIIT Circuit |  | bodyweight | cardio |
| Incline Walk | 12-3-30 | machine | cardio |
| Rowing Machine | Rower, Erg | machine | cardio |
| Running (outdoor) | Jog, Jogging | bodyweight | cardio |
| Ski Erg |  | machine | cardio |
| Skipping | Jump Rope | bodyweight | cardio |
| Sprint Intervals |  | bodyweight | cardio |
| Stair Climber | StairMaster, Stepmill | machine | cardio |
| Swimming |  | bodyweight | cardio |
| Treadmill |  | machine | cardio |
| Walking |  | bodyweight | cardio |

## Muscle ids (for customExercises.regionIDs)

| id | Muscle | Group |
| --- | --- | --- |
| chest.upper | Upper chest | chest |
| chest.mid | Mid chest | chest |
| chest.lower | Lower chest | chest |
| back.lats | Lats | back |
| back.upperTraps | Upper traps | back |
| back.midBack | Mid back | back |
| back.lowerBack | Lower back | back |
| bicep.biceps | Biceps | bicep |
| bicep.brachialis | Brachialis | bicep |
| tricep.longHead | Triceps long head | tricep |
| tricep.lateralHead | Triceps lateral head | tricep |
| tricep.medialHead | Triceps medial head | tricep |
| forearm.flexors | Grip & wrist flexors | forearm |
| forearm.brachioradialis | Brachioradialis | forearm |
| forearm.extensors | Wrist extensors | forearm |
| shoulder.frontDelts | Front delts | shoulder |
| shoulder.sideDelts | Side delts | shoulder |
| shoulder.rearDelts | Rear delts | shoulder |
| legs.quads | Quads | legs |
| legs.hamstrings | Hamstrings | legs |
| legs.glutes | Glutes | legs |
| legs.calves | Calves | legs |
| legs.tibialis | Tibialis | legs |
| legs.adductors | Adductors | legs |
| legs.abductors | Abductors | legs |
| abs.upper | Upper abs | abs |
| abs.lower | Lower abs | abs |
| abs.obliques | Obliques | abs |
| cardio.conditioning | Conditioning | cardio |
