import Foundation
import BinisoftKitCore

/// Everything one week's report needs.
public struct WeekReportInput: Sendable {
    public var week: WeekRecord
    public var goals: [GoalRecord]
    public var categories: [CategoryRecord]
    public var items: [ItemRecord]
    public var measures: [MeasureRecord]
    public var marks: [MarkRecord]
    public var overrides: [ScoreRecord]
    public var days: [DayRecord]
    public var entries: [EntryRecord]
    public var work: [WorkRecord]
    public var notes: [NoteRecord]
    public var reviews: [ReviewRecord]
    public var changes: [PlanChangeRecord]
    public var closedDays: Set<DayKey>
    public var isClosed: Bool
    public var today: DayKey
    /// v10: the annual goals' results (no Health values) – the block "Jahresziel-Ergebnisse"; empty = no block.
    public var results: [GoalResultLine]

    public init(week: WeekRecord, goals: [GoalRecord], categories: [CategoryRecord], items: [ItemRecord], measures: [MeasureRecord],
                marks: [MarkRecord], overrides: [ScoreRecord] = [], days: [DayRecord] = [], entries: [EntryRecord] = [],
                work: [WorkRecord] = [], notes: [NoteRecord] = [], reviews: [ReviewRecord] = [], changes: [PlanChangeRecord] = [],
                closedDays: Set<DayKey> = [], isClosed: Bool = false, today: DayKey, results: [GoalResultLine] = []) {
        self.results = results
        self.week = week
        self.goals = goals
        self.categories = categories
        self.items = items.filter { $0.week == week.week }
        self.measures = measures.filter { $0.week == week.week }
        self.marks = marks.filter { $0.week == week.week }
        self.overrides = overrides.filter { week.week.contains($0.day) }
        self.days = days.filter { week.week.contains($0.day) }
        self.entries = entries.filter { week.week.contains($0.day) }
        self.work = work.filter { week.week.contains($0.day) }
        self.notes = notes.filter { week.week.contains($0.day) }
        let scopes = Set([week.week.string] + week.week.days.map(\.string))
        self.reviews = reviews.filter { scopes.contains($0.scope) }
        self.changes = changes.filter { $0.week == week.week }
        self.closedDays = closedDays
        self.isClosed = isClosed
        self.today = today
    }

    public var weekData: WeekData {
        var marksByKey: [String: Mark] = [:]
        for mark in marks { if let value = mark.mark { marksByKey[WeekData.markKey(mark.itemCode, mark.day)] = value } }
        var overridesByKey: [String: Double] = [:]
        for score in overrides { overridesByKey[WeekData.overrideKey(score.categoryKey, score.day)] = score.score }
        var progress: [String: Double] = [:]
        var worked: [String: Set<DayKey>] = [:]
        let free = workFreeDays
        let excused = excusedDays
        let workCategories = WeekData.workCategories(items: items.filter { $0.week == week.week }, categories: categories)
        // v11 P1.13: items linked to a `list:`/`app:` text directly have a hidden measure (as in `WeekExtras`) –
        // only for the progress here; "Messwerte" and the weekly targets list `measures` as before.
        let all = measures + ExchangeDerivation.virtualMeasures(items: items, measures: measures)
        for item in items {
            if let ratio = Measures.progressRatio(for: item, measures: all, days: week.week.days, entries: entries, work: work,
                                                  excused: excused, workFree: free, workCategories: workCategories) {
                progress[item.code] = ratio
            }
            worked[item.code] = Measures.workedDays(for: item, measures: all, days: week.week.days, entries: entries, work: work)
        }
        return WeekData(week: week.week, goals: goals, categories: categories, items: items, marks: marksByKey,
                        overrides: overridesByKey, isComplete: Scorer.isComplete(week: week.week, today: today, closed: isClosed),
                        progress: progress, worked: worked, workFreeDays: free, excusedDays: excused)
    }

    /// Days without work (Familientag, Erholungstag, Urlaub …).
    public var workFreeDays: Set<DayKey> { Set(days.filter { DayTypes.isWorkFree($0.dayType) }.map(\.day)) }

    /// Sick and holiday days (v8).
    public var excusedDays: Set<DayKey> { Set(days.filter { DayTypes.isExcused($0.dayType) }.map(\.day)) }
}

