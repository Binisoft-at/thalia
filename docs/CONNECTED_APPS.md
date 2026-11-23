# Verbundene Apps – Binisoft-Austausch (Format v1)

Ab Thalia 1.9.0 liefern andere Binisoft-Apps Thalia automatisch Daten: Theo erledigte Aufgaben und Power-Hours, George
Workouts, Nina Kalorien und Makros, Finn Ausgaben, Vermögen und Sparquote – ab Thalia 1.10.0 auch Kontostände. Diese
Seite erklärt, wie das funktioniert, was du dafür tun musst, und enthält je App einen Auftrag zum Einfügen in deren
Session. Plan: [TASKS-v10.md](TASKS-v10.md) §1.5–1.6; Finn ab 1.10.0: [TASKS-v11.md](TASKS-v11.md) §1.5.

Inhalt: [1. So funktioniert es](#1-so-funktioniert-es) · [2. Deine Aufgaben](#2-deine-aufgaben) ·
[3. Aufträge für die anderen Apps](#3-aufträge-für-die-anderen-apps) · [4. Für Entwickler: was wo liegt](#4-für-entwickler-was-wo-liegt) ·
[5. Offene Fragen](#5-offene-fragen)

## 1. So funktioniert es

```
 auf einem Gerät (iPhone, iPad oder Mac – jedes für sich)

 Theo, George,   schreiben   App Group group.at.binisoft.shared       liest    Thalia
 Nina, Finn    ───────────▶  <App>/exchange/source.json          ─────────▶  (rechnet)
                             <App>/exchange/days/JJJJ-MM-TT.json                │
               ◀───────────  Thalia/exchange/catalog.json        ◀─────────     │ legt ab
                  lesen                                           schreibt      ▼
                                                                  iCloud-Eingang x.<quelle>.<Tag>
                                                                                │ Sync
                                                                                ▼
                                                                  Thalia auf allen Geräten, auch der Watch
```

- **Gemeinsamer Ordner auf dem Gerät.** Alle Binisoft-Apps haben die App Group `group.at.binisoft.shared`. Jede App
  schreibt dort in ihren eigenen Ordner eine kleine Datei je Tag (`<App>/exchange/days/JJJJ-MM-TT.json`) und eine
  `source.json` (wer sie ist, welche Gruppen, Vorlagen und Kennzahlen es gibt). Die Tagesdatei entsteht immer
  vollständig aus dem eigenen iCloud-Speicher der App – darum ist es egal, auf welchem Gerät du etwas erledigt hast:
  Theo auf dem iPhone kennt nach seinem Sync auch die am Mac erledigten Aufgaben.
- **Thalia liest und legt in ihren Eingang.** Thalia sieht nach beim Start, im Vordergrund, alle 5 Minuten solange sie
  offen ist, nach ihrem eigenen iCloud-Abgleich, beim Tageswechsel und wenn eine App „etwas Neues“ meldet. Je App und
  Tag speichert sie die Datei im synchronisierten Eingang; ab da sehen alle Geräte mit Thalia die Werte – auch die
  Watch. Der Eingang kommt in die Sicherung („Sicherung erstellen…“), denn die Apps räumen ihre Dateien nach 62 Tagen
  auf.
- **Berechnet, nicht geschrieben.** Thalia legt für fremde Daten nie eigene Haken, Arbeitsblöcke oder Einträge an. Sie
  rechnet sie in jeder Woche dazu, so wie heute die Werte aus Apple Health. Verschwindet etwas in der anderen App (eine
  Aufgabe wieder offen), verschwindet auch die Wirkung in Thalia.
- **Eigenes gewinnt immer.** Ein eigener Haken – auch ein geleerter – geht vor dem abgeleiteten; ein eigener Eintrag
  für Messwert und Tag ersetzt den Wert aus der App; „Übernehmen“ macht aus einem Power-Hour-Block „aus Theo“ einen
  eigenen. Eine Notiz an einem abgeleiteten ✓ macht ihn zum eigenen – er bleibt, auch wenn die Tatsache später
  verschwindet. Abgeschlossene Wochen vor dem aktuellen Abschnitt bleiben, wie sie gewertet wurden (nur „Neu
  berechnen“ in der Woche ändert sie).
- **Grenze: dasselbe Gerät.** Die App Group ist ein Ordner auf *einem* Gerät. Werte von Theo erreichen Thalia nur über
  ein Gerät, auf dem **beide** Apps installiert sind und **Thalia geöffnet wird**. Läuft Theo nur auf dem Mac, muss
  Thalia auf dem Mac ab und zu offen sein. Hinweis in Thalia: „Werte aus anderen Apps erscheinen, sobald Thalia auf
  diesem Gerät geöffnet war.“
- **Watch-Workouts** kommen über Georges iPhone-App: George auf der Watch → Georges eigener Sync → George auf dem
  iPhone schreibt die Tagesdatei → Thalia auf dem iPhone öffnen. Auf der Watch liest und schreibt keine App
  Austausch-Dateien.
- **Apple Health nie.** Werte, die aus Apple Health stammen, gehen nie in den Austausch (Thalias Eingang liegt in
  iCloud; Richtlinie 5.1.3(ii)). Thalia liest Health wie bisher selbst auf dem Gerät.
- **Thalias Katalog.** Thalia schreibt `Thalia/exchange/catalog.json` mit ihrer Struktur – Ziele, Kategorien, Messwerte
  der Woche, Ergebnisse, nie Werte. Daraus bietet Theo im Gruppen-Editor die Auswahl „Thalia-Kategorie“ an, und Finn
  zeigt je Zeile, wofür sie in Thalia zählt (ab 1.10.0 steht bei jedem Ergebnis seine Quelle, `source`). Schalter:
  Einstellungen → Verbundene Apps → „Thalia-Katalog bereitstellen“ (Standard ein).
- **Später (nicht in 1.9.0):** ein Weg über den gemeinsamen iCloud-Container `iCloud.at.binisoft.shared` – dann muss
  Thalia nicht mehr auf demselben Gerät geöffnet werden; außerdem App Intents „Punkt erledigen“ und eine
  Aktualisierung im Hintergrund.

Was wo in Thalia ankommt:

| App | liefert | in Thalia |
|---|---|---|
| Theo | erledigte Aufgaben (`task.done`) | Messwert mit Quelle `app:theo:task` zählt die Aufgaben der Kategorie des Messwerts (`app:theo:task=<Gruppe>` die einer Gruppe); verknüpfte Punkte bekommen den Haken |
| Theo | Power-Hours (`ph`) | Heute: Arbeitsblock „aus Theo“ in der zugeordneten Kategorie (nur lesen, zählt für die Woche, „Übernehmen“); ohne Kategorie „ohne Zuordnung“ |
| George | Workouts (`workout.done`, je Vorlage) | Messwert `app:george:workout=<Vorlage>` zählt sie; ein verknüpfter Punkt wie „Krafttraining“ bekommt ✓ „⇄ George · Push“ |
| Nina | Tageswerte (`kcal`, `protein_g`, `carbs_g`, `fat_g`, `water_ml`) | Messwert `app:nina:kcal` usw. zeigt den Tageswert; ein eigener Eintrag ersetzt ihn |
| Finn | Ausgaben je Gruppe (`spending`, jede Gruppe einzeln) | Ausgaben-Messwert `app:finn:spending` (alle Gruppen) oder `app:finn:spending=<Gruppe>`: Zeilen „aus Finn – in Finn ändern“, eigene Ausgaben kommen dazu |
| Finn | Vermögen (`net_worth`, an jedem Tag mit Änderung) | Ergebnis eines Jahresziels (Art „Zielwert“) mit Quelle `app:finn:net_worth` – der letzte Wert zählt |
| Finn | Sparquote (`savings_rate`, je Monat) | Ergebnis (Art „Zielwert“) mit Quelle `app:finn:savings_rate` (letzter Wert) |
| Finn | Kontostände (`account_balance`, je Konto oder Kontogruppe, ab Thalia 1.10.0) | Ergebnis (Art „Zielwert“) mit Quelle `app:finn:account_balance=<Konto>` („Finn · Kontostand · Girokonto“, letzter Wert) – immer ein bestimmtes Konto, kein „alle“ |

Vermögen, Sparquote und Kontostände sind **Quellen für Ergebnisse**, nicht für Messwerte: ein Messwert in € zählt in
Thalia als Ausgabe. Ab 1.10.0 bietet der Messwert-Editor sie darum nicht mehr an; ein Messwert, der eine davon schon
nutzt, bleibt und zeigt „Für ein Jahresziel-Ergebnis gedacht – ein Messwert in € zählt als Ausgabe.“

In Einstellungen → **Verbundene Apps** steht je App: zuletzt gesehen, Formatversion, Tatsachen der letzten 30 Tage,
„**Ohne Zuordnung**“ (Gruppen ohne Kategorie, mit Auswahl), die Zuordnungen mit ihrer Herkunft („Zuordnung aus Theo“ /
„Zuordnung in Thalia“) und „Zuordnung prüfen“, wenn sich ein Kategorie-Titel geändert hat, darunter „**Was kommt an**“
(die letzten Tage, nur lesen; ein Kontostand mit seinem Konto, z. B. „Kontostand 1.234,50 € · Girokonto“). `-Demo`
und die Übungsseite der Tour zeigen das mit einer Beispiel-Quelle „Demo“ – der echte Speicher bekommt nie
Beispieldaten.

## 2. Deine Aufgaben

Reihenfolge einhalten – Schritte 1–3 zuerst.

1. **Alle Geräte auf Thalia 1.9.0** bringen (iPhone, iPad, Mac, Watch), *bevor* du Messwerte auf `app:…` oder
   `list:…` stellst oder Ergebnisse, Bücher und Abschnitte anlegst. Ältere Versionen behalten diese Quellen zwar
   unverändert, rechnen aber nichts damit und werten die Woche anders; Ergebnisse, Leseliste und Abschnitte kennen sie
   nicht. Finns Kontostände und die Anzeige in Finn, wofür eine Zeile zählt, brauchen Thalia 1.10.0 auf allen Geräten
   (1.9.0 behält Kontostände als „nicht verwendet“ und schreibt den Katalog ohne `source`).
2. **Thalia einmal auf jedem Gerät öffnen**, nach dem Update – vor allem auf den Geräten, auf denen Theo, George, Nina
   oder Finn laufen. Nur dort kommen deren Werte an; später reicht es, Thalia dort ab und zu zu öffnen.
3. **App Group im Apple-Developer-Portal prüfen:** Certificates, Identifiers & Profiles → Identifiers → die App IDs von
   **Theo, George, Nina und Finn** (iPhone/iPad und Mac) → *App Groups* eingeschaltet und **`group.at.binisoft.shared`
   zugewiesen** („Configure“ ist ein eigener Klick nach dem Einschalten). Widget- und Watch-App-IDs nur, wenn diese Ziele
   selbst schreiben – nach den Aufträgen tun sie das nicht. Thalias eigene App IDs haben die Gruppe schon. Danach baut
   die CI neue Profile wie gewohnt.
4. **Aufträge einfügen – erst, wenn Thalia v10 auf `main` ist:** jeder Auftrag verlinkt `ExchangeFormat.swift` und die
   Testdateien auf `main`; vorher liefern die Links 404, und die Session baut das Format von Hand nach, statt die Datei
   zu kopieren. Dann je App den Auftrag aus Abschnitt 3 in die Session ihres Repos kopieren (ein Block = ein Auftrag,
   nichts weglassen). Fragen der Session beantworten; ihr Bericht nennt Bundle-IDs, Schalter und offene Punkte.
   **Mit Thalia 1.10.0:** den neuen Finn-Auftrag (3.4) erst einfügen, wenn 1.10.0 auf `main` ist – er braucht die neue
   `ExchangeFormat.swift` mit `account_balance`. Theo, George und Nina, die ihren Auftrag schon umgesetzt haben, holen
   nur diese neue Datei (nur Zusätze, Abschnitt 4); sonst ändert sich für sie nichts.
5. **Nach ihren Builds** (TestFlight, auf denselben Geräten installiert): jede App einmal öffnen und die Schalter
   „An Thalia liefern“ prüfen – in Finn jede Zeile einzeln einschalten (Standard aus) – daneben steht, wofür sie in
   Thalia zählt (bis du in Schritt 7 und 8 verknüpft hast: „noch nicht in Thalia verknüpft“). Dann Thalia öffnen →
   Einstellungen → Verbundene Apps: die Apps erscheinen mit „zuletzt gesehen“.
6. **Zuordnen:** in Theo im Gruppen-Editor „Thalia-Kategorie“ wählen (dafür muss Thalia auf diesem Gerät einmal offen
   gewesen sein, „Thalia-Katalog bereitstellen“ an) – und/oder in Thalia unter Einstellungen → Verbundene Apps →
   „Ohne Zuordnung“ je Gruppe die Kategorie. Theos Wahl geht vor; „Zuordnung prüfen“ beachten.
   **Nicht doppelt erfassen:** Sobald Theo Power-Hours liefert, sie nicht mehr zusätzlich in Thalia eintragen – ein
   eigener Block und der Block „aus Theo“ für dieselbe Arbeit zählen beide. Dasselbe gilt für Ausgaben, sobald Finn sie
   liefert (eigene Ausgaben kommen zu Finns Zeilen dazu). Beim ersten Nachsehen kommen bis zu 62 Tage zurück an, und
   abgeschlossene Wochen des laufenden Abschnitts werden neu gewertet: was du dort schon von Hand eingetragen hast,
   zählt doppelt. Dann die eigenen Blöcke dieser Tage löschen – oder die Gruppe weder in Theo noch in Thalia zuordnen,
   solange du lieber von Hand einträgst: ihre Power-Hours stehen dann nur „ohne Zuordnung“ da und zählen nirgends.
7. **Messwerte verbinden:** im Messwert-Editor → „Quelle“ → „Verbundene App“ → App → Art → Eintrag (aus den Vorlagen
   und Gruppen der App; eine Kennzahl wie Kalorien oder Protein hat kein „Eintrag“ – die Art ist schon die Kennzahl;
   Vermögen, Sparquote und Kontostand gibt es hier ab 1.10.0 nicht – sie gehören zu Ergebnissen, Schritt 8), oder im
   Plan in der Spalte `link` (z. B. `app:george:workout=<Vorlagen-id>`, `app:theo:task`, `app:nina:kcal`,
   `app:finn:spending`, für Bücher `list:buch`). Punkte wie gewohnt mit dem Messwert
   verknüpfen. Der Planungs-Prompt sagt ChatGPT, Verknüpfungen unverändert zu übernehmen; fehlt eine trotzdem, behält
   der Import die Quelle der Vorwoche (Hinweis in der Vorschau). Format: [IMPORT.md](IMPORT.md).
8. **Ergebnisse, Bücher, Abschnitt:** Ziele → ein Ziel → „Ergebnisse“ → „Ergebnis anlegen“ (z. B. „Bücher“ zählen aus
   der Leseliste, „Vermögen“ als „Zielwert“ mit Quelle „Verbundene App“ → Finn → Vermögen, also
   `app:finn:net_worth`, ebenso die Sparquote; ab 1.10.0 ein Kontostand mit Finn → Kontostand → Konto, also
   `app:finn:account_balance=<Konto>` – hier gibt es kein „alle“; „Website online“ abhaken); Bücher unter Ziele →
   Jahreskarte → ••• → „Leseliste“ → + („Buch hinzufügen“) – ab dem ersten Buch auch über die Karte „Gerade dabei“;
   Stand über „Erfassen“ → „Lesen“ oder Ziele → Jahreskarte → ••• → „Lesen…“ (auch rückwirkend). Bei Bedarf Ziele →
   Jahreskarte → ••• → „Neuen Abschnitt beginnen…“.
   Gut zu wissen: Stand und Ziel eines Ergebnisses stehen im Block „Jahresziel-Ergebnisse“ des Planungs-Prompts und
   der Wochenberichte (die du in ChatGPT einfügst) und in der Sicherung („Sicherung erstellen…“) – bei „Vermögen“ oder
   einem Kontostand aus Finn also der Betrag. Werte aus Apple Health stehen dort nie. Wer das nicht will, gibt dem
   Ergebnis keine Quelle aus Finn.
9. **Nach ein paar Tagen prüfen:** Verbundene Apps → „Was kommt an“; in Heute die Blöcke „aus Theo“ und die Haken
   „⇄ George · …“; in den Ausgaben die Zeilen „aus Finn“; in Finn unter Einstellungen → „Thalia“ je Zeile
   „→ Thalia: …“.

## 3. Aufträge für die anderen Apps

Jeder Block ist vollständig – er enthält das ganze Format, die Regeln, Beispielcode und die Testdateien, weil die
anderen Sessions dieses Repo nicht zuverlässig lesen können. Den Block von der ersten bis zur letzten Zeile kopieren.

### 3.1 Theo

````markdown
# Auftrag: Theo liefert Thalia Daten (Binisoft-Austausch, Format v1)

Dieser Auftrag ist vollständig – alles Nötige steht hier, kein anderes Repo muss gelesen werden. Arbeite in diesem Repo
(Theo) nach dem Binisoft-Handbuch und den Regeln des Repos (HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST): zuerst ein
kurzer Plan in `docs/`, die Logik im Core-Paket mit Tests unter Linux, lokale Prüfung vor dem Push, Version erhöhen,
am Ende ein Bericht (§12). Bei Unklarem: fragen, nicht raten.

## 1. Worum es geht

Thalia ist Binis Planer für Wochenpläne und Jahresziele (ebenfalls eine Binisoft-App). Ab Thalia 1.9.0 können andere
Binisoft-Apps Thalia automatisch Tatsachen liefern: erledigte Aufgaben, Power-Hours, Workouts, Tageswerte, Ausgaben.
Theo schreibt dafür kleine JSON-Dateien in die gemeinsame App Group. Thalia liest sie auf demselben Gerät, legt sie
in ihren eigenen iCloud-Eingang und **rechnet** daraus Werte – Thalia legt dafür nie eigene Einträge an, und Binis eigene
Einträge in Thalia gewinnen immer. Theo liest von Thalia nur einen Katalog mit Thalias Struktur (§7). Keine App
ändert die Daten der anderen; es gibt kein Netz, keinen Server, keine Berechtigungsabfrage.

## 2. Was Theo liefert

- **`task.done`** – jede erledigte Aufgabe, eine Tatsache je Aufgabe, im Tag ihres Erledigt-Zeitpunkts (Kalendertag in
  der Zeitzone des Geräts). **Auch Aufgaben, die auf einem anderen Gerät erledigt wurden** und per Sync angekommen
  sind: Die Tagesdatei entsteht immer aus Theos synchronisiertem Speicher. Wird eine Aufgabe wieder geöffnet, fehlt
  sie in der neu geschriebenen Datei; wird ihr Erledigt-Datum geändert, werden beide Tage neu geschrieben.
  - `id` `"task-" + <synchronisierte id der Aufgabe>` · `ref` id der Gruppe · `refTitle` Name der Gruppe · `title`
    Titel der Aufgabe · `at` Erledigt-Zeitpunkt · `origin` `"app"` · `thalia` bei zugeordneter Gruppe (unten).
  - Aufgaben ohne Gruppe: `ref` `"ohne-gruppe"`, `refTitle` `"Ohne Gruppe"` – so kann Bini auch sie zuordnen.
- **`ph`** – Power-Hours, eine Tatsache je PH-Eintrag in Theo (1 PH = 50 konzentrierte Minuten): `value` in PH mit
  `unit` `"PH"` – oder Minuten mit `unit` `"min"`, Thalia rechnet 50 min = 1 PH. `id` `"ph-" + <id des Eintrags>`,
  `ref`/`refTitle` = Gruppe, `title` = woran gearbeitet wurde, `at` = Ende. Hat Theo keine PH-Einträge, `ph` weglassen
  und im Bericht sagen.
- **Gruppe → Thalia-Kategorie** (§7, für Theo Pflicht): im Gruppen-Editor die Auswahl „Thalia-Kategorie“. Jede
  Tatsache einer zugeordneten Gruppe (`task.done` und `ph`) bekommt
  `"thalia":{"category":"3.2","categoryTitle":"Kunden"}`; Gruppen ohne Wahl bekommen kein `thalia`.
- `source.json` → `refs`: alle Gruppen mit `"kind":"group"`, dazu „Ohne Gruppe“.
- Einstellungen in Theo: Abschnitt „Thalia“ mit dem Schalter „An Thalia liefern“ (Standard ein).
- Keine Werte aus Apple Health.

Was Thalia daraus macht: Power-Hours stehen in Thalias „Heute“ als Arbeitsblock „aus Theo“ in der Kategorie (nur
lesen; sie zählen für die Woche, „Übernehmen“ macht einen eigenen Block daraus). Aufgaben zählen für Thalia-Messwerte
mit der Quelle `app:theo:task` (Aufgaben der Kategorie des Messwerts) oder `app:theo:task=<Gruppen-id>`; Punkte, die mit
so einem Messwert verknüpft sind, bekommen einen abgeleiteten Haken. Ohne Kategorie stehen PH und Aufgaben in Thalia
unter „Ohne Zuordnung“, bis Bini sie in Theo oder in Thalia zuordnet – Theos Zuordnung geht vor.

## 3. Weg und Ordner

- App Group **`group.at.binisoft.shared`** (alle Binisoft-Apps haben sie). Laut Handbuch §6 liegen dort nur kleine
  Ereignisse und Zusammenfassungen, nie die Daten der App selbst.
- Ordner von Theo: `<Group>/Theo/exchange/` – der Ordnername ist der Anzeigename „Theo“, genau wie
  `AppGroupFolder.url(appName: "Theo")` aus BinisoftKit (ohne BinisoftKit:
  `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.at.binisoft.shared")?
  .appendingPathComponent("Theo")`; am Mac beides erst nach der Entitlement-Prüfung, §8). Darin:
  - `source.json` – Herzschlag und Verzeichnis der stabilen ids (§6)
  - `days/JJJJ-MM-TT.json` – eine Datei je Tag (§4, §5)
- Theo schreibt **nur** in seinen eigenen Ordner. Thalia schreibt nur `<Group>/Thalia/exchange/catalog.json`;
  Theo liest ihn nur.
- Die App Group ist ein Ordner **auf einem Gerät**. Thalia sieht nur Dateien, die auf demselben Gerät geschrieben wurden.
  Darum schreibt Theo auf **jedem iPhone, iPad und Mac**, auf dem es läuft – immer aus dem eigenen synchronisierten
  Speicher, so dass jedes Gerät denselben Inhalt schreibt. Thalia legt jede Tagesdatei in ihren iCloud-Eingang; ab da
  sehen alle Geräte mit Thalia die Werte.
- **Nie auf der Apple Watch** – dort weder lesen noch schreiben (`#if !os(watchOS)`). Was auf der Watch erfasst wird,
  kommt über den Sync von Theo auf iPhone/iPad/Mac und von dort in die Tagesdatei.
- **Nur aus dem echten Speicher** – nie aus Demo-, Screenshot-, Vorschau-, Test- oder In-Memory-Speichern (z. B. beim
  Start mit `-Demo`): Beispieldaten dürfen nie bei Thalia ankommen.

## 4. Tagesdatei – Format v1

Beispiel (eine Tagesdatei von Theo):

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"}]}
```

Felder der Datei (alle Pflicht):

| Feld | Inhalt |
|---|---|
| `v` | `1` (Zahl). Thalia liest Version 1 und höher; kleiner als 1 wird abgelehnt. |
| `source` | Quellen-id: der Ordnername klein, nur `a–z`, `0–9`, `-` – hier `"theo"`. Passt sie nicht zum Ordner, lehnt Thalia die Datei ab. |
| `day` | `"JJJJ-MM-TT"`, ein echter Kalendertag; muss zum Dateinamen passen (`days/2026-11-22.json`), sonst abgelehnt. |
| `generatedAt` | Zeitpunkt des Schreibens (Datumsform unten). Hat Thalia für Quelle und Tag schon eine Fassung, gewinnt die mit dem neueren `generatedAt`. |
| `facts` | Liste der Tatsachen des Tages (darf leer sein: `[]`). |

Felder einer Tatsache:

| Feld | | Inhalt |
|---|---|---|
| `id` | Pflicht | Stabil und auf allen Geräten gleich, in der Datei eindeutig. Aus der **synchronisierten** id des Datensatzes (z. B. sein UUID-Feld) – nie `persistentModelID` oder `NSManagedObjectID` (je Gerät verschieden). Präfix je Art, z. B. `"task-…"`. |
| `kind` | Pflicht | Art, siehe unten. |
| `origin` | Pflicht | `"app"` = in Theo selbst erfasst, `"health"` = aus Apple Health. Ohne `origin` (oder mit anderem Wert) verwendet Thalia die Tatsache nicht. |
| `ref` | empfohlen | Stabile id in der Quelle, auf die sich die Tatsache bezieht: Gruppe, Workout-Vorlage, Kennzahl, Konto. Über `ref` ordnet Bini in Thalia zu. |
| `refTitle` | empfohlen | Anzeigename von `ref` („Arbeit/Kunden“). |
| `title` | optional | Titel der Sache („Rechnung schreiben“); Thalia zeigt ihn an. |
| `value` | je nach Art | JSON-Zahl mit Punkt (`1.5`), keine Zeichenkette. |
| `unit` | optional | `"PH"`, `"min"`, `"kcal"`, `"g"`, `"ml"` … |
| `metric` | bei `value` | Kennzahl aus der Tabelle unten. |
| `currency` | bei Geld | ISO 4217, `"EUR"`. |
| `at` | empfohlen | Zeitpunkt des Ereignisses (Datumsform unten). |
| `thalia` | optional | Was in Theo aus Thalias Katalog gewählt wurde: `{"category":"3.2","categoryTitle":"Kunden"}` (§7). `measure` und `result` sind für später reserviert – weglassen. |

Kein Verweis auf Thalias Wochen-Punkte (deren Codes gelten nur eine Woche). Unbekannte Felder liest Thalia nicht,
stören aber nicht.

Arten (v1) und was Thalia damit tut:

| `kind` | Bedeutung | Felder | In Thalia |
|---|---|---|---|
| `task.done` | eine erledigte Aufgabe | `ref` = Gruppe | zählt für Messwerte `app:<quelle>:task` (Aufgaben, deren Kategorie die des Messwerts ist) und `app:<quelle>:task=<ref>` (Aufgaben dieser Gruppe) |
| `workout.done` | ein abgeschlossenes Workout | `ref` = Vorlage | zählt für `app:<quelle>:workout` (alle) und `app:<quelle>:workout=<ref>` |
| `habit.done` | eine erledigte Gewohnheit | `ref` = Gewohnheit | zählt für `app:<quelle>:habit[=<ref>]` |
| `ph` | Power-Hours (1 PH = 50 konzentrierte Minuten) | `value` in PH mit `unit` `"PH"`; mit `unit` `"min"` ist `value` in Minuten (Thalia teilt durch 50); `ref` = Gruppe | ein Arbeitsblock „aus <App>“ in der Kategorie aus `thalia.category`, sonst aus Thalias Zuordnung, sonst „ohne Zuordnung“; Summe für `app:<quelle>:ph[=<ref>]` |
| `value` | Kennzahl eines Tages | `metric`, `value` | Tageswert für `app:<quelle>:<metric>[=<ref>]` – bei `agg: sum` die Summe der Tatsachen des Tages, bei `agg: last` die letzte nach `at` (ohne `at` davor, in Dateireihenfolge) |
| `spending` | Ausgaben einer Gruppe an dem Tag (Tagessumme) | `value` (positiv), `currency`, `ref` = Gruppe | Summe für `app:<quelle>:spending[=<ref>]` |

Bei gezählten Arten (`*.done`) zählt jede Tatsache als 1; `value` wird dort nicht gelesen. Unbekannte Arten und
Kennzahlen behält Thalia und zeigt sie als „nicht verwendet“ – kein Fehler, aber keine Wirkung. Neue Arten nicht
erfinden, sondern im Bericht vorschlagen.

Kennzahlen für `value` (Tabelle v1 – sie wächst nur; eine neue Kennzahl behalten ältere Thalia-Versionen als „nicht
verwendet“):

| `metric` | `agg` | Einheit | Name |
|---|---|---|---|
| `kcal` | sum | kcal | Kalorien |
| `protein_g` | sum | g | Protein |
| `carbs_g` | sum | g | Kohlenhydrate |
| `fat_g` | sum | g | Fett |
| `water_ml` | sum | ml | Wasser |
| `net_worth` | last | € | Vermögen |
| `savings_rate` | last | % | Sparquote |
| `body_weight_kg` | last | kg | Gewicht |
| `account_balance` | last | € | Kontostand (ab Thalia 1.10.0) |

`account_balance` ist der Stand eines Kontos oder einer Kontogruppe am Ende des Tages: `ref` = id des Kontos bzw. der
Gruppe, `refTitle` = ihr Name, eine Tatsache je Konto. Thalia liest ihn nur für ein bestimmtes Konto
(`app:<quelle>:account_balance=<ref>`). Bei allen anderen Kennzahlen ist `ref` die Kennzahl selbst (`"kcal"`).

**Herkunft:** Thalias Eingang liegt in iCloud, und Gesundheitsdaten dürfen nicht nach iCloud (App Review Richtlinie
5.1.3(ii)). Darum schreibt Theo **keine Werte, die aus Apple Health stammen**. Nur wenn sich ein Wert gar nicht
anders trennen lässt, als eigene Tatsache mit `"origin":"health"` – Thalia verwirft solche Tatsachen, bevor sie
gespeichert werden.

**Datum:** ISO 8601 mit Zeitzone, **ohne Sekundenbruchteile**: `"2026-11-22T18:04:00+01:00"` (UTC: `"…Z"`). Thalia
liest auch Bruchteile, `+0100` und `Z`. Der **Tag** einer Tatsache ist der Kalendertag des Ereignisses in der Zeitzone
des Geräts (erledigt am, Ende des Workouts, Datum des Eintrags). Keine Tage in der Zukunft.

## 5. Schreiben – Regeln

1. **Eine Datei je Tag, immer vollständig** aus dem eigenen synchronisierten Speicher: alle Tatsachen des Tages, auch
   die auf einem anderen Gerät erfassten, die per Sync angekommen sind – nie nur „was auf diesem Gerät passiert ist“.
2. **Fehlt eine Tatsache** in einer vorhandenen Tagesdatei, ist sie für Thalia entfernt. Eine **fehlende Datei** heißt
   „keine Information“ (Thalia behält, was sie hat). Darum: Ein Tag, der eine Datei hatte und jetzt nichts mehr hat,
   bekommt `"facts":[]`; für Tage, die nie etwas hatten, keine Datei.
3. **Neu schreiben**, sobald sich an einem Tag etwas ändert, auch rückwirkend (ein geändertes Datum: beide Tage) –
   nach jedem eigenen Speichern (entprellt, etwa 2 s), **direkt nach dem eigenen CloudKit-Import**
   (`NSPersistentCloudKitContainer.eventChangedNotification`, `event.type == .import`, `endDate != nil`), beim Wechsel
   in den Vordergrund und beim Tageswechsel. Der einfachste sichere Weg: bei jedem Anlass alle Tage der letzten 62 Tage
   aus dem Speicher bauen und nur die geänderten schreiben (§9).
4. **Nur schreiben, wenn sich die Tatsachen geändert haben** (Vergleich ohne `generatedAt`); sonst bleibt die Datei, wie
   sie ist. Tatsachen in fester Reihenfolge (nach `at`, dann `id`), damit jedes Gerät denselben Inhalt erzeugt.
5. **Atomar:** in eine temporäre Datei im selben Ordner schreiben, dann umbenennen (`Data.write(to:options: .atomic)` tut
   das). Ordner bei Bedarf anlegen. Thalia liest nur Dateien `JJJJ-MM-TT.json` und überspringt Dotfiles und Temp-Dateien.
6. **JSON** in UTF-8, kompakt, Schlüssel sortiert, Schrägstriche nicht maskiert (`JSONEncoder` mit `.sortedKeys` und
   `.withoutEscapingSlashes`).
7. Danach – einmal je Schreibvorgang – die **Darwin-Benachrichtigung `at.binisoft.exchange.changed`** senden. Sie ist nur
   ein Hinweis: Thalia liest auch beim Start, im Vordergrund, alle 5 Minuten, solange sie offen ist, und nach ihrem
   eigenen iCloud-Import.
8. **Aufräumen:** Tagesdateien, die älter als 62 Tage sind (heute − Tag > 62), löscht Theo selbst. Thalia behält ihre
   Kopie im Eingang.
9. Das Schreiben verzögert nie den Start oder das Speichern (abseits des Main-Threads, entprellt) und zeigt nie einen
   Fehler – Probleme nur ins Log.
10. Was Bini in Theo ausschaltet, zählt wie nicht vorhanden: Der normale Abgleich schreibt die betroffenen Tage ohne
    diese Tatsachen neu, und Thalia nimmt sie für diese Tage heraus.

## 6. source.json

```json
{
  "v": 1,
  "source": "theo",
  "app": "Theo",
  "appVersion": "2.4.0",
  "generatedAt": "2026-11-22T18:04:05+01:00",
  "refs": [
    { "id": "grp-91AB", "title": "Arbeit/Kunden", "kind": "group" },
    { "id": "grp-22CD", "title": "Haushalt", "kind": "group" }
  ]
}
```

- Felder: `v` (1), `source` (wie in den Tagesdateien), `app` (Anzeigename „Theo“), `appVersion`, `generatedAt`,
  `refs` = alle stabilen ids, die Bini in Thalia auswählen können soll, je ein Objekt mit `id`, `title` und `kind`.
- `kind` eines refs: `"group"` (Gruppe von Aufgaben, Power-Hours oder Ausgaben), `"workout"` (Workout-Vorlage),
  `"habit"`, `"account"` (Konto oder Kontogruppe, ab Thalia 1.10.0), `"metric"` (Kennzahl). Thalias Editoren bieten
  unter „Verbundene App → Art → Eintrag“ die passenden an: Workouts → `workout`, Aufgaben/Power-Hours/Ausgaben →
  `group`, Gewohnheiten → `habit`, Kontostand → `account`; ein ref ohne `kind` passt zu allem. Andere Kennzahlen haben
  kein „Eintrag“ (der `ref` ihrer Tatsachen ist die Kennzahl selbst) – ein ref mit `"kind":"metric"` schadet nicht,
  Thalia bietet ihn aber nirgends an.
- Schreiben: sofort, wenn sich `refs` oder die App-Version ändern, sonst höchstens einmal am Tag (Herzschlag – Thalia
  zeigt daraus „zuletzt gesehen“). Atomar, danach die Darwin-Benachrichtigung. `source` muss zum Ordner passen.

## 7. Thalias Katalog und „Thalia-Kategorie“

Thalia schreibt `<Group>/Thalia/exchange/catalog.json` (solange „Thalia-Katalog bereitstellen“ an ist, Standard), nur
wenn sich die Struktur ändert. **Nur Struktur** – keine Werte, kein Fortschritt. Theo liest ihn nur, tolerant:
unbekannte Felder ignorieren; die Datei kann fehlen (Thalia war auf diesem Gerät noch nicht offen, oder der Katalog
ist aus).

| Feld | Inhalt |
|---|---|
| `v`, `source`, `generatedAt` | `1`, `"thalia"`, Zeitpunkt |
| `week` | die Woche, aus der die Messwerte stammen (`"2026-W47"`) |
| `segment` | aktueller Abschnitt der Jahresziele: `{"id":"seg-2","title":"Abschnitt 2"}` |
| `goals` | `[{"key":"3","title":"Arbeit"}]` |
| `categories` | `[{"key":"3.2","goal":"3","title":"Kunden","segment":"seg-2"}]` – `key` ist Text („1.1“, „5“) |
| `measures` | Messwerte der Woche, je mit `code`, `title`, `unit`, `link` (die Quelle des Messwerts, z. B. `"app:george:workout=tpl-1"`) und `category` |
| `results` | Ergebnisse der Jahresziele, je mit `id`, `title`, `kind` (`check` / `count` / `value`), `goal` und – ab Thalia 1.10.0 – `source`: woher der Wert kommt (`"app:finn:net_worth"`, `"app:finn:account_balance=acc-giro"`, `"list:buch"`); fehlt bei Ergebnissen mit eigenen Einträgen und in Katalogen von Thalia vor 1.10.0 |

Ein vollständiges Beispiel steht bei den Testdateien (§10).

**Auswahl „Thalia-Kategorie“** (ob Theo sie braucht, steht hier: Theo braucht sie – im Gruppen-Editor, siehe §2):

- Zeilen „3.2 Kunden“, gruppiert nach Ziel („3 Arbeit“), oben „Keine“; auf iPhone, iPad und Mac gleich.
- Die Wahl wird je Gruppe als JSON in einem **vorhandenen, synchronisierten Einstellungs-Datensatz** von Theo
  gespeichert, z. B. unter dem Schlüssel `thalia.mapping`:
  `{"v":1,"groups":{"grp-91AB":{"category":"3.2","categoryTitle":"Kunden"}}}` – unbekannte Felder beim Speichern
  behalten. Synchronisiert, damit jedes Gerät dieselben Tagesdateien schreibt (nicht in `UserDefaults`). So braucht
  Theo keine CloudKit-Schemaänderung; gibt es keinen solchen Datensatz, vorher bei Bini nachfragen.
- Jede Tatsache einer zugeordneten Gruppe bekommt `"thalia":{"category":"3.2","categoryTitle":"Kunden"}`. Eine geänderte
  Zuordnung schreibt die betroffenen Tage neu (der 62-Tage-Abgleich erledigt das).
- Fehlt der Katalog: die gespeicherte Wahl zeigen und darunter „Thalias Katalog fehlt auf diesem Gerät – Thalia hier
  einmal öffnen.“ Fehlt die gewählte Kategorie im Katalog oder heißt sie dort anders als `categoryTitle`: „Zuordnung
  prüfen“.
- Thalia nimmt `thalia.category` vor ihrer eigenen Zuordnung (Einstellungen → Verbundene Apps); eine Kategorie, die
  Thalia nicht (mehr) hat, übergeht sie. Es reicht, wenn eine Tatsache der Gruppe am Tag die Kategorie trägt – besser
  tragen sie alle. Ohne Kategorie steht die Tatsache in Thalia unter „Ohne Zuordnung“, bis Bini sie dort zuordnet.

## 8. App Group und Entitlement

- Jedes Ziel, das schreibt – iPhone/iPad-App und Mac-App –, hat in seinen Entitlements unter
  `com.apple.security.application-groups` die Gruppe `group.at.binisoft.shared` (im Binisoft-Template über
  `$(SHARED_APP_GROUP)`, in der Info.plist `SharedAppGroup`). Widgets und Watch schreiben nicht – dort nichts ändern.
- Im Apple-Developer-Portal muss die Gruppe den App IDs zugewiesen sein. Das prüft Bini; nenne im Bericht die
  Bundle-IDs, denen die Gruppe zugewiesen sein muss.
- **Am Mac** zur Laufzeit prüfen, ob die signierte App die Gruppe wirklich hat (`SecTaskCopyValueForEntitlement`, §9) –
  abseits des Main-Threads und nicht während des Starts. Ohne das Entitlement kann macOS sonst nach Zugriff auf Daten
  anderer Apps fragen. Auf iPhone/iPad liefert `containerURL(forSecurityApplicationGroupIdentifier:)` ohne Gruppe `nil`
  → nichts tun. Unsignierte CI-Builds: nichts tun.

## 9. Referenzcode

Thalias Referenz für das Format ist eine einzige Datei, nur Foundation, Swift 5 und 6, zum unveränderten Kopieren
(z. B. ins Core-Paket von Theo; die Typen sind `public`):
https://github.com/Binisoft-at/thalia/blob/main/Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift
– Testdateien: https://github.com/Binisoft-at/thalia/tree/main/Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange
(öffentlich auf `main`). **Stand Thalia 1.10.0:** die Datei hat nur Zusätze bekommen – die Kennzahl `account_balance`,
das Katalog-Feld `results[].source` und toleranteres Lesen (eine Zahl, die nicht endlich ist oder dem Betrag nach ab
10¹², gilt als fehlend; ein unlesbares `v` gilt als 1). Wer sie schon aus Thalia 1.9.0 kopiert hat, ersetzt sie durch
die neue Fassung; eigener Code, der sie benutzt, bleibt gültig. Die Datei enthält `BinisoftExchange` (Pfade,
Dateinamen, Aufräumen,
atomares Schreiben, Kodieren), `ExchangeOrigin`, `ExchangeKind`, `ExchangeMetric.table`, `ExchangeFact`,
`ExchangeDayFile`, `ExchangeRef`, `ExchangeSourceInfo`, `ExchangeCatalog`, `ExchangeReader` (tolerantes Lesen mit
deutschen Gründen), `ExchangeDate` und `ExchangeHash` (FNV-1a 64 Bit). Ist sie nicht erreichbar, nach §4–§8 selbst
schreiben – diese Beschreibung ist verbindlich. Die Skizze unten nutzt die Typen dieser Datei.

Schreiber im Core (nur Foundation, unter Linux mit einem temporären Ordner testbar):

```swift
import Foundation

/// Schreibt die Tagesdateien (Format v1) nach `appFolder` = <Group>/Theo.
public enum ThaliaExchangeWriter {
    /// `facts`: alle Tatsachen der letzten 62 Tage aus dem eigenen synchronisierten Speicher, nach Tag ("2026-11-22").
    /// Schreibt nur Tage, deren Tatsachen sich geändert haben, und räumt alte Dateien auf. true = etwas geändert.
    @discardableResult
    public static func sync(_ facts: [String: [ExchangeFact]], source: String, appFolder: URL, today: String,
                            now: Date = Date()) throws -> Bool {
        let manager = FileManager.default
        var changed = false
        for offset in 0...BinisoftExchange.keepDays {
            guard let day = BinisoftExchange.day(today, adding: -offset) else { continue }
            let url = BinisoftExchange.dayFileURL(appFolder: appFolder, day: day)
            let sorted = (facts[day] ?? []).sorted { ($0.at ?? "", $0.id) < ($1.at ?? "", $1.id) }
            let old = try? Data(contentsOf: url)
            if old == nil && sorted.isEmpty { continue }                 // nie eine Datei für einen Tag ohne alles
            if let old, case .success(let read) = ExchangeReader.dayFile(old),
               let same = try? ExchangeDayFile(source: source, day: day, generatedAt: read.file.generatedAt,
                                               facts: sorted).encoded(),
               same == old { continue }                                  // unverändert: generatedAt bleibt
            let file = ExchangeDayFile(source: source, day: day, generatedAt: ExchangeDate.string(now), facts: sorted)
            try BinisoftExchange.write(file.encoded(), to: url)          // atomar: temp + rename
            changed = true
        }
        let days = BinisoftExchange.daysFolder(appFolder: appFolder)
        let names = (try? manager.contentsOfDirectory(atPath: days.path)) ?? []
        for name in BinisoftExchange.expiredDayFiles(names, today: today) {
            try? manager.removeItem(at: days.appendingPathComponent(name))
            changed = true
        }
        return changed
    }
}
```

App-Schicht (nicht auf der Watch):

```swift
#if !os(watchOS)
import Foundation
#if os(macOS)
import Security
#endif

enum ThaliaExchange {
    static let appName = "Theo"
    static let source = BinisoftExchange.sourceID(appName)   // "theo"

    /// <Group>/Theo – nil ohne App Group (unsignierter Build) und am Mac ohne Entitlement. Abseits des Main-Threads.
    static func appFolder() -> URL? {
        #if os(macOS)
        guard hasAppGroupEntitlement() else { return nil }
        #endif
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BinisoftExchange.appGroup)
        else { return nil }
        return root.appendingPathComponent(appName, isDirectory: true)
    }

    /// Thalias Katalog; nil, solange Thalia ihn auf diesem Gerät nicht geschrieben hat.
    static func catalog() -> ExchangeCatalog? {
        guard let folder = appFolder() else { return nil }
        let thalia = folder.deletingLastPathComponent().appendingPathComponent("Thalia", isDirectory: true)
        let url = BinisoftExchange.exchangeFolder(appFolder: thalia).appendingPathComponent(BinisoftExchange.catalogFileName)
        guard let data = try? Data(contentsOf: url), case .success(let catalog) = ExchangeReader.catalog(data) else { return nil }
        return catalog
    }

    /// Nach dem Schreiben: Thalia darf sofort nachsehen.
    static func postChanged() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(BinisoftExchange.changedNotification as CFString), nil, nil, true)
    }

    #if os(macOS)
    /// Hat die signierte App die Gruppe? Abseits des Main-Threads, nicht beim Start.
    static func hasAppGroupEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        return (value as? [String])?.contains(BinisoftExchange.appGroup) ?? false
    }
    #endif
}
#endif
```

Anstoßen (entprellt, etwa 2 s): nach jedem eigenen Speichern, beim Wechsel in den Vordergrund, beim Tageswechsel
(`.NSCalendarDayChanged`) und nach dem eigenen CloudKit-Import (`import CoreData`):

```swift
NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                                       queue: .main) { note in
    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event,
          event.type == .import, event.endDate != nil else { return }
    scheduleThaliaSync()
}
// scheduleThaliaSync(): die Tatsachen der letzten 62 Tage aus dem Speicher bauen (reine Werte), dann abseits des
// Main-Threads: ThaliaExchange.appFolder() → ThaliaExchangeWriter.sync(…, today: ExchangeDate.day(Date())) →
// bei Änderung postChanged(); source.json nach §6. Nicht im Demo-Modus, nicht in der Vorschau, nicht auf der Watch.
```

## 10. Tests

Logik (Tatsachen bauen, Dateien abgleichen) gehört ins Core-Paket, das unter Linux getestet wird; App-Group-Pfad,
Darwin-Benachrichtigung und Entitlement-Prüfung in die App-Schicht. Tests (Swift Testing oder wie im Repo üblich):

1. Tatsachen aus neutralen Beispieldatensätzen: richtige `kind`, `id` stabil (zweimal gebaut = gleich), `ref` und
   `refTitle`, `origin` `"app"`, `at` als `JJJJ-MM-TTTHH:MM:SS+HH:MM` (oder `…Z`) ohne Bruchteile.
2. Tag nach Zeitzone: ein Ereignis um `2026-11-22T23:30:00Z` gehört in `Europe/Vienna` zum `2026-11-23`.
3. Schreiben und zurücklesen: `ExchangeReader.dayFile(data, folder: "Theo", fileName: "2026-11-22.json")` ist
   erfolgreich und `skipped` leer; `ExchangeReader.source(data, folder: "Theo")` ebenso.
4. Abgleich in einem temporären Ordner: unveränderte Tatsachen → Datei unverändert (gleiche Bytes, gleiches
   `generatedAt`); eine entfernte Tatsache → Datei ohne sie; Tag ohne Tatsachen und ohne Datei → keine Datei; Tag mit
   Datei und jetzt ohne Tatsachen → `"facts":[]`; `BinisoftExchange.expiredDayFiles(["2026-09-20.json",
   "2026-09-21.json", "2026-11-22.json", ".x.json"], today: "2026-11-22")` ist `["2026-09-20.json"]` und genau diese
   Datei wird gelöscht.
5. Die Testdateien unten lesen sich (Tagesdatei, source.json, Katalog), und die eigene Ausgabe für denselben Inhalt
   hat dieselbe Form.
6. Keine Health-Werte: aus Apple Health stammende Datensätze ergeben keine Tatsache.
7. Werden ids mit FNV-1a gebildet (`ExchangeHash.hex`): `""` → `cbf29ce484222325`, `"a"` → `af63dc4c8601ec8c`,
   `"foobar"` → `85944171f73967e8`.
8. Theo: eine Aufgabe, die per Sync von einem anderen Gerät kam, steht in der Tagesdatei; wieder geöffnet → fehlt sie;
   Erledigt-Datum verschoben → beide Tage neu; eine Gruppe mit Zuordnung gibt jeder ihrer Tatsachen `thalia`, eine
   ohne Zuordnung keiner; PH in Minuten → `unit` `"min"` (oder in PH umgerechnet); Aufgabe ohne Gruppe → `ref`
   `"ohne-gruppe"`; die Auswahl „Thalia-Kategorie“ listet die Kategorien des Katalogs unten nach Ziel.

Testdaten bleiben neutral wie diese (keine echten Namen, Beträge, Gewichte, Ziele). Testdateien aus Thalias Repo
(Ordner wie in der App Group):

`Theo/exchange/days/2026-11-22.json` – Zwei Gruppen: „Arbeit/Kunden“ mit Kategorie aus dem Katalog, „Haushalt“ ohne (landet in Thalia unter „Ohne Zuordnung“).

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"},
  {"id":"task-0B3E11","kind":"task.done","ref":"grp-22CD","refTitle":"Haushalt","title":"Keller aufräumen",
   "at":"2026-11-22T10:30:00+01:00","origin":"app"},
  {"id":"ph-81D2","kind":"ph","ref":"grp-22CD","refTitle":"Haushalt","title":"Ablage","value":0.5,"unit":"PH","origin":"app"}]}
```

