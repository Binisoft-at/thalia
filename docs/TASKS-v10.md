# Thalia v10 (Version 1.9.0, Tour-Version 10) – Jahresziele, Listen, Abschnitte, verbundene Apps

Anlass (22. Nov. 2026, Bini: „Thalia Korrekturen v8“):

1. **Jahresziele klarer eintragen, abhaken und mit den Wochen verbinden.** In der Übersicht soll man sehen, welche
   Messwerte in einem Ziel stecken. Fortschrittsmarker pro Woche: **eine Kategorie über 8,0 ist „gut dabei“.**
   1. Es gibt auch Ziele wie „10 Bücher lesen“, die man abhakt bzw. einträgt.
   2. **Bücher und Ähnliches** klar erfassen: Buchname, Seitenzahl, Fortschritt …
   3. **Rückwirkend** eintragen können.
2. **Versionen der Jahresziele:** in selbst gewählten **Abschnitten** die Jahresziele aktualisieren und für den
   nächsten Abschnitt neu festlegen. Leistungen älterer Abschnitte bleiben erhalten, werden aber gesondert gezeigt
   (Fokus immer auf dem aktuellen Abschnitt) – in Übersichten und Berichten.
3. **Andere Apps anbinden** (Theo, George, Nina, Finn, …), damit sie automatisch Daten liefern. Architektur
   überlegen, Umsetzung starten, Binis Aufgaben nennen, Prompts für die anderen Apps.
   1. Theo: Aufgaben und PH eintragen, Gruppen → Kategorien zuordnen; erledigte Aufgaben kommen in Thalia an.
   2. Finn: Ausgaben, Vermögen (für Jahresziele) und was sonst angebunden werden soll.
   3. Nina: Kalorien, Makros …
   4. George: Workout X erledigt → in Thalia erledigt.

Der Plan wurde vor der Umsetzung von drei unabhängigen Prüfern gegengelesen (Anforderungen/Bedienung, Datensicherheit
und Sync, App-übergreifende Architektur); ihre Einwände sind eingearbeitet.

**Keine CloudKit-Schemaänderung** (wie v8/v9): alles Neue liegt als JSON in `AppSetting` unter eigenen
Schlüssel-Präfixen – der TestFlight-Build braucht kein „Deploy Schema Changes“. Ältere Builds ignorieren die Schlüssel.

## 0. Grundregeln für v10
1. **Berechnen statt schreiben** für alles, was aus anderen Apps kommt: Thalia legt dafür nie eigene Markierungen,
   Arbeitsblöcke oder Einträge an. WeekContext rechnet die Werte dazu – wie heute die Health-Werte
   (WeekContext.swift ~143–147). **Eigenes gewinnt immer:** eine eigene Markierung (auch eine geleerte),
   ein eigener Arbeitsblock mit derselben `importID`, ein eigener Eintrag für Code + Tag.
2. **Vergangenheit einfrieren:** eine abgeschlossene Woche vor dem Start des aktuellen Abschnitts wird nie automatisch
   neu gewertet (Wächter in `save()`/`storeFinalScore`-Schleife, `rescoreRecentClosedWeeks`, Import-Abschluss), nur über
   „Neu berechnen“ in der Woche.
3. **Ein Datum je Tatsache, ein Datensatz je Tatsache:** jeder datierte Eintrag (Seitenstand, Ergebnis-Eintrag) ist ein
   eigener kleiner Datensatz mit dem Tag im Schlüssel – zwei Geräte überschreiben sich nie gegenseitig, und
   `touchedWeeks()` findet die betroffene Woche (rückwirkend → Neuwertung nach R11, außer eingefroren).
4. **Rückwärtsverträglich:** `MeasureSource.other(String)` (schon in 1.8.0) hält unbekannte Quellen unverändert;
   `SettingRecord` behält unbekannte JSON-Felder beim Speichern.
5. **Demo bleibt Demo:** Beispiel-Meldungen gibt es nur im `-Demo`-Speicher und auf der Übungsseite der Tour (aus
   Fixture-Dateien in ThaliaCore); der echte Speicher bekommt nie Beispieldaten.
6. **Watch:** liest und schreibt keine Austausch-Dateien (`#if !os(watchOS)`); sie sieht die Werte über den
   synchronisierten Eingang wie alles andere.

## 1. Entscheidungen

### 1.1 Speicher: `SettingRecord`
1. Core-Protokoll `SettingRecord: Codable` mit `static var prefix`, `id`, `settingKey`, `modifiedAt`, `deletedAt?`.
   JSON mit `v`; fehlende Felder → Standardwerte; **unbekannte Felder bleiben erhalten** (rohes Objekt mitlesen und beim
   Schreiben zurückmischen). Schlüssel:
   - `goal.result.<uuid>` – Ergebnis eines Jahresziels (§1.2), skalare Felder.
   - `goal.entry.<Tag>.<uuid>` – ein datierter Ergebnis-Eintrag (Haken, +1, Wert), `resultID` darin.
   - `goal.segment.<uuid>` – Abschnitt (§1.4).
   - `list.item.<uuid>` – Listeneintrag (Buch …), skalare Felder.
   - `list.progress.<Tag>.<uuid>` – ein Seitenstand, `itemID` darin.
   - `link.rule.<uuid>` – Zuordnung (§1.5).
   - `x.<quelle>.<Tag>` – Tagesdatei einer anderen App im Eingang (§1.5), `x.sources` = bekannte Quellen.
   - `score.<Woche>` – gespeicherte Kategorie-Wochennoten (§1.2.3).
2. **Abfragen:** keine ungefilterten AppSetting-Abrufe mehr für diese Präfixe. Woche: `#Predicate { keys.contains($0.key) }`
   über die bekannten Schlüssel (7 Tage × Quellen; `score.<Woche>`); Listen/Ergebnisse: Präfix-Abfrage
   `key.starts(with:)` – einmal beim Start in `LaunchDiagnostics` (Debug) und als Fallback mit Filter im Speicher, falls
   das Prädikat auf dem Gerät nicht greift. Auch die v9-Abfragen ohne Filter (ReviewView `@Query settings`,
   `storedArchives`, `writeArchive`, `syncDevices`) bekommen ein Präfix/IN-Prädikat.
3. Löschen = `deletedAt` im JSON; „Zuletzt gelöscht“ zeigt Ergebnisse, Listeneinträge und Abschnitte mit
   (`Trash.records`, Kaskade über die Eltern-id), Widerrufen über den Undo-Manager; „Abschnitt beginnen“ ist **eine**
   Undo-Gruppe.
4. Backup/Export (CSV „mit allem“): neue Zeilenart `record` (`id` = Schlüssel, `note` = JSON), Import aktualisiert nach
   Schlüssel (neuerer `modifiedAt` gewinnt). **Auch der Eingang `x.` kommt ins Backup** – Thalia löscht ihn nie; er ist
   die einzige Langzeitkopie (die Quellen räumen nach 62 Tagen auf). Der Wochen-Export für ChatGPT enthält keine
   `record`-Zeilen.

