import Foundation
import BinisoftKitCore

// Connected apps in Thalia (TASKS-v10 §1.5): what the inbox `x.<source>.<day>` means for a week.
// Grundregel 1 – computed, never written: Thalia never creates own marks, work blocks or entries for
// facts from other apps. `ExchangeDerivation.week` turns the inbox into derived values, work blocks and
// ticks; WeekContext mixes them in like the Health values. Own records always win: an own mark (also a
// cleared one), an own work block with the same `importID`, an own entry for code + day.
// Facts with `origin: health` are never used (guideline 5.1.3(ii)).

/// A measure's (or result's) connected-app source: `app:<source>:<kind|metric>[=<ref>]`
/// ("app:george:workout=tpl-1", "app:theo:task", "app:nina:kcal", "app:finn:spending").
public struct AppSource: Equatable, Hashable, Sendable {
    public static let prefix = "app:"

    /// "george"
    public var source: String
    /// "workout", "task", "habit", "ph", "spending" or a metric ("kcal", "net_worth").
    public var kind: String
    /// A stable id in the source ("tpl-1"): only facts with this `ref` count.
    public var ref: String?

    public init(source: String, kind: String, ref: String? = nil) {
        self.source = BinisoftExchange.sourceID(source)
        self.kind = AppSource.normalizedKind(kind)
        let trimmed = ref?.trimmingCharacters(in: .whitespaces) ?? ""
        self.ref = trimmed.isEmpty ? nil : trimmed
    }

    /// Reads "app:george:workout=tpl-1"; nil when it isn't one.
    public init?(raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard text.lowercased().hasPrefix(AppSource.prefix) else { return nil }
        let body = text.dropFirst(AppSource.prefix.count)
        var main = String(body)
        var ref: String?
        if let equals = body.firstIndex(of: "=") {
            main = String(body[..<equals])
            ref = String(body[body.index(after: equals)...])
        }
        let parts = main.split(separator: ":", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        let source = BinisoftExchange.sourceID(parts[0])
        let kind = AppSource.normalizedKind(parts[1])
        guard !source.isEmpty, source == parts[0].lowercased(), !kind.isEmpty, !kind.contains(" ") else { return nil }
        self.init(source: source, kind: kind, ref: ref)
    }

    /// "task.done" → "task", "Workout" → "workout".
    static func normalizedKind(_ kind: String) -> String {
        let lower = kind.trimmingCharacters(in: .whitespaces).lowercased()
        return lower.hasSuffix(".done") ? String(lower.dropLast(5)) : lower
    }

    /// "app:george:workout=tpl-1"
    public var raw: String { "\(AppSource.prefix)\(source):\(kind)" + (ref.map { "=\($0)" } ?? "") }

    /// The fact kind counted per day ("workout" → workout.done), nil for summed kinds and metrics.
    public var countedKind: ExchangeKind? {
        switch kind {
        case "task": return .taskDone
        case "workout": return .workoutDone
        case "habit": return .habitDone
        default: return nil
        }
    }

    /// The fact kind whose values add up ("ph", "spending"), nil otherwise.
    public var summedKind: ExchangeKind? {
        switch kind {
        case "ph": return .powerHours
        case "spending": return .spending
        default: return nil
        }
    }

    /// The metric of kind `value` ("kcal"), nil otherwise.
    public var metric: ExchangeMetric? { ExchangeMetric.named(kind) }

    /// v1 knows what to do with it.
    public var isKnown: Bool { countedKind != nil || summedKind != nil || metric != nil }

    /// "George"
    public var sourceName: String { ExchangeSourceInfo.displayName(source) }

    /// "Workouts", "Aufgaben", "Power-Hours", "Ausgaben", "Kalorien" …
    public var kindTitle: String {
        switch kind {
        case "task": return "Aufgaben"
        case "workout": return "Workouts"
        case "habit": return "Gewohnheiten"
        case "ph": return "Power-Hours"
        case "spending": return "Ausgaben"
        default: return metric?.title ?? kind
        }
    }

    /// "George · Workouts · tpl-1"
    public var label: String { ([sourceName, kindTitle] + (ref.map { [$0] } ?? [])).joined(separator: " · ") }

    /// "George · Workouts · Push" – the ref's title from the source's `source.json` (else its id).
    public func label(refs: [ExchangeRef]) -> String {
        guard let ref else { return label }
        let title = refs.first { $0.id == ref }?.title ?? ref
        return [sourceName, kindTitle, title].joined(separator: " · ")
    }

    /// The kinds a measure can read from a connected app (Messwert-Editor "Verbundene App → Art", §1.5.4):
    /// counted, summed, then the metrics of `ExchangeMetric.table`.
    public static let kindChoices: [String] = ["workout", "task", "habit", "ph", "spending"] + ExchangeMetric.table.map(\.id)

    /// The kinds that feed a result (v11 §1.5.4, Art "Zielwert", latest value) and not a measure: net worth,
    /// savings rate, account balances – a measure in € counts as spending (`isExpense`). Thalia's own list
    /// (not in the copied `ExchangeFormat.swift`).
    public static let resultOnlyKinds: Set<String> = ["net_worth", "savings_rate", "account_balance"]

    /// v11 §1.5.4: the source needs a `ref` – no "alle" in the editors (the latest balance of any account means
    /// nothing): `account_balance`.
    public var requiresRef: Bool { kind == "account_balance" }

    /// The refs of `source.json` that fit this kind ("Eintrag aus refs"): workouts for `workout`, groups
    /// for tasks, power-hours and spending, habits for `habit`, accounts and account groups for
    /// `account_balance` (v11). A ref without a kind fits every kind. Another metric ("kcal", "net_worth")
    /// has none: a value fact's `ref` is the metric itself, so another metric's ref would match nothing and
    /// "alle" is the only sensible choice.
    public func refChoices(_ refs: [ExchangeRef]) -> [ExchangeRef] {
        let fitting: Set<String>
        switch kind {
        case "workout": fitting = ["workout", "template"]
        case "task", "ph", "spending": fitting = ["group"]
        case "habit": fitting = ["habit"]
        case "account_balance": fitting = ["account"]
        default: return []
        }
        return refs.filter { ref in
            guard let refKind = ref.kind?.trimmingCharacters(in: .whitespaces).lowercased(), !refKind.isEmpty else { return true }
            return fitting.contains(refKind)
        }
    }

    /// The unit a measure with this source gets: "Stück" for counts, "PH", "€", the metric's unit.
    public var suggestedUnit: String {
        if countedKind != nil { return "Stück" }
        if summedKind == .powerHours { return "PH" }
        if summedKind == .spending { return "€" }
        return metric?.unit ?? ""
    }

    /// The day's value from one source's facts of one day (app origin only, known kinds): the number of
    /// counted facts, the sum of power-hours or spending, the metric's sum or last value. A task without
    /// `ref` counts when its category (`categoryOf`) is `categoryKey` (any task when `categoryKey` is
    /// empty). nil when no fact matches.
    public func dayValue(_ facts: [ExchangeFact], categoryKey: String = "", categoryOf: (ExchangeFact) -> String? = { _ in nil })
        -> (value: Double, facts: [ExchangeFact])? {
        let own = facts.filter { $0.isFromApp && (ref == nil || $0.ref == ref) }
        if let counted = countedKind {
            var matching = own.filter { $0.knownKind == counted }
            if counted == .taskDone, ref == nil, !categoryKey.isEmpty {
                matching = matching.filter { categoryOf($0) == categoryKey }
            }
            return matching.isEmpty ? nil : (Double(matching.count), matching)
        }
        if let summed = summedKind {
            let matching = own.filter { $0.knownKind == summed && $0.value != nil }
            guard !matching.isEmpty else { return nil }
            let values = matching.map { fact -> Double in
                summed == .powerHours ? (fact.powerHoursValue ?? 0) : (fact.value ?? 0)
            }
            return (values.reduce(0, +), matching)
        }
        if let metric {
            let matching = AppSource.ordered(own.filter { $0.knownKind == .value && $0.knownMetric == metric && $0.value != nil })
            guard !matching.isEmpty else { return nil }
            let values = matching.compactMap(\.value)
            let value = metric.agg == .sum ? values.reduce(0, +) : (values.last ?? 0)
            return (value, matching)
        }
        return nil
    }

    /// Facts by their time (`at`), those without one in file order before the others.
    static func ordered(_ facts: [ExchangeFact]) -> [ExchangeFact] {
        facts.enumerated().sorted { a, b in
            let ta = a.element.date?.timeIntervalSince1970 ?? -Double.infinity
            let tb = b.element.date?.timeIntervalSince1970 ?? -Double.infinity
            return ta != tb ? ta < tb : a.offset < b.offset
        }.map(\.element)
    }
}

extension ExchangeFact {
    /// A `ph` fact's power-hours (v11 P1.4): `value` in PH, or minutes ÷ 50 when `unit` is "min" ("55 min" =
    /// 1,1 PH); nil without a value. Thalia's own (not in the copied `ExchangeFormat.swift`).
    public var powerHoursValue: Double? {
        guard let value else { return nil }
        return Units.normalized(unit ?? "") == "min" ? value / Double(PowerHour.minutes) : value
    }

