#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Choosing a muscle group by touching it on a body.
///
/// The exercise picker's first step, by default, with the ring as the other
/// option: the side you are looking at drawn large, the other waiting small in
/// the bottom-right corner. Cardio, which no muscle drawing has, is the heart
/// the picker keeps in its bottom-left corner for both styles. A muscle
/// picks its group, so tapping the lats lands on the back exercises exactly as
/// the back disc in the ring would.
///
/// The drawing is `BodyMap.json`: react-native-body-highlighter's male and
/// female bodies, front and back (MIT — see THIRD_PARTY_NOTICES.md), reduced
/// by `SenkuUI/Tools/build_bodymap.py` to four path commands so the parser
/// below can stay small.
struct BodyMapPicker: View {
    /// Which body to draw — the profile's, read from the environment so the
    /// picker needs no profile passed in from each of its callers.
    @Environment(\.senkuBodySex) private var sex

    /// The room there is. The large figure takes all of it but the hint, so
    /// it is as big as the screen allows on any phone.
    let available: CGSize
    let onPick: (WorkoutGroup) -> Void

    /// The hint line and the gap under it. A fixed height — the line shrinks
    /// rather than grows at large text sizes — because where the figures'
    /// feet land is worked out from it, and the heart is lined up with them.
    static let hintHeight: CGFloat = 16
    static let hintGap: CGFloat = 10
    static let bottomPadding: CGFloat = 12

    /// How tall the map is in a given space: all of it after the hint and the
    /// bottom padding, unless the width runs out first.
    static func mapHeight(in space: CGSize) -> CGFloat {
        let byHeight = space.height - hintHeight - hintGap - bottomPadding
        let byWidth = (space.width - 32) * 2
        return max(min(byHeight, byWidth), 200)
    }

    /// From the bottom of the space up to the line both figures stand on. The
    /// cardio heart sits on the same line, in both styles of picker.
    static func groundInset(in space: CGSize) -> CGFloat {
        max(space.height - hintHeight - hintGap - mapHeight(in: space), bottomPadding)
    }

    /// The side drawn large. The other waits small in the corner.
    @State private var side: BodySide = .front

    /// How much of the map the corner figure takes, each way.
    private let thumbnailScale: CGFloat = 0.28

