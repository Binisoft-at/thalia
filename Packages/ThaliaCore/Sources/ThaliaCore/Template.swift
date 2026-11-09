import Foundation

// Bini's goal structure from the handover (10 annual goals, 18 detailed categories) and a template
// week built from the recent plans (bedtime 22:30–23:00, 150–180 g protein, LOWER/UPPER/FULL BODY,
// TEREA limit with breathing pause, 10 pages, < 50 € a day, 8 PH stammloop, 3 PH HAEB, 1 PH other,
// 16 h tutoring, Wednesday family block …). The template is a starting point – every week the
// real plan comes from the planning conversation and may change, suspend or replace any of it.

public enum Template {
    public static let goals: [GoalRecord] = [
        GoalRecord(key: "1", title: "Fit Body", details: "Zielgewicht und Körperfett, Mobilität, bessere Tennistechnik, verlässlicher zweiter Aufschlag und einhändige Rückhand."),
        GoalRecord(key: "2", title: "Strong Mind", details: "Tägliche mentale Praxis, kalte Duschen, Atmung oder Achtsamkeit, Journaling und bewusstere Reaktionen auf Stress und Impulse."),
        GoalRecord(key: "3", title: "Binisoft & Firmen", details: "Fokussierte Arbeit ohne Projektchaos; ein Projekt mit wiederkehrenden Einnahmen; Fortschritt bei HAEB; Nachhilfe in einem bewussten Budget."),
        GoalRecord(key: "4", title: "Schlaf", details: "Ein verlässlicher Schlafrhythmus und ausreichend Erholung."),
        GoalRecord(key: "5", title: "Bücher", details: "Zehn Bücher abschließen und daraus lernen. Hörbücher zählen."),
        GoalRecord(key: "6", title: "Menschen & Umfeld", details: "Zeit mit Menschen, die ich respektiere und von denen ich lerne; neue Beziehungen; weniger unhilfreiche soziale Muster."),
        GoalRecord(key: "7", title: "Rauchstopp", details: "Fortschritt zum Aufhören mit klaren TEREA-Wochenlimits und ehrlichem Zählen."),
        GoalRecord(key: "8", title: "Vermögen & Liquidität", details: "Vermögens- und Liquiditätsziel erreichen; Überblick, Einnahmen, Sparen und Ausgabenentscheidungen verbessern."),
        GoalRecord(key: "9", title: "Hobby & Können", details: "Mindestens 100 Stunden für ein nichtkommerzielles Hobby mit sichtbarem Ergebnis. Bisher vor allem Kochen."),
        GoalRecord(key: "10", title: "Familie", details: "Präsent sein mit der Familie, Qualitätszeit schützen, verbunden bleiben und verlässlich praktische Verantwortung übernehmen."),
    ]

    public static let categories: [CategoryRecord] = [
        CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung und Gewicht"),
        CategoryRecord(key: "1.2", goalKey: "1", title: "Training und Tennis"),
        CategoryRecord(key: "2.1", goalKey: "2", title: "Mentale Routinen"),
        CategoryRecord(key: "2.2", goalKey: "2", title: "Journaling"),
        CategoryRecord(key: "2.3", goalKey: "2", title: "Selbstmanagement"),
        CategoryRecord(key: "2.4", goalKey: "2", title: "Impulsdisziplin"),
        CategoryRecord(key: "3.1", goalKey: "3", title: "Morgenroutine und Fokus"),
        CategoryRecord(key: "3.2", goalKey: "3", title: "stammloop"),
        CategoryRecord(key: "3.3", goalKey: "3", title: "Nachhilfe"),
        CategoryRecord(key: "3.4", goalKey: "3", title: "HAEB"),
        CategoryRecord(key: "3.5", goalKey: "3", title: "Sonstige Aufgaben"),
        CategoryRecord(key: "4", goalKey: "4", title: "Schlaf"),
        CategoryRecord(key: "5", goalKey: "5", title: "Lesen und Lernen"),
        CategoryRecord(key: "6", goalKey: "6", title: "Beziehungen und soziales Umfeld"),
        CategoryRecord(key: "7", goalKey: "7", title: "Rauchen"),
        CategoryRecord(key: "8", goalKey: "8", title: "Finanzverhalten"),
        CategoryRecord(key: "9", goalKey: "9", title: "Hobby und fokussierter Genuss"),
        CategoryRecord(key: "10", goalKey: "10", title: "Familienpräsenz und Unterstützung"),
    ]

