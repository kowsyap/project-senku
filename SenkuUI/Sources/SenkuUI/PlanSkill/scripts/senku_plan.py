#!/usr/bin/env python3
"""Turn a workout plan into a file Senku can import — the helper half.

Standard library only, Python 3.8+, so it runs anywhere an AI or a person can
run Python. Subcommands:

    validate FILE        Check a Senku plan file exactly as the app will read it.
    find QUERY...        Catalogue exercises that best match a name from a plan.
    list [--group G]     Every catalogue exercise, by muscle group.
    regions              Muscle ids, for describing a custom exercise.
    extract FILE         A plan file (xlsx, docx, pdf, csv, txt, md) as plain text.
    sync                 Refresh this skill's copy of the catalogue from the repo.

The rules in `validate` mirror the app's importer (SenkuImport.swift,
TrainingPlan.swift, RepTarget.swift, ExerciseLibrary.swift). When the two
disagree the app is right and this is a bug.
"""

import argparse
import csv
import io
import json
import re
import shutil
import subprocess
import sys
import unicodedata
import uuid
import zipfile
from pathlib import Path
from xml.etree import ElementTree

HERE = Path(__file__).resolve().parent
SKILL = HERE.parent
BUNDLED = SKILL / "data" / "catalogue.json"
CATALOGUE_MD = SKILL / "reference" / "catalogue.md"
PROMPT_MD = SKILL / "prompt.md"
# The copy the app carries, so it can hand the skill out. Generated files are
# left out: the app makes its own, with the person's exercises in them.
APP_COPY = Path("SenkuUI/Sources/SenkuUI/PlanSkill")
GENERATED = {"data", "prompt.md", "reference/catalogue.md"}
IN_REPO = Path("SenkuCore/Sources/SenkuCore/Resources/ExerciseCatalogue.json")

SET_RANGE = (1, 10)
REP_RANGE = (1, 50)
EQUIPMENT = ["barbell", "dumbbell", "kettlebell", "machine", "cable", "bodyweight"]
PLAN_SECTIONS = {"schemaVersion", "plan", "customExercises", "unitSystem"}


# MARK: - The catalogue

def locate_catalogue(explicit=None):
    """The live catalogue when inside the Senku repo, else the bundled copy."""
    if explicit:
        return Path(explicit), "given"
    roots = [SKILL.parent.parent]
    cwd = Path.cwd()
    roots += [cwd, *cwd.parents]
    for root in roots:
        candidate = root / IN_REPO
        if candidate.is_file():
            return candidate, "live"
    if BUNDLED.is_file():
        return BUNDLED, "bundled"
    sys.exit("No exercise catalogue found. Pass --catalogue PATH to ExerciseCatalogue.json.")


def search_key(text):
    """Letters and digits only, lowercased, without accents — the app's rule."""
    folded = unicodedata.normalize("NFKD", text)
    folded = "".join(c for c in folded if not unicodedata.combining(c))
    return "".join(c for c in folded.casefold() if c.isalnum())


def same(lhs, rhs):
    """Equal, forgiving a plural on either side."""
    return lhs == rhs or lhs + "s" == rhs or lhs == rhs + "s"


class Catalogue:
    def __init__(self, path):
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        self.groups = list(data["workoutGroups"])
        self.regions = {r["id"]: r for r in data["muscleRegions"]}
        self.exercises = [self._shape(e) for e in data["exercises"]]

    @staticmethod
    def _shape(raw):
        return {
            "id": raw["id"],
            "name": raw["name"],
            "aliases": raw.get("aliases") or [],
            "group": raw["workoutGroup"],
            "equipment": raw.get("equipment", ""),
            "timed": bool(raw.get("isTimed")),
            "custom": False,
        }


