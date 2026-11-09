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
| `week` | `2026-W46` (also `KW46 2026`) | | motto | context, priorities, exceptions, assumptions | `value` = reported score (history), `flags` `alt` = before KW42 |
| `day` | `2026-11-11` (or `Mi` inside a week) | | day type: Arbeitstag, Reisetag, Familientag, Erholungstag, Frei, Prüfungstag … | note ("Arbeit endet 15:00") | |
| `goal` | `1` … `10` | | annual goal | intent / outcome | |
| `category` | `1.1` | goal id | category | note | |
| `measure` | stable id (`protein`) | category id | name | hint | `unit`, `target`, `period`, `link` (source), `flags` (aggregation), `days` |
| `item` | `<category>-<nn>` (`1.1-03`) | category id | short, precise title | what counts as done | `days`, `schedule`, `target`, `link` (measure id), `flags` (`ko`) |

Results (export, backup, history) use `date`, `value`, `note`:

| type | id | columns |
|---|---|---|
| `mark` | item id | `date`, `value` = `1` / `0.5` / `0` / `na` (✓ ½ ✗ X N/A also read), `note` |
| `entry` | measure id | `date`, `value` (one value per measure and day), `flags` `schaetzung`, `unit` `text` for text values |
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

## Export

*Diese Woche als CSV* and *Alles als CSV (Sicherung)* write this format with results; editing the
file and importing it again updates. *Wochenbericht kopieren* gives the Markdown report for the
planning conversation (`WeekReport` in Core).