    /// title, description, days, schedule, target, link (measurement), flags
    typealias Row = (String, String, String, String, String, String, String)

    /// Only what supports the week – no filler, no fixed ten (v2). Food and training are simply
    /// "eingehalten"/"gemacht"; counts are measurements.
    static let itemRows: [(String, [Row])] = [
        ("1.1", [
            ("Protein im Zielbereich", "Mindestens 150 g Protein – mehr ist in Ordnung.", "täglich", "fix", "", "", ""),
            ("Essfenster eingehalten", "Erste und letzte Mahlzeit im geplanten Fenster.", "täglich", "fix", "", "", ""),
            ("Fasten eingehalten", "Die geplante Fastenzeit eingehalten.", "täglich", "fix", "", "", ""),
            ("Genug Wasser", "Mindestens 2,5 l über den Tag.", "täglich", "fix", "", "", ""),
            ("Gewicht gemessen", "Morgens wiegen und eintragen.", "Mo,Mi,Fr", "fix", "", "gewicht", ""),
        ]),
        ("1.2", [
            ("Krafttraining", "Die geplante Einheit (LOWER, UPPER, FULL BODY) gemacht.", "Mo,Mi,Fr", "fix", "", "", ""),
            ("Zone 2", "Eine Zone-2-Einheit gemacht.", "Di,Do,Sa,So", "woche:2", "", "", ""),
            ("Tennis an der Wand", "Wandeinheit mit Fokus auf die einhändige Rückhand.", "Di,Do,Sa", "woche:2", "", "", ""),
            ("Zweiter Aufschlag geübt", "Aufschläge üben und die Anzahl eintragen.", "Di,Do,Sa", "woche:2", "", "aufschlaege", ""),
            ("Mobilität und Plank", "Zehn Minuten Mobilität und Plank laut Plan.", "täglich", "fix", "", "", ""),
        ]),
        ("2.1", [
            ("Kalt geduscht", "Mindestens eine Minute kalt am Ende.", "täglich", "fix", "", "", ""),
            ("Atemübung", "Fünf Minuten bewusste Atmung oder Achtsamkeit.", "täglich", "fix", "", "", ""),
            ("Dankbarkeit", "Drei Dinge, für die ich dankbar bin.", "täglich", "fix", "", "", ""),
            ("Meditation", "Zehn Minuten Meditation.", "täglich", "woche:3", "", "", ""),
            ("Atempause bei Stress", "Bei Stress fünf Minuten Atempause, bevor ich reagiere.", "täglich", "bedingt", "", "", ""),
        ]),
        ("2.2", [
            ("Ins Journal eingetragen", "Den Tag im Journal festgehalten.", "täglich", "fix", "", "", ""),
            ("Wochenrückblick", "Woche reflektiert und die nächste vorbereitet.", "So", "fix", "", "", ""),
            ("Auslöser notiert", "Bei Stress oder Impuls: Auslöser und Reaktion notiert.", "täglich", "bedingt", "", "", ""),
        ]),
        ("2.3", [
            ("Tagesplan am Vorabend", "Die drei wichtigsten Punkte für morgen festgelegt.", "täglich", "fix", "", "", ""),
            ("Pünktlich gestartet", "Den ersten Block direkt nach dem Aufstehen begonnen.", "Mo-Fr", "fix", "", "", ""),
            ("Bewusst gestoppt", "Den Block beendet, als Zeit oder Umfang erreicht war.", "Mo-Fr", "fix", "", "", ""),
            ("Erst prüfen, dann zusagen", "Zusätzliche Anfragen bewusst geprüft.", "täglich", "bedingt", "", "", ""),
        ]),
        ("2.4", [
            ("Kein zielloses Scrollen", "Geplante Nutzung ist in Ordnung.", "täglich", "fix", "", "", ""),
            ("Kein Alkohol unter der Woche", "Montag bis Donnerstag kein Alkohol.", "Mo-Do", "fix", "", "", ""),
            ("Keine Spontankäufe", "Nichts außerhalb des Plans gekauft.", "täglich", "fix", "", "", ""),
            ("Impuls benannt", "Bei starkem Impuls zwei Minuten gewartet und benannt, was los ist.", "täglich", "bedingt", "", "", ""),
        ]),
        ("3.1", [
            ("Erster Block vor 9:00", "Der erste Fokusblock begann vor 9:00.", "Mo-Fr", "fix", "", "", ""),
            ("Pausen eingehalten", "Nach jeder Power-Hour echte Pause.", "Mo-Fr", "fix", "", "", ""),
            ("Arbeitsende eingehalten", "Zur geplanten Zeit aufgehört.", "Mo-Fr", "fix", "", "", ""),
        ]),
        ("3.2", [
            ("An stammloop gearbeitet", "Heute an stammloop gearbeitet – zählt am Ende gegen das Wochenziel (8 PH).", "Mo-Fr", "fortschritt", "", "stammloop_ph", ""),
            ("Website-Iteration fertig", "Eine Iteration abgeschlossen – nicht nur daran gearbeitet.", "Mo-Fr", "woche:1", "", "", ""),
            ("Kein Scope Creep", "Neue Ideen geparkt statt in den Block genommen.", "Mo-Fr", "fix", "", "", ""),
        ]),
        ("3.3", [
            ("Nachhilfe gehalten", "Stunden laut Plan gehalten – zählt gegen das Wochenziel in PH.", "Mo-Fr", "fortschritt", "", "nachhilfe_ph", ""),
            ("Vorbereitet", "Material für die Stunden vorbereitet.", "Mo-Fr", "fix", "", "", ""),
            ("Budget eingehalten", "Nicht mehr zugesagt als im Wochenbudget.", "täglich", "fix", "", "", ""),
        ]),
        ("3.4", [
            ("An HAEB gearbeitet", "Im geplanten Block an HAEB gearbeitet – Wochenziel 3 PH.", "Di,Do", "fortschritt", "", "haeb_ph", ""),
            ("Nach dem Block abgeschlossen", "HAEB nach dem Block gedanklich abgeschlossen.", "Di,Do", "fix", "", "", ""),
            ("HAEB nicht in die Familienzeit", "HAEB-Druck notiert und in den nächsten Block gelegt.", "täglich", "bedingt", "", "", ""),
        ]),
        ("3.5", [
            ("Sonstiges erledigt", "Sonstige Aufgaben im Block erledigt – Wochenziel 1 PH.", "Mo-Fr", "fortschritt", "", "sonstiges_ph", ""),
            ("Rechnungen gestellt", "Offene Rechnungen verschickt.", "Fr", "fix", "", "", ""),
        ]),
        ("4", [
            ("Abendroutine um 22:30", "Bildschirme aus, Licht dimmen.", "täglich", "fix", "", "", ""),
            ("Im Bett vor 23:00", "Spätestens 23:00 im Bett.", "täglich", "fix", "<=23:00", "bettzeit", ""),
            ("Kein Bildschirm nach 23:00", "Persönliche Regel: verletzt → Schlaf heute 0.", "täglich", "fix", "", "", "ko"),
            ("Sieben Stunden geschlafen", "Mindestens sieben Stunden.", "täglich", "fix", ">=7", "schlaf", ""),
            ("Erholungspause eingehalten", "Geplante Erholungspause nicht ausfallen lassen. Verletzt → Schlaf heute 0.", "täglich", "bedingt", "", "", "ko"),
        ]),
        ("5", [
            ("Zehn Seiten gelesen", "Mindestens zehn Seiten (Hörbuch zählt).", "täglich", "fix", ">=10", "seiten", ""),
            ("Erkenntnis notiert", "Eine Erkenntnis aus dem Gelesenen.", "täglich", "fix", "", "", ""),
        ]),
        ("6", [
            ("Sinnvoller Kontakt", "Jemanden kontaktiert, von dem ich lerne – ein Versuch zählt.", "täglich", "woche:2", "", "", ""),
            ("Pläne privat gehalten", "Pläne und Zahlen nur bewusst geteilt.", "täglich", "fix", "", "", ""),
            ("Gespräch höflich beendet", "Ein zehrendes Gespräch freundlich und klar beendet.", "täglich", "bedingt", "", "", ""),
        ]),
        ("7", [
            ("TEREA-Limit eingehalten", "Höchstens die vereinbarte Zahl; Ausnahmetage beachten.", "täglich", "fix", "<=6", "terea", ""),
            ("Atempause vor dem Rauchen", "Fünf Minuten Atempause vorher.", "täglich", "fix", "", "", ""),
            ("Rauchfreier Abend", "Nach 20:00 rauchfrei.", "täglich", "fix", "", "", ""),
        ]),
        ("8", [
            ("Unter 50 € ausgegeben", "Private Ausgaben unter dem Richtwert.", "täglich", "fix", "<50", "ausgaben", ""),
            ("Kontostand geprüft", "Kontostände angesehen.", "täglich", "woche:1", "", "", ""),
            ("Sparbetrag überwiesen", "Den geplanten Betrag überwiesen.", "täglich", "woche:1", "", "", ""),
        ]),
        ("9", [
            ("Am Hobby gearbeitet", "Nichtkommerzielle Hobbyzeit – Wochenziel 2 h.", "täglich", "fortschritt", "", "hobby", ""),
            ("Neues Rezept", "Ein neues Rezept gekocht.", "täglich", "woche:1", "", "", ""),
        ]),
        ("10", [
            ("Präsente Familienzeit", "Telefon weg, aufmerksam, freundlicher Ton.", "täglich", "fix", "", "", ""),
            ("Praktisch geholfen", "Eine konkrete Aufgabe zu Hause übernommen.", "täglich", "fix", "", "", ""),
            ("Mittwoch-Familienblock", "Arbeit endet um 15:00.", "Mi", "fix", "", "", ""),
            ("Samstag gemeinsam", "Der Samstag gehört der Familie.", "Sa", "fix", "", "", ""),
            ("Sonntagmorgen gemeinsam", "Der Sonntagmorgen gehört der Familie.", "So", "fix", "", "", ""),
        ]),
    ]

