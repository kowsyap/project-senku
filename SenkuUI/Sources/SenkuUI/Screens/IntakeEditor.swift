#if !os(watchOS)
import SwiftUI
import SenkuCore

/// One meal, typed in full.
///
/// The long way round, for when the quick row will not do: a name, four macros,
/// and the calorie figure off the packet if you have one. Everything but the
/// grams is optional, because an entry nobody finishes is an entry that does
/// not get logged.
struct IntakeEditor: View {
    @Bindable var store: IntakeStore
    var editing: IntakeEntry?
    let onClose: () -> Void

    @State private var name = ""
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fibre: Double?
    @State private var calories: Double?
    @State private var saveAsFavourite = false
    @State private var loaded = false
    #if os(iOS)
    @State private var isShowingPhoto = false
    /// Resolved once rather than read in `body`: the answer involves the model
    /// assets on disk, and a form that asks about them on every keystroke is a
    /// form that stutters.
    @State private var canReadPhotos = false
    #endif

    private var derivedCalories: Double {
        (protein ?? 0) * CaloriesPerGram.protein
            + (carbs ?? 0) * CaloriesPerGram.carbohydrate
            + (fat ?? 0) * CaloriesPerGram.fat
    }

    private var hasAnything: Bool {
        (protein ?? 0) > 0 || (carbs ?? 0) > 0 || (fat ?? 0) > 0 || (calories ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                #if os(iOS)
                if canReadPhotos, editing == nil {
                    Section {
                        Button {
                            isShowingPhoto = true
                        } label: {
                            Label("Read a packet or a plate", systemImage: "camera")
                        }
                    }
                }
                #endif

                Section {
                    // The name, and beside it whether to keep it as a button:
                    // a small "Quick-add" over the switch.
                    HStack(spacing: 12) {
                        TextField(Self.defaultName, text: $name)
                            #if os(iOS)
                            .textInputAutocapitalization(.sentences)
                            #endif
                        if editing == nil {
                            VStack(spacing: 2) {
                                Text("Quick-add")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.secondary)
                                Toggle("Quick-add", isOn: $saveAsFavourite)
                                    .labelsHidden()
                            }
                            .disabled(trimmedName.isEmpty)
                        }
                    }
                }

                Section {
                    row("Protein", value: macro($protein), tint: Senku.Palette.protein)
                    row("Carbs", value: macro($carbs), tint: Senku.Palette.carbs)
                    row("Fat", value: macro($fat), tint: Senku.Palette.fat)
                    row("Fibre", value: macro($fibre), tint: Senku.Palette.surplus)
                } header: {
                    Text("Macros")
                }

                Section {
                    LabeledContent {
                        NumericField(value: $calories, range: 0 ... 5000, unit: "kcal", width: 76)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Calories")
                            InfoButton("Calories are worked out at 4 per gram of protein and carbs, and 9 per gram of fat.")
                        }
                    }
                }

