import Foundation

// Results of annual goals (TASKS-v10 §1.2.1–1.2.2): what a goal is meant to achieve in the goal year –
// tick it off ("Website online"), count ("10 Bücher") or reach a value (net worth, weight). The scores
// measure behaviour; results measure outcomes. A result belongs to a goal year and a goal; its target
// can be updated per segment; its share per segment follows from the dates of its facts (nothing is
// copied). Values from Apple Health are only ever computed on the device, never stored or exported.

/// A result of an annual goal.
public struct GoalResult: SettingRecord, Equatable {
    public static let prefix = SettingKeys.goalResult
    public static let fieldNames: Set<String> = ["id", "period", "goal", "title", "kind", "target", "targets", "start", "unit", "source",
                                                 "fromSegment", "endedAfter", "position", "note", "createdAt", "modifiedAt", "deletedAt"]

    public enum Kind: String, CaseIterable, Sendable {
        /// Done once there is an entry (its day = done on).
        case check
        /// The sum of entries – or of a source (finished list entries, a measure, a connected app).
        case count
        /// The latest value (net worth, weight) – from a source or own entries.
        case value

        /// "Abhaken", "Zählen", "Zielwert".
        public var label: String {
            switch self {
            case .check: "Abhaken"
            case .count: "Zählen"
            case .value: "Zielwert"
            }
        }
    }

    public var id: String
    /// The goal year (`GoalPeriod.start`); nil = any.
    public var periodStart: DayKey?
    /// The annual goal ("5").
    public var goalKey: String
    public var title: String
    /// The kind as stored ("check", "count", "value"; an unknown one from a newer build is kept).
    public var kindText: String
    /// A `Target` text (">=10", "<=80", ">=60000"); empty = without a target (only the value is shown).
    public var target: String
    /// The target per segment id ("aktualisieren"): it replaces `target` while that segment runs.
    public var targets: [String: String]
    /// The starting value of a `value` result (weight at the start).
    public var start: Double?
    /// "Bücher", "kg", "€" …
    public var unit: String
    /// "" (own entries), "list" / "list:buch", "measure:<code>", "app:<source>:<metric>[=<ref>]".
    public var source: String
    /// New from this segment on (id).
    public var fromSegment: String?
    /// Ended after this segment (id).
    public var endedAfter: String?
    public var position: Double
    public var note: String
    public var createdAt: Date?
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var unknown: [String: JSONValue]

    public init(id: String = GoalResult.newID(), periodStart: DayKey? = nil, goalKey: String, title: String, kind: Kind = .count,
                target: String = "", targets: [String: String] = [:], start: Double? = nil, unit: String = "", source: String = "",
                fromSegment: String? = nil, endedAfter: String? = nil, position: Double = 0, note: String = "", createdAt: Date? = nil,
                modifiedAt: Date = Date(), deletedAt: Date? = nil) {
        self.id = id
        self.periodStart = periodStart
        self.goalKey = goalKey
        self.title = title
        kindText = kind.rawValue
        self.target = target
        self.targets = targets
        self.start = start
        self.unit = unit
        self.source = source
        self.fromSegment = fromSegment
        self.endedAfter = endedAfter
        self.position = position
        self.note = note
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
        unknown = [:]
    }

    public init(fields object: [String: JSONValue]) {
        let f = RecordFields(object)
        id = f.text("id")
        periodStart = f.day("period")
        goalKey = f.text("goal")
        title = f.text("title")
        kindText = f.optional("kind") ?? Kind.count.rawValue
        target = f.text("target")
        targets = f.stringMap("targets")
        start = f.number("start")
        unit = f.text("unit")
        source = f.text("source")
        fromSegment = f.optional("fromSegment")
        endedAfter = f.optional("endedAfter")
        position = f.number("position") ?? 0
        note = f.text("note")
        createdAt = f.date("createdAt")
        modifiedAt = f.date("modifiedAt") ?? Date(timeIntervalSince1970: 0)
        deletedAt = f.date("deletedAt")
        unknown = GoalResult.unknownFields(in: object)
    }