### 1.2 Jahresziele: Ergebnisse, Wochen über 8,0, enthaltene Messwerte
1. **Ergebnis** (`GoalResult`, gehört zum **Zieljahr** und zu einem Ziel `goalKey`): `title`, `kind`, `target`
   (`Target`-Text wie `>=10`, `<=80`, `>=60000`; leer = ohne Ziel), `targets[segmentID]` (Ziel je Abschnitt,
   „aktualisieren“), `start` (Startwert bei `value`), `unit`, `source`, `fromSegment?`/`endedAfter?` (neu ab /
   beendet nach Abschnitt), `position`. Arten:
   - `check` – abhaken (z. B. „Website online“): erledigt, wenn es einen `goal.entry` gibt (Datum = erledigt am).
   - `count` – zählen (z. B. „10 Bücher“): Stand = Summe der Einträge **oder** aus einer Quelle:
     `list` (fertige Listeneinträge, die „zählt für“ dieses Ergebnis haben; ohne solche: alle fertigen der Art),
     `measure:<Code>` (Summe eines Wochen-Messwerts über Abschnitt/Zieljahr, auch `arbeit:`-PH; `health:`-Quellen nur
     auf dem Gerät gerechnet, nie gespeichert), `app:<quelle>:<kennzahl>[=<ref>]` (Summe/Anzahl aus dem Eingang).
   - `value` – Zielwert (z. B. Vermögen, Gewicht): Stand = letzter Wert aus `measure:<Code>` oder `app:…` oder aus
     eigenen Einträgen.
   - Anteil je Abschnitt ergibt sich aus den Daten der Einträge (`Segments.resolve`), nichts wird kopiert.
2. **Stand und Tempo** (Core `ResultProgress`): Stand, Ziel, Anteil 0…1, Beitrag je Abschnitt, Status `offen` /
   `auf Kurs` / `hinten` / `erreicht` (`Target.isMet`). Soll heute = `start + (ziel − start) × verstrichener Anteil`
   (bei `count` start = 0; Zeitraum = Zieljahr, bei `targets[aktueller Abschnitt]` der Abschnitt). Ohne Ziel nur Stand.
   Anzeige „7 von 10 · davon 4 in Abschnitt 1“.
3. **Wochen über 8,0 – je Kategorie** (Core `GoalTrack`, `GoalTrack.threshold = 8.0`):
   - Beim Wochenabschluss speichert `storeFinalScore` zusätzlich die **Kategorie-Wochennoten**
     `score.<Woche>` = `1.1=8.2;1.2=6.5` (gleiche HealthDevice-Regel wie `finalScore`). Archiv-Wochen (v9) nehmen die
     Kategoriennoten aus `archive.<Woche>`. Einmaliges Nachtragen für abgeschlossene Wochen des Zieljahrs ohne
     `score.` (nur auf dem HealthDevice, schreibt nur `score.`, nie `finalScore`).
   - Eine Kategorie ist in einer Woche „gut dabei“, wenn ihre Note **gerundet auf zwei Stellen ≥ 8,00** ist
     (Annahme, offene Frage an Bini: „über 8,0“ = ab 8,00 oder erst ab 8,01?). Entschuldigte Wochen zählen nicht.
   - Ein Ziel ist in der Woche „gut dabei“, wenn **jede** gewertete Kategorie des Ziels gut dabei ist.
   - Zielkarte: die Kategorie-Zeilen (GoalsView ~l.209) bekommen ein Abzeichen „✓ über 8“ für die laufende Woche
     (live) und eine Zeile „Wochen über 8: 1.1 9/12 · 1.2 7/12“ (letzte 12 gewertete Wochen **im aktuellen
     Abschnitt**, sonst so viele es gibt). Die vorhandene Verlaufslinie bekommt eine Linie bei 8 und gefüllte Punkte ≥ 8
     – keine zweite Punktreihe. Woche: dasselbe Abzeichen am Kategorie-Kopf.
4. **Enthaltene Messwerte:** Zielkarte (bis zu drei Chips „Gewicht · Protein · Schritte“, „+2“) und Zielseite listen die
   Messwerte der Kategorien des Ziels (Definitionen der aktuellen Woche, sonst der letzten mit Definitionen) mit
   Wochenwert/Ziel, und die Messwerte, die ein Ergebnis speisen. In „Wochenziele“ und im Messwert-Editor steht
   „zählt für Ziel 7 · Bücher 3/10“.
5. **Planung sieht die Ergebnisse:** `WeekReport`/`PlanPrompt` bekommen einen Block „Jahresziel-Ergebnisse (nur zur
   Info – nichts unaufgefordert steigern)“ mit Stand/Ziel/Status (keine Health-Werte).
6. **Eintragen – auch rückwirkend – über den bekannten Weg:** zum Tag navigieren, „Erfassen“ öffnen: zwei neue
   Optionen „Jahresziel eintragen“ (Ergebnis wählen → abhaken / +1 / Wert) und „Lesen“ (laufendes Buch → „bis Seite“ /
   „+ Seiten“), beide mit `app.captureDay` vorbelegt (Datum änderbar, Hinweis „Zählt für Di, 17. Nov.“). Die Zielkarte
   bleibt nur zum Ansehen (sie ist ein NavigationLink); die Zielseite hat „Ergebnisse“ mit Anlegen/Bearbeiten,
   abhaken, +1, Wert, Einträge mit Datum ändern/löschen.

### 1.3 Listen: Bücher und Ähnliches
1. `ListItem` (skalar): `kind` (Text mit Vorschlägen, Standard „Buch“; weitere „Kurs“, „Film“, „Podcast“ …), `title`,
   `subtitle` (Autor:in), `total` (z. B. 320), `unit` (je Eintrag, Standard „Seiten“), `startedOn?`, `finishedOn?`,
   `abandoned` (abgebrochen), `resultID?` („zählt für“), `note`. Status abgeleitet: ohne Fortschritt „geplant“, mit
   Fortschritt „läuft“, `finishedOn` „fertig“, `abandoned` „abgebrochen“.
2. `list.progress.<Tag>.<uuid>`: `itemID`, `reached` („bis Seite 120“), `note`. Core `ListMath`: Menge je Tag =
   Zuwachs zum vorigen Stand (nach Tag sortiert, rückwirkend eingefügt korrekt, nie negativ), Anteil, fertig im
   Zeitraum, Seiten je Woche. „bis Seite = total“ schlägt „fertig“ vor.
3. **Messwert-Quelle `list:<art>`** (z. B. `list:buch`): Tageswert = gelesene Menge aller Einträge der Art → ein Punkt
   „20 Seiten lesen“ mit Verknüpfung auf den Messwert bekommt Vorschläge/Fortschritt wie bisher. Das „+“ eines solchen
   Messwerts in Heute öffnet „Lesen“ – Seiten werden nur einmal eingetragen.
