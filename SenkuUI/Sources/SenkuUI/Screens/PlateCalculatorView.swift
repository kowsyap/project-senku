#if !os(watchOS)
import SwiftUI
import SenkuCore

/// What to hang on the bar, as a page of its own.
///
/// ## Why it is not in the set logger
///
/// It was, for about an hour. The set logger is opened *after* a set, to write
/// down what you just did — by which point the bar is already loaded and the
/// plate arithmetic is a fact rather than a question. The question happens at
/// the rack, before anything is lifted, and it wants both hands free and one
/// number typed. So it is a page, reached from the workout screen, and it does
/// nothing else.
struct PlateCalculatorView: View {
    @Bindable var plates: PlateStore

    @State private var target: Double?
    @State private var isEditingRack = false
    @FocusState private var isTyping: Bool

    private var unit: UnitSystem { plates.unit }
    private var set: PlateSet { plates.set(for: unit) }

    private var load: PlateLoad? {
        guard let target, target > 0 else { return nil }
        return PlateMath.load(target: target, using: set)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                entryCard

                if let load {
                    barCard(load)
                    perSideCard(load)
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .senkuBottomBarInset()
        .dismissableKeyboard()
        // An empty bar, which is where every load starts — and one press of
        // "+" from there is the first warm-up set.
        .task { if target == nil { target = set.bar } }
        // Switching units is switching gyms. Converting the number would carry
        // a weight from one rack to another, where it may not even be loadable;
        // the bar is the honest place to start again.
        .onChange(of: plates.unit) { _, _ in target = set.bar }
        .navigationTitle("Plate calculator")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isEditingRack = true } label: {
                    Label("Rack", systemImage: "gearshape")
                }
            }
        }
        .sheet(isPresented: $isEditingRack) {
            PlateRackEditor(plates: plates, unitSystem: unit) { isEditingRack = false }
        }
    }

    // MARK: - The number

    private var entryCard: some View {
        Card {
            VStack(spacing: 14) {
                // The unit belongs to this screen, not to the profile: plates
                // are stamped in whatever the gym bought, and somebody who
                // tracks their body weight in pounds can still walk into a gym
                // with kilo plates on the rack.
                Picker("Units", selection: Binding(
                    get: { plates.unit },
                    set: { plates.unit = $0 }
                )) {
                    Text("kg").tag(UnitSystem.metric)
                    Text("lb").tag(UnitSystem.imperial)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    stepButton("minus", by: -set.smallestStep)

                    // Centred, with the unit hung off the number rather than
                    // sharing the row's width — otherwise the digits drift left
                    // as the unit's label changes length.
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        TextField("0", value: $target, format: .number.precision(.fractionLength(0...1)))
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .focused($isTyping)
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .multilineTextAlignment(.center)
                            .fixedSize()

                        Text(unit.massLabel)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    stepButton("plus", by: set.smallestStep)
                }

                Text("\(set.namedBar.map { "\($0.name) bar" } ?? "Bar") \(PlateLoad.trim(set.bar)) \(unit.massLabel) · steps of \(PlateLoad.trim(set.smallestStep)) \(unit.massLabel)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// One step up or down the ladder of weights this rack can build.
    ///
    /// A number that is not on the ladder is snapped onto it first, so pressing
    /// "+" on 227 gives 230 rather than 232 — the point of the button is to
    /// land on something loadable, and stepping away from an unloadable number
    /// would just be a different unloadable number.
    private func stepButton(_ symbol: String, by amount: Double) -> some View {
        Button {
            let current = target ?? set.bar
            let base = set.snapped(current)
            // Snapping alone may already be the move: 227 up is 230, but 227
            // down is 225, and both are one press.
            let next = abs(base - current) > 0.001 && (base - current).sign == amount.sign
                ? base
                : base + amount
            target = max(0, next)
            Feedback.control()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .frame(width: 46, height: 46)
                .background(Senku.Palette.protein.opacity(0.15), in: .circle)
                .foregroundStyle(Senku.Palette.protein)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Heavier" : "Lighter")
    }

    // MARK: - The bar

    /// The plates drawn as they sit on the sleeve, biggest at the collar.
    ///
    /// A picture rather than a list because that is how you load a bar: you are
    /// matching shapes on a rack, not reading a sum. The heights are
    /// proportional to the real plates — a 45 is taller than a 25 — so the
    /// drawing tells you the same thing at a glance that the numbers do.
    private func barCard(_ load: PlateLoad) -> some View {
        Card {
            VStack(spacing: 10) {
                if load.perSide.isEmpty {
                    Text(load.isExact ? "Just the bar." : "That is lighter than the bar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 3) {
                        // The sleeve, so the plates have something to sit on.
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.tertiary)
                            .frame(width: 26, height: 8)

                        ForEach(Array(load.perSide.enumerated()), id: \.offset) { _, plate in
                            plateShape(plate)
                        }

                        Spacer(minLength: 0)
                    }
                    .frame(height: 108)
                }

                Divider()

                HStack(alignment: .firstTextBaseline) {
                    Text(load.isExact ? "On the bar" : "Closest you can build")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(PlateLoad.trim(load.total)) \(unit.massLabel)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(load.isExact ? Senku.Palette.surplus : Senku.Palette.caution)
                }

                if !load.isExact, !load.perSide.isEmpty {
                    // The half of this worth having: knowing at the rack, not
                    // with the bar on your back.
                    Text("Your rack cannot make \(PlateLoad.trim(load.target)) \(unit.massLabel). Add a smaller plate in the rack settings, or lift this.")
                        .font(.caption2)
                        .foregroundStyle(Senku.Palette.caution)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// One plate, sized and coloured by where it sits in the rack.
    ///
    /// ## Why rank and not ratio
    ///
    /// Drawn to scale, a 2.5 beside a 45 is a eighteenth of its height — a
    /// sliver with no room for its own number. Clamping the small ones to a
    /// floor fixed that and created a worse problem: 10, 5 and 2.5 all hit the
    /// floor and became the same plate. So height follows the plate's *place*
    /// in your rack rather than its weight, which keeps every denomination a
    /// different size however odd the rack is.
    private func plateShape(_ plate: Double) -> some View {
        let rank = set.plates.firstIndex { abs($0 - plate) < 0.001 } ?? 0
        let steps = max(set.plates.count - 1, 1)
        let scale = 1 - (Double(rank) / Double(steps)) * 0.62

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(colour(rank: rank))
            .frame(width: 22, height: 108 * scale)
            .overlay {
                Text(PlateLoad.trim(plate))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
            }
            .accessibilityLabel("\(PlateLoad.trim(plate)) \(unit.massLabel)")
    }

    /// A colour per denomination, by rank rather than by weight.
    ///
    /// The heaviest four follow the competition colours everyone has seen —
    /// red, blue, yellow, green — and the rest carry on down a ladder that
    /// never repeats. Hard-coding it by weight left 5 and 2.5 sharing the
    /// default, which is the one thing a colour code must not do.
    private func colour(rank: Int) -> Color {
        let ladder: [Color] = [
            Senku.Palette.warning,                          // red
            Senku.Palette.deficit,                          // blue
            Senku.Palette.caution,                          // amber
            Senku.Palette.surplus,                          // green
            Color(red: 0.62, green: 0.45, blue: 0.92),      // violet
            Color(red: 0.09, green: 0.69, blue: 0.65),      // teal
            Color(red: 0.95, green: 0.45, blue: 0.75),      // pink
            Senku.Palette.info,                             // slate
        ]
        return ladder[min(rank, ladder.count - 1)]
    }

    // MARK: - Per side, in words

    private func perSideCard(_ load: PlateLoad) -> some View {
        Card("Per side") {
            if load.perSide.isEmpty {
                Text("Nothing — the bar is enough.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(load.description)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Senku.Palette.protein)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("\(load.perSide.count) plate\(load.perSide.count == 1 ? "" : "s") each end.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
