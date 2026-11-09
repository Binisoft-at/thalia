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

## Steps

Catalog: `Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift`.

| id | Teaches | Ticks off when |
|---|---|---|
| welcome | – | Los geht's |
| create | the central + | the create sheet is open |
| mark | ✓ ½ ✗ N/A by tapping | a mark changed |
| work | + PH (50 min) vs real hours | a work block was added |
| measure | measurements, + | an entry was added |
| undo | delete + Widerrufen | a work block went to the trash and came back |
| close | the evening review | the close-day sheet is open |
| week | Sunday: close the week, prompt, import | Weiter |
| everywhere | sync, watch, widgets, Shortcuts, reminders | Weiter |
| finish | where to replay | Fertig |

## Adding a step for a new feature

1. Add a `TourStep` with `since: ThaliaTour.version + 1` (touch `body`, Mac `macBody`) and a goal over
   `ThaliaTourSnapshot` (add a field and fill it in `TourView.PracticePage.snapshot`).
2. Bump `ThaliaTour.version`.
3. `make check` – the Core tests check the catalog.
