# Thalia v9 (Version 1.8.0, Tour-Version 9) – Archiv-Wochen

Anlass (22. Nov. 2026): Beim Nachtragen alter Wochen aus Scans hat ChatGPT fünf Probleme mit dem Import gemeldet.
Bini will sie behoben haben, und der Prompt soll so angepasst sein, dass ChatGPT die CSV neu erstellen kann:

1. **Archivimport ohne Pflichtvorlage.** Wochen mit nur `week` (und eventuell `day`) müssen gehen; fehlende
   `item`/`measure`-Zeilen dürfen keine offenen oder verpassten Aufgaben erzeugen. Für einen erneuten Import braucht
   es eine ausdrücklich wählbare Funktion **„Archivdaten dieser Wochen ersetzen“** – ein ergänzender Import entfernt
   alte, falsche Detaildaten nicht.
2. **Kategoriennoten als Zahlen** (0–10) importieren: eigene Zeilentypen `category_score` und `goal_score` mit
   Datum bzw. Woche, ursprünglicher Bezeichnung, Wert, Quelle und Anzahl gültiger Tage.
3. **Überlieferter Wochenwert und heutige Berechnung getrennt.** `week.value` bleibt der Wert aus den Unterlagen;
   eine Berechnung nach heutigen Regeln (z. B. ohne Urlaubstage) überschreibt ihn nie. Beide klar bezeichnet.
4. **Durchschnitt über vorhandene Werte, echte Nullen zählen.** Summe gültiger Noten ÷ Anzahl gültiger Noten;
   leere, gestrichene, unlesbare Felder zählen nicht; n = 0 → offen; erst das Ergebnis runden.
   Beispiele: (0 + 10 + 10) / 3 = 6,67; (10 + 10 + 0 + 0) / 4 = 5,00.
5. **Historische Kategorien bewahren.** Alte Sammelkategorien nicht auf heutige Unterkategorien aufteilen,
   Jahresziel-Noten nicht auf Kategorien vervielfachen, alte Zusatzkategorien in einen Archivbereich; fehlende
   Einzelhaken, Arbeitszeiten und Messwerte bleiben unbekannt (nichts erfinden).

Keine CloudKit-Schemaänderung (kein neues `@Model`-Feld): die Noten einer Woche liegen als CSV-Text in einem
`AppSetting` (`archive.<Woche>`), der Wochenwert bleibt `WeekPlan.recordedScore`, die Neuberechnung
`WeekPlan.finalScore`/`finalGoalScores`.

## 1. Entscheidungen

1. **Archiv-Woche:** eine Woche der Datei ohne `item`-Zeilen. Der Import legt für sie nie Punkte oder Messwerte an,
   „Leere Felder als ✗ zählen“ füllt sie nie (auch nicht auf dem Plan, den die App für die Woche hat), sie wird wie
   jede vergangene Woche abgeschlossen. Ohne Punkte gibt es nichts Offenes und nichts Verpasstes.
2. **„Archivdaten dieser Wochen ersetzen“** (Schalter im Weg „Mit ChatGPT“, Standard aus): jede vergangene Woche der
   Datei geht vor dem Import vollständig ins Archiv (`archiveWeek`: Punkte, Messwert-Definitionen, Markierungen,
   Werte der Tage, eigene Tageswertungen, Tagesabschlüsse, Tagestypen und Notizen der `day`-Zeilen, Archiv-Noten,
   Papier-Wertung) und kommt aus der Datei neu; „Widerrufen“ holt alles zurück. Wochen ab der aktuellen Woche
   werden nie ersetzt (Warnung, normaler Import). Schalter aus: wie bisher ergänzen; Noten werden nach Schlüssel
   aktualisiert. Hat eine Archiv-Woche in der App noch Punkte und der Schalter ist aus, warnt die Vorschau:
   „KW43: in der App noch 63 Punkte aus einem früheren Import – ‚Archivdaten ersetzen‘ entfernt sie.“
