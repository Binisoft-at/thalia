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
| `mark` | item id | `date`, `value` = `1` / `0.5` / `0` / `na` (✓ ½ ✗ X N/A also read), `note`; an empty `value` is a cleared mark (since 1.9.0 the export writes one when it has a note or keeps a connected app's ✓ away) |
| `entry` | measure id | `date`, `value` (one value per measure and day), `flags` `schaetzung`, `unit` `text` for text values; single entries: one row each with `flags` `einzeln` and the time in `title` (`12:30`) |
| `work` | block id | `parent` category, `title` task, `description` result, `unit` `PH` / `h` / `ersatz`, `date`, `value` minutes, `note` next step |
| `note` | note id | `date`, `title` kind (beobachtung, ausloeser, erfolg, kontakt, idee), `description` |
| `review` | day or week | `title` question (verhalten, geholfen, gestoert, morgen · interpretation, wiederholen, reibung, ausserhalb, aendern, beibehalten), `description` |
| `score` | category id | `date`, `value` own score 0–10, `note` reason |
| `category_score` | today's category or empty | `title` label as in the records, `date` (day grade) or empty (week grade), `value` 0–10, `note` source, `count` (since 1.8.0, see „Archiv-Wochen“) |
| `goal_score` | annual goal `1` … `10` or empty | `title` label as in the records, `value` 0–10, `note` source, `count` (since 1.8.0) |
| `record` | a stored record's key (`goal.result.<id>`, `list.progress.2026-11-17.<id>`, `x.theo.2026-11-22` …; since 1.10.0 also `goal.start`, `goal.end`, `goal.review`, `goal.motto`, `exchange.catalog`) | `note` = its value (JSON; `score.<week>` and the goal year plain text) – backups only, since 1.9.0, see „Datensätze“ |
| `sicherung` | the moment of the backup, ISO 8601 UTC (`2026-11-22T17:03:00.000Z`) | `title` app and build (`Thalia 1.10.0 (58)`), `description` kind of device (`iPhone`, `Mac` – never its name) – the first data row of a full backup, since 1.10.0, see „Sicherung“ |
| `wertung` | a closed week (`2026-W47`) | `value` its stored score exactly as stored (`7.123456`), `note` the goal scores (`1=8.2;2=7.5`), `count` how many goals were scored – full backups only, at the end of the week's block, since 1.10.0 |
| `change` | the code of an item or measurement | `parent` `Punkt` / `Messwert`, `title`, `description`, `value` `neu` / `geändert` / `gelöscht`, `flags` `dauerhaft` / `einmalig` – a plan change of an archive snapshot, inside its week's block, since 1.10.0 |

## Columns

- **days**: `täglich` · `Mo-Fr` · `Mo,Mi,Fr` · `Sa,So` · `werktags` · `Wochenende` (empty = every day).
  Days not listed are "not scheduled" – never "missed".
- **schedule**: `fix` (due on each of its days) · `woche:3` (3× a week on any of its days; what's left
  at the end of the week counts as missed) · `bedingt` (only when the situation occurs, else N/A) ·
  `optional` (recorded, never scored).
- **unit**: g, kcal, l, kg, min, h, PH, Stück, €, Seiten, Uhrzeit, %, Text.
- **target**: `>=150`, `<=6`, `<50`, `<=23:00`, `150-180`, `22:30-23:00` (≥ ≤ min. max. also read).
  Times after midnight count as late against an evening target (00:30 is later than 23:00).
  Since 1.10.0 the words in front are read as whole words – `spätestens`, `bis`, `bis zu`, `höchstens`, `maximal`, `max`,
  `nicht mehr als` = ≤; `weniger als`, `unter` = <; `frühestens`, `ab`, `mindestens`, `min` = ≥; `mehr als`, `über` = >;
  `22:30 bis 23:00` is a range – and the file is read strictly: a target that starts with another word (`ca 150`) is not
  read (warning "Zeile 7: Ziel “ca 150” nicht lesbar – ignoriert"), a unit behind it stays allowed (`≥150 g`). A result's target in a
  `record` row is stored as the plain form (`spätestens 23:00` → `<=23:00`), so every version reads it the same way.
- **numbers** (values, own scores, `count`, the numbers of targets – since 1.10.0 one reader for all of them): a single dot
  is a decimal point (`1.125` = 1,125), a single comma a decimal comma (`2,5`), both together German grouping
  (`8.000,5`); spaces are left out; anything else (`nan`, `1e5`, more than one comma) is not read. A single dot with
  exactly three digits behind it reads as a decimal point too, with a warning: "Zeile 4: „8.000“ als 8 gelesen –
  Tausenderpunkt? Bitte 8000 schreiben" (versions before 1.10.0 read such a value as 8000). Write numbers without a
  thousands dot. The export writes a value with exactly three decimals with a fourth zero (`1.1250`), so no reader –
  older versions included – takes it for a thousands dot.
- **period**: `tag` / `woche` – daily target or weekly total.
- **link**: on an item the id of a measurement whose value suggests the mark (with `target`: ✓ when
  met, ✗ when recorded and missed; without: ✓ as soon as something is recorded). On a measurement the
  source: empty (manual) · `arbeit:3.2` (from work blocks of 3.2: PH = focus minutes ÷ 50, h = real
  hours) · `health:sleep|bedtime|bodyMass|protein|energy|water|exercise|mindful|steps` (Apple Health suggestion)
  · since 1.9.0 `list:buch` (pages read in the reading list) and `app:<source>:<kind|metric>[=<ref>]` (a connected
  app) – see „Verbundene Apps und Leseliste“. Since 1.9.0 an item may also link such a text directly
  (`app:theo:task`) instead of a measurement id. A source this version doesn't know (`health:carbs`, a newer
  version's text) is kept unchanged and acts as manual.
- **flags**: item `ko` = personal zero rule. Measurement: `summe` · `letzter` · `schnitt` · `max` · `min`
  (default `summe`; kg, Uhrzeit and % → `letzter`).

## Reading rules

- Comma, semicolon, tab or `|` (detected); UTF-8, UTF-16 or Windows-1252; German header names
  (`typ`, `titel`, `beschreibung` …) are understood.
- A pasted ChatGPT answer is fine: the first fenced code block is taken (since 1.8.0 a warning names more
  than one CSV block – all weeks belong in one).
- **Preview first** – per kind new / changed / same, items a revised plan drops ("entfallen"),
  warnings (a category without exactly ten items, unreadable days or targets, missing measurements)
  and skipped rows with the reason. Nothing changes until *Importieren*.
- Safe to repeat: rows are matched by id (week + item id, measure id + day …); importing the same
  file twice changes nothing.
- Weeks before KW42 2026 are marked "vor KW42" automatically (another scoring model).
- **Links stay over the weeks (since 1.9.0):** a `measure` row without `link` keeps the source the app has for
  that id – in the same week, else in the nearest earlier week (any source: `arbeit:`, `health:`, `app:`,
  `list:`). A source set back to manual stays manual. The preview says so once per week, e.g. "KW48: bisherige
  Quelle übernommen, die Datei nennt keine – „Workouts“ (app:george:workout=tpl-1, aus KW47)".
- Everything is read on the device.

## Vergangene Wochen (past weeks, since 1.7.0)

*Vergangene Woche nachtragen* (`PastWeekImportView` in `App/Sources/PastImport.swift`; also under
*Vorlagen* in the plan import) brings in weeks from before the app or from a paper tracker. Three ways:

1. **Vom Plan** – the items and measurements of the nearest planned week (before or after the
   chosen one) are copied into it with the same ids, without marks, values and day types. The week
   table opens: tick off, set Krank/Urlaub days, close the week. A week that already has a plan is
   archived first (Undo in the toast).
2. **Mit ChatGPT** – one prompt (`PastWeekPrompt` in `Reports.swift`) for photos, PDFs or tables of one
   or many weeks. It holds the archive rules (nothing invented, a real 0 stays 0), the goals, categories
   and measurements with their ids, the items of the template week with their ids – only as a reference
   for marks the records really show (the week itself if it has a plan, else the nearest planned week) –
   and this format. Range:
   *Wochen aus den Unterlagen* (default – KW and dates are read from the attachments) or a fixed
   range from–to. The answer is one CSV with one block per week, oldest first. Paste it or choose
   the file; the preview lists each week (neu / ersetzt / ergänzt / unverändert, items, marks,
   category and goal grades, Krank/Urlaub days, "Wertung … laut Unterlagen", "wird abgeschlossen", the
   week's warnings). Since 1.8.0 a block may hold only the week's value and grades (see „Archiv-Wochen“),
   and the switch *Archivdaten dieser Wochen ersetzen* is there for a repeated import. The prompt asks to
   make an earlier CSV anew by these rules, and its example uses the placeholder `JJJJ-Wnn` as week id, so
   the prompt pasted back (or the example copied into an answer) lands in no week.
3. **Nur Wertung** – a week and a number from 0 to 10 from paper (`WeekPlan.recordedScore`, the value
   "laut Unterlagen").

The weeks to choose from: last week back to the start of the goal year, at least 52 weeks.

### Format

The header gets the weekday columns (`PlanCSV.matrixHeader`; since 1.8.0 the prompt asks for
`PastWeekPrompt.header`, which also has `count` before `mo`):

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
  day type. Since 1.8.0 a day row dated in another week than its block is skipped with the reason
  ("Tag 2026-11-10 liegt nicht in KW43 – gehört in den Block seiner Woche"), never moved to that week.
- **Krank / Urlaub:** a day type containing "krank" or "urlaub" (Krank, Urlaubstag …) excuses the day:
  nothing is due, its marks and own scores don't count, a weekly quota's share of such days counts
  half. A `day` row with that type is all the file needs.
- **Week row with only a date:** `id` empty and any date of the week in `date` – the week follows from it.
- **Only a score:** a `week` row with `value` and nothing else – a paper week (since 1.8.0 an archive week:
  no items, nothing open or missed). It shows in Rückblick and in the planning prompt's trend lines.
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
  them. Only weeks the file brings items or marks for are filled; a week with marks but without item
  rows is filled on the app's plan, and marks the app already has stay. Archive weeks (no item rows and
  no marks, since 1.8.0) are never filled – not even on the plan the app has for them.
- **Replacing:** a week that already has a different plan is replaced as for a plan import – the old
  plan goes with its marks and values to the archive (Einstellungen → Archiv), Undo in the toast.
- **Week rows (since 1.8.0):** an empty motto or context in the file keeps the app's (the prompt never
  writes one). An empty or unreadable value keeps the app's value laut Unterlagen – unless the week is
  replaced ("Archivdaten ersetzen"). This week and later ones never take a value from the file ("KW47: noch
  nicht vorbei – der Wochenwert wird nicht übernommen."): it would stand in for the running score.
- **Which score counts:** since 1.8.0 the reported `value` ("laut Unterlagen") wins wherever there is
  one, the computed score counts where there is none (`historyScore = recordedScore ?? finalScore`,
  `WeekLine.historyScore`) – in Rückblick, Ø, Ziele, PDF and widgets. The week shows both, named. (1.7.0
  had it the other way round.) Weeks before KW42 2026 are marked "vor KW42" (other model) and are not
  averaged with later ones.

## Archiv-Wochen (seit 1.8.0)

Old records often keep less than the app: the week's value, perhaps the day types, and the grades
(0–10) of categories and annual goals – no single marks, no working times, no measurements. Such a
week comes in as an **archive week**: a week of the file with a `week` row or grades, but without
`item` rows and without marks (`Document.archiveWeeks`). The import never creates items or
measurements for it, *Leere Felder als ✗ zählen* never fills it, and it is closed like every past
week – nothing is open and nothing is missed. Plan: [TASKS-v9.md](TASKS-v9.md).

```csv
type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note,count,mo,di,mi,do,fr,sa,so
week,2026-W43,,,,,,,,,,,,9.28,Scan S. 19,,,,,,,,
day,Sa,,Urlaub,,,,,,,,,,,,,,,,,,,
category_score,1.2,,Sport / Verein,,,,,,,,,2026-10-19,0,Scan S. 19,,,,,,,,
category_score,1.2,,Sport / Verein,,,,,,,,,2026-10-20,10,Scan S. 19,,,,,,,,
category_score,1.2,,Sport / Verein,,,,,,,,,2026-10-21,10,Scan S. 19,,,,,,,,
category_score,1.2,,Sport / Verein,,,,,,,,,2026-10-24,4,Scan S. 19,,,,,,,,
category_score,5,,Lesen,,,,,,,,,,8.5,Scan S. 19,4,,,,,,,
category_score,,,Sonderwoche,,,,,,,,,,9,Scan S. 19,,,,,,,,
goal_score,1,,Gesundheit,,,,,,,,,,7.5,Scan S. 19,,,,,,,,
week,2026-W44,,,,,,,,,,,,9.19,Scan S. 21,,,,,,,,
```

KW43: value 9,28 from the records, Saturday a holiday, four day grades of "Sport / Verein" (category
1.2, a real 0 on Monday), a week grade for "Lesen" (only the mean is in the records, 4 valid days),
"Sonderwoche" without mapping and a goal grade for goal 1. KW44: only its value 9,19 – the block is
this one row.

### Row types

- **`category_score`** – a category's grade 0–10.
  `id` = today's category (`1.2`) only when it is clearly the same, else empty (old combined or extra
  categories are never split or re-read); `title` = the label exactly as in the records (required);
  `date` = the day for a day grade, empty for a week grade (only when the records give just the
  mean); `value` 0–10 (comma or point); `note` = source; `count` = valid days behind a week grade
  (optional). Day grades and a week grade of the same label don't belong together – Thalia takes
  the mean of the day grades itself.
