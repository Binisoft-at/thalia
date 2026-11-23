import Foundation

// v10 storage without a CloudKit schema change (TASKS-v10 §1.1): every new kind of record is a small
// JSON object in an `AppSetting` under its own key prefix – the v9 `archive.<week>` pattern. Older
// builds ignore the keys. Rules:
//   - one record per key; the key of a dated fact carries its day ("goal.entry.2026-11-17.<uuid>"), so
//     two devices never overwrite each other's facts and `touchedWeeks()` finds the week (Grundregel 3)
//   - JSON with `v`; missing fields read as defaults, wrong types too (tolerant)
//   - unknown fields (from a newer build) are kept and written back unchanged (Grundregel 4)
//   - deleting sets `deletedAt` ("Zuletzt gelöscht"); the record stays until the trash is emptied

/// Any JSON value – used to keep fields this build doesn't know.
public enum JSONValue: Equatable, Sendable, Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a JSON value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value):
            // Whole numbers as integers ("3", not "3.0"), so files look the same on every platform.
            if value == value.rounded(), abs(value) < 9e15 { try container.encode(Int64(value)) } else { try container.encode(value) }
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// The text, also for numbers and booleans written as such ("3", "true"); nil for null, arrays, objects.
    public var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .number(let value): return Format.plain(value)
        case .bool(let value): return value ? "true" : "false"
        default: return nil
        }
    }

    /// The number, also from a numeric text ("1.5", "1,5"); nil otherwise.
    public var numberValue: Double? {
        switch self {
        case .number(let value): return value.isFinite ? value : nil
        case .string(let text):
            let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            return Double(cleaned).flatMap { $0.isFinite ? $0 : nil }
        default: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let value): return value
        case .number(let value): return value != 0
        case .string(let text):
            switch text.lowercased() {
            case "true", "ja", "1", "yes": return true
            case "false", "nein", "0", "no": return false
            default: return nil
            }
        default: return nil
        }
    }

    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }

    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self { return value }
        return nil
    }
}

/// JSON text in and out: compact, keys sorted (the same record always gives the same text).
public enum JSONText {
    /// The object in `text`; nil when it isn't a JSON object.
    public static func object(_ text: String) -> [String: JSONValue]? {
        guard let data = text.data(using: .utf8), !data.isEmpty else { return nil }
        return try? JSONDecoder().decode([String: JSONValue].self, from: data)
    }

    public static func string(_ object: [String: JSONValue]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(object), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// "2026-11-22T18:04:05.123Z" – with milliseconds, so "newer wins" can tell two saves apart.
    public static func timestamp(_ date: Date) -> String {
        ExchangeDate.string(date, timeZone: TimeZone(identifier: "UTC") ?? .current, fractional: true)
    }
}

/// Tolerant reading of a record's fields: a missing field or one of the wrong type is nil.
struct RecordFields {
    let object: [String: JSONValue]

    init(_ object: [String: JSONValue]) {
        self.object = object
    }

    func string(_ key: String) -> String? { object[key]?.stringValue }
    func text(_ key: String) -> String { string(key) ?? "" }
    func number(_ key: String) -> Double? { object[key]?.numberValue }
    func bool(_ key: String) -> Bool? { object[key]?.boolValue }
    func date(_ key: String) -> Date? {
        guard let value = object[key] else { return nil }
        if case .number(let seconds) = value { return Date(timeIntervalSince1970: seconds) }
        return value.stringValue.flatMap(ExchangeDate.parse)
    }
    func day(_ key: String) -> DayKey? { string(key).flatMap { DayKey($0) } }
    func week(_ key: String) -> WeekKey? { string(key).flatMap { WeekKey($0) } }
    /// An optional text: nil when missing or empty.
    func optional(_ key: String) -> String? {
        guard let text = string(key)?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return nil }
        return text
    }
    func stringMap(_ key: String) -> [String: String] {
        guard let object = object[key]?.objectValue else { return [:] }
        var result: [String: String] = [:]
        for (name, value) in object { if let text = value.stringValue { result[name] = text } }
        return result
    }
    func objects(_ key: String) -> [RecordFields] {
        (object[key]?.arrayValue ?? []).compactMap { $0.objectValue.map(RecordFields.init) }
    }
}