3. **Neue Zeilentypen** (gelesen und geschrieben, auch im Backup):
   - `category_score` – Note einer Kategorie 0–10. `id` = heutige Kategorie (`1.1`), nur wenn eindeutig dieselbe,
     sonst leer; `title` = Bezeichnung genau wie in der Unterlage (Pflicht); `date` = Tag (Tagesnote) oder leer
     (Wochennote, nur wenn nur der Mittelwert belegt ist); `value` 0–10 (Komma/Punkt); `note` = Quelle;
     `count` = Anzahl gültiger Tage (nur Wochennote, optional).
   - `goal_score` – Note eines Jahresziels 0–10 für die Woche. `id` = Jahresziel `1`…`10` (leer, wenn unklar);
     `title` = Bezeichnung wie in der Unterlage; `value`; `note` = Quelle; `count` optional.
   - Neue optionale Spalte `count` (Aliase `anzahl`, `n`). Der Writer schreibt sie nur, wenn es Noten gibt.
   - Aliase der Typen: `kategorie_note`, `kategoriennote`, `categoryscore`, `ziel_note`, `zielnote`, `goalscore`.
   - Unlesbarer Wert, Wert außerhalb 0–10, fehlender `title` → übersprungen mit Grund. `id`, die keine Kategorie
     bzw. kein Ziel der App ist → Note bleibt ohne Zuordnung (Warnung „… bleibt im Archiv“).
   - Schlüssel (Import ist wiederholbar): Woche · Art · Tag oder „Woche“ · (`id` oder normalisierter `title`).
4. **Mittelwerte (Entscheidung 4):** `ArchiveWeek.mean(values)` = Summe/Anzahl, nil bei 0 Werten; nur die Anzeige
   rundet (2 Stellen, `Format.score`). Wochennote einer Bezeichnung = ausdrückliche Wochenzeile, sonst Mittel der
   Tagesnoten (n = Anzahl Tagesnoten).
5. **Zwei Wertungen (Entscheidung 3):**
   - **„Laut Unterlagen“** = `WeekPlan.recordedScore` (aus `week.value` oder „Nur Wertung“). Wird nie berechnet
     oder überschrieben (nur ein neuer Import/„Nur Wertung“ ändert ihn).
   - **„Nach heutigen Regeln“** = `WeekPlan.finalScore`. Für eine Woche mit Punkten wie bisher (Scorer). Für eine
     Woche ohne Punkte mit Archiv-Noten: `ArchiveWeek.recalculated(...)`:
     Kategorie (zugeordnet, existiert in der App) = Mittel ihrer Tagesnoten **ohne Krank-/Urlaubstage**
     (`DayTypes.isExcused` des Tagestyps); nur eine Wochennote → diese. Jahresziel = Mittel seiner
     Kategorienwerte; keine → seine `goal_score`-Note. Woche = Mittel der Zielwerte (gleich gewichtet), nil ohne
     Werte. Noten ohne Zuordnung zählen nie. `finalGoalScores` bekommt die Zielwerte (gleiche Regel), damit
     Ziel-Diagramme und PDF sie haben.
   - `WeekPlan.historyScore` = `recordedScore ?? finalScore` (bisher umgekehrt): Rückblick, Ø, Ziele, PDF und
     Widgets zeigen den Wert laut Unterlagen, wo es einen gibt. Die Woche zeigt beide, klar bezeichnet.
6. **Archivbereich (Entscheidung 5):** Noten ohne Zuordnung bleiben mit ihrer Originalbezeichnung gespeichert und
   werden in der Woche unter „Ohne Zuordnung (Archiv)“ gezeigt; sie zählen in keiner Rechnung. Nichts wird
   aufgeteilt oder vervielfacht; die App erzeugt aus Noten nie Haken oder Messwerte.
7. **Speicher:** `AppSetting` mit Schlüssel `ArchiveWeek.settingKey(week)` = `"archive.2026-W43"`, Wert = CSV
   (Kopf + `category_score`/`goal_score`-Zeilen der Woche, `ArchiveWeek.csv` / `ArchiveWeek(csv:week:)`).
   Leer → Setting löschen. Teil von `exportDocument` (Backup), `archiveWeek` (Schnappschuss + Entfernen),
   `restore`, `touchedWeeks` (Neuberechnung), Sync-Duplikate (neuester gewinnt, wie andere Settings).
8. **Prompt** (`PastWeekPrompt.text`, gleiche Signatur): Archiv-Regeln wie unten (§3); Kopfzeile
   `PastWeekPrompt.header` = `type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note,count,mo,di,mi,do,fr,sa,so`.
   Enthält Jahresziele (id · Name), Kategorien (id · Name · Ziel), Messwerte (id · Name · Einheit) und die
   Vorlage-Punkte nur als Referenz für wirklich belegte Einzelhaken. Keine Produktnamen von KI-Modellen, keine
   persönlichen Beispiele (nur neutrale wie „Sport / Verein“).
