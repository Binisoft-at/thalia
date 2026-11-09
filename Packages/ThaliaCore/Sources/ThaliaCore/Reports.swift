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
        for day in week.days {
            let info = input.days.first { $0.day == day }
            let overall = score.days[day]
            let journal = input.reviews.first { $0.scope == day.string && $0.field == ReflectionQuestion.journalField }?.text
            out.append("| \(day.shortLabel) | \(info?.dayType ?? "") | \(Format.score(overall?.score, outOf: false)) | \(overall?.coverageText ?? "–") | \(input.closedDays.contains(day) ? "✓" : "–") | \(journal == "ja" ? "✓" : (journal == "nein" ? "✗" : "–")) | \(info?.note ?? "") |")
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

        let dayNotes = input.reviews.filter { $0.field == "notiz" && !$0.text.isEmpty && $0.scope != week.string }
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

/// The prompt for the Sunday planning conversation: it defines Thalia's CSV contract, lists the
/// current structure (so ids stay stable), the plan changes made in the app, and last week's results.
public enum PlanPrompt {
    public static func text(for week: WeekKey, goals: [GoalRecord], categories: [CategoryRecord], measures: [MeasureRecord],
                            lastWeekReport: String?, changes: [PlanChangeRecord] = []) -> String {
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
