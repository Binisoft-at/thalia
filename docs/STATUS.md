# Thalia – Stand (zum Wiedereinstieg nach Kontext-Kompaktierung)

Letzte Aktualisierung: 2026-11-22 · Arbeitsliste: [TASKS-v9.md](TASKS-v9.md) · Durchsicht v7: [REVIEW-v7.md](REVIEW-v7.md) · Bini-Testliste: [TESTING.md](TESTING.md)

## Stand v9 (Version 1.8.0, Tour-Version 9)
- Anlass: fünf Import-Probleme beim Nachtragen alter Wochen aus Scans ([TASKS-v9.md](TASKS-v9.md)). Pakete P1 Core,
  P2 Shared und P3 App umgesetzt:
  **Archiv-Wochen** – eine Woche der Datei ohne `item`-Zeilen und ohne Markierungen (nur `week`, `day`, Noten) bekommt
  keine Punkte, wird nie mit ✗ gefüllt und wie jede vergangene Woche abgeschlossen; **neue Zeilentypen**
  `category_score` und `goal_score` (Noten 0–10, ursprüngliche Bezeichnung, Quelle, Spalte `count`), gespeichert als
  CSV im Setting `archive.<Woche>` (keine CloudKit-Schemaänderung), Teil von Backup, Archiv und Widerrufen;
  **zwei Wertungen** – „Wertung laut Unterlagen“ (`recordedScore`, nie berechnet) und „Nach heutigen Regeln“
  (`finalScore`, aus den Kategoriennoten ohne Krank-/Urlaubstage); `historyScore = recordedScore ?? finalScore`
  (bisher umgekehrt); **Mittelwerte** über vorhandene Noten, echte Nullen zählen, erst die Anzeige rundet;
  **„Ohne Zuordnung (Archiv)“** für alte Bezeichnungen – nichts wird aufgeteilt, vervielfacht oder zu Haken;
  **„Archivdaten dieser Wochen ersetzen“** (Schalter im Weg „Mit ChatGPT“) für den erneuten Import: alles, was die
  App für die vergangenen Wochen der Datei hat, kommt ins Archiv, „Widerrufen“ holt es zurück, diese und spätere
  Wochen nie; **neuer Prompt** (`PastWeekPrompt`, Regeln 1–10, Kopfzeile mit `count`, Beispiel mit zwei Wochen,
  Ziele/Kategorien/Messwerte mit ids, Vorlage nur für belegte Einzelhaken) – zum erneuten Schicken der Scans.
- App (P3): neue Datei `App/Sources/ArchiveCard.swift` – Karte „Archiv“ in der Woche (iPhone unter dem Kopf, Mac/iPad
  in den Spalten der Wochentabelle, beide Wertungen in der Seitenleiste), Wochen-Kopf einer Woche ohne Punkte mit
  dem Wert laut Unterlagen; Nachtragen-Fenster mit dem Ersetzen-Schalter und „Archiv“ je Woche in der Vorschau;
  Rückblick-Zeilen mit „Archiv“ und beiden Wertungen; PDF-Bericht mit Kennzeichen „Archiv“ und Fußnote; Archiv-Liste
  „ohne Punkte“ und „Was die Woche jetzt hat, kommt dafür ins Archiv.“; Erklärungen „Vergangene Wochen“ mit
  Schritt „Archiv-Wochen“ (die Karte heißt jetzt „Neu seit 1.7“); Heute an einem Tag einer Archiv-Woche zeigt
  „KWnn ist eine Archiv-Woche“ mit beiden Wertungen und den Noten des Tages statt „Noch kein Plan“.
- Tour 9: eine Karte `archive` („Archiv-Wochen“, `since: 9`), siehe [TOUR.md](TOUR.md). Demo: die Woche zwei Wochen
  vor der aktuellen hat 16 Kategoriennoten mit Urlaub-Samstag, eine Note ohne Zuordnung („Sonderwoche“) und
  10 Zielnoten. CI-Screenshot zusätzlich `archive` (iPhone und Mac).
- Geprüft lokal: 141 Core-Tests grün (Docker `swift:6.2-noble`), `swiftc -parse` aller App-Dateien; Shared und die
  nicht-UI-Teile von `ArchiveCard.swift` gegen Stub-SwiftData im Docker typgeprüft und mit Verhaltensprüfungen
  (Import, Ersetzen, Widerrufen, Demo, Beispiel aus IMPORT.md). SwiftUI-Teile prüft erst CI am Mac.
- Lücken nach der Durchsicht geschlossen ([TASKS-v9.md](TASKS-v9.md) §5): Zeilen bleiben in ihrem Block (Tag oder
  Note mit fremdem Datum → übersprungen, nie in eine andere Woche); „Archivdaten ersetzen“ nur für Wochen mit
  `week`-Zeile und nicht, wenn die Datei genau das bringt, was die App hat; Archiv-Wochen ohne Messwert-Definitionen;
  Motto, Kontext und Wertung laut Unterlagen bleiben bei leerer Datei-Zeile, laufende Woche ohne Wochenwert;
  Dezimalkomma ohne Anführungszeichen, Werte außerhalb 0–10 und Unlesbares werden erkannt statt falsch übernommen;
  Tagesnoten in `mo … so`, deutsche Spalte `quelle`, Warnungen für zwei Bezeichnungen auf einer id und mehrere
  CSV-Blöcke; Wochenwert exakt im Export; Prompt mit Platzhalter-Beispiel (`JJJJ-Wnn`), Dezimalpunkt-Regel, Regeln für
  Zielnoten, Widersprüche und „neu erstellen“; Widerrufen behält einen Schnappschuss, wenn die Woche nach dem Import
  geändert wurde; Rückblick „Archiv“ nur für Wochen ohne Punkte. 156 Core-Tests grün.
