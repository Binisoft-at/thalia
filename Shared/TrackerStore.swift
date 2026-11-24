import Foundation
import CoreData
import SwiftData
import BinisoftKit
import ThaliaCore

/// v11 P2.1: where a save comes from. Mac, Watch and iPad score closed weeks themselves only after own
/// input (`.user`); background work – the inbox, merging, catch-up, an import – is `.maintenance` (so is
/// every save inside `TrackerStore.withoutUndo`).
enum SaveOrigin {
    case user, maintenance
}

/// v11 P2.5: a mark as it was before a bulk change ("Alle offenen ✓/½/✗", "Vorschläge übernehmen").
/// `restoreMarks(_:)` puts it back; without an own mark before (`existed` false) the written one goes again –
/// an empty own mark would hide a connected app's ✓ for good.
struct MarkSnapshot {
    let item: PlanItem
    let day: DayKey
    /// The recorded value before (nil: empty or no mark).
    let mark: Mark?
    /// An own mark (`ItemMark`) existed, also one without a value.
    let existed: Bool
}

/// v11 P6.8, P7.1: what a closed week stored – `TrackerStore.restore(_:)` writes it back exactly, without
/// scoring ("Widerrufen" after "Woche wieder öffnen" or "Neu berechnen").
struct ClosedWeekSnapshot {
    let week: WeekKey
    let closedAt: Date?
    let finalScore: Double?
    let finalGoalScores: String
    let finalGoalsScored: Int
    /// The stored category week scores (`score.<week>`, as text); nil when none were stored.
    let categoryScores: String?
}

/// v11 P3.2: whether this device's first iCloud sync is done (`sync.firstImportDone`, UserDefaults, per
/// device). Until then no device scores closed weeks by itself (§1.3.3), the import warns and no automatic
/// backup is written. Set when an import ended successfully, no further import began within 60 s and the
/// store holds another device's `sync.seen.` entry (a fresh device's first sync often takes several
/// imports); at the latest 24 h after this install; right away after an update from 1.9.0
/// (`HealthDevice.installedAt == .distantPast`). App and Watch call `noteImport` from their import observer.
@MainActor
enum SyncProgress {
    static let firstImportDoneKey = "sync.firstImportDone"
    /// Quiet time after a finished import before the first sync counts as done.
    static let quietTime: TimeInterval = 60
    /// At the latest this long after the install.
    static let fallbackTime: TimeInterval = 24 * 3600
    private static var pending: Task<Void, Never>?

    static var firstImportDone: Bool { isFirstImportDone(now: Date()) }

    /// The flag, or – once – the fallbacks (an update from 1.9.0, 24 h after the install), which set it.
    static func isFirstImportDone(now: Date) -> Bool {
        if UserDefaults.standard.bool(forKey: firstImportDoneKey) { return true }
        let installed: Date = HealthDevice.installedAt
        if installed == .distantPast {
            markDone("update from an earlier version")
            return true
        }
        guard now.timeIntervalSince(installed) >= fallbackTime else { return false }
        markDone("24 h after the install")
        return true
    }

    /// An iCloud event (its start and its end): a finished, successful import is confirmed 60 s later unless
    /// another one began in between. `container`: the store to look for another device in (default the app's).
    static func noteImport(_ event: NSPersistentCloudKitContainer.Event, container: ModelContainer? = nil) {
        guard event.type == .import, !UserDefaults.standard.bool(forKey: firstImportDoneKey) else { return }
        pending?.cancel()
        pending = nil
        // An import that began (no end yet) or failed: wait for the next end.
        guard event.endDate != nil, event.succeeded else { return }
        let store: ModelContainer = container ?? Persistence.shared.container
        pending = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(quietTime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            confirmFirstImport(context: store.mainContext)
        }
    }

    /// After the quiet time: done when the store holds another device's `sync.seen.` entry. Returns whether
    /// the first sync is done now.
    @discardableResult
    static func confirmFirstImport(context: ModelContext) -> Bool {
        guard !UserDefaults.standard.bool(forKey: firstImportDoneKey) else { return true }
        let own: String = TrackerStore.installID
        guard TrackerStore(context: context).syncDevices().contains(where: { $0.installID != own }) else { return false }
        markDone("first iCloud import finished")
        return true
    }

    private static func markDone(_ reason: String) {
        UserDefaults.standard.set(true, forKey: firstImportDoneKey)
        AppLog.info("First sync done (\(reason))", category: "sync")
    }
}

/// An entry as it was, to put it back exactly (R2, R46).
struct EntrySnapshot {
    let entry: MeasureEntry
    let value: Double?
    let text: String
    let note: String
    let isEstimate: Bool
    let dayKey: String
    let recordedAt: Date
    let deletedAt: Date?
}

/// What `setDayValue` / `setDayText` changed (R2): undone by `TrackerStore.undo(_:)`.
struct DayValueChange {
    /// State before, of every entry that was changed or moved to the trash.
    var edited: [EntrySnapshot] = []
    var created: [MeasureEntry] = []
    var trashed: [MeasureEntry] = []

    var isEmpty: Bool { edited.isEmpty && created.isEmpty && trashed.isEmpty }
}

/// v11 P2.14: a week's stored models as fetched (`TrackerStore.weekInputs(for:goalYear:)`); `context(today:)`
/// reads and scores them – one fetch can serve two days of the same week (the widget's today and tomorrow).
struct WeekInputs {
    let week: WeekKey
    let plans: [WeekPlan]
    let goals: [AnnualGoal]
    let categories: [TrackCategory]
    let items: [PlanItem]
    let measures: [MeasureDefinition]
    let marks: [ItemMark]
    let days: [PlanDay]
    let entries: [MeasureEntry]
    let health: [HealthValue]
    let work: [WorkBlock]
    let notes: [DayNote]
    let overrides: [ScoreOverride]
    let reflections: [Reflection]
    let changes: [PlanChange]
    let settings: [AppSetting]

    func context(today: DayKey) -> WeekContext {
        WeekContext(week: week, today: today, plans: plans, goals: goals, categories: categories, items: items,
                    measures: measures, marks: marks, days: days, entries: entries, health: health, work: work,
                    notes: notes, overrides: overrides, reflections: reflections, changes: changes, settings: settings)
    }
}

/// One of the last power-hour combinations (R33): area · what for · amount.
struct WorkCombo: Hashable, Identifiable {
    let categoryKey: String
    let task: String
    let powerHours: Double
    var id: String { "\(categoryKey)|\(task)|\(powerHours)" }
}

/// A day value in a chart (R93).
struct SeriesPoint: Identifiable, Equatable {
    let day: DayKey
    let value: Double
    var id: String { day.string }
}

/// A closed week's goal score in a chart (R93).
struct WeekScorePoint: Identifiable, Equatable {
    let week: WeekKey
    let score: Double
    var id: String { week.string }
}

/// A week's power-hours against the sum of its weekly PH targets (R88).
struct WeekWorkPoint: Identifiable, Equatable {
    let week: WeekKey
    let powerHours: Double
    let target: Double?
    var id: String { week.string }
    var isReached: Bool { (target ?? 0) > 0 && powerHours >= (target ?? 0) - 1e-9 }
}

/// Every change goes through here – timestamps, soft delete, duplicate-safe keys, save – so the
/// rules live in one place. Views never write to the models directly. The widget snapshot is
/// written by `WidgetPublisher` (bundled, iPhone and Watch only).
@MainActor
struct TrackerStore {
    let context: ModelContext
    var trashPolicy = TrashPolicy(keepDays: 30)

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Reading

    func allGoals() -> [AnnualGoal] { fetch(FetchDescriptor<AnnualGoal>()) }
    func allCategories() -> [TrackCategory] { fetch(FetchDescriptor<TrackCategory>()) }
    func allPlans() -> [WeekPlan] { fetch(FetchDescriptor<WeekPlan>()) }

    func liveGoals() -> [AnnualGoal] { allGoals().filter { $0.deletedAt == nil } }
    func liveCategories() -> [TrackCategory] { allCategories().filter { $0.deletedAt == nil } }

