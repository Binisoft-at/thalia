import Foundation

// Plain values for everything the tracker holds. The app turns its SwiftData objects into these,
// the CSV reads and writes them, and the scorer and the week report work on them – so all the
// rules are tested on Linux.

/// One of the ten annual goals ("1 Fit Body").
public struct GoalRecord: Equatable, Sendable {
    public var key: String
    public var title: String
    public var details: String

    public init(key: String, title: String, details: String = "") {
        self.key = key
        self.title = title
        self.details = details
    }

    public var number: Int { Int(key) ?? 0 }
    /// "1 Fit Body"
    public var label: String { "\(key) \(title)" }
}

/// A detailed category under a goal ("1.1 Ernährung und Gewicht").
public struct CategoryRecord: Equatable, Sendable {
    public var key: String
    public var goalKey: String
    public var title: String
    public var details: String

    public init(key: String, goalKey: String, title: String, details: String = "") {
        self.key = key
        self.goalKey = goalKey
        self.title = title
        self.details = details
    }

    public var label: String { "\(key) \(title)" }

    /// "1.10" sorts after "1.9".
    public static func sortKey(_ key: String) -> [Int] {
        key.split(separator: ".").map { Int($0) ?? 0 }
    }
}

/// A planned week: its theme, the context the plan was made in, and (for weeks tracked
/// elsewhere) the score that was reported for it.
public struct WeekRecord: Equatable, Sendable {
    public var week: WeekKey
    public var title: String
    public var details: String
    public var recordedScore: Double?
    /// "" = equally weighted annual goals (since KW42 2026), "alt" = the earlier model.
    public var scoringModel: String

    public init(week: WeekKey, title: String = "", details: String = "", recordedScore: Double? = nil, scoringModel: String = "") {
        self.week = week
        self.title = title
        self.details = details
        self.recordedScore = recordedScore
        self.scoringModel = scoringModel
    }

    /// Scores before KW42 2026 used another model and aren't directly comparable.
    public var isOldScoring: Bool {
        scoringModel.lowercased().contains("alt") || scoringModel.lowercased().contains("old")
    }

    public static let scoringChange = WeekKey(year: 2026, week: 42)
}

/// The kind of day and its note ("Familientag", "Arbeit endet 15:00").
public struct DayRecord: Equatable, Sendable {
    public var day: DayKey
    public var dayType: String
    public var note: String

    public init(day: DayKey, dayType: String = "", note: String = "") {
        self.day = day
        self.dayType = dayType
        self.note = note
    }
}

/// One of the ten scored items of a category in a given week.
public struct ItemRecord: Equatable, Sendable {
    public var week: WeekKey
    /// Id within the week, e.g. "1.1-03".
    public var code: String
    public var categoryKey: String
    public var position: Int
    public var title: String
    public var details: String
    public var days: DayMask
    public var schedule: ItemSchedule
    /// Optional threshold on the linked measurement ("Proteinziel" ≥ 150 g).
    public var target: Target?
    /// Code of a measurement whose value suggests the mark.
    public var measure: String
    /// Missed → the whole category scores 0 that day (a personal rule, e.g. sleep).
    public var knockout: Bool
    /// "Nebensache": counts only when filled in, shown folded away in the quick check-in.
    public var secondary: Bool
    /// Work days only / also on free days / decided by the category (Business on work days).
    public var dayRule: DayRule

    public init(week: WeekKey, code: String, categoryKey: String, position: Int = 0, title: String, details: String = "",
                days: DayMask = .everyDay, schedule: ItemSchedule = .fixed, target: Target? = nil, measure: String = "",
                knockout: Bool = false, secondary: Bool = false, dayRule: DayRule = .auto) {
        self.week = week
        self.code = code
        self.categoryKey = categoryKey
        self.position = position
        self.title = title
        self.details = details
        self.days = days
        self.schedule = schedule
        self.target = target
        self.measure = measure
        self.knockout = knockout
        self.secondary = secondary
        self.dayRule = dayRule
    }

    /// The CSV `flags` cell: "ko,nebensache,arbeit".
    public var flags: String { ItemFlags.text(knockout: knockout, secondary: secondary, dayRule: dayRule) }

    public var key: String { ItemRecord.key(week: week, code: code) }
    public static func key(week: WeekKey, code: String) -> String { "\(week.string)|\(code)" }

    public func applies(on day: DayKey) -> Bool { days.contains(day.weekday) }
}