public enum WeekReport {
    /// The week as text for the next planning conversation: the score and the reality behind it.
    public static func markdown(_ input: WeekReportInput) -> String {
        let week = input.week.week
        let data = input.weekData
        let score = Scorer.score(data)
        let goals = input.goals.sortedByNumber()
        let categories = input.categories.sortedByKey()
        var out: [String] = []

        out.append("# Wochenbericht \(week.longLabel) (\(week.rangeLabel))")
        if !input.week.title.isEmpty { out.append("Motto: \(input.week.title)") }
        let status = input.isClosed ? "Woche abgeschlossen" : "Woche noch offen (Stand \(input.today.shortLabel))"
        if score.isExcused {
            out.append("**\(WeekScore.excusedText)** · \(status)")
        } else if let overall = score.overall {
            out.append("**Wochenwertung: \(Format.score(overall))/10** · \(score.coverageText) · Jahresziele (gleich gewichtet) · \(status)")
        } else {
            out.append("Noch keine Wertung (Kategorien nicht vollständig ausgefüllt) · \(status)")
        }
        let excusedDays = week.days.filter(score.excusedDays.contains)
        if !excusedDays.isEmpty {
            let list = excusedDays.map { day in "\(day.weekday.short) \(input.days.first { $0.day == day }?.dayType ?? "")" }
            out.append("Krank/Urlaub: \(list.joined(separator: ", ")) – diese Tage zählen nicht; was deshalb von einem Wochenziel fehlt, zählt halb.")
        }
        out.append("Hinweis: Die Wertung misst Verhalten, nicht Ergebnisse. Ein Jahresziel bekommt nur eine Wertung, wenn alle seine Kategorien ausgefüllt sind.")
        out.append("")

        out.append("## Jahresziele")
        out.append("| Ziel | Woche | Kategorien |")
        out.append("|---|---|---|")
        for goal in goals {
            let parts = categories.filter { $0.goalKey == goal.key }.map { category in
                "\(category.key) \(category.title) \(Format.score(score.categoryWeek[category.key], outOf: false))"
            }
            out.append("| \(goal.label) | \(Format.score(score.goalWeek[goal.key]?.score, outOf: false)) | \(parts.joined(separator: " · ")) |")
        }
        out.append("")
        // v10: where the goals' results stand – only for information, no reason to raise the plan.
        out.append(contentsOf: GoalResultLine.block(input.results))

        out.append("## Tage")
        out.append("| Tag | Typ | Wertung | Ausgefüllt | Abschluss | Journal | Notiz |")
        out.append("|---|---|---|---|---|---|---|")
        let journalItem = input.items.first { ReflectionQuestion.isJournalTitle($0.title) }
        for day in week.days {
            let info = input.days.first { $0.day == day }
            let overall = score.days[day]
            let journal = journalSymbol(input, data: data, item: journalItem, day: day)
            let dayScore = data.isExcused(day) ? "zählt nicht" : Format.score(overall?.score, outOf: false)
            out.append("| \(day.shortLabel) | \(info?.dayType ?? "") | \(dayScore) | \(overall?.coverageText ?? "–") | \(input.closedDays.contains(day) ? "✓" : "–") | \(journal) | \(info?.note ?? "") |")
        }
        out.append("")

        out.append("## Arbeit (Power-Hours, 1 PH = 50 min)")
        let totals = WorkTotals(input.work)
        out.append(totals.explanation)
        for (category, sub) in WorkTotals.byCategory(input.work).sorted(by: { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }) {
            let title = categories.first { $0.key == category }?.title ?? category
            let what = Set(input.work.filter { $0.categoryKey == category && !$0.task.isEmpty }.map(\.task)).sorted().prefix(6)
            out.append("- \(category) \(title): \(sub.shortText)" + (what.isEmpty ? "" : " (\(what.joined(separator: ", ")))"))
        }
        let results = input.work.filter { !$0.result.isEmpty }.sorted { ($0.day, $0.id) < ($1.day, $1.id) }
        if !results.isEmpty {
            out.append("")
            out.append("Ergebnisse:")
            for block in results {
                var line = "- \(block.day.shortLabel) · \(block.categoryKey) \(block.task): \(block.result)"
                if !block.nextStep.isEmpty { line += " → nächster Schritt: \(block.nextStep)" }
                out.append(line)
            }
        }
        out.append("")

        if !input.measures.isEmpty {
            out.append("## Messwerte")
            for measure in input.measures.sorted(by: { $0.position < $1.position }) {
                let value = Measures.weekValue(measure, days: week.days, entries: input.entries, work: input.work)
                var line = "- \(measure.title): "
                guard let value else {
                    out.append(line + "nicht erfasst")
                    continue
                }
                let shown = Format.measure(value, unit: measure.unit)
                let recordedDays = week.days.filter { Measures.dayValue(measure, on: $0, entries: input.entries, work: input.work) != nil }
                if measure.period == .week || measure.aggregation == .sum && measure.target == nil {
                    line += "\(shown) in der Woche"
                    if let target = measure.target, measure.period == .week {
                        let share = Measures.targetShare(for: measure, week: week, excused: data.excusedDays, workFree: data.workFreeDays,
                                                         workCategories: data.workCategories)
                        if share <= 1e-9 {
                            // v8: every day of the measurement was a sick or holiday day – not scored.
                            line += " (Ziel \(target.label) – nicht bewertet, alle Tage Krank/Urlaub)"
                        } else {
                            let effective = Measures.effectiveTarget(target, share: share)
                            let scaled = effective == target ? "" : " anteilig wegen Krank/Urlaub"
                            // v11 P1.7: shown like on screen (86, not 85,71) – "erreicht" from the exact value; P1.16:
                            // the same status word as on screen.
                            let state = WeekReport.targetStatus(measure, target: effective, value: value, input: input, data: data)
                            line += " (Ziel \(WeekReport.targetText(effective, unit: measure.unit))\(scaled) – \(state))"
                        }
                    }
                } else {
                    let average = measure.aggregation == .sum ? value / Double(max(1, recordedDays.count)) : value
                    line += "Ø \(Format.measure(average, unit: measure.unit))"
                    if let target = measure.target {
                        let met = recordedDays.filter { Measures.isMet(measure, value: Measures.dayValue(measure, on: $0, entries: input.entries, work: input.work)) == true }.count
                        line += " (Ziel \(target.label): an \(met) von \(recordedDays.count) Tagen)"
                    }
                }
                out.append(line)
            }
            out.append("")
        }

        let missed = missedCommitments(input, data: data)
        out.append("## Verpasste Zusagen")
        out.append(contentsOf: missed.isEmpty ? ["Keine."] : missed.map { "- \($0)" })
        let blanks = week.days.reduce(0) { $0 + (score.days[$1]?.blank ?? 0) }
        if blanks > 0 {
            out.append("- Nicht ausgefüllt: \(Format.count(blanks, "fälliger Punkt", "fällige Punkte")) (weder Haken noch N/A) – kein automatisches Versäumnis.")
        }
        if !input.overrides.isEmpty {
            out.append("")
            out.append("Eigene Wertungen:")
            for override in input.overrides.sorted(by: { ($0.day, $0.categoryKey) < ($1.day, $1.categoryKey) }) {
                out.append("- \(override.day.shortLabel) · \(override.categoryKey): \(Format.score(override.score))\(override.reason.isEmpty ? "" : " – \(override.reason)")")
            }
        }
        out.append("")

        if !input.changes.isEmpty {
            out.append("## Änderungen am Plan in dieser Woche")
            out.append(contentsOf: input.changes.map { "- \($0.line)" })
            out.append("")
        }

        if !input.notes.isEmpty {
            out.append("## Notizen")
            for note in input.notes.sorted(by: { ($0.day, $0.id) < ($1.day, $1.id) }) {
                out.append("- \(note.day.shortLabel) · \(note.kind.label): \(note.text)")
            }
            out.append("")
        }

        let dayNotes = input.reviews.filter { $0.field == ReflectionQuestion.dayNoteField && !$0.text.isEmpty && $0.scope != week.string }
        if !dayNotes.isEmpty {
            out.append("## Notizen zum Tag")
            for day in week.days {
                if let note = dayNotes.first(where: { $0.scope == day.string }) { out.append("- \(day.shortLabel): \(note.text)") }
            }
            out.append("")
        }

        let weekAnswers = input.reviews.filter { $0.scope == week.string && !$0.text.isEmpty }
        out.append("## Wochenreflexion")
        if weekAnswers.isEmpty {
            out.append("Noch nicht ausgefüllt.")
        } else {
            for question in ReflectionQuestion.week {
                if let answer = weekAnswers.first(where: { $0.field == question.id }) { out.append("- **\(question.question)** \(answer.text)") }
            }
        }
        return out.joined(separator: "\n") + "\n"
    }

    /// A weekly target in the report (v11 P1.7): rounded like on screen (`Format.amount(target:unit:)`), with
    /// "≥" in front of "at least" – "≥ 86", "> 85", "129–154", "≤ 23:00".
    static func targetText(_ target: Target, unit: String) -> String {
        let shown = Format.amount(target: target, unit: unit)
        let isTime = target.isTime || Units.isTime(unit)
        return target.comparison == .atLeast && !isTime ? "≥ " + shown : shown
    }

    /// A weekly target's word in the report (v11 P1.16) – the same as on screen: "erreicht" from the exact
    /// value; a limit "im Rahmen" / "überschritten"; otherwise the pace: "nicht erreicht" once the week is
    /// closed or over, "noch offen" on its last planned day, "hinter dem Plan" / "im Plan".
    static func targetStatus(_ measure: MeasureRecord, target: Target, value: Double, input: WeekReportInput, data: WeekData) -> String {
        let week = input.week.week
        let weekOver = input.isClosed || input.today > week.sunday
        let notPlanned: Set<DayKey> = Measures.isWorkMeasure(measure, workCategories: data.workCategories) ? data.workFreeDays : []
        let pace = Pace(done: value, target: target.scaleMax, days: measure.days, week: week, today: input.today, excluding: notPlanned,
                        excused: data.excusedDays, weekOver: weekOver)
        // The app's rule (`PaceStatus.of`): above a range's upper end is missed, or still in the week.
        return PaceStatus.of(target: target, value: value, pace: pace).label
    }

    /// The journal column (R58): the plan's journal item (✓/½ → ✓, ✗ → ✗), else the reflection "ja" / "nein".
    static func journalSymbol(_ input: WeekReportInput, data: WeekData, item: ItemRecord?, day: DayKey) -> String {
        if let item {
            let mark = data.mark(item, on: day)
            if mark == .done || mark == .partial { return "✓" }
            if mark == .missed { return "✗" }
        }
        let answer = input.reviews.first { $0.scope == day.string && $0.field == ReflectionQuestion.journalField }?.text
        if answer == "ja" { return "✓" }
        if answer == "nein" { return "✗" }
        return "–"
    }

    /// One line per category: "1.2 Training und Tennis: Krafttraining ✗ Fr · Zone 2 1 von 2/Woche".
    static func missedCommitments(_ input: WeekReportInput, data: WeekData) -> [String] {
        var result: [String] = []
        let items = input.items.sortedForSheet().filter(\.schedule.isScored)
        for category in input.categories.sortedByKey() {
            var parts: [String] = []
            for item in items where item.categoryKey == category.key {
                if item.schedule == .progress {
                    if let ratio = data.progress[item.code], ratio < 1 - 1e-9, data.isComplete {
                        parts.append("\(item.title): Wochenziel zu \(Int((min(max(ratio, 0), 1) * 100).rounded())) % erreicht")
                    }
                    continue
                }
                let missed = input.marks.filter { $0.itemCode == item.code && $0.mark == .missed && !data.isExcused($0.day) }
                    .sorted { $0.day < $1.day }
                if !missed.isEmpty {
                    let notes = missed.map(\.note).filter { !$0.isEmpty }
                    var text = "\(item.title) ✗ \(missed.map(\.day.weekday.short).joined(separator: ", "))"
                    if item.knockout { text += " (Null-Regel)" }
                    if !notes.isEmpty { text += " (\(notes.joined(separator: "; ")))" }
                    parts.append(text)
                }
                if let target = item.schedule.weeklyTarget, data.isComplete {
                    let used = input.week.week.days.filter { data.mark(item, on: $0)?.counts == true }.count
                    let excused = Scorer.excusedUnits(item, data: data)
                    let note = excused > 0 ? " (\(Format.number(excused, decimals: 2)) wegen Krank/Urlaub halb gezählt)" : ""
                    let available = data.plannedDays(item).contains { !data.isExcused($0) }
                    if used < target, available || data.excusedDays.isEmpty { parts.append("\(item.title) \(used) von \(target)/Woche\(note)") }
                }
            }
            if !parts.isEmpty { result.append("\(category.label): \(parts.joined(separator: " · "))") }
        }
        return result
    }
}

