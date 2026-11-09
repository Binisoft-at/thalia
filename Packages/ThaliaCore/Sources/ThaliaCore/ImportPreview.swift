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

    public init() {}

    public var categoryTitles: [String: String] { categories.mapValues(\.title) }
    public var measureCodes: Set<String> { Set(measures.values.map(\.code)) }
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
        }, existing: existing.entries)
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
    }

    public init(text: String, existing: ExistingState) {
        self.init(document: PlanCSV.parse(text, knownCategories: existing.categoryTitles, knownMeasures: existing.measureCodes),
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
        for week in replacedWeeks {
            result.append("\(week.label) ersetzt den bisherigen Plan – der alte wird mit Markierungen und Werten archiviert (Einstellungen → Archiv).")
        }
        if replacedWeeks.isEmpty {
            if !removedItems.isEmpty { result.append("Punkte entfallen: \(removedItems.count)") }
            if !removedMeasures.isEmpty { result.append("Messwerte entfallen: \(removedMeasures.count)") }
        }
        return result
    }

    public var hasChanges: Bool {
        counts.contains { $0.1 + $0.2 > 0 } || !removedItems.isEmpty || !removedMeasures.isEmpty || !replacedWeeks.isEmpty
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
