# Worked example

`ppl-plan.txt` is a plan as people write them. `ppl-plan.senku.json` is the
file this skill makes from it, and it passes `validate`.

## What was asked

- **"Tricep pushdown"**: bar or rope? Answer: rope, giving *Rope Triceps Pushdown*.
- **"Lateral raises"**: dumbbell, cable or machine? Answer: dumbbell, giving
  *Dumbbell Lateral Raise*.

## What was assumed, and said

- **Target for the week:** 3 × 8–12, the most common scheme. Exercises with
  other numbers carry their own.
- **"Deadlift":** taken as *Conventional Deadlift*, since an unqualified
  deadlift means that.
- **"Pull ups 3xAMRAP":** Senku has no AMRAP, so it uses the week's 3 × 8–12.
- **"Plank 3x60s":** three sets. The seconds are logged in the app as you hold
  it.

## What Senku does not keep

- "6 week hypertrophy": there is no programme length.
- The "Day 1, Day 2, Day 3" numbering: you choose the day when you train.

# Made from scratch

`made-upper-lower.senku.json` is a plan made in the skill's other mode, for
these answers: build muscle, 4 days a week, 60 minutes, full gym, some
experience, nothing to avoid.

- **Shape:** Upper / Lower, with A and B versions of each so the same muscles
  get different exercises.
- **Volume:** checked with `volume --days-per-week 4`. The first draft had
  chest, side delts and triceps under 10 sets a week; an extra set on bench,
  incline press, lateral raises and pushdowns, and a cable lateral raise in
  Upper B, brought every main muscle to 10–18.
- **Sets and reps:** 3 × 8–12 for most; the first compound each day at 6–10;
  isolation at 10–15.
- **Guidance given with it:** rest about 2–3 minutes after heavy compounds and
  1–2 after the rest; stop most sets with 1–3 reps in hand; train the days in
  order and start again.