/// Building a record's fields: nil and empty optionals are left out.
struct FieldWriter {
    var object: [String: JSONValue] = [:]

    mutating func set(_ key: String, _ value: String) { object[key] = .string(value) }
    mutating func set(_ key: String, _ value: String?) { if let value, !value.isEmpty { object[key] = .string(value) } }
    mutating func set(_ key: String, _ value: Double?) { if let value, value.isFinite { object[key] = .number(value) } }
    mutating func set(_ key: String, _ value: Bool) { object[key] = .bool(value) }
    mutating func set(_ key: String, _ value: Date?) { if let value { object[key] = .string(JSONText.timestamp(value)) } }
    mutating func set(_ key: String, _ value: DayKey?) { if let value { object[key] = .string(value.string) } }
    mutating func set(_ key: String, _ value: WeekKey?) { if let value { object[key] = .string(value.string) } }
    mutating func set(_ key: String, _ value: [String: String]) {
        guard !value.isEmpty else { return }
        object[key] = .object(value.mapValues { JSONValue.string($0) })
    }
    mutating func set(_ key: String, objects: [[String: JSONValue]]) { object[key] = .array(objects.map { .object($0) }) }
}

/// A record stored as JSON in an `AppSetting` (TASKS-v10 §1.1). Conforming types read their fields in
/// `init(fields:)` (tolerant) and write them in `fields`; unknown fields go to `unknown` and are written
/// back unchanged, `v` keeps the highest version that wrote the record.
public protocol SettingRecord: Codable, Sendable {
    /// "goal.result." – the key prefix of this kind of record.
    static var prefix: String { get }
    /// The JSON version this build writes.
    static var version: Int { get }
    /// The fields this build reads (with `id`, `modifiedAt`, `deletedAt`); everything else is kept in `unknown`.
    static var fieldNames: Set<String> { get }
    var id: String { get set }
    /// The `AppSetting` key: `prefix + id`, for dated facts `prefix + day + "." + id`.
    var settingKey: String { get }
    var modifiedAt: Date { get set }
    /// In "Zuletzt gelöscht" since then.
    var deletedAt: Date? { get set }
    /// Fields this build doesn't know (from a newer build), written back unchanged.
    var unknown: [String: JSONValue] { get set }
    /// Reads a record from its JSON object; missing or unreadable fields get defaults.
    init(fields: [String: JSONValue])
    /// The known fields as JSON (without `v`).
    var fields: [String: JSONValue] { get }
    /// After reading from a setting: fills what only the key says (the id, the day of a dated fact).
    mutating func adopt(settingKey: String)
}

extension SettingRecord {
    public static var version: Int { 1 }
    public var settingKey: String { Self.prefix + id }
    public var isInTrash: Bool { deletedAt != nil }

    public mutating func adopt(settingKey: String) {
        if id.isEmpty, settingKey.hasPrefix(Self.prefix) {
            id = String(settingKey.dropFirst(Self.prefix.count).split(separator: ".").last ?? "")
        }
    }

    /// The fields this build doesn't read – with `v` only when a newer build wrote it (it is kept then).
    public static func unknownFields(in object: [String: JSONValue]) -> [String: JSONValue] {
        object.filter { key, value in
            if key == "v" { return Int(value.numberValue ?? 0) > version }
            return !fieldNames.contains(key)
        }
    }

    /// The whole JSON object: unknown fields, the known ones on top, `v` = the highest version.
    public var json: [String: JSONValue] {
        var object = unknown
        for (key, value) in fields { object[key] = value }
        let stored = Int(unknown["v"]?.numberValue ?? 0)
        object["v"] = .number(Double(max(stored, Self.version)))
        return object
    }

    /// The setting's value.
    public var settingValue: String { JSONText.string(json) }

    /// The setting's value, keeping unknown fields of the stored version (`previous`) that this value
    /// doesn't carry – for a record built anew instead of read and changed.
    public func settingValue(preserving previous: String?) -> String {
        guard let previous, let object = JSONText.object(previous) else { return settingValue }
        var copy = self
        for (key, value) in Self.unknownFields(in: object) where copy.unknown[key] == nil { copy.unknown[key] = value }
        return copy.settingValue
    }