`Theo/exchange/source.json`

```json
{
  "v": 1,
  "source": "theo",
  "app": "Theo",
  "appVersion": "2.4.0",
  "generatedAt": "2026-11-22T18:04:05+01:00",
  "refs": [
    { "id": "grp-91AB", "title": "Arbeit/Kunden", "kind": "group" },
    { "id": "grp-22CD", "title": "Haushalt", "kind": "group" }
  ]
}
```

`Thalia/exchange/catalog.json` – Thalias Katalog (§7) – nur Struktur; ab Thalia 1.10.0 mit `results[].source`.

```json
{
  "v": 1,
  "source": "thalia",
  "generatedAt": "2026-11-22T06:00:00+01:00",
  "week": "2026-W47",
  "segment": { "id": "seg-2", "title": "Abschnitt 2" },
  "goals": [
    { "key": "1", "title": "Gesundheit" },
    { "key": "3", "title": "Arbeit" },
    { "key": "5", "title": "Lesen" },
    { "key": "8", "title": "Finanzen" }
  ],
  "categories": [
    { "key": "1.2", "goal": "1", "title": "Sport / Verein", "segment": "seg-2" },
    { "key": "3.2", "goal": "3", "title": "Kunden", "segment": "seg-2" },
    { "key": "5", "goal": "5", "title": "Lesen", "segment": "seg-2" },
    { "key": "8.1", "goal": "8", "title": "Ausgaben", "segment": "seg-2" }
  ],
  "measures": [
    { "code": "workouts", "title": "Workouts", "unit": "Stück", "link": "app:george:workout=tpl-1", "category": "1.2" },
    { "code": "kunden_aufgaben", "title": "Aufgaben Kunden", "unit": "Stück", "link": "app:theo:task", "category": "3.2" },
    { "code": "seiten", "title": "Seiten", "unit": "Seiten", "link": "list:buch", "category": "5" },
    { "code": "ausgaben", "title": "Ausgaben", "unit": "€", "link": "app:finn:spending", "category": "8.1" }
  ],
  "results": [
    { "id": "res-web", "title": "Website online", "kind": "check", "goal": "3" },
    { "id": "res-books", "title": "Bücher gelesen", "kind": "count", "goal": "5", "source": "list:buch" },
    { "id": "res-worth", "title": "Vermögen", "kind": "value", "goal": "8", "source": "app:finn:net_worth" },
    { "id": "res-giro", "title": "Puffer Girokonto", "kind": "value", "goal": "8", "source": "app:finn:account_balance=acc-giro" }
  ]
}
```

## 11. Regeln

- **Keine CloudKit-Schemaänderung** in Theo: neue Einstellungen als JSON in einem vorhandenen Einstellungs-Datensatz;
  ein neues Feld oder eine neue Datensatzart nur nach Rückfrage bei Bini (das braucht „Deploy Schema Changes“).
- **Keine Werte aus Apple Health** (§4, Herkunft).
- **Öffentliches Repo:** keine persönlichen Daten in Code, Tests, Testdateien oder Doku – keine echten Namen, Beträge,
  Gewichte oder Ziele; neutrale Beispiele wie „Arbeit/Kunden“, „Push“, „Lesen“.
- Nie aus Demo- oder In-Memory-Speichern schreiben, nie auf der Watch.
- Bestehendes Verhalten von Theo bleibt, wie es ist. Deutsche Texte kurz und schlicht, z. B. in den Einstellungen
  ein Abschnitt „Thalia“ mit den Schaltern aus §2, „Zuletzt geschrieben: …“ und dem Hinweis „Thalia übernimmt die
  Werte, sobald Thalia auf diesem Gerät geöffnet wird.“

## 12. Bericht

Am Ende kurz: was gebaut ist und wo (Dateien), Version, Tests und Prüfungen; die Bundle-IDs, die die App Group
`group.at.binisoft.shared` brauchen; welche `refs` `source.json` liefert (Art und Anzahl, keine Inhalte); was Bini
tun muss (z. B. Schalter einschalten, Zuordnung wählen); offene Fragen.
````

### 3.2 George

````markdown
# Auftrag: George liefert Thalia Daten (Binisoft-Austausch, Format v1)

Dieser Auftrag ist vollständig – alles Nötige steht hier, kein anderes Repo muss gelesen werden. Arbeite in diesem Repo
(George) nach dem Binisoft-Handbuch und den Regeln des Repos (HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST): zuerst ein
kurzer Plan in `docs/`, die Logik im Core-Paket mit Tests unter Linux, lokale Prüfung vor dem Push, Version erhöhen,
am Ende ein Bericht (§12). Bei Unklarem: fragen, nicht raten.

## 1. Worum es geht

