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