    public var fields: [String: JSONValue] {
        var w = FieldWriter()
        w.set("id", id)
        w.set("period", periodStart)
        w.set("goal", goalKey)
        w.set("title", title)
        w.set("kind", kindText)
        w.set("target", target)
        w.set("targets", targets)
        w.set("start", start)
        w.set("unit", unit)
        w.set("source", source)
        w.set("fromSegment", fromSegment)
        w.set("endedAfter", endedAfter)
        w.set("position", position)
        w.set("note", note)
        w.set("createdAt", createdAt)
        w.set("modifiedAt", modifiedAt)
        w.set("deletedAt", deletedAt)
        return w.object
    }

    public init(from decoder: Decoder) throws { try self.init(settingFrom: decoder) }
    public func encode(to encoder: Encoder) throws { try encodeSetting(to: encoder) }

    /// The kind that counts (an unknown one counts like `count`).
    public var kind: Kind {
        get { Kind(rawValue: kindText) ?? .count }
        set { kindText = newValue.rawValue }
    }

    public var resultSource: ResultSource { ResultSource(raw: source) }

    /// The target text that counts in `segment` (its own, else the goal year's).
    public func targetText(in segment: SegmentSpan?) -> String {
        if let segment, let own = targets[segment.id], !own.trimmingCharacters(in: .whitespaces).isEmpty { return own }
        return target
    }

    /// Shown in `segment`: started in it or before (`fromSegment`), not ended before it (`endedAfter`).
    public func isActive(in segment: SegmentSpan, segments: Segments) -> Bool {
        if let from = fromSegment.flatMap(segments.span(id:)), segment.number < from.number { return false }
        if let ended = endedAfter.flatMap(segments.span(id:)), segment.number > ended.number { return false }
        return true
    }

    /// Feeds on this measure (`measure:<code>`).
    public func uses(measure code: String) -> Bool {
        if case .measure(let own) = resultSource { return own == code }
        return false
    }

    /// The measures of a goal (§1.2.4): those of its categories (in order), then those feeding one of
    /// its results – each code once.
    public static func measures(of goalKey: String, categories: [CategoryRecord], measures: [MeasureRecord], results: [GoalResult]) -> [MeasureRecord] {
        let keys = Set(categories.filter { $0.goalKey == goalKey }.map(\.key))
        var seen: Set<String> = []
        var result: [MeasureRecord] = []
        let sorted = measures.sorted { ($0.position, $0.code) < ($1.position, $1.code) }
        for measure in sorted where keys.contains(measure.categoryKey) && seen.insert(measure.code).inserted { result.append(measure) }
        let fed = results.filter { $0.goalKey == goalKey && $0.deletedAt == nil }
        for measure in sorted where fed.contains(where: { $0.uses(measure: measure.code) }) && seen.insert(measure.code).inserted {
            result.append(measure)
        }
        return result
    }

    /// Up to `limit` chips and how many more ("Gewicht · Protein · Schritte", "+2").
    public static func chips(_ titles: [String], limit: Int = 3) -> (shown: [String], more: Int) {
        (Array(titles.prefix(limit)), max(0, titles.count - limit))
    }
}

/// Where a result's value comes from.
public enum ResultSource: Equatable, Sendable {
    /// Own entries (tick, +1, value).
    case entries
    /// Finished list entries: those counting for this result ("zählt für"), without such the finished
    /// ones of the kind ("buch" when none is given).
    case list(kind: String?)
    /// A measure's day values over the segment or goal year (`arbeit:` power-hours too; `health:` only on the device).
    case measure(code: String)
    /// A connected app's facts (`app:finn:net_worth`, `app:george:workout=tpl-1`).
    case app(AppSource)
    /// Something a newer build wrote – counts like own entries, kept unchanged.
    case other(String)

