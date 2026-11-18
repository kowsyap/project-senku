#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Adding or changing one spend or income.
///
/// Name first, with names used before offered as you type: picking one fills
/// its category too. The amounts are a list, like a season's episodes in the
/// watchlist — one per item or payday — and the total is what counts.
struct MoneyEditor: View {
    let store: MoneyStore
    let onDone: () -> Void

    @State private var entry: MoneyEntry
    @State private var amounts: [AmountRow]
    @State private var isNew: Bool
    @State private var isAddingCategory = false
    @State private var newCategory = ""
    @State private var isConfirmingDelete = false
    @FocusState private var nameFocused: Bool

    private struct AmountRow: Identifiable, Equatable {
        let id = UUID()
        var text: String
    }

    init(store: MoneyStore, entry: MoneyEntry?, month: YearMonth, onDone: @escaping () -> Void) {
        self.store = store
        self.onDone = onDone
        let start = entry ?? MoneyEntry(month: month, name: "", category: "", amounts: [])
        _entry = State(initialValue: start)
        _isNew = State(initialValue: entry == nil)
        let rows = start.amounts.map { AmountRow(text: Self.text($0)) }
        _amounts = State(initialValue: rows.isEmpty ? [AmountRow(text: "")] : rows)
    }

    private var kind: MoneyStore.Kind { store.kind }

    private var values: [Double] {
        amounts.compactMap { Self.number($0.text) }.filter { $0 > 0 }
    }

    private var total: Double { values.reduce(0, +) }

    private var canSave: Bool {
        !entry.name.trimmingCharacters(in: .whitespaces).isEmpty && total > 0
            && (kind == .income || !entry.category.isEmpty)
    }

    private var suggestions: [MoneySuggestions.Suggestion] {
        guard nameFocused else { return [] }
        return store.suggestions(for: entry.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(kind.nameLabel, text: $entry.name)
                        .focused($nameFocused)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                        .submitLabel(.next)

                    ForEach(suggestions, id: \.name) { suggestion in
                        Button {
                            entry.name = suggestion.name
                            if kind == .expenses, !suggestion.category.isEmpty {
                                entry.category = suggestion.category
                            }
                            nameFocused = false
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: kind == .expenses ? MoneyStyle.symbol(for: suggestion.category) : "arrow.up.left")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                Text(suggestion.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if kind == .expenses {
                                    Text(suggestion.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if kind == .expenses {
                        categoryMenu
                    }
                }

                Section {
                    ForEach($amounts) { $row in
                        HStack(spacing: 12) {
                            Text("Amount \((amounts.firstIndex(of: row) ?? 0) + 1)")
                                .foregroundStyle(.secondary)
                            TextField("0", text: $row.text)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                                .multilineTextAlignment(.trailing)
                            if amounts.count > 1 {
                                Button {
                                    amounts.removeAll { $0.id == row.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove amount")
                            }
                        }
                    }

                    Button {
                        amounts.append(AmountRow(text: ""))
                    } label: {
                        Label("Add an amount", systemImage: "plus")
                    }

                    LabeledContent("Total") {
                        Text(MoneyStyle.money(total))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                    }
                } header: {
                    Text("Amounts")
                }

                Section {
                    MonthYearPicker(month: $entry.month)
                    TextField("Note", text: $entry.note, axis: .vertical)
                }

                if !isNew {
                    Section {
                        Button("Delete", role: .destructive) { isConfirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New \(kind.entryNoun.capitalized)" : "Edit \(kind.entryNoun.capitalized)")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDone)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .alert("New category", isPresented: $isAddingCategory) {
                TextField("Name", text: $newCategory)
                Button("Add") {
                    if let added = store.addCategory(newCategory) { entry.category = added }
                    newCategory = ""
                }
                Button("Cancel", role: .cancel) { newCategory = "" }
            }
            .alert("Delete this \(kind.entryNoun)?", isPresented: $isConfirmingDelete) {
                Button("Delete", role: .destructive) {
                    store.delete(entry)
                    onDone()
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                if isNew { nameFocused = true }
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(store.categories, id: \.self) { category in
                Button {
                    entry.category = category
                } label: {
                    Label(category, systemImage: MoneyStyle.symbol(for: category))
                }
            }
            Divider()
            Button {
                isAddingCategory = true
            } label: {
                Label("New category…", systemImage: "plus")
            }
        } label: {
            HStack {
                Text("Category")
                    .foregroundStyle(.primary)
                Spacer()
                if entry.category.isEmpty {
                    Text("Choose")
                        .foregroundStyle(.secondary)
                } else {
                    Label(entry.category, systemImage: MoneyStyle.symbol(for: entry.category))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func save() {
        var saved = entry
        saved.name = saved.name.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.note = saved.note.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.amounts = values
        if kind == .income { saved.category = "" }
        store.save(saved)
        onDone()
    }

    private static func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return (try? Double(trimmed, format: .number)) ?? Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))
    }
}

/// A month and a year, the only date money is filed under.
struct MonthYearPicker: View {
    @Binding var month: YearMonth
    var label = "Month"

    private var years: [Int] {
        let now = YearMonth.current().year
        return Array(min(month.year, now - 10)...max(month.year, now + 1))
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Picker("Month", selection: Binding(
                get: { month.month },
                set: { month = YearMonth(year: month.year, month: $0) }
            )) {
                ForEach(1...12, id: \.self) { number in
                    Text(Calendar.current.monthSymbols[number - 1]).tag(number)
                }
            }
            .labelsHidden()
            .fixedSize()

            Picker("Year", selection: Binding(
                get: { month.year },
                set: { month = YearMonth(year: $0, month: month.month) }
            )) {
                ForEach(years, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}
#endif
