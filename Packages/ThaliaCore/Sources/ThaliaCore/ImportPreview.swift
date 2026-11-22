import Foundation
import BinisoftKitCore

/// What the app already has, in the same plain values the CSV reads – keyed like the import.
public struct ExistingState: Sendable {
    public var goals: [String: GoalRecord] = [:]
    public var categories: [String: CategoryRecord] = [:]
    public var weeks: [String: WeekRecord] = [:]
    public var days: [String: DayRecord] = [:]
    public var items: [String: ItemRecord] = [:]
    public var measures: [String: MeasureRecord] = [:]
    public var marks: [String: MarkRecord] = [:]
    /// One aggregated value per measurement and day (`order` 0).
    public var entries: [String: EntryRecord] = [:]
    public var work: [String: WorkRecord] = [:]
    public var notes: [String: NoteRecord] = [:]
    public var reviews: [String: ReviewRecord] = [:]
    public var scores: [String: ScoreRecord] = [:]
    /// Closed days and weeks (R27).
    public var closedDays: Set<DayKey> = []
    public var closedWeeks: Set<WeekKey> = []
    /// The stored archive grades per week (settings `archive.<week>`, v9).
    public var archiveGrades: [WeekKey: ArchiveWeek] = [:]
    /// The stored v10 records by key (`SettingKeys.all`, the newest copy each) – backups bring them as
    /// `record` rows.
    public var records: [String: SettingRow] = [:]

    public init() {}

    public var categoryTitles: [String: String] { categories.mapValues(\.title) }
    public var measureCodes: Set<String> { Set(measures.values.map(\.code)) }
    /// "2026-W45|1.1-01" for every item the app has (v8: marks on unknown items get a warning).
    public var itemKeys: Set<String> { Set(items.values.map(\.key)) }
}

/// A week whose plan an import replaces (R49): what goes to the archive, said plainly.
public struct WeekReplacement: Equatable, Sendable {
    public var week: WeekKey
    /// Marks set in the week (mark != nil).
    public var marks: Int
    /// Values recorded in the week (one per measurement and day).
    public var values: Int
    /// Items of the week (only counted for "Archivdaten ersetzen", v9).
    public var items: Int
    /// Archive grades of the week (v9).
    public var grades: Int
    /// Everything the app has for the week goes to the archive ("Archivdaten dieser Wochen ersetzen", v9),
    /// not only its plan.
    public var isArchiveReplacement: Bool
    /// "KW47 wird ersetzt – 23 Markierungen und 9 Werte gehen ins Archiv."
    public var text: String
    /// "KW47 ersetzen"
    public var buttonTitle: String

    public init(week: WeekKey, marks: Int, values: Int) {
        self.week = week
        self.marks = marks
        self.values = values
        items = 0
        grades = 0
        isArchiveReplacement = false
        text = "\(week.label) wird ersetzt – \(Format.count(marks, "Markierung", "Markierungen")) und "
            + "\(Format.count(values, "Wert", "Werte")) gehen ins Archiv."
        buttonTitle = "\(week.label) ersetzen"
    }

    /// "Archivdaten dieser Wochen ersetzen" (v9): "KW43 wird ersetzt – 63 Punkte, 120 Markierungen,
    /// 22 Noten und die Wertung gehen ins Archiv."
    public init(archiveOf week: WeekKey, items: Int, marks: Int, values: Int, grades: Int, hasScore: Bool) {
        self.week = week
        self.marks = marks
        self.values = values
        self.items = items
        self.grades = grades
        isArchiveReplacement = true
        // (text, singular?) per part that the week has.
        var parts: [(String, Bool)] = []
        for (n, one, many) in [(items, "Punkt", "Punkte"), (marks, "Markierung", "Markierungen"), (values, "Wert", "Werte"),
                               (grades, "Note", "Noten")] where n > 0 {
            parts.append((Format.count(n, one, many), n == 1))
        }
        if hasScore { parts.append(("die Wertung", true)) }
        let list: String
        if let only = parts.first, parts.count == 1 {
            list = only.0 + (only.1 ? " geht" : " gehen")
        } else if let last = parts.last {
            list = parts.dropLast().map(\.0).joined(separator: ", ") + " und " + last.0 + " gehen"
        } else {
            list = "die bisherigen Angaben der Woche gehen"
        }
        text = "\(week.label) wird ersetzt – \(list) ins Archiv."
        buttonTitle = "\(week.label) ersetzen"
    }
}