    /// A record from a setting's value; nil when the value isn't a JSON object.
    public init?(settingValue: String, key: String? = nil) {
        guard let object = JSONText.object(settingValue) else { return nil }
        self.init(fields: object)
        if let key { adopt(settingKey: key) }
    }

    /// For `init(from:)`: the JSON object, read tolerantly.
    public init(settingFrom decoder: Decoder) throws {
        let object = try [String: JSONValue](from: decoder)
        self.init(fields: object)
    }

    /// For `encode(to:)`.
    public func encodeSetting(to encoder: Encoder) throws {
        try json.encode(to: encoder)
    }

    /// A copy in "Zuletzt gelöscht".
    public func trashed(now: Date = Date()) -> Self {
        var copy = self
        copy.deletedAt = now
        copy.modifiedAt = now
        return copy
    }

    /// A copy back from the trash.
    public func restored(now: Date = Date()) -> Self {
        var copy = self
        copy.deletedAt = nil
        copy.modifiedAt = now
        return copy
    }

    /// A copy marked as changed now.
    public func touched(now: Date = Date()) -> Self {
        var copy = self
        copy.modifiedAt = now
        return copy
    }

    /// A new id for a record ("6F1A2C9E-…").
    public static func newID() -> String { UUID().uuidString }
}

/// A child record that belongs to another one (a result's entries, a book's progress): deleting the
/// parent sends its children to the trash with it, restoring brings them back ("Kaskade", §1.1.3).
public protocol SettingChild {
    var parentID: String { get }
}

/// One `AppSetting` as plain values (key, value, the setting's own `modifiedAt`).
public struct StoredSetting: Equatable, Sendable {
    public var key: String
    public var value: String
    public var modifiedAt: Date

    public init(key: String, value: String, modifiedAt: Date = Date(timeIntervalSince1970: 0)) {
        self.key = key
        self.value = value
        self.modifiedAt = modifiedAt
    }
}

/// The key prefixes of TASKS-v10 §1.1 and what the keys say.
public enum SettingKeys {
    /// `goal.result.<uuid>` – a result of an annual goal.
    public static let goalResult = "goal.result."
    /// `goal.entry.<day>.<uuid>` – a dated result entry (tick, +1, value).
    public static let goalEntry = "goal.entry."
    /// `goal.segment.<uuid>` – a segment of the goal year.
    public static let goalSegment = "goal.segment."
    /// `list.item.<uuid>` – a list entry (a book …).
    public static let listItem = "list.item."
    /// `list.progress.<day>.<uuid>` – a page reached on a day.
    public static let listProgress = "list.progress."
    /// `link.rule.<id>` – a mapping of another app's group to a category.
    public static let linkRule = "link.rule."
    /// `x.<source>.<day>` – another app's day file in the synced inbox.
    public static let inbox = "x."
    /// `x.sources` – the sources seen (their `source.json`).
    public static let inboxSources = "x.sources"
    /// `score.<week>` – the stored category week scores ("1.1=8.2;1.2=6.5").
    public static let categoryScores = "score."

    // v11 – device and request records. None of them is in `all`: never in a backup, `record` rows or the
    // week's prefix queries; `week(of:)` gives nil; older builds never read them.

    /// `rescore.<week>` – a request to the iPhone to score a closed week anew (`RescoreRequest`, P2.1).
    public static let rescoreRequest = "rescore."
    /// `sync.build.<install id>` – the build a device runs (`SyncBuild`, P2.1 (d)). Not `sync.seen.`, the only
    /// device prefix 1.9.0 reads.
    public static let buildPrefix = "sync.build."
    /// `backup.last` – the last full backup made by hand on any device (`BackupStamp`, P3.13).
    public static let backupLast = "backup.last"

    /// The goal year (`GoalPeriod`): start, end, review week, motto – plain text settings (v11 P3.7: backed up
    /// as `record` rows, the import only fills in what the app lacks).
    public static let goalYearKeys: [String] = ["goal.start", "goal.end", "goal.review", "goal.motto"]
    /// The switch "Thalia-Katalog bereitstellen" (v11 P3.7, also a `record` row).
    public static let catalogSwitch = "exchange.catalog"

    /// Every v10 prefix, for prefix queries and the backup (`record` rows).
    public static let all: [String] = [goalResult, goalEntry, goalSegment, listItem, listProgress, linkRule, inbox, categoryScores]

