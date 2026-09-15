import Foundation
#if os(macOS)
import AppKit
import SwiftUI
import SenkuCore
import SenkuUI

/// Renders a screen to a PNG at a given width and colour scheme.
///
/// Pass plain layout views. `NavigationStack` and `ScrollView` need a real
/// window to size themselves and come out blank here, so render the content
/// they would contain rather than the container. `RestTimerView` offers a
/// `scrolls: false` initializer for exactly this reason.
@MainActor
func render(
    _ view: some View,
    width: CGFloat,
    scheme: ColorScheme,
    to url: URL
) throws {
    let hosted = view
        .frame(width: width)
        .padding(16)
        .background(scheme == .dark ? Color.black : Color.white)
        .environment(\.colorScheme, scheme)

    let renderer = ImageRenderer(content: hosted)
    renderer.scale = 2

    guard let image = renderer.nsImage,
          let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "senku-render", code: 1)
    }
    try png.write(to: url)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let metrics = try BodyMetrics(
    sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 18
)
let plan = NutritionPlan.make(for: metrics, activityLevel: .moderate, goal: .moderateCut)

// A second plan that trips the safety clamp, to check advisory rendering.
let smallMetrics = try BodyMetrics(sex: .female, age: 62, heightCM: 150, weightKG: 45)
let clampedPlan = NutritionPlan.make(
    for: smallMetrics, activityLevel: .sedentary, goal: .aggressiveCut
)

try MainActor.assumeIsolated {
    try render(
        ResultsView(plan: plan, unitSystem: .metric),
        width: 358, scheme: .light,
        to: outputDirectory.appending(path: "results-light.png")
    )
    try render(
        ResultsView(plan: plan, unitSystem: .metric),
        width: 358, scheme: .dark,
        to: outputDirectory.appending(path: "results-dark.png")
    )
    try render(
        ResultsView(plan: plan, unitSystem: .metric),
        width: 620, scheme: .light,
        to: outputDirectory.appending(path: "results-wide.png")
    )
    try render(
        ResultsView(plan: clampedPlan, unitSystem: .imperial),
        width: 358, scheme: .light,
        to: outputDirectory.appending(path: "results-advisories.png")
    )

    // The rest timer in each of the states worth eyeballing. Times are frozen
    // by passing a fixed `now`, so these renders are reproducible.
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    func timer(_ preset: RestPreset, startedAgo: TimeInterval?) -> RestTimer {
        var t = RestTimer(preset: preset)
        if let startedAgo { t.start(at: t0.addingTimeInterval(-startedAgo)) }
        return t
    }

    let states: [(String, RestTimer)] = [
        ("idle", timer(.ninetySeconds, startedAgo: nil)),
        ("running", timer(.twoMinutes, startedAgo: 45)),
        ("ending", timer(.ninetySeconds, startedAgo: 84)),
        ("finished", timer(.sixtySeconds, startedAgo: 95)),
        ("paused", {
            var t = timer(.threeMinutes, startedAgo: 60)
            t.pause(at: t0)
            return t
        }()),
    ]

    for (name, state) in states {
        try render(
            RestTimerView(timer: state, now: t0, scrolls: false),
            width: 358, scheme: .dark,
            to: outputDirectory.appending(path: "rest-\(name).png")
        )
    }
    try render(
        RestTimerView(timer: states[1].1, now: t0, scrolls: false),
        width: 358, scheme: .light,
        to: outputDirectory.appending(path: "rest-running-light.png")
    )

    // The calculator as it opens: empty, with nothing worked out yet.
    try render(
        PlanInputForm(draft: PlanDraft()),
        width: 358, scheme: .dark,
        to: outputDirectory.appending(path: "calc-empty.png")
    )
    try render(
        PlanInputForm(draft: PlanDraft(age: 30, heightCM: 180, weightKG: 80)),
        width: 358, scheme: .dark,
        to: outputDirectory.appending(path: "calc-filled.png")
    )

    // The Home Screen widget: its start buttons, and a rest in progress.
    var widgetTimer = RestTimer(preset: .twoMinutes)
    widgetTimer.start(at: t0.addingTimeInterval(-45))
    try render(
        RestWidgetView(timer: nil, now: t0).frame(height: 150).padding(14),
        width: 158, scheme: .dark,
        to: outputDirectory.appending(path: "widget-start.png")
    )
    try render(
        RestWidgetView(timer: widgetTimer, now: t0).frame(height: 150).padding(14),
        width: 158, scheme: .dark,
        to: outputDirectory.appending(path: "widget-resting.png")
    )
}

print("rendered to \(outputDirectory.path)")
#else
print("senku-render is macOS only")
#endif
