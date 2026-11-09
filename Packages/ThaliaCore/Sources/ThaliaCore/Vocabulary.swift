import Foundation

// The tracker's vocabulary, in Bini's words: marks (✓ ½ ✗ N/A), schedules, targets, units,
// work kinds, day types and the reflection questions. Stored as plain strings so older app
// versions can read values they don't know yet (CloudKit rule: no enum cases older builds
// can't decode).

/// One scored item on one day. "Blank" (no entry) is `nil`: not yet recorded – neither a
/// failure nor N/A.
public enum Mark: String, CaseIterable, Codable, Sendable {
    case done = "1"
    case partial = "0.5"
    case missed = "0"
    case notApplicable = "na"

    /// Points earned; nil when the item doesn't count that day (N/A).
    public var points: Double? {
        switch self {
        case .done: 1
        case .partial: 0.5
        case .missed: 0
        case .notApplicable: nil
        }
    }

    public var counts: Bool { points != nil }

    public var symbol: String {
        switch self {
        case .done: "✓"
        case .partial: "½"
        case .missed: "✗"
        case .notApplicable: "–"
        }
    }

    public var label: String {
        switch self {
        case .done: "Erledigt"
        case .partial: "Teilweise"
        case .missed: "Fällig, nicht erledigt"
        case .notApplicable: "Nicht fällig (N/A)"
        }
    }

    /// Reads ✓/1/ja · ½/0.5/teilweise · ✗/X/0/nein · N/A/–. Bini's sheets use X for "missed".
    public static func parse(_ raw: String) -> Mark? {
        let t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        switch t {
        case "1", "1.0", "1,0", "✓", "✔", "ja", "yes", "y", "done", "erledigt", "ok", "true": return .done
        case "0.5", "0,5", ".5", ",5", "½", "teilweise", "teils", "partial", "halb": return .partial
        case "0", "0.0", "0,0", "x", "✗", "✘", "nein", "no", "n", "missed", "verpasst", "false": return .missed
        case "na", "n/a", "n.a.", "-", "–", "—", "nicht fällig", "entfällt", "not applicable": return .notApplicable
        default: return nil
        }
    }

    public static func isBlank(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Tapping a cell: blank → ✓ → ½ → ✗ → N/A → blank.
    public static func cycle(_ mark: Mark?) -> Mark? {
        switch mark {
        case nil: .done
        case .done: .partial
        case .partial: .missed
        case .missed: .notApplicable
        case .notApplicable: nil
        }
    }
}

/// When an item is due.
public enum ItemSchedule: Equatable, Hashable, Sendable {
    /// Due on each of its days.
    case fixed
    /// N times a week on any of its days; what's missing counts as missed once the week is over.
    case weekly(Int)
    /// Only when the situation occurs (stress, a cancelled lesson …); otherwise N/A.
    case conditional
    /// Tracked, never scored – no fabricated ten, no automatic zero.
    case optional
    /// A day's share of a weekly target (stammloop 8 PH): "daran gearbeitet" or "heute nicht".
    /// Resolved from the linked weekly measurement once the target is reached or the week is over.
    case progress

    /// Reads "fix", "woche:3", "3x/Woche", "3× pro Woche", "bedingt", "wenn", "optional", "fortschritt".
    public init(raw: String) {
        let t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if t.isEmpty || t == "fix" || t == "fest" || t == "fixed" {
            self = .fixed
        } else if t.contains("fortschritt") || t.contains("progress") || t.contains("gearbeitet") {
            self = .progress
        } else if t.contains("optional") || t == "opt" || t.contains("freiwillig") {
            self = .optional
        } else if t.contains("bedingt") || t.hasPrefix("wenn") || t.contains("conditional") || t.contains("falls") {
            self = .conditional
        } else if t.contains("woche") || t.contains("week") || t.contains("x") || t.contains("×") {
            let digits = t.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
            self = .weekly(max(1, digits.first ?? 1))
        } else {
            self = .fixed
        }
    }

    /// "fix", "woche:3", "bedingt", "optional".
    public var raw: String {
        switch self {
        case .fixed: "fix"
        case .weekly(let n): "woche:\(n)"
        case .conditional: "bedingt"
        case .optional: "optional"
        case .progress: "fortschritt"
        }
    }

    public var label: String {
        switch self {
        case .fixed: "fest"
        case .weekly(let n): "\(n)× pro Woche"
        case .conditional: "bedingt"
        case .optional: "optional"
        case .progress: "Wochenfortschritt"
        }
    }

    public var isScored: Bool { self != .optional }

    public var weeklyTarget: Int? {
        if case .weekly(let n) = self { return n }
        return nil
    }
}

/// A threshold: ">=150", "<=6", "<50", "<=23:00", "150-180", "22:30-23:00".
public struct Target: Equatable, Hashable, Sendable {
    public enum Comparison: String, Sendable {
        case atLeast = ">=", atMost = "<=", above = ">", below = "<", equal = "=", range = "range"
    }

