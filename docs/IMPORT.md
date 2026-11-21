# Thalia – the CSV contract

One format for everything: the weekly plan ChatGPT writes, your own files, exports and backups.
The planning prompt (`PlanPrompt` in `Packages/ThaliaCore/Sources/ThaliaCore/Reports.swift`) gives
ChatGPT exactly this description, your current structure and last week's report.

```csv
type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
week,2026-W46,,Wiederholen statt steigern,"Annahme: Mittwoch frei, ersetzt die alte Arbeitsvorgabe",,,,,,,,,,
day,2026-11-11,,Frei,Feiertag – keine Arbeit.,,,,,,,,,,
measure,protein,1.1,Protein,,,,g,>=150,tag,health:protein,,,,
measure,stammloop_ph,3.2,stammloop,,,,PH,>=8,woche,arbeit:3.2,,,,
item,1.1-01,1.1,Protein erfassen,"Die tatsächliche Proteinmenge notieren; Schätzungen kennzeichnen.",täglich,fix,,,,protein,,,,
item,1.1-02,1.1,Proteinziel erreichen,150–180 g laut Wochenplan.,täglich,fix,,>=150,,protein,,,,
item,1.2-04,1.2,Tennis an der Wand,Wandeinheit mit Fokus auf die einhändige Rückhand.,"Di,Do,Sa",woche:2,,,,,,,,
item,4-03,4,Kein Bildschirm nach 23:00,Persönliche Regel: verletzt → Schlaf heute 0.,täglich,fix,,,,,ko,,,
```

Rows after a `week` row belong to that week. A plan has one `week` row, seven `day` rows,
the `measure` rows and the `item` rows (ten per category). `goal` / `category` rows only when the
structure changes.

## Row types