    /// The prefixes of the JSON records (results, entries, segments, list items, progress, rules).
    public static let records: [String] = [goalResult, goalEntry, goalSegment, listItem, listProgress, linkRule]

    /// A key of v10 (one of `all`).
    public static func isV10(_ key: String) -> Bool { all.contains { key.hasPrefix($0) } }

    /// `prefix + day + "." + id` – the key of a dated fact.
    public static func dated(_ prefix: String, day: DayKey, id: String) -> String { "\(prefix)\(day.string).\(id)" }

    /// The day in a dated key: `goal.entry.<day>.…`, `list.progress.<day>.…`, `x.<source>.<day>`; nil otherwise.
    public static func day(of key: String) -> DayKey? {
        for prefix in [goalEntry, listProgress] where key.hasPrefix(prefix) {
            return key.dropFirst(prefix.count).split(separator: ".").first.flatMap { DayKey(String($0)) }
        }
        if key.hasPrefix(inbox), key != inboxSources {
            return key.split(separator: ".").last.flatMap { DayKey(String($0)) }
        }
        return nil
    }

    /// The week a change of this setting can change the score of (`touchedWeeks()`, Grundregel 3): a
    /// dated fact's week, `score.<week>`, `archive.<week>`; nil for everything else.
    public static func week(of key: String) -> WeekKey? {
        if let day = day(of: key) { return day.week }
        if key.hasPrefix(categoryScores) { return WeekKey(String(key.dropFirst(categoryScores.count))) }
        return ArchiveWeek.week(settingKey: key)
    }
}

/// Helpers for the store (Shared): the newest copy per key, records decoded, values to write.
public enum SettingRecords {
    /// The newest copy of every key (sync duplicates: the later `modifiedAt` inside the JSON, then the setting's).
    public static func newest(_ settings: [StoredSetting]) -> [String: StoredSetting] {
        var result: [String: StoredSetting] = [:]
        for setting in settings {
            guard let current = result[setting.key] else {
                result[setting.key] = setting
                continue
            }
            if isNewer(setting, than: current) { result[setting.key] = setting }
        }
        return result
    }

    static func isNewer(_ a: StoredSetting, than b: StoredSetting) -> Bool {
        let stampA = stamp(of: a.value)
        let stampB = stamp(of: b.value)
        if let stampA, let stampB, stampA != stampB { return stampA > stampB }
        return a.modifiedAt > b.modifiedAt
    }

    /// The records of `type` among `settings` (its prefix only, newest copy per key), sorted by key;
    /// those in the trash only with `includeDeleted`. Dated facts (`goal.entry.`, `list.progress.`, v11 P3.5):
    /// one record per id – moving one to another day is a new key, and an older backup can bring the old key
    /// back; the newest `modifiedAt` counts (a tie: the greater key).
    public static func decode<T: SettingRecord>(_ type: T.Type, from settings: [StoredSetting], includeDeleted: Bool = false) -> [T] {
        var records: [(key: String, record: T)] = newest(settings.filter { $0.key.hasPrefix(T.prefix) }).values
            .sorted { $0.key < $1.key }
            .compactMap { setting in T(settingValue: setting.value, key: setting.key).map { (key: setting.key, record: $0) } }
        if T.prefix == SettingKeys.goalEntry || T.prefix == SettingKeys.listProgress {
            var best: [String: (key: String, record: T)] = [:]
            for entry in records where !entry.record.id.isEmpty {
                if let current = best[entry.record.id],
                   (current.record.modifiedAt, current.key) >= (entry.record.modifiedAt, entry.key) { continue }
                best[entry.record.id] = entry
            }
            records = records.filter { $0.record.id.isEmpty || best[$0.record.id]?.key == $0.key }
        }
        return records.map(\.record).filter { includeDeleted || $0.deletedAt == nil }
    }

    /// When a value says it was written: its `modifiedAt` (records) or `generatedAt` (day files).
    public static func stamp(of value: String) -> Date? {
        guard let object = JSONText.object(value) else { return nil }
        let fields = RecordFields(object)
        return fields.date("modifiedAt") ?? fields.date("generatedAt")
    }

    /// The children of `parentID` (entries of a result, progress of a book).
    public static func children<T: SettingRecord & SettingChild>(of parentID: String, in records: [T]) -> [T] {
        records.filter { $0.parentID == parentID }
    }