4. Oberfläche: Ziele-Seite bekommt die Karte **„Gerade dabei“** (laufende Bücher, Antippen → Fortschritt), von dort und
   von der Ergebnis-Zeile („Bücher 3 von 10 →“) die **Leseliste** (Abschnitte Läuft/Geplant/Fertig nach Abschnitt,
   Suche, + Buch). Gleich auf iPhone und Mac, kein neuer Seitenleisten-Eintrag. Buch-Fenster: Titel, Autor:in, Seiten,
   Art, „zählt für“, Start/Ende (Datum, rückwirkend), abgebrochen.

### 1.4 Abschnitte (Versionen der Jahresziele)
1. `GoalSegment`: `title` („Abschnitt 2“), `periodStart` (Zieljahr), `startWeek`, `reason`, Schnappschuss `goals`
   (`GoalRecord`) und `categories` (`CategoryRecord`) **zu Beginn** des Abschnitts, `createdAt`. Ende = Start des
   nächsten − 1. Ohne gespeicherte Abschnitte: ein Abschnitt „Abschnitt 1“ = ganzes Zieljahr (Core `Segments.resolve`:
   lückenlos, sortiert, je Zieljahr; Woche → Abschnitt; Bezeichnungen alter Wochen aus dem Schnappschuss).
2. **„Neuen Abschnitt beginnen…“** – immer erreichbar: Menü in der Jahreskarte der Ziele-Seite, Einstellungen →
   Jahresziele, und am Ende der Zielüberprüfung (GoalReviewView). Startwoche (Standard nächste Woche, frühestens eine
   Woche nach dem Start des aktuellen; rückwirkend erlaubt), Titel, Grund. Bestätigen (eine Undo-Gruppe): der
   laufende Abschnitt behält seinen Schnappschuss, der neue bekommt einen Schnappschuss des heutigen Stands; danach
   Einstellungen → Jahresziele: Ziele umbenennen, Beschreibung, neue Ziele/Kategorien; Ergebnisse: Ziel je Abschnitt
   setzen („aktualisieren“), neue anlegen (`fromSegment`), beenden (`endedAfter`). **Kein Umhängen oder Löschen von
   Kategorien im Assistenten** (Kategorien kommen weiter über den Planimport). Rückwirkender Start friert ab dann
   (Grundregel 2) die Wochen davor ein.
3. Anzeige: Jahreskarte „Abschnitt 2 · seit KW50 · Woche 3“ (statt eigenem Kopf); Karten zählen im aktuellen Abschnitt,
   ältere Werte grau wie „vor KW42“ (nicht versteckt); darunter **„Frühere Abschnitte“** (je Zeile: Titel, Wochen,
   Ø Wertung, Kategorie-Wochen über 8, erreichte Ergebnisse) → Seite mit den damaligen Zielen und Werten.
   Rückblick: `HistoryRange` bekommt `.segment` („Abschnitt“), Abschnittsgrenzen als Linie mit Name im Verlauf.
   Zielüberprüfung (`periodReport`): Auswahl Abschnitt/Zieljahr. PDF-Bericht: Zeitraum „Aktueller Abschnitt“.
4. Scorer ändert sich nicht; gespeicherte Noten alter Wochen bleiben (Grundregel 2).

### 1.5 Verbundene Apps („Binisoft-Austausch“, Format v1)
1. **Weg: die gemeinsame App Group `group.at.binisoft.shared`** (alle Binisoft-Apps haben sie; Handbuch §6: dort nur
   kleine Ereignisse und Zusammenfassungen). Pfade über `AppGroupFolder.url(appName:)` mit dem Anzeigenamen
   (`Thalia`, `Theo`, `George`, `Nina`, `Finn`):
   - Jede Quelle schreibt nur in ihren Ordner: `<Group>/<App>/exchange/source.json` (Herzschlag: `source`, App-Version,
     Format `v`, `generatedAt`, `refs` = stabile ids + Titel ihrer Gruppen/Workouts/Kennzahlen) und
     **eine Datei je Tag** `<Group>/<App>/exchange/days/<JJJJ-MM-TT>.json`, die sie **aus ihrem eigenen synchronisierten
     Speicher vollständig neu schreibt**, sobald sich an dem Tag etwas ändert (auch rückwirkend) – auf jedem iPhone/iPad/
     Mac, auf dem sie läuft (nie auf der Watch), auch direkt nach ihrem eigenen CloudKit-Import. Atomar (temp + rename),
     danach Darwin-Benachrichtigung `at.binisoft.exchange.changed`. Fehlt eine Tatsache in einer vorhandenen Tagesdatei,
     ist sie entfernt; eine fehlende Datei heißt „keine Information“. Aufräumen nach 62 Tagen.
   - Thalia schreibt `<Group>/Thalia/exchange/catalog.json`: **nur Struktur** – Ziele, Kategorien (Schlüssel, Titel,
     Abschnitt-id), Messwerte der Woche (Code, Titel, Einheit, Verknüpfung), Ergebnisse (id, Titel, Art) – keine Werte,
     kein Fortschritt.
   - Thalia liest auf jedem Gerät `<Group>/*/exchange/source.json` + `days/*.json` (Änderung nach
     `contentModificationDate`; Dotfiles/temp ignorieren), lehnt Dateien ab, deren `source` nicht zum Ordner passt,
     und legt je (Quelle, Tag) **einen** Eintrag `x.<quelle>.<Tag>` in ihren synchronisierten Eingang (neueres
     `generatedAt` gewinnt). Weil jede Quelle die Tagesdatei aus ihrem eigenen Sync erzeugt, schreiben alle Geräte
     denselben Inhalt – Konflikte sind harmlos; ~365 × Quellen Einträge im Jahr.
   - Nur mit dem echten Speicher (nie `-Demo`, Übung, In-Memory); am Mac nur, wenn die signierte App die App Group
     wirklich hat (Entitlement zur Laufzeit prüfen, abseits des Main-Threads, nicht beim Start); nie auf der Watch.
   - Wann: Start, Vordergrund, alle 5 min solange aktiv, nach Thalias eigenem CloudKit-Import, Tageswechsel,
     Darwin-Benachrichtigung (entprellt).
