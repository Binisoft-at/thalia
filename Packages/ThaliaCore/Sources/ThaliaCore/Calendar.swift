import Foundation

// Days and ISO weeks as plain values. Everything the tracker stores refers to a day as
// "2026-11-02" and to a week as "2026-W45" (ISO 8601: weeks start on Monday, week 1 holds the
// year's first Thursday; some years have a week 53). Pure integer arithmetic, so the result is the
// same on every device, in every time zone and on Linux.

/// ISO weekday, Monday = 1 … Sunday = 7.
public enum Weekday: Int, CaseIterable, Comparable, Codable, Sendable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    /// "Mo", "Di", …
    public var short: String {
        ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"][rawValue - 1]
    }

    /// "Montag", …
    public var name: String {
        ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"][rawValue - 1]
    }

    /// Bit in a `DayMask`.
    public var bit: Int { 1 << (rawValue - 1) }

    /// Apple's `DateComponents.weekday` (Sunday = 1 … Saturday = 7).
    public var gregorianWeekday: Int { rawValue % 7 + 1 }
}

/// A calendar day without time or time zone.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    /// Days since 1970-01-01.
    public let ordinal: Int

    public init(ordinal: Int) {
        self.ordinal = ordinal
    }

    public init(year: Int, month: Int, day: Int) {
        ordinal = DayKey.daysFromCivil(year, month, day)
    }

    /// "2026-11-02" or "02.11.2026"; nil when it isn't a valid date.
    public init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let iso = trimmed.split(separator: "-").map(String.init)
        let german = trimmed.split(separator: ".").map(String.init).filter { !$0.isEmpty }
        let parts: (Int, Int, Int)?
        if iso.count == 3, let y = Int(iso[0]), let m = Int(iso[1]), let d = Int(iso[2]), iso[0].count == 4 {
            parts = (y, m, d)
        } else if german.count == 3, let d = Int(german[0]), let m = Int(german[1]), let y = Int(german[2]), german[2].count == 4 {
            parts = (y, m, d)
        } else {
            parts = nil
        }
        guard let (y, m, d) = parts, (1...12).contains(m), d >= 1, d <= DayKey.daysIn(month: m, year: y) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The day `date` falls on in `timeZone` (default: the device's).
    public init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func today(timeZone: TimeZone = .current) -> DayKey {
        DayKey(date: Date(), timeZone: timeZone)
    }

    public var components: (year: Int, month: Int, day: Int) { DayKey.civilFromDays(ordinal) }
    public var year: Int { components.year }
    public var month: Int { components.month }
    public var day: Int { components.day }

    /// "2026-11-02"
    public var string: String {
        let c = components
        return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
    }

    public var description: String { string }

    public var weekday: Weekday {
        // 1970-01-01 was a Thursday.
        Weekday(rawValue: ((ordinal + 3) % 7 + 7) % 7 + 1) ?? .monday
    }

    public func adding(days: Int) -> DayKey { DayKey(ordinal: ordinal + days) }

    public var week: WeekKey {
        let thursday = adding(days: 4 - weekday.rawValue)
        let jan1 = DayKey(year: thursday.year, month: 1, day: 1)
        return WeekKey(year: thursday.year, week: (thursday.ordinal - jan1.ordinal) / 7 + 1)
    }

    /// Midnight at the start of this day in `timeZone`.
    public func startDate(timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = components
        return calendar.date(from: DateComponents(year: c.year, month: c.month, day: c.day)) ?? Date(timeIntervalSince1970: 0)
    }

    /// "Mo, 2. Nov."
    public var shortLabel: String {
        "\(weekday.short), \(day). \(DayKey.monthShort[month - 1])"
    }

    /// "Montag, 2. November 2026"
    public var longLabel: String {
        "\(weekday.name), \(day). \(DayKey.monthNames[month - 1]) \(year)"
    }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool { lhs.ordinal < rhs.ordinal }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a day: \(text)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }

    static let monthNames = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
                             "September", "Oktober", "November", "Dezember"]
    static let monthShort = ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."]

    static func isLeap(_ y: Int) -> Bool { (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 }

    static func daysIn(month m: Int, year y: Int) -> Int {
        switch m {
        case 2: return isLeap(y) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    // Howard Hinnant's days_from_civil / civil_from_days.
    static func daysFromCivil(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }
}

/// An ISO week, "2026-W45".
public struct WeekKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let week: Int

    public init(year: Int, week: Int) {
        self.year = year
        self.week = week
    }

    /// "2026-W45", "2026-KW45", "KW45 2026", "KW 45/2026", "W45-2026".
    public init?(_ text: String) {
        let upper = text.uppercased().replacingOccurrences(of: "KW", with: "W")
        let digits = upper.split(whereSeparator: { !$0.isNumber }).map(String.init)
        guard digits.count == 2, upper.contains("W") else { return nil }
        let (a, b) = (digits[0], digits[1])
        let year: Int
        let week: Int
        if a.count == 4, let y = Int(a), let w = Int(b) {
            (year, week) = (y, w)
        } else if b.count == 4, let y = Int(b), let w = Int(a) {
            (year, week) = (y, w)
        } else {
            return nil
        }
        guard week >= 1, week <= WeekKey.weeksIn(year: year) else { return nil }
        self.init(year: year, week: week)
    }

    /// Weeks in an ISO year: 53 when 28 December falls in week 53.
    public static func weeksIn(year: Int) -> Int {
        DayKey(year: year, month: 12, day: 28).week.week
    }

    /// "2026-W45"
    public var string: String { String(format: "%04d-W%02d", year, week) }
    public var description: String { string }

    /// "KW45"
    public var label: String { "KW\(week)" }
    /// "KW45 2026"
    public var longLabel: String { "KW\(week) \(year)" }

    public var monday: DayKey {
        let jan4 = DayKey(year: year, month: 1, day: 4)
        let firstMonday = jan4.adding(days: 1 - jan4.weekday.rawValue)
        return firstMonday.adding(days: (week - 1) * 7)
    }

    public var sunday: DayKey { monday.adding(days: 6) }

    /// Monday … Sunday.
    public var days: [DayKey] { (0..<7).map { monday.adding(days: $0) } }

    public func contains(_ day: DayKey) -> Bool { day >= monday && day <= sunday }

    public func day(_ weekday: Weekday) -> DayKey { monday.adding(days: weekday.rawValue - 1) }

    public func adding(weeks: Int) -> WeekKey { monday.adding(days: weeks * 7).week }

    /// "2.–8. Nov." / "28. Dez. – 3. Jan."
    public var rangeLabel: String {
        let start = monday
        let end = sunday
        if start.month == end.month {
            return "\(start.day).–\(end.day). \(DayKey.monthShort[end.month - 1])"
        }
        return "\(start.day). \(DayKey.monthShort[start.month - 1]) – \(end.day). \(DayKey.monthShort[end.month - 1])"
    }

    public static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
        (lhs.year, lhs.week) < (rhs.year, rhs.week)
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let key = WeekKey(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a week: \(text)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(string)
    }
}

/// Weekdays an item or measurement applies to, as a bit set (Monday = bit 0).
public struct DayMask: Equatable, Hashable, Codable, Sendable {
    public var rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue & 127
    }

    public init(_ days: [Weekday]) {
        self.init(rawValue: days.reduce(0) { $0 | $1.bit })
    }

    public static let everyDay = DayMask(rawValue: 127)
    public static let workdays = DayMask(rawValue: 31)
    public static let weekend = DayMask(rawValue: 96)

    public func contains(_ day: Weekday) -> Bool { rawValue & day.bit != 0 }
    public var days: [Weekday] { Weekday.allCases.filter(contains) }
    public var isEmpty: Bool { rawValue == 0 }
    public var count: Int { days.count }

    /// Reads "täglich", "Mo-Fr", "Mo,Mi,Fr", "Sa+So", "werktags", "Wochenende", "Di Do", "Mon-Fri".
    /// Empty text = every day. Returns nil when nothing could be read.
    public static func parse(_ text: String) -> DayMask? {
        let lower = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if lower.isEmpty || ["täglich", "taeglich", "tägl.", "jeden tag", "alle", "daily", "every day", "mo-so", "mo–so"].contains(lower) {
            return .everyDay
        }
        if ["werktags", "wochentags", "arbeitstage", "weekdays"].contains(lower) { return .workdays }
        if ["wochenende", "weekend"].contains(lower) { return .weekend }
        var mask = 0
        var normalized = lower.replacingOccurrences(of: "–", with: "-").replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " bis ", with: "-")
        while normalized.contains(" -") || normalized.contains("- ") {
            normalized = normalized.replacingOccurrences(of: " -", with: "-").replacingOccurrences(of: "- ", with: "-")
        }
        let pieces = normalized.split(whereSeparator: { ",;+/ &".contains($0) }).map(String.init).filter { !$0.isEmpty && $0 != "und" }
        for piece in pieces {
            let range = piece.split(separator: "-").map(String.init)
            if range.count == 2, let from = weekday(range[0]), let to = weekday(range[1]) {
                var day = from.rawValue
                while true {
                    mask |= 1 << (day - 1)
                    if day == to.rawValue { break }
                    day = day % 7 + 1
                }
            } else if let day = weekday(piece) {
                mask |= day.bit
            } else {
                return nil
            }
        }
        return mask == 0 ? nil : DayMask(rawValue: mask)
    }

    static func weekday(_ token: String) -> Weekday? {
        let t = token.trimmingCharacters(in: .whitespaces.union(.punctuationCharacters))
        let table: [(Weekday, [String])] = [
            (.monday, ["mo", "mon", "montag", "monday"]),
            (.tuesday, ["di", "die", "dienstag", "tu", "tue", "tuesday"]),
            (.wednesday, ["mi", "mit", "mittwoch", "we", "wed", "wednesday"]),
            (.thursday, ["do", "don", "donnerstag", "th", "thu", "thursday"]),
            (.friday, ["fr", "fre", "freitag", "fri", "friday"]),
            (.saturday, ["sa", "sam", "samstag", "sat", "saturday"]),
            (.sunday, ["so", "son", "sonntag", "su", "sun", "sunday"]),
        ]
        return table.first { $0.1.contains(t) }?.0
    }

    /// "täglich", "Mo–Fr", "Sa, So", "Mo, Mi, Fr", "Di–Do, Sa".
    public var label: String {
        if self == .everyDay { return "täglich" }
        if isEmpty { return "nie" }
        return runs().map { run in
            run.count >= 3 ? "\(run.first!.short)–\(run.last!.short)" : run.map(\.short).joined(separator: ", ")
        }.joined(separator: ", ")
    }

    /// The CSV form: "täglich", "Mo-Fr", "Mo,Mi,Fr".
    public var csv: String {
        if self == .everyDay { return "täglich" }
        return runs().map { run in
            run.count >= 3 ? "\(run.first!.short)-\(run.last!.short)" : run.map(\.short).joined(separator: ",")
        }.joined(separator: ",")
    }

    private func runs() -> [[Weekday]] {
        var result: [[Weekday]] = []
        for day in days {
            if let last = result.last?.last, last.rawValue + 1 == day.rawValue {
                result[result.count - 1].append(day)
            } else {
                result.append([day])
            }
        }
        return result
    }
}