    /// The fact was written in minutes ("min").
    var isInMinutes: Bool { Units.normalized(unit ?? "") == "min" }
}

extension MeasureRecord {
    /// From a connected app (`app:…`, v10).
    public var isApp: Bool { source.appSource != nil }
    /// From the reading list (`list:…`, v10).
    public var isList: Bool { source.listKind != nil }
}

extension MarkRecord {
    /// The marks an export carries (backup, week snapshot, a week for ChatGPT): every mark with a value,
    /// and one without (cleared) when it holds a note or when it is what keeps a connected app's ✓ away –
    /// its item is linked to a measure with an `app:` source (or to an `app:` text directly). Before v10 a
    /// cleared mark meant the same as none; now "Eigenes gewinnt, auch geleert" (Grundregel 1), so a
    /// restore must bring the clear back. Other cleared marks stay out (the export stays as it was).
    public static func exported(_ marks: [MarkRecord], items: [ItemRecord], measures: [MeasureRecord]) -> [MarkRecord] {
        let appMeasures = Set(measures.filter(\.isApp).map { "\($0.week.string)|\($0.code)" })
        var linked: Set<String> = []
        for item in items where !item.measure.isEmpty {
            if MeasureSource(raw: item.measure).appSource != nil || appMeasures.contains("\(item.week.string)|\(item.measure)") {
                linked.insert(ItemRecord.key(week: item.week, code: item.code))
            }
        }
        return marks.filter { mark in
            mark.mark != nil || !mark.note.isEmpty || linked.contains(ItemRecord.key(week: mark.week, code: mark.itemCode))
        }
    }
}

/// A mapping in Thalia: a group (`ref`) of another app → a category (§1.5.3). The id follows from
/// source and ref, so two devices mapping the same group write the same key.
public struct LinkRule: SettingRecord, Equatable {
    public static let prefix = SettingKeys.linkRule
    public static let fieldNames: Set<String> = ["id", "source", "ref", "refTitle", "category", "categoryTitle", "modifiedAt", "deletedAt"]

    public var id: String
    /// "theo"
    public var source: String
    /// "grp-91AB"
    public var ref: String
    public var refTitle: String
    /// "3.2"; empty = mapped to nothing (ignore).
    public var categoryKey: String
    /// The category's title when it was chosen ("Zuordnung prüfen" when it changed).
    public var categoryTitle: String
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var unknown: [String: JSONValue]

    public init(source: String, ref: String, refTitle: String = "", categoryKey: String, categoryTitle: String = "",
                modifiedAt: Date = Date(), deletedAt: Date? = nil) {
        id = LinkRule.id(source: source, ref: ref)
        self.source = BinisoftExchange.sourceID(source)
        self.ref = ref
        self.refTitle = refTitle
        self.categoryKey = categoryKey
        self.categoryTitle = categoryTitle
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
        unknown = [:]
    }

    /// "theo-<fnv1a of the ref>"
    public static func id(source: String, ref: String) -> String {
        "\(BinisoftExchange.sourceID(source))-\(ExchangeHash.hex(ref))"
    }

    public init(fields object: [String: JSONValue]) {
        let f = RecordFields(object)
        id = f.text("id")
        source = BinisoftExchange.sourceID(f.text("source"))
        ref = f.text("ref")
        refTitle = f.text("refTitle")
        categoryKey = f.text("category")
        categoryTitle = f.text("categoryTitle")
        modifiedAt = f.date("modifiedAt") ?? Date(timeIntervalSince1970: 0)
        deletedAt = f.date("deletedAt")
        unknown = LinkRule.unknownFields(in: object)
        if id.isEmpty, !source.isEmpty { id = LinkRule.id(source: source, ref: ref) }
    }

