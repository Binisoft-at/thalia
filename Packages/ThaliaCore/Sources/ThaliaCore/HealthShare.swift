import Foundation

// HEALTHSHARE – TestFlight only (TASKS-v11 §1.4, package P9; remove before the first App Store submission,
// §1.4.12: everything here except the prefix and `isKey`, which the App Store clean-up keeps).
//
// An iPhone that reads Health and has "Health-Werte mit Mac und Watch teilen" on writes a state record and
// one record per day (`key(day:)`) as JSON in `AppSetting` – no schema change. Mac, watch and iPad read them
// as Health values, so they score a week like the iPhone. Never in `SettingKeys.all`: never in a backup,
// `record` rows, the exchange, the catalog or a prompt.
// HEALTHSHARE: only while the gate is `.allowed` (`HealthShareGate`, Shared).

// HEALTHSHARE
public enum HealthShare {
    // HEALTHSHARE: the key prefix of every record of the sharing (state and days).
    public static let prefix = "hshare."
    // HEALTHSHARE: the state record (`HealthShareState`).
    public static let stateKey = "hshare.state"
    /// Days shared: today and the 34 days before (the running week + 4 – covers the grace week and the
    /// three weeks scored again).
    public static let window = 35
    /// Days with the Health suggestions (`read`): today and the 2 days before.
    public static let readDays = 3
    /// The note of a shared value as an entry.
    public static let note = "Apple Health"

    /// The record of `day`.
    public static func key(day: DayKey) -> String { prefix + day.string }

    /// The records of `week`'s seven days (the state is read with `stateKey`).
    public static func keys(week: WeekKey) -> [String] { week.days.map { key(day: $0) } }

    /// The day in a day record's key; nil for the state and every other key.
    public static func day(settingKey key: String) -> DayKey? {
        guard key.hasPrefix(prefix), key != stateKey else { return nil }
        return DayKey(String(key.dropFirst(prefix.count)))
    }

    /// One of the sharing's keys (state or day) – what the App Store clean-up deletes.
    public static func isKey(_ key: String) -> Bool { key.hasPrefix(prefix) }

    /// Today and the days before it in the window, oldest first.
    public static func windowDays(today: DayKey) -> [DayKey] {
        (0..<window).reversed().map { today.adding(days: -$0) }
    }

    /// Today and the 2 days before, oldest first – the days with `read`.
    public static func readWindow(today: DayKey) -> [DayKey] {
        (0..<readDays).reversed().map { today.adding(days: -$0) }
    }

    /// The shared values as Health entries (code, day, value, note "Apple Health") – only days written by
    /// the state's device (`by`) inside `from…through`, and only while the state is on; of two copies of a
    /// day the newer one counts. Empty without a state.
    public static func entries(_ days: [HealthShareDay], state: HealthShareState?) -> [EntryRecord] {
        guard let state, state.on else { return [] }
        var newest: [DayKey: HealthShareDay] = [:]
        for record in days where record.by == state.by && state.covers(record.day) {
            if let known = newest[record.day], known.modifiedAt >= record.modifiedAt { continue }
            newest[record.day] = record
        }
        var result: [EntryRecord] = []
        for day in newest.keys.sorted() {
            guard let record = newest[day] else { continue }
            for code in record.counted.keys.sorted() {
                guard let value = record.counted[code], value.isFinite else { continue }
                result.append(EntryRecord(code: code, day: day, value: value, note: note))
            }
        }
        return result
    }

    /// What the iPhone read from Health for `code` on `day` (a suggestion, not taken over); nil without one.
    /// With `state`: only from its device, inside `from…through`, while it is on.
    public static func read(_ days: [HealthShareDay], code: String, day: DayKey, state: HealthShareState? = nil) -> Double? {
        let candidates = days.filter { record in
            guard record.day == day else { return false }
            guard let state else { return true }
            return state.on && record.by == state.by && state.covers(day)
        }
        return candidates.max { $0.modifiedAt < $1.modifiedAt }?.read[code]
    }

    /// The state covers `day`: on, and `day` inside `from…through`.
    public static func covers(_ day: DayKey, state: HealthShareState?) -> Bool {
        state?.covers(day) ?? false
    }

    /// The same as a reader sees it on `today` (`HealthShareState.readable(today:)`): never a day older than the window.
    public static func covers(_ day: DayKey, state: HealthShareState?, today: DayKey) -> Bool {
        state?.readable(today: today).covers(day) ?? false
    }

