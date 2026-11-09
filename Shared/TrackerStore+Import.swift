import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

extension TrackerStore {
    private func all<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    /// One value per measurement and day, the way exports write them and imports compare them.
    static func aggregate(_ entries: [MeasureEntry], measures: [MeasureDefinition]) -> [EntryRecord] {
        var aggregationByWeekCode: [String: Aggregation] = [:]
        for measure in measures where measure.deletedAt == nil {
            aggregationByWeekCode["\(measure.weekKey)|\(measure.code)"] = Aggregation(token: measure.aggregationRaw) ?? .sum
        }
        let groups = Dictionary(grouping: entries.filter { $0.deletedAt == nil }) { "\($0.code)|\($0.dayKey)" }
        return groups.values.compactMap { group -> EntryRecord? in
            let sorted = group.sorted { $0.recordedAt < $1.recordedAt }
            guard let first = sorted.first, let day = DayKey(first.dayKey) else { return nil }
            let aggregation = aggregationByWeekCode["\(day.week.string)|\(first.code)"] ?? .sum
            let value = aggregation.apply(sorted.compactMap(\.value))
            let text = sorted.map(\.text).filter { !$0.isEmpty }.last ?? ""
            let note = sorted.map(\.note).filter { !$0.isEmpty }.joined(separator: "; ")
            return EntryRecord(code: first.code, day: day, value: value, text: text, note: note, estimate: sorted.contains(where: \.isEstimate))
        }
    }

    /// What the app has, keyed the way the import compares.
    func existingState() -> ExistingState {
        var state = ExistingState()
        for (key, goal) in liveGoals().latest(by: \.key, modified: \.modifiedAt) { state.goals[key] = goal.record }
        for (key, category) in liveCategories().latest(by: \.key, modified: \.modifiedAt) { state.categories[key] = category.record }
        for plan in allPlans() where plan.deletedAt == nil { if let record = plan.record { state.weeks[plan.weekKey] = record } }
        for (key, day) in all(PlanDay.self).latest(by: \.dayKey, modified: \.modifiedAt) { if let record = day.record { state.days[key] = record } }
        let items = all(PlanItem.self).filter { $0.deletedAt == nil }
        for (key, item) in items.latest(by: \.key, modified: \.modifiedAt) { if let record = item.record { state.items[key] = record } }
        let measures = all(MeasureDefinition.self).filter { $0.deletedAt == nil }
        for (key, measure) in measures.latest(by: \.key, modified: \.modifiedAt) { if let record = measure.record { state.measures[key] = record } }
        for mark in all(ItemMark.self) { if let record = mark.record { state.marks[record.key] = record } }
        for entry in Self.aggregate(all(MeasureEntry.self), measures: measures) { state.entries[entry.key] = entry }
        for block in all(WorkBlock.self) where block.deletedAt == nil {
            if let record = block.record { state.work[record.id] = record }
        }
        for note in all(DayNote.self) where note.deletedAt == nil { if let record = note.record { state.notes[record.id] = record } }
        for reflection in all(Reflection.self) { state.reviews[reflection.key] = reflection.record }
        for score in all(ScoreOverride.self) where score.deletedAt == nil { if let record = score.record { state.scores[record.key] = record } }
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
        var week: WeekKey?

        var summary: String {
            var parts = ["\(created) neu", "\(updated) aktualisiert"]
            if !removedItems.isEmpty { parts.append("\(removedItems.count) entfallen") }
            if !archived.isEmpty { parts.append(archived.map(\.label).joined(separator: ", ") + " archiviert") }
            return parts.joined(separator: " · ")
        }
    }