9. **UI:**
   - Nachtragen-Fenster, Weg „Mit ChatGPT“: Schalter „Archivdaten dieser Wochen ersetzen“ mit Fußtext („Alles, was
     die App für diese Wochen hat, kommt ins Archiv und wird durch die Datei ersetzt – für einen erneuten Import.
     Widerrufen holt es zurück. Diese Woche und spätere werden nie ersetzt.“). Vorschau je Woche zusätzlich:
     „12 Kategoriennoten · 10 Zielnoten · Wertung 9,28 laut Unterlagen“, Status „ersetzt“ bei Ersetzen.
   - Woche (iPhone `WeekView`, Mac `WeekTable`-Seitenleiste oder Kopf): Karte **„Archiv“** für eine Woche mit
     Noten oder mit Wert laut Unterlagen: „Wertung laut Unterlagen 9,28“ und „Nach heutigen Regeln 8,93 · ohne
     2 Urlaubstage“ (fehlt eine, „–“ mit kurzem Grund); Tabelle der Kategoriennoten (Originalbezeichnung, darunter
     zugeordnete Kategorie, Mo–So, Ø (n)); Zielnoten; „Ohne Zuordnung (Archiv)“. Noten an Krank-/Urlaubstagen
     gedimmt („zählt heute nicht“). Für eine Woche ohne Punkte zeigt der Wochen-Kopf den Wert laut Unterlagen.
   - Rückblick und PDF-Bericht: Zeilen solcher Wochen tragen „Archiv“ statt „Papier“, wenn Noten da sind; der
     Wert ist der laut Unterlagen (Fußnote im PDF: „Wertung laut Unterlagen; Zielfelder laut Unterlagen oder nach
     heutigen Regeln aus den Kategoriennoten“).
10. **Abschluss:** Version 1.8.0, Tour 9 mit einer Karte `archive` („Archiv-Wochen“, `since: 9`), TOUR.md, IMPORT.md
    (Abschnitt „Archiv-Wochen“ mit beiden Zeilentypen), TESTING.md „v9“, STATUS.md. Demo: eine Papier-Woche
    (KW45 der Demo) bekommt Kategoriennoten (eine Woche mit einem Urlaubstag, eine Note ohne Zuordnung) und
    Zielnoten; CI-Screenshot `archive` (iPhone und Mac: Woche KW45 mit der Archiv-Karte) in `Config/ci.env`
    (`SCREENSHOT_SCREENS`, `MAC_SCREENS`) und `applyLaunchOptions`.

## 2. Tests (Core, `V9Tests.swift`)

- A1 Mittel: [0, 10, 10] → 6,666… (Anzeige 6,67); [10, 10, 0, 0] → 5; [] → nil.
- A2 Parse: `category_score` mit Datum, ohne Datum + `count`, leere `id` (ohne Zuordnung), Komma-Wert; `goal_score`
  mit id 5; Wert 11 und „abc“ übersprungen; fehlender `title` übersprungen; Aliase. Schreiben und wieder lesen
  ergibt dasselbe (auch `ArchiveWeek.csv`).
- A3 Archiv-Woche: Datei mit nur `week`-Zeile (value 9,19) → keine Punkte, `fillingBlanks`/`fillingPastBlanks`
  füllen sie nicht, `closingPast` schließt sie; Vorschau „Wertung 9,19 laut Unterlagen“.
- A4 Neuberechnung: zwei zugeordnete Kategorien eines Ziels mit Tagesnoten, Sa = Urlaub mit Note 0 → Sa zählt nicht;
  Ziel = Mittel der Kategorien; zweites Ziel nur mit `goal_score` 8 → 8; Note ohne Zuordnung ändert nichts;
  Woche = Mittel der Ziele. Ohne Noten → nil.
- A5 Unbekannte `id` (`9.9`) → ohne Zuordnung + Warnung.
- A6 Vorschau ersetzt: `ImportWeekSummary` „ersetzt“ und Detail mit Notenzahlen; aktuelle Woche wird nicht ersetzt
  (Warnung).
- A7 Prompt: enthält `category_score`, `goal_score`, die Kopfzeile, „Nichts erfinden“, „echte 0“, Ziele und
  Kategorien mit ids, keine Modellnamen; eine Woche, mehrere Wochen und leere Liste wie in v8.
- A8 `historyScore`-Reihenfolge: über `WeekLine` – `storedScore` (laut Unterlagen) gewinnt über die Neuberechnung
  (Test in Core über die Eingaben, die Shared liefert).

