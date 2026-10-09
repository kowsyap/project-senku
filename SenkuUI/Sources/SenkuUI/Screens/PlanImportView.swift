#if !os(watchOS)
import SwiftUI
import SenkuCore
import UniformTypeIdentifiers

/// Bringing in a plan from somewhere else: a programme in a spreadsheet, a PDF
/// from a coach, a list in Notes.
///
/// Importing comes first, because most visits are a return with the file in
/// hand. Below it, the two ways to make one: a prompt for any AI chat, and the
/// skill — the same instructions with the exercise list and a checker — for an
/// AI that reads files. Both are built from this app's own catalogue and your
/// own exercises when you ask for them, so neither can be out of date.
struct PlanImportView: View {
    @Bindable var store: TrainingPlanStore
    @Bindable var library: ExerciseLibrary

    @State private var isPicking = false
    @State private var preview: PlanImportPreview?
    @State private var failure: String?
    @State private var files: (prompt: URL, skill: URL)?
    @State private var copied = false
    @State private var imported: String?
    @State private var converter: Converter = .prompt
    @State private var isSavingSkill = false

    enum Converter: String, CaseIterable, Identifiable {
        case prompt, skill

        var id: String { rawValue }

        var title: String {
            switch self {
            case .prompt: "AI prompt"
            case .skill: "AI skill"
            }
        }

        var subtitle: String {
            switch self {
            case .prompt: "Any AI chat"
            case .skill: "Any AI that supports skills"
            }
        }

        var steps: [String] {
            switch self {
            case .prompt: [
                "Copy the prompt, or share it as a file.",
                "Paste it into an AI chat.",
                "Attach your plan — PDF, Excel, Word, a photo or text.",
                "Import the .json it gives you.",
            ]
            case .skill: [
                "Download the skill — one zip, kept as it is.",
                "Install the skill into your AI.",
                "Type /senku-plan and attach your plan — PDF, Excel, Word, a photo or text.",
                "Import the .json it gives you.",
            ]
            }
        }
    }

