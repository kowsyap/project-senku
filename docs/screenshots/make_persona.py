#!/usr/bin/env python3
"""A believable person's last eleven weeks in Senku, for screenshots.

Maya, 28, cutting slowly on a four-day upper/lower split. Everything follows
from everything else: weights climb by double progression across real
sessions, records are the sets that beat what came before, food sits near her
targets, the scale drifts down at a sensible rate. Dated up to the moment it
is run, so the app's "today" has data in it.

    python3 docs/screenshots/make_persona.py OUT.json
    SIMCTL_CHILD_SENKU_SAMPLE=OUT.json xcrun simctl launch <device> pk.Senku

Written in Senku's own backup format, and read by the same importer.
"""

import json
import random
import sys
import uuid
from datetime import datetime, timedelta
from pathlib import Path

random.seed(7)
REPO = Path(__file__).resolve().parents[2]
CATALOGUE = json.loads((REPO / "SenkuCore/Sources/SenkuCore/Resources/ExerciseCatalogue.json").read_text())
BY_NAME = {e["name"]: e for e in CATALOGUE["exercises"]}

# Late afternoon today, whatever the clock says, so "today" has a day in it —
# except the weigh-in, which is shown as "how long ago" and so has to be past.
REAL_NOW = datetime.now().astimezone()
TODAY = REAL_NOW.replace(hour=0, minute=0, second=0, microsecond=0)
NOW = TODAY.replace(hour=17, minute=30)
WEEKS = 11


def iso(moment):
    return moment.isoformat()


def uid():
    return str(uuid.uuid4()).upper()


def ex(name):
    return BY_NAME[name]["id"]


# MARK: - The plan

TARGET = {"sets": 3, "reps": 8, "maxReps": 12}

# (name, sets, min, max, start kg, step kg) — step 0 is bodyweight, None a hold.
DAYS = [
    ("Lower A", ["legs", "abs"], [
        ("Barbell Hip Thrust", 4, 6, 10, 60, 5),
        ("Barbell Back Squat", 4, 5, 8, 45, 2.5),
        ("Barbell Romanian Deadlift", 3, 8, 10, 40, 2.5),
        ("Leg Extension", 3, 12, 15, 25, 2.5),
        ("Lying Leg Curl", 3, 10, 12, 20, 2.5),
        ("Standing Calf Raise", 4, 12, 15, 30, 5),
    ]),
    ("Upper A", ["chest", "back", "shoulder", "bicep", "tricep"], [
        ("Incline Dumbbell Press", 3, 8, 12, 12, 1),
        ("Wide-Grip Lat Pulldown", 3, 10, 12, 30, 2.5),
        ("Seated Cable Row", 3, 10, 12, 27.5, 2.5),
        ("Dumbbell Shoulder Press", 3, 8, 12, 8, 1),
        ("Dumbbell Lateral Raise", 3, 12, 20, 4, 1),
        ("Rope Triceps Pushdown", 3, 10, 15, 12.5, 2.5),
        ("Hammer Curl", 3, 10, 12, 6, 1),
    ]),
    ("Lower B", ["legs", "abs"], [
        ("Bulgarian Split Squat", 3, 8, 12, 8, 1),
        ("Hack Squat", 3, 8, 12, 40, 5),
        ("Cable Pull-Through", 3, 12, 15, 20, 2.5),
        ("Seated Leg Curl", 3, 10, 12, 22.5, 2.5),
        ("Hip Abduction Machine", 3, 15, 20, 35, 5),
        ("Hanging Knee Raise", 3, 10, 15, 0, 0),
        ("Plank", 3, None, None, 0, None),
    ]),
    ("Upper B", ["chest", "back", "shoulder", "bicep", "tricep"], [
        ("Pull-Up", 3, 3, 6, 0, 0),
        ("Dumbbell Bench Press", 3, 8, 12, 14, 1),
        ("Chest-Supported Dumbbell Row", 3, 8, 12, 12, 1),
        ("Face Pull", 3, 12, 15, 15, 2.5),
        ("Cable Lateral Raise", 3, 12, 20, 5, 1.25),
        ("EZ-Bar Curl", 3, 8, 12, 15, 2.5),
        ("Overhead Cable Triceps Extension", 3, 10, 15, 12.5, 2.5),
    ]),
]
SCHEDULE = {0: 2, 1: 1, 3: 0, 5: 3}  # weekday → day index: Lower B Mon, Upper A Tue, Lower A Thu, Upper B Sat


def target_for(sets, low, high):
    if low is None:
        return {"sets": sets, "reps": TARGET["reps"], "maxReps": TARGET["maxReps"]}
    target = {"sets": sets, "reps": low}
    if high and high > low:
        target["maxReps"] = high
    return target


plan_days = []
for name, groups, exercises in DAYS:
    ids = [ex(e[0]) for e in exercises]
    targets = {}
    for (exercise, sets, low, high, *_rest) in exercises:
        t = target_for(sets, low, high)
        if t != TARGET:
            targets[ex(exercise)] = t
    plan_days.append({"id": uid(), "name": name, "groups": groups, "exerciseIDs": ids, "targets": targets})