    public init(raw: String) {
        let text = raw.trimmingCharacters(in: .whitespaces)
        let lower = text.lowercased()
        if text.isEmpty || lower == "entries" || lower == "eintraege" {
            self = .entries
        } else if lower == "list" || lower == "liste" {
            self = .list(kind: nil)
        } else if lower.hasPrefix("list:") {
            let kind = ListItem.kindKey(String(text.dropFirst(5)))
            self = .list(kind: kind.isEmpty ? nil : kind)
        } else if lower.hasPrefix("measure:") {
            let code = String(text.dropFirst(8)).trimmingCharacters(in: .whitespaces)
            self = code.isEmpty ? .other(text) : .measure(code: code)
        } else if let app = AppSource(raw: text) {
            self = .app(app)
        } else {
            self = .other(text)
        }
    }

    public var raw: String {
        switch self {
        case .entries: ""
        case .list(let kind): kind.map { "list:\($0)" } ?? "list"
        case .measure(let code): "measure:\(code)"
        case .app(let source): source.raw
        case .other(let text): text
        }
    }

    /// "Einträge", "Leseliste", "Messwert seiten", "George · Workouts".
    public var label: String {
        switch self {
        case .entries, .other: "Einträge"
        case .list(let kind): kind.map { "Leseliste · \(ListItem.kindTitle($0))" } ?? "Leseliste"
        case .measure(let code): "Messwert \(code)"
        case .app(let source): source.label
        }
    }
}

/// A dated entry of a result: a tick (done on that day), +1, or a value.
public struct GoalEntry: SettingRecord, SettingChild, Equatable {
    public static let prefix = SettingKeys.goalEntry
    public static let fieldNames: Set<String> = ["id", "day", "result", "value", "note", "modifiedAt", "deletedAt"]

    public var id: String
    public var day: DayKey
    public var resultID: String
    /// +1 when nil for a count; the value for a `value` result.
    public var value: Double?
    public var note: String
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var unknown: [String: JSONValue]

    public init(id: String = GoalEntry.newID(), day: DayKey, resultID: String, value: Double? = nil, note: String = "",
                modifiedAt: Date = Date(), deletedAt: Date? = nil) {
        self.id = id
        self.day = day
        self.resultID = resultID
        self.value = value
        self.note = note
        self.modifiedAt = modifiedAt
        self.deletedAt = deletedAt
        unknown = [:]
    }

    public init(fields object: [String: JSONValue]) {
        let f = RecordFields(object)
        id = f.text("id")
        day = f.day("day") ?? DayKey(ordinal: 0)
        resultID = f.text("result")
        value = f.number("value")
        note = f.text("note")
        modifiedAt = f.date("modifiedAt") ?? Date(timeIntervalSince1970: 0)
        deletedAt = f.date("deletedAt")
        unknown = GoalEntry.unknownFields(in: object)
    }

    public var fields: [String: JSONValue] {
        var w = FieldWriter()
        w.set("id", id)
        w.set("day", day)
        w.set("result", resultID)
        w.set("value", value)
        w.set("note", note)
        w.set("modifiedAt", modifiedAt)
        w.set("deletedAt", deletedAt)
        return w.object
    }

    public init(from decoder: Decoder) throws { try self.init(settingFrom: decoder) }
    public func encode(to encoder: Encoder) throws { try encodeSetting(to: encoder) }

    /// "goal.entry.2026-11-17.<uuid>" – moving an entry to another day is a new key.
    public var settingKey: String { SettingKeys.dated(GoalEntry.prefix, day: day, id: id) }
    public var parentID: String { resultID }

    public mutating func adopt(settingKey: String) {
        guard settingKey.hasPrefix(GoalEntry.prefix) else { return }
        let parts = settingKey.dropFirst(GoalEntry.prefix.count).split(separator: ".", maxSplits: 1)
        if day.ordinal == 0, let first = parts.first, let parsed = DayKey(String(first)) { day = parsed }
        if id.isEmpty, parts.count == 2 { id = String(parts[1]) }
    }
}