    public var fields: [String: JSONValue] {
        var w = FieldWriter()
        w.set("id", id)
        w.set("source", source)
        w.set("ref", ref)
        w.set("refTitle", refTitle)
        w.set("category", categoryKey)
        w.set("categoryTitle", categoryTitle)
        w.set("modifiedAt", modifiedAt)
        w.set("deletedAt", deletedAt)
        return w.object
    }

    public init(from decoder: Decoder) throws { try self.init(settingFrom: decoder) }
    public func encode(to encoder: Encoder) throws { try encodeSetting(to: encoder) }

    /// The category Thalia's mapping gives `ref` of `source` (the newest rule not in the trash).
    public static func category(source: String, ref: String, in rules: [LinkRule]) -> String? {
        let id = BinisoftExchange.sourceID(source)
        return rules.filter { $0.deletedAt == nil && $0.source == id && $0.ref == ref }
            .max { $0.modifiedAt < $1.modifiedAt }
            .flatMap { $0.categoryKey.isEmpty ? nil : $0.categoryKey }
    }
}

/// Thalia's synced inbox: one setting `x.<source>.<day>` per source and day holding the day file as
/// read (§1.5.1), `x.sources` with the sources' `source.json`. Thalia never deletes it – it is the only
/// long-term copy, so it goes into the backup.
public enum ExchangeInbox {
    public static let prefix = SettingKeys.inbox
    public static let sourcesKey = SettingKeys.inboxSources

    /// "x.theo.2026-11-22"
    public static func settingKey(source: String, day: DayKey) -> String {
        "\(prefix)\(BinisoftExchange.sourceID(source)).\(day.string)"
    }

    /// "x.theo.2026-11-22" → ("theo", 2026-11-22); nil for other keys (also `x.sources`).
    public static func parse(settingKey key: String) -> (source: String, day: DayKey)? {
        guard key.hasPrefix(prefix), key != sourcesKey else { return nil }
        let parts = key.dropFirst(prefix.count).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty, let day = DayKey(String(parts[1])) else { return nil }
        return (String(parts[0]), day)
    }

    /// The keys of `sources` on `days` (for the IN predicate of a week: 7 × sources).
    public static func keys(sources: [String], days: [DayKey]) -> [String] {
        sources.flatMap { source in days.map { settingKey(source: source, day: $0) } }
    }

    public static func keys(sources: [String], week: WeekKey) -> [String] { keys(sources: sources, days: week.days) }

    /// The setting's value for a day file (canonical JSON) – v11 P1.1: a fact that can't be encoded is left
    /// out, never "{}" over a stored copy; nil only when nothing can be written (callers skip it then).
    public static func value(_ file: ExchangeDayFile) -> String? { encodedValue(file) }

    /// The value where a text is required (a `SettingRow`, `StoredSetting`, `file(_:)`): callers of 1.9.0 keep
    /// compiling (§0.9 – removed once no caller uses it). As `value(_:) -> String?`, "" in the case that can't
    /// happen (nothing encodable) – unreadable like any broken copy, so it never counts.
    @_disfavoredOverload
    public static func value(_ file: ExchangeDayFile) -> String { encodedValue(file) ?? "" }

    static func encodedValue(_ file: ExchangeDayFile) -> String? {
        if let data = try? file.encoded(), let text = String(data: data, encoding: .utf8) { return text }
        var kept = file
        kept.facts = file.facts.filter { (try? BinisoftExchange.encode($0)) != nil }
        guard let data = try? kept.encoded(), let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }

    /// The day file in a setting's value; nil when it can't be read.
    public static func file(_ value: String) -> ExchangeDayFile? {
        guard let data = value.data(using: .utf8), case .success(let read) = ExchangeReader.dayFile(data) else { return nil }
        return read.file
    }

    /// A day file read from a folder goes into the inbox when nothing is stored for its source and day,
    /// or it was generated later than the stored one (the same content from another device changes nothing).
    /// A differing file without a readable `generatedAt` (missing, or without a time zone) wins too: it
    /// was just read from the source's folder, so later changes of such a writer still arrive. Two
    /// different files with the same `generatedAt` (a source that broke the rule) are decided by
    /// `isPreferred`, the same pick on every device.
    public static func shouldStore(_ incoming: ExchangeDayFile, over stored: ExchangeDayFile?) -> Bool {
        guard let stored else { return true }
        guard incoming != stored else { return false }
        guard let a = incoming.generatedDate, let b = stored.generatedDate else { return true }
        return a != b ? a > b : isPreferred(incoming, over: stored)
    }

    /// Of two copies of one source and day, the one that counts – whatever order they were fetched in:
    /// the later `generatedAt` (an unreadable one counts as the oldest), then, for the same time, the
    /// greater canonical text (deterministic, so every device picks the same copy).
    public static func isPreferred(_ a: ExchangeDayFile, over b: ExchangeDayFile) -> Bool {
        guard a != b else { return false }
        let dateA = a.generatedDate ?? .distantPast
        let dateB = b.generatedDate ?? .distantPast
        if dateA != dateB { return dateA > dateB }
        return (encodedValue(a) ?? "") > (encodedValue(b) ?? "")
    }

    /// The day files among `settings` (`x.<source>.<day>` only, the key must match the file), one copy
    /// per key (`isPreferred` – the result doesn't depend on the order of `settings`).
    public static func files(from settings: [StoredSetting]) -> [ExchangeDayFile] {
        var result: [String: ExchangeDayFile] = [:]
        for setting in settings {
            guard let (source, day) = parse(settingKey: setting.key), let file = file(setting.value),
                  BinisoftExchange.sourceID(file.source) == source, file.day == day.string else { continue }
            if let current = result[setting.key], !isPreferred(file, over: current) { continue }
            result[setting.key] = file
        }
        return result.keys.sorted().compactMap { result[$0] }
    }

    /// The file as it may go into the synced inbox (and the backup): only facts recorded in the source
    /// app itself (`origin: app`). Facts from Apple Health, without an origin or with another label never
    /// leave the device (guideline 5.1.3(ii)) – Thalia doesn't use them anyway (`ExchangeFact.isFromApp`).
    public static func syncable(_ file: ExchangeDayFile) -> ExchangeDayFile {
        var copy = file
        copy.facts = file.facts.filter(\.isFromApp)
        return copy
    }