2. **Tagesdatei v1:**
   ```json
   {"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
     {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
      "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
     {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"}]}
   ```
   Felder einer Tatsache: `id` (stabil, geräteübergreifend gleich), `kind`, `ref` (stabile id in der Quelle: Theo-Gruppe,
   George-Vorlage, Finn-Gruppe), `refTitle`, `title?`, `value?`, `unit?`, `metric?` (feste Tabelle mit `agg`),
   `currency?` (ISO 4217, bei Geld), `at?`, **`origin` (Pflicht: `app` = in der Quelle selbst erfasst, `health` = aus
   Apple Health)**, `thalia?` (`category`, `categoryTitle`, `measure`, `result` – in der Quelle aus dem Katalog gewählt).
   Kein Verweis auf Wochen-Punkte (deren Codes gelten nur eine Woche). Datum ISO 8601 mit Zeitzone, ohne Bruchteile.
   Arten v1: `task.done`, `workout.done`, `habit.done`, `ph` (Power-Hours), `value` (Kennzahl eines Tages, `metric`
   aus der Tabelle: `kcal`, `protein_g`, `carbs_g`, `fat_g`, `water_ml` → `agg: sum`; `net_worth`, `savings_rate`,
   `body_weight_kg` → `agg: last`), `spending` (Tagessumme einer Gruppe, `value` + `currency`). Unbekannte Arten/
   Kennzahlen: im Eingang „nicht verwendet“.
   **`origin: health` verwendet Thalia nie** (Richtlinie 5.1.3(ii)); Thalia liest Health selbst auf dem Gerät.
3. **Wirkung – berechnet** (Core `ExchangeDerivation.week(inbox:items:measures:rules:…) → (entries, work, marks)`,
   WeekContext mischt sie ein; Grundregel 1):
   - `ph` → abgeleiteter Arbeitsblock in der Kategorie aus `thalia.category`, sonst aus der Zuordnung in Thalia
     (`LinkRule {source, ref → categoryKey}`); ohne Kategorie „ohne Zuordnung“. In Heute „aus Theo“ (nur lesen);
     „Übernehmen“ legt einen eigenen Block mit `importID = x:<quelle>:<id>` an, der den abgeleiteten ersetzt.
   - `*.done` und `value` → Werte für **Messwerte mit Quelle `app:<quelle>:<art|kennzahl>[=<ref>]`**
     (neue `MeasureSource.app`): `app:george:workout=<ref>` zählt Workouts am Tag, `app:theo:task` zählt Aufgaben, die
     der Kategorie des Messwerts zugeordnet sind, `app:nina:kcal` liefert den Tageswert. Punkte, die mit so einem
     Messwert verknüpft sind (CSV-Spalte `link`), bekommen den Haken **abgeleitet**: Ziel erfüllt (bzw. ≥ 1 ohne Ziel)
     → ✓ „⇄ George · Push“, solange es keine eigene Markierung gibt; sonst Vorschlag wie bisher. Nur an Tagen, an denen
     der Punkt gilt und die nicht entschuldigt sind.
   - Eigene Einträge ersetzen App-Werte je Code + Tag (wie Health: WeekContext ~143–146), in einer gemeinsamen
     Core-Funktion `Measures.merged(own:health:external:)`, die WeekContext, `measureSeries` und `lastValue` benutzen
     (Stepper-Fall und „Wert leeren“ getestet).
   - `spending` → Ausgaben-Messwert mit Quelle `app:finn:spending`: Finn-Zeilen erscheinen in der Ausgabenliste und den
     Gruppen nur zum Lesen („aus Finn – in Finn ändern“), eigene Ausgaben kommen dazu (nicht doppelt erfassen).
   - Ergebnisse mit Quelle `app:…` (z. B. `app:finn:net_worth`) lesen den letzten Wert bzw. die Summe.
4. **Verknüpfungen bleiben über die Wochen:** PlanPrompt (Reports.swift ~515) nennt die Werte `app:…` und `list:…` und
   die Regel „Verknüpfungen aus dem Ausgangsplan unverändert übernehmen“; die CSV-Prüfung akzeptiert sie ohne Warnung;
   beim Import übernimmt ein Messwert mit gleichem Code die Quelle der Vorwoche, wenn die Datei keine angibt (Hinweis in
   der Vorschau). Editoren: Messwert-Editor „Quelle“ (Manuell / Power-Hours / Apple Health / Leseliste / Verbundene
   App → Art → Eintrag aus `refs`), Punkt-Editor zeigt die Verknüpfung an.
5. **Einstellungen → „Verbundene Apps“:** je Quelle: zuletzt gesehen (`source.json`), Formatversion, Tatsachen der
   letzten 30 Tage, **„Ohne Zuordnung“** gruppiert nach `ref` mit Auswahl Kategorie (→ `LinkRule`), Herkunft der
   Zuordnung („Zuordnung aus Theo“ / „in Thalia“), „Zuordnung prüfen“ wenn `categoryTitle` nicht mehr passt; Liste der
   Zuordnungen; **„Was kommt an“** (Wirkung der letzten Tage, nur lesen); Schalter „Thalia-Katalog bereitstellen“
   (Standard ein). Hinweis: „Werte aus anderen Apps erscheinen, sobald Thalia auf diesem Gerät geöffnet war.“
6. **Später (nicht v10):** CloudKit-Weg über `iCloud.at.binisoft.shared`, Modul `BinisoftExchange` im Handbuch-Kit,
   App Intents „Punkt erledigen“, Hintergrund-Aktualisierung. Referenz-Code und Testdateien für die anderen Apps:
   `Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift` (nur Foundation, zum Kopieren) und
   `Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange/*.json` (öffentliches Repo).

### 1.6 Binis Aufgaben und Prompts (Lieferung, nicht Code)
1. `docs/CONNECTED_APPS.md`: Aufgaben für Bini, Grenzen der Lösung (gleiches Gerät; Thalia muss dort geöffnet werden;
   Watch-Workouts über Georges iPhone-App; CloudKit-Weg später) und **je App ein Prompt** zum Einfügen in deren Session
   (Theo, George, Nina, Finn) + ein allgemeiner für weitere Apps. Inhalt je Prompt: Format v1 vollständig, Schreiber
   (Tagesdateien, atomar, nach jedem Speichern und nach eigenem CloudKit-Import, iPhone/iPad/Mac), `source.json`,
   Darwin-Benachrichtigung, Katalog lesen + Auswahl „Thalia-Kategorie“ (Zuordnung in der Quelle als JSON in einem
   vorhandenen Einstellungs-Datensatz – möglichst keine neue CloudKit-Schemaänderung dort), App-Group-Entitlement
   prüfen, Tests mit den Fixtures, keine Health-Werte (`origin: health` nur wenn unvermeidbar), keine persönlichen Daten
   im Repo.
   - Theo: `task.done` + `ph`, Gruppe → Thalia-Kategorie, auch Aufgaben, die auf einem anderen Gerät erledigt und per
     Sync angekommen sind (Tagesdatei aus dem Speicher).
   - George: `workout.done` (ref = Vorlagen-id), auch Workouts von der Watch, sobald sie in der iPhone-App sind; keine
     Herzfrequenz/Energie/Strecke aus Health.
   - Nina: `value` für in Nina erfasste Werte (`kcal`, `protein_g`, `carbs_g`, `fat_g`, `water_ml`); aus Health
     importierte Lebensmittel nicht (oder `origin: health`).
   - Finn: nur was Bini je Kennzahl einschaltet: `net_worth` (`agg: last`, monatlich oder bei Änderung),
     `spending` als Tagessumme je zugeordneter Finn-Gruppe; nur eigene Daten, nie die geteilte Haushaltszone;
     Währung `EUR`.
