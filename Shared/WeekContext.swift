import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

/// Whether Thalia reads Apple Health on this device (H1): iPhone and iPad yes, Mac and Watch no.
enum HealthDevice {
    static var readsHealth: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
}

/// A weekly measurement with a target (R16, R47): the one list of weekly targets.
struct WeeklyTarget: Identifiable {
    let measure: MeasureDefinition
    /// The progress item that hangs on it, if any.
    let item: PlanItem?
    /// The week's value so far (0 without entries).
    let value: Double
    let target: Target
    let pace: Pace
    /// "PH" for work, else `Units.display(unit)`.
    let unit: String
    var id: String { measure.code }
    /// Limits: while below; targets: reached.
    var isMet: Bool { target.isMet(value) }
}

/// R12: a suggestion from a measurement. A struct instead of a named tuple: `[(item:, mark:)]`
/// doesn't convert to `[(PlanItem, Mark)]` implicitly, and ForEach needs an id.
struct MarkSuggestion: Identifiable {
    let item: PlanItem
    /// The suggested mark.
    let mark: Mark
    /// What is recorded (nil for `suggestionsToFill`).
    let current: Mark?
    var id: String { item.code }
}

/// The week's spending for one purpose (R54).
struct ExpensePurpose: Identifiable {
    /// The note, trimmed; empty → "ohne Angabe".
    let purpose: String
    let total: Double
    let count: Int
    var id: String { purpose }
}

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
        let open = openToDo(on: today)
        let shown = Array(open.prefix(5))
        let expenses = expenseMeasure
        return TodaySummary(
            day: today.shortLabel, weekLabel: week.label, dayScore: closed ? overall?.score : nil, weekScore: score.overall,
            fill: overall?.coverage ?? 0, powerHours: totals.powerHours, isClosed: closed,
            nextCategory: next.map { "\($0.key) \($0.title)" }, measures: lines,
            goalScores: goals.map { score.goalWeek[$0.key]?.score }, goalTitles: goals.map(\.title), updatedAt: Date()
        ).with { summary in
            summary.open = shown.map { "\($0.categoryKey) \($0.title)" }
            summary.openKeys = shown.map(\.key)
            summary.openCount = open.count
            summary.dueCount = overall?.due ?? 0
            summary.weekly = weeklyTargets.prefix(4).map { target in
                TodaySummary.GoalLine(title: target.measure.title, value: target.value, target: target.target.scaleMax,
                                      unit: target.unit, categoryKey: target.measure.categoryKey)
            }
            summary.powerHoursWeek = workTotals().powerHours
            summary.powerHoursTarget = workTarget
            summary.expensesToday = expenses.flatMap { dayValue($0, on: today) }
            summary.expensesWeek = expenses.flatMap { weekValue($0) }
            summary.dayKey = today.string
            summary.isNewDay = false
            summary.dayType = dayType(today)
            summary.dayNote = dayNote(today)
            summary.hasPlan = hasPlan
            summary.weeklyOpenCount = openWeeklyToDo(on: today).count
        }
    }

    // MARK: At a glance (v5)

    /// R5: exactly the blank required items of a day (`WeekData.isOpenRequired`), in plan order –
    /// as many as the ring counts (`score.days[day]?.blank`).
    func openToDo(on day: DayKey) -> [PlanItem] {
        let scored = Set(categories.map(\.key))
        return items.filter { item in
            guard scored.contains(item.categoryKey), let record = item.record else { return false }
            return data.isOpenRequired(record, on: day)
        }
    }

    /// R5: n×-per-week items (no "Nebensache") due and blank on `day` whose quota isn't reached yet.
    func openWeeklyToDo(on day: DayKey) -> [PlanItem] {
        items.filter { item in
            guard item.schedule.weeklyTarget != nil, !item.isSecondary, applies(item, on: day), mark(item, on: day) == nil,
                  let quota = quotaProgress(item) else { return false }
            return quota.done < quota.target
        }
    }

    /// R5: the number of blank required items (the ring's count).
    func openCount(on day: DayKey) -> Int {
        score.days[day]?.blank ?? 0
    }

    /// R8: "–" without a plan or for days still to come; the score once closed ("7,5"); else "62 %".
    func dayStatusText(_ day: DayKey) -> String {
        guard hasPlan, day <= today else { return "–" }
        if isClosed(day) { return Format.score(score.days[day]?.score) }
        return score.days[day]?.coverageText ?? "–"
    }

    /// R8/R66: "Mittwoch, abgeschlossen, Wertung 7,5" · "Mittwoch, 62 Prozent erfasst" · "Mittwoch, kommt noch".
    func dayStatusAccessibility(_ day: DayKey) -> String {
        let name = day.weekday.name
        guard hasPlan else { return "\(name), kein Plan" }
        guard day <= today else { return "\(name), kommt noch" }
        if isClosed(day) {
            guard let value = score.days[day]?.score else { return "\(name), abgeschlossen" }
            return "\(name), abgeschlossen, Wertung \(Format.score(value))"
        }
        let percent = Int(((score.days[day]?.coverage ?? 0) * 100).rounded())
        return "\(name), \(percent) Prozent erfasst"
    }

    /// The week's € measurement ("Ausgaben"), if the plan has one.
    var expenseMeasure: MeasureDefinition? {
        measures.first { isExpense($0) }
    }

    /// A spending measurement: every entry is one spending with what it was for (K2).
    func isExpense(_ measure: MeasureDefinition) -> Bool {
        measure.record?.isExpense ?? false
    }

    /// The day's spendings, newest first.
    func expenseEntries(_ measure: MeasureDefinition, on day: DayKey) -> [MeasureEntry] {
        entries.filter { $0.code == measure.code && $0.dayKey == day.string }.sorted { $0.recordedAt > $1.recordedAt }
    }

    /// What earlier spendings were for (one-tap suggestions).
    func expenseSuggestions(_ measure: MeasureDefinition) -> [String] {
        var counts: [String: Int] = [:]
        for entry in entries where entry.code == measure.code && !entry.note.isEmpty { counts[entry.note, default: 0] += 1 }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.map(\.key)
    }

    /// Sum of the weekly power-hour targets of the work measurements.
    var workTarget: Double? {
        let targets: [Double] = measures.compactMap { measure in
            guard let record = measure.record, record.isWork, record.period == .week, let target = record.target else { return nil }
            return target.scaleMax
        }
        return targets.isEmpty ? nil : targets.reduce(0, +)
    }

    /// Weekly targets as plain numbers (widgets, Mac sidebar).
    var weeklyLines: [TodaySummary.GoalLine] {
        measures.compactMap { measure in
            guard let record = measure.record, record.period == .week, let target = record.target, target.scaleMax > 0 else { return nil }
            return TodaySummary.GoalLine(title: measure.title, value: weekValue(measure) ?? 0, target: target.scaleMax,
                                         unit: record.isWork ? "PH" : measure.unit, categoryKey: measure.categoryKey)
        }
    }
}

