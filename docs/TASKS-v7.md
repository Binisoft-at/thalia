# Thalia – v7: App-Durchsicht umsetzen (1.6.0)

**Stand 2026-11-16:** R1–R97 und H1 umgesetzt, alle Paketzeilen abgehakt (inkl. der Nachbesserungen aus der Prüfung: Morgentext in den Einstellungen, `accentFill` hinter weißer Schrift, Toasts im Mac-Einstellungsfenster, `unsavedInput` im Punkt-Fenster, „HEUTE“ blendet ein und aus, „Vorheriger Tag“, kompakte HeroCard, Wochen-Leiste mit Text, Kürzel-Fußnote, € im großen Widget, Siri fragt nach der Menge). Lokal grün: Core-Tests (91) und `swiftc -parse` für App, Shared, Watch, Widgets, WatchWidgets. Offen: Typprüfung in CI am Mac, `[screenshots]`, Gerätetest (TESTING v7), `[testflight]`.

Quelle: [REVIEW-v7.md](REVIEW-v7.md) (97 geprüfte Punkte R1–R97) und die offene Health-Frage (hier **H1**).
Status: [ ] offen · [~] in Arbeit · [x] erledigt.

**Ziel:** Tage, Zahlen und Rückgängig stimmen überall; die tägliche Eingabe wird schneller; Mac, Watch,
Widgets und Kurzbefehle bekommen, was in der Durchsicht fehlte. Version **1.6.0**, Tour-Version **7**.

**Owner-Entscheidungen**
- **Alles umsetzen:** R1–R97 vollständig. Nichts wird still gestrichen. Wo ein Punkt nicht wörtlich geht, steht unten die Alternative, die dasselbe Problem löst.
- **H1 = A:** Messwerte, deren Wert aus Apple Health kommt, zählen auf Geräten ohne Health (Mac, Watch) **nicht als fehlend**; dort steht „Wert aus Health auf dem iPhone“.
- Weiter gültig: **U4** (Tageswertung erst nach dem Abschluss), **K1** (Power-Hours nur mit Bereich **und** Beschreibung), **K2** (jede Ausgabe mit „Wofür“), Wörter auf Knöpfen statt nur Symbole.

**Regeln für alle Pakete**
- Nie `Vendor/BinisoftKit` oder `scripts/ci` ändern (Handbuch). Was dort fehlt, wird in `App/` gelöst und in `docs/HANDBOOK_PROPOSALS.md` vorgeschlagen.
- Keine CloudKit-Schemaänderung (siehe „Schema“).
- Öffentliches Repo: keine echten Namen, Gewichte, privaten Ziele in Code, Tests, Doku. Beispiele neutral („Thema A“, „Mittagessen“, „4,50 €“).
- Keine KI-Modellnamen in Code, Kommentaren, Doku.
- Deutsche Texte in der App genau wie unten angegeben; Bezeichner englisch.
- Lokal prüfbar ist nur Syntax (`swiftc -parse`); Typprüfung läuft erst in CI am Mac. Deshalb exakt die Namen aus dem **API-Vertrag** verwenden.

---

## 1. Entscheidungen

Wo die Durchsicht Optionen offen ließ (je eine Zeile mit Grund):

1. **Ein Tageskonzept (R1, R4, R7, R18, R22, R41):** `AppModel.today` folgt dem Systemtag (`.NSCalendarDayChanged`, Rückkehr in die App, Mac: App wird aktiv); `selectedDay` wandert nur mit, wenn er „heute“ war; jedes Erfassen-Fenster startet mit `AppModel.captureDay` (= `selectedDay`) und zeigt die Zeile „Tag:“; die 4-Uhr-Regel gilt nur für „Tag abschließen“. – Ein Konzept statt sechs widersprüchlicher Einzel-Fixes.
2. **R13 Hinweise im obersten Fenster:** eigener Toast-Host in der App (`toastHost(_:)`, Ebenenzähler im `AppModel`), deutscher Knopf „Widerrufen“; das Kit-Overlay `.toasts()` entfällt. – Das Kit darf nicht geändert werden; Vorschlag ans Handbuch.
3. **R15 Fensterhöhen am Mac:** eigener Modifier `thaliaSheetFrame(width:height:)`, der die Höhe auf die Hauptfensterhöhe begrenzt; Hauptfenster mindestens 900 × 620. – `sheetFrame` aus dem Kit erzwingt zu große Mindesthöhen.
4. **R16 + R50** werden zusammen in P4 gebaut; die Liste „Wochenziele“ ist **eine** Komponente aus P5 (`WeeklyTargetsList`), die Woche, iPad/Mac-Panel und „Heute im Blick“ teilen.
5. **R38** Titelzeile über `ToolbarItem(placement: .principal)` mit eigenem Menü (nicht `navigationSubtitle`) – sicher verfügbare API.
6. **R30:** Mac `Window("Thalia", id: "main")` (genau ein Fenster), iPad `UIApplicationSupportsMultipleScenes = false`. – Einfachste sichere Lösung laut Kritiker.
7. **R84 Indizes: ja.** `#Index` auf den Schlüsselfeldern (`weekKey`, `dayKey`, `code`, `scope`). Grund: rein lokale SQLite-Indizes, kein CloudKit-Feld, automatische leichte Migration, verhindert Verlangsamung über Jahre; Risiko gering, Prüfung in TESTING v7 (nach Update alle Einträge da, Sync läuft). Widget-Stand: nur iPhone (und Watch für ihre Komplikation), gebündelt 1,5 s nach dem Speichern, beim Verlassen der App, nach dem Abgleich und beim Tageswechsel; der Mac schreibt nie.
8. **R87 im Widget abhaken (Aufwand L):** `LiveActivityIntent`, damit `perform()` im App-Prozess läuft; ist die App-Seite nicht erreichbar (Intent läuft doch in der Erweiterung), landet die Aktion in einer Warteschlange-Datei in der App Group und wird beim nächsten App-Start angewendet. Das Widget zeigt sofort optimistisch ✓. Mac/Watch sehen das ✓ nach dem iCloud-Abgleich der App.
9. **R86 Komplikation:** neues watchOS-Widget-Target `ThaliaWatchWidgets` (Bundle-ID `$(WATCH_BUNDLE_ID).widgets`); die Watch-App schreibt ihren eigenen Stand in die App Group der Uhr.
10. **R27 Sicherung:** CSV-Erweiterung, abwärtskompatibel: Flag `abgeschlossen` auf `day`- und `week`-Zeilen; mehrere `entry`-Zeilen je Messwert und Tag mit Flag `einzeln` und der Uhrzeit in `title` („12:30“). Ältere App-Versionen lesen davon nur die letzte Zeile (in IMPORT.md vermerkt).
11. **R28 Duplikate:** „abgeschlossen“ gewinnt (spätestes `closedAt`), Tagestyp/Notiz/Titel aus der neuesten **ausgefüllten** Fassung, Wochenwertung aus der neuesten abgeschlossenen Fassung; zusammengeführt beim Start und nach jedem Abgleich.
12. **R32 Vorschläge:** letzte 90 Tage, nach Häufigkeit, dann Aktualität; einmal laden, beim Tippen nur filtern. Ausgaben: Ist der Betrag gültig, sichert ein Tipp auf einen Vorschlag sofort.
13. **R33 „Zuletzt“:** die letzten drei verschiedenen Kombinationen (Bereich · Wofür · Menge) der letzten 60 Tage; ein Tipp **füllt** das Fenster, „Sichern“/Return sichert (Bereich bleibt bewusst gewählt, K1).
14. **R35** Tastenkürzel am Mac und am iPad mit Tastatur (`onKeyPress`); ⌥⌘↓/↑ als Menübefehle „Nächste/Vorige Kategorie“.
15. **R43 Wortschatz:** Erledigt · Teilweise · Nicht erledigt · Entfällt; Fortschritt: Gearbeitet · Nicht heute; leer = „nicht erfasst“. Überall (Knöpfe, Menüs, Watch, PDF, Hilfe, VoiceOver).
16. **R60** ziehbare Spalte nur am Mac (`HSplitView`, 220–400 pt); iPad bleibt 270 pt.
17. **R62 optional „anpassbare Leiste“: ja**, am Mac auf „Heute“ (`toolbar(id:)`).
18. **R71** Drucken über PDFKit-Druckvorgang, Sichern über `fileExporter`; zusätzlich „Bild sichern…“ im Teilen-Fenster am Mac (die Option aus R71).
19. **R73** Schließen-Knopf als eigenes `SheetCloseButton` (Symbol `xmark`, VoiceOver „Schließen“) – keine neue Button-Rolle, sichere API.
20. **R75 Namen:** „erfassen“ = Power-Hours, Ausgabe, Notiz und das „+“-Fenster („Erfassen“, Menü „Erfassen…“); „eintragen“ = Wert eines Messwerts; „anlegen“ = neuer Messwert oder neuer Punkt; letzte Heute-Seite „Abschluss & Notizen“; Kürzel-Hinweise nur am Mac/iPad, vollständig.
21. **R76 Tour:** 13 Karten (Willkommen + 11 Schritte + Fertig); 8 Schritte mit `since: 7` bilden „Neu in Thalia“. Texte unten im Vertrag.
22. **R77** „PH“ fällt aus der Einheitenliste; übergibt jemand trotzdem „PH“ an `addMeasure`, wird daraus ein Arbeits-Messwert (`arbeit:<Kategorie>`), nie ein nackter PH-Wert.
23. **R80 Erinnerungen:** Abend-Erinnerung je Tag als einzelne Mitteilung für die nächsten 7 Tage (abgeschlossene Tage ausgelassen), beim Abschließen entfernt; Aktion „In 30 Min.“; Erlaubnis erst nach der Tour oder beim Einschalten in den Einstellungen; am Mac beim ersten Start alle Erinnerungen aus; neuer Morgentext. Neu geplant wird bei jedem Aktivwerden – wer Thalia 7 Tage gar nicht öffnet, bekommt danach keine Abend-Erinnerung mehr (iOS erlaubt nur 64 ausstehende Mitteilungen; 5 + 1 + 7 bleiben weit darunter).
24. **R81** Krone-Schritte: kg 0,1 · l 0,25 · € 0,5 · Uhrzeit 5 min · h 0,25 · sonst 1; Start beim heutigen Wert, sonst beim letzten Wert der letzten 60 Tage.
25. **R89** Bereich als `AppEntity` (Siri fragt nach); der doppelte Kurzbefehl „PH mit Beschreibung“ fällt aus der Kurzbefehl-Liste (der Intent bleibt fürs Kontrollzentrum); „Ausgabe in Thalia“ = `AddExpenseIntent` (auch R97).
26. **R92** „Wie KW46 wiederholen“ läuft als normaler Import mit Vorschau (und damit Archiv/Rückgängig).
27. **R93** Zeiträume „12 Wochen“, „Halbjahr“ (26 Wochen), „Zieljahr“; „Ø 4 Wo.“ = Mittel der letzten vier abgeschlossenen Wochenwertungen des Ziels.
28. **R94** Banner, wenn gestern einen Plan hat und nicht abgeschlossen ist; ausblendbar je Tag (UserDefaults `yesterday.dismissed` = ISO-Datum); verschwindet nach dem Abschluss.
29. **R95** „Zielüberprüfung vorbereiten“ ab 3 Wochen vor der Prüfungswoche bis zu ihrem Ende; der Bericht ist Markdown zum Kopieren.
30. **R96** Menüleiste als `MenuBarExtra` mit `.window`-Stil, standardmäßig an, Schalter in den Einstellungen.
31. **R97** Fehlt der Ausgaben-Messwert der Woche, legt der Kurzbefehl „Ausgaben“ (€, Kategorie von Ziel 8) an – wie der Knopf im Ausgaben-Fenster; „Wofür“ ist Pflicht (K2).
32. **H1** „Gerät liest Health“ = iPhone/iPad (`HealthDevice.readsHealth`); Mac und Watch nicht.
33. **R2** Werte werden im bestehenden Eintrag geändert; was dabei verschwindet, geht in den Papierkorb; „Widerrufen“ stellt Wert, Notiz, Schätzung und Uhrzeit exakt wieder her. Ausgaben lehnt `setDayValue` ab.
34. **R5** „offen“ = leere Pflichtpunkte (fix und Fortschritt, keine Nebensache) – genau die Zahl, die der Ring zählt.
35. **R6** Startseite einmal pro Tag gewählt (erste Kategorie mit Offenem, sonst „Abschluss & Notizen“), danach nur noch durch Wischen, Chip oder „Weiter“.
36. **R11** Neu berechnet werden nur abgeschlossene Wochen, die ein Speichern berührt hat.
37. **R12** „Vorschläge übernehmen“ füllt nur leere Punkte; Abweichungen eingeklappt unter „Messwert weicht ab“.
38. **R18** Grenze 4:00 Uhr Ortszeit.
39. **R20** Vorschau 0,6 s nach dem letzten Tastendruck; Knopf „ChatGPT öffnen“: ja.
40. **R40** „Sonntag“ = Wochentag Sonntag des abgeschlossenen Tags und Woche noch offen.
41. **R45** Ziel-Etikett „Tagesziel …“ bei Tageszielen, „Wochenziel …“ bei Wochenzielen.
42. **R47** Soll zählt die Tage des Messwerts ohne arbeitsfreie Tage, wenn der Messwert Arbeit ist (Quelle `arbeit:`, Tageregel „nur Arbeitstage“ oder Arbeits-Kategorie).
43. **R53** im Bereich die drei größten Themen.
44. **R54** „Nach Zweck“ zeigt die fünf größten Posten.
45. **R58** Journal-Punkt = Plan-Punkt, dessen Titel „journal“ enthält (Groß/klein egal).
46. **R59** Am Mac blenden ⌘0, Ring und „HEUTE“ die rechte Spalte ein; iPhone/iPad behalten das Fenster.
47. **R61** Knöpfe rechts, sobald die Zeile mindestens 640 pt breit ist (`ViewThatFits`).
48. **R65** Punkt in der Zelle = Notiz an dieser Markierung (`ItemMark.note`).
49. **R70** „nicht abgeschlossen“ = Woche vor der laufenden mit Plan, nicht abgeschlossen und ohne Papier-Wertung.
50. **R83** `GoalPalette` zieht nach `Shared/GoalPalette.swift` und wird auch ins Widget kompiliert.
51. **R85** Wertezeilen für Tages-Messwerte mit Zahl oder Uhrzeit (keine Texte), eingeklappt unter jeder Kategorie.
52. **R88** 8 Wochen; Ziel je Woche = Summe der PH-Wochenziele dieser Woche.
53. **R91** Prompt hängt den Plan der Quellwoche als CSV an (`week`, `day`, `measure`, `item`) plus 4 Zeilen Tendenz (Wertung, PH gegen Ziel).
54. **R79** Deutsch auch auf der Kit-Seite „Where your data lives“: Thalia ersetzt `SyncStatusSection` **und** `DataLocationView` durch eigene Ansichten mit `SyncGerman` (Kit bleibt unverändert, Vorschlag ans Handbuch Nr. 24). `SyncGerman.error` erkennt den englischen Kit-Satz, weil `SyncState.lastError` schon übersetzt gespeichert ist.
55. **R86** Die Komplikation zeigt den Stand, den die Watch-App zuletzt geschrieben hat (eigene Änderungen, iCloud-Import, Öffnen der App) und um Mitternacht „Neuer Tag“. Ein Push vom iPhone (WatchConnectivity) wäre aktueller, braucht aber einen zweiten Datenweg – bewusst nicht in v7; TESTING v7 prüft, ob der Stand im Alltag reicht.
56. **R12** Vorschläge laufen als `MarkSuggestion` (Struct) durch alle Pakete – keine benannten Tupel über Paketgrenzen.
57. **R27** Alte Sicherungen und ChatGPT-CSVs ohne Einzel-Zeilen vergleichen nur die Tagessumme – ein Import fasst nie Einzel-Ausgaben zusammen.

## 2. Schema und Owner-Schritte

**CloudKit: keine Änderung.** Keine neuen `@Model`-Typen, keine neuen gespeicherten Eigenschaften, `cloudkit/schema.ckdb` bleibt, kein Schema-Deploy nötig.
- `#Index` (R84) erzeugt nur lokale SQLite-Indizes; `tools/schema-from-models.py Shared/Models.swift HealthValue` muss danach **dieselbe** Ausgabe liefern wie vorher (P1 prüft).
- Abschlüsse und Einzel-Ausgaben in der Sicherung (R27): nur im CSV-Format.
- Alles Neue liegt in bestehenden Feldern: Notiz an einer Markierung (R65) = `ItemMark.note`, Besonderheit (R90) = `PlanDay.note`, geparkte Ideen (R95) = `DayNote` mit Art `idee`, Papierkorb (R2, R19) = `deletedAt`, Wochenwertung (R11, R28) = `WeekPlan.final*`.
- Widget-Warteschlange (R87): Datei in der App Group. Banner-Ausblenden (R94), Menüleiste (R96), Erinnerungen (R80), rechte Spalte (R59): `UserDefaults`.

**Owner-Schritte (vor `[testflight]`, nicht vor dem ersten CI-Lauf):**
- **Neue App-ID** für die Watch-Komplikation (R86): `at.binisoft.thalia.watchkitapp.widgets` mit Capability **App Groups** und der Gruppe `group.at.binisoft.shared` zugewiesen („Configure“ ist ein eigener Klick, siehe HANDBOOK_PROPOSALS Nr. 16 – ohne zugewiesene Gruppe scheitert das Archiv). Die automatische Signierung legt die App-ID oft selbst an, die Gruppen-Zuweisung aber nicht verlässlich. P8 trägt die ID in `docs/SETUP.md` ein.
- Sonst nichts: keine neuen Berechtigungen im App-Store-Connect-Eintrag, kein CloudKit-Deploy.

## 3. API-Vertrag

Jede Signatur hier ist verbindlich. „Paket“ = wer sie baut; alle anderen schreiben dagegen, ohne kompilieren zu können.
Bestehende Namen, die andere Pakete benutzen, **nicht umbenennen**: `percent(_:)`, `FillRing`, `MarkBar`, `MeasureInput`, `NoPlanView`, `StepButton`, `GoalBar`, `WeeklyGoalRow` (TodayView, P3) · `ChipButton`, `WorkEditor(draft:)`, `ItemEditor(week:item:presetCategory:)`, `ItemDetailView(item:day:)`, `MeasureSheet(code:day:)`, `NoteEditor(note:day:)` (Editors, P6) · `HeroCard`, `ShareSheet`, `ShareRequest`, `PDFButton`, `PDFShareButton`, `PDFPreviewSheet(kind:context:)`, `ReportView(week:)` (P7) · `KeyBadge`, `DayTypeChip`, `MarkMenu`, `SectionHeading`, `ScoreRing`, `GoalBars` (Components, P5) · `SummaryTile`, `GlanceText` (insbesondere `GlanceText.dayLine(_:closed:open:)`, die Menüleiste R96 nutzt sie), `SidebarGlance`, `FocusContent.areaColor(_:among:)` (Glance, P4) · `GoalPalette` (zieht um, API gleich) · AppModel (P2): `setMark(_:item:day:)`, `trash(_:)`-Varianten, `setAll(_:items:day:scope:)`, `addExpense(_:what:measure:day:)`, `add(_:to:day:)`, `setValue(_:for:day:toast:)`, `categoryTitle(_:)`, `startTour()`, `finishTour()`, `route(_:)`, `open(_:)`, `WorkDraft(block:day:categoryKey:powerHours:)`, `TodayPage`, `AppTab`.

### 3.1 ThaliaCore (alles P1)