2. Bericht: Binis Aufgaben (Reihenfolge), die Prompts, offene Fragen.

### 1.7 Sonstiges
1. Version 1.9.0, Tour 10: Karten `goal-results` („Ergebnisse und Wochen über 8“), `reading` („Leseliste“),
   `segments` („Abschnitte“), `connected-apps` („Verbundene Apps“), alle `since: 10`.
2. Demo (`-Demo` und Übung): zwei Abschnitte (Abschnitt 1 endet vor 6 Wochen), Ergebnisse (`count` „Bücher“ mit Liste,
   `check`, `value` mit `measure:`), drei Bücher (eins fertig in Abschnitt 1, eins läuft mit Fortschritt an drei Tagen,
   eins geplant), Kategorie-Wochennoten, Austausch-Fixtures (Quelle „Demo“: zwei PH, ein Workout, kcal/Protein).
3. CI-Screenshots zusätzlich: `goal-detail`, `reading`, `connected-apps` (iPhone und Mac; aus Demo-Daten, ohne App Group).
4. Doku: `docs/CONNECTED_APPS.md`, IMPORT.md (`link`-Werte `app:`/`list:`, Zeile `record`), TOUR.md, TESTING „v10“,
   STATUS, ARCHITECTURE, HANDBOOK_PROPOSALS (Austausch-Modul + Format, `SettingRecord`, `MeasureSource.other`).

## 2. Pakete
- **P1 Core** (`Packages/ThaliaCore`, Tests `V10Tests.swift`, Fixtures): `SettingRecord` (+ unbekannte Felder),
  `GoalResult`/`GoalEntry` + `ResultProgress`, `GoalTrack` + Kategorie-Noten-Text, `ListItem`/`ListProgress` +
  `ListMath`, `GoalSegment` + `Segments`, `ExchangeFormat.swift` (Tagesdatei, Tatsache, Herkunft, Kennzahl-Tabelle,
  `source.json`, Katalog, tolerant lesen, FNV-1a), `LinkRule`, `MeasureSource.app`/`.list`, `ExchangeDerivation`,
  `Measures.merged`, CSV `record`, PlanPrompt/WeekReport-Block + Link-Regel, CSV-Prüfung, Quelle der Vorwoche beim
  Import, Tour 10, Demo-Daten.
- **P2 Shared**: Store-API für `SettingRecord` (lesen mit Prädikat, speichern, löschen, Papierkorb, Undo), Ergebnisse +
  Einträge, Listen + Fortschritt, Abschnitte (beginnen als Undo-Gruppe, Schnappschuss), Einfrieren (Grundregel 2),
  `score.`-Speichern + Nachtragen, `touchedWeeks` für neue Schlüssel, `ExchangeInbox` (lesen, Eingang, Katalog schreiben,
  Entitlement-Prüfung, Auslöser), WeekContext (Abschnitt, Ergebnisse, GoalTrack, abgeleitete Einträge/Arbeit/Haken,
  `Measures.merged`), WeekReader-Abfragen, Export/Backup, v9-Abfragen filtern.
- **P3 App**: Ziele-Seite (Jahreskarte mit Abschnitt, Karten mit „über 8“, Ergebnis-Zeile, Messwert-Chips, „Gerade
  dabei“, frühere Abschnitte), Zielseite + Ergebnis-Editor, Leseliste + Buch-Fenster, Erfassen-Optionen, Abschnitt-
  Assistent, Einstellungen „Verbundene Apps“, Heute (abgeleitete PH/Haken „aus …“, Übernehmen), Ausgaben (Finn-Zeilen),
  Messwert-Editor „Quelle“, Rückblick `.segment` + Grenzen, Zielüberprüfung, PDF-Zeitraum, Woche „Neu berechnen“,
  Erklärungen, Tour, Screenshots, Version.
- **P4 Doku**: CONNECTED_APPS.md mit Aufgaben und Prompts, IMPORT, TOUR, TESTING, STATUS, ARCHITECTURE, Handbuch-Vorschläge.

## 3. Tests (V10Tests, Auswahl)
- B1 `SettingRecord`: JSON hin und zurück; fehlende Felder; **unbekanntes Feld überlebt Speichern**; Schlüssel mit Tag.
- B2 `ResultProgress`: check mit Datum; count aus Einträgen, aus Liste (nur fertig im Zeitraum, „zählt für“ vor Art),
  aus `measure:` (Summe); value ≥ und ≤ mit Start; Soll und Status; Anteil je Abschnitt aus Datum; Ziel je Abschnitt.
- B3 `GoalTrack`: 8,00 zählt, 7,994 nicht (Rundung wie Anzeige); entschuldigte Woche; Ziel nur wenn jede Kategorie.
- B4 `ListMath`: Menge je Tag aus Fortschritt, rückwirkend eingefügt, nie negativ; fertig im Zeitraum.
- B5 `Segments.resolve`: keiner → einer; zwei lückenlos; rückwirkend; je Zieljahr; Bezeichnung alter Wochen.
- B6 `ExchangeFormat`: Fixtures lesen; fehlende optionale Felder; unbekannte Art; falsche Quelle zum Ordner; kaputte
  Datei → Grund; FNV-1a stabil; Datumsformen.
- B7 `ExchangeDerivation`: Haken nur ohne eigene Markierung (auch geleerte gewinnt); nur an geltenden, nicht
  entschuldigten Tagen; PH mit Kategorie aus `thalia` vor Zuordnung; eigener Block mit `importID` ersetzt;
  `origin: health` wird ignoriert; Tatsache verschwindet → Wirkung weg; zwei gleiche Tagesdateien → einmal.
- B8 `MeasureSource`: `app:nina:kcal`, `app:george:workout=tpl-1`, `list:buch` hin und zurück; **unbekannter Text
  bleibt unverändert** (`other`).
- B9 `Measures.merged`: eigener Eintrag ersetzt App-Wert; Stepper-Basis; leeren.

## Nachträge (Umsetzung)

Was bei der Umsetzung genauer oder anders wurde als oben geplant. Der Plan oben bleibt stehen; bei Abweichungen gilt
dieser Abschnitt.

### P1 Core
- `ExchangeDerivation.week(…)` liefert die Struktur `ExchangeEffect` statt eines Tupels: neben `entries`, `work` und
  `marks` auch `unassignedWork` („ohne Zuordnung“), `additiveCodes`, `markLabels`, `workSources`, `entrySources`,
  `unused`, `ignored` und `markValues`. Eine Tatsachen-id zählt je Datei einmal (die letzte Zeile gewinnt,
  `ExchangeDerivation.latest` / `uniqueFacts`) – Woche, Ergebnisse, Verläufe und „Verbundene Apps“ zählen gleich.
- `Measures.merged(own:health:external:additive:)` hat den zusätzlichen Parameter `additive`: Ausgaben aus Finn werden
  nicht ersetzt, eigene Ausgaben kommen dazu (§1.5.3).
