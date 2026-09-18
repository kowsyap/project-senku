#if os(iOS)
import Foundation
import UIKit
import CoreText
import SenkuCore

/// Everything Senku knows about you, as a PDF you can keep.
///
/// ## Why a PDF and not the JSON
///
/// The JSON import format already exists and is the thing to use for moving
/// data between installs. This is for the other need: a record that outlives
/// the app — something to send to a coach, print, or open in ten years when
/// whatever replaced Senku cannot read its files. So it is laid out to be
/// *read*, not parsed, and it makes no promise of being importable.
///
/// ## How it paginates
///
/// One long attributed string, flowed through Core Text a page at a time:
/// `CTFramesetterCreateFrame` fills a page and reports how much of the string
/// it consumed, and the next page starts there. That is the whole algorithm,
/// and it is why a workout history of any length cannot run off the bottom.
public enum ReportPDF {
    private static let pageSize = CGSize(width: 595, height: 842)  // A4 at 72dpi
    private static let margin: CGFloat = 48

    public static func build(
        profile: ProfileStore.Profile?,
        weights: WeightLogStore,
        records: RecordStore,
        library: ExerciseLibrary,
        plans: TrainingPlanStore,
        workouts: WorkoutStore,
        anime: AnimeStore,
        water: WaterStore,
        intake: IntakeStore,
        unitSystem: UnitSystem
    ) -> URL? {
        let text = compose(
            profile: profile,
            weights: weights,
            records: records,
            library: library,
            plans: plans,
            workouts: workouts,
            anime: anime,
            water: water,
            intake: intake,
            unitSystem: unitSystem
        )

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Senku report \(Self.stamp()).pdf")

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: format()
        )