```swift
// Calendar.swift
extension Weekday {
    /// "M","D","M","D","F","S","S" (R69)
    public var letter: String { get }
}
extension DayKey {
    /// Zeitpunkt `minutes` nach Mitternacht dieses Tages, aus Kalender-Komponenten gebaut (richtig an
    /// Tagen der Zeitumstellung). `minutes` wird in 0..<1440 gefaltet. (R29)
    public func date(minutes: Double, timeZone: TimeZone = .current) -> Date
    /// Minuten seit Mitternacht von `date` in `timeZone`, 0..<1440. (R29)
    public static func minutes(of date: Date, timeZone: TimeZone = .current) -> Double
    /// "Tag abschließen": vor `cutoffHour` Uhr der Vortag, sofern er nicht abgeschlossen ist, sonst der
    /// Kalendertag von `now`. (R18)
    public static func closingDay(now: Date = Date(), timeZone: TimeZone = .current, cutoffHour: Int = 4,
                                  isClosed: (DayKey) -> Bool) -> DayKey
    /// "Heute", "Gestern", "Morgen", sonst `shortLabel`. (R41)
    public func relativeLabel(today: DayKey) -> String
}

// Format.swift
extension Format {
    /// Cent-genau: 12.99 → "12,99 €", 2.5 → "2,50 €", 13 → "13 €", 1234.5 → "1.234,50 €", -3.5 → "-3,50 €". (R17)
    public static func euro(_ value: Double) -> String
}
// Format.measure(_:unit:) gibt für Units.normalized(unit) == "€" jetzt euro(value) zurück.

// Measures.swift
extension WorkTotals {
    /// "3 h 20 min" (Format.duration der Nettominuten). (R52)
    public var netText: String { get }
}
// WorkTotals.explanation lautet jetzt "28 PH × 50 min = 23 h 20 min netto".

// Records.swift
extension MeasureRecord {
    public var isExpense: Bool { get }          // Units.normalized(unit) == "€" || code enthält "ausgabe" (R2, R3, R27)
    public var isHealth: Bool { get }           // source ist .health (R81, H1)
    public var defaultClockMinutes: Double { get } // Uhrzeit-Ziel, sonst 1380 (23:00) (R3)
}
public struct EntryPart: Equatable, Sendable {  // eine einzelne Eintragung eines Tages (R27)
    public var value: Double?
    public var note: String
    public var minutes: Int                      // Uhrzeit, Minuten seit Mitternacht
    public var estimate: Bool
    public init(value: Double?, note: String = "", minutes: Int, estimate: Bool = false)
}
// EntryRecord: neues Feld `public var parts: [EntryPart]` (leer = aggregierter Wert wie bisher);
// init bekommt den letzten Parameter `parts: [EntryPart] = []`. Gleichheit vergleicht parts mit.
// EntryPart.minutes entsteht aus `Int(DayKey.minutes(of: recordedAt))` (abgerundet), geschrieben wird
// `Format.clock(Double(part.minutes))` – so bleibt der Rundlauf exakt.

// Scoring.swift
extension WeekData {
    /// R5: leerer Pflichtpunkt an `day` – genau das, was CategoryDay.blank zählt (fix oder Fortschritt,
    /// fällig, keine Nebensache, keine Markierung). Scorer.categoryDay nutzt dieselbe Regel.
    public func isOpenRequired(_ item: ItemRecord, on day: DayKey) -> Bool
}
// Pace.init(done:target:days:week:today:excluding:) – neuer letzter Parameter
// `excluding: Set<DayKey> = []`: diese Tage zählen nicht als geplant (R47).

// Vocabulary.swift
// Mark.label: .done "Erledigt", .partial "Teilweise", .missed "Nicht erledigt", .notApplicable "Entfällt" (R43)
extension Mark {
    /// Fortschrittspunkte: .done "Gearbeitet", .notApplicable "Nicht heute", sonst label. (R43)
    public func label(progress: Bool) -> String
}
extension Target.Comparison {
    public var choiceLabel: String { get }      // "mindestens","höchstens","unter","über","genau","zwischen" (R77)
    public static let choices: [Target.Comparison] // [.atLeast, .atMost, .below, .above, .equal, .range]
}
extension Target {
    /// "Erfüllt bei ≤ 6 pro Tag", "Erfüllt bei ≤ 23:00 pro Tag", "Erfüllt bei 150–180 g pro Woche" (R77)
    public func sentence(period: TargetPeriod, unit: String = "") -> String
}
extension Units {
    public static let choices: [String]   // ["", "kg", "g", "l", "min", "h", "Uhrzeit", "€", "Stück", "Seiten", "Schritte", "Text"] (R77, ohne PH)
    public static func crownStep(_ unit: String) -> Double   // kg 0.1, l 0.25, € 0.5, uhrzeit 5, h 0.25, sonst 1 (R81)
}
extension DayTypes { public static let workFreeHint: String }   // "Arbeitsfreier Tag: Arbeitspunkte zählen heute nicht" (R78)
extension NoteKind { public static let listText: String }       // "Beobachtung, Auslöser, Erfolg, Kontakt, Idee" (R78)
extension ReflectionQuestion {
    public static let dayNoteField: String                       // "notiz" (R26)
    public static func isJournalTitle(_ title: String) -> Bool   // enthält "journal", Groß/klein egal (R58)
}

// PlanCSV.swift (R27, R91, R92)
// Document: neue Felder `public var closedDays: Set<DayKey> = []`, `public var closedWeeks: Set<WeekKey> = []`.
// Lesen: Flag "abgeschlossen" auf day-/week-Zeilen füllt sie. entry-Zeile mit Flag "einzeln": title = "HH:MM",
// hängt einen EntryPart an den EntryRecord desselben Messwerts/Tags an (value = Summe, note = "; "-verbunden).
// Schreiben: Abschlüsse als Flag (auch Tage ohne Typ/Notiz bekommen dann eine day-Zeile); EntryRecord mit parts
// → eine entry-Zeile je Part mit Flag "einzeln" (plus "schaetzung" falls estimate) und title = Format.clock(minutes).
extension PlanCSV.Document {
    /// Nur Plan einer Woche: week-Zeile, day-Zeilen, measures, items dieser Woche. (R91)
    public func planOnly(week: WeekKey) -> PlanCSV.Document
    /// Plan von `source` als Plan für `target`: week-Zeile mit Titel und Kontext der Quellwoche (week = target),
    /// Tage um volle Wochen verschoben (Typ und Besonderheit bleiben), measures/items mit gleichen codes und
    /// week = target; keine Ergebnisse (marks, entries, work, notes, reviews, scores), keine Abschlüsse,
    /// recordedScore nil. (R92)
    public func repeated(from source: WeekKey, to target: WeekKey) -> PlanCSV.Document
}

// ImportPreview.swift (R27, R49)
// ExistingState: neue Felder `public var closedDays: Set<DayKey> = []`, `public var closedWeeks: Set<WeekKey> = []`.
public struct WeekReplacement: Equatable, Sendable {
    public var week: WeekKey
    public var marks: Int        // gesetzte Markierungen der Woche (mark != nil)
    public var values: Int       // erfasste Werte der Woche (EntryRecords im ExistingState)
    public var text: String      // "KW47 wird ersetzt – 23 Markierungen und 9 Werte gehen ins Archiv."
    public var buttonTitle: String // "KW47 ersetzen"
}
// ImportPreview: neu `public let replacements: [WeekReplacement]` (eine je replacedWeeks),
// `public let newClosedDays: [DayKey]`, `public let newClosedWeeks: [WeekKey]` (Abschlüsse aus der Datei, die
// die App noch nicht hat). `lines` nutzt replacement.text statt des alten Satzes und nennt
// "Abschlüsse: 3 Tage, 1 Woche"; hasChanges zählt neue Abschlüsse mit.
// Einzahl/Mehrzahl über Format.count: "1 Markierung", "1 Wert".
// Vergleich der Einträge (R27, abwärtskompatibel): hat der eingehende EntryRecord KEINE parts (alte Sicherung,
// ChatGPT-CSV), wird er gegen den bestehenden mit geleerten parts verglichen – eine alte Datei mit gleicher
// Summe ist "unchanged" und fasst nie drei einzelne Ausgaben zu einer Zeile zusammen.

// Reports.swift
extension PlanPrompt {
    // Signatur ersetzt die bisherige (neue Parameter mit Standardwerten am Ende):
    public static func text(for week: WeekKey, goals: [GoalRecord], categories: [CategoryRecord], measures: [MeasureRecord],
                            lastWeekReport: String?, changes: [PlanChangeRecord] = [], currentPlan: String? = nil,
                            currentPlanWeek: WeekKey? = nil, trend: [String] = []) -> String
}
// currentPlan != nil → Abschnitt "## Plan von KW46 (Ausgangspunkt)" mit ```csv-Block und dem Satz
// "Übernimm diese Zeilen für KW47 (Datum in die neue Woche verschieben), ändere nur, was ich unten verlange,
//  und nenne jede Änderung unter dem Codeblock." trend → "## Tendenz der letzten 4 Wochen" + je eine Zeile. (R91)
// WeekReport.markdown: Spalte Journal nutzt den Journal-Punkt des Plans, wenn es einen gibt (R58).
public struct PeriodReport: Sendable {   // R95
    public struct GoalLine: Equatable, Sendable { public var key: String; public var title: String; public var average: Double?; public var firstFour: Double?; public var lastFour: Double? }
    public struct MissedItem: Equatable, Sendable { public var title: String; public var categoryKey: String; public var count: Int }
    public struct WorkLine: Equatable, Sendable { public var categoryKey: String; public var title: String; public var powerHours: Double }
    public struct MeasureChange: Equatable, Sendable { public var code: String; public var title: String; public var unit: String; public var first: Double?; public var last: Double? }
    public var start: WeekKey
    public var end: WeekKey
    public var goals: [GoalLine]          // Ø seit Start + Trend (erste vs. letzte 4 Wochen)
    public var missed: [MissedItem]       // 10 häufigste ✗, nach Titel zusammengefasst
    public var work: [WorkLine]           // PH je Bereich, absteigend
    public var measures: [MeasureChange]  // erster und letzter Wochenwert je Messwert-code
    public var ideas: [NoteRecord]        // alle geparkten Ideen, neueste zuerst
    public init(weeks: [WeekReportInput], goalScores: [WeekKey: [String: Double]], ideas: [NoteRecord])
    public func markdown(period: GoalPeriod) -> String  // "# Zielüberprüfung KW49 …" für ChatGPT
}

// Merge.swift (neu, R28)
public struct DayVersion: Equatable, Sendable {
    public var dayType: String; public var note: String; public var closedAt: Date?; public var modifiedAt: Date
    public init(dayType: String, note: String, closedAt: Date?, modifiedAt: Date)
}
public struct WeekVersion: Equatable, Sendable {
    public var title: String; public var details: String; public var recordedScore: Double?; public var scoringModel: String
    public var closedAt: Date?; public var importedAt: Date?; public var finalScore: Double?; public var finalGoalScores: String
    public var finalGoalsScored: Int; public var modifiedAt: Date
    public init(title: String, details: String, recordedScore: Double?, scoringModel: String, closedAt: Date?, importedAt: Date?,
                finalScore: Double?, finalGoalScores: String, finalGoalsScored: Int, modifiedAt: Date)
}
public enum DuplicateMerge {
    /// Leer → nil. closedAt: spätestes nicht-nil; dayType/note: aus der neuesten Fassung, in der sie nicht leer sind.
    public static func day(_ versions: [DayVersion]) -> DayVersion?
    /// closedAt wie oben; final*: aus der neuesten Fassung mit closedAt; title/details/recordedScore/importedAt:
    /// neueste nicht-leere; scoringModel: neueste Fassung; modifiedAt: Maximum.
    public static func week(_ versions: [WeekVersion]) -> WeekVersion?
}

// SyncGerman.swift (neu, R79)
public enum SyncGerman {
    public static func storage(_ mode: StorageMode) -> String   // "Auf diesem Gerät + iCloud" · "Nur auf diesem Gerät" · "Vorübergehend (nicht gesichert)" · "Beispieldaten (nicht gesichert)"
    public static func account(_ account: ICloudAccount) -> String // "Wird geprüft …" · "Angemeldet" · "Nicht angemeldet" · "Eingeschränkt" · "Vorübergehend nicht verfügbar" · "Unbekannt"
    /// "An · zuletzt vor 5 Minuten" · "An" · "Synchronisiert …" · "Synchronisiert gerade nicht" · "Aus – in iCloud anmelden" ·
    /// "Aus – iCloud ist eingeschränkt" · "Aus – nur dieses Gerät" · "Aus – Beispieldaten" · "Aus – Daten können nicht gesichert werden"
    public static func summary(_ state: SyncState, relative: (Date) -> String) -> String
    /// Deutsche Fassung der Fälle aus SyncErrorText (Schema, Speicher voll, nicht angemeldet, kein Netz, Zone);
    /// Unbekanntes: "iCloud meldet: <raw>".
    /// Eingabe ist `SyncState.lastError` – das ist schon der ENGLISCHE Satz des Kits ODER der kurze Rohfehler.
    /// Erkannt werden deshalb beide Formen (klein geschrieben): "schema" / "cannot create or modify field" /
    /// "did not find record type" / "unknown item"; "quota" / "storage is full"; "not authenticated" /
    /// "no account" / "sign in to icloud"; "network" / "offline" / "internet"; "zone" + "not found" /
    /// "setting up". Test je Fall mit beiden Eingaben.
    public static func error(_ raw: String, appName: String) -> String
    /// Grund für .local/.memory auf Deutsch (der Kit-Grund ist englisch): "iCloud-Speicher ließ sich nicht öffnen –
    /// deine Daten bleiben auf diesem Gerät." · "Kein iCloud-Container eingerichtet – deine Daten bleiben auf diesem
    /// Gerät." · nil bei .iCloud/.demo.
    public static func reason(_ mode: StorageMode) -> String?
}

// ThaliaTour.swift – TodaySummary (R4, R5, R87, R90). Alle neuen Felder optional (alte Datei bleibt lesbar),
// fileName bleibt "today-v3.json".
extension TodaySummary {
    // neue gespeicherte Eigenschaften (in der Struct-Definition, alle `var … : T? = nil`):
    //   dayKey: String?           – ISO-Tag, für den der Stand gilt
    //   nextDay: [TodaySummary]?  – 0…1 Element: der vorgeschriebene Stand für morgen
    //   isNewDay: Bool?           – neutraler Zustand „Neuer Tag“
    //   openKeys: [String]?       – "2026-W47|1.1-03", parallel zu `open`
    //   dueCount: Int?            – fällige Pflichtpunkte heute (für die optimistische Füllung)
    //   dayType: String?, dayNote: String?   – Tagestyp und Besonderheit
    //   hasPlan: Bool?            – false: „Kein Plan“
    //   weeklyOpenCount: Int?     – n×/Woche-Punkte, die diese Woche noch fehlen
    /// dayKey == today → self; nextDay?.first mit dayKey == today → dieses; dayKey == nil (Stand einer älteren
    /// App-Version) → self, wenn `updatedAt` am Kalendertag `today` liegt; sonst newDay(today).
    public func resolved(for today: DayKey) -> TodaySummary
    /// Neutral: day = today.shortLabel, dayKey, fill 0, dayScore nil, isClosed false, open [], openCount 0,
    /// powerHours 0, expensesToday nil, isNewDay true; Wochenfelder bleiben, wenn today in derselben Woche liegt.
    public func newDay(_ today: DayKey) -> TodaySummary
    /// Optimistisch nach ✓ im Widget: Zeile aus open/openKeys entfernt, openCount − 1, fill um 1/dueCount höher.
    public func markingDone(itemKey: String) -> TodaySummary
}
public struct WidgetMarkAction: Codable, Equatable, Sendable {   // R87
    public var itemKey: String     // "2026-W47|1.1-03"
    public var dayKey: String      // "2026-11-16"
    public var createdAt: Date
    public init(itemKey: String, dayKey: String, createdAt: Date = Date())
    public var weekKey: String { get }   // vor "|"
    public var itemCode: String { get }  // nach "|"
}

// ThaliaTour.swift – ReminderSettings (R18, R40, R80)
// Codable mit eigenem init(from:) und decodeIfPresent je Feld (alte gespeicherte Einstellungen bleiben lesbar).
extension ReminderSettings {
    public static let macDefault: ReminderSettings          // alles aus
    public static let snoozeActionID: String                // "thalia.snooze"
    public static let eveningCategoryID: String             // "thalia.evening"
    public static let snoozeMinutes: Int                    // 30
    public static func eveningID(_ day: DayKey) -> String   // "thalia.evening.2026-11-16"
    public struct DatedRequest: Equatable, Sendable {
        public let id: String; public let day: DayKey; public let hour: Int; public let minute: Int
        public let title: String; public let body: String; public let destination: String   // "close-day:2026-11-16"
    }
    /// Abend je Tag ab `start` für `count` Tage, abgeschlossene Tage ausgelassen; leer, wenn evening == false.
    public func eveningRequests(from start: DayKey, count: Int = 7, isClosed: (DayKey) -> Bool) -> [DatedRequest]
}
// requests() liefert nur noch Morgen + Woche. Morgen-Text: title "Guten Morgen",
// body "Kurz in Thalia schauen: was heute ansteht – und ob gestern noch offen ist." Woche: destination "close-week".
```

### 3.2 Shared (P1, außer wo P8 steht)

```swift
// Models.swift (R84): je Modell ein #Index auf die Felder, die in Prädikaten vorkommen, z. B.
//   #Index<WeekPlan>([\.weekKey])  #Index<PlanDay>([\.dayKey])  #Index<PlanItem>([\.weekKey])
//   #Index<MeasureDefinition>([\.weekKey])  #Index<ItemMark>([\.weekKey], [\.dayKey])
//   #Index<MeasureEntry>([\.dayKey], [\.code])  #Index<WorkBlock>([\.dayKey], [\.categoryKey])
//   #Index<DayNote>([\.dayKey])  #Index<ScoreOverride>([\.dayKey])  #Index<Reflection>([\.scope])
//   #Index<AppSetting>([\.key])  #Index<HealthValue>([\.dayKey])
// Keine neuen var-Eigenschaften.

// WeekContext.swift
enum HealthDevice {
    /// Thalia liest Apple Health auf diesem Gerät (iPhone, iPad). Mac und Watch nicht. (H1)
    static var readsHealth: Bool { get }
}
struct WeeklyTarget: Identifiable {      // R16, R47
    let measure: MeasureDefinition
    let item: PlanItem?                  // Fortschrittspunkt, der daran hängt
    let value: Double                    // Wochenwert bisher (0 ohne Einträge)
    let target: Target
    let pace: Pace
    let unit: String                     // "PH" bei Arbeit, sonst Units.display(unit)
    var id: String { measure.code }
    var isMet: Bool { target.isMet(value) }   // Limits: solange darunter; Ziele: erreicht
}
/// R12: ein Vorschlag aus Messwerten. Ein Struct statt eines benannten Tupels: `[(item:, mark:)]` lässt sich
/// nicht implizit in `[(PlanItem, Mark)]` umwandeln, und ForEach braucht eine id.
struct MarkSuggestion: Identifiable {
    let item: PlanItem
    let mark: Mark                       // der Vorschlag
    let current: Mark?                   // was gespeichert ist (nil bei suggestionsToFill)
    var id: String { item.code }
}
struct ExpensePurpose: Identifiable {    // R54
    let purpose: String                  // Notiz, getrimmt; leer → "ohne Angabe"
    let total: Double
    let count: Int
    var id: String { purpose }
}
extension WeekContext {
    static let healthElsewhereHint: String   // "Wert aus Health auf dem iPhone" (H1)
    /// R5 – geändert: genau die leeren Pflichtpunkte (WeekData.isOpenRequired); count == score.days[day]?.blank.
    func openToDo(on day: DayKey) -> [PlanItem]
    /// R5 – neu: n×/Woche-Punkte ohne Nebensache, heute fällig und leer, Quote noch nicht erreicht.
    func openWeeklyToDo(on day: DayKey) -> [PlanItem]
    func openCount(on day: DayKey) -> Int                       // score.days[day]?.blank ?? 0
    /// R8: ohne Plan "–"; Tag nach `today` "–"; abgeschlossen → Wertung ("7,5"); sonst "62 %".
    func dayStatusText(_ day: DayKey) -> String
    /// R8/R66: "Mittwoch, abgeschlossen, Wertung 7,5" · "Mittwoch, 62 Prozent erfasst" · "Mittwoch, kommt noch".
    func dayStatusAccessibility(_ day: DayKey) -> String
    var weeklyTargets: [WeeklyTarget] { get }                   // jede Woche-Messung mit Ziel, Planreihenfolge (R16)
    var weeklyTargetsMet: Int { get }                           // weeklyTargets.filter(\.isMet).count – auch PDF/Bericht (R16)
    func pace(for measure: MeasureDefinition) -> Pace?          // R47, ohne arbeitsfreie Tage bei Arbeits-Messwerten
    /// R64 Kurzlabel: "Nebensache" · "optional" · "bedingt" · "3× pro Woche" · "automatisch" · "Wochenfortschritt" · nil (fix)
    func kindLabel(_ item: PlanItem) -> String?
    func dayNote(_ day: DayKey) -> String                       // Besonderheit (PlanDay.note) (R90)
    func isHealthElsewhere(_ measure: MeasureDefinition) -> Bool // Health-Quelle und !HealthDevice.readsHealth (H1)
    /// H1: gilt an `day`, kein Wert, und nicht isHealthElsewhere.
    func countsAsMissing(_ measure: MeasureDefinition, on day: DayKey) -> Bool
    func suggestionsToFill(on day: DayKey) -> [MarkSuggestion]     // Vorschlag bei leerem Punkt (R12)
    func suggestionsDiffering(on day: DayKey) -> [MarkSuggestion]  // Vorschlag ≠ gesetzter Markierung (R12)
    var journalItem: PlanItem? { get }                          // R58
    func journalDone(on day: DayKey) -> Bool?                   // Punkt (✓/½ → true, ✗ → false) sonst Reflexion "ja"/"nein"
    func expensesByPurpose(_ measure: MeasureDefinition, limit: Int = 5) -> [ExpensePurpose] // Woche (R54)
    func isExpense(_ measure: MeasureDefinition) -> Bool        // unverändert, nutzt MeasureRecord.isExpense
    func todaySummary() -> TodaySummary                         // füllt alle neuen Felder (außer nextDay)
}

// TrackerStore.swift – neue Hilfstypen (oberste Ebene, nicht verschachtelt)
struct EntrySnapshot {                       // R2, R46
    let entry: MeasureEntry
    let value: Double?; let text: String; let note: String; let isEstimate: Bool
    let dayKey: String; let recordedAt: Date; let deletedAt: Date?
}
struct DayValueChange {                      // R2
    var edited: [EntrySnapshot] = []         // vorher-Zustand der geänderten Einträge
    var created: [MeasureEntry] = []
    var trashed: [MeasureEntry] = []
    var isEmpty: Bool { get }
}
struct WorkCombo: Hashable, Identifiable {   // R33
    let categoryKey: String; let task: String; let powerHours: Double
    var id: String { "\(categoryKey)|\(task)|\(powerHours)" }
}
struct SeriesPoint: Identifiable, Equatable { let day: DayKey; let value: Double; var id: String { day.string } }        // R93
struct WeekScorePoint: Identifiable, Equatable { let week: WeekKey; let score: Double; var id: String { week.string } } // R93
struct WeekWorkPoint: Identifiable, Equatable {                                                                       // R88
    let week: WeekKey; let powerHours: Double; let target: Double?
    var id: String { week.string }
    var isReached: Bool { (target ?? 0) > 0 && powerHours >= (target ?? 0) - 1e-9 }
}