    func plan(_ week: WeekKey) -> WeekPlan? {
        let key = week.string
        return fetch(FetchDescriptor<WeekPlan>(predicate: #Predicate<WeekPlan> { $0.weekKey == key && $0.deletedAt == nil }))
            .latest(by: \.weekKey, modified: \.modifiedAt)[key]
    }

    func planDay(_ day: DayKey) -> PlanDay? {
        let key = day.string
        return fetch(FetchDescriptor<PlanDay>(predicate: #Predicate<PlanDay> { $0.dayKey == key }))
            .latest(by: \.dayKey, modified: \.modifiedAt)[key]
    }

    /// v8: the day's type is "Krank" or "Urlaub" (`DayTypes.isExcused`): it doesn't count.
    func isExcused(_ day: DayKey) -> Bool {
        DayTypes.isExcused(planDay(day)?.dayType ?? "")
    }

    func items(_ week: WeekKey) -> [PlanItem] {
        let key = week.string
        return fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key && $0.deletedAt == nil }))
    }

    func measures(_ week: WeekKey) -> [MeasureDefinition] {
        let key = week.string
        return fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> { $0.weekKey == key && $0.deletedAt == nil }))
    }

    /// The week, read and scored (widget snapshot, report, export).
    /// v10: `goalYear` false leaves out the goal year's records (segments, results, entries, category week
    /// scores) – for loops over many weeks that only need the score; the score is the same either way.
    func weekContext(for week: WeekKey, today: DayKey = .today(), goalYear: Bool = true) -> WeekContext {
        weekInputs(for: week, goalYear: goalYear).context(today: today)
    }

    /// v11 P2.14: everything a week reads, fetched once (`WeekInputs.context(today:)` builds and scores it –
    /// for two days of one week without fetching twice).
    func weekInputs(for week: WeekKey, goalYear: Bool = true) -> WeekInputs {
        let key = week.string
        let dayKeys = week.days.map(\.string)
        let weekItems = items(week)
        let weekMeasures = measures(week)
        return WeekInputs(
            week: week,
            plans: fetch(FetchDescriptor<WeekPlan>(predicate: #Predicate<WeekPlan> { $0.weekKey == key })),
            goals: allGoals(), categories: allCategories(), items: weekItems,
            measures: weekMeasures,
            marks: fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.weekKey == key })),
            days: fetch(FetchDescriptor<PlanDay>(predicate: #Predicate<PlanDay> { dayKeys.contains($0.dayKey) })),
            entries: fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            health: fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> { dayKeys.contains($0.dayKey) })),
            work: fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            notes: fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            overrides: fetch(FetchDescriptor<ScoreOverride>(predicate: #Predicate<ScoreOverride> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            reflections: fetch(FetchDescriptor<Reflection>(predicate: #Predicate<Reflection> { $0.scope == key || dayKeys.contains($0.scope) })),
            changes: changes(week),
            settings: weekSettings(week, items: weekItems, measures: weekMeasures, goalYear: goalYear)
        )
    }

    /// The settings a week reads (v9/v10): its archive grades, the goal year with its segments, results
    /// and entries and the stored category scores (`goalYear`), the mappings, the known sources and their
    /// day files of the week; the reading list only when a measure or item of the week reads from it.
    func weekSettings(_ week: WeekKey, items: [PlanItem], measures: [MeasureDefinition], goalYear: Bool = true) -> [AppSetting] {
        let sources = settings(keys: [ExchangeInbox.sourcesKey])
        // Every copy of `x.sources` counts (two devices may have written one each before they synced).
        let sourceIDs: [String] = ExchangeSourceList.merged(sources.map(\.value)).ids
        // HEALTHSHARE: also the sharing's state and the week's shared days (`HealthShareWeek` counts them where the gate allows).
        let shareKeys: [String] = [HealthShare.stateKey] + HealthShare.keys(week: week)
        var result = sources + settings(keys: [ArchiveWeek.settingKey(week)] + ExchangeInbox.keys(sources: sourceIDs, week: week) + shareKeys)
        result += settings(prefix: LinkRule.prefix)
        if goalYear {
            result += settings(prefix: "goal.") + settings(prefix: GoalTrack.settingPrefix)
        } else {
            result += settings(keys: TrackerStore.goalPeriodKeys)
        }
        let readsList = measures.contains { MeasureSource(raw: $0.sourceRaw).listKind != nil }
            || items.contains { MeasureSource(raw: $0.measureCode).listKind != nil }
        if readsList { result += settings(prefix: "list.") }
        return result
    }

    /// The widget snapshot (R4): today, plus tomorrow written ahead, so the widget can switch at
    /// midnight by itself. v11 P2.14: tomorrow in the same week reads the week once and builds it twice.
    /// P8.13: no tomorrow ahead that begins a new week without a plan – the widget falls back to "Neuer Tag"
    /// instead of showing "Kein Plan" on Monday morning.
    func widgetSummary(today: DayKey) -> TodaySummary {
        let tomorrow = today.adding(days: 1)
        let inputs: WeekInputs = weekInputs(for: today.week, goalYear: false)
        let current: WeekContext = inputs.context(today: today)
        let nextContext: WeekContext = tomorrow.week == today.week
            ? inputs.context(today: tomorrow)
            : weekContext(for: tomorrow.week, today: tomorrow, goalYear: false)
        let nextDay: [TodaySummary]? = (tomorrow.week != today.week && !nextContext.hasPlan) ? nil : [nextContext.todaySummary()]
        return current.todaySummary().with { $0.nextDay = nextDay }
    }

    /// Writes the widget snapshot (R4, R84). The Mac never writes, neither do in-memory stores.
    func publishWidget(today: DayKey = .today()) {
        #if os(macOS)
        return
        #else
        guard !isInMemory else { return }
        WidgetBridge.publish(widgetSummary(today: today))
        #endif
    }

    /// Whether a week has at least one item (one indexed lookup).
    private func hasItems(_ week: WeekKey) -> Bool {
        let key = week.string
        var descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        return !fetch(descriptor).isEmpty
    }

    /// The most recent week that has a plan, for "copy last week's report". Candidates come from the
    /// small week table; each is checked with one narrow query (R84).
    func latestPlannedWeek(before week: WeekKey) -> WeekKey? {
        // Every plan import and every new item creates the week row (`ensurePlan`).
        let candidates = Set(allPlans().filter { $0.deletedAt == nil }.compactMap(\.week)).filter { $0 < week }.sorted(by: >)
        return candidates.first { hasItems($0) }
    }

    /// R56: the week a new plan for `target` starts from.
    func planningSourceWeek(for target: WeekKey) -> WeekKey? {
        latestPlannedWeek(before: target)
    }

    /// R56/R91: the one place that builds the planning prompt – structure, the source week's
    /// measurements (if the target has none yet), its report and plan changes, its plan as CSV and
    /// the trend of the last four weeks.
    func planningPrompt(for target: WeekKey, today: DayKey) -> String {
        let structure = weekContext(for: target, today: today)
        var measures = structure.measures.compactMap(\.record)
        var report: String?
        var changes: [PlanChangeRecord] = []
        var currentPlan: String?
        var trend: [String] = []
        let source = planningSourceWeek(for: target)
        if let source {
            let previous = weekContext(for: source, today: today)
            if measures.isEmpty { measures = previous.measures.compactMap(\.record) }
            // HEALTHSHARE: without the Health values another device shares – a prompt keeps hiding them (§1.4.7).
            report = WeekReport.markdown(previous.reportInput(sharedHealth: false))
            changes = previous.changes.compactMap(\.record)
            currentPlan = PlanCSV.export(exportDocument(weeks: [source]).planOnly(week: source))
            trend = (0..<4).reversed().map { offset in trendLine(source.adding(weeks: -offset), today: today) }
        }
        let goals = structure.data.goals.isEmpty ? Template.goals : structure.data.goals
        let categories = structure.data.categories.isEmpty ? Template.categories : structure.data.categories
        // v11 P3.4: the target week's days already set in the app ("Schon eingetragen für KW48: Fr 27.11. Urlaub").
        let setDays: [DayRecord] = structure.days.values.compactMap(\.record)
            .filter { !$0.dayType.trimmingCharacters(in: .whitespaces).isEmpty || !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.day < $1.day }
        AppLog.info("Planning prompt built for \(target.string)", category: "import")
        // v10 (§1.2.5): where the goals' results stand – for information, without Health values.
        return PlanPrompt.text(for: target, goals: goals, categories: categories, measures: measures, lastWeekReport: report,
                               changes: changes, currentPlan: currentPlan, currentPlanWeek: source, trend: trend,
                               results: resultLines(today: today), setDays: setDays)
    }

    /// "KW44: Wertung 7,1 · 22 von 28 PH" (without a score "–").
    private func trendLine(_ week: WeekKey, today: DayKey) -> String {
        let context = weekContext(for: week, today: today, goalYear: false)
        let score = context.plan?.historyScore ?? context.score.overall
        let worked = context.workTotals().powerHours
        let work: String
        if let target = context.workTarget {
            work = "\(Format.number(worked, decimals: 2)) von \(Format.number(target, decimals: 2)) PH"
        } else {
            work = Format.powerHours(worked)
        }
        // v8: a week that was all sick or holiday days has no score on purpose.
        if score == nil, context.score.isExcused { return "\(week.label): \(WeekScore.excusedText) · \(work)" }
        return "\(week.label): Wertung \(Format.score(score)) · \(work)"
    }

    /// R92: the source week's plan as an import file for `target` (runs through the normal preview).
    func repeatPlanCSV(from source: WeekKey, to target: WeekKey) -> String {
        PlanCSV.export(exportDocument(weeks: [source]).repeated(from: source, to: target))
    }

    // MARK: Goals and structure

    /// Bini's 10 annual goals and 18 categories from the handover, if nothing is there yet.
    @discardableResult
    func seedStructure() -> Bool {
        guard liveGoals().isEmpty else { return false }
        // Older than any real record: should the person's own structure still arrive from iCloud
        // (a new device before its first sync), their copy wins `latest(by:)` everywhere.
        let seeded = Date(timeIntervalSince1970: 0)
        for record in Template.goals {
            let goal = AnnualGoal(record)
            goal.createdAt = seeded
            goal.modifiedAt = seeded
            context.insert(goal)
        }
        let existing = Set(liveCategories().map(\.key))
        for record in Template.categories where !existing.contains(record.key) {
            let category = TrackCategory(record)
            category.createdAt = seeded
            category.modifiedAt = seeded
            context.insert(category)
        }
        AppLog.info("Goal structure created (10 goals, 18 categories)", category: "store")
        save()
        return true
    }

    func update(_ goal: AnnualGoal, title: String, details: String) {
        goal.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.details = details
        goal.touch()
        save()
    }

    func update(_ category: TrackCategory, title: String, details: String) {
        category.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        category.details = details
        category.touch()
        save()
    }

    // MARK: Weeks and days

    /// Writers edit the copy that `mergeDuplicates` keeps on every device (the oldest one), after
    /// folding in two devices' copies: a change never lands on a copy another device deletes.
    @discardableResult
    func ensurePlan(_ week: WeekKey) -> WeekPlan {
        let key = week.string
        let copies = fetch(FetchDescriptor<WeekPlan>(predicate: #Predicate<WeekPlan> { $0.weekKey == key && $0.deletedAt == nil }))
        if let existing = mergePlans(copies) { return existing }
        let created = WeekPlan(WeekRecord(week: week))
        context.insert(created)
        return created
    }

    @discardableResult
    func ensureDay(_ day: DayKey) -> PlanDay {
        let key = day.string
        let copies = fetch(FetchDescriptor<PlanDay>(predicate: #Predicate<PlanDay> { $0.dayKey == key }))
        if let existing = mergeDays(copies) { return existing }
        let created = PlanDay(dayKey: day.string)
        context.insert(created)
        return created
    }

    func setDayInfo(_ day: DayKey, type: String, note: String) {
        let info = ensureDay(day)
        info.dayType = type.trimmingCharacters(in: .whitespaces)
        info.note = note
        info.modifiedAt = Date()
        save()
        // v8: a sick or holiday day gets no evening reminder – the app plans them again.
        NotificationCenter.default.post(name: TrackerStore.dayInfoChanged, object: nil, userInfo: ["day": day.string])
    }

    /// v8: posted after `setDayInfo` (userInfo "day": "2026-11-20"); `AppModel` plans the reminders again.
    static let dayInfoChanged = Notification.Name("thalia.dayInfoChanged")

    /// v8: only the day's type, the note stays ("Krank" from a menu).
    func setDayType(_ day: DayKey, type: String) {
        setDayInfo(day, type: type, note: planDay(day)?.note ?? "")
    }

    func updatePlan(_ week: WeekKey, title: String, details: String) {
        let plan = ensurePlan(week)
        plan.title = title
        plan.details = details
        plan.touch()
        save()
    }

    /// The deliberate end of the day.
    func closeDay(_ day: DayKey) {
        let info = ensureDay(day)
        info.closedAt = Date()
        info.modifiedAt = Date()
        AppLog.info("Day closed", category: "review")
        save()
    }

    /// v11 P2.7: opens the copy every device keeps (`ensureDay` folds two devices' copies first) – opening
    /// the newest copy only lost against the merge's "closed wins".
    func reopenDay(_ day: DayKey) {
        guard planDay(day) != nil else { return }
        let info = ensureDay(day)
        info.closedAt = nil
        info.modifiedAt = Date()
        save()
    }

    /// Closes the week and keeps its score (quotas that weren't reached now count).
    /// v11 P2.1 (b), KR1-5: Mac, Watch and iPad keep their own score (closing needs one) and ask the iPhone
    /// to score it again with `force` – closing is the week's first scoring, also in an earlier segment.
    func closeWeek(_ week: WeekKey) {
        let plan = ensurePlan(week)
        plan.closedAt = Date()
        plan.touch()
        saveQuietly()
        storeFinalScore(plan)
        if !HealthDevice.scoresHealth && !isInMemory {
            withoutUndo { writeRescoreRequest(week, force: true) }
        }
        AppLog.info("Week closed", category: "review")
        save()
    }

    func reopenWeek(_ week: WeekKey) {
        // v11 P2.7: the copy every device keeps (two devices' copies folded first).
        guard self.plan(week) != nil else { return }
        let plan = ensurePlan(week)
        plan.closedAt = nil
        plan.finalScore = nil
        plan.finalGoalScores = ""
        plan.finalGoalsScored = 0
        plan.touch()
        // v10: the computed category scores go with the final score (the week counts live again); those
        // of a paper week with only a score were never computed and stay.
        if hasItems(week) || archiveGrades(week) != nil { writeCategoryScores([:], week: week) }
        save()
    }

    // MARK: Marks

    func setMark(_ mark: Mark?, item: PlanItem, day: DayKey, note: String? = nil) {
        writeMark(mark, item: item, day: day, note: note)
        save()
    }

    /// Several copies of one mark (written on two devices before they synced): keep the newest – its
    /// value counts, also an empty one (v10: a cleared mark is what keeps a connected app's ✓ away,
    /// Grundregel 1; every screen already reads the newest copy) – fill only an empty note from the
    /// newest copy that has one, delete the rest. `existing` is sorted newest first.
    private func collapse(_ existing: [ItemMark]) -> ItemMark? {
        guard let target = existing.first else { return nil }
        for duplicate in existing.dropFirst() {
            if target.note.isEmpty, !duplicate.note.isEmpty { target.note = duplicate.note }
            context.delete(duplicate)
        }
        if existing.count > 1 { noteMaintenanceRemoval() }
        return target
    }

    private func writeMark(_ mark: Mark?, item: PlanItem, day: DayKey, note: String? = nil) {
        let weekKey = item.weekKey
        let code = item.code
        let dayKey = day.string
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> {
            $0.weekKey == weekKey && $0.itemCode == code && $0.dayKey == dayKey
        })).sorted { $0.modifiedAt > $1.modifiedAt }
        let target: ItemMark
        if let kept = collapse(existing) {
            target = kept
        } else {
            target = ItemMark(weekKey: weekKey, itemCode: code, dayKey: dayKey)
            context.insert(target)
        }
        target.valueRaw = mark?.rawValue ?? ""
        if let note { target.note = note }
        target.modifiedAt = Date()
    }

    /// R23: only the note – the recorded value stays as it is (a new mark keeps `valueRaw == ""`), so
    /// a note on a free day never writes the derived N/A.
    /// v10: an own mark – even one without a value – wins over a ✓ from a connected app (Grundregel 1).
    /// `derived`: the ✓ shown from the app (`WeekContext.isDerivedMark`) – a new mark for the note keeps
    /// it, so writing a note doesn't take the tick away.
    func setMarkNote(_ note: String, item: PlanItem, day: DayKey, derived: Mark? = nil) {
        let weekKey = item.weekKey
        let code = item.code
        let dayKey = day.string
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> {
            $0.weekKey == weekKey && $0.itemCode == code && $0.dayKey == dayKey
        })).sorted { $0.modifiedAt > $1.modifiedAt }
        let target: ItemMark
        if let kept = collapse(existing) {
            target = kept
        } else {
            target = ItemMark(weekKey: weekKey, itemCode: code, dayKey: dayKey)
            if let derived { target.valueRaw = derived.rawValue }
            context.insert(target)
        }
        target.note = note
        target.modifiedAt = Date()
        save()
    }

    /// "Vorschläge übernehmen" (R12). Returns what was recorded before, for Undo (`restoreMarks`).
    /// v11 P2.5: as `MarkSnapshot`s – Undo removes a mark that didn't exist before.
    @discardableResult
    func apply(suggestions: [(PlanItem, Mark)], day: DayKey) -> [MarkSnapshot] {
        let dayKey = day.string
        let weekKeys = Array(Set(suggestions.map { $0.0.weekKey }))
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.dayKey == dayKey }))
            .filter { weekKeys.contains($0.weekKey) }
            .latest(by: { "\($0.weekKey)|\($0.itemCode)" }, modified: \.modifiedAt)
        let previous: [MarkSnapshot] = suggestions.map { pair in
            let stored: ItemMark? = existing["\(pair.0.weekKey)|\(pair.0.code)"]
            return MarkSnapshot(item: pair.0, day: day, mark: stored?.mark, existed: stored != nil)
        }
        for (item, mark) in suggestions { writeMark(mark, item: item, day: day) }
        save()
        return previous
    }

    /// One tap for many (V4): sets every given item to `mark` (nil clears). Returns what was
    /// recorded before, for Undo (v11 P2.5: `MarkSnapshot`s).
    @discardableResult
    func setMarks(_ mark: Mark?, items: [PlanItem], day: DayKey) -> [MarkSnapshot] {
        let weekKey = day.week.string
        let dayKey = day.string
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.weekKey == weekKey && $0.dayKey == dayKey }))
            .latest(by: \.itemCode, modified: \.modifiedAt)
        let previous: [MarkSnapshot] = items.map { item in
            MarkSnapshot(item: item, day: day, mark: existing[item.code]?.mark, existed: existing[item.code] != nil)
        }
        for item in items { writeMark(mark, item: item, day: day) }
        save()
        return previous
    }

    /// v11 P2.5: puts marks back as they were – one that didn't exist before goes again (every copy), so no
    /// empty own mark is left that would hide a connected app's ✓. (The 1.9.0 forms with a day are gone, §0.9.)
    func restoreMarks(_ snapshots: [MarkSnapshot]) {
        for snapshot in snapshots {
            if snapshot.existed {
                writeMark(snapshot.mark, item: snapshot.item, day: snapshot.day)
            } else {
                deleteMarks(item: snapshot.item, day: snapshot.day)
            }
        }
        save()
    }

    /// Deletes every copy of an item's mark on a day (no save).
    private func deleteMarks(item: PlanItem, day: DayKey) {
        let weekKey = item.weekKey
        let code = item.code
        let dayKey = day.string
        for mark in fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> {
            $0.weekKey == weekKey && $0.itemCode == code && $0.dayKey == dayKey
        })) {
            context.delete(mark)
        }
    }

    /// "Bedingte Punkte zuerst abfragen" (U12.9): the situations that happened stay open to be
    /// marked, every other conditional item of the day becomes N/A.
    func settleConditionals(_ items: [PlanItem], occurred: Set<String>, day: DayKey) {
        for item in items where !occurred.contains(item.code) { writeMark(.notApplicable, item: item, day: day) }
        save()
    }

    // MARK: Measurements

    /// Adds one entry. Text and note are trimmed; without a value and without text nothing is
    /// stored (the returned entry is then not inserted).
    @discardableResult
    func addEntry(code: String, day: DayKey, value: Double?, text: String = "", estimate: Bool = false, note: String = "") -> MeasureEntry {
        let entry = MeasureEntry(code: code, dayKey: day.string, value: value)
        entry.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.isEstimate = estimate
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.recordedAt = Date()
        guard value != nil || !entry.text.isEmpty else { return entry }
        context.insert(entry)
        save()
        return entry
    }

    func update(_ entry: MeasureEntry, value: Double?, text: String, estimate: Bool, note: String) {
        entry.value = value
        entry.text = text
        entry.isEstimate = estimate
        entry.note = note
        entry.touch()
        save()
    }

    /// The definition of a measurement in the week of `day` (latest version).
    private func measureDefinition(code: String, day: DayKey) -> MeasureDefinition? {
        measures(day.week).filter { $0.code == code }.max { $0.modifiedAt < $1.modifiedAt }
    }

    /// Sets the day's value directly (the inline field and − / + on a tile, R2). Existing entries are
    /// changed, never deleted: a sum moves the difference onto the newest entry (going down, entries
    /// that fall to 0 go to the trash, newest first); last / average / max / min give the newest entry
    /// the value and trash the others; nil trashes all. Spending measurements are left alone (every
    /// spending has its own "Wofür"). The result undoes exactly with `undo(_:)`.
    @discardableResult
    func setDayValue(code: String, day: DayKey, value: Double?) -> DayValueChange {
        var change = DayValueChange()
        let record = measureDefinition(code: code, day: day)?.record
        if record?.isExpense == true { return change }
        let aggregation = record?.aggregation ?? .sum
        let current = entries(code: code, day: day).filter { $0.value != nil }
        let now = Date()

        func discard(_ entry: MeasureEntry) {
            change.edited.append(snapshot(entry))
            change.trashed.append(entry)
            entry.moveToTrash(now: now)
        }
        func edit(_ entry: MeasureEntry, to newValue: Double) {
            guard entry.value != newValue else { return }
            change.edited.append(snapshot(entry))
            entry.value = newValue
            entry.touch(now: now)
        }

        guard let value else {
            for entry in current { discard(entry) }
            if !change.isEmpty { save() }
            return change
        }
        guard let newest = current.last else {
            let created = MeasureEntry(code: code, dayKey: day.string, value: value)
            created.recordedAt = now
            context.insert(created)
            change.created.append(created)
            save()
            return change
        }

        if aggregation == .sum && value > 0 {
            let total = current.compactMap(\.value).reduce(0, +)
            var difference = value - total
            if difference > 1e-9 {
                edit(newest, to: (newest.value ?? 0) + difference)
            } else if difference < -1e-9 {
                for entry in current.reversed() {
                    let own = entry.value ?? 0
                    if own + difference <= 1e-9 {
                        discard(entry)
                        difference += own
                    } else {
                        edit(entry, to: own + difference)
                        difference = 0
                    }
                    if abs(difference) <= 1e-9 { break }
                }
            }
        } else {
            // The newest entry carries the value (also an explicit 0 for a sum), the others go.
            edit(newest, to: value)
            for entry in current.dropLast() { discard(entry) }
        }
        if !change.isEmpty { save() }
        return change
    }

    /// A text value typed in place (R2): the newest text entry is changed, further ones go to the
    /// trash; an empty (trimmed) text trashes all of them.
    @discardableResult
    func setDayText(code: String, day: DayKey, text: String) -> DayValueChange {
        var change = DayValueChange()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = entries(code: code, day: day).filter { !$0.text.isEmpty }
        let now = Date()
        if let newest = current.last, !trimmed.isEmpty {
            if newest.text != trimmed {
                change.edited.append(snapshot(newest))
                newest.text = trimmed
                newest.touch(now: now)
            }
            for entry in current.dropLast() {
                change.edited.append(snapshot(entry))
                change.trashed.append(entry)
                entry.moveToTrash(now: now)
            }
        } else if trimmed.isEmpty {
            for entry in current {
                change.edited.append(snapshot(entry))
                change.trashed.append(entry)
                entry.moveToTrash(now: now)
            }
        } else {
            let created = MeasureEntry(code: code, dayKey: day.string, value: nil)
            created.text = trimmed
            created.recordedAt = now
            context.insert(created)
            change.created.append(created)
        }
        if !change.isEmpty { save() }
        return change
    }

    /// Takes back a `setDayValue` / `setDayText` exactly: changed and trashed entries get their
    /// earlier state, new ones disappear.
    func undo(_ change: DayValueChange) {
        guard !change.isEmpty else { return }
        for snapshot in change.edited.reversed() { write(snapshot) }
        for entry in change.created { context.delete(entry) }
        save()
    }

    func snapshot(_ entry: MeasureEntry) -> EntrySnapshot {
        EntrySnapshot(entry: entry, value: entry.value, text: entry.text, note: entry.note, isEstimate: entry.isEstimate,
                      dayKey: entry.dayKey, recordedAt: entry.recordedAt, deletedAt: entry.deletedAt)
    }

    /// Value, text, note, estimate, day, time and trash state as they were.
    /// v11 P2.3: an entry moved back from another week scores that week again too.
    func restore(_ snapshot: EntrySnapshot) {
        let left: DayKey? = DayKey(snapshot.entry.dayKey)
        write(snapshot)
        commit(rescoring: TrackerStore.weeksLeft(left, for: DayKey(snapshot.dayKey)))
    }

    /// v11 P2.3: the week a record leaves when its day changes – `touchedWeeks()` only sees the new day.
    static func weeksLeft(_ old: DayKey?, for new: DayKey?) -> Set<WeekKey> {
        guard let old, old.week != new?.week else { return [] }
        return [old.week]
    }

    private func write(_ snapshot: EntrySnapshot) {
        let entry = snapshot.entry
        entry.value = snapshot.value
        entry.text = snapshot.text
        entry.note = snapshot.note
        entry.isEstimate = snapshot.isEstimate
        entry.dayKey = snapshot.dayKey
        entry.recordedAt = snapshot.recordedAt
        entry.deletedAt = snapshot.deletedAt
        entry.touch()
    }

    /// R46: changes amount (to the cent), "Wofür" (trimmed; an empty one keeps the old) and day of a
    /// spending. Returns the state before, for Undo (`restore(_:)`).
    @discardableResult
    func editExpense(_ entry: MeasureEntry, amount: Double, what: String, day: DayKey) -> EntrySnapshot {
        let before = snapshot(entry)
        let left: DayKey? = DayKey(entry.dayKey)
        let purpose = what.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.value = (amount * 100).rounded() / 100
        if !purpose.isEmpty { entry.note = purpose }
        entry.dayKey = day.string
        entry.touch()
        commit(rescoring: TrackerStore.weeksLeft(left, for: day))
        return before
    }

    /// R81: the most recent day value of a measurement in the `lookback` days before `day`.
    /// v10: the values that count, as in the week (`Measures.merged`): own entries, else a confirmed
    /// Health value, else the reading list's or a connected app's value.
    func lastValue(code: String, before day: DayKey, lookback: Int = 60) -> Double? {
        let keys = dayKeys(through: day.adding(days: -1), days: lookback)
        let own = fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            $0.code == code && $0.deletedAt == nil && keys.contains($0.dayKey)
        })).compactMap(\.record).filter { $0.value != nil }
        let health = fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> {
            $0.code == code && keys.contains($0.dayKey)
        })).compactMap(\.record)
        // HEALTHSHARE: Mac, watch and iPad also count the values the iPhone shares (an own Health value per day first).
        let shared: [EntryRecord] = sharedHealthEntries(code: code, dayKeys: keys, except: Set(health.map(\.key)))
        let definitions = fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> {
            $0.code == code && $0.deletedAt == nil
        })).latest(by: \.weekKey, modified: \.modifiedAt).compactMapValues(\.record)
        let computed = computedEntries(code: code, definitions: definitions, days: keys.compactMap { DayKey($0) })
        // HEALTHSHARE: own and shared Health values.
        let found = Measures.merged(own: own, health: health + shared, external: computed.entries, additive: computed.additive)
            .filter { $0.value != nil }
        guard let latestDay = found.map(\.day).max() else { return nil }
        let aggregation = (definitions[latestDay.week.string] ?? measureDefinition(code: code, day: latestDay)?.record)?.aggregation ?? .sum
        let values = found.filter { $0.day == latestDay }.sorted { $0.order < $1.order }.compactMap(\.value)
        return aggregation.apply(values)
    }

    /// v10: the computed day values of a measurement on `days` – the reading list (`list:<art>`) and the
    /// connected apps (`app:…`) – for the definition of each day's week (else the newest). `additive`:
    /// spending codes (own spendings add to the app's).
    func computedEntries(code: String, definitions: [String: MeasureRecord], days: [DayKey]) -> (entries: [EntryRecord], additive: Set<String>) {
        guard let newest = definitions.values.max(by: { $0.week < $1.week }) else { return ([], []) }
        let computed = definitions.values.contains { $0.source.listKind != nil || $0.source.appSource != nil }
        guard computed, let first = days.min(), let last = days.max() else { return ([], []) }
        var entries: [EntryRecord] = []
        var additive: Set<String> = []
        var reading: (items: [ListItem], progress: [ListProgress])?
        var appValues: [String: [DayKey: Double]] = [:]
        let categories = Set(liveCategories().map(\.key))
        for day in days {
            let record = definitions[day.week.string] ?? newest
            if record.source.listKind != nil {
                if reading == nil { reading = (listItems(), listProgress()) }
                let found = ListMath.entries(for: [record], items: reading?.items ?? [], progress: reading?.progress ?? [], days: [day])
                entries += found.filter { $0.code == code }
            } else if let source = record.source.appSource {
                let cacheKey = source.raw + "|" + record.categoryKey
                if appValues[cacheKey] == nil {
                    appValues[cacheKey] = ExchangeDerivation.series(source, inbox: inboxFiles(source: source.source, from: first, through: last),
                                                                    rules: linkRules(), categoryKey: record.categoryKey, known: categories)
                }
                if let value = appValues[cacheKey]?[day] { entries.append(EntryRecord(code: code, day: day, value: value)) }
                if source.summedKind == .spending { additive.insert(code) }
            }
        }
        return (entries, additive)
    }

    /// R41: moves an entry to another day (its time of day stays).
    func move(_ entry: MeasureEntry, to day: DayKey) {
        guard entry.dayKey != day.string else { return }
        let left: DayKey? = DayKey(entry.dayKey)
        entry.dayKey = day.string
        entry.touch()
        commit(rescoring: TrackerStore.weeksLeft(left, for: day))
    }

    func entries(code: String, day: DayKey) -> [MeasureEntry] {
        let key = day.string
        return fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> { $0.code == code && $0.dayKey == key && $0.deletedAt == nil }))
            .sorted { $0.recordedAt < $1.recordedAt }
    }

    /// Confirms an Apple Health value for a measurement (device-only, never synced).
    func adoptHealth(code: String, day: DayKey, value: Double) {
        let key = day.string
        for old in fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> { $0.code == code && $0.dayKey == key })) {
            context.delete(old)
        }
        context.insert(HealthValue(code: code, dayKey: key, value: value))
        save()
    }

    func removeHealth(code: String, day: DayKey) {
        let key = day.string
        for old in fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> { $0.code == code && $0.dayKey == key })) {
            context.delete(old)
        }
        save()
    }

    // MARK: Work (power-hours)

    @discardableResult
    func addWork(day: DayKey, categoryKey: String, task: String, powerHours: Double, result: String = "", nextStep: String = "") -> WorkBlock {
        let block = WorkBlock(dayKey: day.string, categoryKey: categoryKey, task: task.trimmingCharacters(in: .whitespacesAndNewlines),
                              powerHours: max(0.05, powerHours))
        block.result = result
        block.nextStep = nextStep
        context.insert(block)
        save()
        return block
    }

    func update(_ block: WorkBlock, categoryKey: String, task: String, powerHours: Double, result: String, nextStep: String, day: DayKey) {
        block.categoryKey = categoryKey
        // R21/K1: an empty description never replaces the existing one.
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { block.task = trimmed }
        block.powerHours = max(0.05, powerHours)
        block.minutes = Int(PowerHour.minutes(block.powerHours).rounded())
        block.result = result
        block.nextStep = nextStep
        let left: DayKey? = DayKey(block.dayKey)
        block.dayKey = day.string
        block.touch()
        commit(rescoring: TrackerStore.weeksLeft(left, for: day))
    }

    /// Changes only the amount of one entry (− / + in the list); its description stays.
    func setPowerHours(_ block: WorkBlock, _ powerHours: Double) {
        let value: Double = max(0.25, (powerHours * 100).rounded() / 100)
        block.powerHours = value
        block.minutes = Int(PowerHour.minutes(value).rounded())
        block.touch()
        save()
    }

    /// Edits only the description (inline in the list, V10). An empty (trimmed) description is
    /// refused – nothing is saved and the result is false (R21, K1).
    @discardableResult
    func setTask(_ block: WorkBlock, _ task: String) -> Bool {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard trimmed != block.task else { return true }
        block.task = trimmed
        block.touch()
        save()
        return true
    }

    /// Day keys of the last `days` days up to `day` (for narrow predicates).
    private func dayKeys(through day: DayKey, days: Int) -> [String] {
        (0..<max(1, days)).map { day.adding(days: -$0).string }
    }

    /// What earlier blocks of a category were for, in the last `days` days – most used first, then
    /// most recent (R32). Loaded once per sheet; typing only filters.
    func workSuggestions(categoryKey: String, limit: Int = 8, days: Int = 90) -> [String] {
        let keys = dayKeys(through: .today(), days: days)
        let blocks = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> {
            $0.categoryKey == categoryKey && $0.deletedAt == nil && keys.contains($0.dayKey)
        }))
        var counts: [String: (count: Int, last: Date)] = [:]
        for block in blocks where !block.task.isEmpty {
            let current = counts[block.task] ?? (count: 0, last: .distantPast)
            counts[block.task] = (count: current.count + 1, last: max(current.last, block.createdAt))
        }
        return counts.sorted { ($0.value.count, $0.value.last) > ($1.value.count, $1.value.last) }.prefix(limit).map(\.key)
    }

    /// What earlier spendings of a measurement were for (R32): the last `days` days up to `day`, most
    /// used first, then most recent; spellings that differ only in case count together.
    func expenseSuggestions(code: String, through day: DayKey, days: Int = 90, limit: Int = 12) -> [String] {
        let keys = dayKeys(through: day, days: days)
        let entries = fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            $0.code == code && $0.deletedAt == nil && keys.contains($0.dayKey)
        }))
        var counts: [String: (text: String, count: Int, last: Date)] = [:]
        for entry in entries {
            let text = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = text.lowercased()
            let current = counts[key] ?? (text: text, count: 0, last: .distantPast)
            let newer = entry.recordedAt > current.last
            counts[key] = (text: newer ? text : current.text, count: current.count + 1, last: max(current.last, entry.recordedAt))
        }
        return counts.values.sorted { ($0.count, $0.last) > ($1.count, $1.last) }.prefix(limit).map { $0.text }
    }

    /// The last three different power-hour combinations of the last 60 days, newest first (R33).
    func recentWorkCombos(limit: Int = 3) -> [WorkCombo] {
        let keys = dayKeys(through: .today(), days: 60)
        let blocks = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> {
            $0.deletedAt == nil && keys.contains($0.dayKey)
        })).sorted { $0.createdAt > $1.createdAt }
        var result: [WorkCombo] = []
        for block in blocks where !block.task.isEmpty && !block.categoryKey.isEmpty {
            let combo = WorkCombo(categoryKey: block.categoryKey, task: block.task, powerHours: block.hours)
            guard !result.contains(combo) else { continue }
            result.append(combo)
            if result.count >= limit { break }
        }
        return result
    }

    @discardableResult
    func trash(_ blocks: [WorkBlock]) -> [WorkBlock] {
        let now = Date()
        for block in blocks { block.moveToTrash(now: now) }
        save()
        return blocks
    }

    func restore(_ blocks: [WorkBlock]) {
        for block in blocks { block.restoreFromTrash() }
        save()
    }

    // MARK: Notes and reflections

    @discardableResult
    func addNote(day: DayKey, kind: NoteKind, text: String) -> DayNote {
        let note = DayNote(dayKey: day.string, kind: kind, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(note)
        save()
        return note
    }

    func update(_ note: DayNote, kind: NoteKind, text: String) {
        note.kindRaw = kind.rawValue
        note.text = text
        note.touch()
        save()
    }

    /// Changes kind, text and day of a note (R41: the day can be changed while editing).
    func update(_ note: DayNote, kind: NoteKind, text: String, day: DayKey) {
        note.kindRaw = kind.rawValue
        note.text = text
        note.dayKey = day.string
        note.touch()
        save()
    }

    @discardableResult
    func trash(_ notes: [DayNote]) -> [DayNote] {
        for note in notes { note.moveToTrash() }
        save()
        return notes
    }

    func restore(_ notes: [DayNote]) {
        for note in notes { note.restoreFromTrash() }
        save()
    }

    @discardableResult
    func trash(_ entries: [MeasureEntry]) -> [MeasureEntry] {
        for entry in entries { entry.moveToTrash() }
        save()
        return entries
    }

    func restore(_ entries: [MeasureEntry]) {
        for entry in entries { entry.restoreFromTrash() }
        save()
    }

    func setReflection(scope: String, field: String, text: String) {
        let existing = fetch(FetchDescriptor<Reflection>(predicate: #Predicate<Reflection> { $0.scope == scope && $0.field == field }))
            .sorted { $0.modifiedAt > $1.modifiedAt }
        let target: Reflection
        if let first = existing.first {
            guard first.text != text else { return }
            target = first
            for duplicate in existing.dropFirst() { context.delete(duplicate) }
        } else {
            guard !text.isEmpty else { return }
            target = Reflection(scope: scope, field: field)
            context.insert(target)
        }
        target.text = text
        target.modifiedAt = Date()
        save()
    }

    /// The person's own category score for a day; nil removes it.
    func setOverride(categoryKey: String, day: DayKey, score: Double?, reason: String) {
        let key = day.string
        let existing = fetch(FetchDescriptor<ScoreOverride>(predicate: #Predicate<ScoreOverride> {
            $0.categoryKey == categoryKey && $0.dayKey == key && $0.deletedAt == nil
        }))
        guard let score else {
            for old in existing { old.moveToTrash() }
            save()
            return
        }
        let target = existing.first ?? {
            let created = ScoreOverride(categoryKey: categoryKey, dayKey: key, score: score)
            context.insert(created)
            return created
        }()
        for duplicate in existing.dropFirst() { duplicate.moveToTrash() }
        target.score = min(10, max(0, score))
        target.reason = reason
        target.touch()
        save()
    }

    // MARK: Items

    @discardableResult
    func addItem(week: WeekKey, categoryKey: String, title: String, details: String, days: DayMask, schedule: ItemSchedule,
                 target: Target? = nil, measure: String = "", knockout: Bool = false, carryOver: Bool = true) -> PlanItem {
        let existing = items(week)
        let position = (existing.filter { $0.categoryKey == categoryKey }.map(\.position).max() ?? 0) + 1
        // A code is taken when any item of the week has it – also one in "Zuletzt gelöscht" – or a
        // mark still refers to it; otherwise a new item would inherit a deleted item's marks.
        let key = week.string
        let used = Set(fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key })).map(\.code)
                       + fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.weekKey == key })).map(\.itemCode))
        var number = position
        var code = "\(categoryKey)-" + String(format: "%02d", number)
        while used.contains(code) {
            number += 1
            code = "\(categoryKey)-" + String(format: "%02d", number)
        }
        let record = ItemRecord(week: week, code: code, categoryKey: categoryKey, position: position,
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines), details: details,
                                days: days, schedule: schedule, target: target, measure: measure, knockout: knockout)
        let item = PlanItem(record)
        context.insert(item)
        ensurePlan(week)
        recordChange(.added, record, carryOver: carryOver)
        save()
        return item
    }

    func update(_ item: PlanItem, with record: ItemRecord, carryOver: Bool = true) {
        item.update(from: record)
        item.touch()
        recordChange(.edited, record, carryOver: carryOver)
        save()
    }

    /// v11 P2.6: every other live copy of an item (same week and code, two devices offline) goes with it –
    /// one plan change per item. Returns everything trashed (Undo brings the copies back too).
    @discardableResult
    func trash(_ items: [PlanItem], carryOver: Bool = true) -> [PlanItem] {
        let now = Date()
        var trashed: [PlanItem] = []
        var seen: Set<ObjectIdentifier> = []
        for item in items {
            if let record = item.record { recordChange(.deleted, record, carryOver: carryOver) }
            for copy in [item] + liveCopies(of: item) where seen.insert(ObjectIdentifier(copy)).inserted {
                copy.moveToTrash(now: now)
                trashed.append(copy)
            }
        }
        save()
        return trashed
    }

    /// The other live copies of an item in its week (same code).
    private func liveCopies(of item: PlanItem) -> [PlanItem] {
        let key = item.weekKey
        let code = item.code
        return fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> {
            $0.weekKey == key && $0.code == code && $0.deletedAt == nil
        })).filter { $0 !== item }
    }

    /// v11 P2.6: the titles of trashed items whose week has a live copy (same code) – restoring one makes two;
    /// "Zuletzt gelöscht" asks first.
    func restoreConflicts(_ items: [PlanItem]) -> [String] {
        var titles: [String] = []
        for item in items where !liveCopies(of: item).isEmpty && !titles.contains(item.title) { titles.append(item.title) }
        return titles
    }

    /// "Doch wichtig / doch Nebensache" (V2.4.1): recorded for the next prompt.
    func setSecondary(_ item: PlanItem, _ secondary: Bool) {
        guard var record = item.record, record.secondary != secondary else { return }
        record.secondary = secondary
        item.update(from: record)
        item.touch()
        self.record(PlanChangeRecord(week: record.week, kind: .edited, target: .item, code: record.code,
                                     title: "\(record.categoryKey) \(record.title)",
                                     detail: "Gewichtung von mir geändert: " + (secondary ? "Nebensache" : "wichtig"), carryOver: true))
        save()
    }

    func setSecondary(_ measure: MeasureDefinition, _ secondary: Bool) {
        guard var record = measure.record, record.secondary != secondary else { return }
        record.secondary = secondary
        measure.update(from: record)
        measure.touch()
        self.record(PlanChangeRecord(week: record.week, kind: .edited, target: .measure, code: record.code, title: record.title,
                                     detail: "Gewichtung von mir geändert: " + (secondary ? "Nebensache" : "wichtig"), carryOver: true))
        save()
    }

    func restore(_ items: [PlanItem]) {
        for item in items {
            item.restoreFromTrash()
            forgetDeletion(week: item.weekKey, target: .item, code: item.code)
        }
        save()
    }

    // MARK: Measurements (definitions)

    @discardableResult
    func addMeasure(week: WeekKey, categoryKey: String, title: String, details: String = "", unit: String, target: Target?,
                    period: TargetPeriod = .day, days: DayMask = .everyDay, carryOver: Bool = true) -> MeasureDefinition {
        let existing = measures(week)
        let codes = Set(existing.map(\.code))
        let base = Self.code(for: title)
        var code = base
        var counter = 2
        while codes.contains(code) {
            code = "\(base)\(counter)"
            counter += 1
        }
        let position = (existing.map(\.position).max() ?? 0) + 1
        // R77: "PH" is never a bare number – it becomes a work measurement of the category.
        let isPowerHours = Units.normalized(unit) == "ph"
        let record = MeasureRecord(week: week, code: code, categoryKey: categoryKey, position: position,
                                   title: title.trimmingCharacters(in: .whitespacesAndNewlines), details: details,
                                   unit: unit, target: target, period: period,
                                   source: isPowerHours ? .work(category: categoryKey) : .manual, days: days)
        let measure = MeasureDefinition(record)
        context.insert(measure)
        ensurePlan(week)
        recordChange(.added, record, carryOver: carryOver)
        save()
        return measure
    }

    func update(_ measure: MeasureDefinition, with record: MeasureRecord, carryOver: Bool = true) {
        measure.update(from: record)
        measure.touch()
        recordChange(.edited, record, carryOver: carryOver)
        save()
    }

    /// v11 P2.6: every other live copy of a measurement (same week and code) goes with it – one plan change
    /// per measurement. Returns everything trashed (Undo brings the copies back too).
    @discardableResult
    func trash(_ measures: [MeasureDefinition], carryOver: Bool = true) -> [MeasureDefinition] {
        let now = Date()
        var trashed: [MeasureDefinition] = []
        var seen: Set<ObjectIdentifier> = []
        for measure in measures {
            if let record = measure.record { recordChange(.deleted, record, carryOver: carryOver) }
            for copy in [measure] + liveCopies(of: measure) where seen.insert(ObjectIdentifier(copy)).inserted {
                copy.moveToTrash(now: now)
                trashed.append(copy)
            }
        }
        save()
        return trashed
    }

    /// The other live copies of a measurement in its week (same code).
    private func liveCopies(of measure: MeasureDefinition) -> [MeasureDefinition] {
        let key = measure.weekKey
        let code = measure.code
        return fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> {
            $0.weekKey == key && $0.code == code && $0.deletedAt == nil
        })).filter { $0 !== measure }
    }

    /// v11 P2.6: the titles of trashed measurements whose week has a live copy (same code).
    func restoreConflicts(_ measures: [MeasureDefinition]) -> [String] {
        var titles: [String] = []
        for measure in measures where !liveCopies(of: measure).isEmpty && !titles.contains(measure.title) { titles.append(measure.title) }
        return titles
    }

    func restore(_ measures: [MeasureDefinition]) {
        for measure in measures {
            measure.restoreFromTrash()
            forgetDeletion(week: measure.weekKey, target: .measure, code: measure.code)
        }
        save()
    }

    /// "Liegestütze am Abend" → "liegestuetze_am_abend" (stable across weeks, like the CSV codes).
    static func code(for title: String) -> String {
        let replaced = title.lowercased()
            .replacingOccurrences(of: "ä", with: "ae").replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue").replacingOccurrences(of: "ß", with: "ss")
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
        let parts = replaced.map { allowed.contains($0) ? String($0) : " " }.joined()
            .split(separator: " ").prefix(4)
        let code = parts.joined(separator: "_")
        return code.isEmpty ? "wert" : String(code.prefix(32))
    }

    // MARK: Plan changes (U14)

    func changes(_ week: WeekKey) -> [PlanChange] {
        let key = week.string
        return fetch(FetchDescriptor<PlanChange>(predicate: #Predicate<PlanChange> { $0.weekKey == key }))
            .sorted { $0.createdAt < $1.createdAt }
    }

    func setCarryOver(_ change: PlanChange, _ carryOver: Bool) {
        change.carryOver = carryOver
        change.modifiedAt = Date()
        save()
    }

    private func recordChange(_ kind: PlanChangeRecord.Kind, _ item: ItemRecord, carryOver: Bool) {
        var detail = [item.days.label, item.schedule.label]
        if let target = item.target { detail.append(target.label) }
        record(PlanChangeRecord(week: item.week, kind: kind, target: .item, code: item.code,
                                title: "\(item.categoryKey) \(item.title)", detail: detail.joined(separator: " · "), carryOver: carryOver))
    }

    private func recordChange(_ kind: PlanChangeRecord.Kind, _ measure: MeasureRecord, carryOver: Bool) {
        var detail = [measure.unit.isEmpty ? "Zahl" : measure.unit]
        if let target = measure.target { detail.append("\(target.label) \(measure.period.label)") }
        if measure.days != .everyDay { detail.append(measure.days.label) }
        record(PlanChangeRecord(week: measure.week, kind: kind, target: .measure, code: measure.code,
                                title: measure.title, detail: detail.joined(separator: " · "), carryOver: carryOver))
    }

    /// One line per thing and week: "neu" stays "neu" when edited again, "neu" then "gelöscht" is no change at all.
    private func record(_ change: PlanChangeRecord) {
        let existing = changes(change.week).filter { $0.targetRaw == change.target.rawValue && $0.code == change.code }
        if let previous = existing.last, let previousKind = PlanChangeRecord.Kind(rawValue: previous.kindRaw) {
            for duplicate in existing.dropLast() { context.delete(duplicate) }
            switch (previousKind, change.kind) {
            case (.added, .deleted):
                context.delete(previous)
                return
            case (.added, _):
                previous.title = change.title
                previous.detail = change.detail
            default:
                previous.kindRaw = change.kind.rawValue
                previous.title = change.title
                previous.detail = change.detail
            }
            previous.carryOver = change.carryOver
            previous.modifiedAt = Date()
        } else {
            context.insert(PlanChange(change))
        }
    }

    private func forgetDeletion(week: String, target: PlanChangeRecord.Target, code: String) {
        let targetRaw = target.rawValue
        let deleted = PlanChangeRecord.Kind.deleted.rawValue
        let matches = fetch(FetchDescriptor<PlanChange>(predicate: #Predicate<PlanChange> {
            $0.weekKey == week && $0.targetRaw == targetRaw && $0.code == code && $0.kindRaw == deleted
        }))
        for change in matches { context.delete(change) }
    }

    // MARK: History (R88, R93, R95)

    /// R88: power-hours per week against the sum of that week's weekly PH targets, oldest first.
    func workHistory(through week: WeekKey, weeks: Int = 8) -> [WeekWorkPoint] {
        (0..<max(1, weeks)).reversed().map { offset -> WeekWorkPoint in
            let shown = week.adding(weeks: -offset)
            let keys = shown.days.map(\.string)
            let blocks = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> {
                keys.contains($0.dayKey) && $0.deletedAt == nil
            }))
            let powerHours = blocks.reduce(0) { $0 + $1.hours }
            // v8: the target as it counted that week – scaled for sick and holiday days.
            let dayInfo = fetch(FetchDescriptor<PlanDay>(predicate: #Predicate<PlanDay> { keys.contains($0.dayKey) }))
                .latest(by: \.dayKey, modified: \.modifiedAt)
            let excused: Set<DayKey> = DayTypes.excusedDays(shown.days) { dayInfo[$0.string]?.dayType ?? "" }
            let free: Set<DayKey> = Set(shown.days.filter { DayTypes.isWorkFree(dayInfo[$0.string]?.dayType ?? "") })
            // A measurement whose days were all excused has no target that week (not scored, Decision 4).
            let targets: [Double] = measures(shown).latest(by: \.code, modified: \.modifiedAt).values.compactMap { measure in
                guard let record = measure.record, record.isWork, record.period == .week,
                      Measures.targetShare(for: record, week: shown, excused: excused, workFree: free) > 1e-9 else { return nil }
                return Measures.effectiveTarget(for: record, week: shown, excused: excused, workFree: free)?.scaleMax
            }
            return WeekWorkPoint(week: shown, powerHours: powerHours, target: targets.isEmpty ? nil : targets.reduce(0, +))
        }
    }

    /// R93: a measurement's day values from `start` through `end` (days without a value left out).
    func measureSeries(code: String, from start: DayKey, through end: DayKey) -> [SeriesPoint] {
        guard start <= end else { return [] }
        let keys = (0...(end.ordinal - start.ordinal)).map { start.adding(days: $0).string }
        let definitions = fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> {
            $0.code == code && $0.deletedAt == nil
        })).latest(by: \.weekKey, modified: \.modifiedAt).compactMapValues(\.record)
        guard let newest = definitions.values.max(by: { $0.week < $1.week }) else { return [] }
        // v10: own entries replace everything else of their day, Health values the computed ones (the
        // reading list, connected apps) – as in the week (`Measures.merged`).
        let own = fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            $0.code == code && $0.deletedAt == nil && keys.contains($0.dayKey)
        })).compactMap(\.record)
        let health = fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> {
            $0.code == code && keys.contains($0.dayKey)
        })).compactMap(\.record)
        // HEALTHSHARE: Mac, watch and iPad also count the values the iPhone shares (an own Health value per day first) – the
        // measure's chart and the results fed by it (`resultSeries`).
        let shared: [EntryRecord] = sharedHealthEntries(code: code, dayKeys: keys, except: Set(health.map(\.key)))
        let computed = computedEntries(code: code, definitions: definitions, days: keys.compactMap { DayKey($0) })
        // HEALTHSHARE: own and shared Health values.
        let records = Measures.merged(own: own, health: health + shared, external: computed.entries, additive: computed.additive)
        var work: [WorkRecord] = []
        let categories: Set<String> = Set(definitions.values.compactMap { record -> String? in
            if case .work(let category) = record.source { return category }
            return nil
        })
        if !categories.isEmpty {
            work = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> {
                $0.deletedAt == nil && keys.contains($0.dayKey)
            })).filter { categories.contains($0.categoryKey) }.compactMap(\.record)
        }
        return keys.compactMap { key -> SeriesPoint? in
            guard let day = DayKey(key) else { return nil }
            let record = definitions[day.week.string] ?? newest
            guard let value = Measures.dayValue(record, on: day, entries: records, work: work) else { return nil }
            return SeriesPoint(day: day, value: value)
        }
    }

    /// R11/R93: a goal's stored score per closed week up to `week` – one point per week (newest plan).
    func goalScoreHistory(goalKey: String, through week: WeekKey) -> [WeekScorePoint] {
        allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt).values
            .compactMap { plan -> WeekScorePoint? in
                guard let shown = plan.week, shown <= week, let score = plan.finalGoalScoreMap[goalKey] else { return nil }
                return WeekScorePoint(week: shown, score: score)
            }
            .sorted { $0.week < $1.week }
    }

    /// v8 (Decision 5): weeks from `start` through `week` with a plan but no score because every day
    /// with something planned was a sick or holiday day – the goal charts show them as
    /// "entschuldigt" instead of a gap (the review finds them the same way).
    func excusedWeeks(from start: WeekKey? = nil, through week: WeekKey, today: DayKey = DayKey.today()) -> Set<WeekKey> {
        var result: Set<WeekKey> = []
        for plan in allPlans().filter({ $0.deletedAt == nil }).latest(by: \.weekKey, modified: \.modifiedAt).values {
            guard let shown = plan.week, shown <= week, plan.historyScore == nil else { continue }
            if let start, shown < start { continue }
            if weekContext(for: shown, today: today, goalYear: false).score.isExcused { result.insert(shown) }
        }
        return result
    }

    /// R95: the goal review from the start of the goal year through `week` (weeks with a plan only).
    /// v9: a closed archive week (no items, goal values from its grades, decision 5) counts with its
    /// stored goal values too; a paper week with only a score has none and stays out.
    /// v10 (§1.4.3): `start` – from a segment's first week instead ("Abschnitt" in the goal review).
    /// `sharedHealth` false (the copy for the goal-review conversation): without the Health values another device shares
    /// (§1.4.7).
    func periodReport(period: GoalPeriod, through week: WeekKey, from start: WeekKey? = nil, sharedHealth: Bool = true) -> PeriodReport {
        let today = DayKey.today()
        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        var inputs: [WeekReportInput] = []
        var goalScores: [WeekKey: [String: Double]] = [:]
        var shown = max(start ?? period.start.week, period.start.week)
        while shown <= week {
            let scores: [String: Double] = plans[shown.string]?.finalGoalScoreMap ?? [:]
            if hasItems(shown) || !scores.isEmpty {
                inputs.append(weekContext(for: shown, today: today, goalYear: false).reportInput(sharedHealth: sharedHealth))
                if !scores.isEmpty { goalScores[shown] = scores }
            }
            shown = shown.adding(weeks: 1)
        }
        return PeriodReport(weeks: inputs, goalScores: goalScores, ideas: parkedIdeas().compactMap(\.record))
    }

    /// R95: every parked idea (note kind "Idee"), newest first.
    func parkedIdeas() -> [DayNote] {
        let kind = NoteKind.idea.rawValue
        return fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { $0.kindRaw == kind && $0.deletedAt == nil }))
            .sorted { ($0.dayKey, $0.createdAt) > ($1.dayKey, $1.createdAt) }
    }

    // MARK: Spending (R97)

    /// The week's spending measurement; with `create`, "Ausgaben" (€, area of goal 8, carried over)
    /// is created when the week has none – like the button in the spending sheet.
    func expenseMeasure(week: WeekKey, create: Bool) -> MeasureDefinition? {
        let existing = measures(week).filter { $0.record?.isExpense ?? false }.sorted { ($0.position, $0.code) < ($1.position, $1.code) }
        if let first = existing.first { return first }
        guard create else { return nil }
        let category = liveCategories().filter { $0.goalKey == "8" }
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
            .first?.key ?? ""
        return addMeasure(week: week, categoryKey: category, title: "Ausgaben", unit: "€", target: nil, period: .day, carryOver: true)
    }

    /// R97: one spending with what it was for (K2). nil when the amount isn't positive or "Wofür"
    /// is empty; creates the spending measurement if needed.
    @discardableResult
    func addExpense(_ amount: Double, what: String, day: DayKey) -> MeasureEntry? {
        let purpose = what.trimmingCharacters(in: .whitespacesAndNewlines)
        guard amount > 0, amount.isFinite, !purpose.isEmpty,
              let measure = expenseMeasure(week: day.week, create: true) else { return nil }
        return addEntry(code: measure.code, day: day, value: (amount * 100).rounded() / 100, note: purpose)
    }

    // MARK: Duplicates (R28)

    /// Merges days and weeks that exist twice after an offline sync: the oldest record stays and
    /// gets the merged values ("closed" wins, filled-in text beats empty), the others are deleted.
    /// Returns the number of merged groups. v11 P2.13: `maintenance(today:)` runs it in full once a day (nil)
    /// and otherwise – like after every sync – for the weeks from `minWeek` on (`since`): marks of those weeks
    /// and imported blocks of their days through IN predicates, days and weeks in full (few); restored copies
    /// (`mergeImportedCopies`, P3.2) and the template goals and categories always in full. Maintenance:
    /// without Undo, and a merge clears the undo stack (P2.4 – ⌘Z must not reach a deleted copy).
    @discardableResult
    func mergeDuplicates(since minWeek: WeekKey? = nil) -> Int {
        withoutUndo { mergeDuplicatesNow(since: minWeek) }
    }

    private func mergeDuplicatesNow(since minWeek: WeekKey?) -> Int {
        var merged = 0
        // v11 P3.2: restored copies with their originals first (before the import-id merge below).
        merged += mergeImportedCopies()
        merged += mergeTemplateCopies()
        let days = Dictionary(grouping: fetch(FetchDescriptor<PlanDay>()), by: \.dayKey)
        for group in days.values where group.count > 1 {
            if mergeDays(group) != nil { merged += 1 }
        }
        let plans = Dictionary(grouping: allPlans().filter { $0.deletedAt == nil }, by: \.weekKey)
        for group in plans.values where group.count > 1 {
            if mergePlans(group) != nil { merged += 1 }
        }
        // One mark per item and day: a tick from one device and a note from another stay together.
        let recentWeeks: [String] = minWeek.map { TrackerStore.weekKeys(from: $0, through: DayKey.today().week) } ?? []
        let recentDays: [String] = recentWeeks.compactMap(WeekKey.init).flatMap(\.days).map(\.string)
        let allMarks: [ItemMark] = minWeek == nil
            ? fetch(FetchDescriptor<ItemMark>())
            : fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { recentWeeks.contains($0.weekKey) }))
        let marks = Dictionary(grouping: allMarks, by: { "\($0.weekKey)|\($0.itemCode)|\($0.dayKey)" })
        for group in marks.values where group.count > 1 {
            if collapse(group.sorted { $0.modifiedAt > $1.modifiedAt }) != nil { merged += 1 }
        }
        // v10: blocks with the same import id ("Übernehmen" of the same derived block on two devices, the
        // same imported row twice) count once.
        let imported: [WorkBlock] = minWeek == nil
            ? fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { $0.importID != "" && $0.deletedAt == nil }))
            : fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> {
                $0.importID != "" && $0.deletedAt == nil && recentDays.contains($0.dayKey)
            }))
        for group in Dictionary(grouping: imported, by: \.importID).values where group.count > 1 {
            if mergeWork(group) != nil { merged += 1 }
        }
        // v11 P3.5 (4): a dated record moved to another day keeps one key – an older backup's key goes.
        let stale: [String] = minWeek == nil ? staleRecordKeys(GoalEntry.self) + staleRecordKeys(ListProgress.self) : []
        if !stale.isEmpty {
            var ignored = RecordChange()
            let now = Date()
            for key in stale { writeSetting(key, nil, now: now, change: &ignored) }
            merged += stale.count
            noteMaintenanceRemoval()
        }
        guard merged > 0 else { return 0 }
        save()
        AppLog.info("Merged \(merged) duplicate day/week/mark/work record(s)", category: "store")
        return merged
    }

    /// "2026-W45" … "2026-W48": the week keys from `start` through `end` (at least `start`).
    nonisolated static func weekKeys(from start: WeekKey, through end: WeekKey) -> [String] {
        var keys: [String] = [start.string]
        var week = start.adding(weeks: 1)
        while week <= end {
            keys.append(week.string)
            week = week.adding(weeks: 1)
        }
        return keys
    }

    /// v11 P3.5 (4): keys of a dated record type (`goal.entry.`, `list.progress.`) whose id has a newer copy
    /// under another key – the copy `SettingRecords.decode` doesn't read (the newest `modifiedAt`, a tie: the
    /// greater key).
    private func staleRecordKeys<T: SettingRecord>(_ type: T.Type) -> [String] {
        let newest = SettingRecords.newest(settings(prefix: T.prefix).map(\.stored))
        var best: [String: (key: String, modifiedAt: Date)] = [:]
        var keysByID: [String: [String]] = [:]
        for (key, setting) in newest {
            guard let record = T(settingValue: setting.value, key: key), !record.id.isEmpty else { continue }
            keysByID[record.id, default: []].append(key)
            if let current = best[record.id], (current.modifiedAt, current.key) >= (record.modifiedAt, key) { continue }
            best[record.id] = (key, record.modifiedAt)
        }
        var stale: [String] = []
        for (id, keys) in keysByID where keys.count > 1 {
            stale += keys.filter { $0 != best[id]?.key }
        }
        return stale.sorted()
    }

    /// v11 P3.2 (1), KR1-2: restored copies (`importID` = the original's id) are merged with their original
    /// and with each other – blocks and notes, grouped by `recordID`, in full every time (an IN predicate finds
    /// the originals, no full scan). The original stays (`uuid` = the id), else the oldest copy; another copy's
    /// fields count only when it was edited after it was made (`modifiedAt` more than 2 s after `createdAt`)
    /// and is newer – a restored copy never rolls back what changed after the backup. The same on every device.
    /// Returns the number of merged groups (no save).
    @discardableResult
    func mergeImportedCopies() -> Int {
        var merged = 0
        let blocks: [WorkBlock] = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { $0.importID != "" && $0.deletedAt == nil }))
        let blockIDs: [UUID] = Array(Set(blocks.compactMap { UUID(uuidString: $0.importID) }))
        var allBlocks: [WorkBlock] = blocks
        if !blockIDs.isEmpty {
            // A failed IN fetch would return [] silently (KR3-19): then read the live blocks and pick the ids.
            let wanted: Set<UUID> = Set(blockIDs)
            let originals: [WorkBlock] = (try? context.fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { blockIDs.contains($0.uuid) && $0.deletedAt == nil })))
                ?? fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { $0.deletedAt == nil })).filter { wanted.contains($0.uuid) }
            allBlocks += originals.filter { $0.importID.isEmpty }
        }
        for group in Dictionary(grouping: allBlocks, by: { TrackerStore.copyKey($0.recordID) }).values where group.count > 1 {
            guard let keeper = TrackerStore.copyKeeper(group, uuid: \.uuid, recordID: \.recordID, createdAt: \.createdAt) else { continue }
            if let source = TrackerStore.editedSource(group, keeper: keeper, uuid: \.uuid, createdAt: \.createdAt, modifiedAt: \.modifiedAt) {
                keeper.dayKey = source.dayKey
                keeper.categoryKey = source.categoryKey
                if !source.task.isEmpty { keeper.task = source.task }
                keeper.result = source.result
                keeper.nextStep = source.nextStep
                keeper.powerHours = source.powerHours
                keeper.minutes = source.minutes
                keeper.modifiedAt = source.modifiedAt
            }
            for copy in group where copy !== keeper { context.delete(copy) }
            merged += 1
        }
        let notes: [DayNote] = fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { $0.importID != "" && $0.deletedAt == nil }))
        let noteIDs: [UUID] = Array(Set(notes.compactMap { UUID(uuidString: $0.importID) }))
        var allNotes: [DayNote] = notes
        if !noteIDs.isEmpty {
            let wanted: Set<UUID> = Set(noteIDs)
            let originals: [DayNote] = (try? context.fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { noteIDs.contains($0.uuid) && $0.deletedAt == nil })))
                ?? fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { $0.deletedAt == nil })).filter { wanted.contains($0.uuid) }
            allNotes += originals.filter { $0.importID.isEmpty }
        }
        for group in Dictionary(grouping: allNotes, by: { TrackerStore.copyKey($0.recordID) }).values where group.count > 1 {
            guard let keeper = TrackerStore.copyKeeper(group, uuid: \.uuid, recordID: \.recordID, createdAt: \.createdAt) else { continue }
            if let source = TrackerStore.editedSource(group, keeper: keeper, uuid: \.uuid, createdAt: \.createdAt, modifiedAt: \.modifiedAt) {
                keeper.dayKey = source.dayKey
                keeper.kindRaw = source.kindRaw
                if !source.text.isEmpty { keeper.text = source.text }
                keeper.modifiedAt = source.modifiedAt
            }
            for copy in group where copy !== keeper { context.delete(copy) }
            merged += 1
        }
        if merged > 0 {
            noteMaintenanceRemoval()
            AppLog.info("Merged \(merged) restored copy group(s) with their originals", category: "store")
        }
        return merged
    }

    /// A record id as it groups copies: a UUID in one spelling (a backup may write it in either case).
    nonisolated static func copyKey(_ id: String) -> String {
        UUID(uuidString: id)?.uuidString ?? id
    }

    /// The copy every device keeps: the original (its `uuid` is the id), else the oldest (`createdAt`, uuid).
    static func copyKeeper<T: AnyObject>(_ group: [T], uuid: KeyPath<T, UUID>, recordID: KeyPath<T, String>,
                                         createdAt: KeyPath<T, Date>) -> T? {
        if let original = group.first(where: { $0[keyPath: uuid].uuidString == copyKey($0[keyPath: recordID]) }) { return original }
        return group.min { ($0[keyPath: createdAt], $0[keyPath: uuid].uuidString) < ($1[keyPath: createdAt], $1[keyPath: uuid].uuidString) }
    }

    /// The copy whose fields the keeper takes: the newest one edited after it was made (more than 2 s), and
    /// only when it is newer than the keeper; nil otherwise (the keeper stays as it is).
    static func editedSource<T: AnyObject>(_ group: [T], keeper: T, uuid: KeyPath<T, UUID>, createdAt: KeyPath<T, Date>,
                                           modifiedAt: KeyPath<T, Date>) -> T? {
        let edited = group.filter { $0 !== keeper && $0[keyPath: modifiedAt] > $0[keyPath: createdAt].addingTimeInterval(2) }
        guard let newest = edited.max(by: {
            ($0[keyPath: modifiedAt], $0[keyPath: uuid].uuidString) < ($1[keyPath: modifiedAt], $1[keyPath: uuid].uuidString)
        }), newest[keyPath: modifiedAt] > keeper[keyPath: modifiedAt] else { return nil }
        return newest
    }

    /// v11 P3.16 (4), KR1-1: the goals and categories `seedStructure` created (stamped 1970) on a device before
    /// its first sync. Per key, a 1970 copy goes when a live copy edited later exists; when every live copy is
    /// from 1970, exactly one stays – the smallest uuid, the same on every device. Never the last live copy.
    /// Returns the number of merged keys (no save).
    @discardableResult
    func mergeTemplateCopies() -> Int {
        let cutoff = Date(timeIntervalSince1970: 2 * 86_400)
        var merged = 0
        func merge<T: AnyObject>(_ copies: [T], key: KeyPath<T, String>, uuid: KeyPath<T, UUID>, modifiedAt: KeyPath<T, Date>,
                                 delete: (T) -> Void) {
            for group in Dictionary(grouping: copies, by: { $0[keyPath: key] }).values where group.count > 1 {
                let templates = group.filter { $0[keyPath: modifiedAt] < cutoff }
                guard !templates.isEmpty else { continue }
                let doomed: [T]
                if templates.count < group.count {
                    doomed = templates
                } else {
                    let kept = templates.min { $0[keyPath: uuid].uuidString < $1[keyPath: uuid].uuidString }
                    doomed = templates.filter { $0 !== kept }
                }
                guard !doomed.isEmpty, doomed.count < group.count else { continue }
                for copy in doomed { delete(copy) }
                merged += 1
            }
        }
        merge(liveGoals(), key: \.key, uuid: \.uuid, modifiedAt: \.modifiedAt) { context.delete($0) }
        merge(liveCategories(), key: \.key, uuid: \.uuid, modifiedAt: \.modifiedAt) { context.delete($0) }
        if merged > 0 {
            noteMaintenanceRemoval()
            AppLog.info("Removed template copies of \(merged) goal(s)/category(ies)", category: "store")
        }
        return merged
    }

    /// The copies of one work block (same `importID`): every device keeps the same one – the oldest – with
    /// the fields of the most recently changed copy; the others are deleted. v11 (P3.2, KR1-2): the keeper
    /// takes the newest copy's `modifiedAt` – a fresh stamp would make a merged restored copy look edited.
    @discardableResult
    private func mergeWork(_ group: [WorkBlock]) -> WorkBlock? {
        let sorted = group.sorted { ($0.createdAt, $0.uuid.uuidString) < ($1.createdAt, $1.uuid.uuidString) }
        guard let keeper = sorted.first else { return nil }
        guard sorted.count > 1 else { return keeper }
        if let newest = sorted.max(by: { $0.modifiedAt < $1.modifiedAt }), newest !== keeper {
            keeper.dayKey = newest.dayKey
            keeper.categoryKey = newest.categoryKey
            if !newest.task.isEmpty { keeper.task = newest.task }
            keeper.result = newest.result
            keeper.nextStep = newest.nextStep
            keeper.powerHours = newest.powerHours
            keeper.minutes = newest.minutes
            keeper.modifiedAt = newest.modifiedAt
        }
        for duplicate in sorted.dropFirst() { context.delete(duplicate) }
        noteMaintenanceRemoval()
        return keeper
    }

    /// The copies of one day (two devices): the oldest is kept with the merged fields. Returns the
    /// kept copy (the only one when there is just one), nil for none.
    @discardableResult
    private func mergeDays(_ group: [PlanDay]) -> PlanDay? {
        let sorted = group.sorted { $0.createdAt < $1.createdAt }
        guard let keeper = sorted.first else { return nil }
        guard sorted.count > 1 else { return keeper }
        let versions = sorted.map { DayVersion(dayType: $0.dayType, note: $0.note, closedAt: $0.closedAt, modifiedAt: $0.modifiedAt) }
        guard let result = DuplicateMerge.day(versions) else { return keeper }
        keeper.dayType = result.dayType
        keeper.note = result.note
        keeper.closedAt = result.closedAt
        keeper.modifiedAt = Date()
        for duplicate in sorted.dropFirst() { context.delete(duplicate) }
        noteMaintenanceRemoval()
        return keeper
    }

    /// The copies of one week plan (two devices), like `mergeDays`.
    @discardableResult
    private func mergePlans(_ group: [WeekPlan]) -> WeekPlan? {
        let sorted = group.sorted { $0.createdAt < $1.createdAt }
        guard let keeper = sorted.first else { return nil }
        guard sorted.count > 1 else { return keeper }
        let versions = sorted.map {
            WeekVersion(title: $0.title, details: $0.details, recordedScore: $0.recordedScore, scoringModel: $0.scoringModel,
                        closedAt: $0.closedAt, importedAt: $0.importedAt, finalScore: $0.finalScore,
                        finalGoalScores: $0.finalGoalScores, finalGoalsScored: $0.finalGoalsScored, modifiedAt: $0.modifiedAt)
        }
        guard let result = DuplicateMerge.week(versions) else { return keeper }
        keeper.title = result.title
        keeper.details = result.details
        keeper.recordedScore = result.recordedScore
        keeper.scoringModel = result.scoringModel
        keeper.closedAt = result.closedAt
        keeper.importedAt = result.importedAt
        keeper.finalScore = result.finalScore
        keeper.finalGoalScores = result.finalGoalScores
        keeper.finalGoalsScored = result.finalGoalsScored
        keeper.touch()
        for duplicate in sorted.dropFirst() { context.delete(duplicate) }
        noteMaintenanceRemoval()
        return keeper
    }

    // MARK: Trash

    struct Trash {
        var items: [PlanItem] = []
        var work: [WorkBlock] = []
        var notes: [DayNote] = []
        var entries: [MeasureEntry] = []
        var measures: [MeasureDefinition] = []
        /// v10 (§1.1.3): results, list entries and segments – their entries and readings go and come back with them.
        var results: [GoalResult] = []
        var listItems: [ListItem] = []
        var segments: [GoalSegment] = []
        var isEmpty: Bool { items.isEmpty && work.isEmpty && notes.isEmpty && entries.isEmpty && measures.isEmpty && recordCount == 0 }
        var count: Int { items.count + work.count + notes.count + entries.count + measures.count + recordCount }
        /// The v10 records among them.
        var recordCount: Int { results.count + listItems.count + segments.count }
    }

    /// Everything in "Zuletzt gelöscht", each list newest first (R19).
    func trash() -> Trash {
        func newestFirst(_ a: Date?, _ b: Date?) -> Bool { (a ?? .distantPast) > (b ?? .distantPast) }
        let records = trashedRecords()
        return Trash(
            items: fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.deletedAt != nil }))
                .sorted { newestFirst($0.deletedAt, $1.deletedAt) },
            work: fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { $0.deletedAt != nil }))
                .sorted { newestFirst($0.deletedAt, $1.deletedAt) },
            notes: fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { $0.deletedAt != nil }))
                .sorted { newestFirst($0.deletedAt, $1.deletedAt) },
            entries: fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> { $0.deletedAt != nil }))
                .sorted { newestFirst($0.deletedAt, $1.deletedAt) },
            measures: fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> { $0.deletedAt != nil }))
                .sorted { newestFirst($0.deletedAt, $1.deletedAt) },
            results: records.results, listItems: records.listItems, segments: records.segments
        )
    }

    func purge(_ trash: Trash) {
        for item in trash.items { context.delete(item) }
        for block in trash.work { context.delete(block) }
        for note in trash.notes { context.delete(note) }
        for entry in trash.entries { context.delete(entry) }
        for measure in trash.measures { context.delete(measure) }
        purgeRecords(results: trash.results, listItems: trash.listItems, segments: trash.segments)
        save()
    }

    /// Empties what has been in "Zuletzt gelöscht" longer than 30 days. Run at launch.
    func purgeExpired(now: Date = Date()) {
        let all = trash()
        var expired = Trash()
        expired.items = all.items.filter { trashPolicy.isExpired(deletedAt: $0.deletedAt, now: now) }
        expired.work = all.work.filter { trashPolicy.isExpired(deletedAt: $0.deletedAt, now: now) }
        expired.notes = all.notes.filter { trashPolicy.isExpired(deletedAt: $0.deletedAt, now: now) }
        expired.entries = all.entries.filter { trashPolicy.isExpired(deletedAt: $0.deletedAt, now: now) }
        expired.measures = all.measures.filter { trashPolicy.isExpired(deletedAt: $0.deletedAt, now: now) }
        // v10: results, list entries, segments – and single entries, readings and mappings – after 30 days too.
        let records = purgeExpiredRecords(now: now)
        guard !expired.isEmpty || records > 0 else { return }
        AppLog.info("Emptied \(expired.count + records) record(s) from the trash", category: "store")
        noteMaintenanceRemoval()
        purge(expired)
    }

    // MARK: Settings

    func setting(_ key: String) -> String? {
        fetch(FetchDescriptor<AppSetting>(predicate: #Predicate<AppSetting> { $0.key == key }))
            .max { $0.modifiedAt < $1.modifiedAt }?.value
    }

    /// v11 P2.10: the newest copy gets the value, other copies go (`writeSetting`); the same value saves nothing.
    func setSetting(_ key: String, _ value: String) {
        var change = RecordChange()
        writeSetting(key, value, now: Date(), change: &change)
        guard !change.isEmpty else { return }
        commit(change)
    }

    // MARK: Devices in sync

    private static let installIDKey = "sync.installID"
    private static let lastSeenKey = "sync.lastSeenWritten"
    /// v11: the build whose `sync.build.` record this device wrote last (device only).
    private static let buildWrittenKey = "sync.buildWritten"

    /// This installation's id (kept on the device only, never synced). v11 P2.2: creating it notes the install
    /// time (`HealthDevice.installedAt`) – an id that exists without one came from an earlier version.
    static var installID: String {
        if let id = UserDefaults.standard.string(forKey: installIDKey) { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: installIDKey)
        UserDefaults.standard.set(Date(), forKey: HealthDevice.installedAtKey)
        return id
    }

    /// v11 P2.1 (d): the build and version this device runs (`CFBundleVersion`, `CFBundleShortVersionString`).
    nonisolated static var currentBuild: SyncBuild {
        let info: [String: Any] = Bundle.main.infoDictionary ?? [:]
        let build: Int = (info["CFBundleVersion"] as? String).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? 0
        let version: String = info["CFBundleShortVersionString"] as? String ?? ""
        return SyncBuild(build: build, version: version)
    }

    /// Notes in the synced settings that this device just opened Thalia ("Geräte im Abgleich"),
    /// at most every 10 minutes. v11 P2.1 (d): with its build (`sync.build.<installID>` – a key of its own,
    /// 1.9.0 drops a device whose `sync.seen.` value has more parts), at once after an update. Maintenance:
    /// without Undo (P2.4).
    func recordDeviceSeen(kind: String, now: Date = Date()) {
        let defaults = UserDefaults.standard
        let build: SyncBuild = Self.currentBuild
        let newBuild: Bool = defaults.integer(forKey: Self.buildWrittenKey) != build.build
        if !newBuild, let last = defaults.object(forKey: Self.lastSeenKey) as? Date,
           now.timeIntervalSince(last) < SyncDevice.minimumInterval { return }
        let device = SyncDevice(installID: Self.installID, kind: kind, seenAt: now)
        withoutUndo {
            var change = RecordChange()
            writeSetting(device.key, device.value, now: now, change: &change)
            writeSetting(SyncBuild.key(installID: device.installID), build.value, now: now, change: &change)
            if !change.isEmpty { commit(change, origin: .maintenance) }
        }
        defaults.set(now, forKey: Self.lastSeenKey)
        defaults.set(build.build, forKey: Self.buildWrittenKey)
    }

    /// v11 P2.1 (d), KR1-9: every device seen in the last 30 days (`sync.seen.`) runs 1.10.0 or later
    /// (`sync.build.` ≥ `SyncDevice.firstV11Build`) – only then do Mac, Watch and iPad score closed weeks
    /// themselves (1.9.0 scores differently and rewrites the last three weeks after every import, §0.2).
    func allDevicesCurrent(now: Date = Date()) -> Bool {
        let builds = SyncBuild.builds(settings(prefix: SettingKeys.buildPrefix).map(\.stored))
        return SyncDevice.allCurrent(seen: syncDevices(), builds: builds, now: now)
    }

    /// Every device that has noted itself, newest first.
    func syncDevices() -> [SyncDevice] {
        // v10: a prefix query – the settings now hold the inbox and the goals' records too (§1.1.2).
        var newest: [String: SyncDevice] = [:]
        for setting in settings(prefix: SyncDevice.keyPrefix) {
            guard let device = SyncDevice.parse(key: setting.key, value: setting.value) else { continue }
            if let known = newest[device.installID], known.seenAt >= device.seenAt { continue }
            newest[device.installID] = device
        }
        return newest.values.sorted { $0.seenAt > $1.seenAt }
    }

    /// The goal year (start, end, review week, motto) – Bini's foundation year unless changed.
    var goalPeriod: GoalPeriod {
        TrackerStore.goalPeriod(from: settings(keys: TrackerStore.goalPeriodKeys))
    }

    /// The settings of the goal year.
    nonisolated static let goalPeriodKeys = ["goal.start", "goal.end", "goal.review", "goal.motto"]

    /// The goal year from its settings (the newest copy of each; others are ignored) – the store and
    /// `WeekContext` read it the same way.
    nonisolated static func goalPeriod(from settings: [AppSetting]) -> GoalPeriod {
        var values: [String: AppSetting] = [:]
        for setting in settings where goalPeriodKeys.contains(setting.key) {
            if let current = values[setting.key], current.modifiedAt >= setting.modifiedAt { continue }
            values[setting.key] = setting
        }
        var period = GoalPeriod.foundationYear
        if let start = values["goal.start"].flatMap({ DayKey($0.value) }) { period.start = start }
        if let end = values["goal.end"].flatMap({ DayKey($0.value) }) { period.end = end }
        if let review = values["goal.review"].flatMap({ WeekKey($0.value) }) { period.reviewWeek = review }
        if let motto = values["goal.motto"]?.value, !motto.isEmpty { period.motto = motto }
        return period
    }

    /// v11 P2.10: all four settings in one change and one save (nothing when they are unchanged).
    func setGoalPeriod(_ period: GoalPeriod) {
        var change = RecordChange()
        let now = Date()
        writeSetting("goal.start", period.start.string, now: now, change: &change)
        writeSetting("goal.end", period.end.string, now: now, change: &change)
        writeSetting("goal.review", period.reviewWeek.string, now: now, change: &change)
        writeSetting("goal.motto", period.motto, now: now, change: &change)
        guard !change.isEmpty else { return }
        commit(change)
    }

    // MARK: Saving

    /// Saves, then scores closed weeks this save touched again (R11: a late entry changes the stored
    /// score). The widget snapshot is not written here any more (R84, `WidgetPublisher`).
    func save() {
        commit(rescoring: [])
    }

    /// `save()`, scoring `extra` weeks again too (v10: a book's next reading, the weeks of a mapping).
    /// v10, Grundregel 2: a closed week before the current segment's start is never scored again here
    /// (only "Neu berechnen", `recompute(_:)`). Returns those weeks – they kept their score.
    /// v11 P2.1 (§1.3): the iPhone (`HealthDevice.scoresHealth`) scores touched closed weeks as before, once its
    /// first sync is done (`SyncProgress.firstImportDone`), except weeks before this install that read Health
    /// (P2.2). Mac, Watch and iPad write a request `rescore.<week>` for each (in this save, so it travels with
    /// the change) and score it themselves only after own input (`origin` .user and not inside `withoutUndo`),
    /// when `canScore`, after their first sync and when every device runs 1.10.0 (`allDevicesCurrent`).
    /// `keeping`: weeks whose stored score came from elsewhere (an import's `wertung` rows, P3.3) – neither
    /// scored nor requested. A failed save posts `saveFailed` (P2.9).
    @discardableResult
    func commit(rescoring extra: Set<WeekKey>, origin: SaveOrigin = .user, keeping kept: Set<WeekKey> = []) -> Set<WeekKey> {
        let touched = touchedWeeks().union(extra).subtracting(kept)
        var decision = ScoringDecision()
        if !touched.isEmpty {
            decision = scoringDecision(for: touched, fromMaintenance: origin == .maintenance || isMaintenance)
            if !decision.requests.isEmpty {
                withoutUndo { for week in decision.requests { writeRescoreRequest(week, force: false) } }
            }
        }
        do {
            try context.save()
        } catch {
            reportSaveFailure(error)
        }
        var rescored = false
        for plan in decision.score where storeFinalScore(plan) { rescored = true }
        if rescored { saveQuietly() }
        if !decision.frozen.isEmpty {
            AppLog.info("Not scored again (before the current segment): \(decision.frozen.count) week(s)", category: "store")
        }
        return decision.frozen
    }

    /// iPhone after a sync: closed weeks of the last few weeks get their score again with Health values – a
    /// week closed (or edited) on the Mac, Watch or iPad stored it without them. v10: not those before the
    /// current segment (Grundregel 2). v11: the iPhone only (`scoresHealth`, KR1-16), after its first sync,
    /// not weeks before this install that read Health (P2.2); maintenance, without Undo.
    func rescoreRecentClosedWeeks(through week: WeekKey, weeks: Int = 3) {
        guard HealthDevice.scoresHealth, isInMemory || SyncProgress.firstImportDone else { return }
        withoutUndo {
            var rescored = false
            let isFrozen = freezeRule()
            for offset in 0..<weeks {
                let shown = week.adding(weeks: -offset)
                guard let plan = plan(shown), plan.isClosed, !isFrozen(shown), !keepsScoreBeforeInstall(shown) else { continue }
                if storeFinalScore(plan) { rescored = true }
            }
            if rescored { saveQuietly() }
        }
    }

    /// Weeks whose marks, items, measurements, entries, work, own scores, days or archive grades (v9)
    /// are about to be saved.
    private func touchedWeeks() -> Set<WeekKey> {
        var weeks: Set<WeekKey> = []
        func add(week key: String) { if let week = WeekKey(key) { weeks.insert(week) } }
        func add(day key: String) { if let day = DayKey(key) { weeks.insert(day.week) } }
        let models: [any PersistentModel] = context.insertedModelsArray + context.changedModelsArray + context.deletedModelsArray
        for model in models {
            if let mark = model as? ItemMark { add(week: mark.weekKey) }
            else if let item = model as? PlanItem { add(week: item.weekKey) }
            else if let measure = model as? MeasureDefinition { add(week: measure.weekKey) }
            else if let entry = model as? MeasureEntry { add(day: entry.dayKey) }
            else if let block = model as? WorkBlock { add(day: block.dayKey) }
            else if let score = model as? ScoreOverride { add(day: score.dayKey) }
            else if let day = model as? PlanDay { add(day: day.dayKey) }
            // v11 P2.3: adopting or removing a Health value scores its week again.
            else if let value = model as? HealthValue { add(day: value.dayKey) }
            else if let setting = model as? AppSetting, let week = TrackerStore.scoredWeek(settingKey: setting.key) { weeks.insert(week) }
        }
        return weeks
    }

    /// The week whose score a setting can change: `archive.<week>` (v9) and the dated v10 facts – result
    /// entries, readings, the inbox's day files (Grundregel 3). Not `score.<week>`: it is the score's
    /// output, written while scoring. v11: nor a request `rescore.<week>` (P2.1).
    static func scoredWeek(settingKey key: String) -> WeekKey? {
        guard !key.hasPrefix(GoalTrack.settingPrefix), !key.hasPrefix(SettingKeys.rescoreRequest) else { return nil }
        return SettingKeys.week(of: key)
    }

    /// Stores the week's score as it is now (closing, R11 re-scoring). Returns whether it changed.
    /// v9: a week without items that has archive grades stores their recalculation under today's rules
    /// (`ArchiveWeek.recalculated`); the value "laut Unterlagen" (`recordedScore`) is never touched.
    /// v10 (§1.2.3): the category week scores go to `score.<week>` with it ("Wochen über 8").
    @discardableResult
    func storeFinalScore(_ plan: WeekPlan) -> Bool {
        guard let week = plan.week else { return false }
        let closed = weekContext(for: week, goalYear: false)
        let categoriesChanged: Bool = finalCategoryScores(closed).map { writeCategoryScores($0, week: week) } ?? false
        let goalScores: String
        let overall: Double?
        let goalsScored: Int
        if closed.items.isEmpty, let recalculation = closed.archiveRecalculation {
            goalScores = recalculation.goalScoresText
            overall = recalculation.overall
            goalsScored = recalculation.goals.count
        } else {
            goalScores = closed.goals.compactMap { goal in
                closed.score.goalWeek[goal.key]?.score.map { "\(goal.key)=\(Format.plain($0))" }
            }.joined(separator: ";")
            overall = closed.score.overall
            goalsScored = closed.score.goalsScored
        }
        let changed = plan.finalScore != overall || plan.finalGoalsScored != goalsScored || plan.finalGoalScores != goalScores
        guard changed else { return categoriesChanged }
        plan.finalScore = overall
        plan.finalGoalsScored = goalsScored
        plan.finalGoalScores = goalScores
        plan.touch()
        return true
    }

    var isInMemory: Bool {
        context.container.configurations.contains { $0.isStoredInMemoryOnly }
    }
}

// MARK: v11 – maintenance without Undo, saving errors (P2.4, P2.9)

extension TrackerStore {
    /// v11 P2.9: posted when saving fails (userInfo `saveFailedMessageKey`: the error's text); the app shows it.
    nonisolated static let saveFailed = Notification.Name("thalia.saveFailed")
    nonisolated static let saveFailedMessageKey = "message"

    /// Maintenance running per context (nesting counts) – `isMaintenance`.
    private static var maintenanceDepth: [ObjectIdentifier: Int] = [:]
    /// Contexts whose running maintenance merged or deleted records – the undo stack is cleared at its end.
    private static var maintenanceRemoved: Set<ObjectIdentifier> = []

    /// v11 P2.4: background work (merging, re-scoring, the inbox, device notes, catch-up) without Undo – ⌘Z
    /// takes back what the person did, never the maintenance after it. Changes made before are registered
    /// first (`processPendingChanges`), the body's changes not at all; saving happens inside. While it runs,
    /// saves count as maintenance (`isMaintenance`, P2.1). Did it merge or delete something, the undo stack is
    /// cleared afterwards (KR1-14: an undo must never reach a deleted copy).
    @discardableResult
    func withoutUndo<T>(_ body: () -> T) -> T {
        let id = ObjectIdentifier(context)
        Self.maintenanceDepth[id, default: 0] += 1
        defer {
            let depth = (Self.maintenanceDepth[id] ?? 1) - 1
            Self.maintenanceDepth[id] = depth > 0 ? depth : nil
            if depth <= 0, Self.maintenanceRemoved.remove(id) != nil {
                context.undoManager?.removeAllActions()
                AppLog.info("Undo cleared after merging", category: "store")
            }
        }
        guard let undo = context.undoManager else { return body() }
        context.processPendingChanges()
        undo.disableUndoRegistration()
        defer {
            context.processPendingChanges()
            undo.enableUndoRegistration()
        }
        return body()
    }

    /// Inside `withoutUndo`: saves are maintenance (P2.1).
    var isMaintenance: Bool { (Self.maintenanceDepth[ObjectIdentifier(context)] ?? 0) > 0 }

    /// Maintenance merged or deleted records: clear the undo stack when it ends (no effect outside it).
    func noteMaintenanceRemoval() {
        guard isMaintenance else { return }
        Self.maintenanceRemoved.insert(ObjectIdentifier(context))
    }

    /// Saves without scoring; a failure posts `saveFailed` (P2.9). Returns whether it saved.
    @discardableResult
    func saveQuietly() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            reportSaveFailure(error)
            return false
        }
    }

    func reportSaveFailure(_ error: Error) {
        let text = error.localizedDescription
        AppLog.error("Save failed: \(text)", category: "store")
        NotificationCenter.default.post(name: TrackerStore.saveFailed, object: nil, userInfo: [TrackerStore.saveFailedMessageKey: text])
    }

    /// v11 P2.13: once a day (UserDefaults `maintenance.lastFull`) the trash is emptied of what is older than
    /// 30 days and duplicates are merged over the whole store; otherwise only those of the last weeks
    /// (`mergeDuplicates(since:)`). Without Undo. Logs "Maintenance: full/recent, N ms".
    func maintenance(today: DayKey = .today(), now: Date = Date()) {
        let started = Date()
        let defaults = UserDefaults.standard
        let last = defaults.object(forKey: Self.lastFullMaintenanceKey) as? Date
        let full: Bool = last.map { now.timeIntervalSince($0) >= 24 * 3600 || now < $0 } ?? true
        withoutUndo {
            if full {
                purgeExpired(now: now)
                mergeDuplicates()
                defaults.set(now, forKey: Self.lastFullMaintenanceKey)
            } else {
                mergeDuplicates(since: today.week.adding(weeks: -3))
            }
        }
        let milliseconds = Int((Date().timeIntervalSince(started) * 1000).rounded())
        AppLog.info("Maintenance: \(full ? "full" : "recent"), \(milliseconds) ms", category: "store")
    }

    static let lastFullMaintenanceKey = "maintenance.lastFull"
}

