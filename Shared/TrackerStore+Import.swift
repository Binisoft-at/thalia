import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

extension TrackerStore {
    private func all<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    /// One value per measurement and day, the way exports write them and imports compare them.
    /// Several entries of a day – and every spending – also keep their single entries with the time
    /// (`parts`, R27), so a backup restores them one by one.
    static func aggregate(_ entries: [MeasureEntry], measures: [MeasureDefinition]) -> [EntryRecord] {
        var recordByWeekCode: [String: MeasureRecord] = [:]
        for measure in measures where measure.deletedAt == nil {
            if let record = measure.record { recordByWeekCode["\(measure.weekKey)|\(measure.code)"] = record }
        }
        let groups = Dictionary(grouping: entries.filter { $0.deletedAt == nil }) { "\($0.code)|\($0.dayKey)" }
        return groups.values.compactMap { group -> EntryRecord? in
            let sorted = group.sorted { $0.recordedAt < $1.recordedAt }
            guard let first = sorted.first, let day = DayKey(first.dayKey) else { return nil }
            let record = recordByWeekCode["\(day.week.string)|\(first.code)"]
            let aggregation = record?.aggregation ?? .sum
            let value = aggregation.apply(sorted.compactMap(\.value))
            let text = sorted.map(\.text).filter { !$0.isEmpty }.last ?? ""
            let note = sorted.map(\.note).filter { !$0.isEmpty }.joined(separator: "; ")
            let isExpense = record?.isExpense ?? first.code.lowercased().contains("ausgabe")
            var parts: [EntryPart] = []
            if (sorted.count > 1 || isExpense), text.isEmpty {
                parts = sorted.map { entry in
                    EntryPart(value: entry.value, note: entry.note, minutes: Int(DayKey.minutes(of: entry.recordedAt)),
                              estimate: entry.isEstimate)
                }
            }
            // v11 P3.9: a single value keeps its moment (`order`), so the backup writes its time of day.
            let order: Double = sorted.count == 1 ? first.recordedAt.timeIntervalSince1970 : 0
            return EntryRecord(code: first.code, day: day, value: value, text: text, note: note,
                               estimate: sorted.contains(where: \.isEstimate), order: order, parts: parts)
        }
    }

    /// What the app has, keyed the way the import compares – always the newest version of a record
    /// that exists twice (R27), plus the closed days and weeks and (v9) the archive grades per week.
    /// v11: also the stored final scores of closed weeks (P3.3) and the goal year and catalog switch (P3.7).
    func existingState() -> ExistingState {
        readState(weeks: nil, includeRecords: true, work: .all).state
    }

    /// v11 P3.12: the state limited to what a file is about. Always whole: the goals, categories, week rows (closings,
    /// final scores), the measurements of every week (a measure row keeps the source of the nearest earlier week) and
    /// the archive grades. Only for `weeks` (nil: all): items, marks, days, values, own scores and reflections – each
    /// through an IN predicate. `includeRecords`: the stored records (`record` rows – only a full backup or a file with
    /// such rows needs them). `includeWork`: every work block and note (they are matched by id, on any day).
    func existingState(weeks: Set<WeekKey>?, includeRecords: Bool, includeWork: Bool = true) -> ExistingState {
        readState(weeks: weeks, includeRecords: includeRecords, work: includeWork ? .all : .without).state
    }

    /// v11 P3.12: the state a parsed file needs – a full backup (`sicherung` row) everything, any other file its
    /// weeks (`referencedWeeks`), records only with `record` rows, work and notes only with such rows.
    func existingState(for document: PlanCSV.Document, adding weeks: Set<WeekKey> = []) -> ExistingState {
        if document.backupInfo != nil { return existingState() }
        return existingState(weeks: document.referencedWeeks.union(weeks), includeRecords: !document.records.isEmpty,
                             includeWork: !document.work.isEmpty || !document.notes.isEmpty)
    }

    /// Which work blocks and notes a state read takes.
    enum StateWork {
        /// None (a file without work and note rows).
        case without
        /// Those on the days of the weeks read (an export of some weeks).
        case weekDays
        /// All live ones (they are matched by id, P3.12).
        case all
    }

    /// A state read with the creation order of the blocks and notes read (by record id) – the export writes them
    /// in that order (P3.9).
    struct StateRead {
        var state = ExistingState()
        var workOrder: [String: Date] = [:]
        var noteOrder: [String: Date] = [:]
    }

    /// The one reader behind `existingState`: whole or limited to `weeks` (P3.12).
    func readState(weeks: Set<WeekKey>?, includeRecords: Bool, work: StateWork) -> StateRead {
        var read = StateRead()
        var state = ExistingState()
        let weekKeys: [String]? = weeks.map { $0.map(\.string).sorted() }
        let dayKeys: [String]? = weeks.map { set in set.flatMap { $0.days.map(\.string) }.sorted() }
        for (key, goal) in liveGoals().latest(by: \.key, modified: \.modifiedAt) { state.goals[key] = goal.record }
        for (key, category) in liveCategories().latest(by: \.key, modified: \.modifiedAt) { state.categories[key] = category.record }
        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        for (key, plan) in plans {
            if let record = plan.record { state.weeks[key] = record }
            guard plan.isClosed, let week = plan.week else { continue }
            state.closedWeeks.insert(week)
            // v11 P3.3: what the closed week stored, exactly.
            if let score = plan.finalScore {
                state.finalScores[week] = PlanCSV.FinalScore(score: score, goalScores: plan.finalGoalScores, goalsScored: plan.finalGoalsScored)
            }
        }
        for (key, day) in planDays(dayKeys).latest(by: \.dayKey, modified: \.modifiedAt) {
            if let record = day.record { state.days[key] = record }
            if day.isClosed, let date = day.day { state.closedDays.insert(date) }
        }
        for (key, item) in planItems(weekKeys).latest(by: \.key, modified: \.modifiedAt) { if let record = item.record { state.items[key] = record } }
        let measures = all(MeasureDefinition.self).filter { $0.deletedAt == nil }
        for (key, measure) in measures.latest(by: \.key, modified: \.modifiedAt) { if let record = measure.record { state.measures[key] = record } }
        let marks = itemMarks(weekKeys).latest(by: { "\($0.weekKey)|\($0.itemCode)|\($0.dayKey)" }, modified: \.modifiedAt)
        for mark in marks.values { if let record = mark.record { state.marks[record.key] = record } }
        for entry in Self.aggregate(measureEntries(dayKeys), measures: measures) { state.entries[entry.key] = entry }
        if work != .without {
            let blockDays: [String]? = work == .all ? nil : dayKeys
            let blocks = workBlocks(blockDays).latest(by: \.recordID, modified: \.modifiedAt)
            for block in blocks.values {
                guard let record = block.record else { continue }
                state.work[record.id] = record
                read.workOrder[record.id] = block.createdAt
            }
            let notes = dayNotes(blockDays).latest(by: \.recordID, modified: \.modifiedAt)
            for note in notes.values {
                guard let record = note.record else { continue }
                state.notes[record.id] = record
                read.noteOrder[record.id] = note.createdAt
            }
        }
        let scopes: [String]? = weekKeys.map { $0 + (dayKeys ?? []) }
        for reflection in reflections(scopes).latest(by: \.key, modified: \.modifiedAt).values {
            state.reviews[reflection.key] = reflection.record
        }
        let scores = scoreOverrides(dayKeys).latest(by: \.key, modified: \.modifiedAt)
        for score in scores.values { if let record = score.record { state.scores[record.key] = record } }
        state.archiveGrades = storedArchives()
        if includeRecords { state.records = storedRecordRows() }
        read.state = state
        return read
    }

    // MARK: Limited reads (v11 P3.12) – nil keys: all; an IN predicate that fails reads all and filters