    /// The value of `x.<source>.<day>` from a backup (`record` row) as it may be stored: a readable day
    /// file of that source and day, cut down to `syncable` facts (re-encoded only when something went);
    /// nil when it isn't one (the row is left out). `x.sources` and other keys come back unchanged.
    public static func syncableValue(_ value: String, key: String) -> String? {
        guard let (source, day) = parse(settingKey: key) else { return value }
        guard let stored = file(value), BinisoftExchange.sourceID(stored.source) == source, stored.day == day.string else { return nil }
        let kept = syncable(stored)
        return kept == stored ? value : encodedValue(kept)
    }
}

/// `x.sources`: every source seen, with its latest `source.json`.
public struct ExchangeSourceList: Equatable, Sendable {
    public var sources: [ExchangeSourceInfo]

    public init(sources: [ExchangeSourceInfo] = []) {
        self.sources = sources.sorted { $0.source < $1.source }
    }

    /// Reads the setting's value (unreadable → empty).
    public init(value: String) {
        struct Stored: Decodable {
            var sources: [ExchangeLossy<ExchangeSourceInfo>]
        }
        guard let data = value.data(using: .utf8), let stored = try? JSONDecoder().decode(Stored.self, from: data) else {
            self.init()
            return
        }
        self.init(sources: stored.sources.compactMap(\.value))
    }

