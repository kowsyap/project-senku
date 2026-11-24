#if os(iOS)
import SwiftUI
import SenkuCore

/// What to put in the export, asked before it is written.
///
/// The backup starts on and the report off: a copy to restore from is the
/// usual reason to export. Switching the report on switches on every section
/// under it, and charts; off, they all go off and grey out. They are not there
/// to make you choose — they are there for the times the whole record is the
/// wrong thing to hand over: a coach who needs your training and has no
/// business with your anime list, or a doctor who wants the weight history
/// and nothing else.
struct ReportOptionsView: View {
    @Binding var selection: ReportSelection
    let onExport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Backup file", isOn: $selection.backup)
                } footer: {
                    Text("A JSON copy of everything to restore back.")
                }

                Section {
                    Toggle("Report", isOn: reportBinding)
                } footer: {
                    Text("A PDF copy of everything to read and analyse.")
                }

                Section {
                    Group {
                        Toggle("Profile", isOn: $selection.profile)
                        Toggle("Weight", isOn: $selection.weight)
                        Toggle("Personal records", isOn: $selection.records)
                        Toggle("Training plan", isOn: $selection.plan)
                        Toggle("Workouts", isOn: $selection.workouts)
                        Toggle("Water", isOn: $selection.water)
                        Toggle("Food", isOn: $selection.food)
                        if ExtraStore.shared.isInstalled(.watchlist) {
                            Toggle("Watchlist", isOn: $selection.anime)
                        }
                        if ExtraStore.shared.isInstalled(.dues) {
                            Toggle("Dues", isOn: $selection.dues)
                        }
                        if ExtraStore.shared.isInstalled(.expenses) {
                            Toggle("Expenses", isOn: $selection.expenses)
                        }
                        if ExtraStore.shared.isInstalled(.income) {
                            Toggle("Income", isOn: $selection.income)
                        }
                        Toggle("Charts", isOn: $selection.charts)
                    }
                    .disabled(!selection.report)
                }

                Section {
                    Button(action: onExport) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selection.producesNothing)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(allOn ? "None" : "All") {
                        setAll(!allOn)
                    }
                    .disabled(!selection.report)
                }
            }
        }
    }

    /// The report and everything under it together: on switches every section
    /// on to pick from, off clears them.
    private var reportBinding: Binding<Bool> {
        Binding(
            get: { selection.report },
            set: { on in withAnimation(.snappy) { selection.setReport(on) } }
        )
    }

    private var allOn: Bool {
        selection.profile && selection.weight && selection.records && selection.plan
            && selection.workouts && selection.water && selection.food && selection.anime
            && selection.dues && selection.expenses && selection.income
    }

    /// Charts and the backup are left alone: they are not sections, and
    /// "None" meaning "and also no backup" would be a surprise.
    private func setAll(_ value: Bool) {
        selection.profile = value
        selection.weight = value
        selection.records = value
        selection.plan = value
        selection.workouts = value
        selection.water = value
        selection.food = value
        selection.anime = value
        selection.dues = value
        selection.expenses = value
        selection.income = value
    }
}
#endif
