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
                 text: "10 × erreichte Punkte ÷ zählende Punkte. ✓ = 1, ½ = 0,5, ✗ = 0. N/A und leer zählen nicht mit.",
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
                Text("• Nicht geplant ist nicht verpasst. Ein überfälliger Punkt wird aber nicht zu N/A, nur um die Wertung zu schützen.")
                Text("• Optional heißt nicht automatisch erfolgreich: Eine ganz optionale Woche bleibt unbewertet – weder geschenkte 10 noch automatische 0.")
                Text("• Fehlende Abdeckung bleibt sichtbar: „9/10 Ziele bewertet – nicht voll vergleichbar“.")
                Text("• „n× pro Woche“: jeder ✓ ½ ✗ verbraucht einen Platz; was am Wochenende fehlt, zählt als verpasst.")
                Text("• Persönliche Null-Regeln (z. B. Schlaf): ✗ setzt die Kategorie an dem Tag auf 0 – die Messwerte bleiben erhalten.")
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
                 text: "Eine Nachhilfestunde (50 Minuten) ist 1 PH, eine Doppelstunde 2 PH. Abweichungen trägst du einfach mit 0,25-Schritten ein.",
                 example: "16 PH Nachhilfe")
            Step(number: 3, title: "Netto-Arbeitszeit",
                 text: "Alle PH × 50 Minuten.",
                 example: example.explanation)
            Step(number: 4, title: "Schnell erfassen",
                 text: "Auf der Kachel einer Kategorie: + tippen ist 1 PH, halten zeigt 0,25 bis 2 PH. Mit Beschreibung (z. B. „Lena – Mathe“) über „+“ unten.",
                 example: "+ 1 PH · stammloop")
            Text("Zu einem Eintrag gehört idealerweise eine Beschreibung – Thalia schlägt dir die bisherigen pro Kategorie vor. Höchstens zwei aktive Hauptprojekte: stammloop und HAEB.")
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
                    Text("leer – noch nicht erfasst").font(.headline)
                    Text("Weder Versäumnis noch N/A. Bleibt als fehlende Abdeckung sichtbar, bis du es einträgst.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Text("Tippen wechselt ✓ → ½ → ✗ → N/A → leer. Gedrückt halten zeigt alle Möglichkeiten. Wischen: rechts ✓ / ½, links ✗ / N/A.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private func markText(_ mark: Mark) -> String {
        switch mark {
        case .done: "Zählt 1 Punkt."
        case .partial: "Zählt 0,5 – wo „teilweise“ sinnvoll ist."
        case .missed: "Fällig und nicht erledigt: zählt 0 von 1. Auf Papier dein X."
        case .notApplicable: "Nicht fällig oder nicht geplant: fällt aus der Rechnung."
        }
    }

    private var suggestions: some View {
        Group {
            Step(number: 1, title: "Objektive Einträge – Thalia rechnet",
                 text: "Minuten, Seiten, TEREA, Ausgaben, Trainingseinheiten, Bettzeit: Summen, Fortschritt und klare Schwellen.",
                 example: "Protein 162 g ≥ 150 → Vorschlag ✓ für „Proteinziel erreichen“")
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
                    ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                }
        }
        .sheetFrame(minWidth: 560, minHeight: 620)
    }
}
