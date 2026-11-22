import Foundation

// v10 demo content (TASKS-v10 §1.7.2) – only for `-Demo` and the tour's practice page, never for the
// real store (Grundregel 5): two segments (the first ended six weeks ago), results (a count of books
// from the list, a tick, a value from a measure with its own target in segment 2), three books (one
// finished in segment 1, one running with readings on three days, one planned), category week scores
// of the paper weeks, and the inbox of a connected app "Demo" (two power-hours – one without a
// category –, a workout, kcal and protein) as the exchange fixtures `Fixtures/exchange/Demo` have it.
// Neutral titles only.

extension Demo {
    /// The v10 records of the demo, typed and as settings (`rows`, also the document's `record` rows).
    public struct Records: Equatable, Sendable {
        public var period: GoalPeriod
        public var segments: [GoalSegment]
        public var results: [GoalResult]
        public var entries: [GoalEntry]
        public var items: [ListItem]
        public var progress: [ListProgress]
        public var scores: [GoalTrack.Week]
        public var inbox: [ExchangeDayFile]
        public var sources: ExchangeSourceList
        /// Everything above as settings (key, value).
        public var rows: [SettingRow]

        public init(period: GoalPeriod, segments: [GoalSegment] = [], results: [GoalResult] = [], entries: [GoalEntry] = [],
                    items: [ListItem] = [], progress: [ListProgress] = [], scores: [GoalTrack.Week] = [], inbox: [ExchangeDayFile] = [],
                    sources: ExchangeSourceList = ExchangeSourceList(), rows: [SettingRow] = []) {
            self.period = period
            self.segments = segments
            self.results = results
            self.entries = entries
            self.items = items
            self.progress = progress
            self.scores = scores
            self.inbox = inbox
            self.sources = sources
            self.rows = rows
        }
    }

    /// The connected app of the demo.
    public static let exchangeSource = "demo"
    /// The demo's measure counting workouts from the connected app (linked to "Krafttraining").
    public static let workoutMeasure = "workouts"
    /// The item linked to it.
    public static let workoutItem = "1.2-01"
    /// Ids of the demo's results.
    public static let booksResult = "demo-result-books"
    public static let websiteResult = "demo-result-website"
    public static let weightResult = "demo-result-weight"

    /// The goal year the demo's segments and results belong to: the foundation year while `today` is in
    /// it, else the year from 1 June that holds `today`.
    public static func period(today: DayKey) -> GoalPeriod {
        let foundation = GoalPeriod.foundationYear
        if today >= foundation.start && today <= foundation.end { return foundation }
        let year = today.month >= 6 ? today.year : today.year - 1
        let start = DayKey(year: year, month: 6, day: 1)
        return GoalPeriod(start: start, end: DayKey(year: year + 1, month: 5, day: 31), reviewWeek: start.adding(days: 190).week,
                          motto: foundation.motto)
    }

    /// The week segment 2 starts in: five weeks before `today`'s – segment 1 ended six weeks ago.
    public static func secondSegmentStart(today: DayKey) -> WeekKey { today.week.adding(weeks: -5) }

    /// The day the demo's workout is on: the latest day of `today`'s week up to today on which
    /// "Krafttraining" is due and that isn't sick.
    static func workoutDay(today: DayKey, item: ItemRecord?, excused: Set<DayKey>) -> DayKey? {
        guard let item else { return nil }
        return today.week.days.filter { $0 <= today && item.applies(on: $0) && !excused.contains($0) }.last
    }

    /// The latest work day (Mon–Fri) of `today`'s week up to today that isn't sick.
    static func workDay(today: DayKey, excused: Set<DayKey>) -> DayKey? {
        today.week.days.filter { $0 <= today && $0.weekday.rawValue <= 5 && !excused.contains($0) }.last
    }