    /// code, title, unit, target, period, link (source), category, flags, description
    typealias MeasureRow = (String, String, String, String, String, String, String, String, String)

    /// Only things with a number (v2): PH, counts, times, weight.
    static let measureRows: [MeasureRow] = [
        ("gewicht", "Gewicht", "kg", "", "tag", "health:bodyMass", "1.1", "", "Morgens nüchtern."),
        ("aufschlaege", "Zweite Aufschläge", "Stück", ">=100", "woche", "", "1.2", "", ""),
        ("stammloop_ph", "stammloop", "PH", ">=8", "woche", "arbeit:3.2", "3.2", "", "Power-Hours aus den Arbeitsblöcken."),
        ("nachhilfe_ph", "Nachhilfe", "PH", ">=16", "woche", "arbeit:3.3", "3.3", "", "50-min-Stunde = 1 PH, Doppelstunde = 2 PH."),
        ("haeb_ph", "HAEB", "PH", ">=3", "woche", "arbeit:3.4", "3.4", "", ""),
        ("sonstiges_ph", "Sonstiges", "PH", ">=1", "woche", "arbeit:3.5", "3.5", "", ""),
        ("schlaf", "Schlaf", "h", ">=7", "tag", "health:sleep", "4", "letzter", ""),
        ("bettzeit", "Im Bett", "Uhrzeit", "<=23:00", "tag", "health:bedtime", "4", "", ""),
        ("seiten", "Seiten", "Seiten", ">=10", "tag", "", "5", "", ""),
        ("terea", "TEREA", "Stück", "<=6", "tag", "", "7", "", "Ehrlich zählen; Ausnahmetage stehen im Wochenplan."),
        ("ausgaben", "Ausgaben", "€", "<50", "tag", "", "8", "", "Privater Richtwert."),
        ("hobby", "Hobby", "min", ">=120", "woche", "", "9", "", "Nichtkommerziell."),
    ]