/// One week of a file in the preview of past weeks (v8): new or replaced, what comes in.
public struct ImportWeekSummary: Equatable, Sendable {
    public var week: WeekKey
    /// The app has no plan and no week row for this week yet.
    public var isNew: Bool
    /// The file replaces the week's plan; its marks and values go to the archive.
    public var isReplaced: Bool
    /// Something in the week is new or changed.
    public var hasChanges: Bool
    /// Items of the week in the file.
    public var items: Int
    /// Marks with a value (✓ ½ ✗ –) in the file.
    public var marks: Int
    /// Sick and holiday days by the file's day rows.
    public var excusedDays: [DayKey]
    /// The week row's reported score (paper score).
    public var recordedScore: Double?
    /// The import closes the week (the app has it open).
    public var closes: Bool
    /// The file's warnings about this week ("KW45: …", "KW45 1.1-01: …").
    public var warnings: [String]
    /// `category_score` rows of the week in the file (v9).
    public var categoryGrades: Int
    /// `goal_score` rows of the week in the file (v9).
    public var goalGrades: Int
    /// A week without item rows and marks (v9): nothing is created, filled or missed.
    public var isArchive: Bool

    public init(week: WeekKey, isNew: Bool = true, isReplaced: Bool = false, hasChanges: Bool = true, items: Int = 0, marks: Int = 0,
                excusedDays: [DayKey] = [], recordedScore: Double? = nil, closes: Bool = false, warnings: [String] = [],
                categoryGrades: Int = 0, goalGrades: Int = 0, isArchive: Bool = false) {
        self.week = week
        self.isNew = isNew
        self.isReplaced = isReplaced
        self.hasChanges = hasChanges
        self.items = items
        self.marks = marks
        self.excusedDays = excusedDays
        self.recordedScore = recordedScore
        self.closes = closes
        self.warnings = warnings
        self.categoryGrades = categoryGrades
        self.goalGrades = goalGrades
        self.isArchive = isArchive
    }

    /// "KW45 2026 (2.–8. Nov.)"
    public var title: String { "\(week.longLabel) (\(week.rangeLabel))" }

    /// "neu", "ersetzt", "ergänzt" or "unverändert".
    public var status: String {
        if isNew { return "neu" }
        if isReplaced { return "ersetzt" }
        return hasChanges ? "ergänzt" : "unverändert"
    }

    /// "24 Punkte · 96 Markierungen · 2 Tage Krank/Urlaub · Wertung 7,5 laut Unterlagen · wird abgeschlossen";
    /// an archive week: "12 Kategoriennoten · 10 Zielnoten · Wertung 9,28 laut Unterlagen".
    public var detail: String {
        var parts: [String] = []
        if items > 0 { parts.append(Format.count(items, "Punkt", "Punkte")) }
        if marks > 0 { parts.append(Format.count(marks, "Markierung", "Markierungen")) }
        if categoryGrades > 0 { parts.append(Format.count(categoryGrades, "Kategoriennote", "Kategoriennoten")) }
        if goalGrades > 0 { parts.append(Format.count(goalGrades, "Zielnote", "Zielnoten")) }
        if !excusedDays.isEmpty { parts.append(Format.count(excusedDays.count, "Tag", "Tage") + " Krank/Urlaub") }
        if let recordedScore { parts.append("Wertung \(Format.score(recordedScore)) \(ImportWeekSummary.recordedLabel)") }
        if closes { parts.append("wird abgeschlossen") }
        return parts.joined(separator: " · ")
    }

    /// How the week row's value is named everywhere (decision 5): "laut Unterlagen".
    public static let recordedLabel = "laut Unterlagen"
    /// The calculation under today's rules: "nach heutigen Regeln".
    public static let recalculatedLabel = "nach heutigen Regeln"
}

/// The preview shown before anything changes: per kind what is new, updated, unchanged – and which
/// items of a re-planned week the new plan no longer has.
public struct ImportPreview {
    public let document: PlanCSV.Document
    public let goals: ImportPlan<GoalRecord>
    public let categories: ImportPlan<CategoryRecord>
    public let weeks: ImportPlan<WeekRecord>
    public let days: ImportPlan<DayRecord>
    public let items: ImportPlan<ItemRecord>
    public let measures: ImportPlan<MeasureRecord>
    public let marks: ImportPlan<MarkRecord>
    public let entries: ImportPlan<EntryRecord>
    public let work: ImportPlan<WorkRecord>
    public let notes: ImportPlan<NoteRecord>
    public let reviews: ImportPlan<ReviewRecord>
    public let scores: ImportPlan<ScoreRecord>
    /// Item keys of re-planned weeks that the file no longer lists (moved to Recently Deleted).
    public let removedItems: [String]
    public let removedMeasures: [String]
    /// Weeks whose existing plan this file changes: the old week is archived with its marks and
    /// values, the new one replaces it (unchanged files replace nothing).
    public let replacedWeeks: [WeekKey]
    /// One per replaced week, with what goes to the archive (R49).
    public let replacements: [WeekReplacement]
    /// Closed days and weeks in the file that the app doesn't have closed yet (R27).
    public let newClosedDays: [DayKey]
    public let newClosedWeeks: [WeekKey]
    /// One per week of the file, oldest first (v8, preview of past weeks).
    public let weekSummaries: [ImportWeekSummary]
    /// Category and goal grades (v9), by their key.
    public let grades: ImportPlan<ArchiveGrade>
    /// "Archivdaten dieser Wochen ersetzen" (v9): the weeks whose data in the app goes to the archive
    /// completely before the import (`ExistingState.clearing`) – only weeks the app has something
    /// for. They are part of `replacedWeeks` and `replacements` too.
    public let replacingWeeks: [WeekKey]
    /// The archive (grades and source of the week's value) every touched week has after the import –
    /// only weeks where it changes; an empty one means: remove the setting. Stored grades are updated
    /// by key; a week in `replacingWeeks` has only the file's.
    public let archiveUpdates: [WeekKey: ArchiveWeek]
    /// v10 records of a backup (`record` rows) by key: a stored record with a newer `modifiedAt` stays
    /// (counts as unchanged).
    public let records: ImportPlan<SettingRow>