class Library:
    """The catalogue plus the custom exercises a file adds, as the app sees them."""

    def __init__(self, catalogue):
        self.catalogue = catalogue
        self.custom = []

    @property
    def all(self):
        return self.catalogue.exercises + self.custom

    def by_id(self, ref):
        return next((e for e in self.all if e["id"] == ref), None)

    @staticmethod
    def is_named(exercise, ref):
        if ref == exercise["id"]:
            return True
        key = search_key(ref)
        if not key:
            return False
        return any(same(search_key(n), key) for n in [exercise["name"]] + exercise["aliases"])

    def resolve(self, ref):
        """('found', ex) | ('missing', None) | ('ambiguous', [names])."""
        exact = self.by_id(ref)
        if exact:
            return "found", exact
        ref = ref.strip()
        by_name = [e for e in self.all if self.is_named(e, ref)]
        direct = [e for e in by_name if same(search_key(e["name"]), search_key(ref))]
        candidates = direct or by_name
        if not candidates:
            return "missing", None
        if len(candidates) == 1:
            return "found", candidates[0]
        return "ambiguous", [e["name"] for e in candidates]


def group_named(word, groups):
    key = search_key(word)
    if not key:
        return None
    for group in groups:
        raw = search_key(group)
        if raw == key or raw + "s" == key or raw == key + "s":
            return group
    return None


# MARK: - Targets

class Target:
    def __init__(self, sets, reps, max_reps=None, notes=None, where=""):
        def clamp(value, bounds, label):
            low, high = bounds
            kept = min(max(value, low), high)
            if kept != value and notes is not None:
                notes.append(f"{where}: {label} {value} is outside {low}–{high}; the app uses {kept}.")
            return kept

        self.sets = clamp(sets, SET_RANGE, "sets")
        self.reps = clamp(reps, REP_RANGE, "reps")
        top = clamp(max_reps, REP_RANGE, "maxReps") if max_reps is not None else None
        self.max_reps = top if top is not None and top > self.reps else None

    @property
    def text(self):
        return f"{self.sets} × " + (f"{self.reps}–{self.max_reps}" if self.max_reps else f"{self.reps}")

    def __eq__(self, other):
        return (self.sets, self.reps, self.max_reps) == (other.sets, other.reps, other.max_reps)


STANDARD = Target(3, 10)


# MARK: - Validation

class Report:
    def __init__(self):
        self.fatal = []     # the app refuses the whole file
        self.problems = []  # one line skipped, the rest imports
        self.notes = []     # imports, but worth knowing
        self.extra = []     # sections beyond a plan's

    def fail(self, message):
        self.fatal.append(message)


def is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def read_target(raw, where, report, allow_partial=False):
    """A target object, or None. Partial only for an exercise's own target."""
    if not isinstance(raw, dict):
        report.fail(f"{where}: a target must be an object like {{\"sets\": 3, \"reps\": 10}}.")
        return None
    numbers = {}
    for key in ("sets", "reps", "minReps", "maxReps"):
        if key in raw and raw[key] is not None:
            if not is_int(raw[key]):
                report.fail(f"{where}: \"{key}\" must be a whole number, not {json.dumps(raw[key])}.")
                return None
            numbers[key] = raw[key]
    reps = numbers.get("reps", numbers.get("minReps"))
    if not allow_partial and ("sets" not in numbers or reps is None):
        report.fail(f"{where}: a target needs \"sets\" and \"reps\" (or \"minReps\").")
        return None
    return {"sets": numbers.get("sets"), "reps": reps, "maxReps": numbers.get("maxReps")}


