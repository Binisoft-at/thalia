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
    /// The target that counts this week: scaled for sick and holiday days (v8, `Measures.effectiveTarget`).
    let target: Target
    let pace: Pace
    /// "PH" for work, else `Units.display(unit)`.
    let unit: String
    /// The plan's target before scaling (v8).
    var fullTarget: Target
    /// The share of the target that still counts (1 without sick or holiday days, v8).
    var share: Double = 1
    /// "2 Tage krank": the sick or holiday days among the measurement's days (v8); empty without.
    var excusedText: String = ""
    var id: String { measure.code }
    /// Limits: while below; targets: reached.
    var isMet: Bool { target.isMet(value) }
    /// v8: the target was scaled down for sick or holiday days.
    var isScaled: Bool { target != fullTarget }
    /// v8: at least one of the measurement's days still counts (share > 0); otherwise it isn't scored
    /// this week (Decision 4) and stays out of `WeekContext.weeklyTargets`.
    var isCounted: Bool { share > 1e-9 }
    /// v8: "4,8 statt 8 PH – 2 Tage krank"; "zählt nicht – 5 Tage krank" when no day counts; nil
    /// when nothing was scaled.
    var scaledHint: String? {
        if !isCounted { return excusedText.isEmpty ? "zählt nicht" : "zählt nicht – " + excusedText }
        guard isScaled else { return nil }
        let shown: String = unit.isEmpty ? "" : " " + unit
        let base: String = Format.number(target.scaleMax) + " statt " + Format.number(fullTarget.scaleMax) + shown
        return excusedText.isEmpty ? base : base + " – " + excusedText
    }
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
    /// v9: the week's archive grades (setting `archive.<week>`, the newest copy); nil without grades
    /// and without a source.
    let archive: ArchiveWeek?
    /// v9: the archive grades under today's rules ("nach heutigen Regeln", decision 5): without the
    /// week's sick and holiday days, only categories and goals the app has. Live, so a week that isn't
    /// closed shows it too; nil without grades.
    let archiveRecalculation: ArchiveRecalculation?

    // v10 (TASKS-v10 §1.2–1.5)
    /// The goal year (settings `goal.start` …; the foundation year without them).
    let goalPeriod: GoalPeriod
    /// Thalia's mappings of other apps' groups to categories.
    let linkRules: [LinkRule]
    /// The sources seen (`x.sources`) and their day files of this week (`x.<source>.<day>`).
    let exchangeSources: ExchangeSourceList
    let inbox: [ExchangeDayFile]
    /// What the connected apps and the reading list add – computed, never stored (Grundregel 1): own
    /// records always win. `entryRecords`, `workRecords` and the marks the scoring sees come from here.
    let extras: WeekExtras
    /// The goal year's records, decoded on first use (`segments`, `results`, `goalEntries`, `listItems`,
    /// `listProgress`, `storedCategoryWeeks`) – a screen that shows none of them never decodes them.
    private let records: WeekRecords

    /// `settings`: the week's archive setting (`ArchiveWeek.settingKey`); v10: the goal year (`goal.`),
    /// the reading list (`list.`), the mappings (`link.rule.`), the category week scores (`score.`), the
    /// known sources (`x.sources`) and the week's day files from the inbox. Other settings are ignored.
    init(week: WeekKey, today: DayKey, plans: [WeekPlan], goals: [AnnualGoal], categories: [TrackCategory], items: [PlanItem],
         measures: [MeasureDefinition], marks: [ItemMark], days: [PlanDay], entries: [MeasureEntry], health: [HealthValue],
         work: [WorkBlock], notes: [DayNote], overrides: [ScoreOverride], reflections: [Reflection], changes: [PlanChange] = [],
         settings: [AppSetting] = []) {
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
        let weekDays = Set(week.days.map(\.string))
        self.entries = entries.filter { $0.deletedAt == nil && weekDays.contains($0.dayKey) }
        self.health = health.filter { weekDays.contains($0.dayKey) }
        self.work = work.filter { $0.deletedAt == nil && weekDays.contains($0.dayKey) }
            .sorted { $0.createdAt < $1.createdAt }
        self.notes = notes.filter { $0.deletedAt == nil && weekDays.contains($0.dayKey) }.sorted { $0.createdAt < $1.createdAt }
        self.overrides = overrides.filter { $0.deletedAt == nil && weekDays.contains($0.dayKey) }.latest(by: \.key, modified: \.modifiedAt)
        self.reflections = reflections.latest(by: \.key, modified: \.modifiedAt)
        self.changes = changes.filter { $0.weekKey == weekString }.sorted { $0.createdAt < $1.createdAt }

        // v10: the goal year and its records, the mappings and the week's inbox – read from the settings.
        let storedSettings: [StoredSetting] = settings.map(\.stored)
        let period: GoalPeriod = TrackerStore.goalPeriod(from: settings)
        goalPeriod = period
        let yearRecords = WeekRecords(settings: storedSettings, period: period)
        records = yearRecords
        linkRules = SettingRecords.decode(LinkRule.self, from: storedSettings)
        // Every copy of `x.sources` merged (two devices may each have written one before they synced).
        let sourceList: ExchangeSourceList = ExchangeSourceList.merged(settings.filter { $0.key == ExchangeInbox.sourcesKey }.map(\.value))
        exchangeSources = sourceList
        let dayStrings = Set(week.days.map(\.string))
        inbox = ExchangeInbox.files(from: storedSettings.filter { $0.key.hasPrefix(ExchangeInbox.prefix) }).filter { dayStrings.contains($0.day) }

        var overrideValues: [String: Double] = [:]
        for (key, override) in self.overrides { overrideValues[key] = override.score }
        let isComplete = Scorer.isComplete(week: week, today: today, closed: self.plan?.isClosed ?? false)
        let itemRecords = self.items.compactMap(\.record)
        let dayInfo = self.days
        let free = Set(week.days.filter { DayTypes.isWorkFree(dayInfo[$0.string]?.dayType ?? "") })
        // v8: sick and holiday days don't count (nothing due, weekly targets scaled).
        let excused: Set<DayKey> = DayTypes.excusedDays(week.days) { dayInfo[$0.string]?.dayType ?? "" }
        let goalRecords: [GoalRecord] = self.goals.map(\.record)
        let categoryRecords: [CategoryRecord] = self.categories.map(\.record)

        // Own entries count first, confirmed Health values only where no own value exists that day, then
        // (v10) the reading list and the connected apps; own marks and work blocks win over derived ones.
        let ownWork: [WorkRecord] = self.work.compactMap(\.record)
        let ownMeasures: [MeasureRecord] = self.measures.compactMap(\.record)
        // The reading list only matters when a measure or item of the week reads from it.
        let readsList: Bool = ownMeasures.contains { $0.source.listKind != nil }
            || itemRecords.contains { MeasureSource(raw: $0.measure).listKind != nil }
        let extras = WeekExtras.compute(WeekExtras.Input(
            week: week, items: itemRecords, measures: ownMeasures, categories: categoryRecords,
            ownMarks: self.marks.values.compactMap(\.record), ownEntries: self.entries.compactMap(\.record),
            health: self.health.compactMap(\.record), ownWork: ownWork,
            ownWorkImportIDs: Set(self.work.map(\.importID).filter { !$0.isEmpty }), excusedDays: excused, workFreeDays: free,
            inbox: inbox, rules: linkRules, listItems: readsList ? yearRecords.listItems : [],
            listProgress: readsList ? yearRecords.listProgress : [], sourceNames: sourceList.names))
        self.extras = extras
        let records: [EntryRecord] = extras.entries
        entryRecords = records
        workRecords = extras.work
        let measureRecords: [MeasureRecord] = extras.measures

        // Work categories as in `WeekData`, so progress, pace and weekly targets scale the same way.
        let workCategories: Set<String> = WeekData.workCategories(items: itemRecords, categories: categoryRecords)
        var progress: [String: Double] = [:]
        var worked: [String: Set<DayKey>] = [:]
        for item in itemRecords where item.schedule == .progress {
            progress[item.code] = Measures.progressRatio(for: item, measures: measureRecords, days: week.days,
                                                         entries: records, work: extras.work, excused: excused, workFree: free,
                                                         workCategories: workCategories)
            worked[item.code] = Measures.workedDays(for: item, measures: measureRecords, days: week.days,
                                                    entries: records, work: extras.work)
        }
        data = WeekData(week: week, goals: goalRecords, categories: categoryRecords,
                        items: itemRecords, marks: extras.marks, overrides: overrideValues, isComplete: isComplete,
                        progress: progress, worked: worked, workFreeDays: free, excusedDays: excused)
        score = Scorer.score(data)

        let archiveKey = ArchiveWeek.settingKey(week)
        let stored: AppSetting? = settings.filter { $0.key == archiveKey }.max { $0.modifiedAt < $1.modifiedAt }
        let archived: ArchiveWeek? = stored.map { ArchiveWeek(csv: $0.value, week: week) }
        let kept: ArchiveWeek? = (archived?.isEmpty ?? true) ? nil : archived
        archive = kept
        if let kept, kept.hasGrades {
            archiveRecalculation = kept.recalculated(categories: categoryRecords, goals: goalRecords, excusedDays: excused)
        } else {
            archiveRecalculation = nil
        }
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

    /// v8: a ✓ ½ ✗ recorded on a sick or holiday day (e.g. before the day became "Krank"): kept, but
    /// it doesn't count – the week shows it dimmed. nil on other days.
    func excusedMark(_ item: PlanItem, on day: DayKey) -> Mark? {
        guard isExcused(day), let recorded = recordedMark(item, on: day), recorded != .notApplicable else { return nil }
        return recorded
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
    /// v8: a sick or holiday day – nothing due, never open, it doesn't count in the week's score.
    func isExcused(_ day: DayKey) -> Bool { data.isExcused(day) }

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
    /// v10: also for an item linked to an `app:` / `list:` text directly (its hidden measure).
    func suggestion(_ item: PlanItem, on day: DayKey) -> Mark? {
        guard !item.measureCode.isEmpty, let record = item.record, let measure = measureRecord(code: item.measureCode) else { return nil }
        let suggested = Measures.suggestion(for: record, dayValue: dayValue(measure, on: day))
        return suggested == mark(item, on: day) ? nil : suggested
    }

    /// v10: the measure of a code as the scoring sees it – the week's definition, else the hidden measure
    /// of an item linked to an `app:` or `list:` text directly (`ExchangeDerivation.virtualMeasures`).
    func measureRecord(code: String) -> MeasureRecord? {
        measure(code: code)?.record ?? extras.measures.first { $0.code == code }
    }

    /// A measure's day value (own > Health > reading list and connected apps, v10).
    func dayValue(_ record: MeasureRecord, on day: DayKey) -> Double? {
        Measures.dayValue(record, on: day, entries: entryRecords, work: workRecords)
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

    /// Weekly progress of an item with a quota ("2 von 3"). Marks on sick or holiday days don't count (v8).
    func quotaProgress(_ item: PlanItem) -> (done: Int, target: Int)? {
        guard let target = item.schedule.weeklyTarget else { return nil }
        let done = week.days.filter { mark(item, on: $0) == .done || mark(item, on: $0) == .partial }.count
        return (done, target)
    }

    /// v8 (rule B3): the part of a quota that falls on sick or holiday days (n·|E|/|P|, 0 without them).
    func quotaShare(_ item: PlanItem) -> Double {
        item.record.map { Scorer.quotaShare($0, data: data) } ?? 0
    }

    /// v8: the quota units that count half because of sick or holiday days (once the week is over).
    func quotaExcusedUnits(_ item: PlanItem) -> Double {
        item.record.map { Scorer.excusedUnits($0, data: data) } ?? 0
    }

    /// v8: "2/3× · ½ krank" – what's still missing of the quota counts half because of sick or
    /// holiday days (up to their share); "2/3×" otherwise.
    func quotaText(_ item: PlanItem) -> String? {
        guard let quota = quotaProgress(item) else { return nil }
        let base = "\(quota.done)/\(quota.target)×"
        guard quota.done < quota.target, quotaShare(item) > 1e-9 else { return base }
        return base + " · ½ " + excusedWord(excusedDayList)
    }

    /// v8: the week's sick and holiday days, in order.
    var excusedDayList: [DayKey] { week.days.filter { isExcused($0) } }

    /// The week hero's line: "6/10 Ziele bewertet", "Noch keine Ziele"; v8: a week of only sick or
    /// holiday days says "Woche zählt nicht (krank/Urlaub)" (its goals drop out of `goalsTotal`).
    var coverageLine: String {
        if score.isExcused { return WeekScore.excusedText }
        if score.goalsTotal == 0 { return "Noch keine Ziele" }
        return score.coverageText
    }

    /// v8: the goal's items fell only on sick or holiday days – it doesn't count this week (the same
    /// rule as `WeekScore.goalsExcused`); shown as "entschuldigt" instead of a gap.
    func isGoalExcused(_ goal: AnnualGoal) -> Bool {
        guard !data.excusedDays.isEmpty, (score.goalWeek[goal.key]?.categoriesTotal ?? 0) == 0 else { return false }
        let keys = Set(categories(of: goal).map(\.key))
        let planned: [DayKey] = data.items.filter { keys.contains($0.categoryKey) && $0.schedule.isScored }.flatMap { data.plannedDays($0) }
        return !planned.isEmpty && planned.allSatisfy { data.isExcused($0) }
    }

    /// v8: "5/7", or "3/5 · 2 krank" – closed days of those that count (sick and holiday days don't).
    var closedDaysText: String {
        let counted: [DayKey] = week.days.filter { !isExcused($0) }
        let closed: Int = counted.filter { isClosed($0) }.count
        let base = "\(closed)/\(counted.count)"
        let excused: [DayKey] = excusedDayList
        guard !excused.isEmpty else { return base }
        return base + " · \(excused.count) " + excusedWord(excused)
    }

    /// v8: "Krank" or "Urlaub" for an excused day (the short word, whatever the exact type says).
    func excusedName(_ day: DayKey) -> String {
        WeekContext.excusedName(for: dayType(day))
    }

    /// "Krank" when the type mentions it, else "Urlaub".
    static func excusedName(for type: String) -> String {
        type.lowercased().contains("krank") ? "Krank" : "Urlaub"
    }

    /// v8: "krank", "Urlaub" or "krank/Urlaub" for a set of excused days.
    func excusedWord(_ days: [DayKey]) -> String {
        let names = Set(days.map { excusedName($0) })
        if names == ["Krank"] { return "krank" }
        if names == ["Urlaub"] { return "Urlaub" }
        return "krank/Urlaub"
    }

    /// v8: "2 Tage krank", "1 Tag Urlaub"; empty without excused days.
    func excusedDaysText(_ days: [DayKey]) -> String {
        guard !days.isEmpty else { return "" }
        return Format.count(days.count, "Tag", "Tage") + " " + excusedWord(days)
    }

    /// v10: `results` – the goals' results for the block "Jahresziel-Ergebnisse" (`TrackerStore.resultLines`);
    /// give them here or to the planning prompt, not both. The marks are the ones that count (own ones,
    /// and ✓ derived from a connected app where there is none).
    func reportInput(results: [GoalResultLine] = []) -> WeekReportInput {
        let weekRecord = plan?.record ?? WeekRecord(week: week)
        return WeekReportInput(
            week: weekRecord, goals: data.goals, categories: data.categories, items: data.items,
            measures: measures.compactMap(\.record), marks: reportMarks,
            overrides: overrides.values.compactMap(\.record), days: days.values.compactMap(\.record),
            entries: entryRecords, work: workRecords, notes: notes.compactMap(\.record),
            reviews: reflections.values.map(\.record), changes: changes.compactMap(\.record),
            closedDays: Set(week.days.filter { isClosed($0) }), isClosed: isClosed, today: today, results: results
        )
    }

    /// The own marks, plus the derived ✓ where there is no own mark (v10) – as the score counts them.
    private var reportMarks: [MarkRecord] {
        let own: [MarkRecord] = marks.values.compactMap(\.record)
        let ownKeys = Set(own.map { WeekData.markKey($0.itemCode, $0.day) })
        return own + extras.effect.marks.filter { !ownKeys.contains(WeekData.markKey($0.itemCode, $0.day)) }
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

    /// R5: the number of blank required items (the ring's count); 0 on sick and holiday days (v8).
    func openCount(on day: DayKey) -> Int {
        guard !isExcused(day) else { return 0 }
        return score.days[day]?.blank ?? 0
    }

    /// R8: "–" without a plan or for days still to come; the score once closed ("7,5"); else "62 %".
    /// v8: "Krank" / "Urlaub" on sick and holiday days.
    func dayStatusText(_ day: DayKey) -> String {
        guard hasPlan else { return "–" }
        if isExcused(day) { return excusedName(day) }
        guard day <= today else { return "–" }
        if isClosed(day) { return Format.score(score.days[day]?.score) }
        return score.days[day]?.coverageText ?? "–"
    }

    /// R8/R66: "Mittwoch, abgeschlossen, Wertung 7,5" · "Mittwoch, 62 Prozent erfasst" · "Mittwoch, kommt noch".
    /// v8: "Freitag, Krank, zählt nicht".
    func dayStatusAccessibility(_ day: DayKey) -> String {
        let name = day.weekday.name
        guard hasPlan else { return "\(name), kein Plan" }
        if isExcused(day) { return "\(name), \(excusedName(day)), zählt nicht" }
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

    /// Sum of the weekly power-hour targets of the work measurements – scaled for sick and holiday
    /// days (v8); a measurement whose days are all excused doesn't count (nil when none counts).
    var workTarget: Double? {
        let targets: [Double] = measures.compactMap { measure in
            guard let record = measure.record, record.isWork, record.period == .week, targetShare(record) > 1e-9 else { return nil }
            return effectiveTarget(record)?.scaleMax
        }
        return targets.isEmpty ? nil : targets.reduce(0, +)
    }

    /// v8: the weekly power-hour targets as planned (before scaling for sick or holiday days).
    var workTargetFull: Double? {
        let targets: [Double] = measures.compactMap { measure in
            guard let record = measure.record, record.isWork, record.period == .week, let target = record.target else { return nil }
            return target.scaleMax
        }
        return targets.isEmpty ? nil : targets.reduce(0, +)
    }

    /// v8: "4,8 statt 8 PH – 2 Tage krank" when sick or holiday days scale the weekly PH target,
    /// "zählt nicht – 5 Tage krank" when none of its days counts, else nil.
    var workTargetHint: String? {
        guard let full = workTargetFull else { return nil }
        let work: [MeasureDefinition] = measures.filter { $0.record?.isWork == true && $0.record?.period == .week }
        let excused: [DayKey] = excusedDayList.filter { day in work.contains { $0.days.contains(day.weekday) } }
        let text: String = excusedDaysText(excused)
        let base: String
        if let scaled = workTarget {
            guard abs(full - scaled) > 1e-9 else { return nil }
            base = Format.number(scaled) + " statt " + Format.number(full) + " PH"
        } else {
            base = "zählt nicht"
        }
        return text.isEmpty ? base : base + " – " + text
    }

    /// Weekly targets as plain numbers (widgets, Mac sidebar), scaled for sick and holiday days (v8);
    /// without those whose days are all excused (not scored).
    var weeklyLines: [TodaySummary.GoalLine] {
        measures.compactMap { measure in
            guard let record = measure.record, record.period == .week, targetShare(record) > 1e-9,
                  let target = effectiveTarget(record), target.scaleMax > 0 else { return nil }
            return TodaySummary.GoalLine(title: measure.title, value: weekValue(measure) ?? 0, target: target.scaleMax,
                                         unit: record.isWork ? "PH" : measure.unit, categoryKey: measure.categoryKey)
        }
    }

    /// v8: a measurement's target as it counts this week (`Measures.effectiveTarget`): scaled to the
    /// days that aren't sick or holiday days; limits and times unchanged.
    func effectiveTarget(_ record: MeasureRecord) -> Target? {
        Measures.effectiveTarget(for: record, week: week, excused: data.excusedDays, workFree: data.workFreeDays,
                                 workCategories: data.workCategories)
    }

    /// v8: the share of a weekly target that still counts (1 without sick or holiday days).
    func targetShare(_ record: MeasureRecord) -> Double {
        Measures.targetShare(for: record, week: week, excused: data.excusedDays, workFree: data.workFreeDays,
                             workCategories: data.workCategories)
    }

    /// v8: the sick or holiday days among a measurement's days.
    func excusedDays(of measure: MeasureDefinition) -> [DayKey] {
        excusedDayList.filter { measure.days.contains($0.weekday) }
    }
}

// MARK: v7

extension WeekContext {
    /// H1: shown instead of "fehlt" where the value comes from Apple Health on another device.
    static let healthElsewhereHint = "Wert aus Health auf dem iPhone"

    /// R16: every weekly measurement with a target that is scored this week, in plan order. v8:
    /// `target` is scaled for sick and holiday days (`fullTarget` keeps the plan's), so pace,
    /// "erreicht" and the hint agree; a measurement whose days are all sick or holiday days isn't
    /// scored (Decision 4) – it's left out here, in "x von y erreicht", the PDF and the widgets, like
    /// `WeekLine` does.
    var weeklyTargets: [WeeklyTarget] { allWeeklyTargets.filter(\.isCounted) }

    /// v8: the hint for a weekly measurement's target ("4,8 statt 8 PH – 2 Tage krank", "zählt nicht
    /// – 5 Tage krank"), also for one that isn't scored this week; nil without.
    func weeklyTargetHint(code: String) -> String? {
        allWeeklyTargets.first { $0.measure.code == code }?.scaledHint
    }

    /// Every weekly measurement with a target, also those whose days are all excused (share 0).
    private var allWeeklyTargets: [WeeklyTarget] {
        measures.compactMap { measure -> WeeklyTarget? in
            guard let record = measure.record, record.period == .week, let full = record.target else { return nil }
            let target: Target = effectiveTarget(record) ?? full
            let value = weekValue(measure) ?? 0
            let tempo: Pace = pace(for: measure)
                ?? Pace(done: value, target: target.scaleMax, days: measure.days, week: week, today: today, excused: data.excusedDays)
            let linked = items.first { $0.measureCode == measure.code && $0.schedule == .progress }
            var line = WeeklyTarget(measure: measure, item: linked, value: value, target: target, pace: tempo,
                                    unit: record.isWork ? "PH" : Units.display(measure.unit), fullTarget: full)
            line.share = targetShare(record)
            line.excusedText = excusedDaysText(excusedDays(of: measure))
            return line
        }
    }

    /// R16: how many weekly targets are met (also PDF and report) – against the scaled targets (v8).
    var weeklyTargetsMet: Int { weeklyTargets.filter(\.isMet).count }

    /// R47: the weekly measurement's pace; work measurements don't plan on work-free days.
    /// v8: sick and holiday days are left out and the target is scaled (`Measures.weeklyPace`).
    func pace(for measure: MeasureDefinition) -> Pace? {
        guard let record = measure.record else { return nil }
        return Measures.weeklyPace(record, done: weekValue(measure) ?? 0, week: week, today: today, excused: data.excusedDays,
                                   workFree: data.workFreeDays, workCategories: data.workCategories)
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
    /// v8: never missing on a sick or holiday day (a value can still be entered and counts).
    /// v10: never for a value from the reading list or a connected app (nothing to type in).
    func countsAsMissing(_ measure: MeasureDefinition, on day: DayKey) -> Bool {
        if let source = measure.record?.source, source.appSource != nil || source.listKind != nil { return false }
        return !isExcused(day) && applies(measure, on: day) && dayValue(measure, on: day) == nil && !isHealthElsewhere(measure)
    }

    /// The mark a linked measurement suggests, whatever is recorded.
    private func measuredSuggestion(_ item: PlanItem, on day: DayKey) -> Mark? {
        guard !item.measureCode.isEmpty, applies(item, on: day), let record = item.record,
              let linked = measureRecord(code: item.measureCode) else { return nil }
        return Measures.suggestion(for: record, dayValue: dayValue(linked, on: day))
    }

    /// R12: blank items a measurement has a suggestion for. v10: not those ticked by a connected app –
    /// the derived tick stays computed (Grundregel 1).
    func suggestionsToFill(on day: DayKey) -> [MarkSuggestion] {
        items.compactMap { item -> MarkSuggestion? in
            guard recordedMark(item, on: day) == nil, !isDerivedMark(item, on: day),
                  let mark = measuredSuggestion(item, on: day) else { return nil }
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
    /// shown), largest first. v10: a connected app's rows (Finn) count in their groups too.
    func expensesByPurpose(_ measure: MeasureDefinition, limit: Int = 5) -> [ExpensePurpose] {
        var groups: [String: (total: Double, count: Int, spellings: [String: Int])] = [:]
        var rows: [(note: String, value: Double)] = entries.filter { $0.code == measure.code }.map { ($0.note, $0.value ?? 0) }
        for day in week.days {
            rows += appExpenseRows(measure, on: day).map { ($0.purpose, $0.amount) }
        }
        for row in rows {
            let trimmed = row.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            var group = groups[key] ?? (total: 0, count: 0, spellings: [:])
            group.total += row.value
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

// MARK: v9 – archive weeks

extension WeekContext {
    /// The value "laut Unterlagen" (`WeekPlan.recordedScore`): from the week row or "Nur Wertung", never
    /// calculated (decision 5).
    var recordedScore: Double? { plan?.recordedScore }

    /// The score "nach heutigen Regeln" (decision 5): for a week with items the Scorer's (the stored one
    /// once the week is closed), for a week without items the recalculation of its archive grades;
    /// nil without either.
    var recalculatedScore: Double? {
        guard hasPlan else { return archiveRecalculation?.overall }
        guard isClosed, let stored = plan?.finalScore else { return score.overall }
        return stored
    }

    /// The week shows the "Archiv" card (decision 9): archive grades or a value "laut Unterlagen".
    var showsArchive: Bool {
        let graded: Bool = archive?.hasGrades ?? false
        return graded || recordedScore != nil
    }

    /// The week's day types by day ("Urlaub"), days without a type left out.
    var dayTypes: [DayKey: String] {
        var result: [DayKey: String] = [:]
        for day in week.days {
            let type = dayType(day)
            if !type.isEmpty { result[day] = type }
        }
        return result
    }

    /// "ohne 2 Urlaubstage" – the days whose grades don't count under today's rules; nil without.
    var archiveExcludedText: String? {
        archiveRecalculation?.excludedText(dayTypes: dayTypes)
    }

    /// The short line next to "nach heutigen Regeln": why there is no value ("keine Kategoriennoten"),
    /// else for a week without items the days left out ("ohne 1 Urlaubstag"); nil when there's nothing to say.
    var recalculatedNote: String? {
        if recalculatedScore == nil {
            if hasPlan { return score.isExcused ? WeekScore.excusedText : "noch keine Wertung" }
            let graded: Bool = archive?.hasGrades ?? false
            return graded ? "keine Note mit heutiger Kategorie" : "keine Kategoriennoten"
        }
        return hasPlan ? nil : archiveExcludedText
    }

    /// The short line next to "laut Unterlagen" without a value.
    var recordedNote: String? {
        recordedScore == nil ? "nicht in den Unterlagen" : nil
    }

    /// An archive line counts today (decision 6): it has an id and the app has that category or goal.
    /// Otherwise it belongs under "Ohne Zuordnung (Archiv)".
    func isMapped(_ line: ArchiveWeek.Line) -> Bool {
        guard !line.id.isEmpty else { return false }
        switch line.kind {
        case .category: return category(line.id) != nil
        case .goal: return goals.contains { $0.key == line.id }
        }
    }

    /// The archive's category lines with a category of the app, in sheet order.
    var archiveCategoryLines: [ArchiveWeek.Line] {
        let lines: [ArchiveWeek.Line] = archive?.categoryLines ?? []
        return lines.filter { isMapped($0) }
    }

    /// The archive's goal lines with a goal of the app, in sheet order.
    var archiveGoalLines: [ArchiveWeek.Line] {
        let lines: [ArchiveWeek.Line] = archive?.goalLines ?? []
        return lines.filter { isMapped($0) }
    }

    /// "Ohne Zuordnung (Archiv)": lines without an id or with a category or goal the app doesn't have.
    /// They are kept with their original label and never count.
    var archiveUnmappedLines: [ArchiveWeek.Line] {
        let lines: [ArchiveWeek.Line] = archive?.lines ?? []
        return lines.filter { !isMapped($0) }
    }

    /// The goal of an id ("5"), if the app has it.
    func goal(key: String) -> AnnualGoal? {
        goals.first { $0.key == key }
    }
}

// MARK: v10 – results, "Wochen über 8", segments, reading list, connected apps

/// The goal year's records of a week's settings, decoded once on first use. A class so `WeekContext`
/// stays a value that copies cheaply; locked, as a context may be read off the main thread (PDF).
final class WeekRecords: @unchecked Sendable {
    private let settings: [StoredSetting]
    private let period: GoalPeriod
    private let lock = NSRecursiveLock()
    private var segmentsValue: Segments?
    private var resultsValue: [GoalResult]?
    private var entriesValue: [GoalEntry]?
    private var itemsValue: [ListItem]?
    private var progressValue: [ListProgress]?
    private var scoresValue: [GoalTrack.Week]?

    init(settings: [StoredSetting], period: GoalPeriod) {
        self.settings = settings
        self.period = period
    }

    private func cached<T>(_ value: inout T?, _ make: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        if let value { return value }
        let made = make()
        value = made
        return made
    }

    var segments: Segments {
        cached(&segmentsValue) { Segments.resolve(SettingRecords.decode(GoalSegment.self, from: settings), period: period) }
    }

    var results: [GoalResult] {
        cached(&resultsValue) {
            SettingRecords.decode(GoalResult.self, from: settings)
                .filter { $0.periodStart == nil || $0.periodStart == period.start }
                .sorted(by: TrackerStore.resultOrder)
        }
    }

    var entries: [GoalEntry] { cached(&entriesValue) { SettingRecords.decode(GoalEntry.self, from: settings) } }

    var listItems: [ListItem] {
        cached(&itemsValue) { SettingRecords.decode(ListItem.self, from: settings).sorted { ($0.position, $0.title) < ($1.position, $1.title) } }
    }

    var listProgress: [ListProgress] { cached(&progressValue) { SettingRecords.decode(ListProgress.self, from: settings) } }

    var categoryWeeks: [GoalTrack.Week] {
        cached(&scoresValue) {
            let newest = SettingRecords.newest(settings.filter { $0.key.hasPrefix(GoalTrack.settingPrefix) })
            return newest.compactMap { key, setting -> GoalTrack.Week? in
                GoalTrack.week(settingKey: key).map { GoalTrack.Week(week: $0, text: setting.value) }
            }.sorted { $0.week < $1.week }
        }
    }
}

/// A connected app's spending row in the spending list (§1.5.3): shown, never edited here ("in Finn ändern").
struct AppExpenseRow: Identifiable {
    let day: DayKey
    let amount: Double
    /// What it was for (the group in the source app).
    let purpose: String
    /// "Finn"
    let source: String
    let index: Int
    var id: String { "\(day.string)|\(source)|\(index)" }
}

extension WeekContext {
    /// The goal year's segments, gapless – without stored ones one "Abschnitt 1" (§1.4).
    var segments: Segments { records.segments }
    /// The goal year's results (those without a goal year too), not in the trash, by goal and position.
    var results: [GoalResult] { records.results }
    /// The results' own entries (not in the trash).
    var goalEntries: [GoalEntry] { records.entries }
    /// The reading list and every reading (not in the trash) – a day's amount needs the readings before it.
    var listItems: [ListItem] { records.listItems }
    var listProgress: [ListProgress] { records.listProgress }
    /// The stored category week scores (`score.<week>`) of closed weeks, oldest first.
    var storedCategoryWeeks: [GoalTrack.Week] { records.categoryWeeks }

    // MARK: Segments (§1.4)

    /// The segment `today` is in (the focus of every screen).
    var currentSegment: SegmentSpan? { segments.current(today: today) }

    /// The segment this week belongs to.
    var weekSegment: SegmentSpan? { segments.span(for: week) }

    /// "Abschnitt 2 · seit KW50 · Woche 3" – the year card's head.
    var segmentHeadline: String { currentSegment?.headline(week: today.week) ?? "" }

    /// Grundregel 2: the week lies before the current segment – once closed, its score is never computed
    /// again by itself, only with "Neu berechnen" (`TrackerStore.recompute`).
    var isFrozen: Bool { segments.isFrozen(week, today: today) }

    /// The labels of this week (§1.4.1): a week of an earlier segment shows the goals and categories as
    /// they were then; later weeks the current ones.
    var labels: (goals: [GoalRecord], categories: [CategoryRecord]) {
        segments.labels(for: week, today: today, goals: data.goals, categories: data.categories)
    }

    /// The goal's title in this week (§1.4.1): a week of an earlier segment shows the one of then.
    func title(of goal: AnnualGoal) -> String {
        guard segments.hasSeveral else { return goal.title }
        return labels.goals.first { $0.key == goal.key }?.title ?? goal.title
    }

    /// The category's title in this week (§1.4.1): a week of an earlier segment shows the one of then.
    func title(of category: TrackCategory) -> String {
        guard segments.hasSeveral else { return category.title }
        return labels.categories.first { $0.key == category.key }?.title ?? category.title
    }

    // MARK: Results (§1.2.1–1.2.2)

    /// The results shown in the current segment (started in it or before, not ended before it).
    var activeResults: [GoalResult] {
        guard let current = currentSegment else { return results }
        return results.filter { $0.isActive(in: current, segments: segments) }
    }

    /// The active results of a goal.
    func results(of goal: AnnualGoal) -> [GoalResult] {
        activeResults.filter { $0.goalKey == goal.key }
    }

    /// The results of a goal new from a segment that hasn't begun yet ("Gilt ab Abschnitt 2 (KW48)") –
    /// shown apart until it begins, so a result set up right after "Neuen Abschnitt beginnen…" is visible.
    func upcomingResults(of goal: AnnualGoal) -> [GoalResult] {
        guard let current = currentSegment else { return [] }
        let active = Set(activeResults.map(\.id))
        return results.filter { result in
            guard result.goalKey == goal.key, !active.contains(result.id),
                  let from = result.fromSegment.flatMap(segments.span(id:)) else { return false }
            return from.number > current.number
        }
    }

    /// A result's own entries, by day.
    func entries(of result: GoalResult) -> [GoalEntry] {
        goalEntries.filter { $0.resultID == result.id }.sorted { ($0.day, $0.modifiedAt) < ($1.day, $1.modifiedAt) }
    }

    /// The result's source needs the store's day values (`TrackerStore.resultSeries`): a measure over the
    /// goal year, a connected app's facts beyond this week.
    func needsSeries(_ result: GoalResult) -> Bool {
        switch result.resultSource {
        case .measure, .app: return true
        default: return false
        }
    }

    /// A result's progress on `today`: own entries and the reading list from here; for a `measure:` or
    /// `app:` source pass `series` (`TrackerStore.resultSeries`, read once per screen).
    func progress(_ result: GoalResult, series: [DayKey: Double] = [:]) -> ResultProgress {
        ResultProgress.compute(result, segments: segments, today: today, entries: goalEntries, items: listItems, series: series)
    }

    /// The results that a measure feeds (`measure:<code>`) – "zählt für Ziel 5 · Bücher 3/10".
    func results(feedBy measure: MeasureDefinition) -> [GoalResult] {
        activeResults.filter { $0.uses(measure: measure.code) }
    }

    /// The measures of a goal (§1.2.4): those of its categories, then those feeding one of its results –
    /// this week's definitions (the store's `latestMeasureRecords` when the week has none).
    func goalMeasures(_ goal: AnnualGoal) -> [MeasureRecord] {
        GoalResult.measures(of: goal.key, categories: data.categories, measures: measures.compactMap(\.record), results: activeResults)
    }

    // MARK: "Wochen über 8" (§1.2.3)

    /// The category's score this week is "über 8" (live; rounded like on screen).
    func isGood(_ category: TrackCategory) -> Bool {
        GoalTrack.isGood(score.categoryWeek[category.key])
    }

    /// The goal is "gut dabei" this week: every scored category of it is above 8; nil when none is scored.
    func goalIsGood(_ goal: AnnualGoal) -> Bool? {
        GoalTrack.goalIsGood(goal.key, categories: data.categories, scores: score.categoryWeek)
    }

    /// The stored weeks of the current segment (all goal years' weeks when there is none), oldest first.
    var segmentCategoryWeeks: [GoalTrack.Week] {
        guard let current = currentSegment else { return storedCategoryWeeks }
        return storedCategoryWeeks.filter { current.contains($0.week) }
    }

    /// "Wochen über 8: 1.1 9/12 · 1.2 7/12" – the goal's categories over the last 12 closed, scored
    /// weeks of the current segment; nil without any.
    func goalTrackLine(_ goal: AnnualGoal) -> String? {
        let keys = categories(of: goal).map(\.key)
        let range: ClosedRange<WeekKey>? = currentSegment.map { $0.startWeek...$0.endWeek }
        return GoalTrack.line(GoalTrack.tallies(storedCategoryWeeks, categories: keys, range: range))
    }

    /// The category's tally ("1.1 9/12") in the current segment; nil without scored weeks.
    func tally(_ category: TrackCategory) -> GoalTrack.Tally? {
        let range: ClosedRange<WeekKey>? = currentSegment.map { $0.startWeek...$0.endWeek }
        return GoalTrack.tallies(storedCategoryWeeks, categories: [category.key], range: range).first
    }

    // MARK: Reading list (§1.3)

    /// "Gerade dabei": the entries being read (readings or a start, not finished or abandoned).
    var runningListItems: [ListItem] {
        listItems.filter { ListMath.status($0, progress: listProgress) == .running }
    }

    func status(_ item: ListItem) -> ListStatus { ListMath.status(item, progress: listProgress) }

    /// "120 von 320 Seiten · 38 %"
    func progressText(_ item: ListItem) -> String { ListMath.progressText(item, progress: listProgress) }

    /// The highest page reached (through `day`), nil without readings.
    func reached(_ item: ListItem, through day: DayKey? = nil) -> Double? {
        ListMath.reached(itemID: item.id, progress: listProgress, through: day)
    }

    /// A book's readings, by day.
    func readings(of item: ListItem) -> [ListProgress] { ListMath.readings(listProgress, itemID: item.id) }

    // MARK: Connected apps (§1.5.3)

    /// Derived power-hours with a category ("aus Theo", read only) of a day.
    func derivedWork(on day: DayKey) -> [WorkRecord] { extras.effect.work.filter { $0.day == day } }

    /// Power-hours without a category ("ohne Zuordnung") of a day – shown, counted nowhere.
    func unassignedWork(on day: DayKey) -> [WorkRecord] { extras.effect.unassignedWork.filter { $0.day == day } }

    /// "Theo" – where a derived block comes from.
    func workSource(_ record: WorkRecord) -> String? { extras.effect.workSources[record.id] }

    /// The item's ✓ comes from a connected app (no own mark that day).
    func isDerivedMark(_ item: PlanItem, on day: DayKey) -> Bool { extras.isDerived(item.code, on: day) }

    /// "⇄ George · Push" for a derived ✓; nil otherwise.
    func derivedMarkLabel(_ item: PlanItem, on day: DayKey) -> String? {
        extras.effect.markLabels[WeekData.markKey(item.code, day)]
    }

    /// "Finn" when the measure's day value comes from a connected app (own entries replace it, spending adds up).
    func valueSource(_ measure: MeasureDefinition, on day: DayKey) -> String? {
        extras.effect.entrySources["\(measure.code)|\(day.string)"]
    }

    /// A connected app's spending rows of a day (read only): one per group, with the source's purpose.
    func appExpenseRows(_ measure: MeasureDefinition, on day: DayKey) -> [AppExpenseRow] {
        guard let source = valueSource(measure, on: day) else { return [] }
        let derived = extras.effect.entries.filter { $0.code == measure.code && $0.day == day }
        var rows: [AppExpenseRow] = []
        for entry in derived {
            let parts: [EntryPart] = entry.parts.isEmpty ? [EntryPart(value: entry.value, minutes: 0)] : entry.parts
            for part in parts {
                rows.append(AppExpenseRow(day: day, amount: part.value ?? 0, purpose: part.note, source: source, index: rows.count))
            }
        }
        return rows
    }

    /// Facts of the week this build can't use ("nicht verwendet") and those from Apple Health (never used).
    var unusedFactCount: Int { extras.effect.unused.count }
    var ignoredFactCount: Int { extras.effect.ignored }
}
