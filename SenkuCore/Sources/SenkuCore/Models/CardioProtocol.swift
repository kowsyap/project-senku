import Foundation

/// The ladder you follow on a machine, as a table you define.
///
/// ## Why this is not a personal record
///
/// A record is the best you have done; this is what you intend to do. Seven
/// blocks of time, speed and incline is a *protocol* — it is followed rather
/// than beaten, and nothing about it gets better on its own. It lives on the
/// PR page because that is where you go to look up what you are working
/// against, and it is labelled for what it is rather than filed as a record it
/// is not.
///
/// ## Why the columns are yours
///
/// A treadmill ladder wants time, speed and incline. A rowing piece wants
/// distance and split. A swim set wants lengths and rest. There is no set of
/// columns that fits all three, and guessing at one would mean everybody typing
/// around it — so the table has whatever columns you name, and the cells are
/// free text. `5 (4)`, meaning "five minutes, working towards four", stays
/// exactly as you would write it on paper.
public struct CardioProtocol: Codable, Hashable, Sendable, Identifiable {
    public var id: String { exerciseID }

    public let exerciseID: String
    public var columns: [String]
    /// Row-major, and padded to `columns.count` on read rather than on write —
    /// adding a column must not have to rewrite every row.
    public var rows: [[String]]
    public var note: String
    public var updatedAt: Date

    public init(
        exerciseID: String,
        columns: [String] = ["Time", "Speed", "Incline"],
        rows: [[String]] = [],
        note: String = "",
        updatedAt: Date = .now
    ) {
        self.exerciseID = exerciseID
        self.columns = columns
        self.rows = rows
        self.note = note
        self.updatedAt = updatedAt
    }

    public var isEmpty: Bool { rows.allSatisfy { $0.allSatisfy(\.isEmpty) } }

    /// A row, padded or trimmed to the current columns.
    public func cells(at index: Int) -> [String] {
        guard rows.indices.contains(index) else { return Array(repeating: "", count: columns.count) }
        var cells = rows[index]
        while cells.count < columns.count { cells.append("") }
        return Array(cells.prefix(columns.count))
    }

    public mutating func set(_ value: String, row: Int, column: Int) {
        guard rows.indices.contains(row), columns.indices.contains(column) else { return }
        var cells = cells(at: row)
        cells[column] = value
        rows[row] = cells
        updatedAt = .now
    }

    /// What a column comes to, across the ladder.
    public struct ColumnTotal: Hashable, Sendable, Identifiable {
        public let column: String
        public let value: Double
        /// Summed rather than maxed — true for the first column only.
        public let isSum: Bool

        public var id: String { column }

        /// Whole numbers stay whole: "20", not "20.0".
        public var text: String {
            let rounded = (value * 10).rounded() / 10
            return rounded == rounded.rounded()
                ? String(Int(rounded))
                : String(format: "%.1f", rounded)
        }
    }

    /// The bottom line: the first column added up, the rest at their highest.
    ///
    /// ## Why that rule and not a setting
    ///
    /// A ladder's first column is its durations — that is what a ladder is, a
    /// sequence of blocks of time — and the only useful thing to do with a
    /// column of durations is add them. Every other column is an intensity:
    /// speed, incline, resistance, level. Adding those would produce a number
    /// with no meaning ("39 mph"), while the highest is the figure you would
    /// quote about the session.
    ///
    /// Cells are free text, so each is read for the first number in it: `5 (4)`
    /// counts as five, which is the figure you are actually doing. A column with
    /// no numbers in it at all — a notes column — is left out rather than
    /// reported as zero.
    public var totals: [ColumnTotal] {
        columns.enumerated().compactMap { index, column in
            let numbers = rows.indices.compactMap { Self.number(in: cells(at: $0)[index]) }
            guard !numbers.isEmpty else { return nil }

            return ColumnTotal(
                column: column,
                value: index == 0 ? numbers.reduce(0, +) : (numbers.max() ?? 0),
                isSum: index == 0
            )
        }
    }

    /// The first number in a cell, ignoring anything around it.
    static func number(in cell: String) -> Double? {
        var digits = ""
        for character in cell {
            if character.isNumber || (character == "." && !digits.isEmpty) {
                digits.append(character)
            } else if !digits.isEmpty {
                break
            }
        }
        return Double(digits)
    }

    public mutating func addRow() {
        rows.append(Array(repeating: "", count: columns.count))
        updatedAt = .now
    }

    public mutating func removeRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
        updatedAt = .now
    }

    public mutating func addColumn(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        columns.append(trimmed)
        updatedAt = .now
    }

    /// Renames a column, leaving every cell under it where it is.
    ///
    /// Without this the only way to change "Incline" to "Resist" was to delete
    /// the column and add a new one, which takes the figures with it — a rename
    /// that costs you your data is not a rename.
    public mutating func renameColumn(at index: Int, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard columns.indices.contains(index), !trimmed.isEmpty else { return }
        columns[index] = trimmed
        updatedAt = .now
    }

    public mutating func removeColumn(at index: Int) {
        guard columns.indices.contains(index), columns.count > 1 else { return }
        columns.remove(at: index)
        rows = rows.map { row in
            var row = row
            if row.indices.contains(index) { row.remove(at: index) }
            return row
        }
        updatedAt = .now
    }
}
