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
            return EntryRecord(code: first.code, day: day, value: value, text: text, note: note,
                               estimate: sorted.contains(where: \.isEstimate), parts: parts)
        }
    }

    /// What the app has, keyed the way the import compares – always the newest version of a record
    /// that exists twice (R27), plus the closed days and weeks and (v9) the archive grades per week.
    func existingState() -> ExistingState {
        var state = ExistingState()
        for (key, goal) in liveGoals().latest(by: \.key, modified: \.modifiedAt) { state.goals[key] = goal.record }
        for (key, category) in liveCategories().latest(by: \.key, modified: \.modifiedAt) { state.categories[key] = category.record }
        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        for (key, plan) in plans {
            if let record = plan.record { state.weeks[key] = record }
            if plan.isClosed, let week = plan.week { state.closedWeeks.insert(week) }
        }
        for (key, day) in all(PlanDay.self).latest(by: \.dayKey, modified: \.modifiedAt) {
            if let record = day.record { state.days[key] = record }
            if day.isClosed, let date = day.day { state.closedDays.insert(date) }
        }
        let items = all(PlanItem.self).filter { $0.deletedAt == nil }
        for (key, item) in items.latest(by: \.key, modified: \.modifiedAt) { if let record = item.record { state.items[key] = record } }
        let measures = all(MeasureDefinition.self).filter { $0.deletedAt == nil }
        for (key, measure) in measures.latest(by: \.key, modified: \.modifiedAt) { if let record = measure.record { state.measures[key] = record } }
        let marks = all(ItemMark.self).latest(by: { "\($0.weekKey)|\($0.itemCode)|\($0.dayKey)" }, modified: \.modifiedAt)
        for mark in marks.values { if let record = mark.record { state.marks[record.key] = record } }
        for entry in Self.aggregate(all(MeasureEntry.self), measures: measures) { state.entries[entry.key] = entry }
        let blocks = all(WorkBlock.self).filter { $0.deletedAt == nil }.latest(by: \.recordID, modified: \.modifiedAt)
        for block in blocks.values { if let record = block.record { state.work[record.id] = record } }
        let notes = all(DayNote.self).filter { $0.deletedAt == nil }.latest(by: \.recordID, modified: \.modifiedAt)
        for note in notes.values { if let record = note.record { state.notes[record.id] = record } }
        for reflection in all(Reflection.self).latest(by: \.key, modified: \.modifiedAt).values {
            state.reviews[reflection.key] = reflection.record
        }
        let scores = all(ScoreOverride.self).filter { $0.deletedAt == nil }.latest(by: \.key, modified: \.modifiedAt)
        for score in scores.values { if let record = score.record { state.scores[record.key] = record } }
        state.archiveGrades = storedArchives()
        return state
    }

    func preview(_ text: String) -> ImportPreview {
        ImportPreview(text: text, existing: existingState())
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
    @discardableResult
    func apply(_ preview: ImportPreview, closedDays: [DayKey] = [], closedWeeks: [WeekKey] = []) -> ImportResult {
        guard preview.replacedWeeks.isEmpty else {
            let complete = Set(preview.replacingWeeks)
            var archives: [WeekArchive] = []
            for week in preview.replacedWeeks {
                if let archive = archiveWeek(week, saving: false, completely: complete.contains(week)) { archives.append(archive) }
            }
            try? context.save()
            var result = apply(ImportPreview(document: preview.document, existing: existingState()),
                               closedDays: closedDays, closedWeeks: closedWeeks)
            result.archived = preview.replacedWeeks
            result.archives = archives
            result.completeWeeks = complete
            return result
        }
        var result = ImportResult()
        let now = Date()

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

        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        for entry in preview.weeks.entries where entry.action != .unchanged {
            if let plan = plans[entry.key] {
                plan.update(from: entry.record)
                plan.importedAt = now
                plan.touch(now: now)
                result.updated += 1
            } else {
                let plan = WeekPlan(entry.record)
                plan.importedAt = now
                context.insert(plan)
                result.created += 1
            }
        }

        let days = all(PlanDay.self).latest(by: \.dayKey, modified: \.modifiedAt)
        for entry in preview.days.entries where entry.action != .unchanged {
            let day = days[entry.key] ?? {
                let created = PlanDay(dayKey: entry.key)
                context.insert(created)
                result.created += 1
                return created
            }()
            if days[entry.key] != nil { result.updated += 1 }
            day.dayType = entry.record.dayType
            day.note = entry.record.note
            day.modifiedAt = now
        }

        let items = all(PlanItem.self).filter { $0.deletedAt == nil }.latest(by: \.key, modified: \.modifiedAt)
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

        let measures = all(MeasureDefinition.self).filter { $0.deletedAt == nil }.latest(by: \.key, modified: \.modifiedAt)
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
            let marks = all(ItemMark.self).latest(by: { "\($0.weekKey)|\($0.itemCode)|\($0.dayKey)" }, modified: \.modifiedAt)
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

        if preview.entries.hasChanges {
            let entries = Dictionary(grouping: all(MeasureEntry.self).filter { $0.deletedAt == nil }) { "\($0.code)|\($0.dayKey)" }
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

        if preview.work.hasChanges {
            let blocks = all(WorkBlock.self).filter { $0.deletedAt == nil }.latest(by: \.recordID, modified: \.modifiedAt)
            for entry in preview.work.entries where entry.action != .unchanged {
                let record = entry.record
                let block = blocks[entry.key] ?? {
                    let created = WorkBlock(dayKey: record.day.string, categoryKey: record.categoryKey, task: record.task,
                                            powerHours: record.powerHours)
                    created.importID = record.id
                    context.insert(created)
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
            let notes = all(DayNote.self).filter { $0.deletedAt == nil }.latest(by: \.recordID, modified: \.modifiedAt)
            for entry in preview.notes.entries where entry.action != .unchanged {
                let record = entry.record
                let note = notes[entry.key] ?? {
                    let created = DayNote(dayKey: record.day.string, kind: record.kind, text: record.text)
                    created.importID = record.id
                    context.insert(created)
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
            let reflections = all(Reflection.self).latest(by: \.key, modified: \.modifiedAt)
            for entry in preview.reviews.entries where entry.action != .unchanged {
                let record = entry.record
                let reflection = reflections[entry.key] ?? {
                    let created = Reflection(scope: record.scope, field: record.field)
                    context.insert(created)
                    return created
                }()
                if reflections[entry.key] == nil { result.created += 1 } else { result.updated += 1 }
                reflection.text = record.text
                reflection.modifiedAt = now
            }
        }

        if preview.scores.hasChanges {
            let scores = all(ScoreOverride.self).filter { $0.deletedAt == nil }.latest(by: \.key, modified: \.modifiedAt)
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

        // Closed days from the file (R27) and from the caller (demo, tour).
        let daysToClose = Set(closedDays).union(preview.newClosedDays)
        if !daysToClose.isEmpty || !closedWeeks.isEmpty {
            try? context.save()
            for day in daysToClose.sorted() {
                let info = ensureDay(day)
                guard info.closedAt == nil else { continue }
                info.closedAt = now
                info.modifiedAt = now
            }
            for week in closedWeeks { ensurePlan(week).closedAt = now }
        }

        result.week = preview.primaryWeek
        AppLog.info("Import: \(result.created) new, \(result.updated) updated, \(result.removedItems.count) removed, \(preview.document.skipped.count) skipped", category: "import")
        save()
        // Closed weeks from the file get their score like any closed week (R27).
        for week in preview.newClosedWeeks where !(plan(week)?.isClosed ?? false) { closeWeek(week) }
        // v9: a closed week without items whose grades changed gets its recalculation again (the save
        // before the closings doesn't see the change).
        var rescored = false
        for week in preview.archiveUpdates.keys.sorted() {
            guard let plan = plan(week), plan.isClosed, self.items(week).isEmpty else { continue }
            if storeFinalScore(plan) { rescored = true }
        }
        if rescored { save() }
        result.finishedAt = Date()
        return result
    }

    // MARK: Archive grades (v9, decision 7)

    /// Every week's archive grades (settings `archive.<week>`, the newest copy of each), weeks with an
    /// empty archive left out. Few settings exist, so they are filtered in memory.
    func storedArchives() -> [WeekKey: ArchiveWeek] {
        let settings = all(AppSetting.self).filter { $0.key.hasPrefix(ArchiveWeek.settingPrefix) }
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
        let copies = all(AppSetting.self).filter { $0.key == key }.sorted { $0.modifiedAt > $1.modifiedAt }
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
    @discardableResult
    func archiveWeek(_ week: WeekKey, saving: Bool = true, completely: Bool = false) -> WeekArchive? {
        let key = week.string
        let dayKeys = Set(week.days.map(\.string))
        let items = all(PlanItem.self).filter { $0.weekKey == key && $0.deletedAt == nil }
        let measures = all(MeasureDefinition.self).filter { $0.weekKey == key && $0.deletedAt == nil }
        let state: ExistingState
        if completely {
            state = existingState()
            guard state.hasArchiveContent(week) else { return nil }
        } else {
            guard !items.isEmpty || !measures.isEmpty else { return nil }
            state = existingState()
        }
        let marks = all(ItemMark.self).filter { $0.weekKey == key }
        let entries = all(MeasureEntry.self).filter { dayKeys.contains($0.dayKey) && $0.deletedAt == nil }
        let scores = all(ScoreOverride.self).filter { dayKeys.contains($0.dayKey) && $0.deletedAt == nil }

        var snapshot = exportDocument(weeks: [week], state: state)
        snapshot.goals = []
        snapshot.categories = []
        snapshot.work = []
        snapshot.notes = []
        snapshot.reviews = []
        let archive = WeekArchive(weekKey: key, title: plan(week)?.title ?? "", csv: PlanCSV.export(snapshot),
                                  itemCount: items.count, markCount: snapshot.marks.count)
        context.insert(archive)

        let now = Date()
        for item in items { context.delete(item) }
        for measure in measures { context.delete(measure) }
        for mark in marks { context.delete(mark) }
        for entry in entries { context.delete(entry) }
        for score in scores { context.delete(score) }
        for change in all(PlanChange.self) where change.weekKey == key { context.delete(change) }
        for day in all(PlanDay.self) where dayKeys.contains(day.dayKey) {
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
    @discardableResult
    func restore(_ archive: WeekArchive, completely: Bool? = nil) -> ImportResult {
        let csv = archive.csv
        let week = archive.week
        let whole: Bool = completely ?? week.map { restoresCompletely(archive, week: $0) } ?? false
        if let week, !whole { archiveWeek(week, saving: false) }
        context.delete(archive)
        try? context.save()
        let replacing: Set<WeekKey> = whole ? Set([week].compactMap { $0 }) : []
        return apply(ImportPreview(text: csv, existing: existingState(), replacing: replacing))
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
    func undoImport(_ result: ImportResult) {
        for archive in result.archives {
            let weekKey = archive.weekKey
            let before = Set(archives().filter { $0.weekKey == weekKey }.map(\.uuid))
            // v9: a week that went to the archive completely is replaced completely again.
            let completely: Bool = archive.week.map { result.completeWeeks.contains($0) } ?? false
            let edited: Bool = archive.week.flatMap { week in result.finishedAt.map { weekChanged(week, since: $0) } } ?? false
            restore(archive, completely: completely)
            if edited {
                AppLog.info("Undo kept the snapshot of \(weekKey): edited after the import", category: "import")
                continue
            }
            for created in archives() where created.weekKey == weekKey && !before.contains(created.uuid) {
                context.delete(created)
            }
        }
        save()
    }

    /// v9: whether anything of `week` was changed after `date` – its row, days, items, measurements,
    /// marks, values, own scores or archive grades (deleted ones count too).
    private func weekChanged(_ week: WeekKey, since date: Date) -> Bool {
        let key = week.string
        let dayKeys = Set(week.days.map(\.string))
        if allPlans().contains(where: { $0.weekKey == key && $0.modifiedAt > date }) { return true }
        if all(PlanDay.self).contains(where: { dayKeys.contains($0.dayKey) && $0.modifiedAt > date }) { return true }
        if all(PlanItem.self).contains(where: { $0.weekKey == key && $0.modifiedAt > date }) { return true }
        if all(MeasureDefinition.self).contains(where: { $0.weekKey == key && $0.modifiedAt > date }) { return true }
        if all(ItemMark.self).contains(where: { $0.weekKey == key && $0.modifiedAt > date }) { return true }
        if all(MeasureEntry.self).contains(where: { dayKeys.contains($0.dayKey) && $0.modifiedAt > date }) { return true }
        if all(ScoreOverride.self).contains(where: { dayKeys.contains($0.dayKey) && $0.modifiedAt > date }) { return true }
        let setting = ArchiveWeek.settingKey(week)
        return all(AppSetting.self).contains { $0.key == setting && $0.modifiedAt > date }
    }

    /// Everything (or some weeks) in the import format – backup, sharing with the planning AI, editing elsewhere.
    /// v9: with the archive grades of the weeks (`category_score` / `goal_score` rows, the week row's source).
    func exportDocument(weeks: Set<WeekKey>? = nil) -> PlanCSV.Document {
        exportDocument(weeks: weeks, state: existingState())
    }

    /// `exportDocument(weeks:)` from a state already read.
    private func exportDocument(weeks: Set<WeekKey>?, state: ExistingState) -> PlanCSV.Document {
        func keep(_ week: WeekKey) -> Bool { weeks?.contains(week) ?? true }
        func keep(day: DayKey) -> Bool { weeks?.contains(day.week) ?? true }
        var doc = PlanCSV.Document()
        doc.goals = Array(state.goals.values)
        doc.categories = Array(state.categories.values)
        doc.weeks = state.weeks.values.filter { keep($0.week) }
        doc.days = state.days.values.filter { keep(day: $0.day) && (!$0.dayType.isEmpty || !$0.note.isEmpty) }
        doc.items = state.items.values.filter { keep($0.week) }
        doc.measures = state.measures.values.filter { keep($0.week) }
        doc.marks = state.marks.values.filter { keep($0.week) && $0.mark != nil }
        doc.entries = state.entries.values.filter { keep(day: $0.day) }
        doc.work = state.work.values.filter { keep(day: $0.day) }
        doc.notes = state.notes.values.filter { keep(day: $0.day) }
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
        return apply(ImportPreview(document: document, existing: existingState()))
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
    func pastPreview(_ text: String, blanksAsMissed: Bool, today: DayKey, replacingArchives: Bool = false) -> ImportPreview {
        let existing = existingState()
        let document = PlanCSV.parse(text, knownCategories: existing.categoryTitles, knownMeasures: existing.measureCodes,
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