/// The goal review (R95): the goal year so far – each goal's average and trend, the most missed
/// items, power-hours per area, measurements at the start and now, and every parked idea.
public struct PeriodReport: Sendable {
    public struct GoalLine: Equatable, Sendable {
        public var key: String
        public var title: String
        public var average: Double?
        /// The average of the first and the last `window` scored weeks (the trend); nil with fewer than 4.
        public var firstFour: Double?
        public var lastFour: Double?
        /// v11 P1.17: weeks in each of the two trend windows – min(4, scored ÷ 2), 0 without a trend.
        public var window: Int = 0
    }

    /// v11 P1.17: the trend's two windows without overlap – k = min(4, n ÷ 2) weeks each, no trend below
    /// k = 2 (fewer than 4 scored weeks): (first k, last k, k), or (nil, nil, 0).
    public static func trendWindows(_ scores: [Double]) -> (first: Double?, last: Double?, window: Int) {
        let k = min(4, scores.count / 2)
        guard k >= 2 else { return (nil, nil, 0) }
        return (mean(Array(scores.prefix(k))), mean(Array(scores.suffix(k))), k)
    }

    public struct MissedItem: Equatable, Sendable {
        public var title: String
        public var categoryKey: String
        public var count: Int
    }

    public struct WorkLine: Equatable, Sendable {
        public var categoryKey: String
        public var title: String
        public var powerHours: Double
    }

    public struct MeasureChange: Equatable, Sendable {
        public var code: String
        public var title: String
        public var unit: String
        public var first: Double?
        public var last: Double?
    }

    public var start: WeekKey
    public var end: WeekKey
    /// Average since the start and the trend (first vs. last four scored weeks).
    public var goals: [GoalLine]
    /// The ten most missed items (✗), counted by title.
    public var missed: [MissedItem]
    /// Power-hours per area, largest first.
    public var work: [WorkLine]
    /// First and last week value per measurement code.
    public var measures: [MeasureChange]
    /// All parked ideas, newest first.
    public var ideas: [NoteRecord]