    var body: some View {
        let height = Self.mapHeight(in: available)

        VStack(spacing: Self.hintGap) {
            Text("Tap a muscle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: Self.hintHeight)

            if let art = BodyMapArt.shared {
                // Half as wide as tall; each figure is fitted inside it at its
                // own proportions, standing on the bottom edge.
                figures(art)
                    .frame(width: height / 2, height: height)
            } else {
                ContentUnavailableView("No body map", systemImage: "figure.stand",
                                       description: Text("BodyMap.json is missing from the build."))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, Self.bottomPadding)
    }

    /// Both sides at once: the chosen one filling the map, the other in the
    /// bottom-right corner.
    ///
    /// One view per side, kept for the life of the picker and only resized —
    /// so turning around is the two figures trading places, the large one
    /// shrinking into the corner as the small one grows out of it, rather than
    /// one drawing replaced by another.
    private func figures(_ art: BodyMapArt) -> some View {
        GeometryReader { geometry in
            let full = geometry.size
            let small = CGSize(width: full.width * thumbnailScale, height: full.height * thumbnailScale)

            ZStack(alignment: .bottomTrailing) {
                ForEach(BodySide.allCases) { candidate in
                    let isMain = candidate == side
                    let size = isMain ? full : small

                    map(art.side(candidate, for: sex), on: candidate)
                        .frame(width: size.width, height: size.height)
                        // Its muscles answer only when it is the large one;
                        // small, the whole figure is one button that turns.
                        .allowsHitTesting(isMain)
                        .overlay {
                            if !isMain {
                                Button {
                                    withAnimation(.spring(duration: 0.45, bounce: 0.15)) {
                                        side = candidate
                                    }
                                } label: {
                                    Color.clear.contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Show \(candidate.title.lowercased())")
                            }
                        }
                        // The small one stays on top, including while it grows
                        // past the other on its way to the middle.
                        .zIndex(isMain ? 0 : 1)
                }
            }
            .frame(width: full.width, height: full.height, alignment: .bottomTrailing)
        }
    }


    private func map(_ art: BodyMapArt.Side, on side: BodySide) -> some View {
        let areas = BodyMapArea.areas(on: side)
        let tracked = Set(areas.flatMap(\.slugs))
        // Head, hands, knees, shins: drawn, so the body reads as a body, but
        // not tappable — the catalogue scores none of them.
        let untracked = art.path(for: art.slugs.filter { !tracked.contains($0) })

        return ZStack {
            BodyArtShape(art: untracked, frame: art.frame)
                .fill(Color.primary.opacity(0.14))

            ForEach(areas) { area in
                let shape = BodyArtShape(art: art.path(for: area.slugs), frame: art.frame)

                Button {
                    onPick(area.group)
                } label: {
                    shape
                }
                // In the group's own colour, at full strength — the same one
                // its disc wears in the ring, so a muscle here and its group
                // there are recognisably the same thing.
                .buttonStyle(BodyAreaButtonStyle(tint: area.group.tint))
                // Each area's view is the size of the whole body; without this
                // the topmost one would take every tap on the map.
                .contentShape(shape)
                .accessibilityLabel("\(area.title), \(area.group.title)")
            }

            BodyArtShape(art: art.outline, frame: art.frame)
                .stroke(Color.primary.opacity(0.45), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct SenkuBodySexKey: EnvironmentKey {
    static let defaultValue: Sex = .male
}

extension EnvironmentValues {
    /// The profile's sex, for drawing a body that looks like the person using
    /// the app. Set once at the root; male until there is a profile, since a
    /// body has to be drawn as one or the other.
    public var senkuBodySex: Sex {
        get { self[SenkuBodySexKey.self] }
        set { self[SenkuBodySexKey.self] = newValue }
    }
}

/// Fills the area in its tint, and lightens it while a finger is on it — the
/// only feedback a shape gets, since the page it opens replaces the map.
private struct BodyAreaButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint.opacity(configuration.isPressed ? 0.55 : 1))
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Which drawn muscles stand for which catalogue regions

enum BodySide: String, CaseIterable, Identifiable {
    case front, back
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// One tappable part of the body: the drawn muscles it is made of, and the
/// catalogue regions it stands for.
///
/// Every catalogue region except cardio's is on at least one side; cardio's is
/// the heart beside the body, ``cardio``. One region has no
/// drawing of its own and is folded into its neighbour: the abductors, which
/// are the glute muscles at the side of the hip, are part of Glutes.
///
/// The same areas serve both bodies — the library names its muscles alike in
/// the male and female drawings.
struct BodyMapArea: Identifiable, Hashable {
    let id: String
    let title: String
    let group: WorkoutGroup
    let regionIDs: [String]
    /// Keys in a side of `BodyMap.json`.
    let slugs: [String]

    static func areas(on side: BodySide) -> [BodyMapArea] {
        side == .front ? front : back
    }

    /// Not on the body — it has no heart drawn — but beside it, as the heart.
    /// Picks cardio in the picker; kept as an area so the map's coverage of
    /// the catalogue can be checked in one place.
    static let cardio = BodyMapArea(
        id: "cardio", title: "Cardio", group: .cardio,
        regionIDs: ["cardio.conditioning"], slugs: []
    )

    static let front: [BodyMapArea] = [
        .init(id: "front.traps", title: "Traps", group: .back,
              regionIDs: ["back.upperTraps"], slugs: ["trapezius"]),
        .init(id: "front.shoulders", title: "Shoulders", group: .shoulder,
              regionIDs: ["shoulder.frontDelts", "shoulder.sideDelts"], slugs: ["deltoids"]),
        .init(id: "front.chest", title: "Chest", group: .chest,
              regionIDs: ["chest.upper", "chest.mid", "chest.lower"], slugs: ["chest"]),
        .init(id: "front.biceps", title: "Biceps", group: .bicep,
              regionIDs: ["bicep.biceps", "bicep.brachialis"], slugs: ["biceps"]),
        .init(id: "front.triceps", title: "Triceps", group: .tricep,
              regionIDs: ["tricep.longHead", "tricep.lateralHead", "tricep.medialHead"], slugs: ["triceps"]),
        .init(id: "front.forearms", title: "Forearms", group: .forearm,
              regionIDs: ["forearm.flexors", "forearm.brachioradialis"],
              slugs: ["forearm-brachioradialis", "forearm-flexors"]),
        .init(id: "front.abs", title: "Abs", group: .abs,
              regionIDs: ["abs.upper", "abs.lower"], slugs: ["abs-upper", "abs-lower"]),
        .init(id: "front.obliques", title: "Obliques", group: .abs,
              regionIDs: ["abs.obliques"], slugs: ["obliques"]),
        .init(id: "front.quads", title: "Quads", group: .legs,
              regionIDs: ["legs.quads"], slugs: ["quadriceps"]),
        .init(id: "front.innerThigh", title: "Inner thigh", group: .legs,
              regionIDs: ["legs.adductors"], slugs: ["adductors"]),
        .init(id: "front.calves", title: "Calves", group: .legs,
              regionIDs: ["legs.calves"], slugs: ["calves"]),
    ]

    static let back: [BodyMapArea] = [
        .init(id: "back.traps", title: "Traps", group: .back,
              regionIDs: ["back.upperTraps"], slugs: ["trapezius"]),
        .init(id: "back.rearDelts", title: "Rear delts", group: .shoulder,
              regionIDs: ["shoulder.rearDelts"], slugs: ["deltoids"]),
        .init(id: "back.midBack", title: "Mid back", group: .back,
              regionIDs: ["back.midBack"], slugs: ["upper-back-scapular"]),
        .init(id: "back.lats", title: "Lats", group: .back,
              regionIDs: ["back.lats"], slugs: ["lats"]),
        .init(id: "back.lowerBack", title: "Lower back", group: .back,
              regionIDs: ["back.lowerBack"], slugs: ["lower-back"]),
        .init(id: "back.triceps", title: "Triceps", group: .tricep,
              regionIDs: ["tricep.longHead", "tricep.lateralHead", "tricep.medialHead"],
              slugs: ["triceps-long", "triceps-lateral", "triceps-medial"]),
        .init(id: "back.forearms", title: "Forearms", group: .forearm,
              regionIDs: ["forearm.extensors", "forearm.brachioradialis"], slugs: ["forearm"]),
        .init(id: "back.glutes", title: "Glutes", group: .legs,
              regionIDs: ["legs.glutes", "legs.abductors"], slugs: ["gluteal"]),
        .init(id: "back.hamstrings", title: "Hamstrings", group: .legs,
              regionIDs: ["legs.hamstrings"], slugs: ["hamstring"]),
        .init(id: "back.innerThigh", title: "Inner thigh", group: .legs,
              regionIDs: ["legs.adductors"], slugs: ["adductors"]),
        .init(id: "back.calves", title: "Calves", group: .legs,
              regionIDs: ["legs.calves"], slugs: ["calves"]),
    ]
}

// MARK: - The drawing

/// `BodyMap.json`, parsed once into paths in the library's own coordinates.
struct BodyMapArt: Sendable {
    struct Side: Sendable {
        /// The body as drawn — outline, hair and every muscle — rather than the
        /// viewBox the library draws it in. The viewBoxes leave different
        /// margins under the feet (6.6% of the height on the male drawings, 1%
        /// on the female back), so fitting to them would stand each figure at
        /// a different height; fitted to the body, every one's feet are on the
        /// bottom edge.
        let frame: CGRect
        let outline: Path
        let parts: [String: Path]
        /// The same, piece by piece — a left and a right chest rather than one
        /// path — for cutting a piece along lines that mirror side to side.
        let pieces: [String: [Path]]

        var slugs: [String] { Array(parts.keys) }

        func path(for slugs: [String]) -> Path {
            var combined = Path()
            for slug in slugs {
                if let part = parts[slug] { combined.addPath(part) }
            }
            return combined
        }
    }

    struct Body: Sendable {
        let front: Side
        let back: Side
    }

    let male: Body
    let female: Body

    func side(_ side: BodySide, for sex: Sex) -> Side {
        let body = sex == .female ? female : male
        return side == .front ? body.front : body.back
    }

    static let shared: BodyMapArt? = {
        struct Raw: Decodable {
            struct RawSide: Decodable {
                let outline: String
                let parts: [String: [String]]
            }
            struct RawBody: Decodable {
                let front: RawSide
                let back: RawSide
            }
            let male: RawBody
            let female: RawBody
        }

        guard let url = Bundle.module.url(forResource: "BodyMap", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode(Raw.self, from: data)
        else { return nil }

        func side(_ raw: Raw.RawSide) -> Side? {
            let outline = path(raw.outline)
            let pieces = raw.parts.mapValues { $0.map(path) }
            let parts = pieces.mapValues { paths in
                var combined = Path()
                for piece in paths { combined.addPath(piece) }
                return combined
            }
            let drawn = parts.values.reduce(outline.boundingRect) { $0.union($1.boundingRect) }
            guard !drawn.isEmpty else { return nil }
            // A hair of room all round, so the outline's stroke is not shaved
            // off at the edge it is fitted to.
            return Side(frame: drawn.insetBy(dx: -4, dy: -4), outline: outline, parts: parts, pieces: pieces)
        }
        func body(_ raw: Raw.RawBody) -> Body? {
            guard let front = side(raw.front), let back = side(raw.back) else { return nil }
            return Body(front: front, back: back)
        }
        guard let male = body(raw.male), let female = body(raw.female) else { return nil }
        return BodyMapArt(male: male, female: female)
    }()

    /// Reads the normalised form only: absolute `M`, `L`, `C` and `Z`, numbers
    /// separated by spaces. Anything richer was flattened by the build script,
    /// which is what keeps this a dozen lines rather than an SVG parser.
    static func path(_ d: String) -> Path {
        var path = Path()
        var command: Character?
        var numbers: [CGFloat] = []
        var token = ""

        func endNumber() {
            if let value = Double(token) { numbers.append(CGFloat(value)) }
            token = ""
        }
        func point(_ i: Int) -> CGPoint { CGPoint(x: numbers[i], y: numbers[i + 1]) }
        func flush() {
            endNumber()
            switch command {
            case "M" where numbers.count >= 2: path.move(to: point(0))
            case "L" where numbers.count >= 2: path.addLine(to: point(0))
            case "C" where numbers.count >= 6:
                path.addCurve(to: point(4), control1: point(0), control2: point(2))
            case "Z": path.closeSubpath()
            default: break
            }
            numbers.removeAll(keepingCapacity: true)
        }

        for character in d {
            if character.isLetter {
                flush()
                command = character
            } else if character == " " {
                endNumber()
            } else {
                token.append(character)
            }
        }
        flush()
        return path
    }
}

/// A path in the drawing's coordinates, its frame scaled to fit the rect and
/// placed in it by `anchor`.
struct BodyArtShape: Shape {
    let art: Path
    let frame: CGRect
    /// Where the fitted frame sits in the rect when their proportions differ.
    /// Bottom by default: a body stands on the ground.
    var anchor: UnitPoint = .bottom

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / frame.width, rect.height / frame.height)
        let x = rect.minX + (rect.width - frame.width * scale) * anchor.x - frame.minX * scale
        let y = rect.minY + (rect.height - frame.height * scale) * anchor.y - frame.minY * scale
        return art.applying(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: x, ty: y))
    }
}
#endif