// MARK: v7

extension WeekContext {
    /// H1: shown instead of "fehlt" where the value comes from Apple Health on another device.
    static let healthElsewhereHint = "Wert aus Health auf dem iPhone"

    /// R16: every weekly measurement with a target, in plan order.
    var weeklyTargets: [WeeklyTarget] {
        measures.compactMap { measure -> WeeklyTarget? in
            guard let record = measure.record, record.period == .week, let target = record.target else { return nil }
            let value = weekValue(measure) ?? 0
            let tempo: Pace = pace(for: measure)
                ?? Pace(done: value, target: target.scaleMax, days: measure.days, week: week, today: today)
            let linked = items.first { $0.measureCode == measure.code && $0.schedule == .progress }
            return WeeklyTarget(measure: measure, item: linked, value: value, target: target, pace: tempo,
                                unit: record.isWork ? "PH" : Units.display(measure.unit))
        }
    }

    /// R16: how many weekly targets are met (also PDF and report).
    var weeklyTargetsMet: Int { weeklyTargets.filter(\.isMet).count }

    /// R47: the weekly measurement's pace; work measurements don't plan on work-free days.
    func pace(for measure: MeasureDefinition) -> Pace? {
        guard let record = measure.record, record.period == .week, let target = record.target else { return nil }
        let isWorkMeasure = record.isWork || record.dayRule == .workOnly
            || (record.dayRule == .auto && data.workCategories.contains(record.categoryKey))
        let excluded: Set<DayKey> = isWorkMeasure ? data.workFreeDays : []
        return Pace(done: weekValue(measure) ?? 0, target: target.scaleMax, days: measure.days, week: week, today: today,
                    excluding: excluded)
    }

