# Thalia v8 (Version 1.7.0, Tour-Version 8)

Drei Wünsche (21. Nov. 2026):
1. Vergangene Wochen nachtragen – zumindest die Wochenübersicht (Punkte × Tage mit ✓ ½ ✗ –).
2. Tage als „Krank“ oder „Urlaub“: zählen nicht in die Wochenwertung; was über die Woche deshalb nicht
   mehr ging, zählt als teilweise erledigt (Beispiel: 3× Workout, 2 gemacht, ab Freitag krank → das dritte = ½).
3. Mehrere Wochen schön als PDF.

Grundlage: Code-Karte in der Session (Import, Wertung, PDF). Keine CloudKit-Schemaänderung: Tagestypen bleiben
Text (`PlanDay.dayType`), alles Neue ist Logik oder UI.

## 1. Entscheidungen

1. **Entschuldigte Tage:** `DayTypes.isExcused(type)` = Tagestyp enthält „krank“ oder „urlaub“ (klein, Teilstring).
   Presets bekommen „Krank“ und „Urlaub“; Symbole Krank `cross.case`, Urlaub `beach.umbrella` (vor den Regeln für
   „erhol“/„frei“ prüfen). `isWorkFree` bleibt unverändert.
2. **Was an entschuldigten Tagen passiert:** kein Punkt ist fällig (`applies` = false), Markierungen dieses Tages
   zählen nicht (lesen sich als –), eigene Tageswertungen (Overrides) zählen nicht, Messwerte sind nie „fehlend“
   (Eingabe bleibt möglich, Werte zählen in Wochensummen), der Tag ist nie „offen“ (Ring, Widget, Watch,
   Gestern-Banner, Abend-Erinnerung).
3. **Wochenziele „n× pro Woche“ (Regel B3):** P = geplante Tage des Punkts, E = P ∩ entschuldigt, A = P \ E.
   used = Tage in A mit ✓/½/✗. missing = max(0, n − used). share = n·|E|/|P|. excused = min(missing, share).
   Gebucht am letzten Tag von A: applicable += missing, earned += 0,5·excused, `CategoryDay.excused` += excused.
   A leer → nichts buchen (Punkt nicht bewertet). Tests T1–T6 (unten).
4. **Fortschrittspunkte und Wochen-Messziele:** Ziel × share (share = |A|/|P| der Messtage, bei Arbeits-Messwerten
   ohne arbeitsfreie Tage); Grenzen (≤, „höchstens“) werden nicht skaliert. share = 0 → Punkt nicht bewertet.
   Gilt überall über einen Core-Helfer (`Measures.targetShare`, `Measures.effectiveTarget`): Pace, Wochenziele,
   „Soll bis heute“, Widget-Zeilen, Bericht, PDF.
5. **Ganze Woche entschuldigt** (alle Tage mit Geplantem entschuldigt): keine Wochenwertung (`overall` nil),
   Text „Woche zählt nicht (krank/Urlaub)“, Rückblick/Charts zeigen „entschuldigt“ statt einer Lücke.
6. **Ziele, deren Punkte nur auf entschuldigte Tage fielen,** zählen nicht in `goalsTotal`
   („x/y Ziele bewertet“ bleibt vergleichbar). Ziele ganz ohne Punkte zählen weiter (bestehender Test bleibt grün).
7. **Markierungen von vor der Krankmeldung** (z. B. Freitag früh ✓, dann Typ „Krank“) bleiben gespeichert, zählen aber
   nicht; die Woche zeigt sie gedimmt. Typ zurück auf „Arbeitstag“ → zählen wieder.
