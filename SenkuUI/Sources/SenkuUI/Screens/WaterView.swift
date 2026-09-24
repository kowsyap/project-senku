#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Water: how much today, how much is left, and one tap to add a glass.
///
/// The screen is opened six times a day for two seconds each, so the top of it
/// is the number and the buttons, and everything that is read once — the goal's
/// arithmetic, the containers, the reminders — is below or behind a sheet.
public struct WaterView: View {
    @Bindable private var store: WaterStore
    @Bindable private var workouts: WorkoutStore

    private let profile: ProfileStore.Profile?

    @State private var isEditingGoal = false
    @State private var isShowingStreaks = false
    @State private var isShowingSettings = false
    @State private var customAmount: Double?
    @State private var isAddingCustom = false

    public init(
        store: WaterStore,
        workouts: WorkoutStore,
        profile: ProfileStore.Profile?
    ) {
        self.store = store
        self.workouts = workouts
        self.profile = profile
    }

    private var today: WaterDay {
        store.day(profile: profile, workouts: workouts)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                bottleCard
                quickAdd
                if store.settings.takesCreatine { creatineCard }
                historyCard
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .senkuBottomBarInset()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingSettings = true } label: {
                    StackedActionLabel("Settings", symbol: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isAddingCustom = true } label: {
                    StackedActionLabel("Log", symbol: "plus")
                }
                .accessibilityLabel("Log another amount")
            }
        }
        .sheet(isPresented: $isAddingCustom) {
            CustomAmountSheet { millilitres in
                store.add(millilitres: millilitres)
                afterLogging()
                isAddingCustom = false
            } onCancel: {
                isAddingCustom = false
            }
        }
        .sheet(isPresented: $isEditingGoal) {
            NavigationStack {
                WaterGoalEditor(store: store, goal: today.goal)
            }
            .presentationDetents([.medium])
        }
        .navigationDestination(isPresented: $isShowingStreaks) {
            StreaksView(tracks: tracks)
        }
        .navigationDestination(isPresented: $isShowingSettings) {
            WaterSettingsView(store: store)
        }
        .senkuPushed(isShowingStreaks, isShowingSettings)
    }

    // MARK: - The number

    private var bottleCard: some View {
        let day = today

        return Card {
            HStack(alignment: .center, spacing: 20) {
                Bottle(fraction: day.fraction, isMet: day.isMet)
                    .frame(width: 86, height: 132)

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Int(day.totalML.rounded()).formatted())")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Senku.Palette.deficit)
                    + Text(" ml")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // The sentence the shape cannot say. Never optional.
                    // Without the percentage — it is inside the bottle now.
                    // The accessibility value below still carries it, because
                    // VoiceOver cannot see the bottle at all.
                    Text(day.written)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(day.isMet
                         ? (day.overML > 0 ? "\(Int(day.overML)) ml over" : "Target met")
                         : "\(Int(day.remainingML)) ml to go")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(day.isMet ? Senku.Palette.surplus : Color.primary)

                    Button {
                        isEditingGoal = true
                    } label: {
                        Text(day.goal.explanation)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .underline()
                    }
                    .buttonStyle(.plain)

                    Button {
                        isShowingStreaks = true
                    } label: {
                        Label("Streaks", systemImage: "flame.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Senku.Palette.caution.opacity(0.18), in: .capsule)
                            .foregroundStyle(Senku.Palette.caution)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Water today")
            .accessibilityValue(day.spoken)
        }
    }

    /// One tap per container, which is the whole feature.
    ///
    /// Nothing else lives on this row. Undo has gone — a mis-tap is removed
    /// from today's list below, which is the same gesture with the advantage of
    /// saying which drink it is removing — and the containers are edited from
    /// the one settings page, rather than having a second way in here.
    private var quickAdd: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(store.settings.containers) { container in
                    Button {
                        store.add(millilitres: container.millilitres, container: container)
                        afterLogging()
                    } label: {
                        VStack(spacing: 3) {
                            VesselIcon(vessel: .forSize(container.millilitres), size: 22)
                                .frame(height: 24)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text("\(Int(container.millilitres))")
                                    .font(.headline)
                                    .monospacedDigit()
                                Text("ml")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }

                            Text(container.name)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Senku.Palette.deficit.opacity(0.15))
                        )
                        .foregroundStyle(Senku.Palette.deficit)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log \(Int(container.millilitres)) millilitres, \(container.name)")
                }
            }
        }
    }

    // MARK: - Creatine

    private var creatineCard: some View {
        Card("Creatine") {
            // A checkbox, not a switch. A switch is for a setting that stays
            // put — "I take creatine" is one — while this is a thing you do
            // once a day and tick off, and a row of switches on one screen
            // makes the two look like the same kind of decision.
            Button {
                store.setCreatine(!store.tookCreatine())
                Feedback.control()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: store.tookCreatine() ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundStyle(store.tookCreatine() ? Senku.Palette.surplus : Color.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Taken today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.primary)
                        // Saturation is the mechanism, so consecutive days is
                        // the only figure about creatine worth reporting — a
                        // single dose means nothing on its own.
                        Text(store.creatineStreak > 0
                             ? "\(store.creatineStreak) day\(store.creatineStreak == 1 ? "" : "s") in a row"
                             : "It works by staying topped up, not by any one dose")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Creatine taken today")
            .accessibilityValue(store.tookCreatine() ? "Yes" : "No")

            Divider()

            creatineWeek
        }
    }

    /// The same seven days the water chart covers, so the two read together.
    private var creatineWeek: some View {
        let calendar = Calendar.current
        let days: [Date] = (0 ..< 7).compactMap {
            calendar.date(byAdding: .day, value: -(6 - $0), to: .now)
        }

        return HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                let taken = store.tookCreatine(on: day)

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(taken ? Senku.Palette.surplus : Color.secondary.opacity(0.15))
                        .frame(height: 26)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(taken ? 1 : 0)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .strokeBorder(
                                    Senku.Palette.deficit,
                                    lineWidth: calendar.isDateInToday(day) ? 1.5 : 0
                                )
                        )

                    Text(day.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue(taken ? "Taken" : "Not taken")
            }
        }
    }

    // MARK: - History

    private var historyCard: some View {
        let week = store.log.recentTotals(days: 7).reversed()
        // The tallest bar in view, so a week where nothing reached the target
        // still has shape rather than seven stubs. The dashed goal line is what
        // says where the target is.
        let goal = today.goal.totalML
        let ceiling = max(goal, week.map(\.totalML).max() ?? 0)

        return Card("Water intake") {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(week), id: \.date) { day in
                    // Each day against the goal it actually had — a training
                    // day asks for more, and judging Tuesday by today's target
                    // is the app marking a day it never set.
                    let dayGoal = store.goal(profile: profile, workouts: workouts, on: day.date).totalML
                    let met = dayGoal > 0 && day.totalML >= dayGoal

                    VStack(spacing: 4) {
                        let fraction = ceiling > 0 ? min(1, day.totalML / ceiling) : 0

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.quaternary.opacity(0.5))
                                .frame(height: 64)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(met ? Senku.Palette.surplus : Senku.Palette.deficit)
                                .frame(height: max(2, 64 * fraction))
                        }
                        .overlay(alignment: .bottom) {
                            // Where the target sits on this scale.
                            if ceiling > 0, dayGoal > 0, dayGoal <= ceiling {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.5))
                                    .frame(height: 1)
                                    .offset(y: -64 * (dayGoal / ceiling))
                            }
                        }

                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(Int(day.totalML)) millilitres")
                }
            }

            if !today.entries.isEmpty {
                Divider()

                // Every drink today, not the last six. The cap made a long day
                // look like a short one and put the list at odds with the
                // bottle above it, which has always counted all of them.
                ForEach(today.entries) { entry in
                    HStack {
                        Text("\(Int(entry.millilitres)) ml")
                            .font(.subheadline)
                            .monospacedDigit()
                        Spacer()
                        Text(entry.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            store.delete(entry)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// What the streak screen draws. Calories will be a fourth entry here when
    /// there is something to count.
    private var tracks: [StreakTrack] {
        var tracks: [StreakTrack] = [
            StreakTrack(
                id: "water",
                title: "Water",
                detail: "Days you hit the target",
                symbol: "drop.fill",
                tint: Senku.Palette.deficit,
                days: metWaterDays()
            )
        ]

        if store.settings.takesCreatine {
            tracks.append(
                StreakTrack(
                    id: "creatine",
                    title: "Creatine",
                    detail: "Days you took it",
                    symbol: "pills.fill",
                    tint: Senku.Palette.surplus,
                    days: store.creatineDays
                )
            )
        }
        return tracks
    }

    /// Days whose total reached that day's goal.
    ///
    /// Recomputed rather than recorded, so a target that changes — a new
    /// weight, creatine started, a workout logged late — is reflected in the
    /// history rather than leaving yesterday judged against a number that no
    /// longer exists. The training-day bump is resolved per day, which is the
    /// part that would be wrong if this were stored at the time.
    private func metWaterDays(days: Int = 35) -> Set<Date> {
        let calendar = Calendar.current

        return Set(
            store.log.recentTotals(days: days).compactMap { day in
                let goal = store.goal(profile: profile, workouts: workouts, on: day.date)
                guard goal.totalML > 0, day.totalML >= goal.totalML else { return nil }
                return calendar.startOfDay(for: day.date)
            }
        )
    }

    /// Every path that logs a drink comes through here.
    private func afterLogging() {
        Feedback.control()
        #if canImport(UserNotifications) && !os(macOS)
        // Met the target? The rest of today's reminders are cancelled, because
        // nagging past success is how a reminder gets switched off for good.
        WaterReminders.refresh(settings: store.settings, isMet: today.isMet)
        #endif
    }
}

/// A bottle that fills up. Decorative — the figure beside it is the record.
private struct Bottle: View {
    let fraction: Double
    let isMet: Bool

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: proxy.size.width * 0.28, style: .continuous)

            ZStack(alignment: .bottom) {
                shape.fill(.quaternary.opacity(0.4))

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: isMet
                                ? [Senku.Palette.surplus, Senku.Palette.surplus.opacity(0.7)]
                                : [Senku.Palette.deficit, Senku.Palette.deficit.opacity(0.65)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: proxy.size.height * fraction)
                    .animation(.snappy(duration: 0.35), value: fraction)

                shape.strokeBorder(.quaternary, lineWidth: 2)

                // Inside the bottle, where the eye already is — and white on
                // the water, plain on the empty part, so it stays readable as
                // the level rises past it. The watch page does the same.
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(fraction > 0.55 ? Color.white : Color.secondary)
                    .frame(maxHeight: .infinity)
            }
            .clipShape(shape)
        }
        .accessibilityHidden(true)
    }
}

