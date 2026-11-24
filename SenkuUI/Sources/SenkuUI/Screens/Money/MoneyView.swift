#if !os(watchOS)
import SwiftUI
import Charts
import SenkuCore

/// Expenses, or income: a dashboard for a chosen stretch of months, then the
/// entries month by month.
struct MoneyView: View {
    let store: MoneyStore
    /// The other one — income on the expenses screen and the other way round
    /// — when it is added, for money in against money out.
    let counterpart: MoneyStore?

    @State private var period: MoneyPeriod
    @State private var isChoosingCustom = false
    @State private var customFrom = YearMonth.current().adding(-5)
    @State private var customTo = YearMonth.current()
    @State private var focus: String?
    @State private var listMonth = YearMonth.current()
    @State private var page: Page = .dashboard
    /// Which page of rows each table is on; see `pageSize`.
    @State private var monthsPage = 0
    @State private var inOutPage = 0

    enum Page: Hashable { case dashboard, list }
    @State private var editing: Editing?
    #if os(iOS)
    @State private var exported: ExportedReport?
    #endif

    private struct Editing: Identifiable {
        let entry: MoneyEntry?
        var id: UUID { entry?.id ?? Self.newID }
        static let newID = UUID()
    }

    /// Six months, except in a debug build asked for another, which is how
    /// screenshots of a longer stretch are taken:
    ///
    ///     SIMCTL_CHILD_SENKU_MONEY_PERIOD=12 xcrun simctl launch <device> pk.Senku
    private static var openingPeriod: MoneyPeriod {
        #if DEBUG
        if let asked = ProcessInfo.processInfo.environment["SENKU_MONEY_PERIOD"] {
            if asked == "all" { return .all }
            if let months = Int(asked) { return .months(months) }
        }
        #endif
        return .months(6)
    }

    private var kind: MoneyStore.Kind { store.kind }
    private var now: YearMonth { .current() }

    private var range: ClosedRange<YearMonth> {
        period.range(now: now, earliest: store.earliest)
    }

    private var report: MoneyReport {
        MoneyReport(store.entries, range: range, grouping: store.grouping, only: focus)
    }

    /// Unfiltered, for the donut and the tables, which are where a focus is chosen.
    private var whole: MoneyReport {
        MoneyReport(store.entries, range: range, grouping: store.grouping)
    }

    private var previous: MoneyReport {
        MoneyReport(store.entries, range: MoneyPeriod.previous(to: range), grouping: store.grouping, only: focus)
    }

    init(store: MoneyStore, counterpart: MoneyStore?, period: MoneyPeriod? = nil) {
        self.store = store
        self.counterpart = counterpart
        _period = State(initialValue: period ?? Self.openingPeriod)
    }