| type | id | parent | title | description | other columns |
|---|---|---|---|---|---|
| `week` | `2026-W46` (also `KW46 2026`) | | motto | context, priorities, exceptions, assumptions | `value` = reported score (history), `flags` `alt` = before KW42, `abgeschlossen` = week closed (backup) |
| `day` | `2026-11-11` (or `Mi` inside a week) | | day type: Arbeitstag, Reisetag, Familientag, Erholungstag, Frei, Krank, Urlaub, Prüfungstag … (Krank/Urlaub: the day doesn't count, see below) | note ("Arbeit endet 15:00") | `flags` `abgeschlossen` = day closed (backup) |
| `goal` | `1` … `10` | | annual goal | intent / outcome | |
| `category` | `1.1` | goal id | category | note | |
| `measure` | stable id (`protein`) | category id | name | hint | `unit`, `target`, `period`, `link` (source), `flags` (aggregation), `days` |
| `item` | `<category>-<nn>` (`1.1-03`) | category id | short, precise title | what counts as done | `days`, `schedule`, `target`, `link` (measure id), `flags` (`ko`) |

Results (export, backup, history) use `date`, `value`, `note`:

| type | id | columns |
|---|---|---|
| `mark` | item id | `date`, `value` = `1` / `0.5` / `0` / `na` (✓ ½ ✗ X N/A also read), `note` |
| `entry` | measure id | `date`, `value` (one value per measure and day), `flags` `schaetzung`, `unit` `text` for text values; single entries: one row each with `flags` `einzeln` and the time in `title` (`12:30`) |
| `work` | block id | `parent` category, `title` task, `description` result, `unit` `PH` / `h` / `ersatz`, `date`, `value` minutes, `note` next step |
| `note` | note id | `date`, `title` kind (beobachtung, ausloeser, erfolg, kontakt, idee), `description` |
| `review` | day or week | `title` question (verhalten, geholfen, gestoert, morgen · interpretation, wiederholen, reibung, ausserhalb, aendern, beibehalten), `description` |
| `score` | category id | `date`, `value` own score 0–10, `note` reason |

## Columns

- **days**: `täglich` · `Mo-Fr` · `Mo,Mi,Fr` · `Sa,So` · `werktags` · `Wochenende` (empty = every day).
  Days not listed are "not scheduled" – never "missed".
- **schedule**: `fix` (due on each of its days) · `woche:3` (3× a week on any of its days; what's left
  at the end of the week counts as missed) · `bedingt` (only when the situation occurs, else N/A) ·
  `optional` (recorded, never scored).
- **unit**: g, kcal, l, kg, min, h, PH, Stück, €, Seiten, Uhrzeit, %, Text.
- **target**: `>=150`, `<=6`, `<50`, `<=23:00`, `150-180`, `22:30-23:00` (≥ ≤ min. max. also read).
  Times after midnight count as late against an evening target (00:30 is later than 23:00).
- **period**: `tag` / `woche` – daily target or weekly total.
- **link**: on an item the id of a measurement whose value suggests the mark (with `target`: ✓ when
  met, ✗ when recorded and missed; without: ✓ as soon as something is recorded). On a measurement the
  source: empty (manual) · `arbeit:3.2` (from work blocks of 3.2: PH = focus minutes ÷ 50, h = real
  hours) · `health:sleep|bedtime|bodyMass|protein|energy|water|exercise|mindful|steps` (Apple Health suggestion).
- **flags**: item `ko` = personal zero rule. Measurement: `summe` · `letzter` · `schnitt` · `max` · `min`
  (default `summe`; kg, Uhrzeit and % → `letzter`).

## Reading rules

- Comma, semicolon, tab or `|` (detected); UTF-8, UTF-16 or Windows-1252; German header names
  (`typ`, `titel`, `beschreibung` …) are understood.
- A pasted ChatGPT answer is fine: the first fenced code block is taken.
- **Preview first** – per kind new / changed / same, items a revised plan drops ("entfallen"),
  warnings (a category without exactly ten items, unreadable days or targets, missing measurements)
  and skipped rows with the reason. Nothing changes until *Importieren*.
- Safe to repeat: rows are matched by id (week + item id, measure id + day …); importing the same
  file twice changes nothing.
- Weeks before KW42 2026 are marked "vor KW42" automatically (another scoring model).
- Everything is read on the device.

## Vergangene Wochen (past weeks, since 1.7.0)

*Vergangene Woche nachtragen* (`PastWeekImportView` in `App/Sources/PastImport.swift`; also under
*Vorlagen* in the plan import) brings in weeks from before the app or from a paper tracker. Three ways:

1. **Vom Plan** – the items and measurements of the nearest planned week (before or after the
   chosen one) are copied into it with the same ids, without marks, values and day types. The week
   table opens: tick off, set Krank/Urlaub days, close the week. A week that already has a plan is
   archived first (Undo in the toast).
2. **Mit ChatGPT** – one prompt (`PastWeekPrompt` in `Reports.swift`) for photos, PDFs or tables of one
   or many weeks. It holds the goals and categories, the items of the template week with their ids
   (the week itself if it has a plan, else the nearest planned week) and this format. Range:
   *Wochen aus den Unterlagen* (default – KW and dates are read from the attachments) or a fixed
   range from–to. The answer is one CSV with one block per week, oldest first. Paste it or choose
   the file; the preview lists each week (neu / ersetzt / ergänzt / unverändert, items, marks,
   Krank/Urlaub days, score, "wird abgeschlossen", the week's warnings).
3. **Nur Wertung** – a week and a number from 0 to 10 from paper (`WeekPlan.recordedScore`).

The weeks to choose from: last week back to the start of the goal year, at least 52 weeks.

### Format

The header gets the weekday columns (`PlanCSV.matrixHeader`):

```csv
type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note,mo,di,mi,do,fr,sa,so
week,,,,,,,,,,,,2026-10-19,6.8,,,,,,,,
week,2026-W44,,,,,,,,,,,,,,,,,,,,
day,Fr,,Krank,Erkältung,,,,,,,,,,,,,,,,,
day,Sa,,Krank,,,,,,,,,,,,,,,,,,
item,1.2-01,1.2,Krafttraining,,täglich,woche:3,,,,,,,,,✓,,½,,,,
item,4-03,4,Kein Bildschirm nach 23:00,,täglich,fix,,,,,ko,,,,✓,✓,✗,✓,,,✓
```

KW43 comes in with only its paper score 6,8 (found by its date); KW44 with two items, seven marks and
two sick days.

- **Weekday columns** `mo,di,mi,do,fr,sa,so` (also `montag` … `sonntag`, `mon` … `sun`) on `item` rows:
  one mark per day – `✓` / `1` erledigt, `½` / `0.5` teilweise, `✗` / `X` / `0` nicht erledigt,
  `–` / `N/A` entfällt; empty = no mark. An unreadable cell is listed under *Nicht gelesen*. The columns
  can be mixed with `mark` rows. The export stays in the long format (one `mark` row per item and
  day), so a round trip changes the layout, not the content.
- **Day rows by weekday** (`Mo` … `So`) belong to the week row above, so one block fits every week. A day
  row with only an id or date (no type, no note) changes nothing – empty template rows never clear a
  day type.
- **Krank / Urlaub:** a day type containing "krank" or "urlaub" (Krank, Urlaubstag …) excuses the day:
  nothing is due, its marks and own scores don't count, a weekly quota's share of such days counts
  half. A `day` row with that type is all the file needs.
- **Week row with only a date:** `id` empty and any date of the week in `date` – the week follows from it.
- **Only a score:** a `week` row with `value` and nothing else – a paper week. It shows in Rückblick and in
  the planning prompt's trend lines.
- **Marks on unknown items:** marks (rows or columns) on an item that is neither in the file nor in the
  app get one warning per week ("KW44: Markierungen für unbekannte Punkte …"). Items of a category
  the app doesn't have are skipped.

### What the import does with past weeks

- **Closing:** every week of the file before the current week – with items, marks or a week row – is
  closed, and so are its days with a mark or a day type (`Document.closingPast`). Days of such a week
  that the app already has a mark or a day type for are closed too, so a file with only some days
  leaves no marked day open (not the marks of a week the file replaces). A closed week gets
  its score as when closing it by hand, so it counts in Rückblick, Ziele, Ø 4 Wo. and the goal review.
  The current week and later ones stay open, with the warning "KW48: noch nicht vorbei – wird nicht
  abgeschlossen."
- **Leere Felder:** open by default – a due fixed item without a mark leaves its category day unscored.
  With *Leere Felder als ✗ zählen*, every blank field of a fixed, required item on its days counts as
  ✗ (never on a free day for work items, never on a Krank/Urlaub day; `Document.fillingBlanks`). Quotas
  ("n× pro Woche"), progress, conditional and secondary items stay blank – the week's rules settle
  them. Only weeks the file brings items or marks for are filled; a week without item rows is filled
  on the app's plan, and marks the app already has stay.
- **Replacing:** a week that already has a different plan is replaced as for a plan import – the old
  plan goes with its marks and values to the archive (Einstellungen → Archiv), Undo in the toast.
- **Which score counts:** a closed week with items shows its computed score; a reported `value` counts
  only where there is none (`historyScore = finalScore ?? recordedScore`). Weeks before KW42 2026 are
  marked "vor KW42" (other model) and are not averaged with later ones.

## Export

*Diese Woche als CSV* and *Alles als CSV (Sicherung)* write this format with results; editing the
file and importing it again updates. *Wochenbericht kopieren* gives the Markdown report for the
planning conversation (`WeekReport` in Core).

### Backups since version 1.6.0

A backup keeps everything needed to restore a day exactly:

- **Closings:** `day` and `week` rows carry the flag `abgeschlossen` when the day or week was
  closed. A closed day without type or note still gets its own `day` row (title and description
  empty). Importing such a file closes those days again; closed weeks get their score as when
  closing them by hand. The preview lists them: "Abschlüsse: 3 Tage, 1 Woche".
- **Single entries:** when a measurement has several entries on one day – and always for spendings
  (€) – each entry is its own `entry` row with the flag `einzeln` (plus `schaetzung` if estimated),
  the time of day in `title` (`12:30`), its own `value` and `note` ("Wofür"):

  ```csv
  type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
  entry,ausgaben,,08:10,,,,,,,,einzeln,2026-11-16,4.5,Kaffee
  entry,ausgaben,,12:30,,,,,,,,einzeln,2026-11-16,12.9,Mittagessen
  ```

  Importing replaces the day's entries of that measurement with these rows, one by one at their time.
- **Newest version:** where iCloud holds a record twice, the backup takes the most recently changed one.

**Older app versions** (before 1.6.0) ignore the flag `abgeschlossen` and read only the **last**
`einzeln` row of a measurement and day. Older backups and ChatGPT files without `einzeln` rows are
compared by the day's total only: a file with the same total counts as unchanged and never merges
single spendings into one row.
