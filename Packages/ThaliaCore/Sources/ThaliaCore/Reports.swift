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

    public init(week: WeekRecord, goals: [GoalRecord], categories: [CategoryRecord], items: [ItemRecord], measures: [MeasureRecord],
                marks: [MarkRecord], overrides: [ScoreRecord] = [], days: [DayRecord] = [], entries: [EntryRecord] = [],
                work: [WorkRecord] = [], notes: [NoteRecord] = [], reviews: [ReviewRecord] = [], changes: [PlanChangeRecord] = [],
                closedDays: Set<DayKey> = [], isClosed: Bool = false, today: DayKey) {
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
        for item in items {
            if let ratio = Measures.progressRatio(for: item, measures: measures, days: week.week.days, entries: entries, work: work) {
                progress[item.code] = ratio
            }
            worked[item.code] = Measures.workedDays(for: item, measures: measures, days: week.week.days, entries: entries, work: work)
        }
        let free = Set(days.filter { DayTypes.isWorkFree($0.dayType) }.map(\.day))
        return WeekData(week: week.week, goals: goals, categories: categories, items: items, marks: marksByKey,
                        overrides: overridesByKey, isComplete: Scorer.isComplete(week: week.week, today: today, closed: isClosed),
                        progress: progress, worked: worked, workFreeDays: free)
    }
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
        if let overall = score.overall {
            out.append("**Wochenwertung: \(Format.score(overall))/10** · \(score.coverageText) · gleich gewichtete Jahresziele (je 10 %) · \(status)")
        } else {
            out.append("Noch keine Wertung (Kategorien nicht vollständig ausgefüllt) · \(status)")
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

        out.append("## Tage")
        out.append("| Tag | Typ | Wertung | Ausgefüllt | Abschluss | Journal | Notiz |")
        out.append("|---|---|---|---|---|---|---|")
        let journalItem = input.items.first { ReflectionQuestion.isJournalTitle($0.title) }
        for day in week.days {
            let info = input.days.first { $0.day == day }
            let overall = score.days[day]
            let journal = journalSymbol(input, data: data, item: journalItem, day: day)
            out.append("| \(day.shortLabel) | \(info?.dayType ?? "") | \(Format.score(overall?.score, outOf: false)) | \(overall?.coverageText ?? "–") | \(input.closedDays.contains(day) ? "✓" : "–") | \(journal) | \(info?.note ?? "") |")
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
                    if let target = measure.target, measure.period == .week { line += " (Ziel \(target.label) – \(target.isMet(value) ? "erreicht" : "nicht erreicht"))" }
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
            out.append("- Nicht ausgefüllt: \(blanks) fällige Punkte (weder Haken noch N/A) – kein automatisches Versäumnis.")
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
                        parts.append("\(item.title): Wochenziel zu \(Int((ratio * 100).rounded())) % erreicht")
                    }
                    continue
                }
                let missed = input.marks.filter { $0.itemCode == item.code && $0.mark == .missed }.sorted { $0.day < $1.day }
                if !missed.isEmpty {
                    let notes = missed.map(\.note).filter { !$0.isEmpty }
                    var text = "\(item.title) ✗ \(missed.map(\.day.weekday.short).joined(separator: ", "))"
                    if item.knockout { text += " (Null-Regel)" }
                    if !notes.isEmpty { text += " (\(notes.joined(separator: "; ")))" }
                    parts.append(text)
                }
                if let target = item.schedule.weeklyTarget, data.isComplete {
                    let used = input.week.week.days.filter { data.mark(item, on: $0)?.counts == true }.count
                    if used < target { parts.append("\(item.title) \(used) von \(target)/Woche") }
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
        public var firstFour: Double?
        public var lastFour: Double?
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
            return GoalLine(key: goal.key, title: goal.title, average: PeriodReport.mean(scores),
                            firstFour: PeriodReport.mean(Array(scores.prefix(4))), lastFour: PeriodReport.mean(Array(scores.suffix(4))))
        }

        var missedCounts: [String: (categoryKey: String, count: Int)] = [:]
        for input in sorted {
            let items = Dictionary(input.items.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })
            for mark in input.marks where mark.mark == .missed {
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

    /// "↑", "↓", "→" (first vs. last four weeks), "–" without both.
    static func trend(_ line: GoalLine) -> String {
        guard let first = line.firstFour, let last = line.lastFour else { return "–" }
        if last - first > 0.25 { return "↑" }
        if first - last > 0.25 { return "↓" }
        return "→"
    }

    /// The review as Markdown to paste into ChatGPT.
    public func markdown(period: GoalPeriod) -> String {
        var out: [String] = []
        let review = period.reviewWeek
        out.append("# Zielüberprüfung \(review.label) (\(review.rangeLabel) \(review.year))")
        out.append("Zieljahr seit \(period.start.longLabel) · ausgewertet \(start.longLabel) bis \(end.longLabel)")
        if !period.motto.isEmpty { out.append("Motto: \(period.motto)") }
        out.append("Hinweis: Die Wertungen messen Verhalten, nicht Ergebnisse (0–10, Jahresziele gleich gewichtet).")
        out.append("")

        out.append("## Jahresziele")
        out.append("| Ziel | Ø seit Start | erste 4 Wochen | letzte 4 Wochen | Trend |")
        out.append("|---|---|---|---|---|")
        for line in goals {
            out.append("| \(line.key) \(line.title) | \(Format.score(line.average)) | \(Format.score(line.firstFour)) | \(Format.score(line.lastFour)) | \(PeriodReport.trend(line)) |")
        }
        out.append("")

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
    public static func text(for week: WeekKey, goals: [GoalRecord], categories: [CategoryRecord], measures: [MeasureRecord],
                            lastWeekReport: String?, changes: [PlanChangeRecord] = [], currentPlan: String? = nil,
                            currentPlanWeek: WeekKey? = nil, trend: [String] = []) -> String {
        var out: [String] = []
        out.append("Du hilfst mir, meinen Wochenplan für \(week.longLabel) (\(week.rangeLabel)) in meine Tracking-App „Thalia“ zu übertragen. Meine Nachricht mit Rückblick, Zusagen, Prioritäten, Zielen und Ausnahmen steht ganz unten.")
        out.append("")
        out.append("## Grundsätze")
        out.append(contentsOf: [
            "- Fundamentjahr: auftauchen, nützliches Verhalten wiederholen, konsistent werden – ohne unnötigen Druck. Eine gute Woche ist kein Grund, den Plan zu erhöhen; nichts unaufgefordert steigern.",
            "- Die zehn Jahresziele sind die Grundlage. Pro Kategorie **so viele Punkte wie nötig, um die Wochenziele zu unterstützen – nicht mehr**. Zwei Punkte sind in Ordnung; keine Fülltätigkeiten.",
            "- Schnell abhakbar formulieren: ein Punkt ist eine Ja/Nein-Frage über mein Verhalten („Protein im Zielbereich“, „Essfenster eingehalten“, „Krafttraining gemacht“).",
            "- Essen und Training nur abhaken, keine Details: Protein „im Zielbereich (mindestens x g, mehr ist ok)“, Fasten/Essfenster „eingehalten“, Training/Zone 2 „gemacht“. Kein Mahlzeitenprotokoll (das führe ich in einer anderen App), keine Stunden fürs Fasten.",
            "- Messwerte (measure) nur für Dinge mit einer Zahl: Power-Hours, Anzahlen (z. B. zweite Aufschläge, TEREA, Seiten), Ausgaben, Gewicht, Schlafdauer, Uhrzeiten.",
            "- Journal: nur ein Punkt „Ins Journal eingetragen“ – keine Fragen.",
            "- Arbeit in Power-Hours: 1 PH = 50 Fokusminuten, Nachhilfe ebenso (50-min-Stunde = 1 PH, 100 min = 2 PH). Wochenziele pro Bereich als measure mit link arbeit:<Kategorie> und period woche.",
            "- **Jedes tagesübergreifende Ziel** (8 PH stammloop, 5× Dehnen-Minuten, 100 Seiten, 3 Kontakte …) bekommt immer zwei verknüpfte Zeilen: einen measure mit period woche und target (die Zahl, die ich eintrage oder die aus den Power-Hours kommt) und einen item mit schedule fortschritt und link auf genau diesen measure („An stammloop gearbeitet“). Den Fortschrittspunkt hake ich nicht ab: Thalia leitet ihn aus dem Messwert ab (Tag mit Wert = gearbeitet) und bewertet am Ende – oder sobald das Ziel erreicht ist – rückwirkend nach dem Wochenergebnis. So zeigt die App für jedes Wochenziel einen Fortschrittsbalken mit „heute +x“.",
            "- Gewichtung: Was für meine Ziele wirklich zählt, ist wichtig (Standard). Kleinkram, Journal-Details, Makros und Nice-to-have bekommen in flags „nebensache“: das zählt nur, wenn ich es ausfülle, und die App zeigt es beim schnellen Check-in eingeklappt. Lieber wenige wichtige Punkte als viele gleich laute.",
            "- Freie Tage: Was nur an Arbeitstagen Sinn ergibt (Fokusarbeit, Business, Lernblöcke fürs Geschäft), bekommt flags „arbeit“; an Familien-, Erholungs- und freien Tagen zählt es dann nicht. Was auch an solchen Tagen geht (Mentales, Familie, Hobby, Lesen, Morgenroutine, Dehnen …), bekommt „frei“ oder bleibt ohne Angabe.",
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
        out.append("Komma als Trennzeichen. Werte mit Komma, Anführungszeichen oder Zeilenumbruch in \"doppelte Anführungszeichen\". Leere Spalten leer lassen. Zahlen mit Dezimalpunkt (2.5). Unter dem Codeblock höchstens fünf Zeilen mit Annahmen und aufgelösten Widersprüchen.")
        out.append("")
        out.append("Reihenfolge: eine week-Zeile, sieben day-Zeilen (Mo–So), die measure-Zeilen, dann die item-Zeilen nach Kategorie. goal- und category-Zeilen nur, wenn sich die Struktur ändert.")
        out.append("")
        out.append("## Zeilentypen")
        out.append("| type | id | parent | title | description |")
        out.append("|---|---|---|---|---|")
        out.append("| week | \(week.string) | | Wochenmotto | Kontext, Prioritäten, Ausnahmen, Annahmen |")
        out.append("| day | Datum, z. B. \(week.monday.string) | | Tagestyp: Arbeitstag, Reisetag, Familientag, Erholungstag, Frei, Prüfungstag … | Besonderheit, z. B. „Arbeit endet 15:00“ |")
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
            "- link: bei item die id eines Messwerts. Bei measure die Quelle: leer = manuell | arbeit:3.2 = Power-Hours aus den Arbeitsblöcken dieser Kategorie | health:sleep, health:bedtime, health:bodyMass, health:steps … = Vorschlag aus Apple Health.",
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
        if let plan = currentPlan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty {
            out.append("## Plan von \(currentPlanWeek?.label ?? "letzter Woche") (Ausgangspunkt)")
            out.append("```csv")
            out.append(plan)
            out.append("```")
            out.append("Übernimm diese Zeilen für \(week.label) (Datum in die neue Woche verschieben), ändere nur, was ich unten verlange, und nenne jede Änderung unter dem Codeblock.")
            out.append("")
        }
        if !trend.isEmpty {
            out.append("## Tendenz der letzten 4 Wochen")
            out.append(contentsOf: trend.map { "- \($0)" })
            out.append("")
        }
        out.append("## Mein Rückblick und Plan für \(week.label):")
        out.append("")
        return out.joined(separator: "\n")
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
