#if !os(watchOS)
import SwiftUI
import SenkuCore

/// A personal record as a picture, for sending to a friend or posting as a
/// story.
///
/// Drawn at a story's shape, 9:16, and rendered at three times its point size
/// so it comes out at 1080 × 1920 — the size Instagram and WhatsApp stories
/// fill without cropping, and still a picture that reads in a chat. Always
/// dark, whatever the phone's theme: it is going to be seen on someone else's.
///
/// Everything on it is what the record page already shows. Nothing leaves the
/// phone except the image, and only when the share sheet is used.
struct RecordShareCard: View {
    let exerciseName: String
    let groupTitle: String
    let tint: Color
    /// The lift itself: "100 kg × 5", "2:30", "Bodyweight × 20".
    let headline: String
    let date: Date
    /// "≥ 120 kg", or nothing for a hold or a lift with no weight.
    let estimate: String?
    /// How far it beat the record before it: "+5 kg", "+2 reps".
    let gain: String?
    /// Every record's figure, oldest first, for the line along the bottom.
    let history: [Double]
    let contributions: [String: Double]
    let sex: Sex

    /// In points; the image is three times this.
    static let size = CGSize(width: 360, height: 640)
    static let renderScale: CGFloat = 3

    private static let ink = Color(red: 0.05, green: 0.05, blue: 0.08)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 30)

            Text(groupTitle.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.5))

            Text(exerciseName)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.top, 2)

            Text(headline)
                .font(.system(size: 68, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .foregroundStyle(
                    LinearGradient(colors: [.white, tint], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: tint.opacity(0.6), radius: 18)
                .padding(.top, 10)

            HStack(spacing: 10) {
                if let gain {
                    Label(gain, systemImage: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.18), in: Capsule())
                }
                if let estimate {
                    Text("Est. 1 Rep Max \(Text(estimate).foregroundStyle(.white).bold())")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding(.top, 6)

            if history.count >= 2 {
                progress
                    .padding(.top, 26)
            }

            Spacer(minLength: 12)

            if hasMap {
                BodyHighlight { part in
                    part.share(of: contributions).map(BodyHighlight.heat)
                }
                .frame(height: history.count >= 2 ? 218 : 280)
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 16)

            footer
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .padding(.bottom, 26)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(background)
        .environment(\.colorScheme, .dark)
        .environment(\.senkuBodySex, sex)
    }

    private var hasMap: Bool {
        (BodyMapPart.front + BodyMapPart.back).contains { $0.share(of: contributions) != nil }
    }

    /// Every record on the way here, joined up, with the last one lit.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RecordSparkline(values: history, closed: true)
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.32), tint.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    ))
                RecordSparkline(values: history)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                GeometryReader { proxy in
                    let points = RecordSparkline.points(history, in: CGRect(origin: .zero, size: proxy.size))
                    ForEach(points.indices, id: \.self) { index in
                        let isLast = index == points.count - 1
                        Circle()
                            .fill(isLast ? Color.white : tint)
                            .frame(width: isLast ? 10 : 6, height: isLast ? 10 : 6)
                            .shadow(color: isLast ? tint : .clear, radius: 6)
                            .position(points[index])
                    }
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 5)
        }
    }

    private var header: some View {
        HStack {
            Label("PERSONAL RECORD", systemImage: "trophy.fill")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(tint)

            Spacer()

            Text(date.formatted(.dateTime.day().month(.abbreviated).year()))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image("SenkuMark", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(height: 28)
            Text("SENKU")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
    }

    /// Near-black, lit from the top in the muscle's colour.
    private var background: some View {
        ZStack {
            Self.ink
            RadialGradient(
                colors: [tint.opacity(0.55), tint.opacity(0)],
                center: UnitPoint(x: 0.85, y: 0.02),
                startRadius: 0,
                endRadius: 460
            )
            RadialGradient(
                colors: [tint.opacity(0.18), tint.opacity(0)],
                center: UnitPoint(x: 0.1, y: 1.0),
                startRadius: 0,
                endRadius: 380
            )
        }
    }

    /// The card as an image, at story resolution.
    @MainActor
    func rendered() -> Image? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = Self.renderScale
        #if os(iOS)
        return renderer.uiImage.map { Image(uiImage: $0) }
        #else
        return renderer.nsImage.map { Image(nsImage: $0) }
        #endif
    }
}

#if os(iOS)
extension RecordShareCard {
    @MainActor
    func renderedUIImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = Self.renderScale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// The system share sheet, handed a plain picture.
///
/// Not SwiftUI's `ShareLink`: it offers an `Image` as a lazily exported
/// transferable, which Instagram's extension cannot open — it said "content
/// currently unavailable" — while a `UIImage` is what every app's extension
/// expects. Presented over whatever is on top, which is the preview sheet.
@MainActor
enum RecordSharing {
    static func present(image: UIImage, message: String) {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.keyWindow?.rootViewController else { return }
        while let presented = top.presentedViewController { top = presented }

        let controller = UIActivityViewController(
            activityItems: [image, ShareMessage(text: message)],
            applicationActivities: nil
        )
        controller.popoverPresentationController?.sourceView = top.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 0, height: 0
        )
        top.present(controller, animated: true)
    }
}

/// The line that goes with the picture, for the apps that take one.
///
/// Instagram and Facebook take a picture and nothing else: offered a caption
/// too, their extensions refuse the lot. Saving to Photos has nowhere to put
/// it. Everyone else — Messages, WhatsApp — gets it.
private final class ShareMessage: NSObject, UIActivityItemSource {
    let text: String

