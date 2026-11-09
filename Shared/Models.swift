import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

// Thalia's SwiftData models, synced through the private database of iCloud.at.binisoft.thalia.
//
// CloudKit rules: every attribute has a default, nothing is unique, no relationships – records
// refer to each other by stable keys ("2026-W45", "2026-W45|1.1-03", "2026-11-02"), so a mark that
// syncs before its item never breaks anything. If two devices create the same key offline, the
// store reads the most recently changed one. Enums are stored as raw strings (older builds read
// values they don't know). New fields must be optional or have a default, and go into
// cloudkit/schema.ckdb before the next TestFlight build.

/// One of the ten annual goals.
@Model
final class AnnualGoal {
    var uuid: UUID = UUID()
    var key: String = ""
    var title: String = ""
    var details: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(_ record: GoalRecord) {
        key = record.key
        title = record.title
        details = record.details
    }

    var record: GoalRecord { GoalRecord(key: key, title: title, details: details) }
}

/// A detailed category under a goal ("1.1 Ernährung und Gewicht").
@Model
final class TrackCategory {
    var uuid: UUID = UUID()
    var key: String = ""
    var goalKey: String = ""
    var title: String = ""
    var details: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(_ record: CategoryRecord) {
        key = record.key
        goalKey = record.goalKey
        title = record.title
        details = record.details
    }

    var record: CategoryRecord { CategoryRecord(key: key, goalKey: goalKey, title: title, details: details) }
}

/// A planned (or historical) week.
@Model
final class WeekPlan {
    var uuid: UUID = UUID()
    /// "2026-W45"
    var weekKey: String = ""
    var title: String = ""
    var details: String = ""
    /// Score reported for a week tracked outside the app (paper history).
    var recordedScore: Double?
    /// "" = equally weighted goals (since KW42 2026), "alt" = earlier model.
    var scoringModel: String = ""
    var closedAt: Date?
    var importedAt: Date?
    /// The score when the week was closed, so the history doesn't recompute old weeks.
    var finalScore: Double?
    /// "1=7;2=8.1;…" – the annual goals' scores when the week was closed.
    var finalGoalScores: String = ""
    var finalGoalsScored: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(_ record: WeekRecord) {
        weekKey = record.week.string
        update(from: record)
    }

    func update(from record: WeekRecord) {
        title = record.title
        details = record.details
        recordedScore = record.recordedScore
        scoringModel = record.scoringModel
    }

    var week: WeekKey? { WeekKey(weekKey) }
    var isClosed: Bool { closedAt != nil }
    var isOldScoring: Bool { record?.isOldScoring ?? false }

    /// Closed score, else the reported paper score.
    var historyScore: Double? { finalScore ?? recordedScore }

    var finalGoalScoreMap: [String: Double] {
        var result: [String: Double] = [:]
        for pair in finalGoalScores.split(separator: ";") {
            let parts = pair.split(separator: "=")
            if parts.count == 2, let value = Double(parts[1]) { result[String(parts[0])] = value }
        }
        return result
    }

    var record: WeekRecord? {
        week.map { WeekRecord(week: $0, title: title, details: details, recordedScore: recordedScore, scoringModel: scoringModel) }
    }
}

/// The kind of day, its note, and whether the evening review closed it.
@Model
final class PlanDay {
    var uuid: UUID = UUID()
    /// "2026-11-02"
    var dayKey: String = ""
    var dayType: String = ""
    var note: String = ""
    var closedAt: Date?
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(dayKey: String) {
        self.dayKey = dayKey
    }

    var day: DayKey? { DayKey(dayKey) }
    var isClosed: Bool { closedAt != nil }
    var record: DayRecord? { day.map { DayRecord(day: $0, dayType: dayType, note: note) } }
}

/// One of the ten scored items of a category in a week.
@Model
final class PlanItem {
    var uuid: UUID = UUID()
    var weekKey: String = ""
    /// Id within the week ("1.1-03").
    var code: String = ""
    var categoryKey: String = ""
    var position: Int = 0
    var title: String = ""
    var details: String = ""
    /// Weekdays as a bit set (Monday = 1, every day = 127).
    var daysMask: Int = 127
    /// "fix", "woche:3", "bedingt", "optional"
    var scheduleRaw: String = "fix"
    /// ">=150", "<=23:00" – threshold on the linked measurement.
    var targetRaw: String = ""
    var measureCode: String = ""
    var isKnockout: Bool = false
    /// "nebensache", "arbeit" / "frei" (v3).
    var flagsRaw: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(_ record: ItemRecord) {
        weekKey = record.week.string
        code = record.code
        update(from: record)
    }