- **`goal_score`** – an annual goal's grade 0–10 for the week. `id` = goal `1` … `10` (empty when
  unclear); `title` = the label as in the records; `value`; `note` = source; `count` optional. A goal
  grade is never spread over categories; a date on it must lie in its block's week and is not used
  otherwise. Where the records grade each annual goal on its own line (even if they call it a
  category), that is a `goal_score` with the goal's id.
- **Column `count`** (also `anzahl`, `n`): 1–7; anything else gets a warning and is ignored. The writer
  adds the column only when a document has grades, so every other export keeps its header.
- **Type aliases:** `kategorie_note`, `kategoriennote`, `kategorienote`, `categoryscore`,
  `category-score`, `kategorie-note`; `ziel_note`, `zielnote`, `goalscore`, `goal-score`, `ziel-note`,
  `jahresziel_note`.
- **Skipped with a reason:** no `title`, an empty or unreadable value, a value outside 0–10, an
  unreadable date, any grade before the first `week` row, a date in another week than its block
  ("… liegt nicht in KW43 – gehört in den Block seiner Woche"; never moved there), and shifted columns:
  a decimal comma without quotes (`…,6,67,Scan S. 3,…`) reads as value 6 and source 67, so a row whose
  value and following cell are both plain digits, or that has filled cells beyond the header, is skipped
  ("Spalten verrutscht – … Dezimalkomma?"). Write `6.67` or `"6,67"`.