    /// Adds the v10 content to the demo document (measures and the link of the current week, the
    /// records as `record` rows) and returns it typed.
    static func addV10(_ doc: inout PlanCSV.Document, today: DayKey, history: Bool) -> Records {
        let week = today.week
        let period = Demo.period(today: today)
        let stamp = today.adding(days: -1).date(minutes: 20 * 60)
        var records = Records(period: period)

        // The current week: measures from the connected app, "Krafttraining" linked to the workouts.
        let position = (doc.measures.filter { $0.week == week }.map(\.position).max() ?? 0) + 1
        doc.measures.append(MeasureRecord(week: week, code: workoutMeasure, categoryKey: "1.2", position: position, title: "Workouts",
                                          details: "Aus der verbundenen App.", unit: "Stück",
                                          source: .app(AppSource(source: exchangeSource, kind: "workout", ref: "tpl-push"))))
        doc.measures.append(MeasureRecord(week: week, code: "kalorien", categoryKey: "1.1", position: position + 1, title: "Kalorien",
                                          unit: "kcal", source: .app(AppSource(source: exchangeSource, kind: "kcal")), secondary: true))
        doc.measures.append(MeasureRecord(week: week, code: "protein", categoryKey: "1.1", position: position + 2, title: "Protein",
                                          unit: "g", target: Target.parse(">=150"), source: .app(AppSource(source: exchangeSource, kind: "protein_g")),
                                          secondary: true))
        let types = Dictionary(doc.days.map { ($0.day, $0.dayType) }, uniquingKeysWith: { _, last in last })
        let excused = DayTypes.excusedDays(week.days) { types[$0] ?? "" }
        var linked: ItemRecord?
        if let index = doc.items.firstIndex(where: { $0.week == week && $0.code == workoutItem }) {
            doc.items[index].measure = workoutMeasure
            linked = doc.items[index]
        }
        let workout = workoutDay(today: today, item: linked, excused: excused)
        // The tick on the workout's day comes from the app – no own mark there.
        if let workout { doc.marks.removeAll { $0.week == week && $0.itemCode == workoutItem && $0.day == workout } }

        // Segments: "Abschnitt 1" (stored with its snapshot) and "Abschnitt 2" since five weeks.
        let first = GoalSegment.first(period: period, goals: Template.goals, categories: Template.categories,
                                      now: period.start.date(minutes: 9 * 60))
        records.segments = [first]
        let secondStart = secondSegmentStart(today: today)
        var second: GoalSegment?
        if secondStart > period.start.week && secondStart <= period.end.week {
            let created = secondStart.monday.adding(days: -1).date(minutes: 18 * 60)
            let segment = GoalSegment(id: "demo-segment-2", title: "Abschnitt 2", periodStart: period.start, startWeek: secondStart,
                                      reason: "Zielüberprüfung: Ziele nachgeschärft", goals: Template.goals, categories: Template.categories,
                                      createdAt: created)
            records.segments.append(segment)
            second = segment
        }

        // Results: books from the list, a tick, a value from a measure (with its own target in segment 2).
        let created = period.start.date(minutes: 10 * 60)
        records.results = [
            GoalResult(id: booksResult, periodStart: period.start, goalKey: "5", title: "Bücher gelesen", kind: .count, target: ">=10",
                       unit: "Bücher", source: "list", position: 1, createdAt: created, modifiedAt: created),
            GoalResult(id: websiteResult, periodStart: period.start, goalKey: "3", title: "Website online", kind: .check, position: 2,
                       createdAt: created, modifiedAt: created),
            GoalResult(id: weightResult, periodStart: period.start, goalKey: "1", title: "Gewicht", kind: .value, target: "<=85",
                       targets: second.map { [$0.id: "<=86"] } ?? [:], start: 89, unit: "kg", source: "measure:gewicht", position: 3,
                       createdAt: created, modifiedAt: created),
        ]
        let doneOn = max(period.start, today.adding(days: -10))
        records.entries = [GoalEntry(id: "demo-entry-website", day: doneOn, resultID: websiteResult, note: "Neue Startseite veröffentlicht",
                                     modifiedAt: doneOn.date(minutes: 17 * 60))]

        // Three books: finished in segment 1, running (readings on three days), planned.
        let segmentOneEnd = (second?.startWeek.monday ?? today).adding(days: -1)
        let finished = max(period.start, segmentOneEnd.adding(days: -10))
        let started = max(period.start, finished.adding(days: -24))
        let running = max(period.start, today.adding(days: -6))
        records.items = [
            ListItem(id: "demo-book-1", title: "Kleine Schritte", subtitle: "Autorin A", total: 240, startedOn: started, finishedOn: finished,
                     resultID: booksResult, position: 1, createdAt: started.date(minutes: 8 * 60), modifiedAt: finished.date(minutes: 21 * 60)),
            ListItem(id: "demo-book-2", title: "Klarer Kopf", subtitle: "Autor B", total: 320, startedOn: running, resultID: booksResult,
                     position: 2, createdAt: running.date(minutes: 8 * 60), modifiedAt: stamp),
            ListItem(id: "demo-book-3", title: "Lange Wege", subtitle: "Autorin C", total: 410, position: 3,
                     createdAt: running.date(minutes: 9 * 60), modifiedAt: running.date(minutes: 9 * 60)),
        ]
        records.progress = [
            ListProgress(id: "demo-reading-1", day: started.adding(days: 8), itemID: "demo-book-1", reached: 110,
                         modifiedAt: started.adding(days: 8).date(minutes: 21 * 60)),
            ListProgress(id: "demo-reading-2", day: finished, itemID: "demo-book-1", reached: 240, modifiedAt: finished.date(minutes: 21 * 60)),
        ]
        for (index, (offset, page)) in [(-5, 40.0), (-3, 95.0), (-1, 120.0)].enumerated() {
            let day = max(running, today.adding(days: offset))
            records.progress.append(ListProgress(id: "demo-reading-\(index + 3)", day: day, itemID: "demo-book-2", reached: page,
                                                 modifiedAt: day.date(minutes: 21 * 60 + Double(index))))
        }

        // Category week scores of the paper weeks (Rückblick, "Wochen über 8").
        if history {
            for offset in 3...10 {
                let old = week.adding(weeks: -offset)
                var scores: [String: Double] = [:]
                for category in Template.categories {
                    var rng = Random(seed: "score|\(old.string)|\(category.key)")
                    scores[category.key] = (60 + (rng.unit() * 38).rounded()) / 10
                }
                records.scores.append(GoalTrack.Week(week: old, scores: scores))
            }
        }

        // The inbox of the connected app "Demo".
        records.inbox = exchangeInbox(today: today, workout: workout, workDay: workDay(today: today, excused: excused))
        records.sources = ExchangeSourceList(sources: [exchangeSourceInfo(today: today)])

        var rows: [SettingRow] = []
        rows += records.segments.map { SettingRow(key: $0.settingKey, value: $0.settingValue) }
        rows += records.results.map { SettingRow(key: $0.settingKey, value: $0.settingValue) }
        rows += records.entries.map { SettingRow(key: $0.settingKey, value: $0.settingValue) }
        rows += records.items.map { SettingRow(key: $0.settingKey, value: $0.settingValue) }
        rows += records.progress.map { SettingRow(key: $0.settingKey, value: $0.settingValue) }
        rows += records.scores.map { SettingRow(key: GoalTrack.settingKey($0.week), value: GoalTrack.text($0.scores)) }
        rows += records.inbox.compactMap { file in
            DayKey(file.day).map { SettingRow(key: ExchangeInbox.settingKey(source: file.source, day: $0), value: ExchangeInbox.value(file)) }
        }
        rows.append(SettingRow(key: ExchangeInbox.sourcesKey, value: records.sources.value))
        records.rows = rows.sorted { $0.key < $1.key }
        return records
    }