## 3. Prompt-Text (Kern, deutsch)

```
Du überträgst Wochen aus meinen Unterlagen (Fotos, Scans, PDFs, Tabellen) in eine CSV für meine Tracker-App Thalia.
Es ist ein Archiv: übertrage nur, was in den Unterlagen steht.

<Wochen: genau diese … | die Wochen aus den Unterlagen – KW und Datum liest du dort ab>

## Regeln
1. Nichts erfinden. Leere, gestrichene oder unlesbare Felder: keine Zeile. Eine echte 0 schreibst du als 0.
2. Je Woche ein Block, älteste zuerst; jeder Block beginnt mit genau einer week-Zeile.
3. week: id = Woche (2026-W43; unklar → leer lassen und date = ein Datum der Woche), value = der Wochenwert genau
   wie in der Unterlage – nicht selbst berechnen, nicht runden; note = Quelle (z. B. „Scan S. 19“).
   Ist nur der Wochenwert belegt, besteht der Block nur aus dieser Zeile.
4. day (nur wenn belegt): id = Datum oder Mo…So, title = Tagestyp (Arbeitstag, Frei, Krank, Urlaub …),
   description = kurze Notiz.
5. category_score = Note einer Kategorie (0–10):
   title = Bezeichnung genau wie in der Unterlage; id = heutige Kategorie aus der Liste unten, nur wenn es eindeutig
   dieselbe ist – sonst leer (alte Sammel- oder Zusatzkategorien nie aufteilen oder umdeuten);
   date = der Tag bei einer Tagesnote; leer bei einer Wochennote, die nur als Mittelwert belegt ist (dann
   count = Anzahl gültiger Tage, wenn angegeben); value = Note; note = Quelle.
   Mittelwerte rechnet Thalia selbst: zu übertragenen Tagesnoten keine Wochennote derselben Kategorie.
6. goal_score = Note eines Jahresziels (0–10) für die Woche: id = Jahresziel 1–10 aus der Liste unten,
   title = Bezeichnung wie in der Unterlage, value, note = Quelle, count wenn angegeben.
   Zielnoten nie auf Kategorien verteilen.
7. Einzelhaken nur, wenn einzelne Punkte wirklich lesbar abgehakt sind: item-Zeilen mit den ids der Vorlage und
   den Spalten mo…so (✓ ½ ✗ –). Sonst keine item-Zeilen – fehlende Punkte gelten nicht als verpasst.
8. Messwerte (entry) nur mit belegtem Wert: id = Messwert-id unten, date, value. Aus einer Note folgt kein Messwert.
9. Keine score-, measure-, goal-, category- oder work-Zeilen.
10. Antworte mit genau einem ```csv-Block; danach in 2–5 Zeilen, was unsicher war.

## Kopfzeile
<PastWeekPrompt.header>

## Beispiel (zwei Wochen)
<week mit value + 3 category_score (eine ohne id) + 1 goal_score; week nur mit value>

