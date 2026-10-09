#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Both sides of the body, side by side, coloured muscle by muscle — for
/// showing what something trained rather than for choosing.
///
/// The drawing is the picker's (`BodyMapArt`), divided more finely than the
/// picker needs — upper, mid and lower chest; the three triceps heads; upper
/// and lower abs — because what an exercise trains is said in those parts.
/// What each part is coloured is the caller's business: `nil` leaves it grey.
struct BodyHighlight: View {
    @Environment(\.senkuBodySex) private var sex

    let color: (BodyMapPart) -> Color?

    var body: some View {
        if let art = BodyMapArt.shared {
            HStack(spacing: 16) {
                ForEach(BodySide.allCases) { side in
                    figure(art.side(side, for: sex), on: side)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func figure(_ art: BodyMapArt.Side, on side: BodySide) -> some View {
        let parts = BodyMapPart.parts(on: side)
        let tracked = Set(parts.flatMap(\.slugs))
        let untracked = art.path(for: art.slugs.filter { !tracked.contains($0) })

        return ZStack {
            BodyArtShape(art: untracked, frame: art.frame)
                .fill(Color.primary.opacity(0.08))
            ForEach(parts) { part in
                BodyArtShape(art: part.path(in: art), frame: art.frame)
                    .fill(color(part) ?? Color.primary.opacity(0.14))
            }
            BodyArtShape(art: art.outline, frame: art.frame)
                .stroke(Color.primary.opacity(0.4), lineWidth: 0.75)
        }
        .aspectRatio(0.5, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - Colours

    /// Yellow for a muscle an exercise touches, through orange, to red for
    /// one it is *the* exercise for — the scale the percentages above it use.
    static func heat(_ share: Double) -> Color {
        let t = min(max(share, 0), 1)
        let yellow = (r: 1.00, g: 0.82, b: 0.10)
        let red = (r: 0.90, g: 0.12, b: 0.12)
        return Color(
            red: yellow.r + (red.r - yellow.r) * t,
            green: yellow.g + (red.g - yellow.g) * t,
            blue: yellow.b + (red.b - yellow.b) * t
        )
    }

    static let trained = Color(red: 0.20, green: 0.74, blue: 0.36)
    static let missed = Color(red: 0.90, green: 0.20, blue: 0.20)
}

/// A dot and a word, for the colour keys under the bodies.
struct BodyHighlightKey: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Parts

/// The three heads of the pectoral, as they divide on the muscle rather than in
/// stripes.
///
/// The clavicular head is a band along the top, from the collarbone by the
/// sternum, slanting down toward the arm. The abdominal head is a curve along
/// the bottom and outer edge. The sternocostal head is the large fan between.
/// Each piece is cut on its own, with "toward the arm" mirrored for the left
/// and right sides, in coordinates of the piece's box: `u` runs from the
/// sternum (0) to the arm (1), `v` from the top (0) to the bottom (1).
enum ChestHead: Hashable {
    case clavicular
    case sternocostal
    case abdominal

    func region(of piece: Path, bodyCentre: CGFloat) -> Path {
        let box = piece.boundingRect
        // The arm is on whichever side of the piece is away from the middle
        // of the body.
        let armOnLeft = box.midX < bodyCentre
        func point(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            CGPoint(
                x: armOnLeft ? box.maxX - u * box.width : box.minX + u * box.width,
                y: box.minY + v * box.height
            )
        }

        // Above the line from high by the sternum to low by the arm.
        var clavicular = Path()
        clavicular.move(to: point(-0.2, -0.2))
        clavicular.addLine(to: point(1.2, -0.2))
        clavicular.addLine(to: point(1.2, 0.62))
        clavicular.addQuadCurve(to: point(-0.2, 0.14), control: point(0.5, 0.36))
        clavicular.closeSubpath()

        // Below the curve from the arm side of the chest round to its bottom.
        var abdominal = Path()
        abdominal.move(to: point(1.2, 0.52))
        abdominal.addQuadCurve(to: point(-0.05, 1.12), control: point(0.45, 0.70))
        abdominal.addLine(to: point(1.2, 1.2))
        abdominal.closeSubpath()

        switch self {
        case .clavicular:
            return piece.intersection(clavicular)
        case .abdominal:
            return piece.intersection(abdominal)
        case .sternocostal:
            return piece.subtracting(clavicular).subtracting(abdominal)
        }
    }
}

/// A piece of the drawing, and the one or two catalogue regions it stands for.
///
/// Finer than ``BodyMapArea``, which is what the picker taps. The library
/// draws each chest as one piece, so the three chest regions are cut out of
/// it along the way the pectoral's heads actually divide — see ``ChestHead``.
/// The other splits are the library's own pieces, sorted by
/// `build_bodymap.py`.
struct BodyMapPart: Identifiable, Hashable {
    let id: String
    let group: WorkoutGroup
    let regionIDs: [String]
    let slugs: [String]
    /// Which head of the chest piece this is; nil for the whole of its slugs.
    var head: ChestHead? = nil

    static func parts(on side: BodySide) -> [BodyMapPart] {
        side == .front ? front : back
    }

    static let front: [BodyMapPart] = [
        .init(id: "front.traps", group: .back, regionIDs: ["back.upperTraps"], slugs: ["trapezius"]),
        .init(id: "front.shoulders", group: .shoulder,
              regionIDs: ["shoulder.frontDelts", "shoulder.sideDelts"], slugs: ["deltoids"]),
        .init(id: "front.chest.upper", group: .chest, regionIDs: ["chest.upper"], slugs: ["chest"], head: .clavicular),
        .init(id: "front.chest.mid", group: .chest, regionIDs: ["chest.mid"], slugs: ["chest"], head: .sternocostal),
        .init(id: "front.chest.lower", group: .chest, regionIDs: ["chest.lower"], slugs: ["chest"], head: .abdominal),
        .init(id: "front.biceps", group: .bicep,
              regionIDs: ["bicep.biceps", "bicep.brachialis"], slugs: ["biceps"]),
        // From the front the triceps shows only its outer edge.
        .init(id: "front.triceps", group: .tricep, regionIDs: ["tricep.lateralHead"], slugs: ["triceps"]),
        .init(id: "front.brachioradialis", group: .forearm,
              regionIDs: ["forearm.brachioradialis"], slugs: ["forearm-brachioradialis"]),
        .init(id: "front.flexors", group: .forearm, regionIDs: ["forearm.flexors"], slugs: ["forearm-flexors"]),
        .init(id: "front.abs.upper", group: .abs, regionIDs: ["abs.upper"], slugs: ["abs-upper"]),
        .init(id: "front.abs.lower", group: .abs, regionIDs: ["abs.lower"], slugs: ["abs-lower"]),
        .init(id: "front.obliques", group: .abs, regionIDs: ["abs.obliques"], slugs: ["obliques"]),
        .init(id: "front.quads", group: .legs, regionIDs: ["legs.quads"], slugs: ["quadriceps"]),
        .init(id: "front.innerThigh", group: .legs, regionIDs: ["legs.adductors"], slugs: ["adductors"]),
        .init(id: "front.calves", group: .legs, regionIDs: ["legs.calves"], slugs: ["calves"]),
    ]

    static let back: [BodyMapPart] = [
        .init(id: "back.traps", group: .back, regionIDs: ["back.upperTraps"], slugs: ["trapezius"]),
        .init(id: "back.rearDelts", group: .shoulder, regionIDs: ["shoulder.rearDelts"], slugs: ["deltoids"]),
        .init(id: "back.midBack", group: .back, regionIDs: ["back.midBack"], slugs: ["upper-back-scapular"]),
        .init(id: "back.lats", group: .back, regionIDs: ["back.lats"], slugs: ["lats"]),
        .init(id: "back.lowerBack", group: .back, regionIDs: ["back.lowerBack"], slugs: ["lower-back"]),
        .init(id: "back.triceps.long", group: .tricep, regionIDs: ["tricep.longHead"], slugs: ["triceps-long"]),
        .init(id: "back.triceps.lateral", group: .tricep, regionIDs: ["tricep.lateralHead"], slugs: ["triceps-lateral"]),
        .init(id: "back.triceps.medial", group: .tricep, regionIDs: ["tricep.medialHead"], slugs: ["triceps-medial"]),
        .init(id: "back.extensors", group: .forearm, regionIDs: ["forearm.extensors"], slugs: ["forearm"]),
        .init(id: "back.glutes", group: .legs, regionIDs: ["legs.glutes", "legs.abductors"], slugs: ["gluteal"]),
        .init(id: "back.hamstrings", group: .legs, regionIDs: ["legs.hamstrings"], slugs: ["hamstring"]),
        .init(id: "back.innerThigh", group: .legs, regionIDs: ["legs.adductors"], slugs: ["adductors"]),
        .init(id: "back.calves", group: .legs, regionIDs: ["legs.calves"], slugs: ["calves"]),
    ]

    /// The part's outline in the drawing: its pieces, cut to its head.
    func path(in art: BodyMapArt.Side) -> Path {
        guard let head else { return art.path(for: slugs) }
        var cut = Path()
        for slug in slugs {
            for piece in art.pieces[slug] ?? [] {
                cut.addPath(head.region(of: piece, bodyCentre: art.frame.midX))
            }
        }
        return cut
    }

    /// How hard an exercise works this part: its hardest-worked region.
    /// Nil when it works none of them.
    func share(of contributions: [String: Double]) -> Double? {
        regionIDs.compactMap { contributions[$0] }.max()
    }

    /// A muscle counts as trained once the exercises done give one of its
    /// regions at least half an exercise's worth of work. Lower, and a bench
    /// press would turn the triceps green from the share it lends them.
    static let trainedThreshold = 0.5

    enum SessionState: Equatable {
        case trained
        /// In one of the day's groups, and not trained.
        case missed
    }

    /// What a finished session did for this part: trained, missed from the
    /// day's plan, or neither (nil).
    func state(coverage: [String: Double], plannedGroups: Set<WorkoutGroup>) -> SessionState? {
        if regionIDs.contains(where: { (coverage[$0] ?? 0) >= Self.trainedThreshold }) {
            return .trained
        }
        return plannedGroups.contains(group) ? .missed : nil
    }

    /// Each region's coverage from a set of exercises: their contributions
    /// summed, capped at one — the same rule as the coverage percentages.
    static func coverage(of exercises: [Exercise]) -> [String: Double] {
        var coverage: [String: Double] = [:]
        for exercise in exercises {
            for (region, share) in exercise.contributions {
                coverage[region, default: 0] += share
            }
        }
        return coverage.mapValues { min(1, $0) }
    }
}
#endif