    /// The demo app's `source.json` (its heartbeat with the refs of its workout and groups).
    public static func exchangeSourceInfo(today: DayKey, timeZone: TimeZone = .current) -> ExchangeSourceInfo {
        ExchangeSourceInfo(source: exchangeSource, app: "Demo", appVersion: "1.0",
                           generatedAt: ExchangeDate.string(today.date(minutes: 20 * 60, timeZone: timeZone), timeZone: timeZone), refs: [
                               ExchangeRef(id: "tpl-push", title: "Push", kind: "workout"),
                               ExchangeRef(id: "grp-projekt", title: "Projekt", kind: "group"),
                               ExchangeRef(id: "grp-verein", title: "Sport / Verein", kind: "group"),
                           ])
    }

    /// The demo app's day files: a workout ("Push") on `workout`, two power-hours on `workDay` (one
    /// for 3.2 chosen in the app, one without a category), kcal and protein today. The fixture files
    /// `Tests/ThaliaCoreTests/Fixtures/exchange/Demo/exchange/` are this for Sunday 22 Nov. 2026 in
    /// Europe/Vienna (a test keeps both equal); the demo builds them for its own `today`.
    public static func exchangeInbox(today: DayKey, workout: DayKey?, workDay: DayKey?, timeZone: TimeZone = .current) -> [ExchangeDayFile] {
        var facts: [DayKey: [ExchangeFact]] = [:]
        func at(_ day: DayKey, _ minutes: Double) -> String {
            ExchangeDate.string(day.date(minutes: minutes, timeZone: timeZone), timeZone: timeZone)
        }
        if let workout {
            facts[workout, default: []].append(ExchangeFact(id: "demo-workout-\(workout.string)", kind: ExchangeKind.workoutDone.rawValue,
                                                            ref: "tpl-push", refTitle: "Push", title: "Push", at: at(workout, 18 * 60)))
        }
        if let workDay {
            facts[workDay, default: []].append(ExchangeFact(id: "demo-ph-\(workDay.string)-1", kind: ExchangeKind.powerHours.rawValue,
                                                            ref: "grp-projekt", refTitle: "Projekt", title: "Landingpage", value: 1, unit: "PH",
                                                            at: at(workDay, 11 * 60),
                                                            thalia: ExchangeThaliaHint(category: "3.2", categoryTitle: "stammloop")))
            facts[workDay, default: []].append(ExchangeFact(id: "demo-ph-\(workDay.string)-2", kind: ExchangeKind.powerHours.rawValue,
                                                            ref: "grp-verein", refTitle: "Sport / Verein", title: "Vereinsabend vorbereitet",
                                                            value: 0.5, unit: "PH", at: at(workDay, 16 * 60)))
        }
        facts[today, default: []].append(ExchangeFact(id: "demo-kcal-\(today.string)", kind: ExchangeKind.value.rawValue, ref: "kcal",
                                                      refTitle: "Kalorien", value: 1850, unit: "kcal", metric: "kcal", at: at(today, 19 * 60)))
        facts[today, default: []].append(ExchangeFact(id: "demo-protein-\(today.string)", kind: ExchangeKind.value.rawValue, ref: "protein_g",
                                                      refTitle: "Protein", value: 120, unit: "g", metric: "protein_g", at: at(today, 19 * 60)))
        return facts.keys.sorted().map { day in
            ExchangeDayFile(source: exchangeSource, day: day.string, generatedAt: at(day, 20 * 60), facts: facts[day] ?? [])
        }
    }
}