    func update(from record: ItemRecord) {
        categoryKey = record.categoryKey
        position = record.position
        title = record.title
        details = record.details
        daysMask = record.days.rawValue
        scheduleRaw = record.schedule.raw
        targetRaw = record.target?.raw ?? ""
        measureCode = record.measure
        isKnockout = record.knockout
        flagsRaw = ItemFlags.text(secondary: record.secondary, dayRule: record.dayRule)
    }

    var isSecondary: Bool { ItemFlags.secondary(ItemFlags.parse(flagsRaw)) }

    var key: String { "\(weekKey)|\(code)" }
    var schedule: ItemSchedule { ItemSchedule(raw: scheduleRaw) }
    var days: DayMask { DayMask(rawValue: daysMask) }

    var record: ItemRecord? {
        guard let week = WeekKey(weekKey) else { return nil }
        let flags = ItemFlags.parse(flagsRaw)
        return ItemRecord(week: week, code: code, categoryKey: categoryKey, position: position, title: title, details: details,
                          days: days, schedule: schedule, target: Target.parse(targetRaw), measure: measureCode, knockout: isKnockout,
                          secondary: ItemFlags.secondary(flags), dayRule: ItemFlags.dayRule(flags))
    }
}

/// A raw measurement for a week ("Protein, g, ≥ 150 pro Tag").
@Model
final class MeasureDefinition {
    var uuid: UUID = UUID()
    var weekKey: String = ""
    var code: String = ""
    var categoryKey: String = ""
    var position: Int = 0
    var title: String = ""
    var details: String = ""
    var unit: String = ""
    var targetRaw: String = ""
    /// "tag" / "woche"
    var periodRaw: String = "tag"
    /// "", "arbeit:3.2", "health:sleep"
    var sourceRaw: String = ""
    /// "summe", "letzter", "schnitt", "max", "min"
    var aggregationRaw: String = "summe"
    var daysMask: Int = 127
    /// "nebensache", "arbeit" / "frei" (v3).
    var flagsRaw: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(_ record: MeasureRecord) {
        weekKey = record.week.string
        code = record.code
        update(from: record)
    }

    func update(from record: MeasureRecord) {
        categoryKey = record.categoryKey
        position = record.position
        title = record.title
        details = record.details
        unit = record.unit
        targetRaw = record.target?.raw ?? ""
        periodRaw = record.period.rawValue
        sourceRaw = record.source.raw
        aggregationRaw = record.aggregation.rawValue
        daysMask = record.days.rawValue
        flagsRaw = ItemFlags.text(secondary: record.secondary, dayRule: record.dayRule)
    }

    var isSecondary: Bool { ItemFlags.secondary(ItemFlags.parse(flagsRaw)) }

    var key: String { "\(weekKey)|\(code)" }
    var days: DayMask { DayMask(rawValue: daysMask) }

    var record: MeasureRecord? {
        guard let week = WeekKey(weekKey) else { return nil }
        return MeasureRecord(week: week, code: code, categoryKey: categoryKey, position: position, title: title, details: details,
                             unit: unit, target: Target.parse(targetRaw), period: TargetPeriod(raw: periodRaw),
                             source: MeasureSource(raw: sourceRaw), aggregation: Aggregation(token: aggregationRaw),
                             days: DayMask(rawValue: daysMask),
                             secondary: ItemFlags.secondary(ItemFlags.parse(flagsRaw)), dayRule: ItemFlags.dayRule(ItemFlags.parse(flagsRaw)))
    }
}

/// ✓ ½ ✗ N/A for one item on one day. An empty `valueRaw` means "cleared" (blank).
@Model
final class ItemMark {
    var uuid: UUID = UUID()
    var weekKey: String = ""
    var itemCode: String = ""
    var dayKey: String = ""
    var valueRaw: String = ""
    var note: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(weekKey: String, itemCode: String, dayKey: String) {
        self.weekKey = weekKey
        self.itemCode = itemCode
        self.dayKey = dayKey
    }

