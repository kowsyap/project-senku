#if !os(watchOS)
import SwiftUI
import SenkuCore

/// Bills, renewals, deadlines: what is due, soonest first.
///
/// The list answers one question — what needs doing, and when — so it is
/// grouped by how close things are rather than by category. Overdue sits at
/// the top in red, because an unpaid bill from last week is the one row that
/// matters more than all the others.
///
/// The circle on each row ticks off the *next* due date, which moves a monthly
/// bill on to next month and stops its reminders for this one. That tick is the
/// difference between this and a calendar alarm.
public struct DueDatesView: View {
    @Bindable private var store: DueDateStore

    @State private var editing: DueItem?
    @State private var isAdding = false
    @State private var deleting: DueItem?
    @State private var isShowingHistory = false

    public init(store: DueDateStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.items.isEmpty {
                empty
            } else {
                list
            }
        }
        .senkuBottomBarInset()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isShowingHistory = true } label: {
                    StackedActionLabel("History", symbol: "clock.arrow.circlepath")
                }
                .disabled(store.log.isEmpty)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { isAdding = true } label: {
                    StackedActionLabel("Add", symbol: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $isShowingHistory) {
            DueHistoryView(store: store)
        }
        .senkuPushed(isShowingHistory)
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                DueItemEditor(item: DueItem(title: "", firstDue: .now), store: store, isNew: true)
            }
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                DueItemEditor(item: item, store: store)
            }
        }
        .alert(
            "Delete “\(deleting?.title ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { store.delete(deleting) }
                deleting = nil
            }
            Button("Keep", role: .cancel) { deleting = nil }
        }
    }

    // MARK: - The list

    private struct Group_: Identifiable {
        let id: String
        let title: String
        let items: [DueItem]
    }

    /// Two groups: what is still to pay this month — overdue included — and
    /// everything already dealt with, waiting for its next date.
    private var groups: [Group_] {
        let all = store.sorted
        return [
            Group_(id: "month", title: "This month", items: all.filter { $0.isOpen() }),
            Group_(id: "paid", title: "Paid", items: all.filter { !$0.isOpen() }),
        ].filter { !$0.items.isEmpty }
    }

    private var list: some View {
        List {
            monthTotal

            ForEach(groups) { group in
                Section {
                    ForEach(group.items) { item in
                        Button {
                            editing = item
                        } label: {
                            row(item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading) {
                            if item.isOpen() {
                                Button {
                                    Feedback.control()
                                    store.markDone(item.id)
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(Senku.Palette.surplus)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleting = item
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            if item.doneThrough != nil {
                                Button {
                                    store.undoDone(item.id)
                                } label: {
                                    Label("Undo last done", systemImage: "arrow.uturn.backward")
                                }
                            }
                        }
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
    }

    /// What this month comes to, across the top — only when something has an
    /// amount, since a total of nothing is not worth the space.
    @ViewBuilder
    private var monthTotal: some View {
        let totals = DueMonthTotals(store.items)
        if totals.hasAmounts {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LEFT TO PAY THIS MONTH")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(.secondary)
                        Text(DueFormat.money(totals.toPay))
                            .font(.title.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(totalTint(totals))
                    }
                    Spacer()
                    if totals.paid > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("PAID")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.secondary)
                            Text(DueFormat.money(totals.paid))
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(Senku.Palette.surplus)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Red if any of it is overdue, orange if any is due today — the worse of
    /// the two wins — and green once nothing is left.
    private func totalTint(_ totals: DueMonthTotals) -> Color {
        if totals.includesOverdue { return Senku.Palette.warning }
        if totals.includesToday { return Senku.Palette.caution }
        return totals.toPay > 0 ? Color.primary : Senku.Palette.surplus
    }

    private func row(_ item: DueItem) -> some View {
        let state = DueState(daysUntilDue: item.daysUntilDue())
        let isOpen = item.isOpen()

        return HStack(spacing: 12) {
            if isOpen {
                // A control, not an indicator: ticks off the due date without
                // opening anything. Long-press the row to take it back.
                Button {
                    Feedback.control()
                    store.markDone(item.id)
                } label: {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundStyle(tint(state))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark done")
            } else {
                // Nothing to tick until next month comes round. A tick for
                // what was paid this month; a plain calendar for what simply
                // is not due yet, so it does not claim a payment never made.
                let paid = item.wasDone() || item.isFinished
                Image(systemName: paid ? "checkmark.circle.fill" : "calendar")
                    .font(.title2)
                    .foregroundStyle(paid ? Senku.Palette.surplus : Color.secondary)
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(item.isFinished ? Color.secondary : Color.primary)

                Text(subtitle(item))
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(isOpen ? state.phrase : (item.isFinished ? "Done" : "Next"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOpen ? tint(state) : Color.secondary)
                if let next = item.nextOpen() {
                    Text(DueFormat.date(next))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        // The whole row opens the editor, gaps included: a plain button is
        // otherwise only hittable on its text, and a tap in the space between
        // the title and the date did nothing.
        .contentShape(Rectangle())
    }

    /// "Credit card · ₹12,000" — the category, or how often it repeats when
    /// there is no category; the date is already on the right.
    private func subtitle(_ item: DueItem) -> String {
        [item.category.isEmpty ? item.repeatSummary : item.category, DueFormat.amount(item)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func tint(_ state: DueState) -> Color {
        switch state {
        case .overdue: Senku.Palette.warning
        case .today, .soon(1): Senku.Palette.caution
        case .soon: Color.primary
        case .later, .finished: Color.secondary
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("Nothing due", systemImage: "calendar.badge.clock")
        } description: {
            Text("Card bills, rent, renewals, deadlines — anything with a date. Repeat it monthly or yearly, and tick it off when it is done.")
        } actions: {
            Button("Add a Due") { isAdding = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// Everything ticked off, newest first, a month at a time.
///
/// Swipe to delete a line. The newest line for an item is an undo — that due
/// date opens again; an older one is only taken out of the log.
struct DueHistoryView: View {
    @Bindable var store: DueDateStore

    private struct Month: Identifiable {
        let id: Date
        let rows: [(item: DueItem, entry: DueCompletion)]
        var total: Double { rows.reduce(0) { $0 + ($1.entry.amount ?? 0) } }
    }

    private var months: [Month] {
        let calendar = Calendar.current
        var order: [Date] = []
        var byMonth: [Date: [(item: DueItem, entry: DueCompletion)]] = [:]
        for row in store.log {
            let month = calendar.dateInterval(of: .month, for: row.entry.doneAt)?.start ?? row.entry.doneAt
            if byMonth[month] == nil { order.append(month) }
            byMonth[month, default: []].append(row)
        }
        return order.map { Month(id: $0, rows: byMonth[$0] ?? []) }
    }

    var body: some View {
        List {
            ForEach(months) { month in
                Section {
                    ForEach(month.rows, id: \.entry.id) { row in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.title)
                                    .foregroundStyle(Color.primary)
                                Text("Due \(DueFormat.date(row.entry.due)) · done \(DueFormat.date(row.entry.doneAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let amount = row.entry.amount, amount > 0 {
                                Text(DueFormat.money(amount))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.removeCompletion(row.entry.id, from: row.item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(month.id.formatted(.dateTime.month(.wide).year()))
                        Spacer()
                        if month.total > 0 {
                            Text(DueFormat.money(month.total))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .overlay {
            if store.log.isEmpty {
                ContentUnavailableView(
                    "Nothing yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Tick something off and it is logged here.")
                )
            }
        }
        .senkuBottomBarInset()
        .navigationTitle("History")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// Adding or changing one item.
struct DueItemEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var item: DueItem
    @State private var amountText: String
    @Bindable var store: DueDateStore

    private let isNew: Bool

    init(item: DueItem, store: DueDateStore, isNew: Bool = false) {
        var item = item
        // A new item starts with "on the day" — unless there is no room for
        // it, in which case it starts with none rather than over the budget.
        if isNew, DueReminderPlan.cost(of: item) > DueReminderPlan.slotsLeft(store.items) {
            item.remindDaysBefore = []
        }
        _item = State(initialValue: item)
        _amountText = State(initialValue: item.amount.map { $0.formatted(.number.grouping(.never).precision(.fractionLength(0...2))) } ?? "")
        self.store = store
        self.isNew = isNew
    }

    var body: some View {
        Form {
            Section {
                TextField("Title — e.g. Amex bill", text: $item.title)
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif

                HStack {
                    TextField("Category (optional)", text: $item.category)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                    if !store.categories.isEmpty {
                        Menu {
                            ForEach(store.categories, id: \.self) { category in
                                Button(category) { item.category = category }
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                        }
                    }
                }

                TextField("Amount (optional)", text: $amountText)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            } header: {
                Text("What")
            }

            Section {
                DatePicker(
                    item.repeats == .never ? "Due on" : "First due",
                    selection: $item.firstDue,
                    displayedComponents: .date
                )

                Picker("Repeats", selection: $item.repeats) {
                    Text("Never").tag(DueRepeat.never)
                    Text("Daily").tag(DueRepeat.days)
                    Text("Weekly").tag(DueRepeat.weeks)
                    Text("Monthly").tag(DueRepeat.months)
                    Text("Yearly").tag(DueRepeat.years)
                }

                if item.repeats != .never {
                    Stepper(value: $item.every, in: 1...36) {
                        LabeledContent("Every", value: "\(item.every) \(item.repeats.unit(item.every))")
                    }
                }
            } header: {
                Text("When")
            } footer: {
                if let next = item.nextOpen() {
                    Text("Next: \(DueFormat.date(next)). \(item.repeatSummary).")
                }
            }

            Section {
                Toggle("On the day", isOn: onTheDayBinding)
                    // Turning it off is always allowed; on, only while it fits.
                    .disabled(!item.remindDaysBefore.contains(0) && !fits(onTheDay: true, early: early))

                Picker("Also remind", selection: earlyBinding) {
                    Text("No").tag(0)
                    ForEach(earlyOptions, id: \.self) { days in
                        Text(earlyLabel(days)).tag(days)
                    }
                }

                if !item.remindDaysBefore.isEmpty {
                    DatePicker("At", selection: timeBinding, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Remind me")
            } footer: {
                if isFull {
                    Text("No more reminders can be added. Turn some off on other items to free one up.")
                }
            }

            Section {
                TextField("Notes", text: $item.note, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Notes")
            }

            if !isNew {
                Section {
                    if item.doneThrough != nil {
                        Button("Undo last done") { item.undoDone() }
                    }
                    Button(role: .destructive) {
                        store.delete(item)
                        dismiss()
                    } label: {
                        Text("Delete").frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .dismissableKeyboard()
        .navigationTitle(isNew ? "Add a Due" : item.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!item.isComplete)
            }
        }
    }

    /// The earlier reminder, if one is set: 0 for none.
    private var early: Int {
        item.remindDaysBefore.first { $0 > 0 } ?? 0
    }

    private var onTheDayBinding: Binding<Bool> {
        Binding(
            get: { item.remindDaysBefore.contains(0) },
            set: { on in setReminders(onTheDay: on, early: early) }
        )
    }

    private var earlyBinding: Binding<Int> {
        Binding(
            get: { early },
            set: { days in setReminders(onTheDay: item.remindDaysBefore.contains(0), early: days) }
        )
    }

    private func setReminders(onTheDay: Bool, early: Int) {
        item.remindDaysBefore = [early > 0 ? early : nil, onTheDay ? 0 : nil].compactMap { $0 }
    }

    /// Only the choices that fit — and whatever is already set, even if it is
    /// an older one like "3 days before" that is no longer offered.
    private var earlyOptions: [Int] {
        let onTheDay = item.remindDaysBefore.contains(0)
        var options = DueItem.earlyReminderChoices.filter {
            $0 == early || early > 0 || fits(onTheDay: onTheDay, early: $0)
        }
        if early > 0, !options.contains(early) { options.append(early) }
        return options.sorted()
    }

    private func earlyLabel(_ days: Int) -> String {
        switch days {
        case 1: "1 day before"
        case 7: "A week before"
        default: "\(days) days before"
        }
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(byAdding: .minute, value: item.remindAtMinute, to: Calendar.current.startOfDay(for: .now)) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                item.remindAtMinute = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private var slotsLeft: Int {
        DueReminderPlan.slotsLeft(store.items, excluding: item.id)
    }

    /// Whether these reminders keep everything inside the budget.
    private func fits(onTheDay: Bool, early: Int) -> Bool {
        var trial = item
        trial.remindDaysBefore = [early > 0 ? early : nil, onTheDay ? 0 : nil].compactMap { $0 }
        return DueReminderPlan.cost(of: trial) <= slotsLeft
    }

    /// Nothing more can be switched on — said once, under the controls, so a
    /// greyed-out switch or a short menu is not a mystery.
    private var isFull: Bool {
        let onTheDay = item.remindDaysBefore.contains(0)
        let canAddDay = onTheDay || fits(onTheDay: true, early: early)
        let canAddEarly = early > 0 || fits(onTheDay: onTheDay, early: 1)
        return !(canAddDay && canAddEarly)
    }

    private func save() {
        item.title = item.title.trimmingCharacters(in: .whitespaces)
        item.category = item.category.trimmingCharacters(in: .whitespaces)

        // Read the way the phone's region writes numbers — "12,000.50" here,
        // "12.000,50" in Germany — rather than assuming one.
        let parsed = try? Double(amountText.trimmingCharacters(in: .whitespaces), format: .number)
        item.amount = parsed.flatMap { $0 > 0 ? $0 : nil }
        item.every = max(1, item.every)

        store.save(item)
        dismiss()
    }
}
#endif