extension TrackerStore {
    // R2: Summe: Differenz am neuesten Eintrag (bei Minus von hinten nach vorn abbauen, was auf 0 fällt → Papierkorb);
    // letzter/Schnitt/Max/Min: neuester Eintrag bekommt den Wert, übrige → Papierkorb; nil → alle in den Papierkorb.
    // Ausgaben-Messwerte (MeasureRecord.isExpense) → keine Änderung, leeres DayValueChange.
    @discardableResult func setDayValue(code: String, day: DayKey, value: Double?) -> DayValueChange
    // setDayText(code:day:text:) (bestehend) arbeitet genauso: neuester Text-Eintrag wird geändert, weitere → Papierkorb,
    // leerer Text → alle in den Papierkorb. Kein `context.delete` mehr in setDayValue/setDayText (R2).
    func undo(_ change: DayValueChange)                               // exakt zurück
    func snapshot(_ entry: MeasureEntry) -> EntrySnapshot
    func restore(_ snapshot: EntrySnapshot)                           // Wert, Text, Notiz, Schätzung, Tag, Zeit, Papierkorb-Status
    /// R46: ändert Betrag, Wofür und Tag; Rückgabe = Zustand vorher (für Widerrufen).
    @discardableResult func editExpense(_ entry: MeasureEntry, amount: Double, what: String, day: DayKey) -> EntrySnapshot
    func move(_ entry: MeasureEntry, to day: DayKey)                 // R41
    func update(_ note: DayNote, kind: NoteKind, text: String, day: DayKey)  // R41 (alte Fassung ohne day bleibt)
    func setMarkNote(_ note: String, item: PlanItem, day: DayKey)    // R23: nur die Notiz, Wert bleibt wie gespeichert
    // setMarkNote(_:item:day:current:) bleibt bis Runde 5 als Weiterleitung auf die neue Fassung (ignoriert `current`,
    // damit der R23-Fehler sofort weg ist und Editors.swift bis P6 weiter passt); P9 löscht sie.
    @discardableResult func apply(suggestions: [(PlanItem, Mark)], day: DayKey) -> [(PlanItem, Mark?)]  // R12: vorher
    @discardableResult func setTask(_ block: WorkBlock, _ task: String) -> Bool  // R21: leer → false, nichts gespeichert
    // update(_ block:categoryKey:task:powerHours:result:nextStep:day:) (bestehend): leerer (getrimmter) task behält den
    // alten Text – der Speicher nimmt grundsätzlich keine leere PH-Beschreibung an (R21, K1).
    func workSuggestions(categoryKey: String, limit: Int = 8, days: Int = 90) -> [String]   // R32
    func expenseSuggestions(code: String, through day: DayKey, days: Int = 90, limit: Int = 12) -> [String]  // R32
    func recentWorkCombos(limit: Int = 3) -> [WorkCombo]             // R33, neueste zuerst, 60 Tage
    func lastValue(code: String, before day: DayKey, lookback: Int = 60) -> Double?   // R81
    func trash() -> Trash                                            // R19: jede Liste neueste zuerst (deletedAt absteigend)
    @discardableResult func mergeDuplicates() -> Int                 // R28: Anzahl zusammengeführter Gruppen
    func widgetSummary(today: DayKey) -> TodaySummary                // R4: heute + nextDay = [morgen]
    func publishWidget(today: DayKey = .today())                     // R4/R84: schreibt widgetSummary; macOS: No-op, In-Memory: No-op
    func planningSourceWeek(for target: WeekKey) -> WeekKey?         // R56: latestPlannedWeek(before: target)
    func planningPrompt(for target: WeekKey, today: DayKey) -> String  // R56/R91: einzige Stelle, die den Prompt baut
    func repeatPlanCSV(from source: WeekKey, to target: WeekKey) -> String   // R92
    func measureSeries(code: String, from: DayKey, through: DayKey) -> [SeriesPoint]   // R93
    func goalScoreHistory(goalKey: String, through week: WeekKey) -> [WeekScorePoint]  // R11/R93, je Woche einmal
    func workHistory(through week: WeekKey, weeks: Int = 8) -> [WeekWorkPoint]         // R88, älteste zuerst
    func periodReport(period: GoalPeriod, through week: WeekKey) -> PeriodReport       // R95
    func parkedIdeas() -> [DayNote]                                  // R95: Art .idea, neueste zuerst
    func expenseMeasure(week: WeekKey, create: Bool) -> MeasureDefinition?  // R97
    /// R97: nil bei amount <= 0 oder leerem what; legt den Messwert bei Bedarf an.
    @discardableResult func addExpense(_ amount: Double, what: String, day: DayKey) -> MeasureEntry?
    func undoImport(_ result: ImportResult)                          // R49
}
// save(): kein Widget-Schreiben mehr (R84); berechnet abgeschlossene, berührte Wochen neu (R11).
// archiveWeek: setzt auch finalScore/finalGoalScores/finalGoalsScored zurück (R11).
// addMeasure: Einheit "PH" → Quelle .work(category: categoryKey) (R77).
// ImportResult: neu `var archives: [WeekArchive] = []` (R49). apply(_:) übernimmt Abschlüsse aus der Datei (R27).

// WidgetBridge.swift (wird ins iOS-Widget und ins Watch-Widget kompiliert: nur Foundation/BinisoftKitCore/ThaliaCore)
extension WidgetBridge {
    static func enqueue(_ action: WidgetMarkAction)      // R87: <group>/Thalia/pending-marks.json
    static func drainPending() -> [WidgetMarkAction]     // liest und leert die Warteschlange
    static func applyOptimistic(_ action: WidgetMarkAction)  // Stand lesen, markingDone, schreiben, Timelines neu laden
}
// publish(_:) lädt Timelines auf iOS **und watchOS** neu (R86).

// WidgetPublisher.swift (neu, P1; nur App und Watch, nicht in Widget-Erweiterungen)
@MainActor
final class WidgetPublisher {
    init(container: ModelContainer)
    /// Beobachtet ModelContext.didSave, .NSCalendarDayChanged und NSPersistentCloudKitContainer.eventChangedNotification
    /// (Import-Ereignis beendet – Änderungen anderer Geräte, wichtig für die Watch-Komplikation), schreibt 1,5 s gebündelt.
    /// No-op auf macOS und bei In-Memory-Speichern.
    func start()
    func publishSoon()
    func publishNow()
}

// WidgetActions.swift (neu, **P8**; nur `#if os(iOS)`, kompiliert in App und iOS-Widget)
struct MarkDoneFromWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource      // "Punkt erledigt"
    static let isDiscoverable: Bool                 // false
    @Parameter(title: "Punkt") var itemKey: String
    @Parameter(title: "Tag") var dayKey: String
    init()
    init(itemKey: String, dayKey: String)
    @MainActor func perform() async throws -> some IntentResult
    // perform: WidgetActions.handler gesetzt → aufrufen; sonst WidgetBridge.enqueue; immer WidgetBridge.applyOptimistic.
}
@MainActor enum WidgetActions {
    static var handler: ((WidgetMarkAction) -> Void)?   // setzt die App beim Start (P2)
}

// GoalPalette.swift (neu, **P8**; aus App/Sources/Style.swift verschoben, API unverändert, auch im iOS-Widget)
```

### 3.3 App (Vertrag zwischen den App-Paketen)

```swift
// AppModel.swift (P2) – Schreibweise als Übersicht: gespeicherte Eigenschaften gehören in die Klasse selbst,
// nicht in eine Extension (gilt ebenso für TodaySummary oben).
enum AppSheet {
    case focus(DayKey)                          // GEÄNDERT (vorher WeekKey) – R22
    case weeklyGoals(WeekKey)                   // R16
    case planWeek(WeekKey)                      // R56: ImportView(showPrompt: true, week:)
    case repeatPlan(from: WeekKey, to: WeekKey) // R92: ImportView(showPrompt: false, week: to, repeatFrom: from)
    case editItem(PlanItem)                     // R63: ItemEditor(week:item:)
    case goalReview                             // R95: GoalReviewView()
    // alle übrigen Fälle unverändert; .dayOverview(day) zeigt jetzt GlanceSheet(day:)
}
// id: "focus-<day>", "weekly-goals-<week>", "plan-<week>", "repeat-<from>-<to>", "edit-item-<uuid>", "goal-review".
extension AppModel {
    var today: DayKey                     // folgt dem Systemtag (R1)
    var captureDay: DayKey { get }        // = selectedDay; Start-Tag jedes Erfassen-Fensters (R41)
    var todayPageOrder: [TodayPage]       // setzt TodayContent (P3) (R35)
    var showsGlanceInspector: Bool        // UserDefaults "today.inspector" (R59)
    var hasUnsavedInput: Bool             // über .unsavedInput(_:in:) (R14)
    var blocksSheetCommands: Bool { get } // sheet != nil && hasUnsavedInput (R14)
    var closeRequest: Int                 // +1 bei ⌘↩ / ⇧⌘↩, während ein Abschluss-Fenster offen ist (R39)
    var toastLevel: Int                   // Ebenenzähler für toastHost (R13)
    var mainWindowHeight: CGFloat         // Mac, für thaliaSheetFrame (R15), Standard 800
    func refreshToday()                   // R1/R6: Tageswechsel → selectedDay/selectedWeek mit, todayPage = nil, Widget
    func goToToday()                      // R7: selectedDay/selectedWeek = heute, tab/sidebar .today
    /// R18: day != nil && day != today → day; sonst DayKey.closingDay(... isClosed: store) .
    func dayToClose(showing day: DayKey? = nil) -> DayKey
    func moveTodayPage(by offset: Int)    // R35
    func addPowerHours(_ powerHours: Double, categoryKey: String, task: String, day: DayKey,
                       result: String = "", nextStep: String = "")          // R13: Toast mit Widerrufen
    func setValue(_ value: Double?, for measure: MeasureDefinition, day: DayKey, toast: Bool = true) // R2: Widerrufen = store.undo
    func applySuggestions(_ suggestions: [MarkSuggestion], day: DayKey)     // R12: "1 Vorschlag übernommen" + Widerrufen
    var menuBarTitle: String              // macOS (R96): "73 %", abgeschlossen "7,5", ohne Plan ""; neu berechnet bei
                                          // refreshToday, afterSync, ModelContext.didSave und App aktiv
    func updateExpense(_ entry: MeasureEntry, amount: Double, what: String, day: DayKey) // R46: "Ausgabe geändert" + Widerrufen
    func closeDay(_ day: DayKey)          // R80: store.closeDay + Abend-Erinnerung des Tages weg + Widget
    func reopenDay(_ day: DayKey)         // R80: store.reopenDay + Erinnerung wieder planen
    func closeWeek(_ week: WeekKey)       // store.closeWeek + Toast "KW47 abgeschlossen"
    func afterSync()                      // R4/R28: mergeDuplicates, Widget
    func applyWidgetAction(_ action: WidgetMarkAction)  // R87: ✓ setzen (nur wenn Punkt offen)
    func drainWidgetActions()             // R87: Warteschlange anwenden
}
// route(_:) versteht zusätzlich: "close-day" (dayToClose()), "close-day:YYYY-MM-DD", "close-week" (Woche von
// dayToClose()), "close-week:YYYY-Www", "glance" (Mac: Spalte, sonst Fenster), "focus" (.focus(today)),
// "goal-review", "weekly-goals".

// SheetChrome.swift (neu, P2)
extension View {
    func toastHost(_ app: AppModel) -> some View                    // R13: zeigt den Toast nur auf der obersten Ebene
    func thaliaSheetFrame(width: CGFloat, height: CGFloat) -> some View // R15: ersetzt jedes .sheetFrame(…)
    func unsavedInput(_ isDirty: Bool, in app: AppModel) -> some View // R14
}
struct SheetCloseButton: View { init(action: @escaping () -> Void) }  // R73: × mit VoiceOver "Schließen"

// AppPlatform.swift (P2)
extension View {
    /// R31: iPhone – Leiste über dem Ziffernblock mit einem Knopf ("Fertig" oder "Weiter"), nur solange isActive.
    func keypadButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View
}

// Components.swift (P5)
struct MarkCell: View {   // bestehende Aufrufe bleiben gültig
    let mark: Mark?
    let applies: Bool
    var isToday = false
    var suggestion: Mark?
    var options: [Mark] = Mark.allCases
    var hasNote = false                 // R65: kleiner Punkt
    var accessibilityPrefix = ""        // R66: "Mittwoch, Fahrrad fahren"
    var help = ""                       // R63: Tooltip
    var onOpenValue: (() -> Void)? = nil  // R9: automatische Punkte → Wert eintragen
    var onAddNote: (() -> Void)? = nil    // R65
    let onSet: (Mark?) -> Void
}
// options leer und onOpenValue nil → gedämpft (opacity 0.35), nicht antippbar, kein Menü.
// "Leeren" im Haltemenü nur bei gesetzter Markierung.
struct SuggestionChips: View {   // R32
    init(suggestions: [String], typed: String, selected: String, limit: Int = 6, onPick: @escaping (String) -> Void)
}
struct CaptureDayRow: View {     // R41: "Tag: Heute · Gestern · Datum", orange Hinweis wenn nicht heute
    init(day: Binding<DayKey>, today: DayKey)
}
/// R41: "Power-Hours" heute, "Power-Hours · So, 15. Nov." sonst.
func captureTitle(_ base: String, day: DayKey, today: DayKey) -> String
struct WrapLayout: Layout { init(spacing: CGFloat = 8) }   // R33/R78: umbrechende Chips
struct WeeklyTargetRow: View {    // R16/R47: Balken mit Soll-Strich, "6 von 8 PH – im Plan", Farbe des Ziels
    init(target: WeeklyTarget, onOpen: (() -> Void)? = nil)
}
struct WeeklyTargetsList: View {  // R16: die eine Wochenziel-Liste (ein Section-Inhalt)
    init(context: WeekContext, limit: Int? = nil, onOpen: ((MeasureDefinition) -> Void)? = nil)
}
struct DayNoteLabel: View { init(note: String) }   // R90: "Besonderheit: …", nichts bei leerem Text
struct KindBadge: View { init(text: String?) }     // R64: nimmt direkt context.kindLabel(item); nil/leer → nichts
// ScoreRing: neuer Parameter `var tint: Color = Brand.accent` (nach caption) (R68)
// GoalBars: neuer Parameter `var keys: [String] = []` (Zielschlüssel für Farben) (R68)

// TodayView.swift (P3)
// MarkBar: neuer Parameter `var compact = false` vor `onSet` → MarkBar(mark:options:suggestion:isProgress:compact:onSet:)
// (R61). Beantwortet → nicht gewählte Knöpfe grau (R36). Wörter aus Mark.label(progress:) (R43).
// DayOverviewSheet und DayOverviewList ENTFALLEN (ersetzt durch GlanceSheet/GlanceList, P4).
struct ExpenseInputRow: View {   // R31/R32/R46 – auch im Messwert-Fenster (P6, R3) benutzt
    init(measure: MeasureDefinition, context: WeekContext, day: DayKey, editing: Binding<MeasureEntry?>)
    // editing != nil: Felder vorbefüllt, Knopf "Sichern" → app.updateExpense, kleiner Knopf "Abbrechen" setzt nil.
}
struct ExpenseEntryRow: View {   // R46: Tipp / Kontextmenü "Bearbeiten" ruft onEdit
    init(entry: MeasureEntry, onEdit: (() -> Void)? = nil)
}

// Glance.swift (P4)
struct GlanceSheet: View { init(day: DayKey) }                         // R50/R51
struct GlanceList: View { init(context: WeekContext, day: DayKey, onOpen: @escaping (TodayPage) -> Void) }
struct FocusSheet: View { init(day: DayKey) }                          // GEÄNDERT (vorher week:) R22/R88
struct ExpensesSheet: View { init(day: DayKey) }                       // unverändert
struct WeeklyGoalsSheet: View { init(week: WeekKey) }                  // R16
struct YesterdayBanner: View {                                         // R94
    enum Style { case card, sidebar }
    init(today: DayKey, style: Style = .card)
}

// GoalsView.swift (P7)
struct GoalReviewView: View { init() }                                 // R95

// ImportView.swift (P2)
// init(showPrompt: Bool, week: WeekKey? = nil, repeatFrom: WeekKey? = nil, embedded: Bool = false)
// TrashView (SettingsView.swift, P2): init(embedded: Bool = false)