    /// - Parameters:
    ///   - weeks: the planned weeks of the period (any order).
    ///   - goalScores: the stored goal scores of closed weeks (`WeekPlan.finalGoalScoreMap`).
    public init(weeks: [WeekReportInput], goalScores: [WeekKey: [String: Double]], ideas: [NoteRecord]) {
        let sorted = weeks.sorted { $0.week.week < $1.week.week }
        let fallback = DayKey(ordinal: 0).week
        start = sorted.first?.week.week ?? fallback
        end = sorted.last?.week.week ?? fallback

        let latestGoals = (sorted.last?.goals ?? []).sortedByNumber()
        goals = latestGoals.map { goal in
            let scores = sorted.compactMap { goalScores[$0.week.week]?[goal.key] }
            let trend = PeriodReport.trendWindows(scores)
            return GoalLine(key: goal.key, title: goal.title, average: PeriodReport.mean(scores),
                            firstFour: trend.first, lastFour: trend.last, window: trend.window)
        }

        var missedCounts: [String: (categoryKey: String, count: Int)] = [:]
        for input in sorted {
            let items = Dictionary(input.items.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
            let excused = input.excusedDays
            for mark in input.marks where mark.mark == .missed && !excused.contains(mark.day) {
                guard let item = items[mark.itemCode] else { continue }
                let current = missedCounts[item.title]?.count ?? 0
                missedCounts[item.title] = (categoryKey: item.categoryKey, count: current + 1)
            }
        }
        missed = missedCounts.map { MissedItem(title: $0.key, categoryKey: $0.value.categoryKey, count: $0.value.count) }
            .sorted { ($0.count, $1.title) > ($1.count, $0.title) }
            .prefix(10).map { $0 }

        var titles: [String: String] = [:]
        for input in sorted { for category in input.categories { titles[category.key] = category.title } }
        var hours: [String: Double] = [:]
        for input in sorted { for block in input.work { hours[block.categoryKey, default: 0] += block.powerHours } }
        work = hours.map { WorkLine(categoryKey: $0.key, title: titles[$0.key] ?? $0.key, powerHours: $0.value) }
            .sorted { ($0.powerHours, $1.categoryKey) > ($1.powerHours, $0.categoryKey) }

        var changes: [String: MeasureChange] = [:]
        var order: [String] = []
        for input in sorted {
            for measure in input.measures.sorted(by: { $0.position < $1.position }) {
                let value = Measures.weekValue(measure, days: input.week.week.days, entries: input.entries, work: input.work)
                var change = changes[measure.code] ?? MeasureChange(code: measure.code, title: measure.title, unit: measure.unit,
                                                                     first: nil, last: nil)
                if changes[measure.code] == nil { order.append(measure.code) }
                change.title = measure.title
                change.unit = measure.unit
                if let value {
                    if change.first == nil { change.first = value }
                    change.last = value
                }
                changes[measure.code] = change
            }
        }
        measures = order.compactMap { changes[$0] }

        self.ideas = ideas.sorted { ($0.day, $0.id) > ($1.day, $1.id) }
    }

    static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// "↑", "↓", "→" (first vs. last weeks), "–" without both.
    static func trend(_ line: GoalLine) -> String {
        guard let first = line.firstFour, let last = line.lastFour else { return "–" }
        if last - first > 0.25 { return "↑" }
        if first - last > 0.25 { return "↓" }
        return "→"
    }

    /// The review as Markdown to paste into ChatGPT.
    /// - Parameters:
    ///   - segment: v10 – the review covers this segment of the goal year (a line names it); nil = the goal year.
    ///   - results: v10 – the annual goals' results (no Health values), a block after the goals; empty = none.
    public func markdown(period: GoalPeriod, segment: SegmentSpan? = nil, results: [GoalResultLine] = []) -> String {
        var out: [String] = []
        let review = period.reviewWeek
        out.append("# Zielüberprüfung \(review.label) (\(review.rangeLabelWithYear))")
        out.append("Zieljahr seit \(period.start.longLabel) · ausgewertet \(start.longLabel) bis \(end.longLabel) · Ø aus abgeschlossenen Wochen")
        if let segment { out.append("Abschnitt: \(segment.title) · seit \(segment.startWeek.longLabel)") }
        if !period.motto.isEmpty { out.append("Motto: \(period.motto)") }
        out.append("Hinweis: Die Wertungen messen Verhalten, nicht Ergebnisse (0–10, Jahresziele gleich gewichtet).")
        out.append("")

        out.append("## Jahresziele")
        out.append("| Ziel | Ø seit Start | erste Wochen | letzte Wochen | Trend |")
        out.append("|---|---|---|---|---|")
        for line in goals {
            // v11 P1.17: "7,4 (je 3)" – the windows never overlap; fewer than 4 scored weeks: "–".
            let each = line.window > 0 ? " (je \(line.window))" : ""
            let first = line.firstFour.map { Format.score($0) + each } ?? "–"
            let last = line.lastFour.map { Format.score($0) + each } ?? "–"
            out.append("| \(line.key) \(line.title) | \(Format.score(line.average)) | \(first) | \(last) | \(PeriodReport.trend(line)) |")
        }
        out.append("")
        out.append(contentsOf: GoalResultLine.block(results))

        out.append("## Am häufigsten verpasst")
        if missed.isEmpty {
            out.append("Keine.")
        } else {
            out.append(contentsOf: missed.map { "- \($0.categoryKey) \($0.title): \($0.count)× ✗" })
        }
        out.append("")

        out.append("## Power-Hours je Bereich")
        if work.isEmpty {
            out.append("Keine erfasst.")
        } else {
            out.append(contentsOf: work.map { "- \($0.categoryKey) \($0.title): \(Format.powerHours($0.powerHours))" })
        }
        out.append("")

        if !measures.isEmpty {
            out.append("## Messwerte (erste und letzte Woche mit Wert)")
            for change in measures {
                let first = change.first.map { Format.measure($0, unit: change.unit) } ?? "–"
                let last = change.last.map { Format.measure($0, unit: change.unit) } ?? "–"
                out.append("- \(change.title): \(first) → \(last)")
            }
            out.append("")
        }

        out.append("## Geparkte Ideen")
        if ideas.isEmpty {
            out.append("Keine.")
        } else {
            out.append(contentsOf: ideas.map { "- \($0.day.shortLabel) \($0.day.year): \($0.text)" })
        }
        out.append("")

        out.append("## Bitte")
        out.append("Hilf mir bei der Zielüberprüfung: Was behalte ich bei, was passe ich an, was lasse ich weg – und welche geparkten Ideen verdienen jetzt Platz? Wiederholen statt steigern, ohne unnötigen Druck.")
        return out.joined(separator: "\n") + "\n"
    }
}

/// The prompt for the Sunday planning conversation: it defines Thalia's CSV contract, lists the
/// current structure (so ids stay stable), the plan changes made in the app, and last week's results.
public enum PlanPrompt {
    /// - Parameters:
    ///   - currentPlan: the source week's plan as CSV (`PlanCSV.export(document.planOnly(week:))`) – ChatGPT
    ///     takes it over and changes only what the message asks for (R91).
    ///   - trend: a few lines "KW44: Wertung 7,1 · 22 von 28 PH".
    ///   - results: v10, the annual goals' results (no Health values) – the block "Jahresziel-Ergebnisse",
    ///     left out when empty or when `lastWeekReport` already has it.
    ///   - setDays: v11 P3.4 – the target week's days already set in the app (type, note): "Schon eingetragen
    ///     für KW48: Fr 27.11. Urlaub – so übernehmen." – a plan doesn't turn a set "Urlaub" into "Arbeitstag".
    public static func text(for week: WeekKey, goals: [GoalRecord], categories: [CategoryRecord], measures: [MeasureRecord],
                            lastWeekReport: String?, changes: [PlanChangeRecord] = [], currentPlan: String? = nil,
                            currentPlanWeek: WeekKey? = nil, trend: [String] = [], results: [GoalResultLine] = [],
                            setDays: [DayRecord] = []) -> String {
        var out: [String] = []
        out.append("Du hilfst mir, meinen Wochenplan für \(week.longLabel) (\(week.rangeLabel)) in meine Tracking-App „Thalia“ zu übertragen. Meine Nachricht mit Rückblick, Zusagen, Prioritäten, Zielen und Ausnahmen steht ganz unten.")
        out.append("")
        out.append("## Grundsätze")
        out.append(contentsOf: [
            "- Fundamentjahr: auftauchen, nützliches Verhalten wiederholen, konsistent werden – ohne unnötigen Druck. Eine gute Woche ist kein Grund, den Plan zu erhöhen; nichts unaufgefordert steigern.",
            "- Die Jahresziele sind die Grundlage. Pro Kategorie **so viele Punkte wie nötig, um die Wochenziele zu unterstützen – nicht mehr**. Zwei Punkte sind in Ordnung; keine Fülltätigkeiten.",
            "- Schnell abhakbar formulieren: ein Punkt ist eine Ja/Nein-Frage über mein Verhalten („Protein im Zielbereich“, „Essfenster eingehalten“, „Krafttraining gemacht“).",
            "- Essen und Training nur abhaken, keine Details: Protein „im Zielbereich (mindestens x g, mehr ist ok)“, Fasten/Essfenster „eingehalten“, Training/Zone 2 „gemacht“. Kein Mahlzeitenprotokoll (das führe ich in einer anderen App), keine Stunden fürs Fasten.",
            "- Messwerte (measure) nur für Dinge mit einer Zahl: Power-Hours, Anzahlen (z. B. zweite Aufschläge, TEREA, Seiten), Ausgaben, Gewicht, Schlafdauer, Uhrzeiten.",
            "- Journal: nur ein Punkt „Ins Journal eingetragen“ – keine Fragen.",
            "- Arbeit in Power-Hours: 1 PH = 50 Fokusminuten, Nachhilfe ebenso (50-min-Stunde = 1 PH, 100 min = 2 PH). Wochenziele pro Bereich als measure mit link arbeit:<Kategorie> und period woche.",
            "- **Jedes tagesübergreifende Ziel** (8 PH stammloop, 5× Dehnen-Minuten, 100 Seiten, 3 Kontakte …) bekommt immer zwei verknüpfte Zeilen: einen measure mit period woche und target (die Zahl, die ich eintrage oder die aus den Power-Hours kommt) und einen item mit schedule fortschritt und link auf genau diesen measure („An stammloop gearbeitet“). Den Fortschrittspunkt hake ich nicht ab: Thalia leitet ihn aus dem Messwert ab (Tag mit Wert = gearbeitet) und bewertet am Ende – oder sobald das Ziel erreicht ist – rückwirkend nach dem Wochenergebnis. So zeigt die App für jedes Wochenziel einen Fortschrittsbalken mit „heute +x“.",
            "- Gewichtung: Was für meine Ziele wirklich zählt, ist wichtig (Standard). Kleinkram, Journal-Details, Makros und Nice-to-have bekommen in flags „nebensache“: das zählt nur, wenn ich es ausfülle, und die App zeigt es beim schnellen Check-in eingeklappt. Lieber wenige wichtige Punkte als viele gleich laute.",
            "- Freie Tage: Was nur an Arbeitstagen Sinn ergibt (Fokusarbeit, Business, Lernblöcke fürs Geschäft), bekommt flags „arbeit“; an Familien-, Erholungs- und freien Tagen zählt es dann nicht. Was auch an solchen Tagen geht (Mentales, Familie, Hobby, Lesen, Morgenroutine, Dehnen …), bekommt „frei“ oder bleibt ohne Angabe.",
            "- Krank und Urlaub: Tage mit dem Tagestyp „Krank“ oder „Urlaub“ zählen nicht in die Wochenwertung. Wochenziele werden für diese Tage anteilig gekürzt, was deshalb fehlt, zählt halb. Den Plan dafür nicht umbauen.",
            "- Aktuelle, konkrete Angaben gehen alten, kopierten Sätzen vor. Widersprüche offen auflösen; Annahmen in die description der week-Zeile.",
            "- Schlaf, Familie und geplante Erholung sind keine Reservezeit für Arbeit. Null Arbeit an einem geplanten freien Tag ist richtig – diese Tage bekommen keine Arbeitspunkte.",
            "- Höchstens zwei aktive Hauptprojekte: stammloop und HAEB.",
            "- Familie: nur mein eigenes Verhalten (Aufmerksamkeit, Ton, Zusagen, Hilfe), nie das von anderen. Sensible Themen sachlich, ohne Moral.",
            "- Alles auf Deutsch mit richtigen Umlauten.",
        ])
        out.append("")
        out.append("## Ausgabe")
        out.append("Antworte mit genau einem ```csv-Codeblock. Die erste Zeile ist exakt:")
        out.append(PlanCSV.header)
        out.append("Komma als Trennzeichen. Werte mit Komma, Anführungszeichen oder Zeilenumbruch in \"doppelte Anführungszeichen\". Leere Spalten leer lassen. Zahlen mit Dezimalpunkt (2.5) und ohne Tausenderpunkt (8000, nicht 8.000). Unter dem Codeblock höchstens fünf Zeilen mit Annahmen und aufgelösten Widersprüchen.")
        out.append("")
        out.append("Reihenfolge: eine week-Zeile, sieben day-Zeilen (Mo–So), die measure-Zeilen, dann die item-Zeilen nach Kategorie. goal- und category-Zeilen nur, wenn sich die Struktur ändert.")
        out.append("")
        out.append("## Zeilentypen")
        out.append("| type | id | parent | title | description |")
        out.append("|---|---|---|---|---|")
        out.append("| week | \(week.string) | | Wochenmotto | Kontext, Prioritäten, Ausnahmen, Annahmen |")
        out.append("| day | Datum, z. B. \(week.monday.string) | | Tagestyp: Arbeitstag, Reisetag, Familientag, Erholungstag, Frei, Krank, Urlaub, Prüfungstag … | Besonderheit, z. B. „Arbeit endet 15:00“ |")
        out.append("| measure | stabile id, z. B. aufschlaege | Kategorie-id | Name | Hinweis |")
        out.append("| item | <Kategorie>-<Nr>, z. B. 1.1-01 | Kategorie-id | kurzer Titel als Ja/Nein | was als erledigt zählt |")
        out.append("| goal | 1 … 10 | | Jahresziel | Absicht |")
        out.append("| category | z. B. 1.1 | Ziel-id | Kategorie | |")
        out.append("")
        out.append("## Spalten")
        out.append(contentsOf: [
            "- days: täglich | Mo-Fr | Mo,Mi,Fr | Sa,So – an welchen Tagen der Punkt gilt (leer = täglich). Nicht geplante Tage zählen nie als verpasst.",
            "- schedule (item): fix = an jedem seiner Tage fällig | woche:3 = 3× pro Woche an beliebigen seiner Tage (Fehlendes zählt am Wochenende als verpasst) | fortschritt = Tagesanteil an einem Wochenziel, link auf den Wochen-Messwert | bedingt = nur wenn die Situation eintritt, sonst N/A | optional = wird erfasst, nie bewertet.",
            "- unit (measure): PH, Stück, Seiten, €, kg, h, min, Uhrzeit, %.",
            "- target: >=150 | <=6 | <50 | <=23:00 | 150-180. Bei measure das Tages- oder Wochenziel. Bei item die Schwelle für den verknüpften Messwert (Thalia schlägt dann ✓ oder ✗ vor).",
            "- period (measure): tag | woche.",
            "- link: bei item die id eines Messwerts. Bei measure die Quelle: leer = manuell | arbeit:3.2 = Power-Hours aus den Arbeitsblöcken dieser Kategorie | health:sleep, health:bedtime, health:bodyMass, health:steps … = Vorschlag aus Apple Health | list:buch = gelesene Seiten aus der Leseliste | app:<app>:<art>[=<ref>] = Werte aus einer verbundenen App (z. B. app:george:workout=tpl-1 zählt Workouts, app:theo:task erledigte Aufgaben der Kategorie, app:nina:kcal den Tageswert). Verknüpfungen aus dem Ausgangsplan unverändert übernehmen – auch app:… und list:…; ohne link verliert der Messwert seine Quelle nicht.",
            "- flags (kommagetrennt, in Anführungszeichen wenn mehrere): nebensache = zählt nur wenn ausgefüllt, eingeklappt | arbeit = nur an Arbeitstagen | frei = auch an freien Tagen | bei item ko = persönliche Null-Regel (✗ → Kategorie an diesem Tag 0) | bei measure zusätzlich summe | letzter | schnitt | max | min (Standard summe; kg, Uhrzeit, % → letzter). Beispiel: \"arbeit,ko\".",
            "- date, value, note: für den Plan leer lassen.",
        ])
        out.append("")
        let sortedGoals = goals.sortedByNumber()
        if !sortedGoals.isEmpty {
            out.append("## Meine aktuelle Struktur (ids genau so verwenden)")
            let sortedCategories = categories.sortedByKey()
            for goal in sortedGoals {
                let list = sortedCategories.filter { $0.goalKey == goal.key }.map { "\($0.key) \($0.title)" }.joined(separator: " · ")
                out.append("- \(goal.label): \(list)")
            }
            out.append("")
        }
        if !measures.isEmpty {
            out.append("## Messwerte bisher (ids beibehalten, damit Verläufe weiterlaufen)")
            for measure in measures.sorted(by: { $0.position < $1.position }) {
                var parts = [measure.unit]
                if let target = measure.target { parts.append("\(target.raw) \(measure.period.label)") }
                if !measure.source.raw.isEmpty { parts.append(measure.source.raw) }
                out.append("- \(measure.code): \(measure.title) (\(parts.filter { !$0.isEmpty }.joined(separator: ", ")))")
            }
            out.append("")
        }
        if !changes.isEmpty {
            out.append("## Meine Änderungen in der App (bitte berücksichtigen)")
            out.append(contentsOf: changes.map { "- \($0.line)" })
            out.append("„dauerhaft übernehmen“ heißt: so in den neuen Plan aufnehmen. „nur diese Woche“: nicht übernehmen. „Gewichtung“: kommt der Punkt wieder vor, meine Einschätzung (wichtig/nebensache) verwenden.")
            out.append("")
        }
        out.append("## Beispiel (Ausschnitt)")
        out.append("```csv")
        out.append(exampleCSV(week).trimmingCharacters(in: .newlines))
        out.append("```")
        out.append("")
        if let report = lastWeekReport, !report.isEmpty {
            out.append("## Ergebnisse der letzten Woche (aus Thalia)")
            out.append(report.trimmingCharacters(in: .newlines))
            out.append("")
        }
        if !(lastWeekReport ?? "").contains(GoalResultLine.heading) {
            out.append(contentsOf: GoalResultLine.block(results))
        }
        if let plan = currentPlan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty {
            out.append("## Plan von \(currentPlanWeek?.label ?? "letzter Woche") (Ausgangspunkt)")
            out.append("```csv")
            out.append(plan)
            out.append("```")
            out.append("Übernimm diese Zeilen für \(week.label) (Datum in die neue Woche verschieben), ändere nur, was ich unten verlange, und nenne jede Änderung unter dem Codeblock. Verknüpfungen aus dem Ausgangsplan unverändert übernehmen (Spalte link, auch app:… und list:…).")
            out.append("")
        }
        if !trend.isEmpty {
            out.append("## Tendenz der letzten 4 Wochen")
            out.append(contentsOf: trend.map { "- \($0)" })
            out.append("")
        }
        if let line = setDaysLine(week, setDays) {
            out.append(line)
            out.append("")
        }
        out.append("## Mein Rückblick und Plan für \(week.label):")
        out.append("")
        return out.joined(separator: "\n")
    }

