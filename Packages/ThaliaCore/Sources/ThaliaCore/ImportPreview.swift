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
    /// "KW47 wird ersetzt – 23 Markierungen und 9 Werte gehen ins Archiv."
    public var text: String
    /// "KW47 ersetzen"
    public var buttonTitle: String

    public init(week: WeekKey, marks: Int, values: Int) {
        self.week = week
        self.marks = marks
        self.values = values
        text = "\(week.label) wird ersetzt – \(Format.count(marks, "Markierung", "Markierungen")) und "
            + "\(Format.count(values, "Wert", "Werte")) gehen ins Archiv."
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

    public init(week: WeekKey, isNew: Bool = true, isReplaced: Bool = false, hasChanges: Bool = true, items: Int = 0, marks: Int = 0,
                excusedDays: [DayKey] = [], recordedScore: Double? = nil, closes: Bool = false, warnings: [String] = []) {
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
    }

    /// "KW45 2026 (2.–8. Nov.)"
    public var title: String { "\(week.longLabel) (\(week.rangeLabel))" }

    /// "neu", "ersetzt", "ergänzt" or "unverändert".
    public var status: String {
        if isNew { return "neu" }
        if isReplaced { return "ersetzt" }
        return hasChanges ? "ergänzt" : "unverändert"
    }

    /// "24 Punkte · 96 Markierungen · 2 Tage Krank/Urlaub · Wertung 7,5 · wird abgeschlossen"
    public var detail: String {
        var parts: [String] = []
        if items > 0 { parts.append(Format.count(items, "Punkt", "Punkte")) }
        if marks > 0 { parts.append(Format.count(marks, "Markierung", "Markierungen")) }
        if !excusedDays.isEmpty { parts.append(Format.count(excusedDays.count, "Tag", "Tage") + " Krank/Urlaub") }
        if let recordedScore { parts.append("Wertung \(Format.score(recordedScore))") }
        if closes { parts.append("wird abgeschlossen") }
        return parts.joined(separator: " · ")
    }
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

    public init(document: PlanCSV.Document, existing: ExistingState) {
        self.document = document
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
        replacedWeeks = replaced
        replacements = replaced.map { week in
            WeekReplacement(week: week,
                            marks: existing.marks.values.filter { $0.week == week && $0.mark != nil }.count,
                            values: existing.entries.values.filter { week.contains($0.day) }.count)
        }
        newClosedDays = document.closedDays.subtracting(existing.closedDays).sorted()
        newClosedWeeks = document.closedWeeks.subtracting(existing.closedWeeks).sorted()
        weekSummaries = ImportPreview.summaries(document: document, existing: existing, items: items, marks: marks, days: days,
                                                weeks: weeks, replaced: Set(replaced), newClosedWeeks: Set(newClosedWeeks))
    }

    /// Every week the file touches (week rows, items, measurements, marks, day rows), each with what comes in.
    static func summaries(document: PlanCSV.Document, existing: ExistingState, items: ImportPlan<ItemRecord>,
                          marks: ImportPlan<MarkRecord>, days: ImportPlan<DayRecord>, weeks: ImportPlan<WeekRecord>,
                          replaced: Set<WeekKey>, newClosedWeeks: Set<WeekKey>) -> [ImportWeekSummary] {
        var all = Set(document.weeks.map(\.week)).union(document.plannedWeeks).union(document.measuredWeeks)
        for mark in document.marks { all.insert(mark.week) }
        for day in document.days { all.insert(day.day.week) }
        return all.sorted().map { week in
            let prefix = week.string + "|"
            let isNew = existing.weeks[week.string] == nil && !existing.items.values.contains { $0.week == week }
            let changed = items.entries.contains { $0.key.hasPrefix(prefix) && $0.action != .unchanged }
                || marks.entries.contains { $0.key.hasPrefix(prefix) && $0.action != .unchanged }
                || days.entries.contains { week.contains($0.record.day) && $0.action != .unchanged }
                || weeks.entries.contains { $0.record.week == week && $0.action != .unchanged }
                || replaced.contains(week) || newClosedWeeks.contains(week)
            let excused = document.days.filter { week.contains($0.day) && DayTypes.isExcused($0.dayType) }.map(\.day).sorted()
            let warnings = document.warnings.filter { $0.hasPrefix(week.label + ":") || $0.hasPrefix(week.label + " ") }
            return ImportWeekSummary(
                week: week, isNew: isNew, isReplaced: replaced.contains(week), hasChanges: changed,
                items: document.items.filter { $0.week == week }.count,
                marks: document.marks.filter { $0.week == week && $0.mark != nil }.count,
                excusedDays: excused, recordedScore: document.weeks.first { $0.week == week }?.recordedScore,
                closes: newClosedWeeks.contains(week), warnings: warnings
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

    public init(text: String, existing: ExistingState) {
        self.init(document: PlanCSV.parse(text, knownCategories: existing.categoryTitles, knownMeasures: existing.measureCodes,
                                          knownItems: existing.itemKeys),
                  existing: existing)
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
        ]
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
            || !newClosedDays.isEmpty || !newClosedWeeks.isEmpty
    }

    /// "KW45 2026 (2.–8. Nov.): 180 Punkte in 18 Kategorien · 22 Messwerte"
    public var headline: String {
        let weeks = document.plannedWeeks.union(document.measuredWeeks).union(document.weeks.map(\.week)).sorted()
        guard !weeks.isEmpty else {
            return document.isEmpty ? "Keine lesbaren Zeilen" : "\(document.rowCount) Zeilen"
        }
        return weeks.map { week in
            let items = document.items.filter { $0.week == week }
            let categories = Set(items.map(\.categoryKey)).count
            let measures = document.measures.filter { $0.week == week }.count
            var parts: [String] = []
            if !items.isEmpty { parts.append("\(items.count) Punkte in \(categories) Kategorien") }
            if measures > 0 { parts.append("\(measures) Messwerte") }
            if let recorded = document.weeks.first(where: { $0.week == week })?.recordedScore {
                parts.append("Wertung \(Format.score(recorded))")
            }
            return "\(week.longLabel) (\(week.rangeLabel))" + (parts.isEmpty ? "" : ": " + parts.joined(separator: " · "))
        }.joined(separator: "\n")
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