## Jahresziele (id · Name)
## Kategorien (id · Name · Jahresziel)
## Messwerte (id · Name · Einheit)
## Vorlage für Einzelhaken (nur bei belegten Haken) – Punkte von KWnn (id · Kategorie · Titel)
## Meine Unterlagen:
```

## 4. Pakete

- **P1 Core** (`Packages/ThaliaCore`): Zeilentypen + Spalte `count` in `PlanCSV` (lesen, schreiben, Aliase,
  Prüfungen, Schlüssel), `Document.grades`, `ArchiveGrade`, `ArchiveWeek` (gruppieren, `mean`, `weeklyGrade`,
  `recalculated`, `csv`/`init(csv:week:)`, `settingKey`), Archiv-Wochen in `fillingBlanks`/`fillingPastBlanks`/
  `closingPast`, `ImportWeekSummary` + `ImportPreview` (Noten, ersetzt, Warnungen), `PastWeekPrompt` neu,
  `WeekLine`/`RangeReport` falls nötig, Tests A1–A8. `swift test` grün.
- **P2 Shared** (`Shared/`): Speicher (`archiveGrades(_:)`, `setArchiveGrades(_:week:)`), `apply(… replacing:)`,
  `archiveWeek`/`restore`/`exportDocument`/`touchedWeeks`, `storeFinalScore` mit Neuberechnung,
  `WeekPlan.historyScore`, `pastPreview(… replacingArchives:)`, `WeekContext.archive` + `archiveRecalculation`,
  Range-Daten, Demo-Noten.
- **P3 App** (`App/Sources/`): Schalter + Vorschau (PastImport), Archiv-Karte (iPhone + Mac), Wochen-Kopf,
  Rückblick/PDF „Archiv“, Screenshot `archive`, Tour 9, Version 1.8.0, Doku.
- **Prüfen:** Review gegen diesen Plan, Verifikation jeder Entscheidung, Lücken schließen, `scripts/ci/local-check.sh`.

## 5. Nachträge nach der Durchsicht (Lücken geschlossen)

Abweichungen vom Text oben, damit ein erneuter Import sicher ist:

- **Zeilen bleiben in ihrem Block:** jede Note braucht eine `week`-Zeile davor; ein Datum (bei `day`, `category_score`,
  `goal_score`) in einer anderen Woche als der des Blocks → übersprungen mit Grund, nie in die Woche des Datums
  verschoben (bisher: Warnung und Verschieben).
- **Ersetzen (Entscheidung 2):** nur Wochen mit `week`-Zeile in der Datei; eine Woche, die die Datei genau so bringt,
  wie die App sie hat, wird nicht noch einmal ersetzt. Warnung ohne Schalter jetzt „KW43: in der App noch 63 Punkte
  ohne Markierungen – ‚Archivdaten ersetzen‘ entfernt sie.“ bzw. „… 24 Punkte mit 80 Markierungen – ‚Archivdaten
  ersetzen‘ nur wählen, wenn sie aus einem fehlerhaften Import stammen; es verschiebt alles ins Archiv.“ Mit Schalter
  zusätzlich „KW45: 80 Markierungen aus der App gehen ins Archiv – die Datei bringt keine Einzelhaken.“
- **Archiv-Woche (Entscheidung 1):** `measure`-Zeilen einer Woche ohne `item`-Zeilen werden mit Warnung verworfen.
- **Wochenwert (Entscheidung 5):** unlesbar, außerhalb 0–10 oder bei verrutschten Spalten → nicht übernommen (Warnung);
  ohne Ersetzen behält eine leere oder unlesbare Datei-Zeile den Wert der App; leeres Motto und leerer Kontext
  behalten die der App; diese Woche und spätere bekommen keinen Wochenwert aus der Datei. Export schreibt ihn exakt.
- **Verrutschte Spalten:** Wert und Folgezelle nur Ziffern („9,28“ ohne Anführungszeichen) oder gefüllte Zellen hinter
  der Kopfzeile → Note übersprungen, Wochenwert nicht übernommen.
- **Lesen:** Tagesnoten in `mo … so` einer `category_score`-Zeile; Spalte `quelle` (deutsche Kopfzeile) als Quelle;
  Warnungen für zwei Bezeichnungen auf derselben id und für mehrere CSV-Blöcke; „steht vor der ersten week-Zeile“
  statt „nicht lesbar“.
- **Prompt (§3):** das Beispiel nutzt die Platzhalter-Woche `JJJJ-Wnn` (zurück eingefügt landet nichts in einer
  echten Woche), die Zielnote ist kein Mittel der Beispiel-Noten; neu: „erstelle sie nach diesen Regeln vollständig
  neu“, Dezimalkomma als Punkt, gleich viele Spalten wie die Kopfzeile, Widerspruch ohne Vorgabe → Feld weglassen,
  `mo … so` nur in item-Zeilen, Noten nie als Text in `note`/`description`, eine Note je Jahresziel ist `goal_score`
  (auch wenn die Unterlage sie Kategorie nennt), Zielnoten nie aus Kategoriennoten berechnen, item-Zeilen machen die
  Noten der Woche für die heutige Berechnung unwirksam.
- **Widerrufen:** wurde die Woche nach dem Import geändert, bleibt der Schnappschuss dieses Stands im Archiv.
  „Archivdaten ersetzen“ setzt alle Kopien der Wochenzeile zurück (Sync-Duplikate).
- **Rückblick:** „Archiv“ nur für Wochen ohne Punkte (wie im PDF).
- **Fußtext des Schalters:** „Alles, was die App für die Wochen der Datei hat, kommt ins Archiv und wird durch die
  Datei ersetzt – für einen erneuten Import. Wochen, die in der App abgehakt wurden, vorher aus der Datei nehmen.
  Widerrufen holt alles zurück. Diese Woche und spätere werden nie ersetzt.“
