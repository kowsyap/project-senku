---
name: senku-plan
description: Convert a workout plan (Excel, PDF, Word, CSV, text, or pasted) into a JSON file the Senku app imports to set up its training split — days, muscle groups, exercises matched to Senku's catalogue, sets and rep ranges, and custom exercises for anything the catalogue lacks. Use when someone types /senku-plan (with or without a file), or wants to load a training programme or split into Senku.
---

# Senku plan import

You turn someone's workout plan into **one JSON file** that the Senku iPhone app
imports. Importing it replaces their training plan and adds any new exercises.
Nothing else in the app changes: workouts, records, food and water are left alone.

The hard part is not the file format. It is reading a messy plan correctly and
matching every exercise to the right one in Senku's catalogue. **Never guess
between two real possibilities: ask.**

## The command: `/senku-plan`

Typing **`/senku-plan`** starts this skill in any AI, with a plan attached, a
file named after it (`/senku-plan my-plan.pdf`), or nothing at all. With
nothing, ask for the plan in one line: *"Attach your workout plan — PDF, Excel,
Word, a photo or text — or paste it here."* Then follow the steps below.
Plain requests such as "convert my plan for Senku" start it as well.

## What you have

| Path | What it is |
| --- | --- |
| `scripts/senku_plan.py` | Helper, Python 3 standard library only. `extract`, `find`, `list`, `regions`, `validate`. |
| `reference/format.md` | The file format, field by field. Read it before writing the file. |
| `reference/catalogue.md` | Every exercise Senku knows, with other names, plus the muscle ids. Use it if you cannot run the script. |
| `prompt.md` | The same job as one paste for a chat AI: instructions, format and exercises. Not needed when you have this file. |
| `examples/` | A plan as text and the file it becomes. |

Run the script from this folder, e.g. `python3 scripts/senku_plan.py find "lat pulldown"`.
Inside the Senku repository it reads the app's live catalogue automatically;
anywhere else it uses the copy in `data/`.

## Steps

### 1. Read the plan

- **xlsx, docx, pdf, csv, txt:** `python3 scripts/senku_plan.py extract FILE`.
  If you can read the file yourself (a PDF you can see, say), that works too.
  For a PDF laid out as a table, check rows did not run together.
- **.xls, .numbers, .pages, images:** read them directly if you can. Otherwise
  ask for an export as xlsx, csv or PDF, or for the text pasted in.

Find the **days** (Push, Pull, Legs; Day 1; Monday), the **exercises** in each,
and each exercise's **sets and reps**.

### 2. Settle what Senku cannot hold, before writing anything

Senku stores days, exercises in order, and sets × reps or a rep range. It does
**not** store weekdays, weights, rest times, tempo, RPE/RIR, supersets, drop
sets, warm-ups, notes, or week-by-week progression. Do not invent a place for
them. Collect what will be dropped and say so in your final message.

Ask the user (all at once, briefly) only where it changes the file:

- **A multi-week or periodised programme** (week 1–4 with changing reps): which
  week to load. Default to week 1 if they do not care.
- **Variants** (A/B days, "Upper 1 / Upper 2"): keep them as separate days.
- **Days that repeat** ("Push, Pull, Legs, Push, Pull, Legs"): Senku's plan is
  a list of distinct days chosen on the day, so list each distinct day once.

### 3. Match every exercise

For each exercise, `python3 scripts/senku_plan.py find "<name as written>"`
(or search `reference/catalogue.md`).

- **One clear match:** use its full catalogue **Name**.
- **Several plausible matches:** use the plan's own clues (equipment, angle,
  grip) and pick only if the plan settles it. "DB incline press" settles
  dumbbell and incline. "Leg curl" does not settle seated or lying, and "RDL"
  does not settle barbell or dumbbell: **ask.** Put all your questions in one
  message, each with the likely options.
- **No match:** it becomes a custom exercise (step 5). Check spelling,
  abbreviations and other names first. Most gym names are already in the
  catalogue as aliases.