    init(text: String) { self.text = text }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType type: UIActivity.ActivityType?
    ) -> Any? {
        guard let type else { return text }
        let id = type.rawValue.lowercased()
        if id.contains("instagram") || id.contains("facebook") || type == .saveToCameraRoll {
            return nil
        }
        return text
    }
}
#endif

/// Every record joined up, oldest on the left. Flat when they are all equal,
/// rather than dividing by nothing.
struct RecordSparkline: Shape {
    let values: [Double]
    var closed = false

    static func points(_ values: [Double], in rect: CGRect) -> [CGPoint] {
        guard values.count >= 2, let low = values.min(), let high = values.max() else { return [] }
        let span = high - low
        return values.enumerated().map { index, value in
            CGPoint(
                x: rect.minX + rect.width * CGFloat(index) / CGFloat(values.count - 1),
                y: span == 0
                    ? rect.midY
                    : rect.maxY - rect.height * CGFloat((value - low) / span)
            )
        }
    }

    func path(in rect: CGRect) -> Path {
        let points = Self.points(values, in: rect)
        guard !points.isEmpty else { return Path() }

        var path = Path()
        path.addLines(points)
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// The card, as it will look, with the button that sends it.
///
/// A preview first rather than straight to the share sheet: what goes to a
/// friend should be something you have seen.
struct RecordShareSheet: View {
    let card: RecordShareCard
    /// Goes with the image where the app takes text too, as Messages does.
    let message: String
    let onClose: () -> Void

    @State private var image: Image?
    #if os(iOS)
    @State private var uiImage: UIImage?
    #endif

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                GeometryReader { proxy in
                    let size = RecordShareCard.size
                    let scale = min(proxy.size.width / size.width, proxy.size.height / size.height)
                    card
                        .scaleEffect(scale)
                        .frame(width: size.width * scale, height: size.height * scale)
                        .clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                #if os(iOS)
                if let uiImage {
                    Button {
                        RecordSharing.present(image: uiImage, message: message)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(card.tint)
                    .controlSize(.large)
                } else {
                    ProgressView().frame(height: 50)
                }
                #else
                if let image {
                    ShareLink(
                        item: image,
                        message: Text(message),
                        preview: SharePreview(card.exerciseName, image: image)
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(card.tint)
                    .controlSize(.large)
                } else {
                    ProgressView().frame(height: 50)
                }
                #endif
            }
            .padding()
            .navigationTitle("Share record")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
            .task {
                #if os(iOS)
                uiImage = card.renderedUIImage()
                #else
                image = card.rendered()
                #endif
            }
        }
    }
}

extension RecordShareCard {
    /// The card for an exercise's best record.
    init?(
        entry: ExerciseRecords,
        exercise: Exercise?,
        name: String,
        unitSystem: UnitSystem,
        sex: Sex
    ) {
        guard let best = entry.best else { return nil }
        let isBodyweight = exercise?.equipment == .bodyweight

        func lift(_ record: PersonalRecord) -> String {
            if let seconds = record.seconds {
                return record.isBodyweightOnly
                    ? Display.hold(seconds)
                    : "+\(Display.tidyMass(record.weightKG, in: unitSystem)) · \(Display.hold(seconds))"
            }
            if record.isBodyweightOnly { return "BW × \(record.reps)" }
            let weight = Display.tidyMass(record.weightKG, in: unitSystem)
            return isBodyweight ? "+\(weight) × \(record.reps)" : "\(weight) × \(record.reps)"
        }

        // The figure a record is judged on, so the line climbs the way the
        // page ranks them.
        func figure(_ record: PersonalRecord) -> Double {
            if let seconds = record.seconds { return seconds }
            if record.isBodyweightOnly { return Double(record.reps) }
            return record.weightKG
        }

        // What it beat: the best of everything before it.
        let before = ExerciseRecords(
            exerciseID: entry.exerciseID,
            records: entry.records.filter { $0.date < best.date }
        ).best
        var gain: String?
        if let before {
            if let now = best.seconds, let then = before.seconds, now > then {
                gain = "+\(Display.hold(now - then))"
            } else if !best.isTimed, best.weightKG > before.weightKG, !best.isBodyweightOnly {
                gain = "+\(Display.tidyMass(best.weightKG - before.weightKG, in: unitSystem))"
            } else if !best.isTimed, best.weightKG == before.weightKG, best.reps > before.reps {
                let more = best.reps - before.reps
                gain = "+\(more) \(more == 1 ? "rep" : "reps")"
            }
        }

        let estimate = entry.bestEstimated.flatMap { record in
            record.estimatedOneRepMax.map { single in
                let text = Display.tidyMass(single, in: unitSystem)
                return record.isEstimateLowerBound ? "≥ \(text)" : text
            }
        }

        self.init(
            exerciseName: name,
            groupTitle: exercise?.workoutGroup.title ?? "Strength",
            tint: exercise?.workoutGroup.tint ?? Senku.Palette.protein,
            headline: lift(best),
            date: best.date,
            estimate: entry.isTimed ? nil : estimate,
            gain: gain,
            history: entry.records.reversed().map(figure),
            contributions: exercise?.contributions ?? [:],
            sex: sex
        )
    }

    /// The words that go with the picture.
    var message: String {
        "New PR on \(exerciseName): \(headline)"
    }
}
#endif
