import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

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

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
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

    func items(_ week: WeekKey) -> [PlanItem] {
        let key = week.string
        return fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key && $0.deletedAt == nil }))
    }

    func measures(_ week: WeekKey) -> [MeasureDefinition] {
        let key = week.string
        return fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> { $0.weekKey == key && $0.deletedAt == nil }))
    }

    /// The week, read and scored (widget snapshot, report, export).
    func weekContext(for week: WeekKey, today: DayKey = .today()) -> WeekContext {
        let key = week.string
        let dayKeys = week.days.map(\.string)
        return WeekContext(
            week: week, today: today,
            plans: fetch(FetchDescriptor<WeekPlan>(predicate: #Predicate<WeekPlan> { $0.weekKey == key })),
            goals: allGoals(), categories: allCategories(), items: items(week),
            measures: measures(week),
            marks: fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.weekKey == key })),
            days: fetch(FetchDescriptor<PlanDay>(predicate: #Predicate<PlanDay> { dayKeys.contains($0.dayKey) })),
            entries: fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            health: fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> { dayKeys.contains($0.dayKey) })),
            work: fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            notes: fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            overrides: fetch(FetchDescriptor<ScoreOverride>(predicate: #Predicate<ScoreOverride> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })),
            reflections: fetch(FetchDescriptor<Reflection>(predicate: #Predicate<Reflection> { $0.scope == key || dayKeys.contains($0.scope) })),
            changes: changes(week)
        )
    }

    /// The widget snapshot (R4): today, plus tomorrow written ahead, so the widget can switch at
    /// midnight by itself.
    func widgetSummary(today: DayKey) -> TodaySummary {
        let tomorrow = today.adding(days: 1)
        let next = weekContext(for: tomorrow.week, today: tomorrow).todaySummary()
        return weekContext(for: today.week, today: today).todaySummary().with { $0.nextDay = [next] }
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
            report = WeekReport.markdown(previous.reportInput())
            changes = previous.changes.compactMap(\.record)
            currentPlan = PlanCSV.export(exportDocument(weeks: [source]).planOnly(week: source))
            trend = (0..<4).reversed().map { offset in trendLine(source.adding(weeks: -offset), today: today) }
        }
        let goals = structure.data.goals.isEmpty ? Template.goals : structure.data.goals
        let categories = structure.data.categories.isEmpty ? Template.categories : structure.data.categories
        AppLog.info("Planning prompt built for \(target.string)", category: "import")
        return PlanPrompt.text(for: target, goals: goals, categories: categories, measures: measures, lastWeekReport: report,
                               changes: changes, currentPlan: currentPlan, currentPlanWeek: source, trend: trend)
    }

    /// "KW44: Wertung 7,1 · 22 von 28 PH" (without a score "–").
    private func trendLine(_ week: WeekKey, today: DayKey) -> String {
        let context = weekContext(for: week, today: today)
        let score = context.plan?.historyScore ?? context.score.overall
        let worked = context.workTotals().powerHours
        let work: String
        if let target = context.workTarget {
            work = "\(Format.number(worked, decimals: 2)) von \(Format.number(target, decimals: 2)) PH"
        } else {
            work = Format.powerHours(worked)
        }
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

    func reopenDay(_ day: DayKey) {
        guard let info = planDay(day) else { return }
        info.closedAt = nil
        info.modifiedAt = Date()
        save()
    }

    /// Closes the week and keeps its score (quotas that weren't reached now count).
    func closeWeek(_ week: WeekKey) {
        let plan = ensurePlan(week)
        plan.closedAt = Date()
        plan.touch()
        try? context.save()
        storeFinalScore(plan)
        AppLog.info("Week closed", category: "review")
        save()
    }

    func reopenWeek(_ week: WeekKey) {
        guard let plan = plan(week) else { return }
        plan.closedAt = nil
        plan.finalScore = nil
        plan.finalGoalScores = ""
        plan.finalGoalsScored = 0
        plan.touch()
        save()
    }

    // MARK: Marks

    func setMark(_ mark: Mark?, item: PlanItem, day: DayKey, note: String? = nil) {
        writeMark(mark, item: item, day: day, note: note)
        save()
    }

    /// Several copies of one mark (written on two devices before they synced): keep the newest,
    /// fill its empty value or note from the newest copy that has one, delete the rest. `existing`
    /// is sorted newest first.
    private func collapse(_ existing: [ItemMark]) -> ItemMark? {
        guard let target = existing.first else { return nil }
        for duplicate in existing.dropFirst() {
            if target.valueRaw.isEmpty, !duplicate.valueRaw.isEmpty { target.valueRaw = duplicate.valueRaw }
            if target.note.isEmpty, !duplicate.note.isEmpty { target.note = duplicate.note }
            context.delete(duplicate)
        }
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
    func setMarkNote(_ note: String, item: PlanItem, day: DayKey) {
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
        target.note = note
        target.modifiedAt = Date()
        save()
    }

    /// "Vorschläge übernehmen" (R12). Returns what was recorded before, for Undo (`restoreMarks`).
    @discardableResult
    func apply(suggestions: [(PlanItem, Mark)], day: DayKey) -> [(PlanItem, Mark?)] {
        let dayKey = day.string
        let weekKeys = Array(Set(suggestions.map { $0.0.weekKey }))
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.dayKey == dayKey }))
            .filter { weekKeys.contains($0.weekKey) }
            .latest(by: { "\($0.weekKey)|\($0.itemCode)" }, modified: \.modifiedAt)
        let previous: [(PlanItem, Mark?)] = suggestions.map { pair in
            (pair.0, existing["\(pair.0.weekKey)|\(pair.0.code)"]?.mark)
        }
        for (item, mark) in suggestions { writeMark(mark, item: item, day: day) }
        save()
        return previous
    }

    /// One tap for many (V4): sets every given item to `mark` (nil clears). Returns what was
    /// recorded before, for Undo.
    @discardableResult
    func setMarks(_ mark: Mark?, items: [PlanItem], day: DayKey) -> [(PlanItem, Mark?)] {
        let weekKey = day.week.string
        let dayKey = day.string
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { $0.weekKey == weekKey && $0.dayKey == dayKey }))
            .latest(by: \.itemCode, modified: \.modifiedAt)
        let previous = items.map { item in (item, existing[item.code]?.mark) }
        for item in items { writeMark(mark, item: item, day: day) }
        save()
        return previous
    }

    func restoreMarks(_ previous: [(PlanItem, Mark?)], day: DayKey) {
        for (item, mark) in previous { writeMark(mark, item: item, day: day) }
        save()
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
    func restore(_ snapshot: EntrySnapshot) {
        write(snapshot)
        save()
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
        let purpose = what.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.value = (amount * 100).rounded() / 100
        if !purpose.isEmpty { entry.note = purpose }
        entry.dayKey = day.string
        entry.touch()
        save()
        return before
    }

    /// R81: the most recent day value of a measurement in the `lookback` days before `day`.
    func lastValue(code: String, before day: DayKey, lookback: Int = 60) -> Double? {
        let keys = dayKeys(through: day.adding(days: -1), days: lookback)
        let found = fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            $0.code == code && $0.deletedAt == nil && keys.contains($0.dayKey)
        })).filter { $0.value != nil }
        guard let latestKey = found.map(\.dayKey).max(), let latestDay = DayKey(latestKey) else { return nil }
        let aggregation = measureDefinition(code: code, day: latestDay)?.record?.aggregation ?? .sum
        let values = found.filter { $0.dayKey == latestKey }.sorted { $0.recordedAt < $1.recordedAt }.compactMap(\.value)
        return aggregation.apply(values)
    }

    /// R41: moves an entry to another day (its time of day stays).
    func move(_ entry: MeasureEntry, to day: DayKey) {
        guard entry.dayKey != day.string else { return }
        entry.dayKey = day.string
        entry.touch()
        save()
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
        block.dayKey = day.string
        block.touch()
        save()
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

    @discardableResult
    func trash(_ items: [PlanItem], carryOver: Bool = true) -> [PlanItem] {
        for item in items {
            item.moveToTrash()
            if let record = item.record { recordChange(.deleted, record, carryOver: carryOver) }
        }
        save()
        return items
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

    @discardableResult
    func trash(_ measures: [MeasureDefinition], carryOver: Bool = true) -> [MeasureDefinition] {
        for measure in measures {
            measure.moveToTrash()
            if let record = measure.record { recordChange(.deleted, record, carryOver: carryOver) }
        }
        save()
        return measures
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
            let targets: [Double] = measures(shown).latest(by: \.code, modified: \.modifiedAt).values.compactMap { measure in
                guard let record = measure.record, record.isWork, record.period == .week, let target = record.target else { return nil }
                return target.scaleMax
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
        var records = fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            $0.code == code && $0.deletedAt == nil && keys.contains($0.dayKey)
        })).compactMap(\.record)
        let own = Set(records.map(\.key))
        records += fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> {
            $0.code == code && keys.contains($0.dayKey)
        })).compactMap(\.record).filter { !own.contains($0.key) }
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

    /// R95: the goal review from the start of the goal year through `week` (weeks with a plan only).
    func periodReport(period: GoalPeriod, through week: WeekKey) -> PeriodReport {
        let today = DayKey.today()
        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        var inputs: [WeekReportInput] = []
        var goalScores: [WeekKey: [String: Double]] = [:]
        var shown = period.start.week
        while shown <= week {
            if hasItems(shown) {
                inputs.append(weekContext(for: shown, today: today).reportInput())
                if let scores = plans[shown.string]?.finalGoalScoreMap, !scores.isEmpty { goalScores[shown] = scores }
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
    /// Returns the number of merged groups. Run at launch and after every sync.
    @discardableResult
    func mergeDuplicates() -> Int {
        var merged = 0
        let days = Dictionary(grouping: fetch(FetchDescriptor<PlanDay>()), by: \.dayKey)
        for group in days.values where group.count > 1 {
            if mergeDays(group) != nil { merged += 1 }
        }
        let plans = Dictionary(grouping: allPlans().filter { $0.deletedAt == nil }, by: \.weekKey)
        for group in plans.values where group.count > 1 {
            if mergePlans(group) != nil { merged += 1 }
        }
        // One mark per item and day: a tick from one device and a note from another stay together.
        let marks = Dictionary(grouping: fetch(FetchDescriptor<ItemMark>()), by: { "\($0.weekKey)|\($0.itemCode)|\($0.dayKey)" })
        for group in marks.values where group.count > 1 {
            if collapse(group.sorted { $0.modifiedAt > $1.modifiedAt }) != nil { merged += 1 }
        }
        guard merged > 0 else { return 0 }
        save()
        AppLog.info("Merged \(merged) duplicate day/week/mark record(s)", category: "store")
        return merged
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
        return keeper
    }

    // MARK: Trash

    struct Trash {
        var items: [PlanItem] = []
        var work: [WorkBlock] = []
        var notes: [DayNote] = []
        var entries: [MeasureEntry] = []
        var measures: [MeasureDefinition] = []
        var isEmpty: Bool { items.isEmpty && work.isEmpty && notes.isEmpty && entries.isEmpty && measures.isEmpty }
        var count: Int { items.count + work.count + notes.count + entries.count + measures.count }
    }

    /// Everything in "Zuletzt gelöscht", each list newest first (R19).
    func trash() -> Trash {
        func newestFirst(_ a: Date?, _ b: Date?) -> Bool { (a ?? .distantPast) > (b ?? .distantPast) }
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
                .sorted { newestFirst($0.deletedAt, $1.deletedAt) }
        )
    }

    func purge(_ trash: Trash) {
        for item in trash.items { context.delete(item) }
        for block in trash.work { context.delete(block) }
        for note in trash.notes { context.delete(note) }
        for entry in trash.entries { context.delete(entry) }
        for measure in trash.measures { context.delete(measure) }
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
        guard !expired.isEmpty else { return }
        AppLog.info("Emptied \(expired.count) record(s) from the trash", category: "store")
        purge(expired)
    }

    // MARK: Settings

    func setting(_ key: String) -> String? {
        fetch(FetchDescriptor<AppSetting>(predicate: #Predicate<AppSetting> { $0.key == key }))
            .max { $0.modifiedAt < $1.modifiedAt }?.value
    }

    func setSetting(_ key: String, _ value: String) {
        let existing = fetch(FetchDescriptor<AppSetting>(predicate: #Predicate<AppSetting> { $0.key == key }))
        if let first = existing.first {
            first.value = value
            first.modifiedAt = Date()
            for duplicate in existing.dropFirst() { context.delete(duplicate) }
        } else {
            context.insert(AppSetting(key: key, value: value))
        }
        save()
    }

    // MARK: Devices in sync

    private static let installIDKey = "sync.installID"
    private static let lastSeenKey = "sync.lastSeenWritten"

    /// This installation's id (kept on the device only, never synced).
    static var installID: String {
        if let id = UserDefaults.standard.string(forKey: installIDKey) { return id }
        let id = UUID().uuidString.lowercased()
        UserDefaults.standard.set(id, forKey: installIDKey)
        return id
    }

    /// Notes in the synced settings that this device just opened Thalia ("Geräte im Abgleich"),
    /// at most every 10 minutes.
    func recordDeviceSeen(kind: String, now: Date = Date()) {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: Self.lastSeenKey) as? Date,
           now.timeIntervalSince(last) < SyncDevice.minimumInterval { return }
        let device = SyncDevice(installID: Self.installID, kind: kind, seenAt: now)
        setSetting(device.key, device.value)
        defaults.set(now, forKey: Self.lastSeenKey)
    }

    /// Every device that has noted itself, newest first.
    func syncDevices() -> [SyncDevice] {
        // Few settings exist, so they are filtered in memory (no string-prefix predicate needed).
        let settings = fetch(FetchDescriptor<AppSetting>()).filter { $0.key.hasPrefix(SyncDevice.keyPrefix) }
        var newest: [String: SyncDevice] = [:]
        for setting in settings {
            guard let device = SyncDevice.parse(key: setting.key, value: setting.value) else { continue }
            if let known = newest[device.installID], known.seenAt >= device.seenAt { continue }
            newest[device.installID] = device
        }
        return newest.values.sorted { $0.seenAt > $1.seenAt }
    }

    /// The goal year (start, end, review week, motto) – Bini's foundation year unless changed.
    var goalPeriod: GoalPeriod {
        var period = GoalPeriod.foundationYear
        if let start = setting("goal.start").flatMap(DayKey.init) { period.start = start }
        if let end = setting("goal.end").flatMap(DayKey.init) { period.end = end }
        if let review = setting("goal.review").flatMap(WeekKey.init) { period.reviewWeek = review }
        if let motto = setting("goal.motto"), !motto.isEmpty { period.motto = motto }
        return period
    }

    func setGoalPeriod(_ period: GoalPeriod) {
        setSetting("goal.start", period.start.string)
        setSetting("goal.end", period.end.string)
        setSetting("goal.review", period.reviewWeek.string)
        setSetting("goal.motto", period.motto)
    }

    // MARK: Saving

    /// Saves, then scores closed weeks this save touched again (R11: a late entry changes the stored
    /// score). The widget snapshot is not written here any more (R84, `WidgetPublisher`).
    func save() {
        let touched = touchedWeeks()
        do {
            try context.save()
        } catch {
            AppLog.error("Save failed: \(error.localizedDescription)", category: "store")
        }
        // Only a device that reads Apple Health re-scores closed weeks: the Mac and the Watch don't
        // see Health values and would store a different score (they ping-ponged with the iPhone).
        guard !touched.isEmpty, HealthDevice.readsHealth else { return }
        var rescored = false
        for week in touched.sorted() {
            guard let plan = plan(week), plan.isClosed else { continue }
            if storeFinalScore(plan) { rescored = true }
        }
        if rescored { try? context.save() }
    }

    /// iPhone/iPad after a sync: closed weeks of the last few weeks get their score again with
    /// Health values – a week closed (or edited) on the Mac or Watch stored it without them.
    func rescoreRecentClosedWeeks(through week: WeekKey, weeks: Int = 3) {
        guard HealthDevice.readsHealth else { return }
        var rescored = false
        for offset in 0..<weeks {
            guard let plan = plan(week.adding(weeks: -offset)), plan.isClosed else { continue }
            if storeFinalScore(plan) { rescored = true }
        }
        if rescored { try? context.save() }
    }

    /// Weeks whose marks, items, measurements, entries, work, own scores or days are about to be saved.
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
        }
        return weeks
    }

    /// Stores the week's score as it is now (closing, R11 re-scoring). Returns whether it changed.
    @discardableResult
    private func storeFinalScore(_ plan: WeekPlan) -> Bool {
        guard let week = plan.week else { return false }
        let closed = weekContext(for: week)
        let goalScores = closed.goals.compactMap { goal in
            closed.score.goalWeek[goal.key]?.score.map { "\(goal.key)=\(Format.plain($0))" }
        }.joined(separator: ";")
        let overall = closed.score.overall
        let changed = plan.finalScore != overall || plan.finalGoalsScored != closed.score.goalsScored
            || plan.finalGoalScores != goalScores
        guard changed else { return false }
        plan.finalScore = overall
        plan.finalGoalsScored = closed.score.goalsScored
        plan.finalGoalScores = goalScores
        plan.touch()
        return true
    }

    var isInMemory: Bool {
        context.container.configurations.contains { $0.isStoredInMemoryOnly }
    }
}