# MARK: - Workouts, by double progression

state = {}  # exercise → (weight, reps) for the next session
workouts = []
records = []
best = {}  # exercise → (weight, reps or seconds)


def offer_record(exercise_id, weight, reps, seconds, when):
    key = seconds if seconds is not None else reps
    old = best.get(exercise_id)
    beats = old is None or weight > old[0] + 0.01 or (abs(weight - old[0]) < 0.01 and key > old[1])
    if not beats:
        return
    best[exercise_id] = (weight, key)
    entry = {"exerciseID": exercise_id, "weightKG": weight, "date": iso(when)}
    if seconds is not None:
        entry["seconds"] = seconds
    else:
        entry["reps"] = reps
    records.append(entry)


start = TODAY - timedelta(weeks=WEEKS)
day = start
while day < TODAY:
    index = SCHEDULE.get(day.weekday())
    # A missed session now and then, as in life.
    if index is not None and random.random() > 0.08:
        name, groups, exercises = DAYS[index]
        plan_day = plan_days[index]
        clock = day.replace(hour=random.choice([6, 7, 17, 18]), minute=random.choice([0, 10, 20, 30]))
        session_start = clock
        entries = []
        for (exercise, sets, low, high, start_kg, step) in exercises:
            exercise_id = ex(exercise)
            weight, reps = state.get(exercise_id, (start_kg, low or 0))
            logged = []
            for number in range(sets):
                clock += timedelta(minutes=random.randint(2, 4))
                if low is None:  # a hold, getting longer
                    seconds = min(90, 30 + 5 * len([w for w in workouts if w["dayName"] == name]))
                    logged.append({"id": uid(), "weightKG": 0, "seconds": seconds, "completedAt": iso(clock)})
                    offer_record(exercise_id, 0, 0, seconds, clock)
                    continue
                done = reps if number < sets - 1 or random.random() > 0.25 else max(low, reps - 1)
                logged.append({"id": uid(), "weightKG": weight, "reps": done, "completedAt": iso(clock)})
                offer_record(exercise_id, weight, done, None, clock)
            entry = {"exerciseID": exercise_id, "sets": logged,
                     "target": plan_day["targets"].get(exercise_id, TARGET)}
            entries.append(entry)
            if low is not None:
                all_top = all(s["reps"] >= high for s in logged)
                if all_top and step:
                    state[exercise_id] = (round(weight + step, 2), low)
                elif all_top:
                    state[exercise_id] = (weight, reps + 1)  # bodyweight: one more rep
                else:
                    state[exercise_id] = (weight, min(high, reps + 1))
        # Cardio after the lower days.
        if index in (0, 2):
            clock += timedelta(minutes=4)
            entries.append({"exerciseID": ex("Incline Walk"), "sets": [], "cardio": {
                "id": uid(), "seconds": 1200, "values": {"speed": 5.5, "incline": 12},
                "completedAt": iso(clock + timedelta(minutes=20))}})
            clock += timedelta(minutes=20)
        workouts.append({
            "id": uid(), "date": iso(session_start), "dayID": plan_day["id"], "dayName": name,
            "groups": groups, "entries": entries, "finishedAt": iso(clock + timedelta(minutes=3)),
        })
    day += timedelta(days=1)

# MARK: - Body, food, water

weigh_ins = []
weight = 66.4
for back in range(WEEKS * 7, -1, -1):
    moment = (TODAY - timedelta(days=back)).replace(hour=7, minute=random.randint(0, 25))
    weight -= 0.32 / 7
    if back == 0:
        moment = min(moment, REAL_NOW - timedelta(minutes=25))
    elif random.random() < 0.25:
        continue
    weigh_ins.append({"date": iso(moment), "weightKG": round(weight + random.uniform(-0.35, 0.35), 1)})

BREAKFAST = ("Greek yogurt, berries & oats", 32, 52, 9, 6)
SHAKE = ("Protein shake", 26, 6, 2, 1)
LUNCH = [("Chicken burrito bowl", 46, 68, 15, 9), ("Turkey & hummus wrap", 36, 52, 14, 6)]
SNACK = [("Cottage cheese & fruit", 24, 26, 5, 3), ("Egg & avocado toast", 20, 30, 19, 7)]
DINNER = [("Salmon, rice & greens", 40, 62, 19, 5), ("Tofu stir-fry with noodles", 30, 66, 16, 8),
          ("Lean beef chilli", 42, 48, 14, 11)]
intake = []
water = []
for back in range(56, -1, -1):
    date = TODAY - timedelta(days=back)
    if back and random.random() < 0.08:
        continue  # a day she forgot
    meals = [BREAKFAST, SHAKE, random.choice(LUNCH), random.choice(SNACK), random.choice(DINNER)]
    times = [(7, 40), (10, 45), (13, 10), (16, 20), (19, 40)]
    for (meal, (hour, minute)) in zip(meals, times):
        moment = date.replace(hour=hour, minute=minute + random.randint(0, 10))
        if moment > NOW:
            break
        p, c, f, fibre = meal[1:]
        jitter = random.uniform(0.9, 1.12)
        intake.append({"id": uid(), "date": iso(moment), "name": meal[0], "proteinG": round(p * jitter, 1),
                       "carbsG": round(c * jitter, 1), "fatG": round(f * jitter, 1), "fiberG": fibre})
    for hour in [7, 9, 11, 13, 15, 17, 20]:
        moment = date.replace(hour=hour, minute=random.randint(0, 50))
        if moment > NOW or random.random() < 0.15:
            continue
        water.append({"id": uid(), "date": iso(moment), "ml": random.choice([250, 400, 500, 500])})