def validate(document, catalogue):
    report = Report()
    library = Library(catalogue)
    days_out = []

    if not isinstance(document, dict):
        report.fail("The file must be one JSON object.")
        return report, None, days_out

    extra = sorted(set(document) - PLAN_SECTIONS)
    report.extra = extra
    if extra:
        report.notes.append(
            "Also contains " + ", ".join(extra) + " — those sections would be imported too. "
            "A plan file normally holds only \"plan\" and \"customExercises\"."
        )
    if "schemaVersion" in document and not is_int(document["schemaVersion"]):
        report.fail("\"schemaVersion\" must be a whole number.")

    # Custom exercises go in first, so the plan can name them.
    customs = document.get("customExercises")
    if customs is not None and not isinstance(customs, list):
        report.fail("\"customExercises\" must be a list.")
        customs = []
    for index, entry in enumerate(customs or []):
        where = f"customExercises[{index}]"
        if not isinstance(entry, dict):
            report.fail(f"{where}: must be an object.")
            continue
        name, equipment, region_ids = entry.get("name"), entry.get("equipment"), entry.get("regionIDs")
        if not isinstance(name, str) or not isinstance(equipment, str) \
                or not isinstance(region_ids, list) or not all(isinstance(r, str) for r in region_ids):
            report.fail(f"{where}: needs \"name\" (text), \"equipment\" (text) and \"regionIDs\" (list of text).")
            continue
        if "isTimed" in entry and entry["isTimed"] is not None and not isinstance(entry["isTimed"], bool):
            report.fail(f"{where}: \"isTimed\" must be true or false.")
            continue
        known = [r for r in region_ids if r in catalogue.regions]
        unknown = [r for r in region_ids if r not in catalogue.regions]
        if unknown:
            report.notes.append(f"“{name}”: no muscle called {', '.join(unknown)} — left out. See `regions`.")
        if not known:
            report.problems.append(f"“{name}”: none of its muscles exist, so it will not be added.")
            continue
        if equipment not in EQUIPMENT:
            report.notes.append(f"“{name}”: equipment “{equipment}” is not one of {', '.join(EQUIPMENT)}.")
        existing = next((e for e in library.all if e["name"].lower() == name.lower()), None)
        if existing:
            where_from = "the catalogue" if not existing["custom"] else "this file"
            report.notes.append(f"“{name}” is already in {where_from}; the app keeps that one and skips this.")
            continue
        library.custom.append({
            "id": f"custom.{len(library.custom) + 1}",
            "name": name,
            "aliases": [],
            "group": catalogue.regions[known[0]]["workoutGroup"],
            "equipment": equipment,
            "timed": bool(entry.get("isTimed")),
            "custom": True,
        })

    plan = document.get("plan")
    if plan is None:
        report.notes.append("No \"plan\" section — nothing about your week would change.")
        return report, None, days_out
    if not isinstance(plan, dict):
        report.fail("\"plan\" must be an object.")
        return report, None, days_out

    plan_target = STANDARD
    if plan.get("target") is not None:
        raw = read_target(plan["target"], "plan.target", report)
        if raw:
            plan_target = Target(raw["sets"], raw["reps"], raw["maxReps"], report.notes, "plan.target")
    else:
        report.notes.append("No plan target — every exercise without its own uses the app's 3 × 10.")

    days = plan.get("days")
    if not isinstance(days, list):
        report.fail("\"plan\" needs \"days\": a list.")
        return report, plan_target, days_out
    if not days:
        report.problems.append("The plan has no days, so the app keeps your current plan.")

    names_seen = set()
    for index, day in enumerate(days):
        where = f"plan.days[{index}]"
        if not isinstance(day, dict):
            report.fail(f"{where}: must be an object.")
            continue
        name = day.get("name")
        if not isinstance(name, str):
            report.fail(f"{where}: needs a \"name\".")
            continue
        label = name or where
        if name.strip().lower() in names_seen:
            report.notes.append(f"Two days are called “{name}”.")
        names_seen.add(name.strip().lower())

        if day.get("id") is not None:
            try:
                uuid.UUID(str(day["id"]))
            except ValueError:
                report.fail(f"{label}: \"id\" must be a UUID, or left out.")
                continue

        groups_raw = day.get("groups") or []
        ids_raw = day.get("exerciseIDs") or []
        items_raw = day.get("exercises") or []
        if not isinstance(groups_raw, list) or not all(isinstance(g, str) for g in groups_raw):
            report.fail(f"{label}: \"groups\" must be a list of text.")
            continue
        if not isinstance(ids_raw, list) or not all(isinstance(x, str) for x in ids_raw):
            report.fail(f"{label}: \"exerciseIDs\" must be a list of text.")
            continue
        if not isinstance(items_raw, list):
            report.fail(f"{label}: \"exercises\" must be a list.")
            continue

        # (reference, partial target or None), in order.
        written = [(ref, None) for ref in ids_raw]
        stored_targets = day.get("targets") or {}
        if not isinstance(stored_targets, dict):
            report.fail(f"{label}: \"targets\" must be an object.")
            continue
        broken = False
        for item_index, item in enumerate(items_raw):
            spot = f"{label}, exercise {item_index + 1}"
            if isinstance(item, str):
                written.append((item, None))
                continue
            if not isinstance(item, dict):
                report.fail(f"{spot}: must be a name or an object.")
                broken = True
                break
            ref = item.get("name", item.get("exercise", item.get("id")))
            if not isinstance(ref, str):
                report.fail(f"{spot}: an object needs \"name\".")
                broken = True
                break
            partial = read_target(item, spot, report, allow_partial=True)
            if partial is None:
                broken = True
                break
            has_numbers = any(partial[k] is not None for k in ("sets", "reps", "maxReps"))
            written.append((ref, partial if has_numbers else None))
        if broken:
            continue

        # Stored targets first, then the ones written inline — the app's order.
        own = {}
        for ref, raw in stored_targets.items():
            parsed = read_target(raw, f"{label}: targets[{ref}]", report)
            if parsed:
                own[ref] = Target(parsed["sets"], parsed["reps"], parsed["maxReps"], report.notes, f"{label}, {ref}")
        for ref, partial in written:
            if partial is not None:
                sets = partial["sets"] if partial["sets"] is not None else plan_target.sets
                reps = partial["reps"] if partial["reps"] is not None else plan_target.reps
                top = partial["maxReps"]
                if top is None and partial["reps"] is None:
                    top = plan_target.max_reps
                own[ref] = Target(sets, reps, top, report.notes, f"{label}, {ref}")

        resolved, targets = [], {}
        for ref, _ in written:
            outcome, value = library.resolve(ref)
            if outcome == "missing":
                report.problems.append(f"{label}: no exercise called “{ref}”. Try `find`, or add it to customExercises.")
            elif outcome == "ambiguous":
                report.problems.append(f"{label}: “{ref}” could be {' or '.join(value)} — use the full name.")
            else:
                if value["id"] in [e["id"] for e in resolved]:
                    report.notes.append(f"{label}: “{value['name']}” is listed twice; the app keeps it once.")
                    continue
                resolved.append(value)
                if ref in own:
                    targets[value["id"]] = own[ref]

        groups = []
        for written_group in groups_raw:
            group = group_named(written_group, catalogue.groups)
            if group is None:
                report.problems.append(
                    f"{label}: no muscle group called “{written_group}”. Groups are: {', '.join(catalogue.groups)}."
                )
            elif group not in groups:
                groups.append(group)
        if not groups:
            for exercise in resolved:
                if exercise["group"] not in groups:
                    groups.append(exercise["group"])

        if not resolved:
            report.notes.append(f"{label}: no exercises, so it will not be offered as a workout until it has some.")
        for exercise in resolved:
            target = targets.get(exercise["id"])
            if target and exercise["group"] == "cardio":
                report.notes.append(f"{label}: “{exercise['name']}” is cardio; sets and reps do not apply to it.")
            elif target and exercise["timed"] and (target.reps, target.max_reps) != (plan_target.reps, plan_target.max_reps):
                report.notes.append(f"{label}: “{exercise['name']}” is a hold; only its sets count, not reps.")

        days_out.append({"name": name, "groups": groups, "exercises": resolved, "targets": targets})

    return report, plan_target, days_out


