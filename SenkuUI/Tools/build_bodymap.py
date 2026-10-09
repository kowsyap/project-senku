"""Turn react-native-body-highlighter's front/back paths into Senku's BodyMap.json.

Usage: python3 build_bodymap.py <dir> <out.json>
<dir> holds these files from https://github.com/HichamELBSI/react-native-body-highlighter
(MIT; see THIRD_PARTY_NOTICES.md at the repository root), flattened into one directory:
  assets/bodyFront.ts, bodyBack.ts, bodyFemaleFront.ts, bodyFemaleBack.ts
  components/SvgMaleWrapper.tsx, SvgFemaleWrapper.tsx

Every path is normalised to absolute M / L / C / Z, so the Swift side needs only a
four-command parser. Arcs become cubic Béziers; H/V become L; Q/T/S become C.
"""
import json, math, re, sys

# --- Read the TypeScript data ----------------------------------------------

def read_parts(path):
    src = open(path).read()
    parts = {}
    for m in re.finditer(r'slug: "([a-z-]+)".*?path: \{(.*?)\n    \},', src, re.S):
        slug, body = m.group(1), m.group(2)
        paths = []
        for side in ("common", "left", "right"):
            sm = re.search(side + r': \[(.*?)\]', body, re.S)
            if sm:
                for d in re.findall(r'"([^"]+)"', sm.group(1)):
                    paths.append((side, d))
        parts[slug] = paths
    return parts

def read_outlines(path):
    src = open(path).read()
    ds = re.findall(r'd="([^"]+)"', src)
    labels = re.findall(r'accessibilityLabel="(?:fe)?male-body-outline-(front|back)"', src)
    assert len(ds) == len(labels) == 2, (path, len(ds), len(labels))
    return dict(zip(labels, ds))

def read_frames(path):
    """The viewBox the library draws each side in: `side === "front" ? "x y w h" : "x y w h"`."""
    m = re.search(r'side === "front" \? "([^"]+)" : "([^"]+)"', open(path).read())
    front, back = ([float(v) for v in g.split()] for g in m.groups())
    return {"front": front, "back": back}

# --- Tokenise, honouring arc flags written without separators --------------

