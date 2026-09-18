#if os(iOS)
import SwiftUI
import SenkuCore

/// What to put in the export, asked before it is written.
///
/// Everything starts on. The picker is not there to make you choose — it is
/// there for the times the whole record is the wrong thing to hand over: a
/// coach who needs your training and has no business with your anime list, or a
/// doctor who wants the weight history and nothing else.
struct ReportOptionsView: View {
    @Binding var selection: ReportSelection
    let onExport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Profile", isOn: $selection.profile)
                    Toggle("Weight", isOn: $selection.weight)
                    Toggle("Personal records", isOn: $selection.records)
                    Toggle("Training plan", isOn: $selection.plan)
                    Toggle("Workouts", isOn: $selection.workouts)
                    Toggle("Water", isOn: $selection.water)
                    Toggle("Food", isOn: $selection.food)
                    Toggle("Anime", isOn: $selection.anime)
                } header: {
                    Text("In the report")
                } footer: {
                    Text("A section with nothing in it is left out whether it is ticked or not.")
                }

                Section {
                    Toggle("Charts", isOn: $selection.charts)
                } footer: {
                    Text("Weight over time, and the last 30 days of water, protein and calories against their targets.")
                }

                Section {
                    Toggle("Backup file", isOn: $selection.backup)
                } header: {
                    Text("Shared alongside")
                } footer: {
                    // Two files, two jobs. Worth saying plainly here, because
                    // the share sheet shows them side by side and they look
                    // interchangeable.
                    Text("A JSON copy of everything, which Import Data takes back. The PDF is for reading; this is for restoring.")
                }

                Section {
                    Button(action: onExport) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(selection.producesNothing)
                }
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(allOn ? "None" : "All") {
                        setAll(!allOn)
                    }
                }
            }
        }
    }

    private var allOn: Bool {
        selection.profile && selection.weight && selection.records && selection.plan
            && selection.workouts && selection.water && selection.food && selection.anime
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
    }
}
#endif
