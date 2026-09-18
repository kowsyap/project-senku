#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Food: the protein you have had, the calories it came with, and one tap to
/// add the thing you eat every day.
///
/// ## Why protein is the big number
///
/// The app already tells you what to eat. This screen is only about whether you
/// did — and of the four figures it could headline, protein is the one that
/// changes what happens to you: it is what protects lean mass on a cut, it is
/// the hardest target to hit by accident, and it is the one people actually
/// count. Calories matter too, and get a line of their own, but a screen with
/// four equal rings is a screen with no answer on it.
///
/// ## Why there is no food search
///
/// There is no food database, by decision rather than omission — see
/// ``IntakeEntry``. What is here instead is the row of favourites, because the
/// honest observation about eating is that most people eat about eight things,
/// and a button for each beats a search field for all of them.
public struct IntakeView: View {
    @Bindable private var store: IntakeStore

    private let profile: ProfileStore.Profile?
    private let onOpenCalculator: () -> Void

    @State private var isAdding = false
    @State private var editing: IntakeEntry?
    @State private var isShowingStreaks = false
    @State private var isShowingSettings = false
    @State private var quickProtein: Double?

    public init(
        store: IntakeStore,
        profile: ProfileStore.Profile?,
        onOpenCalculator: @escaping () -> Void = {}
    ) {
        self.store = store
        self.profile = profile
        self.onOpenCalculator = onOpenCalculator
    }

    private var today: IntakeDay? { store.day(profile: profile) }