NUM = re.compile(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')

class Scanner:
    def __init__(self, d):
        self.d, self.i = d, 0
    def skip(self):
        while self.i < len(self.d) and self.d[self.i] in ' ,\t\n\r':
            self.i += 1
    def at_command(self):
        self.skip()
        return self.i < len(self.d) and self.d[self.i].isalpha() and self.d[self.i] not in 'eE'
    def done(self):
        self.skip()
        return self.i >= len(self.d)
    def command(self):
        self.skip()
        c = self.d[self.i]; self.i += 1
        return c
    def number(self):
        self.skip()
        m = NUM.match(self.d, self.i)
        if not m:
            raise ValueError(f"number expected at {self.i}: {self.d[self.i:self.i+20]!r}")
        self.i = m.end()
        return float(m.group())
    def flag(self):
        self.skip()
        c = self.d[self.i]
        if c not in '01':
            raise ValueError(f"flag expected at {self.i}: {self.d[self.i:self.i+20]!r}")
        self.i += 1
        return int(c)

# --- Arc to cubic (SVG implementation notes, F.6.5) ------------------------

def arc_to_cubics(x1, y1, rx, ry, phi, fa, fs, x2, y2):
    if (x1, y1) == (x2, y2):
        return []
    if rx == 0 or ry == 0:
        return [('L', x2, y2)]
    rx, ry = abs(rx), abs(ry)
    p = math.radians(phi)
    cp, sp = math.cos(p), math.sin(p)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p = cp * dx + sp * dy
    y1p = -sp * dx + cp * dy
    lam = (x1p ** 2) / rx ** 2 + (y1p ** 2) / ry ** 2
    if lam > 1:
        s = math.sqrt(lam); rx *= s; ry *= s
    num = rx**2 * ry**2 - rx**2 * y1p**2 - ry**2 * x1p**2
    den = rx**2 * y1p**2 + ry**2 * x1p**2
    co = math.sqrt(max(0, num / den)) if den else 0
    if fa == fs:
        co = -co
    cxp = co * rx * y1p / ry
    cyp = -co * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a
    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not fs and dt > 0:
        dt -= 2 * math.pi
    elif fs and dt < 0:
        dt += 2 * math.pi

    segs = max(1, math.ceil(abs(dt) / (math.pi / 2) - 1e-9))
    delta = dt / segs
    k = 4 / 3 * math.tan(delta / 4)
    out = []
    def pt(t):
        x, y = rx * math.cos(t), ry * math.sin(t)
        return cp * x - sp * y + cx, sp * x + cp * y + cy
    def dpt(t):
        x, y = -rx * math.sin(t), ry * math.cos(t)
        return cp * x - sp * y, sp * x + cp * y
    t = t1
    for _ in range(segs):
        a, b = t, t + delta
        (ax, ay), (bx, by) = pt(a), pt(b)
        (dax, day), (dbx, dby) = dpt(a), dpt(b)
        out.append(('C', ax + k * dax, ay + k * day, bx - k * dbx, by - k * dby, bx, by))
        t = b
    # Land exactly on the endpoint the path asked for.
    last = out[-1]
    out[-1] = last[:5] + (x2, y2)
    return out

# --- Normalise ---------------------------------------------------------------

def normalise(d):
    s = Scanner(d)
    out = []
    x = y = sx = sy = 0.0
    last_c2 = last_q = None   # reflection points for S and T
    cmd = None
    while not s.done():
        if s.at_command():
            cmd = s.command()
        elif cmd is None:
            raise ValueError("path does not start with a command")
        elif cmd in 'Mm':
            cmd = 'L' if cmd == 'M' else 'l'   # implicit lineto after moveto
        rel = cmd.islower()
        C = cmd.upper()
        ox, oy = (x, y) if rel else (0.0, 0.0)
        if C == 'Z':
            out.append(('Z',)); x, y = sx, sy; last_c2 = last_q = None
            cmd = None if s.done() or s.at_command() else cmd
            continue
        if C == 'M':
            x, y = s.number() + ox, s.number() + oy; sx, sy = x, y
            out.append(('M', x, y)); last_c2 = last_q = None
        elif C == 'L':
            x, y = s.number() + ox, s.number() + oy
            out.append(('L', x, y)); last_c2 = last_q = None
        elif C == 'H':
            x = s.number() + (ox if rel else 0)
            out.append(('L', x, y)); last_c2 = last_q = None
        elif C == 'V':
            y = s.number() + (oy if rel else 0)
            out.append(('L', x, y)); last_c2 = last_q = None
        elif C == 'C':
            x1, y1 = s.number() + ox, s.number() + oy
            x2, y2 = s.number() + ox, s.number() + oy
            x, y = s.number() + ox, s.number() + oy
            out.append(('C', x1, y1, x2, y2, x, y)); last_c2 = (x2, y2); last_q = None
        elif C == 'S':
            x1, y1 = (2 * x - last_c2[0], 2 * y - last_c2[1]) if last_c2 else (x, y)
            x2, y2 = s.number() + ox, s.number() + oy
            x, y = s.number() + ox, s.number() + oy
            out.append(('C', x1, y1, x2, y2, x, y)); last_c2 = (x2, y2); last_q = None
        elif C in 'QT':
            if C == 'Q':
                qx, qy = s.number() + ox, s.number() + oy
            else:
                qx, qy = (2 * x - last_q[0], 2 * y - last_q[1]) if last_q else (x, y)
            ex, ey = s.number() + ox, s.number() + oy
            out.append(('C', x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y),
                        ex + 2 / 3 * (qx - ex), ey + 2 / 3 * (qy - ey), ex, ey))
            x, y = ex, ey; last_q = (qx, qy); last_c2 = None
        elif C == 'A':
            rx, ry, phi = s.number(), s.number(), s.number()
            fa, fs = s.flag(), s.flag()
            ex, ey = s.number() + ox, s.number() + oy
            out.extend(arc_to_cubics(x, y, rx, ry, phi, fa, fs, ex, ey))
            x, y = ex, ey; last_c2 = last_q = None
        else:
            raise ValueError(f"unsupported command {cmd}")
    return out

def fmt(n):
    t = f"{n:.2f}".rstrip('0').rstrip('.')
    return '0' if t in ('-0', '') else t

def serialise(segs, dx=0.0):
    parts = []
    for seg in segs:
        c, *v = seg
        xs = [fmt(val - dx) if i % 2 == 0 else fmt(val) for i, val in enumerate(v)]
        parts.append(c + ' '.join(xs))
    return ''.join(parts)

def side(parts, outline, dx):
    muscles = {}
    for slug, paths in parts.items():
        muscles[slug] = [serialise(normalise(d), dx) for _, d in paths]
    return {"width": 724, "height": 1448,
            "outline": serialise(normalise(outline), dx),
            "parts": muscles}

