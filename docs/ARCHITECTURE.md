# Thalia – architecture

```
Packages/ThaliaCore   all rules, Foundation only, Swift Testing on Linux:
  Calendar             DayKey ("2026-11-02"), WeekKey ("2026-W45", ISO, week 53), DayMask, GoalPeriod
  Vocabulary           Mark (✓ ½ ✗ N/A), ItemSchedule, Target, units, MeasureSource, WorkKind, DayTypes (work-free; Krank/Urlaub = excused, v8), NoteKind, reflection questions
  Records              plain values for goals, categories, weeks, days, items, measures, marks, entries, work, notes, reviews, own scores
  Scoring              Scorer (category → goal → week, 10 % per goal, quotas, zero rule, overrides, excused days + rule B3), Pace
  Measures             day/week values, work in PH vs real hours, mark suggestions, targets scaled for excused days;
                       v10 Measures.merged(own:health:external:additive:) – own entry > Health > app/list values per code and day
  PlanCSV / ImportPreview   the CSV contract (incl. mo…so matrix columns), validation, import diff incl. removals, preview per week
  Archive              v9: ArchiveGrade / ArchiveWeek (category_score, goal_score; means, today's recalculation, setting CSV)
  Template / Demo      Bini's 10 goals + 18 categories + template week; deterministic demo data (Friday of this week Krank)
  Reports              WeekReport (Markdown for the planning conversation), PlanPrompt (the prompt for ChatGPT),
                       PastWeekPrompt (past weeks from photos/PDFs/tables), WeekLine + RangeReport (several weeks)
  ThaliaTour           tour catalog, widget snapshot (TodaySummary), ReminderSettings
  SettingRecord        v10: JSON records in AppSetting under key prefixes (SettingKeys: goal.result. goal.entry.<day>.
                       goal.segment. list.item. list.progress.<day>. link.rule. x.<source>.<day> x.sources score.<week>),
                       unknown fields kept, deletedAt + trash cascade (SettingChild), SettingRow for backup `record` rows
  GoalResults          v10: GoalResult (check / count / value, target per segment, ResultSource entries | list | measure: | app:),
                       GoalEntry, ResultProgress (state, pace target, status, share per segment), GoalResultLine (prompt/report block)
  GoalTrack            v10: category week scores `score.<week>` ("1.1=8.2;1.2=6.5"), "Wochen über 8" (rounded ≥ 8,00)
  Lists                v10: ListItem, ListProgress, ListStatus, ListMath (amount per day = increase over the highest earlier reading)
  Segments             v10: GoalSegment (snapshot of goals + categories), Segments.resolve (gapless per goal year), isFrozen, SegmentSpan
  ExchangeFormat       v10: Binisoft exchange format v1 – Foundation only, copied verbatim by the other apps (docs/CONNECTED_APPS.md)
  Exchange             v10: AppSource (app:<source>:<kind>[=<ref>]), LinkRule, ExchangeInbox (x.<source>.<day>), ExchangeSourceList,
                       ExchangeDerivation (a week's computed effect: values, work blocks, ticks – own records win, origin health
                       ignored), ExchangeOverview ("Verbundene Apps"), ExchangeCatalog.thalia
  WeekExtras           v10: one call for WeekContext – merged entries, own + derived work and marks, hidden measures for direct links
  DemoV10              v10 demo: two segments, results, three books, category week scores, inbox of the source "Demo"
Shared/                compiled into the app, the Mac app and the watch app:
  Models               SwiftData models (CloudKit rules: defaults, no relationships – keys; HealthValue device-only)
  TrackerStore(+Import, +Range)  every change: marks, entries, work (power-hours), notes, reflections, overrides, items,
                       import/export, trash; past weeks (copy plan, paper score); the range report over several weeks
  TrackerStore+Records v10 records: reads by prefix / IN predicate (in-memory fallback, verifyPrefixQuery), one copy per key,
                       RecordChange (undo), trash cascade, results + entries, reading list + readings, segments (beginSegment =
                       one undo group), freeze rule (Grundregel 2) + recompute, score.<week> + backfill, mappings, inbox
                       (storeInbox drops origin health before it syncs), "Verbundene Apps", adoptWork, catalog
  ExchangeInboxReader  v10, not on watchOS: ExchangeFolders (scan <Group>/*/exchange, write Thalia/exchange/catalog.json),
                       ExchangeMonitor (start, foreground, 5 min, own CloudKit import, day change, Darwin notification
                       at.binisoft.exchange.changed), Mac App Group entitlement check; real store only
  WeekContext / WeekReader   one week read live (@Query) and scored once – used by every screen, the widget snapshot and the watch;
                       v10: segment, results, GoalTrack, derived values / work / ticks through WeekExtras (own records win)
  Persistence          ModelStore.open (own container, device-only Health store), demo + practice stores
  WidgetBridge, WidgetPublisher, WidgetActions   widget snapshot in the App Group, ✓ from the widget
App/Sources            iOS + macOS app (German UI):
  AppModel             tab/sidebar, the one sheet, selected day/week, actions with Undo, deep links, launch arguments
  RootView             iPhone/iPad tabs (Heute, Woche, Ziele, Rückblick) + bottom accessory; Mac split view; sheets; tour
  TodayView            the day: work (+PH, „aus Theo“), measurements (+, Health), items by category, notes
  WeekView             the weekly sheet: items × Mo–So, week score, ten goal bars, weekly targets with pace
  ArchiveCard          v9: the week's „Archiv“ card – „Wertung laut Unterlagen“ / „Nach heutigen Regeln“, grades Mo–So, no mapping
  GoalsView / ReviewView   the ten goals (year progress, KW49 review), history across the KW42 change
  CloseDayView / CloseWeekView   the evening review and the weekly closing (report + planning prompt)
  Editors, ImportView, PastImport, SettingsView, Explainers   sheets, import/export, past weeks, settings, in-app explainers
  GoalResults          v10: results of the annual goals – „Ergebnisse“ on the goal page (GoalResultsSection, rows, ResultEditor),
                       a result's page with its entries, „Jahresziel eintragen“ (GoalEntrySheet), the badge „✓ über 8“
  ReadingList          v10: the reading list (ReadingListView: Läuft / Geplant / Fertig / Abgebrochen), „Gerade dabei“
                       (CurrentlyReadingCard), book window (BookEditor), „Lesen“ with „bis Seite“ / „+ Seiten“ (ReadingProgressSheet)
  Segments             v10: „Neuen Abschnitt beginnen…“ (SegmentWizard), segment editor, „Frühere Abschnitte“ (EarlierSegmentsCard)
                       and a segment's page, new goals/categories for Einstellungen → Jahresziele, FrozenWeekNote („Neu berechnen“)
  ConnectedApps        v10: Einstellungen → „Verbundene Apps“ (per source: last seen, Meldungen, „Ohne Zuordnung“ → category,
                       mappings, „Was kommt an“, read problems, „Thalia-Katalog bereitstellen“), Today's „aus Theo“ rows with
                       „Übernehmen“, the measure editor's „Quelle“ (Manuell / Power-Hours / Apple Health / Leseliste / Verbundene App)
  v10 screens          Ziele: year card „Abschnitt 2 · seit KW50 · Woche 3“ with its ••• menu, „✓ über 8“ and „Wochen über 8“,
                       results, measure chips, „Gerade dabei“, „Frühere Abschnitte“; goal page with results, „Messwerte diese
                       Woche“ and the range „Abschnitt“; Einstellungen → Jahresziele with the segments; Rückblick: a line where a
                       segment begins; PDF report „Aktueller Abschnitt“; week: „✓ über 8“ on the category head,
                       „Neu berechnen“; Erfassen → „Jahresziel
                       eintragen“ / „Lesen“; Einstellungen → „Verbundene Apps“; Heute: blocks „aus Theo“, ticks „⇄ George · …“;
                       Ausgaben: rows „aus Finn“; measure editor „Quelle“
  PDFExport / RangePDF   week and day PDF; the PDF report over several weeks (page by page, PDFKit preview)
  Services             reminders (UNUserNotificationCenter), HealthService (HealthKit, read-only)
  Intents              App Shortcuts: Power-Hour erfassen, Messwert eintragen, Stand des Tages, Tag abschließen
Watch/Sources          ring, open items, counters, power-hours with Bereich and Wofür, measurements
Widgets/Sources        Heute and Woche widgets (Home + Lock Screen), Control Center (Erfassen, Power-Hours, Ausgabe)
WatchWidgets/Sources   the watch complication
Vendor/BinisoftKit     shared kit (synced from the handbook, v1)
```