8. **Vergangene Woche nachtragen** – neues Fenster „Vergangene Woche nachtragen“ mit drei Wegen:
   a) **Plan übernehmen und selbst abhaken:** Punkte der nächstgelegenen geplanten Woche (vor- oder nachher) in die
      gewählte Woche kopieren (ohne Markierungen), dann die Woche in der Wochentabelle abhaken, Tagestypen setzen.
   b) **Mit ChatGPT übertragen – auch viele Wochen auf einmal:** Prompt kopieren (enthält Ziele, Kategorien, die
      Punkte der nächstgelegenen geplanten Woche mit ids als Vorlage und das CSV-Format) → in ChatGPT **Fotos, PDFs
      oder Tabellen mehrerer Wochen** dazulegen → ChatGPT liest KW/Datum aus den Unterlagen und liefert **eine CSV mit
      einem Block je Woche** (week-Zeile, day-Zeilen inkl. Krank/Urlaub, item-Zeilen, Markierungen; nur eine
      Wertung bekannt → week-Zeile mit value) → CSV einfügen (oder Datei wählen) → Vorschau **je Woche** (neu/ersetzt,
      Punkte, Markierungen, Krank/Urlaub-Tage, Warnungen) → Import. Zeitraum im Fenster: „Wochen aus den Unterlagen“
      (Standard, ChatGPT erkennt sie) oder fester Bereich von–bis. Alle importierten vergangenen Wochen und ihre Tage
      werden **abgeschlossen** (so erscheinen sie in Rückblick, Zielen, Ø 4 Wo.). Wochen ≥ aktuelle Woche in der Datei
      → Warnung, werden nicht abgeschlossen. Schalter „Leere Felder“: offen lassen (Standard) / als ✗ zählen.
   c) **Nur Wochenwertung:** KW + Zahl (Papier-Wertung, `recordedScore`).
   Wochenauswahl: Beginn des Zieljahrs bzw. 52 Wochen zurück bis letzte Woche.
9. **CSV-Erweiterungen (Core):** Item-Zeilen dürfen Spalten `mo,di,mi,do,fr,sa,so` (auch montag…sonntag, mon…sun)
   mit ✓/½/✗/– haben → Markierungen; Markierungs-Zeilen auf unbekannte Punkte → Warnung; Tageszeilen mit Typ
   „Krank“/„Urlaub“ funktionieren schon (Typ ist Text). Export bleibt im langen Format.
10. **PDF mehrerer Wochen:** Fenster „PDF-Bericht“ mit Zeitraum (letzte 4 / 8 / 13 Wochen, Zieljahr bis heute,
    eigener Zeitraum von–bis) und Umfang (nur Übersicht · + Wochenübersicht je Woche (Deckblatt + Tabellen) ·
    + Rückblick-Texte). Seiten: Deckblatt (Zeitraum, Ø-Ring, Kacheln, Balken je Woche, 10 Ziele mit Ø und Trend),
    Übersichtstabelle (je Woche eine Zeile: KW, Wertung, 10 Zielfelder in Zielfarbe, PH, abgeschlossene Tage,
    Krank/Urlaub-Tage, Wochenziele), PH je Bereich, dann die Wochenseiten. Seitenzahlen durchgehend.
    Erzeugung seitenweise mit Fortschritt („Seite 37 von 120“), Vorschau über PDFKit (nicht als Live-Views).
    Einstieg: Rückblick (Werkzeugleiste „PDF-Bericht“), Woche …-Menü „Mehrere Wochen als PDF“, Mac Ablage
    „Zeitraum als PDF…“ (⌥⌘P).
11. **Version 1.7.0, Tour 8:** drei neue Karten `since: 8` („Krank & Urlaub“, „Vergangene Wochen“, „PDF-Bericht“).

## 2. Testfälle Wertung (ThaliaCore)

- T1: 3×, jeden Tag geplant, ✓ Mo, ✓ Mi, Fr–So Krank → Do bekommt applicable 1, earned 0,5 → Do 5,0;
  categoryWeek = (10+10+5)/3 ≈ 8,33 (ohne Regel: 6,67).
- T2: 3× an Mo/Mi/Fr, ✓ Mo, ✓ Mi, Fr Krank → gebucht auf Mi: applicable 2, earned 1,5 → 7,5; Woche 8,75.
- T3: 3×, jeden Tag, nichts gemacht, Fr–So Krank → missing 3, excused 9/7, earned ≈ 0,64 auf Do → ≈ 2,14.
- T4: ganze Woche Urlaub → nichts gebucht, Punkt/Kategorie/Ziel ohne Wertung, Woche `overall` nil.
- T5: 3× und 3 gemacht → kein Abzug.
- T6: `canMarkNotApplicable`: 3×, Fr–So Krank, nichts gemacht → needed = ceil(3 − 9/7) = 2 → N/A am Di erlaubt
  (Mi, Do bleiben), am Mi nicht.
- T7: Fortschritt 8 PH Mo–Fr, Do–Fr Krank, 4 PH → Ziel 4,8, Verhältnis 0,83 → teilweise; 5 PH → erreicht.
- T8: täglicher Punkt Mo–So, Sa+So Urlaub, Mo–Fr ✓ → Kategorie 10, Sa/So ohne Wertung, nicht offen.
- T9: Override auf einem Krank-Tag wird ignoriert; Ziel nur mit Punkten an Krank-Tagen fällt aus `goalsTotal`.

## 3. API-Vertrag