    /// "Schon eingetragen für KW48: Fr 27.11. Urlaub, Sa 28.11. Reisetag („Flug 14:00“) – so übernehmen." – the
    /// target week's days with a type or a note, by day; nil without any (v11 P3.4).
    static func setDaysLine(_ week: WeekKey, _ days: [DayRecord]) -> String? {
        let set = days.filter { week.contains($0.day) && !($0.dayType.trimmingCharacters(in: .whitespaces).isEmpty && $0.note.isEmpty) }
            .sorted { $0.day < $1.day }
        guard !set.isEmpty else { return nil }
        let parts = set.map { day -> String in
            let date = "\(day.day.weekday.short) \(Format.pad(day.day.day, 2)).\(Format.pad(day.day.month, 2))."
            let type = day.dayType.trimmingCharacters(in: .whitespaces)
            let note = day.note.trimmingCharacters(in: .whitespacesAndNewlines)
            return [date, type, note.isEmpty ? "" : "(\u{201E}\(note)\u{201C})"].filter { !$0.isEmpty }.joined(separator: " ")
        }
        return "Schon eingetragen für \(week.label): \(parts.joined(separator: ", ")) – so übernehmen."
    }

    /// A few correct rows, written by the real exporter so the example never drifts from the format.
    static func exampleCSV(_ week: WeekKey) -> String {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week, title: "Wiederholen statt steigern", details: "Annahme: Der Feiertag am Mittwoch ersetzt die alte Arbeitsvorgabe für diesen Tag.")]
        doc.days = [
            DayRecord(day: week.monday, dayType: "Arbeitstag"),
            DayRecord(day: week.day(.wednesday), dayType: "Frei", note: "Feiertag – keine Arbeit."),
        ]
        doc.measures = [
            MeasureRecord(week: week, code: "stammloop_ph", categoryKey: "3.2", position: 1, title: "stammloop", unit: "PH",
                          target: Target.parse(">=8"), period: .week, source: .work(category: "3.2")),
            MeasureRecord(week: week, code: "aufschlaege", categoryKey: "1.2", position: 2, title: "Zweite Aufschläge", unit: "Stück",
                          target: Target.parse(">=100"), period: .week),
        ]
        doc.items = [
            ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Protein im Zielbereich",
                       details: "Mindestens 150 g – mehr ist in Ordnung."),
            ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", position: 1, title: "Zone 2",
                       details: "Eine Zone-2-Einheit gemacht.", days: DayMask.parse("Di,Do,Sa") ?? .everyDay, schedule: .weekly(2)),
            ItemRecord(week: week, code: "1.2-02", categoryKey: "1.2", position: 2, title: "Zweite Aufschläge geübt",
                       details: "Automatisch aus dem Wochenziel 100 Aufschläge.", schedule: .progress, measure: "aufschlaege", dayRule: .always),
            ItemRecord(week: week, code: "2.2-01", categoryKey: "2.2", position: 1, title: "Ins Journal eingetragen",
                       details: "Kurz reicht.", secondary: true, dayRule: .always),
            ItemRecord(week: week, code: "3.2-01", categoryKey: "3.2", position: 1, title: "An stammloop gearbeitet",
                       details: "Automatisch aus den PH; zählt am Ende gegen das Wochenziel (8 PH).", days: .workdays, schedule: .progress,
                       measure: "stammloop_ph", dayRule: .workOnly),
            ItemRecord(week: week, code: "4-03", categoryKey: "4", position: 3, title: "Kein Bildschirm nach 23:00",
                       details: "Persönliche Regel: verletzt → Schlaf heute 0.", knockout: true),
        ]
        return PlanCSV.export(doc)
    }
}

