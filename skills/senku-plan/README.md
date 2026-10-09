# Senku plan import

Turns a workout plan from Excel, PDF, Word, CSV or text into a file the Senku
app imports. The file sets up your split: days, muscle groups, exercises
matched to Senku's catalogue, and sets and rep ranges. Exercises Senku doesn't
know are added as your own. Nothing else in the app is touched.

It works with any AI. The instructions are plain Markdown, and the checker is a
Python script with no dependencies, which you can also run yourself.

```
senku-plan/
├── SKILL.md              the instructions the AI follows
├── prompt.md             everything in one paste, for a chat AI (generated)
├── scripts/senku_plan.py extract · find · list · regions · validate · sync
├── reference/format.md   the file format
├── reference/catalogue.md every exercise and muscle id (for AIs without code)
├── data/catalogue.json   the catalogue the script uses outside the repo
└── examples/             a plan, the file it becomes, and why
```

## The command

Once the skill is installed, in any AI:

```
/senku-plan              then attach your plan
/senku-plan my-plan.pdf
```

In Claude Code it is a real slash command. Elsewhere the skill tells the AI to
answer to it, so the same command works in Claude, ChatGPT, Codex, Copilot
and others that support skills. "Convert my plan for Senku" works too.

## Using it

### Claude Code

- **In this repository:** it is already available, through `.claude/skills`.
  Ask *"convert my plan.xlsx for Senku"*.
- **Anywhere else:** copy the folder to `~/.claude/skills/senku-plan`.

### Claude (web or desktop)

Zip the `senku-plan` folder and add it as a skill in Claude's settings
(code execution needs to be on). Then attach your plan and ask for it to be
converted for Senku.

### Other agents (Codex, Copilot, Cursor and similar)

If the tool supports `SKILL.md` skills, put the folder in its skills directory.
If not, tell it:

> Read `skills/senku-plan/SKILL.md` and follow it to convert `my-plan.pdf`.

### Chat-only AIs (ChatGPT, Gemini…)

Paste `prompt.md` into the chat, or attach it, along with your plan. It holds
the instructions, the format and every exercise in one file. The Senku app
hands out the same prompt from **Workout → Your Week → Import a plan**, with
your own exercises added to it.

An AI that can run Python, such as ChatGPT with data analysis, can also run the
checker if you upload `scripts/senku_plan.py` and `data/catalogue.json`. If it
can't run code, check the result yourself before importing:

```
python3 scripts/senku_plan.py validate senku-plan.json
```

## Importing into Senku

1. Get the `.json` file onto your iPhone: AirDrop, Files or Mail.
2. In Senku, **press and hold the SENKU logo** at the top of any screen for a
   second.
3. Pick the file. The summary lists anything it skipped.

Importing **replaces your current plan**. Workouts, records, food, water and
everything else stay as they are.

## The script on its own

```sh
python3 scripts/senku_plan.py extract plan.xlsx           # the plan as text
python3 scripts/senku_plan.py find "db incline press"     # closest catalogue exercises
python3 scripts/senku_plan.py list --group chest          # a group's exercises
python3 scripts/senku_plan.py regions                     # muscle ids for custom exercises
python3 scripts/senku_plan.py validate senku-plan.json    # exactly what the app will do
```

`validate` exits 0 when the file is clean, 1 when lines would be skipped, and 2
when the app would refuse the file.

## Keeping it current

Inside the Senku repository the script reads the app's live catalogue, so it is
never stale there. Anywhere else it uses `data/catalogue.json`. After the
catalogue changes, run this from inside the repository:

```sh
python3 skills/senku-plan/scripts/senku_plan.py sync
```

It refreshes `data/catalogue.json`, `reference/catalogue.md` and `prompt.md`,
and mirrors the skill into the app (`SenkuUI/Sources/SenkuUI/PlanSkill`), which
hands it out from the Import a plan page. A test fails if the two drift.
`validate` warns when the copy is out of date.