### 3.1 ThaliaCore (P1)
- `DayTypes.isExcused(_:) -> Bool`, `DayTypes.excusedHint` („Krank/Urlaub: Der Tag zählt nicht in die Wochenwertung“),
  Presets + Symbole wie Entscheidung 1.
- `WeekData`: neues letztes Init-Argument `excusedDays: Set<DayKey> = []`, Feld `excusedDays`, `isExcused(_ day:)`;
  `applies`, `mark()`, `options`, Overrides, `bookShortfalls` (Regel B3), `canMarkNotApplicable` wie oben.
- `CategoryDay.excused: Double`, `DayOverall.isExcused: Bool`, `WeekScore.excusedDays`, `WeekScore.goalsExcused`,
  `WeekScore.isExcused` (ganze Woche), `coverageText` „Woche zählt nicht (krank/Urlaub)“.
- `Measures.targetShare(days:week:notPlanned:excused:) -> Double`, `Measures.effectiveTarget(_:share:) -> Target`,
  `progressRatio(…, excused:, workFree:)` (Default `[]`), `Pace(…)` mit entschuldigten Tagen.
- PlanCSV: Matrix-Spalten `mo…so` auf Item-Zeilen; `parse(_:knownItems:)` (Default `[]`) mit Warnung für
  Markierungen auf unbekannte Punkte; `Document.fillingBlanks(weeks:with: Mark)`; `Document.closingPast(today:)`
  (alle Wochen < heute.week und ihre Tage mit Markierungen/Typ → closedWeeks/closedDays).
- `PastWeekPrompt.text(weeks:items:categories:goals:measures:) -> String` (Reports.swift, neben PlanPrompt);
  `weeks: [WeekKey]` – leer = „die Wochen aus den angehängten Fotos/PDFs/Tabellen, KW und Datum dort ablesen“,
  sonst genau diese Wochen; verlangt eine CSV mit einem Block je Woche, verbietet erfundene Markierungen für leere
  Felder, nennt Krank/Urlaub als Tagestyp und „nur Wertung → week-Zeile mit value“. Test: mehrere Wochen + leer.
- `WeekLine` (week, score, isClosed, isOldScoring, isPaperOnly, isExcused, goalScores, powerHours, powerHoursTarget,
  closedDays, excusedDays, weeklyTargetsMet, weeklyTargetsCount) und `RangeReport` (lines, average (ohne alte und
  entschuldigte Wochen), goal averages + trend (±0,25 wie Zielüberprüfung), PH je Bereich, Summen) mit
  `RangeReport(lines:goals:work:)`; öffentliche Inits.
- Tests: T1–T9, Matrix-Parse, unbekannte Markierung → Warnung, fillingBlanks, closingPast, PastWeekPrompt enthält
  ids und Format, RangeReport-Durchschnitt/Trend, `presets` enthält Krank/Urlaub.

### 3.2 Shared/App (P2 – Rahmen und Tagestypen)
- `WeekContext` reicht `excusedDays` aus `PlanDay.dayType` in `WeekData` (beide Konstruktionsstellen); `isExcused(day)`,
  `openCount`/`isOpenRequired`/`dayStatusText` berücksichtigen es; Wochenziele über `effectiveTarget`.
- `AppModel.isDayClosed` bleibt; neu `isDayExcused(_:)`; Abend-Erinnerungen und Gestern-Banner überspringen
  entschuldigte Tage; `setDayInfo` plant Erinnerungen neu.
- `AppSheet`: neue Fälle `.importPast(WeekKey?)` → `PastWeekImportView(week:)` (P3) und `.rangePDF` →
  `RangePDFSheet()` (P4); `id`, `SheetContent`; Mac-Befehl Ablage „Zeitraum als PDF…“ ⌥⌘P → `.rangePDF`;
  Woche …-Menü „Vergangene Woche nachtragen…“ und „Mehrere Wochen als PDF…“; Rückblick-Leerstand verweist auf
  „Vergangene Woche nachtragen“.
- UI für entschuldigte Tage: Tagestyp-Auswahl (Titelmenü Heute, Woche, Tag abschließen) mit Krank/Urlaub oben;
  Heute an einem Krank/Urlaub-Tag: Karte „Krank – dieser Tag zählt nicht in die Wochenwertung“ mit „Typ ändern“;
  Wochentabelle: Spalte gedimmt, Kopf mit Symbol, Zellen „–“; Heute im Blick/Fokus/Wochenziele zeigen skalierte
  Ziele („4,8 statt 8 PH – 2 Tage krank“); Watch und Widgets: entschuldigter Tag = nicht offen, Hinweis „Krank“.