    /// R64: short label for how an item counts; nil for a plain fixed item.
    func kindLabel(_ item: PlanItem) -> String? {
        if item.isSecondary { return "Nebensache" }
        switch item.schedule {
        case .fixed: return nil
        case .optional: return "optional"
        case .conditional: return "bedingt"
        case .weekly(let count): return "\(count)× pro Woche"
        case .progress: return isDerived(item) ? "automatisch" : "Wochenfortschritt"
        }
    }

    /// R90: the plan's note for the day ("Besonderheit").
    func dayNote(_ day: DayKey) -> String {
        info(day)?.note ?? ""
    }

    /// H1: a Health measurement on a device that doesn't read Health (Mac, Watch).
    func isHealthElsewhere(_ measure: MeasureDefinition) -> Bool {
        (measure.record?.isHealth ?? false) && !HealthDevice.readsHealth
    }

    /// H1: due that day, no value – and not a value that only Health on the iPhone can give.
    func countsAsMissing(_ measure: MeasureDefinition, on day: DayKey) -> Bool {
        applies(measure, on: day) && dayValue(measure, on: day) == nil && !isHealthElsewhere(measure)
    }

    /// The mark a linked measurement suggests, whatever is recorded.
    private func measuredSuggestion(_ item: PlanItem, on day: DayKey) -> Mark? {
        guard !item.measureCode.isEmpty, applies(item, on: day), let record = item.record,
              let linked = measure(code: item.measureCode) else { return nil }
        return Measures.suggestion(for: record, dayValue: dayValue(linked, on: day))
    }

    /// R12: blank items a measurement has a suggestion for.
    func suggestionsToFill(on day: DayKey) -> [MarkSuggestion] {
        items.compactMap { item -> MarkSuggestion? in
            guard recordedMark(item, on: day) == nil, let mark = measuredSuggestion(item, on: day) else { return nil }
            return MarkSuggestion(item: item, mark: mark, current: nil)
        }
    }

    /// R12: items whose recorded mark differs from the suggestion (`current` = recorded).
    func suggestionsDiffering(on day: DayKey) -> [MarkSuggestion] {
        items.compactMap { item -> MarkSuggestion? in
            guard let current = recordedMark(item, on: day), let mark = measuredSuggestion(item, on: day), mark != current else {
                return nil
            }
            return MarkSuggestion(item: item, mark: mark, current: current)
        }
    }

    /// R58: the plan's journal item ("Ins Journal eingetragen").
    var journalItem: PlanItem? {
        items.first { ReflectionQuestion.isJournalTitle($0.title) }
    }

    /// R58: the journal item's mark (✓/½ → true, ✗ → false), else the reflection "ja" / "nein".
    func journalDone(on day: DayKey) -> Bool? {
        if let item = journalItem {
            let marked: Mark? = mark(item, on: day)
            if marked == .done || marked == .partial { return true }
            if marked == .missed { return false }
        }
        switch reflection(scope: day.string, field: ReflectionQuestion.journalField) {
        case "ja": return true
        case "nein": return false
        default: return nil
        }
    }

    /// R54: the week's spending grouped by what it was for (case-insensitive, the most used spelling
    /// shown), largest first.
    func expensesByPurpose(_ measure: MeasureDefinition, limit: Int = 5) -> [ExpensePurpose] {
        var groups: [String: (total: Double, count: Int, spellings: [String: Int])] = [:]
        for entry in entries where entry.code == measure.code {
            let trimmed = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            var group = groups[key] ?? (total: 0, count: 0, spellings: [:])
            group.total += entry.value ?? 0
            group.count += 1
            group.spellings[trimmed, default: 0] += 1
            groups[key] = group
        }
        let purposes: [ExpensePurpose] = groups.map { element -> ExpensePurpose in
            let group = element.value
            let spelling = group.spellings.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? element.key
            return ExpensePurpose(purpose: spelling.isEmpty ? "ohne Angabe" : spelling, total: group.total, count: group.count)
        }
        return Array(purposes.sorted { ($0.total, $1.purpose) > ($1.total, $0.purpose) }.prefix(limit))
    }
}