    /// The children to send to the trash with their parent (those not already there), all with the
    /// parent's `deletedAt` – so restoring the parent brings exactly them back (`restoredChildren`).
    public static func trashedChildren<T: SettingRecord & SettingChild>(of parentID: String, in records: [T], now: Date) -> [T] {
        children(of: parentID, in: records).filter { $0.deletedAt == nil }.map { $0.trashed(now: now) }
    }

    /// The children that went to the trash together with the parent (same `deletedAt`), restored.
    public static func restoredChildren<T: SettingRecord & SettingChild>(of parentID: String, deletedAt: Date, in records: [T],
                                                                         now: Date = Date()) -> [T] {
        children(of: parentID, in: records).filter { child in
            guard let deleted = child.deletedAt else { return false }
            return abs(deleted.timeIntervalSince(deletedAt)) < 0.001
        }.map { $0.restored(now: now) }
    }
}

/// One `record` row of the CSV backup (TASKS-v10 §1.1.4): `id` = the setting's key, `note` = its value.
public struct SettingRow: Equatable, Sendable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    /// When the value was written (`modifiedAt` / `generatedAt`), nil for plain text (`score.`).
    public var stamp: Date? { SettingRecords.stamp(of: value) }

    /// `incoming` replaces `existing` on import: newer `modifiedAt` wins; without stamps the file wins
    /// when it differs (like every other row). `x.sources` has no stamp: it changes only when the file
    /// knows a source (or a newer `source.json`) the app doesn't – see `resolved`.
    public static func wins(_ incoming: SettingRow, over existing: SettingRow?) -> Bool {
        guard let existing else { return true }
        guard incoming.value != existing.value else { return false }
        if incoming.key == SettingKeys.inboxSources { return resolved(incoming, over: existing).value != existing.value }
        if let a = incoming.stamp, let b = existing.stamp { return a > b }
        return true
    }

    /// What the import stores for a row: the winner of `wins` – for `x.sources` both lists merged
    /// (`ExchangeSourceList.merged`), so restoring an older backup never drops a source connected since.
    public static func resolved(_ incoming: SettingRow, over existing: SettingRow?) -> SettingRow {
        guard let existing else { return incoming }
        if incoming.key == SettingKeys.inboxSources {
            let current = ExchangeSourceList(value: existing.value)
            let merged = current.merging(ExchangeSourceList(value: incoming.value))
            return merged == current ? existing : SettingRow(key: incoming.key, value: merged.value)
        }
        return wins(incoming, over: existing) ? incoming : existing
    }
}

/// Small JSON helpers for the v11 records (`RescoreRequest`, `SyncBuild`, `BackupStamp`): tolerant reading,
/// keys sorted when written, dates as ISO 8601 with milliseconds (`JSONText.timestamp`).
enum SettingJSON {
    static func string<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    static func decode<T: Decodable>(_ value: String) -> T? {
        guard JSONText.object(value) != nil, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func text<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> String? {
        ((try? c.decodeIfPresent(JSONValue.self, forKey: key)) ?? nil)?.stringValue
    }

    static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Int? {
        guard let number = ((try? c.decodeIfPresent(JSONValue.self, forKey: key)) ?? nil)?.numberValue,
              number.isFinite, abs(number) < 1e15 else { return nil }
        return Int(number.rounded())
    }

    static func bool<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Bool? {
        ((try? c.decodeIfPresent(JSONValue.self, forKey: key)) ?? nil)?.boolValue
    }

    static func date<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ key: K) -> Date? {
        guard let value = (try? c.decodeIfPresent(JSONValue.self, forKey: key)) ?? nil else { return nil }
        if case .number(let seconds) = value, seconds.isFinite { return Date(timeIntervalSince1970: seconds) }
        return value.stringValue.flatMap(ExchangeDate.parse)
    }
}

/// `rescore.<week>` (v11 P2.1): Mac, watch or iPad ask the iPhone to score a closed week anew with the
/// full data (Health values only exist there). `{"at":"…","by":"<install id>","force":false,"v":1}`.
/// `force`: also a frozen week (closing on another device, "Am iPhone neu berechnen"). The iPhone deletes
/// the request once it is older than 10 minutes. Not in `SettingKeys.all`.
public struct RescoreRequest: Codable, Equatable, Sendable {
    public var v: Int
    /// The install id of the device that asked.
    public var by: String
    /// When it asked.
    public var at: Date
    public var force: Bool

