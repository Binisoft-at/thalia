# Thalia – tour

The interactive tour runs the real *Heute* screen on a practice week (the template week with
realistic entries, in memory, never synced) with a German coach card on top. Each step ticks
itself off once the practice page shows it was done.

- Opens by itself **once after install**; after an update that added steps it shows only those as
  **"Neu in Thalia"**; otherwise never by itself.
- Replay: Einstellungen → Thalia-Tour, the ••• menu on iPhone, Hilfe → Thalia-Tour on the Mac.
- While it is open, Mac menu commands (⌘N …) act on the practice page.
- The coach card is Thalia's own (`TourView.swift`) because the kit's card has English button
  titles; it uses the kit's tour engine (`TourProgress`, `TourSchedule`).

## Steps (tour version 8, app 1.7.0)

Catalog: `Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift`. 16 cards in the full tour:
welcome, 14 steps, finish. The 3 steps with `since: 8` make up "Neu in Thalia" for everyone who
took the tour in 1.6 (`steps(newerThan: 7)`: whats-new, excused, past-weeks, range-pdf, finish).
Someone who last took it in tour version 6 gets the 8 v7 steps plus the 3 v8 steps, in tour order.
The three v8 cards tick off with „Weiter“ (no goal: setting a day type, the past-week window and
the PDF report are not on the practice page).

| # | id | since | Title | Teaches | Ticks off when |
|---|---|---|---|---|---|
| – | welcome | – | Willkommen bei Thalia | practice page, nothing real is touched | Los geht's |
| 1 | create | 2 | Alles beginnt unten bei + | the central „Erfassen“ (⇧⌘N), every sheet names its day | the create sheet is open (`isCreateOpen`) |
| 2 | day | 7 | Welcher Tag gerade gilt | date, day type and „Besonderheit“ in the title, midnight switch, „Zu heute“ (⇧⌘T), the morning banner „Nachtragen / Abschließen“ | Weiter |
| 3 | excused | 8 | Krank & Urlaub | title menu → Tagestyp → „Krank“/„Urlaub“ (week: long press / right-click on the day); the day doesn't count, nothing is due, no evening reminder, grey column; what no longer fit in the week counts half (3× training, 2 done, sick from Friday → the third = Teilweise); weekly targets shrink („4,8 statt 8 PH – 2 Tage krank“) | Weiter |
| 4 | mark | 7 | Punkte mit einem Tipp | Erledigt · Teilweise · Nicht erledigt · Entfällt, answered rows turn calm, swipe or „Weiter“; Mac: keys 1–4, ⌥⌘↓ | a mark changed (`markSummary`) |
| 5 | work | 7 | Power-Hours mit „Wofür“ | the last three entries, area + amount + „Wofür“, Return saves, the inline row under the weekly target | a work block was added (`workCount`) |
| 6 | measure | 7 | Werte und Ausgaben eintragen | „Fertig“ above the number pad, spending with „Weiter“ and suggestions, tap an expense to edit it | an entry changed (`entrySummary`) |
| 7 | undo | 1 | Fehler sind kein Problem | delete + „Widerrufen“ in the topmost window, ⌘Z | a work block went to the trash and came back (`trashedWorkCount`) |
| 8 | close | 2 | Den Tag abschließen | the evening review, then image or PDF (⌘S, ⌘P on the Mac) | the close-day sheet is open (`isCloseDayOpen`) |
| 9 | glance | 7 | Heute im Blick | the ring opens it: open items, „Diese Woche noch“, weekly targets with pace, Fokus (8 weeks) and Ausgaben; Mac: right column ⌘0, ⌘5, ⌘6 | the sheet or the Mac column is open (`isGlanceOpen`) |
| 10 | week | 7 | Sonntag: Woche abschließen und planen | „Weiter: Woche abschließen“, prompt with last week's plan, CSV, „Wie KW … wiederholen“, archive + undo | Weiter |
| 11 | past-weeks | 8 | Vergangene Wochen | Woche → … (Mac: Ablage) → „Vergangene Woche nachtragen…“ with the window's three ways „Vom Plan“, „Mit ChatGPT“ (photos/PDFs/tables of many weeks, one CSV, preview per week), „Nur Wertung“; imported weeks are closed and count in Rückblick and Ziele | Weiter |
| 12 | review | 7 | Ziele über Monate | 12 weeks / half-year / goal year in the goal detail, „Zielüberprüfung vorbereiten“ with parked ideas | Weiter |
| 13 | range-pdf | 8 | PDF-Bericht | Rückblick → „PDF-Bericht“, Woche → … → „Mehrere Wochen als PDF…“, Mac Ablage → „Zeitraum als PDF…“ ⌥⌘P; period (4/8/13 weeks, goal year, from–to) and scope; built page by page (cover with Ø and trend per goal, one row per week, PH per area, optional week pages); Mac: bookmarks, ⌘S, ⌘P | Weiter |
| 14 | everywhere | 7 | Überall dabei | Watch first page and crown, complication, ticking off in the widget, Siri asks for the area, „Ausgabe in Thalia“ + Transaktion automation; Mac: the menu bar | Weiter |
| – | finish | – | Bereit | where to replay (Einstellungen → Thalia-Tour, Hilfe → Thalia-Tour) | Fertig |

Removed in v7 (content moved into the cards above): `colours` (words on the buttons → mark),
`described` (→ work, measure), `weekly-goals` (→ work, glance), `share` and `pdf` (→ close).

## Adding a step for a new feature

1. Add a `TourStep` with `since: ThaliaTour.version + 1` (touch `body`, Mac `macBody`) and a goal over
   `ThaliaTourSnapshot` (add a field and fill it in `TourView.PracticePage.snapshot`).
2. Bump `ThaliaTour.version`.
3. Update `tourCatalogIsValid` in `CSVTests.swift` (card count, the "Neu in Thalia" list).
4. Update the table above and the TESTING.md line for the new „Neu in Thalia“.
5. `make check` – the Core tests check the catalog.

Screenshots of one card: `tour:<id>` in `SCREENSHOT_SCREENS` (Config/ci.env) launches with `-Demo -TourStep <id>`,
e.g. `tour:excused`.