- **Weekday columns:** a `category_score` row may carry its day grades in `mo` … `so` instead of one row per
  day (each filled cell is a day grade, checked like `value`); on a `goal_score` row they are skipped. The
  prompt still asks for one row per day.
- **Two labels, one id:** when two different labels get the same id for the same day (or both as a week
  grade), only the last stays, with a warning under the week ("KW43 Mo: zwei Noten für 1.1 („Sport“,
  „Verein“) – nur die letzte bleibt; bei unklarer Zuordnung id leer lassen.").
- **No mapping:** an `id` that is neither a category or goal of the app nor of the file is cleared
  ("KW43: „Sonderwoche“ – 9.9 ist keine Kategorie der App; die Note bleibt ohne Zuordnung im Archiv.").
  Grades without mapping are kept with their label and shown under „Ohne Zuordnung (Archiv)“; they
  never count. Each week lists them once in the preview.
- **`week` row:** `value` is the value from the records, read like a grade ("9.28" and "9,28" are both
  9,28). Unreadable ("ca. 9"), outside 0–10 or in a row with shifted columns it is not taken, with a
  warning – the app keeps its value. Its `note` is the source (with German headers the column `quelle`);
  it is kept only for a week with a value or grades. The export writes the value exactly, so a backup
  reads back unchanged.
