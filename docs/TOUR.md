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

## Steps (tour version 7, app 1.6.0)

Catalog: `Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift`. 13 cards in the full tour:
welcome, 11 steps, finish. The 8 steps with `since: 7` make up "Neu in Thalia" for everyone who
took the tour in an earlier version (`steps(newerThan: 6)`).

| # | id | since | Title | Teaches | Ticks off when |
|---|---|---|---|---|---|
| – | welcome | – | Willkommen bei Thalia | practice page, nothing real is touched | Los geht's |
| 1 | create | 2 | Alles beginnt unten bei + | the central „Erfassen“ (⇧⌘N), every sheet names its day | the create sheet is open (`isCreateOpen`) |
| 2 | day | 7 | Welcher Tag gerade gilt | date, day type and „Besonderheit“ in the title, midnight switch, „Zu heute“ (⇧⌘T), the morning banner „Nachtragen / Abschließen“ | Weiter |
| 3 | mark | 7 | Punkte mit einem Tipp | Erledigt · Teilweise · Nicht erledigt · Entfällt, answered rows turn calm, swipe or „Weiter“; Mac: keys 1–4, ⌥⌘↓ | a mark changed (`markSummary`) |
| 4 | work | 7 | Power-Hours mit „Wofür“ | the last three entries, area + amount + „Wofür“, Return saves, the inline row under the weekly target | a work block was added (`workCount`) |
| 5 | measure | 7 | Werte und Ausgaben eintragen | „Fertig“ above the number pad, spending with „Weiter“ and suggestions, tap an expense to edit it | an entry changed (`entrySummary`) |
| 6 | undo | 1 | Fehler sind kein Problem | delete + „Widerrufen“ in the topmost window, ⌘Z | a work block went to the trash and came back (`trashedWorkCount`) |
| 7 | close | 2 | Den Tag abschließen | the evening review, then image or PDF (⌘S, ⌘P on the Mac) | the close-day sheet is open (`isCloseDayOpen`) |
| 8 | glance | 7 | Heute im Blick | the ring opens it: open items, „Diese Woche noch“, weekly targets with pace, Fokus (8 weeks) and Ausgaben; Mac: right column ⌘0, ⌘5, ⌘6 | the sheet or the Mac column is open (`isGlanceOpen`) |
| 9 | week | 7 | Sonntag: Woche abschließen und planen | „Weiter: Woche abschließen“, prompt with last week's plan, CSV, „Wie KW … wiederholen“, archive + undo | Weiter |
| 10 | review | 7 | Ziele über Monate | 12 weeks / half-year / goal year in the goal detail, „Zielüberprüfung vorbereiten“ with parked ideas | Weiter |
| 11 | everywhere | 7 | Überall dabei | Watch first page and crown, complication, ticking off in the widget, Siri asks for the area, „Ausgabe in Thalia“ + Transaktion automation; Mac: the menu bar | Weiter |
| – | finish | – | Bereit | where to replay (Einstellungen → Thalia-Tour, Hilfe → Thalia-Tour) | Fertig |

Removed in v7 (content moved into the cards above): `colours` (words on the buttons → mark),
`described` (→ work, measure), `weekly-goals` (→ work, glance), `share` and `pdf` (→ close).

## Adding a step for a new feature

1. Add a `TourStep` with `since: ThaliaTour.version + 1` (touch `body`, Mac `macBody`) and a goal over
   `ThaliaTourSnapshot` (add a field and fill it in `TourView.PracticePage.snapshot`).
2. Bump `ThaliaTour.version`.
3. Update `tourCatalogIsValid` in `CSVTests.swift` (card count, the "Neu in Thalia" list).
4. `make check` – the Core tests check the catalog.