/// Where a result stands (§1.2.2): its value, the target, the share reached, what an even pace would
/// have reached by today, its status and how much each segment contributed.
public struct ResultProgress: Equatable, Sendable {
    public enum Status: String, Sendable {
        /// Nothing recorded yet.
        case open
        case onTrack
        case behind
        case reached
        /// The time span is over and the target wasn't reached.
        case missed
        /// No target: only the value is shown.
        case untargeted

        /// "offen", "auf Kurs", "hinten", "erreicht", "nicht erreicht", "".
        public var label: String {
            switch self {
            case .open: "offen"
            case .onTrack: "auf Kurs"
            case .behind: "hinten"
            case .reached: "erreicht"
            case .missed: "nicht erreicht"
            case .untargeted: ""
            }
        }
    }

    public var kind: GoalResult.Kind
    /// count: the total in the time span (in the segment with a segment target) · value: the latest
    /// value · check: 1 done, 0 open. nil: no value yet (value).
    public var current: Double?
    /// count with a segment target: the total of the whole goal year (or the result's time span).
    public var total: Double?
    public var target: Target?
    /// The number aimed for (the target's value; for a range the end towards which it moves).
    public var targetValue: Double?
    /// The starting point of the pace (0 for count, `start` or the value before the segment for value).
    public var start: Double
    /// 0…1 of the way from `start` to the target; nil without a target or a value.
    public var fraction: Double?
    /// "Soll heute": start + (target − start) × the share of the time span gone by.
    public var expected: Double?
    public var status: Status
    /// check: the day it was done.
    public var doneOn: DayKey?
    /// Segment id → its contribution (count: the sum in it; value: the change in it; check: 1 where done).
    public var bySegment: [String: Double]
    /// The segment of today, when the result runs in it.
    public var segment: SegmentSpan?
    /// The target is the current segment's own ("aktualisiert").
    public var usesSegmentTarget: Bool
    /// More than one segment in the goal year (texts name the current one).
    public var hasSeveralSegments: Bool
    public var unit: String
    /// The time span counted: the goal year (or from/to the result's segments).
    public var from: DayKey
    public var through: DayKey

    /// "offen", "auf Kurs" …
    public var statusText: String { status.label }

    public init(kind: GoalResult.Kind, current: Double? = nil, total: Double? = nil, target: Target? = nil, targetValue: Double? = nil,
                start: Double = 0, fraction: Double? = nil, expected: Double? = nil, status: Status = .open, doneOn: DayKey? = nil,
                bySegment: [String: Double] = [:], segment: SegmentSpan? = nil, usesSegmentTarget: Bool = false,
                hasSeveralSegments: Bool = false, unit: String = "", from: DayKey, through: DayKey) {
        self.kind = kind
        self.current = current
        self.total = total
        self.target = target
        self.targetValue = targetValue
        self.start = start
        self.fraction = fraction
        self.expected = expected
        self.status = status
        self.doneOn = doneOn
        self.bySegment = bySegment
        self.segment = segment
        self.usesSegmentTarget = usesSegmentTarget
        self.hasSeveralSegments = hasSeveralSegments
        self.unit = unit
        self.from = from
        self.through = through
    }

    /// The current segment's contribution.
    public var inSegment: Double? { segment.flatMap { bySegment[$0.id] } }

