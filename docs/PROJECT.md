# Senku — what it is, and the rules it is built to

## The idea in one line

A science-based training and nutrition companion for iPhone and Apple Watch that
**shows its work** — every number comes with the formula that produced it and the
caveats that apply to it.

## Why "shows its work" is the whole product

There are hundreds of macro calculators. Almost all of them hand you a number
with no explanation, no indication of which formula produced it, and no warning
when the number is a bad idea for you specifically.

Senku is named after a scientist, and that sets the design rule for everything:

- **Name the formula.** Mifflin-St Jeor, Katch-McArdle, Harris-Benedict — you can
  see which one ran, and switch it.
- **Distinguish measured from estimated.** A body fat figure you measured and one
  guessed from your BMI are not the same input, and the app never blurs them.
- **Refuse to be dangerous quietly.** A deficit landing under the safe floor is
  clamped, and the app says so rather than silently serving the number.
- **Show the ladder, not one number.** Maintenance at every activity level, so
  you can see what changing your training actually does.
- **Measure rather than assume, once there is something to measure.** After a
  fortnight of food and weigh-ins the app compares what you ate against what the
  scale did and offers the maintenance figure *that* implies — the one number in
  the app derived from evidence about you rather than from a population average.

## Who it is for

One person, originally: the author, who wanted his own numbers in one place and
did not want to pay a subscription to see them. It is published because the
problem is not unusual — and because a personal app can do the thing a product
cannot, which is hold several unrelated parts of a life without either being a
compromise. That is why an anime tracker sits in the same binary as a squat log.

## Rules the code is held to

These are not aspirations. They are visible in the source and in the commit
history, and they are why some obvious features are absent.

1. **A number on screen is accountable.** If the app cannot explain where a
   figure came from, it does not show it. `AdaptiveMaintenance` returns `nil`
   rather than a figure with a caveat, because a number gets believed and small
   print does not.
2. **Absence is not zero.** A day with nothing logged is "nothing logged", never
   "0 g — you failed". Streaks skip it; averages leave it out.
3. **Nothing is entered twice.** A set logged in a workout updates the PR page. A
   drink logged on the wrist reaches the phone. The watch keeps no history of its
   own, because two devices holding a list is the one genuinely hard problem in
   syncing, and it is avoidable.
4. **The history is a record, not a draft.** Past days cannot be edited. They can
   be marked "never logged", which is a different claim and an honest one.
5. **Every screen is reachable one-handed, mid-set.** The rest timer is never
   more than a tap away; the workout screen opens on the thing you came to tap.
6. **Comments say why, not what.** The code explains decisions, dead ends and
   the bugs that shaped it, because six months later the "what" is readable and
   the "why" is gone.

## What it is not

- **Not a social app.** No accounts, no feed, no sharing. Data lives on the
  device and in an App Group the widgets and watch read.
- **Not a food database.** Licensing one is a contract and a subscription;
  scraping one is somebody else's data. It stores what you can actually know —
  the grams — and a row of quick-adds for the eight things you actually eat.
- **Not a coach.** It reports and it advises. It never changes a target without
  being asked, and every suggestion is a button you press or ignore.
- **Not cloud-backed.** iCloud is refused to a personal development team, so the
  backup story is an export you own: a PDF to read and a JSON to restore.

## Status

All six planned features are built and in daily use. The seventh — logging a
workout from the watch — was designed and dropped; the reasoning is in
[REQUIREMENTS.md](REQUIREMENTS.md).
