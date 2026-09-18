import Foundation
import SenkuCore

/// A file that fills Senku in.
///
/// ## What this is for
///
/// Typing a year of weigh-ins on a phone is not a thing anyone will do, and
/// neither is retyping a set of lifts you already have in a spreadsheet. This
/// is the way in: one JSON file, handed to the app through the hidden long
/// press on the wordmark, carrying as much or as little as you have.
///
/// ## Every section is optional
///
/// A file with nothing but `profile` is valid. So is one with nothing but a
/// list of weigh-ins. That matters more than it looks: the sections here are
/// the ones that exist today, and the workout log, water and macros will each
/// add their own. A file written for today's app must keep working when they
/// do, and a file written for a later app must not be rejected wholesale by an
/// older one — which is why decoding ignores keys it does not recognise rather
/// than failing, and why the version is carried but not enforced.
///
/// ## Merge, not replace
///
/// Importing adds. It does not wipe what is there, because a file you meant as
/// "here is my old history" would otherwise silently delete the month you have
/// logged since. The one exception is `profile`, which is a single value and so
/// can only be replaced — and which the summary names before anything is
/// written.
///
/// ## Dates
///
/// ISO 8601: `"2026-03-14"` or `"2026-03-14T08:30:00Z"`. A bare day is read as
/// midnight local, which is the right reading for a weigh-in someone recorded
/// as "the 14th".
public struct SenkuImportDocument: Codable, Sendable {
    public var schemaVersion: Int?
    /// "metric" or "imperial" — what to display weights in, for a file that
    /// carries no profile. Without it an imperial user imports a hundred
    /// pounds-and-ounces records and sees every one of them in kilograms.
    public var unitSystem: UnitSystem?
    public var profile: ProfileStore.Profile?
    public var weighIns: [WeighInEntry]?
    public var records: [RecordEntry]?
    public var customExercises: [CustomExerciseEntry]?

    // The rest of the app's state, written by the exporter and read back on
    // import. These carry the app's own types verbatim rather than a
    // hand-written entry shape, because they exist to restore a device exactly
    // — a backup is not a place to be lossy — while the four above stay
    // hand-shaped so that a file written by a person stays easy to write.
    public var plan: TrainingPlan?
    public var workouts: [WorkoutSession]?
    public var cardioRecords: [CardioRecord]?
    public var cardioPlans: [CardioProtocol]?
    public var anime: [AnimeEntry]?

    /// Weights may be given in either unit.
    ///
    /// The app stores kilograms, and a file written by hand is written in
    /// whatever the person weighs things in — so both are accepted and `lb`
    /// wins if somebody supplies both. Asking an imperial user to convert a
    /// hundred numbers before importing them is asking them not to import them.
    public struct WeighInEntry: Codable, Sendable {
        public var date: Date
        public var weightKG: Double?
        public var weightLB: Double?
        public var note: String?

        public var kilograms: Double? {
            if let weightLB { return Convert.kilograms(fromPounds: weightLB) }
            return weightKG
        }
    }

    public struct RecordEntry: Codable, Sendable {
        public var exerciseID: String
        public var weightKG: Double?
        public var weightLB: Double?
        public var reps: Int?
        /// A held exercise — a plank, a wall sit — measured in seconds.
        public var seconds: TimeInterval?
        public var date: Date

        public var kilograms: Double {
            if let weightLB { return Convert.kilograms(fromPounds: weightLB) }
            return weightKG ?? 0
        }
    }

    public struct CustomExerciseEntry: Codable, Sendable {
        public var name: String
        /// `barbell`, `dumbbell`, `machine`, `cable`, `bodyweight`.
        public var equipment: String
        /// Region ids from the catalogue, e.g. `chest.upper`.
        public var regionIDs: [String]
    }

    /// Everything on this device, for a backup that restores exactly.
    @MainActor
    public static func snapshot(
        profile: ProfileStore.Profile?,
        weights: WeightLogStore,
        records: RecordStore,
        library: ExerciseLibrary,
        plans: TrainingPlanStore,
        workouts: WorkoutStore,
        cardioRecords: CardioRecordStore,
        cardioPlans: CardioProtocolStore,
        anime: AnimeStore
    ) -> SenkuImportDocument {
        var document = SenkuImportDocument()
        document.schemaVersion = 1
        document.unitSystem = profile?.unitSystem ?? UnitPreference.current
        document.profile = profile

        document.weighIns = weights.weighIns.map {
            WeighInEntry(date: $0.date, weightKG: $0.weightKG, note: $0.note)
        }
        document.records = records.records.map {
            RecordEntry(
                exerciseID: $0.exerciseID,
                weightKG: $0.weightKG,
                reps: $0.reps,
                seconds: $0.seconds,
                date: $0.date
            )
        }
        document.customExercises = library.custom.map { exercise in
            CustomExerciseEntry(
                name: exercise.name,
                equipment: exercise.equipment.rawValue,
                regionIDs: Array(exercise.contributions.keys)
            )
        }

        document.plan = plans.plan
        // The live session too: a backup taken mid-workout should restore
        // mid-workout, which is exactly when someone reaches for one.
        document.workouts = workouts.history + [workouts.live].compactMap { $0 }
        document.cardioRecords = cardioRecords.records
        document.cardioPlans = cardioPlans.protocols
        document.anime = anime.entries

        return document
    }

