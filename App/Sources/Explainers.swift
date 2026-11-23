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
                 text: "Durchschnitt der Jahresziele. Jedes Jahresziel zählt gleich viel – Fit Body mit zwei Kategorien wiegt so viel wie Schlaf mit einer, Binisoft mit fünf nicht mehr.",
                 example: "Fit Body 7,0 und Schlaf 4,0 → (7,0 + 4,0) ÷ 2 = 5,5 – nicht (8 + 6 + 4) ÷ 3")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Nicht geplant ist nicht verpasst. Ein überfälliger Punkt wird aber nicht zu „Entfällt“, nur um die Wertung zu schützen.")
                Text("• Optional heißt nicht automatisch erfolgreich: Eine ganz optionale Woche bleibt unbewertet – weder geschenkte 10 noch automatische 0.")
                Text("• Fehlende Abdeckung bleibt sichtbar: z. B. „9 von 10 Zielen bewertet“ – nicht voll vergleichbar.")
                Text("• „n× pro Woche“: jedes Erledigt, Teilweise oder Nicht erledigt verbraucht einen Platz; was am Wochenende fehlt, zählt als nicht erledigt – außer es ging wegen Krank oder Urlaub nicht mehr: dann zählt es halb.")
                Text("• Krank- und Urlaubstage zählen nicht in die Wochenwertung. Ist die ganze Woche krank oder Urlaub, bleibt sie ohne Wertung: „Woche zählt nicht (krank/Urlaub)“.")
                Text("• Persönliche Null-Regeln (z. B. Schlaf): Nicht erledigt setzt die Kategorie an dem Tag auf 0 – die Messwerte bleiben erhalten.")
                Text("• Deine eigene Wertung ersetzt die Rechnung, wenn du sie setzt.")
                Text("• Seit KW42 2026 gleich gewichtet – ältere Wochen sind nicht direkt vergleichbar.")
                Text("• Eine Verhaltenswertung belegt kein Jahresergebnis: Eine hohe Finanz-Wertung heißt noch nicht, dass das Vermögensziel erreicht ist.")
            }
            .font(.subheadline)
            .card()
            FeatureExplainerLinks()
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
            Text("An Krank- und Urlaubstagen ist nichts fällig. Markierungen von vorher bleiben gespeichert, zählen aber nicht und erscheinen gedimmt; zurück auf „Arbeitstag“ zählen sie wieder.")
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

/// v8: explainers for the three new features. `Explainer` (AppModel) stays as it is; these open from
/// the "Neu seit 1.7" card at the end of "Wie wird gerechnet?" – a NavigationStack is around every explainer.
enum FeatureExplainer: String, CaseIterable, Identifiable {
    case excused, pastWeeks, rangePDF
    // v10 (1.9.0)
    case goalResults, reading, segments, connectedApps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .excused: "Krank & Urlaub"
        case .pastWeeks: "Vergangene Wochen"
        case .rangePDF: "PDF-Bericht"
        case .goalResults: "Ergebnisse und Wochen über 8"
        case .reading: "Leseliste"
        case .segments: "Abschnitte"
        case .connectedApps: "Verbundene Apps"
        }
    }

    var symbol: String {
        switch self {
        case .excused: "cross.case"
        case .pastWeeks: "clock.arrow.circlepath"
        case .rangePDF: "doc.richtext"
        case .goalResults: "trophy"
        case .reading: "books.vertical"
        case .segments: "square.split.2x1"
        case .connectedApps: "arrow.left.arrow.right"
        }
    }
}

