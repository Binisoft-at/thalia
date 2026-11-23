# Exchange fixtures (Binisoft-Austausch, format v1)

Test files for every app that writes or reads the exchange – laid out like the shared App Group
`group.at.binisoft.shared`: `<App>/exchange/source.json`, `<App>/exchange/days/<YYYY-MM-DD>.json`,
`Thalia/exchange/catalog.json`. The format and a reader/writer to copy verbatim:
`Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift`. Thalia's tests read these files
(`V10Tests.swift`, `V11Tests.swift`); neutral example data only.

- `Theo` – `task.done` and `ph` with a category chosen from Thalia's catalog, one without.
- `George` – `workout.done` (ref = the workout template), one fact with `origin: health` (never used).
- `Nina` – `value` facts (`kcal`, `protein_g`), a fraction-second date, an unknown metric, one from Health.
- `Finn` (v11, TASKS-v11 §1.5) – `source.json` with groups and accounts (`"kind": "account"`, an account and an
  account group); per day file the facts of each row switched on in Finn: `spending` per group (EUR), net worth
  on every day it changed (`nw-<YYYY-MM-DD>`, the balance at the end of the day), account balances per account or
  account group (`account_balance`, `ref` = the account id, `kb-<ref>-<YYYY-MM-DD>`), and the savings rate once a
  month in the file of the month's last day (`sr-<YYYY-MM>`, `2026-10-31.json`). A test compares them with what
  the writer builds (`V11Tests.swift`).
- `Demo` – the connected app of Thalia's `-Demo` and the tour's practice page (`Demo.exchangeInbox`,
  here for Sunday 22 Nov. 2026): a workout (`Push`), two `ph` (one with a category chosen in the app,
  one without), `kcal` and `protein_g`. The demo builds the same files for its own day; a test keeps
  both equal.
- `Thalia/exchange/catalog.json` – structure only: goals, categories, measures, results; v11: `results[].source`
  where a result has one (`app:finn:net_worth`, `app:finn:account_balance=acc-giro`, `list:buch`) – Finn shows per
  row what it counts for in Thalia. Exactly what `ExchangeCatalog.thalia` writes (`V11Tests.swift`).
- `invalid/` – files a reader must refuse or partly skip, each with the reason in the test.