    public var comparison: Comparison
    public var value: Double
    public var upper: Double?
    /// The values are times of day in minutes since midnight.
    public var isTime: Bool

    public init(_ comparison: Comparison, _ value: Double, upper: Double? = nil, isTime: Bool = false) {
        self.comparison = comparison
        self.value = value
        self.upper = upper
        self.isTime = isTime
    }

    public static func parse(_ raw: String) -> Target? {
        var t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }
        t = t.replacingOccurrences(of: "≥", with: ">=").replacingOccurrences(of: "≤", with: "<=")
            .replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "bis", with: "-")
            .replacingOccurrences(of: "uhr", with: "")
        var comparison: Comparison?
        for (prefix, value) in [(">=", Comparison.atLeast), ("=>", .atLeast), ("<=", .atMost), ("=<", .atMost),
                                ("mindestens", .atLeast), ("mind.", .atLeast), ("min.", .atLeast), ("min", .atLeast),
                                ("höchstens", .atMost), ("maximal", .atMost), ("max.", .atMost), ("max", .atMost),
                                ("unter", .below), ("über", .above),
                                (">", .above), ("<", .below), ("=", .equal)] where t.hasPrefix(prefix) {
            comparison = value
            t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        let numberish = t.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.,:- ").inverted)
        if comparison == nil, let dash = numberish.dropFirst().firstIndex(of: "-") {
            let low = String(numberish[numberish.startIndex..<dash])
            let high = String(numberish[numberish.index(after: dash)...])
            guard let (a, timeA) = parseNumber(low), let (b, timeB) = parseNumber(high) else { return nil }
            return Target(.range, min(a, b), upper: max(a, b), isTime: timeA || timeB)
        }
        guard let (value, isTime) = parseNumber(numberish) else { return nil }
        return Target(comparison ?? .atLeast, value, isTime: isTime)
    }

    /// "150", "2,5", "23:00" → (value, isTime).
    static func parseNumber(_ raw: String) -> (Double, Bool)? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        if t.contains(":") {
            let parts = t.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (0...24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
            return (Double(parts[0] * 60 + parts[1]), true)
        }
        guard let value = Double(t.replacingOccurrences(of: ",", with: ".")) else { return nil }
        return (value, false)
    }

    public func isMet(_ measured: Double) -> Bool {
        let v = isTime ? Target.normalizedTime(measured, reference: value) : measured
        switch comparison {
        case .atLeast: return v >= value - 1e-9
        case .atMost: return v <= value + 1e-9
        case .above: return v > value
        case .below: return v < value
        case .equal: return abs(v - value) < 1e-9
        case .range: return v >= value - 1e-9 && v <= (upper ?? value) + 1e-9
        }
    }

    /// Times after midnight count as "late" against an evening target: 00:30 is later than 23:00.
    public static func normalizedTime(_ minutes: Double, reference: Double) -> Double {
        reference >= 12 * 60 && minutes < 12 * 60 ? minutes + 24 * 60 : minutes
    }

    /// ">=150", "<=23:00", "150-180"
    public var raw: String {
        let a = isTime ? Format.clock(value) : Format.plain(value)
        if comparison == .range { return "\(a)-\(isTime ? Format.clock(upper ?? value) : Format.plain(upper ?? value))" }
        return comparison.rawValue + a
    }

    /// "≥ 150", "≤ 23:00", "150–180"
    public var label: String {
        let a = isTime ? Format.clock(value) : Format.number(value)
        switch comparison {
        case .atLeast: return "≥ \(a)"
        case .atMost: return "≤ \(a)"
        case .above: return "> \(a)"
        case .below: return "< \(a)"
        case .equal: return "= \(a)"
        case .range: return "\(a)–\(isTime ? Format.clock(upper ?? value) : Format.number(upper ?? value))"
        }
    }

    /// Where a progress bar should end: the target for "at least", the limit for "at most".
    public var scaleMax: Double {
        switch comparison {
        case .range: return upper ?? value
        default: return value
        }
    }

    /// True for limits (TEREA ≤ 6, spending < 50 €): less is fine.
    public var isLimit: Bool { comparison == .atMost || comparison == .below }
}

/// Whether a measurement target is per day or for the week's total.
public enum TargetPeriod: String, Sendable {
    case day = "tag"
    case week = "woche"

    public init(raw: String) {
        let t = raw.lowercased()
        self = (t.contains("woche") || t.contains("week") || t == "w") ? .week : .day
    }

    public var label: String { self == .day ? "pro Tag" : "pro Woche" }
}