    /// A request is kept this long (seconds): its week's `closedAt` or marks may arrive after it.
    public static let lifetime: TimeInterval = 10 * 60

    public init(v: Int = 1, by: String, at: Date = Date(), force: Bool = false) {
        self.v = v
        self.by = by
        self.at = at
        self.force = force
    }

    enum CodingKeys: String, CodingKey { case v, by, at, force }

    /// Tolerant: missing or odd fields read as defaults (an unreadable `at` as long ago).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = SettingJSON.int(c, .v) ?? 1
        by = SettingJSON.text(c, .by) ?? ""
        at = SettingJSON.date(c, .at) ?? Date(timeIntervalSince1970: 0)
        force = SettingJSON.bool(c, .force) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)
        try c.encode(by, forKey: .by)
        try c.encode(JSONText.timestamp(at), forKey: .at)
        try c.encode(force, forKey: .force)
    }

    /// "rescore.2026-W47"
    public static func key(_ week: WeekKey) -> String { SettingKeys.rescoreRequest + week.string }

    /// The week in "rescore.2026-W47"; nil for other keys.
    public static func week(settingKey key: String) -> WeekKey? {
        guard key.hasPrefix(SettingKeys.rescoreRequest) else { return nil }
        return WeekKey(String(key.dropFirst(SettingKeys.rescoreRequest.count)))
    }

    /// The setting's value (JSON, keys sorted).
    public var value: String { SettingJSON.string(self) }

    /// The request in a setting's value; nil when it isn't one.
    public init?(value: String) {
        guard let decoded: RescoreRequest = SettingJSON.decode(value) else { return nil }
        self = decoded
    }

    /// Older than `lifetime` at `now`.
    public func isExpired(now: Date = Date()) -> Bool { now.timeIntervalSince(at) > RescoreRequest.lifetime }

    /// Of several copies of one week's request: `force` if any asked for it, the latest `at`, the device of
    /// the latest – nil without copies.
    public static func merged(_ requests: [RescoreRequest]) -> RescoreRequest? {
        guard let latest = requests.max(by: { $0.at < $1.at }) else { return nil }
        var result = latest
        result.force = requests.contains { $0.force }
        return result
    }
}

/// `backup.last` (v11 P3.13, KR2-2): the last full backup made by hand – on any device, synced, so a Mac
/// doesn't remind when the iPhone was backed up yesterday. `{"at":"…","device":"iPhone","v":1}` – the kind of
/// device, never its name. Not in `SettingKeys.all`: never in the backup itself.
public struct BackupStamp: Codable, Equatable, Sendable {
    public var v: Int
    public var at: Date
    /// "iPhone", "iPad", "Mac" (`SyncDeviceKind`).
    public var device: String

    public init(v: Int = 1, at: Date = Date(), device: String) {
        self.v = v
        self.at = at
        self.device = device
    }

    enum CodingKeys: String, CodingKey { case v, at, device }

    /// Tolerant: missing or odd fields read as defaults (an unreadable `at` as long ago).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = SettingJSON.int(c, .v) ?? 1
        at = SettingJSON.date(c, .at) ?? Date(timeIntervalSince1970: 0)
        device = SettingJSON.text(c, .device) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(v, forKey: .v)
        try c.encode(JSONText.timestamp(at), forKey: .at)
        try c.encode(device, forKey: .device)
    }

    /// The setting's value (JSON, keys sorted).
    public var value: String { SettingJSON.string(self) }

    /// The stamp in a setting's value; nil when it isn't one.
    public init?(value: String) {
        guard let decoded: BackupStamp = SettingJSON.decode(value) else { return nil }
        self = decoded
    }

    /// Of several copies (two devices backed up before they synced): the latest.
    public static func latest(_ values: [String]) -> BackupStamp? {
        values.compactMap(BackupStamp.init(value:)).max { $0.at < $1.at }
    }

    /// Whole days from the backup to `now` in `calendar` ("vor 3 Tagen"); 0 the same day.
    public func days(until now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: at)
        let end = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}
