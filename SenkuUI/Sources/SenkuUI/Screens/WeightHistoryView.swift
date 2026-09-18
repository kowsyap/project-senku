#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Every weigh-in, on a page of its own.
///
/// It was a card at the foot of the weight screen, paginated ten at a time
/// behind a "show more" button — which is what a list does when it is a guest
/// on someone else's screen. On its own page it can just be the list, and the
/// weight screen above it is left as the two things worth a glance: the trend
/// and the figures.
struct WeightHistoryView: View {
    @Bindable var store: WeightLogStore
    let unitSystem: UnitSystem

    @State private var deleting: WeighIn?

    var body: some View {
        List {
            ForEach(store.weighIns) { weighIn in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weighIn.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.subheadline)
                        if let note = weighIn.note, !note.isEmpty {
                            Text(note)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: 8)

                    Text(Display.mass(weighIn.weightKG, in: unitSystem))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
                .swipeActions {
                    Button(role: .destructive) {
                        deleting = weighIn
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("\(store.weighIns.count) weigh-ins")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
        .alert(
            "Delete this weigh-in?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { store.delete(deleting) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        } message: {
            Text("The trend and your maintenance estimate are worked out from every reading, so removing one changes both.")
        }
    }
}

/// The weight screen's one setting.
struct WeightSettingsView: View {
    @Binding var reminding: Bool

    var body: some View {
        Form {
            #if canImport(UserNotifications) && !os(macOS)
            Section {
                Toggle(isOn: $reminding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remind me to weigh in")
                        Text("Every day at \(WeightReminder.hour):00")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Reminder")
            } footer: {
                Text("Morning, before food and water make the number mean something else. Weighing at the same time each day is most of what makes a trend line worth reading.")
            }
            #endif
        }
        .navigationTitle("Weight settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
    }
}
#endif