def print_report(report, plan_target, days, source, catalogue_path):
    print(f"Catalogue: {source} ({catalogue_path})")
    if plan_target is not None:
        print(f"Target for the week: {plan_target.text}")
    for day in days:
        groups = ", ".join(day["groups"]) or "no groups"
        print(f"\n{day['name']}  [{groups}]")
        width = max([len(e["name"]) for e in day["exercises"]] + [10])
        for number, exercise in enumerate(day["exercises"], 1):
            kind = " (custom)" if exercise["custom"] else ""
            if exercise["group"] == "cardio":
                aim = "cardio"
            else:
                own = day["targets"].get(exercise["id"])
                if exercise["timed"]:
                    # A hold is planned in sets; its seconds are logged, not set.
                    sets = (own or plan_target).sets
                    aim = f"{sets} sets, held" + ("" if own else " (plan)")
                else:
                    aim = own.text if own else f"{plan_target.text} (plan)"
            print(f"  {number:>2}. {exercise['name']:<{width}}  {aim}{kind}")

    for title, lines in (("Will not import", report.fatal), ("Problems", report.problems), ("Notes", report.notes)):
        if lines:
            print(f"\n{title}:")
            for line in lines:
                print(f"  - {line}")

    print()
    if report.fatal:
        print(f"✗ The app would refuse this file ({len(report.fatal)} fatal). Fix those first.")
        return 2
    if report.problems:
        print(f"✗ {len(report.problems)} problem(s): those lines would be skipped. Fix them before handing the file over.")
        return 1
    if report.extra:
        print("✓ Senku will import this cleanly — including the other sections noted above.")
    else:
        print("✓ Senku will import this cleanly. It replaces the plan and adds any new exercises; nothing else changes.")
    return 0