    var mark: Mark? { Mark(rawValue: valueRaw) }
    var key: String { "\(itemCode)|\(dayKey)" }

    var record: MarkRecord? {
        guard let week = WeekKey(weekKey), let day = DayKey(dayKey) else { return nil }
        return MarkRecord(week: week, itemCode: itemCode, day: day, mark: mark, note: note)
    }
}

/// One recorded measurement value (several per day add up or the last one counts).
@Model
final class MeasureEntry {
    var uuid: UUID = UUID()
    var code: String = ""
    var dayKey: String = ""
    var value: Double?
    var text: String = ""
    var note: String = ""
    var isEstimate: Bool = false
    var recordedAt: Date = Date()
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(code: String, dayKey: String, value: Double?) {
        self.code = code
        self.dayKey = dayKey
        self.value = value
    }

    var record: EntryRecord? {
        guard let day = DayKey(dayKey) else { return nil }
        return EntryRecord(code: code, day: day, value: value, text: text, note: note, estimate: isEstimate,
                           order: recordedAt.timeIntervalSince1970)
    }
}

/// A block of work in power-hours: category, how many PH, what for, result, next step.
/// (`minutes`, `kindRaw`, `startedAt`, `endedAt`, `isRunning` are from v1 and stay for CloudKit.)
@Model
final class WorkBlock {
    var uuid: UUID = UUID()
    var dayKey: String = ""
    var categoryKey: String = ""
    var task: String = ""
    var result: String = ""
    var minutes: Int = 0
    /// "fokus", "unterricht", "ersatz"
    var kindRaw: String = "fokus"
    var nextStep: String = ""
    var startedAt: Date?
    var endedAt: Date?
    var isRunning: Bool = false
    /// Id from an imported file (re-importing updates instead of duplicating).
    var importID: String = ""
    /// Power-hours (v2). 0 in v1 records: then `minutes ÷ 50`.
    var powerHours: Double = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(dayKey: String, categoryKey: String, task: String, powerHours: Double) {
        self.dayKey = dayKey
        self.categoryKey = categoryKey
        self.task = task
        self.powerHours = powerHours
        self.minutes = Int(PowerHour.minutes(powerHours).rounded())
    }

    /// Id used in exports (`id` itself belongs to SwiftData).
    var recordID: String { importID.isEmpty ? uuid.uuidString : importID }

    var hours: Double { powerHours > 0 ? powerHours : Double(minutes) / Double(PowerHour.minutes) }

    var record: WorkRecord? {
        guard let day = DayKey(dayKey) else { return nil }
        return WorkRecord(id: recordID, day: day, categoryKey: categoryKey, task: task, result: result, powerHours: hours,
                          nextStep: nextStep)
    }
}

/// A short note captured during the day (observation, trigger, success, contact, parked idea).
@Model
final class DayNote {
    var uuid: UUID = UUID()
    var dayKey: String = ""
    var kindRaw: String = "beobachtung"
    var text: String = ""
    var importID: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(dayKey: String, kind: NoteKind, text: String) {
        self.dayKey = dayKey
        self.kindRaw = kind.rawValue
        self.text = text
    }

    var kind: NoteKind { NoteKind(raw: kindRaw) }
    var recordID: String { importID.isEmpty ? uuid.uuidString : importID }

    var record: NoteRecord? {
        guard let day = DayKey(dayKey) else { return nil }
        return NoteRecord(id: recordID, day: day, kind: kind, text: text)
    }
}

/// One answer of the evening or weekly reflection.
@Model
final class Reflection {
    var uuid: UUID = UUID()
    /// "2026-11-02" or "2026-W45"
    var scope: String = ""
    /// Question id ("verhalten", "wiederholen" …)
    var field: String = ""
    var text: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(scope: String, field: String) {
        self.scope = scope
        self.field = field
    }

    var key: String { "\(scope)|\(field)" }
    var record: ReviewRecord { ReviewRecord(scope: scope, field: field, text: text) }
}

