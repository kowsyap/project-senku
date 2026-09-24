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
                    } footer: {
                        // Lives here rather than in the toolbar because it is
                        // a way of filling this form in, not a separate way of
                        // logging food. Whatever it reads lands in the fields
                        // below and is yours to correct before anything is
                        // saved.
                        Text("Fills in the fields below. A packet is transcribed exactly; a plate is estimated, and worth checking.")
                    }
                }
                #endif

                Section {
                    TextField(Self.defaultName, text: $name)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                }

                Section {
                    row("Protein", value: $protein, tint: Senku.Palette.protein)
                    row("Carbs", value: $carbs, tint: Senku.Palette.carbs)
                    row("Fat", value: $fat, tint: Senku.Palette.fat)
                    row("Fibre", value: $fibre, tint: Senku.Palette.surplus)
                } header: {
                    Text("Macros")
                } footer: {
                    Text("\(Int(derivedCalories.rounded())) kcal at 4/4/9.")
                }

                Section {
                    LabeledContent("From the packet") {
                        NumericField(value: $calories, range: 0 ... 5000, unit: "kcal", width: 76)
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    // The rule from F5: two figures that disagree are shown as
                    // two figures. A label knows about the oil in the pan; 4/4/9
                    // does not, and neither of them is wrong enough to overwrite
                    // the other silently.
                    Text(calories == nil
                         ? "Leave this empty and the calories come from the macros above."
                         : "Kept as you typed it. The figure from the macros is \(Int(derivedCalories.rounded())) kcal, and both are shown where they disagree.")
                }

                if editing == nil {
                    Section {
                        Toggle("Save as a quick-add", isOn: $saveAsFavourite)
                            .disabled(trimmedName.isEmpty)
                    } footer: {
                        Text(trimmedName.isEmpty
                             ? "Give it a name to keep it as a button."
                             : "Adds \(trimmedName) to the quick-add menu.")
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
            .navigationTitle(editing == nil ? "Log food" : "Edit")
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
                // Hidden rather than disabled where the model is not there: on
                // iOS 26 it cannot read an image at all, and on a device
                // without the assets it would only fail on the tap.
                if #available(iOS 27, *) { canReadPhotos = FoodPhotoEstimator.isAvailable }
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
                calories = editing.enteredCalories
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
        calories = proposal.enteredCalories
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
            enteredCalories: calories
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

    @State private var editing: FoodFavourite?
    @State private var isAdding = false

    var body: some View {
        Form {
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
            } footer: {
                Text("The menu on the food screen. Ordered by how often you log each one, so what you eat most sits first.")
            }
        }
        .navigationTitle("Food settings")
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
            .navigationTitle(favourite == nil ? "New quick-add" : "Edit")
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
#endif
