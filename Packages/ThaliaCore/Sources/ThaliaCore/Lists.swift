import Foundation

// Lists (TASKS-v10 §1.3): books and the like. A list entry holds only scalar fields; every page reached
// is its own dated record (`list.progress.<day>.<uuid>`), so progress can be entered for any day –
// also afterwards – and two devices never overwrite each other. `ListMath` turns the readings into
// amounts per day (the increase over the previous reading, never negative), which also feed measures
// with the source `list:<kind>` ("20 Seiten lesen").

/// A list entry: a book, a course, a film …
public struct ListItem: SettingRecord, Equatable {
    public static let prefix = SettingKeys.listItem
    public static let fieldNames: Set<String> = ["id", "kind", "title", "subtitle", "total", "unit", "startedOn", "finishedOn", "abandoned",
                                                 "result", "note", "position", "createdAt", "modifiedAt", "deletedAt"]

    public var id: String
    /// "Buch" (default), "Kurs", "Film", "Podcast" … – free text.
    public var kind: String
    public var title: String
    /// The author ("Autor:in").
    public var subtitle: String
    /// The size (pages of a book), nil when unknown.
    public var total: Double?
    /// The unit of `total` and of every reading ("Seiten").
    public var unit: String
    public var startedOn: DayKey?
    public var finishedOn: DayKey?
    /// Stopped without finishing.
    public var abandoned: Bool
    /// The result it counts for ("zählt für"), nil = by its kind.
    public var resultID: String?
    public var note: String
    public var position: Double
    public var createdAt: Date?
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var unknown: [String: JSONValue]

    public init(id: String = ListItem.newID(), kind: String = ListItem.defaultKind, title: String, subtitle: String = "", total: Double? = nil,
                unit: String? = nil, startedOn: DayKey? = nil, finishedOn: DayKey? = nil, abandoned: Bool = false, resultID: String? = nil,
                note: String = "", position: Double = 0, createdAt: Date? = nil, modifiedAt: Date = Date(), deletedAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.total = total
        self.unit = unit ?? ListItem.defaultUnit(kind: kind)
        self.startedOn = startedOn
        self.finishedOn = finishedOn
        self.abandoned = abandoned
        self.resultID = resultID
        self.note = note
        self.position = position
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
        unknown = [:]
    }

    public init(fields object: [String: JSONValue]) {
        let f = RecordFields(object)
        id = f.text("id")
        kind = f.optional("kind") ?? ListItem.defaultKind
        title = f.text("title")
        subtitle = f.text("subtitle")
        total = f.number("total").flatMap { $0 > 0 ? $0 : nil }
        unit = f.optional("unit") ?? ListItem.defaultUnit(kind: kind)
        startedOn = f.day("startedOn")
        finishedOn = f.day("finishedOn")
        abandoned = f.bool("abandoned") ?? false
        resultID = f.optional("result")
        note = f.text("note")
        position = f.number("position") ?? 0
        createdAt = f.date("createdAt")
        modifiedAt = f.date("modifiedAt") ?? Date(timeIntervalSince1970: 0)
        deletedAt = f.date("deletedAt")
        unknown = ListItem.unknownFields(in: object)
    }

    public var fields: [String: JSONValue] {
        var w = FieldWriter()
        w.set("id", id)
        w.set("kind", kind)
        w.set("title", title)
        w.set("subtitle", subtitle)
        w.set("total", total)
        w.set("unit", unit)
        w.set("startedOn", startedOn)
        w.set("finishedOn", finishedOn)
        w.set("abandoned", abandoned)
        w.set("result", resultID)
        w.set("note", note)
        w.set("position", position)
        w.set("createdAt", createdAt)
        w.set("modifiedAt", modifiedAt)
        w.set("deletedAt", deletedAt)
        return w.object
    }

    public init(from decoder: Decoder) throws { try self.init(settingFrom: decoder) }
    public func encode(to encoder: Encoder) throws { try encodeSetting(to: encoder) }

    public static let defaultKind = "Buch"
    /// The kinds offered (free text is fine too).
    public static let kindSuggestions = ["Buch", "Hörbuch", "Kurs", "Film", "Serie", "Podcast", "Artikel"]

    /// "Seiten" for books, "Minuten" for audio books and podcasts, "Lektionen" for courses, "Folgen" for series.
    public static func defaultUnit(kind: String) -> String {
        switch kindKey(kind) {
        case "hoerbuch", "podcast": return "Minuten"
        case "kurs": return "Lektionen"
        case "serie": return "Folgen"
        case "film": return "Minuten"
        default: return "Seiten"
        }
    }

    /// The kind as it appears in a source: "Buch" → "buch", "Hörbuch" → "hoerbuch".
    public static func kindKey(_ kind: String) -> String { PlanCSV.slug(kind.trimmingCharacters(in: .whitespaces)) }