/// How several entries of one day become the day's value.
public enum Aggregation: String, CaseIterable, Sendable {
    case sum = "summe"
    case last = "letzter"
    case average = "schnitt"
    case maximum = "max"
    case minimum = "min"

    public init?(token: String) {
        switch token.lowercased() {
        case "summe", "sum", "total": self = .sum
        case "letzter", "last", "zuletzt": self = .last
        case "schnitt", "avg", "average", "durchschnitt", "mittel": self = .average
        case "max", "maximum": self = .maximum
        case "min", "minimum": self = .minimum
        default: return nil
        }
    }

    /// Weight, times and percentages keep the last value; everything else adds up.
    public static func `default`(forUnit unit: String) -> Aggregation {
        let u = Units.normalized(unit)
        return ["kg", "uhrzeit", "%", "text", "1-10", "skala"].contains(u) ? .last : .sum
    }

    public func apply(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        switch self {
        case .sum: return values.reduce(0, +)
        case .last: return values.last
        case .average: return values.reduce(0, +) / Double(values.count)
        case .maximum: return values.max()
        case .minimum: return values.min()
        }
    }
}

public enum Units {
    public static func normalized(_ unit: String) -> String {
        let u = unit.trimmingCharacters(in: .whitespaces).lowercased()
        switch u {
        case "uhr", "time", "hh:mm", "zeit", "uhrzeit": return "uhrzeit"
        case "minuten", "minute", "min.": return "min"
        case "stunden", "stunde", "std", "std.", "hours": return "h"
        case "power-hour", "power-hours", "powerhour", "power hours", "power hour": return "ph"
        case "euro", "eur": return "€"
        case "liter": return "l"
        case "stk", "stk.", "stück", "anzahl", "x": return "stück"
        case "notiz", "note": return "text"
        default: return u
        }
    }

    public static func isTime(_ unit: String) -> Bool { normalized(unit) == "uhrzeit" }
    public static func isText(_ unit: String) -> Bool { normalized(unit) == "text" }

    /// How the unit is shown after a value ("150 g", "7,5 h", "3 PH", "23:10").
    public static func display(_ unit: String) -> String {
        switch normalized(unit) {
        case "ph": return "PH"
        case "uhrzeit", "text": return ""
        case "stück": return "Stk."
        default: return unit.trimmingCharacters(in: .whitespaces)
        }
    }

    /// A useful step for the + / − buttons.
    public static func step(_ unit: String) -> Double {
        switch normalized(unit) {
        case "l": return 0.25
        case "g": return 10
        case "kcal": return 100
        case "min": return 5
        case "h", "ph": return 0.5
        case "kg": return 0.1
        case "€": return 5
        case "seiten": return 5
        case "uhrzeit": return 15
        default: return 1
        }
    }
}

/// Where a measurement's value comes from.
public enum MeasureSource: Equatable, Sendable {
    case manual
    /// Computed from work blocks of this category (unit PH → focus minutes / 50, h → minutes / 60).
    case work(category: String)
    /// Apple Health suggests a value; the person confirms or overrides it.
    case health(HealthKind)

    /// "", "arbeit:3.2", "health:sleep".
    public init(raw: String) {
        let t = raw.trimmingCharacters(in: .whitespaces)
        let lower = t.lowercased()
        if lower.hasPrefix("arbeit:") || lower.hasPrefix("work:") {
            self = .work(category: String(t[t.index(after: t.firstIndex(of: ":")!)...]).trimmingCharacters(in: .whitespaces))
        } else if lower.hasPrefix("health:") || lower.hasPrefix("gesundheit:") {
            let kind = String(lower[lower.index(after: lower.firstIndex(of: ":")!)...])
            self = HealthKind(token: kind).map(MeasureSource.health) ?? .manual
        } else {
            self = .manual
        }
    }

    public var raw: String {
        switch self {
        case .manual: ""
        case .work(let category): "arbeit:\(category)"
        case .health(let kind): "health:\(kind.rawValue)"
        }
    }
}

/// Apple Health types Thalia can read as suggestions (never stored in iCloud).
public enum HealthKind: String, CaseIterable, Sendable {
    case sleep, bedtime, bodyMass, protein, energy, water, exercise, mindful, steps

    public init?(token: String) {
        let t = token.lowercased()
        if let match = HealthKind.allCases.first(where: { $0.rawValue.lowercased() == t }) {
            self = match
            return
        }
        switch t {
        case "schlaf": self = .sleep
        case "bettzeit", "einschlafen": self = .bedtime
        case "gewicht", "weight", "bodymass": self = .bodyMass
        case "kalorien", "calories", "kcal": self = .energy
        case "wasser": self = .water
        case "training", "workout", "bewegung": self = .exercise
        case "achtsamkeit", "atem", "breathing": self = .mindful
        case "schritte": self = .steps
        default: return nil
        }
    }