// MARK: v11 – who scores closed weeks (P2.1, P2.2)

extension TrackerStore {
    /// What a save does with the closed weeks it touched.
    struct ScoringDecision {
        /// Score now (after the save).
        var score: [WeekPlan] = []
        /// Ask the iPhone (`rescore.<week>`, in the save).
        var requests: [WeekKey] = []
        /// Before the current segment: left as they are.
        var frozen: Set<WeekKey> = []
    }

    /// The conditions read once per save (only when a closed week was touched).
    private struct ScoringGate {
        let isInMemory: Bool
        let isPhone: Bool
        let isSynced: Bool
        let allCurrent: Bool
    }

    private func scoringGate() -> ScoringGate {
        let memory = isInMemory
        let phone = HealthDevice.scoresHealth
        let synced = memory || SyncProgress.firstImportDone
        // The iPhone doesn't need the version check (it scores with the full data anyway).
        let current = memory || phone || allDevicesCurrent()
        return ScoringGate(isInMemory: memory, isPhone: phone, isSynced: synced, allCurrent: current)
    }

    /// v11 P2.1 (b): which touched weeks are scored now, which are asked of the iPhone, which stay frozen.
    /// In-memory stores (demo, practice) never sync: they score what this device can score, without requests.
    func scoringDecision(for weeks: Set<WeekKey>, fromMaintenance: Bool) -> ScoringDecision {
        var decision = ScoringDecision()
        var isFrozen: ((WeekKey) -> Bool)?
        var gate: ScoringGate?
        for week in weeks.sorted() {
            guard let plan = plan(week), plan.isClosed else { continue }
            let rule = isFrozen ?? freezeRule()
            isFrozen = rule
            if rule(week) {
                decision.frozen.insert(week)
                continue
            }
            let current = gate ?? scoringGate()
            gate = current
            if current.isInMemory {
                if canScore(week) { decision.score.append(plan) }
            } else if current.isPhone {
                guard current.isSynced, !keepsScoreBeforeInstall(week) else { continue }
                decision.score.append(plan)
            } else {
                decision.requests.append(week)
                if !fromMaintenance, current.isSynced, current.allCurrent, canScore(week) { decision.score.append(plan) }
            }
        }
        if !decision.requests.isEmpty {
            AppLog.info("Asked the iPhone to score \(decision.requests.count) closed week(s) again", category: "store")
        }
        return decision
    }