    /// count: "7 von 10 · davon 4 in Abschnitt 2", with a segment target "3 von 6 in Abschnitt 2 · 7 im
    /// Zieljahr", without a target "7 Bücher"; value: "86,4 kg · Ziel ≤ 85 kg · −1,2 kg in Abschnitt 2";
    /// check: "erledigt am Di, 17. Nov." / "offen".
    public var text: String {
        switch kind {
        case .check:
            return doneOn.map { "erledigt am \($0.shortLabel)" } ?? "offen"
        case .count:
            let value = current ?? 0
            var parts: [String]
            if let targetValue {
                parts = ["\(amount(value)) von \(amount(targetValue))\(unitSuffix)"]
            } else {
                parts = ["\(amount(value))\(unitSuffix)"]
            }
            if usesSegmentTarget, let segment {
                parts[0] += " in \(segment.title)"
                if let total { parts.append("\(amount(total)) im Zieljahr") }
            } else if hasSeveralSegments, let segment {
                parts.append("davon \(amount(inSegment ?? 0)) in \(segment.title)")
            }
            return parts.joined(separator: " · ")
        case .value:
            guard let current else { return target.map { "noch kein Wert · Ziel \(targetLabel($0))" } ?? "noch kein Wert" }
            var parts = [Format.measure(current, unit: unit)]
            if let target { parts.append("Ziel \(targetLabel(target))") }
            if hasSeveralSegments, let segment, let change = inSegment, abs(change) > 1e-9 {
                let sign = change > 0 ? "+" : "−"
                parts.append("\(sign)\(Format.measure(abs(change), unit: unit)) in \(segment.title)")
            }
            return parts.joined(separator: " · ")
        }
    }

    /// "7/10", "86,4 kg", "✓" / "–".
    public var shortText: String {
        switch kind {
        case .check: return doneOn == nil ? "–" : "✓"
        case .count:
            let value = amount(current ?? 0)
            return targetValue.map { "\(value)/\(amount($0))" } ?? value
        case .value: return current.map { Format.measure($0, unit: unit) } ?? "–"
        }
    }

    var unitSuffix: String {
        let shown = Units.display(unit)
        return shown.isEmpty || Units.normalized(unit) == "€" ? "" : " " + shown
    }

    func amount(_ value: Double) -> String {
        Units.normalized(unit) == "€" ? Format.euro(value) : Format.number(value, decimals: 2)
    }

    func targetLabel(_ target: Target) -> String {
        guard Units.normalized(unit) == "€" else {
            let shown = Units.display(unit)
            return shown.isEmpty || target.isTime ? target.label : "\(target.label) \(shown)"
        }
        let value = Format.euro(target.value)
        switch target.comparison {
        case .atLeast: return "≥ \(value)"
        case .atMost: return "≤ \(value)"
        case .above: return "> \(value)"
        case .below: return "< \(value)"
        case .equal: return "= \(value)"
        case .range: return "\(value)–\(Format.euro(target.upper ?? target.value))"
        }
    }
}