    public var label: String {
        switch self {
        case .sleep: "Schlafdauer"
        case .bedtime: "Einschlafzeit"
        case .bodyMass: "Gewicht"
        case .protein: "Protein"
        case .energy: "Kalorien"
        case .water: "Wasser"
        case .exercise: "Trainingsminuten"
        case .mindful: "Achtsamkeitsminuten"
        case .steps: "Schritte"
        }
    }
}

/// Work is counted in power-hours only: 1 PH = 50 focused minutes – tutoring too (50- or
/// 100-minute lessons are 1 or 2 PH). The category says what it was for.
public enum PowerHour {
    public static let minutes = 50
    /// The quick choices in the work sheet.
    public static let quick: [Double] = [0.25, 0.5, 0.75, 1, 2]

    /// Default PH for a new block in a category (tutoring: one 50-minute lesson).
    public static func defaultValue(for categoryKey: String) -> Double { 1 }

    /// Real time of some power-hours: 12 PH → 600 min.
    public static func minutes(_ powerHours: Double) -> Double { powerHours * Double(minutes) }
}

/// The kind of day sets what's reasonable: zero work can be exactly right on a planned day off.
public enum DayTypes {
    public static let presets = ["Arbeitstag", "Reisetag", "Familientag", "Erholungstag", "Frei", "Prüfungstag", "Besuch"]

    public static func symbol(for type: String) -> String {
        let t = type.lowercased()
        if t.contains("reise") || t.contains("flug") || t.contains("flughafen") { return "airplane" }
        if t.contains("famil") || t.contains("besuch") { return "figure.2.and.child.holdinghands" }
        if t.contains("erhol") || t.contains("ruhe") || t.contains("krank") { return "leaf" }
        if t.contains("frei") || t.contains("feiertag") || t.contains("urlaub") || t.contains("geburtstag") { return "sun.max" }
        if t.contains("prüfung") || t.contains("exam") { return "pencil.and.list.clipboard" }
        if t.contains("arbeit") || t.contains("work") { return "briefcase" }
        return "calendar"
    }

    /// Days on which no work is planned at all.
    public static func isWorkFree(_ type: String) -> Bool {
        let t = type.lowercased()
        return ["frei", "feiertag", "urlaub", "geburtstag", "erholung", "familie", "ruhetag", "krank", "besuch"].contains { t.contains($0) }
    }
}

/// Short notes captured during the day.
public enum NoteKind: String, CaseIterable, Sendable {
    case observation = "beobachtung"
    case trigger = "ausloeser"
    case success = "erfolg"
    case contact = "kontakt"
    case idea = "idee"

    public init(raw: String) {
        let t = raw.lowercased()
        self = NoteKind.allCases.first { $0.rawValue == t || $0.label.lowercased() == t } ?? .observation
    }

    public var label: String {
        switch self {
        case .observation: "Beobachtung"
        case .trigger: "Auslöser"
        case .success: "Erfolg"
        case .contact: "Kontakt"
        case .idea: "Idee (geparkt)"
        }
    }

    public var symbol: String {
        switch self {
        case .observation: "eye"
        case .trigger: "bolt.heart"
        case .success: "star"
        case .contact: "person.2"
        case .idea: "lightbulb"
        }
    }
}

/// The evening and weekly reflection questions.
public struct ReflectionQuestion: Identifiable, Equatable, Sendable {
    public let id: String
    public let question: String
    public let hint: String

    /// The evening: no questions any more – a check "ins Journal eingetragen" (`journalField`)
    /// and one optional line.
    public static let day: [ReflectionQuestion] = [
        .init(id: "notiz", question: "Notiz zum Tag", hint: "Optional – ein Satz genügt."),
    ]

    /// Stored as a reflection with text "ja" / "nein".
    public static let journalField = "journal"

    public static let week: [ReflectionQuestion] = [
        .init(id: "interpretation", question: "Meine Deutung der Woche", hint: "Was ist wirklich passiert – hinter den Zahlen?"),
        .init(id: "wiederholen", question: "Was hat gut genug funktioniert, um es zu wiederholen?", hint: "Wiederholen statt steigern."),
        .init(id: "reibung", question: "Was hat vermeidbare Reibung erzeugt?", hint: "Konkret: wann, wo, wodurch."),
        .init(id: "ausserhalb", question: "Was lag wirklich außerhalb des Plans?", hint: "Nicht alles ist eine Disziplinfrage."),
        .init(id: "aendern", question: "Was soll sich nächste Woche ändern?", hint: "Klein und machbar."),
        .init(id: "beibehalten", question: "Was bleibt bewusst gleich?", hint: "Konsistenz vor Spitzen."),
    ]

    public static func question(for id: String) -> ReflectionQuestion? {
        (day + week).first { $0.id == id }
    }
}