    private func planDays(_ keys: [String]?) -> [PlanDay] {
        guard let keys else { return all(PlanDay.self) }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<PlanDay>(predicate: #Predicate<PlanDay> { keys.contains($0.dayKey) })))
            ?? all(PlanDay.self).filter { wanted.contains($0.dayKey) }
    }

    /// Live items of the weeks.
    private func planItems(_ keys: [String]?) -> [PlanItem] {
        guard let keys else { return all(PlanItem.self).filter { $0.deletedAt == nil } }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { keys.contains($0.weekKey) && $0.deletedAt == nil })))
            ?? all(PlanItem.self).filter { wanted.contains($0.weekKey) && $0.deletedAt == nil }
    }

    /// Live measurements of the weeks.
    private func measureDefinitions(_ keys: [String]?) -> [MeasureDefinition] {
        guard let keys else { return all(MeasureDefinition.self).filter { $0.deletedAt == nil } }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> {
            keys.contains($0.weekKey) && $0.deletedAt == nil
        }))) ?? all(MeasureDefinition.self).filter { wanted.contains($0.weekKey) && $0.deletedAt == nil }
    }

    private func itemMarks(_ keys: [String]?) -> [ItemMark] {
        guard let keys else { return all(ItemMark.self) }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<ItemMark>(predicate: #Predicate<ItemMark> { keys.contains($0.weekKey) })))
            ?? all(ItemMark.self).filter { wanted.contains($0.weekKey) }
    }

    /// Live values of the days.
    private func measureEntries(_ keys: [String]?) -> [MeasureEntry] {
        guard let keys else { return all(MeasureEntry.self).filter { $0.deletedAt == nil } }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            keys.contains($0.dayKey) && $0.deletedAt == nil
        }))) ?? all(MeasureEntry.self).filter { wanted.contains($0.dayKey) && $0.deletedAt == nil }
    }

    /// Live work blocks of the days.
    private func workBlocks(_ keys: [String]?) -> [WorkBlock] {
        guard let keys else { return all(WorkBlock.self).filter { $0.deletedAt == nil } }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { keys.contains($0.dayKey) && $0.deletedAt == nil })))
            ?? all(WorkBlock.self).filter { wanted.contains($0.dayKey) && $0.deletedAt == nil }
    }

    /// Live notes of the days.
    private func dayNotes(_ keys: [String]?) -> [DayNote] {
        guard let keys else { return all(DayNote.self).filter { $0.deletedAt == nil } }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { keys.contains($0.dayKey) && $0.deletedAt == nil })))
            ?? all(DayNote.self).filter { wanted.contains($0.dayKey) && $0.deletedAt == nil }
    }

    /// Reflections of days and weeks (`scope`).
    private func reflections(_ keys: [String]?) -> [Reflection] {
        guard let keys else { return all(Reflection.self) }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<Reflection>(predicate: #Predicate<Reflection> { keys.contains($0.scope) })))
            ?? all(Reflection.self).filter { wanted.contains($0.scope) }
    }

    /// Live own scores of the days.
    private func scoreOverrides(_ keys: [String]?) -> [ScoreOverride] {
        guard let keys else { return all(ScoreOverride.self).filter { $0.deletedAt == nil } }
        guard !keys.isEmpty else { return [] }
        let wanted = Set(keys)
        return (try? context.fetch(FetchDescriptor<ScoreOverride>(predicate: #Predicate<ScoreOverride> {
            keys.contains($0.dayKey) && $0.deletedAt == nil
        }))) ?? all(ScoreOverride.self).filter { wanted.contains($0.dayKey) && $0.deletedAt == nil }
    }

    /// v10 (§1.1.4): every stored v10 record – results, entries, segments, the reading list, mappings,
    /// the inbox (`x.`, Thalia never deletes it) and the category week scores – the newest copy of each
    /// key, as `record` rows of the backup. One prefix query per kind.
    /// v11: a dated entry or reading moved to another day goes out once, its newest copy (P3.5 (2), the rule of
    /// `SettingRecords.decode`); the goal year and the catalog switch come along as plain text (P3.7). Never
    /// `rescore.`, `sync.build.`, `backup.last` or shared Health values (not in `SettingKeys.all`).
    func storedRecordRows() -> [String: SettingRow] {
        var settings: [StoredSetting] = []
        for prefix in SettingKeys.all { settings += self.settings(prefix: prefix).map(\.stored) }
        var rows: [String: SettingRow] = [:]
        for (key, setting) in SettingRecords.newest(settings) where !setting.value.isEmpty {
            // The inbox only with facts recorded in the source app (5.1.3(ii)) – also when a copy stored
            // by an earlier build of v10 still holds others; an unreadable day file stays out.
            guard let value = ExchangeInbox.syncableValue(setting.value, key: key) else { continue }
            rows[key] = SettingRow(key: key, value: value)
        }
        // A day of the inbox with two copies (two devices before they synced): the copy the weeks read
        // (`ExchangeInbox.isPreferred`), not the one written last – a restore shows the same values.
        let days: [String: [StoredSetting]] = Dictionary(grouping: settings.filter { ExchangeInbox.parse(settingKey: $0.key) != nil }, by: \.key)
        let doubled: [StoredSetting] = days.values.filter { $0.count > 1 }.flatMap { $0 }
        for file in ExchangeInbox.files(from: doubled) {
            guard let day = DayKey(file.day) else { continue }
            let key = ExchangeInbox.settingKey(source: file.source, day: day)
            // v11 P1.1: a day that can't be written as JSON stays out (never "{}").
            guard let value = ExchangeInbox.value(ExchangeInbox.syncable(file)) else { continue }
            rows[key] = SettingRow(key: key, value: value)
        }
        for key in Self.olderDatedCopies(Array(rows.values)) { rows[key] = nil }
        // v11 P3.7: the goal year and "Thalia-Katalog bereitstellen" – plain text, the newest copy each.
        for (key, setting) in SettingRecords.newest(self.settings(keys: PlanCSV.plainSettings).map(\.stored)) {
            guard !setting.value.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            rows[key] = SettingRow(key: key, value: setting.value)
        }
        return rows
    }

    /// v11 P3.5 (2): keys of dated entries and readings (`goal.entry.`, `list.progress.`) whose id has a newer copy under
    /// another key – the newest `modifiedAt` counts, a tie the greater key (as `SettingRecords.decode` reads them).
    nonisolated static func olderDatedCopies(_ rows: [SettingRow]) -> [String] {
        var best: [String: (stamp: Date, key: String)] = [:]
        var keysByID: [String: [String]] = [:]
        for row in rows {
            guard let prefix = [SettingKeys.goalEntry, SettingKeys.listProgress].first(where: { row.key.hasPrefix($0) }),
                  let id = JSONText.object(row.value)?["id"]?.stringValue, !id.isEmpty else { continue }
            let group = prefix + id
            keysByID[group, default: []].append(row.key)
            let candidate = (stamp: row.stamp ?? .distantPast, key: row.key)
            if let current = best[group], (current.stamp, current.key) >= (candidate.stamp, candidate.key) { continue }
            best[group] = candidate
        }
        var older: [String] = []
        for (group, keys) in keysByID where keys.count > 1 {
            older += keys.filter { $0 != best[group]?.key }
        }
        return older.sorted()
    }

    func preview(_ text: String) -> ImportPreview {
        // v11 P3.12: read the file against the structure first, then compare it with only what it is about.
        let structure = existingState(weeks: [], includeRecords: false, includeWork: false)
        let probe = Self.probe(text, structure: structure)
        return Self.preview(text, probe: probe, existing: existingState(for: probe))
    }

    /// v11 P3.10, P3.12: `preview(_:)` with the reading and comparing off the main thread (`ImportPreview` is
    /// `Sendable`) – a year's backup doesn't freeze the app. The app's state is read here, on the main context.
    func backgroundPreview(_ text: String) async -> ImportPreview {
        let structure = existingState(weeks: [], includeRecords: false, includeWork: false)
        let probe: PlanCSV.Document = await Task.detached(priority: .userInitiated) {
            TrackerStore.probe(text, structure: structure)
        }.value
        let existing = existingState(for: probe)
        return await Task.detached(priority: .userInitiated) {
            TrackerStore.preview(text, probe: probe, existing: existing)
        }.value
    }

    /// The file read against the app's structure (categories, measurement ids, goals) – what `ImportPreview`
    /// reads, without the app's items (only the warnings about marks need those).
    nonisolated static func probe(_ text: String, structure: ExistingState) -> PlanCSV.Document {
        PlanCSV.parse(text, knownCategories: structure.categoryTitles, knownMeasures: structure.measureCodes,
                      knownGoals: Set(structure.goals.keys))
    }

    /// The preview from the first reading and the limited state: a file with marks is read again with the
    /// items of its weeks (marks on unknown items get a warning), any other file is the first reading.
    nonisolated static func preview(_ text: String, probe: PlanCSV.Document, existing: ExistingState) -> ImportPreview {
        guard !probe.marks.isEmpty else { return ImportPreview(document: probe, existing: existing) }
        return ImportPreview(text: text, existing: existing)
    }

    struct ImportResult {
        var created = 0
        var updated = 0
        var removedItems: [PlanItem] = []
        var archived: [WeekKey] = []
        /// The archives the replaced weeks went to (R49: Undo restores them).
        var archives: [WeekArchive] = []
        /// v9: the weeks that went to the archive completely ("Archivdaten dieser Wochen ersetzen"):
        /// Undo replaces them completely again.
        var completeWeeks: Set<WeekKey> = []
        var week: WeekKey?
        /// v9: when the import was saved – Undo keeps a snapshot of what was edited in a week after it.
        var finishedAt: Date?
        /// v10 (Grundregel 2): closed weeks the import changed but didn't score again – they lie before the
        /// current segment; "Neu berechnen" in the week does it.
        var frozenWeeks: Set<WeekKey> = []
        /// v11 P3.4 (d): what "Widerrufen" takes back besides the archives – the work blocks, notes and reflections
        /// the import added (their uuids) and the day types and day notes as they were before (one per day).
        var insertedWork: [UUID] = []
        var insertedNotes: [UUID] = []
        var insertedReflections: [UUID] = []
        var daysBefore: [DayRecord] = []
        /// v11 P3.3: weeks whose stored score came from the file's `wertung` rows (not scored anew).
        var keptScores: Set<WeekKey> = []

        /// v11 P3.4 (d): the toast offers "Widerrufen" – a week went to the archive, or the import added work,
        /// notes or reflections or changed a day.
        var canUndo: Bool {
            !archives.isEmpty || !insertedWork.isEmpty || !insertedNotes.isEmpty || !insertedReflections.isEmpty || !daysBefore.isEmpty
        }

        /// "KW40, KW41: nicht neu gewertet – früherer Abschnitt („Neu berechnen“ in der Woche)"; nil without.
        var frozenHint: String? {
            guard !frozenWeeks.isEmpty else { return nil }
            let weeks = frozenWeeks.sorted().map(\.label).joined(separator: ", ")
            return "\(weeks): nicht neu gewertet – früherer Abschnitt (\u{201E}Neu berechnen\u{201C} in der Woche)"
        }

        /// The short form for the second line of the toast after the import: "KW40, KW41 nicht neu gewertet" –
        /// one line on an iPhone too (the toast has two); the week itself says why and offers "Neu berechnen".
        var frozenToast: String? {
            guard !frozenWeeks.isEmpty else { return nil }
            let weeks = frozenWeeks.sorted().map(\.label)
            let shown = weeks.count > 3 ? "\(weeks.prefix(3).joined(separator: ", ")) …" : weeks.joined(separator: ", ")
            return "\(shown) nicht neu gewertet"
        }

        var summary: String {
            var parts = ["\(created) neu", "\(updated) aktualisiert"]
            if !removedItems.isEmpty { parts.append("\(removedItems.count) entfallen") }
            if !archived.isEmpty { parts.append(archived.map(\.label).joined(separator: ", ") + " archiviert") }
            return parts.joined(separator: " · ")
        }
    }

    /// Applies a previewed file. A week the file plans anew replaces the existing one: the old plan
    /// with its marks and values goes to the archive first (U15), so only the new week counts.
    /// v9: a week in `preview.replacingWeeks` ("Archivdaten dieser Wochen ersetzen", made with
    /// `ImportPreview(…, replacing:)` / `ImportPreview.pastWeeks(…, replacingArchives: true)`) goes to the
    /// archive completely (`archiveWeek(_:completely:)`) and comes from the file anew; Undo brings it back.
    /// The file's grades are stored per week (`preview.archiveUpdates`, updated by key).
    /// Unchanged rows are left alone.
    /// v11: one save as maintenance (P2.1 – Mac, Watch and iPad never score here, they ask the iPhone); a week with a
    /// `wertung` row keeps the file's score exactly and is neither scored nor asked for (P3.3); existing days and
    /// weeks are written to the copy every device keeps (`ensureDay`/`ensurePlan`, P2.7); new blocks, notes and
    /// reflections and the days as they were are noted for "Widerrufen" (P3.4 (d)); new values mark the restore
    /// window (P3.2 (3)); stored records the file replaces under another key go (P3.5); only what the file is about
    /// is read (P3.12).
    @discardableResult
    func apply(_ preview: ImportPreview, closedDays: [DayKey] = [], closedWeeks: [WeekKey] = []) -> ImportResult {
        guard preview.replacedWeeks.isEmpty else {
            let complete = Set(preview.replacingWeeks)
            var archives: [WeekArchive] = []
            for week in preview.replacedWeeks {
                if let archive = archiveWeek(week, saving: false, completely: complete.contains(week)) { archives.append(archive) }
            }
            saveQuietly()
            let existing = existingState(for: preview.document, adding: Set(preview.replacedWeeks))
            var result = apply(ImportPreview(document: preview.document, existing: existing),
                               closedDays: closedDays, closedWeeks: closedWeeks)
            result.archived = preview.replacedWeeks
            result.archives = archives
            result.completeWeeks = complete
            return result
        }
        var result = ImportResult()
        let now = Date()
        // v11 P3.7: what a backup only fills in (plain settings, weeks iCloud hadn't brought yet) is stamped as very old –
        // "füllt nur auf": a copy of the same record that arrives later (iCloud still loading) is the app's own value and
        // wins wherever the newest copy counts (`goalPeriod(from:)`, `writeSetting`, `DuplicateMerge.week`).
        let filledAt = Date(timeIntervalSince1970: 0)

        let goals = liveGoals().latest(by: \.key, modified: \.modifiedAt)
        for entry in preview.goals.entries where entry.action != .unchanged {
            if let goal = goals[entry.key] {
                goal.title = entry.record.title
                goal.details = entry.record.details
                goal.touch(now: now)
                result.updated += 1
            } else {
                context.insert(AnnualGoal(entry.record))
                result.created += 1
            }
        }

        let categories = liveCategories().latest(by: \.key, modified: \.modifiedAt)
        for entry in preview.categories.entries where entry.action != .unchanged {
            if let category = categories[entry.key] {
                category.goalKey = entry.record.goalKey
                category.title = entry.record.title
                category.details = entry.record.details
                category.touch(now: now)
                result.updated += 1
            } else {
                context.insert(TrackCategory(entry.record))
                result.created += 1
            }
        }

        // v11 P2.7: an existing week or day is written to the copy every device keeps – `ensurePlan`/`ensureDay`
        // fold two devices' copies first (only where there are several; one copy is that copy). Weeks and days made
        // here are closed and scored on these objects later (`planToWrite`, `dayToWrite`).
        var madePlans: [String: WeekPlan] = [:]
        var madeDays: [String: PlanDay] = [:]
        func planToWrite(_ week: WeekKey) -> WeekPlan { madePlans[week.string] ?? ensurePlan(week) }
        func dayToWrite(_ day: DayKey) -> PlanDay { madeDays[day.string] ?? ensureDay(day) }
        let planCopies = Dictionary(grouping: allPlans().filter { $0.deletedAt == nil }, by: \.weekKey)
        for entry in preview.weeks.entries where entry.action != .unchanged {
            if let copies = planCopies[entry.key], let first = copies.first {
                let plan = copies.count > 1 ? ensurePlan(entry.record.week) : first
                plan.update(from: entry.record)
                plan.importedAt = now
                plan.touch(now: now)
                result.updated += 1
            } else {
                let plan = WeekPlan(entry.record)
                plan.importedAt = now
                context.insert(plan)
                madePlans[entry.key] = plan
                result.created += 1
            }
        }

        let changedDays = preview.days.entries.filter { $0.action != .unchanged }
        let dayCopies = Dictionary(grouping: changedDays.isEmpty ? [] : planDays(changedDays.map(\.key)), by: \.dayKey)
        for entry in changedDays {
            let day: PlanDay
            if let copies = dayCopies[entry.key], let first = copies.first {
                day = copies.count > 1 ? ensureDay(entry.record.day) : first
                result.updated += 1
            } else {
                day = PlanDay(dayKey: entry.key)
                context.insert(day)
                madeDays[entry.key] = day
                result.created += 1
            }
            // v11 P3.4 (d): the day as it was, for "Widerrufen".
            result.daysBefore.append(DayRecord(day: entry.record.day, dayType: day.dayType, note: day.note))
            day.dayType = entry.record.dayType
            day.note = entry.record.note
            day.modifiedAt = now
        }

        let itemWeeks = Set(preview.items.entries.filter { $0.action != .unchanged }.map { $0.record.week.string }
            + preview.removedItems.map(Self.weekPart))
        let items = (itemWeeks.isEmpty ? [] : planItems(itemWeeks.sorted())).latest(by: \.key, modified: \.modifiedAt)
        for entry in preview.items.entries where entry.action != .unchanged {
            if let item = items[entry.key] {
                item.update(from: entry.record)
                item.touch(now: now)
                result.updated += 1
            } else {
                context.insert(PlanItem(entry.record))
                result.created += 1
            }
        }
        for key in preview.removedItems {
            guard let item = items[key] else { continue }
            item.moveToTrash(now: now)
            result.removedItems.append(item)
        }

        let measureWeeks = Set(preview.measures.entries.filter { $0.action != .unchanged }.map { $0.record.week.string }
            + preview.removedMeasures.map(Self.weekPart))
        let measures = (measureWeeks.isEmpty ? [] : measureDefinitions(measureWeeks.sorted())).latest(by: \.key, modified: \.modifiedAt)
        for entry in preview.measures.entries where entry.action != .unchanged {
            if let measure = measures[entry.key] {
                measure.update(from: entry.record)
                measure.touch(now: now)
                result.updated += 1
            } else {
                context.insert(MeasureDefinition(entry.record))
                result.created += 1
            }
        }
        for key in preview.removedMeasures { measures[key]?.moveToTrash(now: now) }

        if preview.marks.hasChanges {
            let markWeeks = Set(preview.marks.entries.filter { $0.action != .unchanged }.map { $0.record.week.string }).sorted()
            let marks = itemMarks(markWeeks).latest(by: { "\($0.weekKey)|\($0.itemCode)|\($0.dayKey)" }, modified: \.modifiedAt)
            for entry in preview.marks.entries where entry.action != .unchanged {
                let record = entry.record
                let mark = marks[entry.key] ?? {
                    let created = ItemMark(weekKey: record.week.string, itemCode: record.itemCode, dayKey: record.day.string)
                    context.insert(created)
                    return created
                }()
                mark.valueRaw = record.mark?.rawValue ?? ""
                mark.note = record.note
                mark.modifiedAt = now
                if marks[entry.key] == nil { result.created += 1 } else { result.updated += 1 }
            }
        }

        var restoredDays: Set<String> = []
        if preview.entries.hasChanges {
            let entryDays = Set(preview.entries.entries.filter { $0.action != .unchanged }.map { $0.record.day.string }).sorted()
            let entries = Dictionary(grouping: measureEntries(entryDays)) { "\($0.code)|\($0.dayKey)" }
            restoredDays = Set(entryDays)
            for entry in preview.entries.entries where entry.action != .unchanged {
                for old in entries[entry.key] ?? [] { old.moveToTrash(now: now) }
                let record = entry.record
                if record.parts.isEmpty {
                    let created = MeasureEntry(code: record.code, dayKey: record.day.string, value: record.value)
                    created.text = record.text
                    created.note = record.note
                    created.isEstimate = record.estimate
                    created.recordedAt = record.order > 0 ? Date(timeIntervalSince1970: record.order) : now
                    context.insert(created)
                } else {
                    // Single entries come back one by one, at their time of day (R27).
                    for part in record.parts {
                        let created = MeasureEntry(code: record.code, dayKey: record.day.string, value: part.value)
                        created.note = part.note
                        created.isEstimate = part.estimate
                        created.recordedAt = record.day.date(minutes: Double(part.minutes))
                        context.insert(created)
                    }
                }
                if entry.action == .create { result.created += 1 } else { result.updated += 1 }
            }
        }

        // v11 P3.9: new blocks and notes are made one after the other in the file's order (1 ms apart), so the next
        // backup writes them in the same order.
        var sequence: Double = 0
        func nextCreated() -> Date {
            defer { sequence += 1 }
            return now.addingTimeInterval(sequence / 1000)
        }
        if preview.work.hasChanges {
            let blocks = workBlocks(nil).latest(by: \.recordID, modified: \.modifiedAt)
            for entry in preview.work.entries where entry.action != .unchanged {
                let record = entry.record
                let block = blocks[entry.key] ?? {
                    let created = WorkBlock(dayKey: record.day.string, categoryKey: record.categoryKey, task: record.task,
                                            powerHours: record.powerHours)
                    created.importID = record.id
                    created.createdAt = nextCreated()
                    context.insert(created)
                    result.insertedWork.append(created.uuid)
                    return created
                }()
                if blocks[entry.key] == nil { result.created += 1 } else { result.updated += 1 }
                block.dayKey = record.day.string
                block.categoryKey = record.categoryKey
                // An empty description never replaces an existing one (R21, K1).
                if !record.task.isEmpty || block.task.isEmpty { block.task = record.task }
                block.result = record.result
                block.powerHours = record.powerHours
                block.minutes = Int(record.minutes.rounded())
                block.nextStep = record.nextStep
                block.touch(now: now)
            }
        }

        if preview.notes.hasChanges {
            let notes = dayNotes(nil).latest(by: \.recordID, modified: \.modifiedAt)
            for entry in preview.notes.entries where entry.action != .unchanged {
                let record = entry.record
                let note = notes[entry.key] ?? {
                    let created = DayNote(dayKey: record.day.string, kind: record.kind, text: record.text)
                    created.importID = record.id
                    created.createdAt = nextCreated()
                    context.insert(created)
                    result.insertedNotes.append(created.uuid)
                    return created
                }()
                if notes[entry.key] == nil { result.created += 1 } else { result.updated += 1 }
                note.dayKey = record.day.string
                note.kindRaw = record.kind.rawValue
                note.text = record.text
                note.touch(now: now)
            }
        }

        if preview.reviews.hasChanges {
            let scopes = Set(preview.reviews.entries.filter { $0.action != .unchanged }.map(\.record.scope)).sorted()
            let reflections = self.reflections(scopes).latest(by: \.key, modified: \.modifiedAt)
            for entry in preview.reviews.entries where entry.action != .unchanged {
                let record = entry.record
                let reflection = reflections[entry.key] ?? {
                    let created = Reflection(scope: record.scope, field: record.field)
                    context.insert(created)
                    result.insertedReflections.append(created.uuid)
                    return created
                }()
                if reflections[entry.key] == nil { result.created += 1 } else { result.updated += 1 }
                reflection.text = record.text
                reflection.modifiedAt = now
            }
        }

        if preview.scores.hasChanges {
            let scoreDays = Set(preview.scores.entries.filter { $0.action != .unchanged }.map { $0.record.day.string }).sorted()
            let scores = scoreOverrides(scoreDays).latest(by: \.key, modified: \.modifiedAt)
            for entry in preview.scores.entries where entry.action != .unchanged {
                let record = entry.record
                let score = scores[entry.key] ?? {
                    let created = ScoreOverride(categoryKey: record.categoryKey, dayKey: record.day.string, score: record.score)
                    context.insert(created)
                    return created
                }()
                if scores[entry.key] == nil { result.created += 1 } else { result.updated += 1 }
                score.score = record.score
                score.reason = record.reason
                score.touch(now: now)
            }
        }

        // v9: the grades of old records, one setting per week (an empty archive removes it).
        for week in preview.archiveUpdates.keys.sorted() {
            if let archive = preview.archiveUpdates[week] { writeArchive(archive, week: week, now: now) }
        }
        result.created += preview.grades.creates
        result.updated += preview.grades.updates

        // v10 (§1.1.4): stored records of a backup (`record` rows) by key – a stored copy with a newer
        // `modifiedAt` stays (the preview counts it as unchanged). The inbox comes back the same way.
        // v11 P3.7: the goal year and the catalog switch first (the preview fills them in only where the app has no
        // value), then results, segments and the rest; P3.5: an entry or reading the file brings newer under another
        // day's key loses its old key.
        if preview.records.hasChanges || !preview.removedRecords.isEmpty {
            var change = RecordChange()
            let changed = preview.records.entries.filter { $0.action != .unchanged }
            let plainFirst = changed.filter { PlanCSV.plainSettings.contains($0.record.key) }
                + changed.filter { !PlanCSV.plainSettings.contains($0.record.key) }
            for entry in plainFirst {
                var value: String = entry.record.value
                // `x.sources` is merged, never replaced: a source connected after the backup stays known.
                if entry.record.key == ExchangeInbox.sourcesKey {
                    value = exchangeSources().merging(ExchangeSourceList(value: value)).value
                }
                // P3.7: a plain setting is only filled in (`filledAt`) – a real value that iCloud brings later wins.
                let stamp: Date = PlanCSV.plainSettings.contains(entry.record.key) ? filledAt : now
                writeSetting(entry.record.key, value, now: stamp, change: &change)
                if entry.action == .create { result.created += 1 } else { result.updated += 1 }
            }
            for key in preview.removedRecords { writeSetting(key, nil, now: now, change: &change) }
        }

        // v11 P3.3: a closed week's stored score from the file (`wertung`), exactly – the week is closed if it is open,
        // keeps the file's `score.<week>` and is neither scored here nor asked for (`keeping`). P3.7: a week this restore
        // made (iCloud hadn't brought it yet) is only filled in (`filledAt`) – the real copy that arrives later keeps a
        // score the iPhone gave after the backup (`DuplicateMerge.week` takes the newest closed copy).
        let kept: Set<WeekKey> = Set(preview.document.finalScores.keys)
        result.keptScores = kept
        for (week, final) in preview.document.finalScores.sorted(by: { $0.key < $1.key }) {
            let madeHere: Bool = madePlans[week.string] != nil
            let plan = planToWrite(week)
            var changed = false
            if plan.closedAt == nil {
                plan.closedAt = now
                changed = true
            }
            if plan.finalScore != final.score || plan.finalGoalScores != final.goalScores || plan.finalGoalsScored != final.goalsScored {
                plan.finalScore = final.score
                plan.finalGoalScores = final.goalScores
                plan.finalGoalsScored = final.goalsScored
                changed = true
            }
            if changed { plan.touch(now: madeHere ? filledAt : now) }
        }

        // Closed days from the file (R27) and from the caller (demo, tour). v11 (P3.10): no save before – the
        // import is one save; a day or week this import made is closed on that copy (never a second one).
        let daysToClose = Set(closedDays).union(preview.newClosedDays)
        for day in daysToClose.sorted() {
            let info = dayToWrite(day)
            guard info.closedAt == nil else { continue }
            info.closedAt = now
            info.modifiedAt = now
        }
        for week in closedWeeks { planToWrite(week).closedAt = now }

        result.week = preview.primaryWeek
        AppLog.info("Import: \(result.created) new, \(result.updated) updated, \(result.removedItems.count) removed, \(preview.document.skipped.count) skipped, \(kept.count) scores kept", category: "import")
        // v10 (Grundregel 2): closed weeks before the current segment keep their score. v11 P2.1: maintenance – Mac,
        // Watch and iPad ask the iPhone instead of scoring; P3.3: the weeks with a `wertung` row are kept.
        result.frozenWeeks = commit(rescoring: [], origin: .maintenance, keeping: kept)
        // Closed weeks from the file get their score like any closed week (R27) – closing a week isn't
        // scoring it again, so this happens in an earlier segment too. Not a week whose score the file brings.
        var closedNow: Set<WeekKey> = []
        for week in preview.newClosedWeeks where !kept.contains(week) && !(plan(week)?.isClosed ?? false) {
            closeImportedWeek(week, fillsIn: madePlans[week.string] != nil)
            closedNow.insert(week)
        }
        // v9: a closed week without items whose grades changed gets its recalculation – v11: the one save above sees
        // the changed `archive.<week>` (no save before the closings any more, P3.10) and decides per device (P2.1):
        // the iPhone scores it, Mac, Watch and iPad ask the iPhone; one before the current segment is in `frozenWeeks`.
        // A week closed just now got its score: it isn't left as it was.
        result.frozenWeeks.subtract(closedNow)
        result.frozenWeeks.subtract(kept)
        let finished = Date()
        result.finishedAt = finished
        // v11 P3.2 (3): the days whose values this import wrote, and when – `cleanRestoreDuplicates` compares them with
        // copies that arrive from iCloud later.
        if !restoredDays.isEmpty, !isInMemory {
            RestoreWindow.note(from: now, through: finished, days: restoredDays)
        }
        return result
    }

    /// A week this import closes (also "Widerrufen", which imports the snapshot again). The iPhone scores it like
    /// `closeWeek` – except a week before this install that reads Health (P2.2: its Health values of then aren't here).
    /// Mac, Watch and iPad score it only when they could score the week at all (`canScore`: no Health progress item, or
    /// the sharing covers it) – an import is maintenance (P2.1 (b)): a score without the iPhone's Health values would sync
    /// to every device and stay for good where the iPhone keeps it (`keepsScoreBeforeInstall`, 1.9.0). Such a week is only
    /// closed (Mac, Watch, iPad: and asked for with `force`, the iPhone scores it after the sync); the screens show the
    /// live score until then. `fillsIn`: this import made the week (iCloud may not have brought it yet) – stamped as very
    /// old (P3.7), so a real copy that arrives later keeps its score (`DuplicateMerge.week`). In-memory stores (demo,
    /// tour) score as before.
    func closeImportedWeek(_ week: WeekKey, fillsIn: Bool = false) {
        let scoresHere: Bool = isInMemory || (HealthDevice.scoresHealth ? !keepsScoreBeforeInstall(week) : canScore(week))
        if scoresHere {
            closeWeek(week)
        } else {
            let plan = ensurePlan(week)
            plan.closedAt = Date()
            plan.touch()
            if !HealthDevice.scoresHealth { withoutUndo { writeRescoreRequest(week, force: true) } }
            AppLog.info("Week closed by an import without a score of its own (reads Health)", category: "review")
            save()
        }
        guard fillsIn, !isInMemory, let made = plan(week) else { return }
        made.touch(now: Date(timeIntervalSince1970: 0))
        saveQuietly()
    }

    /// "2026-W45" of an item or measurement key ("2026-W45|1.1-01").
    nonisolated static func weekPart(_ key: String) -> String {
        key.split(separator: "|", maxSplits: 1).first.map(String.init) ?? key
    }

    // MARK: Archive grades (v9, decision 7)

    /// Every week's archive grades (settings `archive.<week>`, the newest copy of each), weeks with an
    /// empty archive left out. v10: one prefix query (§1.1.2) – the settings hold the inbox and the
    /// goals' records too.
    func storedArchives() -> [WeekKey: ArchiveWeek] {
        let settings = settings(prefix: ArchiveWeek.settingPrefix)
        var result: [WeekKey: ArchiveWeek] = [:]
        for (key, setting) in settings.latest(by: \.key, modified: \.modifiedAt) {
            guard let week = ArchiveWeek.week(settingKey: key) else { continue }
            let archive = ArchiveWeek(csv: setting.value, week: week)
            if !archive.isEmpty { result[week] = archive }
        }
        return result
    }

    /// The archive grades of a week (and the source of its value); nil when it has none.
    func archiveGrades(_ week: WeekKey) -> ArchiveWeek? {
        guard let csv = setting(ArchiveWeek.settingKey(week)) else { return nil }
        let archive = ArchiveWeek(csv: csv, week: week)
        return archive.isEmpty ? nil : archive
    }

    /// Stores a week's archive grades; an empty archive removes the setting (every copy). Closed weeks
    /// are scored again on saving (`touchedWeeks`).
    func setArchiveGrades(_ archive: ArchiveWeek, week: WeekKey) {
        writeArchive(archive, week: week, now: Date())
        save()
    }

    /// Writes the setting without saving: the newest copy gets the value, other copies go; nil or an
    /// empty archive deletes them all. Unchanged values are left alone.
    private func writeArchive(_ archive: ArchiveWeek?, week: WeekKey, now: Date) {
        let key = ArchiveWeek.settingKey(week)
        let copies = settings(keys: [key]).sorted { $0.modifiedAt > $1.modifiedAt }
        var stored: ArchiveWeek? = archive
        if let archive, archive.week != week {
            // Grades always belong to the setting's week.
            let moved: [ArchiveGrade] = archive.grades.map { grade in
                var copy = grade
                copy.week = week
                return copy
            }
            stored = ArchiveWeek(week: week, grades: moved, source: archive.source)
        }
        guard let stored, !stored.isEmpty else {
            for copy in copies { context.delete(copy) }
            return
        }
        let value = stored.csv
        if let newest = copies.first {
            if newest.value != value {
                newest.value = value
                newest.modifiedAt = now
            }
            for duplicate in copies.dropFirst() { context.delete(duplicate) }
        } else {
            let created = AppSetting(key: key, value: value)
            created.modifiedAt = now
            context.insert(created)
        }
    }

    // MARK: Archive (U15)

    func archives() -> [WeekArchive] {
        all(WeekArchive.self).sorted { $0.archivedAt > $1.archivedAt }
    }

    /// Moves a week's plan – items, measurements, marks, values, own scores, day closings – into
    /// the archive as one CSV snapshot. Work blocks, notes and reflections stay: they belong to the
    /// day, not to the plan.
    /// v9, `completely` ("Archivdaten dieser Wochen ersetzen", decision 2): also the day types and
    /// notes of the week's days, its archive grades and the value "laut Unterlagen" – everything the
    /// file brings anew; it archives a week without items too. The week row (motto, context) stays.
    /// The snapshot always carries the week's grades, so restoring it brings them back.
    /// v11: it carries the week's plan changes too (`change` rows, P3.7 – restoring it brings back "Auch in den
    /// nächsten Wochen"); only the week is read, through predicates (P3.12).
    @discardableResult
    func archiveWeek(_ week: WeekKey, saving: Bool = true, completely: Bool = false) -> WeekArchive? {
        let key = week.string
        let dayKeys: [String] = week.days.map(\.string)
        let items = planItems([key])
        let measures = measureDefinitions([key])
        if !completely { guard !items.isEmpty || !measures.isEmpty else { return nil } }
        let state: ExistingState = readState(weeks: [week], includeRecords: false, work: .without).state
        if completely { guard state.hasArchiveContent(week) else { return nil } }
        let marks = itemMarks([key])
        let entries = measureEntries(dayKeys)
        let scores = scoreOverrides(dayKeys)
        let planChanges = changes(week)

        var snapshot = exportDocument(weeks: [week], state: state)
        snapshot.goals = []
        snapshot.categories = []
        snapshot.work = []
        snapshot.notes = []
        snapshot.reviews = []
        snapshot.changes = planChanges.compactMap(\.record)
        let archive = WeekArchive(weekKey: key, title: plan(week)?.title ?? "", csv: PlanCSV.export(snapshot),
                                  itemCount: items.count, markCount: snapshot.marks.count)
        context.insert(archive)

        let now = Date()
        for item in items { context.delete(item) }
        for measure in measures { context.delete(measure) }
        for mark in marks { context.delete(mark) }
        for entry in entries { context.delete(entry) }
        for score in scores { context.delete(score) }
        for change in planChanges { context.delete(change) }
        for day in planDays(dayKeys) {
            let typed = completely && (!day.dayType.isEmpty || !day.note.isEmpty)
            guard day.closedAt != nil || typed else { continue }
            day.closedAt = nil
            if completely {
                day.dayType = ""
                day.note = ""
            }
            day.modifiedAt = now
        }
        if completely { writeArchive(nil, week: week, now: now) }
        // v10: the computed category scores go with the final score (a restore closes the week again).
        if !items.isEmpty || completely { writeCategoryScores([:], week: week, now: now) }
        // Every copy of the week row (sync duplicates): merging them later must not bring back a closing
        // or a value laut Unterlagen from an older copy.
        for plan in allPlans() where plan.weekKey == key && plan.deletedAt == nil {
            guard plan.closedAt != nil || plan.finalScore != nil || !plan.finalGoalScores.isEmpty
                || (completely && plan.recordedScore != nil) else { continue }
            plan.closedAt = nil
            plan.finalScore = nil
            plan.finalGoalScores = ""
            plan.finalGoalsScored = 0
            if completely { plan.recordedScore = nil }
            plan.touch()
        }
        let grades: Int = completely ? (state.archiveGrades[week]?.grades.count ?? 0) : 0
        AppLog.info("Archived \(key)\(completely ? " completely" : ""): \(items.count) items, \(marks.count) marks, \(grades) grades",
                    category: "import")
        if saving { save() }
        return archive
    }

    /// Brings an archived week back; what the week has now is archived in its place.
    /// v9, `completely`: everything the week has now goes to the archive (`archiveWeek(_:completely:)`)
    /// and the snapshot alone counts – for a snapshot of "Archivdaten dieser Wochen ersetzen", so grades,
    /// day types and the value the file brought don't stay mixed in. nil decides from the snapshot and
    /// the week (`restoresCompletely`).
    /// v11 P3.7: the snapshot's plan changes (`change` rows) come back too – a change the week has again since is
    /// not doubled.
    @discardableResult
    func restore(_ archive: WeekArchive, completely: Bool? = nil) -> ImportResult {
        let csv = archive.csv
        let week = archive.week
        let whole: Bool = completely ?? week.map { restoresCompletely(archive, week: $0) } ?? false
        if let week, !whole { archiveWeek(week, saving: false) }
        context.delete(archive)
        saveQuietly()
        let replacing: Set<WeekKey> = whole ? Set([week].compactMap { $0 }) : []
        let preview = ImportPreview(text: csv, existing: existingState(), replacing: replacing)
        let result = apply(preview)
        if restoreChanges(preview.document.changes) { saveQuietly() }
        return result
    }

    /// v11 P3.7: plan changes of a snapshot back as `PlanChange` – none twice: a thing (week, Punkt/Messwert, code)
    /// that has a change already keeps it. Returns whether one was added (no save).
    @discardableResult
    func restoreChanges(_ records: [PlanChangeRecord]) -> Bool {
        var added = false
        for (week, group) in Dictionary(grouping: records, by: \.week) {
            var known = Set(changes(week).map { "\($0.targetRaw)|\($0.code)" })
            for record in group where known.insert("\(record.target.rawValue)|\(record.code)").inserted {
                context.insert(PlanChange(record))
                added = true
            }
        }
        if added { AppLog.info("Plan changes restored: \(records.count)", category: "import") }
        return added
    }

    /// v9: whether restoring `archive` into `week` replaces everything the week has: the snapshot has
    /// grades or no plan (only "Archivdaten ersetzen" archives such a week), or the week has no plan now
    /// (it holds archive data, which a plan archive wouldn't move). A normal week with a plan keeps the
    /// v8 behaviour (only its plan goes to the archive), and so do this week and later ones (decision 2).
    private func restoresCompletely(_ archive: WeekArchive, week: WeekKey) -> Bool {
        guard week < DayKey.today().week else { return false }
        // The app's categories, so the snapshot's measurements read as they will on restoring.
        let known = Dictionary(liveCategories().map { ($0.key, $0.title) }, uniquingKeysWith: { first, _ in first })
        let snapshot = PlanCSV.parse(archive.csv, knownCategories: known)
        if !snapshot.grades.isEmpty || (archive.itemCount == 0 && snapshot.measures.isEmpty) { return true }
        return items(week).isEmpty && measures(week).isEmpty
    }

    func delete(_ archive: WeekArchive) {
        context.delete(archive)
        save()
    }

    /// Undo of an import that replaced weeks (R49): every archive comes back, and the archive that
    /// this creates of the imported week is deleted again – unless the week was edited after the
    /// import (v9): then that snapshot stays in Einstellungen → Archiv, so nothing typed since is lost.
    /// v11 P3.4 (d): the work blocks, notes and reflections the import added go again, and changed days get their
    /// type and note back – before the archives, so a complete restore ends with the snapshot's days. Whether a
    /// week was edited after the import is read first, before this changes anything. The weeks whose days or work
    /// blocks went back are scored again at the end like any closed week the user changes (a restore in between saves
    /// them quietly, so the last save names them).
    func undoImport(_ result: ImportResult) {
        let edited: [Bool] = result.archives.map { archive in
            archive.week.flatMap { week in result.finishedAt.map { weekChanged(week, since: $0) } } ?? false
        }
        let undone: Set<WeekKey> = takeBackAdded(result)
        for (index, archive) in result.archives.enumerated() {
            let weekKey = archive.weekKey
            let before = Set(archives().filter { $0.weekKey == weekKey }.map(\.uuid))
            // v9: a week that went to the archive completely is replaced completely again.
            let completely: Bool = archive.week.map { result.completeWeeks.contains($0) } ?? false
            restore(archive, completely: completely)
            if edited[index] {
                AppLog.info("Undo kept the snapshot of \(weekKey): edited after the import", category: "import")
                continue
            }
            for created in archives() where created.weekKey == weekKey && !before.contains(created.uuid) {
                context.delete(created)
            }
        }
        commit(rescoring: undone)
    }

    /// v11 P3.4 (d): deletes the blocks, notes and reflections an import added (by uuid; one merged away since is
    /// simply gone) and gives the days it changed their type and note back. No save. Returns the weeks of the blocks
    /// and days it changed (their score can change).
    private func takeBackAdded(_ result: ImportResult) -> Set<WeekKey> {
        let now = Date()
        var weeks: Set<WeekKey> = []
        let blockIDs = result.insertedWork
        if !blockIDs.isEmpty {
            let wanted = Set(blockIDs)
            let blocks: [WorkBlock] = (try? context.fetch(FetchDescriptor<WorkBlock>(predicate: #Predicate<WorkBlock> { blockIDs.contains($0.uuid) })))
                ?? all(WorkBlock.self).filter { wanted.contains($0.uuid) }
            for block in blocks {
                if let day = DayKey(block.dayKey) { weeks.insert(day.week) }
                context.delete(block)
            }
        }
        let noteIDs = result.insertedNotes
        if !noteIDs.isEmpty {
            let wanted = Set(noteIDs)
            let notes: [DayNote] = (try? context.fetch(FetchDescriptor<DayNote>(predicate: #Predicate<DayNote> { noteIDs.contains($0.uuid) })))
                ?? all(DayNote.self).filter { wanted.contains($0.uuid) }
            for note in notes { context.delete(note) }
        }
        let reflectionIDs = result.insertedReflections
        if !reflectionIDs.isEmpty {
            let wanted = Set(reflectionIDs)
            let reflections: [Reflection] = (try? context.fetch(FetchDescriptor<Reflection>(predicate: #Predicate<Reflection> {
                reflectionIDs.contains($0.uuid)
            }))) ?? all(Reflection.self).filter { wanted.contains($0.uuid) }
            for reflection in reflections { context.delete(reflection) }
        }
        var seen: Set<DayKey> = []
        for before in result.daysBefore where seen.insert(before.day).inserted {
            let day = ensureDay(before.day)
            guard day.dayType != before.dayType || day.note != before.note else { continue }
            day.dayType = before.dayType
            day.note = before.note
            day.modifiedAt = now
            weeks.insert(before.day.week)
        }
        let count = blockIDs.count + noteIDs.count + reflectionIDs.count
        if count + seen.count > 0 {
            AppLog.info("Undo of an import: \(count) added record(s), \(seen.count) day(s)", category: "import")
        }
        return weeks
    }

    /// v9: whether anything of `week` was changed after `date` – its row, days, items, measurements,
    /// marks, values, own scores or archive grades (deleted ones count too). v11: through predicates (P3.12).
    private func weekChanged(_ week: WeekKey, since date: Date) -> Bool {
        let key = week.string
        let dayKeys: [String] = week.days.map(\.string)
        if allPlans().contains(where: { $0.weekKey == key && $0.modifiedAt > date }) { return true }
        if planDays(dayKeys).contains(where: { $0.modifiedAt > date }) { return true }
        let items: [PlanItem] = (try? context.fetch(FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key })))
            ?? all(PlanItem.self).filter { $0.weekKey == key }
        if items.contains(where: { $0.modifiedAt > date }) { return true }
        let measures: [MeasureDefinition] = (try? context.fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> {
            $0.weekKey == key
        }))) ?? all(MeasureDefinition.self).filter { $0.weekKey == key }
        if measures.contains(where: { $0.modifiedAt > date }) { return true }
        if itemMarks([key]).contains(where: { $0.modifiedAt > date }) { return true }
        let entries: [MeasureEntry] = (try? context.fetch(FetchDescriptor<MeasureEntry>(predicate: #Predicate<MeasureEntry> {
            dayKeys.contains($0.dayKey)
        }))) ?? all(MeasureEntry.self).filter { dayKeys.contains($0.dayKey) }
        if entries.contains(where: { $0.modifiedAt > date }) { return true }
        let scores: [ScoreOverride] = (try? context.fetch(FetchDescriptor<ScoreOverride>(predicate: #Predicate<ScoreOverride> {
            dayKeys.contains($0.dayKey)
        }))) ?? all(ScoreOverride.self).filter { dayKeys.contains($0.dayKey) }
        if scores.contains(where: { $0.modifiedAt > date }) { return true }
        return settings(keys: [ArchiveWeek.settingKey(week)]).contains { $0.modifiedAt > date }
    }

    /// Everything (or some weeks) in the import format – backup, sharing with the planning AI, editing elsewhere.
    /// v9: with the archive grades of the weeks (`category_score` / `goal_score` rows, the week row's source).
    /// v11: some weeks read only those weeks (P3.12, no records); everything (the backup, "Sicherung erstellen…")
    /// starts with the `sicherung` row (P3.6) and carries the closed weeks' final scores (`wertung`, P3.3).
    func exportDocument(weeks: Set<WeekKey>? = nil) -> PlanCSV.Document {
        let read = readState(weeks: weeks, includeRecords: weeks == nil, work: weeks == nil ? .all : .weekDays)
        return exportDocument(weeks: weeks, state: read.state, workOrder: read.workOrder, noteOrder: read.noteOrder)
    }

    /// v11 P3.6: the `sicherung` row – when, which app and build, which kind of device (never its name).
    static func backupInfo(now: Date = Date()) -> PlanCSV.BackupInfo {
        let build: SyncBuild = TrackerStore.currentBuild
        let app = PlanCSV.BackupInfo.appName(version: build.version.isEmpty ? "?" : build.version,
                                             build: build.build > 0 ? String(build.build) : "")
        return PlanCSV.BackupInfo(date: now, app: app, device: SyncDeviceKind.current)
    }

    /// `exportDocument(weeks:)` from a state already read. `workOrder`/`noteOrder`: when each block and note was made
    /// (by record id) – they go out in that order (P3.9).
    private func exportDocument(weeks: Set<WeekKey>?, state: ExistingState, workOrder: [String: Date] = [:],
                                noteOrder: [String: Date] = [:]) -> PlanCSV.Document {
        func keep(_ week: WeekKey) -> Bool { weeks?.contains(week) ?? true }
        func keep(day: DayKey) -> Bool { weeks?.contains(day.week) ?? true }
        var doc = PlanCSV.Document()
        doc.goals = Array(state.goals.values)
        doc.categories = Array(state.categories.values)
        doc.weeks = state.weeks.values.filter { keep($0.week) }
        doc.days = state.days.values.filter { keep(day: $0.day) && (!$0.dayType.isEmpty || !$0.note.isEmpty) }
        doc.items = state.items.values.filter { keep($0.week) }
        doc.measures = state.measures.values.filter { keep($0.week) }
        // v10: a cleared mark that keeps a connected app's ✓ away (or holds a note) comes along, so a
        // restore or an Undo of an import brings the clear back (Grundregel 1).
        doc.marks = MarkRecord.exported(state.marks.values.filter { keep($0.week) }, items: doc.items, measures: doc.measures)
        if weeks == nil {
            // v11 P3.9 (3): the backup leaves out marks of items it doesn't have (an item deleted since) – never an
            // archive snapshot or a week's CSV.
            let itemKeys = Set(doc.items.map(\.key))
            doc.marks = doc.marks.filter { itemKeys.contains(ItemRecord.key(week: $0.week, code: $0.itemCode)) }
        }
        doc.entries = state.entries.values.filter { keep(day: $0.day) }
        // v11 P3.9 (2): blocks and notes in the order they were made (the writer keeps it within a day).
        func made(_ order: [String: Date], _ id: String) -> Date { order[id] ?? .distantPast }
        doc.work = state.work.values.filter { keep(day: $0.day) }
            .sorted { (made(workOrder, $0.id), $0.id) < (made(workOrder, $1.id), $1.id) }
        doc.notes = state.notes.values.filter { keep(day: $0.day) }
            .sorted { (made(noteOrder, $0.id), $0.id) < (made(noteOrder, $1.id), $1.id) }
        doc.reviews = state.reviews.values.filter { review in
            if let week = WeekKey(review.scope) { return keep(week) }
            if let day = DayKey(review.scope) { return keep(day: day) }
            return false
        }
        doc.scores = state.scores.values.filter { keep(day: $0.day) }
        // Closings travel as flags; a closed day without type or note still gets its day row (R27).
        doc.closedDays = state.closedDays.filter { keep(day: $0) }
        doc.closedWeeks = state.closedWeeks.filter { keep($0) }
        doc.addArchives(state.archiveGrades.values.filter { keep($0.week) }.sorted { $0.week < $1.week })
        // v10 (§1.1.4): the backup ("Sicherung erstellen…") carries every v10 record, the inbox included; an
        // export of some weeks (a week for ChatGPT, an archive snapshot) none. v11: and the goal year (P3.7), the
        // `sicherung` row (P3.6) and the stored final scores (P3.3).
        if weeks == nil {
            doc.records = state.records.values.sorted { $0.key < $1.key }
            doc.backupInfo = Self.backupInfo()
            doc.finalScores = state.finalScores.filter { state.closedWeeks.contains($0.key) }
        }
        return doc
    }

    func exportCSV(weeks: Set<WeekKey>? = nil) -> String {
        PlanCSV.export(exportDocument(weeks: weeks))
    }

    // MARK: Past weeks (v8)

    /// Whether a week has at least one item (one narrow lookup).
    private func hasPlannedItems(_ week: WeekKey) -> Bool {
        let key = week.string
        var descriptor = FetchDescriptor<PlanItem>(predicate: #Predicate<PlanItem> { $0.weekKey == key && $0.deletedAt == nil })
        descriptor.fetchLimit = 1
        let found: [PlanItem] = (try? context.fetch(descriptor)) ?? []
        return !found.isEmpty
    }

    /// The planned week (with items) nearest to `week`, before or after it – never `week` itself.
    /// At the same distance both ways the earlier one. Candidates come from the small week table (R84).
    func nearestPlannedWeek(to week: WeekKey) -> WeekKey? {
        let candidates = Set(allPlans().filter { $0.deletedAt == nil }.compactMap(\.week)).subtracting([week])
        let origin = week.monday.ordinal
        let ordered = candidates.sorted { a, b in
            let left = abs(a.monday.ordinal - origin)
            let right = abs(b.monday.ordinal - origin)
            return left == right ? a < b : left < right
        }
        return ordered.first { hasPlannedItems($0) }
    }

    /// The week whose items a past week is filled in on: the week itself when it has a plan, else the
    /// nearest planned one. Several weeks: the latest of them decides; none (weeks from the
    /// attachments): last week.
    func pastTemplateWeek(for weeks: [WeekKey], today: DayKey) -> WeekKey? {
        let anchor = weeks.max() ?? today.week.adding(weeks: -1)
        if hasPlannedItems(anchor) { return anchor }
        return nearestPlannedWeek(to: anchor)
    }

    /// Number of items of a week (newest copy of each), for "Vorlage: KW46 · 24 Punkte".
    func plannedItemCount(_ week: WeekKey) -> Int {
        items(week).latest(by: \.key, modified: \.modifiedAt).count
    }

    /// Path a: `source`'s plan as the plan of `target` – items and measurements with the same ids,
    /// without marks, values and day types (those belong to the target: Krank, Urlaub …). The target's
    /// week row (motto, paper score) stays. Runs through the normal import, so a planned target is
    /// archived first and comes back with Undo (R49).
    @discardableResult
    func copyPlan(from source: WeekKey, to target: WeekKey) -> ImportResult {
        var document = exportDocument(weeks: [source]).repeated(from: source, to: target)
        document.days = []
        if let current = plan(target)?.record { document.weeks = [current] }
        AppLog.info("Plan \(source.string) copied to \(target.string)", category: "import")
        return apply(ImportPreview(document: document, existing: existingState(for: document)))
    }

    /// Path c: a past week's score from paper (`WeekPlan.recordedScore`, 0–10); nil removes it. A new
    /// week before KW42 2026 gets the earlier model, like a CSV week row without flags.
    func setPaperScore(_ score: Double?, week: WeekKey) {
        let isNew = plan(week) == nil
        let weekPlan = ensurePlan(week)
        weekPlan.recordedScore = score.map { min(10, max(0, $0)) }
        if isNew, week < WeekRecord.scoringChange { weekPlan.scoringModel = "alt" }
        weekPlan.touch()
        AppLog.info("Paper score set for \(week.string)", category: "import")
        save()
    }

    /// Path b: the prompt for ChatGPT – goals, categories, the template week's items and measurements
    /// with their ids, the CSV format. `weeks` empty: the weeks of the attached photos, PDFs or tables.
    func pastWeekPrompt(weeks: [WeekKey], today: DayKey) -> String {
        var templateItems: [ItemRecord] = []
        var templateMeasures: [MeasureRecord] = []
        if let source = pastTemplateWeek(for: weeks, today: today) {
            templateItems = items(source).latest(by: \.key, modified: \.modifiedAt).values.compactMap(\.record)
            templateMeasures = measures(source).latest(by: \.key, modified: \.modifiedAt).values.compactMap(\.record)
        }
        var goals = liveGoals().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        if goals.isEmpty { goals = Template.goals }
        var categories = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        if categories.isEmpty { categories = Template.categories }
        AppLog.info("Past-week prompt built (\(weeks.count) weeks, \(templateItems.count) items)", category: "import")
        return PastWeekPrompt.text(weeks: weeks, items: templateItems, categories: categories, goals: goals,
                                   measures: templateMeasures)
    }

    /// Path b: a file of past weeks, read for the preview (decision 8). Blank fields of fixed items count
    /// as ✗ when asked (`blanksAsMissed`, never in archive weeks); weeks before this week are closed with
    /// their days – the days the file brings and those the app already has marks or a day type for.
    /// v9, `replacingArchives` ("Archivdaten dieser Wochen ersetzen"): every past week of the file that
    /// the app has something for goes to the archive completely when applied (`preview.replacingWeeks`);
    /// this week and later ones are never replaced. The logic lives in ThaliaCore
    /// (`ImportPreview.pastWeeks`, tested there).
    /// v11 P3.12: the file is read against the structure first, then compared with only the weeks it is about.
    func pastPreview(_ text: String, blanksAsMissed: Bool, today: DayKey, replacingArchives: Bool = false) -> ImportPreview {
        let structure = existingState(weeks: [], includeRecords: false, includeWork: false)
        let probe = Self.probe(text, structure: structure)
        let existing = existingState(for: probe)
        let document: PlanCSV.Document = probe.marks.isEmpty ? probe
            : PlanCSV.parse(text, knownCategories: existing.categoryTitles, knownMeasures: existing.measureCodes,
                            knownItems: existing.itemKeys, knownGoals: Set(existing.goals.keys))
        return ImportPreview.pastWeeks(document, existing: existing, blanksAsMissed: blanksAsMissed,
                                       replacingArchives: replacingArchives, today: today)
    }

    /// Imports a whole document without a preview (demo and tour data).
    /// Entries go in one by one (an import keeps one value per measurement and day). The demo's
    /// archive week (v9, `Demo.archiveWeek`) gets its grades through `apply` (`archiveUpdates`) and is
    /// closed like an archive week after a past-week import (decision 1), so its goal values reach the
    /// goal charts and the goal review.
    func seed(_ content: Demo.Content) {
        var document = content.document
        let entries = document.entries
        document.entries = []
        apply(ImportPreview(document: document, existing: existingState()), closedDays: content.closedDays, closedWeeks: content.closedWeeks)
        for record in entries {
            let entry = MeasureEntry(code: record.code, dayKey: record.day.string, value: record.value)
            entry.isEstimate = record.estimate
            entry.recordedAt = record.day.startDate().addingTimeInterval(7 * 3600 + record.order * 4 * 3600)
            context.insert(entry)
        }
        save()
        let thisWeek = DayKey.today().week
        let planned = Set(document.items.map(\.week))
        let archiveWeeks = Set(document.grades.map(\.week)).filter { $0 < thisWeek && !planned.contains($0) }
        for week in Set(content.closedWeeks).union(archiveWeeks).sorted() { closeWeek(week) }
    }
}