Thalia ist Binis Planer für Wochenpläne und Jahresziele (ebenfalls eine Binisoft-App). Ab Thalia 1.9.0 können andere
Binisoft-Apps Thalia automatisch Tatsachen liefern: erledigte Aufgaben, Power-Hours, Workouts, Tageswerte, Ausgaben.
George schreibt dafür kleine JSON-Dateien in die gemeinsame App Group. Thalia liest sie auf demselben Gerät, legt sie
in ihren eigenen iCloud-Eingang und **rechnet** daraus Werte – Thalia legt dafür nie eigene Einträge an, und Binis eigene
Einträge in Thalia gewinnen immer. George liest von Thalia nur einen Katalog mit Thalias Struktur (§7). Keine App
ändert die Daten der anderen; es gibt kein Netz, keinen Server, keine Berechtigungsabfrage.

## 2. Was George liefert

- **`workout.done`** – jedes abgeschlossene Workout in George, eine Tatsache je Workout, im Tag seines Endes
  (Kalendertag in der Zeitzone des Geräts).
  - `id` `"wo-" + <synchronisierte id des Workouts>` · `ref` id der **Vorlage** (stabil, synchronisiert) · `refTitle`
    Name der Vorlage · `title` Name des Workouts · `at` Ende · `origin` `"app"`. Kein `value` nötig.
  - Workouts ohne Vorlage: `ref` `"frei"`, `refTitle` `"Freies Workout"`.
  - **Workouts von der Apple Watch:** Die Watch schreibt nie selbst. Sobald das Workout über **Georges eigenen Sync**
    (Georges CloudKit oder Georges eigene Übertragung von der Watch) in Georges synchronisiertem Speicher auf
    iPhone/iPad/Mac angekommen ist, steht es dort in der Tagesdatei. Ein Workout, das George auf dem iPhone nur
    aus Apple Health zurückliest (auch eines, das Georges eigene Watch-App dort gespeichert hat), stammt aus HealthKit
    und wird **nie** geschrieben (Richtlinie 5.1.3(ii)).
  - Ein in George aufgezeichnetes Workout ist `origin` `"app"`, auch wenn George es zusätzlich in Apple Health speichert.
    Workouts, die George nur aus Apple Health übernommen hat (andere Apps), gar nicht schreiben.
- **Keine Kennzahlen aus Apple Health:** keine Herzfrequenz, keine Energie, keine Strecke, keine Dauer aus Health.
- `source.json` → `refs`: alle Vorlagen mit `"kind":"workout"`, dazu `{"id":"frei","title":"Freies Workout","kind":"workout"}`.
- Einstellungen in George: Abschnitt „Thalia“ mit dem Schalter „An Thalia liefern“ (Standard ein).

Was Thalia daraus macht: Ein Messwert mit der Quelle `app:george:workout=<Vorlagen-id>` zählt die Workouts dieser
Vorlage am Tag (`app:george:workout` zählt alle). Ein Punkt wie „Krafttraining“, der mit dem Messwert verknüpft ist,
bekommt den Haken „⇄ George · Push“, solange Bini in Thalia selbst nichts markiert hat. Bini wählt die Vorlage in
Thalias Messwert-Editor aus den `refs` – darum müssen ids und Titel dort stimmen.

## 3. Weg und Ordner

- App Group **`group.at.binisoft.shared`** (alle Binisoft-Apps haben sie). Laut Handbuch §6 liegen dort nur kleine
  Ereignisse und Zusammenfassungen, nie die Daten der App selbst.
- Ordner von George: `<Group>/George/exchange/` – der Ordnername ist der Anzeigename „George“, genau wie
  `AppGroupFolder.url(appName: "George")` aus BinisoftKit (ohne BinisoftKit:
  `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.at.binisoft.shared")?
  .appendingPathComponent("George")`; am Mac beides erst nach der Entitlement-Prüfung, §8). Darin:
  - `source.json` – Herzschlag und Verzeichnis der stabilen ids (§6)
  - `days/JJJJ-MM-TT.json` – eine Datei je Tag (§4, §5)
- George schreibt **nur** in seinen eigenen Ordner. Thalia schreibt nur `<Group>/Thalia/exchange/catalog.json`;
  George liest ihn nur.
- Die App Group ist ein Ordner **auf einem Gerät**. Thalia sieht nur Dateien, die auf demselben Gerät geschrieben wurden.
  Darum schreibt George auf **jedem iPhone, iPad und Mac**, auf dem es läuft – immer aus dem eigenen synchronisierten
  Speicher, so dass jedes Gerät denselben Inhalt schreibt. Thalia legt jede Tagesdatei in ihren iCloud-Eingang; ab da
  sehen alle Geräte mit Thalia die Werte.
- **Nie auf der Apple Watch** – dort weder lesen noch schreiben (`#if !os(watchOS)`). Was auf der Watch erfasst wird,
  kommt über den Sync von George auf iPhone/iPad/Mac und von dort in die Tagesdatei.
- **Nur aus dem echten Speicher** – nie aus Demo-, Screenshot-, Vorschau-, Test- oder In-Memory-Speichern (z. B. beim
  Start mit `-Demo`): Beispieldaten dürfen nie bei Thalia ankommen.

## 4. Tagesdatei – Format v1

Beispiel (eine Tagesdatei von Theo):

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"}]}
```

Felder der Datei (alle Pflicht):

| Feld | Inhalt |
|---|---|
| `v` | `1` (Zahl). Thalia liest Version 1 und höher; kleiner als 1 wird abgelehnt. |
| `source` | Quellen-id: der Ordnername klein, nur `a–z`, `0–9`, `-` – hier `"george"`. Passt sie nicht zum Ordner, lehnt Thalia die Datei ab. |
| `day` | `"JJJJ-MM-TT"`, ein echter Kalendertag; muss zum Dateinamen passen (`days/2026-11-22.json`), sonst abgelehnt. |
| `generatedAt` | Zeitpunkt des Schreibens (Datumsform unten). Hat Thalia für Quelle und Tag schon eine Fassung, gewinnt die mit dem neueren `generatedAt`. |
| `facts` | Liste der Tatsachen des Tages (darf leer sein: `[]`). |

Felder einer Tatsache:

| Feld | | Inhalt |
|---|---|---|
| `id` | Pflicht | Stabil und auf allen Geräten gleich, in der Datei eindeutig. Aus der **synchronisierten** id des Datensatzes (z. B. sein UUID-Feld) – nie `persistentModelID` oder `NSManagedObjectID` (je Gerät verschieden). Präfix je Art, z. B. `"task-…"`. |
| `kind` | Pflicht | Art, siehe unten. |
| `origin` | Pflicht | `"app"` = in George selbst erfasst, `"health"` = aus Apple Health. Ohne `origin` (oder mit anderem Wert) verwendet Thalia die Tatsache nicht. |
| `ref` | empfohlen | Stabile id in der Quelle, auf die sich die Tatsache bezieht: Gruppe, Workout-Vorlage, Kennzahl, Konto. Über `ref` ordnet Bini in Thalia zu. |
| `refTitle` | empfohlen | Anzeigename von `ref` („Arbeit/Kunden“). |
| `title` | optional | Titel der Sache („Rechnung schreiben“); Thalia zeigt ihn an. |
| `value` | je nach Art | JSON-Zahl mit Punkt (`1.5`), keine Zeichenkette. |
| `unit` | optional | `"PH"`, `"min"`, `"kcal"`, `"g"`, `"ml"` … |
| `metric` | bei `value` | Kennzahl aus der Tabelle unten. |
| `currency` | bei Geld | ISO 4217, `"EUR"`. |
| `at` | empfohlen | Zeitpunkt des Ereignisses (Datumsform unten). |
| `thalia` | optional | Was in George aus Thalias Katalog gewählt wurde: `{"category":"3.2","categoryTitle":"Kunden"}` (§7). `measure` und `result` sind für später reserviert – weglassen. |

Kein Verweis auf Thalias Wochen-Punkte (deren Codes gelten nur eine Woche). Unbekannte Felder liest Thalia nicht,
stören aber nicht.

Arten (v1) und was Thalia damit tut:

| `kind` | Bedeutung | Felder | In Thalia |
|---|---|---|---|
| `task.done` | eine erledigte Aufgabe | `ref` = Gruppe | zählt für Messwerte `app:<quelle>:task` (Aufgaben, deren Kategorie die des Messwerts ist) und `app:<quelle>:task=<ref>` (Aufgaben dieser Gruppe) |
| `workout.done` | ein abgeschlossenes Workout | `ref` = Vorlage | zählt für `app:<quelle>:workout` (alle) und `app:<quelle>:workout=<ref>` |
| `habit.done` | eine erledigte Gewohnheit | `ref` = Gewohnheit | zählt für `app:<quelle>:habit[=<ref>]` |
| `ph` | Power-Hours (1 PH = 50 konzentrierte Minuten) | `value` in PH mit `unit` `"PH"`; mit `unit` `"min"` ist `value` in Minuten (Thalia teilt durch 50); `ref` = Gruppe | ein Arbeitsblock „aus <App>“ in der Kategorie aus `thalia.category`, sonst aus Thalias Zuordnung, sonst „ohne Zuordnung“; Summe für `app:<quelle>:ph[=<ref>]` |
| `value` | Kennzahl eines Tages | `metric`, `value` | Tageswert für `app:<quelle>:<metric>[=<ref>]` – bei `agg: sum` die Summe der Tatsachen des Tages, bei `agg: last` die letzte nach `at` (ohne `at` davor, in Dateireihenfolge) |
| `spending` | Ausgaben einer Gruppe an dem Tag (Tagessumme) | `value` (positiv), `currency`, `ref` = Gruppe | Summe für `app:<quelle>:spending[=<ref>]` |

Bei gezählten Arten (`*.done`) zählt jede Tatsache als 1; `value` wird dort nicht gelesen. Unbekannte Arten und
Kennzahlen behält Thalia und zeigt sie als „nicht verwendet“ – kein Fehler, aber keine Wirkung. Neue Arten nicht
erfinden, sondern im Bericht vorschlagen.

Kennzahlen für `value` (Tabelle v1 – sie wächst nur; eine neue Kennzahl behalten ältere Thalia-Versionen als „nicht
verwendet“):

| `metric` | `agg` | Einheit | Name |
|---|---|---|---|
| `kcal` | sum | kcal | Kalorien |
| `protein_g` | sum | g | Protein |
| `carbs_g` | sum | g | Kohlenhydrate |
| `fat_g` | sum | g | Fett |
| `water_ml` | sum | ml | Wasser |
| `net_worth` | last | € | Vermögen |
| `savings_rate` | last | % | Sparquote |
| `body_weight_kg` | last | kg | Gewicht |
| `account_balance` | last | € | Kontostand (ab Thalia 1.10.0) |

`account_balance` ist der Stand eines Kontos oder einer Kontogruppe am Ende des Tages: `ref` = id des Kontos bzw. der
Gruppe, `refTitle` = ihr Name, eine Tatsache je Konto. Thalia liest ihn nur für ein bestimmtes Konto
(`app:<quelle>:account_balance=<ref>`). Bei allen anderen Kennzahlen ist `ref` die Kennzahl selbst (`"kcal"`).

**Herkunft:** Thalias Eingang liegt in iCloud, und Gesundheitsdaten dürfen nicht nach iCloud (App Review Richtlinie
5.1.3(ii)). Darum schreibt George **keine Werte, die aus Apple Health stammen**. Nur wenn sich ein Wert gar nicht
anders trennen lässt, als eigene Tatsache mit `"origin":"health"` – Thalia verwirft solche Tatsachen, bevor sie
gespeichert werden.

**Datum:** ISO 8601 mit Zeitzone, **ohne Sekundenbruchteile**: `"2026-11-22T18:04:00+01:00"` (UTC: `"…Z"`). Thalia
liest auch Bruchteile, `+0100` und `Z`. Der **Tag** einer Tatsache ist der Kalendertag des Ereignisses in der Zeitzone
des Geräts (erledigt am, Ende des Workouts, Datum des Eintrags). Keine Tage in der Zukunft.

## 5. Schreiben – Regeln

1. **Eine Datei je Tag, immer vollständig** aus dem eigenen synchronisierten Speicher: alle Tatsachen des Tages, auch
   die auf einem anderen Gerät erfassten, die per Sync angekommen sind – nie nur „was auf diesem Gerät passiert ist“.
2. **Fehlt eine Tatsache** in einer vorhandenen Tagesdatei, ist sie für Thalia entfernt. Eine **fehlende Datei** heißt
   „keine Information“ (Thalia behält, was sie hat). Darum: Ein Tag, der eine Datei hatte und jetzt nichts mehr hat,
   bekommt `"facts":[]`; für Tage, die nie etwas hatten, keine Datei.
3. **Neu schreiben**, sobald sich an einem Tag etwas ändert, auch rückwirkend (ein geändertes Datum: beide Tage) –
   nach jedem eigenen Speichern (entprellt, etwa 2 s), **direkt nach dem eigenen CloudKit-Import**
   (`NSPersistentCloudKitContainer.eventChangedNotification`, `event.type == .import`, `endDate != nil`), beim Wechsel
   in den Vordergrund und beim Tageswechsel. Der einfachste sichere Weg: bei jedem Anlass alle Tage der letzten 62 Tage
   aus dem Speicher bauen und nur die geänderten schreiben (§9).
4. **Nur schreiben, wenn sich die Tatsachen geändert haben** (Vergleich ohne `generatedAt`); sonst bleibt die Datei, wie
   sie ist. Tatsachen in fester Reihenfolge (nach `at`, dann `id`), damit jedes Gerät denselben Inhalt erzeugt.
5. **Atomar:** in eine temporäre Datei im selben Ordner schreiben, dann umbenennen (`Data.write(to:options: .atomic)` tut
   das). Ordner bei Bedarf anlegen. Thalia liest nur Dateien `JJJJ-MM-TT.json` und überspringt Dotfiles und Temp-Dateien.
6. **JSON** in UTF-8, kompakt, Schlüssel sortiert, Schrägstriche nicht maskiert (`JSONEncoder` mit `.sortedKeys` und
   `.withoutEscapingSlashes`).
7. Danach – einmal je Schreibvorgang – die **Darwin-Benachrichtigung `at.binisoft.exchange.changed`** senden. Sie ist nur
   ein Hinweis: Thalia liest auch beim Start, im Vordergrund, alle 5 Minuten, solange sie offen ist, und nach ihrem
   eigenen iCloud-Import.
8. **Aufräumen:** Tagesdateien, die älter als 62 Tage sind (heute − Tag > 62), löscht George selbst. Thalia behält ihre
   Kopie im Eingang.
9. Das Schreiben verzögert nie den Start oder das Speichern (abseits des Main-Threads, entprellt) und zeigt nie einen
   Fehler – Probleme nur ins Log.
10. Was Bini in George ausschaltet, zählt wie nicht vorhanden: Der normale Abgleich schreibt die betroffenen Tage ohne
    diese Tatsachen neu, und Thalia nimmt sie für diese Tage heraus.

## 6. source.json

```json
{
  "v": 1,
  "source": "george",
  "app": "George",
  "appVersion": "1.6.2",
  "generatedAt": "2026-11-22T19:30:00+01:00",
  "refs": [
    { "id": "tpl-1", "title": "Push", "kind": "workout" },
    { "id": "tpl-2", "title": "Pull", "kind": "workout" }
  ]
}
```

- Felder: `v` (1), `source` (wie in den Tagesdateien), `app` (Anzeigename „George“), `appVersion`, `generatedAt`,
  `refs` = alle stabilen ids, die Bini in Thalia auswählen können soll, je ein Objekt mit `id`, `title` und `kind`.
- `kind` eines refs: `"group"` (Gruppe von Aufgaben, Power-Hours oder Ausgaben), `"workout"` (Workout-Vorlage),
  `"habit"`, `"account"` (Konto oder Kontogruppe, ab Thalia 1.10.0), `"metric"` (Kennzahl). Thalias Editoren bieten
  unter „Verbundene App → Art → Eintrag“ die passenden an: Workouts → `workout`, Aufgaben/Power-Hours/Ausgaben →
  `group`, Gewohnheiten → `habit`, Kontostand → `account`; ein ref ohne `kind` passt zu allem. Andere Kennzahlen haben
  kein „Eintrag“ (der `ref` ihrer Tatsachen ist die Kennzahl selbst) – ein ref mit `"kind":"metric"` schadet nicht,
  Thalia bietet ihn aber nirgends an.
- Schreiben: sofort, wenn sich `refs` oder die App-Version ändern, sonst höchstens einmal am Tag (Herzschlag – Thalia
  zeigt daraus „zuletzt gesehen“). Atomar, danach die Darwin-Benachrichtigung. `source` muss zum Ordner passen.

## 7. Thalias Katalog und „Thalia-Kategorie“

Thalia schreibt `<Group>/Thalia/exchange/catalog.json` (solange „Thalia-Katalog bereitstellen“ an ist, Standard), nur
wenn sich die Struktur ändert. **Nur Struktur** – keine Werte, kein Fortschritt. George liest ihn nur, tolerant:
unbekannte Felder ignorieren; die Datei kann fehlen (Thalia war auf diesem Gerät noch nicht offen, oder der Katalog
ist aus).

| Feld | Inhalt |
|---|---|
| `v`, `source`, `generatedAt` | `1`, `"thalia"`, Zeitpunkt |
| `week` | die Woche, aus der die Messwerte stammen (`"2026-W47"`) |
| `segment` | aktueller Abschnitt der Jahresziele: `{"id":"seg-2","title":"Abschnitt 2"}` |
| `goals` | `[{"key":"3","title":"Arbeit"}]` |
| `categories` | `[{"key":"3.2","goal":"3","title":"Kunden","segment":"seg-2"}]` – `key` ist Text („1.1“, „5“) |
| `measures` | Messwerte der Woche, je mit `code`, `title`, `unit`, `link` (die Quelle des Messwerts, z. B. `"app:george:workout=tpl-1"`) und `category` |
| `results` | Ergebnisse der Jahresziele, je mit `id`, `title`, `kind` (`check` / `count` / `value`), `goal` und – ab Thalia 1.10.0 – `source`: woher der Wert kommt (`"app:finn:net_worth"`, `"app:finn:account_balance=acc-giro"`, `"list:buch"`); fehlt bei Ergebnissen mit eigenen Einträgen und in Katalogen von Thalia vor 1.10.0 |

Ein vollständiges Beispiel steht bei den Testdateien (§10).

**Auswahl „Thalia-Kategorie“** (ob George sie braucht, steht hier: George braucht sie nicht – Workouts ordnet Bini in Thalia über die Vorlagen-id zu. **Nichts von der folgenden Liste bauen:** keine Auswahl, kein `thalia.mapping`, kein Feld `thalia`. Optional darf der Vorlagen-Editor nur anzeigen, welcher Thalia-Messwert die Vorlage zählt (`catalog.measures`, deren `link` `app:george:workout=<id>` ist). Die Liste steht nur der Vollständigkeit halber da):

- Zeilen „3.2 Kunden“, gruppiert nach Ziel („3 Arbeit“), oben „Keine“; auf iPhone, iPad und Mac gleich.
- Die Wahl wird je Gruppe als JSON in einem **vorhandenen, synchronisierten Einstellungs-Datensatz** von George
  gespeichert, z. B. unter dem Schlüssel `thalia.mapping`:
  `{"v":1,"groups":{"grp-91AB":{"category":"3.2","categoryTitle":"Kunden"}}}` – unbekannte Felder beim Speichern
  behalten. Synchronisiert, damit jedes Gerät dieselben Tagesdateien schreibt (nicht in `UserDefaults`). So braucht
  George keine CloudKit-Schemaänderung; gibt es keinen solchen Datensatz, vorher bei Bini nachfragen.
- Jede Tatsache einer zugeordneten Gruppe bekommt `"thalia":{"category":"3.2","categoryTitle":"Kunden"}`. Eine geänderte
  Zuordnung schreibt die betroffenen Tage neu (der 62-Tage-Abgleich erledigt das).
- Fehlt der Katalog: die gespeicherte Wahl zeigen und darunter „Thalias Katalog fehlt auf diesem Gerät – Thalia hier
  einmal öffnen.“ Fehlt die gewählte Kategorie im Katalog oder heißt sie dort anders als `categoryTitle`: „Zuordnung
  prüfen“.
- Thalia nimmt `thalia.category` vor ihrer eigenen Zuordnung (Einstellungen → Verbundene Apps); eine Kategorie, die
  Thalia nicht (mehr) hat, übergeht sie. Es reicht, wenn eine Tatsache der Gruppe am Tag die Kategorie trägt – besser
  tragen sie alle. Ohne Kategorie steht die Tatsache in Thalia unter „Ohne Zuordnung“, bis Bini sie dort zuordnet.

## 8. App Group und Entitlement

- Jedes Ziel, das schreibt – iPhone/iPad-App und Mac-App –, hat in seinen Entitlements unter
  `com.apple.security.application-groups` die Gruppe `group.at.binisoft.shared` (im Binisoft-Template über
  `$(SHARED_APP_GROUP)`, in der Info.plist `SharedAppGroup`). Widgets und Watch schreiben nicht – dort nichts ändern.
- Im Apple-Developer-Portal muss die Gruppe den App IDs zugewiesen sein. Das prüft Bini; nenne im Bericht die
  Bundle-IDs, denen die Gruppe zugewiesen sein muss.
- **Am Mac** zur Laufzeit prüfen, ob die signierte App die Gruppe wirklich hat (`SecTaskCopyValueForEntitlement`, §9) –
  abseits des Main-Threads und nicht während des Starts. Ohne das Entitlement kann macOS sonst nach Zugriff auf Daten
  anderer Apps fragen. Auf iPhone/iPad liefert `containerURL(forSecurityApplicationGroupIdentifier:)` ohne Gruppe `nil`
  → nichts tun. Unsignierte CI-Builds: nichts tun.

## 9. Referenzcode

Thalias Referenz für das Format ist eine einzige Datei, nur Foundation, Swift 5 und 6, zum unveränderten Kopieren
(z. B. ins Core-Paket von George; die Typen sind `public`):
https://github.com/Binisoft-at/thalia/blob/main/Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift
– Testdateien: https://github.com/Binisoft-at/thalia/tree/main/Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange
(öffentlich auf `main`). **Stand Thalia 1.10.0:** die Datei hat nur Zusätze bekommen – die Kennzahl `account_balance`,
das Katalog-Feld `results[].source` und toleranteres Lesen (eine Zahl, die nicht endlich ist oder dem Betrag nach ab
10¹², gilt als fehlend; ein unlesbares `v` gilt als 1). Wer sie schon aus Thalia 1.9.0 kopiert hat, ersetzt sie durch
die neue Fassung; eigener Code, der sie benutzt, bleibt gültig. Die Datei enthält `BinisoftExchange` (Pfade,
Dateinamen, Aufräumen,
atomares Schreiben, Kodieren), `ExchangeOrigin`, `ExchangeKind`, `ExchangeMetric.table`, `ExchangeFact`,
`ExchangeDayFile`, `ExchangeRef`, `ExchangeSourceInfo`, `ExchangeCatalog`, `ExchangeReader` (tolerantes Lesen mit
deutschen Gründen), `ExchangeDate` und `ExchangeHash` (FNV-1a 64 Bit). Ist sie nicht erreichbar, nach §4–§8 selbst
schreiben – diese Beschreibung ist verbindlich. Die Skizze unten nutzt die Typen dieser Datei.

Schreiber im Core (nur Foundation, unter Linux mit einem temporären Ordner testbar):

```swift
import Foundation

/// Schreibt die Tagesdateien (Format v1) nach `appFolder` = <Group>/George.
public enum ThaliaExchangeWriter {
    /// `facts`: alle Tatsachen der letzten 62 Tage aus dem eigenen synchronisierten Speicher, nach Tag ("2026-11-22").
    /// Schreibt nur Tage, deren Tatsachen sich geändert haben, und räumt alte Dateien auf. true = etwas geändert.
    @discardableResult
    public static func sync(_ facts: [String: [ExchangeFact]], source: String, appFolder: URL, today: String,
                            now: Date = Date()) throws -> Bool {
        let manager = FileManager.default
        var changed = false
        for offset in 0...BinisoftExchange.keepDays {
            guard let day = BinisoftExchange.day(today, adding: -offset) else { continue }
            let url = BinisoftExchange.dayFileURL(appFolder: appFolder, day: day)
            let sorted = (facts[day] ?? []).sorted { ($0.at ?? "", $0.id) < ($1.at ?? "", $1.id) }
            let old = try? Data(contentsOf: url)
            if old == nil && sorted.isEmpty { continue }                 // nie eine Datei für einen Tag ohne alles
            if let old, case .success(let read) = ExchangeReader.dayFile(old),
               let same = try? ExchangeDayFile(source: source, day: day, generatedAt: read.file.generatedAt,
                                               facts: sorted).encoded(),
               same == old { continue }                                  // unverändert: generatedAt bleibt
            let file = ExchangeDayFile(source: source, day: day, generatedAt: ExchangeDate.string(now), facts: sorted)
            try BinisoftExchange.write(file.encoded(), to: url)          // atomar: temp + rename
            changed = true
        }
        let days = BinisoftExchange.daysFolder(appFolder: appFolder)
        let names = (try? manager.contentsOfDirectory(atPath: days.path)) ?? []
        for name in BinisoftExchange.expiredDayFiles(names, today: today) {
            try? manager.removeItem(at: days.appendingPathComponent(name))
            changed = true
        }
        return changed
    }
}
```

App-Schicht (nicht auf der Watch):

```swift
#if !os(watchOS)
import Foundation
#if os(macOS)
import Security
#endif

enum ThaliaExchange {
    static let appName = "George"
    static let source = BinisoftExchange.sourceID(appName)   // "george"