    /// v11 P2.1 (a): a progress item of the week counts through a measure with an Apple Health source – only
    /// then do values that only one device has change the week's score.
    func weekReadsHealth(_ week: WeekKey) -> Bool {
        let codes = Set(items(week).filter { $0.schedule == .progress && !$0.measureCode.isEmpty }.map(\.measureCode))
        guard !codes.isEmpty else { return false }
        return measures(week).contains { codes.contains($0.code) && ($0.record?.isHealth ?? false) }
    }

    /// v11 P2.1 (a): this device can score the week with everything that counts – it doesn't read Apple Health,
    /// or this is the iPhone. (P9 adds weeks whose Health values another device shares.)
    func canScore(_ week: WeekKey) -> Bool {
        // HEALTHSHARE: or the iPhone shares the week's Health values (§1.3.1 (b), §1.4.7) – scored like there.
        !weekReadsHealth(week) || HealthDevice.scoresHealth || healthShareCovers(week)
    }

    /// v11 P2.2 (KR1-10, KR3-2): a closed week that ended before this install and reads Health keeps its score
    /// on this device – its adopted Health values of then aren't here. Automatic re-scoring only; "Neu
    /// berechnen" by hand still scores it.
    func keepsScoreBeforeInstall(_ week: WeekKey) -> Bool {
        let installed: Date = HealthDevice.installedAt
        guard installed > .distantPast, week.sunday.adding(days: 1).date(minutes: 0) <= installed,
              weekReadsHealth(week) else { return false }
        AppLog.info("Kept score of \(week.string): week before this install reads Health", category: "store")
        return true
    }