/// The links to the v8 explainers, as one card.
struct FeatureExplainerLinks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // v9: 1.8 adds "Archiv-Wochen" as a step of "Vergangene Wochen".
            Label("Neu seit 1.7", systemImage: "sparkles")
                .font(.headline)
            ForEach(FeatureExplainer.allCases) { feature in
                NavigationLink {
                    FeatureExplainerView(feature: feature)
                } label: {
                    HStack {
                        Label(feature.title, systemImage: feature.symbol)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .card()
    }
}

/// One v8 feature explained, in the same layout as `ExplainerView`.
struct FeatureExplainerView: View {
    let feature: FeatureExplainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch feature {
                case .excused: excused
                case .pastWeeks: pastWeeks
                case .rangePDF: rangePDF
                case .goalResults: goalResults
                case .reading: reading
                case .segments: segments
                case .connectedApps: connectedApps
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.groupedBackground)
        .navigationTitle(feature.title)
        .inlineNavigationTitle()
    }

    // MARK: Krank & Urlaub

    private var excused: some View {
        Group {
            Step(number: 1, title: "Tag als Krank oder Urlaub",
                 text: excusedSettingText,
                 example: "Fr: Krank · Sa: Krank · So: Krank")
            Step(number: 2, title: "Was an dem Tag gilt",
                 text: "Kein Punkt ist fällig und der Tag ist nie offen: kein Ring, keine Abend-Erinnerung, kein Hinweis am nächsten Morgen. Abschließen ist nicht nötig. Werte lassen sich weiter eintragen und zählen in den Wochensummen.",
                 example: "Woche: Spalte grau, Zellen „–“ · Heute: „Krank – zählt nicht“")
            Step(number: 3, title: "„n× pro Woche“: was nicht mehr ging, zählt halb",
                 text: "Fehlt am Wochenende etwas, weil Tage krank oder Urlaub waren, zählt das als Teilweise – höchstens so viel, wie auf diese Tage fiel (n × entschuldigte Tage ÷ geplante Tage).",
                 example: "3× Training, Mo und Mi erledigt, ab Fr krank → das dritte zählt ½: (10 + 10 + 5) ÷ 3 = 8,33 statt 6,67")
            Step(number: 4, title: "Wochenziele schrumpfen mit",
                 text: "Fortschrittspunkte und Wochen-Messziele zählen nur den Anteil der Tage, die bleiben. Grenzen wie „höchstens 6“ bleiben gleich.",
                 example: "8 PH Mo–Fr, Do und Fr krank → Ziel 4,8 PH: 4 PH = Teilweise, 5 PH = erreicht")
            Step(number: 5, title: "Ganze Woche krank oder Urlaub",
                 text: "Fällt alles Geplante auf solche Tage, bekommt die Woche keine Wertung. Rückblick, Ziele und PDF zeigen „entschuldigt“, der Durchschnitt lässt sie aus.",
                 example: "KW44: Woche zählt nicht (krank/Urlaub)")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Markierungen von vor der Krankmeldung bleiben gespeichert, zählen aber nicht und erscheinen gedimmt. Zurück auf „Arbeitstag“ – dann zählen sie wieder.")
                Text("• Eigene Tageswertungen zählen an solchen Tagen nicht.")
                Text("• Ziele, deren Punkte nur auf solche Tage fielen, zählen nicht bei „x/y Ziele bewertet“.")
                Text("• Auch eigene Tagestypen mit „krank“ oder „urlaub“ im Namen zählen so.")
                Text("• Familientag und Erholungstag sind etwas anderes: Dort entfallen nur Arbeitspunkte, der Rest bleibt fällig.")
            }
            .font(.subheadline)
            .card()
        }
    }

    private var excusedSettingText: String {
        #if os(macOS)
        return "Heute: Titelmenü in der Symbolleiste → Tagestyp → „Krank“ oder „Urlaub“ (ganz oben). In der Woche: Rechtsklick auf den Tag. Auch im Tagesabschluss."
        #else
        return "Heute: oben auf den Titel tippen → Tagestyp → „Krank“ oder „Urlaub“ (ganz oben). In der Woche: lange auf den Tag drücken. Auch im Tagesabschluss."
        #endif
    }

    // MARK: Vergangene Wochen

    private var pastWeeks: some View {
        Group {
            Step(number: 1, title: "Das Fenster",
                 text: pastWeeksOpenText,
                 example: "Vom Plan · Mit ChatGPT · Nur Wertung")
            Step(number: 2, title: "Vom Plan",
                 text: "Die Punkte der nächstgelegenen geplanten Woche kommen in die gewählte Woche, ohne Markierungen. Dann in der Woche abhaken, Krank- und Urlaubstage setzen und die Woche abschließen – erst dann zählt sie. Hat die Woche schon einen Plan, kommt er ins Archiv – „Widerrufen“ holt ihn zurück.",
                 example: "Plan von KW47 übernehmen → KW44")
            Step(number: 3, title: "Mit ChatGPT – auch viele Wochen auf einmal",
                 text: "„Prompt kopieren“, in ChatGPT Fotos, PDFs oder Tabellen dazulegen. Zurück kommt eine CSV mit einem Block je Woche: Tage (auch Krank/Urlaub), die Wertung laut Unterlagen, Kategorien- und Zielnoten 0–10 und nur belegte Einzelhaken. CSV einfügen oder „Datei…“ → Vorschau je Woche → Importieren. Zeitraum: „Wochen aus den Unterlagen“ oder ein fester Bereich von–bis.",
                 example: "KW43 2026 · neu · 12 Kategoriennoten · 10 Zielnoten · Wertung 9,28 laut Unterlagen")
            Step(number: 4, title: "Archiv-Wochen",
                 text: "Eine Woche nur mit Wertung und Noten bekommt keine Punkte – nichts ist offen oder verpasst. Die Woche zeigt die Karte „Archiv“: die Wertung laut Unterlagen, daneben „Nach heutigen Regeln“ aus den Kategoriennoten (ohne Krank- und Urlaubstage), die Noten Mo–So mit Ø (n) und „Ohne Zuordnung (Archiv)“ für alte Bezeichnungen. Für einen erneuten Import: „Archivdaten dieser Wochen ersetzen“.",
                 example: "Wertung laut Unterlagen 9,28 · Nach heutigen Regeln 8,93 · ohne 2 Urlaubstage")
            Step(number: 5, title: "Nur Wertung",
                 text: "Für Wochen, von denen nur die Zahl vom Papier bekannt ist: Woche wählen, Wertung 0–10 eintragen – die Wertung laut Unterlagen. Sie erscheint im Rückblick; mehrere Wochen nacheinander gehen ohne Schließen.",
                 example: "KW38 · 7,5")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Per CSV nachgetragene vergangene Wochen werden mit ihren Tagen abgeschlossen – so zählen sie im Rückblick, bei den Zielen und im Ø 4 Wo.")
                Text("• Leere Felder bleiben leer. Nur mit dem Schalter „Leere Felder als ✗ zählen“ werden sie zu Nicht erledigt.")
                Text("• Diese und spätere Wochen werden nicht abgeschlossen; die Vorschau warnt.")
                Text("• Markierungen auf Punkte, die weder in der Datei noch in der App stehen, meldet die Vorschau.")
                Text("• Eine ersetzte Woche kommt ins Archiv und lässt sich widerrufen.")
                Text("• Ein ergänzender Import entfernt nichts. Erst „Archivdaten dieser Wochen ersetzen“ nimmt alte, falsche Punkte und Markierungen dieser Wochen heraus – diese Woche und spätere nie.")
                Text("• Im Rückblick und im PDF zählt die Wertung laut Unterlagen vor der berechneten.")
                Text("• Aus Noten macht Thalia nie Haken oder Messwerte; fehlende Einzelhaken, Arbeitszeiten und Messwerte bleiben unbekannt.")
            }
            .font(.subheadline)
            .card()
        }
    }

    private var pastWeeksOpenText: String {
        #if os(macOS)
        return "Ablage → „Vergangene Woche nachtragen…“, auch rechts in der Woche (Wochenübersicht) und im Import unter „Vorlagen“. Wählbar sind die Wochen ab Beginn des Zieljahrs – mindestens 52 Wochen zurück – bis letzte Woche."
        #else
        return "Woche → … → „Vergangene Woche nachtragen…“, auch im Import unter „Vorlagen“. Wählbar sind die Wochen ab Beginn des Zieljahrs – mindestens 52 Wochen zurück – bis letzte Woche."
        #endif
    }

    // MARK: PDF-Bericht

    private var rangePDF: some View {
        Group {
            Step(number: 1, title: "Das Fenster",
                 text: rangePDFOpenText,
                 example: "Rückblick → PDF-Bericht")
            Step(number: 2, title: "Zeitraum und Umfang",
                 text: "Letzte 4, 8 oder 13 Wochen (bis zur letzten fertigen Woche), Zieljahr bis heute oder ein eigener Zeitraum von–bis. Umfang: nur Übersicht, + Wochenübersicht je Woche (Deckblatt und Tabellen) oder + Rückblick-Texte.",
                 example: "Letzte 8 Wochen · + Wochenübersicht je Woche · 42 Seiten")
            Step(number: 3, title: "Was drinsteht",
                 text: "Deckblatt mit Ø-Ring, Kacheln, Balken je Woche und den Jahreszielen mit Ø und Trend; eine Übersicht mit einer Zeile je Woche (Wertung, Ziele in Zielfarbe, PH, abgeschlossene Tage, Krank/Urlaub, Wochenziele); Power-Hours je Bereich; danach die Wochenseiten. Die Seitenzahlen laufen durch.",
                 example: "1 Fit Body · Ø 7,2 · ↑ steigend")
            Step(number: 4, title: "Erzeugen und teilen",
                 text: rangePDFShareText,
                 example: "Seite 37 von 120")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Der Ø zählt nur gleich gewichtete Wochen (ab KW42 2026) mit Wertung; entschuldigte Wochen (krank/Urlaub) fallen weg.")
                Text("• Trend je Ziel: die letzten gegen die ersten Wochen – je bis zu vier, ohne Überschneidung, erst ab 4 gewerteten Wochen; bei mehr als 0,25 Unterschied steigend oder fallend – wie in der Zielüberprüfung.")
                Text("• Wochen ohne Punkte (Papier-Wertung oder Archiv) stehen als Zeile in der Übersicht, ohne eigene Seiten; ihre Wertung ist die laut Unterlagen.")
            }
            .font(.subheadline)
            .card()
        }
    }

    private var rangePDFOpenText: String {
        #if os(macOS)
        return "Ablage → „Zeitraum als PDF…“ (⌥⌘P), Rückblick → „PDF-Bericht“ oder rechts in der Woche (Wochenübersicht). Im Rückblick per Rechtsklick auf eine Woche auch „PDF-Bericht ab dieser Woche“."
        #else
        return "Rückblick → „PDF-Bericht“ oder Woche → … → „Mehrere Wochen als PDF…“. Im Rückblick eine Woche gedrückt halten → „PDF-Bericht ab dieser Woche“."
        #endif
    }

    private var rangePDFShareText: String {
        #if os(macOS)
        return "Thalia baut den Bericht Seite für Seite – abbrechen geht jederzeit – und zeigt ihn in der Vorschau. Dann sichern (⌘S), drucken (⌘P) oder teilen. Lesezeichen führen zu jeder Woche."
        #else
        return "Thalia baut den Bericht Seite für Seite – abbrechen geht jederzeit – und zeigt ihn in der Vorschau. Dann teilen, etwa in Dateien oder per Mail. Lesezeichen führen zu jeder Woche."
        #endif
    }

    // MARK: v10 – Ergebnisse und Wochen über 8

    private var goalResults: some View {
        Group {
            Step(number: 1, title: "Ergebnisse eines Jahresziels",
                 text: "Ziele → ein Ziel → „Ergebnisse“ → „Ergebnis anlegen“. Drei Arten: abhaken (erledigt am Tag des Eintrags), zählen (Einträge, fertige Bücher der Leseliste, ein Messwert oder eine verbundene App) und Zielwert (der letzte Wert zählt, mit Startwert).",
                 example: "Website online ✓ · Bücher 3 von 10 · Zielwert auf Kurs")
            Step(number: 2, title: "Stand und Tempo",
                 text: "Die Zeile zeigt Stand, Ziel und Status: „auf Kurs“, wenn der Stand mindestens dem gleichmäßigen Tempo bis heute entspricht, sonst „im Rückstand“; „erreicht“, sobald das Ziel erfüllt ist. Eine Grenze wie „höchstens 20 Packungen“ ist „im Rahmen“, „zu schnell“ oder „überschritten“ und am Ende „eingehalten“. Ohne Ziel steht nur der Stand.",
                 example: "7 von 10 · davon 4 in Abschnitt 2 · auf Kurs")
            Step(number: 3, title: "Eintragen – auch rückwirkend",
                 text: goalEntryText,
                 example: "Jahresziel eintragen · Zählt für Di, 17. Nov.")
            Step(number: 4, title: "Wochen über 8",
                 text: "Eine Kategorie ist in einer Woche gut dabei, wenn ihre Wochennote gerundet mindestens 8,00 ist – 7,99 nicht. Ein Ziel ist gut dabei, wenn jede seiner gewerteten Kategorien es ist. Entschuldigte Wochen zählen nicht mit.",
                 example: "✓ über 8 · Wochen über 8: 1.1 9/12 · 1.2 7/12")
            Step(number: 5, title: "Messwerte im Ziel",
                 text: "Die Zielkarte zeigt bis zu drei Messwerte der Kategorien des Ziels, die Zielseite alle mit Wochenwert und Ziel. Ein Messwert, der ein Ergebnis speist, sagt das in „Wochenziele“ und im Messwert-Editor.",
                 example: "zählt für Ziel 5 · Bücher 3/10")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• „Wochen über 8“ zählt die letzten zwölf gewerteten Wochen im aktuellen Abschnitt.")
                Text("• Die Planung sieht die Ergebnisse als Information – sie steigert nichts unaufgefordert. Werte aus Apple Health stehen nie darin.")
                Text("• Ein gelöschtes Ergebnis liegt mit seinen Einträgen 30 Tage unter „Zuletzt gelöscht“.")
            }
            .font(.subheadline)
            .card()
        }
    }

    private var goalEntryText: String {
        #if os(macOS)
        return "Zum Tag gehen, dann „Erfassen“ (⇧⌘N) → „Jahresziel eintragen“: Ergebnis wählen, abhaken, +1 oder einen Wert. Das Datum ist vorbelegt und änderbar. Auf der Seite eines Ergebnisses lassen sich Einträge ändern und löschen."
        #else
        return "Zum Tag gehen, dann + → „Jahresziel eintragen“: Ergebnis wählen, abhaken, +1 oder einen Wert. Das Datum ist vorbelegt und änderbar. Auf der Seite eines Ergebnisses lassen sich Einträge ändern und löschen."
        #endif
    }

    // MARK: v10 – Leseliste

    private var reading: some View {
        Group {
            Step(number: 1, title: "Die Leseliste",
                 text: "Ziele → Jahreskarte → ••• → „Leseliste“, ab dem ersten Buch auch über die Karte „Gerade dabei“. Läuft, Geplant, Fertig (nach Abschnitt) und Abgebrochen, mit Suche. + legt ein Buch an: Titel, Autor:in, Seiten, Art, „Zählt für“ und Beginn und Ende – auch rückwirkend.",
                 example: "Läuft · Klarer Kopf · 120 von 320 Seiten · 38 %")
            Step(number: 2, title: "Lesen eintragen",
                 text: "„Bis Seite“ (der Stand) oder „+ Seiten“ (dazu), für jeden Tag – auch einen früheren. Gelesen ist, was über den bisher höchsten Stand hinausgeht; ein Stand, der rückwirkend dazwischen kommt, rechnet richtig, nie negativ. Ist die letzte Seite erreicht, schlägt Thalia „fertig“ vor.",
                 example: "bis Seite 140 · Mi, 18. Nov. → 20 Seiten")
            Step(number: 3, title: "Messwerte und Ergebnisse",
                 text: "Ein Messwert mit der Quelle „Leseliste“ zählt die gelesenen Seiten von selbst – ein Punkt „20 Seiten lesen“ bekommt Vorschlag und Fortschritt wie immer. Sein + in Heute öffnet „Lesen“, so wird jede Seite nur einmal eingetragen. Ein Ergebnis „Bücher“ zählt die fertigen Bücher.",
                 example: "Lesen · 20 Seiten · zählt für Ziel 5 · Bücher 3/10")
        }
    }

    // MARK: v10 – Abschnitte

    private var segments: some View {
        Group {
            Step(number: 1, title: "Jahresziele neu festlegen",
                 text: "Ziele → Jahreskarte → ••• → „Neuen Abschnitt beginnen…“, auch unter Einstellungen → Jahresziele und am Ende der Zielüberprüfung. Startwoche (Standard nächste Woche, auch rückwirkend), Titel und Grund – danach Ziele umbenennen, neue anlegen und Ergebnisse für den neuen Abschnitt setzen.",
                 example: "Abschnitt 2 · seit KW50 · Woche 3")
            Step(number: 2, title: "Fokus auf dem aktuellen Abschnitt",
                 text: "Die Karten zählen im aktuellen Abschnitt; ältere Werte sind grau, nicht versteckt. Darunter stehen „Frühere Abschnitte“ mit ihren Wochen, Ø Wertung, Kategorie-Wochen über 8 und erreichten Ergebnissen – mit den Zielen, wie sie damals hießen.",
                 example: "Abschnitt 1 · KW23–KW49 · Ø 7,4")
            Step(number: 3, title: "Vergangenes bleibt, wie es war",
                 text: frozenText,
                 example: "Vor Abschnitt 2: KW44 wird nicht mehr von selbst neu gewertet")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Der Assistent hängt keine Kategorien um und löscht keine – Kategorien kommen weiter über den Wochenplan.")
                Text("• Widerrufen gleich danach nimmt den ganzen Schritt zurück.")
                Text("• Rückblick, Zielüberprüfung und PDF-Bericht bieten den Zeitraum „Abschnitt“ bzw. „Aktueller Abschnitt“.")
            }
            .font(.subheadline)
            .card()
        }
    }

    private var frozenText: String {
        "Eine abgeschlossene Woche vor dem aktuellen Abschnitt wird nie von selbst neu gewertet – auch nicht durch einen späten Eintrag oder eine Meldung aus einer anderen App. Nur die Woche direkt davor wird in der ersten Woche des Abschnitts noch nachgewertet. „Neu berechnen“ in der Woche rechnet sie auf Wunsch nach heutigen Regeln."
    }

    // MARK: v10 – Verbundene Apps

    private var connectedApps: some View {
        Group {
            Step(number: 1, title: "Was andere Apps liefern",
                 text: "Theo (erledigte Aufgaben, Power-Hours), George (Workouts), Nina (Kalorien, Makros, Wasser) und Finn (Ausgaben, Vermögen) legen auf demselben Gerät kleine Tagesdateien ab. Thalia liest sie, sobald sie dort geöffnet ist, und gleicht sie über iCloud mit den anderen Geräten ab.",
                 example: "Einstellungen → Verbundene Apps · Theo · zuletzt gesehen")
            Step(number: 2, title: "Gerechnet, nie geschrieben",
                 text: "Thalia legt für Werte aus anderen Apps keine eigenen Einträge an. Ein verknüpfter Punkt bekommt den Haken von selbst, solange es keine eigene Markierung gibt – auch eine geleerte eigene Markierung geht vor. Ein eigener Eintrag für den Tag ersetzt den Wert aus der App.",
                 example: "✓ ⇄ George · Push")
            Step(number: 3, title: "Power-Hours aus Theo",
                 text: "Sie stehen in Heute „aus Theo“ und zählen für das Wochenziel. „Übernehmen“ macht einen eigenen Eintrag daraus, der den aus Theo ersetzt. Gruppen ohne Kategorie stehen unter „Ohne Zuordnung“ – in Theo oder unter Einstellungen → Verbundene Apps eine Kategorie wählen.",
                 example: "1,5 PH · Arbeit/Kunden · aus Theo · Übernehmen")
            Step(number: 4, title: "Messwerte verbinden",
                 text: "Messwert bearbeiten → „Quelle“ → „Verbundene App“ → App → Art → Eintrag. Ausgaben aus Finn erscheinen in der Ausgabenliste „aus Finn – in Finn ändern“; eigene Ausgaben kommen dazu. Vermögen, Sparquote und Kontostände zählen für ein Ergebnis (Art „Zielwert“), nicht als Messwert – ein Kontostand immer für ein bestimmtes Konto.",
                 example: "George · Workouts · Push → Krafttraining ✓")
            VStack(alignment: .leading, spacing: 8) {
                Label("Wichtig", systemImage: "exclamationmark.circle")
                    .font(.headline)
                Text("• Werte aus Apple Health gehen nie in den Austausch – Thalia liest Health selbst auf dem iPhone.")
                Text("• Nur auf iPhone, iPad und Mac, auf demselben Gerät wie die andere App; die Watch zeigt die Werte nach dem Abgleich.")
                Text("• Eine abgeschlossene Woche vor dem aktuellen Abschnitt ändert sich durch späte Meldungen nicht.")
                Text("• „Thalia-Katalog bereitstellen“ zeigt anderen Apps nur Namen von Zielen, Kategorien, Messwerten und Ergebnissen – keine Werte.")
            }
            .font(.subheadline)
            .card()
        }
    }
}
