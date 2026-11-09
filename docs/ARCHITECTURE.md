# Thalia – architecture

```
Packages/ThaliaCore   all rules, Foundation only, Swift Testing on Linux:
  Calendar             DayKey ("2026-11-02"), WeekKey ("2026-W45", ISO, week 53), DayMask, GoalPeriod
  Vocabulary           Mark (✓ ½ ✗ N/A), ItemSchedule, Target, units, MeasureSource, WorkKind, DayTypes, NoteKind, reflection questions
  Records              plain values for goals, categories, weeks, days, items, measures, marks, entries, work, notes, reviews, own scores
  Scoring              Scorer (category → goal → week, 10 % per goal, quotas, zero rule, overrides), Pace
  Measures             day/week values, work in PH vs real hours, mark suggestions
  PlanCSV / ImportPreview   the CSV contract, validation (ten items per category), import diff incl. removals
  Template / Demo      Bini's 10 goals + 18 categories + template week; deterministic demo data
  Reports              WeekReport (Markdown for the planning conversation), PlanPrompt (the prompt for ChatGPT)
  ThaliaTour           tour catalog, widget snapshot (TodaySummary), ReminderSettings
Shared/                compiled into the app, the Mac app and the watch app:
  Models               SwiftData models (CloudKit rules: defaults, no relationships – keys; HealthValue device-only)
  TrackerStore(+Import)  every change: marks, entries, work + timer, notes, reflections, overrides, items, import/export, trash
  WeekContext / WeekReader   one week read live (@Query) and scored once – used by every screen, the widget snapshot and the watch
  Persistence          ModelStore.open (own container, device-only Health store), demo + practice stores
  WidgetBridge, WorkActivity   widget snapshot in the App Group; Live Activity attributes
App/Sources            iOS + macOS app (German UI):
  AppModel             tab/sidebar, the one sheet, selected day/week, actions with Undo, deep links, launch arguments
  RootView             iPhone/iPad tabs (Heute, Woche, Ziele, Rückblick) + bottom accessory; Mac split view; sheets; tour
  TodayView            the day: work (+PH, timer), measurements (+, Health), items by category, notes
  WeekView             the weekly sheet: items × Mo–So, week score, ten goal bars, weekly targets with pace
  GoalsView / ReviewView   the ten goals (year progress, KW49 review), history across the KW42 change
  CloseDayView / CloseWeekView   the evening review and the weekly closing (report + planning prompt)
  Editors, ImportView, SettingsView, Explainers   sheets, import/export, settings, in-app explainers
  Services             reminders (UNUserNotificationCenter), HealthService (HealthKit, read-only), Live Activity
  Intents              App Shortcuts: Power-Hour erfassen, Messwert eintragen, Stand des Tages, Tag abschließen
Watch/Sources          today's score, +1 PH / timer, measurements +, open items
Widgets/Sources        Heute and Woche widgets (Home + Lock Screen), Power-Hour Live Activity
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

## Launch arguments (screenshots in CI)

`-Demo` (this week up to today, last week closed, earlier weeks as paper scores) with
`-DemoScreen today|week|goals|review|close-day|close-week|import|create|work|report|explainer|settings`,
`-Tour`, `-TourStep <id>`, `-ResetTour`. Screens CI captures: `Config/ci.env`.
