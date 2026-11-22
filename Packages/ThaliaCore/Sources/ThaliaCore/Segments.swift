import Foundation

// Segments of the goal year (TASKS-v10 §1.4, "Versionen der Jahresziele"): the owner updates the annual
// goals in self-chosen segments. A segment starts in a week and ends where the next one starts; without
// stored segments the whole goal year is "Abschnitt 1". Earlier segments keep their achievements and
// labels (snapshots), their weeks are frozen (Grundregel 2), and screens focus on the current one.

/// A stored segment: where it starts, why, and the goals and categories as they were at its start.
public struct GoalSegment: SettingRecord, Equatable {
    public static let prefix = SettingKeys.goalSegment
    public static let fieldNames: Set<String> = ["id", "title", "period", "startWeek", "reason", "goals", "categories", "createdAt",
                                                 "modifiedAt", "deletedAt"]

    public var id: String
    /// "Abschnitt 2"; empty = numbered automatically.
    public var title: String
    /// The goal year (`GoalPeriod.start`) it belongs to.
    public var periodStart: DayKey
    public var startWeek: WeekKey
    /// "Zielüberprüfung", "neue Arbeitsstelle" …
    public var reason: String
    /// The goals and categories when the segment began.
    public var goals: [GoalRecord]
    public var categories: [CategoryRecord]
    public var createdAt: Date
    public var modifiedAt: Date
    public var deletedAt: Date?
    public var unknown: [String: JSONValue]
    /// Fields of a goal / category in the snapshot this build doesn't know (by key) – written back
    /// unchanged (Grundregel 4 inside the snapshot too).
    public var goalExtras: [String: [String: JSONValue]] = [:]
    public var categoryExtras: [String: [String: JSONValue]] = [:]

    static let goalFieldNames: Set<String> = ["key", "title", "details"]
    static let categoryFieldNames: Set<String> = ["key", "goal", "title", "details"]

    public init(id: String = GoalSegment.newID(), title: String = "", periodStart: DayKey, startWeek: WeekKey, reason: String = "",
                goals: [GoalRecord] = [], categories: [CategoryRecord] = [], createdAt: Date = Date(), modifiedAt: Date? = nil,
                deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.periodStart = periodStart
        self.startWeek = startWeek
        self.reason = reason
        self.goals = goals
        self.categories = categories
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt ?? createdAt
        self.deletedAt = deletedAt
        unknown = [:]
    }

    public init(fields object: [String: JSONValue]) {
        let f = RecordFields(object)
        id = f.text("id")
        title = f.text("title")
        periodStart = f.day("period") ?? DayKey(ordinal: 0)
        startWeek = f.week("startWeek") ?? periodStart.week
        reason = f.text("reason")
        var goalExtras: [String: [String: JSONValue]] = [:]
        goals = f.objects("goals").compactMap { goal in
            guard let key = goal.optional("key") else { return nil }
            let extra = goal.object.filter { !GoalSegment.goalFieldNames.contains($0.key) }
            if !extra.isEmpty { goalExtras[key] = extra }
            return GoalRecord(key: key, title: goal.text("title"), details: goal.text("details"))
        }
        var categoryExtras: [String: [String: JSONValue]] = [:]
        categories = f.objects("categories").compactMap { category in
            guard let key = category.optional("key") else { return nil }
            let extra = category.object.filter { !GoalSegment.categoryFieldNames.contains($0.key) }
            if !extra.isEmpty { categoryExtras[key] = extra }
            return CategoryRecord(key: key, goalKey: category.optional("goal") ?? String(key.split(separator: ".").first ?? ""),
                                  title: category.text("title"), details: category.text("details"))
        }
        self.goalExtras = goalExtras
        self.categoryExtras = categoryExtras
        createdAt = f.date("createdAt") ?? f.date("modifiedAt") ?? Date(timeIntervalSince1970: 0)
        modifiedAt = f.date("modifiedAt") ?? createdAt
        deletedAt = f.date("deletedAt")
        unknown = GoalSegment.unknownFields(in: object)
    }

