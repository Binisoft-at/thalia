# Thalia – Stand (zum Wiedereinstieg nach Kontext-Kompaktierung)

Letzte Aktualisierung: 2026-11-21 · Arbeitsliste: [TASKS-v8.md](TASKS-v8.md) · Durchsicht v7: [REVIEW-v7.md](REVIEW-v7.md) · Bini-Testliste: [TESTING.md](TESTING.md)

## Stand v8 (Version 1.7.0, Tour-Version 8)
- Drei Wünsche vom 21. Nov. 2026 aus [TASKS-v8.md](TASKS-v8.md), Pakete P1–P5 umgesetzt:
  **Krank & Urlaub** (Tagestypen, die nicht in die Wochenwertung zählen; „n× pro Woche“ zählt den entschuldigten
  Teil halb, Regel B3; Wochenziele skaliert, „4,8 statt 8 PH – 2 Tage krank“; ganze Woche „entschuldigt“),
  **Vergangene Woche nachtragen** (Fenster mit „Plan übernehmen“, „Mit ChatGPT“ – viele Wochen in einer CSV,
  Vorschau je Woche, Abschluss der importierten Wochen – und „Nur Wertung“; CSV mit Matrix-Spalten `mo…so`) und
  **PDF-Bericht** über mehrere Wochen (Deckblatt, Übersicht je Woche, PH je Bereich, Wochenseiten, seitenweise mit
  Fortschritt, PDFKit-Vorschau, Lesezeichen; Mac ⌥⌘P, Sichern, Drucken).
- Lokal geprüft: 120 Core-Tests in 17 Suiten grün (Docker `swift:6.2-noble`), `swiftc -parse` sauber für App, Shared,
  Watch, Widgets und WatchWidgets. Typprüfung und Build der SwiftUI/PDFKit-Teile laufen erst in CI am Mac – zuerst
  ansehen: `App/Sources/RangePDF.swift`, `PDFExport.swift`, `PastImport.swift`, `ReviewView.swift`.
- Keine CloudKit-Schemaänderung: Tagestypen bleiben Text (`PlanDay.dayType`), kein neues `@Model`-Feld.
- Neue Dateien: `App/Sources/PastImport.swift`, `App/Sources/RangePDF.swift`, `Shared/TrackerStore+Range.swift`,
  Core-Tests `V8Tests.swift`. Neue Fenster: `AppSheet.importPast(WeekKey?)`, `AppSheet.rangePDF`.
- Tour 8: drei neue Karten `since: 8` (Krank & Urlaub, Vergangene Wochen, PDF-Bericht), siehe [TOUR.md](TOUR.md).
  Erklärungen: „Wie wird gerechnet?“ endet mit „Neu in 1.7“ (drei Seiten). Demo-Daten: Freitag der aktuellen Woche
  ist „Krank“ (nur `-Demo`, nicht die Übungsseite der Tour). Einstellungen → Hilfe nennt die drei Seiten auch einzeln.
  CI-Screenshots zusätzlich `past-import` und `range-pdf` (iPhone und Mac).
- Offen bzw. zu prüfen: Dateigröße langer Berichte (Bänder als einfacher Verlauf, sollte Vektor bleiben), die
  Screenshots `past-import`/`range-pdf`, Mac-Build. Kleine Lücken: siehe „Offene Punkte v8“ unten.
- Nächste Schritte: CI mit `[screenshots]`, dann TestFlight 1.7.0 (Build-Nr. > 53), Bini testet nach TESTING.md „v8“.

### Offene Punkte v8
- Läuft CI an einem Freitag, zeigen die Demo-Screenshots „today“, „close-day“ und „overview“ den Krank-Tag statt eines
  normalen Tags (Demo-Freitag ist immer „Krank“, so verlangt in Entscheidung 11).
- Erledigt beim Lückenschließen: Import (und Rückgängig, Archiv-Wiederherstellen) plant die Abend-Erinnerungen neu;
  `closingKnownDays`/`fillingPastBlanks` liegen jetzt in ThaliaCore (`PlanCSV.Document`) mit Repo-Tests; ein Wochenziel,
  dessen Tage alle krank/Urlaub sind, wird nicht bewertet (fehlt in „x von y erreicht“, PDF, Widgets; Hinweis „zählt
  nicht“); Wochen-Kopf und Mac-Seitenleiste zeigen „Woche zählt nicht (krank/Urlaub)“; die Ziel-Diagramme zeigen eine
  ganz entschuldigte Woche als graue Säule.