# MARK: - Finding exercises

ABBREVIATIONS = {
    "db": "dumbbell", "dbs": "dumbbell", "bb": "barbell", "kb": "kettlebell", "bw": "bodyweight",
    "inc": "incline", "dec": "decline", "ext": "extension", "ext.": "extension",
    "lat": "lat", "lats": "lat", "sl": "single", "pulldowns": "pulldown",
}


def words(text):
    out = []
    for raw in re.split(r"[^0-9a-zA-Z]+", unicodedata.normalize("NFKD", text).casefold()):
        if not raw:
            continue
        word = ABBREVIATIONS.get(raw, raw)
        # "ups" as well as "rows": short plurals matter in names like pull-ups.
        out.append(word[:-1] if len(word) > 2 and word.endswith("s") and not word.endswith("ss") else word)
    return out


def score(exercise, query):
    """(score, why): exact name, a name containing it, or shared words."""
    names = [exercise["name"]] + exercise["aliases"]
    if Library.is_named(exercise, query):
        return 100, "exact"
    needle = search_key(query)
    for name in names:
        hay = search_key(name)
        if needle and (needle in hay or (len(needle) > 3 and needle.endswith("s") and needle[:-1] in hay)):
            return 80, "name contains it"
    wanted = set(words(query))
    if not wanted:
        return 0, ""
    # How much of the query the name covers, then — between equals — how
    # little of the name is left over: "pull-ups" is nearer Pull-Up than
    # Neutral-Grip Pull-Up.
    best = (0.0, 0.0)
    for name in names:
        own = set(words(name))
        have = own | set(words(exercise["equipment"]))
        shared = wanted & have
        if shared:
            best = max(best, (len(shared) / len(wanted), len(shared & own) / len(own)))
    recall, precision = best
    return (int(60 * recall + 10 * precision), f"{round(100 * recall)}% of the words") if recall else (0, "")


def describe(exercise):
    extras = []
    if exercise["aliases"]:
        extras.append("also: " + ", ".join(exercise["aliases"]))
    if exercise["timed"]:
        extras.append("held")
    return f"{exercise['name']}  [{exercise['group']}, {exercise['equipment']}]" + (
        "  — " + "; ".join(extras) if extras else ""
    )


# MARK: - Extracting text

def column_index(reference):
    letters = re.match(r"[A-Z]+", reference).group(0)
    number = 0
    for letter in letters:
        number = number * 26 + ord(letter) - 64
    return number - 1