    var body: some View {
        List {
            Section {
                Button {
                    isPicking = true
                } label: {
                    Label("Import plan (.json)", systemImage: "square.and.arrow.down")
                        .font(.headline)
                }
            }

            converterCard
        }
        // Clear of the floating tab bar, like every other page under it.
        .senkuBottomBarInset()
        .navigationTitle("Import a Plan")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // Built on arrival, from what the app has now — your own
            // exercises included — and not again while the page is open.
            if files == nil { files = try? PlanConverter.files(own: library.custom) }
        }
        .fileExporter(
            isPresented: $isSavingSkill,
            document: ZipDocument(url: files?.skill),
            contentType: .zip,
            defaultFilename: "senku-plan"
        ) { _ in }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.json, .plainText, .text]) { result in
            read(result)
        }
        .sheet(isPresented: Binding(get: { preview != nil }, set: { if !$0 { preview = nil } })) {
            if let preview {
                NavigationStack {
                    PlanImportPreviewSheet(preview: preview, library: library) {
                        let summary = preview.apply(library: library, plans: store)
                        let days = store.days.count
                        imported = "Your week now has \(days) \(days == 1 ? "day" : "days")."
                            + (summary.problems.isEmpty ? "" : " \(summary.problems.count) skipped.")
                        self.preview = nil
                    } onCancel: {
                        self.preview = nil
                    }
                }
            }
        }
        .alert("Can’t import this file", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
        .alert("Plan imported", isPresented: Binding(get: { imported != nil }, set: { if !$0 { imported = nil } })) {
            Button("OK", role: .cancel) { imported = nil }
        } message: {
            Text(imported ?? "")
        }
    }

    /// Icon and word drawn side by side by hand: inside a list row, a
    /// prominent button's `Label` was showing the word without the icon.
    private func buttonLabel(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(title)
        }
        .font(.body.weight(.semibold))
        .frame(maxWidth: .infinity)
    }

    /// The two ways to make a file, as one card: the prompt for any AI chat,
    /// the skill for an AI that takes skills. Same last step for both.
    private var converterCard: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Converter", selection: $converter) {
                    ForEach(Converter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Text(converter.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(converter.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 14, alignment: .trailing)
                            Text(step)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Group {
                    switch converter {
                    case .prompt: promptActions
                    case .skill: skillActions
                    }
                }
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(.vertical, 6)
        } header: {
            // Both lines in the header, so the second sits on the card
            // rather than a section's gap away from it.
            VStack(alignment: .leading, spacing: 4) {
                Text("Don’t have a file yet?")
                Text("Turn any plan into a JSON file with AI.")
                    .font(.subheadline)
                    .textCase(nil)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var promptActions: some View {
        HStack(spacing: 10) {
            Button {
                copyPrompt()
            } label: {
                buttonLabel(copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderedProminent)

            if let files {
                ShareLink(item: files.prompt) {
                    buttonLabel("Share", symbol: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var skillActions: some View {
        if let files {
            HStack(spacing: 10) {
                // Straight to Files, which is where a download belongs; Share
                // is for sending it on — AirDrop to a Mac, Mail, an AI app.
                Button {
                    isSavingSkill = true
                } label: {
                    buttonLabel("Download", symbol: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)

                ShareLink(item: files.skill) {
                    buttonLabel("Share", symbol: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private func copyPrompt() {
        guard let text = try? PlanConverter.prompt(own: library.custom) else { return }
        #if os(iOS)
        UIPasteboard.general.string = text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        Feedback.control()
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copied = false }
        }
    }

    private func read(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            preview = try PlanImportPreview.make(from: data, library: library)
        } catch {
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// The week a file would make, shown before it replaces yours.
///
/// Drawn the way the Week page draws your week — each day a card with its
/// muscles and how well its exercises cover them — so a plan from somewhere
/// else can be judged by the same eye as one built here. Every exercise opens
/// its info sheet, body map included, new ones from the file too. Nothing is
/// changed until Replace, and confirmed.
struct PlanImportPreviewSheet: View {
    let preview: PlanImportPreview
    let library: ExerciseLibrary
    let onReplace: () -> Void
    let onCancel: () -> Void

    @State private var isConfirming = false
    @State private var info: Exercise?

    private var plan: TrainingPlan { preview.plan }

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    figure("\(plan.days.count)", label: plan.days.count == 1 ? "day" : "days")
                    Divider().frame(height: 34)
                    figure(plan.target.text, label: "target")
                    Divider().frame(height: 34)
                    figure("\(Set(plan.days.flatMap(\.exerciseIDs)).count)", label: "exercises")
                }
                .padding(.vertical, 4)
            }

            if !preview.problems.isEmpty {
                Section {
                    ForEach(preview.problems, id: \.self) { problem in
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Senku.Palette.caution)
                    }
                } header: {
                    Text("Will be skipped")
                } footer: {
                    Text("Paste these back to the AI that made the file and ask it to fix them — or import anyway and add them yourself.")
                }
            }

            ForEach(plan.days) { day in
                Section {
                    dayHeader(day)
                    ForEach(day.exerciseIDs, id: \.self) { id in
                        exerciseRow(id, on: day)
                    }
                }
            }

            if !plan.untrainedGroups.isEmpty {
                Section {
                    HStack(spacing: 6) {
                        ForEach(plan.untrainedGroups) { GroupGlyph(group: $0, size: 22) }
                    }
                } header: {
                    Text("Not in this week")
                }
            }

            if !preview.newExercises.isEmpty {
                Section {
                    ForEach(preview.newExercises, id: \.self) { Text($0) }
                } header: {
                    Text("New exercises")
                } footer: {
                    Text("Not in Senku’s list, so they are added as your own.")
                }
            }

            if !preview.ignoredSections.isEmpty {
                Section {
                    Text("This file also has \(preview.ignoredSections.joined(separator: ", ")). Only the plan is imported here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Preview")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Replace") { isConfirming = true }
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
                    // The Workout colour wherever the preview opens — from the
                    // Week page it inherits it, from the long press it would not.
                    .tint(RootView.Tab.workout.tint)
            }
        }
        .alert("Replace your week?", isPresented: $isConfirming) {
            Button("Replace", role: .destructive, action: onReplace)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current days and their exercises are replaced by these \(plan.days.count). Logged workouts are kept.")
        }
        .sheet(item: $info) { exercise in
            ExerciseInfoSheet(
                exercise: exercise,
                library: library,
                refusal: nil,
                onDelete: nil,
                onClose: { info = nil }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(ExercisePicker.solidSheet)
        }
    }

    private func figure(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// The day as the Week page shows it: name, count, muscles, coverage.
    private func dayHeader(_ day: SplitDay) -> some View {
        let exercises = day.exerciseIDs.compactMap { preview.exercises[$0] }
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day.name.isEmpty ? "Untitled day" : day.name)
                    .font(.headline)
                Spacer()
                Text(day.isEmpty ? "No exercises" : "\(day.exerciseIDs.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(day.groups) { GroupGlyph(group: $0, size: 22) }
            }
            if !day.isEmpty, !day.groups.isEmpty {
                Text(day.groups.map { group in
                    let coverage = MuscleCoverage.of(exercises, for: group, in: library.catalogue)
                    return "\(group.title) \(coverage.percentage)%"
                }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func exerciseRow(_ id: String, on day: SplitDay) -> some View {
        let exercise = preview.exercises[id]
        let tint = exercise?.workoutGroup.tint ?? .secondary
        return Button {
            info = exercise
        } label: {
            HStack(spacing: 10) {
                if let group = exercise?.workoutGroup {
                    GroupGlyph(group: group, size: 18)
                }
                Text(exercise?.name ?? id)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                if exercise?.isCustom == true {
                    Text("New")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.15), in: .capsule)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text(aim(for: id, on: day))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((day.targets[id] == nil ? Color.secondary : tint).opacity(day.targets[id] == nil ? 0.12 : 0.18), in: .capsule)
                    .foregroundStyle(day.targets[id] == nil ? Color.secondary : tint)
                Image(systemName: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(exercise == nil)
    }

    private func aim(for id: String, on day: SplitDay) -> String {
        if preview.cardio.contains(id) { return "Cardio" }
        let target = day.target(for: id, plan: plan.target)
        return preview.held.contains(id) ? "\(target.sets) sets" : target.text
    }
}

/// The skill zip, for the save dialog.
struct ZipDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.zip]

    let data: Data

    init(url: URL?) {
        data = url.flatMap { try? Data(contentsOf: $0) } ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
#endif
