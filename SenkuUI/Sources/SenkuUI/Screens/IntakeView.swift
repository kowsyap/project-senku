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
    @State private var quickCalories: Double?
    @State private var picked: UUID?
    @State private var servings = 1

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
        // A count left over from the last food is a silent way to log twice
        // what you had.
        .onChange(of: picked) { _, _ in servings = 1 }
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
                DualGoalRing(
                    outer: day.calorieFraction,
                    outerTint: calorieTint(day),
                    inner: day.proteinFraction,
                    innerTint: day.isProteinMet ? Senku.Palette.surplus : Senku.Palette.protein
                ) {
                    VStack(spacing: -2) {
                        Text(Display.gramsValue(day.proteinG))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .foregroundStyle(Senku.Palette.protein)
                        Text("g")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 116, height: 116)

                VStack(alignment: .leading, spacing: 5) {
                    legend("Protein", Senku.Palette.protein,
                           day.isProteinMet
                           ? "Target met"
                           : "\(Display.tidyGrams(day.proteinRemainingG)) to go",
                           met: day.isProteinMet)

                    legend("Calories", Senku.Palette.carbs,
                           calorieCaption(day),
                           met: day.isCaloriesMet)

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

    /// One ring, named and coloured, with the figure it is reporting.
    ///
    /// The rings are concentric and unlabelled on their own — which is fine on a
    /// watch face people learn once, and not fine on a screen opened four times
    /// a day. The dot is the same colour as the arc, so which number belongs to
    /// which ring is answered by looking rather than by remembering.
    private func legend(_ title: String, _ tint: Color, _ detail: String, met: Bool) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Circle()
                .fill(met ? Senku.Palette.surplus : tint)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(met ? Senku.Palette.surplus : Color.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    /// Green inside the band, red past it, amber on the way — the one place a
    /// colour carries the judgement, since the arc itself stops at full and
    /// cannot show how far past the target you went.
    private func calorieTint(_ day: IntakeDay) -> Color {
        if day.isOverCalories { return Senku.Palette.warning }
        return day.isCaloriesMet ? Senku.Palette.surplus : Senku.Palette.carbs
    }

    private func calorieCaption(_ day: IntakeDay) -> String {
        let over = day.calories - day.targets.calories
        if day.isUnlogged { return "Nothing logged" }
        if over > 0 { return "\(Int(over.rounded())) over" }
        return "\(Int((-over).rounded())) to go"
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
                Text("\(Display.gramsValue(value)) / \(Int(target.rounded())) g")
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
        .accessibilityValue("\(Display.gramsValue(value)) of \(Int(target.rounded())) grams")
    }

    // MARK: - Logging

    /// Three ways in, in the order they get used.
    ///
    /// A menu rather than a grid of buttons: the grid was one tap, which is
    /// better, but it grows down the screen with every thing you save until the
    /// numbers it is meant to serve are below the fold. A menu costs one extra
    /// tap and stays one line however many favourites you keep.
    private var favouritesCard: some View {
        Card("Quick add") {
            HStack(spacing: 10) {
                Menu {
                    // Names alone. The macros are on the line below once
                    // something is picked, and a menu that repeats them is a
                    // wall of numbers to read before you can find "Shake".
                    ForEach(store.orderedFavourites) { favourite in
                        Button(favourite.name) { picked = favourite.id }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(pickedFavourite?.name ?? "Pick a food")
                            .font(.subheadline)
                            .foregroundStyle(pickedFavourite == nil ? Color.secondary : Color.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.quaternary.opacity(0.5))
                    )
                }
                .disabled(store.favourites.isEmpty)

                addButton(tint: Senku.Palette.protein, enabled: pickedFavourite != nil) {
                    guard let favourite = pickedFavourite else { return }
                    store.log(favourite, servings: servings)
                    picked = nil
                    servings = 1
                    Feedback.control()
                }
                .accessibilityLabel("Add the picked food")
            }

            if let favourite = pickedFavourite {
                HStack(spacing: 10) {
                    // Servings, because two of something is the common case and
                    // pressing add twice makes two rows out of one thing you
                    // ate. Starts at one every time: it is the answer nine
                    // times in ten, and a count left over from the last food is
                    // a silent way to log twice what you had.
                    Stepper(value: $servings, in: 1 ... 20) {
                        Text("\(servings) serving\(servings == 1 ? "" : "s")")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.secondary)
                            .monospacedDigit()
                    }
                    .fixedSize()

                    Spacer(minLength: 0)

                    Text(favouriteDetail(favourite, servings: servings))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else if store.favourites.isEmpty {
                Text("Save the things you eat often — in the editor, or behind the gear — and they appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // The two bare cases, side by side. Somebody who knows their shake
            // is 30 g of protein, or that dinner was about 700 kcal, should not
            // have to open a form to say so — and should not have to invent the
            // half they do not know either.
            HStack(spacing: 10) {
                quickField(
                    "Protein",
                    unit: "g",
                    tint: Senku.Palette.protein,
                    value: $quickProtein,
                    range: 0 ... 300,
                    decimals: 1
                ) {
                    guard let grams = quickProtein, grams > 0 else { return }
                    store.addProtein(grams)
                    quickProtein = nil
                    Feedback.control()
                }

                quickField(
                    "Calories",
                    unit: "kcal",
                    tint: Senku.Palette.carbs,
                    value: $quickCalories,
                    range: 0 ... 5000
                ) {
                    guard let calories = quickCalories, calories > 0 else { return }
                    store.addCalories(calories)
                    quickCalories = nil
                    Feedback.control()
                }
            }
        }
    }

    private var pickedFavourite: FoodFavourite? {
        picked.flatMap { id in store.favourites.first { $0.id == id } }
    }

    /// What one press will actually log, servings included — the figures the
    /// menu no longer carries.
    private func favouriteDetail(_ favourite: FoodFavourite, servings: Int = 1) -> String {
        let multiplier = Double(max(1, servings))
        let calories = Int((favourite.calories * multiplier).rounded())

        return favourite.isCaloriesOnly
            ? "\(calories) kcal"
            : "\(Display.tidyGrams(favourite.proteinG * multiplier)) protein · \(calories) kcal"
    }

    /// A number and a button to commit it. The field clears on add, so the next
    /// thing you eat starts from empty rather than from what you last typed.
    private func quickField(
        _ title: String,
        unit: String,
        tint: Color,
        value: Binding<Double?>,
        range: ClosedRange<Double>,
        decimals: Int = 0,
        add: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(title) only")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.secondary)

            HStack(spacing: 6) {
                NumericField(value: value, range: range, decimals: decimals, unit: unit, width: 52)

                Spacer(minLength: 0)

                addButton(tint: tint, enabled: (value.wrappedValue ?? 0) > 0, action: add)
                    .accessibilityLabel("Log \(title.lowercased())")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func addButton(
        tint: Color,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 38, height: 38)
                .background(tint.opacity(enabled ? 0.18 : 0.08), in: .circle)
                .foregroundStyle(enabled ? tint : Color.secondary)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func todayCard(_ day: IntakeDay) -> some View {
        Card("Today") {
            ForEach(day.entries) { entry in
                Button {
                    editing = entry
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name ?? (entry.proteinG > 0 ? "Protein" : "Calories"))
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                            Text(entry.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }

                        Spacer(minLength: 0)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Display.tidyGrams(entry.proteinG))
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

/// Two rings, concentric: calories outside, protein inside.
///
/// ## Why two and not two cards
///
/// They are the same question asked twice — how much of today's target is done
/// — and the thing you actually want to know is how they stand *against each
/// other*. A day where the outer ring is full and the inner one is half is a
/// day you ate enough and ate the wrong things, and that is legible at a glance
/// here in a way that two numbers in two cards never made it.
///
/// Calories go outside because the outer arc is the longer one, and calories are
/// the figure with the wider range to travel. Protein is inside, wrapped around
/// its own number, because it is the one the screen is headlining.
struct DualGoalRing<Label: View>: View {
    let outer: Double
    let outerTint: Color
    let inner: Double
    let innerTint: Color
    @ViewBuilder let label: Label

    private let outerWidth: CGFloat = 11
    private let innerWidth: CGFloat = 9
    /// The gap between them. Enough that the two arcs never read as one thick
    /// band, which is what happened at four points.
    private let gap: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let innerInset = outerWidth + gap

            ZStack {
                ring(fraction: outer, tint: outerTint, width: outerWidth)
                    .frame(width: size, height: size)

                ring(fraction: inner, tint: innerTint, width: innerWidth)
                    .frame(width: size - innerInset * 2, height: size - innerInset * 2)

                label
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private func ring(fraction: Double, tint: Color, width: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: width)

            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy(duration: 0.35), value: fraction)
        }
    }
}
#endif