    /// The setting's value: {"sources":[…],"v":1}.
    public var value: String {
        struct Stored: Encodable {
            var v: Int
            var sources: [ExchangeSourceInfo]
        }
        guard let data = try? BinisoftExchange.encode(Stored(v: BinisoftExchange.version, sources: sources)),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    /// Every copy of `x.sources` as one list (two devices that saw different apps wrote their own copy
    /// before they synced; a restored backup brings an older one): the union of the sources, the newest
    /// `source.json` of each. The value carries no stamp, so no copy may simply win.
    public static func merged(_ values: [String]) -> ExchangeSourceList {
        var list = ExchangeSourceList()
        for value in values { list = list.merging(ExchangeSourceList(value: value)) }
        return list
    }

    /// With every source of `other` (`merging(_:)` per source).
    public func merging(_ other: ExchangeSourceList) -> ExchangeSourceList {
        var list = self
        for info in other.sources { list = list.merging(info) }
        return list
    }

    /// "theo", "george" …
    public var ids: [String] { sources.map { BinisoftExchange.sourceID($0.source) } }

    /// Source id → the app's name from its `source.json` ("TimeTracker"), for "aus …" and "Was kommt an".
    public var names: [String: String] {
        var result: [String: String] = [:]
        for info in sources { result[BinisoftExchange.sourceID(info.source)] = info.displayName }
        return result
    }

    /// With `info` – replacing the stored one of its source when it is newer. A different `source.json`
    /// whose `generatedAt` can't be read (no time zone) replaces it too, so its refs still change; a
    /// placeholder (no `generatedAt` at all: day files seen before any `source.json`) never does.
    public func merging(_ info: ExchangeSourceInfo) -> ExchangeSourceList {
        let id = BinisoftExchange.sourceID(info.source)
        var list = sources
        if let index = list.firstIndex(where: { BinisoftExchange.sourceID($0.source) == id }) {
            let stored = list[index]
            let newer: Bool
            switch (info.generatedDate, stored.generatedDate) {
            case let (a?, b?): newer = a != b ? a > b : ExchangeSourceList.text(info) > ExchangeSourceList.text(stored)
            case (_?, nil): newer = true
            case (nil, _): newer = info != stored && !info.generatedAt.trimmingCharacters(in: .whitespaces).isEmpty
            }
            guard newer else { return self }
            list[index] = info
        } else {
            list.append(info)
        }
        return ExchangeSourceList(sources: list)
    }

    /// The canonical text of a `source.json` – two different ones with the same `generatedAt` are decided by
    /// it, the same way on every device.
    static func text(_ info: ExchangeSourceInfo) -> String {
        (try? BinisoftExchange.encode(info)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    public func info(_ source: String) -> ExchangeSourceInfo? {
        let id = BinisoftExchange.sourceID(source)
        return sources.first { BinisoftExchange.sourceID($0.source) == id }
    }
}

/// What the inbox does to one week – computed, never stored (Grundregel 1).
public struct ExchangeEffect: Equatable, Sendable {
    /// Day values of measures with an `app:` source (and of items linked to an `app:` text directly),
    /// one per code and day – none where an own entry exists (except spending, which adds up).
    public var entries: [EntryRecord] = []
    /// Spending measures: own entries add to the app's rows instead of replacing them (pass to
    /// `Measures.merged(…, additive:)`).
    public var additiveCodes: Set<String> = []
    /// Derived work blocks with a category, id `x:<source>:<fact id>` (the `importID` of "Übernehmen").
    public var work: [WorkRecord] = []
    /// Power-hours without a category ("ohne Zuordnung") – shown, counted nowhere.
    public var unassignedWork: [WorkRecord] = []
    /// Derived ✓ for items linked to an app measure, only where no own mark exists.
    public var marks: [MarkRecord] = []
    /// `WeekData.markKey` → "⇄ George · Push".
    public var markLabels: [String: String] = [:]
    /// Work id → "Theo" (for "aus Theo").
    public var workSources: [String: String] = [:]
    /// `EntryRecord.key` → "Finn".
    public var entrySources: [String: String] = [:]
    /// Facts this build can't use (unknown kind or metric) – "nicht verwendet".
    public var unused: [ExchangeFact] = []
    /// Facts with `origin: health` (or none) – never used.
    public var ignored = 0

    public init() {}

    public var isEmpty: Bool { entries.isEmpty && work.isEmpty && unassignedWork.isEmpty && marks.isEmpty }

    /// Derived marks by `WeekData.markKey`, to merge into `WeekData.marks` (own marks are never in here).
    public var markValues: [String: Mark] {
        var result: [String: Mark] = [:]
        for mark in marks { if let value = mark.mark { result[WeekData.markKey(mark.itemCode, mark.day)] = value } }
        return result
    }
}

/// The inbox's effect on a week (TASKS-v10 §1.5.3), a pure function.
public enum ExchangeDerivation {
    /// "x:theo:ph-77C0" – the `importID` of a work block taken over from a fact ("Übernehmen").
    public static func importID(source: String, factID: String) -> String {
        "x:\(BinisoftExchange.sourceID(source)):\(factID)"
    }

    /// "x:theo:ph-77C0" → ("theo", "ph-77C0").
    public static func parseImportID(_ id: String) -> (source: String, factID: String)? {
        guard id.hasPrefix("x:") else { return nil }
        let parts = id.dropFirst(2).split(separator: ":", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        return (String(parts[0]), String(parts[1]))
    }

    /// One file per source and day – the newest `generatedAt` (two equal copies count once) – each with a
    /// fact id once (`uniqueFacts`), so the week, results, series and the overview count the same.
    public static func latest(_ files: [ExchangeDayFile]) -> [ExchangeDayFile] {
        var result: [String: ExchangeDayFile] = [:]
        for file in files {
            let key = BinisoftExchange.sourceID(file.source) + "|" + file.day
            if let current = result[key], !ExchangeInbox.isPreferred(file, over: current) { continue }
            result[key] = file
        }
        return result.keys.sorted().compactMap { key in
            result[key].map { file in
                var copy = file
                copy.facts = uniqueFacts(file.facts)
                return copy
            }
        }
    }

    /// A fact id once: the last row with that id counts, at its place in the file.
    public static func uniqueFacts(_ facts: [ExchangeFact]) -> [ExchangeFact] {
        var last: [String: Int] = [:]
        for (index, fact) in facts.enumerated() { last[fact.id] = index }
        return facts.enumerated().filter { last[$0.element.id] == $0.offset }.map(\.element)
    }

    /// The category of a fact: `thalia.category` from the source (when the app has that category, or
    /// nothing to check against) – on the fact itself, else on another fact of the same group (`choices`,
    /// `groupChoices`: a source may name the category once per group) – before Thalia's own mapping
    /// (`LinkRule`); nil = "ohne Zuordnung".
    public static func category(of fact: ExchangeFact, source: String, rules: [LinkRule], known: Set<String> = [],
                                choices: [String: String] = [:]) -> String? {
        if let chosen = fact.thalia?.category, known.isEmpty || known.contains(chosen) { return chosen }
        guard !fact.ref.isEmpty else { return nil }
        if let chosen = choices[fact.ref], known.isEmpty || known.contains(chosen) { return chosen }
        return LinkRule.category(source: source, ref: fact.ref, in: rules)
    }

    /// The categories the sources chose per group (`ref`) in `files`: source → ref → category, the
    /// latest day file (by day, then `generatedAt`) winning. Within one file one fact of a group naming
    /// the category is enough (§1.5.2 names it on the task only); a later file in which none of the
    /// group's facts names one ends the choice – the group was unmapped in the source (every fact of a
    /// mapped group carries `thalia`), so Thalia's own mapping counts again.
    public static func groupChoices(_ files: [ExchangeDayFile]) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        let ordered = latest(files).sorted { ($0.day, $0.generatedDate ?? .distantPast) < ($1.day, $1.generatedDate ?? .distantPast) }
        for file in ordered {
            let source = BinisoftExchange.sourceID(file.source)
            var named: [String: String] = [:]
            var refs: Set<String> = []
            for fact in file.facts where fact.isFromApp && !fact.ref.isEmpty {
                refs.insert(fact.ref)
                if let chosen = fact.thalia?.category { named[fact.ref] = chosen }
            }
            for ref in refs {
                if let chosen = named[ref] {
                    result[source, default: [:]][ref] = chosen
                } else {
                    result[source]?.removeValue(forKey: ref)
                }
            }
        }
        return result
    }

    /// Items whose `link` is an `app:` or `list:` text instead of a measure code get a hidden measure of
    /// that code (title from the source, the item's category), so suggestions and ticks work the same.
    public static func virtualMeasures(items: [ItemRecord], measures: [MeasureRecord]) -> [MeasureRecord] {
        var codes = Set(measures.map { "\($0.week.string)|\($0.code)" })
        var result: [MeasureRecord] = []
        for item in items.sortedForSheet() where !item.measure.isEmpty {
            let source = MeasureSource(raw: item.measure)
            guard source.appSource != nil || source.listKind != nil, codes.insert("\(item.week.string)|\(item.measure)").inserted else { continue }
            let unit: String = source.appSource?.suggestedUnit ?? (source.listKind.map(ListItem.defaultUnit(kind:)) ?? "")
            result.append(MeasureRecord(week: item.week, code: item.measure, categoryKey: item.categoryKey, position: 10_000 + result.count,
                                        title: source.label, unit: unit, source: source, aggregation: .sum, secondary: true))
        }
        return result
    }

    /// The effect of `inbox` on `week`.
    /// - Parameters:
    ///   - inbox: day files (any days and sources; duplicates allowed – the newest per source and day counts).
    ///   - items, measures: the week's plan; measures with an `app:` source get values, items linked to them ticks.
    ///   - rules: Thalia's mappings of other apps' groups to categories.
    ///   - categories: the categories the app has (a `thalia.category` the app doesn't have is ignored;
    ///     also gives the work-day rule as in `WeekData`).
    ///   - ownMarks: every own mark of the week – also cleared ones (`mark == nil`): they win.
    ///   - ownEntries: own entries (and confirmed Health values) of the week: an own entry for code + day wins.
    ///   - ownWorkIDs: `importID`s of own work blocks: a block taken over replaces the derived one.
    ///   - excusedDays, workFreeDays: no ticks on sick and holiday days, nor for work items on free days.
    ///   - sourceNames: source id → the app's name from its `source.json` (`ExchangeSourceList.names`);
    ///     without one the id with a capital letter ("theo" → "Theo").
    public static func week(_ week: WeekKey, inbox: [ExchangeDayFile], items: [ItemRecord], measures: [MeasureRecord],
                            rules: [LinkRule] = [], categories: [CategoryRecord] = [], ownMarks: [MarkRecord] = [],
                            ownEntries: [EntryRecord] = [], ownWorkIDs: Set<String> = [], excusedDays: Set<DayKey> = [],
                            workFreeDays: Set<DayKey> = [], sourceNames: [String: String] = [:]) -> ExchangeEffect {
        var effect = ExchangeEffect()
        let known = Set(categories.map(\.key))
        let choices = groupChoices(inbox)
        let weekItems = items.filter { $0.week == week }
        let weekMeasures = measures.filter { $0.week == week }
        let allMeasures = weekMeasures + virtualMeasures(items: weekItems, measures: weekMeasures)

        // Usable facts per source and day (one file each, a fact id once).
        var factsByDay: [String: [DayKey: [ExchangeFact]]] = [:]
        var names: [String: String] = [:]
        for file in latest(inbox) {
            guard let day = DayKey(file.day), week.contains(day) else { continue }
            let source = BinisoftExchange.sourceID(file.source)
            names[source] = sourceNames[source] ?? ExchangeSourceInfo.displayName(source)
            // A fact id counts once (`latest` keeps the last row of the file).
            var usable: [ExchangeFact] = []
            for fact in file.facts {
                guard fact.isFromApp else {
                    effect.ignored += 1
                    continue
                }
                guard fact.isKnown else {
                    effect.unused.append(fact)
                    continue
                }
                usable.append(fact)
            }
            factsByDay[source, default: [:]][day] = usable
        }

        // Power-hours → derived work blocks (category from the source before Thalia's mapping).
        for source in factsByDay.keys.sorted() {
            for day in week.days {
                for fact in factsByDay[source]?[day] ?? [] where fact.knownKind == .powerHours {
                    let id = importID(source: source, factID: fact.id)
                    guard !ownWorkIDs.contains(id), let hours = fact.powerHoursValue, hours > 0 else { continue }
                    let category = self.category(of: fact, source: source, rules: rules, known: known, choices: choices[source] ?? [:])
                    let task = fact.title ?? (fact.refTitle.isEmpty ? (names[source] ?? source) : fact.refTitle)
                    let block = WorkRecord(id: id, day: day, categoryKey: category ?? "", task: task, powerHours: hours)
                    effect.workSources[id] = names[source] ?? source
                    if category == nil { effect.unassignedWork.append(block) } else { effect.work.append(block) }
                }
            }
        }

        // Values of measures with an app source.
        let ownKeys = Set(ownEntries.map(\.key))
        for measure in allMeasures {
            guard let source = measure.source.appSource, source.isKnown else { continue }
            let additive = source.summedKind == .spending
            if additive { effect.additiveCodes.insert(measure.code) }
            for day in week.days {
                let key = "\(measure.code)|\(day.string)"
                if ownKeys.contains(key), !additive { continue }
                let facts = factsByDay[source.source]?[day] ?? []
                guard let found = source.dayValue(facts, categoryKey: measure.categoryKey, categoryOf: { fact in
                    category(of: fact, source: source.source, rules: rules, known: known, choices: choices[source.source] ?? [:])
                }) else { continue }
                let value = found.value
                var parts: [EntryPart] = []
                if additive {
                    parts = found.facts.map { fact in
                        let minutes = fact.date.map { Int(DayKey.minutes(of: $0)) } ?? 0
                        return EntryPart(value: fact.value, note: fact.title ?? fact.refTitle, minutes: minutes)
                    }
                }
                effect.entries.append(EntryRecord(code: measure.code, day: day, value: value, parts: parts))
                effect.entrySources[key] = names[source.source] ?? source.sourceName
            }
        }

        // Derived ticks: met (or ≥ 1 without a target) on a day the item applies, not excused, no own mark.
        let ownMarkKeys = Set(ownMarks.map { WeekData.markKey($0.itemCode, $0.day) })
        let data = WeekData(week: week, goals: [], categories: categories, items: weekItems, workFreeDays: workFreeDays,
                            excusedDays: excusedDays)
        let values = Measures.merged(own: ownEntries, external: effect.entries, additive: effect.additiveCodes)
        for item in weekItems.sortedForSheet() where item.schedule != .progress && !item.measure.isEmpty {
            guard let measure = allMeasures.first(where: { $0.code == item.measure }), let source = measure.source.appSource else { continue }
            let additive = effect.additiveCodes.contains(measure.code)
            for day in week.days where data.applies(item, on: day) {
                let key = WeekData.markKey(item.code, day)
                guard !ownMarkKeys.contains(key) else { continue }
                // An own value is no app value: the usual suggestion applies.
                if ownKeys.contains("\(measure.code)|\(day.string)"), !additive { continue }
                guard effect.entrySources["\(measure.code)|\(day.string)"] != nil,
                      let value = Measures.dayValue(measure, on: day, entries: values) else { continue }
                let target = item.target ?? (measure.period == .day ? measure.target : nil)
                let met = target?.isMet(value) ?? (value >= 1 - 1e-9)
                guard met else { continue }
                let facts = factsByDay[source.source]?[day] ?? []
                let label = markLabel(source: source, facts: source.dayValue(facts, categoryKey: measure.categoryKey, categoryOf: { fact in
                    category(of: fact, source: source.source, rules: rules, known: known, choices: choices[source.source] ?? [:])
                })?.facts ?? [], fallback: measure.title, name: names[source.source])
                effect.marks.append(MarkRecord(week: week, itemCode: item.code, day: day, mark: .done, note: label))
                effect.markLabels[key] = label
            }
        }
        return effect
    }

    /// "⇄ George · Push": the facts' common `refTitle` (else their title, else the measure's).
    static func markLabel(source: AppSource, facts: [ExchangeFact], fallback: String, name: String?) -> String {
        let refTitles = Set(facts.map(\.refTitle).filter { !$0.isEmpty })
        let titles = Set(facts.compactMap(\.title))
        let detail: String
        if refTitles.count == 1, let only = refTitles.first { detail = only }
        else if titles.count == 1, let only = titles.first { detail = only }
        else { detail = fallback }
        return "⇄ \(name ?? source.sourceName) · \(detail)"
    }

    /// The day values of an app source over any days – for results with an `app:` source
    /// (`ResultProgress`) and series: per day as `AppSource.dayValue`.
    public static func series(_ source: AppSource, inbox: [ExchangeDayFile], rules: [LinkRule] = [], categoryKey: String = "",
                              known: Set<String> = []) -> [DayKey: Double] {
        var result: [DayKey: Double] = [:]
        let choices = groupChoices(inbox)[source.source] ?? [:]
        for file in latest(inbox) where BinisoftExchange.sourceID(file.source) == source.source {
            guard let day = DayKey(file.day) else { continue }
            if let found = source.dayValue(file.facts, categoryKey: categoryKey, categoryOf: { fact in
                category(of: fact, source: source.source, rules: rules, known: known, choices: choices)
            }) {
                result[day] = found.value
            }
        }
        return result
    }
}

/// Einstellungen → "Verbundene Apps" (§1.5.5): per source what arrived and what still needs a category.
public struct ExchangeSourceSummary: Equatable, Sendable {
    /// A group of the source whose power-hours or tasks have no category yet ("Ohne Zuordnung").
    public struct Unassigned: Equatable, Sendable {
        public var ref: String
        public var title: String
        /// Facts in the time span.
        public var count: Int

        public init(ref: String, title: String, count: Int) {
            self.ref = ref
            self.title = title
            self.count = count
        }
    }

    /// A group with a category: where the mapping comes from, and whether to check it.
    public struct Mapping: Equatable, Sendable {
        public enum Origin: String, Sendable {
            /// Chosen in the source from Thalia's catalog (`thalia.category`).
            case source
            /// A `LinkRule` in Thalia.
            case thalia
        }

        public var ref: String
        public var title: String
        public var categoryKey: String
        public var origin: Origin
        /// The category's title no longer matches the one the source chose ("Zuordnung prüfen"),
        /// or the category is gone.
        public var needsCheck: Bool
        /// "Zuordnung aus Theo" / "Zuordnung in Thalia".
        public var originLabel: String

        public init(ref: String, title: String, categoryKey: String, origin: Origin, needsCheck: Bool, originLabel: String) {
            self.ref = ref
            self.title = title
            self.categoryKey = categoryKey
            self.origin = origin
            self.needsCheck = needsCheck
            self.originLabel = originLabel
        }
    }

    public var source: String
    /// "Theo"
    public var name: String
    /// The latest `source.json`, nil when none was seen.
    public var info: ExchangeSourceInfo?
    /// Facts used in the time span (app origin, known kinds).
    public var factCount: Int
    /// Days with a day file in the time span.
    public var dayCount: Int
    public var unassigned: [Unassigned]
    public var mappings: [Mapping]
    /// Facts with `origin: health` (never used).
    public var ignored: Int
    /// Facts of an unknown kind or metric ("nicht verwendet").
    public var unused: Int

    public init(source: String, name: String, info: ExchangeSourceInfo? = nil, factCount: Int = 0, dayCount: Int = 0,
                unassigned: [Unassigned] = [], mappings: [Mapping] = [], ignored: Int = 0, unused: Int = 0) {
        self.source = source
        self.name = name
        self.info = info
        self.factCount = factCount
        self.dayCount = dayCount
        self.unassigned = unassigned
        self.mappings = mappings
        self.ignored = ignored
        self.unused = unused
    }

    /// When the source last wrote its `source.json` ("zuletzt gesehen"); nil without one.
    public var lastSeen: Date? { info?.generatedDate }
    public var formatVersion: Int? { info?.v }
}

public enum ExchangeOverview {
    /// Shown under the list (§1.5.5).
    public static let hint = "Werte aus anderen Apps erscheinen, sobald Thalia auf diesem Gerät geöffnet war."

    /// One summary per source seen (in `sources` or the inbox), sorted by name, for the `days` days up to `today`.
    public static func summaries(inbox: [ExchangeDayFile], sources: [ExchangeSourceInfo] = [], rules: [LinkRule] = [],
                                 categories: [CategoryRecord] = [], today: DayKey, days: Int = 30) -> [ExchangeSourceSummary] {
        let first = today.adding(days: -(max(1, days) - 1))
        let titles = Dictionary(categories.map { ($0.key, $0.title) }, uniquingKeysWith: { a, _ in a })
        let known = Set(titles.keys)
        var ids = Set(sources.map { BinisoftExchange.sourceID($0.source) })
        let files = ExchangeDerivation.latest(inbox).filter { file in
            guard let day = DayKey(file.day) else { return false }
            return day >= first && day <= today
        }
        for file in files { ids.insert(BinisoftExchange.sourceID(file.source)) }
        let choices = ExchangeDerivation.groupChoices(files)
        return ids.sorted().map { id in
            let info = sources.first { BinisoftExchange.sourceID($0.source) == id }
            let name = info?.displayName ?? ExchangeSourceInfo.displayName(id)
            let own = files.filter { BinisoftExchange.sourceID($0.source) == id }
            var count = 0
            var ignored = 0
            var unused = 0
            var unassigned: [String: ExchangeSourceSummary.Unassigned] = [:]
            var mappings: [String: ExchangeSourceSummary.Mapping] = [:]
            for file in own {
                for fact in file.facts {
                    guard fact.isFromApp else {
                        ignored += 1
                        continue
                    }
                    guard fact.isKnown else {
                        unused += 1
                        continue
                    }
                    count += 1
                    guard fact.knownKind == .powerHours || fact.knownKind == .taskDone, !fact.ref.isEmpty else { continue }
                    let title = fact.refTitle.isEmpty ? fact.ref : fact.refTitle
                    let groupChoice = choices[id]?[fact.ref].flatMap { known.isEmpty || known.contains($0) ? $0 : nil }
                    if let chosen = fact.thalia?.category.flatMap({ known.isEmpty || known.contains($0) ? $0 : nil }) ?? groupChoice {
                        let stale = fact.thalia?.categoryTitle.map { recorded in
                            ImportPlan<String>.contentKey([recorded]) != ImportPlan<String>.contentKey([titles[chosen] ?? recorded])
                        } ?? false
                        let previous = mappings[fact.ref]
                        mappings[fact.ref] = ExchangeSourceSummary.Mapping(
                            ref: fact.ref, title: title, categoryKey: chosen, origin: .source,
                            needsCheck: stale || (previous?.needsCheck ?? false), originLabel: "Zuordnung aus \(name)")
                    } else if let mapped = LinkRule.category(source: id, ref: fact.ref, in: rules) {
                        guard mappings[fact.ref]?.origin != .source else { continue }
                        mappings[fact.ref] = ExchangeSourceSummary.Mapping(
                            ref: fact.ref, title: title, categoryKey: mapped, origin: .thalia,
                            needsCheck: !known.isEmpty && !known.contains(mapped), originLabel: "Zuordnung in Thalia")
                    } else {
                        var entry = unassigned[fact.ref] ?? ExchangeSourceSummary.Unassigned(ref: fact.ref, title: title, count: 0)
                        entry.count += 1
                        entry.title = title
                        unassigned[fact.ref] = entry
                    }
                }
            }
            // A source's choice that points to a category the app doesn't have: Thalia's own rules still count.
            for rule in rules where rule.deletedAt == nil && rule.source == id && mappings[rule.ref] == nil && unassigned[rule.ref] == nil {
                guard !rule.categoryKey.isEmpty else { continue }
                mappings[rule.ref] = ExchangeSourceSummary.Mapping(
                    ref: rule.ref, title: rule.refTitle.isEmpty ? rule.ref : rule.refTitle, categoryKey: rule.categoryKey, origin: .thalia,
                    needsCheck: !known.isEmpty && !known.contains(rule.categoryKey), originLabel: "Zuordnung in Thalia")
            }
            return ExchangeSourceSummary(
                source: id, name: name, info: info, factCount: count, dayCount: own.count,
                unassigned: unassigned.values.sorted { ($0.title, $0.ref) < ($1.title, $1.ref) },
                mappings: mappings.values.sorted { ($0.title, $0.ref) < ($1.title, $1.ref) },
                ignored: ignored, unused: unused)
        }
    }
}

extension ExchangeCatalog {
    /// Thalia's `catalog.json` (§1.5.1): structure only – goals, categories (with the current segment),
    /// the week's measures (code, title, unit, link), results (id, title, kind) – no values, no progress.
    public static func thalia(goals: [GoalRecord], categories: [CategoryRecord], measures: [MeasureRecord], results: [GoalResult],
                              segment: SegmentSpan? = nil, week: WeekKey? = nil, generatedAt: Date = Date(),
                              timeZone: TimeZone = .current) -> ExchangeCatalog {
        ExchangeCatalog(
            generatedAt: ExchangeDate.string(generatedAt, timeZone: timeZone), week: week?.string,
            segment: segment.map { SegmentEntry(id: $0.id, title: $0.title) },
            goals: goals.sortedByNumber().map { GoalEntry(key: $0.key, title: $0.title) },
            categories: categories.sortedByKey().map { CategoryEntry(key: $0.key, goal: $0.goalKey, title: $0.title, segment: segment?.id) },
            measures: measures.filter { week == nil || $0.week == week }.sorted { ($0.position, $0.code) < ($1.position, $1.code) }
                .map { MeasureEntry(code: $0.code, title: $0.title, unit: $0.unit, link: $0.source.raw, category: $0.categoryKey) },
            results: results.filter { $0.deletedAt == nil }.sorted { ($0.goalKey.count, $0.goalKey, $0.position) < ($1.goalKey.count, $1.goalKey, $1.position) }
                .map { ResultEntry(id: $0.id, title: $0.title, kind: $0.kindText, goal: $0.goalKey, source: $0.source) })
    }
}

/// One fact as it arrived, for "Was kommt an" (§1.5.5, read only).
public struct ExchangeArrival: Equatable, Sendable {
    public var day: DayKey
    /// "Theo"
    public var source: String
    /// "Rechnung schreiben"
    public var title: String
    /// "Aufgabe · Arbeit/Kunden → 3.2", "1,5 PH · ohne Zuordnung", "Workout · Push", "Kalorien 2.100 kcal",
    /// "Ausgabe 23,40 € · Lebensmittel", "aus Apple Health – nicht verwendet", "nicht verwendet".
    public var detail: String
    /// Thalia uses it (app origin, known kind).
    public var isUsed: Bool

    public init(day: DayKey, source: String, title: String, detail: String, isUsed: Bool) {
        self.day = day
        self.source = source
        self.title = title
        self.detail = detail
        self.isUsed = isUsed
    }
}

extension ExchangeOverview {
    /// The facts of the `days` days up to `today`, newest day first, in file order within a day.
    public static func arrivals(inbox: [ExchangeDayFile], rules: [LinkRule] = [], categories: [CategoryRecord] = [], today: DayKey,
                                days: Int = 7, sourceNames: [String: String] = [:]) -> [ExchangeArrival] {
        let first = today.adding(days: -(max(1, days) - 1))
        let known = Set(categories.map(\.key))
        let files = ExchangeDerivation.latest(inbox).filter { file in
            guard let day = DayKey(file.day) else { return false }
            return day >= first && day <= today
        }
        let choices = ExchangeDerivation.groupChoices(files)
        var result: [ExchangeArrival] = []
        for file in files.sorted(by: { ($0.day, $0.source) > ($1.day, $1.source) }) {
            guard let day = DayKey(file.day) else { continue }
            let source = BinisoftExchange.sourceID(file.source)
            let name = sourceNames[source] ?? ExchangeSourceInfo.displayName(source)
            for fact in file.facts {
                let title = fact.title ?? (fact.refTitle.isEmpty ? fact.kind : fact.refTitle)
                guard fact.isFromApp else {
                    let detail = fact.knownOrigin == .health ? "aus Apple Health – nicht verwendet" : "ohne Herkunft – nicht verwendet"
                    result.append(ExchangeArrival(day: day, source: name, title: title, detail: detail, isUsed: false))
                    continue
                }
                guard fact.isKnown, let kind = fact.knownKind else {
                    result.append(ExchangeArrival(day: day, source: name, title: title, detail: "nicht verwendet", isUsed: false))
                    continue
                }
                let category = ExchangeDerivation.category(of: fact, source: source, rules: rules, known: known, choices: choices[source] ?? [:])
                let group = fact.refTitle.isEmpty ? "" : " · \(fact.refTitle)"
                let detail: String
                switch kind {
                case .taskDone: detail = "Aufgabe\(group)" + (category.map { " → \($0)" } ?? " · ohne Zuordnung")
                case .workoutDone: detail = "Workout\(group)"
                case .habitDone: detail = "Gewohnheit\(group)"
                case .powerHours:
                    // v11 P1.4: minutes as power-hours – "55 min = 1,1 PH".
                    let hours = Format.powerHours(fact.powerHoursValue ?? 0)
                    let amount = fact.isInMinutes ? "\(Format.number(fact.value ?? 0, decimals: 0)) min = \(hours)" : hours
                    detail = amount + (category.map { " → \($0)" } ?? " · ohne Zuordnung")
                case .spending: detail = "Ausgabe \(Format.euro(fact.value ?? 0))\(group)"
                case .value:
                    let metric = fact.knownMetric
                    let unit = metric?.unit ?? (fact.unit ?? "")
                    // v11 §1.5.4: a metric per account names it – "Kontostand 1.234 € · Girokonto".
                    let named = !fact.ref.isEmpty && fact.ref != metric?.id && !fact.refTitle.isEmpty ? " · \(fact.refTitle)" : ""
                    detail = "\(metric?.title ?? fact.metric ?? "Wert") \(Format.measure(fact.value ?? 0, unit: unit))\(named)"
                }
                result.append(ExchangeArrival(day: day, source: name, title: title, detail: detail, isUsed: true))
            }
        }
        return result
    }
}