extension ResultProgress {
    /// The result's progress on `today`.
    /// - Parameters:
    ///   - entries: the own entries (any results; only this one's count, not those in the trash).
    ///   - items: the list entries (for a `list` source).
    ///   - series: the source's day values (for `measure:` and `app:` sources), computed by the caller –
    ///     `health:` measures only on the device.
    public static func compute(_ result: GoalResult, segments: Segments, today: DayKey, entries: [GoalEntry] = [], items: [ListItem] = [],
                               series: [DayKey: Double] = [:]) -> ResultProgress {
        let period = segments.period
        let from = result.fromSegment.flatMap(segments.span(id:))?.startDay ?? period.start
        let through = result.endedAfter.flatMap(segments.span(id:))?.endDay ?? period.end
        let current = segments.current(today: today)
        let running = current.flatMap { span in span.startDay <= through && span.endDay >= from ? span : nil }
        let segmentTargetText = running.flatMap { result.targets[$0.id] }?.trimmingCharacters(in: .whitespaces) ?? ""
        let segmentTarget = segmentTargetText.isEmpty ? nil : Target.parse(segmentTargetText)
        let target = segmentTarget ?? Target.parse(result.target)
        var paceFrom = from
        var paceThrough = through
        if segmentTarget != nil, let running {
            paceFrom = max(from, running.startDay)
            paceThrough = min(through, running.endDay)
        }

        // The dated facts behind the result, in the time span.
        let own = entries.filter { $0.resultID == result.id && $0.deletedAt == nil && $0.day >= from && $0.day <= through }
            .sorted { ($0.day, $0.modifiedAt) < ($1.day, $1.modifiedAt) }
        var facts: [(day: DayKey, value: Double)] = []
        switch result.kind {
        case .check:
            facts = own.prefix(1).map { (day: $0.day, value: 1.0) }
        case .count:
            switch result.resultSource {
            case .entries, .other:
                facts = own.map { (day: $0.day, value: $0.value ?? 1) }
            case .list(let kind):
                let live = items.filter { $0.deletedAt == nil }
                let assigned = live.filter { $0.resultID == result.id }
                let counted: [ListItem]
                if !assigned.isEmpty {
                    counted = ListMath.finished(assigned, from: from, through: through)
                } else {
                    let unassigned = live.filter { $0.resultID == nil || $0.resultID?.isEmpty == true }
                    counted = ListMath.finished(unassigned, from: from, through: through, kind: kind ?? ListItem.kindKey(ListItem.defaultKind))
                }
                facts = counted.compactMap { item in item.finishedOn.map { (day: $0, value: 1.0) } }
            case .measure, .app:
                facts = series.filter { $0.key >= from && $0.key <= through }.map { (day: $0.key, value: $0.value) }
            }
        case .value:
            var byDay: [DayKey: Double] = [:]
            switch result.resultSource {
            case .measure, .app:
                for (day, value) in series where day <= through { byDay[day] = value }
            default:
                break
            }
            // Own entries win over the source's value of the day.
            for entry in own { if let value = entry.value { byDay[entry.day] = value } }
            facts = byDay.keys.sorted().compactMap { day in byDay[day].map { (day: day, value: $0) } }
        }
        facts.sort { $0.day < $1.day }

        let elapsedThrough = min(today, paceThrough)
        let spanDays = Double(paceThrough.ordinal - paceFrom.ordinal + 1)
        let goneDays = Double(elapsedThrough.ordinal - paceFrom.ordinal + 1)
        let elapsed: Double = spanDays <= 0 ? 1 : min(1, max(0, goneDays / spanDays))
        var progress = ResultProgress(kind: result.kind, current: nil, total: nil, target: target, targetValue: nil, start: 0,
                                      fraction: nil, expected: nil, status: .open, doneOn: nil, bySegment: [:], segment: running,
                                      usesSegmentTarget: segmentTarget != nil, hasSeveralSegments: segments.hasSeveral, unit: result.unit,
                                      from: from, through: through)

        let spans = segments.spans.filter { $0.startDay <= through && $0.endDay >= from }
        switch result.kind {
        case .check:
            progress.doneOn = facts.first?.day
            progress.current = progress.doneOn == nil ? 0 : 1
            progress.fraction = progress.current
            progress.status = progress.doneOn != nil ? .reached : (today > through ? .missed : .open)
            progress.target = nil
            if let day = progress.doneOn, let span = segments.span(for: day) { progress.bySegment[span.id] = 1 }
            return progress

        case .count:
            let inPace = facts.filter { $0.day >= paceFrom && $0.day <= paceThrough }.reduce(0) { $0 + $1.value }
            progress.current = inPace
            if segmentTarget != nil { progress.total = facts.reduce(0) { $0 + $1.value } }
            for span in spans {
                progress.bySegment[span.id] = facts.filter { span.contains($0.day) }.reduce(0) { $0 + $1.value }
            }
            progress.start = 0

        case .value:
            let upToToday = facts.filter { $0.day <= today }
            progress.current = upToToday.last?.value
            let before: Double? = facts.last { $0.day < paceFrom }?.value
            let first: Double? = result.start ?? facts.first?.value
            var startValue: Double? = first
            if segmentTarget != nil, let before { startValue = before }
            progress.start = startValue ?? progress.current ?? 0
            var baseline = result.start ?? facts.first { $0.day >= from }?.value
            if let earlier = facts.last(where: { $0.day < from })?.value { baseline = earlier }
            for span in spans {
                let inSpan = upToToday.filter { span.contains($0.day) }
                if let last = inSpan.last?.value, let base = baseline ?? inSpan.first?.value {
                    progress.bySegment[span.id] = last - base
                    baseline = last
                }
            }
        }

        guard let target else {
            progress.status = progress.current == nil ? .open : .untargeted
            return progress
        }
        let aim = ResultProgress.aim(target, from: progress.start)
        progress.targetValue = aim
        progress.expected = progress.start + (aim - progress.start) * elapsed
        guard let value = progress.current else {
            progress.status = .open
            return progress
        }
        let distance = aim - progress.start
        progress.fraction = abs(distance) < 1e-9 ? (target.isMet(value) ? 1 : 0) : min(1, max(0, (value - progress.start) / distance))
        if target.isMet(value) {
            progress.status = .reached
        } else if today > paceThrough {
            progress.status = .missed
        } else if result.kind == .count, value <= 1e-9, (progress.expected ?? 0) < 1 {
            progress.status = .open
        } else {
            let direction: Double = distance >= 0 ? 1 : -1
            let made = (value - progress.start) * direction
            let due = ((progress.expected ?? progress.start) - progress.start) * direction
            progress.status = made + 1e-9 < due * 0.85 ? .behind : .onTrack
        }
        return progress
    }

