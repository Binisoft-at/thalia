import SwiftUI
import BinisoftKit
import ThaliaCore

/// In-app explainers, with Bini's own numbers from the handover: how a week is scored, power-hours
/// vs real hours, what each mark means, and what Thalia calculates versus what stays your call.
struct ExplainerView: View {
    let explainer: Explainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch explainer {
                case .scoring: scoring
                case .powerHours: powerHours
                case .marks: marks
                case .suggestions: suggestions
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.groupedBackground)
        .navigationTitle(title)
        .inlineNavigationTitle()
    }

    private var title: String {
        switch explainer {
        case .scoring: "Wie wird gerechnet?"
        case .powerHours: "Power-Hours"
        case .marks: "Markierungen"
        case .suggestions: "Rechnen und Entscheiden"
        }
    }

    private var scoring: some View {
        Group {
            Step(number: 1, title: "Kategorie am Tag",
                 text: "10 × erreichte Punkte ÷ zählende Punkte. Erledigt = 1, Teilweise = 0,5, Nicht erledigt = 0. Entfällt und leer zählen nicht mit.",
                 example: "Ernährung: 8 von 10 erledigt → 8,0 · Training: 6 von 10 → 6,0")
            Step(number: 2, title: "Kategorie in der Woche",
                 text: "Durchschnitt ihrer gültigen Tageswerte. Ein Tag ohne zählende Punkte ist kein Nullwert, er fällt weg.",
                 example: "Mo 10, Di 5, Rest ohne Punkte → 7,5")
            Step(number: 3, title: "Jahresziel",
                 text: "Durchschnitt seiner Kategorien – gleich gewichtet innerhalb des Ziels.",
                 example: "Fit Body = (8,0 + 6,0) ÷ 2 = 7,0")
            Step(number: 4, title: "Woche",
                 text: "Durchschnitt der zehn Jahresziele. Jedes Ziel ist 10 % – Fit Body mit zwei Kategorien wiegt so viel wie Schlaf mit einer, Binisoft mit fünf nicht mehr.",
                 example: "Fit Body 7,0 und Schlaf 4,0 → (7,0 + 4,0) ÷ 2 = 5,5 – nicht (8 + 6 + 4) ÷ 3")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Nicht geplant ist nicht verpasst. Ein überfälliger Punkt wird aber nicht zu „Entfällt“, nur um die Wertung zu schützen.")
                Text("• Optional heißt nicht automatisch erfolgreich: Eine ganz optionale Woche bleibt unbewertet – weder geschenkte 10 noch automatische 0.")
                Text("• Fehlende Abdeckung bleibt sichtbar: „9/10 Ziele bewertet – nicht voll vergleichbar“.")
                Text("• „n× pro Woche“: jedes Erledigt, Teilweise oder Nicht erledigt verbraucht einen Platz; was am Wochenende fehlt, zählt als nicht erledigt.")
                Text("• Persönliche Null-Regeln (z. B. Schlaf): Nicht erledigt setzt die Kategorie an dem Tag auf 0 – die Messwerte bleiben erhalten.")
                Text("• Deine eigene Wertung ersetzt die Rechnung, wenn du sie setzt.")
                Text("• Seit KW42 2026 gleich gewichtet – ältere Wochen sind nicht direkt vergleichbar.")
                Text("• Eine Verhaltenswertung belegt kein Jahresergebnis: Eine hohe Finanz-Wertung heißt noch nicht, dass das Vermögensziel erreicht ist.")
            }
            .font(.subheadline)
            .card()
        }
    }

    private var powerHours: some View {
        let example = WorkTotals([
            WorkRecord(id: "s", day: .today(), categoryKey: "3.2", task: "stammloop", powerHours: 8),
            WorkRecord(id: "t", day: .today(), categoryKey: "3.3", task: "Nachhilfe", powerHours: 16),
            WorkRecord(id: "h", day: .today(), categoryKey: "3.4", task: "HAEB", powerHours: 3),
            WorkRecord(id: "o", day: .today(), categoryKey: "3.5", task: "Sonstiges", powerHours: 1),
        ])
        return Group {
            Step(number: 1, title: "Eine Power-Hour (PH) = 50 Minuten Fokus",
                 text: "Keine 60-Minuten-Stunde. Pausen zählen nicht.",
                 example: "8 PH stammloop + 3 PH HAEB + 1 PH Sonstiges = 12 PH")
            Step(number: 2, title: "Nachhilfe zählt genauso",
                 text: "Eine Nachhilfestunde (50 Minuten) ist 1 PH, eine Doppelstunde 2 PH. Abweichungen erfasst du in 0,25-Schritten.",
                 example: "16 PH Nachhilfe")
            Step(number: 3, title: "Netto-Arbeitszeit",
                 text: "Alle PH × 50 Minuten.",
                 example: example.explanation)
            Step(number: 4, title: "Schnell erfassen",
                 text: powerHoursCaptureText,
                 example: "Menge 2 PH · Wofür „Thema A“ · +")
            Text("Jeder Eintrag braucht einen Bereich und ein „Wofür“ – ohne Beschreibung sichert Thalia keine Power-Hours. Vorschläge kommen aus deinen Einträgen der letzten Monate im selben Bereich. Höchstens zwei aktive Hauptprojekte: stammloop und HAEB.")
                .font(.subheadline)
                .card()
        }
    }

    private var marks: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Mark.allCases, id: \.self) { mark in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: Optional(mark).symbolName)
                        .font(.title2)
                        .foregroundStyle(Optional(mark).color)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(mark.symbol)  \(mark.label)").font(.headline)
                        Text(markText(mark)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: Optional<Mark>.none.symbolName)
                    .font(.title2)
                    .foregroundStyle(Optional<Mark>.none.color)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("○  leer – nicht erfasst").font(.headline)
                    Text("Weder „Nicht erledigt“ noch „Entfällt“. Bleibt als fehlende Abdeckung sichtbar, bis du den Punkt markierst.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text(markingText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Fortschrittspunkte heißen „Gearbeitet“ und „Nicht heute“ – am Wochenende zählt, wie weit das Wochenziel erreicht ist.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func markText(_ mark: Mark) -> String {
        switch mark {
        case .done: "Zählt 1 Punkt."
        case .partial: "Zählt 0,5 – wo „teilweise“ sinnvoll ist."
        case .missed: "War dran und ist nicht passiert: zählt 0 von 1. Auf Papier dein X."
        case .notApplicable: "Heute nicht dran oder nicht geplant: fällt aus der Rechnung."
        }
    }

    /// R76: direct buttons on Today, stepping through only in the week.
    private var markingText: String {
        #if os(macOS)
        return "Auf „Heute“ klickst du direkt auf Erledigt, Teilweise, Nicht erledigt oder Entfällt – oder drückst 1, 2, 3, 4. Ein zweiter Klick auf die gewählte Markierung leert den Punkt. In der Woche schaltet ein Klick auf eine Zelle der Reihe nach weiter: ✓ → ½ → ✗ → – → leer; das Kontextmenü zeigt alle Möglichkeiten."
        #else
        return "Auf „Heute“ tippst du direkt auf Erledigt, Teilweise, Nicht erledigt oder Entfällt. Ein zweiter Tipp auf die gewählte Markierung leert den Punkt. In der Woche schaltet ein Tipp auf eine Zelle der Reihe nach weiter: ✓ → ½ → ✗ → – → leer."
        #endif
    }

    /// R76: power-hours always with area and "Wofür" – no "+ = 1 PH" any more.
    private var powerHoursCaptureText: String {
        #if os(macOS)
        return "⌘N oder „Erfassen“ → Power-Hours: oben stehen deine letzten drei Einträge zum Anklicken, sonst Bereich, Menge und Wofür – Return sichert. In den Arbeits-Kategorien auf „Heute“ steht die Zeile „Menge · Wofür · +“ direkt unter dem Wochenziel."
        #else
        return "„+“ unten → Power-Hours: oben stehen deine letzten drei Einträge zum Antippen, sonst Bereich, Menge und Wofür – Return sichert. In den Arbeits-Kategorien auf „Heute“ steht die Zeile „Menge · Wofür · +“ direkt unter dem Wochenziel."
        #endif
    }

    private var suggestions: some View {
        Group {
            Step(number: 1, title: "Objektive Einträge – Thalia rechnet",
                 text: "Minuten, Seiten, TEREA, Ausgaben, Trainingseinheiten, Bettzeit: Summen, Fortschritt und klare Schwellen.",
                 example: "Protein 162 g ≥ 150 → Vorschlag „Erledigt“ für „Proteinziel erreichen“")
            Step(number: 2, title: "Berichtete Erledigung – dein Eintrag zählt",
                 text: "Journal geschrieben? Block wie geplant? Anruf gemacht? Dein Haken ist der Beleg. Thalia schließt nicht aus anderen Daten darauf.",
                 example: "Viele Schritte belegen keine geplante Cardio-Einheit.")
            Step(number: 3, title: "Subjektives Urteil – deine Entscheidung",
                 text: "War die Familienzeit aufmerksam? Hat HAEB-Druck auf andere Arbeit abgefärbt? Das trägst du ein oder bestätigst es – nichts wird still überschrieben.",
                 example: "Eigene Kategorie-Wertung im Tagesabschluss")
            Text("Apple Health liefert nur Vorschläge. Sie zählen erst, wenn du sie übernimmst; ein eigener Wert hat Vorrang. Sensible Einträge – Rauchen, Alkohol, Finanzen, Sexualität, Beziehungen – sind sachlich, ohne Moral.")
                .font(.subheadline)
                .card()
        }
    }
}

private struct Step: View {
    let number: Int
    let title: String
    let text: String
    let example: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Brand.accent)
                .frame(width: 34, height: 34)
                .background(Brand.accent.opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(text).font(.subheadline)
                Text(example)
                    .font(.system(.footnote, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Brand.accent.opacity(0.08), in: .rect(cornerRadius: 8))
            }
        }
        .card()
    }
}

/// The explainer as a sheet (from the week screen).
struct ExplainerSheet: View {
    let explainer: Explainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ExplainerView(explainer: explainer)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 560, height: 740)
    }
}
