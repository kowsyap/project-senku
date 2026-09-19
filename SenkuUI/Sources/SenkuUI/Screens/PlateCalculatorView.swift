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
                } else {
                    Text("Type what you want on the bar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .background(.background)
        .senkuBottomBarInset()
        .dismissableKeyboard()
        .navigationTitle("Plates")
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

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", value: $target, format: .number.precision(.fractionLength(0...1)))
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .focused($isTyping)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 170)

                    Text(unit.massLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Text("Bar \(PlateLoad.trim(set.bar)) \(unit.massLabel) · smallest step \(PlateLoad.trim(set.smallestStep)) \(unit.massLabel)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
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

    /// One plate, sized like the real thing and labelled with its weight.
    private func plateShape(_ plate: Double) -> some View {
        let biggest = set.plates.first ?? plate
        // Nothing smaller than a third of the tallest: a 1.25 drawn to scale
        // beside a 45 would be a sliver with no room for its own number.
        let scale = max(0.34, plate / max(biggest, 0.001))

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(colour(for: plate))
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

    /// Competition plate colours where they apply, and a sensible ladder where
    /// they do not — the point is that two plates of different weight never
    /// look the same, not that a commercial gym's rack is colour-coded.
    private func colour(for plate: Double) -> Color {
        switch (unit, plate) {
        case (.metric, 25), (.imperial, 45): return Senku.Palette.warning
        case (.metric, 20), (.imperial, 35): return Senku.Palette.deficit
        case (.metric, 15), (.imperial, 25): return Senku.Palette.caution
        case (.metric, 10), (.imperial, 10): return Senku.Palette.surplus
        default: return Senku.Palette.info
        }
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