    /// Applies a previewed file. A week the file plans anew replaces the existing one: the old plan
    /// with its marks and values goes to the archive first (U15), so only the new week counts.
    /// Unchanged rows are left alone.
    @discardableResult
    func apply(_ preview: ImportPreview, closedDays: [DayKey] = [], closedWeeks: [WeekKey] = []) -> ImportResult {
        guard preview.replacedWeeks.isEmpty else {
            for week in preview.replacedWeeks { archiveWeek(week, saving: false) }
            try? context.save()
            var result = apply(ImportPreview(document: preview.document, existing: existingState()),
                               closedDays: closedDays, closedWeeks: closedWeeks)
            result.archived = preview.replacedWeeks
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
                let created = MeasureEntry(code: record.code, dayKey: record.day.string, value: record.value)
                created.text = record.text
                created.note = record.note
                created.isEstimate = record.estimate
                created.recordedAt = record.order > 0 ? Date(timeIntervalSince1970: record.order) : now
                context.insert(created)
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
                block.task = record.task
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

        if !closedDays.isEmpty || !closedWeeks.isEmpty {
            try? context.save()
            for day in closedDays { ensureDay(day).closedAt = now }
            for week in closedWeeks { ensurePlan(week).closedAt = now }
        }

        result.week = preview.primaryWeek
        AppLog.info("Import: \(result.created) new, \(result.updated) updated, \(result.removedItems.count) removed, \(preview.document.skipped.count) skipped", category: "import")
        save()
        return result
    }

    // MARK: Archive (U15)

    func archives() -> [WeekArchive] {
        all(WeekArchive.self).sorted { $0.archivedAt > $1.archivedAt }
    }

    /// Moves a week's plan – items, measurements, marks, values, own scores, day closings – into
    /// the archive as one CSV snapshot. Work blocks, notes and reflections stay: they belong to the
    /// day, not to the plan.
    @discardableResult
    func archiveWeek(_ week: WeekKey, saving: Bool = true) -> WeekArchive? {
        let key = week.string
        let dayKeys = Set(week.days.map(\.string))
        let items = all(PlanItem.self).filter { $0.weekKey == key && $0.deletedAt == nil }
        let measures = all(MeasureDefinition.self).filter { $0.weekKey == key && $0.deletedAt == nil }
        guard !items.isEmpty || !measures.isEmpty else { return nil }
        let marks = all(ItemMark.self).filter { $0.weekKey == key }
        let entries = all(MeasureEntry.self).filter { dayKeys.contains($0.dayKey) && $0.deletedAt == nil }
        let scores = all(ScoreOverride.self).filter { dayKeys.contains($0.dayKey) && $0.deletedAt == nil }

        var snapshot = exportDocument(weeks: [week])
        snapshot.goals = []
        snapshot.categories = []
        snapshot.work = []
        snapshot.notes = []
        snapshot.reviews = []
        let archive = WeekArchive(weekKey: key, title: plan(week)?.title ?? "", csv: PlanCSV.export(snapshot),
                                  itemCount: items.count, markCount: snapshot.marks.count)
        context.insert(archive)

        for item in items { context.delete(item) }
        for measure in measures { context.delete(measure) }
        for mark in marks { context.delete(mark) }
        for entry in entries { context.delete(entry) }
        for score in scores { context.delete(score) }
        for change in all(PlanChange.self) where change.weekKey == key { context.delete(change) }
        for day in all(PlanDay.self) where dayKeys.contains(day.dayKey) && day.closedAt != nil {
            day.closedAt = nil
            day.modifiedAt = Date()
        }
        if let plan = plan(week), plan.closedAt != nil {
            plan.closedAt = nil
            plan.touch()
        }
        AppLog.info("Archived \(key): \(items.count) items, \(marks.count) marks", category: "import")
        if saving { save() }
        return archive
    }

    /// Brings an archived week back; what the week has now is archived in its place.
    @discardableResult
    func restore(_ archive: WeekArchive) -> ImportResult {
        if let week = archive.week { archiveWeek(week, saving: false) }
        let csv = archive.csv
        context.delete(archive)
        try? context.save()
        return apply(ImportPreview(text: csv, existing: existingState()))
    }

    func delete(_ archive: WeekArchive) {
        context.delete(archive)
        save()
    }

    /// Everything (or some weeks) in the import format – backup, sharing with the planning AI, editing elsewhere.
    func exportDocument(weeks: Set<WeekKey>? = nil) -> PlanCSV.Document {
        let state = existingState()
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
        return doc
    }

    func exportCSV(weeks: Set<WeekKey>? = nil) -> String {
        PlanCSV.export(exportDocument(weeks: weeks))
    }

    /// Imports a whole document without a preview (demo and tour data).
    /// Entries go in one by one (an import keeps one value per measurement and day).
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
        for week in content.closedWeeks { closeWeek(week) }
    }
}
