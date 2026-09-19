# Contributing to Senku

Senku is a vibe-coding project. It was built by one person, in sessions, with a
coding agent, to cover one person's daily use cases — and it is public because
those use cases are not unusual. If it nearly does what you want, that gap is
worth a pull request.

Things that are especially welcome:

- **A use case I do not have.** A screen, a metric, a habit I do not track.
- **A unit, locale or body I do not use.** The app knows kg and lb because those
  are the plates in my gym. That is not a principled limit.
- **A device I do not own.** Layout bugs on a phone size or a watch case I have
  never run on.
- **A formula worth naming.** Adding one is easy; it just has to be citable.

## Before you write code

**Open an issue and describe the use case**, not the implementation. "I train
twice a day and the water goal only counts one session" is a better opening than
"add a sessions array". Half the decisions in this codebase are recorded in
[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) with their reasoning attached, and
it is worth a look — your idea may already be there, either answered or
deliberately dropped with a reason you can argue with.

## The one rule

**A number on screen is accountable.** If the app cannot say where a figure came
from, it does not show it. `AdaptiveMaintenance` returns `nil` rather than a
figure with a caveat, because a number gets believed and small print does not.

Everything else follows from that, and the rest of the house style is in
[docs/PROJECT.md](docs/PROJECT.md). In short:

1. **Absence is not zero.** A day with nothing logged is "nothing logged", never
   "0 g — you failed". Streaks skip it; averages leave it out.
2. **Nothing is entered twice.** If a set produces a PR, the PR page already
   knows.
3. **The history is a record, not a draft.**
4. **Comments say why, not what.** Especially where the obvious approach was
   tried and failed. Six months later the "what" is still readable and the "why"
   is gone.

## Where code goes

| It is… | It belongs in… |
| --- | --- |
| arithmetic, a model, a rule | `SenkuCore` — no SwiftUI import, ever |
| a screen, a store, formatting | `SenkuUI` |
| an entry point, an entitlement, a plist | the `Senku` Xcode project |

If logic ends up in a view, it cannot be tested on the host, and the host tests
are what make this project quick to work on. Move it down.

## Tests

Anything with a rule in it gets a test. The host suites run in about a hundredth
of a second and need no simulator:

```sh
cd SenkuCore && swift test     # 171 tests
cd ../SenkuUI  && swift test   # 69 tests
```

Then build the app before you open the PR:

```sh
cd Senku
xcodebuild -project Senku.xcodeproj -scheme Senku \
  -destination 'generic/platform=iOS Simulator' build
```

A **generic** destination, not a named device — [docs/XCODE_SETUP.md](docs/XCODE_SETUP.md)
explains why a named one breaks the watch link.

If your change touches a screen, run it with the sample data and look at it:

```sh
SIMCTL_CHILD_SENKU_SAMPLE=1 xcrun simctl launch booted pk.Senku
```

Anything touching water, food, weight or the profile crosses a process boundary,
so check the widget and the watch too, not just the phone screen.

## Pull requests

- One change per PR. A feature and a refactor in the same diff is two PRs.
- Say what it does and **why**, and mention the issue it came from.
- Screenshots for anything visual — phone and watch if it affects both.
- Commit messages in the imperative, describing the decision rather than the
  file. `git log` here reads as a narrative on purpose.
- Keep `swift test` green, and add to it.

## Setting up

[docs/XCODE_SETUP.md](docs/XCODE_SETUP.md) covers the targets, the App Group, the
signing (a free Apple ID is enough), the debug hooks, and the simulator pairing
for the watch.

## Code of conduct

Be decent. This is somebody's gym log, not a company. Disagreement about a
formula is welcome; contempt is not.