/// Typing an amount that is not one of the containers.
private struct CustomAmountSheet: View {
    let onAdd: (Double) -> Void
    let onCancel: () -> Void

    @State private var millilitres: Double = 330

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Amount") {
                        HStack {
                            TextField("330", value: $millilitres, format: .number)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 90)
                                .monospacedDigit()
                            Text("ml").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .dismissableKeyboard()
            .navigationTitle("Log a Drink")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { onAdd(millilitres) }
                        .disabled(millilitres <= 0)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}

/// Setting a target by hand, or going back to the computed one.
private struct WaterGoalEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: WaterStore
    let goal: WaterGoal

    @State private var target: Double = 2500

    var body: some View {
        Form {
            Section {
                LabeledContent("Target") {
                    HStack {
                        TextField("2500", value: $target, format: .number)
                            #if os(iOS)
                            .keyboardType(.numberPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 90)
                            .monospacedDigit()
                        Text("ml").foregroundStyle(.secondary)
                    }
                }

                Button("Use the computed target") {
                    store.update { $0.goalOverrideML = nil }
                    dismiss()
                }
                .disabled(!goal.isOverridden)
            } header: {
                Text("Your own target")
            } footer: {
                Text("Senku works out \(Int(goal.baseML + goal.trainingBonusML + goal.creatineBonusML)) ml for today — \(goal.explanation.lowercased()). Setting your own replaces that until you clear it.")
            }
        }
        .dismissableKeyboard()
        .navigationTitle("Daily Target")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    store.update { $0.goalOverrideML = target }
                    dismiss()
                }
            }
        }
        .onAppear { target = goal.totalML }
    }
}

#endif