/// The person's own score for a category on a day, replacing the calculated one.
@Model
final class ScoreOverride {
    var uuid: UUID = UUID()
    var categoryKey: String = ""
    var dayKey: String = ""
    var score: Double = 0
    var reason: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var deletedAt: Date?

    init(categoryKey: String, dayKey: String, score: Double) {
        self.categoryKey = categoryKey
        self.dayKey = dayKey
        self.score = score
    }

    var key: String { "\(categoryKey)|\(dayKey)" }

    var record: ScoreRecord? {
        guard let day = DayKey(dayKey) else { return nil }
        return ScoreRecord(categoryKey: categoryKey, day: day, score: score, reason: reason)
    }
}

/// Small synced settings (the goal year, its motto, the review week).
@Model
final class AppSetting {
    var uuid: UUID = UUID()
    var key: String = ""
    var value: String = ""
    var modifiedAt: Date = Date()

    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// A replaced week, kept to restore it: the week as CSV in the import format (plan and results).
/// Hidden from all screens and statistics.
@Model
final class WeekArchive {
    var uuid: UUID = UUID()
    var weekKey: String = ""
    var title: String = ""
    var csv: String = ""
    var itemCount: Int = 0
    var markCount: Int = 0
    var archivedAt: Date = Date()
    var modifiedAt: Date = Date()

    init(weekKey: String, title: String, csv: String, itemCount: Int, markCount: Int) {
        self.weekKey = weekKey
        self.title = title
        self.csv = csv
        self.itemCount = itemCount
        self.markCount = markCount
    }

    var week: WeekKey? { WeekKey(weekKey) }
}

/// A change to the week's plan made in the app; the next planning prompt lists it.
@Model
final class PlanChange {
    var uuid: UUID = UUID()
    var weekKey: String = ""
    /// "neu", "geändert", "gelöscht"
    var kindRaw: String = ""
    /// "Punkt", "Messwert"
    var targetRaw: String = ""
    var code: String = ""
    var title: String = ""
    var detail: String = ""
    var carryOver: Bool = true
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()

    init(_ record: PlanChangeRecord) {
        weekKey = record.week.string
        kindRaw = record.kind.rawValue
        targetRaw = record.target.rawValue
        code = record.code
        title = record.title
        detail = record.detail
        carryOver = record.carryOver
    }

    var record: PlanChangeRecord? {
        guard let week = WeekKey(weekKey), let kind = PlanChangeRecord.Kind(rawValue: kindRaw),
              let target = PlanChangeRecord.Target(rawValue: targetRaw) else { return nil }
        return PlanChangeRecord(week: week, kind: kind, target: target, code: code, title: title, detail: detail, carryOver: carryOver)
    }
}

/// An Apple Health value the person confirmed for a measurement. Device-only: App Store
/// guideline 5.1.3(ii) – personal health information is never stored in iCloud. Other devices
/// read Health themselves; what syncs is the person's own mark.
@Model
final class HealthValue {
    var uuid: UUID = UUID()
    var code: String = ""
    var dayKey: String = ""
    var value: Double = 0
    var recordedAt: Date = Date()

    init(code: String, dayKey: String, value: Double) {
        self.code = code
        self.dayKey = dayKey
        self.value = value
    }

    var record: EntryRecord? {
        guard let day = DayKey(dayKey) else { return nil }
        return EntryRecord(code: code, day: day, value: value, note: "Apple Health", order: recordedAt.timeIntervalSince1970)
    }
}

extension AnnualGoal: SoftDeletable {}
extension TrackCategory: SoftDeletable {}
extension WeekPlan: SoftDeletable {}
extension PlanItem: SoftDeletable {}
extension MeasureDefinition: SoftDeletable {}
extension MeasureEntry: SoftDeletable {}
extension WorkBlock: SoftDeletable {}
extension DayNote: SoftDeletable {}
extension ScoreOverride: SoftDeletable {}

extension Array {
    /// One element per key, the most recently modified one (CloudKit can hold duplicates created offline).
    func latest(by key: (Element) -> String, modified: (Element) -> Date) -> [String: Element] {
        var result: [String: Element] = [:]
        for element in self {
            let k = key(element)
            if let current = result[k], modified(current) >= modified(element) { continue }
            result[k] = element
        }
        return result
    }
}