    public var fields: [String: JSONValue] {
        var w = FieldWriter()
        w.set("id", id)
        w.set("title", title)
        w.set("period", periodStart)
        w.set("startWeek", startWeek)
        w.set("reason", reason)
        w.set("goals", objects: goals.map { goal in
            var g = FieldWriter(object: goalExtras[goal.key] ?? [:])
            g.set("key", goal.key)
            g.set("title", goal.title)
            g.set("details", goal.details)
            return g.object
        })
        w.set("categories", objects: categories.map { category in
            var c = FieldWriter(object: categoryExtras[category.key] ?? [:])
            c.set("key", category.key)
            c.set("goal", category.goalKey)
            c.set("title", category.title)
            c.set("details", category.details)
            return c.object
        })
        w.set("createdAt", createdAt)
        w.set("modifiedAt", modifiedAt)
        w.set("deletedAt", deletedAt)
        return w.object
    }

    public init(from decoder: Decoder) throws { try self.init(settingFrom: decoder) }
    public func encode(to encoder: Encoder) throws { try encodeSetting(to: encoder) }

    /// The id of the goal year's first segment ("Abschnitt 1"), the same on every device: it exists
    /// without being stored, and storing it (with its snapshot, when the second one begins) keeps the
    /// targets and results that point to it.
    public static func firstID(period: GoalPeriod) -> String { "first-\(period.start.string)" }

    /// The first segment stored with a snapshot (when "Neuen Abschnitt beginnen…" ends the implicit one).
    public static func first(period: GoalPeriod, goals: [GoalRecord], categories: [CategoryRecord], now: Date = Date()) -> GoalSegment {
        GoalSegment(id: firstID(period: period), title: "Abschnitt 1", periodStart: period.start, startWeek: period.start.week,
                    goals: goals, categories: categories, createdAt: now)
    }
}

/// A segment as it counts: from its start week through the week before the next one.
public struct SegmentSpan: Equatable, Sendable {
    public var id: String
    /// 1, 2, 3 … in the goal year.
    public var number: Int
    /// "Abschnitt 2"
    public var title: String
    public var startWeek: WeekKey
    public var endWeek: WeekKey
    /// The first counted day (the goal year's start for the first segment).
    public var startDay: DayKey
    /// The last counted day (the goal year's end for the last one).
    public var endDay: DayKey
    public var reason: String
    /// The goals and categories when it began (empty for the implicit first segment).
    public var goals: [GoalRecord]
    public var categories: [CategoryRecord]
    /// Stored as a record (false: the implicit first segment).
    public var isStored: Bool

    public init(id: String, number: Int, title: String, startWeek: WeekKey, endWeek: WeekKey, startDay: DayKey, endDay: DayKey,
                reason: String = "", goals: [GoalRecord] = [], categories: [CategoryRecord] = [], isStored: Bool = false) {
        self.id = id
        self.number = number
        self.title = title
        self.startWeek = startWeek
        self.endWeek = endWeek
        self.startDay = startDay
        self.endDay = endDay
        self.reason = reason
        self.goals = goals
        self.categories = categories
        self.isStored = isStored
    }

    public func contains(_ week: WeekKey) -> Bool { week >= startWeek && week <= endWeek }
    public func contains(_ day: DayKey) -> Bool { day >= startDay && day <= endDay }

    /// Weeks from start to end.
    public var weekCount: Int { (endWeek.monday.ordinal - startWeek.monday.ordinal) / 7 + 1 }
    public var dayCount: Int { endDay.ordinal - startDay.ordinal + 1 }

    /// Week number within the segment (1 = its start week).
    public func weekNumber(of week: WeekKey) -> Int { (week.monday.ordinal - startWeek.monday.ordinal) / 7 + 1 }

    /// 0…1 through the segment on `day`.
    public func progress(on day: DayKey) -> Double {
        min(1, max(0, Double(day.ordinal - startDay.ordinal + 1) / Double(max(1, dayCount))))
    }

    /// "Abschnitt 2 · seit KW50"
    public var label: String { "\(title) · seit \(startWeek.label)" }

    /// "Abschnitt 2 · seit KW50 · Woche 3" – the year card's head (§1.4.3).
    public func headline(week: WeekKey) -> String {
        guard contains(week) else { return label }
        return "\(label) · Woche \(weekNumber(of: week))"
    }

