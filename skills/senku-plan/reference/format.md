# The plan file

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
| `regionIDs` | **yes** | Muscle ids (`scripts/senku_plan.py regions`). The **first** decides its muscle group. Unknown ids are dropped; none left means it is not added. |
| `isTimed` | no | `true` for a hold measured in seconds. |

Custom exercises are added before the plan is read, so the plan can name them.
One whose name already exists (in the catalogue, or made earlier in the app) is
not added again. The existing one is used.