    /// v11 P2.1, P7.1: asks the iPhone to score `week` again with its full data (`rescore.<week>`); `force`
    /// also a frozen week ("Am iPhone neu berechnen", closing on another device). Without Undo; saved.
    func requestRescore(_ week: WeekKey, force: Bool) {
        withoutUndo {
            writeRescoreRequest(week, force: force)
            saveQuietly()
        }
    }

    /// Writes the request without saving: every copy merged into one (`force` stays when any copy asked).
    func writeRescoreRequest(_ week: WeekKey, force: Bool, now: Date = Date()) {
        let key = RescoreRequest.key(week)
        let stored: [RescoreRequest] = settings(keys: [key]).compactMap { RescoreRequest(value: $0.value) }
        guard let request = RescoreRequest.merged(stored + [RescoreRequest(by: TrackerStore.installID, at: now, force: force)]) else { return }
        var change = RecordChange()
        writeSetting(key, request.value, now: now, change: &change)
    }

    /// Requests whose `at` this launch already handled (a later run takes the others first, P2.1 (c)).
    private static var handledRequests: [String: Date] = [:]
    /// Protected `force` requests already returned for the toast (once per request and launch).
    private static var toastedRequests: [String: Date] = [:]

    /// v11 P2.1 (c): the iPhone works through the requests of Mac, Watch and iPad – after its first sync, at most
    /// 8 per run (not yet handled ones first, oldest first; the rest next time). A closed week gets its score
    /// again when it isn't frozen or the request has `force`, and not when it ended before this install and
    /// reads Health (P2.2 – such `force` weeks are returned once, for the toast "KW44: Auf diesem iPhone
    /// fehlen …"). A request goes once it is older than 10 minutes (its week's `closedAt` or marks may arrive
    /// after it, and it is repeated on the next sync – writing only what changed); at once when the week is
    /// frozen and it has no `force`. Without Undo.
    @discardableResult
    func processRescoreRequests(now: Date = Date(), limit: Int = 8) -> [WeekKey] {
        guard HealthDevice.scoresHealth, isInMemory || SyncProgress.firstImportDone else { return [] }
        return withoutUndo { processRescoreRequestsNow(now: now, limit: limit) }
    }

