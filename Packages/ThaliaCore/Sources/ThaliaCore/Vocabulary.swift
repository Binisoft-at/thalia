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

    /// The words on buttons, menus, watch, PDF and VoiceOver (R43).
    public var label: String {
        switch self {
        case .done: "Erledigt"
        case .partial: "Teilweise"
        case .missed: "Nicht erledigt"
        case .notApplicable: "Entfällt"
        }
    }

    /// Progress items ("daran gearbeitet"): "Gearbeitet" and "Nicht heute", otherwise `label` (R43).
    public func label(progress: Bool) -> String {
        guard progress else { return label }
        switch self {
        case .done: return "Gearbeitet"
        case .notApplicable: return "Nicht heute"
        default: return label
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

    /// Reads a stored or typed target. Leading words (v11 P1.3, whole words only): "spätestens", "bis",
    /// "bis zu", "höchstens", "maximal", "max", "nicht mehr als" → ≤; "weniger als", "unter" → <;
    /// "frühestens", "ab", "mindestens", "min" → ≥; "mehr als", "über" → >. "bis" between two numbers is a
    /// range ("22:30 bis 23:00"); a unit at the end is fine ("≥150 g"). A text starting with an unknown word
    /// ("ca 150") falls back to its number as in 1.9.0 – stored targets never lose their meaning silently;
    /// the editors and the CSV check read strictly (`parse(_:strict:)`).
    public static func parse(_ raw: String) -> Target? {
        parse(raw, strict: false)
    }

    /// `strict` (editors, the CSV check): a text that starts with a letter but no known word is nil
    /// ("Ziel „ca 150“ nicht lesbar"); otherwise as `parse(_:)`.
    public static func parse(_ raw: String, strict: Bool) -> Target? {
        var t = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty else { return nil }
        t = t.replacingOccurrences(of: "≥", with: ">=").replacingOccurrences(of: "≤", with: "<=")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "uhr", with: "")
            .trimmingCharacters(in: .whitespaces)
        var comparison: Comparison?
        for (prefix, value) in [(">=", Comparison.atLeast), ("=>", .atLeast), ("<=", .atMost), ("=<", .atMost),
                                (">", .above), ("<", .below), ("=", .equal)] where t.hasPrefix(prefix) {
            comparison = value
            t = String(t.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            break
        }
        if comparison == nil {
            for (word, value) in Target.leadingWords {
                guard let rest = Target.dropWord(word, from: t) else { continue }
                comparison = value
                t = rest
                break
            }
        }
        if comparison == nil, strict, t.first?.isLetter == true { return nil }
        t = Target.rangeWord(t)
        var numberish = t.trimmingCharacters(in: CharacterSet(charactersIn: "0123456789.,:- ").inverted)
        // A unit at the end may end in "." ("≤ 6 Stk."): everything after the last digit goes (v11 P1.3).
        if let last = numberish.lastIndex(where: \.isNumber) { numberish = String(numberish[...last]) }
        if comparison == nil, let dash = numberish.dropFirst().firstIndex(of: "-") {
            let low = String(numberish[numberish.startIndex..<dash])
            let high = String(numberish[numberish.index(after: dash)...])
            guard let (a, timeA) = parseNumber(low), let (b, timeB) = parseNumber(high) else { return nil }
            return Target(.range, min(a, b), upper: max(a, b), isTime: timeA || timeB)
        }
        guard let (value, isTime) = parseNumber(numberish) else { return nil }
        return Target(comparison ?? .atLeast, value, isTime: isTime)
    }

    /// The words a target may start with (v11 P1.3), longest first, so "bis zu" wins over "bis" and
    /// "nicht mehr als" over "mehr als".
    static let leadingWords: [(String, Comparison)] = [
        ("nicht mehr als", .atMost), ("weniger als", .below), ("mehr als", .above), ("bis zu", .atMost),
        ("spätestens", .atMost), ("höchstens", .atMost), ("maximal", .atMost), ("max.", .atMost), ("max", .atMost), ("bis", .atMost),
        ("frühestens", .atLeast), ("mindestens", .atLeast), ("mind.", .atLeast), ("min.", .atLeast), ("min", .atLeast), ("ab", .atLeast),
        ("unter", .below), ("über", .above),
    ]

    /// The text after `word` when it starts with it as a whole word – followed by a space, a digit or the
    /// end ("ab 8", "max6"; not "abends", "minuten"); a word ending in "." needs nothing after it.
    static func dropWord(_ word: String, from text: String) -> String? {
        guard text.hasPrefix(word) else { return nil }
        let rest = text.dropFirst(word.count)
        if !word.hasSuffix("."), let next = rest.first, !(next == " " || next.isNumber) { return nil }
        return String(rest).trimmingCharacters(in: .whitespaces)
    }

    /// "22:30 bis 23:00" → "22:30 - 23:00": "bis" only between two numbers.
    static func rangeWord(_ text: String) -> String {
        guard let found = text.range(of: "bis") else { return text }
        let before = text[..<found.lowerBound]
        let after = text[found.upperBound...]
        guard before.contains(where: \.isNumber), after.contains(where: \.isNumber) else { return text }
        return before + "-" + after
    }

    /// v11 P1.2: a time target around midnight – one compared value ≥ 12:00 (as before) or < 04:00, a range
    /// only when both ends are ≥ 12:00 or < 04:00 ("23:00–00:30", "22:30–23:00"; "10:00–18:00" is a day
    /// window). Only the comparison changes (`isMet`, `label`), never what is stored.
    public var isNight: Bool {
        guard isTime else { return false }
        func late(_ minutes: Double) -> Bool { minutes >= 12 * 60 || minutes < 4 * 60 }
        if comparison == .range { return late(value) && late(upper ?? value) }
        return late(value)
    }

    /// The minutes of a night target's comparison: times before 12:00 count as the next day (00:30 → 24:30).
    public static func nightMinutes(_ minutes: Double) -> Double {
        minutes < 12 * 60 ? minutes + 24 * 60 : minutes
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
        var v = isTime ? Target.normalizedTime(measured, reference: value) : measured
        var low = value
        var high = upper ?? value
        if isNight {
            // v11 P1.2: measured value and bounds on the night scale; a range's mapped bounds sorted
            // ("23:00–00:30" stored as 00:30–23:00 is the evening window).
            v = Target.nightMinutes(measured)
            let a = Target.nightMinutes(value)
            let b = Target.nightMinutes(upper ?? value)
            low = comparison == .range ? min(a, b) : a
            high = comparison == .range ? max(a, b) : a
        }
        switch comparison {
        case .atLeast: return v >= low - 1e-9
        case .atMost: return v <= low + 1e-9
        case .above: return v > low
        case .below: return v < low
        case .equal: return abs(v - low) < 1e-9
        case .range: return v >= low - 1e-9 && v <= high + 1e-9
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

    /// "≥ 150", "≤ 23:00", "150–180"; a night window in its order ("23:00–00:30", v11 P1.2).
    public var label: String {
        let a = isTime ? Format.clock(value) : Format.number(value)
        if comparison == .range, isNight {
            let ends = [value, upper ?? value].sorted { Target.nightMinutes($0) < Target.nightMinutes($1) }
            return "\(Format.clock(ends[0]))–\(Format.clock(ends[1]))"
        }
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

    /// "Erfüllt bei ≤ 6 pro Tag", "Erfüllt bei ≤ 23:00 pro Tag", "Erfüllt bei 150–180 g pro Woche" (R77).
    public func sentence(period: TargetPeriod, unit: String = "") -> String {
        let shown = isTime || Units.isTime(unit) ? "" : Units.display(unit)
        return "Erfüllt bei \(label)\(shown.isEmpty ? "" : " " + shown) \(period.label)"
    }
}

extension Target.Comparison {
    /// The words in the target picker (R77).
    public var choiceLabel: String {
        switch self {
        case .atLeast: "mindestens"
        case .atMost: "höchstens"
        case .below: "unter"
        case .above: "über"
        case .equal: "genau"
        case .range: "zwischen"
        }
    }

    /// The picker's order.
    public static let choices: [Target.Comparison] = [.atLeast, .atMost, .below, .above, .equal, .range]
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

    /// Decimals shown for a value of this unit (v11 P1.6): PH and litres 2 (quarter hours, 0,25 l), kg and h 1,
    /// counted units 0 (Stk., Seiten, Schritte, min, kcal, g, ml); 1 for everything else. € goes through
    /// `Format.euro` (cents), times through `Format.clock`.
    public static func decimals(_ unit: String) -> Int {
        switch normalized(unit) {
        case "ph", "l", "€": return 2
        case "kg", "h": return 1
        case "stück", "seiten", "schritte", "min", "kcal", "g", "ml": return 0
        default: return 1
        }
    }

    /// A unit after "von" (v11 P1.14): words ending in -e, -er or -el get an "n" ("von 10 Büchern", "Kursen",
    /// "Kapiteln", "Litern"); words already ending in -n or -s and short forms (PH, km, kg, Stk., min, €)
    /// stay ("von 300 Seiten", "von 12 PH").
    public static func dative(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        // Nouns only (capitalised, more than three letters, no "."): short forms like "kcal" stay.
        guard trimmed.count > 3, trimmed.first?.isUppercase == true, !trimmed.contains("."),
              lower.hasSuffix("e") || lower.hasSuffix("er") || lower.hasSuffix("el") else { return trimmed }
        return trimmed + "n"
    }

    /// A plural unit for the value 1 without a target (v11 P1.14): "1 Buch", "1 Seite"; unknown units stay.
    public static func singular(_ unit: String) -> String {
        let trimmed = unit.trimmingCharacters(in: .whitespaces)
        guard let found = singulars.first(where: { $0.0.lowercased() == trimmed.lowercased() })?.1 else { return trimmed }
        return trimmed.first?.isUppercase == true ? found : found.lowercased()
    }

    static let singulars: [(String, String)] = [
        ("Bücher", "Buch"), ("Seiten", "Seite"), ("Packungen", "Packung"), ("Workouts", "Workout"), ("Lektionen", "Lektion"),
        ("Folgen", "Folge"), ("Kurse", "Kurs"), ("Filme", "Film"), ("Minuten", "Minute"), ("Stunden", "Stunde"), ("Schritte", "Schritt"),
    ]

    /// The units offered when creating a measurement (R77) – power-hours come from work, not from here.
    public static let choices: [String] = ["", "kg", "g", "l", "min", "h", "Uhrzeit", "€", "Stück", "Seiten", "Schritte", "Text"]

    /// One step of the watch's Digital Crown (R81).
    public static func crownStep(_ unit: String) -> Double {
        switch normalized(unit) {
        case "kg": return 0.1
        case "l": return 0.25
        case "€": return 0.5
        case "uhrzeit": return 5
        case "h": return 0.25
        default: return 1
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
    /// A connected app's facts (v10, "app:george:workout=tpl-1", "app:nina:kcal", "app:theo:task"): computed
    /// from the inbox, never stored as own entries (`ExchangeDerivation`).
    case app(AppSource)
    /// Read from the reading list (v10, "list:buch"): the day's value is the amount read in all entries of
    /// that kind (`ListMath`).
    case list(kind: String)
    /// A source this build doesn't know ("health:carbs", "x:…" from a newer build). It behaves like
    /// `manual`, but the text is kept unchanged, so saving the measure here never erases it.
    case other(String)

    /// "", "arbeit:3.2", "health:sleep", "app:nina:kcal", "list:buch"; unknown "prefix:…" texts are kept as
    /// `other` (also an "app:…" or "list:…" text that can't be read).
    public init(raw: String) {
        let t = raw.trimmingCharacters(in: .whitespaces)
        let lower = t.lowercased()
        if lower.hasPrefix("arbeit:") || lower.hasPrefix("work:") {
            self = .work(category: String(t[t.index(after: t.firstIndex(of: ":")!)...]).trimmingCharacters(in: .whitespaces))
        } else if lower.hasPrefix("health:") || lower.hasPrefix("gesundheit:") {
            let kind = String(lower[lower.index(after: lower.firstIndex(of: ":")!)...])
            self = HealthKind(token: kind).map(MeasureSource.health) ?? .other(t)
        } else if lower.hasPrefix(AppSource.prefix) {
            self = AppSource(raw: t).map(MeasureSource.app) ?? .other(t)
        } else if lower.hasPrefix(MeasureSource.listPrefix) {
            let kind = ListItem.kindKey(String(t.dropFirst(MeasureSource.listPrefix.count)))
            self = kind.isEmpty ? .other(t) : .list(kind: kind)
        } else if t.contains(":") {
            self = .other(t)
        } else {
            self = .manual
        }
    }

    public var raw: String {
        switch self {
        case .manual: ""
        case .work(let category): "arbeit:\(category)"
        case .health(let kind): "health:\(kind.rawValue)"
        case .app(let source): source.raw
        case .list(let kind): MeasureSource.listPrefix + kind
        case .other(let text): text
        }
    }

    /// "list:"
    public static let listPrefix = "list:"

    /// The connected app's source, if any.
    public var appSource: AppSource? {
        if case .app(let source) = self { return source }
        return nil
    }

    /// The reading-list kind ("buch"), if any.
    public var listKind: String? {
        if case .list(let kind) = self { return kind }
        return nil
    }

    /// The value is computed (power-hours, a connected app, the reading list) – the "+" of such a
    /// measure doesn't simply add an own entry.
    public var isComputed: Bool {
        switch self {
        case .work, .app, .list: return true
        default: return false
        }
    }

    /// For the measure editor's "Quelle" (v10): "Manuell", "Power-Hours", "Apple Health", "Leseliste",
    /// "Verbundene App", "Andere Quelle".
    public var choiceLabel: String {
        switch self {
        case .manual: "Manuell"
        case .work: "Power-Hours"
        case .health: "Apple Health"
        case .list: "Leseliste"
        case .app: "Verbundene App"
        case .other: "Andere Quelle"
        }
    }

    /// "Leseliste · Buch", "George · workout = tpl-1", "Apple Health · Schritte", "Power-Hours · 3.2"; "" for manual.
    public var label: String {
        switch self {
        case .manual: ""
        case .work(let category): "Power-Hours · \(category)"
        case .health(let kind): "Apple Health · \(kind.label)"
        case .list(let kind): "Leseliste · \(ListItem.kindTitle(kind))"
        case .app(let source): source.label
        case .other(let text): text
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
    public static let presets = ["Arbeitstag", "Reisetag", "Familientag", "Erholungstag", "Frei", "Krank", "Urlaub", "Prüfungstag", "Besuch"]

    /// The presets whose days don't count in the week's score (v8), in picker order.
    public static let excusedPresets = ["Krank", "Urlaub"]

    public static func symbol(for type: String) -> String {
        let t = type.lowercased()
        // Excused days first: the symbol says "zählt nicht" even for "Familienurlaub".
        if t.contains("krank") { return "cross.case" }
        if t.contains("urlaub") { return "beach.umbrella" }
        if t.contains("reise") || t.contains("flug") || t.contains("flughafen") { return "airplane" }
        if t.contains("famil") || t.contains("besuch") { return "figure.2.and.child.holdinghands" }
        if t.contains("erhol") || t.contains("ruhe") || t.contains("krank") { return "leaf" }
        if t.contains("frei") || t.contains("feiertag") || t.contains("urlaub") || t.contains("geburtstag") { return "sun.max" }
        if t.contains("prüfung") || t.contains("exam") { return "pencil.and.list.clipboard" }
        if t.contains("arbeit") || t.contains("work") { return "briefcase" }
        return "calendar"
    }

    /// Shown on work-free days (R78).
    public static let workFreeHint = "Arbeitsfreier Tag: Arbeitspunkte zählen heute nicht"

    /// Days on which no work is planned at all.
    public static func isWorkFree(_ type: String) -> Bool {
        let t = type.lowercased()
        return ["frei", "feiertag", "urlaub", "geburtstag", "erholung", "familie", "ruhetag", "krank", "besuch"].contains { t.contains($0) }
    }

    /// Shown on sick and holiday days (v8).
    public static let excusedHint = "Krank/Urlaub: Der Tag zählt nicht in die Wochenwertung"

    /// Sick or holiday ("Krank", "Urlaubstag", "krank – Erkältung"): nothing is due, the day doesn't
    /// count in the week's score (v8). Not "Frei", "Feiertag" or "Erholungstag".
    public static func isExcused(_ type: String) -> Bool {
        let t = type.lowercased()
        return t.contains("krank") || t.contains("urlaub")
    }

    /// The excused days among `days` by their types (`"2026-11-06"` → "Krank").
    public static func excusedDays(_ days: [DayKey], types: (DayKey) -> String) -> Set<DayKey> {
        Set(days.filter { isExcused(types($0)) })
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

    /// The kinds in one line (R78).
    public static let listText = "Beobachtung, Auslöser, Erfolg, Kontakt, Idee"

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
        .init(id: ReflectionQuestion.dayNoteField, question: "Notiz zum Tag", hint: "Optional – ein Satz genügt."),
    ]

    /// Stored as a reflection with text "ja" / "nein".
    public static let journalField = "journal"

    /// The day's note ("Notiz zum Tag") is stored under this field (R26).
    public static let dayNoteField = "notiz"

    /// The plan's journal item: its title contains "journal", any case (R58).
    public static func isJournalTitle(_ title: String) -> Bool {
        title.lowercased().contains("journal")
    }

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