    /// "aus Health am iPhone" (or "am iPad") – the caption of a shared value on the other devices (§1.4.8).
    public static func sharedCaption(_ state: HealthShareState?) -> String {
        "aus Health am \(state?.writerKind ?? "iPhone")"
    }

    /// "Health am iPhone: 72,6 kg – dort übernehmen" – read there, taken over nowhere (§1.4.8). `shown`: the value as text.
    public static func suggestionText(_ shown: String, state: HealthShareState?) -> String {
        "Health am \(state?.writerKind ?? "iPhone"): \(shown) – dort übernehmen"
    }

    /// The day records among `keys` older than the window by `today` (more than 34 days before it) – to
    /// delete, at most once a day, on every device with the gate open.
    public static func expired(keys: [String], today: DayKey) -> [String] {
        let first = today.adding(days: -(window - 1))
        return keys.filter { key in day(settingKey: key).map { $0 < first } ?? false }.sorted()
    }
}

// HEALTHSHARE: one shared day (`key(day:)`).
/// `{"by":"<install id>","counted":{"<code>":72.5},"day":"2026-11-23","modifiedAt":"…","read":{"<code>":72.6},"v":1}` –
/// `counted`: the Health values taken over on the iPhone (`HealthValue`); `read`: what Thalia read from Health
/// there (suggestions, only today and the 2 days before). Only codes of measures with a `health:` source of the
/// day's week.
public struct HealthShareDay: Codable, Equatable, Sendable {
    public var v: Int
    public var day: DayKey
    /// The install id of the writing device.
    public var by: String
    public var counted: [String: Double]
    public var read: [String: Double]
    public var modifiedAt: Date

    public init(v: Int = 1, day: DayKey, by: String, counted: [String: Double] = [:], read: [String: Double] = [:],
                modifiedAt: Date = Date()) {
        self.v = v
        self.day = day
        self.by = by
        self.counted = counted.filter { $0.value.isFinite }
        self.read = read.filter { $0.value.isFinite }
        self.modifiedAt = modifiedAt
    }

    enum CodingKeys: String, CodingKey { case v, day, by, counted, read, modifiedAt }

    /// Tolerant: missing or odd fields read as defaults; a value that isn't a number is left out.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = SettingJSON.int(c, .v) ?? 1
        day = SettingJSON.text(c, .day).flatMap { DayKey($0) } ?? DayKey(ordinal: 0)
        by = SettingJSON.text(c, .by) ?? ""
        counted = HealthShareDay.values(c, .counted)
        read = HealthShareDay.values(c, .read)
        modifiedAt = SettingJSON.date(c, .modifiedAt) ?? Date(timeIntervalSince1970: 0)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)
        try c.encode(day.string, forKey: .day)
        try c.encode(by, forKey: .by)
        try c.encode(counted.filter { $0.value.isFinite }, forKey: .counted)
        try c.encode(read.filter { $0.value.isFinite }, forKey: .read)
        try c.encode(JSONText.timestamp(modifiedAt), forKey: .modifiedAt)
    }

    static func values(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String: Double] {
        guard let object = ((try? c.decodeIfPresent(JSONValue.self, forKey: key)) ?? nil)?.objectValue else { return [:] }
        var result: [String: Double] = [:]
        for (code, value) in object { if let number = value.numberValue, number.isFinite { result[code] = number } }
        return result
    }

    // HEALTHSHARE: the record's key.
    public var settingKey: String { HealthShare.key(day: day) }

    /// The setting's value (JSON, keys sorted).
    public var value: String { SettingJSON.string(self) }

    /// The record in a setting's value (the day from `key` when the JSON has none); nil when it isn't one.
    public init?(value: String, key: String? = nil) {
        guard var decoded: HealthShareDay = SettingJSON.decode(value) else { return nil }
        // HEALTHSHARE
        if decoded.day.ordinal == 0, let fromKey = key.flatMap(HealthShare.day(settingKey:)) { decoded.day = fromKey }
        self = decoded
    }

    /// The same values (`counted`, `read`, device and day) – the writer saves only on a change, never just
    /// because `modifiedAt` differs.
    public func hasSameValues(as other: HealthShareDay?) -> Bool {
        guard let other else { return false }
        return day == other.day && by == other.by && counted == other.counted && read == other.read
    }
}