    /// - Parameter replacing: "Archivdaten dieser Wochen ersetzen" – weeks whose data in the app goes to
    ///   the archive first; the preview compares the file with the app as it is afterwards. Weeks the
    ///   app has nothing for are simply new. (`ImportPreview.pastWeeks` picks them: past weeks only.)
    public init(document file: PlanCSV.Document, existing original: ExistingState, replacing: Set<WeekKey> = []) {
        let replacingSet = replacing.filter { original.hasArchiveContent($0) }
        let existing = original.clearing(replacingSet)
        // v10: a measure the file gives no source keeps the one it has (this week or the week before).
        let document = ImportPreview.keepingSources(file, existing: existing)
        self.document = document
        records = ImportPlan(incoming: document.records.map { row -> (key: String, record: SettingRow) in
            (row.key, SettingRow.resolved(row, over: existing.records[row.key]))
        }, existing: existing.records)
        replacingWeeks = replacingSet.sorted()
        grades = ImportPlan(incoming: document.grades.map { ($0.key, $0) }, existing: existing.gradeRecords)
        // The week row's note is kept as the source only where it names one: for a week value or grades.
        // A note on another week row (a plan) creates no archive.
        let sourced = Set(document.weeks.filter { $0.recordedScore != nil }.map(\.week)).union(document.grades.map(\.week))
        var updates: [WeekKey: ArchiveWeek] = [:]
        for week in sourced.intersection(document.weekNotes.keys).union(document.grades.map(\.week)).union(replacingSet) {
            let stored = existing.archiveGrades[week] ?? ArchiveWeek(week: week)
            let source = sourced.contains(week) ? document.weekNotes[week] : nil
            let after = stored.merging(document.grades.filter { $0.week == week }, source: source)
            let before = original.archiveGrades[week] ?? ArchiveWeek(week: week)
            if after != before { updates[week] = after }
        }
        archiveUpdates = updates
        goals = ImportPlan(incoming: document.goals.map { ($0.key, $0) }, existing: existing.goals)
        categories = ImportPlan(incoming: document.categories.map { ($0.key, $0) }, existing: existing.categories)
        weeks = ImportPlan(incoming: document.weeks.map { ($0.week.string, $0) }, existing: existing.weeks)
        days = ImportPlan(incoming: document.days.map { ($0.day.string, $0) }, existing: existing.days)
        items = ImportPlan(incoming: document.items.map { ($0.key, $0) }, existing: existing.items)
        measures = ImportPlan(incoming: document.measures.map { ($0.key, $0) }, existing: existing.measures)
        marks = ImportPlan(incoming: document.marks.map { ($0.key, $0) }, existing: existing.marks)
        entries = ImportPlan(incoming: document.entries.map { entry in
            var normalized = entry
            normalized.order = 0
            return (entry.key, normalized)
        }, existing: ImportPreview.comparableEntries(document.entries, existing: existing.entries))
        work = ImportPlan(incoming: document.work.map { ($0.id, $0) }, existing: existing.work)
        notes = ImportPlan(incoming: document.notes.map { ($0.id, $0) }, existing: existing.notes)
        reviews = ImportPlan(incoming: document.reviews.map { ($0.key, $0) }, existing: existing.reviews)
        scores = ImportPlan(incoming: document.scores.map { ($0.key, $0) }, existing: existing.scores)

        let incomingItems = Set(document.items.map(\.key))
        removedItems = existing.items.values
            .filter { document.plannedWeeks.contains($0.week) && !incomingItems.contains($0.key) }
            .map(\.key).sorted()
        let incomingMeasures = Set(document.measures.map(\.key))
        removedMeasures = existing.measures.values
            .filter { document.measuredWeeks.contains($0.week) && !incomingMeasures.contains($0.key) }
            .map(\.key).sorted()

        var replaced: [WeekKey] = []
        for week in document.plannedWeeks.union(document.measuredWeeks).sorted() {
            guard existing.items.values.contains(where: { $0.week == week }) else { continue }
            let prefix = week.string + "|"
            let changed = items.entries.contains { $0.key.hasPrefix(prefix) && $0.action != .unchanged }
                || measures.entries.contains { $0.key.hasPrefix(prefix) && $0.action != .unchanged }
                || removedItems.contains { $0.hasPrefix(prefix) } || removedMeasures.contains { $0.hasPrefix(prefix) }
            if changed { replaced.append(week) }
        }
        var allReplacements = replaced.map { week in
            WeekReplacement(week: week,
                            marks: existing.marks.values.filter { $0.week == week && $0.mark != nil }.count,
                            values: existing.entries.values.filter { week.contains($0.day) }.count)
        }
        for week in replacingSet.subtracting(replaced) {
            allReplacements.append(WeekReplacement(
                archiveOf: week, items: original.items.values.filter { $0.week == week }.count,
                marks: original.marks.values.filter { $0.week == week && $0.mark != nil }.count,
                values: original.entries.values.filter { week.contains($0.day) }.count,
                grades: original.archiveGrades[week]?.grades.count ?? 0,
                hasScore: original.weeks[week.string]?.recordedScore != nil))
        }
        replacements = allReplacements.sorted { $0.week < $1.week }
        replacedWeeks = replacements.map(\.week)
        newClosedDays = document.closedDays.subtracting(existing.closedDays).sorted()
        newClosedWeeks = document.closedWeeks.subtracting(existing.closedWeeks).sorted()
        weekSummaries = ImportPreview.summaries(document: document, existing: existing, original: original, items: items, marks: marks,
                                                days: days, weeks: weeks, grades: grades, archiveUpdates: updates,
                                                replaced: Set(replacedWeeks), newClosedWeeks: Set(newClosedWeeks))
    }

