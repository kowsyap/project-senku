#if os(iOS)
import Foundation
import UIKit
import CoreGraphics

/// A chart the report can draw, described rather than rendered.
///
/// ## Why a description and not an image
///
/// The report is drawn straight into a PDF context, so a chart can be *vector*
/// — real lines at whatever resolution the thing printing it has, rather than a
/// bitmap that goes soft on paper. Describing the chart here and drawing it at
/// render time keeps that, and keeps pagination able to ask "how tall is this"
/// before deciding which page it goes on.
struct ReportChart {
    enum Kind {
        /// A line through every point, for something continuous: body weight.
        case line
        /// A bar per point, for something counted a day at a time: water, food.
        case bars
    }

    struct Point {
        let label: String
        let value: Double
    }

    let title: String
    let kind: Kind
    let points: [Point]
    /// The target line, where there is one. Drawn dashed, so the bars are read
    /// against something rather than only against each other.
    let reference: Double?
    let referenceLabel: String?
    let tint: UIColor
    /// What a value reads as: "2,450 ml", "82.1 kg".
    let format: (Double) -> String

    static let height: CGFloat = 150
    private static let plotInset: CGFloat = 28   // room for the axis labels

    init(
        title: String,
        kind: Kind,
        points: [Point],
        reference: Double? = nil,
        referenceLabel: String? = nil,
        tint: UIColor,
        format: @escaping (Double) -> String
    ) {
        self.title = title
        self.kind = kind
        self.points = points
        self.reference = reference
        self.referenceLabel = referenceLabel
        self.tint = tint
        self.format = format
    }

    /// Fewer than two points is not a chart, it is a dot — and the figure it
    /// would show is already in the table above it.
    var isDrawable: Bool { points.count >= 2 }

    func draw(in rect: CGRect, context: CGContext) {
        guard isDrawable else { return }

        let values = points.map(\.value)
        // Zero is always in view for bars: a bar chart with a floating baseline
        // exaggerates every difference on it, which is the oldest way there is
        // to lie with a chart. A line of body weights is the opposite case —
        // starting at zero would flatten a real trend into a straight line — so
        // it gets a padded range around what actually happened.
        let top: Double
        let bottom: Double
        switch kind {
        case .bars:
            bottom = 0
            top = max(values.max() ?? 1, reference ?? 0) * 1.1
        case .line:
            let low = values.min() ?? 0
            let high = values.max() ?? 1
            let padding = max((high - low) * 0.25, 0.5)
            bottom = low - padding
            top = high + padding
        }
        let span = max(top - bottom, 0.0001)

        drawLabel(title, at: CGPoint(x: rect.minX, y: rect.minY), size: 11, weight: .semibold, color: .black)

        let plot = CGRect(
            x: rect.minX + Self.plotInset,
            y: rect.minY + 18,
            width: rect.width - Self.plotInset,
            height: rect.height - 34
        )

        func y(_ value: Double) -> CGFloat {
            plot.maxY - CGFloat((value - bottom) / span) * plot.height
        }

        context.saveGState()

        // The frame: two lines rather than a box, which is all the eye needs to
        // find the baseline.
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.25).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: plot.minX, y: plot.minY))
        context.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
        context.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
        context.strokePath()

        drawLabel(format(top), at: CGPoint(x: rect.minX, y: plot.minY - 4), size: 7, color: .gray)
        drawLabel(format(bottom), at: CGPoint(x: rect.minX, y: plot.maxY - 7), size: 7, color: .gray)

        if let reference, reference > bottom, reference < top {
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.45).cgColor)
            context.setLineWidth(0.7)
            context.setLineDash(phase: 0, lengths: [3, 3])
            context.move(to: CGPoint(x: plot.minX, y: y(reference)))
            context.addLine(to: CGPoint(x: plot.maxX, y: y(reference)))
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])

            if let referenceLabel {
                drawLabel(
                    referenceLabel,
                    at: CGPoint(x: plot.maxX - 60, y: y(reference) - 9),
                    size: 7,
                    color: .darkGray,
                    width: 60,
                    alignment: .right
                )
            }
        }

        switch kind {
        case .bars:
            let slot = plot.width / CGFloat(points.count)
            let width = max(1.5, slot * 0.62)

            for (index, point) in points.enumerated() {
                let centre = plot.minX + slot * (CGFloat(index) + 0.5)
                let height = max(0.5, plot.maxY - y(point.value))
                let bar = CGRect(x: centre - width / 2, y: plot.maxY - height, width: width, height: height)

                // Bars that reached the target are solid; the rest are faded.
                // The dashed line says where the target is, and this says which
                // bars made it without the reader having to measure.
                let met = reference.map { point.value >= $0 } ?? true
                context.setFillColor(tint.withAlphaComponent(met ? 0.95 : 0.45).cgColor)
                context.fill(bar)
            }

        case .line:
            context.setStrokeColor(tint.cgColor)
            context.setLineWidth(1.4)
            context.setLineJoin(.round)

            for (index, point) in points.enumerated() {
                let x = points.count == 1
                    ? plot.midX
                    : plot.minX + plot.width * CGFloat(index) / CGFloat(points.count - 1)
                let position = CGPoint(x: x, y: y(point.value))
                index == 0 ? context.move(to: position) : context.addLine(to: position)
            }
            context.strokePath()
        }

        // Only the ends are labelled. Thirty dates across 500 points is a grey
        // smear, and the dates in between are in the table this sits above.
        if let first = points.first?.label, let last = points.last?.label, first != last {
            drawLabel(first, at: CGPoint(x: plot.minX, y: plot.maxY + 3), size: 7, color: .gray)
            drawLabel(
                last,
                at: CGPoint(x: plot.maxX - 70, y: plot.maxY + 3),
                size: 7,
                color: .gray,
                width: 70,
                alignment: .right
            )
        }

        context.restoreGState()
    }

    private func drawLabel(
        _ text: String,
        at point: CGPoint,
        size: CGFloat,
        weight: UIFont.Weight = .regular,
        color: UIColor,
        width: CGFloat = 200,
        alignment: NSTextAlignment = .left
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment

        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
        attributed.draw(in: CGRect(x: point.x, y: point.y, width: width, height: size + 4))
    }
}
#endif