    private func processRescoreRequestsNow(now: Date, limit: Int) -> [WeekKey] {
        var requests: [(key: String, week: WeekKey, request: RescoreRequest)] = []
        for (key, copies) in Dictionary(grouping: settings(prefix: SettingKeys.rescoreRequest), by: \.key) {
            guard let week = RescoreRequest.week(settingKey: key) else { continue }
            let request = RescoreRequest.merged(copies.compactMap { RescoreRequest(value: $0.value) })
                ?? RescoreRequest(by: "", at: Date(timeIntervalSince1970: 0))
            requests.append((key, week, request))
        }
        guard !requests.isEmpty else { return [] }
        func handled(_ entry: (key: String, week: WeekKey, request: RescoreRequest)) -> Bool {
            Self.handledRequests[entry.key] == entry.request.at
        }
        var change = RecordChange()
        var toast: [WeekKey] = []
        var rescored = 0
        // Handled and expired: nothing left to do but delete (doesn't count against the limit).
        for entry in requests where handled(entry) && entry.request.isExpired(now: now) {
            writeSetting(entry.key, nil, now: now, change: &change)
            Self.handledRequests[entry.key] = nil
        }
        // Not yet handled first, then the oldest.
        let open = requests.filter { !(handled($0) && $0.request.isExpired(now: now)) }.sorted { a, b in
            let handledA: Bool = handled(a)
            let handledB: Bool = handled(b)
            if handledA != handledB { return !handledA }
            if a.request.at != b.request.at { return a.request.at < b.request.at }
            return a.key < b.key
        }
        let isFrozen = freezeRule()
        for entry in open.prefix(max(0, limit)) {
            let week = entry.week
            let request = entry.request
            Self.handledRequests[entry.key] = request.at
            var delete = request.isExpired(now: now)
            if let plan = plan(week), plan.isClosed {
                if isFrozen(week) && !request.force {
                    delete = true
                } else if keepsScoreBeforeInstall(week) {
                    if request.force, Self.toastedRequests[entry.key] != request.at {
                        Self.toastedRequests[entry.key] = request.at
                        toast.append(week)
                    }
                } else if storeFinalScore(plan) {
                    rescored += 1
                }
            }
            if delete {
                writeSetting(entry.key, nil, now: now, change: &change)
                Self.handledRequests[entry.key] = nil
            }
        }
        if rescored > 0 || !change.isEmpty { saveQuietly() }
        if rescored > 0 { AppLog.info("Scored \(rescored) week(s) again on request", category: "store") }
        if open.count > limit { AppLog.info("Rescore requests left for the next run: \(open.count - limit)", category: "store") }
        return toast.sorted()
    }