    public var body: some View {
        Group {
            if let today {
                loggedBody(today)
            } else {
                noTargets
            }
        }
        .background(.background)
        .senkuBottomBarInset()
        .toolbar {
            if today != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button { isShowingSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { isAdding = true } label: {
                        StackedActionLabel("Log", symbol: "plus")
                    }
                    .accessibilityLabel("Log food")
                }
            }
        }
        .sheet(isPresented: $isAdding) {
            IntakeEditor(store: store) { isAdding = false }
        }
        .sheet(item: $editing) { entry in
            IntakeEditor(store: store, editing: entry) { editing = nil }
        }
        .navigationDestination(isPresented: $isShowingStreaks) {
            StreaksView(tracks: tracks)
        }
        .navigationDestination(isPresented: $isShowingSettings) {
            IntakeSettingsView(store: store)
        }
    }

    private func loggedBody(_ day: IntakeDay) -> some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                proteinCard(day)
                restCard(day)
                favouritesCard
                if !day.entries.isEmpty { todayCard(day) }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .dismissableKeyboard()
    }

    // MARK: - Protein, which is the point

    private func proteinCard(_ day: IntakeDay) -> some View {
        Card {
            HStack(alignment: .center, spacing: 18) {
                GoalRing(
                    fraction: day.proteinFraction,
                    tint: Senku.Palette.protein,
                    isMet: day.isProteinMet
                ) {
                    VStack(spacing: -2) {
                        Text("\(Int(day.proteinG.rounded()))")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("g")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Protein")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)

                    Text(day.isProteinMet
                         ? "Target met"
                         : "\(Int(day.proteinRemainingG.rounded())) g to go")
                        .font(.headline)
                        .foregroundStyle(day.isProteinMet ? Senku.Palette.surplus : Color.primary)

                    Text("Target \(Int(day.targets.proteinGrams.rounded())) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)

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
            .accessibilityLabel("Food today")
            .accessibilityValue(day.spoken)
        }
    }

    // MARK: - Everything else, smaller

    private func restCard(_ day: IntakeDay) -> some View {
        Card {
            VStack(spacing: 12) {
                calorieRow(day)

                Divider()

                macroBar("Carbs", day.carbsG, day.targets.carbGrams, Senku.Palette.carbs)
                macroBar("Fat", day.fatG, day.targets.fatGrams, Senku.Palette.fat)
                macroBar("Fibre", day.fiberG, day.targets.fiberGrams, Senku.Palette.surplus)
            }
        }
    }

    /// Calories as a band rather than a bar, because the bar would be a lie:
    /// filling it up reads as success, and past the top it goes on reading as
    /// success while you eat into next week's deficit.
    private func calorieRow(_ day: IntakeDay) -> some View {
        let over = day.calories - day.targets.calories

        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calories")
                    .font(.subheadline.weight(.semibold))
                Text(day.isUnlogged
                     ? "Nothing logged yet"
                     : (abs(over) < 1
                        ? "Exactly on target"
                        : over > 0
                            ? "\(Int(over.rounded())) over target"
                            : "\(Int((-over).rounded())) to go"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(day.calories.rounded()).formatted())")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(day.isCaloriesMet ? Senku.Palette.surplus : Color.primary)
                Text("/ \(Int(day.targets.calories.rounded()).formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calories")
        .accessibilityValue("\(Int(day.calories.rounded())) of \(Int(day.targets.calories.rounded()))")
    }

    private func macroBar(_ title: String, _ value: Double, _ target: Double, _ tint: Color) -> some View {
        let fraction = target > 0 ? min(1, value / target) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Spacer()
                Text("\(Int(value.rounded())) / \(Int(target.rounded())) g")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary.opacity(0.5))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(2, proxy.size.width * fraction))
                        .animation(.snappy(duration: 0.3), value: fraction)
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value.rounded())) of \(Int(target.rounded())) grams")
    }

    // MARK: - Logging

    private var favouritesCard: some View {
        Card("Quick add") {
            if store.favourites.isEmpty {
                Text("Save the things you eat often and they get a button here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(store.orderedFavourites) { favourite in
                        Button {
                            store.log(favourite)
                            Feedback.control()
                        } label: {
                            VStack(spacing: 2) {
                                Text(favourite.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundStyle(Color.primary)
                                Text("\(Int(favourite.proteinG.rounded())) g · \(Int(favourite.calories.rounded())) kcal")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Senku.Palette.protein.opacity(0.14))
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Log \(favourite.name)")
                    }
                }
            }

            Divider()

            // The bare case, and deliberately the shortest path on the screen:
            // a number, a button, done. Somebody who knows their shake is 30 g
            // should not have to open a form to say so.
            HStack(spacing: 10) {
                Text("Protein only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)

                Spacer(minLength: 0)

                NumericField(value: $quickProtein, range: 0 ... 300, unit: "g", width: 58)

                Button {
                    guard let grams = quickProtein, grams > 0 else { return }
                    store.addProtein(grams)
                    quickProtein = nil
                    Feedback.control()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                        .background(Senku.Palette.protein.opacity(0.18), in: .circle)
                        .foregroundStyle(Senku.Palette.protein)
                }
                .buttonStyle(.plain)
                .disabled((quickProtein ?? 0) <= 0)
                .accessibilityLabel("Log protein")
            }
        }
    }

    private func todayCard(_ day: IntakeDay) -> some View {
        Card("Today") {
            ForEach(day.entries) { entry in
                Button {
                    editing = entry
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name ?? "Protein")
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(entry.proteinG.rounded())) g")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(Senku.Palette.protein)
                            Text("\(Int(entry.calories.rounded())) kcal")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if entry.id != day.entries.last?.id { Divider() }
            }
        }
    }

    // MARK: - Streaks

    /// Both habits, side by side. They are genuinely different questions — you
    /// can hit protein on a day you ate 3,500 calories — and a single "nutrition"
    /// streak would hide whichever one you are failing.
    private var tracks: [StreakTrack] {
        [
            StreakTrack(
                id: "protein",
                title: "Protein",
                detail: "Days you reached the target",
                symbol: "fork.knife",
                tint: Senku.Palette.protein,
                days: store.proteinDays(profile: profile)
            ),
            StreakTrack(
                id: "calories",
                title: "Calories",
                detail: "Days you landed within 10% of the target",
                symbol: "flame.fill",
                tint: Senku.Palette.carbs,
                days: store.calorieDays(profile: profile)
            ),
        ]
    }

    // MARK: - No profile

    /// Without targets this screen is a list of numbers with nothing to compare
    /// them to, which is worse than not being here.
    private var noTargets: some View {
        ContentUnavailableView {
            Label("No targets yet", systemImage: "fork.knife")
        } description: {
            Text("Work out your numbers in Quick calc and save them, and this screen will show what you have eaten against them.")
        } actions: {
            Button("Open quick calc", action: onOpenCalculator)
                .buttonStyle(.borderedProminent)
        }
    }
}

/// A ring that fills towards a target, with whatever you like in the middle.
///
/// Distinct from ``MacroRing``, which divides a whole into three shares. This
/// one answers "how far through are you", which is a different question and
/// wants a different shape: one arc, from the top, clockwise.
struct GoalRing<Label: View>: View {
    let fraction: Double
    let tint: Color
    let isMet: Bool
    @ViewBuilder let label: Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 11)

            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(
                    isMet ? Senku.Palette.surplus : tint,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.snappy(duration: 0.35), value: fraction)

            label
        }
        .accessibilityHidden(true)
    }
}
#endif