// HEALTHSHARE: the state of the sharing (`stateKey`).
/// `{"by":"<install id>","from":"2026-10-20","modifiedAt":"…","on":true,"through":"2026-11-23","v":1}` – `by` also
/// when off (a tombstone: readers skip the day records then), so the device that ended it is known.
public struct HealthShareState: Codable, Equatable, Sendable {
    public var v: Int
    public var on: Bool
    /// The install id of the writing device (also of the one that switched it off).
    public var by: String
    /// The first and last shared day.
    public var from: DayKey?
    public var through: DayKey?
    public var modifiedAt: Date
    /// The kind of the writing device ("iPhone", "iPad" – never its name); nil in a state written without it.
    public var device: String?

    public init(v: Int = 1, on: Bool, by: String, from: DayKey? = nil, through: DayKey? = nil, modifiedAt: Date = Date(),
                device: String? = nil) {
        self.v = v
        self.on = on
        self.by = by
        self.from = from
        self.through = through
        self.modifiedAt = modifiedAt
        self.device = device
    }

    enum CodingKeys: String, CodingKey { case v, on, by, from, through, modifiedAt, device }

    /// Tolerant: missing or odd fields read as defaults (off).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = SettingJSON.int(c, .v) ?? 1
        on = SettingJSON.bool(c, .on) ?? false
        by = SettingJSON.text(c, .by) ?? ""
        from = SettingJSON.text(c, .from).flatMap { DayKey($0) }
        through = SettingJSON.text(c, .through).flatMap { DayKey($0) }
        modifiedAt = SettingJSON.date(c, .modifiedAt) ?? Date(timeIntervalSince1970: 0)
        device = SettingJSON.text(c, .device)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)
        try c.encode(on, forKey: .on)
        try c.encode(by, forKey: .by)
        try c.encodeIfPresent(from?.string, forKey: .from)
        try c.encodeIfPresent(through?.string, forKey: .through)
        try c.encode(JSONText.timestamp(modifiedAt), forKey: .modifiedAt)
        try c.encodeIfPresent(device, forKey: .device)
    }

    // HEALTHSHARE: on for today's window (`HealthShare.window` days up to `today`) by `by`; `device` its kind ("iPad").
    public static func sharing(by: String, today: DayKey, now: Date = Date(), device: String? = nil) -> HealthShareState {
        // HEALTHSHARE
        HealthShareState(on: true, by: by, from: today.adding(days: -(HealthShare.window - 1)), through: today, modifiedAt: now,
                         device: device)
    }

    /// The writing device's kind for the texts on the other devices: "iPhone" when the state doesn't say ("aus Health
    /// am iPad" after an iPad took the sharing over, §3.4.2).
    public var writerKind: String {
        guard let device, !device.isEmpty else { return "iPhone" }
        return device
    }

    // HEALTHSHARE: as a reader sees it on `today` (§1.4.6): every device deletes the day records older than the window by
    // its own clock (`HealthShare.expired`), so `from` is at most `HealthShare.window` days back – a writer that wasn't
    // active for a few days never makes days count as covered that may be gone already.
    public func readable(today: DayKey) -> HealthShareState {
        var copy = self
        // HEALTHSHARE
        let first: DayKey = today.adding(days: -(HealthShare.window - 1))
        if let from, from < first { copy.from = first }
        return copy
    }

    /// Off, written by `by` (the tombstone).
    public static func stopped(by: String, now: Date = Date()) -> HealthShareState {
        HealthShareState(on: false, by: by, modifiedAt: now)
    }

    /// On, and `day` inside `from…through`.
    public func covers(_ day: DayKey) -> Bool {
        guard on, let from, let through else { return false }
        return day >= from && day <= through
    }

    /// The setting's value (JSON, keys sorted).
    public var value: String { SettingJSON.string(self) }

    /// The state in a setting's value; nil when it isn't one.
    public init?(value: String) {
        guard let decoded: HealthShareState = SettingJSON.decode(value) else { return nil }
        self = decoded
    }

    /// Of several copies (two devices before they synced): the newest `modifiedAt` – nil without copies.
    public static func newest(_ values: [String]) -> HealthShareState? {
        values.compactMap(HealthShareState.init(value:)).max { $0.modifiedAt < $1.modifiedAt }
    }
}