    /// Every week the file touches (week rows, items, measurements, marks, day rows, grades), each with
    /// what comes in. `existing` is the app as the import finds it (after "Archivdaten ersetzen"),
    /// `original` as it is now.
    static func summaries(document: PlanCSV.Document, existing: ExistingState, original: ExistingState, items: ImportPlan<ItemRecord>,
                          marks: ImportPlan<MarkRecord>, days: ImportPlan<DayRecord>, weeks: ImportPlan<WeekRecord>,
                          grades: ImportPlan<ArchiveGrade>, archiveUpdates: [WeekKey: ArchiveWeek],
                          replaced: Set<WeekKey>, newClosedWeeks: Set<WeekKey>) -> [ImportWeekSummary] {
        let archiveWeeks = document.archiveWeeks
        return document.fileWeeks.sorted().map { week in
            let prefix = week.string + "|"
            let isNew = original.weeks[week.string] == nil && !original.items.values.contains { $0.week == week }
                && original.archiveGrades[week]?.isEmpty != false
            let changed = items.entries.contains { $0.key.hasPrefix(prefix) && $0.action != .unchanged }
                || marks.entries.contains { $0.key.hasPrefix(prefix) && $0.action != .unchanged }
                || days.entries.contains { week.contains($0.record.day) && $0.action != .unchanged }
                || weeks.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || grades.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || archiveUpdates[week] != nil || replaced.contains(week) || newClosedWeeks.contains(week)
            let excused = document.days.filter { week.contains($0.day) && DayTypes.isExcused($0.dayType) }.map(\.day).sorted()
            let warnings = document.warnings.filter { $0.hasPrefix(week.label + ":") || $0.hasPrefix(week.label + " ") }
            let weekGrades = document.grades.filter { $0.week == week }
            return ImportWeekSummary(
                week: week, isNew: isNew, isReplaced: replaced.contains(week), hasChanges: changed,
                items: document.items.filter { $0.week == week }.count,
                marks: document.marks.filter { $0.week == week && $0.mark != nil }.count,
                excusedDays: excused, recordedScore: document.weeks.first { $0.week == week }?.recordedScore,
                closes: newClosedWeeks.contains(week), warnings: warnings,
                categoryGrades: weekGrades.filter { $0.kind == .category }.count,
                goalGrades: weekGrades.filter { $0.kind == .goal }.count,
                isArchive: archiveWeeks.contains(week)
            )
        }
    }

    /// The app's entries prepared for comparing with the file (R27, backwards compatible): against a
    /// row without single entries (older backup, ChatGPT CSV) only the day's total counts – an old
    /// file never merges three single spendings into one; with the same single entries, value, note
    /// and estimate follow from them.
    static func comparableEntries(_ incoming: [EntryRecord], existing: [String: EntryRecord]) -> [String: EntryRecord] {
        var result = existing
        for entry in incoming {
            guard var current = result[entry.key] else { continue }
            if entry.parts.isEmpty {
                current.parts = []
                // A total written with four decimals is the same total.
                if same(current.value, entry.value) { current.value = entry.value }
            } else if partsMatch(current.parts, entry.parts) {
                current.parts = entry.parts
                current.value = entry.value
                current.note = entry.note
                current.estimate = entry.estimate
                current.text = entry.text
            }
            current.order = 0
            result[entry.key] = current
        }
        return result
    }