    /// <Group>/George – nil ohne App Group (unsignierter Build) und am Mac ohne Entitlement. Abseits des Main-Threads.
    static func appFolder() -> URL? {
        #if os(macOS)
        guard hasAppGroupEntitlement() else { return nil }
        #endif
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BinisoftExchange.appGroup)
        else { return nil }
        return root.appendingPathComponent(appName, isDirectory: true)
    }

    /// Thalias Katalog; nil, solange Thalia ihn auf diesem Gerät nicht geschrieben hat.
    static func catalog() -> ExchangeCatalog? {
        guard let folder = appFolder() else { return nil }
        let thalia = folder.deletingLastPathComponent().appendingPathComponent("Thalia", isDirectory: true)
        let url = BinisoftExchange.exchangeFolder(appFolder: thalia).appendingPathComponent(BinisoftExchange.catalogFileName)
        guard let data = try? Data(contentsOf: url), case .success(let catalog) = ExchangeReader.catalog(data) else { return nil }
        return catalog
    }

    /// Nach dem Schreiben: Thalia darf sofort nachsehen.
    static func postChanged() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(BinisoftExchange.changedNotification as CFString), nil, nil, true)
    }

    #if os(macOS)
    /// Hat die signierte App die Gruppe? Abseits des Main-Threads, nicht beim Start.
    static func hasAppGroupEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        return (value as? [String])?.contains(BinisoftExchange.appGroup) ?? false
    }
    #endif
}
#endif
```

Anstoßen (entprellt, etwa 2 s): nach jedem eigenen Speichern, beim Wechsel in den Vordergrund, beim Tageswechsel
(`.NSCalendarDayChanged`) und nach dem eigenen CloudKit-Import (`import CoreData`):

```swift
NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                                       queue: .main) { note in
    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event,
          event.type == .import, event.endDate != nil else { return }
    scheduleThaliaSync()
}
// scheduleThaliaSync(): die Tatsachen der letzten 62 Tage aus dem Speicher bauen (reine Werte), dann abseits des
// Main-Threads: ThaliaExchange.appFolder() → ThaliaExchangeWriter.sync(…, today: ExchangeDate.day(Date())) →
// bei Änderung postChanged(); source.json nach §6. Nicht im Demo-Modus, nicht in der Vorschau, nicht auf der Watch.
```

## 10. Tests

Logik (Tatsachen bauen, Dateien abgleichen) gehört ins Core-Paket, das unter Linux getestet wird; App-Group-Pfad,
Darwin-Benachrichtigung und Entitlement-Prüfung in die App-Schicht. Tests (Swift Testing oder wie im Repo üblich):

1. Tatsachen aus neutralen Beispieldatensätzen: richtige `kind`, `id` stabil (zweimal gebaut = gleich), `ref` und
   `refTitle`, `origin` `"app"`, `at` als `JJJJ-MM-TTTHH:MM:SS+HH:MM` (oder `…Z`) ohne Bruchteile.
2. Tag nach Zeitzone: ein Ereignis um `2026-11-22T23:30:00Z` gehört in `Europe/Vienna` zum `2026-11-23`.
3. Schreiben und zurücklesen: `ExchangeReader.dayFile(data, folder: "George", fileName: "2026-11-22.json")` ist
   erfolgreich und `skipped` leer; `ExchangeReader.source(data, folder: "George")` ebenso.
4. Abgleich in einem temporären Ordner: unveränderte Tatsachen → Datei unverändert (gleiche Bytes, gleiches
   `generatedAt`); eine entfernte Tatsache → Datei ohne sie; Tag ohne Tatsachen und ohne Datei → keine Datei; Tag mit
   Datei und jetzt ohne Tatsachen → `"facts":[]`; `BinisoftExchange.expiredDayFiles(["2026-09-20.json",
   "2026-09-21.json", "2026-11-22.json", ".x.json"], today: "2026-11-22")` ist `["2026-09-20.json"]` und genau diese
   Datei wird gelöscht.
5. Die Testdateien unten lesen sich (Tagesdatei, source.json, Katalog), und die eigene Ausgabe für denselben Inhalt
   hat dieselbe Form.
6. Keine Health-Werte: aus Apple Health stammende Datensätze ergeben keine Tatsache.
7. Werden ids mit FNV-1a gebildet (`ExchangeHash.hex`): `""` → `cbf29ce484222325`, `"a"` → `af63dc4c8601ec8c`,
   `"foobar"` → `85944171f73967e8`.
8. George: ein Workout, das von der Watch über den Sync kam, steht in der Tagesdatei des iPhone (die Watch-Seite
   schreibt nie); `ref` ist die Vorlagen-id, ohne Vorlage `"frei"`; ein nur aus Apple Health übernommenes Workout
   ergibt keine Tatsache; die Tatsachen haben keine Health-Kennzahlen (kein `value`, kein `metric`).

Testdaten bleiben neutral wie diese (keine echten Namen, Beträge, Gewichte, Ziele). Testdateien aus Thalias Repo
(Ordner wie in der App Group):

`George/exchange/days/2026-11-22.json` – `wo-HK01` mit `origin: "health"` zeigt, was Thalia verwirft – George schreibt so etwas nicht.

```json
{
  "v": 1,
  "source": "george",
  "day": "2026-11-22",
  "generatedAt": "2026-11-22T19:30:00+01:00",
  "facts": [
    { "id": "wo-5A10", "kind": "workout.done", "ref": "tpl-1", "refTitle": "Push", "title": "Push",
      "at": "2026-11-22T07:40:00+01:00", "origin": "app" },
    { "id": "wo-5A11", "kind": "workout.done", "ref": "tpl-2", "refTitle": "Pull", "title": "Pull",
      "at": "2026-11-22T17:10:00+01:00", "origin": "app" },
    { "id": "wo-HK01", "kind": "workout.done", "ref": "tpl-1", "refTitle": "Push", "title": "Laufen aus Apple Health",
      "at": "2026-11-22T12:00:00+01:00", "origin": "health" }
  ]
}
```

`George/exchange/source.json`

```json
{
  "v": 1,
  "source": "george",
  "app": "George",
  "appVersion": "1.6.2",
  "generatedAt": "2026-11-22T19:30:00+01:00",
  "refs": [
    { "id": "tpl-1", "title": "Push", "kind": "workout" },
    { "id": "tpl-2", "title": "Pull", "kind": "workout" }
  ]
}
```

`Thalia/exchange/catalog.json` – Thalias Katalog (§7) – nur Struktur; ab Thalia 1.10.0 mit `results[].source`.

```json
{
  "v": 1,
  "source": "thalia",
  "generatedAt": "2026-11-22T06:00:00+01:00",
  "week": "2026-W47",
  "segment": { "id": "seg-2", "title": "Abschnitt 2" },
  "goals": [
    { "key": "1", "title": "Gesundheit" },
    { "key": "3", "title": "Arbeit" },
    { "key": "5", "title": "Lesen" },
    { "key": "8", "title": "Finanzen" }
  ],
  "categories": [
    { "key": "1.2", "goal": "1", "title": "Sport / Verein", "segment": "seg-2" },
    { "key": "3.2", "goal": "3", "title": "Kunden", "segment": "seg-2" },
    { "key": "5", "goal": "5", "title": "Lesen", "segment": "seg-2" },
    { "key": "8.1", "goal": "8", "title": "Ausgaben", "segment": "seg-2" }
  ],
  "measures": [
    { "code": "workouts", "title": "Workouts", "unit": "Stück", "link": "app:george:workout=tpl-1", "category": "1.2" },
    { "code": "kunden_aufgaben", "title": "Aufgaben Kunden", "unit": "Stück", "link": "app:theo:task", "category": "3.2" },
    { "code": "seiten", "title": "Seiten", "unit": "Seiten", "link": "list:buch", "category": "5" },
    { "code": "ausgaben", "title": "Ausgaben", "unit": "€", "link": "app:finn:spending", "category": "8.1" }
  ],
  "results": [
    { "id": "res-web", "title": "Website online", "kind": "check", "goal": "3" },
    { "id": "res-books", "title": "Bücher gelesen", "kind": "count", "goal": "5", "source": "list:buch" },
    { "id": "res-worth", "title": "Vermögen", "kind": "value", "goal": "8", "source": "app:finn:net_worth" },
    { "id": "res-giro", "title": "Puffer Girokonto", "kind": "value", "goal": "8", "source": "app:finn:account_balance=acc-giro" }
  ]
}
```

## 11. Regeln

- **Keine CloudKit-Schemaänderung** in George: neue Einstellungen als JSON in einem vorhandenen Einstellungs-Datensatz;
  ein neues Feld oder eine neue Datensatzart nur nach Rückfrage bei Bini (das braucht „Deploy Schema Changes“).
- **Keine Werte aus Apple Health** (§4, Herkunft).
- **Öffentliches Repo:** keine persönlichen Daten in Code, Tests, Testdateien oder Doku – keine echten Namen, Beträge,
  Gewichte oder Ziele; neutrale Beispiele wie „Arbeit/Kunden“, „Push“, „Lesen“.
- Nie aus Demo- oder In-Memory-Speichern schreiben, nie auf der Watch.
- Bestehendes Verhalten von George bleibt, wie es ist. Deutsche Texte kurz und schlicht, z. B. in den Einstellungen
  ein Abschnitt „Thalia“ mit den Schaltern aus §2, „Zuletzt geschrieben: …“ und dem Hinweis „Thalia übernimmt die
  Werte, sobald Thalia auf diesem Gerät geöffnet wird.“

## 12. Bericht

Am Ende kurz: was gebaut ist und wo (Dateien), Version, Tests und Prüfungen; die Bundle-IDs, die die App Group
`group.at.binisoft.shared` brauchen; welche `refs` `source.json` liefert (Art und Anzahl, keine Inhalte); was Bini
tun muss (z. B. Schalter einschalten, Zuordnung wählen); offene Fragen.
````

### 3.3 Nina

````markdown
# Auftrag: Nina liefert Thalia Daten (Binisoft-Austausch, Format v1)

Dieser Auftrag ist vollständig – alles Nötige steht hier, kein anderes Repo muss gelesen werden. Arbeite in diesem Repo
(Nina) nach dem Binisoft-Handbuch und den Regeln des Repos (HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST): zuerst ein
kurzer Plan in `docs/`, die Logik im Core-Paket mit Tests unter Linux, lokale Prüfung vor dem Push, Version erhöhen,
am Ende ein Bericht (§12). Bei Unklarem: fragen, nicht raten.

## 1. Worum es geht

Thalia ist Binis Planer für Wochenpläne und Jahresziele (ebenfalls eine Binisoft-App). Ab Thalia 1.9.0 können andere
Binisoft-Apps Thalia automatisch Tatsachen liefern: erledigte Aufgaben, Power-Hours, Workouts, Tageswerte, Ausgaben.
Nina schreibt dafür kleine JSON-Dateien in die gemeinsame App Group. Thalia liest sie auf demselben Gerät, legt sie
in ihren eigenen iCloud-Eingang und **rechnet** daraus Werte – Thalia legt dafür nie eigene Einträge an, und Binis eigene
Einträge in Thalia gewinnen immer. Nina liest von Thalia nur einen Katalog mit Thalias Struktur (§7). Keine App
ändert die Daten der anderen; es gibt kein Netz, keinen Server, keine Berechtigungsabfrage.

## 2. Was Nina liefert

- **`value`** – Tageswerte, die **in Nina erfasst** wurden: `kcal`, `protein_g`, `carbs_g`, `fat_g`, `water_ml` (alle
  `agg: sum`). Empfohlen ist **eine Tatsache je Kennzahl und Tag** mit der Tagessumme:
  `{"id":"kcal-2026-11-22","kind":"value","metric":"kcal","ref":"kcal","refTitle":"Kalorien","value":1850,"unit":"kcal","origin":"app"}`
  (`at` optional = Zeitpunkt des letzten Eintrags). Erlaubt ist auch eine Tatsache je Eintrag – Thalia summiert –, aber
  nicht beides für denselben Tag.
  - Nur Kennzahlen, die Nina wirklich führt. Ein Tag ohne Einträge hat keine Tatsachen; eine echte 0 (Einträge da, aber
    0 g Fett) darf 0 sein.
  - Einheiten wie in der Tabelle: kcal, Gramm, Milliliter (`water_ml`).
- **Nicht aus Apple Health:** aus Health importierte Lebensmittel und Werte, die Nina aus Health liest (z. B. Wasser oder
  Energie), zählen nicht mit. Lässt sich ein Anteil nicht trennen, lieber weglassen; nur wenn es gar nicht anders geht,
  als eigene Tatsache mit `"origin":"health"` (Thalia verwirft sie).
- `source.json` → `refs`: die geführten Kennzahlen mit `"kind":"metric"`, z. B. `{"id":"kcal","title":"Kalorien","kind":"metric"}`.
- Einstellungen in Nina: Abschnitt „Thalia“ mit dem Schalter „An Thalia liefern“ (Standard ein).

Was Thalia daraus macht: Ein Messwert mit der Quelle `app:nina:kcal` (oder `app:nina:protein_g` …) zeigt den Tageswert;
ein eigener Eintrag in Thalia für denselben Tag ersetzt ihn. Punkte wie „Proteinziel erreichen“, die mit dem Messwert
verknüpft sind, bekommen den Haken, wenn das Ziel erfüllt ist.

## 3. Weg und Ordner

- App Group **`group.at.binisoft.shared`** (alle Binisoft-Apps haben sie). Laut Handbuch §6 liegen dort nur kleine
  Ereignisse und Zusammenfassungen, nie die Daten der App selbst.
- Ordner von Nina: `<Group>/Nina/exchange/` – der Ordnername ist der Anzeigename „Nina“, genau wie
  `AppGroupFolder.url(appName: "Nina")` aus BinisoftKit (ohne BinisoftKit:
  `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.at.binisoft.shared")?
  .appendingPathComponent("Nina")`; am Mac beides erst nach der Entitlement-Prüfung, §8). Darin:
  - `source.json` – Herzschlag und Verzeichnis der stabilen ids (§6)
  - `days/JJJJ-MM-TT.json` – eine Datei je Tag (§4, §5)
- Nina schreibt **nur** in ihren eigenen Ordner. Thalia schreibt nur `<Group>/Thalia/exchange/catalog.json`;
  Nina liest ihn nur.
- Die App Group ist ein Ordner **auf einem Gerät**. Thalia sieht nur Dateien, die auf demselben Gerät geschrieben wurden.
  Darum schreibt Nina auf **jedem iPhone, iPad und Mac**, auf dem es läuft – immer aus dem eigenen synchronisierten
  Speicher, so dass jedes Gerät denselben Inhalt schreibt. Thalia legt jede Tagesdatei in ihren iCloud-Eingang; ab da
  sehen alle Geräte mit Thalia die Werte.
- **Nie auf der Apple Watch** – dort weder lesen noch schreiben (`#if !os(watchOS)`). Was auf der Watch erfasst wird,
  kommt über den Sync von Nina auf iPhone/iPad/Mac und von dort in die Tagesdatei.
- **Nur aus dem echten Speicher** – nie aus Demo-, Screenshot-, Vorschau-, Test- oder In-Memory-Speichern (z. B. beim
  Start mit `-Demo`): Beispieldaten dürfen nie bei Thalia ankommen.

## 4. Tagesdatei – Format v1

Beispiel (eine Tagesdatei von Theo):

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"}]}
```

Felder der Datei (alle Pflicht):

| Feld | Inhalt |
|---|---|
| `v` | `1` (Zahl). Thalia liest Version 1 und höher; kleiner als 1 wird abgelehnt. |
| `source` | Quellen-id: der Ordnername klein, nur `a–z`, `0–9`, `-` – hier `"nina"`. Passt sie nicht zum Ordner, lehnt Thalia die Datei ab. |
| `day` | `"JJJJ-MM-TT"`, ein echter Kalendertag; muss zum Dateinamen passen (`days/2026-11-22.json`), sonst abgelehnt. |
| `generatedAt` | Zeitpunkt des Schreibens (Datumsform unten). Hat Thalia für Quelle und Tag schon eine Fassung, gewinnt die mit dem neueren `generatedAt`. |
| `facts` | Liste der Tatsachen des Tages (darf leer sein: `[]`). |

Felder einer Tatsache:

| Feld | | Inhalt |
|---|---|---|
| `id` | Pflicht | Stabil und auf allen Geräten gleich, in der Datei eindeutig. Aus der **synchronisierten** id des Datensatzes (z. B. sein UUID-Feld) – nie `persistentModelID` oder `NSManagedObjectID` (je Gerät verschieden). Präfix je Art, z. B. `"task-…"`. |
| `kind` | Pflicht | Art, siehe unten. |
| `origin` | Pflicht | `"app"` = in Nina selbst erfasst, `"health"` = aus Apple Health. Ohne `origin` (oder mit anderem Wert) verwendet Thalia die Tatsache nicht. |
| `ref` | empfohlen | Stabile id in der Quelle, auf die sich die Tatsache bezieht: Gruppe, Workout-Vorlage, Kennzahl, Konto. Über `ref` ordnet Bini in Thalia zu. |
| `refTitle` | empfohlen | Anzeigename von `ref` („Arbeit/Kunden“). |
| `title` | optional | Titel der Sache („Rechnung schreiben“); Thalia zeigt ihn an. |
| `value` | je nach Art | JSON-Zahl mit Punkt (`1.5`), keine Zeichenkette. |
| `unit` | optional | `"PH"`, `"min"`, `"kcal"`, `"g"`, `"ml"` … |
| `metric` | bei `value` | Kennzahl aus der Tabelle unten. |
| `currency` | bei Geld | ISO 4217, `"EUR"`. |
| `at` | empfohlen | Zeitpunkt des Ereignisses (Datumsform unten). |
| `thalia` | optional | Was in Nina aus Thalias Katalog gewählt wurde: `{"category":"3.2","categoryTitle":"Kunden"}` (§7). `measure` und `result` sind für später reserviert – weglassen. |

Kein Verweis auf Thalias Wochen-Punkte (deren Codes gelten nur eine Woche). Unbekannte Felder liest Thalia nicht,
stören aber nicht.

Arten (v1) und was Thalia damit tut:

| `kind` | Bedeutung | Felder | In Thalia |
|---|---|---|---|
| `task.done` | eine erledigte Aufgabe | `ref` = Gruppe | zählt für Messwerte `app:<quelle>:task` (Aufgaben, deren Kategorie die des Messwerts ist) und `app:<quelle>:task=<ref>` (Aufgaben dieser Gruppe) |
| `workout.done` | ein abgeschlossenes Workout | `ref` = Vorlage | zählt für `app:<quelle>:workout` (alle) und `app:<quelle>:workout=<ref>` |
| `habit.done` | eine erledigte Gewohnheit | `ref` = Gewohnheit | zählt für `app:<quelle>:habit[=<ref>]` |
| `ph` | Power-Hours (1 PH = 50 konzentrierte Minuten) | `value` in PH mit `unit` `"PH"`; mit `unit` `"min"` ist `value` in Minuten (Thalia teilt durch 50); `ref` = Gruppe | ein Arbeitsblock „aus <App>“ in der Kategorie aus `thalia.category`, sonst aus Thalias Zuordnung, sonst „ohne Zuordnung“; Summe für `app:<quelle>:ph[=<ref>]` |
| `value` | Kennzahl eines Tages | `metric`, `value` | Tageswert für `app:<quelle>:<metric>[=<ref>]` – bei `agg: sum` die Summe der Tatsachen des Tages, bei `agg: last` die letzte nach `at` (ohne `at` davor, in Dateireihenfolge) |
| `spending` | Ausgaben einer Gruppe an dem Tag (Tagessumme) | `value` (positiv), `currency`, `ref` = Gruppe | Summe für `app:<quelle>:spending[=<ref>]` |

Bei gezählten Arten (`*.done`) zählt jede Tatsache als 1; `value` wird dort nicht gelesen. Unbekannte Arten und
Kennzahlen behält Thalia und zeigt sie als „nicht verwendet“ – kein Fehler, aber keine Wirkung. Neue Arten nicht
erfinden, sondern im Bericht vorschlagen.

Kennzahlen für `value` (Tabelle v1 – sie wächst nur; eine neue Kennzahl behalten ältere Thalia-Versionen als „nicht
verwendet“):

| `metric` | `agg` | Einheit | Name |
|---|---|---|---|
| `kcal` | sum | kcal | Kalorien |
| `protein_g` | sum | g | Protein |
| `carbs_g` | sum | g | Kohlenhydrate |
| `fat_g` | sum | g | Fett |
| `water_ml` | sum | ml | Wasser |
| `net_worth` | last | € | Vermögen |
| `savings_rate` | last | % | Sparquote |
| `body_weight_kg` | last | kg | Gewicht |
| `account_balance` | last | € | Kontostand (ab Thalia 1.10.0) |

`account_balance` ist der Stand eines Kontos oder einer Kontogruppe am Ende des Tages: `ref` = id des Kontos bzw. der
Gruppe, `refTitle` = ihr Name, eine Tatsache je Konto. Thalia liest ihn nur für ein bestimmtes Konto
(`app:<quelle>:account_balance=<ref>`). Bei allen anderen Kennzahlen ist `ref` die Kennzahl selbst (`"kcal"`).

**Herkunft:** Thalias Eingang liegt in iCloud, und Gesundheitsdaten dürfen nicht nach iCloud (App Review Richtlinie
5.1.3(ii)). Darum schreibt Nina **keine Werte, die aus Apple Health stammen**. Nur wenn sich ein Wert gar nicht
anders trennen lässt, als eigene Tatsache mit `"origin":"health"` – Thalia verwirft solche Tatsachen, bevor sie
gespeichert werden.

**Datum:** ISO 8601 mit Zeitzone, **ohne Sekundenbruchteile**: `"2026-11-22T18:04:00+01:00"` (UTC: `"…Z"`). Thalia
liest auch Bruchteile, `+0100` und `Z`. Der **Tag** einer Tatsache ist der Kalendertag des Ereignisses in der Zeitzone
des Geräts (erledigt am, Ende des Workouts, Datum des Eintrags). Keine Tage in der Zukunft.

## 5. Schreiben – Regeln

1. **Eine Datei je Tag, immer vollständig** aus dem eigenen synchronisierten Speicher: alle Tatsachen des Tages, auch
   die auf einem anderen Gerät erfassten, die per Sync angekommen sind – nie nur „was auf diesem Gerät passiert ist“.
2. **Fehlt eine Tatsache** in einer vorhandenen Tagesdatei, ist sie für Thalia entfernt. Eine **fehlende Datei** heißt
   „keine Information“ (Thalia behält, was sie hat). Darum: Ein Tag, der eine Datei hatte und jetzt nichts mehr hat,
   bekommt `"facts":[]`; für Tage, die nie etwas hatten, keine Datei.
3. **Neu schreiben**, sobald sich an einem Tag etwas ändert, auch rückwirkend (ein geändertes Datum: beide Tage) –
   nach jedem eigenen Speichern (entprellt, etwa 2 s), **direkt nach dem eigenen CloudKit-Import**
   (`NSPersistentCloudKitContainer.eventChangedNotification`, `event.type == .import`, `endDate != nil`), beim Wechsel
   in den Vordergrund und beim Tageswechsel. Der einfachste sichere Weg: bei jedem Anlass alle Tage der letzten 62 Tage
   aus dem Speicher bauen und nur die geänderten schreiben (§9).
4. **Nur schreiben, wenn sich die Tatsachen geändert haben** (Vergleich ohne `generatedAt`); sonst bleibt die Datei, wie
   sie ist. Tatsachen in fester Reihenfolge (nach `at`, dann `id`), damit jedes Gerät denselben Inhalt erzeugt.
5. **Atomar:** in eine temporäre Datei im selben Ordner schreiben, dann umbenennen (`Data.write(to:options: .atomic)` tut
   das). Ordner bei Bedarf anlegen. Thalia liest nur Dateien `JJJJ-MM-TT.json` und überspringt Dotfiles und Temp-Dateien.
6. **JSON** in UTF-8, kompakt, Schlüssel sortiert, Schrägstriche nicht maskiert (`JSONEncoder` mit `.sortedKeys` und
   `.withoutEscapingSlashes`).
7. Danach – einmal je Schreibvorgang – die **Darwin-Benachrichtigung `at.binisoft.exchange.changed`** senden. Sie ist nur
   ein Hinweis: Thalia liest auch beim Start, im Vordergrund, alle 5 Minuten, solange sie offen ist, und nach ihrem
   eigenen iCloud-Import.
8. **Aufräumen:** Tagesdateien, die älter als 62 Tage sind (heute − Tag > 62), löscht Nina selbst. Thalia behält ihre
   Kopie im Eingang.
9. Das Schreiben verzögert nie den Start oder das Speichern (abseits des Main-Threads, entprellt) und zeigt nie einen
   Fehler – Probleme nur ins Log.
10. Was Bini in Nina ausschaltet, zählt wie nicht vorhanden: Der normale Abgleich schreibt die betroffenen Tage ohne
    diese Tatsachen neu, und Thalia nimmt sie für diese Tage heraus.

## 6. source.json

```json
{"v":1,"source":"nina","app":"Nina","appVersion":"1.0","generatedAt":"2026-11-22T21:15:00+01:00","refs":[
  {"id":"kcal","title":"Kalorien","kind":"metric"},{"id":"protein_g","title":"Protein","kind":"metric"},
  {"id":"carbs_g","title":"Kohlenhydrate","kind":"metric"},{"id":"fat_g","title":"Fett","kind":"metric"},
  {"id":"water_ml","title":"Wasser","kind":"metric"}]}