- Kategorie einer Tatsache: ihr `thalia.category`, sonst das einer anderen Tatsache derselben Gruppe und Quelle
  (`groupChoices`), sonst die `LinkRule` – das Beispiel in §1.5.2 nennt die Kategorie nur bei der Aufgabe.
- Punkte dürfen direkt auf einen `app:…`- oder `list:…`-Text verweisen; Core legt dafür einen verborgenen Messwert an
  (`ExchangeDerivation.virtualMeasures`).
- Quelle der Vorwoche beim Import (§1.5.4) gilt für jede Quelle (`arbeit:`, `health:`, `app:`, `list:`); eine auf
  manuell gesetzte Quelle bleibt manuell; ein Hinweis je Woche in den Warnungen der Vorschau.
- `record`-Zeilen (§1.1.4) lesen nur Schlüssel der v10-Präfixe (`SettingKeys.all`), Alias `datensatz` / `records`;
  `archive.<Woche>` bleibt in den `category_score`-/`goal_score`-Zeilen. Sie stehen am Ende und nur, wenn es welche gibt,
  so bleiben alle anderen Exporte byte-gleich.
- `ResultProgress.Status` hat zusätzlich `.missed` („nicht erreicht“, wenn der Zeitraum vorbei ist) und `.untargeted`
  (ohne Ziel). Mit einem Ziel für den aktuellen Abschnitt zählen `count`-Ergebnisse samt Tempo im Abschnitt („1 von 2
  in Abschnitt 2 · 3 im Zieljahr“); `value`-Ergebnisse rechnen das Tempo ab dem Wert vor dem Abschnitt.
- Liste als Quelle ohne zugeordnete Einträge: fertige Einträge der Art zählen, aber keine, die einem anderen Ergebnis
  zugeordnet sind; ohne Art gilt „buch“.
- Bezeichnungen alter Wochen kommen aus dem Schnappschuss des nächsten Abschnitts (Stand am Ende des Abschnitts),
  sonst aus dem eigenen. Der stillschweigende „Abschnitt 1“ hat die feste id `first-<periodStart>`.
- „Über 8,0“ ist umgesetzt als gerundet ≥ 8,00 (`GoalTrack.threshold`) – Annahme, siehe offene Fragen.
- Lesefehler im Austausch haben deutsche Gründe (`ExchangeReadError.reason`, zusätzlich `wrongType` und
  `elementNotAnObject`).
- Tour 10: `goal-results`, `reading` und `segments` stehen nach „review“, `connected-apps` nach „everywhere“. Zwei
  bestehende Tests sind angepasst (`CSVTests.tourCatalogIsValid`; `CalendarTests.sources`: `app:nina:kcal` ist jetzt
  `.app`, `health:carbs` bleibt `.other`).
- Demo (§1.7.2): neue Eigenschaft `Demo.Content.records` (auch in `document.records`); die laufende Woche hat drei
  Messwerte mit Quelle `app:demo:…` (workouts, kalorien, protein), Punkt 1.2-01 „Krafttraining“ ist mit „workouts“
  verknüpft. Grundregel 5 sagt „aus Fixture-Dateien“ – die App kann Test-Ressourcen nicht lesen, darum baut die Demo
  ihre Tagesdateien im Code; `Fixtures/exchange/Demo/` enthält denselben Inhalt für den 22. Nov. 2026, ein Test hält
  beides gleich. `Package.swift`: Test-Ressourcen `.copy("Fixtures")`.
- Neue öffentliche Helfer: `AppSource.kindChoices`, `refChoices(_:)`, `label(refs:)` (Messwert-Editor),
  `ExchangeDerivation.uniqueFacts(_:)`, `Demo.exchangeSourceInfo(today:timeZone:)`, Parameter `timeZone` bei
  `Demo.exchangeInbox`.

### P2 Shared
- Neue Datei `Shared/ExchangeInboxReader.swift` mit `ExchangeScan`, `ExchangeFolders` und `ExchangeMonitor` (nicht auf
  der Watch) – nicht „ExchangeInbox“, weil Core schon das öffentliche `ExchangeInbox` (Schlüssel und Werte) hat. Die
  Datensätze liegen in `Shared/TrackerStore+Records.swift`.
- `Trash.records` (§1.1.3) ist aufgeteilt in `results`, `listItems` und `segments` (plus `recordCount`). Einzelne
  Einträge, Seitenstände und Zuordnungen stehen nicht im Papierkorb: sie werden über `RecordChange` widerrufen und
  nach 30 Tagen entfernt.
- `touchedWeeks` lässt `score.<Woche>` aus – das ist das Ergebnis der Wertung, keine Eingabe.
- `storeFinalScore` schreibt bzw. löscht `score.<Woche>` nur für Wochen mit Punkten oder Archivnoten; Papierwochen
  behalten, was sie haben. Das einmalige Nachtragen schreibt `score.` auch für eingefrorene Wochen des Zieljahrs (sie
  hatten nichts, und „Frühere Abschnitte“ braucht sie).
- Tatsachen mit `origin: health` werden entfernt, bevor eine Tagesdatei in den synchronisierten Eingang kommt; „Was
  kommt an“ zeigt sie darum nie.
- Eine Quelle mit Tagesdateien, aber noch ohne `source.json`, bekommt einen Platzhalter in `x.sources`.
- Einfrieren am Ende eines Imports: Eine Woche, die der Import erst abschließt, bekommt ihre erste Wertung auch dann,
  wenn sie eingefroren ist (auch nach „Archivdaten ersetzen“). Bereits abgeschlossene, eingefrorene Wochen werden
  übersprungen und in `ImportResult.frozenWeeks` / `frozenHint` genannt; Noten einer solchen Archiv-Woche ohne
  „ersetzen“ neu einzulesen braucht danach „Neu berechnen“ in der Woche.
- Für Ergebnisse mit `measure:`- oder `app:`-Quelle kommt der Verlauf aus `store.resultSeries`; `context.needsSeries`
  sagt, wann. Die Datensätze in WeekContext sind faul berechnete Eigenschaften (`WeekRecords`).
- `lastValue` nutzt jetzt auch bestätigte Health-Werte (über `Measures.merged`, B9); `countsAsMissing` ist für
  `app:`-/`list:`-Messwerte falsch; `suggestionsToFill` lässt abgeleitete Haken aus; `expensesByPurpose` enthält die
  Zeilen aus der App.
- Schalter „Thalia-Katalog bereitstellen“ = synchronisierte Einstellung `exchange.catalog` (`aus` = aus, Standard
  ein); ausgeschaltet löscht das nächste Nachsehen `catalog.json`. Erstes Nachsehen 5 s nach dem Start, Auslöser 2 s
  entprellt.