def extract_xlsx(path):
    ns = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
          "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
    with zipfile.ZipFile(path) as book:
        shared = []
        if "xl/sharedStrings.xml" in book.namelist():
            root = ElementTree.fromstring(book.read("xl/sharedStrings.xml"))
            for item in root.findall("m:si", ns):
                shared.append("".join(t.text or "" for t in item.iter(f"{{{ns['m']}}}t")))
        workbook = ElementTree.fromstring(book.read("xl/workbook.xml"))
        rels = ElementTree.fromstring(book.read("xl/_rels/workbook.xml.rels"))
        targets = {r.get("Id"): r.get("Target") for r in rels}
        out = []
        for sheet in workbook.find("m:sheets", ns):
            rid = sheet.get(f"{{{ns['r']}}}id")
            target = targets[rid].lstrip("/")
            target = target if target.startswith("xl/") else "xl/" + target
            root = ElementTree.fromstring(book.read(target))
            out.append(f"=== Sheet: {sheet.get('name')} ===")
            for row in root.iter(f"{{{ns['m']}}}row"):
                cells = {}
                for cell in row.findall("m:c", ns):
                    kind, value = cell.get("t"), cell.find("m:v", ns)
                    if kind == "s" and value is not None:
                        text = shared[int(value.text)]
                    elif kind == "inlineStr":
                        text = "".join(t.text or "" for t in cell.iter(f"{{{ns['m']}}}t"))
                    else:
                        text = value.text if value is not None else ""
                    if text not in (None, ""):
                        cells[column_index(cell.get("r"))] = text
                if cells:
                    width = max(cells) + 1
                    out.append("\t".join(cells.get(i, "") for i in range(width)))
        return "\n".join(out)


def extract_docx(path):
    ns = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"
    with zipfile.ZipFile(path) as doc:
        root = ElementTree.fromstring(doc.read("word/document.xml"))
    out = []
    body = root.find(f"{ns}body")
    for block in body:
        if block.tag == f"{ns}p":
            out.append("".join(t.text or "" for t in block.iter(f"{ns}t")))
        elif block.tag == f"{ns}tbl":
            for row in block.iter(f"{ns}tr"):
                cells = ["".join(t.text or "" for t in cell.iter(f"{ns}t")) for cell in row.iter(f"{ns}tc")]
                out.append("\t".join(cells))
    return "\n".join(line for line in out if line.strip())


def extract_pdf(path):
    try:
        from pypdf import PdfReader  # optional
        return "\n".join(page.extract_text() or "" for page in PdfReader(str(path)).pages)
    except ImportError:
        pass
    if shutil.which("pdftotext"):
        return subprocess.run(["pdftotext", "-layout", str(path), "-"], capture_output=True, text=True).stdout
    sys.exit("Cannot read PDFs here (no pypdf, no pdftotext). Read the PDF directly, or ask for a text copy.")


def extract(path):
    suffix = path.suffix.lower()
    if suffix in (".xlsx", ".xlsm"):
        return extract_xlsx(path)
    if suffix == ".docx":
        return extract_docx(path)
    if suffix == ".pdf":
        return extract_pdf(path)
    if suffix in (".xls", ".doc", ".numbers", ".pages"):
        sys.exit(f"{suffix} is an older or Apple format. Export it as .xlsx, .docx, .csv or PDF first.")
    text = path.read_text(encoding="utf-8", errors="replace")
    if suffix in (".csv", ".tsv"):
        rows = csv.reader(io.StringIO(text), delimiter="\t" if suffix == ".tsv" else ",")
        return "\n".join("\t".join(row) for row in rows)
    return text


# MARK: - Sync

def catalogue_markdown(catalogue):
    """The exercise list as Markdown. The app writes the same text, byte for byte."""
    lines = [
        "# Senku exercise catalogue",
        "",
        "Name exercises in a plan by **Name** (an alias works too, unless it is shared).",
        "Anything not listed here goes in `customExercises`.",
        "",
    ]
    for group in catalogue.groups:
        lines += [f"## {group}", "", "| Name | Also called | Equipment | Notes |", "| --- | --- | --- | --- |"]
        for e in sorted((e for e in catalogue.exercises if e["group"] == group), key=lambda e: e["name"]):
            note = "held (seconds)" if e["timed"] else ("cardio" if group == "cardio" else "")
            lines.append(f"| {e['name']} | {', '.join(e['aliases'])} | {e['equipment']} | {note} |")
        lines.append("")
    lines += ["## Muscle ids (for customExercises.regionIDs)", "", "| id | Muscle | Group |", "| --- | --- | --- |"]
    for region in catalogue.regions.values():
        lines.append(f"| {region['id']} | {region['name']} | {region['workoutGroup']} |")
    lines.append("")
    return "\n".join(lines)


