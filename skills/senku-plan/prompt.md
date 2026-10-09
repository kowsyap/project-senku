# Convert my workout plan into a Senku plan file

I'm attaching a workout plan. Turn it into ONE JSON file that the Senku iPhone app
imports. Importing replaces my training plan and adds any new exercises; nothing
else in the app changes.

## How to do it

1. **Read the plan.** Find the days, the exercises in each, and each exercise's sets and reps.
2. **Senku cannot store** weekdays, weights, rest times, tempo, RPE/RIR, supersets,
   drop sets, warm-ups, notes or week-by-week progression. Don't invent places for
   them. List what you dropped at the end. For a multi-week programme, ask which
   week to load (default: week 1). Keep A/B variants as separate days, and list
   repeated days once.
3. **Match every exercise to the catalogue below** and write its **Name exactly as
   listed**, copied character for character, not an alias. If the plan doesn't settle
   which of several catalogue exercises it means (e.g. "leg curl" = seated or lying?),
   **ask me before writing the file**, all questions in one message, with the options.
   Use the plan's clues (equipment, angle) when they do settle it.
4. **Sets and reps:** put the most common scheme in `plan.target`. Give an exercise
   its own numbers only where they differ. A range "8–12" is `minReps` 8, `maxReps` 12;
   a single "10" is `reps` 10. Sets 1–10, reps 1–50, whole numbers only. Pyramids
   (12/10/8) → range lowest–highest. AMRAP → leave on the plan's target. Holds
   (plank 60 s) → sets only. Cardio → name only.
5. **Not in the catalogue at all** → add to `customExercises` with a `name`, an
   `equipment` (barbell, dumbbell, kettlebell, machine, cable, bodyweight) and
   `regionIDs` from the muscle id table (main muscle first). Add `"isTimed": true` for holds.
   If the catalogue lists **my own exercises**, use one by naming it in the plan and
   copying its line into `customExercises` unchanged — the app keeps mine.
6. **Muscle groups per day** (optional): chest, back, shoulder, bicep, tricep,
   forearm, legs, abs, cardio.
7. **Check before answering:** every exercise name appears exactly in the catalogue
   or in your customExercises; every number is a whole number, not text; only
   `schemaVersion`, `plan` and `customExercises` at the top level.
8. **Answer with** the JSON file (as a downloadable file if you can, otherwise one
   code block), then a short list of each day with exercises and sets × reps, what
   you assumed, and what you dropped.

# The file format

One JSON object. Two sections, both optional, plus a version:

```json
{
  "schemaVersion": 1,
  "customExercises": [ ... ],
  "plan": { ... }
}
```

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
| legs.adductors | Adductors | legs |
| legs.abductors | Abductors | legs |
| abs.upper | Upper abs | abs |
| abs.lower | Lower abs | abs |
| abs.obliques | Obliques | abs |
| cardio.conditioning | Conditioning | cardio |