Write exercises by their full catalogue **Name**, not an alias. Some aliases
belong to more than one exercise, and the app refuses those as ambiguous.

### 4. Work out sets and reps

- **The plan-wide target** is the scheme most exercises use, e.g. 3 × 8–12.
  Put it in `plan.target`.
- **Per exercise**, write numbers only where they differ from that target. An
  exercise with the plan's numbers is a plain name.
- A range "8–12" is `minReps` 8 and `maxReps` 12. A single "10" is `reps` 10.
  Sets go from 1 to 10 and reps from 1 to 50.
- **Pyramids** ("12, 10, 8"): the range is lowest to highest, `minReps` 8 and
  `maxReps` 12. Mention it.
- **AMRAP / to failure:** leave the exercise on the plan's target and mention it.
- **Holds** (plank 3 × 60 s): give sets only. The hold's seconds are logged in
  the app, not planned.
- **Cardio** (treadmill 20 min): just the name, no numbers.

How Senku uses the numbers: an exercise is **done** after its sets. When every
set at one weight reaches the **top** of the range, the next workout suggests a
heavier weight back at the bottom. So the ranges matter; copy them faithfully.

### 5. Custom exercises

For anything the catalogue truly lacks, add an entry to `customExercises`:

- `name`: how the plan says it, tidied ("Landmine Squeeze Press").
- `equipment`: one of `barbell`, `dumbbell`, `kettlebell`, `machine`, `cable`,
  `bodyweight`. Use `bodyweight` for bands and other kit outside those.
- `regionIDs`: the muscles it trains, main one **first**, since the first one
  decides its muscle group. Run `python3 scripts/senku_plan.py regions`.
- `isTimed: true` only for a hold measured in seconds.

The plan then names it like any other exercise. If the person already made the
same custom exercise in the app, the import keeps theirs and the plan uses it.

### 6. Muscle groups per day

`groups` is the day's intent, used for the coverage scores in the app:
`chest`, `back`, `shoulder`, `bicep`, `tricep`, `forearm`, `legs`, `abs`,
`cardio`. Plurals and capitals are fine. Give them when the day's name says
them (Push = chest, shoulder, tricep). Leave `groups` out to have them taken
from the exercises.

### 7. Write the file, then check it

Follow `reference/format.md`. Save it as `senku-plan.json`, or name it after the
plan, then run:

```
python3 scripts/senku_plan.py validate senku-plan.json
```

- **✗ refused** or **✗ problems:** fix every one and run it again. Repeat until
  it prints **✓**. Never hand over a file that has not passed.
- **Notes** are not errors, but read them. A clamped number or a skipped
  duplicate custom exercise may mean you misread the plan.

**If you cannot run code**, check by hand against `reference/format.md` and
`reference/catalogue.md`: every name exactly as listed, whole numbers only.
Then tell the user to run the `validate` line above themselves before
importing. The app also reports anything it skips.

### 8. Hand it over

Give the file, then a short message with:

1. **The plan as it will appear:** each day with its exercises and sets × reps.
   The `validate` output is a good base.
2. **What was dropped** (step 2) and **what was assumed** (pyramids, AMRAP,
   any matches you chose).
3. **How to import:**
   1. Get the file onto the iPhone, for example with AirDrop or Files.
   2. In Senku, press and hold the **SENKU** logo at the top of any screen for
      a second.
   3. Choose the file.
4. **The warning:** importing **replaces the current plan**. Workouts, records
   and everything else stay.

## Rules

- One file, holding only `plan` and `customExercises` (plus `schemaVersion: 1`).
  Never add profile, records, workouts, water or food sections. Those would be
  imported too.
- Full catalogue names. Ask rather than guess between variants. Every custom
  exercise has at least one valid muscle id.
- Never claim the file is ready if `validate` has not printed ✓, unless you
  could not run it and said so.
