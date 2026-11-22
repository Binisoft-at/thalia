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
| `category_score` | today's category or empty | `title` label as in the records, `date` (day grade) or empty (week grade), `value` 0–10, `note` source, `count` (since 1.8.0, see „Archiv-Wochen“) |
| `goal_score` | annual goal `1` … `10` or empty | `title` label as in the records, `value` 0–10, `note` source, `count` (since 1.8.0) |

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
- A pasted ChatGPT answer is fine: the first fenced code block is taken (since 1.8.0 a warning names more
  than one CSV block – all weeks belong in one).
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
  (*Alles als CSV*) carry the grade rows and the source.

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
