import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

/// Everything about one week, read once and scored once: the screens (through `WeekReader`), the
/// widget snapshot, the report and the watch all use this, so every place counts the same way.
struct WeekContext {
    let week: WeekKey
    let today: DayKey
    let plan: WeekPlan?
    let goals: [AnnualGoal]
    let categories: [TrackCategory]
    let items: [PlanItem]
    let measures: [MeasureDefinition]
    /// Latest mark per `"<itemCode>|<day>"`.
    let marks: [String: ItemMark]
    let days: [String: PlanDay]
    let entries: [MeasureEntry]
    let health: [HealthValue]
    let work: [WorkBlock]
    let notes: [DayNote]
    /// By `"<categoryKey>|<day>"`.
    let overrides: [String: ScoreOverride]
    /// By `"<scope>|<field>"`.
    let reflections: [String: Reflection]
    /// Changes made in the app this week (the next prompt lists them).
    let changes: [PlanChange]

    let entryRecords: [EntryRecord]
    let workRecords: [WorkRecord]
    let data: WeekData
    let score: WeekScore

    init(week: WeekKey, today: DayKey, plans: [WeekPlan], goals: [AnnualGoal], categories: [TrackCategory], items: [PlanItem],
         measures: [MeasureDefinition], marks: [ItemMark], days: [PlanDay], entries: [MeasureEntry], health: [HealthValue],
         work: [WorkBlock], notes: [DayNote], overrides: [ScoreOverride], reflections: [Reflection], changes: [PlanChange] = []) {
        self.week = week
        self.today = today
        let weekString = week.string
        self.plan = plans.filter { $0.weekKey == weekString && $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)[weekString]
        self.goals = Array(goals.filter { $0.deletedAt == nil }.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { (Int($0.key) ?? 99, $0.key) < (Int($1.key) ?? 99, $1.key) }
        self.categories = Array(categories.filter { $0.deletedAt == nil }.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
        self.items = Array(items.filter { $0.weekKey == weekString && $0.deletedAt == nil }.latest(by: \.code, modified: \.modifiedAt).values)
            .sorted {
                let a = CategoryRecord.sortKey($0.categoryKey)
                let b = CategoryRecord.sortKey($1.categoryKey)
                return a != b ? a.lexicographicallyPrecedes(b) : ($0.position, $0.code) < ($1.position, $1.code)
            }
        self.measures = Array(measures.filter { $0.weekKey == weekString && $0.deletedAt == nil }.latest(by: \.code, modified: \.modifiedAt).values)
            .sorted { ($0.position, $0.code) < ($1.position, $1.code) }
        self.marks = marks.filter { $0.weekKey == weekString }.latest(by: \.key, modified: \.modifiedAt)
        self.days = days.latest(by: \.dayKey, modified: \.modifiedAt)
        let dayStrings = Set(week.days.map(\.string))
        self.entries = entries.filter { $0.deletedAt == nil && dayStrings.contains($0.dayKey) }
        self.health = health.filter { dayStrings.contains($0.dayKey) }
        self.work = work.filter { $0.deletedAt == nil && dayStrings.contains($0.dayKey) }
            .sorted { $0.createdAt < $1.createdAt }
        self.notes = notes.filter { $0.deletedAt == nil && dayStrings.contains($0.dayKey) }.sorted { $0.createdAt < $1.createdAt }
        self.overrides = overrides.filter { $0.deletedAt == nil && dayStrings.contains($0.dayKey) }.latest(by: \.key, modified: \.modifiedAt)
        self.reflections = reflections.latest(by: \.key, modified: \.modifiedAt)
        self.changes = changes.filter { $0.weekKey == weekString }.sorted { $0.createdAt < $1.createdAt }

        // Confirmed Health values count like entries, but only where no own value exists that day.
        var records = self.entries.compactMap(\.record)
        let own = Set(records.map(\.key))
        records += self.health.compactMap(\.record).filter { !own.contains($0.key) }
        entryRecords = records
        workRecords = self.work.compactMap(\.record)

        var markValues: [String: Mark] = [:]
        for (key, mark) in self.marks { if let value = mark.mark { markValues[key] = value } }
        var overrideValues: [String: Double] = [:]
        for (key, override) in self.overrides { overrideValues[key] = override.score }
        let isComplete = Scorer.isComplete(week: week, today: today, closed: self.plan?.isClosed ?? false)
        let itemRecords = self.items.compactMap(\.record)
        let measureRecords = self.measures.compactMap(\.record)
        var progress: [String: Double] = [:]
        var worked: [String: Set<DayKey>] = [:]
        for item in itemRecords where item.schedule == .progress {
            progress[item.code] = Measures.progressRatio(for: item, measures: measureRecords, days: week.days,
                                                         entries: records, work: workRecords)
            worked[item.code] = Measures.workedDays(for: item, measures: measureRecords, days: week.days,
                                                    entries: records, work: workRecords)
        }
        let dayInfo = self.days
        let free = Set(week.days.filter { DayTypes.isWorkFree(dayInfo[$0.string]?.dayType ?? "") })
        data = WeekData(week: week, goals: self.goals.map(\.record), categories: self.categories.map(\.record),
                        items: itemRecords, marks: markValues, overrides: overrideValues, isComplete: isComplete,
                        progress: progress, worked: worked, workFreeDays: free)
        score = Scorer.score(data)
    }

    var hasPlan: Bool { !items.isEmpty }
    var isClosed: Bool { plan?.isClosed ?? false }

    /// The mark that counts: derived for progress items, N/A for work-only items on free days.
    func mark(_ item: PlanItem, on day: DayKey) -> Mark? {
        guard let record = item.record else { return marks[WeekData.markKey(item.code, day)]?.mark }
        return data.mark(record, on: day)
    }

    /// The mark as recorded (for undo of bulk changes).
    func recordedMark(_ item: PlanItem, on day: DayKey) -> Mark? {
        marks[WeekData.markKey(item.code, day)]?.mark
    }

    /// Due that day (scheduled and not left out because the day is free).
    func applies(_ item: PlanItem, on day: DayKey) -> Bool {
        guard let record = item.record else { return item.days.contains(day.weekday) }
        return data.applies(record, on: day)
    }

    /// A measurement shown that day: scheduled, and on free days not a work-only one.
    func applies(_ measure: MeasureDefinition, on day: DayKey) -> Bool {
        guard measure.days.contains(day.weekday) else { return false }
        guard data.workFreeDays.contains(day), let record = measure.record else { return true }
        switch record.dayRule {
        case .workOnly: return false
        case .always: return true
        case .auto: return !(record.isWork || data.workCategories.contains(record.categoryKey))
        }
    }

    func isDerived(_ item: PlanItem) -> Bool { item.record.map { data.isDerived($0) } ?? false }
    func isFreeDay(_ day: DayKey) -> Bool { data.workFreeDays.contains(day) }

    /// n×/week item already done often enough on other days (folded away in the daily list).
    func isQuotaMetElsewhere(_ item: PlanItem, on day: DayKey) -> Bool {
        item.record.map { Scorer.isQuotaMetElsewhere($0, on: day, data: data) } ?? false
    }

    func markNote(_ item: PlanItem, on day: DayKey) -> String {
        marks[WeekData.markKey(item.code, day)]?.note ?? ""
    }

    func measure(code: String) -> MeasureDefinition? {
        measures.first { $0.code == code }
    }

    func dayValue(_ measure: MeasureDefinition, on day: DayKey) -> Double? {
        guard let record = measure.record else { return nil }
        return Measures.dayValue(record, on: day, entries: entryRecords, work: workRecords)
    }

    func weekValue(_ measure: MeasureDefinition) -> Double? {
        guard let record = measure.record else { return nil }
        return Measures.weekValue(record, days: week.days, entries: entryRecords, work: workRecords)
    }

    /// The mark a linked measurement suggests, when it differs from what's recorded.
    func suggestion(_ item: PlanItem, on day: DayKey) -> Mark? {
        guard !item.measureCode.isEmpty, let record = item.record, let measure = measure(code: item.measureCode) else { return nil }
        let suggested = Measures.suggestion(for: record, dayValue: dayValue(measure, on: day))
        return suggested == mark(item, on: day) ? nil : suggested
    }

    func info(_ day: DayKey) -> PlanDay? { days[day.string] }
    func isClosed(_ day: DayKey) -> Bool { info(day)?.isClosed ?? false }
    func dayType(_ day: DayKey) -> String { info(day)?.dayType ?? "" }

    func categories(of goal: AnnualGoal) -> [TrackCategory] {
        categories.filter { $0.goalKey == goal.key }
    }

    func items(in category: TrackCategory) -> [PlanItem] {
        items.filter { $0.categoryKey == category.key }
    }

    func goal(of category: TrackCategory) -> AnnualGoal? {
        goals.first { $0.key == category.goalKey }
    }

    func category(_ key: String) -> TrackCategory? {
        categories.first { $0.key == key }
    }

    /// Items that apply on a day (scheduled there, not left out on a free day); optional ones included.
    func items(on day: DayKey) -> [PlanItem] {
        items.filter { applies($0, on: day) }
    }

    func work(on day: DayKey) -> [WorkBlock] { work.filter { $0.dayKey == day.string } }
    func notes(on day: DayKey) -> [DayNote] { notes.filter { $0.dayKey == day.string } }

    func workTotals(on day: DayKey? = nil) -> WorkTotals {
        WorkTotals(day.map { d in workRecords.filter { $0.day == d } } ?? workRecords)
    }

    func reflection(scope: String, field: String) -> String {
        reflections["\(scope)|\(field)"]?.text ?? ""
    }

    /// Items due on a day without a mark yet (fixed schedule only – the rest can't be "missing").
    func blanks(on day: DayKey) -> [PlanItem] {
        items.filter { $0.schedule == .fixed && applies($0, on: day) && mark($0, on: day) == nil }
    }

    /// Conditional items not marked on a day (closing the day can set them to N/A).
    func openConditionals(on day: DayKey) -> [PlanItem] {
        items.filter { $0.schedule == .conditional && applies($0, on: day) && mark($0, on: day) == nil }
    }

    /// n×/week items still short of their quota (closing the day lists them for completeness).
    func openWeekly(on day: DayKey) -> [PlanItem] {
        items.filter { item in
            guard let quota = quotaProgress(item) else { return false }
            return applies(item, on: day) && quota.done < quota.target && mark(item, on: day) == nil
        }
    }

    /// Weekly progress of an item with a quota ("2 von 3").
    func quotaProgress(_ item: PlanItem) -> (done: Int, target: Int)? {
        guard let target = item.schedule.weeklyTarget else { return nil }
        let done = week.days.filter { mark(item, on: $0) == .done || mark(item, on: $0) == .partial }.count
        return (done, target)
    }

    func reportInput() -> WeekReportInput {
        let weekRecord = plan?.record ?? WeekRecord(week: week)
        return WeekReportInput(
            week: weekRecord, goals: data.goals, categories: data.categories, items: data.items,
            measures: measures.compactMap(\.record), marks: marks.values.compactMap(\.record),
            overrides: overrides.values.compactMap(\.record), days: days.values.compactMap(\.record),
            entries: entryRecords, work: workRecords, notes: notes.compactMap(\.record),
            reviews: reflections.values.map(\.record), changes: changes.compactMap(\.record),
            closedDays: Set(week.days.filter { isClosed($0) }), isClosed: isClosed, today: today
        )
    }

    /// Weekly progress of a progress item ("62 %"), nil when it has no target.
    func progress(_ item: PlanItem) -> Double? { data.progress[item.code] }

    /// The options a mark offers on a day (weekly items lose N/A when the quota needs the day, U18.3).
    func options(_ item: PlanItem, on day: DayKey) -> [Mark] {
        guard let record = item.record else { return Mark.allCases }
        return Scorer.options(for: record, on: day, data: data)
    }

    /// The widget / watch summary for `today`.
    func todaySummary() -> TodaySummary {
        let overall = score.days[today]
        let totals = workTotals(on: today)
        let lines: [TodaySummary.MeasureLine] = measures.filter { $0.record?.period == .day && $0.record?.target != nil }.prefix(4).map { measure in
            let value = dayValue(measure, on: today)
            let record = measure.record
            return TodaySummary.MeasureLine(
                title: measure.title,
                value: value.map { Format.measure($0, unit: measure.unit) } ?? "–",
                target: record?.target?.label ?? "",
                met: record.flatMap { Measures.isMet($0, value: value) }
            )
        }
        let closed = isClosed(today)
        let next = categories.first { score.category($0.key, on: today).blank > 0 }
        return TodaySummary(
            day: today.shortLabel, weekLabel: week.label, dayScore: closed ? overall?.score : nil, weekScore: score.overall,
            fill: overall?.coverage ?? 0, powerHours: totals.powerHours, isClosed: closed,
            nextCategory: next.map { "\($0.key) \($0.title)" }, measures: lines,
            goalScores: goals.map { score.goalWeek[$0.key]?.score }, goalTitles: goals.map(\.title), updatedAt: Date()
        )
    }
}