                if let editing {
                    Section {
                        Button("Delete", role: .destructive) {
                            store.delete(editing)
                            onClose()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "Log Food" : "Edit")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .dismissableKeyboard()
            #if os(iOS)
            .sheet(isPresented: $isShowingPhoto) {
                if #available(iOS 27, *) {
                    FoodPhotoSheet(onRead: fill) { isShowingPhoto = false }
                }
            }
            .task {
                // Shown only once Gemini is set up: a key saved and the switch
                // on. Hidden rather than disabled, because a button that
                // explains why it cannot be pressed is a button asking to be
                // pressed.
                if #available(iOS 27, *) { canReadPhotos = GeminiAccount.isActive }
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!hasAnything)
                }
            }
            .task {
                // Once: a sheet's task runs again on every re-appearance, and
                // reloading here would throw away what is half typed.
                guard !loaded, let editing else { loaded = true; return }
                loaded = true
                name = editing.name ?? ""
                protein = editing.proteinG
                carbs = editing.carbsG
                fat = editing.fatG
                fibre = editing.fiberG
                // The figure it was saved with, or the one its macros give.
                calories = editing.enteredCalories ?? (derivedCalories > 0 ? derivedCalories.rounded() : nil)
            }
        }
    }

    /// What an unnamed meal is called.
    ///
    /// Not left blank: the day's list is read back in the evening to work out
    /// where the calories went, and a row with no name at all reads as a glitch.
    /// "Meal" is honest about being a placeholder while still being something to
    /// point at.
    static let defaultName = "Meal"

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The name as saved: what you typed, or "Meal". A quick-add still has to be
    /// named by you — a menu full of "Meal" would be no menu at all.
    private var savedName: String {
        trimmedName.isEmpty ? Self.defaultName : trimmedName
    }

    /// A macro field that refills Calories from the macros as you type them.
    /// Calories can still be typed over; changing a macro again recalculates.
    /// Only typing does this — loading an entry to edit leaves its calories.
    private func macro(_ value: Binding<Double?>) -> Binding<Double?> {
        Binding(
            get: { value.wrappedValue },
            set: { new in
                value.wrappedValue = new
                calories = derivedCalories > 0 ? derivedCalories.rounded() : nil
            }
        )
    }

    private func row(_ title: String, value: Binding<Double?>, tint: Color) -> some View {
        LabeledContent {
            NumericField(value: value, range: 0 ... 1000, decimals: 1, unit: "g")
        } label: {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(title)
            }
        }
    }

    #if os(iOS)
    /// Takes what the camera read and puts it in the fields.
    ///
    /// Overwrites rather than merges: a reading is a description of one thing,
    /// and half of it against half of what you had typed would be a fourth
    /// thing that never existed.
    @available(iOS 27, *)
    private func fill(_ estimate: FoodEstimate) {
        guard let proposal = estimate.proposal() else { return }
        name = proposal.name ?? ""
        protein = proposal.proteinG
        carbs = proposal.carbsG
        fat = proposal.fatG
        fibre = proposal.fiberG
        calories = proposal.enteredCalories ?? (derivedCalories > 0 ? derivedCalories.rounded() : nil)
    }
    #endif

    private func save() {
        guard let entry = try? IntakeEntry(
            id: editing?.id ?? UUID(),
            date: editing?.date ?? .now,
            name: savedName,
            proteinG: protein ?? 0,
            carbsG: carbs ?? 0,
            fatG: fat ?? 0,
            fiberG: fibre,
            // The figure from the macros, kept as the macros rather than as a
            // typed number; only a different figure is saved as typed.
            enteredCalories: calories.flatMap { abs($0 - derivedCalories) < 1 ? nil : $0 }
        ) else { return }

        if editing == nil {
            store.add(entry)
            if saveAsFavourite, !trimmedName.isEmpty {
                store.save(
                    FoodFavourite(
                        name: trimmedName,
                        proteinG: protein ?? 0,
                        carbsG: carbs ?? 0,
                        fatG: fat ?? 0,
                        fiberG: fibre,
                        enteredCalories: (protein ?? 0) == 0 && (carbs ?? 0) == 0 && (fat ?? 0) == 0
                            ? calories
                            : nil,
                        timesUsed: 1
                    )
                )
            }
        } else {
            store.update(entry)
        }

        Feedback.control()
        onClose()
    }
}

/// The quick-add row, editable.
struct IntakeSettingsView: View {
    @Bindable var store: IntakeStore
    var profile: ProfileStore.Profile?
    /// The new calorie and protein adjustments, to be saved to the profile.
    var onAdjustTargets: (_ calories: Double, _ protein: Double) -> Void = { _, _ in }

    @State private var editing: FoodFavourite?
    @State private var isAdding = false