    /// The number a target aims for: its value; for a range the end in the direction of travel from `start`.
    static func aim(_ target: Target, from start: Double) -> Double {
        guard target.comparison == .range else { return target.value }
        return start <= target.value ? target.value : (target.upper ?? target.value)
    }
}

/// A result as one line of the planning prompt and the week report (§1.2.5) – no Health values.
public struct GoalResultLine: Equatable, Sendable {
    public var goalKey: String
    public var goalTitle: String
    public var title: String
    /// "7 von 10 · davon 4 in Abschnitt 2"
    public var text: String
    /// "auf Kurs"
    public var status: String
    /// "7/10"
    public var shortText: String

    /// `hidesValue`: the value comes from Apple Health – it never leaves the device, the line says so.
    public init(result: GoalResult, goal: GoalRecord?, progress: ResultProgress, hidesValue: Bool = false) {
        goalKey = result.goalKey
        goalTitle = goal?.title ?? ""
        title = result.title
        if hidesValue {
            text = "Wert nur auf dem Gerät"
            status = ""
            shortText = "–"
        } else {
            text = progress.text
            status = progress.statusText
            shortText = progress.shortText
        }
    }

    public init(goalKey: String, goalTitle: String = "", title: String, text: String, status: String = "", shortText: String = "") {
        self.goalKey = goalKey
        self.goalTitle = goalTitle
        self.title = title
        self.text = text
        self.status = status
        self.shortText = shortText
    }

    /// "- 5 Bücher · Bücher gelesen: 3 von 10 · auf Kurs"
    public var markdown: String {
        let goal = goalTitle.isEmpty ? goalKey : "\(goalKey) \(goalTitle)"
        return "- \(goal) · \(title): \(text)" + (status.isEmpty ? "" : " · \(status)")
    }

    /// "zählt für Ziel 5 · Bücher 3/10" – under a measure in "Wochenziele" and in the measure editor.
    public var countsForText: String {
        "zählt für Ziel \(goalKey) · \(title)" + (shortText.isEmpty ? "" : " \(shortText)")
    }

    /// The block's heading.
    public static let heading = "Jahresziel-Ergebnisse (nur zur Info – nichts unaufgefordert steigern)"

    /// The block for the report and the prompt; empty without lines.
    public static func block(_ lines: [GoalResultLine]) -> [String] {
        guard !lines.isEmpty else { return [] }
        return ["## \(heading)"] + lines.map(\.markdown) + [""]
    }
}