def framed_side(parts, outline, frame):
    """A side in the library's own coordinates, with the viewBox it is drawn in."""
    return {"frame": [round(v, 2) for v in frame],
            "outline": serialise(normalise(outline)),
            "parts": {slug: [serialise(normalise(d)) for _, d in paths]
                      for slug, paths in parts.items()}}

# Senku scores lats and mid back separately; the library draws them as one
# "upper-back". Its pieces by index, found by rendering each one numbered: the
# large wings are the lats, the pieces over the shoulder blades are the
# scapular muscles rows train.
UPPER_BACK = {
    "male": {"lats": [1, 5], "upper-back-scapular": [0, 2, 3, 4]},
    "female": {"lats": [1, 3], "upper-back-scapular": [0, 2]},
}

# Muscles the library draws as several pieces that Senku scores as different
# regions, split into their own keys. Indices found by rendering each piece
# numbered; the two bodies number them differently.
#   abs      top three rows above the navel, and the long piece below it
#   forearm  front: the large outer piece is brachioradialis, the strands the
#            wrist flexors (the back's pieces are all extensors, left whole)
#   triceps  back: the large inner piece is the long head, the outer ones the
#            lateral (upper) and medial (lower) heads
SPLITS = {
    "male": {
        "front": {
            "abs": {"abs-upper": [0, 1, 2, 4, 5, 6], "abs-lower": [3, 7]},
            "forearm": {"forearm-brachioradialis": [0, 3], "forearm-flexors": [1, 2, 4, 5]},
        },
        "back": {
            "triceps": {"triceps-long": [1, 4], "triceps-lateral": [0, 3], "triceps-medial": [2, 5]},
        },
    },
    "female": {
        "front": {
            "abs": {"abs-upper": [0, 2, 3, 4, 5, 7], "abs-lower": [1, 6]},
            "forearm": {"forearm-brachioradialis": [2, 7], "forearm-flexors": [0, 1, 3, 4, 5, 6]},
        },
        "back": {
            "triceps": {"triceps-long": [2, 3], "triceps-lateral": [0, 4], "triceps-medial": [1, 5]},
        },
    },
}

def split_pieces(parts, sex, side):
    for slug, split in SPLITS[sex][side].items():
        pieces = parts.pop(slug)
        used = sorted(i for idx in split.values() for i in idx)
        assert used == list(range(len(pieces))), f"{sex} {side} {slug}: {len(pieces)} pieces, split covers {used}"
        for key, idx in split.items():
            parts[key] = [pieces[i] for i in idx]

def split_upper_back(parts, sex):
    upper = parts.pop("upper-back")
    split = UPPER_BACK[sex]
    used = sorted(i for idx in split.values() for i in idx)
    assert used == list(range(len(upper))), f"{sex}: upper-back has {len(upper)} pieces, split covers {used}"
    for key, idx in split.items():
        parts[key] = [upper[i] for i in idx]

def body(here, sex, front_ts, back_ts, wrapper):
    front, back = read_parts(f"{here}/{front_ts}"), read_parts(f"{here}/{back_ts}")
    split_upper_back(back, sex)
    split_pieces(front, sex, "front")
    split_pieces(back, sex, "back")
    outlines, frames = read_outlines(f"{here}/{wrapper}"), read_frames(f"{here}/{wrapper}")
    return {"front": framed_side(front, outlines["front"], frames["front"]),
            "back": framed_side(back, outlines["back"], frames["back"])}

if __name__ == "__main__":
    HERE, OUT = sys.argv[1], sys.argv[2]
    doc = {
        "source": "react-native-body-highlighter (male and female, front and back), https://github.com/HichamELBSI/react-native-body-highlighter",
        "license": "MIT, Copyright (c) 2022 ELABBASSI Hicham. See THIRD_PARTY_NOTICES.md.",
        "note": "Paths normalised to absolute M/L/C/Z in the library's own coordinates; frame is the viewBox the library draws that side in.",
        "male": body(HERE, "male", "bodyFront.ts", "bodyBack.ts", "SvgMaleWrapper.tsx"),
        "female": body(HERE, "female", "bodyFemaleFront.ts", "bodyFemaleBack.ts", "SvgFemaleWrapper.tsx"),
    }
    json.dump(doc, open(OUT, "w"), separators=(",", ":"))
    print("wrote", OUT)
