# Roadmap

Everything planned is built. This is the record of what shipped, what was
dropped and why, and what is still open — kept because the *why* is the part
that gets lost.

## Built

| | Feature | Notes |
| --- | --- | --- |
| ✅ | **Quick calc** | BMR, maintenance at every activity level, macros, advisories |
| ✅ | **Profile** | The same plan, kept, and everything else derived from it |
| ✅ | **F1 — Weight log** | Trend line, rate by regression, adaptive maintenance, reminder, history, widget |
| ✅ | **F2 — PR page** | Records per exercise, cardio records, cardio protocols, group filters |
| ✅ | **F3 — Workout** | Splits, coverage per muscle group, checklist, set logger, cardio, rest tie-in |
| ✅ | **F4 — Water** | Bottle, three containers, goal from profile, reminders, creatine, streaks, widget, watch |
| ✅ | **F5 — Food** | Protein and calorie rings, quick-adds, servings, streaks, widget, watch, adaptive maintenance |
| ✅ | **F6 — Anime** | Seasons or totals, statuses, search, sorting, posters, totals |
| ✅ | **Rest timer** | Presets, Live Activity, Control Center, chime on a locked phone, watch haptics |
| ✅ | **Plate calculator** | Per-side breakdown drawn to scale, rack editor, both units |
| ✅ | **Export** | PDF with charts and a section picker, plus a JSON backup that restores |
| ✅ | **Import** | Hand-writable JSON; the same path the sample data uses |

## Dropped, with reasons

| | Idea | Why not |
| --- | --- | --- |
| ❌ | **F7 — Logging a workout from the watch** | Two devices writing into one live session is the hardest problem in the app, and the phone is already in the gym bag. Design kept in REQUIREMENTS for the record. |
| ❌ | **iCloud / CloudKit sync** | Refused outright to a personal development team. The App Group plus the JSON export is the backup story. |
| ❌ | **HealthKit** | Two sources of truth for weight, with the dedupe and provenance that implies, for a payoff that depends on owning a connected scale. |
| ❌ | **Food database** | A licence and a subscription, or somebody else's scraped data. Quick-adds cover the eight things people actually eat. |

## Open

Small, and none of them blocking daily use.

- **Editing a past day.** Food and water are today-only. A past day can be marked
  "never logged" so a streak survives, but a wrong figure cannot be corrected.
- **3 a.m. day boundary.** Midnight currently. A late meal after a late session
  counts to the next day, which is not how anybody thinks about it.
- **Sets-per-week volume guidance.** The thing coverage percentages make people
  ask for next.
- **A watch complication for water or food.** The rest timer has one; nothing
  else does.

## How this project is built

In sessions, by one person, with a coding agent, in the order the app was
actually needed — not front-loaded design. The requirements document was written
first and has been amended as decisions were taken; every "Answered:" line in it
is a real decision with its reasoning attached.
