# Senku plan

A skill that gives you a workout plan the Senku app imports. It does two jobs:

- **Make** a plan for you from a few questions: your goal, how many days a week,
  how long you have, your equipment and experience.
- **Convert** a plan you already have, from Excel, PDF, Word, CSV, a photo or
  text.

Either way you get one `.json` file: days, muscle groups, exercises matched to
Senku's catalogue, and sets and rep ranges. Exercises Senku doesn't know are
added as your own. Nothing else in the app is touched.

It works with any AI. The instructions are plain Markdown, and the checker is a
Python script with no dependencies, which you can also run yourself.

```
senku-plan/
├── SKILL.md               the instructions the AI follows
├── prompt.md              converting, in one paste for a chat AI (generated)
├── prompt-make.md         making, in one paste for a chat AI (generated)
├── scripts/senku_plan.py  extract · find · list · regions · validate · volume
├── reference/format.md    the file format
├── reference/design.md    how a plan is designed: split, volume, order, reps
├── reference/catalogue.md every exercise and muscle id (for AIs without code)
├── data/catalogue.json    the catalogue the script uses
└── examples/              a converted plan, a made one, and why
```

## The command

Once the skill is installed, in any AI:

```
/senku-plan                      then ask for a plan, or attach yours
/senku-plan make me a 4-day plan
/senku-plan my-plan.pdf
```

In Claude Code it is a real slash command. Elsewhere the skill tells the AI to
answer to it. "Make me a workout plan for Senku" or "convert my plan for Senku"
work too.

## Installing it

### Claude (web or desktop)

Custom skills need a paid plan (Pro, Max, Team or Enterprise) with code
execution on.

1. Download `senku-plan.zip` from the latest release. Keep it zipped.
2. On claude.ai or the desktop app, open **Settings → Capabilities**, make sure
   code execution and file creation are on, then under **Skills** choose
   **+ → Upload a skill** and pick the zip. (Claude moves these menus now and
   then; look for *Skills* in Settings.)
3. Start a chat and type `/senku-plan`.

### Claude Code

Unzip it to `~/.claude/skills/senku-plan`, then type `/senku-plan`.

### Other agents (Codex, Copilot, Cursor and similar)

If the tool supports `SKILL.md` skills, put the folder in its skills directory.
If not, tell it:

> Read `senku-plan/SKILL.md` and follow it to make me a plan.

### Chat-only AIs (ChatGPT, Gemini…)

Paste `prompt-make.md` (to make a plan) or `prompt.md` (to convert one) into
the chat. Each holds the instructions, the format and every exercise. The
Senku app hands out the same prompts from **Workout → Your Week → Import a
plan**, with your own exercises, and for making a plan what your profile
already says about you, added.

## Importing into Senku

1. Get the `.json` file onto your iPhone: AirDrop, Files or Mail.
2. In Senku, **press and hold the SENKU logo** at the top of any screen for a
   second, or use **Import plan** on the Import a plan page.
3. Pick the file. The preview shows the week before anything changes.

Importing **replaces your current plan**. Workouts, records, food, water and
everything else stay as they are.

## The script on its own

```sh
python3 scripts/senku_plan.py extract plan.xlsx                      # a plan as text
python3 scripts/senku_plan.py find "db incline press"                # closest catalogue exercises
python3 scripts/senku_plan.py list --group chest                     # a group's exercises
python3 scripts/senku_plan.py regions                                # muscle ids for custom exercises
python3 scripts/senku_plan.py validate senku-plan.json               # exactly what the app will do
python3 scripts/senku_plan.py volume senku-plan.json --days-per-week 4   # weekly sets per muscle
```

`validate` exits 0 when the file is clean, 1 when lines would be skipped, and 2
when the app would refuse the file.

## Exercise list version

`reference/catalogue.md` starts with a catalogue version. Plan files carry it as
`catalogueVersion`, and the app says on import when it was made from an older
list. A new release of this skill follows every change to Senku's exercises.

This skill is built in the Senku repository and published here; `sync` and
`publish` in the script do that.