```

- Felder: `v` (1), `source` (wie in den Tagesdateien), `app` (Anzeigename „Nina“), `appVersion`, `generatedAt`,
  `refs` = alle stabilen ids, die Bini in Thalia auswählen können soll, je ein Objekt mit `id`, `title` und `kind`.
- `kind` eines refs: `"group"` (Gruppe von Aufgaben, Power-Hours oder Ausgaben), `"workout"` (Workout-Vorlage),
  `"habit"`, `"account"` (Konto oder Kontogruppe, ab Thalia 1.10.0), `"metric"` (Kennzahl). Thalias Editoren bieten
  unter „Verbundene App → Art → Eintrag“ die passenden an: Workouts → `workout`, Aufgaben/Power-Hours/Ausgaben →
  `group`, Gewohnheiten → `habit`, Kontostand → `account`; ein ref ohne `kind` passt zu allem. Andere Kennzahlen haben
  kein „Eintrag“ (der `ref` ihrer Tatsachen ist die Kennzahl selbst) – ein ref mit `"kind":"metric"` schadet nicht,
  Thalia bietet ihn aber nirgends an.
- Schreiben: sofort, wenn sich `refs` oder die App-Version ändern, sonst höchstens einmal am Tag (Herzschlag – Thalia
  zeigt daraus „zuletzt gesehen“). Atomar, danach die Darwin-Benachrichtigung. `source` muss zum Ordner passen.

## 7. Thalias Katalog und „Thalia-Kategorie“

Thalia schreibt `<Group>/Thalia/exchange/catalog.json` (solange „Thalia-Katalog bereitstellen“ an ist, Standard), nur
wenn sich die Struktur ändert. **Nur Struktur** – keine Werte, kein Fortschritt. Nina liest ihn nur, tolerant:
unbekannte Felder ignorieren; die Datei kann fehlen (Thalia war auf diesem Gerät noch nicht offen, oder der Katalog
ist aus).

| Feld | Inhalt |
|---|---|
| `v`, `source`, `generatedAt` | `1`, `"thalia"`, Zeitpunkt |
| `week` | die Woche, aus der die Messwerte stammen (`"2026-W47"`) |
| `segment` | aktueller Abschnitt der Jahresziele: `{"id":"seg-2","title":"Abschnitt 2"}` |
| `goals` | `[{"key":"3","title":"Arbeit"}]` |
| `categories` | `[{"key":"3.2","goal":"3","title":"Kunden","segment":"seg-2"}]` – `key` ist Text („1.1“, „5“) |
| `measures` | Messwerte der Woche, je mit `code`, `title`, `unit`, `link` (die Quelle des Messwerts, z. B. `"app:george:workout=tpl-1"`) und `category` |
| `results` | Ergebnisse der Jahresziele, je mit `id`, `title`, `kind` (`check` / `count` / `value`), `goal` und – ab Thalia 1.10.0 – `source`: woher der Wert kommt (`"app:finn:net_worth"`, `"app:finn:account_balance=acc-giro"`, `"list:buch"`); fehlt bei Ergebnissen mit eigenen Einträgen und in Katalogen von Thalia vor 1.10.0 |

Ein vollständiges Beispiel steht bei den Testdateien (§10).

**Auswahl „Thalia-Kategorie“** (ob Nina sie braucht, steht hier: Nina braucht sie nicht – Kennzahlen gelten unabhängig von Kategorien. **Nichts von der folgenden Liste bauen:** keine Auswahl, kein `thalia.mapping`, kein Feld `thalia`; sie steht nur der Vollständigkeit halber da):

- Zeilen „3.2 Kunden“, gruppiert nach Ziel („3 Arbeit“), oben „Keine“; auf iPhone, iPad und Mac gleich.
- Die Wahl wird je Gruppe als JSON in einem **vorhandenen, synchronisierten Einstellungs-Datensatz** von Nina
  gespeichert, z. B. unter dem Schlüssel `thalia.mapping`:
  `{"v":1,"groups":{"grp-91AB":{"category":"3.2","categoryTitle":"Kunden"}}}` – unbekannte Felder beim Speichern
  behalten. Synchronisiert, damit jedes Gerät dieselben Tagesdateien schreibt (nicht in `UserDefaults`). So braucht
  Nina keine CloudKit-Schemaänderung; gibt es keinen solchen Datensatz, vorher bei Bini nachfragen.
- Jede Tatsache einer zugeordneten Gruppe bekommt `"thalia":{"category":"3.2","categoryTitle":"Kunden"}`. Eine geänderte
  Zuordnung schreibt die betroffenen Tage neu (der 62-Tage-Abgleich erledigt das).
- Fehlt der Katalog: die gespeicherte Wahl zeigen und darunter „Thalias Katalog fehlt auf diesem Gerät – Thalia hier
  einmal öffnen.“ Fehlt die gewählte Kategorie im Katalog oder heißt sie dort anders als `categoryTitle`: „Zuordnung
  prüfen“.
- Thalia nimmt `thalia.category` vor ihrer eigenen Zuordnung (Einstellungen → Verbundene Apps); eine Kategorie, die
  Thalia nicht (mehr) hat, übergeht sie. Es reicht, wenn eine Tatsache der Gruppe am Tag die Kategorie trägt – besser
  tragen sie alle. Ohne Kategorie steht die Tatsache in Thalia unter „Ohne Zuordnung“, bis Bini sie dort zuordnet.

## 8. App Group und Entitlement

- Jedes Ziel, das schreibt – iPhone/iPad-App und Mac-App –, hat in seinen Entitlements unter
  `com.apple.security.application-groups` die Gruppe `group.at.binisoft.shared` (im Binisoft-Template über
  `$(SHARED_APP_GROUP)`, in der Info.plist `SharedAppGroup`). Widgets und Watch schreiben nicht – dort nichts ändern.
- Im Apple-Developer-Portal muss die Gruppe den App IDs zugewiesen sein. Das prüft Bini; nenne im Bericht die
  Bundle-IDs, denen die Gruppe zugewiesen sein muss.
- **Am Mac** zur Laufzeit prüfen, ob die signierte App die Gruppe wirklich hat (`SecTaskCopyValueForEntitlement`, §9) –
  abseits des Main-Threads und nicht während des Starts. Ohne das Entitlement kann macOS sonst nach Zugriff auf Daten
  anderer Apps fragen. Auf iPhone/iPad liefert `containerURL(forSecurityApplicationGroupIdentifier:)` ohne Gruppe `nil`
  → nichts tun. Unsignierte CI-Builds: nichts tun.

## 9. Referenzcode

Thalias Referenz für das Format ist eine einzige Datei, nur Foundation, Swift 5 und 6, zum unveränderten Kopieren
(z. B. ins Core-Paket von Nina; die Typen sind `public`):
https://github.com/Binisoft-at/thalia/blob/main/Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift
– Testdateien: https://github.com/Binisoft-at/thalia/tree/main/Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange
(öffentlich auf `main`). **Stand Thalia 1.10.0:** die Datei hat nur Zusätze bekommen – die Kennzahl `account_balance`,
das Katalog-Feld `results[].source` und toleranteres Lesen (eine Zahl, die nicht endlich ist oder dem Betrag nach ab
10¹², gilt als fehlend; ein unlesbares `v` gilt als 1). Wer sie schon aus Thalia 1.9.0 kopiert hat, ersetzt sie durch
die neue Fassung; eigener Code, der sie benutzt, bleibt gültig. Die Datei enthält `BinisoftExchange` (Pfade,
Dateinamen, Aufräumen,
atomares Schreiben, Kodieren), `ExchangeOrigin`, `ExchangeKind`, `ExchangeMetric.table`, `ExchangeFact`,
`ExchangeDayFile`, `ExchangeRef`, `ExchangeSourceInfo`, `ExchangeCatalog`, `ExchangeReader` (tolerantes Lesen mit
deutschen Gründen), `ExchangeDate` und `ExchangeHash` (FNV-1a 64 Bit). Ist sie nicht erreichbar, nach §4–§8 selbst
schreiben – diese Beschreibung ist verbindlich. Die Skizze unten nutzt die Typen dieser Datei.

Schreiber im Core (nur Foundation, unter Linux mit einem temporären Ordner testbar):

```swift
import Foundation

/// Schreibt die Tagesdateien (Format v1) nach `appFolder` = <Group>/Nina.
public enum ThaliaExchangeWriter {
    /// `facts`: alle Tatsachen der letzten 62 Tage aus dem eigenen synchronisierten Speicher, nach Tag ("2026-11-22").
    /// Schreibt nur Tage, deren Tatsachen sich geändert haben, und räumt alte Dateien auf. true = etwas geändert.
    @discardableResult
    public static func sync(_ facts: [String: [ExchangeFact]], source: String, appFolder: URL, today: String,
                            now: Date = Date()) throws -> Bool {
        let manager = FileManager.default
        var changed = false
        for offset in 0...BinisoftExchange.keepDays {
            guard let day = BinisoftExchange.day(today, adding: -offset) else { continue }
            let url = BinisoftExchange.dayFileURL(appFolder: appFolder, day: day)
            let sorted = (facts[day] ?? []).sorted { ($0.at ?? "", $0.id) < ($1.at ?? "", $1.id) }
            let old = try? Data(contentsOf: url)
            if old == nil && sorted.isEmpty { continue }                 // nie eine Datei für einen Tag ohne alles
            if let old, case .success(let read) = ExchangeReader.dayFile(old),
               let same = try? ExchangeDayFile(source: source, day: day, generatedAt: read.file.generatedAt,
                                               facts: sorted).encoded(),
               same == old { continue }                                  // unverändert: generatedAt bleibt
            let file = ExchangeDayFile(source: source, day: day, generatedAt: ExchangeDate.string(now), facts: sorted)
            try BinisoftExchange.write(file.encoded(), to: url)          // atomar: temp + rename
            changed = true
        }
        let days = BinisoftExchange.daysFolder(appFolder: appFolder)
        let names = (try? manager.contentsOfDirectory(atPath: days.path)) ?? []
        for name in BinisoftExchange.expiredDayFiles(names, today: today) {
            try? manager.removeItem(at: days.appendingPathComponent(name))
            changed = true
        }
        return changed
    }
}
```

App-Schicht (nicht auf der Watch):

```swift
#if !os(watchOS)
import Foundation
#if os(macOS)
import Security
#endif

enum ThaliaExchange {
    static let appName = "Nina"
    static let source = BinisoftExchange.sourceID(appName)   // "nina"

    /// <Group>/Nina – nil ohne App Group (unsignierter Build) und am Mac ohne Entitlement. Abseits des Main-Threads.
    static func appFolder() -> URL? {
        #if os(macOS)
        guard hasAppGroupEntitlement() else { return nil }
        #endif
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BinisoftExchange.appGroup)
        else { return nil }
        return root.appendingPathComponent(appName, isDirectory: true)
    }

    /// Thalias Katalog; nil, solange Thalia ihn auf diesem Gerät nicht geschrieben hat.
    static func catalog() -> ExchangeCatalog? {
        guard let folder = appFolder() else { return nil }
        let thalia = folder.deletingLastPathComponent().appendingPathComponent("Thalia", isDirectory: true)
        let url = BinisoftExchange.exchangeFolder(appFolder: thalia).appendingPathComponent(BinisoftExchange.catalogFileName)
        guard let data = try? Data(contentsOf: url), case .success(let catalog) = ExchangeReader.catalog(data) else { return nil }
        return catalog
    }

    /// Nach dem Schreiben: Thalia darf sofort nachsehen.
    static func postChanged() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(BinisoftExchange.changedNotification as CFString), nil, nil, true)
    }

    #if os(macOS)
    /// Hat die signierte App die Gruppe? Abseits des Main-Threads, nicht beim Start.
    static func hasAppGroupEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        return (value as? [String])?.contains(BinisoftExchange.appGroup) ?? false
    }
    #endif
}
#endif
```

Anstoßen (entprellt, etwa 2 s): nach jedem eigenen Speichern, beim Wechsel in den Vordergrund, beim Tageswechsel
(`.NSCalendarDayChanged`) und nach dem eigenen CloudKit-Import (`import CoreData`):

```swift
NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                                       queue: .main) { note in
    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event,
          event.type == .import, event.endDate != nil else { return }
    scheduleThaliaSync()
}
// scheduleThaliaSync(): die Tatsachen der letzten 62 Tage aus dem Speicher bauen (reine Werte), dann abseits des
// Main-Threads: ThaliaExchange.appFolder() → ThaliaExchangeWriter.sync(…, today: ExchangeDate.day(Date())) →
// bei Änderung postChanged(); source.json nach §6. Nicht im Demo-Modus, nicht in der Vorschau, nicht auf der Watch.
```

## 10. Tests

Logik (Tatsachen bauen, Dateien abgleichen) gehört ins Core-Paket, das unter Linux getestet wird; App-Group-Pfad,
Darwin-Benachrichtigung und Entitlement-Prüfung in die App-Schicht. Tests (Swift Testing oder wie im Repo üblich):

1. Tatsachen aus neutralen Beispieldatensätzen: richtige `kind`, `id` stabil (zweimal gebaut = gleich), `ref` und
   `refTitle`, `origin` `"app"`, `at` als `JJJJ-MM-TTTHH:MM:SS+HH:MM` (oder `…Z`) ohne Bruchteile.
2. Tag nach Zeitzone: ein Ereignis um `2026-11-22T23:30:00Z` gehört in `Europe/Vienna` zum `2026-11-23`.
3. Schreiben und zurücklesen: `ExchangeReader.dayFile(data, folder: "Nina", fileName: "2026-11-22.json")` ist
   erfolgreich und `skipped` leer; `ExchangeReader.source(data, folder: "Nina")` ebenso.
4. Abgleich in einem temporären Ordner: unveränderte Tatsachen → Datei unverändert (gleiche Bytes, gleiches
   `generatedAt`); eine entfernte Tatsache → Datei ohne sie; Tag ohne Tatsachen und ohne Datei → keine Datei; Tag mit
   Datei und jetzt ohne Tatsachen → `"facts":[]`; `BinisoftExchange.expiredDayFiles(["2026-09-20.json",
   "2026-09-21.json", "2026-11-22.json", ".x.json"], today: "2026-11-22")` ist `["2026-09-20.json"]` und genau diese
   Datei wird gelöscht.
5. Die Testdateien unten lesen sich (Tagesdatei, source.json, Katalog), und die eigene Ausgabe für denselben Inhalt
   hat dieselbe Form.
6. Keine Health-Werte: aus Apple Health stammende Datensätze ergeben keine Tatsache.
7. Werden ids mit FNV-1a gebildet (`ExchangeHash.hex`): `""` → `cbf29ce484222325`, `"a"` → `af63dc4c8601ec8c`,
   `"foobar"` → `85944171f73967e8`.
8. Nina: drei Mahlzeiten eines Tages ergeben je Kennzahl eine Tatsache mit der Summe; ein aus Apple Health importiertes
   Lebensmittel zählt nicht mit; ein Tag ohne Einträge hat keine Tatsachen; eine Mahlzeit auf einen anderen Tag
   verschoben → beide Tage neu; nur Kennzahlen aus der Tabelle (`fiber_g` aus der Testdatei unten wäre in Thalia
   „nicht verwendet“ – nicht schreiben).

Testdaten bleiben neutral wie diese (keine echten Namen, Beträge, Gewichte, Ziele). Testdateien aus Thalias Repo
(Ordner wie in der App Group):

`Nina/exchange/days/2026-11-22.json` – Testdatei für Thalias Leser: Einzel-Einträge (`kcal-1`, `kcal-2` – Thalia summiert), ein Datum mit Bruchteilen, eine unbekannte Kennzahl (`fiber_g`, „nicht verwendet“) und ein Wert aus Health (`kcal-hk`, verworfen). Nina selbst schreibt Tagessummen nach §2, ohne Bruchteile, ohne `fiber_g` und ohne Health-Werte.

```json
{
  "v": 1,
  "source": "nina",
  "day": "2026-11-22",
  "generatedAt": "2026-11-22T21:15:00.500+01:00",
  "facts": [
    { "id": "kcal-1", "kind": "value", "ref": "kcal", "refTitle": "Kalorien", "metric": "kcal", "value": 650, "unit": "kcal",
      "at": "2026-11-22T07:15:00.250+01:00", "origin": "app" },
    { "id": "kcal-2", "kind": "value", "ref": "kcal", "refTitle": "Kalorien", "metric": "kcal", "value": 1450, "unit": "kcal",
      "at": "2026-11-22T19:00:00+01:00", "origin": "app" },
    { "id": "protein-1", "kind": "value", "ref": "protein_g", "refTitle": "Protein", "metric": "protein_g", "value": 140, "unit": "g",
      "at": "2026-11-22T19:00:00+01:00", "origin": "app" },
    { "id": "fiber-1", "kind": "value", "ref": "fiber_g", "refTitle": "Ballaststoffe", "metric": "fiber_g", "value": 28, "unit": "g",
      "origin": "app" },
    { "id": "kcal-hk", "kind": "value", "ref": "kcal", "refTitle": "Kalorien", "metric": "kcal", "value": 300, "unit": "kcal",
      "origin": "health" }
  ]
}
```

`Thalia/exchange/catalog.json` – Thalias Katalog (§7) – nur Struktur; ab Thalia 1.10.0 mit `results[].source`.

```json
{
  "v": 1,
  "source": "thalia",
  "generatedAt": "2026-11-22T06:00:00+01:00",
  "week": "2026-W47",
  "segment": { "id": "seg-2", "title": "Abschnitt 2" },
  "goals": [
    { "key": "1", "title": "Gesundheit" },
    { "key": "3", "title": "Arbeit" },
    { "key": "5", "title": "Lesen" },
    { "key": "8", "title": "Finanzen" }
  ],
  "categories": [
    { "key": "1.2", "goal": "1", "title": "Sport / Verein", "segment": "seg-2" },
    { "key": "3.2", "goal": "3", "title": "Kunden", "segment": "seg-2" },
    { "key": "5", "goal": "5", "title": "Lesen", "segment": "seg-2" },
    { "key": "8.1", "goal": "8", "title": "Ausgaben", "segment": "seg-2" }
  ],
  "measures": [
    { "code": "workouts", "title": "Workouts", "unit": "Stück", "link": "app:george:workout=tpl-1", "category": "1.2" },
    { "code": "kunden_aufgaben", "title": "Aufgaben Kunden", "unit": "Stück", "link": "app:theo:task", "category": "3.2" },
    { "code": "seiten", "title": "Seiten", "unit": "Seiten", "link": "list:buch", "category": "5" },
    { "code": "ausgaben", "title": "Ausgaben", "unit": "€", "link": "app:finn:spending", "category": "8.1" }
  ],
  "results": [
    { "id": "res-web", "title": "Website online", "kind": "check", "goal": "3" },
    { "id": "res-books", "title": "Bücher gelesen", "kind": "count", "goal": "5", "source": "list:buch" },
    { "id": "res-worth", "title": "Vermögen", "kind": "value", "goal": "8", "source": "app:finn:net_worth" },
    { "id": "res-giro", "title": "Puffer Girokonto", "kind": "value", "goal": "8", "source": "app:finn:account_balance=acc-giro" }
  ]
}
```

## 11. Regeln

- **Keine CloudKit-Schemaänderung** in Nina: neue Einstellungen als JSON in einem vorhandenen Einstellungs-Datensatz;
  ein neues Feld oder eine neue Datensatzart nur nach Rückfrage bei Bini (das braucht „Deploy Schema Changes“).
- **Keine Werte aus Apple Health** (§4, Herkunft).
- **Öffentliches Repo:** keine persönlichen Daten in Code, Tests, Testdateien oder Doku – keine echten Namen, Beträge,
  Gewichte oder Ziele; neutrale Beispiele wie „Arbeit/Kunden“, „Push“, „Lesen“.
- Nie aus Demo- oder In-Memory-Speichern schreiben, nie auf der Watch.
- Bestehendes Verhalten von Nina bleibt, wie es ist. Deutsche Texte kurz und schlicht, z. B. in den Einstellungen
  ein Abschnitt „Thalia“ mit den Schaltern aus §2, „Zuletzt geschrieben: …“ und dem Hinweis „Thalia übernimmt die
  Werte, sobald Thalia auf diesem Gerät geöffnet wird.“

## 12. Bericht

Am Ende kurz: was gebaut ist und wo (Dateien), Version, Tests und Prüfungen; die Bundle-IDs, die die App Group
`group.at.binisoft.shared` brauchen; welche `refs` `source.json` liefert (Art und Anzahl, keine Inhalte); was Bini
tun muss (z. B. Schalter einschalten, Zuordnung wählen); offene Fragen.
````

### 3.4 Finn

````markdown
# Auftrag: Finn liefert Thalia Daten (Binisoft-Austausch, Format v1)

Dieser Auftrag ist vollständig – alles Nötige steht hier, kein anderes Repo muss gelesen werden. Arbeite in diesem Repo
(Finn) nach dem Binisoft-Handbuch und den Regeln des Repos (HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST): zuerst ein
kurzer Plan in `docs/`, die Logik im Core-Paket mit Tests unter Linux, lokale Prüfung vor dem Push, Version erhöhen,
am Ende ein Bericht (§12). Bei Unklarem: fragen, nicht raten.

## 1. Worum es geht

Thalia ist Binis Planer für Wochenpläne und Jahresziele (ebenfalls eine Binisoft-App). Ab Thalia 1.9.0 können andere
Binisoft-Apps Thalia automatisch Tatsachen liefern: erledigte Aufgaben, Power-Hours, Workouts, Tageswerte, Ausgaben.
Finn schreibt dafür kleine JSON-Dateien in die gemeinsame App Group. Thalia liest sie auf demselben Gerät, legt sie
in ihren eigenen iCloud-Eingang und **rechnet** daraus Werte – Thalia legt dafür nie eigene Einträge an, und Binis eigene
Einträge in Thalia gewinnen immer. Finn liest von Thalia nur einen Katalog mit Thalias Struktur (§7). Keine App
ändert die Daten der anderen; es gibt kein Netz, keinen Server, keine Berechtigungsabfrage.

Diese Fassung gilt ab **Thalia 1.10.0** (Kontostände, Anzeige „→ Thalia: …“). Liefert Finn schon nach einer früheren
Fassung: „monatlich“ beim Vermögen entfällt (eine gespeicherte Wahl „monatlich“ gilt als „bei jeder Änderung“), und
Schalter, die in `UserDefaults` liegen, kommen einmal in den synchronisierten Datensatz aus §2.

## 2. Was Finn liefert

Nur, was Bini in Finn einschaltet – **jede Zeile einzeln, mit eigenem Schalter, Standard aus** (Einstellungen →
Abschnitt „Thalia“, §7 „Anzeige in Finn“):

- **Ausgaben je Gruppe** (jede Gruppe ein eigener Schalter): `spending`, eine Tatsache je eingeschalteter Finn-Gruppe
  und Tag mit der Tagessumme der eigenen Ausgaben:
  `{"id":"sp-<Gruppen-id>-2026-11-22","kind":"spending","ref":"<Gruppen-id>","refTitle":"Lebensmittel","title":"Lebensmittel","value":23.4,"currency":"EUR","at":"2026-11-22T17:45:00+01:00","origin":"app"}`
  - `value` positiv, auf Cent gerundet; nur Ausgaben – keine Einnahmen, keine Umbuchungen zwischen eigenen Konten;
    `at` = Zeitpunkt der letzten Ausgabe des Tages (optional).
  - Ein Tag ohne Ausgaben in der Gruppe: keine Tatsache.
- **Vermögen** (`aus` / `bei jeder Änderung`, kein „monatlich“): an jedem Tag, an dem sich das Vermögen ändert, eine
  Tatsache mit dem Stand am Ende des Tages – `kind` `"value"`, `metric` `"net_worth"` (`agg: last`), `ref`
  `"net_worth"`, `refTitle` `"Vermögen"`, Wert in Euro, `currency` `"EUR"`, `id` `"nw-<JJJJ-MM-TT>"`
  (`"nw-2026-11-22"`). Ein Tag ohne Änderung hat keine Tatsache – Thalia nimmt den letzten Stand. Ältere Tatsachen
  `nw-<JJJJ-MM>` in Thalias Eingang bleiben lesbar.
- **Sparquote** (`aus` / `an`): eine Tatsache je Monat in der Datei des Monatsletzten – `metric` `"savings_rate"` in
  Prozent (`agg: last`, `unit` `"%"`), `ref` `"savings_rate"`, `refTitle` `"Sparquote"`, `id` `"sr-<JJJJ-MM>"`
  (`"sr-2026-10"` in `days/2026-10-31.json`). Der laufende Monat kommt, sobald er vorbei ist.
- **Kontostände** (je Konto und je Kontogruppe ein eigener Schalter, `aus` / `an`): an jedem Tag, an dem sich der Stand
  ändert, eine Tatsache mit dem Stand am Ende des Tages – `kind` `"value"`, `metric` `"account_balance"` (`agg: last`,
  €, „Kontostand“, neu in Thalia 1.10.0), `ref` = id des Kontos bzw. der Kontogruppe (stabil, synchronisiert),
  `refTitle` = ihr Name, `currency` `"EUR"`, `id` `"kb-<ref>-<JJJJ-MM-TT>"` (`"kb-acc-giro-2026-11-22"`). Eine
  Kontogruppe liefert die Summe ihrer Konten.
- **Nur eigene Daten:** nur Binis eigene Konten und Buchungen – **nie die geteilte Haushaltszone** und nie Buchungen
  anderer Personen, auch nicht anteilig; auch kein Konto oder Vermögen der Haushaltszone.
- **Währung EUR:** Beträge in Euro mit `"currency":"EUR"`. Thalia rechnet nicht um; Buchungen in anderer Währung mit dem
  Euro-Betrag, den Finn zeigt, sonst weglassen.
- `source.json` → `refs`: die eingeschalteten Gruppen (`"kind":"group"`) und Konten bzw. Kontogruppen
  (`"kind":"account"`) – daraus wählt Bini in Thalia „Eintrag“. Vermögen und Sparquote brauchen keinen ref.
- **Die Auswahl ist synchronisiert:** welche Zeilen an sind, liegt als JSON in einem **vorhandenen, synchronisierten
  Einstellungs-Datensatz** von Finn, z. B. unter dem Schlüssel `thalia.delivery`:
  `{"v":1,"spending":["grp-lebensmittel","grp-freizeit"],"netWorth":"change","savingsRate":true,"accounts":["acc-giro","accgrp-sparen"]}`
  (Beispiel; unbekannte Felder beim Speichern behalten) – **nie in `UserDefaults`**. So schreibt jedes Gerät dieselben
  Tagesdateien; sonst schrieben iPhone und Mac abwechselnd verschiedene Fassungen derselben Tage. Gibt es keinen
  solchen Datensatz, vorher bei Bini nachfragen.
- Ausschalten wirkt wie §5 Regel 10: die Tage der letzten 62 Tage werden ohne diese Tatsachen neu geschrieben.
- **Anzeige in Finn:** jede Zeile zeigt unter ihrem Schalter, wofür sie in Thalia zählt (§7).

Was Thalia daraus macht: Ausgaben erscheinen in Thalias Ausgabenliste und deren Gruppen nur zum Lesen („aus Finn – in
Finn ändern“), eigene Ausgaben in Thalia kommen dazu (Messwert-Quelle `app:finn:spending` für alle Gruppen oder
`app:finn:spending=<Gruppen-id>`). Vermögen, Sparquote und Kontostände speisen **Ergebnisse** der Jahresziele (Art
„Zielwert“, der letzte Wert zählt) mit der Quelle `app:finn:net_worth`, `app:finn:savings_rate` oder
`app:finn:account_balance=<Konto-id>` – ein Kontostand immer für ein bestimmtes Konto, nie „alle“. Als Messwert bietet
Thalia sie nicht an (ein Messwert in € zählt in Thalia als Ausgabe). „Was kommt an“ in Thalia zeigt einen Kontostand
mit seinem Konto: „Kontostand 1.234,50 € · Girokonto“.

## 3. Weg und Ordner

- App Group **`group.at.binisoft.shared`** (alle Binisoft-Apps haben sie). Laut Handbuch §6 liegen dort nur kleine
  Ereignisse und Zusammenfassungen, nie die Daten der App selbst.
- Ordner von Finn: `<Group>/Finn/exchange/` – der Ordnername ist der Anzeigename „Finn“, genau wie
  `AppGroupFolder.url(appName: "Finn")` aus BinisoftKit (ohne BinisoftKit:
  `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.at.binisoft.shared")?
  .appendingPathComponent("Finn")`; am Mac beides erst nach der Entitlement-Prüfung, §8). Darin:
  - `source.json` – Herzschlag und Verzeichnis der stabilen ids (§6)
  - `days/JJJJ-MM-TT.json` – eine Datei je Tag (§4, §5)
- Finn schreibt **nur** in seinen eigenen Ordner. Thalia schreibt nur `<Group>/Thalia/exchange/catalog.json`;
  Finn liest ihn nur.
- Die App Group ist ein Ordner **auf einem Gerät**. Thalia sieht nur Dateien, die auf demselben Gerät geschrieben wurden.
  Darum schreibt Finn auf **jedem iPhone, iPad und Mac**, auf dem es läuft – immer aus dem eigenen synchronisierten
  Speicher, so dass jedes Gerät denselben Inhalt schreibt. Thalia legt jede Tagesdatei in ihren iCloud-Eingang; ab da
  sehen alle Geräte mit Thalia die Werte.
- **Nie auf der Apple Watch** – dort weder lesen noch schreiben (`#if !os(watchOS)`). Was auf der Watch erfasst wird,
  kommt über den Sync von Finn auf iPhone/iPad/Mac und von dort in die Tagesdatei.
- **Nur aus dem echten Speicher** – nie aus Demo-, Screenshot-, Vorschau-, Test- oder In-Memory-Speichern (z. B. beim
  Start mit `-Demo`): Beispieldaten dürfen nie bei Thalia ankommen.

## 4. Tagesdatei – Format v1

