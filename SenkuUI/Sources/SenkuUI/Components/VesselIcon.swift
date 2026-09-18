#if !os(watchOS)
import SwiftUI

/// A glass, a bottle or a jug, drawn to size.
///
/// SF Symbols has no tumbler and no jug — the drinking vessels it offers are a
/// coffee cup, a mug, a wine glass and a water bottle, none of which is the
/// thing on the table. Rather than label a glass of water with a cup of coffee,
/// the two missing shapes are drawn here and the bottle comes from the system.
struct VesselIcon: View {
    enum Vessel {
        case tumbler, bottle, jug

        /// Chosen by size rather than by name, so a renamed container still
        /// looks like itself.
        static func forSize(_ millilitres: Double) -> Vessel {
            switch millilitres {
            case ..<350: .tumbler
            case ..<700: .bottle
            default: .jug
            }
        }
    }

    let vessel: Vessel
    var size: CGFloat = 22

    var body: some View {
        switch vessel {
        case .bottle:
            // Outlined rather than filled, to sit with the tumbler and the jug
            // — those are drawn as strokes, and a solid bottle between two
            // outlines reads as the odd one out rather than as the middle size.
            Image(systemName: "waterbottle")
                .font(.system(size: size))
        case .tumbler:
            Tumbler().stroke(lineWidth: size * 0.09).frame(width: size * 0.7, height: size)
        case .jug:
            Jug().stroke(lineWidth: size * 0.09).frame(width: size, height: size)
        }
    }
}

/// A straight-sided glass, tapering slightly towards the base.
private struct Tumbler: Shape {
    func path(in rect: CGRect) -> Path {
        let taper = rect.width * 0.12

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - taper, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()

        // The waterline, which is what makes it read as a glass of something
        // rather than as an empty trapezium.
        path.move(to: CGPoint(x: rect.minX + taper * 0.35, y: rect.minY + rect.height * 0.32))
        path.addLine(to: CGPoint(x: rect.maxX - taper * 0.35, y: rect.minY + rect.height * 0.32))

        return path
    }
}

/// A body, a handle and a lip.
private struct Jug: Shape {
    func path(in rect: CGRect) -> Path {
        let bodyWidth = rect.width * 0.62
        let body = CGRect(
            x: rect.minX + rect.width * 0.06,
            y: rect.minY + rect.height * 0.18,
            width: bodyWidth,
            height: rect.height * 0.82
        )

        var path = Path()
        path.addRoundedRect(in: body, cornerSize: CGSize(width: rect.width * 0.1, height: rect.width * 0.1))

        // The lip, poured from the left.
        path.move(to: CGPoint(x: body.minX, y: body.minY + body.height * 0.12))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: body.minX + body.width * 0.28, y: body.minY))

        // The handle, on the right.
        path.move(to: CGPoint(x: body.maxX, y: body.minY + body.height * 0.22))
        path.addQuadCurve(
            to: CGPoint(x: body.maxX, y: body.minY + body.height * 0.72),
            control: CGPoint(x: rect.maxX + rect.width * 0.12, y: body.midY)
        )

        return path
    }
}
#endif