/// The prompt for bringing past weeks in from old records (v8; v9: archive weeks): photos, scans,
/// PDFs or tables of one or many weeks go in, one Thalia CSV with a block per week comes out – only
/// what the records say: the week's value, day types, category and goal grades (0–10), single marks
/// and values only where they are really there. Nothing invented, split or multiplied (TASKS-v9 §3).
public enum PastWeekPrompt {
    /// The week id in the template when the weeks come from the attachments.
    public static let weekPlaceholder = "JJJJ-Wnn"

    /// The answer's columns: the import columns, `count` (grades), the weekday columns (marks).
    public static let columns = PlanCSV.columns + [PlanCSV.countColumn] + PlanCSV.matrixColumns

    /// `type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note,count,mo,di,mi,do,fr,sa,so`
    public static var header: String { columns.joined(separator: ",") }

    /// The example's two week ids: placeholders, so the example – pasted back or copied into an answer –
    /// never lands in a real week (its rows are skipped as unreadable).
    static let exampleWeekIDs = [weekPlaceholder, weekPlaceholder]

    /// - Parameters:
    ///   - weeks: the weeks to bring in; empty = the weeks of the attached photos, scans, PDFs or tables
    ///     (KW and dates are read from there).
    ///   - items: the template for single marks (the week's own plan or the nearest planned week's) –
    ///     only used where single items are really ticked in the records.
    ///   - measures: the measurements whose recorded values may come along (entry rows).
    public static func text(weeks: [WeekKey], items: [ItemRecord], categories: [CategoryRecord], goals: [GoalRecord],
                            measures: [MeasureRecord]) -> String {
        let sorted = Array(Set(weeks)).sorted()
        var out: [String] = []
        out.append("Du überträgst Wochen aus meinen Unterlagen (Fotos, Scans, PDFs, Tabellen) in eine CSV für meine Tracker-App „Thalia“.")
        out.append("Es ist ein Archiv: Übertrage nur, was in den Unterlagen steht.")
        out.append("Hast du für diese Unterlagen schon eine CSV erstellt, erstelle sie nach diesen Regeln vollständig neu – übernimm nichts aus ihr, was die Regeln nicht erlauben (etwa Noten als Text in note).")
        out.append("")
        out.append(contentsOf: intro(sorted))
        out.append("")
        out.append("## Regeln")
        out.append(contentsOf: rules(sorted, hasItems: !items.isEmpty, hasMeasures: !measures.isEmpty))
        out.append("")
        out.append("## Kopfzeile")
        out.append("Die erste Zeile der CSV ist genau:")
        out.append(header)
        out.append("Komma als Trennzeichen, Zahlen mit Dezimalpunkt und ohne Tausenderpunkt (8000, nicht 8.000): ein Dezimalkomma der Unterlage schreibst du als Punkt (9,19 → 9.19) – ein Komma ohne Anführungszeichen verschiebt alle weiteren Spalten. Werte mit Komma, Anführungszeichen oder Zeilenumbruch in \"doppelte Anführungszeichen\". Jede Zeile hat genau so viele Spalten wie die Kopfzeile; leere Spalten leer lassen. Alles auf Deutsch mit richtigen Umlauten.")
        out.append("")
        out.append("## Beispiel (zwei Wochen)")
        out.append("```csv")
        out.append(exampleCSV().trimmingCharacters(in: .newlines))
        out.append("```")
        out.append("\(weekPlaceholder) steht für die echte week-id (z. B. 2026-W43). Erste Woche: Wochenwert mit Quelle; Samstag Urlaub (die Note des Tages wird trotzdem übertragen); \u{201E}Sport / Verein\u{201C} mit Tagesnoten samt echter 0, je Tag eine Zeile; \u{201E}Lesen\u{201C} nur als Mittelwert über 4 gültige Tage; \u{201E}Sonderwoche\u{201C} ohne heutige Kategorie (id leer); eine Zielnote, so wie sie in der Unterlage steht – nicht aus den Kategorien gerechnet. Zweite Woche: nur der Wochenwert. Bezeichnungen, ids und Werte sind nur Beispiele – nimm die ids aus den Listen unten und die Werte aus den Unterlagen; das Beispiel selbst gehört nicht in die Antwort.")
        out.append("")
        let sortedGoals = goals.sortedByNumber()
        out.append("## Jahresziele (id · Name)")
        if sortedGoals.isEmpty { out.append("- (keine)") }
        out.append(contentsOf: sortedGoals.map { "- \($0.key) · \($0.title)" })
        out.append("")
        let sortedCategories = categories.sortedByKey()
        out.append("## Kategorien (id · Name · Jahresziel)")
        if sortedCategories.isEmpty { out.append("- (keine)") }
        out.append(contentsOf: sortedCategories.map { "- \($0.key) · \($0.title) · Ziel \($0.goalKey)" })
        out.append("")
        out.append("## Messwerte (id · Name · Einheit)")
        let sortedMeasures = measures.sorted { ($0.position, $0.code) < ($1.position, $1.code) }
        if sortedMeasures.isEmpty { out.append("- (keine)") }
        out.append(contentsOf: sortedMeasures.map { "- \($0.code) · \($0.title) · \($0.unit.isEmpty ? "–" : $0.unit)" })
        out.append("")
        out.append(templateHeading(items))
        if !items.isEmpty {
            out.append("```csv")
            out.append(template(items: items).trimmingCharacters(in: .newlines))
            out.append("```")
            out.append("Nur Zeilen für Punkte, deren Haken in den Unterlagen wirklich stehen – in den Block ihrer Woche, id, parent, title, days und schedule unverändert, nur mo bis so ausfüllen.")
        }
        out.append("")
        if sorted.count == 1, let week = sorted.first {
            out.append("## Meine Unterlagen für \(week.label):")
        } else {
            out.append("## Meine Unterlagen:")
        }
        out.append("")
        return out.joined(separator: "\n")
    }

    /// Which weeks: exactly the given ones, or the weeks of the attachments.
    static func intro(_ weeks: [WeekKey]) -> [String] {
        guard let first = weeks.first else {
            return ["Wochen: die Wochen aus den Unterlagen – KW und Datum jeder Woche liest du dort ab (eine Woche geht von Montag bis Sonntag). Eine oder viele Wochen; Wochen, die du nicht sicher zuordnen kannst, nennst du unter dem Codeblock, statt zu raten."]
        }
        if weeks.count == 1 {
            return ["Woche: genau diese – \(first.longLabel) (\(first.rangeLabel)), week-id \(first.string). Fehlt sie in den Unterlagen, schreib keinen Block und sag es unter dem Codeblock."]
        }
        return ["Wochen: genau diese \(weeks.count) vergangenen Wochen. Nur die Wochen unten übertragen, mit ihrer week-id; fehlt eine in den Unterlagen, lass ihren Block weg und nenne sie unter dem Codeblock:"]
            + weeks.map { "- \($0.longLabel) (\($0.rangeLabel)): week-id \($0.string)" }
    }