Beispiel (eine Tagesdatei von Theo):

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"}]}
```

Felder der Datei (alle Pflicht):

| Feld | Inhalt |
|---|---|
| `v` | `1` (Zahl). Thalia liest Version 1 und höher; kleiner als 1 wird abgelehnt. |
| `source` | Quellen-id: der Ordnername klein, nur `a–z`, `0–9`, `-` – hier `"finn"`. Passt sie nicht zum Ordner, lehnt Thalia die Datei ab. |
| `day` | `"JJJJ-MM-TT"`, ein echter Kalendertag; muss zum Dateinamen passen (`days/2026-11-22.json`), sonst abgelehnt. |
| `generatedAt` | Zeitpunkt des Schreibens (Datumsform unten). Hat Thalia für Quelle und Tag schon eine Fassung, gewinnt die mit dem neueren `generatedAt`. |
| `facts` | Liste der Tatsachen des Tages (darf leer sein: `[]`). |

Felder einer Tatsache:

| Feld | | Inhalt |
|---|---|---|
| `id` | Pflicht | Stabil und auf allen Geräten gleich, in der Datei eindeutig. Aus der **synchronisierten** id des Datensatzes (z. B. sein UUID-Feld) – nie `persistentModelID` oder `NSManagedObjectID` (je Gerät verschieden). Präfix je Art, z. B. `"task-…"`. |
| `kind` | Pflicht | Art, siehe unten. |
| `origin` | Pflicht | `"app"` = in Finn selbst erfasst, `"health"` = aus Apple Health. Ohne `origin` (oder mit anderem Wert) verwendet Thalia die Tatsache nicht. |
| `ref` | empfohlen | Stabile id in der Quelle, auf die sich die Tatsache bezieht: Gruppe, Workout-Vorlage, Kennzahl, Konto. Über `ref` ordnet Bini in Thalia zu. |
| `refTitle` | empfohlen | Anzeigename von `ref` („Arbeit/Kunden“). |
| `title` | optional | Titel der Sache („Rechnung schreiben“); Thalia zeigt ihn an. |
| `value` | je nach Art | JSON-Zahl mit Punkt (`1.5`), keine Zeichenkette. |
| `unit` | optional | `"PH"`, `"min"`, `"kcal"`, `"g"`, `"ml"` … |
| `metric` | bei `value` | Kennzahl aus der Tabelle unten. |
| `currency` | bei Geld | ISO 4217, `"EUR"`. |
| `at` | empfohlen | Zeitpunkt des Ereignisses (Datumsform unten). |
| `thalia` | optional | Was in Finn aus Thalias Katalog gewählt wurde: `{"category":"3.2","categoryTitle":"Kunden"}` (§7). `measure` und `result` sind für später reserviert – weglassen. |

Kein Verweis auf Thalias Wochen-Punkte (deren Codes gelten nur eine Woche). Unbekannte Felder liest Thalia nicht,
stören aber nicht.

Arten (v1) und was Thalia damit tut:

| `kind` | Bedeutung | Felder | In Thalia |
|---|---|---|---|
| `task.done` | eine erledigte Aufgabe | `ref` = Gruppe | zählt für Messwerte `app:<quelle>:task` (Aufgaben, deren Kategorie die des Messwerts ist) und `app:<quelle>:task=<ref>` (Aufgaben dieser Gruppe) |
| `workout.done` | ein abgeschlossenes Workout | `ref` = Vorlage | zählt für `app:<quelle>:workout` (alle) und `app:<quelle>:workout=<ref>` |
| `habit.done` | eine erledigte Gewohnheit | `ref` = Gewohnheit | zählt für `app:<quelle>:habit[=<ref>]` |
| `ph` | Power-Hours (1 PH = 50 konzentrierte Minuten) | `value` in PH mit `unit` `"PH"`; mit `unit` `"min"` ist `value` in Minuten (Thalia teilt durch 50); `ref` = Gruppe | ein Arbeitsblock „aus <App>“ in der Kategorie aus `thalia.category`, sonst aus Thalias Zuordnung, sonst „ohne Zuordnung“; Summe für `app:<quelle>:ph[=<ref>]` |
| `value` | Kennzahl eines Tages | `metric`, `value` | Tageswert für `app:<quelle>:<metric>[=<ref>]` – bei `agg: sum` die Summe der Tatsachen des Tages, bei `agg: last` die letzte nach `at` (ohne `at` davor, in Dateireihenfolge) |
| `spending` | Ausgaben einer Gruppe an dem Tag (Tagessumme) | `value` (positiv), `currency`, `ref` = Gruppe | Summe für `app:<quelle>:spending[=<ref>]` |

Bei gezählten Arten (`*.done`) zählt jede Tatsache als 1; `value` wird dort nicht gelesen. Unbekannte Arten und
Kennzahlen behält Thalia und zeigt sie als „nicht verwendet“ – kein Fehler, aber keine Wirkung. Neue Arten nicht
erfinden, sondern im Bericht vorschlagen.

Kennzahlen für `value` (Tabelle v1 – sie wächst nur; eine neue Kennzahl behalten ältere Thalia-Versionen als „nicht
verwendet“):

| `metric` | `agg` | Einheit | Name |
|---|---|---|---|
| `kcal` | sum | kcal | Kalorien |
| `protein_g` | sum | g | Protein |
| `carbs_g` | sum | g | Kohlenhydrate |
| `fat_g` | sum | g | Fett |
| `water_ml` | sum | ml | Wasser |
| `net_worth` | last | € | Vermögen |
| `savings_rate` | last | % | Sparquote |
| `body_weight_kg` | last | kg | Gewicht |
| `account_balance` | last | € | Kontostand (ab Thalia 1.10.0) |

`account_balance` ist der Stand eines Kontos oder einer Kontogruppe am Ende des Tages: `ref` = id des Kontos bzw. der
Gruppe, `refTitle` = ihr Name, eine Tatsache je Konto. Thalia liest ihn nur für ein bestimmtes Konto
(`app:<quelle>:account_balance=<ref>`). Bei allen anderen Kennzahlen ist `ref` die Kennzahl selbst (`"kcal"`).

**Herkunft:** Thalias Eingang liegt in iCloud, und Gesundheitsdaten dürfen nicht nach iCloud (App Review Richtlinie
5.1.3(ii)). Darum schreibt Finn **keine Werte, die aus Apple Health stammen**. Nur wenn sich ein Wert gar nicht
anders trennen lässt, als eigene Tatsache mit `"origin":"health"` – Thalia verwirft solche Tatsachen, bevor sie
gespeichert werden.

**Datum:** ISO 8601 mit Zeitzone, **ohne Sekundenbruchteile**: `"2026-11-22T18:04:00+01:00"` (UTC: `"…Z"`). Thalia
liest auch Bruchteile, `+0100` und `Z`. Der **Tag** einer Tatsache ist der Kalendertag des Ereignisses in der Zeitzone
des Geräts (erledigt am, Ende des Workouts, Datum des Eintrags). Keine Tage in der Zukunft.

## 5. Schreiben – Regeln

1. **Eine Datei je Tag, immer vollständig** aus dem eigenen synchronisierten Speicher: alle Tatsachen des Tages, auch
   die auf einem anderen Gerät erfassten, die per Sync angekommen sind – nie nur „was auf diesem Gerät passiert ist“.
2. **Fehlt eine Tatsache** in einer vorhandenen Tagesdatei, ist sie für Thalia entfernt. Eine **fehlende Datei** heißt
   „keine Information“ (Thalia behält, was sie hat). Darum: Ein Tag, der eine Datei hatte und jetzt nichts mehr hat,
   bekommt `"facts":[]`; für Tage, die nie etwas hatten, keine Datei.
3. **Neu schreiben**, sobald sich an einem Tag etwas ändert, auch rückwirkend (ein geändertes Datum: beide Tage) –
   nach jedem eigenen Speichern (entprellt, etwa 2 s), **direkt nach dem eigenen CloudKit-Import**
   (`NSPersistentCloudKitContainer.eventChangedNotification`, `event.type == .import`, `endDate != nil`), beim Wechsel
   in den Vordergrund und beim Tageswechsel. Der einfachste sichere Weg: bei jedem Anlass alle Tage der letzten 62 Tage
   aus dem Speicher bauen und nur die geänderten schreiben (§9).
4. **Nur schreiben, wenn sich die Tatsachen geändert haben** (Vergleich ohne `generatedAt`); sonst bleibt die Datei, wie
   sie ist. Tatsachen in fester Reihenfolge (nach `at`, dann `id`), damit jedes Gerät denselben Inhalt erzeugt.
5. **Atomar:** in eine temporäre Datei im selben Ordner schreiben, dann umbenennen (`Data.write(to:options: .atomic)` tut
   das). Ordner bei Bedarf anlegen. Thalia liest nur Dateien `JJJJ-MM-TT.json` und überspringt Dotfiles und Temp-Dateien.
6. **JSON** in UTF-8, kompakt, Schlüssel sortiert, Schrägstriche nicht maskiert (`JSONEncoder` mit `.sortedKeys` und
   `.withoutEscapingSlashes`).
7. Danach – einmal je Schreibvorgang – die **Darwin-Benachrichtigung `at.binisoft.exchange.changed`** senden. Sie ist nur
   ein Hinweis: Thalia liest auch beim Start, im Vordergrund, alle 5 Minuten, solange sie offen ist, und nach ihrem
   eigenen iCloud-Import.
8. **Aufräumen:** Tagesdateien, die älter als 62 Tage sind (heute − Tag > 62), löscht Finn selbst. Thalia behält ihre
   Kopie im Eingang.
9. Das Schreiben verzögert nie den Start oder das Speichern (abseits des Main-Threads, entprellt) und zeigt nie einen
   Fehler – Probleme nur ins Log.
10. Was Bini in Finn ausschaltet, zählt wie nicht vorhanden: Der normale Abgleich schreibt die betroffenen Tage ohne
    diese Tatsachen neu, und Thalia nimmt sie für diese Tage heraus.

## 6. source.json

```json
{
  "v": 1,
  "source": "finn",
  "app": "Finn",
  "appVersion": "1.0",
  "generatedAt": "2026-11-22T20:00:00Z",
  "refs": [
    { "id": "grp-lebensmittel", "title": "Lebensmittel", "kind": "group" },
    { "id": "grp-freizeit", "title": "Freizeit", "kind": "group" },
    { "id": "acc-giro", "title": "Girokonto", "kind": "account" },
    { "id": "accgrp-sparen", "title": "Sparen", "kind": "account" }
  ]
}
```

- Felder: `v` (1), `source` (wie in den Tagesdateien), `app` (Anzeigename „Finn“), `appVersion`, `generatedAt`,
  `refs` = alle stabilen ids, die Bini in Thalia auswählen können soll, je ein Objekt mit `id`, `title` und `kind`.
- Finn: die eingeschalteten Ausgaben-Gruppen mit `"kind":"group"`, die eingeschalteten Konten und Kontogruppen mit
  `"kind":"account"` (im Beispiel ein Konto und eine Kontogruppe). Vermögen und Sparquote brauchen keinen ref.
- `kind` eines refs: `"group"` (Gruppe von Aufgaben, Power-Hours oder Ausgaben), `"workout"` (Workout-Vorlage),
  `"habit"`, `"account"` (Konto oder Kontogruppe, ab Thalia 1.10.0), `"metric"` (Kennzahl). Thalias Editoren bieten
  unter „Verbundene App → Art → Eintrag“ die passenden an: Workouts → `workout`, Aufgaben/Power-Hours/Ausgaben →
  `group`, Gewohnheiten → `habit`, Kontostand → `account`; ein ref ohne `kind` passt zu allem. Andere Kennzahlen haben
  kein „Eintrag“ (der `ref` ihrer Tatsachen ist die Kennzahl selbst) – ein ref mit `"kind":"metric"` schadet nicht,
  Thalia bietet ihn aber nirgends an.
- Schreiben: sofort, wenn sich `refs` oder die App-Version ändern, sonst höchstens einmal am Tag (Herzschlag – Thalia
  zeigt daraus „zuletzt gesehen“). Atomar, danach die Darwin-Benachrichtigung. `source` muss zum Ordner passen.

## 7. Thalias Katalog und „Thalia-Kategorie“

Thalia schreibt `<Group>/Thalia/exchange/catalog.json` (solange „Thalia-Katalog bereitstellen“ an ist, Standard), nur
wenn sich die Struktur ändert. **Nur Struktur** – keine Werte, kein Fortschritt. Finn liest ihn nur, tolerant:
unbekannte Felder ignorieren; die Datei kann fehlen (Thalia war auf diesem Gerät noch nicht offen, oder der Katalog
ist aus).

| Feld | Inhalt |
|---|---|
| `v`, `source`, `generatedAt` | `1`, `"thalia"`, Zeitpunkt |
| `week` | die Woche, aus der die Messwerte stammen (`"2026-W47"`) |
| `segment` | aktueller Abschnitt der Jahresziele: `{"id":"seg-2","title":"Abschnitt 2"}` |
| `goals` | `[{"key":"3","title":"Arbeit"}]` |
| `categories` | `[{"key":"3.2","goal":"3","title":"Kunden","segment":"seg-2"}]` – `key` ist Text („1.1“, „5“) |
| `measures` | Messwerte der Woche, je mit `code`, `title`, `unit`, `link` (die Quelle des Messwerts, z. B. `"app:george:workout=tpl-1"`) und `category` |
| `results` | Ergebnisse der Jahresziele, je mit `id`, `title`, `kind` (`check` / `count` / `value`), `goal` und – ab Thalia 1.10.0 – `source`: woher der Wert kommt (`"app:finn:net_worth"`, `"app:finn:account_balance=acc-giro"`, `"list:buch"`); fehlt bei Ergebnissen mit eigenen Einträgen und in Katalogen von Thalia vor 1.10.0 |

Ein vollständiges Beispiel steht bei den Testdateien (§10).

**Anzeige in Finn: wofür eine Zeile in Thalia zählt** (das braucht Finn). Einstellungen → „Thalia“ listet jede Zeile
aus §2 mit ihrem Schalter und darunter, klein und grau, wofür sie in Thalia zählt – gelesen aus dem Katalog dieses
Geräts (neu lesen, wenn die Einstellungen erscheinen). Jede Zeile hat eine Thalia-Quelle; gesucht wird sie in
`measures[].link` und in `results[].source` (Leerzeichen außen egal, `app:finn:<art>` ohne Groß-/Kleinschreibung, der
Teil nach `=` genau):

| Zeile in Finn | passt zu |
|---|---|
| Ausgaben-Gruppe `<g>` | `app:finn:spending=<g>` und `app:finn:spending` (alle Gruppen) |
| Vermögen | `app:finn:net_worth` |
| Sparquote | `app:finn:savings_rate` |
| Konto oder Kontogruppe `<k>` | `app:finn:account_balance=<k>` |

- Ein Messwert: „→ Thalia: Messwert „Ausgaben““, bei `app:finn:spending` ohne `=` mit „(alle Gruppen)“: „→ Thalia:
  Messwert „Ausgaben“ (alle Gruppen)“. Ein Ergebnis: „→ Thalia: Ergebnis „Vermögen“ (Ziel 8)“ (`title` und `goal`).
  Mehrere Treffer: je eine Zeile.
- Kein Treffer: „noch nicht in Thalia verknüpft“.
- Katalog fehlt (Thalia war auf diesem Gerät noch nicht offen, oder der Katalog ist aus): statt der Hinweise einmal
  „Thalias Katalog fehlt auf diesem Gerät – Thalia hier einmal öffnen.“
- Katalog ohne `results[].source` (Thalia vor 1.10.0 schreibt das Feld nicht): hat kein Ergebnis ein `source`, zeigen
  Vermögen, Sparquote und Konten ohne Treffer „Thalia auf diesem Gerät aktualisieren – dann steht hier, wofür der Wert
  zählt“ statt „noch nicht in Thalia verknüpft“. Ausgaben-Zeilen prüfen weiter `measures[].link` (gab es schon
  vorher). Ein Katalog von 1.10.0 ohne ein einziges Ergebnis mit Quelle sieht gleich aus – der Hinweis schadet dort
  nicht.
- Mit dem Katalog aus §10: Vermögen → „→ Thalia: Ergebnis „Vermögen“ (Ziel 8)“; Konto „Girokonto“ → „→ Thalia:
  Ergebnis „Puffer Girokonto“ (Ziel 8)“; „Lebensmittel“ und „Freizeit“ → „→ Thalia: Messwert „Ausgaben“ (alle
  Gruppen)“; Kontogruppe „Sparen“ und Sparquote → „noch nicht in Thalia verknüpft“.
- Nur anzeigen: die Anzeige ändert keine Tatsache und keinen Schalter.

**Auswahl „Thalia-Kategorie“** (ob Finn sie braucht, steht hier: Finn braucht sie nicht – Ausgaben-Gruppen, Vermögen, Sparquote und Konten verknüpft Bini in Thalia, mit den ids aus `refs`. **Nichts von der folgenden Liste bauen:** keine Auswahl, kein `thalia.mapping`, kein Feld `thalia`; sie steht nur der Vollständigkeit halber da):

- Zeilen „3.2 Kunden“, gruppiert nach Ziel („3 Arbeit“), oben „Keine“; auf iPhone, iPad und Mac gleich.
- Die Wahl wird je Gruppe als JSON in einem **vorhandenen, synchronisierten Einstellungs-Datensatz** von Finn
  gespeichert, z. B. unter dem Schlüssel `thalia.mapping`:
  `{"v":1,"groups":{"grp-91AB":{"category":"3.2","categoryTitle":"Kunden"}}}` – unbekannte Felder beim Speichern
  behalten. Synchronisiert, damit jedes Gerät dieselben Tagesdateien schreibt (nicht in `UserDefaults`). So braucht
  Finn keine CloudKit-Schemaänderung; gibt es keinen solchen Datensatz, vorher bei Bini nachfragen.
- Jede Tatsache einer zugeordneten Gruppe bekommt `"thalia":{"category":"3.2","categoryTitle":"Kunden"}`. Eine geänderte
  Zuordnung schreibt die betroffenen Tage neu (der 62-Tage-Abgleich erledigt das).
- Fehlt der Katalog: die gespeicherte Wahl zeigen und darunter „Thalias Katalog fehlt auf diesem Gerät – Thalia hier
  einmal öffnen.“ Fehlt die gewählte Kategorie im Katalog oder heißt sie dort anders als `categoryTitle`: „Zuordnung
  prüfen“.
- Thalia nimmt `thalia.category` vor ihrer eigenen Zuordnung (Einstellungen → Verbundene Apps); eine Kategorie, die
  Thalia nicht (mehr) hat, übergeht sie. Es reicht, wenn eine Tatsache der Gruppe am Tag die Kategorie trägt – besser
  tragen sie alle. Ohne Kategorie steht die Tatsache in Thalia unter „Ohne Zuordnung“, bis Bini sie dort zuordnet.

## 8. App Group und Entitlement

- Jedes Ziel, das schreibt – iPhone/iPad-App und Mac-App –, hat in seinen Entitlements unter
  `com.apple.security.application-groups` die Gruppe `group.at.binisoft.shared` (im Binisoft-Template über
  `$(SHARED_APP_GROUP)`, in der Info.plist `SharedAppGroup`). Widgets und Watch schreiben nicht – dort nichts ändern.
- Im Apple-Developer-Portal muss die Gruppe den App IDs zugewiesen sein. Das prüft Bini; nenne im Bericht die
  Bundle-IDs, denen die Gruppe zugewiesen sein muss.
- **Am Mac** zur Laufzeit prüfen, ob die signierte App die Gruppe wirklich hat (`SecTaskCopyValueForEntitlement`, §9) –
  abseits des Main-Threads und nicht während des Starts. Ohne das Entitlement kann macOS sonst nach Zugriff auf Daten
  anderer Apps fragen. Auf iPhone/iPad liefert `containerURL(forSecurityApplicationGroupIdentifier:)` ohne Gruppe `nil`
  → nichts tun. Unsignierte CI-Builds: nichts tun.

## 9. Referenzcode

Thalias Referenz für das Format ist eine einzige Datei, nur Foundation, Swift 5 und 6, zum unveränderten Kopieren
(z. B. ins Core-Paket von Finn; die Typen sind `public`):
https://github.com/Binisoft-at/thalia/blob/main/Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift
– Testdateien: https://github.com/Binisoft-at/thalia/tree/main/Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange
(öffentlich auf `main`). **Stand Thalia 1.10.0:** die Datei hat nur Zusätze bekommen – die Kennzahl `account_balance`,
das Katalog-Feld `results[].source` und toleranteres Lesen (eine Zahl, die nicht endlich ist oder dem Betrag nach ab
10¹², gilt als fehlend; ein unlesbares `v` gilt als 1). Wer sie schon aus Thalia 1.9.0 kopiert hat, ersetzt sie durch
die neue Fassung; eigener Code, der sie benutzt, bleibt gültig. Die Datei enthält `BinisoftExchange` (Pfade,
Dateinamen, Aufräumen,
atomares Schreiben, Kodieren), `ExchangeOrigin`, `ExchangeKind`, `ExchangeMetric.table`, `ExchangeFact`,
`ExchangeDayFile`, `ExchangeRef`, `ExchangeSourceInfo`, `ExchangeCatalog`, `ExchangeReader` (tolerantes Lesen mit
deutschen Gründen), `ExchangeDate` und `ExchangeHash` (FNV-1a 64 Bit). Ist sie nicht erreichbar, nach §4–§8 selbst
schreiben – diese Beschreibung ist verbindlich. Die Skizze unten nutzt die Typen dieser Datei.

Schreiber im Core (nur Foundation, unter Linux mit einem temporären Ordner testbar):

```swift
import Foundation

/// Schreibt die Tagesdateien (Format v1) nach `appFolder` = <Group>/Finn.
public enum ThaliaExchangeWriter {
    /// `facts`: alle Tatsachen der letzten 62 Tage aus dem eigenen synchronisierten Speicher, nach Tag ("2026-11-22").
    /// Schreibt nur Tage, deren Tatsachen sich geändert haben, und räumt alte Dateien auf. true = etwas geändert.
    @discardableResult
    public static func sync(_ facts: [String: [ExchangeFact]], source: String, appFolder: URL, today: String,
                            now: Date = Date()) throws -> Bool {
        let manager = FileManager.default
        var changed = false
        for offset in 0...BinisoftExchange.keepDays {
            guard let day = BinisoftExchange.day(today, adding: -offset) else { continue }
            let url = BinisoftExchange.dayFileURL(appFolder: appFolder, day: day)
            let sorted = (facts[day] ?? []).sorted { ($0.at ?? "", $0.id) < ($1.at ?? "", $1.id) }
            let old = try? Data(contentsOf: url)
            if old == nil && sorted.isEmpty { continue }                 // nie eine Datei für einen Tag ohne alles
            if let old, case .success(let read) = ExchangeReader.dayFile(old),
               let same = try? ExchangeDayFile(source: source, day: day, generatedAt: read.file.generatedAt,
                                               facts: sorted).encoded(),
               same == old { continue }                                  // unverändert: generatedAt bleibt
            let file = ExchangeDayFile(source: source, day: day, generatedAt: ExchangeDate.string(now), facts: sorted)
            try BinisoftExchange.write(file.encoded(), to: url)          // atomar: temp + rename
            changed = true
        }
        let days = BinisoftExchange.daysFolder(appFolder: appFolder)
        let names = (try? manager.contentsOfDirectory(atPath: days.path)) ?? []
        for name in BinisoftExchange.expiredDayFiles(names, today: today) {
            try? manager.removeItem(at: days.appendingPathComponent(name))
            changed = true
        }
        return changed
    }
}
```

App-Schicht (nicht auf der Watch):

```swift
#if !os(watchOS)
import Foundation
#if os(macOS)
import Security
#endif

enum ThaliaExchange {
    static let appName = "Finn"
    static let source = BinisoftExchange.sourceID(appName)   // "finn"