/// A raw measurement definition for a week ("Protein, g, ≥ 150 pro Tag").
public struct MeasureRecord: Equatable, Sendable {
    public var week: WeekKey
    /// Stable across weeks ("protein"), so trends continue.
    public var code: String
    public var categoryKey: String
    public var position: Int
    public var title: String
    public var details: String
    public var unit: String
    public var target: Target?
    public var period: TargetPeriod
    public var source: MeasureSource
    public var aggregation: Aggregation
    public var days: DayMask
    /// "Nebensache": shown folded away in the quick check-in.
    public var secondary: Bool
    public var dayRule: DayRule

    public init(week: WeekKey, code: String, categoryKey: String = "", position: Int = 0, title: String, details: String = "",
                unit: String = "", target: Target? = nil, period: TargetPeriod = .day, source: MeasureSource = .manual,
                aggregation: Aggregation? = nil, days: DayMask = .everyDay, secondary: Bool = false, dayRule: DayRule = .auto) {
        self.secondary = secondary
        self.dayRule = dayRule
        self.week = week
        self.code = code
        self.categoryKey = categoryKey
        self.position = position
        self.title = title
        self.details = details
        self.unit = unit
        self.target = target
        self.period = period
        self.source = source
        self.aggregation = aggregation ?? .default(forUnit: unit)
        self.days = days
    }

    public var key: String { "\(week.string)|\(code)" }
    public var isTime: Bool { Units.isTime(unit) }
    public var isText: Bool { Units.isText(unit) }
    /// Filled from power-hours (`arbeit:<category>`): always counted in PH.
    public var isWork: Bool {
        if case .work = source { return true }
        return false
    }
}

/// When an item or measurement is due on free days (Familientag, Erholungstag, Urlaub …).
public enum DayRule: String, Sendable {
    /// Decided by the category: Business (goal 3, except the morning routine 3.1) only on work days.
    case auto = ""
    /// Only on work days ("arbeit").
    case workOnly = "arbeit"
    /// Also on free days ("frei").
    case always = "frei"
}

/// The `flags` column of items and measurements.
public enum ItemFlags {
    public static let secondaryTokens: Set<String> = ["nebensache", "neben", "nebenbei", "sekundär", "sekundaer", "secondary", "unwichtig", "optional-anzeige"]
    public static let workOnlyTokens: Set<String> = ["arbeit", "arbeitstag", "work", "workday"]
    public static let alwaysTokens: Set<String> = ["frei", "freitag-tauglich", "immer", "always"]

    public static func secondary(_ flags: Set<String>) -> Bool {
        !flags.isDisjoint(with: secondaryTokens) && !flags.contains("wichtig")
    }

    public static func dayRule(_ flags: Set<String>) -> DayRule {
        if !flags.isDisjoint(with: workOnlyTokens) { return .workOnly }
        if !flags.isDisjoint(with: alwaysTokens) { return .always }
        return .auto
    }

    public static func text(knockout: Bool = false, secondary: Bool, dayRule: DayRule, extra: [String] = []) -> String {
        var parts: [String] = []
        if knockout { parts.append("ko") }
        if secondary { parts.append("nebensache") }
        if dayRule != .auto { parts.append(dayRule.rawValue) }
        return (parts + extra).joined(separator: ",")
    }