    /// "KW23–KW49" (with the year when it changes: "KW50 2026 – KW21 2027").
    public var weeksLabel: String {
        if startWeek == endWeek { return startWeek.label }
        if startWeek.year == endWeek.year { return "\(startWeek.label)–\(endWeek.label)" }
        return "\(startWeek.longLabel) – \(endWeek.longLabel)"
    }
}

/// The segments of one goal year, gapless and sorted.
public struct Segments: Equatable, Sendable {
    public var period: GoalPeriod
    public var spans: [SegmentSpan]

    public init(period: GoalPeriod, spans: [SegmentSpan]) {
        self.period = period
        self.spans = spans
    }

    /// The segments of `period` from the stored ones: only those of this goal year, not in the trash;
    /// a start before the year counts as its first week, one after its end is left out; two on the same
    /// week → the newest. Without one at the year's first week, "Abschnitt 1" covers the time before the
    /// first stored one (or the whole year). Each ends the week before the next one starts.
    public static func resolve(_ stored: [GoalSegment], period: GoalPeriod) -> Segments {
        let first = period.start.week
        let last = period.end.week
        var byWeek: [WeekKey: GoalSegment] = [:]
        for segment in stored where segment.deletedAt == nil && segment.periodStart == period.start {
            let start = max(segment.startWeek, first)
            guard start <= last else { continue }
            if let current = byWeek[start], (current.modifiedAt, current.id) >= (segment.modifiedAt, segment.id) { continue }
            byWeek[start] = segment
        }
        var starts: [(WeekKey, GoalSegment?)] = byWeek.keys.sorted().map { ($0, byWeek[$0]) }
        if starts.first?.0 != first { starts.insert((first, nil), at: 0) }
        var spans: [SegmentSpan] = []
        for (index, entry) in starts.enumerated() {
            let (start, segment) = entry
            let next = index + 1 < starts.count ? starts[index + 1].0 : nil
            let endWeek = next.map { $0.adding(weeks: -1) } ?? last
            let startDay = max(start.monday, period.start)
            let endDay = next.map { $0.monday.adding(days: -1) } ?? period.end
            let number = index + 1
            let stored = segment?.title.trimmingCharacters(in: .whitespaces) ?? ""
            let title = stored.isEmpty ? "Abschnitt \(number)" : stored
            spans.append(SegmentSpan(id: segment?.id ?? GoalSegment.firstID(period: period), number: number, title: title,
                                     startWeek: start, endWeek: endWeek, startDay: startDay, endDay: endDay,
                                     reason: segment?.reason ?? "", goals: segment?.goals ?? [], categories: segment?.categories ?? [],
                                     isStored: segment != nil))
        }
        return Segments(period: period, spans: spans)
    }

    public func span(for week: WeekKey) -> SegmentSpan? { spans.first { $0.contains(week) } }
    public func span(for day: DayKey) -> SegmentSpan? { spans.first { $0.contains(day) } }
    public func span(id: String) -> SegmentSpan? { spans.first { $0.id == id } }

    /// The segment of `today` (the last one after the year's end, the first one before its start).
    public func current(today: DayKey) -> SegmentSpan? {
        if let span = span(for: today) { return span }
        if today > period.end { return spans.last }
        return spans.first
    }

    /// The segments before the current one, newest first ("Frühere Abschnitte").
    public func earlier(today: DayKey) -> [SegmentSpan] {
        guard let current = current(today: today) else { return [] }
        return spans.filter { $0.number < current.number }.reversed()
    }

    /// More than one segment: screens name them ("davon 4 in Abschnitt 2").
    public var hasSeveral: Bool { spans.count > 1 }

    /// Grundregel 2: a week before the start of the current segment is never scored again automatically
    /// (only "Neu berechnen" in the week). Weeks of earlier goal years too. Before the goal year starts
    /// nothing is frozen. One grace: during the current segment's first week the week right before it
    /// is not frozen yet – it was closed only just now (often on the Mac, without Apple Health), and the
    /// iPhone's catch-up and late entries on Monday still give it its proper score. A segment begun back
    /// in time (its first week is over) freezes the weeks before it at once.
    public func isFrozen(_ week: WeekKey, today: DayKey) -> Bool {
        guard today >= period.start, let current = current(today: today) else { return false }
        if today.week == current.startWeek, week == current.startWeek.adding(weeks: -1) { return false }
        return week < current.startWeek
    }

