#if !os(watchOS)
import SwiftUI
import SenkuCore

/// What is on the rack, and what the bar weighs.
///
/// One screen, reached by tapping the per-side row while logging a set —
/// which is exactly when a wrong answer is noticed, and the only time anybody
/// will want to correct this.
struct PlateRackEditor: View {
    @Bindable var plates: PlateStore
    let unitSystem: UnitSystem
    let onClose: () -> Void

    /// Everything a gym might stock, in each unit. Toggling is honest about
    /// what this screen is for: not inventing plate sizes, but saying which of
    /// the usual ones your gym actually has.
    private var candidates: [Double] {
        unitSystem == .imperial
            ? [45, 35, 25, 10, 5, 2.5, 1.25]
            : [25, 20, 15, 10, 5, 2.5, 1.25, 0.5]
    }

    private var set: PlateSet { plates.set(for: unitSystem) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // Named, because nobody thinks "twenty kilograms" — they
                    // think "the women's bar". Typing a number is still there
                    // underneath for a gym with something odd.
                    ForEach(PlateSet.bars) { bar in
                        Button {
                            plates.setBar(bar.weight(in: unitSystem), in: unitSystem)
                            Feedback.control()
                        } label: {
                            HStack {
                                Image(systemName: abs(set.bar - bar.weight(in: unitSystem)) < 0.01
                                      ? "largecircle.fill.circle"
                                      : "circle")
                                    .foregroundStyle(abs(set.bar - bar.weight(in: unitSystem)) < 0.01
                                                     ? Senku.Palette.protein
                                                     : Color.secondary)

                                Text(bar.name)
                                    .foregroundStyle(Color.primary)

                                Spacer()

                                Text("\(PlateLoad.trim(bar.weight(in: unitSystem))) \(unitSystem.massLabel)")
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    LabeledContent("Anything else") {
                        HStack(spacing: 6) {
                            TextField(
                                "Bar",
                                value: Binding(
                                    get: { set.bar },
                                    set: { plates.setBar($0, in: unitSystem) }
                                ),
                                format: .number.precision(.fractionLength(0...1))
                            )
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 70)

                            Text(unitSystem.massLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Bar")
                } footer: {
                    Text("Everything below is worked out from whatever is selected here.")
                }

                Section {
                    ForEach(candidates, id: \.self) { plate in
                        Button {
                            plates.toggle(plate, in: unitSystem)
                            Feedback.control()
                        } label: {
                            HStack {
                                Image(systemName: plates.has(plate, in: unitSystem)
                                      ? "checkmark.square.fill"
                                      : "square")
                                    .foregroundStyle(plates.has(plate, in: unitSystem)
                                                     ? Senku.Palette.protein
                                                     : Color.secondary)

                                Text("\(PlateLoad.trim(plate)) \(unitSystem.massLabel)")
                                    .foregroundStyle(Color.primary)

                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Plates on the rack")
                } footer: {
                    // The figure that decides whether a small progression is
                    // even possible — and the reason to care which small plates
                    // the gym has.
                    Text("Smallest change you can make to the bar: \(PlateLoad.trim(set.smallestStep)) \(unitSystem.massLabel). Plates go on in pairs, so it is twice your smallest plate.")
                }

                Section {
                    Button("Back to a standard rack") {
                        plates.reset(for: unitSystem)
                    }
                }
            }
            .navigationTitle("Plates")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .dismissableKeyboard()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                }
            }
        }
    }
}
#endif