    /// Writes the file, in the shape ``decode(_:)`` reads.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(self)
    }

    /// Reads a file.
    ///
    /// The date strategy accepts a plain day as well as a full timestamp,
    /// because a file written by hand will have days in it and a file written
    /// by an export will have timestamps, and refusing either would make the
    /// format a chore to produce.
    public static func decode(_ data: Data) throws -> SenkuImportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = ImportDates.timestamp(text) { return date }
            if let date = ImportDates.day(text) { return date }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Not a date: \(text)")
            )
        }
        return try decoder.decode(SenkuImportDocument.self, from: data)
    }
}

/// Built per call rather than cached in a global.
///
/// `ISO8601DateFormatter` is not `Sendable`, and a shared instance would be a
/// data race the compiler is right to refuse. Importing a file is a once-in-a
/// while action measured in milliseconds; the formatter is not worth a lock.
private enum ImportDates {
    static func timestamp(_ text: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    static func day(_ text: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }
}

/// What an import did, in the words the confirmation shows.
///
/// Counted per section and per outcome rather than as one total, because
/// "added 40" and "skipped 40 you already had" are the same file and very
/// different news.
public struct ImportSummary: Sendable {
    public var profileReplaced = false
    public var weighInsAdded = 0
    public var weighInsSkipped = 0
    public var recordsAdded = 0
    public var recordsSkipped = 0
    public var exercisesAdded = 0
    public var exercisesSkipped = 0
    public var planReplaced = false
    public var workoutsAdded = 0
    public var workoutsSkipped = 0
    public var cardioAdded = 0
    public var cardioSkipped = 0
    public var animeAdded = 0
    public var animeSkipped = 0
    /// Entries the app could not make sense of, named so they can be fixed.
    public var problems: [String] = []

    public var isEmpty: Bool {
        !profileReplaced && !planReplaced
            && weighInsAdded == 0 && recordsAdded == 0 && exercisesAdded == 0
            && workoutsAdded == 0 && cardioAdded == 0 && animeAdded == 0
    }

    public var headline: String {
        if isEmpty && problems.isEmpty { return "Nothing new to add" }
        if isEmpty { return "Nothing was imported" }

        var parts: [String] = []
        if profileReplaced { parts.append("profile") }
        if weighInsAdded > 0 { parts.append("\(weighInsAdded) weigh-in\(weighInsAdded == 1 ? "" : "s")") }
        if recordsAdded > 0 { parts.append("\(recordsAdded) record\(recordsAdded == 1 ? "" : "s")") }
        if exercisesAdded > 0 { parts.append("\(exercisesAdded) exercise\(exercisesAdded == 1 ? "" : "s")") }
        if planReplaced { parts.append("your plan") }
        if workoutsAdded > 0 { parts.append("\(workoutsAdded) workout\(workoutsAdded == 1 ? "" : "s")") }
        if cardioAdded > 0 { parts.append("\(cardioAdded) cardio entr\(cardioAdded == 1 ? "y" : "ies")") }
        if animeAdded > 0 { parts.append("\(animeAdded) anime") }
        return "Imported " + parts.formatted(.list(type: .and))
    }

