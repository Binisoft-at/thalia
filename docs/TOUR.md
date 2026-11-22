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

## Steps (tour version 10, app 1.9.0)

Catalog: `Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift`. 21 cards in the full tour:
welcome, 19 steps, finish. The four steps with `since: 10` make up "Neu in Thalia" for everyone who
took the tour in 1.8 (`steps(newerThan: 9)`: whats-new, goal-results, reading, segments,
connected-apps, finish). Someone who last took it in 1.7 (tour version 8) gets the v9 step as well
(whats-new, archive, goal-results, reading, segments, connected-apps, finish); tour version 7 gets the
3 v8 steps on top (whats-new, excused, past-weeks, archive, goal-results, reading, segments,
range-pdf, connected-apps, finish); tour version 6 gets the 8 v7 steps as well, in tour order.
`tourCatalogIsValid` in `CSVTests.swift` checks all four lists.
The v8, v9 and v10 cards tick off with „Weiter“ (no goal: setting a day type, the past-week window,
the archive card, the PDF report, the Ziele page, the reading list, the segment wizard and
Einstellungen → Verbundene Apps are not on the practice page).
The practice store holds the demo's v10 records (two segments, three results, three books with
readings, the inbox of the sample source „Demo“) – as in `-Demo`, never in the real store
(TASKS-v10 Grundregel 5). So the four v10 cards carry a button „Ansehen“ next to „Zurück“ that opens
their screen on the practice data (`TourShowcase` in `App/Sources/ConnectedApps.swift`):
goal-results → „Jahresziel eintragen“, reading → the Leseliste, segments → „Neuen Abschnitt
beginnen…“, connected-apps → „Verbundene Apps“ with the source „Demo“. They still tick off with
„Weiter“.

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
| 12 | archive | 9 | Archiv-Wochen | Woche → … (Mac: Ablage) → „Vergangene Woche nachtragen…“ → „Mit ChatGPT“: an old week may hold only its value and grades 0–10 of categories and annual goals – no items, nothing open or missed; the card „Archiv“ with „Wertung laut Unterlagen“ (kept as it was) and „Nach heutigen Regeln“ (from the category grades, without Krank/Urlaub days), „Ohne Zuordnung (Archiv)“ for old labels; „Archivdaten dieser Wochen ersetzen“ for a repeated import, Widerrufen (⌘Z) brings it back | Weiter |
| 13 | review | 7 | Ziele über Monate | 12 weeks / half-year / goal year in the goal detail, „Zielüberprüfung vorbereiten“ with parked ideas | Weiter |
| 14 | goal-results | 10 | Ergebnisse und Wochen über 8 | Ziele → ein Ziel → „Ergebnisse“: abhaken, +1 or a value („10 Bücher“, „Website online“); the row shows Stand, Ziel and „auf Kurs“ / „hinten“; back in time: go to the day, + → „Jahresziel eintragen“ (Mac: „Erfassen“ ⇧⌘N); a category with a week score from 8 is „gut dabei“: „✓ über 8“ and „Wochen über 8“ of the last twelve weeks on the goal card, with the measures in the goal | Weiter |
| 15 | reading | 10 | Leseliste | Ziele → „Gerade dabei“ (the books being read), a tap enters „bis Seite“ or „+ Seiten“, also for an earlier day; from there and from the row „Bücher 3 von 10“ to the Leseliste (Läuft, Geplant, Fertig, search, „+ Buch“ – the + button „Buch hinzufügen“); the last page suggests „fertig“; a measure with the source „Leseliste“ counts the pages by itself – entered only once | Weiter |
| 16 | segments | 10 | Abschnitte | Ziele → year card → „Neuen Abschnitt beginnen…“ (also Einstellungen → Jahresziele and the end of the goal review): start week, title, reason, then rename goals and update results; the cards count in the current segment, older ones under „Frühere Abschnitte“, their weeks stay scored as they were; Mac: ⌘Z takes back the whole step | Weiter |
| 17 | range-pdf | 8 | PDF-Bericht | Rückblick → „PDF-Bericht“, Woche → … → „Mehrere Wochen als PDF…“, Mac Ablage → „Zeitraum als PDF…“ ⌥⌘P; period (4/8/13 weeks, goal year, from–to) and scope; built page by page (cover with Ø and trend per goal, one row per week, PH per area, optional week pages); Mac: bookmarks, ⌘S, ⌘P | Weiter |
| 18 | everywhere | 7 | Überall dabei | Watch first page and crown, complication, ticking off in the widget, Siri asks for the area, „Ausgabe in Thalia“ + Transaktion automation; Mac: the menu bar | Weiter |
| 19 | connected-apps | 10 | Verbundene Apps | Einstellungen → „Verbundene Apps“ (Mac ⌘,): Theo, George, Nina or Finn deliver done items and values on the same device; power-hours „aus Theo“ in Heute, „Übernehmen“ makes an own entry; linked items get the tick „⇄ George · Push“ while there is no own mark – own entries always win; groups without a category under „Ohne Zuordnung“; values appear once Thalia was open on that device; nothing from Apple Health goes into the exchange. Details: [CONNECTED_APPS.md](CONNECTED_APPS.md) | Weiter |
| – | finish | – | Bereit | where to replay (Einstellungen → Thalia-Tour, Hilfe → Thalia-Tour) | Fertig |

Removed in v7 (content moved into the cards above): `colours` (words on the buttons → mark),
`described` (→ work, measure), `weekly-goals` (→ work, glance), `share` and `pdf` (→ close).

## Adding a step for a new feature

1. Add a `TourStep` with `since: ThaliaTour.version + 1` (touch `body`, Mac `macBody`) and a goal over
   `ThaliaTourSnapshot` (add a field and fill it in `TourView.PracticePage.snapshot`). A card whose screen
   is not on the practice page can get „Ansehen“: add its sheet to `TourShowcase.sheet(for:day:)`.
2. Bump `ThaliaTour.version`.
3. Update `tourCatalogIsValid` in `CSVTests.swift` (card count, the "Neu in Thalia" list).
4. Update the table above and the TESTING.md line for the new „Neu in Thalia“.
5. `make check` – the Core tests check the catalog.

Screenshots of one card: `tour:<id>` in `SCREENSHOT_SCREENS` (Config/ci.env) launches with `-Demo -TourStep <id>`,
e.g. `tour:excused`.