// Intents.swift (P8)
struct WorkAreaEntity: AppEntity { /* id = Kategorie-key, Anzeige "3.2 Titel" */ }
struct AddExpenseIntent: AppIntent { /* "Ausgabe in Thalia": Betrag, Wofür (Pflicht) */ }
```

### 3.4 Tour v7 (P9, `ThaliaTour.version = 7`)

13 Karten im ganzen Durchgang: `welcome` · 11 Schritte · `finish`. Mit `since: 7` (= „Neu in Thalia“): `day`, `mark`, `work`, `measure`, `glance`, `week`, `review`, `everywhere`. Entfallen: `colours`, `described`, `weekly-goals`, `share`, `pdf` (Inhalt in andere Karten verschoben). Neues Snapshot-Feld `ThaliaTourSnapshot.isGlanceOpen: Bool` (TourView: `.dayOverview`-Fenster offen oder Mac-Spalte sichtbar).

| # | id · since · Symbol | Titel | body (iPhone/iPad) | macBody | Ziel |
|---|---|---|---|---|---|
| 1 | create · 2 · plus.circle | Alles beginnt unten bei + | Tippe unten auf +. Von dort erfasst du Power-Hours, Ausgaben und Notizen – jedes Fenster zeigt oben, für welchen Tag es zählt. | Klicke in der Symbolleiste auf „Erfassen“ oder drücke ⇧⌘N. Jedes Fenster zeigt oben, für welchen Tag es zählt. | isCreateOpen |
| 2 | day · 7 · calendar | Welcher Tag gerade gilt | Oben stehen Datum, Tagestyp und die Besonderheit aus dem Plan. Um Mitternacht springt Thalia selbst auf den neuen Tag. Blätterst du zurück, zeigt die Leiste unten „Zu heute“. Ist gestern noch offen, erinnert dich morgens ein Hinweis mit „Nachtragen“ und „Abschließen“. | Oben stehen Datum, Tagestyp und die Besonderheit aus dem Plan. Um Mitternacht springt Thalia selbst auf den neuen Tag, ⇧⌘T führt zu heute. Ist gestern noch offen, steht links unten „Nachtragen“ und „Abschließen“. | – |
| 3 | mark · 7 · checkmark.circle | Punkte mit einem Tipp | Tippe bei einem Punkt auf Erledigt, Teilweise, Nicht erledigt oder Entfällt. Beantwortete Zeilen werden ruhig, offene bleiben bunt. Wische zur nächsten Kategorie oder tippe unten auf „Weiter“. | Klicke auf Erledigt, Teilweise, Nicht erledigt oder Entfällt – oder drücke 1, 2, 3, 4. Die Auswahl springt zum nächsten offenen Punkt, ⌥⌘↓ wechselt die Kategorie. | changed markSummary |
| 4 | work · 7 · bolt.fill | Power-Hours mit „Wofür“ | + → Power-Hours: oben stehen deine letzten drei Einträge zum Antippen. Sonst Bereich, Menge und Wofür – Return sichert. In den Arbeits-Kategorien steht die Zeile „Menge · Wofür · +“ direkt unter dem Wochenziel, das von selbst mitzählt. | ⌘N: oben die letzten drei Einträge zum Anklicken, sonst Bereich, Menge und Wofür – Return sichert. Das Wochenziel zählt von selbst mit. | increased workCount |
| 5 | measure · 7 · plus.forwardslash.minus | Werte und Ausgaben eintragen | Bei einem Messwert die Zahl eintippen – „Fertig“ über dem Ziffernblock speichert sofort. Ausgaben: Betrag, „Weiter“, Wofür – Vorschläge kommen aus den letzten Monaten. Ein Tipp auf eine Ausgabe ändert sie. | Bei einem Messwert die Zahl eintippen, Return speichert. Ausgaben: Betrag und Wofür – Vorschläge aus den letzten Monaten; ein Klick auf eine Ausgabe ändert sie. | changed entrySummary |
| 6 | undo · 1 · arrow.uturn.backward | Fehler sind kein Problem | Einen Power-Hour-Eintrag nach links wischen und löschen – dann im Hinweis auf „Widerrufen“. Der Hinweis erscheint immer im obersten Fenster. | Rechtsklick auf einen Power-Hour-Eintrag → Löschen, dann im Hinweis auf „Widerrufen“ – oder ⌘Z. | undone trashedWorkCount |
| 7 | close · 2 · moon.stars | Den Tag abschließen | Abends: „Tag abschließen“. Erst dann rechnet Thalia die Tageswertung. Danach kannst du den Tag als Bild teilen oder als PDF ansehen. | Abends: „Tag abschließen“ (⌘↩, zum Bestätigen nochmal ⌘↩). Danach als Bild teilen oder als PDF sichern (⌘S) und drucken (⌘P). | isCloseDayOpen |
| 8 | glance · 7 · eye | Heute im Blick | Tippe oben auf den Ring: was noch zu tun ist, „Diese Woche noch“, die Wochenziele mit Tempo und – sobald alles erfasst ist – „Tag abschließen“. Fokus und Ausgaben öffnen sich darin; Fokus blättert durch die Wochen und zeigt die letzten 8. | ⌘0 blendet „Heute im Blick“ rechts ein, während du weiterarbeitest. Fokus (⌘5) blättert durch die Wochen und zeigt die letzten 8, Ausgaben (⌘6) die ganze Woche nach Zweck. | isGlanceOpen |
| 9 | week · 7 · calendar.badge.plus | Sonntag: Woche abschließen und planen | Nach dem Tagesabschluss am Sonntag führt „Weiter: Woche abschließen“ direkt dorthin. Dann „1 · Prompt kopieren“ – er enthält den Plan der letzten Woche – und „2 · CSV einfügen“. Fällt die Planung aus: „Wie KW … wiederholen“. Eine ersetzte Woche kommt ins Archiv und lässt sich widerrufen. | Nach dem Tagesabschluss am Sonntag führt „Weiter: Woche abschließen“ dorthin, ⇧⌘↩ schließt sie ab. Dann „1 · Prompt kopieren“ und „2 · CSV einfügen“; fällt die Planung aus: „Wie KW … wiederholen“. | – |
| 10 | review · 7 · flag | Ziele über Monate | Im Ziel-Detail zeigt der Verlauf 12 Wochen, ein Halbjahr oder das ganze Zieljahr – mit Messwerten und Ziellinie. Drei Wochen vor der Zielüberprüfung hilft „Zielüberprüfung vorbereiten“, samt aller geparkten Ideen. | (gleich) | – |
| 11 | everywhere · 7 · applewatch | Überall dabei | Auf der Watch stehen Offenes und Zähler auf der ersten Seite, Werte stellst du mit der Krone ein; die Komplikation zeigt Ring, Offenes und PH. Im Widget hakst du offene Punkte direkt ab. Siri fragt bei Power-Hours nach dem Bereich, „Ausgabe in Thalia“ bucht Betrag und Wofür – auf Wunsch automatisch nach jeder Kartenzahlung. | Oben in der Menüleiste zeigt Thalia den Tag und erfasst Power-Hours und Ausgaben, ohne das Fenster zu öffnen. Auf iPhone und Watch: Widgets zum Abhaken, Komplikation, Siri. | – |

`finish`: „Die Tour findest du jederzeit wieder unter Einstellungen → Thalia-Tour (am Mac: Hilfe → Thalia-Tour). Neue Funktionen erscheinen hier als kurzes „Neu in Thalia“.“

---

## 4. Pakete

Zeilen mit „(Teil)“ gehören zu einem Punkt, der über mehrere Pakete verteilt ist. „Abnahme:“ = woran das Paket selbst sieht, dass es fertig ist (am Gerät prüft TESTING.md v7).

### P1 – Daten (Core + Shared)
**Dateien:** `Packages/ThaliaCore/Sources/ThaliaCore/*` (+ neu `Merge.swift`, `SyncGerman.swift`), `Packages/ThaliaCore/Tests/ThaliaCoreTests/*`, `Shared/Models.swift`, `Shared/TrackerStore.swift`, `Shared/TrackerStore+Import.swift`, `Shared/WeekContext.swift`, `Shared/WeekReader.swift`, `Shared/WidgetBridge.swift`, neu `Shared/WidgetPublisher.swift`, `Shared/Persistence.swift`, `Shared/DemoData.swift`, `docs/IMPORT.md`. Nicht: `ThaliaTour.catalog` (P9).

- [x] R1 (Teil) – `WidgetPublisher.start()` beobachtet `.NSCalendarDayChanged` und schreibt den neuen Tag. Abnahme: Code vorhanden, keine Wirkung auf macOS.
- [x] R2 (Teil) – `TrackerStore.setDayValue(code:day:value:) -> DayValueChange` nach Vertrag (Eintrag ändern statt löschen, Rest in den Papierkorb, Ausgaben abgelehnt) und `undo(_:)`, `snapshot(_:)`, `restore(_:)`. `setDayText` nach demselben Muster (neuester Text-Eintrag wird geändert, Rest in den Papierkorb). Abnahme: kein `context.delete` mehr in `setDayValue`/`setDayText`; `undo` stellt `value`, `note`, `isEstimate`, `recordedAt`, `deletedAt` wieder her; im Code-Review an diesem Beispiel nachvollzogen (Shared ist auf Linux nicht testbar): Summen-Messwert mit Einträgen 2, 3, 1 (älteste zuerst) auf 4 setzen → der neueste (1) fällt auf 0 und geht in den Papierkorb, der davor (3) wird 2, Summe 4; `undo` → wieder 2, 3, 1 mit Notizen und Uhrzeiten.
- [x] R3 (Teil) – `MeasureRecord.isExpense`, `isHealth`, `defaultClockMinutes` in Records.swift; `WeekContext.isExpense` ruft `record.isExpense`. `addEntry`/`setDayText` speichern keinen leeren Text (getrimmt leer → nichts). Abnahme: Test `measureKinds` (€, „ausgaben“-code, health, Uhrzeit-Ziel 22:30 → 1350, ohne Ziel → 1380).
- [x] R4 (Teil) – `widgetSummary(today:)` (heute + `nextDay = [morgen]` aus `weekContext(for: tomorrow.week, today: tomorrow).todaySummary()`), `publishWidget(today:)`, `TodaySummary.resolved(for:)`, `newDay(_:)`, neue Felder `dayKey`, `nextDay`, `isNewDay`. Abnahme: Test `summaryResolvesAfterMidnight` (gleicher Tag → self, morgen → nextDay, übermorgen → isNewDay true, fill 0, isClosed false); altes JSON ohne neue Felder dekodiert.
- [x] R5 (Teil) – `WeekData.isOpenRequired` (Core, auch in `Scorer.categoryDay` benutzt), `WeekContext.openToDo` neu, `openWeeklyToDo`, `openCount`; `todaySummary()` setzt `openCount` = Pflichtpunkte, `weeklyOpenCount`, `hasPlan`. Abnahme: Test `openMatchesBlank` (Summe von `isOpenRequired` über einen Tag == `score.days[day].blank`, mit Nebensache, n×/Woche, Fortschritt, freiem Tag).
- [x] R8 (Teil) – `WeekContext.dayStatusText(_:)`, `dayStatusAccessibility(_:)` nach Vertrag. Abnahme: kommende Tage „–“, nicht abgeschlossene „NN %“, abgeschlossene Wertung.
- [x] R11 (Teil) – `save()`: vor `context.save()` aus `insertedModelsArray`/`changedModelsArray`/`deletedModelsArray` die berührten Wochen sammeln (ItemMark.weekKey, PlanItem.weekKey, MeasureDefinition.weekKey, MeasureEntry/WorkBlock/ScoreOverride/PlanDay über dayKey → Woche); danach jede abgeschlossene davon neu werten (private `storeFinalScore(_ plan:)`, auch von `closeWeek` benutzt) und mit `try? context.save()` sichern (nicht rekursiv `save()`). `archiveWeek` setzt `finalScore = nil`, `finalGoalScores = ""`, `finalGoalsScored = 0`. `goalScoreHistory` nimmt je Woche nur den neuesten Plan. Abnahme: Code-Review; Nachtrag in abgeschlossener Woche ändert `finalScore`.
- [x] R12 (Teil) – `MarkSuggestion`, `suggestionsToFill(on:)` (Punkte mit `recordedMark == nil` und einem Vorschlag), `suggestionsDiffering(on:)` (gesetzte Markierung ≠ Vorschlag, `current` = gesetzte); `apply(suggestions:day:)` gibt vorherige Markierungen zurück. Abnahme: Signaturen wie im Vertrag; ein bewusst gesetztes ½ erscheint nur in `suggestionsDiffering`, nie in `suggestionsToFill`.
- [x] R16 (Teil) – `WeeklyTarget`, `weeklyTargets`, `weeklyTargetsMet`; `todaySummary().weekly` daraus. Abnahme: ein Limit „< 50 €/Woche“ mit 30 € zählt als erfüllt, mit 60 € nicht.
- [x] R17 (Teil) – `Format.euro`, `Format.measure` für „€“. Abnahme: Tests 12,99 € · 2,50 € · 13 € · 49,96 € · 1.234,50 € · -3,50 €.
- [x] R18 (Teil) – `DayKey.closingDay(...)`. Abnahme: Tests (Europe/Vienna) 03:30 mit offenem Vortag → Vortag; 03:30 mit geschlossenem Vortag → heute; 04:00 → heute; 23:00 → heute.
- [x] R19 (Teil) – `trash()` jede Liste nach `deletedAt` absteigend.
- [x] R21 (Teil) – `setTask` lehnt leere (getrimmte) Beschreibung ab, gibt `false` zurück; `update(_ block:…)` behält bei leerem task den alten Text. Abnahme: kein Weg im Speicher schreibt eine leere Beschreibung über eine vorhandene.
- [x] R23 – `setMarkNote(_:item:day:)` schreibt nur die Notiz in die (ggf. neue) `ItemMark`, `valueRaw` bleibt wie gespeichert (neu: ""); alte Variante mit `current:` leitet bis Runde 5 nur noch auf die neue weiter (P9 löscht sie). Abnahme: kein Aufruf von `setMark` aus `setMarkNote`; eine Notiz an einem freien Tag speichert `valueRaw == ""`.
- [x] R26 (Teil) – `ReflectionQuestion.dayNoteField = "notiz"`; Reports nutzt die Konstante statt "notiz".
- [x] R27 – Sicherung vollständig: (a) `EntryPart`/`EntryRecord.parts`; `TrackerStore.aggregate` füllt `parts`, wenn eine Gruppe > 1 Eintrag hat oder der Messwert `isExpense` ist (`minutes` = `DayKey.minutes(of: recordedAt)`); (b) `apply`: Eintrag mit `parts` → alte Einträge des Tages in den Papierkorb, je Part ein `MeasureEntry` mit `recordedAt = day.date(minutes:)`; (c) Abschlüsse: `ExistingState.closedDays/closedWeeks`, `PlanCSV` Flag `abgeschlossen` lesen/schreiben, `exportDocument` schreibt sie (auch Tage ohne Typ/Notiz), `apply` setzt `preview.newClosedDays` (`closedAt = now`) und schließt `newClosedWeeks` über `closeWeek` (Wertung); (d) `existingState()` nimmt überall die neueste Fassung (`latest(by:modified:)` auch für ItemMark, WorkBlock, DayNote, Reflection, ScoreOverride); (e) `docs/IMPORT.md`: Flags `abgeschlossen`, `einzeln`, Uhrzeit in `title`, Hinweis auf ältere Versionen. Abnahme: Test `backupRoundTrip` – 3 Ausgaben an einem Tag + abgeschlossener Tag + abgeschlossene Woche → export → parse → `ImportPreview` gegen denselben Zustand: alles `unchanged`, 3 Parts mit Uhrzeit; Test `oldBackupStillImports` (Datei ohne Flags: wird gelesen; gegen einen Zustand mit 3 Einzel-Ausgaben gleicher Summe ist der Eintrag `unchanged` – nichts wird zusammengefasst).
- [x] R28 – `Merge.swift` (`DayVersion`, `WeekVersion`, `DuplicateMerge`) und `TrackerStore.mergeDuplicates()`: PlanDay je `dayKey`, WeekPlan (nicht gelöscht) je `weekKey`; behalten wird der älteste (`createdAt`), Werte aus `DuplicateMerge`, übrige gelöscht, gespeichert, Log „Merged n duplicate day/week record(s)“. Abnahme: Tests `mergeDays` (leerer neuerer Typ verliert gegen älteren ausgefüllten; abgeschlossen gewinnt) und `mergeWeeks` (Wertung aus abgeschlossener Fassung).
- [x] R29 (Teil) – `DayKey.date(minutes:timeZone:)`, `DayKey.minutes(of:timeZone:)`. Abnahme: Test Europe/Vienna: 2026-10-25 und 2026-03-29, 23:00 → Stunde 23, 00:30 (1470) → 00:30 desselben Kalendertags.
- [x] R32 (Teil) – `workSuggestions(categoryKey:limit:days:)` nur letzte 90 Tage, `expenseSuggestions(code:through:days:limit:)` (Notizen der Einträge des codes, 90 Tage, Häufigkeit, dann jüngste Nutzung).
- [x] R33 (Teil) – `WorkCombo`, `recentWorkCombos(limit:)`.
- [x] R41 (Teil) – `move(_:to:)`, `update(_:kind:text:day:)`; `update(_ block:…day:)` gibt es schon.
- [x] R43 (Teil) – `Mark.label` neu, `Mark.label(progress:)`. Abnahme: Test `markWords`.
- [x] R46 (Teil) – `editExpense(_:amount:what:day:)` (Betrag auf Cent gerundet, Wofür getrimmt, nicht leer).
- [x] R47 (Teil) – `Pace(…, excluding:)`, `WeekContext.pace(for:)` (arbeitsfreie Tage raus bei Arbeits-Messwerten), `WeeklyTarget.pace` daraus. Abnahme: Test `paceSkipsFreeDays` (Mo–Fr, Mi frei, Ziel 8, Do: expected = 8 × 3/4).
- [x] R49 (Teil) – `WeekReplacement`, `ImportPreview.replacements`, neue `lines`; `ImportResult.archives`; `undoImport(_:)`: je Archiv `restore(_:)` und danach das dabei neu entstandene Archiv der importierten Woche löschen. Abnahme: Test `replacementText` („KW47 wird ersetzt – 2 Markierungen und 1 Wert gehen ins Archiv.“, Knopf „KW47 ersetzen“).
- [x] R52 (Teil) – `WorkTotals.netText`, `explanation` neu. Abnahme: Test „28 PH × 50 min = 23 h 20 min netto“ (bestehenden Test anpassen).
- [x] R54 (Teil) – `ExpensePurpose`, `expensesByPurpose(_:limit:)` (Gruppierung nach getrimmter Notiz, Groß/klein zusammen, Anzeige der häufigsten Schreibweise).
- [x] R56 (Teil) – `planningSourceWeek(for:)`, `planningPrompt(for:today:)` – Inhalt wie bisher in ImportView (Struktur, Messwerte der Quellwoche falls die Zielwoche keine hat, Bericht der Quellwoche, Änderungen) plus R91. Abnahme: CloseWeekView und ImportView können ihre eigene Prompt-Funktion löschen.
- [x] R58 (Teil) – `ReflectionQuestion.isJournalTitle`, `WeekContext.journalItem`, `journalDone(on:)`, `WeekReport` Journal-Spalte aus dem Punkt. Abnahme: Test `journalFromItem` (Punkt ✓, Reflexion „nein“ → Bericht zeigt ✓).
- [x] R64 (Teil) – `WeekContext.kindLabel(_:)`.
- [x] R77 (Teil) – `Target.Comparison.choiceLabel/choices`, `Target.sentence(period:unit:)`, `Units.choices`; `addMeasure` macht aus „PH“ eine Arbeits-Quelle. Abnahme: Tests „Erfüllt bei ≤ 6 pro Tag“, „Erfüllt bei ≤ 23:00 pro Tag“, „Erfüllt bei 150–180 g pro Woche“.
- [x] R78 (Teil) – `DayTypes.workFreeHint`, `NoteKind.listText`.
- [x] R79 (Teil) – `SyncGerman.swift` mit allen Texten aus dem Vertrag (`storage`, `account`, `summary`, `error`, `reason`). Abnahme: Tests je Zustand; `error` je Fall einmal mit dem englischen Kit-Satz (`SyncErrorText.describe(raw, appName:)`) und einmal mit dem Rohtext.
- [x] R80 (Teil) – `ReminderSettings`: eigenes `init(from:)`, `macDefault`, `snoozeActionID`, `eveningCategoryID`, `snoozeMinutes`, `eveningID(_:)`, `DatedRequest`, `eveningRequests(from:count:isClosed:)`, `requests()` ohne Abend, neuer Morgentext, Woche → „close-week“. Abnahme: Tests (alte JSON ohne neue Felder lesbar; 7 Abende, geschlossener Tag fehlt; `evening = false` → leer); bestehenden Test `remindersUseApplesWeekdays` anpassen (6 statt 7 Anfragen, kein `thalia.evening` mehr in `requests()`, Abend-Prüfung über `eveningRequests`).
- [x] R81 (Teil) – `Units.crownStep`, `lastValue(code:before:lookback:)`.
- [x] R84 – `#Index` in Models.swift wie im Vertrag; `save()` schreibt kein Widget mehr; `WidgetPublisher`; `weekContext(for:)` holt `WeekPlan` nur für diese Woche (`#Predicate { $0.weekKey == key }`), `latestPlannedWeek` und `workSuggestions` mit Prädikat statt Vollscan. Abnahme: `tools/schema-from-models.py Shared/Models.swift HealthValue` liefert dieselbe Ausgabe wie vorher (`diff` leer).
- [x] R86 (Teil) – WidgetBridge: `import WidgetKit` und `reloadAllTimelines()` unter `#if os(iOS) || os(watchOS)`.
- [x] R87 (Teil) – `WidgetMarkAction`, `TodaySummary.openKeys`/`dueCount`/`markingDone(itemKey:)`, `WidgetBridge.enqueue/drainPending/applyOptimistic`. Abnahme: Test `markingDoneUpdatesSummary`.
- [x] R88 (Teil) – `WeekWorkPoint`, `workHistory(through:weeks:)` (Ziel = Summe der PH-Wochenziele der jeweiligen Woche).
- [x] R90 (Teil) – `WeekContext.dayNote(_:)`, `TodaySummary.dayType/dayNote`.
- [x] R91 – `PlanPrompt.text(…, currentPlan:currentPlanWeek:trend:)`; `planningPrompt` hängt `PlanCSV.export(document.planOnly(week: source))` an und 4 Tendenz-Zeilen „KW44: Wertung 7,1 · 22 von 28 PH“ (ohne Wertung „–“). Abnahme: Test `promptCarriesPlan` (enthält „Übernimm diese Zeilen“ und die item-Zeile der Quellwoche).
- [x] R92 (Teil) – `Document.repeated(from:to:)`, `repeatPlanCSV(from:to:)`. Abnahme: Test `repeatPlan` (Tage +7, Typ/Notiz gleich, keine marks/entries, gleiche codes).
- [x] R93 (Teil) – `SeriesPoint`, `measureSeries`, `WeekScorePoint`, `goalScoreHistory`.
- [x] R95 (Teil) – `PeriodReport` (+ markdown), `periodReport(period:through:)` (Wochen von `period.start.week` bis `week`, nur mit Plan; Ziel-Wertungen aus `finalGoalScoreMap`), `parkedIdeas()`. Abnahme: Test `periodReport` mit zwei Wochen (Ø, häufigster ✗, PH je Bereich, Messwert erster/letzter, Ideen).
- [x] R97 (Teil) – `expenseMeasure(week:create:)` (sucht `isExpense`, legt sonst „Ausgaben“, €, Kategorie des ersten Ziel-8-Bereichs, `carryOver: true` an), `addExpense(_:what:day:)`.
- [x] H1 (Teil) – `HealthDevice.readsHealth`, `WeekContext.healthElsewhereHint`, `isHealthElsewhere`, `countsAsMissing`. Abnahme: Code-Review – auf macOS/watchOS liefert `countsAsMissing` für einen `health:`-Messwert ohne Wert `false`, auf iOS `true`; der Hinweistext steht nur an einer Stelle (`healthElsewhereHint`).

### P2 – App-Rahmen
**Dateien:** `App/Sources/AppModel.swift`, `RootView.swift`, `ThaliaApp.swift`, `Services.swift`, `SettingsView.swift`, `ImportView.swift`, `TourView.swift`, `AppPlatform.swift`, neu `SheetChrome.swift`, neu `MenuBar.swift`, `Config/iOS/Info.plist`, `Config/macOS/Thalia.entitlements`.

- [x] R1 – `AppModel`: `startDayWatch()` im `init` (nicht Sandbox): `.NSCalendarDayChanged`, iOS `UIApplication.significantTimeChangeNotification`, macOS `NSApplication.didBecomeActiveNotification` → `refreshToday()`; `refreshToday()` nach Vertrag. RootView behält `scenePhase == .active`. Abnahme: Mac-Fenster über Mitternacht offen → „Heute“, Leiste und neue Einträge gehören zum neuen Tag; ein bewusst gewählter älterer Tag bleibt.
- [x] R2 (Teil) – `setValue(_:for:day:toast:)`: `let change = store.setDayValue(…)`; Toast „Wasser: 2,5 l“ mit Widerrufen → `store.undo(change)`; bei leerem `change` kein Toast.
- [x] R4 (Teil) – `AppModel` hält einen `WidgetPublisher` (nicht Sandbox, nicht Demo) und startet ihn; `refreshToday`, `afterSync`, `scenePhase` `.background`/`.inactive` → `publishNow()`. RootView: `.onChange(of: app.sync.state.lastSync) { app.afterSync() }`.
- [x] R5 (Teil) – `TodayAccessory`: ohne Plan „Kein Plan – Wochenplan importieren“ (Tipp → `.planWeek(app.today.week)`), sonst geschlossen „Tag abgeschlossen“, `openCount == 0` „Alles erfasst“, sonst „Heute 73 %“ mit Untertitel „11 offen · 4 PH“ (`context.openCount`). *Umgesetzt mit `.planWeek(day.week)`: die Leiste folgt dem gewählten Tag (R7) und plant die Woche, der der Plan fehlt – bei gewähltem Heute ist das `app.today.week`.*
- [x] R6 (Teil) – `refreshToday()` setzt `todayPage = nil`, wenn `selectedDay` mitwandert.
- [x] R7 – Leiste folgt `app.selectedDay` (Titel „Heute 73 %“ bzw. „So · 80 %“); ist er nicht heute, zusätzlicher Knopf „Zu heute“ (Symbol `arrow.uturn.backward`, Beschriftung für VoiceOver) → `goToToday()`; Mond schließt `app.dayToClose(showing: app.selectedDay)`; TabView-Selection-Binding: erneutes Tippen auf „Heute“, während `tab == .today` → `goToToday()`. Abnahme: Sonntag gewählt → Leiste „So · 80 %“ mit „Zu heute“; „+“ und Mond zielen auf Sonntag; erneuter Tipp auf den Heute-Tab springt auf heute.
- [x] R12 (Teil) – `applySuggestions(_:day:)`: `store.apply(suggestions: suggestions.map { ($0.item, $0.mark) }, day:)` → Toast „\(Format.count(n, "Vorschlag", "Vorschläge")) übernommen“ mit Widerrufen → `store.restoreMarks(previous, day:)`.
- [x] R13 – `SheetChrome.swift`: `toastHost(_:)` (Modifier zählt `app.toastLevel` hoch/runter in `onAppear`/`onDisappear`, merkt seine Ebene, zeigt `app.toasts.current` nur auf der obersten Ebene; eigene Toast-Ansicht mit `floatingGlass`, Knopf „Widerrufen“, Abstand unten 72 pt auf Ebene 1, sonst 16 pt); `AppChrome` nutzt `.toastHost(app)` statt `.toasts(app.toasts)`; `SheetContent` bekommt `.toastHost(app)`; `TourPresenter` ebenso. `addPowerHours(…result:nextStep:)`. Abnahme: kein `.toasts(` mehr im App-Code.
- [x] R14 – `unsavedInput(_:in:)`; in `ThaliaCommands` jeder Befehl, der ein Fenster öffnet: `.disabled(app.commandTarget.blocksSheetCommands)`; Ausnahme: „Tag abschließen…“ (⌘↩) bzw. „Woche abschließen…“ (⇧⌘↩), solange genau das passende Abschluss-Fenster offen ist – dann lösen sie `closeRequest` aus (R39) und ersetzen nichts. „Zuletzt gelöscht“, „Wie wird gerechnet?“, „Power-Hours“ setzen `app.commandTarget.sheet`. Zusätzlich prüft jede dieser Aktionen beim Ausführen `blocksSheetCommands` und tut dann nichts – falls das Menü den ausgegrauten Zustand verspätet zeigt, geht trotzdem keine Eingabe verloren. Abnahme: im Punkt-Fenster eine Notiz tippen, ⌘N/⇧⌘N/⌘↩ → nichts passiert; im Tagesabschluss mit Abendnotiz ⌘↩ → schließt den Tag ab, Notiz bleibt gespeichert.
- [x] R15 – `thaliaSheetFrame(width:height:)`: macOS `frame(minWidth: width, idealWidth: width + 40, maxWidth: .infinity, minHeight: 360, idealHeight: h, maxHeight: h)` mit `h = min(height, max(360, mainWindowHeight − 80))` (AppModel optional aus der Umgebung: `@Environment(AppModel.self) private var app: AppModel?`), iOS unverändert. Mac-Root misst die Höhe (`onGeometryChange`) → `mainWindowHeight` und hat `.frame(minWidth: 900, minHeight: 620)`. Eigene `.sheetFrame`-Aufrufe in RootView (Archiv 520 × 680, Einstellungen 540 × 760), SettingsView (Kategorie 420 × 380, Papierkorb 480 × 640), ImportView (600 × 820) ersetzen; `TourPresenter` (Mac) statt `.frame(minWidth: 760, idealWidth: 900, minHeight: 680, idealHeight: 800)` → `.thaliaSheetFrame(width: 760, height: 800)` (die alte Mindesthöhe 680 lag über der Mindesthöhe des Hauptfensters). Abnahme: Mac-Hauptfenster auf 900 × 620 verkleinert – „Tag abschließen“, PDF, Import und Tour passen ins Fenster, „Abschließen“/„Fertig“ sind erreichbar, der Inhalt scrollt.
- [x] R16 (Teil) – `AppSheet.weeklyGoals` + `SheetContent` → `WeeklyGoalsSheet(week:)`.
- [x] R18 (Teil) – `dayToClose(showing:)`; `route("close-day")` und Befehl „Tag abschließen…“ benutzen ihn; `route("close-day:<Datum>")` öffnet genau diesen Tag. `NotificationRouter` reicht `destination` mit Tag weiter.
- [x] R19 (Teil) – `TrashView`: lesbare Zeilen (PH: Titel = Wofür, Untertitel „Mo, 16. Nov. · <Kategorietitel> · 2 PH“; Einträge eines Ausgaben-Messwerts „Ausgaben: 12,50 € · Mittagessen“, andere „<Messwert>: 0,5 l · Mo, 16. Nov.“; Punkte/Messwerte „KW47 · 1.1 <Titel>“), `.swipeActions(edge:allowsFullSwipe: false)`, „Endgültig löschen“ und „Leeren“ mit `confirmationDialog` („Endgültig löschen?“ / „Papierkorb leeren?“, Nachricht „Das lässt sich nicht widerrufen.“); `ArchiveView` „Löschen“ ebenso mit Rückfrage. Abnahme: kein Vollwischen löscht.
- [x] R20 – ImportView: Vorschau 0,6 s nach dem letzten Tastendruck (`.task(id: text)` mit `Task.sleep`), `previewText` merkt, wofür die Vorschau gilt, „Importieren“ nur bei `previewText == text`; `.onChange(of: targetWeek) { promptCopied = false }`; `Link("ChatGPT öffnen", destination: URL(string: "https://chatgpt.com")!)` neben „Prompt kopieren“. Abnahme: Vorschau zeigen, im Textfeld eine Zeile ändern → nach 0,6 s neue Vorschau, „Importieren“ übernimmt die Korrektur; Woche umstellen → Knopf heißt wieder „Planungs-Prompt kopieren“.
- [x] R22 (Teil) – `AppSheet.focus(DayKey)`, `SheetContent` → `FocusSheet(day:)`, `route("focus")` → `.focus(today)`, Launch-Option „focus“ → `.focus(today)`, Befehl ⌘5 → `.focus(target.selectedDay)`.
- [x] R24 – `SettingsView` auf **allen** Plattformen (iPhone/iPad-Fenster und Mac-Einstellungsfenster): „Wochenplan importieren & exportieren…“ und „Zuletzt gelöscht“ als `NavigationLink` mit `ImportView(showPrompt: true, embedded: true)` bzw. `TrashView(embedded: true)` (ohne eigenen NavigationStack und ohne Schließen-Knopf) – so öffnen sie dort, wo man gerade ist, statt hinter dem Einstellungsfenster. Mac-Einstellungsfenster, „Thalia-Tour“: `openWindow(id: "main")`, `NSApp.activate()`, Einstellungsfenster schließen (`NSApp.keyWindow?.close()` – es ist in dem Moment das Schlüsselfenster), dann `app.startTour()`. Abnahme: iPhone – Import aus den Einstellungen, „Zurück“ führt in die Einstellungen; Mac – Import und Papierkorb erscheinen im Einstellungsfenster, die Tour startet im Hauptfenster.
- [x] R28 (Teil) – `afterSync()` ruft `store.mergeDuplicates()`; einmal beim Start (nicht Demo/Sandbox).
- [x] R30 – ThaliaApp: macOS `Window("Thalia", id: "main")` statt `WindowGroup` (Rest gleich, `MainWindowGuard` bleibt), iOS `WindowGroup(id: "main")`; Info.plist `UIApplicationSupportsMultipleScenes` = false. Abnahme: Mac hat kein „Neues Fenster“ (⌘N bleibt Power-Hours).
- [x] R31 (Teil) – `keypadButton(_:isActive:action:)` in AppPlatform.swift (iOS: `.toolbar { ToolbarItemGroup(placement: .keyboard) { if isActive { Spacer(); Button(title, action: action).fontWeight(.semibold) } } }`, macOS: unverändert).
- [x] R35 (Teil) – Menü „Gehe zu“: „Nächste Kategorie“ (⌥⌘↓), „Vorige Kategorie“ (⌥⌘↑) → `commandTarget.moveTodayPage(by: ±1)`, deaktiviert außerhalb von „Heute“; `moveTodayPage` blättert in `todayPageOrder`.
- [x] R39 (Teil) – `closeRequest`; „Tag abschließen…“ (⌘↩): ist `.closeDay` offen → `closeRequest += 1`, sonst Fenster öffnen.
- [x] R40 (Teil) – „Woche abschließen…“ bekommt ⇧⌘↩ (gleiches Muster mit `closeRequest`); `route("close-week")` öffnet `.closeWeek`; Wochen-Erinnerung zielt auf „close-week“.
- [x] R41 (Teil) – `captureDay`; „Power-Hours erfassen…“, „Notiz…“, „Messwert eintragen…“ (heißt heute „Messwert erfassen…“, R75) starten mit `captureDay`.
- [x] R46 (Teil) – `updateExpense(_:amount:what:day:)`: `store.editExpense` → Toast „Ausgabe geändert“ mit Widerrufen → `store.restore(snapshot)`.
- [x] R49 (Teil) – ImportView: je `preview.replacements` ein oranger Hinweis (`exclamationmark.triangle.fill`, `replacement.text`); Knopf „KW47 ersetzen“ (mehrere: „KW47, KW48 ersetzen“) mit `confirmationDialog` („KW47 ersetzen?“, Nachricht „23 Markierungen und 9 Werte gehen ins Archiv. Du kannst das danach widerrufen.“); nach dem Import Toast „Importiert: …“ mit Widerrufen → `store.undoImport(result)` (nur wenn ersetzt wurde). Fußtext: „Hat eine Woche schon einen Plan, wird sie ersetzt: der alte Plan kommt mit Markierungen und Werten ins Archiv (Einstellungen → Archiv).“
- [x] R56 (Teil) – ImportView(`week:`): Zielwoche vorbelegt (`onAppear` setzt `targetWeek = defaultWeek()` nur noch, wenn `week == nil`); liegt `planningSourceWeek(for:)` vor und ist nicht abgeschlossen → oranger Hinweis „KW46 ist noch nicht abgeschlossen – erst danach kennt der Prompt verfehlte Ziele.“ + Knopf „Erst Woche abschließen“ (→ `.closeWeek(source)`); Abschnitte „1 · Prompt kopieren“ und „2 · CSV einfügen“; Prompt nur noch über `store.planningPrompt(for:today:)`. `AppSheet.planWeek` in `SheetContent`.
- [x] R59 (Teil) – `showsGlanceInspector` (liest/schreibt `UserDefaults` „today.inspector“); Mac ⌘0 → `sidebar = .today`, `showsGlanceInspector.toggle()`; `route("glance")` am Mac ebenso. Abnahme: Mac – ⌘0, Klick auf den Ring und auf „HEUTE“ blenden die rechte Spalte ein und aus, Heute bleibt daneben bedienbar; der Zustand übersteht einen Neustart; die grauen Zeilen zeigen beim Darüberfahren Hintergrund und Tooltip (P4).
- [x] R62 (Teil) – Menü: „Erstellen…“ heißt „Erfassen…“ (⇧⌘N), „Messwert erfassen…“ heißt „Messwert eintragen…“ (⇧⌘E, R75); „Gehe zu“ bekommt „Vorige Woche“ (⇧⌘[) und „Nächste Woche“ (⇧⌘]) auf `selectedWeek`; „Vorheriger Tag“/„Nächster Tag“ nur aktiv, wenn `sidebar == .today`. Abnahme: das Menü zeigt „Erfassen…“ ⇧⌘N und „Messwert eintragen…“ ⇧⌘E; „Gehe zu“ hat „Vorige/Nächste Woche“; „Vorheriger/Nächster Tag“ sind außerhalb von Heute ausgegraut; die Heute-Leiste zeigt „Tag abschließen“ mit Text (P3).
- [x] R63 (Teil) – `AppSheet.editItem(PlanItem)` → `ItemEditor(week: WeekKey(item.weekKey) ?? app.selectedWeek, item: item)`.
- [x] R71 (Teil) – `Config/macOS/Thalia.entitlements`: `com.apple.security.print` = true.
- [x] R73 (Teil) – `SheetCloseButton` in `SheetChrome.swift` (`Button(action: action) { Image(systemName: "xmark") }`, `.accessibilityLabel("Schließen")`, `.help("Schließen")`); P2-eigene Fenster (Import, Einstellungen-Fenster am iPhone, Papierkorb) nutzen ihn schon jetzt.
- [x] R79 – Einstellungen: eigener Abschnitt „iCloud & Daten“ mit `SyncGerman.storage(app.mode)`, `SyncGerman.account(app.sync.state.account)`, `SyncGerman.summary(…)`, Fehlertext `SyncGerman.error(…)` (ersetzt die Kit-Ansicht `SyncStatusSection`); die Kit-Seite `DataLocationView` (englisch: „Status on this device“, „Where Your Data Lives“) wird durch eine eigene `ThaliaDataLocationView` in SettingsView.swift ersetzt: dieselben `ThaliaDataFacts.sections`, Abschnitt „Status auf diesem Gerät“ mit „Synchronisation“ (`SyncGerman.summary`), „Speicher“ (`SyncGerman.storage`), „iCloud-Container“, Grund (`SyncGerman.reason`) und Fehler (`SyncGerman.error`), Titel „Wo deine Daten liegen“; `.task { await app.sync.refreshAccount() }` bleibt. Zeile „Bundle“ entfällt; „Speicher“ nutzt `SyncGerman.storage`. Abnahme: `grep -n "SyncStatusSection\|DataLocationView\|mode.title\|account.title\|sync.summary" App/Sources` findet nichts mehr.
- [x] R80 – Services: `ReminderScheduler.apply(_ settings: ReminderSettings, authorize: Bool, isClosed: @escaping (DayKey) -> Bool = { _ in false }) async -> String` (AppModel übergibt `{ store.planDay($0)?.isClosed ?? false }`; bei jedem Aktivwerden der App neu geplant, 7 Tage voraus) fragt nur bei `authorize` nach Erlaubnis, sonst nur, wenn schon erlaubt (`notificationSettings().authorizationStatus == .authorized`); plant `requests()` + `eveningRequests(from: today, …)` (einmalige Kalender-Auslöser, Kategorie `eveningCategoryID` mit Aktion `UNNotificationAction(identifier: ReminderSettings.snoozeActionID, title: "In 30 Min.", options: [])`, registriert per `UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier: ReminderSettings.eveningCategoryID, actions: [snooze], intentIdentifiers: [], options: [])])`, `userInfo["destination"]`); `dayClosed(_:)` entfernt ausstehende und zugestellte Mitteilung `eveningID(day)`; `dayReopened(_:)` plant neu; `NotificationRouter` behandelt die Aktion („In 30 Min.“ → einmalig in 30 min neu). `load()` liefert auf macOS ohne gespeicherte Einstellungen `.macDefault`. ThaliaApp ruft beim Start `apply(…, authorize: false)`; `AppModel.finishTour()` und die Erinnerungs-Einstellungen rufen `authorize: true`. Einstellungen: Fußtext am Mac „Am Mac standardmäßig aus – das iPhone erinnert dich schon.“
- [x] R84 (Teil) – nur iOS schreibt Widget-Stand (der `WidgetPublisher` ist auf macOS ein No-op).
- [x] R87 (Teil) – ThaliaApp (iOS): `WidgetActions.handler = { model.applyWidgetAction($0) }`; RootView bei `.active` → `app.drainWidgetActions()`; `applyWidgetAction`: Woche/Punkt über `store.items(WeekKey(action.weekKey))` finden, nur bei leerer Markierung `store.setMark(.done…)`, danach Widget veröffentlichen.
- [x] R89 (Teil) – Einstellungen, Abschnitt „Siri und Kurzbefehle“: „„Hey Siri, Power-Hour in Thalia erfassen“ – Siri fragt nach Bereich, Menge und Wofür. „Ausgabe in Thalia“ fragt nach Betrag und Wofür.“
- [x] R92 (Teil) – `AppSheet.repeatPlan`; ImportView(`repeatFrom:`): beim Erscheinen `text = store.repeatPlanCSV(from:to:)` + Vorschau; Menü „Vorlagen“ bekommt „Wie \(source.label) wiederholen“ (`source = planningSourceWeek(for: targetWeek)`).
- [x] R95 (Teil) – `AppSheet.goalReview` → `GoalReviewView()`; `route("goal-review")`.
- [x] R96 – neu `MenuBar.swift` (nur macOS): `MenuBarContent` mit Statuszeile (`GlanceText.dayLine`), kompaktem PH-Formular (bis zu drei `recentWorkCombos` als Knöpfe zum Füllen, Bereich-Menü, Menge 0,25–8, „Wofür?“, Knopf „Erfassen“ → `app.addPowerHours`), Ausgaben-Zeile (Betrag, „Wofür?“, „Erfassen“ → `store.expenseMeasure(week:create: true)` + `app.addExpense`), „Thalia öffnen“ (`openWindow(id: "main")`, `NSApp.activate()`), „Tag abschließen…“ (öffnen + `.closeDay(app.dayToClose())`). ThaliaApp: `MenuBarExtra(isInserted: $menuBarEnabled) { … } label: { … }` mit `.menuBarExtraStyle(.window)`, `@AppStorage("menubar.enabled") var menuBarEnabled = true`; Label: `Text(app.menuBarTitle)` neben einem Symbol (ohne Plan nur das Symbol) – bewusst kein `WeekReader`/`@Query` im Label, weil die Menüleiste nur Text und Bild sicher darstellt; `menuBarTitle` hält AppModel aktuell (Vertrag). Der Inhalt des Fensters bekommt `.environment(app)`, `.environment(health)`, `.modelContainer(app.container)`. Einstellungen (Mac): Schalter „Thalia in der Menüleiste“. Abnahme: Label ändert sich nach einem Haken in der App ohne Neustart.
- [x] R97 (Teil) – Einstellungen, gleicher Abschnitt: „Kartenzahlungen automatisch: Kurzbefehle → Automation → Transaktion → Aktion „Ausgabe in Thalia“, Betrag = Betrag, Wofür = Händler. Dann landet jede Kartenzahlung von selbst in Thalia; von Hand bleiben nur Barzahlungen.“
- [x] Launch-Optionen (für CI-Bilder): „weekly-goals“ → `.weeklyGoals(today.week)`, „goal-review“ → `.goalReview`, „trash“ → `.trash`.

### P3 – Heute
**Dateien:** `App/Sources/TodayView.swift` (darf in neue Dateien geteilt werden, z. B. `TodayRows.swift`, `TodayHeader.swift`; Namen bleiben).

- [x] R2 (Teil) – `MeasureMenu`: „Wert leeren“ nicht bei Ausgaben (`context.isExpense`) und nicht bei Arbeit.
- [x] R6 – `TodayContent`: Startseite in `app.todayPage` **speichern** (in `.task(id: day)` und in `.onChange(of: pages.map(\.key))`: ist `todayPage` nil oder nicht mehr in den Seiten – z. B. nach einem Wechsel des Tagestyps – → `firstOpenPage`); der Binding-Getter liest nur noch `app.todayPage` (kein `?? firstOpenPage` mehr, das bei jedem Haken neu rechnet); `firstOpenPage` gibt `.day` zurück, wenn nichts offen ist; kein automatisches Weiterspringen beim Abhaken. Abnahme: letzten offenen Punkt abhaken → Seite bleibt.
- [x] R9 (Teil) – `ItemMarkRow`-Kontextmenü: Markier-Einträge und „Leeren“ nur, wenn `options` nicht leer; bei automatischen Punkten „Wert eintragen…“ (Arbeit → `.work(WorkDraft(day:categoryKey:))`, sonst `.measure(code:day:)`).
- [x] R13 (Teil) – lokales Kategorie-Raster-Fenster (`CategoryPicker`) und `ConditionalsSheet`: `.toastHost(app)`.
- [x] R15 (Teil) – `.sheetFrame` → `.thaliaSheetFrame(width:height:)` (ConditionalsSheet 460 × 520).
- [x] R17 (Teil) – `ExpenseInputRow`/`ExpenseEntryRow`: Beträge über `Format.euro`.
- [x] R21 – `InlineWorkRow`: leeres Feld beim Verlassen → alter Text zurück (`task = block.task`), sonst `store.setTask`; `.onChange(of: block.task)` übernimmt fremde Änderungen, solange das Feld nicht fokussiert ist.
- [x] R22 (Teil) – Menü „Fokus (Power-Hours)“ → `.focus(day)`.
- [x] R25 – `ConditionalsSheet`: Ausschalten ändert erst bei „Fertig“ etwas (lokales `turnedOff: Set<String>`; „Fertig“: deren Markierung leeren, Rest wie bisher); linker Knopf „Später“ (schließt ohne Änderung). Abnahme: Situation ausschalten, „Später“ → Markierung unverändert; ausschalten, „Fertig“ → Markierung geleert.
- [x] R29 (Teil) – `MeasureInput.date(minutes:day:)` → `day.date(minutes:)`, `minutes(of:)` → `DayKey.minutes(of:)`; Startuhrzeit `record.defaultClockMinutes`.
- [x] R31 (Teil) – `MeasureInput` Zahlenfeld: `.keypadButton("Fertig", isActive: focused) { commit(set); focused = false }`; `ExpenseInputRow`: Betrag „Weiter“ (→ Fokus „Wofür“), Wofür „Fertig“ (→ hinzufügen). „+ Schritt“ während des Tippens: erst `commit`, dann vom eingetippten Wert aus addieren. Abnahme: „4,5“ tippen, „+ 0,5“ → 5.
- [x] R32 (Teil) – `ExpenseInputRow` und `NewWorkRow`: Vorschläge einmal laden (`store.expenseSuggestions(code:through:)` bzw. `workSuggestions(categoryKey:)`, beim Erscheinen und bei Fokus-Beginn in `@State`), Anzeige über `SuggestionChips`; Ausgaben: gültiger Betrag + Tipp auf Vorschlag sichert sofort. Keine Store-Abfrage pro Tastendruck. Abnahme: ein Montag ohne Einträge der Woche zeigt Vorschläge aus den Vorwochen; „4,50“ + Tipp auf einen Vorschlag sichert sofort; Zeile und Ausgaben-Fenster zeigen dieselbe Reihenfolge; im `body` von `NewWorkRow`/`ExpenseInputRow` steht kein `store.`-Aufruf.
- [x] R35 – Mac und iPad mit Tastatur: `CategoryPage`-Liste mit Auswahl (`selectedItemCode`), `.onKeyPress(characters: CharacterSet(charactersIn: "1234"))` → Markierung (1 Erledigt/Gearbeitet, 2 Teilweise, 3 Nicht erledigt, 4 Entfällt/Nicht heute; nur wenn in `options`), danach Auswahl zum nächsten offenen Punkt; ↑/↓ über die Listen-Auswahl; `.help("Erledigt (1)")` usw. auf den Knöpfen (nur Mac/iPad). `TodayContent` setzt `app.todayPageOrder`. Knöpfe mit Wörtern bleiben. Abnahme: Mac – Punkt auswählen, „1“ setzt Erledigt und die Auswahl springt zum nächsten offenen Punkt; ↑/↓ wählt; ⌥⌘↓ wechselt die Kategorie; Tooltip „Erledigt (1)“.
- [x] R36 – `MarkBar`/`MarkOptionButton`: Zeile beantwortet → nicht gewählte Knöpfe `foregroundStyle(.secondary)` auf `Color.secondary.opacity(0.08)`, gewählter wie bisher; offene Zeilen bunt; alles bleibt antippbar (wirkt auch im Abschluss und bei bedingten Punkten). Abnahme: nach „Erledigt“ sind die übrigen Knöpfe der Zeile grau, offene Zeilen bleiben bunt; ein grauer Knopf lässt sich weiterhin antippen (Heute, Abschluss, bedingte Punkte).
- [x] R37 – Arbeits-Kategorien: `WeeklyGoalRow` für Arbeits-Messwerte nur lesend (Balken, „6 von 8 PH“, „heute +2 PH“), ohne `MeasureInput` und ohne Erklärzeile; das %-Etikett ist ein Knopf mit Popover (bisheriger Erklärtext); der Abschnitt „Power-Hours heute“ (Einträge + `NewWorkRow`) folgt direkt nach „Wochenziele“, Fußtext entfällt; `MeasureInput` zeigt für Arbeit keinen zweiten „Erfassen“-Knopf mehr, wo die Zeile darunter steht. Abnahme: eine Arbeits-Kategorie zeigt die PH von heute nur einmal, keinen zweiten Erfassen-Knopf, die Zeile „Menge · Wofür · +“ direkt unter dem Wochenziel; die Erklärung erscheint nur per Tipp auf das %-Etikett.
- [x] R38 – iPhone: `TodayHeader` verschwindet aus dem Pager; `ToolbarItem(placement: .principal)` mit Menü: Zeile 1 „Heute“/Wochentag, Zeile 2 „16. Nov. · KW47 · Arbeitstag“ (Menü: Tage der Woche, „Vorige Woche“, „Nächste Woche“, „Zu heute“, „Tagestyp und Besonderheit…“ → `.dayInfo(day)`); Ring mit % als `ToolbarItem(placement: .topBarTrailing)` (Tipp → `.dayOverview(day)`); unter den Chips eine Zeile für `DayNoteLabel` (R90) und `DayTypes.workFreeHint` (R78), nur wenn vorhanden. Kategorie-Kopf einzeilig: Schlüssel+Titel, „3 von 5“, Mini-Ring 28 pt, Höhe ≤ 56 pt, Details per ⓘ. Abnahme: iPhone-Standardgröße zeigt auf der ersten Kategorie ≥ 5 Punkte ohne Scrollen.
- [x] R43 (Teil) – `MarkOptionButton.word` = `option.label(progress: isProgress)` („Nicht erledigt“ mit `minimumScaleFactor`).
- [x] R46 (Teil) – Kategorieseite: `ExpenseEntryRow(entry:onEdit:)`-Tipp oder Kontextmenü „Bearbeiten“ füllt `ExpenseInputRow(measure:context:day:editing:)` (gemeinsamer `@State editing: MeasureEntry?` in `CategoryPage`, an die Zeile gebunden); Knopf zeigt dann „Sichern“ → `app.updateExpense`, kleiner Knopf „Abbrechen“. Inits genau wie im Vertrag – P6 benutzt beide im Messwert-Fenster.
- [x] R47 (Teil) – `WeeklyGoalRow` nutzt `context.pace(for:)` (Soll ohne freie Tage).
- [x] R50 (Teil) – `DayOverviewSheet` und `DayOverviewList` löschen; `TodaySplit`-Spalte zeigt `GlanceList(context:day:onOpen:)`.
- [x] R56 (Teil) – `NoPlanView`: „Wochenplan importieren“ → `.planWeek(week)`.
- [x] R59 (Teil) – `TodaySplit`: `.inspector(isPresented: $app.showsGlanceInspector)` statt `@AppStorage`; am Mac öffnet der Ring im Kopf die Spalte statt des Fensters.
- [x] R60 – Mac: `TodaySplit` mit `HSplitView`, Liste `frame(minWidth: 220, idealWidth: 270, maxWidth: 400)`; `CategoryListRow` `.help("\(key) \(title)")`; Datum/KW in den Fenstertitel (`navigationTitle(day.longLabel)` + `.toolbarTitleMenu` mit dem Tage-Menü), Kopf in der Liste kompakt (nur Ring + „73 % erfasst“); iPad unverändert 270 pt. Abnahme: Mac – die Spalte lässt sich zwischen 220 und 400 pt ziehen, lange Kategorienamen stehen im Tooltip; das Datum steht nur einmal (Fenstertitel).
- [x] R61 – `ItemMarkRow`: `ViewThatFits(in: .horizontal)` – breit (≥ 640 pt): Titel links, `MarkBar(compact: true)` rechts als feste Spalte (Breite 300); sonst wie bisher untereinander. `compact`: Höhe 34 statt 46, Symbol und Wort nebeneinander; am Mac etwas flacher. Abnahme: Mac bei 1180 pt Fensterbreite – die Knöpfe stehen rechts neben den Titeln, auf einer Kategorie sind mindestens 8 Punkte ohne Scrollen sichtbar (vorher 5); iPhone unverändert untereinander.
- [x] R62 (Teil) – `TodayToolbar` (Mac): „Tag abschließen“ mit Text (`.labelStyle(.titleAndIcon)`), Tooltip „Erfassen (⇧⌘N)“; Leiste anpassbar über `.toolbar(id: "today")`: `TodayToolbar` wird `CustomizableToolbarContent` (jedes Item `ToolbarItem(id:placement:)`, auch die iOS-Items, damit ein Typ für beide Plattformen reicht).
- [x] R63 (Teil) – `ItemMarkRow`-Kontextmenü: „Bearbeiten…“ → `.editItem(item)`; „Löschen…“ mit Dialog „Löschen – auch künftig weglassen“ / „Nur diese Woche löschen“.
- [x] R64 (Teil) – `ItemMarkRow` Kurzlabel `KindBadge(text: context.kindLabel(item))`, bisherige Langtexte entfallen.
- [x] R74 – Kategorie-Kopf: ist alles erfasst, statt „Alle …“ der Knopf „Weiter: 1.2“ bzw. „Zum Abschluss“ (blättert); „Alle leeren“ wandert ins Kontextmenü des Kopfs; unterer Knopf auf der letzten Kategorie „Weiter: Abschluss & Notizen“; Seite `.day` heißt „Abschluss & Notizen“ (Liste am Mac/iPad). Abnahme: Kategorie fertig → der Kopf zeigt „Weiter: 1.2“ (letzte Kategorie: „Zum Abschluss“), „Alle leeren“ nur im Haltemenü; die letzte Seite heißt „Abschluss & Notizen“.
- [x] R90 (Teil) – Besonderheit über `DayNoteLabel(note: context.dayNote(day))` unter dem Tagestyp (iPhone: unter den Chips; Mac/iPad: im Listenkopf).
- [x] R92 (Teil) – `NoPlanView`: liegt `store.planningSourceWeek(for: week)` vor → zweiter Knopf „Wie \(source.label) wiederholen“ → `.repeatPlan(from: source, to: week)`.
- [x] R94 (Teil) – `YesterdayBanner(today: app.today)` oben auf Heute (iPhone über den Chips, iPad/Mac oben in der Liste), nur wenn `day == app.today`.
- [x] H1 (Teil) – `MeasureRow`: `context.isHealthElsewhere(measure)` und kein Wert → Untertitel `WeekContext.healthElsewhereHint`, kein Eingabefeld.

### P4 – Heute im Blick, Fokus, Ausgaben
**Dateien:** `App/Sources/Glance.swift` (darf geteilt werden: `Focus.swift`, `Expenses.swift`).

- [x] R5 (Teil) – `OpenToDoSection` nutzt das neue `openToDo` (nur Pflicht); neuer Abschnitt „Diese Woche noch · n“ aus `openWeeklyToDo` mit „2 von 3 diese Woche“; Mac-Seitenleiste „73 % erfasst · 11 offen“ aus `openCount`.
- [x] R13 (Teil) – lokale Fenster in Fokus/Ausgaben (`WorkEditor`) mit `.environment(app)` und `.toastHost(app)`.
- [x] R14 (Teil) – `ExpensesContent`: `.unsavedInput(!amount.isEmpty || !what.isEmpty, in: app)`.
- [x] R15 (Teil) – alle `.sheetFrame` → `.thaliaSheetFrame` (Fokus 560 × 680, Ausgaben 520 × 640, Glance 460 × 640, Wochenziele 480 × 560).
- [x] R16 (Teil) – Kachel „Wochenziele“ (statt „Ziele“): Wert „\(weeklyTargetsMet)/\(weeklyTargets.count)“, Detail „erreicht“; öffnet `WeeklyGoalsSheet`/Push (R51) mit `WeeklyTargetsList(context:)`; Mac-Seitenleiste: „Wertung 7,1 · 6/10 Ziele bewertet“.
- [x] R17 (Teil) – alle €-Texte (Kacheln, `GlanceText.euro`, `expensesLine`, Listen) über `Format.euro`.
- [x] R22 – `FocusSheet(day:)`: Fakt „Heute“ heißt bei anderem Tag „So, 15. Nov.“ (`day.relativeLabel(today:)`), „+“ bucht auf `day` und öffnet den PH-Editor als lokales Fenster über Fokus (R51), der Editor zeigt den Tag (P6). Abnahme: Heute auf Sonntag zurückgeblättert, Fokus öffnen → Fakt heißt „So, 15. Nov.“, „+“ bucht auf Sonntag, das PH-Fenster zeigt „Power-Hours · So, 15. Nov.“.
- [x] R31 (Teil) – `ExpensesContent`: Betrag `.keypadButton("Weiter", …)` → Fokus „Wofür“, Wofür `.submitLabel(.done)` → hinzufügen.
- [x] R32 (Teil) – `ExpensesContent`: Vorschläge wie die Zeile (`store.expenseSuggestions`, `SuggestionChips`), gleiche Reihenfolge; gültiger Betrag + Tipp sichert sofort.
- [x] R41 (Teil) – `ExpensesContent`: `CaptureDayRow(day: $day, today: app.today)` oben im Abschnitt „Neue Ausgabe“; `day` startet mit dem Fenster-Tag.
- [x] R45 – Ziel-Kachel „Tagesziel < 50 €“ bzw. „Wochenziel …“, Wert „noch 38 €“ (grün) oder „+12 €“ (rot) gegen Tages- bzw. Wochensumme; Diagramm: `chartYAxis` mit Achse, gestrichelte `RuleMark` beim Tagesziel, bei nur Nullen Overlay „Noch keine Ausgaben“. Abnahme: 12 € bei Tagesziel < 50 € → „Tagesziel < 50 € · noch 38 €“ grün; 62 € → „+12 €“ rot; eine Woche ohne Ausgaben zeigt Achse, Ziellinie und „Noch keine Ausgaben“.
- [x] R46 (Teil) – Ausgaben-Fenster: Tipp auf Eintrag oder Kontextmenü „Bearbeiten“ füllt Betrag/Wofür/Tag; Knopf „Sichern“ → `app.updateExpense`; „Abbrechen“ leert.
- [x] R47 – Fokus `AreaRow`: `GoalBar(fraction:expected:reached:tint:)` mit Soll aus `context.pace(for:)`, Status `pace.label(unit: "PH")` (orange bei „hinter dem Plan“); Tipp → lokaler PH-Editor mit vorgewähltem Bereich; Kopf-Fakten „Heute“, „Soll bis heute“ (Summe der `expected` der Bereiche), „Ø pro Arbeitstag“.
- [x] R50 – `GlanceSheet(day:)` + `GlanceList`: Kopf „Montag · Arbeitstag“, darunter „16. Nov. · KW47 · 73 % erfasst“ (abgeschlossen: Wertung), `DayNoteLabel` und bei arbeitsfreiem Tag `DayTypes.workFreeHint` (Hinweis R38/R50: Platz für Besonderheit und „arbeitsfrei“ bleibt); `YesterdayBanner`; Kacheln Fokus · Ausgaben · Wochenziele; „Noch zu tun“; „Diese Woche noch“; „Wochenziele“ (`WeeklyTargetsList(context:limit: 4)` + „Alle Wochenziele“); Kategorien; Messwerte; Notizen; ist alles erfasst und der Tag offen: Hauptknopf „Tag abschließen“ (→ `.closeDay(day)`). Kein HeroCard, kein PH-Abschnitt. Abnahme: Heute im Blick zeigt das Datum einmal, keinen PH-Abschnitt, „Noch zu tun“ in der oberen Hälfte; sind alle Pflichtpunkte erfasst, steht „Tag abschließen“ da.
- [x] R51 – `GlanceSheet` mit `NavigationStack(path:)` und `enum GlanceRoute: Hashable { case focus, expenses, weeklyGoals }`; Kacheln pushen Fokus/Ausgaben/Wochenziele (Zurück-Pfeil); PH-Editor aus Fokus als lokales Fenster, danach wieder Fokus. Abnahme: Kachel Fokus → Fokus mit Zurück-Pfeil im selben Fenster; „+“ in Fokus → PH-Fenster, nach „Sichern“ wieder Fokus; Zurück → Heute im Blick; nichts schließt das Fenster ungefragt.
- [x] R52 – Fokus-Legende mit Bereichsnamen („3.2 <Kurztitel>“) statt Schlüsseln; Eintragsplaketten in derselben Bereichsfarbe wie das Diagramm (`areaColor`); Nettozeit über `WorkTotals.netText`; doppelter Fußtext entfällt.
- [x] R53 – Fokus-Einträge als Abschnitte je Tag („Mo, 16. Nov. · 3,5 PH“, neuester Tag oben); Zeile: Wofür (leer: orange „Beschreibung fehlt“), zweite Zeile Ergebnis (wenn vorhanden) sonst Bereich; im Bereich die drei größten Themen („Thema A 4 · Thema B 2“). Abnahme: Fokus-Einträge stehen unter Tagesüberschriften mit Summe, das Ergebnis ist auf dem iPhone als zweite Zeile sichtbar, eine fehlende Beschreibung steht orange da.
- [x] R54 – Ausgaben: Abschnitt „Woche“ nach Tagen („Mo, 16. Nov. · 23,40 €“), Abschnitt „Nach Zweck“ (`expensesByPurpose`, fünf größte); Tipp auf einen Balken (`chartXSelection`) wählt den Tag zum Nachtragen. Abnahme: Ausgaben zeigt alle Tage der Woche mit Summe und „Nach Zweck“ (höchstens fünf); Tipp auf den Dienstag-Balken stellt die Eingabe auf Dienstag.
- [x] R59 (Teil) – Mac-Seitenleiste: „HEUTE“-Zeile öffnet die rechte Spalte (`app.showsGlanceInspector = true`, `sidebar = .today`); alle grauen Zeilen mit `.onHover`-Hintergrund und `.help(…)` („Heute im Blick einblenden“, „Fokus öffnen“, „Ausgaben öffnen“, „Woche öffnen“).
- [x] R88 – Fokus blättert: Titelzeile „‹ KW46 ›“ (lokaler `@State week`, Start `day.week`); in fremden Wochen ist „Heute“ „–“; Abschnitt „Letzte 8 Wochen“: Balken PH je Woche (`store.workHistory(through: week)`), Ziellinie, Satz „Ziel erreicht in 3 von 8 Wochen“; Tipp auf einen Balken springt zu dieser Woche. Abnahme: Fokus blättert mit ‹ › durch die Wochen; das Diagramm zeigt 8 Balken mit Ziellinie und „Ziel erreicht in x von 8 Wochen“; Tipp auf einen Balken zeigt diese Woche.
- [x] R89 (Teil) – Fokus-Fußtext: „Tipp: „Hey Siri, Power-Hour in Thalia erfassen“ – Siri fragt nach Bereich, Menge und Wofür.“
- [x] R90 (Teil) – Besonderheit im Glance-Kopf und als graue Zeile in der Mac-Seitenleiste.
- [x] R94 – `YesterdayBanner`: liest `WeekReader(week: yesterday.week, today: today)`; sichtbar, wenn `hasPlan`, gestern nicht abgeschlossen und nicht ausgeblendet (`@AppStorage("yesterday.dismissed")` ≠ gestern); Text „So, 15. Nov. · 3 offen“ (0 offen: „So, 15. Nov. · nicht abgeschlossen“), Knöpfe „Nachtragen“ (`selectedDay = gestern`, `tab/sidebar = .today`) und „Abschließen“ (`.closeDay(gestern)`), × blendet aus. Stil `.sidebar`: zwei graue Zeilen mit Links. Platzierung: Glance-Kopf und Mac-Seitenleiste (P4), Heute (P3). Abnahme: ist gestern offen, zeigen Heute, Heute im Blick und die Mac-Seitenleiste „So, 15. Nov. · 3 offen“ mit „Nachtragen“ und „Abschließen“; nach dem Abschluss oder × verschwindet es für diesen Tag.
- [x] R16/R50 zusammen – `WeeklyGoalsSheet(week:)`: `WeekReader` + `List { WeeklyTargetsList(context:) }`, Titel „Wochenziele · KW47“.
- [x] H1 (Teil) – „Messwerte“ in `GlanceList`: Health-Messwert ohne Wert auf Mac → Zeile mit `healthElsewhereHint`, zählt nicht als fehlend.

### P5 – Woche
**Dateien:** `App/Sources/WeekView.swift`, `App/Sources/WeekTable.swift`, `App/Sources/Components.swift`.

- [x] R8 – iPhone-Tagesstreifen und Mac-Tageskopf zeigen `context.dayStatusText(day)`, abgeschlossene Tage mit Siegel (`checkmark.seal.fill`), VoiceOver `dayStatusAccessibility`. Abnahme: kein „Mo 7,5“ vor dem Abschluss, kein % für kommende Tage.
- [x] R9 – `MarkCell` nach Vertrag; `WeekItemRow`/`WeekTableRow`: `options: context.options(item, on: day)`, bei `context.isDerived(item)` `onOpenValue` (Arbeit → `.work(WorkDraft(day:categoryKey:))`, Ausgaben → `.expenses(day)`, sonst `.measure(code: item.measureCode, day:)`). Abnahme: eine Wochenzelle an einem freien Tag bzw. bei einem automatischen Punkt ist gedämpft, ein Tipp ändert keine gespeicherte Markierung; beim automatischen PH-Punkt öffnet der Tipp das PH-Fenster mit Bereich.
- [x] R10 – `WeekTable`: eine Spaltendefinition (`WeekTableColumns`: Titel min 120 pt flexibel, Tag 38 pt, Woche 44 pt, gleiche Innenabstände) für Kopf, Kategorie- und Punktzeilen; Inhalt `frame(minWidth: 120 + 7 × 38 + 44 + Abstände)`, damit das Fenster nicht schmaler wird als die Tabelle. Abnahme: kleinstes Fenster – „Di“ steht über Dienstag, „Woche“ ganz sichtbar.
- [x] R13 (Teil) – `WeekSummaryPanel`-Teilen-Fenster: `.toastHost(app)`.
- [x] R16 (Teil) – `WeeklyTargetRow`, `WeeklyTargetsList` in Components (ersetzen `PaceRow`, `targetsSection`, `WeekTargetsSection`); Woche (iPhone), Mac-Panel und P4 nutzen sie.
- [x] R32 (Teil) – `SuggestionChips` (horizontale Chips aus `ChipButton`, gefiltert mit `localizedCaseInsensitiveContains(typed)`, ohne den gewählten, höchstens `limit`).
- [x] R33 (Teil) – `WrapLayout: Layout` (umbrechende Zeilen).
- [x] R41 (Teil) – `CaptureDayRow`: Chips „Heute“ · „Gestern“ · kompakter `DatePicker` (nur Datum), bei `day != today` darunter orange „Zählt für So, 15. Nov. – nicht für heute“; `captureTitle(_:day:today:)`.
- [x] R42 – Tipp auf einen Wochentag öffnet ihn in Heute (`selectedDay`, `tab/sidebar = .today`) – iPhone-Streifen und Mac-Kopf; vergangene offene Tage mit Plan zeigen orange „5 offen“ (`openCount`); Kontextmenü „Tag abschließen…“ (`.closeDay(day)`) und „Tagestyp und Besonderheit…“ (`.dayInfo(day)`). Abnahme: Tipp auf „Mi“ öffnet Heute auf Mittwoch (iPhone und Mac); ein vergangener offener Tag zeigt orange „5 offen“; langes Drücken bietet „Tag abschließen…“ und „Tagestyp und Besonderheit…“.
- [x] R47 (Teil) – `WeeklyTargetRow` nutzt `target.pace` (Soll-Strich, „im Plan / hinter dem Plan / erreicht“, Limit grün solange darunter).
- [x] R55 – iPhone-Woche: Titel „KW47“ mit Menü der letzten 8 Wochen und „Zur aktuellen Woche“ (`ToolbarItem(placement: .principal)`), Pfeile ‹ › als Toolbar-Knöpfe, „Woche abschließen“ in der Leiste; Wochenkontext einzeilig (Tipp klappt auf); Wochenziele einklappbar (`@AppStorage("week.goals.expanded")`); HeroCard kompakt (`HeroCard(…, compact: true)`: Ring 68 statt 96 pt, Innenabstand 12, höchstens zwei Fakten); Knopf „Planen“ entfällt (steht im …-Menü als „KW48 planen“). Abnahme: iPhone-Woche zeigt „KW47“ mit Pfeilen in der Titelzeile, die erste Zelle ist ohne Scrollen sichtbar; „Planen“ steht nur im …-Menü; die Wochenziele lassen sich einklappen und bleiben so.
- [x] R56 (Teil) – „Nächste Woche planen“ (Mac-Panel) und …-Menü (iPhone) heißen „\(next.label) planen“ → `.planWeek(context.week.adding(weeks: 1))`.
- [x] R62 (Teil) – `WeekTable`-Leiste: Knöpfe mit Text (`.labelStyle(.titleAndIcon)`), Tooltips mit Kürzeln. *„Diese Woche“ ⌘T, „Wochenübersicht“ ⌥⌘0 (Kürzel am Knopf), Pfeile ⇧⌘[ / ⇧⌘] aus „Gehe zu“.*
- [x] R63 – Kontextmenü der Punkte (iPhone, Mac): „Bearbeiten…“ → `.editItem(item)`, „Details…“ → `.item(item, detailDay)`, „Als Nebensache“/„Doch wichtig“ (`store.setSecondary`), „Löschen…“ mit Dialog „Löschen – auch künftig weglassen“ / „Nur diese Woche löschen“; Zellen mit `.help("Mi, 18. Nov. · Erledigt")` und Hover-Rahmen (Mac). Abnahme: „Bearbeiten…“ öffnet sofort den Punkt-Editor (iPhone, Mac, Heute); „Löschen…“ fragt „auch künftig / nur diese Woche“; „Als Nebensache“ schaltet um; Mac-Zellen haben Tooltip und Hover-Rahmen.
- [x] R64 – Kurzlabels `KindBadge(text: context.kindLabel(item))` in Woche und Tabelle; iPhone zusätzlich Fortschritt „62 %“ bei Fortschrittspunkten. Abnahme: in Woche, Mac-Tabelle, Heute und PDF steht für denselben Punkt dasselbe Kurzlabel; das iPhone zeigt bei Fortschrittspunkten „62 %“.
- [x] R65 – `MarkCell(hasNote: !context.markNote(item, on: day).isEmpty)` (4-pt-Punkt oben rechts); Kontextmenü „Notiz hinzufügen…“ → `.item(item, day)`; Titel-Tipp und „Details…“ öffnen denselben Tag (`detailDay` = gewählter Tag in der Woche, sonst heute, sonst Montag). Abnahme: eine Notiz an Mittwoch zeigt in der Mittwochs-Zelle einen Punkt; „Notiz hinzufügen…“ im Kontextmenü der Donnerstags-Zelle öffnet Donnerstag. *Text nach Entscheidung 20 (R75, Notiz = „erfassen“): „Notiz erfassen…“, bei vorhandener Notiz „Notiz bearbeiten…“.*
- [x] R68 (Teil) – `ScoreRing(tint:)`, `GoalBars(keys:)` (Balken in `GoalPalette.color(goal:)`); Mac-Panel: nur noch **eine** farbige Zielliste (GoalBars + „Jahresziele“-Liste zusammen: farbige Zeilen mit Wert).
- [x] R85 – je Kategorie (iPhone-Abschnitt und Mac-Tabelle) eingeklappte Zeilengruppe „Werte“: je Tages-Messwert mit Zahl/Uhrzeit eine Zeile Mo–So (`Format.measure`, grün erfüllt, rot verfehlt, „·“ leer); Tipp auf einen Tag → `.measure(code:day:)` (Arbeit → PH-Editor, Ausgaben → `.expenses(day)`). Abnahme: in der Woche zeigt „Werte“ unter einer Kategorie z. B. Bettzeit Mo–So in Grün/Rot/„·“; Tipp auf Mittwoch öffnet den Wert für Mittwoch.
- [x] R90 (Teil) – `DayNoteLabel` in Components; Tage mit Besonderheit bekommen im Streifen/Kopf einen kleinen Punkt mit Tooltip.

### P6 – Erfassen und Bearbeiten
**Dateien:** `App/Sources/Editors.swift`.

- [x] R3 – `MeasureForm`: Arbeits-Messwert → Liste der PH-Einträge des Tages mit Wofür + Knopf „Power-Hours erfassen“ (`.work(WorkDraft(day:categoryKey:))` als lokales Fenster); Ausgaben → dieselbe Zeile wie auf der Kategorieseite: `ExpenseInputRow(measure:context:day:editing:)` mit eigenem `@State editing` und darunter die Ausgaben des Tages als `ExpenseEntryRow(entry:onEdit:)` (beide aus P3, Vertrag) – damit gilt K2 („Wofür“ Pflicht) und R46 (bearbeiten) auch hier; Schnellknöpfe „+1/+2/+5 Schritt“ nur bei Summen-Messwerten; Startuhrzeit `record.defaultClockMinutes` über `day.date(minutes:)`; leere Texte/Notizen werden nicht gespeichert. Abnahme: Gewicht hat keine „+0,1“-Knöpfe mehr, PH/Ausgaben lassen sich hier nicht ohne Wofür eintragen.
- [x] R9 (Teil) – `ItemDetailForm` Wochenzeile: `MarkCell(…, options: context.options(item, on: d), onOpenValue: …)` nach denselben Regeln wie die Woche.
- [x] R13 (Teil) – `ItemDetailForm`: nach „Löschen – auch künftig weglassen“/„Nur diese Woche löschen“ schließt das Fenster (`@Environment(\.dismiss)`); `WorkEditor.save()` für neue Einträge über `app.addPowerHours(…result:nextStep:)` (Toast mit Widerrufen); lokales `ItemEditor`-Fenster mit `.toastHost(app)`.
- [x] R14 (Teil) – `.unsavedInput(…)` in `WorkEditor` (Wofür/Ergebnis/nächster Schritt geändert), `NoteEditor`, `ItemEditor`, `MeasureDefinitionEditor`, `DayInfoEditor`, `WeekInfoEditor`.
- [x] R15 (Teil) – alle `.sheetFrame` → `.thaliaSheetFrame` (gleiche Breite, Höhe = bisherige minHeight + 120).
- [x] R22 (Teil) – `ThaliaCreateSheet`: „Fokus ansehen“ → `.focus(day)`.
- [x] R23 (Teil) – `ItemDetailForm`: Notiz über `store.setMarkNote(note, item:, day:)` (ohne `current:`). Abnahme: Notiz an freiem Tag speichert kein „Entfällt“.
- [x] R29 (Teil) – `MeasureForm` Uhrzeit: Start `day.date(minutes: record.defaultClockMinutes)`, Speichern `DayKey.minutes(of:)`.
- [x] R31 (Teil) – `MeasureForm` Zahlenfeld `.keypadButton("Fertig", isActive: …)` → `addEntry()`.
- [x] R32 (Teil) – `WorkEditor`: Vorschläge einmal je Bereichswechsel laden, `SuggestionChips`.
- [x] R33 – `WorkEditor` (neue Einträge): Abschnitt „Zuletzt“ mit bis zu drei `recentWorkCombos` als Knöpfe „3.3 · Thema A · 2 PH“ (Tipp füllt Bereich, Wofür, Menge); Geschäftsbereiche (Ziel 3 außer 3.1) als umbrechende Chips (`WrapLayout`), übrige im Menü „Anderer Bereich“; `TextField(…).onSubmit(save)` und Toolbar „Sichern“; Bereich ohne Vorauswahl (K1). Abnahme: + → Power-Hours zeigt oben bis zu drei „Zuletzt“-Knöpfe; ein Tipp füllt Bereich, Wofür, Menge; Return sichert; alle Geschäftsbereiche sind ohne Abschneiden sichtbar; ohne Tipp ist kein Bereich vorgewählt.
- [x] R41 – `WorkEditor` und `NoteEditor`: `@State day` aus dem Entwurf, `CaptureDayRow(day: $day, today: app.today)` als erste Zeile, Titel `captureTitle("Power-Hours", day:today:)` bzw. „Notiz“; Sichern bucht auf `day` (Bearbeiten verschiebt: `store.update(block, …, day: day)`, `store.update(note, kind:text:day:)`); `ThaliaCreateSheet` Titel `captureTitle("Erfassen", day: app.captureDay, today: app.today)` und alle Optionen mit `app.captureDay`; `MeasureSheet` Titel `captureTitle(measure.title, day: day, today: app.today)` mit demselben orangen Hinweis, wenn `day != app.today` (Hinweis „jedes Erfassen-Fenster zeigt seinen Zieltag“). Abnahme: + → Power-Hours bei gewähltem Sonntag zeigt „Tag: Gestern“ und den orangen Hinweis, Titel „Power-Hours · So, 15. Nov.“; ein bestehender Eintrag lässt sich auf heute verschieben; Notiz-Fenster genauso.
- [x] R43 (Teil) – `ItemDetailForm`: Markier-Knöpfe = `MarkBar(mark:options:suggestion:isProgress:onSet:)` wie in Heute (statt Symbol + „N/A“); Fußtext „Erledigt · Teilweise · Nicht erledigt · Entfällt · leer = nicht erfasst“.
- [x] R77 – `MeasureDefinitionEditor`: statt Freitext Picker „Ziel“ („kein Ziel“ + `Target.Comparison.choices` mit `choiceLabel`), Wertfeld (Zahl) bzw. `DatePicker` bei „Uhrzeit“, bei „zwischen“ zweites Feld; darunter live `target.sentence(period:unit:)`; Einheiten `Units.choices`; beim Bearbeiten `targetRaw` in die Felder zerlegt.
- [x] R78 – `NoteEditor`: Art als Chips (`WrapLayout` + `ChipButton` mit Symbol); `DayInfoEditor`: Tagestypen als Chips + „Eigener …“ (Textfeld nur dann), Fußtext `DayTypes.workFreeHint`, wenn `DayTypes.isWorkFree(type)`; `ThaliaCreateSheet` Notiz-Untertitel `NoteKind.listText`.
- [x] R31/R75 (Teil) – `ThaliaCreateSheet`: Fußnote nur am Mac/iPad: „⌘N Power-Hours · ⇧⌘N Erfassen · ⌥⌘N Notiz · ⇧⌘E Messwert eintragen · ⌘↩ Tag abschließen · ⇧⌘↩ Woche abschließen · ⇧⌘I Wochenplan importieren“.

### P7 – Abschluss, Rückblick, Ziele, PDF
**Dateien:** `App/Sources/CloseDayView.swift`, `CloseWeekView.swift`, `ReviewView.swift`, `GoalsView.swift`, `PDFExport.swift`, `Sharing.swift`.

- [x] R11 (Teil) – `GoalsContent.history(for:)` über `store.goalScoreHistory(goalKey:through:)` (keine Duplikate).
- [x] R12 – Abschnitt 2: Knopf „\(Format.count(n, "Vorschlag", "Vorschläge")) aus Messwerten übernehmen“ nur für `context.suggestionsToFill(on: day)` → `app.applySuggestions(_:day:)` (die lokale Tupel-Liste `suggestions` entfällt); `suggestionsDiffering` eingeklappt „Messwert weicht ab (n)“, je Zeile „<Punkt>: <gesetzte Markierung> → <Vorschlag>“ (Wörter aus `Mark.label`, z. B. „Teilweise → Erledigt“) + Knopf „Übernehmen“ (`app.setMark(s.mark, item: s.item, day:)`). Abnahme: ein bewusst gesetztes ½ bleibt nach dem Knopf ½.
- [x] R13 (Teil) – alle lokalen Fenster (`ShareSheet`, `MeasureSheet`, `ItemDetailView`, `OverrideSheet`, `PDFPreviewSheet` aus `PDFButton`, Ziel-Bearbeiten) mit `.environment(app)` und `.toastHost(app)`.
- [x] R14 (Teil) – `CloseDayForm`/`CloseWeekForm`: `.unsavedInput(answers != loadedAnswers, in: app)`; Ziel-Bearbeiten-Fenster ebenso.
- [x] R15 (Teil) – alle `.sheetFrame` → `.thaliaSheetFrame` (Tag 620 × 720, Woche 640 × 760, Bericht 620 × 640, PDF 640 × 760, Override 440 × 320, Teilen 480 × 720, Ziel 460 × 320).
- [x] R26 (+ R90 Teil) – PDF: Tabellen-Kopf beim Tag „Mo, 16. Nov.“ statt „Heute“ (Spalte 90 pt); neue Seite „Rückblick“ (Woche) mit allen Antworten von `ReflectionQuestion.week` (ohne Kürzen auf 4/3 Zeilen) und den Tagesnotizen (`dayNoteField` je Tag); Deckblatt Tag: „Notiz zum Tag“ und „Besonderheit“ (`context.dayNote(day)`). Abnahme: das PDF eines vergangenen Tags zeigt „Mo, 16. Nov.“ statt „Heute“; das Wochen-PDF hat eine Seite „Rückblick“ mit allen sechs Antworten ungekürzt und den Tagesnotizen; das Tages-Deckblatt zeigt Notiz zum Tag und Besonderheit.
- [x] R31 (Teil) – Abschluss: „Fehlt noch“ nutzt weiter `MeasureInput` (P3) und bekommt die Fertig-Taste dadurch (keine eigene Zahl-Eingabe bauen; das Override-Fenster hat einen Stepper und braucht keine). Abnahme: im Tagesabschluss am iPhone steht über dem Ziffernblock „Fertig“, der Wert landet sofort in „Belege“.
- [x] R39 – `CloseDayForm` in `ScrollViewReader`; Knopf „Abschließen“ oben rechts (`.confirmationAction`); nach dem Abschließen `proxy.scrollTo("hero", anchor: .top)`, oben und unten nur noch „Fertig“ (unten Hauptknopf); `.onChange(of: app.closeRequest)` schließt ab (zweites ⌘↩ am Mac); `CloseWeekForm` genauso („Abschließen“ oben rechts, ⇧⌘↩); Sharing `HeroCard`: Sparkles `.symbolEffect(.bounce, value: celebrate)`.
- [x] R40 – nach dem Abschließen eines Sonntags (Woche offen): Knopf „Weiter: Woche KW47 abschließen“ → `app.sheet = .closeWeek(day.week)`. Abnahme: Sonntag abschließen → Knopf „Weiter: Woche KW47 abschließen“ öffnet den Wochenabschluss; an anderen Tagen oder bei abgeschlossener Woche erscheint er nicht.
- [x] R56 (Teil) – `CloseWeekForm`: eigene `planningPrompt()` löschen, `store.planningPrompt(for: next, today:)`; nach dem Abschluss Schritte „1 · Prompt kopieren“ und „2 · CSV einfügen“ (→ `.planWeek(next)`); vor dem Abschluss Prompt-Knopf mit Hinweis „Erst abschließen – dann kennt der Prompt verfehlte Ziele.“
- [x] R57 – `ReportView`: gestaltete Wochenübersicht (HeroCard, farbige Zielliste, „Was wirklich passiert ist“ und Reflexion nur lesend – gemeinsame Ansicht `WeekSummarySections(context:)` in CloseWeekView.swift, auch vom Abschluss benutzt); Markdown in `DisclosureGroup("Text für ChatGPT")`; Leiste nur „Text kopieren“ und Menü „Teilen“ (Text teilen · Woche als PDF · Als Bild teilen). Abnahme: der Bericht zeigt keine „#“, „**“ oder Tabellenstriche mehr; der Markdown-Text ist eingeklappt und über „Text kopieren“ vollständig kopierbar.
- [x] R58 – Abschnitt 4: gibt es `context.journalItem`, steht dort dessen `MarkBar` statt des Schalters; PDF-Kachel „Journal“ aus `context.journalDone(on:)`.
- [x] R61 (Teil) – `quickRow`: `ViewThatFits` wie Heute (`MarkBar(compact: true)` rechts ab 640 pt).
- [x] R64 (Teil) – PDF-Punktzeilen nutzen `context.kindLabel(item)`.
- [x] R47/R16 (Teil) – PDF „Wochenziele“ aus `context.weeklyTargets` (gleiche Zählung und Pace wie App).
- [x] R68 – `GoalCard`: statt „–“ „1 von 4 Kategorien bewertet“ (aus `score.goalWeek[key].categoriesScored/Total`) mit dünnem Bogen; `ScoreRing(tint: goal.color)`, Sparkline und Balken in Zielfarbe; `CloseWeekForm`/Gewichtung `GoalBars(scores:height:keys:)`. Abnahme: eine Ziel-Karte mit 1 von 4 bewerteten Kategorien zeigt „1 von 4 Kategorien bewertet“ statt „–“; Ringe, Sparklines und Balken tragen die Zielfarbe; das Mac-Wochenpanel hat nur noch eine Zielliste.
- [x] R69 – `GoalDetailContent`: Kopfzeile „M D M D F S S“ (`Weekday.letter`) über den Symbolen, heutige Spalte hervorgehoben, VoiceOver je Zelle „Mittwoch: Erledigt“. Abnahme: das Ziel-Detail zeigt „M D M D F S S“ über den Symbolen, heute hervorgehoben; VoiceOver nennt den Wochentag.
- [x] R70 – Rückblick: Wochen vor der laufenden mit Plan, nicht abgeschlossen, ohne Papier-Wertung → Zeile mit orangem Etikett „nicht abgeschlossen“, Wischen/Kontextmenü „Woche abschließen“ (`.closeWeek(week)`); im Diagramm orange Balken (laufende Wertung). Abnahme: eine vergangene Woche mit Plan ohne Abschluss erscheint im Rückblick orange mit „nicht abgeschlossen“; Wischen/Kontextmenü „Woche abschließen“ öffnet den Abschluss.
- [x] R71 – `PDFPreviewSheet` (Mac): „Sichern…“ (⌘S, `fileExporter` mit dem PDF) und „Drucken…“ (⌘P, `PDFDocument(url:)?.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true)?.run()`); `ShareSheet` (Mac): „Bild sichern…“. Abnahme: Mac – die PDF-Vorschau hat „Sichern…“ (⌘S, Sichern-Dialog) und „Drucken…“ (⌘P, Druckdialog); im Teilen-Fenster sichert „Bild sichern…“ ein PNG.
- [x] R72 – Konfetti und Erfolgs-Vibration nur im Moment des Abschließens: `@State justClosed` in Tag/Woche, `HeroCard(celebrate: justClosed && score >= 8)`; in Sharing `.sensoryFeedback(.success, trigger: celebrate)` statt `celebrate && shown`. Abnahme: einen abgeschlossenen guten Tag erneut öffnen → kein Konfetti, keine Vibration; beim Abschließen selbst beides genau einmal.
- [x] R80 (Teil) – Abschließen über `app.closeDay(day)`, Wieder-Öffnen über `app.reopenDay(day)`, Woche über `app.closeWeek(week)`.
- [x] R93 – `GoalDetailContent`: Abschnitt „Verlauf“ mit Segment „12 Wochen · Halbjahr · Zieljahr“: Wochenwertung des Ziels (`goalScoreHistory`), je Messwert der Ziel-Kategorien Linie (`measureSeries`) mit gestrichelter Ziellinie, Ausgaben als Monatsbalken; `GoalCard`: ist die laufende Woche „–“, steht „Ø 4 Wo. 7,2“. Abnahme: das Ziel-Detail zeigt „Verlauf“ mit drei Zeiträumen, Wochenwertung, je Messwert eine Linie mit gestrichelter Ziellinie und bei Ausgaben Monatsbalken; eine Ziel-Karte mit laufender Woche „–“ zeigt „Ø 4 Wo.“.
- [x] R95 – `GoalsContent` Jahreskarte: 0–3 Wochen vor der Prüfungswoche Knopf „Zielüberprüfung vorbereiten“ → `.goalReview`; `GoalReviewView`: je Ziel Ø seit Start + Trendpfeil, „Am häufigsten verpasst“, PH je Bereich, Messwerte „Anfang → jetzt“, „Geparkte Ideen“, Leiste „Bericht kopieren“ (`report.markdown(period:)`); Rückblick bekommt dauerhaft den Abschnitt „Geparkte Ideen“ (`store.parkedIdeas()`, mit Datum).
- [x] H1 (Teil) – Abschnitt 1 „Fehlt noch“ nur aus `countsAsMissing`; Health-Messwerte ohne Wert am Mac als graue Zeile mit `healthElsewhereHint`; PDF „Werte“ zeigt sie mit demselben Hinweis.

### P8 – Watch, Widgets, Kurzbefehle, Projekt
**Dateien:** `Watch/Sources/*`, `Widgets/Sources/*`, neu `WatchWidgets/Sources/ThaliaWatchWidgets.swift`, `App/Sources/Intents.swift`, `Shared/RouteIntents.swift`, neu `Shared/WidgetActions.swift`, neu `Shared/GoalPalette.swift`, `App/Sources/Style.swift` (nur `GoalPalette` entfernen), `project.yml`, `Config/Base.xcconfig`, `Config/ci.env`, `Config/Widgets/*`, neu `Config/WatchWidgets/Info.plist` + `ThaliaWatchWidgets.entitlements`, `docs/SETUP.md` (neue App-ID der Komplikation, siehe „Owner-Schritte“).

- [x] R1 (Teil) – Watch: `today` zusätzlich bei `.NSCalendarDayChanged` neu setzen.
- [x] R2 (Teil) – Watch: Ausgaben-Messwerte bekommen keine −/+ (Zeile zeigt Summe und „am iPhone erfassen“); „Wert leeren“ gibt es dort nicht; Zähler über `setDayValue` (ändert den Eintrag).
- [x] R3 (Teil) – `LogMeasureIntent`: `@Parameter(title: "Messwert") var measure: String` ohne Vorgabe (Siri fragt: „Welcher Messwert?“); lehnt Arbeit, Ausgaben und Uhrzeiten ab: „Power-Hours trägst du mit „Power-Hour erfassen“ ein – mit Bereich und Wofür.“ / „Ausgaben gehen mit „Ausgabe in Thalia“ – mit Betrag und Wofür.“ / „Uhrzeiten trägst du in der App ein.“; nach dem Eintragen `store.publishWidget()`. *Siri-Frage über `requestValueDialog: IntentDialog("Welcher Messwert?")`; PH-Text nach Entscheidung 20 (R75, PH = „erfassen“): „Power-Hours erfasst du mit „Power-Hour erfassen“ – mit Bereich und Wofür.“*
- [x] R4 – Widget-Timeline: Einträge „jetzt“ (`summary.resolved(for: heute)`) und „Mitternacht“ (`resolved(for: morgen)`), Policy `.after(Mitternacht + 1 min)`; `isNewDay` → Ansicht „Neuer Tag“ (Ring leer, „Neuer Tag – Thalia öffnen“); veralteter Stand wird nie als „Heute“ oder „Abgeschlossen“ gezeigt.
- [x] R5 (Teil) – Widgets: „offen“ = `openCount`; `hasPlan == false` → „Kein Plan“; Watch-Seite 1 nutzt `context.openCount`.
- [x] R17 (Teil) – Widgets: Beträge über `Format.euro`.
- [x] R34 – Watch-Seite 1: Ring/Status, „Power-Hours“, Abschnitt „Offen“ (Kategorien mit `openToDo`, „1.1 Ernährung · 2“; Tipp springt per `TabView(selection:)` zur Seite), Abschnitt „Zähler“ (Tages-Messwerte mit Summe, nicht Arbeit/Ausgaben/Health/Uhrzeit/Text, keine Nebensache) mit −/+; Kategorie-Seiten nur mit Offenem/Pflicht; Nebensachen als eigener Abschnitt „Nebensachen“. Abnahme: Watch-Seite 1 zeigt „Offen“ mit Kategorien und „Zähler“ mit −/+; ein Tipp auf eine Kategorie öffnet ihre Seite; ein Zähler lässt sich ohne Wischen erhöhen; leere Kategorie-Seiten gibt es nicht.
- [x] R43 (Teil) – Watch: Wahl-Knöpfe mit Wörtern (`Mark.label(progress:)`), VoiceOver sagt Wörter.
- [x] R48 – PH auf der Watch: Bereich → ein Bildschirm mit Menge (Krone, 0,25–8, Start 1 PH) und „Wofür“ (Vorschläge + Diktat), „Sichern“; danach `NavigationPath` leeren und Seite 1 zeigen, Banner „+1 PH · <Bereich>“ (2 s), Erfolgs-Vibration. Abnahme: nach „Sichern“ steht die Watch wieder auf Seite 1 mit „+1 PH · <Bereich>“ und vibriert; Menge und Wofür lagen auf einem Bildschirm.
- [x] R81 – Watch: Tipp auf einen Wert öffnet `WatchValueEditor` (Krone, Schritt `Units.crownStep`, Start = heutiger Wert ?? `store.lastValue(code:before:)` ?? 0, „Sichern“ → `setDayValue`); Health-Messwerte (`record.isHealth`) ohne −/+, mit `healthElsewhereHint` (H1). Abnahme: Watch – Tipp auf „Gewicht“ öffnet den Krone-Editor beim letzten Wert, Drehen ändert in 0,1-Schritten, „Sichern“ ändert den Tageswert im bestehenden Eintrag; Health-Messwerte haben keine −/+.
- [x] R82 – `WatchMarkPicker`: gewählte Markierung hervorgehoben (`.borderedProminent` vs `.bordered`); Vibration beim Setzen (`.success`) und anders beim Leeren (`.click`) über `WKInterfaceDevice.current().play(_:)`. Abnahme: die gesetzte Markierung ist auf der Watch hervorgehoben; Setzen und Leeren vibrieren spürbar unterschiedlich.
- [x] R83 – `FocusChip`: neben dem Balken „14/28 Woche“; `widgetGoalColor` entfällt, Widgets nutzen `GoalPalette` (neu `Shared/GoalPalette.swift`, in `project.yml` zu den Widget-Quellen; `Style.swift` ohne `GoalPalette`). Abnahme: mittleres/großes Widget zeigt „14/28 Woche“ neben dem PH-Balken; `grep -rn widgetGoalColor Widgets` findet nichts.
- [x] R84 (Teil) – Watch-App hält einen `WidgetPublisher` (für die Komplikation); Intents schreiben nach Änderungen `store.publishWidget()`.
- [x] R86 – neues Target `ThaliaWatchWidgets` (app-extension, watchOS) in `project.yml`: Quellen `WatchWidgets/Sources`, `Shared/WidgetBridge.swift`, `Shared/AppInfo.swift`, `Shared/GoalPalette.swift`; Abhängigkeiten ThaliaCore + BinisoftKitCore; `PRODUCT_BUNDLE_IDENTIFIER: $(WATCH_WIDGETS_BUNDLE_ID)`, Info.plist (NSExtensionPointIdentifier `com.apple.widgetkit-extension`, `SharedAppGroup`), Entitlements mit App Group; `ThaliaWatch` hängt davon ab (eingebettet). `Config/Base.xcconfig`: `WATCH_WIDGETS_BUNDLE_ID = $(WATCH_BUNDLE_ID).widgets`. `Config/ci.env`: `ENTITLEMENTS_IOS="Thalia.app|Config/iOS/Thalia.entitlements Thalia.app/Watch/ThaliaWatch.app|Config/watchOS/ThaliaWatch.entitlements Thalia.app/PlugIns/ThaliaWidgets.appex|Config/Widgets/ThaliaWidgets.entitlements Thalia.app/Watch/ThaliaWatch.app/PlugIns/ThaliaWatchWidgets.appex|Config/WatchWidgets/ThaliaWatchWidgets.entitlements"` (ersetzt die Standardliste von `check-entitlements.sh`, deshalb alle vier Paare). Widget: Familien `.accessoryCircular` (Ring), `.accessoryRectangular` (Ring + „11 offen · 4 PH“), `.accessoryInline`, `.accessoryCorner`; `TimelineEntryRelevance` ab 20 Uhr höher (rückt abends nach oben); Tipp öffnet die Watch-App. Frische des Stands: die Watch-App schreibt über ihren `WidgetPublisher` (nach eigenen Änderungen, nach jedem iCloud-Import und beim Aktivwerden – `ThaliaWatchApp` ruft bei `scenePhase == .active` `publishNow()`), um Mitternacht zeigt das Watch-Widget selbst „Neuer Tag“ (gleiche Timeline wie R4). `docs/SETUP.md`: App-ID `at.binisoft.thalia.watchkitapp.widgets` (App Groups) in die Tabelle und den Portal-Schritt. Abnahme: `scripts/ci/build.sh` erwartet nichts Neues; Watch-App bekommt Plugin (`find … ThaliaWatch.app/PlugIns/ThaliaWatchWidgets.appex` im Build-Log „Bundle layout“).
- [x] R87 – `Shared/WidgetActions.swift` nach Vertrag (`#if os(iOS)`, in `project.yml` zu App und Widget); mittleres/großes Widget: jede offene Zeile `Button(intent: MarkDoneFromWidgetIntent(itemKey: key, dayKey: summary.dayKey ?? ""))` mit Kreis-Symbol, danach rückt der nächste Punkt nach; ½/✗/Entfällt bleiben in der App.
- [x] R89 – `WorkAreaEntity: AppEntity` (id = key, Anzeige „3.2 <Titel>“, `defaultQuery` mit `suggestedEntities` = Geschäftsbereiche zuerst, dann übrige, aus `store.liveCategories()`); `LogPowerHourIntent.area: WorkAreaEntity` ohne Vorgabe; `AddExpenseIntent` („Ausgabe in Thalia“, `@Parameter(title: "Betrag") var amount: Double`, `@Parameter(title: "Wofür", optionsProvider: …)` mit `store.expenseSuggestions`), ohne App-Öffnen, Antwort „12,50 € für Mittagessen erfasst. Heute: 23,40 €.“; `TodayStatusIntent` nennt Offenes: „Heute: 73 % erfasst, 11 offen – als Nächstes 1.1 <Punkt>, 2.1 <Punkt>. 4 PH.“; `ThaliaShortcuts`: Eintrag „PH mit Beschreibung“ (OpenPowerHoursIntent) und „Ausgabe“ (OpenExpenseIntent) raus, `AddExpenseIntent` mit Sätzen „Ausgabe in \(.applicationName)“, „\(.applicationName) Ausgabe“ rein (die Open-Intents bleiben fürs Kontrollzentrum). Abnahme: Siri „Power-Hour in Thalia erfassen“ fragt nach dem Bereich (Liste), Menge und Wofür; „Ausgabe in Thalia“ fragt Betrag und Wofür und bucht ohne App-Öffnen; „Stand des Tages“ nennt die Zahl offener Punkte und die nächsten zwei; die Kurzbefehl-Liste hat keinen zweiten PH-Eintrag; Fokus und Einstellungen zeigen den Siri-Hinweis.
- [x] R90 (Teil) – mittleres/großes Widget: Zeile Besonderheit (`summary.dayNote`), Tagestyp neben dem Datum.
- [x] R97 – `AddExpenseIntent` bucht über `store.addExpense(_:what:day:)` (legt den Messwert bei Bedarf an), lehnt leeres Wofür oder Betrag ≤ 0 ab („Wofür war die Ausgabe? Ohne Zweck trage ich nichts ein.“), schreibt danach `publishWidget()`. Abnahme: Kurzbefehl „Ausgabe in Thalia“ mit 12,50 und „Mittagessen“ bucht ohne App-Öffnen und legt den Ausgaben-Messwert an, wenn er fehlt; leeres Wofür oder Betrag 0 wird abgelehnt; die Einstellungen erklären die Automation.
- [x] H1 (Teil) – Watch-Kategorien/Seite 1 zählen Health-Messwerte nicht als fehlend (siehe R81).

### P9 – Querschnitt und Release (läuft zuletzt, allein)
**Dateien:** alle App-Dateien für Texte/Barrierefreiheit, `App/Sources/Explainers.swift`, `App/Sources/Style.swift`, `App/Resources/Assets.xcassets`, `Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift` (Katalog, Snapshot), `CSVTests.swift` (Tour-Tests), `App/Sources/TourView.swift` (Snapshot), `Shared/GoalPalette.swift` (R44 Verläufe), `Shared/TrackerStore.swift` (nur die alte `setMarkNote(…current:)`-Weiterleitung löschen), `Config/Base.xcconfig` (Version), `Config/ci.env` (Bildschirme), `docs/TOUR.md`, `docs/TESTING.md`, `docs/STATUS.md`, `docs/HANDBOOK_PROPOSALS.md`.

- [x] R15 (Teil) – `ExplainerSheet` (Explainers.swift): `.sheetFrame(minWidth: 560, minHeight: 620)` → `.thaliaSheetFrame(width: 560, height: 740)`. Kontrolle: `grep -rn "sheetFrame(" App/Sources` findet nur noch `SheetChrome.swift`.
- [x] R23 (Aufräumen) – `setMarkNote(_:item:day:current:)` löschen, sobald `grep -rn "setMarkNote(.*current:" App Watch Shared` keinen Aufruf mehr findet.
- [x] R43 – Wortschatz überall: Menüs (`MarkMenu` mit `mark.label`), Punkt-Fenster, Abschluss, Watch, PDF-Legende („✓ erledigt · ½ teilweise · ✗ nicht erledigt · – entfällt · ○ nicht erfasst“), Hilfe (`Explainers`), Einstellungen, VoiceOver (`Optional<Mark>.accessibilityText` „Nicht erfasst“); `grep -rn "N/A\|Fällig, nicht\|\"Nicht\"" App Watch Widgets` nur noch in Parser/Kommentaren.
- [x] R44 – Kontrast: Schrift der Markier-Knöpfe und Kürzel im Hellmodus dunkler (Erledigt ≈ #1E7D3A, Teilweise ≈ #B25E00, Nicht erledigt ≈ #C62828 auf hellem Grund, Ziel ≥ 4,5:1), Kopf-Verläufe (`GoalPalette.gradient`) ohne Transparenz; Dunkelmodus: dunkleres Türkis hinter weißer Schrift (eigene Farbe `Color.accentFill` in Style.swift/Assets, nicht `Brand.accent` ändern). Zielfarben bleiben. Abnahme: Kontrast der drei Schriftfarben auf ihrem Hellmodus-Grund ≥ 4,5:1 und weiße Schrift auf `accentFill` im Dunkelmodus ≥ 4,5:1 (Werte im Code-Kommentar); `Brand.accent` und `GoalPalette.colors` unverändert.
- [x] R66 – VoiceOver: Wochenzellen `accessibilityPrefix` „Mittwoch, Fahrrad fahren“ + „nicht erfasst“/Markierung; Watch-Knöpfe sprechen Wörter; Abschluss: verfehltes Ziel mit eigenem Symbol (`xmark.circle`) und Text „verfehlt · Ziel ≤ 23:00“. Abnahme: VoiceOver liest in der Woche „Mittwoch, Fahrrad fahren, nicht erfasst“; Watch-Knöpfe sagen „Erledigt“ usw.; im Abschluss liest ein verfehltes Ziel „verfehlt, Ziel ≤ 23:00“.
- [x] R67 – Dynamic Type: `@ScaledMetric` für `MarkOptionButton` (Höhe 46, Symbol 15, Wort 10,5), `StepButton`, `ChipButton`, `KeyBadge`, Kategorie-Chips; ab `.accessibility1` ordnet `MarkBar` die Knöpfe 2 × 2. Bei Standardgröße identisch. Abnahme: bei Standardgröße sehen Heute und Woche aus wie vorher (Screenshot-Vergleich); ab AX1 stehen die Markier-Knöpfe 2 × 2, kein Wort ist abgeschnitten.
- [x] R73 – Fenster schließen einheitlich: `SheetCloseButton` in `.cancellationAction` überall, wo nichts bestätigt wird (Heute im Blick, Fokus, Ausgaben, Messwert, Punkt, Bericht, PDF, Papierkorb, Import, Erklärungen, Einstellungen-Fenster); „Fertig“/„Sichern“ nur, wo etwas bestätigt wird; nach dem Abschluss ist „Fertig“ unten der Hauptknopf. Kein „Schließen“ mehr neben „Tag abschließen“. Abnahme: kein Fenster zeigt „Schließen“ neben „Tag abschließen“; reine Ansicht-Fenster haben das × (VoiceOver „Schließen“), „Fertig“/„Sichern“ nur, wo etwas bestätigt wird.
- [x] R75 – ein Name pro Aktion (Entscheidung 20) in allen Texten; letzte Heute-Seite „Abschluss & Notizen“; Kürzel-Hinweise nur am Mac/iPad, vollständig. Abnahme: „Erstellen…“ steht nirgends mehr, „anlegen“ nur bei Messwert/Punkt, „eintragen“ nur bei Werten, „erfassen“ bei PH, Ausgabe, Notiz und „+“; die Kürzel-Fußnote erscheint auf dem iPhone nicht.
- [x] R76 – Hilfe korrigiert (`Explainers`: direkte Knöpfe statt Wischen/Halten, Durchtippen nur in der Woche, PH immer mit „Wofür“, kein „+ = 1 PH“); Tour v7 nach 3.4 (Katalog, `version = 7`, Snapshot `isGlanceOpen`, `TourView.PracticePage.snapshot`), Tests in `CSVTests.tourCatalogIsValid` neu: `allSteps.count == 13`; `steps(newerThan: 6)` = whats-new + day, mark, work, measure, glance, week, review, everywhere + finish; `steps(newerThan: 1)` enthält create, close, nicht undo; `problems()` leer; `tourStepsTickOff` weiter grün; Einstellungen-Hilfetexte. Abnahme: Tour-Tests grün; `Explainers` enthält kein Wischen/Halten zum Markieren und kein „+ = 1 PH“ mehr; `docs/TOUR.md` listet 13 Karten.
- [x] R38 (Teil) – Tour-Text zum neuen Kopf (Schritt „day“).
- [x] Version – `MARKETING_VERSION = 1.6.0` in `Config/Base.xcconfig`.
- [x] Doku – `docs/TOUR.md` (Tabelle v7), `docs/TESTING.md` neuer Abschnitt „v7 (ab Version 1.6.0)“ (je Punktgruppe: Mitternacht/Widget, Watch-Ausgaben, offen-Zahl, Fertig-Taste, Vorschläge, Besonderheit, Prompt mit Plan, Wiederholen, Import ersetzen + widerrufen, Papierkorb-Rückfrage, Komplikation, Widget abhaken, Siri-Ausgabe + Transaktion-Automation, Menüleiste, Erinnerung „In 30 Min.“, Mac-Tastatur 1–4, Health-Hinweis am Mac, nach Update alle Einträge da/Sync läuft), `docs/STATUS.md` (Stand v7), `Config/ci.env` `SCREENSHOT_SCREENS` + „weekly-goals goal-review“, `MAC_SCREENS` + „overview“.
- [x] Handbuch – `docs/HANDBOOK_PROPOSALS.md` neue Zeilen: 22 Toasts im obersten Fenster + lokalisierter Knopf („Undo“) im Kit (Thalia: `SheetChrome.toastHost`); 23 `sheetFrame` mit kleiner Mindest- und begrenzter Idealhöhe (Thalia: `thaliaSheetFrame`); 24 deutsche `SyncState`-Texte im Kit samt lokalisierbarer `SyncStatusSection`/`DataLocationView` und rohem Fehler neben dem übersetzten (Thalia: `SyncGerman`, eigene `ThaliaDataLocationView`); 25 Muster „Widget-Knopf, der App-Daten schreibt“ (LiveActivityIntent + Warteschlange); 26 Watch-Komplikation als Vorlage-Target (Bundle-ID, App Group, `ENTITLEMENTS_IOS`); 27 CloudKit + `#Index` als dokumentierte Option.

### Abdeckung (jeder Punkt mindestens einmal)

| Punkt | Pakete | Punkt | Pakete | Punkt | Pakete |
|---|---|---|---|---|---|
| R1 | P2, P1, P8 | R34 | P8 | R67 | P9 |
| R2 | P1, P2, P3, P8 | R35 | P3, P2 | R68 | P7, P5 |
| R3 | P6, P8, P1 | R36 | P3 | R69 | P7 |
| R4 | P1, P2, P8 | R37 | P3 | R70 | P7 |
| R5 | P1, P2, P4, P8 | R38 | P3, P9 | R71 | P7, P2 |
| R6 | P3, P2 | R39 | P7, P2 | R72 | P7 |
| R7 | P2 | R40 | P7, P2 | R73 | P9, P2 |
| R8 | P1, P5 | R41 | P5, P6, P4, P1, P2 | R74 | P3 |
| R9 | P5, P6, P3 | R42 | P5 | R75 | P9, P6 |
| R10 | P5 | R43 | P1, P3, P6, P8, P9 | R76 | P9 |
| R11 | P1, P7 | R44 | P9 | R77 | P6, P1 |
| R12 | P1, P2, P7 | R45 | P4 | R78 | P6, P1 |
| R13 | P2, P3, P4, P5, P6, P7 | R46 | P1, P2, P3, P4 | R79 | P1, P2 |
| R14 | P2, P4, P6, P7 | R47 | P1, P3, P4, P5, P7 | R80 | P1, P2, P7 |
| R15 | P2, P3, P4, P6, P7, P9 | R48 | P8 | R81 | P8, P1 |
| R16 | P1, P2, P4, P5, P7 | R49 | P1, P2 | R82 | P8 |
| R17 | P1, P3, P4, P8 | R50 | P4, P3 | R83 | P8 |
| R18 | P1, P2 | R51 | P4 | R84 | P1, P2, P8 |
| R19 | P1, P2 | R52 | P1, P4 | R85 | P5 |
| R20 | P2 | R53 | P4 | R86 | P8, P1 |
| R21 | P3, P1 | R54 | P1, P4 | R87 | P8, P1, P2 |
| R22 | P4, P2, P3, P6 | R55 | P5 | R88 | P1, P4 |
| R23 | P1, P6, P9 | R56 | P1, P2, P3, P5, P7 | R89 | P8, P2, P4 |
| R24 | P2 | R57 | P7 | R90 | P1, P3, P4, P5, P8, P7 |
| R25 | P3 | R58 | P1, P7 | R91 | P1 |
| R26 | P7, P1 | R59 | P2, P3, P4 | R92 | P1, P2, P3 |
| R27 | P1 | R60 | P3 | R93 | P1, P7 |
| R28 | P1, P2 | R61 | P3, P7 | R94 | P4, P3 |
| R29 | P1, P3, P6 | R62 | P3, P5, P2 | R95 | P1, P7, P2 |
| R30 | P2 | R63 | P5, P3, P2 | R96 | P2 |
| R31 | P2, P3, P4, P6, P7 | R64 | P1, P3, P5, P7 | R97 | P8, P1, P2 |
| R32 | P1, P3, P4, P5, P6 | R65 | P5 | H1 | P1, P3, P4, P7, P8 |
| R33 | P1, P5, P6 | R66 | P9 | | |

---

## 5. Reihenfolge

Fünf Runden, je zwei Pakete parallel (Dateien disjunkt), Vertrag aus Abschnitt 3 gilt von Anfang an:

1. **P1 ‖ P8** – P1 legt Core/Shared an; P8 hat nur eigene Dateien (`Watch/`, `Widgets/`, `WatchWidgets/`, `Intents.swift`, `RouteIntents.swift`, die zwei neuen Shared-Dateien, `project.yml`, Config). P8 nutzt P1-APIs nur laut Vertrag.
2. **P2 ‖ P5** – App-Rahmen und Woche/Komponenten; beide brauchen die Store-/WeekContext-APIs aus Runde 1 (jetzt lesbar), P5 liefert `SuggestionChips`, `CaptureDayRow`, `WeeklyTargetsList` für Runde 3/4.
3. **P3 ‖ P4** – Heute und Glance. P3 löscht `DayOverviewSheet/List`, P4 legt `GlanceSheet/List` neu an (andere Namen, kein Konflikt).
4. **P6 ‖ P7** – Editors und Abschluss/Rückblick/PDF.
5. **P9** allein – Querschnitt, Tour, Version, Doku; danach CI (`[screenshots]`) und TestFlight.

Alternative bei Zeitdruck: P6 kann schon in Runde 3 neben P3 laufen (keine Dateiüberschneidung), dann Runde 4 = P4 ‖ P7.

## 6. Prüfung

Gemeinsam für jedes Paket (Abschluss der eigenen Arbeit):

1. **Docker starten**, falls nötig: `docker info >/dev/null 2>&1 || (sudo -n dockerd >/tmp/dockerd.log 2>&1 &) ; sleep 5`.
2. **Syntax der eigenen Dateien** (während der Partner noch arbeitet):
   `docker run --rm -v /home/user/thalia:/home/user/thalia -w /home/user/thalia swift:6.2-noble bash -c 'for f in <eigene .swift-Dateien>; do swiftc -parse "$f" || exit 1; done'`
3. **Ende der Runde** (beide Pakete fertig): `scripts/ci/local-check.sh` (Core-Tests + `swiftc -parse` für App, Shared, Watch, Widgets). Neue Ordner (`WatchWidgets/`) prüft P8 per Hand mit Schritt 2, weil das Skript sie nicht kennt (Skript nicht ändern).
4. **Core-Tests** (P1, P9): `docker run --rm -v /home/user/thalia:/home/user/thalia -w /home/user/thalia swift:6.2-noble swift test --package-path Packages/ThaliaCore` – alle grün, neue Tests aus der P1-Liste vorhanden.
5. **Vertrag:** für jede Signatur, die das Paket baut, `grep -n` auf den exakten Namen; für jede, die es benutzt, Schreibweise mit Abschnitt 3 vergleichen (Parameter-Labels!).
6. **Fallen, die nur der Mac findet** (vor Abgabe durchsehen):
   - keine langen Ausdrücke mit mehreren `??`/Ternären in View-Bodies: `grep -nE '\?\?.*\?\?.*\?\?|\?.*:.*\?.*:.*\?' <dateien>` → in getypte Hilfsfunktionen auslagern;
   - kein `Section("…") { } footer:` (nur `Section { } header: { } footer: { }`): `grep -n 'footer:' <dateien>` und Kopf prüfen;
   - kein `if`/`else`, das in einem `body` ein `let` zuweist (Hilfsfunktion);
   - `Optional(x)` nur auf nicht-optionalen Werten (z. B. `Optional(option).color` mit `option: Mark`);
   - kein `self` in Closures im `init` einer Struct, bevor alle Eigenschaften gesetzt sind;
   - kein `.background(SomeView(), in: shape)` (nur `.background(ShapeStyle, in: shape)` oder `.background { … }`);
   - Plattform-APIs gekapselt (`#if os(iOS)` / `#if os(macOS)`): `keyboardType`, `.keyboard`-Toolbar, `topBarTrailing`, `HSplitView`, `NSApp`, `MenuBarExtra`, `WKInterfaceDevice`, `LiveActivityIntent`.
7. **Regeln:** `git status --porcelain Vendor scripts/ci` ist leer; eine Suche nach Namen von KI-Modellen (die Liste selbst nicht ins Repo schreiben) in App, Shared, Packages, Watch, Widgets, WatchWidgets und docs findet nichts; keine echten Namen/Gewichte/privaten Ziele in neuen Texten, Tests, Beispielen.
8. **P1 zusätzlich:** `tools/schema-from-models.py Shared/Models.swift HealthValue` vor und nach R84 identisch (`diff`).
9. **P9 zusätzlich:** Version 1.6.0, Tour-Tests grün, `grep -rn "sheetFrame(\|\.toasts(" App/Sources` nur in `SheetChrome.swift`, TESTING.md v7 vollständig; dann Push mit `[screenshots]`, Bilder prüfen (Heute iPhone mit Titelmenü, Heute im Blick, Fokus, Ausgaben, Woche, Wochenziele, Zielüberprüfung, Mac Heute/Woche/Abschluss), danach `[testflight]`.

## 7. Bekannte Risiken und Ausweichwege

Was erst CI am Mac oder das Gerät zeigt – mit dem Plan B, der dasselbe Problem löst:

| Punkt | Risiko | Ausweichweg |
|---|---|---|
| R87 | `LiveActivityIntent` läuft aus einem Widget-Knopf im App-Prozess; tut es das nicht (Erweiterung), ist `WidgetActions.handler` nil. | Schon eingebaut: Warteschlange in der App Group + optimistisches ✓; die App wendet sie beim nächsten Aktivwerden an. Mac/Watch sehen das ✓ erst danach (TESTING v7). |
| R14 | Menübefehle (`Commands`) zeigen den ausgegrauten Zustand bei `@Observable` evtl. verspätet. | Jede Aktion prüft `blocksSheetCommands` beim Ausführen selbst (P2 R14) – keine Eingabe geht verloren. |
| R84 | `#Index` auf CloudKit-synchronisierten Modellen. | Nur lokale Indizes, kein CloudKit-Feld (Schema-Diff leer). Zeigt CI/TestFlight Migrations- oder Sync-Fehler: `#Index`-Zeilen entfernen – der Widget-Teil von R84 (nur iPhone, gebündelt) bleibt, Abfragen bleiben eng (Prädikate statt Vollscan). |
| R86 | Die Komplikation ist nur so frisch wie der letzte Lauf der Watch-App (Entscheidung 55). | Mitternacht-Eintrag „Neuer Tag“ verhindert falsche Tage; zeigt der Alltag zu alte Stände, folgt WatchConnectivity in v8. |
| R97 | Die Automation „Transaktion“ liefert den Betrag als Währung; die Umwandlung in `Double` ist nicht garantiert. | TESTING v7 prüft eine echte Kartenzahlung. Scheitert sie: Parameter auf `IntentCurrencyAmount` umstellen (gleicher Kurzbefehl-Name), Betrag = `amount.amount`. |
| R31 | `.keyboard`-Toolbar in Listen/Sheets erscheint unter iOS manchmal nicht. | `keypadButton` ist ein Modifier an einer Stelle (AppPlatform); Ausweichweg dort: `safeAreaInset(edge: .bottom)` mit demselben Knopf, solange `isActive`. |
| R60 | `toolbarTitleMenu` am Mac zeigt das Menü nur bei Klick auf den Titel. | Das Tage-Menü steht zusätzlich in der Leiste (R62 „Gehe zu“ + Tag-Knöpfe) – die Funktion hängt nicht am Titelmenü. |
| R96 | Das Menüleisten-Label stellt nur Text/Bild sicher dar. | Label = `Text(app.menuBarTitle)` + Symbol, keine `@Query` im Label (P2 R96). |
