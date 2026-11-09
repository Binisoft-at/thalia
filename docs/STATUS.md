# Thalia – Stand (zum Wiedereinstieg nach Kontext-Kompaktierung)

Letzte Aktualisierung: 2026-11-04 · Arbeitsliste: [TASKS-v2.md](TASKS-v2.md) · Bini-Testliste: [TESTING.md](TESTING.md)

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
- `Packages/ThaliaCore` (Linux-getestet): Calendar (DayKey/WeekKey/DayMask/GoalPeriod), Vocabulary (Mark, ItemSchedule, Target, Units, MeasureSource, WorkKind, DayTypes, NoteKind, ReflectionQuestion), Records, Scoring (Scorer, Pace), Measures (+WorkTotals), PlanCSV, ImportPreview, Template, Demo, Reports (WeekReport, PlanPrompt), ThaliaTour (+TodaySummary, ReminderSettings), Format.
- `Shared/`: Models (SwiftData, Schlüssel statt Relationen, HealthValue device-only), TrackerStore(+Import), WeekContext/WeekReader, Persistence, DemoData, WidgetBridge, WorkActivity.
- `App/Sources`: AppModel, RootView, TodayView, WeekView, GoalsView, ReviewView, CloseDayView, CloseWeekView, Editors, ImportView, SettingsView, Explainers, Services (Reminder, Health, Live Activity), Intents, TourView, Components, AppPlatform, ThaliaTips, ThaliaApp.
- `Watch/Sources`, `Widgets/Sources`. Screens für CI-Screenshots: `Config/ci.env`.

## v2 – Fortschritt
Siehe Status-Häkchen in [TASKS-v2.md](TASKS-v2.md). Nächster Schritt steht dort unter „Jetzt“.

Stand 4. Nov. 2026: v2 fertig gebaut. CI run 8 grün (4131b80), Screenshots geprüft, CloudKit-Schema
importiert (run 4) und von Bini nach Production deployt (5.3), **TestFlight 1.1.0 (16)** für iOS und
macOS hochgeladen (run 16, 810df85). Tour-Version 2 („Neu in Thalia“ für die geänderten Schritte).
Offen: Bini testet laut [TESTING.md](TESTING.md); M1 (Mac) nach Feedback weiter verfeinern
(z. B. Wochen-Raster als dichte Tabelle).
