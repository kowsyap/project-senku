# Senku — Project Definition

## The idea in one line

A science-based training and nutrition companion for iPhone, Mac and Apple Watch
that **shows its work** — every number it gives you comes with the formula it
used and the caveats that apply.

## Why "shows its work" is the whole product

There are hundreds of macro calculators. Almost all of them hand you a number
with no explanation, no indication of which formula produced it, and no warning
when the number is a bad idea for you specifically.

Senku is named after a scientist, and that sets the design rule for everything:

- **Name the formula.** Mifflin-St Jeor, Katch-McArdle, Harris-Benedict — the
  user can see which one ran and switch it.
- **Distinguish measured from estimated.** A body fat figure you measured and one
  guessed from your BMI are not the same input, and the app never blurs them.
- **Refuse to be dangerous quietly.** A deficit that lands under 1,200/1,500 kcal
  gets clamped, and the app says so rather than silently serving the number.
- **Show the whole ladder, not one number.** Maintenance at every activity level,
  so you can see what changing your training actually does.

This is already implemented in `SenkuCore` — see `NutritionPlan.advisories` and
`EnergyProfile.formulaUsed`.

## Who it is for

| Audience | Need | How Senku serves it |
|---|---|---|
| **You, the owner** | A persistent profile you update over months | Saved profile, trend history, adaptive TDEE |
| **A friend who asks "what should I eat?"** | One answer, right now, no account | Guest mode: calculate, show, discard |
| **Someone mid-workout** | Rest timing without fiddling | Watch app + Live Activity + widget |

The guest/saved split you described is a real product decision, not just a
storage detail: guest mode has **no onboarding, no account, no persistence**, and
that is what makes the app shareable in a gym conversation.

---

## Feature set

### V1 — the core loop

**1. Nutrition targets** *(core logic complete)*

Input: sex, age, height, weight, optional body fat, activity level, goal.

Output:
- BMR and resting metabolic rate
- Maintenance at all five activity levels
- Target calories for the chosen goal, with a safety floor
- Protein / carbs / fat in grams and percentages
- Fiber and daily water, plus a training-day water bump
- BMI, lean mass, fat mass, healthy weight range
- Projected weekly change and time-to-target-weight
- Advisories when the plan deserves a caveat

Goals span aggressive cut through aggressive bulk as **percentages of
maintenance**, so the adjustment scales with body size instead of applying a flat
500 kcal to everyone.

**2. Guest mode vs saved profile**

- **Guest**: fill in, get results, nothing is written to disk. A "Save this as my
  profile" button is offered but never assumed.
- **Saved**: profile persists, feeds every other feature, syncs across devices.

**3. Rest timer**

- Presets (60s / 90s / 2m / 3m / 5m) plus a custom value
- Runs on the lock screen as a **Live Activity**, with Dynamic Island support
- **Home Screen widget** and an **iOS Control Center control** for one-tap start
- On Watch: haptic on completion — the single most valuable place for this
  feature, since you feel it without looking
- Auto-start on logging a set, once the workout logger exists

**4. All three platforms**

iPhone as the primary surface, Mac for planning and review, Watch for the
in-workout moments.

### V2 — the differentiators

**5. Workout logger**

Exercises, sets, reps, weight. Pairs naturally with the rest timer — finish a
set, the timer starts itself. This is what turns Senku from a calculator into a
daily-use app.

**6. Progress tracking with trend smoothing**

Raw daily weight is mostly water noise, and it is the single biggest reason
people quit a plan. Senku displays an **exponentially weighted moving average**
as the primary line and raw readings as faint dots behind it.

**7. Adaptive TDEE** ← *the feature nobody else does well*

After 2–3 weeks of logged weight and intake, compute the user's **actual**
maintenance from observed weight change rather than a population formula:

```
actual TDEE = mean intake − (weight change in kg × 7700 / days)
```

Then compare it to the predicted figure and adjust. This is what makes the app
worth keeping past week three — it stops being a guess and starts being *your*
number.

**8. HealthKit**

Read weight, steps and active energy; write workouts. Lets activity level be
observed instead of self-reported, which is where most calculators go wrong.

**9. Gym utilities**

Plate calculator (what to load on the bar), 1RM estimator, warm-up set
suggestions. Small, high-frequency, genuinely useful mid-session.

### V3 — depth

- **Meal builder**: assemble foods to hit today's remaining macros
- **Diet phase planner**: schedule cut/maintain/bulk blocks across months
- **Progression suggestions**: flag stalled lifts, propose deloads
- **Shortcuts / Siri**: "Hey Siri, start my rest timer"
- **Export**: CSV and PDF of history

---

## Explicitly out of scope

Naming these now prevents scope drift later:

- **A food database.** Licensing a good one is expensive and maintaining a bad
  one is worse. Senku sets targets; a dedicated tracker logs against them.
- **Social feeds, streaks, gamification.** Not the product.
- **Medical claims.** Senku gives population-formula estimates with stated error
  bars. It is not a clinical tool, and the advisories say so.

---

## Guiding principles

1. **Pure core, thin shells.** All math lives in `SenkuCore` with zero UI or
   platform imports, so the same tested code serves all three platforms.
2. **Values, not objects.** Everything in the core is an immutable `struct`.
   `NutritionPlan.make` is pure and synchronous — a SwiftUI view can rebuild it
   on every keystroke with no concurrency machinery.
3. **Validation at the boundary.** `BodyMetrics.init` throws on impossible input,
   so no calculation downstream ever has to defend itself.
4. **Never invent precision.** Estimates are labelled as estimates.