    /// The labels of a week (§1.4.1 "Bezeichnungen alter Wochen aus dem Schnappschuss"): a week of an
    /// earlier segment shows the goals and categories as they were at that segment's end – the snapshot
    /// the next segment took when it began (else its own); the current segment and weeks outside the
    /// year show `live`. Goals or categories missing from a snapshot keep their live label.
    public func labels(for week: WeekKey, today: DayKey, goals live: [GoalRecord], categories liveCategories: [CategoryRecord])
        -> (goals: [GoalRecord], categories: [CategoryRecord]) {
        guard let index = spans.firstIndex(where: { $0.contains(week) }), let current = current(today: today),
              spans[index].number < current.number else { return (live, liveCategories) }
        let later = spans[(index + 1)...].first { !$0.goals.isEmpty || !$0.categories.isEmpty }
        let snapshot = later ?? spans[index]
        let goalTitles = Dictionary(snapshot.goals.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        let categoryTitles = Dictionary(snapshot.categories.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
        var goals = live.map { goalTitles[$0.key] ?? $0 }
        for goal in snapshot.goals where !live.contains(where: { $0.key == goal.key }) { goals.append(goal) }
        var categories = liveCategories.map { categoryTitles[$0.key] ?? $0 }
        for category in snapshot.categories where !liveCategories.contains(where: { $0.key == category.key }) { categories.append(category) }
        return (goals.sortedByNumber(), categories.sortedByKey())
    }

    /// The next segment after the current one – planned, not begun yet (it starts after today); nil
    /// without one. Right after "Neuen Abschnitt beginnen…" with the default start (next week) this is
    /// the new segment: its targets and new results are set here before it begins.
    public func upcoming(today: DayKey) -> SegmentSpan? {
        guard let current = current(today: today) else { return nil }
        return spans.first { $0.number > current.number && $0.startDay > today }
    }

    /// Stored segments of this goal year (not in the trash) that `resolve` doesn't show – two begun on the
    /// same week (two devices, or a planned one begun again): only the newest counts. The settings list
    /// them so they can be deleted.
    public static func hidden(_ stored: [GoalSegment], period: GoalPeriod) -> [GoalSegment] {
        let shown = Set(resolve(stored, period: period).spans.filter(\.isStored).map(\.id))
        return stored.filter { $0.deletedAt == nil && $0.periodStart == period.start && !shown.contains($0.id) }
            .sorted { ($0.startWeek, $0.modifiedAt) < ($1.startWeek, $1.modifiedAt) }
    }

    // MARK: "Neuen Abschnitt beginnen…" (§1.4.2)

    /// The earliest start week: one week after the current segment's start – and after the start of a
    /// segment already planned (`upcoming`), so a second "Neuen Abschnitt beginnen…" never offers the
    /// week of one that exists.
    public func earliestStart(today: DayKey) -> WeekKey {
        let currentStart: WeekKey = current(today: today)?.startWeek ?? period.start.week
        let lastStart: WeekKey = spans.last?.startWeek ?? currentStart
        return max(currentStart, lastStart).adding(weeks: 1)
    }

    /// The default start: next week (not before the earliest start, not after the year's last week).
    public func defaultStart(today: DayKey) -> WeekKey {
        min(max(today.week.adding(weeks: 1), earliestStart(today: today)), period.end.week)
    }

    /// The start weeks to offer: from the earliest start (back in time allowed) to the year's last week.
    public func startChoices(today: DayKey) -> [WeekKey] {
        var result: [WeekKey] = []
        var week = earliestStart(today: today)
        while week <= period.end.week, result.count < 60 {
            result.append(week)
            week = week.adding(weeks: 1)
        }
        return result
    }

    /// A new segment may start in `week`.
    public func canStart(_ week: WeekKey, today: DayKey) -> Bool {
        week >= earliestStart(today: today) && week <= period.end.week
    }

    /// "Abschnitt 3" – the title for the next new segment (it starts after every existing one, see
    /// `earliestStart`, so it gets the next number).
    public func nextTitle(today: DayKey) -> String { "Abschnitt \(spans.count + 1)" }
}
