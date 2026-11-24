# Thalia – architecture

```
Packages/ThaliaCore   all rules, Foundation only, Swift Testing on Linux:
  Calendar             DayKey ("2026-11-02"), WeekKey ("2026-W45", ISO, week 53), DayMask, GoalPeriod
  Vocabulary           Mark (✓ ½ ✗ N/A), ItemSchedule, Target, units, MeasureSource, WorkKind, DayTypes (work-free; Krank/Urlaub = excused, v8), NoteKind, reflection questions
  Records              plain values for goals, categories, weeks, days, items, measures, marks, entries, work, notes, reviews, own scores
  Scoring              Scorer (category → goal → week, goals equally weighted, quotas – v11: a missed quota counts on its
                       blank last day –, zero rule, overrides, excused days + rule B3), Pace + v11 PaceStatus
                       (erreicht · im Plan · hinter dem Plan · noch offen · nicht erreicht; limits im Rahmen / überschritten)
  Measures             day/week values, work in PH vs real hours, mark suggestions, targets scaled for excused days;
                       v10 Measures.merged(own:health:external:additive:) – own entry > Health > app/list values per code and day;
                       v11 night time targets (Target.isNight, nightMinutes), Target.parse(_:strict:)
  Format               German numbers, euro, clock, durations (v11: strict parse below 1e12, non-finite or huge values
                       show „–“ instead of trapping); v11 Units.decimals, Format.amount(_:unit:) and
                       Format.amount(target:unit:) – display rounding in the direction of the comparison, scores unchanged
  PlanCSV / ImportPreview   the CSV contract (incl. mo…so matrix columns), validation, import diff incl. removals, preview per week;
                       v11 rows `sicherung`, `wertung`, `change`, `record` rows also for the goal year and the catalog switch,
                       one number reader `PlanCSV.number`, `ImportPreview` Sendable (built off the main thread)
  Archive              v9: ArchiveGrade / ArchiveWeek (category_score, goal_score; means, today's recalculation, setting CSV)
  Template / Demo      Bini's 10 goals + 18 categories + template week; deterministic demo data (Friday of this week Krank)
  Reports              WeekReport (Markdown for the planning conversation), PlanPrompt (the prompt for ChatGPT),
                       PastWeekPrompt (past weeks from photos/PDFs/tables), WeekLine + RangeReport (several weeks)
  ThaliaTour           tour catalog (v11 `catalog(healthShare:)`), widget snapshot (TodaySummary), ReminderSettings
                       (v11: morning, evening and weekly reminders as dated requests for 7 days, no repeating ones)
  SettingRecord        v10: JSON records in AppSetting under key prefixes (SettingKeys: goal.result. goal.entry.<day>.
                       goal.segment. list.item. list.progress.<day>. link.rule. x.<source>.<day> x.sources score.<week>),
                       unknown fields kept, deletedAt + trash cascade (SettingChild), SettingRow for backup `record` rows;
                       v11 keys outside `SettingKeys.all` (never in a backup, never in `record` rows):
                       `rescore.<week>` (RescoreRequest), `backup.last` (BackupStamp), `hshare.` (HealthShare)
  SyncDevices          `sync.seen.<installID>` („Geräte im Abgleich“); v11 `sync.build.<installID>` (SyncBuild) and
                       SyncDevice.allCurrent (every device of the last 30 days on build ≥ firstV11Build = 58);
                       SyncGerman (German sync texts, v11 isPersistentProblem)
  HealthShare          v11, HEALTHSHARE (TestFlight only): `hshare.state` and `hshare.<day>` records, window 35 days,
                       suggestions 3 days, entries/covers/expired – removed before the App Store (TASKS-v11 §1.4.12)
  GoalResults          v10: GoalResult (check / count / value, target per segment, ResultSource entries | list | measure: | app:),
                       GoalEntry, ResultProgress (state, pace target, status, share per segment), GoalResultLine (prompt/report block)
  GoalTrack            v10: category week scores `score.<week>` ("1.1=8.2;1.2=6.5"), "Wochen über 8" (rounded ≥ 8,00)
  Lists                v10: ListItem, ListProgress, ListStatus, ListMath (amount per day = increase over the highest earlier reading)
  Segments             v10: GoalSegment (snapshot of goals + categories), Segments.resolve (gapless per goal year), isFrozen, SegmentSpan
  ExchangeFormat       v10: Binisoft exchange format v1 – Foundation only, copied verbatim by the other apps (docs/CONNECTED_APPS.md)
  Exchange             v10: AppSource (app:<source>:<kind>[=<ref>]), LinkRule, ExchangeInbox (x.<source>.<day>), ExchangeSourceList,
                       ExchangeDerivation (a week's computed effect: values, work blocks, ticks – own records win, origin health
                       ignored), ExchangeOverview ("Verbundene Apps"), ExchangeCatalog.thalia; v11 metric `account_balance`,
                       catalog field `results[].source`, AppSource.resultOnlyKinds / requiresRef (format v1, additions only)
  WeekExtras           v10: one call for WeekContext – merged entries, own + derived work and marks, hidden measures for direct links
  DemoV10              v10 demo: two segments, results, three books, category week scores, inbox of the source "Demo"
Shared/                compiled into the app, the Mac app and the watch app:
  Models               SwiftData models (CloudKit rules: defaults, no relationships – keys; HealthValue device-only)
  TrackerStore(+Import, +Range)  every change: marks, entries, work (power-hours), notes, reflections, overrides, items,
                       import/export, trash; past weeks (copy plan, paper score); the range report over several weeks;
                       v11: `commit(rescoring:origin:keeping:)` with SaveOrigin (user / maintenance), `withoutUndo` (maintenance
                       stays off the undo stack, a merge clears it), rescore requests (`requestRescore`,
                       `processRescoreRequests` – iPhone only, 8 per run), SyncProgress (`sync.firstImportDone`),
                       `maintenance(today:)` (full merge once per 24 h, else the last 4 weeks), `mergeImportedCopies`,
                       MarkSnapshot, ClosedWeekSnapshot, WeekInputs, `saveFailed`; import: backup rows, restore window,
                       `cleanRestoreDuplicates`, `existingState(weeks:includeRecords:includeWork:)`, `backgroundPreview`
  HealthShareStore     v11, HEALTHSHARE: HealthShareGate (allowed / denied / unknown from the App Store transaction,
                       cached), HealthShareWeek (the shared values a week reads), the writer, the clean-up (stays after
                       the sharing goes: an App Store build deletes every `hshare.` record)
  TrackerStore+Records v10 records: reads by prefix / IN predicate (in-memory fallback, verifyPrefixQuery), one copy per key,
                       RecordChange (undo), trash cascade, results + entries, reading list + readings, segments (beginSegment =
                       one undo group), freeze rule (Grundregel 2) + recompute, score.<week> + backfill, mappings, inbox
                       (storeInbox drops origin health before it syncs), "Verbundene Apps", adoptWork, catalog
  ExchangeInboxReader  v10, not on watchOS: ExchangeFolders (scan <Group>/*/exchange, write Thalia/exchange/catalog.json),
                       ExchangeMonitor (start, foreground, 5 min, own CloudKit import, day change, Darwin notification
                       at.binisoft.exchange.changed), Mac App Group entitlement check; real store only
  WeekContext / WeekReader   one week read live (@Query) and scored once – used by every screen, the widget snapshot and the watch;
                       v10: segment, results, GoalTrack, derived values / work / ticks through WeekExtras (own records win);
                       v11: `WeekReader(…, goalYear: false)` for small readers, Equatable by its records box, records kept per
                       instance, `isHealthElsewhere(_:on:)`, HealthDevice.scoresHealth (iPhone only) / installedAt
  Persistence          ModelStore.open (own container, device-only Health store), demo + practice stores
  WidgetBridge, WidgetPublisher, WidgetActions   widget snapshot in the App Group, ✓ from the widget; v11: the import
                       observer also tells SyncProgress about every import, `publishIfNeeded` for the watch
App/Sources            iOS + macOS app (German UI):
  AppModel             tab/sidebar, the one sheet, selected day/week, actions with Undo, deep links, launch arguments;
                       v11: Mac inspectors only while they fit (`roomWidth` = window − visible sidebar, at least the detail;
                       Heute 900 pt, Woche 750 pt, ±20 pt) – else `showDayOverview` opens a sheet; `reopenWeek` with
                       Widerrufen; maintenance at start and after sync without Undo; sent/received times, the sync line
                       (SyncProblem, `-FakeSyncProblem`), the automatic backup trigger, `tourCatalog`
  RootView             iPhone/iPad tabs (Heute, Woche, Ziele, Rückblick) + bottom accessory; Mac split view; sheets; tour
  TodayView            the day: work (+PH, „aus Theo“), measurements (+, Health), items by category, notes
  WeekView             the weekly sheet: items × Mo–So, week score, goal bars, weekly targets with pace
  ArchiveCard          v9: the week's „Archiv“ card – „Wertung laut Unterlagen“ / „Nach heutigen Regeln“, grades Mo–So, no mapping
  GoalsView / ReviewView   the ten goals (year progress, KW49 review), history across the KW42 change; v11: the Ziele
                       page builds goal histories and excused weeks from its observed plans (no full plan fetch per body;
                       only an unscored week of the 26-week window is read, with `goalYear: false`)
  CloseDayView / CloseWeekView   the evening review and the weekly closing (report + planning prompt)
  Editors, ImportView, PastImport, SettingsView, Explainers   sheets, import/export, past weeks, settings, in-app explainers;
                       v11 ImportView: the preview is built off the main thread (`backgroundPreview`), a file over 200 KB
                       stays out of the text field (one row with its size), the file is read again right before applying
  GoalResults          v10: results of the annual goals – „Ergebnisse“ on the goal page (GoalResultsSection, rows, ResultEditor),
                       a result's page with its entries, „Jahresziel eintragen“ (GoalEntrySheet), the badge „✓ über 8“
  ReadingList          v10: the reading list (ReadingListView: Läuft / Geplant / Fertig / Abgebrochen), „Gerade dabei“
                       (CurrentlyReadingCard), book window (BookEditor), „Lesen“ with „bis Seite“ / „+ Seiten“ (ReadingProgressSheet)
  Segments             v10: „Neuen Abschnitt beginnen…“ (SegmentWizard), segment editor, „Frühere Abschnitte“ (EarlierSegmentsCard)
                       and a segment's page, new goals/categories for Einstellungen → Jahresziele, FrozenWeekNote („Neu berechnen“;
                       v11: „Am iPhone neu berechnen“ where `canScore` says no, „Nach heutigem Stand“, „Widerrufen“)
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
  PDFExport / RangePDF   week and day PDF (v11: async, page by page with „Seite x von y“); the PDF report over several
                       weeks (page by page, PDFKit preview)
  Services             reminders (UNUserNotificationCenter; v11 dated morning, evening and weekly requests, `weekClosed`),
                       HealthService (HealthKit, read-only; v11 `readValues(days:measures:)` for the sharing)
  Intents              App Shortcuts: Power-Hour erfassen, Messwert eintragen, Stand des Tages, Tag abschließen
  Backups              v11: BackupWriter („Sicherung erstellen…“ off the main thread, `backup.last`, the weekly automatic
                       file in Application Support/Sicherungen – 4 newest + one per month for 6 months, never after a
                       suspiciously small file), BackupExportButton, BackupsPage („Sicherungen“)
  BackgroundGrace      v11, iOS: background time until the CloudKit export after a Shortcut, Siri or widget ✓ (up to
                       20 s) and for `afterSync`; empty on macOS (Intents.swift is built for the Mac too)
  HealthShareSettings  v11, HEALTHSHARE: the switch „Health-Werte mit Mac und Watch teilen“ (HealthShareController,
                       HealthShareSection), the writer's triggers, the read-only shared value (SharedHealthInput)
  Style / SheetChrome  v11: StatusTint (one colour per status for weekly targets and results),
                       PracticeUnavailableView (the tour's practice page offers nothing real)
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
- `HealthValue` is in a device-only configuration (`cloudKitDatabase: .none`) – guideline 5.1.3(ii). Exception in
  TestFlight only (v11, HEALTHSHARE): with „Health-Werte mit Mac und Watch teilen“ one device writes its adopted
  values of the last 35 days as `hshare.<day>` records; an App Store build deletes them all at launch and after each
  sync.
- A closed week stores its final score (`WeekPlan.finalScore`, goal scores) so the history never
  recomputes old weeks.
- **Who scores (v11):** the iPhone scores closed weeks (after its first sync, `SyncProgress`). Mac, watch and iPad
  score only after their own input, only weeks without a Health progress item (or covered by shared values), and only
  when every device of the last 30 days runs 1.10.0 (`sync.build.`); they always write a `rescore.<week>` request the
  iPhone handles after its next sync (8 per run, deleted after 10 minutes). Maintenance – inbox, merging, backfill,
  import – never scores there. A fresh install keeps the scores of Health weeks that ended before it.
- Deletes go to *Zuletzt gelöscht* (30 days) with Undo; ⌘Z and shake work through the context's undo manager.
  v11: maintenance runs in `TrackerStore.withoutUndo` – off the undo stack; when it merged or removed something the
  stack is cleared, so ⌘Z never points at an object a merge deleted.
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
  `rescoreRecentClosedWeeks`, the end of an import) – only „Neu berechnen“ in the week does, and (v11) a request with
  `force` (closing on Mac, watch or iPad, „Am iPhone neu berechnen“) on the iPhone. The week right before
  the segment freezes from the segment's second week on (the iPhone's Health catch-up after a Mac closing). Frozen
  closed weeks show their stored score everywhere (v11), „Nach heutigem Stand“ only as a second line.
- **Inbox copies (v10):** `x.sources` is read as the union of all its copies; copies of a day file are picked the same
  way on every device (`ExchangeInbox.isPreferred`); only facts with `origin: app` are stored.
- **v11 keys without a schema change** (never in `SettingKeys.all`, so never in a backup, a `record` row or the week's
  prefix reads; older builds ignore them): `rescore.<week>` (`{"v","by","at","force"}`), `sync.build.<installID>`
  (`{"v","build","version"}` – its own key, because 1.9.0 drops a device whose `sync.seen.` value has more parts),
  `backup.last` (`{"v","at","device"}`, the kind of device, never its name), `hshare.state` (with the writer's kind of device in `device`) and
  `hshare.<day>` (HEALTHSHARE). New JSON field: `list.item` → `startAt`. Device-only UserDefaults: `health.installedAt`,
  `sync.firstImportDone`, `sync.buildWritten`, `maintenance.lastFull`, `restore.window`, `backup.lastAuto`,
  `backup.lastAutoSmall`, `sync.lastSent`, `sync.lastReceived`, `sync.lastChange`, `week.summary` (now read through
  `AppModel.showsWeekSummary`), and for the sharing `thalia.health.shareGate`, `thalia.health.share`,
  `thalia.health.shareEndedElsewhere`, `thalia.health.shareCleaned`.

## Launch arguments (screenshots in CI)

`-Demo` (this week up to today, last week closed, earlier weeks as paper scores) with
`-DemoScreen today|week|goals|review|close-day|close-week|import|past-import|range-pdf|create|work|report|explainer|settings`,
v10 also `goal-detail|reading|connected-apps` (and more, see `AppModel.applyLaunchOptions`), v11 `backup`
(Einstellungen → Sicherungen) and – HEALTHSHARE, iOS – `health` (Einstellungen → Apple Health with the TestFlight
switch), both through `SettingsView(initialPage:)`; `-Tour`, `-TourStep <id>`, `-ResetTour`. Debug builds only (v11):
`-FakeSyncProblem local|memory|quota` (the sync line) and `-HealthShareGate allowed|denied|unknown` (the TestFlight
gate). Screens CI captures: `Config/ci.env`.
