import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

/// Every change goes through here – timestamps, soft delete, duplicate-safe keys, save, widget
/// snapshot – so the rules live in one place. Views never write to the models directly.
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
            week: week, today: today, plans: allPlans(), goals: allGoals(), categories: allCategories(), items: items(week),
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

    /// The most recent week that has a plan, for "copy last week's report".
    func latestPlannedWeek(before week: WeekKey) -> WeekKey? {
        let keys = Set(fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.deletedAt == nil })).map(\.weekKey))
        return keys.compactMap(WeekKey.init).filter { $0 < week }.max()
    }

    // MARK: Goals and structure

    /// Bini's 10 annual goals and 18 categories from the handover, if nothing is there yet.
    @discardableResult
    func seedStructure() -> Bool {
        guard liveGoals().isEmpty else { return false }
        for goal in Template.goals { context.insert(AnnualGoal(goal)) }
        let existing = Set(liveCategories().map(\.key))
        for category in Template.categories where !existing.contains(category.key) { context.insert(TrackCategory(category)) }
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

    @discardableResult
    func ensurePlan(_ week: WeekKey) -> WeekPlan {
        if let existing = plan(week) { return existing }
        let created = WeekPlan(WeekRecord(week: week))
        context.insert(created)
        return created
    }

    @discardableResult
    func ensureDay(_ day: DayKey) -> PlanDay {
        if let existing = planDay(day) { return existing }
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
        let closed = weekContext(for: week)
        plan.finalScore = closed.score.overall
        plan.finalGoalsScored = closed.score.goalsScored
        plan.finalGoalScores = closed.goals.compactMap { goal in
            closed.score.goalWeek[goal.key]?.score.map { "\(goal.key)=\(Format.plain($0))" }
        }.joined(separator: ";")
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

    private func writeMark(_ mark: Mark?, item: PlanItem, day: DayKey, note: String? = nil) {
        let weekKey = item.weekKey
        let code = item.code
        let dayKey = day.string
        let existing = fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> {
            $0.weekKey == weekKey && $0.itemCode == code && $0.dayKey == dayKey
        })).sorted { $0.modifiedAt > $1.modifiedAt }
        let target: ItemMark
        if let first = existing.first {
            target = first
            for duplicate in existing.dropFirst() { context.delete(duplicate) }
        } else {
            target = ItemMark(weekKey: weekKey, itemCode: code, dayKey: dayKey)
            context.insert(target)
        }
        target.valueRaw = mark?.rawValue ?? ""
        if let note { target.note = note }
        target.modifiedAt = Date()
    }

    func setMarkNote(_ note: String, item: PlanItem, day: DayKey, current: Mark?) {
        setMark(current, item: item, day: day, note: note)
    }

    /// "Vorschläge übernehmen" in the evening review.
    func apply(suggestions: [(PlanItem, Mark)], day: DayKey) {
        for (item, mark) in suggestions { writeMark(mark, item: item, day: day) }
        save()
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

    @discardableResult
    func addEntry(code: String, day: DayKey, value: Double?, text: String = "", estimate: Bool = false, note: String = "") -> MeasureEntry {
        let entry = MeasureEntry(code: code, dayKey: day.string, value: value)
        entry.text = text
        entry.isEstimate = estimate
        entry.note = note
        entry.recordedAt = Date()
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

    /// Sets the day's value directly (the inline field and − / + on a tile): one entry replaces
    /// the day's entries; nil clears the day. Undo sets the previous value again.
    func setDayValue(code: String, day: DayKey, value: Double?) {
        for entry in entries(code: code, day: day) { context.delete(entry) }
        if let value {
            context.insert(MeasureEntry(code: code, dayKey: day.string, value: value))
        }
        save()
    }

    /// A text value typed in place: replaces the day's text entry (empty clears it).
    func setDayText(code: String, day: DayKey, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = entries(code: code, day: day)
        guard current.last?.text != trimmed || current.count > 1 else { return }
        for entry in current { context.delete(entry) }
        if !trimmed.isEmpty {
            let entry = MeasureEntry(code: code, dayKey: day.string, value: nil)
            entry.text = trimmed
            context.insert(entry)
        }
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
        block.task = task.trimmingCharacters(in: .whitespacesAndNewlines)
        block.powerHours = max(0.05, powerHours)
        block.minutes = Int(PowerHour.minutes(block.powerHours).rounded())
        block.result = result
        block.nextStep = nextStep
        block.dayKey = day.string
        block.touch()
        save()
    }

    /// Sets a category's power-hours for a day (− / typed value on a work tile, V7): more adds a
    /// block, less shrinks the newest blocks (and removes those that reach 0).
    func setWorkTotal(categoryKey: String, day: DayKey, powerHours target: Double) {
        let dayKey = day.string
        let blocks = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> {
            $0.categoryKey == categoryKey && $0.dayKey == dayKey && $0.deletedAt == nil
        })).sorted { $0.createdAt < $1.createdAt }
        let current = blocks.reduce(0) { $0 + $1.hours }
        let wanted = max(0, (target * 100).rounded() / 100)
        if wanted > current + 1e-9 {
            addWork(day: day, categoryKey: categoryKey, task: "", powerHours: wanted - current)
            return
        }
        var excess = current - wanted
        for block in blocks.reversed() where excess > 1e-9 {
            let hours = block.hours
            if hours <= excess + 1e-9 {
                block.moveToTrash()
                excess -= hours
            } else {
                block.powerHours = hours - excess
                block.minutes = Int(PowerHour.minutes(block.powerHours).rounded())
                block.touch()
                excess = 0
            }
        }
        save()
    }

    /// Edits only the description (inline in the list, V10).
    func setTask(_ block: WorkBlock, _ task: String) {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != block.task else { return }
        block.task = trimmed
        block.touch()
        save()
    }

    /// What earlier blocks of a category were for ("Lena – Mathe"), most used first – the suggestions
    /// under the description field.
    func workSuggestions(categoryKey: String, limit: Int = 8) -> [String] {
        let blocks = fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { $0.categoryKey == categoryKey && $0.deletedAt == nil }))
        var counts: [String: (count: Int, last: Date)] = [:]
        for block in blocks where !block.task.isEmpty {
            let current = counts[block.task] ?? (0, .distantPast)
            counts[block.task] = (current.count + 1, max(current.last, block.createdAt))
        }
        return counts.sorted { ($0.value.count, $0.value.last) > ($1.value.count, $1.value.last) }.prefix(limit).map(\.key)
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
        var code = "\(categoryKey)-" + String(format: "%02d", position)
        let codes = Set(existing.map(\.code))
        if codes.contains(code) { code = "\(categoryKey)-m\(UUID().uuidString.prefix(4).lowercased())" }
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
        let record = MeasureRecord(week: week, code: code, categoryKey: categoryKey, position: position,
                                   title: title.trimmingCharacters(in: .whitespacesAndNewlines), details: details,
                                   unit: unit, target: target, period: period, days: days)
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

    func trash() -> Trash {
        Trash(
            items: fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.deletedAt != nil })),
            work: fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { $0.deletedAt != nil })),
            notes: fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { $0.deletedAt != nil })),
            entries: fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> { $0.deletedAt != nil })),
            measures: fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> { $0.deletedAt != nil }))
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

    func save() {
        do {
            try context.save()
        } catch {
            AppLog.error("Save failed: \(error.localizedDescription)", category: "store")
        }
        if !isInMemory {
            let today = DayKey.today()
            WidgetBridge.publish(weekContext(for: today.week, today: today).todaySummary())
        }
    }

    var isInMemory: Bool {
        context.container.configurations.contains { $0.isStoredInMemoryOnly }
    }
}
