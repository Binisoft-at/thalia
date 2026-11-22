# Exchange fixtures (Binisoft-Austausch, format v1)

Test files for every app that writes or reads the exchange – laid out like the shared App Group
`group.at.binisoft.shared`: `<App>/exchange/source.json`, `<App>/exchange/days/<YYYY-MM-DD>.json`,
`Thalia/exchange/catalog.json`. The format and a reader/writer to copy verbatim:
`Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift`. Thalia's tests read these files
(`V10Tests.swift`); neutral example data only.

- `Theo` – `task.done` and `ph` with a category chosen from Thalia's catalog, one without.
- `George` – `workout.done` (ref = the workout template), one fact with `origin: health` (never used).
- `Nina` – `value` facts (`kcal`, `protein_g`), a fraction-second date, an unknown metric, one from Health.
- `Finn` – `spending` (EUR) and `net_worth`.
- `Demo` – the connected app of Thalia's `-Demo` and the tour's practice page (`Demo.exchangeInbox`,
  here for Sunday 22 Nov. 2026): a workout (`Push`), two `ph` (one with a category chosen in the app,
  one without), `kcal` and `protein_g`. The demo builds the same files for its own day; a test keeps
  both equal.
- `Thalia/exchange/catalog.json` – structure only: goals, categories, measures, results.
- `invalid/` – files a reader must refuse or partly skip, each with the reason in the test.