    /// "buch" → "Buch", "hoerbuch" → "Hörbuch" (a suggestion if it is one, else the key capitalized).
    public static func kindTitle(_ key: String) -> String {
        if let suggestion = kindSuggestions.first(where: { kindKey($0) == key }) { return suggestion }
        return ExchangeSourceInfo.displayName(key)
    }

    /// Of this kind ("Buch" ~ "buch").
    public func isKind(_ key: String) -> Bool { ListItem.kindKey(kind) == ListItem.kindKey(key) }

    /// "Titel · Autor:in"
    public var label: String { subtitle.isEmpty ? title : "\(title) · \(subtitle)" }
}

/// A reading on a day: "bis Seite 120".
public struct ListProgress: SettingRecord, SettingChild, Equatable {
    public static let prefix = SettingKeys.listProgress
    public static let fieldNames: Set<String> = ["id", "day", "item", "reached", "note", "modifiedAt", "deletedAt"]

    public var id: String
    public var day: DayKey
    public var itemID: String
    /// The page (or minute, lesson …) reached.
    public var reached: Double
    public var note: String
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var unknown: [String: JSONValue]

    public init(id: String = ListProgress.newID(), day: DayKey, itemID: String, reached: Double, note: String = "", modifiedAt: Date = Date(),
                deletedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.itemID = itemID
        self.reached = reached
        self.note = note
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
        unknown = [:]
    }

    public init(fields object: [String: JSONValue]) {
        let f = RecordFields(object)
        id = f.text("id")
        day = f.day("day") ?? DayKey(ordinal: 0)
        itemID = f.text("item")
        reached = max(0, f.number("reached") ?? 0)
        note = f.text("note")
        modifiedAt = f.date("modifiedAt") ?? Date(timeIntervalSince1970: 0)
        deletedAt = f.date("deletedAt")
        unknown = ListProgress.unknownFields(in: object)
    }

    public var fields: [String: JSONValue] {
        var w = FieldWriter()
        w.set("id", id)
        w.set("day", day)
        w.set("item", itemID)
        w.set("reached", reached)
        w.set("note", note)
        w.set("modifiedAt", modifiedAt)
        w.set("deletedAt", deletedAt)
        return w.object
    }

    public init(from decoder: Decoder) throws { try self.init(settingFrom: decoder) }
    public func encode(to encoder: Encoder) throws { try encodeSetting(to: encoder) }

    /// "list.progress.2026-11-17.<uuid>" – moving a reading to another day is a new key.
    public var settingKey: String { SettingKeys.dated(ListProgress.prefix, day: day, id: id) }
    public var parentID: String { itemID }

    public mutating func adopt(settingKey: String) {
        guard settingKey.hasPrefix(ListProgress.prefix) else { return }
        let parts = settingKey.dropFirst(ListProgress.prefix.count).split(separator: ".", maxSplits: 1)
        if day.ordinal == 0, let first = parts.first, let parsed = DayKey(String(first)) { day = parsed }
        if id.isEmpty, parts.count == 2 { id = String(parts[1]) }
    }
}

/// Derived from an entry and its readings.
public enum ListStatus: String, CaseIterable, Sendable {
    case planned, running, finished, abandoned

    /// "Geplant", "Läuft", "Fertig", "Abgebrochen" – the sections of the reading list.
    public var label: String {
        switch self {
        case .planned: "Geplant"
        case .running: "Läuft"
        case .finished: "Fertig"
        case .abandoned: "Abgebrochen"
        }
    }
}

public enum ListMath {
    /// The readings of one entry that count: not in the trash, one per day (the last saved), by day.
    public static func readings(_ progress: [ListProgress], itemID: String) -> [ListProgress] {
        var byDay: [DayKey: ListProgress] = [:]
        for reading in progress where reading.itemID == itemID && reading.deletedAt == nil {
            if let current = byDay[reading.day], (current.modifiedAt, current.reached) >= (reading.modifiedAt, reading.reached) { continue }
            byDay[reading.day] = reading
        }
        return byDay.keys.sorted().compactMap { byDay[$0] }
    }

    /// The amount per day of one entry: the increase over the highest earlier reading – in day order,
    /// whenever it was entered, never negative (a lower reading counts 0, the next one counts from the
    /// highest so far). The sum is the highest reading.
    public static func dailyAmounts(itemID: String, progress: [ListProgress]) -> [DayKey: Double] {
        var result: [DayKey: Double] = [:]
        var highest = 0.0
        for reading in readings(progress, itemID: itemID) {
            let amount = max(0, reading.reached - highest)
            highest = max(highest, reading.reached)
            if amount > 0 { result[reading.day] = amount }
        }
        return result
    }

    /// The amount per day of all entries (of `kind`, e.g. "buch"; nil = every kind) not in the trash.
    public static func dailyAmounts(items: [ListItem], progress: [ListProgress], kind: String? = nil) -> [DayKey: Double] {
        var result: [DayKey: Double] = [:]
        for item in items where item.deletedAt == nil && (kind.map(item.isKind) ?? true) {
            for (day, amount) in dailyAmounts(itemID: item.id, progress: progress) { result[day, default: 0] += amount }
        }
        return result
    }