favourites = [
    {"id": uid(), "name": "Protein shake", "proteinG": 26, "carbsG": 6, "fatG": 2, "fiberG": 1, "timesUsed": 51},
    {"id": uid(), "name": "Greek yogurt bowl", "proteinG": 32, "carbsG": 48, "fatG": 8, "fiberG": 6, "timesUsed": 44},
    {"id": uid(), "name": "Burrito bowl", "proteinG": 46, "carbsG": 62, "fatG": 14, "fiberG": 9, "timesUsed": 17},
    {"id": uid(), "name": "Cottage cheese", "proteinG": 24, "carbsG": 22, "fatG": 5, "fiberG": 3, "timesUsed": 12},
]

# MARK: - The rest of a life

cardio_records = []
for weeks_ago, minutes, speed in [(9, 20, 5.0), (6, 25, 5.3), (3, 30, 5.5), (1, 30, 5.8)]:
    moment = (TODAY - timedelta(weeks=weeks_ago)).replace(hour=8)
    cardio_records.append({"id": uid(), "exerciseID": ex("Incline Walk"), "seconds": minutes * 60,
                           "values": {"speed": speed, "incline": 12}, "date": iso(moment),
                           "source": {"manual": {}}})
cardio_plans = [{"exerciseID": ex("Incline Walk"), "columns": ["Time", "Speed", "Incline"],
                 "rows": [["5", "5.0", "6"], ["20", "5.5", "12"], ["5", "4.5", "3"]],
                 "note": "Warm up, the 12-3-30 block, walk it off.", "updatedAt": iso(TODAY - timedelta(days=20))}]


def anime(title, genres, status, seasons=(), total=None, movie=False, added=60):
    return {"id": uid(), "title": title, "genres": genres, "status": status,
            "seasons": [{"id": uid(), "number": n + 1, "title": "", "episodes": e} for n, e in enumerate(seasons)],
            **({"totalEpisodes": total} if total else {}), "isMovie": movie, "note": "",
            "addedAt": iso(TODAY - timedelta(days=added)), "updatedAt": iso(TODAY - timedelta(days=added // 3))}


anime_list = [
    anime("Frieren: Beyond Journey's End", ["Adventure", "Fantasy"], "completed", [28], added=120),
    anime("Spy x Family", ["Comedy", "Action"], "airing", [25, 12, 13], added=90),
    anime("Haikyu!!", ["Sports"], "completed", [25, 25, 10, 25], added=200),
    anime("The Apothecary Diaries", ["Mystery", "Drama"], "airing", [24, 24], added=45),
    anime("Your Name", ["Romance", "Drama"], "watched", total=1, movie=True, added=150),
    anime("Kaguya-sama: Love Is War", ["Romance", "Comedy"], "pending", total=37, added=10),
]


def due(title, category, amount, day_of_month, repeats="months"):
    first = TODAY.replace(day=1) + timedelta(days=day_of_month - 1)
    return {"id": uid(), "title": title, "category": category, "amount": amount, "note": "",
            "firstDue": iso(first - timedelta(days=62)), "repeats": repeats, "every": 1,
            "remindDaysBefore": [3, 0], "remindAtMinute": 540,
            "doneThrough": iso(first - timedelta(days=31)), "history": [],
            "createdAt": iso(TODAY - timedelta(days=80))}


dues = [due("Rent", "Home", 1450, 1), due("Credit card", "Card", 380, 18),
        due("Gym membership", "Health", 45, 12), due("Phone", "Bills", 35, 22)]

profile = {
    "name": "Maya",
    "metrics": {"sex": "female", "age": 28, "heightCM": 165, "weightKG": weigh_ins[-1]["weightKG"],
                "bodyFatPercentage": 27},
    "activityLevel": "moderate", "goal": "moderateCut", "formula": "automatic", "unitSystem": "metric",
    "goalWeightKG": 59, "updatedAt": iso(TODAY - timedelta(days=WEEKS * 7)),
}

document = {
    "schemaVersion": 1, "unitSystem": "metric", "profile": profile, "weighIns": weigh_ins,
    "records": records, "plan": {"days": plan_days, "target": TARGET}, "workouts": workouts,
    "cardioRecords": cardio_records, "cardioPlans": cardio_plans, "water": water, "intake": intake,
    "favourites": favourites, "anime": anime_list, "dueDates": dues, "watchlistName": "Anime",
}

Path(sys.argv[1]).write_text(json.dumps(document, indent=1))
print(f"{len(workouts)} workouts, {len(records)} records, {len(weigh_ins)} weigh-ins, "
      f"{len(intake)} meals, {len(water)} drinks → {sys.argv[1]}")