    public var detail: String? {
        var lines: [String] = []

        let skipped = weighInsSkipped + recordsSkipped + exercisesSkipped
            + workoutsSkipped + cardioSkipped + animeSkipped
        if skipped > 0 {
            lines.append("\(skipped) already there, left alone.")
        }
        if !problems.isEmpty {
            lines.append(problems.prefix(5).joined(separator: "\n"))
            if problems.count > 5 {
                lines.append("…and \(problems.count - 5) more.")
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

/// Applies a document to the stores.
///
/// One bad entry does not stop the file. A weigh-in of 4000 kg is a typo in one
/// line, not a reason to reject the other three hundred — it is skipped, named
/// in `problems`, and the rest goes in. That is the opposite of how the
/// catalogue is loaded, and deliberately so: the catalogue ships with the app
/// and a fault in it is a bug, while this file comes from outside and a fault
/// in it is Tuesday.
@MainActor
public enum SenkuImporter {
    public static func apply(
        _ document: SenkuImportDocument,
        profiles: ProfileStore,
        weights: WeightLogStore,
        records: RecordStore,
        library: ExerciseLibrary,
        plans: TrainingPlanStore,
        workouts: WorkoutStore,
        cardioRecords: CardioRecordStore,
        cardioPlans: CardioProtocolStore,
        anime: AnimeStore
    ) -> ImportSummary {
        var summary = ImportSummary()

        if let unitSystem = document.unitSystem {
            UnitPreference.current = unitSystem
        }

        if let profile = document.profile {
            profiles.save(profile)
            summary.profileReplaced = true
        }

        for entry in document.weighIns ?? [] {
            guard let weightKG = entry.kilograms else {
                summary.problems.append("A weigh-in on \(entry.date.formatted(date: .abbreviated, time: .omitted)) has no weight.")
                continue
            }
            // Same day, same weight, already logged: the overlap you get when
            // you import a file twice, or import one that starts where the app
            // already has readings.
            let duplicate = weights.weighIns.contains {
                Calendar.current.isDate($0.date, inSameDayAs: entry.date)
                    && abs($0.weightKG - weightKG) < 0.01
            }
            guard !duplicate else {
                summary.weighInsSkipped += 1
                continue
            }

            do {
                weights.add(
                    try WeighIn(
                        date: entry.date,
                        weightKG: weightKG,
                        source: .imported,
                        note: entry.note
                    )
                )
                summary.weighInsAdded += 1
            } catch {
                summary.problems.append("Weigh-in \(weightKG) kg: out of range.")
            }
        }

        for entry in document.customExercises ?? [] {
            let regions = entry.regionIDs.compactMap { library.catalogue.region($0) }
            guard !regions.isEmpty else {
                summary.problems.append("“\(entry.name)”: no muscle in \(entry.regionIDs.joined(separator: ", ")).")
                continue
            }
            guard !library.all.contains(where: { $0.name.lowercased() == entry.name.lowercased() }) else {
                summary.exercisesSkipped += 1
                continue
            }
            guard let exercise = Exercise.custom(
                name: entry.name,
                equipment: Equipment(entry.equipment),
                regions: regions
            ) else {
                summary.problems.append("“\(entry.name)”: could not be built.")
                continue
            }

            library.add(exercise)
            summary.exercisesAdded += 1
        }

        for entry in document.records ?? [] {
            // Against the library rather than the catalogue, so a record can
            // name a custom exercise defined earlier in the same file.
            guard library.exercise(entry.exerciseID) != nil else {
                summary.problems.append("No exercise called “\(entry.exerciseID)”.")
                continue
            }
            guard records.book.existingRecord(
                exerciseID: entry.exerciseID,
                weightKG: entry.kilograms,
                reps: entry.reps ?? 0,
                seconds: entry.seconds
            ) == nil else {
                summary.recordsSkipped += 1
                continue
            }

            do {
                records.add(
                    try PersonalRecord(
                        exerciseID: entry.exerciseID,
                        weightKG: entry.kilograms,
                        reps: entry.seconds == nil ? (entry.reps ?? 0) : 0,
                        seconds: entry.seconds,
                        date: entry.date,
                        source: .manual
                    )
                )
                summary.recordsAdded += 1
            } catch {
                summary.problems.append("\(entry.exerciseID): weight or reps out of range.")
            }
        }

        if let plan = document.plan, !plan.days.isEmpty {
            // Replaced, not merged. Two plans interleaved is not a plan, and a
            // file carrying one was written by the exporter, which means the
            // intent was "make this device look like that one".
            for day in plans.days { plans.delete(day) }
            for day in plan.days { plans.add(day) }
            summary.planReplaced = true
        }

        for session in document.workouts ?? [] {
            guard !workouts.contains(session.id) else {
                summary.workoutsSkipped += 1
                continue
            }
            workouts.restore(session)
            summary.workoutsAdded += 1
        }

        for record in document.cardioRecords ?? [] {
            guard !cardioRecords.records.contains(where: { $0.id == record.id }) else {
                summary.cardioSkipped += 1
                continue
            }
            cardioRecords.add(record)
            summary.cardioAdded += 1
        }

        for plan in document.cardioPlans ?? [] {
            guard cardioPlans.plan(for: plan.exerciseID) == nil else {
                summary.cardioSkipped += 1
                continue
            }
            cardioPlans.save(plan)
            summary.cardioAdded += 1
        }

        for series in document.anime ?? [] {
            guard anime.entry(series.id) == nil else {
                summary.animeSkipped += 1
                continue
            }
            anime.restore(series)
            summary.animeAdded += 1
        }

        return summary
    }
}