    /// <Group>/Finn – nil ohne App Group (unsignierter Build) und am Mac ohne Entitlement. Abseits des Main-Threads.
    static func appFolder() -> URL? {
        #if os(macOS)
        guard hasAppGroupEntitlement() else { return nil }
        #endif
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BinisoftExchange.appGroup)
        else { return nil }
        return root.appendingPathComponent(appName, isDirectory: true)
    }

    /// Thalias Katalog; nil, solange Thalia ihn auf diesem Gerät nicht geschrieben hat.
    static func catalog() -> ExchangeCatalog? {
        guard let folder = appFolder() else { return nil }
        let thalia = folder.deletingLastPathComponent().appendingPathComponent("Thalia", isDirectory: true)
        let url = BinisoftExchange.exchangeFolder(appFolder: thalia).appendingPathComponent(BinisoftExchange.catalogFileName)
        guard let data = try? Data(contentsOf: url), case .success(let catalog) = ExchangeReader.catalog(data) else { return nil }
        return catalog
    }

    /// Nach dem Schreiben: Thalia darf sofort nachsehen.
    static func postChanged() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(BinisoftExchange.changedNotification as CFString), nil, nil, true)
    }

    #if os(macOS)
    /// Hat die signierte App die Gruppe? Abseits des Main-Threads, nicht beim Start.
    static func hasAppGroupEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        return (value as? [String])?.contains(BinisoftExchange.appGroup) ?? false
    }
    #endif
}
#endif
```

Anstoßen (entprellt, etwa 2 s): nach jedem eigenen Speichern, beim Wechsel in den Vordergrund, beim Tageswechsel
(`.NSCalendarDayChanged`) und nach dem eigenen CloudKit-Import (`import CoreData`):

```swift
NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                                       queue: .main) { note in
    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event,
          event.type == .import, event.endDate != nil else { return }
    scheduleThaliaSync()
}
// scheduleThaliaSync(): die Tatsachen der letzten 62 Tage aus dem Speicher bauen (reine Werte), dann abseits des
// Main-Threads: ThaliaExchange.appFolder() → ThaliaExchangeWriter.sync(…, today: ExchangeDate.day(Date())) →
// bei Änderung postChanged(); source.json nach §6. Nicht im Demo-Modus, nicht in der Vorschau, nicht auf der Watch.
```

## 10. Tests

Logik (Tatsachen bauen, Dateien abgleichen) gehört ins Core-Paket, das unter Linux getestet wird; App-Group-Pfad,
Darwin-Benachrichtigung und Entitlement-Prüfung in die App-Schicht. Tests (Swift Testing oder wie im Repo üblich):

1. Tatsachen aus neutralen Beispieldatensätzen: richtige `kind`, `id` stabil (zweimal gebaut = gleich), `ref` und
   `refTitle`, `origin` `"app"`, `at` als `JJJJ-MM-TTTHH:MM:SS+HH:MM` (oder `…Z`) ohne Bruchteile.
2. Tag nach Zeitzone: ein Ereignis um `2026-11-22T23:30:00Z` gehört in `Europe/Vienna` zum `2026-11-23`.
3. Schreiben und zurücklesen: `ExchangeReader.dayFile(data, folder: "Finn", fileName: "2026-11-22.json")` ist
   erfolgreich und `skipped` leer; `ExchangeReader.source(data, folder: "Finn")` ebenso.
4. Abgleich in einem temporären Ordner: unveränderte Tatsachen → Datei unverändert (gleiche Bytes, gleiches
   `generatedAt`); eine entfernte Tatsache → Datei ohne sie; Tag ohne Tatsachen und ohne Datei → keine Datei; Tag mit
   Datei und jetzt ohne Tatsachen → `"facts":[]`; `BinisoftExchange.expiredDayFiles(["2026-09-20.json",
   "2026-09-21.json", "2026-11-22.json", ".x.json"], today: "2026-11-22")` ist `["2026-09-20.json"]` und genau diese
   Datei wird gelöscht.
5. Die Testdateien unten lesen sich (Tagesdatei, source.json, Katalog), und die eigene Ausgabe für denselben Inhalt
   hat dieselbe Form.
6. Keine Health-Werte: aus Apple Health stammende Datensätze ergeben keine Tatsache.
7. Werden ids mit FNV-1a gebildet (`ExchangeHash.hex`): `""` → `cbf29ce484222325`, `"a"` → `af63dc4c8601ec8c`,
   `"foobar"` → `85944171f73967e8`.
8. Finn:
   - **Schalter je Zeile:** alles aus → keine Tatsachen und `refs` leer; jede Gruppe, Vermögen, Sparquote und jedes
     Konto bzw. jede Kontogruppe einzeln an und aus; eine eingeschaltete Gruppe mit drei Ausgaben an einem Tag → eine
     `spending`-Tatsache mit der Summe in EUR, eine ausgeschaltete Gruppe am selben Tag → keine; Einnahmen und
     Umbuchungen zählen nicht; Buchungen, Konten und Vermögen der geteilten Haushaltszone ergeben nie eine Tatsache.
   - **Vermögen je Änderungstag:** drei Tage mit Änderung und einer ohne → drei Tatsachen `nw-JJJJ-MM-TT` mit dem Stand
     am Tagesende, der Tag ohne Änderung keine; nie eine Tatsache `nw-JJJJ-MM`.
   - **Sparquote:** an → eine Tatsache `sr-JJJJ-MM` nur in der Datei des Monatsletzten, der laufende Monat erst, wenn er
     vorbei ist.
   - **Konto ein/aus:** ein Konto an → je Änderungstag `kb-<Konto>-<Tag>` mit `metric` `account_balance`, `ref` =
     Konto-id und `refTitle` = Kontoname, das Konto in `refs` mit `"kind":"account"`; eine Kontogruppe → die Summe
     ihrer Konten; wieder aus → die betroffenen Tage ohne diese Tatsachen neu geschrieben und das Konto nicht mehr in
     `refs`.
   - **Auswahl synchronisiert:** die Schalter kommen aus dem synchronisierten Datensatz (§2), nicht aus
     `UserDefaults`; zwei Geräte mit demselben Speicher bauen dieselben Tatsachen.
   - **Katalog mit und ohne `source`:** der Katalog unten → die Hinweise aus §7 („→ Thalia: Ergebnis „Vermögen“
     (Ziel 8)“, „→ Thalia: Messwert „Ausgaben“ (alle Gruppen)“, „noch nicht in Thalia verknüpft“); derselbe Katalog
     ohne die Felder `source` → Vermögen, Sparquote und Konten „Thalia auf diesem Gerät aktualisieren – dann steht
     hier, wofür der Wert zählt“, die Gruppen weiter über `measures[].link`; kein Katalog → „Thalias Katalog fehlt auf
     diesem Gerät – Thalia hier einmal öffnen.“

Testdaten bleiben neutral wie diese (keine echten Namen, Beträge, Gewichte, Ziele). Testdateien aus Thalias Repo
(Ordner wie in der App Group):

`Finn/exchange/source.json` – zwei Gruppen, ein Konto und eine Kontogruppe (`"kind":"account"`).

```json
{
  "v": 1,
  "source": "finn",
  "app": "Finn",
  "appVersion": "1.0",
  "generatedAt": "2026-11-22T20:00:00Z",
  "refs": [
    { "id": "grp-lebensmittel", "title": "Lebensmittel", "kind": "group" },
    { "id": "grp-freizeit", "title": "Freizeit", "kind": "group" },
    { "id": "acc-giro", "title": "Girokonto", "kind": "account" },
    { "id": "accgrp-sparen", "title": "Sparen", "kind": "account" }
  ]
}
```

`Finn/exchange/days/2026-11-22.json` – ein Tag mit Änderungen: zwei Gruppen mit Tagessumme (eine ohne `at`), das Vermögen am Tagesende (`nw-2026-11-22`) und der Stand eines Kontos und einer Kontogruppe (`kb-acc-giro-2026-11-22`, `kb-accgrp-sparen-2026-11-22`).

```json
{
  "v": 1,
  "source": "finn",
  "day": "2026-11-22",
  "generatedAt": "2026-11-22T20:00:00Z",
  "facts": [
    { "id": "sp-grp-lebensmittel-2026-11-22", "kind": "spending", "ref": "grp-lebensmittel", "refTitle": "Lebensmittel", "title": "Lebensmittel",
      "value": 23.4, "currency": "EUR", "at": "2026-11-22T17:45:00+01:00", "origin": "app" },
    { "id": "sp-grp-freizeit-2026-11-22", "kind": "spending", "ref": "grp-freizeit", "refTitle": "Freizeit", "title": "Freizeit",
      "value": 12, "currency": "EUR", "origin": "app" },
    { "id": "nw-2026-11-22", "kind": "value", "ref": "net_worth", "refTitle": "Vermögen", "metric": "net_worth", "value": 52000,
      "currency": "EUR", "origin": "app" },
    { "id": "kb-acc-giro-2026-11-22", "kind": "value", "ref": "acc-giro", "refTitle": "Girokonto", "metric": "account_balance",
      "value": 1234.5, "currency": "EUR", "origin": "app" },
    { "id": "kb-accgrp-sparen-2026-11-22", "kind": "value", "ref": "accgrp-sparen", "refTitle": "Sparen", "metric": "account_balance",
      "value": 8000, "currency": "EUR", "origin": "app" }
  ]
}
```

`Finn/exchange/days/2026-10-31.json` – ein Monatsletzter: das Vermögen, die Sparquote des Monats (`sr-2026-10`) und der Stand des Girokontos.

```json
{
  "v": 1,
  "source": "finn",
  "day": "2026-10-31",
  "generatedAt": "2026-10-31T21:30:00Z",
  "facts": [
    { "id": "nw-2026-10-31", "kind": "value", "ref": "net_worth", "refTitle": "Vermögen", "metric": "net_worth", "value": 51000,
      "currency": "EUR", "origin": "app" },
    { "id": "sr-2026-10", "kind": "value", "ref": "savings_rate", "refTitle": "Sparquote", "metric": "savings_rate", "value": 18.5,
      "unit": "%", "origin": "app" },
    { "id": "kb-acc-giro-2026-10-31", "kind": "value", "ref": "acc-giro", "refTitle": "Girokonto", "metric": "account_balance",
      "value": 980, "currency": "EUR", "origin": "app" }
  ]
}
```

`Thalia/exchange/catalog.json` – Thalias Katalog (§7) – nur Struktur; ab Thalia 1.10.0 mit `results[].source`. Für Finn: „Vermögen“ und „Puffer Girokonto“ zählen Werte aus Finn, „Ausgaben“ alle Ausgaben-Gruppen (die Hinweise dazu in §7).

```json
{
  "v": 1,
  "source": "thalia",
  "generatedAt": "2026-11-22T06:00:00+01:00",
  "week": "2026-W47",
  "segment": { "id": "seg-2", "title": "Abschnitt 2" },
  "goals": [
    { "key": "1", "title": "Gesundheit" },
    { "key": "3", "title": "Arbeit" },
    { "key": "5", "title": "Lesen" },
    { "key": "8", "title": "Finanzen" }
  ],
  "categories": [
    { "key": "1.2", "goal": "1", "title": "Sport / Verein", "segment": "seg-2" },
    { "key": "3.2", "goal": "3", "title": "Kunden", "segment": "seg-2" },
    { "key": "5", "goal": "5", "title": "Lesen", "segment": "seg-2" },
    { "key": "8.1", "goal": "8", "title": "Ausgaben", "segment": "seg-2" }
  ],
  "measures": [
    { "code": "workouts", "title": "Workouts", "unit": "Stück", "link": "app:george:workout=tpl-1", "category": "1.2" },
    { "code": "kunden_aufgaben", "title": "Aufgaben Kunden", "unit": "Stück", "link": "app:theo:task", "category": "3.2" },
    { "code": "seiten", "title": "Seiten", "unit": "Seiten", "link": "list:buch", "category": "5" },
    { "code": "ausgaben", "title": "Ausgaben", "unit": "€", "link": "app:finn:spending", "category": "8.1" }
  ],
  "results": [
    { "id": "res-web", "title": "Website online", "kind": "check", "goal": "3" },
    { "id": "res-books", "title": "Bücher gelesen", "kind": "count", "goal": "5", "source": "list:buch" },
    { "id": "res-worth", "title": "Vermögen", "kind": "value", "goal": "8", "source": "app:finn:net_worth" },
    { "id": "res-giro", "title": "Puffer Girokonto", "kind": "value", "goal": "8", "source": "app:finn:account_balance=acc-giro" }
  ]
}
```

## 11. Regeln

- **Keine CloudKit-Schemaänderung** in Finn: neue Einstellungen als JSON in einem vorhandenen Einstellungs-Datensatz;
  ein neues Feld oder eine neue Datensatzart nur nach Rückfrage bei Bini (das braucht „Deploy Schema Changes“).
- **Schalter synchronisiert:** die Auswahl, welche Zeilen an Thalia gehen, liegt im synchronisierten
  Einstellungs-Datensatz (§2), nie in `UserDefaults` – jedes Gerät schreibt dieselben Tagesdateien.
- **Jede Zeile einzeln, Standard aus;** Vermögen nur `aus` / `bei jeder Änderung`, kein „monatlich“.
- **Keine Werte aus Apple Health** (§4, Herkunft).
- **Öffentliches Repo:** keine persönlichen Daten in Code, Tests, Testdateien oder Doku – keine echten Namen, Beträge,
  Gewichte oder Ziele; neutrale Beispiele wie „Arbeit/Kunden“, „Push“, „Lesen“.
- Nie aus Demo- oder In-Memory-Speichern schreiben, nie auf der Watch.
- Bestehendes Verhalten von Finn bleibt, wie es ist. Deutsche Texte kurz und schlicht, z. B. in den Einstellungen
  ein Abschnitt „Thalia“ mit den Schaltern aus §2 (je Zeile, darunter „→ Thalia: …“ nach §7), „Zuletzt geschrieben: …“
  und dem Hinweis „Thalia übernimmt die Werte, sobald Thalia auf diesem Gerät geöffnet wird.“

## 12. Bericht

Am Ende kurz: was gebaut ist und wo (Dateien), Version, Tests und Prüfungen; die Bundle-IDs, die die App Group
`group.at.binisoft.shared` brauchen; welche `refs` `source.json` liefert (Art und Anzahl, keine Inhalte); was Bini
tun muss (z. B. Schalter einschalten, Zuordnung wählen); offene Fragen.
````

### 3.5 Weitere Apps (allgemein)

`<App>` und `<quelle>` dürfen stehen bleiben – die Session legt beide fest und nennt sie im Plan.

````markdown
# Auftrag: <App> liefert Thalia Daten (Binisoft-Austausch, Format v1)

Dieser Auftrag ist vollständig – alles Nötige steht hier, kein anderes Repo muss gelesen werden. Arbeite in diesem Repo
(<App>) nach dem Binisoft-Handbuch und den Regeln des Repos (HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST): zuerst ein
kurzer Plan in `docs/`, die Logik im Core-Paket mit Tests unter Linux, lokale Prüfung vor dem Push, Version erhöhen,
am Ende ein Bericht (§12). Bei Unklarem: fragen, nicht raten.

## 1. Worum es geht

Thalia ist Binis Planer für Wochenpläne und Jahresziele (ebenfalls eine Binisoft-App). Ab Thalia 1.9.0 können andere
Binisoft-Apps Thalia automatisch Tatsachen liefern: erledigte Aufgaben, Power-Hours, Workouts, Tageswerte, Ausgaben.
<App> schreibt dafür kleine JSON-Dateien in die gemeinsame App Group. Thalia liest sie auf demselben Gerät, legt sie
in ihren eigenen iCloud-Eingang und **rechnet** daraus Werte – Thalia legt dafür nie eigene Einträge an, und Binis eigene
Einträge in Thalia gewinnen immer. <App> liest von Thalia nur einen Katalog mit Thalias Struktur (§7). Keine App
ändert die Daten der anderen; es gibt kein Netz, keinen Server, keine Berechtigungsabfrage.

## 2. Was <App> liefert

In diesem allgemeinen Auftrag steht `<App>` für den Anzeigenamen der App (zugleich ihr Ordnername in der App Group)
und `<quelle>` für ihre Quellen-id (der Name klein, nur `a–z`, `0–9`, `-`). Vor dem Bau beide festlegen und im Plan
nennen.

- Wähle die Arten, die zur App passen (Tabelle in §4): `task.done`, `workout.done`, `habit.done`, `ph`, `value` (nur
  Kennzahlen der Tabelle) oder `spending`. Passt keine, nichts erfinden, sondern im Bericht vorschlagen.
- Je Art: eine Tatsache je Ereignis (bei `value` und `spending` gern die Tagessumme), `id` aus der synchronisierten id
  des Datensatzes mit einem Präfix je Art, `ref` = die Gruppe, Vorlage oder Kennzahl, auf die sich die Tatsache bezieht.
- Hat die App Gruppen, deren Aufgaben oder Power-Hours zu Thalias Kategorien passen: die Auswahl „Thalia-Kategorie“
  (§7). Gezählte Dinge wie Workouts oder Gewohnheiten brauchen sie nicht – Bini wählt sie in Thalia über `ref`.
- `source.json` → `refs`: alles, was Bini in Thalia auswählen können soll, mit passendem `kind`.
- Einstellungen: Abschnitt „Thalia“ mit dem Schalter „An Thalia liefern“; bei Geld oder anderen heiklen Werten jede
  Zeile mit eigenem Schalter und Standard aus (wie Finn). Die Auswahl liegt in einem synchronisierten
  Einstellungs-Datensatz, nicht in `UserDefaults` – sonst schreiben zwei Geräte verschiedene Fassungen derselben Tage.
- Nur Daten, die in der App selbst erfasst wurden – nichts aus Apple Health, nichts aus geteilten Bereichen anderer
  Personen.

Was Thalia daraus macht: Werte für Messwerte mit der Quelle `app:<quelle>:<art|kennzahl>[=<ref>]`
(z. B. `app:<quelle>:workout=<ref>`, `app:<quelle>:task`, `app:<quelle>:kcal`), abgeleitete Haken für verknüpfte Punkte,
Arbeitsblöcke „aus <App>“ für `ph`, Ausgaben „aus <App>“ für `spending`, Ergebnisse der Jahresziele mit der Quelle
`app:<quelle>:…`. Thalia 1.9.0 kennt jede Quelle, die diesem Format folgt – an Thalia muss dafür nichts geändert
werden.

## 3. Weg und Ordner

- App Group **`group.at.binisoft.shared`** (alle Binisoft-Apps haben sie). Laut Handbuch §6 liegen dort nur kleine
  Ereignisse und Zusammenfassungen, nie die Daten der App selbst.
- Ordner von <App>: `<Group>/<App>/exchange/` – der Ordnername ist der Anzeigename „<App>“, genau wie
  `AppGroupFolder.url(appName: "<App>")` aus BinisoftKit (ohne BinisoftKit:
  `FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.at.binisoft.shared")?
  .appendingPathComponent("<App>")`; am Mac beides erst nach der Entitlement-Prüfung, §8). Darin:
  - `source.json` – Herzschlag und Verzeichnis der stabilen ids (§6)
  - `days/JJJJ-MM-TT.json` – eine Datei je Tag (§4, §5)
- <App> schreibt **nur** in seinen eigenen Ordner. Thalia schreibt nur `<Group>/Thalia/exchange/catalog.json`;
  <App> liest ihn nur.
- Die App Group ist ein Ordner **auf einem Gerät**. Thalia sieht nur Dateien, die auf demselben Gerät geschrieben wurden.
  Darum schreibt <App> auf **jedem iPhone, iPad und Mac**, auf dem es läuft – immer aus dem eigenen synchronisierten
  Speicher, so dass jedes Gerät denselben Inhalt schreibt. Thalia legt jede Tagesdatei in ihren iCloud-Eingang; ab da
  sehen alle Geräte mit Thalia die Werte.
- **Nie auf der Apple Watch** – dort weder lesen noch schreiben (`#if !os(watchOS)`). Was auf der Watch erfasst wird,
  kommt über den Sync von <App> auf iPhone/iPad/Mac und von dort in die Tagesdatei.
- **Nur aus dem echten Speicher** – nie aus Demo-, Screenshot-, Vorschau-, Test- oder In-Memory-Speichern (z. B. beim
  Start mit `-Demo`): Beispieldaten dürfen nie bei Thalia ankommen.

## 4. Tagesdatei – Format v1

Beispiel (eine Tagesdatei von Theo):

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"}]}
```

Felder der Datei (alle Pflicht):

| Feld | Inhalt |
|---|---|
| `v` | `1` (Zahl). Thalia liest Version 1 und höher; kleiner als 1 wird abgelehnt. |
| `source` | Quellen-id: der Ordnername klein, nur `a–z`, `0–9`, `-` – hier `"<quelle>"`. Passt sie nicht zum Ordner, lehnt Thalia die Datei ab. |
| `day` | `"JJJJ-MM-TT"`, ein echter Kalendertag; muss zum Dateinamen passen (`days/2026-11-22.json`), sonst abgelehnt. |
| `generatedAt` | Zeitpunkt des Schreibens (Datumsform unten). Hat Thalia für Quelle und Tag schon eine Fassung, gewinnt die mit dem neueren `generatedAt`. |
| `facts` | Liste der Tatsachen des Tages (darf leer sein: `[]`). |

Felder einer Tatsache:

| Feld | | Inhalt |
|---|---|---|
| `id` | Pflicht | Stabil und auf allen Geräten gleich, in der Datei eindeutig. Aus der **synchronisierten** id des Datensatzes (z. B. sein UUID-Feld) – nie `persistentModelID` oder `NSManagedObjectID` (je Gerät verschieden). Präfix je Art, z. B. `"task-…"`. |
| `kind` | Pflicht | Art, siehe unten. |
| `origin` | Pflicht | `"app"` = in <App> selbst erfasst, `"health"` = aus Apple Health. Ohne `origin` (oder mit anderem Wert) verwendet Thalia die Tatsache nicht. |
| `ref` | empfohlen | Stabile id in der Quelle, auf die sich die Tatsache bezieht: Gruppe, Workout-Vorlage, Kennzahl, Konto. Über `ref` ordnet Bini in Thalia zu. |
| `refTitle` | empfohlen | Anzeigename von `ref` („Arbeit/Kunden“). |
| `title` | optional | Titel der Sache („Rechnung schreiben“); Thalia zeigt ihn an. |
| `value` | je nach Art | JSON-Zahl mit Punkt (`1.5`), keine Zeichenkette. |
| `unit` | optional | `"PH"`, `"min"`, `"kcal"`, `"g"`, `"ml"` … |
| `metric` | bei `value` | Kennzahl aus der Tabelle unten. |
| `currency` | bei Geld | ISO 4217, `"EUR"`. |
| `at` | empfohlen | Zeitpunkt des Ereignisses (Datumsform unten). |
| `thalia` | optional | Was in <App> aus Thalias Katalog gewählt wurde: `{"category":"3.2","categoryTitle":"Kunden"}` (§7). `measure` und `result` sind für später reserviert – weglassen. |

Kein Verweis auf Thalias Wochen-Punkte (deren Codes gelten nur eine Woche). Unbekannte Felder liest Thalia nicht,
stören aber nicht.

Arten (v1) und was Thalia damit tut:

| `kind` | Bedeutung | Felder | In Thalia |
|---|---|---|---|
| `task.done` | eine erledigte Aufgabe | `ref` = Gruppe | zählt für Messwerte `app:<quelle>:task` (Aufgaben, deren Kategorie die des Messwerts ist) und `app:<quelle>:task=<ref>` (Aufgaben dieser Gruppe) |
| `workout.done` | ein abgeschlossenes Workout | `ref` = Vorlage | zählt für `app:<quelle>:workout` (alle) und `app:<quelle>:workout=<ref>` |
| `habit.done` | eine erledigte Gewohnheit | `ref` = Gewohnheit | zählt für `app:<quelle>:habit[=<ref>]` |
| `ph` | Power-Hours (1 PH = 50 konzentrierte Minuten) | `value` in PH mit `unit` `"PH"`; mit `unit` `"min"` ist `value` in Minuten (Thalia teilt durch 50); `ref` = Gruppe | ein Arbeitsblock „aus <App>“ in der Kategorie aus `thalia.category`, sonst aus Thalias Zuordnung, sonst „ohne Zuordnung“; Summe für `app:<quelle>:ph[=<ref>]` |
| `value` | Kennzahl eines Tages | `metric`, `value` | Tageswert für `app:<quelle>:<metric>[=<ref>]` – bei `agg: sum` die Summe der Tatsachen des Tages, bei `agg: last` die letzte nach `at` (ohne `at` davor, in Dateireihenfolge) |
| `spending` | Ausgaben einer Gruppe an dem Tag (Tagessumme) | `value` (positiv), `currency`, `ref` = Gruppe | Summe für `app:<quelle>:spending[=<ref>]` |

Bei gezählten Arten (`*.done`) zählt jede Tatsache als 1; `value` wird dort nicht gelesen. Unbekannte Arten und
Kennzahlen behält Thalia und zeigt sie als „nicht verwendet“ – kein Fehler, aber keine Wirkung. Neue Arten nicht
erfinden, sondern im Bericht vorschlagen.

Kennzahlen für `value` (Tabelle v1 – sie wächst nur; eine neue Kennzahl behalten ältere Thalia-Versionen als „nicht
verwendet“):

| `metric` | `agg` | Einheit | Name |
|---|---|---|---|
| `kcal` | sum | kcal | Kalorien |
| `protein_g` | sum | g | Protein |
| `carbs_g` | sum | g | Kohlenhydrate |
| `fat_g` | sum | g | Fett |
| `water_ml` | sum | ml | Wasser |
| `net_worth` | last | € | Vermögen |
| `savings_rate` | last | % | Sparquote |
| `body_weight_kg` | last | kg | Gewicht |
| `account_balance` | last | € | Kontostand (ab Thalia 1.10.0) |

`account_balance` ist der Stand eines Kontos oder einer Kontogruppe am Ende des Tages: `ref` = id des Kontos bzw. der
Gruppe, `refTitle` = ihr Name, eine Tatsache je Konto. Thalia liest ihn nur für ein bestimmtes Konto
(`app:<quelle>:account_balance=<ref>`). Bei allen anderen Kennzahlen ist `ref` die Kennzahl selbst (`"kcal"`).

**Herkunft:** Thalias Eingang liegt in iCloud, und Gesundheitsdaten dürfen nicht nach iCloud (App Review Richtlinie
5.1.3(ii)). Darum schreibt <App> **keine Werte, die aus Apple Health stammen**. Nur wenn sich ein Wert gar nicht
anders trennen lässt, als eigene Tatsache mit `"origin":"health"` – Thalia verwirft solche Tatsachen, bevor sie
gespeichert werden.

**Datum:** ISO 8601 mit Zeitzone, **ohne Sekundenbruchteile**: `"2026-11-22T18:04:00+01:00"` (UTC: `"…Z"`). Thalia
liest auch Bruchteile, `+0100` und `Z`. Der **Tag** einer Tatsache ist der Kalendertag des Ereignisses in der Zeitzone
des Geräts (erledigt am, Ende des Workouts, Datum des Eintrags). Keine Tage in der Zukunft.

## 5. Schreiben – Regeln

1. **Eine Datei je Tag, immer vollständig** aus dem eigenen synchronisierten Speicher: alle Tatsachen des Tages, auch
   die auf einem anderen Gerät erfassten, die per Sync angekommen sind – nie nur „was auf diesem Gerät passiert ist“.
2. **Fehlt eine Tatsache** in einer vorhandenen Tagesdatei, ist sie für Thalia entfernt. Eine **fehlende Datei** heißt
   „keine Information“ (Thalia behält, was sie hat). Darum: Ein Tag, der eine Datei hatte und jetzt nichts mehr hat,
   bekommt `"facts":[]`; für Tage, die nie etwas hatten, keine Datei.
3. **Neu schreiben**, sobald sich an einem Tag etwas ändert, auch rückwirkend (ein geändertes Datum: beide Tage) –
   nach jedem eigenen Speichern (entprellt, etwa 2 s), **direkt nach dem eigenen CloudKit-Import**
   (`NSPersistentCloudKitContainer.eventChangedNotification`, `event.type == .import`, `endDate != nil`), beim Wechsel
   in den Vordergrund und beim Tageswechsel. Der einfachste sichere Weg: bei jedem Anlass alle Tage der letzten 62 Tage
   aus dem Speicher bauen und nur die geänderten schreiben (§9).
4. **Nur schreiben, wenn sich die Tatsachen geändert haben** (Vergleich ohne `generatedAt`); sonst bleibt die Datei, wie
   sie ist. Tatsachen in fester Reihenfolge (nach `at`, dann `id`), damit jedes Gerät denselben Inhalt erzeugt.
5. **Atomar:** in eine temporäre Datei im selben Ordner schreiben, dann umbenennen (`Data.write(to:options: .atomic)` tut
   das). Ordner bei Bedarf anlegen. Thalia liest nur Dateien `JJJJ-MM-TT.json` und überspringt Dotfiles und Temp-Dateien.
6. **JSON** in UTF-8, kompakt, Schlüssel sortiert, Schrägstriche nicht maskiert (`JSONEncoder` mit `.sortedKeys` und
   `.withoutEscapingSlashes`).
7. Danach – einmal je Schreibvorgang – die **Darwin-Benachrichtigung `at.binisoft.exchange.changed`** senden. Sie ist nur
   ein Hinweis: Thalia liest auch beim Start, im Vordergrund, alle 5 Minuten, solange sie offen ist, und nach ihrem
   eigenen iCloud-Import.
8. **Aufräumen:** Tagesdateien, die älter als 62 Tage sind (heute − Tag > 62), löscht <App> selbst. Thalia behält ihre
   Kopie im Eingang.
9. Das Schreiben verzögert nie den Start oder das Speichern (abseits des Main-Threads, entprellt) und zeigt nie einen
   Fehler – Probleme nur ins Log.
10. Was Bini in <App> ausschaltet, zählt wie nicht vorhanden: Der normale Abgleich schreibt die betroffenen Tage ohne
    diese Tatsachen neu, und Thalia nimmt sie für diese Tage heraus.

## 6. source.json

```json
{
  "v": 1,
  "source": "theo",
  "app": "Theo",
  "appVersion": "2.4.0",
  "generatedAt": "2026-11-22T18:04:05+01:00",
  "refs": [
    { "id": "grp-91AB", "title": "Arbeit/Kunden", "kind": "group" },
    { "id": "grp-22CD", "title": "Haushalt", "kind": "group" }
  ]
}
```

- Felder: `v` (1), `source` (wie in den Tagesdateien), `app` (Anzeigename „<App>“), `appVersion`, `generatedAt`,
  `refs` = alle stabilen ids, die Bini in Thalia auswählen können soll, je ein Objekt mit `id`, `title` und `kind`.
- `kind` eines refs: `"group"` (Gruppe von Aufgaben, Power-Hours oder Ausgaben), `"workout"` (Workout-Vorlage),
  `"habit"`, `"account"` (Konto oder Kontogruppe, ab Thalia 1.10.0), `"metric"` (Kennzahl). Thalias Editoren bieten
  unter „Verbundene App → Art → Eintrag“ die passenden an: Workouts → `workout`, Aufgaben/Power-Hours/Ausgaben →
  `group`, Gewohnheiten → `habit`, Kontostand → `account`; ein ref ohne `kind` passt zu allem. Andere Kennzahlen haben
  kein „Eintrag“ (der `ref` ihrer Tatsachen ist die Kennzahl selbst) – ein ref mit `"kind":"metric"` schadet nicht,
  Thalia bietet ihn aber nirgends an.
- Schreiben: sofort, wenn sich `refs` oder die App-Version ändern, sonst höchstens einmal am Tag (Herzschlag – Thalia
  zeigt daraus „zuletzt gesehen“). Atomar, danach die Darwin-Benachrichtigung. `source` muss zum Ordner passen.

## 7. Thalias Katalog und „Thalia-Kategorie“

Thalia schreibt `<Group>/Thalia/exchange/catalog.json` (solange „Thalia-Katalog bereitstellen“ an ist, Standard), nur
wenn sich die Struktur ändert. **Nur Struktur** – keine Werte, kein Fortschritt. <App> liest ihn nur, tolerant:
unbekannte Felder ignorieren; die Datei kann fehlen (Thalia war auf diesem Gerät noch nicht offen, oder der Katalog
ist aus).

| Feld | Inhalt |
|---|---|
| `v`, `source`, `generatedAt` | `1`, `"thalia"`, Zeitpunkt |
| `week` | die Woche, aus der die Messwerte stammen (`"2026-W47"`) |
| `segment` | aktueller Abschnitt der Jahresziele: `{"id":"seg-2","title":"Abschnitt 2"}` |
| `goals` | `[{"key":"3","title":"Arbeit"}]` |
| `categories` | `[{"key":"3.2","goal":"3","title":"Kunden","segment":"seg-2"}]` – `key` ist Text („1.1“, „5“) |
| `measures` | Messwerte der Woche, je mit `code`, `title`, `unit`, `link` (die Quelle des Messwerts, z. B. `"app:george:workout=tpl-1"`) und `category` |
| `results` | Ergebnisse der Jahresziele, je mit `id`, `title`, `kind` (`check` / `count` / `value`), `goal` und – ab Thalia 1.10.0 – `source`: woher der Wert kommt (`"app:finn:net_worth"`, `"app:finn:account_balance=acc-giro"`, `"list:buch"`); fehlt bei Ergebnissen mit eigenen Einträgen und in Katalogen von Thalia vor 1.10.0 |

Ein vollständiges Beispiel steht bei den Testdateien (§10).

**Auswahl „Thalia-Kategorie“** (ob <App> sie braucht, steht hier: nur für Gruppen, deren Aufgaben oder Power-Hours zu Thalias Kategorien gehören (§2)):

- Zeilen „3.2 Kunden“, gruppiert nach Ziel („3 Arbeit“), oben „Keine“; auf iPhone, iPad und Mac gleich.
- Die Wahl wird je Gruppe als JSON in einem **vorhandenen, synchronisierten Einstellungs-Datensatz** von <App>
  gespeichert, z. B. unter dem Schlüssel `thalia.mapping`:
  `{"v":1,"groups":{"grp-91AB":{"category":"3.2","categoryTitle":"Kunden"}}}` – unbekannte Felder beim Speichern
  behalten. Synchronisiert, damit jedes Gerät dieselben Tagesdateien schreibt (nicht in `UserDefaults`). So braucht
  <App> keine CloudKit-Schemaänderung; gibt es keinen solchen Datensatz, vorher bei Bini nachfragen.
- Jede Tatsache einer zugeordneten Gruppe bekommt `"thalia":{"category":"3.2","categoryTitle":"Kunden"}`. Eine geänderte
  Zuordnung schreibt die betroffenen Tage neu (der 62-Tage-Abgleich erledigt das).
- Fehlt der Katalog: die gespeicherte Wahl zeigen und darunter „Thalias Katalog fehlt auf diesem Gerät – Thalia hier
  einmal öffnen.“ Fehlt die gewählte Kategorie im Katalog oder heißt sie dort anders als `categoryTitle`: „Zuordnung
  prüfen“.
- Thalia nimmt `thalia.category` vor ihrer eigenen Zuordnung (Einstellungen → Verbundene Apps); eine Kategorie, die
  Thalia nicht (mehr) hat, übergeht sie. Es reicht, wenn eine Tatsache der Gruppe am Tag die Kategorie trägt – besser
  tragen sie alle. Ohne Kategorie steht die Tatsache in Thalia unter „Ohne Zuordnung“, bis Bini sie dort zuordnet.

## 8. App Group und Entitlement

- Jedes Ziel, das schreibt – iPhone/iPad-App und Mac-App –, hat in seinen Entitlements unter
  `com.apple.security.application-groups` die Gruppe `group.at.binisoft.shared` (im Binisoft-Template über
  `$(SHARED_APP_GROUP)`, in der Info.plist `SharedAppGroup`). Widgets und Watch schreiben nicht – dort nichts ändern.
- Im Apple-Developer-Portal muss die Gruppe den App IDs zugewiesen sein. Das prüft Bini; nenne im Bericht die
  Bundle-IDs, denen die Gruppe zugewiesen sein muss.
- **Am Mac** zur Laufzeit prüfen, ob die signierte App die Gruppe wirklich hat (`SecTaskCopyValueForEntitlement`, §9) –
  abseits des Main-Threads und nicht während des Starts. Ohne das Entitlement kann macOS sonst nach Zugriff auf Daten
  anderer Apps fragen. Auf iPhone/iPad liefert `containerURL(forSecurityApplicationGroupIdentifier:)` ohne Gruppe `nil`
  → nichts tun. Unsignierte CI-Builds: nichts tun.

## 9. Referenzcode

Thalias Referenz für das Format ist eine einzige Datei, nur Foundation, Swift 5 und 6, zum unveränderten Kopieren
(z. B. ins Core-Paket von <App>; die Typen sind `public`):
https://github.com/Binisoft-at/thalia/blob/main/Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift
– Testdateien: https://github.com/Binisoft-at/thalia/tree/main/Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange
(öffentlich auf `main`). **Stand Thalia 1.10.0:** die Datei hat nur Zusätze bekommen – die Kennzahl `account_balance`,
das Katalog-Feld `results[].source` und toleranteres Lesen (eine Zahl, die nicht endlich ist oder dem Betrag nach ab
10¹², gilt als fehlend; ein unlesbares `v` gilt als 1). Wer sie schon aus Thalia 1.9.0 kopiert hat, ersetzt sie durch
die neue Fassung; eigener Code, der sie benutzt, bleibt gültig. Die Datei enthält `BinisoftExchange` (Pfade,
Dateinamen, Aufräumen,
atomares Schreiben, Kodieren), `ExchangeOrigin`, `ExchangeKind`, `ExchangeMetric.table`, `ExchangeFact`,
`ExchangeDayFile`, `ExchangeRef`, `ExchangeSourceInfo`, `ExchangeCatalog`, `ExchangeReader` (tolerantes Lesen mit
deutschen Gründen), `ExchangeDate` und `ExchangeHash` (FNV-1a 64 Bit). Ist sie nicht erreichbar, nach §4–§8 selbst
schreiben – diese Beschreibung ist verbindlich. Die Skizze unten nutzt die Typen dieser Datei.

Schreiber im Core (nur Foundation, unter Linux mit einem temporären Ordner testbar):

```swift
import Foundation