    static func same(_ a: Double?, _ b: Double?) -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return abs(a - b) < 1e-6
    }

    static func partsMatch(_ a: [EntryPart], _ b: [EntryPart]) -> Bool {
        guard a.count == b.count else { return false }
        let left = a.sorted { $0.minutes < $1.minutes }
        let right = b.sorted { $0.minutes < $1.minutes }
        return zip(left, right).allSatisfy { x, y in
            x.minutes == y.minutes && x.note == y.note && x.estimate == y.estimate && same(x.value, y.value)
        }
    }

    /// `replacing`: as for `init(document:existing:replacing:)` – e.g. restoring an archive snapshot of
    /// an archive week, so the grades imported since don't stay merged in.
    public init(text: String, existing: ExistingState, replacing: Set<WeekKey> = []) {
        self.init(document: PlanCSV.parse(text, knownCategories: existing.categoryTitles, knownMeasures: existing.measureCodes,
                                          knownItems: existing.itemKeys, knownGoals: Set(existing.goals.keys)),
                  existing: existing, replacing: replacing)
    }

    var counts: [(String, Int, Int, Int)] {
        [
            ("Jahresziele", goals.creates, goals.updates, goals.unchanged),
            ("Kategorien", categories.creates, categories.updates, categories.unchanged),
            ("Wochen", weeks.creates, weeks.updates, weeks.unchanged),
            ("Tage", days.creates, days.updates, days.unchanged),
            ("Punkte", items.creates, items.updates, items.unchanged),
            ("Messwerte", measures.creates, measures.updates, measures.unchanged),
            ("Markierungen", marks.creates, marks.updates, marks.unchanged),
            ("Erfasste Werte", entries.creates, entries.updates, entries.unchanged),
            ("Arbeitsblöcke", work.creates, work.updates, work.unchanged),
            ("Notizen", notes.creates, notes.updates, notes.unchanged),
            ("Reflexionen", reviews.creates, reviews.updates, reviews.unchanged),
            ("Eigene Wertungen", scores.creates, scores.updates, scores.unchanged),
            gradeCounts(.category),
            gradeCounts(.goal),
            ("Datensätze", records.creates, records.updates, records.unchanged),
        ]
    }

    /// ("Kategoriennoten", new, changed, same) – the grades of one kind (v9).
    func gradeCounts(_ kind: ArchiveGrade.Kind) -> (String, Int, Int, Int) {
        let entries = grades.entries.filter { $0.record.kind == kind }
        return (kind.plural, entries.filter { $0.action == .create }.count, entries.filter { $0.action == .update }.count,
                entries.filter { $0.action == .unchanged }.count)
    }

    /// One line per kind that the file contains: "Punkte: 180 neu · 0 geändert · 0 gleich".
    public var lines: [String] {
        var result = counts.filter { $0.1 + $0.2 + $0.3 > 0 }.map { name, new, changed, same in
            "\(name): \(new) neu · \(changed) geändert · \(same) gleich"
        }
        result.append(contentsOf: replacements.map(\.text))
        if replacedWeeks.isEmpty {
            if !removedItems.isEmpty { result.append("Punkte entfallen: \(removedItems.count)") }
            if !removedMeasures.isEmpty { result.append("Messwerte entfallen: \(removedMeasures.count)") }
        }
        if let closings = closingsLine { result.append(closings) }
        return result
    }

    /// "Abschlüsse: 3 Tage, 1 Woche" – closings the app doesn't have yet.
    var closingsLine: String? {
        var parts: [String] = []
        if !newClosedDays.isEmpty { parts.append(Format.count(newClosedDays.count, "Tag", "Tage")) }
        if !newClosedWeeks.isEmpty { parts.append(Format.count(newClosedWeeks.count, "Woche", "Wochen")) }
        return parts.isEmpty ? nil : "Abschlüsse: " + parts.joined(separator: ", ")
    }

    public var hasChanges: Bool {
        counts.contains { $0.1 + $0.2 > 0 } || !removedItems.isEmpty || !removedMeasures.isEmpty || !replacedWeeks.isEmpty
            || !newClosedDays.isEmpty || !newClosedWeeks.isEmpty || !archiveUpdates.isEmpty
    }

    /// "KW45 2026 (2.–8. Nov.): 180 Punkte in 18 Kategorien · 22 Messwerte"
    public var headline: String {
        let weeks = document.plannedWeeks.union(document.measuredWeeks).union(document.weeks.map(\.week))
            .union(document.grades.map(\.week)).sorted()
        guard !weeks.isEmpty else {
            return document.isEmpty ? "Keine lesbaren Zeilen" : "\(document.rowCount) Zeilen"
        }
        return weeks.map { week in
            let items = document.items.filter { $0.week == week }
            let categories = Set(items.map(\.categoryKey)).count
            let measures = document.measures.filter { $0.week == week }.count
            let grades = document.grades.filter { $0.week == week }.count
            var parts: [String] = []
            if !items.isEmpty { parts.append("\(items.count) Punkte in \(categories) Kategorien") }
            if measures > 0 { parts.append("\(measures) Messwerte") }
            if grades > 0 { parts.append(Format.count(grades, "Note", "Noten")) }
            if let recorded = document.weeks.first(where: { $0.week == week })?.recordedScore {
                parts.append("Wertung \(Format.score(recorded)) \(ImportWeekSummary.recordedLabel)")
            }
            return "\(week.longLabel) (\(week.rangeLabel))" + (parts.isEmpty ? "" : ": " + parts.joined(separator: " · "))
        }.joined(separator: "\n")
    }

    /// v10 (§1.5.4): links stay over the weeks – a measure without a source in the file keeps the source
    /// the app has for its code (this week, else the nearest earlier week), with one hint per week in
    /// the warnings ("KW48: bisherige Quelle übernommen …").
    static func keepingSources(_ document: PlanCSV.Document, existing: ExistingState) -> PlanCSV.Document {
        guard document.measures.contains(where: { $0.source == .manual }) else { return document }
        var byCode: [String: [MeasureRecord]] = [:]
        for measure in existing.measures.values { byCode[measure.code, default: []].append(measure) }
        guard !byCode.isEmpty else { return document }
        var doc = document
        var kept: [WeekKey: [String]] = [:]
        for index in doc.measures.indices where doc.measures[index].source == .manual {
            let measure = doc.measures[index]
            // The app's own measure of the week, else the nearest earlier week's – a manual one stays manual.
            guard let previous = byCode[measure.code]?.filter({ $0.week <= measure.week }).max(by: { $0.week < $1.week }),
                  previous.source != .manual else { continue }
            doc.measures[index].source = previous.source
            let from = previous.week == measure.week ? "" : ", aus \(previous.week.label)"
            kept[measure.week, default: []].append("\u{201E}\(measure.title)\u{201C} (\(previous.source.raw)\(from))")
        }
        for week in kept.keys.sorted() {
            let hint = "\(week.label): bisherige Quelle übernommen, die Datei nennt keine – " + (kept[week] ?? []).joined(separator: ", ")
            if !doc.warnings.contains(hint) { doc.warnings.append(hint) }
        }
        return doc
    }

    /// The week a plan import is about (to jump there afterwards).
    public var primaryWeek: WeekKey? {
        document.plannedWeeks.sorted().last ?? document.weeks.map(\.week).sorted().last
    }
}