- Neue Parameter mit Standardwert (alte Aufrufe bleiben gültig): `weekContext(for:today:goalYear:)`,
  `periodReport(period:through:from:)`, `reportInput(results:)`, `setMarkNote(_:item:day:derived:)`; `save()` läuft
  über `commit(rescoring:)`. `beginSegment(startWeek:title:reason:today:)` gibt `RecordChange?` zurück (nil, wenn die
  Startwoche nicht erlaubt ist).
- `mergeDuplicates` fasst auch Arbeitsblöcke mit derselben, nicht leeren `importID` zusammen („Übernehmen“ auf zwei
  Geräten).

### P3 App
- Neue Dateien `App/Sources/GoalResults.swift`, `ReadingList.swift`, `Segments.swift`, `ConnectedApps.swift`.
- Die neuen Fenster öffnen meist als **eigene Fenster der Seite** (`thaliaLocalSheet`), nicht über das eine Fenster
  der App; zusätzliche `AppSheet`-Fälle für Wege von außen, Menü, Tour und Screenshots: `goalEntry`, `reading`, `book`,
  `readingList`, `beginSegment`, `resultEditor`, `connectedApps` (dazu `-DemoScreen goal-detail`, `reading`,
  `connected-apps`).
- Neue Ziele und Kategorien (Einstellungen → Jahresziele) legt die App direkt als `AnnualGoal`/`TrackCategory` an –
  es gibt dafür keine eigene Store-Funktion.
- „Neu berechnen“ steht nur in eingefrorenen abgeschlossenen Wochen (`FrozenWeekNote` in Woche und Wochentabelle).
- Mit nur einem Abschnitt bleibt die Abschnitt-Oberfläche verborgen (kein „Abschnitt 1“ auf den Karten, kein
  `.segment` im Rückblick, kein „Ziel in Abschnitt …“) – `Segments.hasSeveral`.
- `verifyPrefixQuery()` läuft in Debug-Builds 8 s nach dem Start aus `AppModel` (nicht in `LaunchDiagnostics`),
  zusammen mit dem Nachtragen der Kategorie-Noten; `ExchangeMonitor.setActive` hängt an den Aktiv-/Hintergrund-
  Benachrichtigungen der App.
- „Verbundene Apps“ zählt Tatsachen als „Meldungen“ („12 Meldungen an 9 Tagen · letzte 30 Tage“).
- Messwert-Editor „Quelle“: die neue Quelle schlägt die Einheit vor (PH, die Einheit der Leseliste, die der App; eine
  Kennzahl in € schlägt nichts vor – ein Messwert in € ist ein Ausgaben-Messwert); die Woche summiert bei PH, Liste,
  gezählten und summierten App-Arten, eine Kennzahl nimmt ihre Regel (`agg: last` → letzter Wert), sonst wie bisher
  nach Einheit.

### Lückenschluss (nach der Prüfung)
- **`x.sources` aus allen Kopien:** zwei Geräte, die verschiedene Apps sehen, schreiben vor dem Abgleich je eine Kopie;
  der Wert hat keinen Zeitstempel. Gelesen wird darum die Vereinigung aller Kopien (`ExchangeSourceList.merged`, je
  Quelle das neueste `source.json`) – in `exchangeSources()`, `weekSettings`, WeekContext und WeekReader; das nächste
  Nachsehen schreibt eine zusammengeführte Kopie. Ein Backup ersetzt `x.sources` nie, es wird zusammengeführt
  (`SettingRow.resolved`, auch in der Vorschau).
- **Kopien eines Tages überall gleich:** `ExchangeInbox.isPreferred` (späteres `generatedAt`, bei gleichem der größere
  kanonische Text) entscheidet in `files(from:)` und `ExchangeDerivation.latest`; `storeInbox` vergleicht mit
  derselben Wahl. Eine abweichende Datei ohne lesbares `generatedAt` (fehlt, ohne Zeitzone) wird übernommen, statt
  die erste Kopie für immer zu behalten.
- **Nur Tatsachen mit `origin: app` kommen in den synchronisierten Eingang** (`ExchangeInbox.syncable`) – auch
  fehlende oder andere Herkunft, nicht nur `health`; `record`-Zeilen `x.<Quelle>.<Tag>` eines Backups werden beim
  Lesen ebenso gekürzt (`syncableValue`), eine unlesbare wird übersprungen. Auch das Schreiben des Backups kürzt so
  (`storedRecordRows`) – falls ein früher Build von v10 noch andere Tatsachen gespeichert hat – und nimmt bei zwei
  Kopien eines Tages die, die die Wochen lesen (`isPreferred`), damit eine Wiederherstellung dieselben Werte zeigt.
- **Geleerte Haken überleben Backup und Wochen-Schnappschuss:** Exporte enthalten eine Markierung ohne Wert, wenn sie
  eine Notiz trägt oder ihr Punkt mit einem `app:`-Messwert verknüpft ist (`MarkRecord.exported`); der Import legt sie
  als geleerte an. Andere geleerte Markierungen bleiben draußen (die Exporte bleiben sonst gleich).
- **Zusammenführen zweier Kopien einer Markierung:** der Wert der neuesten gilt, auch ein leerer (`collapse`); nur
  eine leere Notiz wird aus einer älteren Kopie ergänzt.
- **Notiz an einem abgeleiteten ✓ (bewusst so):** `setMarkNote(_:item:day:derived:)` legt die Markierung mit dem ✓
  an, sonst nähme die Notiz den Haken weg (eine eigene Markierung gewinnt, auch ohne Wert). Verschwindet die Tatsache
  später in der Quelle, bleibt der ✓ als eigener stehen – wie jeder selbst gesetzte.
- **Schonfrist beim Einfrieren:** in der ersten Woche eines Abschnitts (auch eines neuen Zieljahrs) ist die Woche
  direkt davor noch nicht eingefroren – sie wurde eben erst abgeschlossen (oft am Mac ohne Apple Health), und das
  iPhone bzw. späte Einträge am Montag geben ihr noch ihre Wertung. Ein rückwirkend begonnener Abschnitt friert sofort
  ein (`Segments.isFrozen`).
- **Art eines Buchs geändert:** `saveListItem` wertet die abgeschlossenen Wochen seiner Seitenstände neu (der
  Schlüssel `list.item.` hat keinen Tag).
- **Nachtragen der Kategorie-Noten:** statt eines einmaligen Merkers merkt sich jedes Gerät die schon angesehenen
  abgeschlossenen Wochen (`score.backfill.v10.weeks`) und läuft nach dem Start und nach jedem Abgleich – Wochen, die
  auf einem frisch eingerichteten iPhone erst später ankommen, bekommen ihre Noten auch.