## Stand v7 (Version 1.6.0, Tour-Version 7)
- Alle neun Pakete P1–P9 aus [TASKS-v7.md](TASKS-v7.md) sind umgesetzt (R1–R97 und H1). Lokal geprüft: Core-Tests grün,
  `swiftc -parse` für App, Shared, Watch, Widgets und WatchWidgets. Typprüfung und Build laufen erst in CI am Mac.
- Keine CloudKit-Schemaänderung (nur lokale `#Index`, Schema-Diff leer). Neu: Watch-Komplikation als eigenes Target
  `ThaliaWatchWidgets` – Owner-Schritt vor `[testflight]`: App-ID `…watchkitapp.widgets` mit App Group (siehe [SETUP.md](SETUP.md)).
- Neue Dateien: `App/Sources/SheetChrome.swift` (Toasts im obersten Fenster, `thaliaSheetFrame`, ×-Knopf), `Glance.swift`,
  `Focus.swift`, `Expenses.swift`, `MenuBar.swift`; `Shared/WidgetPublisher.swift`, `WidgetActions.swift`, `GoalPalette.swift`;
  Core `Merge.swift`, `SyncGerman.swift`; `WatchWidgets/`. Kontrastfarben (R44) als Assets `ThaliaAccentFill`, `Mark…Text`.
- CI: Lauf 21 sofort grün (Build), Screenshots geprüft. Mac zeigte in 21–24 kein Fenster: `@AppStorage` im App-Struct an
  `MenuBarExtra(isInserted:)` blockierte den Hauptthread nach dem Start (gefunden mit `LaunchDiagnostics`, nur Debug).
  Behoben in Lauf 25 (Schalter im AppModel). Dazu: Datum/Uhrzeit-Picker immer deutsch, Kategorie-Kopf einzeilig.
- Mac-Layout nur am CI-Bildschirm (1024 × 768) gesehen: dort wird die Seitenleiste schmal und rechts abgeschnitten;
  auf normalen Mac-Bildschirmen (Fenster 1180 pt) prüfen.
- TestFlight: macOS 1.6.0 (47) stürzte am Mac ab (AppKit-Toolbar bei `.toolbar(id:)`); iPhone 1.5.0 stürzte beim Tippen
  auf eine Mitteilung ab (async-Delegate). Beides behoben → **iOS + Watch + macOS 1.6.0 (52)** hochgeladen über
  `testflight-diagnose.yml` (Build-Nr. als Eingabe). Der reguläre TestFlight-Workflow hat als nächste Run-Nr. 52: für
  1.6.0 nicht mehr verwenden (Build 52 existiert), sonst neue Version oder Diagnose-Workflow mit Nummer > 52.
- iOS-Export scheiterte dreimal mit „Error Downloading App Information“: laut Distribution-Log HTTP 500 von
  `GET /v1/apps?…include=appStoreVersions` (Apple-Serverfehler, kam und ging). `asc-probe.yml` prüft diese Anfragen.
- 1.6.1: Sync-Prüfung (Workflow mit Gegenprüfung) – 4 Fehler und 7 Risiken behoben, „Geräte im Abgleich“ in den
  Einstellungen, Produktions-Schema geprüft (alle Felder da). Details und bekannte Grenzen: [SYNC.md](SYNC.md).
  Health am Mac: bleibt (Regel 5.1.3(ii)) bis Bini A/B entscheidet.
- TestFlight: **1.6.1 (53)** für iOS + Watch + macOS hochgeladen (testflight-diagnose.yml, Build-Nr. 53). Nächste
  Uploads: Build-Nr. > 53 (regulärer Workflow erst ab Run 54 verwenden oder Diagnose-Workflow mit Nummer).
- Nächste Schritte: Bini testet nach TESTING.md „1.6.1“ und „v7“.
- Bekannte Risiken mit Ausweichweg: [TASKS-v7.md](TASKS-v7.md) Abschnitt 7 (Widget-Abhaken aus der Erweiterung, `#Index`
  mit CloudKit, Transaktion-Betrag, Ziffernblock-Leiste).

## Repos und Regeln
- App: `Binisoft-at/thalia` → lokal `/home/user/thalia`. Push auf `claude/gifted-mendel-nn3d4f` **und** `main` (Handbuch: direkt auf main; CI läuft nur auf main).
- Handbuch: `Binisoft-at/binisoft-handbook` (Tag `v1`) → `/home/user/binisoft-handbook`. Regeln: README, HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST. Nie `Vendor/BinisoftKit` oder `scripts/ci` in der App ändern.
- Commits enden mit `Co-Authored-By: Claude <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01GTSNJwt4VJSPttHHHbqj92`. Keine Modellnamen.
- Antworten an Bini: kurz, Deutsch, Format HOW_WE_WORK §6 (gebaut · wo · Build-Nr. · ausprobieren · nächste Schritte · Fragen A/B · verifiziert/nicht).