// MARK: Past weeks against the app's state (v8, decision 8)

extension PlanCSV.Document {
    /// `closingPast` looks at the file alone. A week the import closes (the app has it open) also
    /// closes the days the app already has a mark or a day type for, so a file with only some days
    /// leaves no marked day open. Not counted: marks of a week the file replaces (they go to the
    /// archive), marks the file sets itself, and the day type of a day the file has a day row for.
    public func closingKnownDays(existing: ExistingState) -> PlanCSV.Document {
        let weeks = closedWeeks.subtracting(existing.closedWeeks)
        guard !weeks.isEmpty else { return self }
        let fileDays = Set(days.map(\.day))
        var known: Set<DayKey> = []
        for record in existing.days.values where weeks.contains(record.day.week) && !fileDays.contains(record.day) {
            if !record.dayType.trimmingCharacters(in: .whitespaces).isEmpty { known.insert(record.day) }
        }
        let fileMarks = Set(marks.map(\.key))
        var kept = existing.marks.values.filter { mark in
            mark.mark != nil && weeks.contains(mark.week) && mark.week.contains(mark.day) && !fileMarks.contains(mark.key)
        }
        let planned = plannedWeeks.union(measuredWeeks)
        if kept.contains(where: { planned.contains($0.week) }) {
            let replaced = Set(ImportPreview(document: self, existing: existing).replacedWeeks)
            kept = kept.filter { !replaced.contains($0.week) }
        }
        known.formUnion(kept.map(\.day))
        guard !known.isSubset(of: closedDays) else { return self }
        var result = self
        result.closedDays.formUnion(known)
        return result
    }

    /// Blank fields of the past weeks the file brings items or marks for, filled with ✗ – fixed,
    /// required items on their days, never on free or excused days (`fillingBlanks`). A week without
    /// item rows is filled on the app's plan and day types; marks the app already has are kept, unless
    /// the file replaces the week (then they go to the archive anyway).
    public func fillingPastBlanks(existing: ExistingState, today: DayKey) -> PlanCSV.Document {
        // Only weeks with item rows or marks: archive weeks (v9) have neither, so they are never filled –
        // not even on the app's plan.
        let weeks = plannedWeeks.union(marks.map(\.week)).filter { $0 < today.week }
        guard !weeks.isEmpty else { return self }
        let replaced = Set(ImportPreview(document: self, existing: existing).replacedWeeks)
        let typedDays = Set(days.map(\.day))
        let fileMarks = Set(marks.map(\.key))
        var probe = self
        for week in weeks {
            if !plannedWeeks.contains(week) {
                probe.items += existing.items.values.filter { $0.week == week }
            }
            probe.days += existing.days.values.filter { week.contains($0.day) && !typedDays.contains($0.day) }
        }
        let kept = existing.marks.values.filter { mark in
            weeks.contains(mark.week) && !replaced.contains(mark.week) && mark.mark != nil && !fileMarks.contains(mark.key)
        }
        probe.marks += kept
        let keptKeys = Set(kept.map(\.key))
        var result = self
        result.marks = probe.fillingBlanks(weeks: weeks, with: .missed).marks.filter { !keptKeys.contains($0.key) }
        return result
    }
}