    var body: some View {
        ScrollView {
            content
        }
        .background(.background)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                Button(action: export) {
                    StackedActionLabel("Export", symbol: "square.and.arrow.up")
                }
                .disabled(store.entries.isEmpty)
            }
            #endif
            ToolbarItem(placement: .primaryAction) {
                Button { editing = Editing(entry: nil) } label: {
                    StackedActionLabel("Add", symbol: "plus")
                }
            }
        }
        .sheet(item: $editing) { editing in
            MoneyEditor(store: store, entry: editing.entry, month: editing.entry?.month ?? listMonth) {
                self.editing = nil
            }
        }
        .sheet(isPresented: $isChoosingCustom) { customSheet }
        #if os(iOS)
        .sheet(item: $exported) { ShareSheet(urls: $0.urls) }
        #endif
        .senkuBottomBarInset()
    }

    var content: some View {
            VStack(spacing: Senku.Metrics.stackSpacing) {
                if store.entries.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing yet", systemImage: kind == .expenses ? "creditcard" : "dollarsign.bank.building")
                    } actions: {
                        Button("Add \(kind == .expenses ? "a spend" : "income")") { editing = Editing(entry: nil) }
                            .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 40)
                } else {
                    Picker("View", selection: $page) {
                        Text("Dashboard").tag(Page.dashboard)
                        Text(kind == .expenses ? "Spends" : "Earnings").tag(Page.list)
                    }
                    .pickerStyle(.segmented)

                    switch page {
                    case .dashboard: dashboard
                    case .list: monthList
                    }
                }
            }
            .padding()
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Dashboard

    @ViewBuilder
    private var dashboard: some View {
        periodPicker

        if let focus {
            HStack {
                Text("Only \(focus)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Show all") { self.focus = nil }
                    .font(.subheadline)
            }
            .padding(.horizontal, 4)
        }

        figures

        if whole.total > 0 {
            if focus == nil { donutCard }
            if report.monthCount > 1 { monthlyCard }
            if kind == .expenses { namesCard }
            if focus == nil { groupTable }
            if report.monthCount > 1 { monthTable }
        }

        if let counterpart, !counterpart.entries.isEmpty,
           MoneyReport(counterpart.entries, range: range, grouping: counterpart.grouping).total + whole.total > 0 {
            inOutCard(counterpart)
        }
    }

    private var periodChoices: [(String, MoneyPeriod)] {
        [("6 months", .months(6)),
         ("This year", .thisYear), ("12 months", .months(12)), ("All", .all)]
    }

    private var periodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(periodChoices, id: \.0) { title, choice in
                    chip(title, isOn: period == choice) { period = choice }
                }
                chip(customTitle ?? "Custom…", isOn: customTitle != nil) { isChoosingCustom = true }
            }
            .padding(.horizontal, 2)
        }
    }

    private var customTitle: String? {
        guard case .custom(let a, let b) = period else { return nil }
        let r = min(a, b)...max(a, b)
        return r.lowerBound == r.upperBound
            ? MoneyStyle.title(r.lowerBound)
            : "\(MoneyStyle.title(r.lowerBound)) – \(MoneyStyle.title(r.upperBound))"
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isOn ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(isOn ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12)))
                .foregroundStyle(isOn ? Color.accentColor : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var customSheet: some View {
        NavigationStack {
            Form {
                MonthYearPicker(month: $customFrom, label: "From")
                MonthYearPicker(month: $customTo, label: "To")
            }
            .navigationTitle("Custom")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isChoosingCustom = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show") {
                        period = .custom(customFrom, customTo)
                        isChoosingCustom = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var figures: some View {
        let change = report.change(from: previous)
        return HStack(spacing: 10) {
            tile(
                "Monthly average",
                MoneyStyle.money(report.monthlyAverage),
                change.map { "\(MoneyStyle.percent($0)) on the period before" } ?? "Over \(report.monthCount) months"
            )
            if let highest = report.highestMonth, report.monthCount > 1 {
                tile("Highest month", MoneyStyle.money(highest.total), MoneyStyle.title(highest.month, long: true))
            }
        }
    }

    private func tile(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Senku.Metrics.cardCorner, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        )
    }

    // MARK: Charts

    private var palette: [String: Color] {
        MoneyStyle.colors(for: whole.topGroups(7).map(\.key))
    }

    private var donutCard: some View {
        let groups = whole.topGroups(7)
        let colors = palette
        return Card(kind.groupTitle) {
            Chart(groups) { group in
                SectorMark(
                    angle: .value("Total", group.total),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(colors[group.key] ?? MoneyStyle.other)
            }
            .chartLegend(.hidden)
            .frame(height: 200)
            .overlay {
                VStack(spacing: 0) {
                    Text(MoneyStyle.money(whole.total))
                        .font(.headline)
                        .monospacedDigit()
                    Text(kind.totalLabel.lowercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(groups.map { "\($0.key) \(Int(($0.share * 100).rounded())) percent" }.joined(separator: ", "))

            VStack(spacing: 8) {
                ForEach(groups) { group in
                    Button {
                        if group.key != MoneyReport.other { focus = group.key }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(colors[group.key] ?? MoneyStyle.other)
                                .frame(width: 10, height: 10)
                            Text(group.key)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(MoneyStyle.share(group.share))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Text(MoneyStyle.money(group.total))
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 80, alignment: .trailing)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(group.key == MoneyReport.other)
                }
            }
        }
    }

    @State private var selectedDate: Date?

    /// Each month's total, split by category (or source) unless one is
    /// chosen — one chart, since the split bars add up to the same totals.
    private var monthlyCard: some View {
        let points = report.monthly
        let average = report.monthlyAverage
        let split = focus == nil && whole.groups.count > 1
        let stacked = whole.stacked(5)
        let keys = whole.topGroups(5).map(\.key)
        let colors = palette
        let barColor = focus.flatMap { colors[$0] } ?? MoneyStyle.series[0]
        let selected = selectedDate.map { YearMonth($0) }
        let selectedTotal = selected.flatMap { month in points.first { $0.month == month }?.total }
        return Card("Month by month") {
            Chart {
                if split {
                    ForEach(stacked, id: \.self) { point in
                        BarMark(
                            x: .value("Month", point.month.firstDay(), unit: .month),
                            y: .value("Total", point.total),
                            width: .ratio(0.7)
                        )
                        .foregroundStyle(by: .value(kind.groupLabel, point.key))
                        .opacity(selected == nil || selected == point.month ? 1 : 0.4)
                    }
                } else {
                    ForEach(points, id: \.month) { point in
                        BarMark(
                            x: .value("Month", point.month.firstDay(), unit: .month),
                            y: .value("Total", point.total),
                            width: .ratio(0.7)
                        )
                        .cornerRadius(4)
                        .foregroundStyle(barColor.opacity(selected == nil || selected == point.month ? 1 : 0.4))
                    }
                }
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading, spacing: 2) {
                        Text("Average")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
            .chartForegroundStyleScale(domain: keys, range: keys.map { colors[$0] ?? MoneyStyle.other })
            .chartLegend(split ? .visible : .hidden)
            .chartLegend(position: .bottom, alignment: .leading, spacing: 10)
            // Every month in the period, so a gap reads as a gap.
            .chartXScale(domain: report.range.lowerBound.firstDay()...report.range.upperBound.adding(1).firstDay())
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: max(1, points.count / 6))) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) { Text(Self.short(amount)) }
                    }
                }
            }
            .frame(height: split ? 240 : 200)

            if let selected, let selectedTotal {
                Text("\(MoneyStyle.title(selected, long: true)): \(MoneyStyle.money(selectedTotal))")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
        }
    }

    private var namesCard: some View {
        Card("Top names") {
            ForEach(report.names.prefix(6)) { name in
                HStack {
                    Text(name.key)
                        .font(.subheadline)
                    Text("× \(name.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyStyle.money(name.total))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: Tables

    private var groupTable: some View {
        let before = MoneyReport(store.entries, range: MoneyPeriod.previous(to: range), grouping: store.grouping)
        return Card(kind == .expenses ? "Categories" : "Sources") {
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text(kind.groupLabel).frame(maxWidth: .infinity, alignment: .leading).gridColumnAlignment(.leading)
                    Text("Total")
                    Text("%")
                    Text("Per month")
                    Text("Change")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(whole.groups) { group in
                    let was = before.groups.first { $0.key == group.key }?.total ?? 0
                    GridRow {
                        Button { focus = group.key } label: {
                            Text(group.key).lineLimit(1)
                        }
                        .buttonStyle(.plain)
                        .gridColumnAlignment(.leading)
                        Text(MoneyStyle.money(group.total))
                        Text(MoneyStyle.share(group.share))
                        Text(MoneyStyle.money(whole.monthlyTotal(of: group.key)))
                        Text(was > 0 ? MoneyStyle.percent((group.total - was) / was) : "—")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var monthTable: some View {
        let all = Array(report.monthly.reversed().filter { $0.count > 0 })
        let rows = Self.slice(all, page: monthsPage)
        return Card("Months") {
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Month").frame(maxWidth: .infinity, alignment: .leading).gridColumnAlignment(.leading)
                    Text("Total")
                    Text("Entries")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(rows, id: \.month) { row in
                    GridRow {
                        Button {
                            listMonth = row.month
                            page = .list
                        } label: {
                            Text(MoneyStyle.title(row.month))
                        }
                        .buttonStyle(.plain)
                        .gridColumnAlignment(.leading)
                        Text(MoneyStyle.money(row.total))
                        Text("\(row.count)")
                    }
                    .font(.footnote)
                    .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            pager(count: all.count, page: $monthsPage)
        }
        .onChange(of: period) { monthsPage = 0 }
        .onChange(of: focus) { monthsPage = 0 }
    }

    // MARK: Paging

    /// Rows a table shows at once. Past that, it pages, newest first.
    static let pageSize = 6

    /// The rows on `page`, held to the last page when there are fewer rows
    /// than there were.
    static func slice<Row>(_ rows: [Row], page: Int) -> [Row] {
        let last = max(0, (rows.count - 1) / pageSize)
        let start = min(max(page, 0), last) * pageSize
        return Array(rows[start..<min(start + pageSize, rows.count)])
    }

    /// "‹  7–12 of 27  ›" under a table, only when it has more than a page.
    @ViewBuilder
    private func pager(count: Int, page: Binding<Int>) -> some View {
        if count > Self.pageSize {
            let last = (count - 1) / Self.pageSize
            let current = min(page.wrappedValue, last)
            let first = current * Self.pageSize + 1
            HStack {
                Button {
                    page.wrappedValue = current - 1
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 28)
                        .contentShape(Rectangle())
                }
                .disabled(current == 0)
                .accessibilityLabel("Newer")

                Spacer()
                Text("\(first)–\(min(first + Self.pageSize - 1, count)) of \(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()

                Button {
                    page.wrappedValue = current + 1
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 28)
                        .contentShape(Rectangle())
                }
                .disabled(current == last)
                .accessibilityLabel("Older")
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .animation(.snappy, value: current)
        }
    }

    // MARK: In and out

    private func inOutCard(_ other: MoneyStore) -> some View {
        let incomeStore = kind == .income ? store : other
        let spendStore = kind == .expenses ? store : other
        let months = YearMonth.span(range.lowerBound, range.upperBound)
        let income = MoneyReport(incomeStore.entries, range: range, grouping: .name).monthly
        let spent = MoneyReport(spendStore.entries, range: range, grouping: .category).monthly
        let rows = months.indices.map { (month: months[$0], income: income[$0].total, spent: spent[$0].total) }
        let inColor = MoneyStyle.series[0], outColor = MoneyStyle.series[1]
        let totalIn = rows.reduce(0) { $0 + $1.income }, totalOut = rows.reduce(0) { $0 + $1.spent }
        let listed = Array(rows.reversed().filter { $0.income > 0 || $0.spent > 0 })

        return Card("Money in and out") {
            HStack(spacing: 16) {
                legend("Income", inColor, totalIn)
                legend("Spent", outColor, totalOut)
                legend("Saved", nil, totalIn - totalOut)
            }

            if rows.count > 1 {
                Chart {
                    ForEach(rows, id: \.month) { row in
                        BarMark(x: .value("Month", row.month.firstDay(), unit: .month), y: .value("Amount", row.income))
                            .foregroundStyle(by: .value("Kind", "Income"))
                            .position(by: .value("Kind", "Income"))
                            .cornerRadius(3)
                        BarMark(x: .value("Month", row.month.firstDay(), unit: .month), y: .value("Amount", row.spent))
                            .foregroundStyle(by: .value("Kind", "Spent"))
                            .position(by: .value("Kind", "Spent"))
                            .cornerRadius(3)
                    }
                }
                .chartForegroundStyleScale(["Income": inColor, "Spent": outColor])
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: max(1, rows.count / 6))) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) { Text(Self.short(amount)) }
                        }
                    }
                }
                .frame(height: 200)
            }

            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Month").frame(maxWidth: .infinity, alignment: .leading).gridColumnAlignment(.leading)
                    Text("In")
                    Text("Out")
                    Text("Saved")
                    Text("%")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                Divider().gridCellUnsizedAxes(.horizontal)

                ForEach(Self.slice(listed, page: inOutPage), id: \.month) { row in
                    let saved = row.income - row.spent
                    GridRow {
                        Text(MoneyStyle.title(row.month)).gridColumnAlignment(.leading)
                        Text(MoneyStyle.money(row.income))
                        Text(MoneyStyle.money(row.spent))
                        Text(MoneyStyle.money(saved))
                            .fontWeight(.semibold)
                        Text(row.income > 0 ? "\(Int((saved / row.income * 100).rounded()))" : "—")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            pager(count: listed.count, page: $inOutPage)
        }
        .onChange(of: period) { inOutPage = 0 }
    }

    private func legend(_ title: String, _ color: Color?, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if let color {
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(MoneyStyle.money(amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Month by month

    private var latestMonth: YearMonth { max(now, store.entries.first?.month ?? now) }

    private var listedMonths: [YearMonth] {
        Array(Set(store.entries.map(\.month) + [now])).sorted(by: >)
    }

    /// The month's total, against the month before.
    private func monthFigures(total: Double, count: Int) -> some View {
        let before = store.entries(in: listMonth.adding(-1)).reduce(0) { $0 + $1.total }
        let change = before > 0 ? (total - before) / before : nil
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            tile(kind.totalLabel, MoneyStyle.money(total), "\(count) \(count == 1 ? "entry" : "entries")")
            tile(
                MoneyStyle.title(listMonth.adding(-1)),
                MoneyStyle.money(before),
                change.map { "\(MoneyStyle.percent($0)) this month" } ?? "Nothing to compare"
            )
        }
    }

    private var monthList: some View {
        let entries = store.entries(in: listMonth)
        let total = entries.reduce(0) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button { listMonth = listMonth.adding(-1) } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Menu {
                    ForEach(listedMonths) { month in
                        Button(MoneyStyle.title(month, long: true)) { listMonth = month }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(MoneyStyle.title(listMonth, long: true))
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button { listMonth = listMonth.adding(1) } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .disabled(listMonth >= latestMonth)
                .accessibilityLabel("Next month")
            }

            monthFigures(total: total, count: entries.count)

            if entries.isEmpty {
                Text("Nothing in \(MoneyStyle.title(listMonth, long: true)).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        row(entry)
                        if entry.id != entries.last?.id {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Senku.Metrics.cardCorner, style: .continuous)
                        .fill(Color.secondary.opacity(0.10))
                )
            }
        }
    }

    private func row(_ entry: MoneyEntry) -> some View {
        Button { editing = Editing(entry: entry) } label: {
            HStack(spacing: 12) {
                Image(systemName: kind == .expenses ? MoneyStyle.symbol(for: entry.category) : "dollarsign.bank.building")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Text(detail(entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(MoneyStyle.money(entry.total))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit", systemImage: "pencil") { editing = Editing(entry: entry) }
            Button("Delete", systemImage: "trash", role: .destructive) { store.delete(entry) }
        }
    }

    private func detail(_ entry: MoneyEntry) -> String {
        var parts: [String] = []
        if kind == .expenses { parts.append(entry.category) }
        if entry.amounts.count > 1 { parts.append("\(entry.amounts.count) amounts") }
        if !entry.note.isEmpty { parts.append(entry.note) }
        return parts.isEmpty ? MoneyStyle.title(entry.month) : parts.joined(separator: " · ")
    }

    // MARK: - Export

    #if os(iOS)
    /// What is on screen, as a CSV: the dashboard's period and the category
    /// or source picked on it, or the one month open in the list.
    private func export() {
        var filter = MoneyExport(
            from: page == .dashboard ? range.lowerBound : listMonth,
            to: page == .dashboard ? range.upperBound : listMonth
        )
        if page == .dashboard, let focus {
            filter.excluded = Set(MoneyExport.groups(store.entries, kind: kind)).subtracting([focus])
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filter.fileName(store.entries, kind: kind))
        do {
            try filter.csv(store.entries, kind: kind).write(to: url, atomically: true, encoding: .utf8)
            exported = ExportedReport(urls: [url])
        } catch {}
    }
    #endif

    /// "$1.2k" on an axis, where a full amount would crowd it.
    private static func short(_ amount: Double) -> String {
        amount >= 1000 ? "\((amount / 1000).formatted(.number.precision(.fractionLength(0...1))))k" : "\(Int(amount))"
    }
}
#endif