    /// The rules of TASKS-v9 §3, numbered.
    static func rules(_ weeks: [WeekKey], hasItems: Bool, hasMeasures: Bool) -> [String] {
        let weekID = weeks.isEmpty
            ? "id = Woche (Woche erkennen: Jahr und KW, z. B. 2026-W43; unklar → id leer lassen und date = ein Datum der Woche, z. B. 2026-10-19)"
            : "id = die week-id oben"
        let marks = hasItems
            ? "7. Einzelhaken nur, wenn einzelne Punkte wirklich lesbar abgehakt sind: item-Zeilen aus der Vorlage unten (id, parent, title, days, schedule unverändert) mit den Spalten mo … so: ✓ = erledigt · ½ = teilweise · ✗ = nicht erledigt · – = entfällt. Sonst keine item-Zeilen – fehlende Punkte gelten nicht als verpasst. Aus einer Note folgen keine Haken. Hat eine Woche item-Zeilen, rechnet Thalia sie nach diesen Punkten, und ihre Noten zählen dann nicht mit – einzelne Haken also nur, wenn die Woche damit wirklich belegt ist."
            : "7. Keine item-Zeilen (die App hat keine Vorlage für Einzelhaken) – fehlende Punkte gelten nicht als verpasst. Aus einer Note folgen keine Haken."
        let values = hasMeasures
            ? "8. Messwerte (entry) nur mit belegtem Wert: id = Messwert-id aus der Liste unten, date, value. Aus einer Note folgt kein Messwert, keine Anzahl und keine Arbeitszeit."
            : "8. Keine entry-Zeilen (keine Messwerte als Vorlage). Aus einer Note folgt kein Messwert, keine Anzahl und keine Arbeitszeit."
        return [
            "1. Nichts erfinden. Leere, gestrichene oder unlesbare Felder: keine Zeile. Eine echte 0 schreibst du als 0. Widersprechen sich Unterlagen, nimm die, die ich nenne; nenne ich keine, lass das widersprüchliche Feld weg. Beides erwähnst du unter dem Codeblock.",
            "2. Je Woche ein Block, älteste zuerst; jeder Block beginnt mit genau einer week-Zeile. Alle Zeilen eines Blocks gehören zu dieser Woche – ein Datum aus einer anderen Woche liest Thalia nicht.",
            "3. week: \(weekID); value = der Wochenwert genau wie in der Unterlage – nicht selbst berechnen, nicht runden, nur das Dezimalkomma als Punkt (9,19 → 9.19); note = Quelle (z. B. „Scan S. 3“); title und description leer lassen. Ist nur der Wochenwert belegt, besteht der Block nur aus dieser Zeile.",
            "4. day (nur wenn belegt): id = Datum oder Mo … So, title = Tagestyp (Arbeitstag, Frei, Krank, Urlaub …), description = kurze Notiz. Krank- und Urlaubstage zählen heute nicht in die Wochenwertung – ihre Noten überträgst du trotzdem.",
            "5. category_score = Note einer Kategorie (0–10): title = Bezeichnung genau wie in der Unterlage; id = heutige Kategorie aus der Liste unten, nur wenn es eindeutig dieselbe ist – sonst leer (alte Sammel- oder Zusatzkategorien nie aufteilen oder umdeuten; zwei Bezeichnungen nie auf dieselbe id); date = der Tag bei einer Tagesnote (Datum oder Mo … So) – je Tagesnote eine eigene Zeile, die Spalten mo … so gibt es nur in item-Zeilen; date leer bei einer Wochennote, die nur als Mittelwert belegt ist (dann count = Anzahl gültiger Tage, wenn angegeben); value = Note; note = Quelle. Mittelwerte rechnet Thalia selbst: zu übertragenen Tagesnoten keine Wochennote derselben Kategorie. Noten nie als Text in note oder description – immer als category_score oder goal_score.",
            "6. goal_score = Note eines Jahresziels (0–10) für die Woche: id = Jahresziel 1–10 aus der Liste unten (leer, wenn unklar), title = Bezeichnung wie in der Unterlage, value, note = Quelle, count wenn angegeben. Steht in der Unterlage eine Note je Jahresziel (eine Zeile je Ziel), ist das goal_score mit der id des Jahresziels – auch wenn die Unterlage sie Kategorie nennt. Zielnoten nie auf Kategorien verteilen, je Kategorie wiederholen oder aus Kategoriennoten berechnen.",
            marks,
            values,
            "9. Keine score-, measure-, goal-, category- oder work-Zeilen.",
            "10. Antworte mit genau einem ```csv-Block für alle Wochen; danach in 2–5 Zeilen, was unsicher war (unlesbare Felder, widersprüchliche Angaben, unsichere Zuordnungen, fehlende Wochen).",
        ]
    }

    /// "## Vorlage für Einzelhaken (nur bei belegten Haken) – Punkte von KW46"
    static func templateHeading(_ items: [ItemRecord]) -> String {
        let heading = "## Vorlage für Einzelhaken (nur bei belegten Haken)"
        guard let week = items.map(\.week).max() else { return heading + ": keine Punkte in der App" }
        return heading + " – Punkte von \(week.label)"
    }

    /// The items to copy for single marks: the header and one row per item with empty weekday
    /// columns – written by the real column list so it never drifts from the format.
    static func template(items: [ItemRecord]) -> String {
        var table: [[String]] = [columns]
        func row(_ values: [String: String]) { table.append(columns.map { values[$0] ?? "" }) }
        for item in items.sortedForSheet() {
            row(["type": "item", "id": item.code, "parent": item.categoryKey, "title": item.title, "days": item.days.csv,
                 "schedule": item.schedule.raw, "target": item.target?.raw ?? "", "link": item.measure, "flags": item.flags])
        }
        return CSV.write(table)
    }

    /// Two weeks as an example (§3): a week with its value, a holiday Saturday, three labels (one
    /// without today's category, one only as a mean) and a goal grade that is no mean of the example's
    /// category grades; a week with only its value. Neutral labels only. The week ids are placeholders,
    /// so the example never lands in a real week; with real ids (`weekIDs`) it is valid input – a test
    /// reads it back.
    static func exampleCSV(weekIDs: [String] = exampleWeekIDs) -> String {
        let first = weekIDs.first ?? weekPlaceholder
        let second = weekIDs.dropFirst().first ?? weekPlaceholder
        var table: [[String]] = [columns]
        func row(_ values: [String: String]) { table.append(columns.map { values[$0] ?? "" }) }
        let source = "Scan S. 3"
        row(["type": "week", "id": first, "value": "8.75", "note": source])
        row(["type": "day", "id": "Sa", "title": "Urlaub"])
        for (weekday, value) in [(Weekday.monday, "10"), (.tuesday, "0"), (.saturday, "10")] {
            row(["type": ArchiveGrade.Kind.category.rawValue, "id": "1.2", "title": "Sport / Verein", "date": weekday.short,
                 "value": value, "note": source])
        }
        row(["type": ArchiveGrade.Kind.category.rawValue, "id": "5", "title": "Lesen", "value": "6.5", "note": source,
             PlanCSV.countColumn: "4"])
        row(["type": ArchiveGrade.Kind.category.rawValue, "title": "Sonderwoche", "value": "7", "note": source])
        row(["type": ArchiveGrade.Kind.goal.rawValue, "id": "1", "title": "Fitness", "value": "8", "note": source])
        row(["type": "week", "id": second, "value": "7.2", "note": "Scan S. 4"])
        return CSV.write(table)
    }
}

/// One week in a report over several weeks (v8, PDF-Bericht).
public struct WeekLine: Equatable, Sendable {
    public var week: WeekKey
    /// The score that counts: stored for closed and paper weeks, live for open ones; nil when none.
    public var score: Double?
    public var isClosed: Bool
    /// Scored with the model before KW42 2026 – not averaged with the others.
    public var isOldScoring: Bool
    /// Only a reported score, no plan in the app.
    public var isPaperOnly: Bool
    /// Every day with something planned was sick or on holiday: no score.
    public var isExcused: Bool
    /// Goal key → the week's goal score.
    public var goalScores: [String: Double]
    public var powerHours: Double
    /// Sum of the weekly power-hour targets as they count (scaled for excused days), nil without targets.
    public var powerHoursTarget: Double?
    /// Closed days that count – sick and holiday days left out (v11 P6.2: "Tage abgeschlossen" of the PDF).
    public var closedDays: Int
    public var excusedDays: Int
    public var weeklyTargetsMet: Int
    public var weeklyTargetsCount: Int
    /// The week has archive grades (v9): Rückblick and PDF say "Archiv" instead of "Papier".
    public var isArchive: Bool

    public init(week: WeekKey, score: Double? = nil, isClosed: Bool = false, isOldScoring: Bool = false, isPaperOnly: Bool = false,
                isExcused: Bool = false, goalScores: [String: Double] = [:], powerHours: Double = 0, powerHoursTarget: Double? = nil,
                closedDays: Int = 0, excusedDays: Int = 0, weeklyTargetsMet: Int = 0, weeklyTargetsCount: Int = 0,
                isArchive: Bool = false) {
        self.isArchive = isArchive
        self.week = week
        self.score = score
        self.isClosed = isClosed
        self.isOldScoring = isOldScoring
        self.isPaperOnly = isPaperOnly
        self.isExcused = isExcused
        self.goalScores = goalScores
        self.powerHours = powerHours
        self.powerHoursTarget = powerHoursTarget
        self.closedDays = closedDays
        self.excusedDays = excusedDays
        self.weeklyTargetsMet = weeklyTargetsMet
        self.weeklyTargetsCount = weeklyTargetsCount
    }

    /// The score a week shows in Rückblick, Ø, Ziele, PDF and widgets (v9, decision 5): the value
    /// "laut Unterlagen" wins over the calculated one (`WeekPlan.historyScore`).
    public static func historyScore(recorded: Double?, computed: Double?) -> Double? {
        recorded ?? computed
    }