- **No measurements in archive weeks:** `measure` rows in a week without items are dropped with a warning
  ("KW43: Messwert „Seiten“ nicht übernommen – eine Woche ohne Punkte bekommt keine Messwerte.") – a weekly
  target nothing can meet would count as missed. `entry` values stay.
- **Items and grades in one week:** a week with item rows is scored by its items; its grades are kept
  but don't count today (warning "KW43: Punkte und Noten – nach heutigen Regeln zählen nur die Punkte, die
  Noten stehen im Archiv.").
- **Repeatable:** a grade's key is week · kind · day (or "woche") · id (or the normalized title).
  Importing the same file twice changes nothing; a changed value updates its grade.
- **Storage:** no new iCloud field – the grades of a week live as CSV in the setting
  `archive.2026-W43` (`ArchiveWeek.csv`), the value in `WeekPlan.recordedScore`. Backups
  (*Sicherung erstellen…*) carry the grade rows and the source.

### Two scores, clearly named

- **Wertung laut Unterlagen** = `week.value` (or *Nur Wertung*). Never calculated or overwritten – only a
  new import or *Nur Wertung* changes it.
- **Nach heutigen Regeln** = `WeekPlan.finalScore`. For a week with items the Scorer, as always. For an
  archive week (`ArchiveWeek.recalculated`): a category (mapped, the app has it) = the mean of its day
  grades **without Krank/Urlaub days**; with only a week grade that one. A goal = the mean of its
  categories; without any, its `goal_score`. The week = the mean of the goal values (equally weighted);
  open without values. Grades without mapping never count. The goal values go to `finalGoalScores`, so
  goal charts, the goal review and the PDF have them once the week is closed; a week with only a value
  (no grades) stays out of the goal charts and the goal review, as paper weeks did before.
- **Means:** sum of the valid grades ÷ their number; empty, crossed-out or unreadable fields have no
  row and don't count; a real 0 counts; n = 0 → open; only the result is rounded (two places, on
  display). (0 + 10 + 10) / 3 = 6,67 · (10 + 10 + 0 + 0) / 4 = 5. In the example: "Sport / Verein" is
  Ø 6 (4) as recorded and 6,67 (3) nach heutigen Regeln (the holiday Saturday left out) – the grade on
  Saturday stays in the archive.
