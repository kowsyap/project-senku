#if !os(watchOS)
import SwiftUI
import SenkuCore

/// One habit's worth of days, for the streak screen to draw.
///
/// A description rather than a view, so adding calories later is a fourth entry
/// in an array rather than a fourth calendar to build and keep in step with the
/// other three.
struct StreakTrack: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    /// The days it was achieved, as start-of-day dates.
    let days: Set<Date>

    func streak(forgiven: Set<Date>) -> Streak {
        Streak.of(days, forgiven: forgiven)
    }
}

/// Thirty days of every habit the app tracks, side by side.
///
/// Read-only, deliberately. A calendar you can edit is a calendar that can be
/// made to say anything, and a streak is only worth looking at if it is a
/// record of what happened rather than of what you would like to have happened.
/// Today is still editable where the habit is logged — the water screen's tick
/// — and a day that has passed is finished.
struct StreaksView: View {
    let tracks: [StreakTrack]

    @State private var forgiven = ForgivenDayStore()
    /// The day the sheet is asking about, and the habit it belongs to.
    @State private var asking: Excuse?

    private struct Excuse: Identifiable {
        let track: StreakTrack
        let date: Date
        var id: String { "\(track.id)-\(date.timeIntervalSince1970)" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                ForEach(tracks) { track in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            header(track)
                            MonthGrid(
                                days: track.days,
                                forgiven: forgiven.days(for: track.id),
                                tint: track.tint
                            ) { day in
                                asking = Excuse(track: track, date: day)
                            }
                        }
                    }
                }

                Text("The last 30 days. Tap a past day you never logged.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .senkuBottomBarInset()
        // An alert rather than an action sheet: this is one question with one
        // answer, and it belongs over the day it is about instead of sliding up
        // from the bottom of the screen.
        .alert(
            asking.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? "",
            isPresented: Binding(get: { asking != nil }, set: { if !$0 { asking = nil } }),
            presenting: asking
        ) { excuse in
            if forgiven.isForgiven(excuse.date, in: excuse.track.id) {
                Button("Count as missed") {
                    forgiven.setForgiven(false, on: excuse.date, in: excuse.track.id)
                }
            } else {
                Button("Never logged") {
                    forgiven.setForgiven(true, on: excuse.date, in: excuse.track.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { excuse in
            Text("\(excuse.track.title): keeps the streak. It cannot be filled in.")
        }
        .navigationTitle("Streaks")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func header(_ track: StreakTrack) -> some View {
        let streak = track.streak(forgiven: forgiven.days(for: track.id))

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: track.symbol)
                .font(.title3)
                .foregroundStyle(track.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                Text(track.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            figure("\(streak.current)", "now", tint: track.tint)
            figure("\(streak.longest)", "best")
        }
    }

    private func figure(_ value: String, _ label: String, tint: Color = .secondary) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundStyle(.tertiary)
        }
    }
}

/// Thirty-something days as whole weeks, filled where the habit was kept.
private struct MonthGrid: View {
    let days: Set<Date>
    let forgiven: Set<Date>
    let tint: Color
    let onPick: (Date) -> Void

    private let weeks = 5
    private let calendar = Calendar.current

    /// Whole Monday-to-Sunday rows ending with this week, so the columns stay
    /// under their weekday letters instead of drifting with the month.
    private var dates: [Date] {
        let today = calendar.startOfDay(for: .now)
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7   // Monday first

        guard let endOfWeek = calendar.date(byAdding: .day, value: 6 - weekday, to: today),
              let start = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: endOfWeek)
        else { return [] }

        return (0 ..< weeks * 7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0 ..< weeks, id: \.self) { week in
                HStack(spacing: 4) {
                    ForEach(0 ..< 7, id: \.self) { weekday in
                        let index = week * 7 + weekday
                        if dates.indices.contains(index) {
                            cell(dates[index])
                        }
                    }
                }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let done = days.contains { calendar.isDate($0, inSameDayAs: day) }
        let excused = !done && forgiven.contains { calendar.isDate($0, inSameDayAs: day) }
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > calendar.startOfDay(for: .now)
        // Only a finished day can be excused: today can still be logged, and
        // tomorrow has not happened.
        let pickable = !isFuture && !isToday

        return Button {
            onPick(day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: 10, weight: done ? .bold : .regular))
                .foregroundStyle(
                    done
                        ? Color.white
                        : Color.secondary.opacity(isFuture ? 0.35 : (excused ? 0.55 : 1))
                )
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(done ? tint : Color.secondary.opacity(isFuture ? 0.04 : 0.12))
                )
                .overlay(
                    // A dashed outline for a day that was never logged: present
                    // but hollow, which is what the day itself is. Nothing like
                    // the filled square of a day you kept, and nothing like the
                    // blank of one you missed.
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(
                            excused ? Color.secondary : Senku.Palette.deficit,
                            style: StrokeStyle(
                                lineWidth: excused ? 1 : (isToday ? 1.5 : 0),
                                dash: excused ? [2.5, 2.5] : []
                            )
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!pickable)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted))
        .accessibilityValue(done ? "Kept" : (excused ? "Never logged" : "Missed"))
        .accessibilityHint(pickable ? "Mark as never logged" : "")
    }
}
#endif
