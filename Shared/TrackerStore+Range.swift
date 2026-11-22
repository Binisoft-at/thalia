import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

// v8: the report over several weeks ("PDF-Bericht"): which weeks it shows, each week read and
// scored once, and one line per week with the same score rule as the Rückblick (R70).

extension TrackerStore {
    /// The weeks from `start` through `end` that a report shows, oldest first: a plan with items, a
    /// stored or reported score (paper weeks), or archive grades (v9). Archived weeks (`WeekArchive`)
    /// never count.
    func rangeWeeks(from start: WeekKey, through end: WeekKey) -> [WeekKey] {
        guard start <= end else { return [] }
        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        let graded: Set<WeekKey> = Set(storedArchives().filter { $0.value.hasGrades }.keys)
        let weeks: [WeekKey] = plans.values.compactMap { plan -> WeekKey? in
            guard let week = plan.week, week >= start, week <= end else { return nil }
            if plan.historyScore != nil || graded.contains(week) { return week }
            return rangeHasItems(week) ? week : nil
        }
        return weeks.sorted()
    }

    /// Every week a report up to `end` can show (the "Von"/"Bis" choices), oldest first.
    func reportableWeeks(through end: WeekKey) -> [WeekKey] {
        rangeWeeks(from: WeekKey(year: 2000, week: 1), through: end)
    }

    /// The weeks of `rangeWeeks(from:through:)`, read and scored (paper weeks included).
    func weekContexts(from start: WeekKey, through end: WeekKey, today: DayKey = .today()) -> [WeekContext] {
        rangeWeeks(from: start, through: end).map { weekContext(for: $0, today: today) }
    }

    /// One week's line: the stored score of a closed or paper week wins (v9: the value "laut
    /// Unterlagen" first), else the running one – the same rule as the Rückblick. Goal scores: stored
    /// when the week was closed, else live; a week without items takes them from its archive grades
    /// (`WeekLine.isArchive` for "Archiv").
    func rangeLine(_ context: WeekContext) -> WeekLine {
        let stored: Double? = context.plan?.historyScore
        let goals: [String: Double] = context.plan?.finalGoalScoreMap ?? [:]
        return WeekLine(context.reportInput(), storedScore: stored, storedGoalScores: goals, archive: context.archive)
    }

    /// The report over already read weeks (the PDF sheet reads them one by one).
    func rangeReport(contexts: [WeekContext]) -> RangeReport {
        let goals: [GoalRecord] = liveGoals().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        let categories: [CategoryRecord] = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        let lines: [WeekLine] = contexts.map { rangeLine($0) }
        let work: [WorkRecord] = contexts.flatMap(\.workRecords)
        return RangeReport(lines: lines, goals: goals, work: work, categories: categories)
    }

    /// The report from `start` through `end`: one line per week, the averages, every goal's trend
    /// and the power-hours per area.
    func rangeReport(from start: WeekKey, through end: WeekKey) -> RangeReport {
        rangeReport(contexts: weekContexts(from: start, through: end))
    }

    /// Whether a week has at least one item (one indexed lookup).
    private func rangeHasItems(_ week: WeekKey) -> Bool {
        let key = week.string
        var descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        let found: [PlanItem] = (try? context.fetch(descriptor)) ?? []
        return !found.isEmpty
    }
}