- **Where they show:** the week's card „Archiv“ (iPhone below the head, Mac in the table and the side
  panel) names both: "Wertung laut Unterlagen 9,28" and "Nach heutigen Regeln 7,58 · ohne 1 Urlaubstag";
  a missing one is "–" with a short reason. Below it the category grades (label from the records, the
  app's category under it, Mo–So, Ø (n)), the goal grades and „Ohne Zuordnung (Archiv)“. Grades on
  Krank/Urlaub days are dimmed ("zählt heute nicht"). The head of a week without items shows the value
  laut Unterlagen. Rückblick rows and the PDF report tag such weeks „Archiv“ (instead of „Papier“); the
  PDF adds "Archiv: Wertung laut Unterlagen; Zielfelder laut Unterlagen oder nach heutigen Regeln aus den
  Kategoriennoten."

### Archivdaten dieser Wochen ersetzen

A supplementing import never removes anything: items, marks or values from an earlier, faulty import
stay. For a repeated import the window *Vergangene Woche nachtragen* → *Mit ChatGPT* has the switch
**Archivdaten dieser Wochen ersetzen** (off by default). With it, every past week with a `week` row in
the file that the app has something for goes to the archive completely before the import – items,
measurement definitions, marks, values, own day scores, day closings, day types and the days'
„Besonderheit“, the archive grades, the value laut Unterlagen, the week's closing and scores – and comes
from the file anew. Only weeks with a `week` row: a stray day row or grade never reaches another week (it
is skipped, see above). A week the file brings exactly as the app has it is left alone, so the same file
twice makes no second snapshot. Work blocks, notes (Notizen) and reflections stay, and so do the motto and
context when the file's week row has none. The preview says "ersetzt" and lists what goes ("KW43 wird
ersetzt – 63 Punkte, 120 Markierungen, 22 Noten und die Wertung gehen ins Archiv."; with marks and no
single marks in the file also "KW45: 80 Markierungen aus der App gehen ins Archiv – die Datei bringt keine
Einzelhaken."); importing asks first. *Widerrufen* in the toast and Einstellungen → Archiv bring it all
back; when the week was edited after the import, Undo keeps a snapshot of that state in Einstellungen →
Archiv. This week and later ones are never replaced ("KWnn: noch nicht vorbei – wird nicht ersetzt, nur
ergänzt."). Without the switch, an archive week that still has items in the app gets a warning: "KW43: in
der App noch 63 Punkte ohne Markierungen – ‚Archivdaten ersetzen‘ entfernt sie." or, with marks, "KW45: in
der App noch 24 Punkte mit 80 Markierungen – ‚Archivdaten ersetzen‘ nur wählen, wenn sie aus einem
fehlerhaften Import stammen; es verschiebt alles ins Archiv."

**Careful with weeks tracked in the app:** the switch doesn't know where the app's items and marks came
from. A week that was really tracked in the app and is in the file only with its value goes to the
archive too. Leave such weeks out of the file (or import without the switch); Undo and Einstellungen →
Archiv bring them back if it happened.

Nothing is reconstructed: the app never turns grades into marks or measurements, never splits a
combined category and never multiplies a goal grade onto its categories. Missing single marks,
working times and measurements stay unknown.

## Verbundene Apps und Leseliste (since 1.9.0)

Two more sources for a `measure` row's `link`. Their values are **computed** every time – never stored as
entries – and an own entry for the same measurement and day replaces them (spending adds up instead). Confirmed
Apple Health values come before them. How the other apps deliver: [CONNECTED_APPS.md](CONNECTED_APPS.md).

| `link` | Day value |
|---|---|
| `list:buch` | pages read in all reading-list entries of that kind – per entry the increase over its highest earlier reading, never negative (`list:hoerbuch`, `list:kurs` … for other kinds) |
| `app:george:workout=<ref>` | number of workouts of that template (`ref` from George's `source.json`); `app:george:workout` counts all |
| `app:theo:task` | tasks done whose group is mapped to the measurement's category; `app:theo:task=<ref>` the tasks of one group |
| `app:theo:ph` | power-hours (sum); `=<ref>` for one group |
| `app:nina:kcal` | the day's value (also `protein_g`, `carbs_g`, `fat_g`, `water_ml`) |
| `app:finn:spending` | the day's spending (unit `€`); Finn's rows show read-only, own spendings add up; `=<ref>` for one group |
| `app:finn:net_worth` | the latest value of the day – give such a measurement the flag `letzter` (also `savings_rate`, `body_weight_kg`) |

The general form is `app:<source>:<kind|metric>[=<ref>]`: `<source>` is the app's id (`theo`, `george`, `nina`,
`finn` …), `<kind>` one of `workout`, `task`, `habit`, `ph`, `spending` (counted or summed), or a metric of the
table (`kcal`, `protein_g`, `carbs_g`, `fat_g`, `water_ml`, `net_worth`, `savings_rate`, `body_weight_kg`);
`=<ref>` keeps only the facts with that id. A text that doesn't read as one stays unchanged as an unknown source.
Power-hours from a connected app also count for the `arbeit:` measurement of their category, like own work blocks.

```csv
type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
measure,workouts,1.2,Workouts,,,,Stück,>=3,woche,app:george:workout=tpl-1,,,,
item,1.2-01,1.2,Krafttraining,Workout aus der Vorlage „Push“.,"Mo,Mi,Fr",fix,,,,workouts,,,,
measure,seiten,5,Seiten,,,,Seiten,>=20,tag,list:buch,,,,
item,5-01,5,Lesen,20 Seiten.,täglich,fix,,>=20,,seiten,,,,
item,3.2-04,3.2,Kundenaufgabe erledigt,Mindestens eine Aufgabe aus Theo.,Mo-Fr,fix,,,,app:theo:task,,,,
```

- **Derived ticks:** an item linked to such a measurement gets ✓ "⇄ George · Push" on a day it applies and that isn't
  excused, when the target is met (without a target: a value of at least 1) – as long as there is no own mark (a
  cleared mark counts as own). Otherwise the usual suggestion.
- **Direct links:** `item,3.2-04,…,app:theo:task` links the item to the text itself; Thalia adds a hidden
  measurement for it in the item's category. The check accepts `app:…` and `list:…` links without a measure row
  (no "verknüpfter Messwert fehlt").
- **Kept over the weeks:** the planning prompt names these values and asks ChatGPT to take every link of the source
  plan over unchanged ("Verknüpfungen aus dem Ausgangsplan unverändert übernehmen"); a measure row without `link` keeps
  the previous week's source anyway (see „Reading rules“).
- Measurement sources are also set in the app: measure editor → „Quelle“ → Manuell / Power-Hours / Apple Health /
  Leseliste / Verbundene App (app → kind → entry from the app's `source.json`).

## Datensätze (`record`, since 1.9.0)

The annual goals' results and their entries, the segments, the reading list and its readings, the mappings of
other apps' groups, the connected apps' inbox and the category week scores are stored as JSON in settings – no
new iCloud fields. A backup carries each as one `record` row: `id` = the setting's key, `note` = its value, all
other columns empty. Alias: `datensatz`, `records`.

```csv
type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
record,list.progress.2026-11-17.5d0e…,,,,,,,,,,,,,"{""day"":""2026-11-17"",""id"":""5d0e…"",""item"":""b2a9…"",""modifiedAt"":""2026-11-17T20:15:00.000Z"",""note"":"""",""reached"":120,""v"":1}"
record,score.2026-W47,,,,,,,,,,,,,1.1=8.2;1.2=6.5
```

| Key | What |
|---|---|
| `goal.result.<id>` | a result of an annual goal (check / count / value, target, target per segment, source) |
| `goal.entry.<JJJJ-MM-TT>.<id>` | one dated entry of a result (tick, +1, value) |
| `goal.segment.<id>` | a segment of the goal year, with the goals and categories at its start |
| `list.item.<id>` | a reading-list entry (book, course …) |
| `list.progress.<JJJJ-MM-TT>.<id>` | one reading ("bis Seite 120") |
| `link.rule.<id>` | a group of another app mapped to a category |
| `x.<source>.<JJJJ-MM-TT>` | a connected app's day file as Thalia received it |
| `x.sources` | the connected apps seen (their `source.json`) |
| `score.<week>` | the category week scores, plain text `1.1=8.2;1.2=6.5` (not JSON) |
| `goal.start`, `goal.end` | since 1.10.0: the goal year, plain text `2026-06-01` |
| `goal.review`, `goal.motto` | since 1.10.0: the review week (`2027-W22`) and the motto, plain text |
| `exchange.catalog` | since 1.10.0: „Thalia-Katalog bereitstellen“, `an` / `aus` |

- **Reading:** only keys with these prefixes (and the five plain settings); anything else is skipped ("Zeile 12:
  Datensatz “rescore.2026-W47” wird nicht gelesen (unbekannter Schlüssel)") – never a request to score a week again
  (`rescore.`), a device's build (`sync.build.`), the last backup (`backup.last`) or shared Health values (`hshare.`).
  So are an empty `note` ("… ohne Inhalt (note)"), a value that isn't a JSON object, except for `score.` and the plain
  settings ("… ist kein lesbares JSON"), and a goal year that isn't a date ("… nicht lesbar"). Two rows with the same
  key: the last one counts, with a warning. Archive grades stay in their `category_score` / `goal_score` rows
  (`archive.<week>` is no `record`).
- **Importing:** by key. A stored record with a newer `modifiedAt` (day files: `generatedAt`) stays as it is; without
  a time stamp (`score.`) the file wins when it differs. `x.sources` is merged, never replaced: a connected app the app
  knows and the file doesn't stays (an older backup never drops one). A day file `x.<source>.<day>` keeps only facts
  with `origin` `app` – values from Apple Health never come in; a row that isn't a day file of that source and day is
  skipped ("… ist kein lesbarer Tag einer verbundenen App"). The preview has the line „Datensätze“ (new, changed,
  same); importing the same file twice changes nothing. Fields this version doesn't know are kept.
  Since 1.10.0: **the goal year and the catalog switch are only filled in** where the app has no value – they carry no
  time stamp, and an old backup must not replace a new goal year; when they differ the preview says so in orange
  ("Zieljahr in der Datei: 1.6.2026–31.5.2027 – in der App bleibt 1.6.2027–31.5.2028."). They are written before the
  results and segments. **An entry or reading moved to another day** (its key has the day) counts once: when the app
  holds the same id under another day's key, the newer copy wins – the file's newer copy is written and the app's old
  key goes; the app's newer copy stays (the row counts as unchanged). A result's target is stored in its plain form.
- **Writing:** *Sicherung erstellen…* writes every record, the inbox `x.` included – Thalia never deletes it,
  and it is the only long-term copy (the other apps remove their files after 62 days). A day file goes out only with
  facts with `origin` `app`, and a day stored twice (two devices before they synced) goes out as the copy the weeks
  read; since 1.10.0 an entry or reading stored under two days goes out once (its newest copy), and the goal year and
  the catalog switch go out first. The rows come last, sorted by
  key, and only when there are any, so every other file stays exactly as before. *Diese Woche als CSV*, the week
  export for ChatGPT and the planning prompt have no `record` rows.
- Versions before 1.9.0 skip the rows ("unbekannter Typ"); 1.9.0 skips the five plain settings ("unbekannter
  Schlüssel").

## Export

*Diese Woche als CSV* and *Sicherung erstellen (alles als CSV)* write this format with results; editing the
file and importing it again updates. Since 1.9.0 the backup also ends with the `record` rows (results, reading
list, segments, mappings, the connected apps' inbox, category week scores – see „Datensätze“). Since 1.10.0 the
backup has one name everywhere – *Sicherung erstellen…* in Einstellungen → Deine Daten and in the Mac's Ablage menu,
*Sicherung erstellen (alles als CSV)* in this window – and is built off the main thread ("Sicherung wird erstellt …");
see „Sicherung (seit 1.10.0)“.
*Wochenbericht kopieren* gives the Markdown report for the planning conversation (`WeekReport` in Core); since
1.9.0 it and the planning prompt carry the block "Jahresziel-Ergebnisse (nur zur Info – nichts unaufgefordert
steigern)" with each result's state, target and status – never Apple Health values.

### Backups since version 1.6.0

A backup keeps everything needed to restore a day exactly:

- **Closings:** `day` and `week` rows carry the flag `abgeschlossen` when the day or week was
  closed. A closed day without type or note still gets its own `day` row (title and description
  empty). Importing such a file closes those days again; closed weeks get their score as when
  closing them by hand (since 1.10.0 a backup's `wertung` row keeps the stored score instead, see „Sicherung“). The
  preview lists them: "Abschlüsse: 3 Tage, 1 Woche".
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

## Sicherung (seit 1.10.0)

Plan: [TASKS-v11.md](TASKS-v11.md) (P3). A full backup (*Sicherung erstellen…*) restores the app as it was – with
when and where it was made, the stored week scores, the goal year and the plan changes of archived weeks:

```csv
type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note,count
sicherung,2026-11-22T17:03:00.000Z,,Thalia 1.10.0 (58),iPhone,,,,,,,,,,,
week,2026-W47,,Wiederholen statt steigern,,,,,,,,abgeschlossen,2026-11-16,,,
entry,gewicht,,07:10,,,,,,,,,2026-11-17,1.1250,,
wertung,2026-W47,,,,,,,,,,,,7.123456,1=8.2;2=7.5,2
record,goal.start,,,,,,,,,,,,,2026-06-01,
```

- **`sicherung`** – the first data row of a full backup: `id` the moment in UTC (the same text on every device),
  `title` app and build, `description` the kind of device (never its name). The preview's head says "Sicherung vom
  22.11.2026, 18:03 · Thalia 1.10.0 (58) · iPhone" instead of the list of weeks. Only "Sicherung erstellen" writes it.
- **`wertung`** – at the end of every closed week's block that has a stored score: `value` exactly as stored (it reads
  back to the same bits), `note` the goal scores as stored, `count` the number of scored goals (missing or unreadable:
  counted from the goal scores; outside 0–10: skipped). Importing keeps it: the week is closed (if it is open), gets
  the three fields and the file's `score.<week>`, and is **not scored again** – also not on an iPhone, and on a Mac,
  Apple Watch or iPad it sends no request to the iPhone. A backup without these rows (older versions) is imported as
  before: the closed weeks get their score as when closing them by hand. The preview line is „Wochenwertungen“.
- **Who scores after an import:** an import is one save and counts as maintenance. A closed week it changes (marks,
  values, archive grades …) gets its score again on the iPhone; a Mac, Apple Watch or iPad never scores it there and asks
  the iPhone instead (`rescore.<week>`). Weeks before the current segment keep their score, as before. A week the
  import closes (also *Widerrufen*) gets the closing's score – on a Mac, Apple Watch or iPad only when it reads no Apple
  Health values there (or the TestFlight sharing covers it); otherwise it stays without a score of its own and the
  iPhone scores it after the sync (a request with `force`). A freshly installed iPhone doesn't score such a week from
  before its install.
- **`change`** – only in archive snapshots (Einstellungen → Archiv): the week's plan changes ("Auch in den nächsten
  Wochen"), so restoring the snapshot or *Widerrufen* after replacing a week brings them back; a change the week has
  again since is not doubled. A full backup has none, and the archive itself (`WeekArchive`) is not in the backup.
- **Single values keep their time:** a value that is the only one of its measurement and day carries its time of day in
  `title` (`07:10`) and comes back at that time; a re-import stays "unverändert". Work blocks and notes go out in the
  order they were made and come back in that order.
- **Marks of deleted items** stay out of a full backup (never out of an archive snapshot or a week's CSV).
- **Values with three decimals** get a fourth zero (`1.1250`), see „Columns“ → numbers.
- **The goal year** (`goal.start`, `goal.end`, `goal.review`, `goal.motto`) and „Thalia-Katalog bereitstellen“
  (`exchange.catalog`) are `record` rows; the import only fills them in (see „Datensätze“) – with a very old time stamp,
  so the real value that iCloud brings later wins. The same holds for a closed week a restore creates with its `wertung`.
- **Never in a backup:** shared Health values, the requests to score a week again (`rescore.`), the devices' builds
  (`sync.build.`), the last backup (`backup.last`) – and, as before, values from Apple Health and the settings of this
  device.

### Reading a backup in

- **Old backup, changes in the app:** a backup older than a day that would change what the app has gets an orange line:
  "Die Sicherung ist 9 Tage alt – 37 Markierungen und 12 Werte in der App weichen ab und werden auf den Stand der
  Sicherung gesetzt." A re-planned week says so in its own line. There is no "newer wins" mode.
- **Backups of older versions** (no `sicherung` and no `record` rows, but goals, categories and marks, values, work,
  notes or closings in more than one week): "Diese Sicherung stammt von einer älteren Thalia-Version – Ergebnisse,
  Leseliste und verbundene Apps fehlen darin."
- **iCloud still loading:** with iCloud on and before this device's first sync is done (`sync.firstImportDone`), a file
  with `record` rows or closings gets "iCloud lädt noch deine Daten. Lies die Sicherung erst ein, wenn der Abgleich
  fertig ist – sonst zählen Power-Hours, Werte und Notizen doppelt." and reading it in asks first ("Trotzdem einlesen").
- **What the app keeps:** the file wins as before, also a cleared mark – but an empty note in the file keeps the app's
  note (marks and days), and a day the app has as "Krank" or "Urlaub" stays so when the file calls it otherwise, with
  an orange line ("Fr 27.11.: bleibt „Urlaub“ – die Datei sagt „Arbeitstag“.").
- **Large files** (above about 200 KB, a year's backup) stay out of the text field – one line "Thalia Sicherung
  2026-11-22.csv · 3,7 MB" with "Datei entfernen". Reading and comparing run off the main thread ("Sicherung wird
  gelesen …"); applying is one save, with the hint "Sicherung wird eingespielt – bitte warten". Only what the file is
  about is read from the app (its weeks; records only with `record` rows; work and notes only with such rows).
- **Read again before applying:** right before the import the file is compared with the app again. Has a week got a
  plan meanwhile (another device), the preview shows the replacement and asks "KW48 ersetzen?" instead of mixing the
  plans.
- **Another week than chosen** (the plan import with the prompt): a file that plans exactly one other week gets "Die CSV
  ist für KW49 – gewählt ist KW48." and importing asks ("Trotzdem KW49 importieren"; or ask ChatGPT to correct the week).
  Files with several weeks have no such line.
- **The same backup on two devices** (or read in while iCloud was still loading): work blocks and notes keep the id of
  their original (`importID`); every device merges a restored copy with its original and with the other copies – the
  original stays, else the oldest copy; another copy's fields count only when it was edited later, so a restored copy
  never rolls back what changed after the backup. Values have no id: for 7 days after reading a backup in
  (UserDefaults `restore.window`, per device) the values it wrote are compared after every sync with older copies of the
  same measurement and day – the same values (value, text, note, estimate; not the time) → the restored copies go to
  „Zuletzt gelöscht“.
- **Widerrufen** in the toast takes back what an import added – work blocks, notes and reflections – and gives the
  days it changed their type and note back, besides the weeks it replaced (archive). It appears whenever there is
  such a thing. Marks and values of a week that wasn't replaced stay. A closed week whose days or work blocks went
  back is scored again, as after any change by hand (on a Mac, Apple Watch or iPad by the rules of „Who scores“).

### Automatic backups and „Letzte Sicherung“

- **„Letzte Sicherung“ for all devices:** after every backup by hand, the synced record `backup.last`
  (`{"at":"…","device":"iPhone","v":1}`, the kind of device) says when and where; Einstellungen → Deine Daten shows
  "Letzte Sicherung: 22.11.2026 am iPhone (vor 3 Tagen) · automatisch: 23.11.2026 auf diesem Gerät" or "Noch keine
  Sicherung". The week's closing reminds only when **no** device has made a backup by hand for 30 days ("Letzte
  Sicherung vor 34 Tagen – jetzt sichern?").
- **Weekly file:** iPhone and Mac write a backup themselves at most every 7 days when Thalia goes to the background –
  "Thalia Sicherung 2026-11-23.csv" in Application Support/Sicherungen of the device (device backup or Time Machine
  include it), written atomically and never over an existing file. Only with iCloud (after the device's first sync) or
  local storage – never in `-Demo`, the tour's practice page or a store that only lives in memory. Kept: the 4 newest
  and one per month for 6 months; after an unusually small file (less than half the largest kept one) nothing is
  removed and Einstellungen says "Letzte automatische Sicherung auffällig klein – ältere bleiben". Einstellungen → Deine
  Daten → Sicherungen lists them (date, size, "Teilen…"). Per device: UserDefaults `backup.lastAuto`.

**Older versions** (1.9.0 and earlier) list the `sicherung`, `wertung` and `change` rows and the five plain `record`
rows under „Nicht gelesen“ and import the rest as before; they ignore the time of a single value and read `1.1250`
correctly.