- `TrackerStore` (Shared/TrackerStore.swift): nichts Neues nötig außer Helfern, die P2 braucht.

### 3.3 Import (P3)
- Neue Datei `App/Sources/PastImport.swift`: `PastWeekImportView(week: WeekKey?)` mit den drei Wegen aus
  Entscheidung 8 (Weg b für viele Wochen in einer CSV, Vorschau je Woche, Datei-Auswahl wie im Wochenplan-Import); nutzt `ImportPreview`/Apply aus ImportView (gemeinsame Teile dort herausziehen, ImportView.swift
  gehört P3), schließt importierte vergangene Wochen (über `Document.closingPast`), „Leere Felder“-Schalter.
- `Shared/TrackerStore+Import.swift`: `nearestPlannedWeek(to:)` (vor und zurück), `copyPlan(from:to:)` (ohne
  Markierungen, über `Document.repeated`), `setPaperScore(_:week:)`.
- docs/IMPORT.md: Abschnitt „Vergangene Wochen“ (Matrix-Spalten, Beispiel, Krank/Urlaub-Tageszeilen).

### 3.4 PDF (P4)
- `App/Sources/PDFExport.swift`: `weekPageCount`, `weekPages(_:sections:firstPage:total:)`, `WeekPDFSections`;
  bestehende Einzel-PDFs unverändert; entschuldigte Tage in Wochen-/Tages-PDF mit Symbol und „zählt nicht“.
- Neue Datei `App/Sources/RangePDF.swift`: `RangePDFSheet()` (Zeitraum, Umfang, Erzeugen mit Fortschritt,
  PDFKit-Vorschau, Teilen; Mac Sichern/Drucken), `RangeCoverPage`, `RangeOverviewPage`, `RangeWorkPage`,
  `PDFExport.makeRange(...) async -> URL?` (seitenweise, `Task.yield()`, PDF-Titel/Creator, Lesezeichen je Woche).
- Neue Datei `Shared/TrackerStore+Range.swift`: `rangeReport(from:through:) -> RangeReport`,
  `weekContexts(from:through:)`.
- Rückblick-Werkzeugleiste „PDF-Bericht“ (ReviewView.swift gehört P4).

### 3.5 Abschluss (P5)
- Tour 8 (ThaliaTour.swift, docs/TOUR.md, CSVTests Tour-Tests), Explainers (Krank/Urlaub, Vergangene Wochen,
  PDF-Bericht), Version 1.7.0, TESTING „v8“, STATUS, ci.env SCREENSHOT_SCREENS + `past-import range-pdf`
  (Launch-Optionen in AppModel.applyLaunchOptions: `past-import` → `.importPast(nil)`, `range-pdf` → `.rangePDF`;
  Demo-Daten: ein Krank-Tag Fr in der aktuellen Demo-Woche, damit Screenshots es zeigen).

## 4. Pakete und Dateien

| Paket | Dateien |
|---|---|
| P1 Core | Packages/ThaliaCore/** |
| P2 Rahmen + Tagestypen | Shared/WeekContext.swift, Shared/TrackerStore.swift, Shared/WidgetBridge.swift, App/Sources/AppModel.swift, RootView.swift, ThaliaApp.swift, TodayView.swift, WeekView.swift, WeekTable.swift, Components.swift, Glance.swift, Focus.swift, Expenses.swift, CloseDayView.swift, CloseWeekView.swift, GoalsView.swift, Services.swift, Watch/**, Widgets/**, WatchWidgets/** |
| P3 Import | App/Sources/PastImport.swift (neu), ImportView.swift, Shared/TrackerStore+Import.swift, docs/IMPORT.md |
| P4 PDF | App/Sources/PDFExport.swift, RangePDF.swift (neu), ReviewView.swift, Shared/TrackerStore+Range.swift (neu), Sharing.swift |
| P5 Abschluss | ThaliaTour.swift + Tests, Explainers.swift, Config/Base.xcconfig, Config/ci.env, DemoData.swift / Demo.swift, docs/* |

Reihenfolge: P1 → (P2 ∥ P3 → P4) → P5 → Compile-Review → Vollständigkeit → Lücken schließen.

## 5. Prüfung
`make check` (Core-Tests + `swiftc -parse`), keine Fallen aus TASKS-v7 §6 (lange `??`/Ternär-Ketten im Body,
`Section("…"){} footer:`, if/else-`let` im ViewBuilder, Plattform-APIs ohne `#if os`), dann CI mit `[screenshots]`.
