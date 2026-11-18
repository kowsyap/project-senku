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

Check the week with `python3 scripts/senku_plan.py volume FILE --days-per-week N`.
It counts weekly sets per muscle from the catalogue's own muscle data and flags
what is under-trained, over-trained or hit only once.

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