- Nicht umgesetzt (bewusst): die Textabschnitte der alten CSV („Kategoriennoten der Übersicht:“ in `day.note`,
  „Kategorienmittel …“ in `week.note`) werden nicht ausgelesen – der neue Prompt lässt ChatGPT die CSV mit echten
  Notenzeilen neu erstellen. Fehlende Einzelhaken, Arbeitszeiten und Messwerte bleiben unbekannt.
- Nächste Schritte: CI mit `[screenshots]` (Screens `archive`), Build 1.8.0 für TestFlight (Build-Nr. 56 oder höher),
  dann TESTING.md „v9“ am Gerät; Prompt neu kopieren und die Scans erneut schicken, CSV mit „Archivdaten dieser
  Wochen ersetzen“ importieren.

## Stand v8 (Version 1.7.0, Tour-Version 8)
- Drei Wünsche vom 21. Nov. 2026 aus [TASKS-v8.md](TASKS-v8.md), Pakete P1–P5 umgesetzt:
  **Krank & Urlaub** (Tagestypen, die nicht in die Wochenwertung zählen; „n× pro Woche“ zählt den entschuldigten
  Teil halb, Regel B3; Wochenziele skaliert, „4,8 statt 8 PH – 2 Tage krank“; ganze Woche „entschuldigt“),
  **Vergangene Woche nachtragen** (Fenster mit „Vom Plan“, „Mit ChatGPT“ – viele Wochen in einer CSV,
  Vorschau je Woche, Abschluss der importierten Wochen – und „Nur Wertung“; CSV mit Matrix-Spalten `mo…so`) und
  **PDF-Bericht** über mehrere Wochen (Deckblatt, Übersicht je Woche, PH je Bereich, Wochenseiten, seitenweise mit
  Fortschritt, PDFKit-Vorschau, Lesezeichen; Mac ⌥⌘P, Sichern, Drucken).
- Geprüft: 125 Core-Tests in 18 Suiten grün (Docker `swift:6.2-noble`), CI-Läufe 33–35 grün (macOS + iOS gebaut,
  Screenshots angesehen). Nach CI 33 behoben: Wege-Auswahl „Vom Plan“ (statt abgeschnittenem „Plan übernehm…“),
  Prompt-Knöpfe als ganze Zeilen (auch im Planungs-Import), PDF-Spalte „Wertung“ einzeilig, breitere Wochenbalken,
  Papier-Wochen zählen als abgeschlossen, Uhrzeit im PDF-Fuß deutsch (14:43 statt 2:43 PM).
- TestFlight: 1.7.0 (54) hochgeladen, hat aber einen leeren „Prompt kopieren“-Knopf im Nachtragen-Fenster –
  **1.7.0 (55)** ist der Build zum Testen (iOS + watchOS + macOS, `testflight-diagnose.yml`, Build-Nr. als Eingabe;
  laut `asc-probe` am 21. Nov. 2026 für iOS und macOS verarbeitet und `IN_BETA_TESTING`).
- Keine CloudKit-Schemaänderung: Tagestypen bleiben Text (`PlanDay.dayType`), kein neues `@Model`-Feld.
- Neue Dateien: `App/Sources/PastImport.swift`, `App/Sources/RangePDF.swift`, `Shared/TrackerStore+Range.swift`,
  Core-Tests `V8Tests.swift`. Neue Fenster: `AppSheet.importPast(WeekKey?)`, `AppSheet.rangePDF`.
- Tour 8: drei neue Karten `since: 8` (Krank & Urlaub, Vergangene Wochen, PDF-Bericht), siehe [TOUR.md](TOUR.md).
  Erklärungen: „Wie wird gerechnet?“ endet mit „Neu in 1.7“ (drei Seiten). Demo-Daten: Freitag der aktuellen Woche
  ist „Krank“ (nur `-Demo`, nicht die Übungsseite der Tour). Einstellungen → Hilfe nennt die drei Seiten auch einzeln.
  CI-Screenshots zusätzlich `past-import` und `range-pdf` (iPhone und Mac).
- Offen bzw. zu prüfen: Dateigröße langer Berichte (Bänder als einfacher Verlauf, sollte Vektor bleiben) – am Gerät
  mit „Zieljahr bis heute“ + „Rückblick-Texte“. Kleine Lücken: siehe „Offene Punkte v8“ unten.
- Nächste Schritte: Bini testet 1.7.0 (55) nach TESTING.md „v8“. Nächste Build-Nr. für TestFlight: 56 oder höher.

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