/// Schreibt die Tagesdateien (Format v1) nach `appFolder` = <Group>/<App>.
public enum ThaliaExchangeWriter {
    /// `facts`: alle Tatsachen der letzten 62 Tage aus dem eigenen synchronisierten Speicher, nach Tag ("2026-11-22").
    /// Schreibt nur Tage, deren Tatsachen sich geändert haben, und räumt alte Dateien auf. true = etwas geändert.
    @discardableResult
    public static func sync(_ facts: [String: [ExchangeFact]], source: String, appFolder: URL, today: String,
                            now: Date = Date()) throws -> Bool {
        let manager = FileManager.default
        var changed = false
        for offset in 0...BinisoftExchange.keepDays {
            guard let day = BinisoftExchange.day(today, adding: -offset) else { continue }
            let url = BinisoftExchange.dayFileURL(appFolder: appFolder, day: day)
            let sorted = (facts[day] ?? []).sorted { ($0.at ?? "", $0.id) < ($1.at ?? "", $1.id) }
            let old = try? Data(contentsOf: url)
            if old == nil && sorted.isEmpty { continue }                 // nie eine Datei für einen Tag ohne alles
            if let old, case .success(let read) = ExchangeReader.dayFile(old),
               let same = try? ExchangeDayFile(source: source, day: day, generatedAt: read.file.generatedAt,
                                               facts: sorted).encoded(),
               same == old { continue }                                  // unverändert: generatedAt bleibt
            let file = ExchangeDayFile(source: source, day: day, generatedAt: ExchangeDate.string(now), facts: sorted)
            try BinisoftExchange.write(file.encoded(), to: url)          // atomar: temp + rename
            changed = true
        }
        let days = BinisoftExchange.daysFolder(appFolder: appFolder)
        let names = (try? manager.contentsOfDirectory(atPath: days.path)) ?? []
        for name in BinisoftExchange.expiredDayFiles(names, today: today) {
            try? manager.removeItem(at: days.appendingPathComponent(name))
            changed = true
        }
        return changed
    }
}
```

App-Schicht (nicht auf der Watch):

```swift
#if !os(watchOS)
import Foundation
#if os(macOS)
import Security
#endif

enum ThaliaExchange {
    static let appName = "<App>"
    static let source = BinisoftExchange.sourceID(appName)   // "<quelle>"

    /// <Group>/<App> – nil ohne App Group (unsignierter Build) und am Mac ohne Entitlement. Abseits des Main-Threads.
    static func appFolder() -> URL? {
        #if os(macOS)
        guard hasAppGroupEntitlement() else { return nil }
        #endif
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: BinisoftExchange.appGroup)
        else { return nil }
        return root.appendingPathComponent(appName, isDirectory: true)
    }

    /// Thalias Katalog; nil, solange Thalia ihn auf diesem Gerät nicht geschrieben hat.
    static func catalog() -> ExchangeCatalog? {
        guard let folder = appFolder() else { return nil }
        let thalia = folder.deletingLastPathComponent().appendingPathComponent("Thalia", isDirectory: true)
        let url = BinisoftExchange.exchangeFolder(appFolder: thalia).appendingPathComponent(BinisoftExchange.catalogFileName)
        guard let data = try? Data(contentsOf: url), case .success(let catalog) = ExchangeReader.catalog(data) else { return nil }
        return catalog
    }

    /// Nach dem Schreiben: Thalia darf sofort nachsehen.
    static func postChanged() {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(BinisoftExchange.changedNotification as CFString), nil, nil, true)
    }

    #if os(macOS)
    /// Hat die signierte App die Gruppe? Abseits des Main-Threads, nicht beim Start.
    static func hasAppGroupEntitlement() -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        return (value as? [String])?.contains(BinisoftExchange.appGroup) ?? false
    }
    #endif
}
#endif
```

Anstoßen (entprellt, etwa 2 s): nach jedem eigenen Speichern, beim Wechsel in den Vordergrund, beim Tageswechsel
(`.NSCalendarDayChanged`) und nach dem eigenen CloudKit-Import (`import CoreData`):

```swift
NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil,
                                       queue: .main) { note in
    guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
            as? NSPersistentCloudKitContainer.Event,
          event.type == .import, event.endDate != nil else { return }
    scheduleThaliaSync()
}
// scheduleThaliaSync(): die Tatsachen der letzten 62 Tage aus dem Speicher bauen (reine Werte), dann abseits des
// Main-Threads: ThaliaExchange.appFolder() → ThaliaExchangeWriter.sync(…, today: ExchangeDate.day(Date())) →
// bei Änderung postChanged(); source.json nach §6. Nicht im Demo-Modus, nicht in der Vorschau, nicht auf der Watch.
```

## 10. Tests

Logik (Tatsachen bauen, Dateien abgleichen) gehört ins Core-Paket, das unter Linux getestet wird; App-Group-Pfad,
Darwin-Benachrichtigung und Entitlement-Prüfung in die App-Schicht. Tests (Swift Testing oder wie im Repo üblich):

1. Tatsachen aus neutralen Beispieldatensätzen: richtige `kind`, `id` stabil (zweimal gebaut = gleich), `ref` und
   `refTitle`, `origin` `"app"`, `at` als `JJJJ-MM-TTTHH:MM:SS+HH:MM` (oder `…Z`) ohne Bruchteile.
2. Tag nach Zeitzone: ein Ereignis um `2026-11-22T23:30:00Z` gehört in `Europe/Vienna` zum `2026-11-23`.
3. Schreiben und zurücklesen: `ExchangeReader.dayFile(data, folder: "<App>", fileName: "2026-11-22.json")` ist
   erfolgreich und `skipped` leer; `ExchangeReader.source(data, folder: "<App>")` ebenso.
4. Abgleich in einem temporären Ordner: unveränderte Tatsachen → Datei unverändert (gleiche Bytes, gleiches
   `generatedAt`); eine entfernte Tatsache → Datei ohne sie; Tag ohne Tatsachen und ohne Datei → keine Datei; Tag mit
   Datei und jetzt ohne Tatsachen → `"facts":[]`; `BinisoftExchange.expiredDayFiles(["2026-09-20.json",
   "2026-09-21.json", "2026-11-22.json", ".x.json"], today: "2026-11-22")` ist `["2026-09-20.json"]` und genau diese
   Datei wird gelöscht.
5. Die Testdateien unten lesen sich (Tagesdatei, source.json, Katalog), und die eigene Ausgabe für denselben Inhalt
   hat dieselbe Form.
6. Keine Health-Werte: aus Apple Health stammende Datensätze ergeben keine Tatsache.
7. Werden ids mit FNV-1a gebildet (`ExchangeHash.hex`): `""` → `cbf29ce484222325`, `"a"` → `af63dc4c8601ec8c`,
   `"foobar"` → `85944171f73967e8`.
8. Je gewählter Art: eine geänderte, eine gelöschte und eine auf einem anderen Gerät erfasste Sache landen richtig in
   den Tagesdateien; ausgeschaltete Kennzahlen ergeben keine Tatsache.

Testdaten bleiben neutral wie diese (keine echten Namen, Beträge, Gewichte, Ziele). Testdateien aus Thalias Repo
(Ordner wie in der App Group):

`Theo/exchange/days/2026-11-22.json` – Beispiel einer Quelle mit Aufgaben und Power-Hours.

```json
{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[
  {"id":"task-6F1A2C","kind":"task.done","ref":"grp-91AB","refTitle":"Arbeit/Kunden","title":"Rechnung schreiben",
   "at":"2026-11-22T18:04:00+01:00","origin":"app","thalia":{"category":"3.2","categoryTitle":"Kunden"}},
  {"id":"ph-77C0","kind":"ph","ref":"grp-91AB","refTitle":"Arbeit/Kunden","value":1.5,"unit":"PH","origin":"app"},
  {"id":"task-0B3E11","kind":"task.done","ref":"grp-22CD","refTitle":"Haushalt","title":"Keller aufräumen",
   "at":"2026-11-22T10:30:00+01:00","origin":"app"},
  {"id":"ph-81D2","kind":"ph","ref":"grp-22CD","refTitle":"Haushalt","title":"Ablage","value":0.5,"unit":"PH","origin":"app"}]}
```

`Theo/exchange/source.json`

```json
{
  "v": 1,
  "source": "theo",
  "app": "Theo",
  "appVersion": "2.4.0",
  "generatedAt": "2026-11-22T18:04:05+01:00",
  "refs": [
    { "id": "grp-91AB", "title": "Arbeit/Kunden", "kind": "group" },
    { "id": "grp-22CD", "title": "Haushalt", "kind": "group" }
  ]
}
```

`George/exchange/days/2026-11-22.json` – Beispiel mit gezählten Tatsachen; `wo-HK01` (`origin: "health"`) zeigt, was Thalia verwirft.

```json
{
  "v": 1,
  "source": "george",
  "day": "2026-11-22",
  "generatedAt": "2026-11-22T19:30:00+01:00",
  "facts": [
    { "id": "wo-5A10", "kind": "workout.done", "ref": "tpl-1", "refTitle": "Push", "title": "Push",
      "at": "2026-11-22T07:40:00+01:00", "origin": "app" },
    { "id": "wo-5A11", "kind": "workout.done", "ref": "tpl-2", "refTitle": "Pull", "title": "Pull",
      "at": "2026-11-22T17:10:00+01:00", "origin": "app" },
    { "id": "wo-HK01", "kind": "workout.done", "ref": "tpl-1", "refTitle": "Push", "title": "Laufen aus Apple Health",
      "at": "2026-11-22T12:00:00+01:00", "origin": "health" }
  ]
}
```

`Thalia/exchange/catalog.json` – Thalias Katalog (§7) – nur Struktur; ab Thalia 1.10.0 mit `results[].source`.

```json
{
  "v": 1,
  "source": "thalia",
  "generatedAt": "2026-11-22T06:00:00+01:00",
  "week": "2026-W47",
  "segment": { "id": "seg-2", "title": "Abschnitt 2" },
  "goals": [
    { "key": "1", "title": "Gesundheit" },
    { "key": "3", "title": "Arbeit" },
    { "key": "5", "title": "Lesen" },
    { "key": "8", "title": "Finanzen" }
  ],
  "categories": [
    { "key": "1.2", "goal": "1", "title": "Sport / Verein", "segment": "seg-2" },
    { "key": "3.2", "goal": "3", "title": "Kunden", "segment": "seg-2" },
    { "key": "5", "goal": "5", "title": "Lesen", "segment": "seg-2" },
    { "key": "8.1", "goal": "8", "title": "Ausgaben", "segment": "seg-2" }
  ],
  "measures": [
    { "code": "workouts", "title": "Workouts", "unit": "Stück", "link": "app:george:workout=tpl-1", "category": "1.2" },
    { "code": "kunden_aufgaben", "title": "Aufgaben Kunden", "unit": "Stück", "link": "app:theo:task", "category": "3.2" },
    { "code": "seiten", "title": "Seiten", "unit": "Seiten", "link": "list:buch", "category": "5" },
    { "code": "ausgaben", "title": "Ausgaben", "unit": "€", "link": "app:finn:spending", "category": "8.1" }
  ],
  "results": [
    { "id": "res-web", "title": "Website online", "kind": "check", "goal": "3" },
    { "id": "res-books", "title": "Bücher gelesen", "kind": "count", "goal": "5", "source": "list:buch" },
    { "id": "res-worth", "title": "Vermögen", "kind": "value", "goal": "8", "source": "app:finn:net_worth" },
    { "id": "res-giro", "title": "Puffer Girokonto", "kind": "value", "goal": "8", "source": "app:finn:account_balance=acc-giro" }
  ]
}
```

## 11. Regeln

- **Keine CloudKit-Schemaänderung** in <App>: neue Einstellungen als JSON in einem vorhandenen Einstellungs-Datensatz;
  ein neues Feld oder eine neue Datensatzart nur nach Rückfrage bei Bini (das braucht „Deploy Schema Changes“).
- **Keine Werte aus Apple Health** (§4, Herkunft).
- **Öffentliches Repo:** keine persönlichen Daten in Code, Tests, Testdateien oder Doku – keine echten Namen, Beträge,
  Gewichte oder Ziele; neutrale Beispiele wie „Arbeit/Kunden“, „Push“, „Lesen“.
- Nie aus Demo- oder In-Memory-Speichern schreiben, nie auf der Watch.
- Bestehendes Verhalten von <App> bleibt, wie es ist. Deutsche Texte kurz und schlicht, z. B. in den Einstellungen
  ein Abschnitt „Thalia“ mit den Schaltern aus §2, „Zuletzt geschrieben: …“ und dem Hinweis „Thalia übernimmt die
  Werte, sobald Thalia auf diesem Gerät geöffnet wird.“

## 12. Bericht

Am Ende kurz: was gebaut ist und wo (Dateien), Version, Tests und Prüfungen; die Bundle-IDs, die die App Group
`group.at.binisoft.shared` brauchen; welche `refs` `source.json` liefert (Art und Anzahl, keine Inhalte); was Bini
tun muss (z. B. Schalter einschalten, Zuordnung wählen); offene Fragen.
````

## 4. Für Entwickler: was wo liegt

| Teil | Datei |
|---|---|
| Format v1 zum Kopieren (nur Foundation, Swift 5 und 6): `BinisoftExchange`, `ExchangeFact`, `ExchangeDayFile`, `ExchangeSourceInfo`, `ExchangeCatalog` (ab 1.10.0 `ResultEntry.source`), `ExchangeMetric.table` (ab 1.10.0 mit `account_balance`), `ExchangeReader`, `ExchangeDate`, `ExchangeHash` | `Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift` |
| Thalias Seite: `AppSource` (`app:<quelle>:<art\|kennzahl>[=<ref>]`; ab 1.10.0 `resultOnlyKinds`, `requiresRef`, `refChoices` mit `account`), `LinkRule`, `ExchangeInbox` (`x.<quelle>.<Tag>`, `x.sources`), `ExchangeDerivation` (Wirkung auf eine Woche, berechnet), `ExchangeOverview` („Verbundene Apps“, „Was kommt an“ mit dem Konto eines Kontostands), `ExchangeCatalog.thalia` (füllt `source`), `ExchangeFact.powerHoursValue` | `Packages/ThaliaCore/Sources/ThaliaCore/Exchange.swift` |
| Testdateien, angeordnet wie die App Group: `<App>/exchange/source.json`, `<App>/exchange/days/JJJJ-MM-TT.json`, `Thalia/exchange/catalog.json`, `invalid/`; `Demo/` ist die Quelle von `-Demo` und der Übungsseite | `Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange/` (mit `README.md`) |
| Tests (B6 Format, B7 Wirkung, B8 Quellen, B9 `Measures.merged`, Demo = Testdateien) | `Packages/ThaliaCore/Tests/ThaliaCoreTests/V10Tests.swift` |
| Tests ab 1.10.0 (C1 Zahlen, C4 PH in Minuten, C15 Finn: Kontostand, Ergebnis-Quellen, Katalog mit und ohne `source`, Finn-Testdateien und Katalog = was der Encoder schreibt) | `Packages/ThaliaCore/Tests/ThaliaCoreTests/V11Tests.swift` |
| Lesen der App Group, Katalog schreiben, Auslöser (`ExchangeFolders`, `ExchangeMonitor`, Mac-Entitlement), nicht auf der Watch | `Shared/ExchangeInboxReader.swift` |
| Eingang speichern (Health-Tatsachen vorher entfernt), Zuordnungen, Übersicht, „Übernehmen“, Katalog-Schalter | `Shared/TrackerStore+Records.swift` (`storeInbox`, `mapGroup`, `exchangeSummaries`, `exchangeArrivals`, `adoptWork`, `providesCatalog`) |
| Einmischen in die Woche (abgeleitete Werte, Blöcke, Haken; eigenes gewinnt) | `Shared/WeekContext.swift` über `WeekExtras.compute` (`Packages/ThaliaCore/Sources/ThaliaCore/WeekExtras.swift`) |

Öffentliche Adressen für die anderen Apps (auf `main`):
https://github.com/Binisoft-at/thalia/blob/main/Packages/ThaliaCore/Sources/ThaliaCore/ExchangeFormat.swift und
https://github.com/Binisoft-at/thalia/tree/main/Packages/ThaliaCore/Tests/ThaliaCoreTests/Fixtures/exchange.

**Thalia 1.10.0 – `ExchangeFormat.swift` hat sich nur additiv geändert** (Format bleibt v1): die Kennzahl
`account_balance` in `ExchangeMetric.table` (Kontostand je Konto, `agg: last`, €), das Katalog-Feld
`ExchangeCatalog.ResultEntry.source` (nur geschrieben, wenn nicht leer; tolerant gelesen – fehlt es, ist es leer oder
kein Text, gilt nil) und toleranteres Lesen (`ExchangeRead.number`: nicht endliche Zahlen und Beträge ab 10¹² gelten als
fehlend; `v` über `ExchangeRead.version`, ein unlesbares `v` gilt als 1). Apps, die die Datei kopiert haben, holen die
neue Fassung – die Aufträge oben sagen es (§9). Ältere Thalia-Versionen behalten `account_balance`-Tatsachen als „nicht
verwendet“ im Eingang; ein Katalog ohne `source` stört niemanden (Finn zeigt dann „Thalia auf diesem Gerät
aktualisieren …“).

Ändert sich das Format, steigt `v`; Thalia liest jede Version ab 1 und übergeht unbekannte Arten, Kennzahlen und Felder.
Eine neue Art oder Kennzahl kommt zuerst in `ExchangeFormat.swift` (Tabelle) und die Testdateien, dann in die Aufträge
oben.

## 5. Offene Fragen

1. **„Über 8,0“ – Entschieden (23. Nov. 2026): ab 8,00, gerundet auf zwei Stellen** (nicht erst ab 8,01;
   `GoalTrack.threshold`).
2. **Finn – Vermögen – Entschieden (23. Nov. 2026):** bei jeder Änderung, kein „monatlich“. In Finn ist jede Zeile
   einzeln wählbar (jede Ausgaben-Gruppe, Vermögen, Sparquote, Kontostände einzelner Konten und Kontogruppen), Standard
   aus, die Auswahl synchronisiert; Finn zeigt je Zeile, welchen Thalia-Messwert bzw. welches Ergebnis sie speist
   (Auftrag 3.4, TASKS-v11 §1.5).
3. **Darwin-Benachrichtigung am Mac:** ob sie zwischen zwei Mac-Apps in der Sandbox ankommt, ist ungeprüft. Thalia liest
   ohnehin beim Start, im Vordergrund und alle 5 Minuten – ab 1.10.0 am Mac auch, während eine andere App vorn ist
   (der 5-Minuten-Takt läuft, solange Thalia offen ist). Es kann nur etwas länger dauern.
4. **Theo – Power-Hours:** Der Auftrag geht davon aus, dass Theo PH-Einträge je Gruppe hat; sonst liefert Theo nur
   Aufgaben und sagt es im Bericht.
5. **CloudKit-Weg** über `iCloud.at.binisoft.shared` (ohne „dasselbe Gerät“): eigener Plan nach 1.9.0.