## Data and sync

- SwiftData in the private database of `iCloud.at.binisoft.thalia` (`.private(...)`, `groupContainer: .none`).
- No relationships: records point to each other by keys, so sync order never matters. If two
  devices create the same key offline, the most recently changed record is read (`Array.latest`).
- Enum-like values are raw strings with a fallback; new fields optional or defaulted; the schema
  file `cloudkit/schema.ckdb` lists every synced record type (generated from `Shared/Models.swift`).
- `HealthValue` is in a device-only configuration (`cloudKitDatabase: .none`) – guideline 5.1.3(ii).
- A closed week stores its final score (`WeekPlan.finalScore`, goal scores) so the history never
  recomputes old weeks.
- Deletes go to *Zuletzt gelöscht* (30 days) with Undo; ⌘Z and shake work through the context's undo manager.
- **v10 without a schema change:** results, entries, segments, the reading list, mappings, the inbox and the
  category week scores are JSON in `AppSetting` under their own key prefixes (`SettingRecord`, the v9
  `archive.<week>` pattern). A dated fact has its day in the key (`goal.entry.<day>.<id>`), so two devices never
  overwrite each other and `touchedWeeks()` finds the week. Unknown JSON fields survive saving; deleting sets
  `deletedAt`. Older builds ignore the keys. Backups carry them as `record` rows ([IMPORT.md](IMPORT.md)).
- **Connected apps** ([CONNECTED_APPS.md](CONNECTED_APPS.md)): other Binisoft apps write day files into the App
  Group `group.at.binisoft.shared` on the same device; Thalia (iPhone, iPad, Mac – never the watch, never `-Demo`)
  stores each as `x.<source>.<day>` in the synced inbox, never deletes it and never stores facts from Apple Health.
  Their effect on a week is computed (`ExchangeDerivation`), never written as own marks, blocks or entries; own
  records always win.
- **Frozen past (v10):** a closed week before the current segment is never scored again automatically (save,
  `rescoreRecentClosedWeeks`, the end of an import) – only „Neu berechnen“ in the week does. The week right before
  the segment freezes from the segment's second week on (the iPhone's Health catch-up after a Mac closing).
- **Inbox copies (v10):** `x.sources` is read as the union of all its copies; copies of a day file are picked the same
  way on every device (`ExchangeInbox.isPreferred`); only facts with `origin: app` are stored.

## Launch arguments (screenshots in CI)

`-Demo` (this week up to today, last week closed, earlier weeks as paper scores) with
`-DemoScreen today|week|goals|review|close-day|close-week|import|past-import|range-pdf|create|work|report|explainer|settings`,
v10 also `goal-detail|reading|connected-apps` (and more, see `AppModel.applyLaunchOptions`),
`-Tour`, `-TourStep <id>`, `-ResetTour`. Screens CI captures: `Config/ci.env`.