/// The goal year ("1 June 2026 – 31 May 2027") with its review milestone.
public struct GoalPeriod: Equatable, Codable, Sendable {
    public var start: DayKey
    public var end: DayKey
    public var reviewWeek: WeekKey
    public var motto: String

    public init(start: DayKey, end: DayKey, reviewWeek: WeekKey, motto: String) {
        self.start = start
        self.end = end
        self.reviewWeek = reviewWeek
        self.motto = motto
    }

    /// Bini's goal year as described in the handover.
    public static let foundationYear = GoalPeriod(
        start: DayKey(year: 2026, month: 6, day: 1),
        end: DayKey(year: 2027, month: 5, day: 31),
        reviewWeek: WeekKey(year: 2026, week: 49),
        motto: "Fundamentjahr: auftauchen, nützliches Verhalten wiederholen und ohne unnötigen Druck konsistent werden."
    )

    public var totalDays: Int { end.ordinal - start.ordinal + 1 }

    /// 0…1 through the year on `day`.
    public func progress(on day: DayKey) -> Double {
        let done = Double(day.ordinal - start.ordinal + 1)
        return min(1, max(0, done / Double(totalDays)))
    }

    /// Week number within the goal year (1 = the week holding the start day).
    public func weekNumber(of week: WeekKey) -> Int {
        (week.monday.ordinal - start.week.monday.ordinal) / 7 + 1
    }

    public var totalWeeks: Int { weekNumber(of: end.week) }
}