    var body: some View {
        Form {
            if let profile {
                targetsSection(profile)
            }

            #if os(iOS)
            if #available(iOS 27, *) {
                Section {
                    NavigationLink("Photo reading") { FoodIntelligenceSettings() }
                }
            }
            #endif

            Section {
                if store.favourites.isEmpty {
                    Text("Nothing saved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.orderedFavourites) { favourite in
                        Button {
                            editing = favourite
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(favourite.name)
                                        .foregroundStyle(Color.primary)
                                    Text(favourite.isCaloriesOnly
                                         ? "\(Int(favourite.calories.rounded())) kcal"
                                         : "\(Display.tidyGrams(favourite.proteinG)) protein · \(Int(favourite.calories.rounded())) kcal")
                                        .font(.caption)
                                        .foregroundStyle(Color.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let ordered = store.orderedFavourites
                        offsets.map { ordered[$0] }.forEach(store.delete)
                    }
                }

                Button {
                    isAdding = true
                } label: {
                    Label("Add a quick-add", systemImage: "plus")
                }
            } header: {
                Text("Quick add")
            }

        }
        .navigationTitle("Food Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .senkuBottomBarInset()
        .sheet(item: $editing) { favourite in
            FavouriteEditor(store: store, favourite: favourite) { editing = nil }
        }
        .sheet(isPresented: $isAdding) {
            FavouriteEditor(store: store, favourite: nil) { isAdding = false }
        }
    }
}

/// One quick-add button, as a form.
private struct FavouriteEditor: View {
    @Bindable var store: IntakeStore
    let favourite: FoodFavourite?
    let onClose: () -> Void

    @State private var name = ""
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @State private var fibre: Double?
    @State private var calories: Double?
    @State private var loaded = false

    private var macrosGiven: Bool {
        (protein ?? 0) > 0 || (carbs ?? 0) > 0 || (fat ?? 0) > 0
    }

    private var derivedCalories: Double {
        (protein ?? 0) * CaloriesPerGram.protein
            + (carbs ?? 0) * CaloriesPerGram.carbohydrate
            + (fat ?? 0) * CaloriesPerGram.fat
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                }

                Section {
                    LabeledContent("Protein") {
                        NumericField(value: $protein, range: 0 ... 1000, decimals: 1, unit: "g")
                    }
                    LabeledContent("Carbs") {
                        NumericField(value: $carbs, range: 0 ... 1000, decimals: 1, unit: "g")
                    }
                    LabeledContent("Fat") {
                        NumericField(value: $fat, range: 0 ... 1000, decimals: 1, unit: "g")
                    }
                    LabeledContent("Fibre") {
                        NumericField(value: $fibre, range: 0 ... 1000, decimals: 1, unit: "g")
                    }
                } header: {
                    Text("Macros")
                } footer: {
                    Text(macrosGiven
                         ? "\(Int(derivedCalories.rounded())) kcal at 4/4/9."
                         : "Leave these empty for something you only know the calories of.")
                }

                Section {
                    LabeledContent("Calories") {
                        NumericField(value: $calories, range: 0 ... 5000, unit: "kcal", width: 76)
                    }
                    .disabled(macrosGiven)
                } footer: {
                    // A go-to item whose macros you do not know is still worth a
                    // button: the takeaway you order every fortnight moves the
                    // calorie ring and should not have to be invented to be
                    // logged. Disabled once macros are given, because then the
                    // arithmetic has the answer and two figures would disagree.
                    Text(macrosGiven
                         ? "Worked out from the macros above."
                         : "For a go-to item whose macros you do not know. It moves the calorie ring and leaves protein alone.")
                }

                if let favourite {
                    Section {
                        Button("Delete", role: .destructive) {
                            store.delete(favourite)
                            onClose()
                        }
                    }
                }
            }
            .navigationTitle(favourite == nil ? "New Quick-Add" : "Edit")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .dismissableKeyboard()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                guard !loaded, let favourite else { loaded = true; return }
                loaded = true
                name = favourite.name
                protein = favourite.proteinG
                carbs = favourite.carbsG
                fat = favourite.fatG
                fibre = favourite.fiberG
                calories = favourite.enteredCalories
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.save(
            FoodFavourite(
                id: favourite?.id ?? UUID(),
                name: trimmed,
                proteinG: protein ?? 0,
                carbsG: carbs ?? 0,
                fatG: fat ?? 0,
                fiberG: fibre,
                enteredCalories: macrosGiven ? nil : calories,
                timesUsed: favourite?.timesUsed ?? 0
            )
        )
        onClose()
    }
}

// MARK: - Your targets

extension IntakeSettingsView {
    static let calorieStep: Double = 50
    static let proteinStep: Double = 5
    static let calorieReach: Double = 1000
    static let proteinReach: Double = 100

    /// Eat more or less than the calculator says, by a difference that stays
    /// put when the plan underneath it changes.
    @ViewBuilder
    func targetsSection(_ profile: ProfileStore.Profile) -> some View {
        let calculator = profile.calculatorPlan
        let plan = profile.plan
        let calories = profile.calorieAdjustment ?? 0
        let protein = profile.proteinAdjustment ?? 0
        let floor = profile.metrics.sex.safeMinimumCalories

        // Never below the safe floor: the lowest step is the one that lands on
        // it or just above, and a plan already at the floor cannot go lower.
        let lowestCalories = max(
            -Self.calorieReach,
            min(0, ((floor - calculator.energy.targetCalories) / Self.calorieStep).rounded(.up) * Self.calorieStep)
        )
        let lowestProtein = -min(
            Self.proteinReach,
            (calculator.macros.proteinGrams / Self.proteinStep).rounded(.down) * Self.proteinStep
        )

        Section {
            Stepper(
                value: Binding(
                    get: { calories },
                    set: { onAdjustTargets($0, protein) }
                ),
                in: lowestCalories ... Self.calorieReach,
                step: Self.calorieStep
            ) {
                adjustmentLabel(
                    "Calories",
                    value: "\(Int(plan.macros.calories.rounded()).formatted()) kcal",
                    calculator: "\(Int(calculator.macros.calories.rounded()).formatted()) kcal",
                    difference: calories == 0 ? nil : "\(Display.signedCalories(calories)) kcal"
                )
            }

            Stepper(
                value: Binding(
                    get: { protein },
                    set: { onAdjustTargets(calories, $0) }
                ),
                in: lowestProtein ... Self.proteinReach,
                step: Self.proteinStep
            ) {
                adjustmentLabel(
                    "Protein",
                    value: Display.grams(plan.macros.proteinGrams),
                    calculator: Display.grams(calculator.macros.proteinGrams),
                    difference: protein == 0 ? nil : "\(protein > 0 ? "+" : "")\(Int(protein)) g"
                )
            }

            if calories != 0 || protein != 0 {
                Button("Use the calculator's targets") {
                    onAdjustTargets(0, 0)
                }
            }
        } header: {
            Text("Your targets")
        }
    }

    private func adjustmentLabel(
        _ title: String,
        value: String,
        calculator: String,
        difference: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(title)
                Text(value)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Text(difference.map { "Calculator \(calculator) · \($0)" } ?? "Calculator's target")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
#endif