// MARK: Restored values and their originals (v11 P3.2 (3))

extension TrackerStore {
    /// v11 P3.2 (3): values have no id – a backup read in before iCloud brought the originals leaves them twice.
    /// Per code and day of an import's window (`RestoreWindow`, 7 days): when the values made in the window are the
    /// same as those made before it – value (to the CSV's four decimals), text, note, estimate; never the time – the
    /// window's copies go to "Zuletzt gelöscht". Runs after every sync (`AppModel.afterSync`); maintenance without
    /// Undo, saved as maintenance (Mac, Watch and iPad ask the iPhone to score). Returns how many values went.
    @discardableResult
    func cleanRestoreDuplicates(now: Date = Date()) -> Int {
        guard !isInMemory else { return 0 }
        let windows = RestoreWindow.current(now: now)
        guard !windows.isEmpty else { return 0 }
        return withoutUndo { () -> Int in
            var trashed = 0
            for window in windows {
                let groups = Dictionary(grouping: measureEntries(window.days)) { "\($0.code)|\($0.dayKey)" }
                for group in groups.values {
                    let made = group.filter { $0.createdAt >= window.start && $0.createdAt <= window.end }
                    let before = group.filter { $0.createdAt < window.start }
                    guard !made.isEmpty, !before.isEmpty, Self.sameValues(made, before) else { continue }
                    for entry in made { entry.moveToTrash(now: now) }
                    trashed += made.count
                }
            }
            guard trashed > 0 else { return 0 }
            noteMaintenanceRemoval()
            commit(rescoring: [], origin: .maintenance)
            AppLog.info("Restored values that arrived twice: \(trashed) moved to the trash", category: "import")
            return trashed
        }
    }