    // MARK: Closed week snapshots (P6.8, P7.1)

    /// v11 P6.8, P7.1: what the week stored when closed (nil without a plan).
    func closedWeekSnapshot(_ week: WeekKey) -> ClosedWeekSnapshot? {
        guard let plan = plan(week) else { return nil }
        return ClosedWeekSnapshot(week: week, closedAt: plan.closedAt, finalScore: plan.finalScore, finalGoalScores: plan.finalGoalScores,
                                  finalGoalsScored: plan.finalGoalsScored, categoryScores: storedValue(GoalTrack.settingKey(week)))
    }

    /// Writes a snapshot back exactly – closed state, final score, goal scores, `score.<week>` – without
    /// scoring (the "Widerrufen" of "Woche wieder öffnen" and "Neu berechnen").
    func restore(_ snapshot: ClosedWeekSnapshot) {
        let plan = ensurePlan(snapshot.week)
        plan.closedAt = snapshot.closedAt
        plan.finalScore = snapshot.finalScore
        plan.finalGoalScores = snapshot.finalGoalScores
        plan.finalGoalsScored = snapshot.finalGoalsScored
        plan.touch()
        var change = RecordChange()
        writeSetting(GoalTrack.settingKey(snapshot.week), snapshot.categoryScores, now: Date(), change: &change)
        saveQuietly()
        AppLog.info("Week \(snapshot.week.string) restored as it was", category: "review")
    }
}