// MARK: Path b in one (v8 decision 8, v9 decisions 1 and 2)

extension ImportPreview {
    /// The preview of "Mit ChatGPT" in "Vergangene Woche nachtragen": blank fields as ✗ when asked
    /// (never in archive weeks), past weeks closed with their days (also those the app has marks or
    /// day types for), and – with "Archivdaten dieser Wochen ersetzen" – every past week with a `week`
    /// row in the file that the app has something for goes to the archive first and comes from the
    /// file anew (unless the file brings exactly what the app has: then nothing is replaced). The
    /// current week and later ones are never replaced and get no week value (a warning; the rest is
    /// imported as usual).
    /// The file's week rows keep the app's motto and context when they have none (the prompt never
    /// writes them), and – where the week isn't replaced – the value laut Unterlagen when the file has
    /// none or an unreadable one. Measurement rows of archive weeks are dropped (decision 1). Without
    /// the switch, an archive week that still has items in the app gets a warning.
    /// `document`: the parsed file (`PlanCSV.parse` with the app's categories, measurements, items, goals).
    public static func pastWeeks(_ document: PlanCSV.Document, existing: ExistingState, blanksAsMissed: Bool = false,
                                 replacingArchives: Bool = false, today: DayKey) -> ImportPreview {
        var doc = document
        let current = today.week
        // Decision 1: an archive week never gets measurements – no weekly target that nothing can meet.
        let archive = doc.archiveWeeks
        let dropped = doc.measures.filter { archive.contains($0.week) }
        if !dropped.isEmpty {
            doc.measures.removeAll { archive.contains($0.week) }
            doc.measuredWeeks.subtract(archive)
            for week in Set(dropped.map(\.week)).sorted() {
                let names = dropped.filter { $0.week == week }.map { "\u{201E}\($0.title)\u{201C}" }
                let noun = names.count == 1 ? "Messwert" : "Messwerte"
                doc.warnings.append("\(week.label): \(noun) \(names.joined(separator: ", ")) nicht übernommen – eine Woche ohne Punkte bekommt keine Messwerte.")
            }
        }
        // A running week has no value laut Unterlagen: it would replace its own score everywhere.
        for index in doc.weeks.indices where doc.weeks[index].week >= current && doc.weeks[index].recordedScore != nil {
            doc.warnings.append("\(doc.weeks[index].week.label): noch nicht vorbei – der Wochenwert wird nicht übernommen.")
            doc.weeks[index].recordedScore = nil
        }
        var replacing: Set<WeekKey> = []
        if replacingArchives {
            // Only weeks with a week row: a stray day row or grade never replaces a week (decision 2).
            let weeks = Set(doc.weeks.map(\.week))
            replacing = weeks.filter { $0 < current && existing.hasArchiveContent($0) }
            for week in weeks.filter({ $0 >= current }).sorted() {
                doc.warnings.append("\(week.label): noch nicht vorbei – wird nicht ersetzt, nur ergänzt.")
            }
        }
        var prepared = ImportPreview.prepared(doc, existing: existing, replacing: replacing, blanksAsMissed: blanksAsMissed,
                                              today: today)
        // The same file twice with the switch: a week the file brings exactly as the app has it isn't
        // replaced again (no second, identical snapshot in the archive).
        let unchanged = ImportPreview.unchangedByReplacing(replacing, document: prepared, existing: existing)
        if !unchanged.isEmpty {
            replacing.subtract(unchanged)
            prepared = ImportPreview.prepared(doc, existing: existing, replacing: replacing, blanksAsMissed: blanksAsMissed,
                                              today: today)
        }
        doc = prepared
        for week in doc.archiveWeeks.subtracting(replacing).sorted() where week < current {
            let count = existing.items.values.filter { $0.week == week }.count
            guard count > 0 else { continue }
            let marked = existing.marks.values.filter { $0.week == week && $0.mark != nil }.count
            let items = Format.count(count, "Punkt", "Punkte")
            let warning: String
            if marked == 0 {
                warning = "\(week.label): in der App noch \(items) ohne Markierungen – \u{201A}Archivdaten ersetzen\u{2018} entfernt \(count == 1 ? "ihn" : "sie")."
            } else {
                let source = count == 1 ? "er aus einem fehlerhaften Import stammt" : "sie aus einem fehlerhaften Import stammen"
                warning = "\(week.label): in der App noch \(items) mit \(Format.count(marked, "Markierung", "Markierungen")) – "
                    + "\u{201A}Archivdaten ersetzen\u{2018} nur wählen, wenn \(source); es verschiebt alles ins Archiv."
            }
            if !doc.warnings.contains(warning) { doc.warnings.append(warning) }
        }
        let fileMarks = Set(doc.marks.filter { $0.mark != nil }.map(\.week))
        for week in replacing.sorted() where !doc.plannedWeeks.contains(week) && !fileMarks.contains(week) {
            let marked = existing.marks.values.filter { $0.week == week && $0.mark != nil }.count
            guard marked > 0 else { continue }
            let verb = marked == 1 ? "geht" : "gehen"
            doc.warnings.append("\(week.label): \(Format.count(marked, "Markierung", "Markierungen")) aus der App \(verb) ins Archiv – die Datei bringt keine Einzelhaken.")
        }
        // Decision 5: a week with items is scored by them; its grades stay in the archive and don't count.
        let graded = Set(doc.grades.map(\.week))
        for week in doc.plannedWeeks.intersection(graded).sorted() {
            doc.warnings.append("\(week.label): Punkte und Noten – nach heutigen Regeln zählen nur die Punkte, die Noten stehen im Archiv.")
        }
        return ImportPreview(document: doc, existing: existing, replacing: replacing)
    }