## Checks
- Lokal: Docker-Daemon ggf. starten (`sudo dockerd &`), dann `make check` (Core-Tests in `swift:6.2-noble` + `swiftc -parse`).
- CI-Ergebnis: `git fetch origin ci-output && git show origin/ci-output:ci/status.txt` (Fehler: `ci/errors.txt`, Screenshots: `ci/shots/`).
- TestFlight: `[testflight]` in der Commit-Nachricht oder Workflow manuell; Ergebnis auf `ci-testflight` (`status.txt`, `uploaded.txt`). Build-Nr. = Run-Nr.
- App-Store-Connect-Status: Workflow `asc-status.yml` (read-only) → `ci-output:asc/status.txt`.
- CloudKit: `cloudkit-schema.yml` → `ci-testflight`? nein: `ci-cloudkit` (`status.txt`, `needs-deploy.txt`). Schema aus Modellen: `tools/schema-from-models.py Shared/Models.swift HealthValue`.
- Achtung: TestFlight und CI gleichzeitig auf main → der Mac-Job kann ohne Runner abgebrochen werden; dann „rerun failed jobs“.

## Stand v1 (erledigt)
- Setup-Checkliste (Artifact): https://claude.ai/artifact/8xyJXeSDbZDD8fMeZF3Air – alles bis 6.2 erledigt (db-Collection `steps`).
- TestFlight **Build 8** (iOS + macOS 1.0.0) hochgeladen, VALID, IN_BETA_TESTING. CloudKit-Schema in Production deployed (14 Record-Typen).
- Bini hat den Grundablauf getestet, Sync iPhone↔Mac funktioniert. Health, Widgets usw. noch nicht.
- Offene A/B-Fragen aus v1 (unbeantwortet): Sprache (A Deutsch), Health-Werte nur Gerät (A), Papier-Historie importieren (A), Erinnerungszeiten (A 08:15/21:45/So 17:00).

## Architektur (Kurz)
- `Packages/ThaliaCore` (Linux-getestet): Calendar (DayKey/WeekKey/DayMask/GoalPeriod), Vocabulary (Mark, ItemSchedule, Target, Units, MeasureSource, WorkKind, DayTypes, NoteKind, ReflectionQuestion), Records, Scoring (Scorer, Pace), Measures (+WorkTotals), PlanCSV, ImportPreview, Template, Demo, Reports (WeekReport, PlanPrompt, PastWeekPrompt, WeekLine/RangeReport), ThaliaTour (+TodaySummary, ReminderSettings), Format.
- `Shared/`: Models (SwiftData, Schlüssel statt Relationen, HealthValue device-only), TrackerStore(+Import, +Range), WeekContext/WeekReader, Persistence, DemoData, WidgetBridge, WorkActivity.
- `App/Sources`: AppModel, RootView, TodayView, WeekView, GoalsView, ReviewView, CloseDayView, CloseWeekView, Editors, ImportView, PastImport, PDFExport, RangePDF, SettingsView, Explainers, Services (Reminder, Health, Live Activity), Intents, TourView, Components, AppPlatform, ThaliaTips, ThaliaApp.
- `Watch/Sources`, `Widgets/Sources`. Screens für CI-Screenshots: `Config/ci.env`.

## v2 – Fortschritt
Siehe Status-Häkchen in [TASKS-v2.md](TASKS-v2.md). Nächster Schritt steht dort unter „Jetzt“.

Stand 9. Nov. 2026: v3 fertig – Repo öffentlich (Historie auf einen Commit neu geschrieben), CI grün,
**TestFlight 1.2.0 (25)**. Aufgaben und Plan: [TASKS-v3.md](TASKS-v3.md).

Stand 4. Nov. 2026: v2 fertig gebaut. CI run 8 grün (4131b80), Screenshots geprüft, CloudKit-Schema
importiert (run 4) und von Bini nach Production deployt (5.3), **TestFlight 1.1.0 (16)** für iOS und
macOS hochgeladen (run 16, 810df85). Tour-Version 2 („Neu in Thalia“ für die geänderten Schritte).
Offen: Bini testet laut [TESTING.md](TESTING.md); M1 (Mac) nach Feedback weiter verfeinern
(z. B. Wochen-Raster als dichte Tabelle).