    /// The stored form (models keep it as one string): "nebensache,arbeit".
    public static func parse(_ raw: String) -> Set<String> {
        Set(raw.lowercased().split(whereSeparator: { ",; |".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }
}

/// A mark as stored: item, day, value (nil = cleared), note.
public struct MarkRecord: Equatable, Sendable {
    public var week: WeekKey
    public var itemCode: String
    public var day: DayKey
    public var mark: Mark?
    public var note: String

    public init(week: WeekKey, itemCode: String, day: DayKey, mark: Mark?, note: String = "") {
        self.week = week
        self.itemCode = itemCode
        self.day = day
        self.mark = mark
        self.note = note
    }

    public var key: String { "\(week.string)|\(itemCode)|\(day.string)" }
}

/// One recorded measurement value (several per day are aggregated).
public struct EntryRecord: Equatable, Sendable {
    public var code: String
    public var day: DayKey
    public var value: Double?
    public var text: String
    public var note: String
    /// Estimated (restaurant portion, rough guess).
    public var estimate: Bool
    /// Order within the day (time recorded); "last" aggregation takes the latest.
    public var order: Double

    public init(code: String, day: DayKey, value: Double?, text: String = "", note: String = "", estimate: Bool = false, order: Double = 0) {
        self.code = code
        self.day = day
        self.value = value
        self.text = text
        self.note = note
        self.estimate = estimate
        self.order = order
    }

    public var key: String { "\(code)|\(day.string)" }
}

/// A block of work in power-hours: category, how many PH, what for (student, task), result, next step.
public struct WorkRecord: Equatable, Sendable {
    public var id: String
    public var day: DayKey
    public var categoryKey: String
    /// What it was for ("Lena – Mathe", "Landingpage").
    public var task: String
    public var result: String
    public var powerHours: Double
    public var nextStep: String

    public init(id: String, day: DayKey, categoryKey: String, task: String, result: String = "", powerHours: Double,
                nextStep: String = "") {
        self.id = id
        self.day = day
        self.categoryKey = categoryKey
        self.task = task
        self.result = result
        self.powerHours = powerHours
        self.nextStep = nextStep
    }

    public var minutes: Double { PowerHour.minutes(powerHours) }
}

/// A change made in the app to the week's plan (a measurement or item added, edited or deleted).
/// The next planning prompt lists them, saying whether they should carry over.
public struct PlanChangeRecord: Equatable, Sendable {
    public enum Kind: String, Sendable { case added = "neu", edited = "geändert", deleted = "gelöscht" }
    public enum Target: String, Sendable { case item = "Punkt", measure = "Messwert" }

    public var week: WeekKey
    public var kind: Kind
    public var target: Target
    public var code: String
    public var title: String
    /// What it is now ("Mo–Fr · ≥150 g") or what was removed.
    public var detail: String
    /// true: keep it in the next weeks · false: only this week.
    public var carryOver: Bool

    public init(week: WeekKey, kind: Kind, target: Target, code: String, title: String, detail: String = "", carryOver: Bool) {
        self.week = week
        self.kind = kind
        self.target = target
        self.code = code
        self.title = title
        self.detail = detail
        self.carryOver = carryOver
    }

    /// "Messwert neu: Plank (plank) – min, ≥3 pro Tag → dauerhaft übernehmen"
    public var line: String {
        let base = "\(target.rawValue) \(kind.rawValue): \(title) (\(code))" + (detail.isEmpty ? "" : " – \(detail)")
        return base + (carryOver ? " → dauerhaft übernehmen" : " → nur diese Woche, nicht übernehmen")
    }
}

/// A short note captured during the day.
public struct NoteRecord: Equatable, Sendable {
    public var id: String
    public var day: DayKey
    public var kind: NoteKind
    public var text: String

    public init(id: String, day: DayKey, kind: NoteKind = .observation, text: String) {
        self.id = id
        self.day = day
        self.kind = kind
        self.text = text
    }
}

/// One answer of the evening or weekly reflection. `scope` is a day ("2026-11-02") or a week ("2026-W45").
public struct ReviewRecord: Equatable, Sendable {
    public var scope: String
    public var field: String
    public var text: String

    public init(scope: String, field: String, text: String) {
        self.scope = scope
        self.field = field
        self.text = text
    }

    public var key: String { "\(scope)|\(field)" }
}

/// The person's own category score for a day, replacing the calculated one (e.g. a zero rule).
public struct ScoreRecord: Equatable, Sendable {
    public var categoryKey: String
    public var day: DayKey
    public var score: Double
    public var reason: String

    public init(categoryKey: String, day: DayKey, score: Double, reason: String = "") {
        self.categoryKey = categoryKey
        self.day = day
        self.score = score
        self.reason = reason
    }

    public var key: String { "\(categoryKey)|\(day.string)" }
}

/// Sorting helpers.
public extension Array where Element == CategoryRecord {
    func sortedByKey() -> [CategoryRecord] {
        sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }
}

public extension Array where Element == GoalRecord {
    func sortedByNumber() -> [GoalRecord] { sorted { ($0.number, $0.key) < ($1.number, $1.key) } }
}

public extension Array where Element == ItemRecord {
    func sortedForSheet() -> [ItemRecord] {
        sorted {
            let a = CategoryRecord.sortKey($0.categoryKey)
            let b = CategoryRecord.sortKey($1.categoryKey)
            if a != b { return a.lexicographicallyPrecedes(b) }
            return ($0.position, $0.code) < ($1.position, $1.code)
        }
    }
}