    /// A week from its report input, scored with the v8 rules.
    /// - Parameters:
    ///   - storedScore: `WeekPlan.historyScore` of a closed or paper week (wins over the live score).
    ///   - storedGoalScores: `WeekPlan.finalGoalScoreMap` of a closed week (wins when not empty).
    ///   - archive: the week's archive grades (v9): without items, the goals and – without any other
    ///     score – the week come from their recalculation under today's rules.
    public init(_ input: WeekReportInput, storedScore: Double? = nil, storedGoalScores: [String: Double] = [:],
                archive: ArchiveWeek? = nil) {
        let data = input.weekData
        let result = Scorer.score(data)
        let week = input.week.week
        let paperOnly = input.items.isEmpty && input.week.recordedScore != nil
        let live: Double? = result.isExcused ? nil : result.overall
        let graded = archive?.hasGrades == true
        let recalculation: ArchiveRecalculation? = graded && input.items.isEmpty
            ? archive?.recalculated(categories: input.categories, goals: input.goals, excusedDays: input.excusedDays)
            : nil
        var goals = storedGoalScores
        if goals.isEmpty {
            for (key, goal) in result.goalWeek { if let score = goal.score { goals[key] = score } }
        }
        if goals.isEmpty, let recalculation { goals = recalculation.goals }
        var targets: [Double] = []
        var met = 0
        var count = 0
        for measure in input.measures where measure.period == .week && measure.target != nil {
            let share = Measures.targetShare(for: measure, week: week, excused: data.excusedDays, workFree: data.workFreeDays,
                                             workCategories: data.workCategories)
            guard share > 1e-9, let target = measure.target else { continue }
            let effective = Measures.effectiveTarget(target, share: share)
            if measure.isWork { targets.append(effective.scaleMax) }
            let value = Measures.weekValue(measure, days: week.days, entries: input.entries, work: input.work) ?? 0
            count += 1
            if effective.isMet(value) { met += 1 }
        }
        let score = storedScore ?? live ?? WeekLine.historyScore(recorded: input.week.recordedScore, computed: recalculation?.overall)
        self.init(week: week, score: score, isClosed: input.isClosed,
                  isOldScoring: input.week.isOldScoring, isPaperOnly: paperOnly, isExcused: result.isExcused, goalScores: goals,
                  powerHours: WorkTotals(input.work).powerHours, powerHoursTarget: targets.isEmpty ? nil : targets.reduce(0, +),
                  closedDays: week.days.filter { input.closedDays.contains($0) && !result.excusedDays.contains($0) }.count,
                  excusedDays: result.excusedDays.count,
                  weeklyTargetsMet: met, weeklyTargetsCount: count, isArchive: graded)
    }

    /// Counts in averages: has a score, current model, not excused.
    public var isComparable: Bool { score != nil && !isOldScoring && !isExcused }
}

/// A report over several weeks (v8, PDF-Bericht): one line per week, the average, every goal's
/// average and trend, power-hours per area and the totals.
public struct RangeReport: Equatable, Sendable {
    public struct GoalLine: Equatable, Sendable {
        public var key: String
        public var title: String
        public var average: Double?
        /// Average of the first and the last `window` weeks with a score (the trend); nil with fewer than 4.
        public var firstFour: Double?
        public var lastFour: Double?
        /// Weeks with a score for this goal.
        public var weeks: Int
        /// v11 P1.17: weeks in each trend window – min(4, weeks ÷ 2), 0 without a trend.
        public var window: Int

        public init(key: String, title: String, average: Double? = nil, firstFour: Double? = nil, lastFour: Double? = nil, weeks: Int = 0,
                    window: Int = 0) {
            self.key = key
            self.title = title
            self.average = average
            self.firstFour = firstFour
            self.lastFour = lastFour
            self.weeks = weeks
            self.window = window
        }

        /// 1 rising, −1 falling, 0 steady (±0,25 like the goal review), nil without both.
        public var trend: Int? {
            guard let first = firstFour, let last = lastFour else { return nil }
            if last - first > 0.25 { return 1 }
            if first - last > 0.25 { return -1 }
            return 0
        }

        /// "↑", "↓", "→", "–".
        public var trendArrow: String {
            switch trend {
            case .some(1): return "↑"
            case .some(-1): return "↓"
            case .some: return "→"
            case .none: return "–"
            }
        }

        /// The SF Symbol the goal review uses: "arrow.up.right", "arrow.down.right", "arrow.right", "minus".
        public var trendSymbol: String {
            switch trend {
            case .some(1): return "arrow.up.right"
            case .some(-1): return "arrow.down.right"
            case .some: return "arrow.right"
            case .none: return "minus"
            }
        }

        /// "steigend", "fallend", "gleichbleibend", "noch kein Trend".
        public var trendWord: String {
            switch trend {
            case .some(1): return "steigend"
            case .some(-1): return "fallend"
            case .some: return "gleichbleibend"
            case .none: return "noch kein Trend"
            }
        }
    }

    public struct WorkLine: Equatable, Sendable {
        public var categoryKey: String
        public var title: String
        public var powerHours: Double

        public init(categoryKey: String, title: String, powerHours: Double) {
            self.categoryKey = categoryKey
            self.title = title
            self.powerHours = powerHours
        }
    }

    /// One line per week, oldest first.
    public var lines: [WeekLine]
    /// Average of the comparable weeks (with a score, current model, not excused).
    public var average: Double?
    /// Average of the weeks scored with the earlier model, kept apart.
    public var oldAverage: Double?
    public var goals: [GoalLine]
    /// Power-hours per area, largest first.
    public var work: [WorkLine]
    public var powerHours: Double
    /// Sum of the weekly targets of the weeks that have one; nil when none has.
    public var powerHoursTarget: Double?
    public var closedWeeks: Int
    public var closedDays: Int
    public var excusedDays: Int
    public var excusedWeeks: Int
    public var weeklyTargetsMet: Int
    public var weeklyTargetsCount: Int

    /// - Parameters:
    ///   - goals: the goals to report (sorted by number).
    ///   - work: the range's work blocks; `categories` give their titles.
    public init(lines: [WeekLine], goals: [GoalRecord], work: [WorkRecord], categories: [CategoryRecord] = []) {
        let sorted = lines.sorted { $0.week < $1.week }
        self.lines = sorted
        let comparable = sorted.filter(\.isComparable)
        average = RangeReport.mean(comparable.compactMap(\.score))
        oldAverage = RangeReport.mean(sorted.filter { $0.isOldScoring && !$0.isExcused }.compactMap(\.score))
        self.goals = goals.sortedByNumber().map { goal in
            let scores = sorted.filter { !$0.isOldScoring && !$0.isExcused }.compactMap { $0.goalScores[goal.key] }
            let trend = PeriodReport.trendWindows(scores)
            return GoalLine(key: goal.key, title: goal.title, average: RangeReport.mean(scores),
                            firstFour: trend.first, lastFour: trend.last, weeks: scores.count, window: trend.window)
        }
        var titles: [String: String] = [:]
        for category in categories { titles[category.key] = category.title }
        var hours: [String: Double] = [:]
        for block in work { hours[block.categoryKey, default: 0] += block.powerHours }
        self.work = hours.map { WorkLine(categoryKey: $0.key, title: titles[$0.key] ?? $0.key, powerHours: $0.value) }
            .sorted { ($0.powerHours, $1.categoryKey) > ($1.powerHours, $0.categoryKey) }
        powerHours = sorted.reduce(0) { $0 + $1.powerHours }
        let targets = sorted.compactMap(\.powerHoursTarget)
        powerHoursTarget = targets.isEmpty ? nil : targets.reduce(0, +)
        closedWeeks = sorted.filter(\.isClosed).count
        closedDays = sorted.reduce(0) { $0 + $1.closedDays }
        excusedDays = sorted.reduce(0) { $0 + $1.excusedDays }
        excusedWeeks = sorted.filter(\.isExcused).count
        weeklyTargetsMet = sorted.reduce(0) { $0 + $1.weeklyTargetsMet }
        weeklyTargetsCount = sorted.reduce(0) { $0 + $1.weeklyTargetsCount }
    }

    public var start: WeekKey? { lines.first?.week }
    public var end: WeekKey? { lines.last?.week }
    /// Weeks that count in the average.
    public var scoredWeeks: Int { lines.filter(\.isComparable).count }

    /// "KW40–KW47 2026", "KW52 2026 – KW3 2027", "KW45 2026"; "" without weeks.
    public var title: String {
        guard let start, let end else { return "" }
        if start == end { return start.longLabel }
        if start.year == end.year { return "\(start.label)–\(end.label) \(end.year)" }
        return "\(start.longLabel) – \(end.longLabel)"
    }

    static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}