def prompt_markdown(catalogue_md):
    """Everything a chat AI needs in one paste: instructions, format, exercises."""
    intro = (SKILL / "reference" / "prompt-intro.md").read_text(encoding="utf-8")
    fmt = (SKILL / "reference" / "format.md").read_text(encoding="utf-8")
    fmt = fmt.replace("# The plan file", "# The file format", 1)
    fmt = fmt.replace("(`scripts/senku_plan.py regions`)", "(see the muscle id table at the end)")
    return intro.rstrip("\n") + "\n\n" + fmt.rstrip("\n") + "\n\n" + catalogue_md


def copy_into_app(repo):
    """Mirror the hand-written skill files into the app's bundle."""
    destination = repo / APP_COPY
    if destination.exists():
        shutil.rmtree(destination)
    for source in sorted(SKILL.rglob("*")):
        relative = source.relative_to(SKILL).as_posix()
        if source.is_dir() or "__pycache__" in relative or source.name == ".DS_Store":
            continue
        if relative in GENERATED or relative.split("/")[0] in GENERATED:
            continue
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
    return destination


# MARK: - Command line

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--catalogue", help="Path to ExerciseCatalogue.json (found automatically otherwise).")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("validate").add_argument("file")
    finding = commands.add_parser("find")
    finding.add_argument("query", nargs="+")
    finding.add_argument("--limit", type=int, default=5)
    listing = commands.add_parser("list")
    listing.add_argument("--group")
    commands.add_parser("regions")
    commands.add_parser("extract").add_argument("file")
    commands.add_parser("sync")
    args = parser.parse_args()

    if args.command == "extract":
        print(extract(Path(args.file)))
        return 0

    path, source = locate_catalogue(args.catalogue)
    catalogue = Catalogue(path)

    if args.command == "validate":
        try:
            document = json.loads(Path(args.file).read_text(encoding="utf-8"))
        except json.JSONDecodeError as error:
            print(f"✗ Not valid JSON: {error}")
            return 2
        if source == "live" and BUNDLED.is_file() and BUNDLED.read_bytes() != path.read_bytes():
            print("Note: this skill's bundled catalogue is out of date — run `sync`.")
        report, plan_target, days = validate(document, catalogue)
        return print_report(report, plan_target, days, source, path)

    if args.command == "find":
        query = " ".join(args.query)
        scored = [(*score(e, query), e) for e in catalogue.exercises]
        ranked = sorted((t for t in scored if t[0] > 0), key=lambda t: (-t[0], t[2]["name"]))[: args.limit]
        if not ranked:
            print(f"Nothing like “{query}”. Try other words, or add it to customExercises.")
        for _, why, e in ranked:
            print(f"{describe(e)}   <{why}>")
        return 0

    if args.command == "list":
        for group in catalogue.groups:
            if args.group and group_named(args.group, [group]) is None:
                continue
            print(f"== {group} ==")
            for e in sorted((e for e in catalogue.exercises if e["group"] == group), key=lambda e: e["name"]):
                print(f"  {describe(e)}")
        return 0

    if args.command == "regions":
        for group in catalogue.groups:
            regions = [r for r in catalogue.regions.values() if r["workoutGroup"] == group]
            if regions:
                print(f"== {group} ==")
                for region in regions:
                    print(f"  {region['id']:<28} {region['name']}")
        return 0

    if args.command == "sync":
        if source != "live":
            sys.exit("Run this inside the Senku repository; there is no live catalogue to copy from here.")
        BUNDLED.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, BUNDLED)
        markdown = catalogue_markdown(catalogue)
        CATALOGUE_MD.write_text(markdown, encoding="utf-8")
        PROMPT_MD.write_text(prompt_markdown(markdown), encoding="utf-8")
        repo = path.parents[len(IN_REPO.parts) - 1]
        app_copy = copy_into_app(repo)
        print(f"Copied {len(catalogue.exercises)} exercises to {BUNDLED}, wrote {CATALOGUE_MD.name} "
              f"and {PROMPT_MD.name}, and refreshed the app's copy in {app_copy}.")
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