- **Abschnitte:** ein bereits geplanter Abschnitt (beginnt nach heute, `Segments.upcoming`) bekommt im
  Ergebnis-Fenster ein eigenes Feld „Ziel in Abschnitt 2 (ab KW48, optional)“; ein neues Ergebnis gilt dann ab ihm.
  Ergebnisse eines noch nicht begonnenen Abschnitts stehen auf der Zielseite mit „Gilt ab Abschnitt 2 (KW48)“. Ein
  zweites „Neuen Abschnitt beginnen…“ bietet frühestens die Woche nach dem geplanten an (`earliestStart`) und zählt
  weiter („Abschnitt 3“) – ein rückwirkender Start innerhalb des laufenden Abschnitts geht dann erst nach dem
  geplanten. Zwei gespeicherte auf derselben Woche (zwei Geräte): der ältere steht in Einstellungen → Jahresziele als
  „doppelt“ und lässt sich löschen (`Segments.hidden`). Unbekannte Felder in den Schnappschüssen bleiben erhalten.
- **Bezeichnungen alter Wochen** auch im Wochenblatt und in der Wochentabelle (`WeekContext.title(of:)`).
- **Leseliste als Quelle:** die Watch zeigt solche Messwerte nur an („mit „Lesen“ am iPhone eintragen“), „Messwert
  eintragen“ führt zu „Lesen“, die App-Kurzbefehle lehnen ab – Seiten werden nur einmal eingetragen.
- **Wochenberichte** (Wochenabschluss, Import → „Wochenbericht kopieren“, Woche → „Text für ChatGPT“) enthalten den
  Block „Jahresziel-Ergebnisse“ (`reportInput(results:)`).
- **Messwert-Editor:** eine Kennzahl (`kcal`, `net_worth` …) bietet kein „Eintrag“ an (`refChoices` leer) – der `ref`
  einer Wert-Tatsache ist die Kennzahl selbst.
- **Kategorie aus der Quelle:** eine spätere Tagesdatei, in der keine Tatsache einer Gruppe ein `thalia` trägt, beendet
  die Wahl der Quelle für diese Gruppe (`groupChoices`) – Thalias eigene Zuordnung zählt dann wieder.
- **Namen der Quellen** aus `source.json` (`app`, z. B. „TimeTracker“) in „aus …“ und „Was kommt an“.
- **Lesen im App-Group-Ordner:** abgelehnte oder teilweise kaputte Dateien werden bei jedem Nachsehen wieder gelesen,
  ihr Grund bleibt in „Verbundene Apps“ stehen; Dateien über 256 KB werden mit Grund ausgelassen.
- **Import eingefrorener Wochen:** die Meldung nach dem Import nennt sie in einer zweiten Zeile („KW40 nicht neu
  gewertet“, passt auch am iPhone in eine Zeile); die Woche selbst sagt warum und hat „Neu berechnen“.
- **Nicht geändert (dokumentiert):** Beim ersten Nachsehen nach dem Update kommen bis zu 62 Tage einer Quelle an und
  werten abgeschlossene Wochen des laufenden Abschnitts neu; von Hand in 1.8.0 eingetragene PH für dieselbe Arbeit
  zählen dann doppelt. Das klärt nur Bini (eigene Blöcke löschen oder nicht mehr doppelt erfassen) –
  `docs/CONNECTED_APPS.md` „Deine Aufgaben“ sagt es.

### P4 Doku
- `docs/CONNECTED_APPS.md` (neu): Erklärung für Bini, „Deine Aufgaben“, je ein vollständiger Auftrag für Theo, George,
  Nina, Finn und weitere Apps (Format v1, Regeln, Beispielcode, Testdateien). Das Schreiber-Beispiel darin ist gegen
  `ExchangeFormat.swift` in Swift 5 und 6 übersetzt und mit einem temporären Ordner geprüft.
- Festlegungen der Aufträge über §1.5/§1.6 hinaus – Vorgaben an die anderen Apps, Thalia hängt von keiner ab: ids mit
  Präfix je Art aus der synchronisierten id; eine Tagesdatei nur neu, wenn sich ihre Tatsachen ändern (`generatedAt`
  bleibt stabil, feste Reihenfolge nach `at` und `id`); bei jedem Anlass Abgleich der letzten 62 Tage; ein Tag mit Datei
  und ohne Tatsachen bekommt `"facts":[]`; `source.json` sofort bei geänderten `refs`, sonst höchstens täglich;
  Zuordnung in der Quelle unter einem Schlüssel wie `thalia.mapping`; Theo `ref` `"ohne-gruppe"`, George `ref`
  `"frei"`; Nina eine Tagessumme je Kennzahl (`kcal-<Tag>`); Finn `sp-<Gruppe>-<Tag>`, Vermögen `nw-<Tag>` (bei
  Änderung) oder `nw-<JJJJ-MM>` am Monatsletzten (monatlich), Sparquote optional; je App ein Schalter „An Thalia
  liefern“ (Finn je Kennzahl, Standard aus).
- IMPORT.md: `link`-Werte `app:` / `list:`, direkte Verknüpfung, Quelle der Vorwoche, Zeilenart `record`.
  ARCHITECTURE.md: die neuen Teile in Core, Shared und App. HANDBOOK_PROPOSALS.md: Vorschläge 31–35 (Austausch-Modul
  und Format, Katalog, `SettingRecord`, `MeasureSource.other`, Entitlement-Prüfung am Mac).
- TOUR.md: Tour 10 mit 21 Karten und den „Neu in Thalia“-Listen. TESTING.md „v10 (ab Version 1.9.0)“: Prüfliste für
  das Gerät, nach den Entscheidungen 1.1–1.7 gegliedert; die Linux-Prüfungen stehen in STATUS.md „Stand v10“ (dort
  auch der Stand von P3 beim Schreiben). Bezeichnungen der Oberfläche, die es beim Schreiben noch nicht gab
  („Erfassen“ → „Jahresziel eintragen“ / „Lesen“, Heute „aus Theo“ / „Übernehmen“, Ausgaben „aus Finn“,
  Messwert-Editor „Quelle“, Punkt-Editor mit der Verknüpfung, „zählt für …“ in „Wochenziele“, „Zuletzt gelöscht“ mit
  Ergebnissen, Büchern und Abschnitten, Einstellungen → „Verbundene Apps“ mit „Ohne Zuordnung“, „Zuordnung prüfen“,
  „Was kommt an“), folgen dem Plan; die übrigen sind mit dem Code von P3 abgeglichen: die Leseliste hat „+“ mit „Buch
  hinzufügen“, die Karte „Gerade dabei“ erscheint erst ab dem ersten Buch (davor über Jahreskarte → ••• →
  „Leseliste“), das Ergebnis-Fenster hat „Ziel in Abschnitt 2 (optional)“ statt einer Liste je Abschnitt, der
  Abschnitt-Assistent „Beginnt mit“, und „✓ über 8“ steht auch am Kategorie-Kopf der Woche.

### Offene Fragen an Bini
1. „Über 8,0“: ab 8,00 (umgesetzt) oder erst ab 8,01?
2. Finn – Vermögen „monatlich“ oder „bei Änderung“, Sparquote gewünscht?
3. Darwin-Benachrichtigung zwischen zwei Mac-Apps in der Sandbox ist ungeprüft; Thalia liest ohnehin beim Start, im
   Vordergrund und alle 5 Minuten.