    /// The highest reading of an entry up to `day` (nil = all), nil without readings.
    public static func reached(itemID: String, progress: [ListProgress], through day: DayKey? = nil) -> Double? {
        let counted = readings(progress, itemID: itemID).filter { day == nil || $0.day <= day! }
        return counted.map(\.reached).max()
    }

    /// The latest reading's day.
    public static func lastReadingDay(itemID: String, progress: [ListProgress]) -> DayKey? {
        readings(progress, itemID: itemID).last?.day
    }

    /// Share of `total` reached, 0…1; 1 once finished; nil without a total.
    public static func fraction(_ item: ListItem, progress: [ListProgress]) -> Double? {
        if item.finishedOn != nil { return 1 }
        guard let total = item.total, total > 0 else { return nil }
        return min(1, (reached(itemID: item.id, progress: progress) ?? 0) / total)
    }

    /// Planned without readings and start, running with them, finished with `finishedOn`, abandoned.
    public static func status(_ item: ListItem, progress: [ListProgress]) -> ListStatus {
        if item.abandoned { return .abandoned }
        if item.finishedOn != nil { return .finished }
        if item.startedOn != nil || reached(itemID: item.id, progress: progress) != nil { return .running }
        return .planned
    }

    /// "bis Seite = total" suggests "fertig".
    public static func suggestsFinish(_ item: ListItem, reached: Double) -> Bool {
        guard let total = item.total, total > 0, item.finishedOn == nil, !item.abandoned else { return false }
        return reached >= total - 1e-9
    }

    /// Entries finished from `start` through `end` (not abandoned, not in the trash), oldest first.
    /// `kind`: only that kind; `resultID`: only those counting for it.
    public static func finished(_ items: [ListItem], from start: DayKey, through end: DayKey, kind: String? = nil,
                                resultID: String? = nil) -> [ListItem] {
        items.filter { item in
            guard item.deletedAt == nil, !item.abandoned, let day = item.finishedOn, day >= start, day <= end else { return false }
            if let kind, !item.isKind(kind) { return false }
            if let resultID, item.resultID != resultID { return false }
            return true
        }.sorted { ($0.finishedOn ?? DayKey(ordinal: 0), $0.title) < ($1.finishedOn ?? DayKey(ordinal: 0), $1.title) }
    }

    /// The amount read from `start` through `end`.
    public static func amount(items: [ListItem], progress: [ListProgress], kind: String? = nil, from start: DayKey, through end: DayKey) -> Double {
        dailyAmounts(items: items, progress: progress, kind: kind).filter { $0.key >= start && $0.key <= end }.values.reduce(0, +)
    }

    /// The amount read per week ("Seiten je Woche").
    public static func perWeek(items: [ListItem], progress: [ListProgress], kind: String? = nil) -> [WeekKey: Double] {
        var result: [WeekKey: Double] = [:]
        for (day, amount) in dailyAmounts(items: items, progress: progress, kind: kind) { result[day.week, default: 0] += amount }
        return result
    }

    /// Day values of the measures with a `list:<kind>` source on `days` (computed, like Health values –
    /// pass them as `external` to `Measures.merged`).
    public static func entries(for measures: [MeasureRecord], items: [ListItem], progress: [ListProgress], days: [DayKey]) -> [EntryRecord] {
        var result: [EntryRecord] = []
        var amounts: [String: [DayKey: Double]] = [:]
        var done: Set<String> = []
        for measure in measures {
            guard let kind = measure.source.listKind else { continue }
            let daily = amounts[kind] ?? dailyAmounts(items: items, progress: progress, kind: kind)
            amounts[kind] = daily
            for day in days {
                guard let amount = daily[day], amount > 0, done.insert("\(measure.code)|\(day.string)").inserted else { continue }
                result.append(EntryRecord(code: measure.code, day: day, value: amount))
            }
        }
        return result
    }

    /// "120 von 320 Seiten · 38 %", "120 Seiten" without a total, "320 Seiten · fertig".
    public static func progressText(_ item: ListItem, progress: [ListProgress]) -> String {
        let reached = reached(itemID: item.id, progress: progress)
        let unit = item.unit.isEmpty ? "" : " " + item.unit
        if item.finishedOn != nil {
            let total = item.total ?? reached
            return total.map { "\(Format.number($0, decimals: 0))\(unit) · fertig" } ?? "fertig"
        }
        guard let reached else { return item.total.map { "\(Format.number($0, decimals: 0))\(unit)" } ?? "noch nicht begonnen" }
        guard let total = item.total, total > 0 else { return "\(Format.number(reached, decimals: 0))\(unit)" }
        let percent = Int((min(1, reached / total) * 100).rounded())
        return "\(Format.number(reached, decimals: 0)) von \(Format.number(total, decimals: 0))\(unit) · \(percent) %"
    }
}