    /// The file's week rows against the app (`pastWeeks`): an empty motto and context keep the app's,
    /// a week that isn't replaced keeps its value laut Unterlagen when the file has none (and a running
    /// week always keeps the app's), then blank fields as ✗ and the closings – against the app as it is
    /// once `replacing` went to the archive.
    static func prepared(_ document: PlanCSV.Document, existing: ExistingState, replacing: Set<WeekKey>, blanksAsMissed: Bool,
                         today: DayKey) -> PlanCSV.Document {
        var doc = document
        for index in doc.weeks.indices {
            var record = doc.weeks[index]
            guard let stored = existing.weeks[record.week.string] else { continue }
            if record.title.isEmpty { record.title = stored.title }
            if record.details.isEmpty { record.details = stored.details }
            if record.week >= today.week || (record.recordedScore == nil && !replacing.contains(record.week)) {
                record.recordedScore = stored.recordedScore
            }
            doc.weeks[index] = record
        }
        let base = existing.clearing(replacing)
        if blanksAsMissed { doc = doc.fillingPastBlanks(existing: base, today: today) }
        return doc.closingPast(today: today).closingKnownDays(existing: base)
    }

    /// The weeks of `weeks` that "Archivdaten ersetzen" would leave as they are: every row of the file
    /// for the week is unchanged against the app, and the app has nothing more for it (items,
    /// measurements, marks, values, own scores, day types, closings, grades).
    static func unchangedByReplacing(_ weeks: Set<WeekKey>, document: PlanCSV.Document, existing: ExistingState) -> Set<WeekKey> {
        guard !weeks.isEmpty else { return [] }
        let plain = ImportPreview(document: document, existing: existing)
        return weeks.filter { week in
            func days(_ day: DayKey) -> Bool { week.contains(day) }
            let changed = plain.items.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || plain.measures.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || plain.marks.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || plain.entries.entries.contains { days($0.record.day) && $0.action != .unchanged }
                || plain.scores.entries.contains { days($0.record.day) && $0.action != .unchanged }
                || plain.days.entries.contains { days($0.record.day) && $0.action != .unchanged }
                || plain.weeks.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || plain.grades.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || plain.archiveUpdates[week] != nil || plain.replacedWeeks.contains(week)
                || plain.newClosedWeeks.contains(week) || plain.newClosedDays.contains(where: days)
            guard !changed else { return false }
            // Nothing in the app beyond what the file brings.
            let same = existing.items.values.filter { $0.week == week }.count == document.items.filter { $0.week == week }.count
                && existing.measures.values.filter { $0.week == week }.count == document.measures.filter { $0.week == week }.count
                && existing.marks.values.filter { $0.week == week && $0.mark != nil }.count
                    == document.marks.filter { $0.week == week && $0.mark != nil }.count
                && existing.entries.values.filter { days($0.day) }.count == document.entries.filter { days($0.day) }.count
                && existing.scores.values.filter { days($0.day) }.count == document.scores.filter { days($0.day) }.count
                && existing.days.values.filter { days($0.day) && (!$0.dayType.isEmpty || !$0.note.isEmpty) }.count
                    == document.days.filter { days($0.day) }.count
                && (existing.archiveGrades[week]?.grades.count ?? 0) == document.grades.filter { $0.week == week }.count
                && existing.closedDays.filter(days).isSubset(of: document.closedDays)
                && (!existing.closedWeeks.contains(week) || document.closedWeeks.contains(week))
            return same
        }
    }
}