        do {
            try renderer.writePDF(to: url) { context in
                let framesetter = CTFramesetterCreateWithAttributedString(text)
                let column = CGRect(
                    x: margin,
                    y: margin,
                    width: pageSize.width - 2 * margin,
                    height: pageSize.height - 2 * margin
                )

                var start = 0
                var page = 0
                let total = text.length

                while start < total {
                    context.beginPage()
                    page += 1

                    guard let cgContext = UIGraphicsGetCurrentContext() else { break }

                    // Core Text draws bottom-up; the flip puts the origin back
                    // at the top left where the rest of the layout assumes it.
                    cgContext.textMatrix = .identity
                    cgContext.translateBy(x: 0, y: pageSize.height)
                    cgContext.scaleBy(x: 1, y: -1)

                    let path = CGPath(rect: column, transform: nil)
                    let frame = CTFramesetterCreateFrame(
                        framesetter,
                        CFRangeMake(start, 0),
                        path,
                        nil
                    )
                    CTFrameDraw(frame, cgContext)

                    let consumed = CTFrameGetVisibleStringRange(frame)
                    // A page that fits nothing would loop for ever — a single
                    // word longer than the column, say. Stop rather than hang.
                    guard consumed.length > 0 else { break }
                    start += consumed.length

                    drawFooter(page: page, in: cgContext)
                }
            }
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Content

    private static func compose(
        profile: ProfileStore.Profile?,
        weights: WeightLogStore,
        records: RecordStore,
        library: ExerciseLibrary,
        plans: TrainingPlanStore,
        workouts: WorkoutStore,
        anime: AnimeStore,
        water: WaterStore,
        intake: IntakeStore,
        unitSystem: UnitSystem
    ) -> NSAttributedString {
        let out = NSMutableAttributedString()

        out.append(title("Senku"))
        out.append(body(Date.now.formatted(date: .complete, time: .shortened) + "\n\n"))

        // MARK: Profile
        if let profile {
            out.append(heading("Profile"))
            if let name = profile.name, !name.isEmpty {
                out.append(row("Name", name))
            }
            out.append(row("Sex", profile.metrics.sex.rawValue.capitalized))
            out.append(row("Age", "\(profile.metrics.age)"))
            out.append(row("Height", Display.height(profile.metrics.heightCM, in: unitSystem)))
            out.append(row("Weight", Display.mass(profile.metrics.weightKG, in: unitSystem)))
            if let goal = profile.goalWeightKG {
                out.append(row("Goal weight", Display.mass(goal, in: unitSystem)))
            }
            out.append(row("Activity", profile.activityLevel.title))
            out.append(row("Goal", profile.goal.title))

            let plan = profile.plan
            out.append(row("Maintenance", "\(Int(plan.energy.maintenanceCalories.rounded())) kcal"))
            out.append(row("Target", "\(Int(plan.energy.targetCalories.rounded())) kcal"))
            out.append(row(
                "Macros",
                "\(Int(plan.macros.proteinGrams))P · \(Int(plan.macros.carbGrams))C · \(Int(plan.macros.fatGrams))F"
            ))
            out.append(body("\n"))
        }

        // MARK: Weight
        let series = weights.series
        if !weights.weighIns.isEmpty {
            out.append(heading("Weight"))
            if let last = weights.weighIns.first {
                out.append(row("Last reading", "\(Display.mass(last.weightKG, in: unitSystem)) on \(last.date.formatted(date: .abbreviated, time: .omitted))"))
            }
            if let trend = series.trendKG {
                out.append(row("Trend", Display.mass(trend, in: unitSystem)))
            }
            if let weekly = series.weeklyChangeKG {
                out.append(row("Weekly change", Display.massDelta(weekly, in: unitSystem)))
            }
            out.append(row("Readings", "\(weights.weighIns.count)"))
            out.append(body("\n"))

            out.append(subheading("Every reading"))
            for weighIn in weights.weighIns {
                out.append(body("\(weighIn.date.formatted(date: .abbreviated, time: .omitted))   \(Display.mass(weighIn.weightKG, in: unitSystem))\n"))
            }
            out.append(body("\n"))
        }

        // MARK: Records
        let book = records.book
        if !records.records.isEmpty {
            out.append(heading("Personal records"))
            for group in library.catalogue.workoutGroups {
                let ids = Set(library.exercises(in: group).map(\.id))
                let mine = records.records.filter { ids.contains($0.exerciseID) }
                guard !mine.isEmpty else { continue }

                out.append(subheading(group.title))
                for exerciseID in Set(mine.map(\.exerciseID)).sorted() {
                    guard let best = book.records(for: exerciseID).best else { continue }
                    let value = best.isBodyweightOnly && !best.isTimed
                        ? "Bodyweight × \(best.reps)"
                        : Display.set(
                            weightKG: best.weightKG,
                            reps: best.reps,
                            seconds: best.seconds,
                            in: unitSystem
                        )
                    out.append(body("\(library.name(of: exerciseID))   \(value)   \(best.date.formatted(date: .abbreviated, time: .omitted))\n"))
                }
                out.append(body("\n"))
            }
        }

        // MARK: Plan
        if plans.hasPlan {
            out.append(heading("Training plan"))
            for day in plans.days {
                out.append(subheading(day.name))

                let exercises = day.exerciseIDs.compactMap { library.exercise($0) }
                var filed: Set<String> = []

                // Under the muscle rather than in one list, and with each
                // exercise's own share of that muscle beside it — which is what
                // makes the percentage on the heading line check out instead of
                // being a figure the reader has to take on trust.
                for group in day.groups {
                    let coverage = MuscleCoverage.of(exercises, for: group, in: library.catalogue)
                    out.append(body("\(group.title) — \(coverage.percentage)%\n"))

                    let contributors = MuscleCoverage.contributors(
                        among: exercises,
                        to: group,
                        in: library.catalogue
                    )
                    for entry in contributors {
                        filed.insert(entry.exercise.id)
                        let share = Int((entry.fraction * 100).rounded())
                        out.append(body("   • \(entry.exercise.name)   \(share)%\n"))
                    }
                    if contributors.isEmpty {
                        out.append(body("   • nothing yet\n"))
                    }
                    if !coverage.gaps.isEmpty {
                        out.append(body("   missing: \(coverage.gaps.map(\.name).joined(separator: ", "))\n"))
                    }
                    out.append(body("\n"))
                }

                // Anything the day's muscles do not account for still has to
                // appear: it is on the checklist, so a plan that left it out of
                // the report would not be the plan.
                let stranded = exercises.filter { !filed.contains($0.id) }
                if !stranded.isEmpty {
                    out.append(body("Also in this day\n"))
                    for exercise in stranded {
                        out.append(body("   • \(exercise.name)\n"))
                    }
                    out.append(body("\n"))
                }
            }
        }

        // MARK: Workouts
        if !workouts.history.isEmpty {
            out.append(heading("Workouts"))
            for session in workouts.history {
                out.append(subheading("\(session.dayName) — \(session.date.formatted(date: .abbreviated, time: .omitted))"))
                for entry in session.entries where entry.hasAnyWork {
                    let detail: String
                    if let cardio = entry.cardio {
                        detail = Display.cardio(cardio, for: library.exercise(entry.exerciseID), in: unitSystem)
                    } else if entry.sets.isEmpty {
                        detail = "done, nothing logged"
                    } else {
                        detail = entry.sets
                            .map { "\(Display.mass($0.weightKG, in: unitSystem, decimals: 0))×\($0.reps)" }
                            .joined(separator: "  ")
                    }
                    out.append(body("   \(library.name(of: entry.exerciseID))   \(detail)\n"))
                }
                out.append(body("\n"))
            }
        }

        // MARK: Water
        //
        // Thirty days rather than every drink ever logged. A glass at 11:04 is
        // data the app needs and nobody reads; the day's total against the
        // day's goal is the thing a person — or a coach — can act on.
        if !water.entries.isEmpty {
            out.append(heading("Water"))

            let days = water.log.recentTotals(days: 30)
            let goalToday = water.goal(profile: profile, workouts: workouts)
            out.append(row("Today's goal", "\(Int(goalToday.totalML)) ml — \(goalToday.explanation)"))

            let logged = days.filter { $0.totalML > 0 }
            if !logged.isEmpty {
                let mean = logged.reduce(0) { $0 + $1.totalML } / Double(logged.count)
                out.append(row("Average, days logged", "\(Int(mean.rounded())) ml"))
                out.append(row("Days logged", "\(logged.count) of 30"))
            }

            if water.settings.takesCreatine {
                let streak = Streak.of(water.creatineDays)
                out.append(row("Creatine", "\(streak.current) day streak, best \(streak.longest), \(streak.total) days in all"))
            }
            out.append(body("\n"))

            out.append(subheading("Last 30 days"))
            for day in days where day.totalML > 0 {
                let goal = water.goal(profile: profile, workouts: workouts, on: day.date)
                let met = goal.totalML > 0 && day.totalML >= goal.totalML ? "met" : ""
                out.append(body("\(day.date.formatted(date: .abbreviated, time: .omitted))   \(Int(day.totalML)) of \(Int(goal.totalML)) ml   \(met)\n"))
            }
            out.append(body("\n"))
        }

        // MARK: Food
        if !intake.entries.isEmpty {
            out.append(heading("Food"))

            if let targets = intake.targets(profile: profile) {
                out.append(row("Target", "\(Int(targets.calories.rounded())) kcal"))
                out.append(row(
                    "Macro targets",
                    "\(Int(targets.proteinGrams))P · \(Int(targets.carbGrams))C · \(Int(targets.fatGrams))F"
                ))

                // The figure the maintenance estimate is built from, and the
                // count beside it — an average over four logged days out of
                // thirty is not the same claim as one over thirty, and a report
                // that printed only the number would hide the difference.
                if let average = intake.log.averageCalories(days: 30) {
                    out.append(row(
                        "Average intake",
                        "\(Int(average.calories.rounded())) kcal over \(average.loggedDays) logged day\(average.loggedDays == 1 ? "" : "s")"
                    ))
                }

                let days = intake.log.recentDays(30, targets: targets).filter { !$0.isUnlogged }
                let proteinMet = days.filter(\.isProteinMet).count
                let caloriesMet = days.filter(\.isCaloriesMet).count
                out.append(row("Protein target met", "\(proteinMet) of \(days.count) logged days"))
                out.append(row("Calories within 10%", "\(caloriesMet) of \(days.count) logged days"))
                out.append(body("\n"))

                out.append(subheading("Last 30 days"))
                for day in days {
                    out.append(body(
                        "\(day.date.formatted(date: .abbreviated, time: .omitted))   "
                        + "\(Display.gramsValue(day.proteinG))/\(Int(day.targets.proteinGrams))g P   "
                        + "\(Int(day.calories.rounded()))/\(Int(day.targets.calories.rounded())) kcal\n"
                    ))
                }
                out.append(body("\n"))
            }

            if !intake.favourites.isEmpty {
                out.append(subheading("Quick adds"))
                for favourite in intake.orderedFavourites {
                    let detail = favourite.isCaloriesOnly
                        ? "\(Int(favourite.calories.rounded())) kcal"
                        : "\(Display.gramsValue(favourite.proteinG))P · \(Display.gramsValue(favourite.carbsG))C · \(Display.gramsValue(favourite.fatG))F · \(Int(favourite.calories.rounded())) kcal"
                    out.append(body("\(favourite.name)   \(detail)\n"))
                }
                out.append(body("\n"))
            }
        }

        // MARK: Anime
        if !anime.entries.isEmpty {
            out.append(heading("Anime"))
            for status in AnimeStatus.allCases {
                let shown = anime.list(status: status, sort: .title)
                guard !shown.isEmpty else { continue }

                out.append(subheading("\(status.title) (\(shown.count))"))
                for series in shown {
                    var line = series.title
                    if !series.countSummary.isEmpty { line += "   \(series.countSummary)" }
                    if !series.genres.isEmpty { line += "   \(series.genres.joined(separator: ", "))" }
                    out.append(body(line + "\n"))
                }
                out.append(body("\n"))
            }
        }

        return out
    }

    // MARK: - Type

    private static func title(_ text: String) -> NSAttributedString {
        attributed(text + "\n", font: .systemFont(ofSize: 28, weight: .heavy))
    }

    private static func heading(_ text: String) -> NSAttributedString {
        attributed("\n" + text.uppercased() + "\n", font: .systemFont(ofSize: 15, weight: .bold), spacing: 6)
    }

    private static func subheading(_ text: String) -> NSAttributedString {
        attributed(text + "\n", font: .systemFont(ofSize: 12, weight: .semibold), spacing: 3)
    }

    private static func body(_ text: String) -> NSAttributedString {
        attributed(text, font: .monospacedSystemFont(ofSize: 10, weight: .regular), spacing: 2)
    }

    private static func row(_ label: String, _ value: String) -> NSAttributedString {
        body("\(label.padding(toLength: max(label.count, 16), withPad: " ", startingAt: 0))\(value)\n")
    }

    private static func attributed(
        _ text: String,
        font: UIFont,
        spacing: CGFloat = 2
    ) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacing = spacing
        paragraph.lineBreakMode = .byWordWrapping

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph,
            ]
        )
    }

    // MARK: - Page furniture

    private static func drawFooter(page: Int, in context: CGContext) {
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: pageSize.height)
        context.scaleBy(x: 1, y: -1)

        let text = NSAttributedString(
            string: "Senku · page \(page)",
            attributes: [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.gray,
            ]
        )
        text.draw(at: CGPoint(x: margin, y: pageSize.height - margin + 16))
        context.restoreGState()
    }

    private static func format() -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Senku report",
            kCGPDFContextCreator as String: "Senku",
        ]
        return format
    }

    private static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
#endif