    /// Day types of the template week: Wednesday family block, Saturday family, Sunday rest.
    static let dayRows: [(Weekday, String, String)] = [
        (.monday, "Arbeitstag", ""),
        (.tuesday, "Arbeitstag", "HAEB-Block"),
        (.wednesday, "Arbeitstag", "Arbeit endet um 15:00 – Familienblock."),
        (.thursday, "Arbeitstag", "HAEB-Block"),
        (.friday, "Arbeitstag", ""),
        (.saturday, "Familientag", "Samstag gemeinsam, keine Arbeit."),
        (.sunday, "Erholungstag", "Sonntagmorgen mit der Familie, Wochenrückblick."),
    ]

    /// The template plan for a week, as a document.
    public static func week(_ week: WeekKey, includeStructure: Bool = true) -> PlanCSV.Document {
        var doc = PlanCSV.Document()
        if includeStructure {
            doc.goals = goals
            doc.categories = categories
        }
        doc.weeks = [WeekRecord(
            week: week,
            title: "Wiederholen statt steigern",
            details: "Vorlagewoche: Schlaf hat Vorrang, Familienblöcke sind kein Arbeitspuffer. Arbeit in Power-Hours (1 PH = 50 min, Nachhilfe auch): 8 PH stammloop, 3 PH HAEB, 1 PH Sonstiges, 16 PH Nachhilfe = 28 PH ≈ 23,3 h netto. Bitte jede Woche mit dem aktuellen Plan ersetzen."
        )]
        doc.days = dayRows.map { DayRecord(day: week.day($0.0), dayType: $0.1, note: $0.2) }
        for (index, row) in measureRows.enumerated() {
            doc.measures.append(MeasureRecord(
                week: week, code: row.0, categoryKey: row.6, position: index + 1, title: row.1, details: row.8, unit: row.2,
                target: Target.parse(row.3), period: TargetPeriod(raw: row.4), source: MeasureSource(raw: row.5),
                aggregation: Aggregation(token: row.7), days: .everyDay
            ))
        }
        for (category, rows) in itemRows {
            for (index, row) in rows.enumerated() {
                doc.items.append(ItemRecord(
                    week: week, code: "\(category)-" + String(format: "%02d", index + 1), categoryKey: category,
                    position: index + 1, title: row.0, details: row.1, days: DayMask.parse(row.2) ?? .everyDay,
                    schedule: ItemSchedule(raw: row.3), target: Target.parse(row.4), measure: row.5, knockout: row.6 == "ko"
                ))
            }
        }
        doc.plannedWeeks = [week]
        doc.measuredWeeks = [week]
        return doc
    }

    /// The template week as CSV text (Import → "Vorlagewoche").
    public static func weekCSV(_ week: WeekKey, includeStructure: Bool = true) -> String {
        PlanCSV.export(Template.week(week, includeStructure: includeStructure))
    }

    /// Only the goal structure (10 goals, 18 categories).
    public static func structureCSV() -> String {
        var doc = PlanCSV.Document()
        doc.goals = goals
        doc.categories = categories
        return PlanCSV.export(doc)
    }
}