    /// The same values, as a multiset: value to four decimals (what a backup writes), text, note, estimate.
    nonisolated static func sameValues(_ a: [MeasureEntry], _ b: [MeasureEntry]) -> Bool {
        func key(_ entry: MeasureEntry) -> String {
            let value: String = entry.value.map { $0.isFinite && abs($0) < 1e12 ? String(Int64(($0 * 10_000).rounded())) : "x" } ?? "-"
            return "\(value)|\(entry.text)|\(entry.note)|\(entry.isEstimate)"
        }
        return a.map(key).sorted() == b.map(key).sorted()
    }
}

/// v11 P3.2 (3): when an import wrote values and on which days – UserDefaults `restore.window` (per device), each
/// window kept 7 days. `TrackerStore.cleanRestoreDuplicates` compares the values made in a window with older copies.
enum RestoreWindow {
    static let key = "restore.window"
    static let lifetime: TimeInterval = 7 * 86_400
    /// At most this many windows are kept (the newest).
    static let limit = 8

    struct Window: Equatable {
        let start: Date
        let end: Date
        /// "2026-11-20" …
        let days: [String]
    }

    /// Notes an import that wrote values on `days` between `start` and `end`.
    static func note(from start: Date, through end: Date, days: Set<String>, defaults: UserDefaults = .standard) {
        var windows = current(now: end, defaults: defaults)
        windows.append(Window(start: start, end: end, days: days.sorted()))
        store(Array(windows.suffix(limit)), defaults: defaults)
    }

    /// The windows of the last 7 days, oldest first (older ones are forgotten).
    static func current(now: Date = Date(), defaults: UserDefaults = .standard) -> [Window] {
        let stored = defaults.array(forKey: key) as? [[String: Any]] ?? []
        let windows: [Window] = stored.compactMap { item in
            guard let start = item["start"] as? Date, let end = item["end"] as? Date else { return nil }
            return Window(start: start, end: end, days: item["days"] as? [String] ?? [])
        }
        let fresh = windows.filter { now.timeIntervalSince($0.end) < lifetime && !$0.days.isEmpty }
        if fresh.count != stored.count { store(fresh, defaults: defaults) }
        return fresh
    }

    private static func store(_ windows: [Window], defaults: UserDefaults) {
        guard !windows.isEmpty else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(windows.map { ["start": $0.start, "end": $0.end, "days": $0.days] as [String: Any] }, forKey: key)
    }
}
