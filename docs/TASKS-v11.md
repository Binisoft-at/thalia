# Thalia v11 (Version 1.10.0, Tour-Version 11) – Prüfung nach 1.9.0, Finn, Health am Mac (TestFlight)

Anlass (23. Nov. 2026): 1.9.0 (57) ist auf TestFlight. Eine Gesamtprüfung (Code, CI-Screenshots von Lauf 37 mit
Demo-Daten, Startprotokolle) hat Befunde ergeben, die je zwei Prüfer gegengelesen haben (stimmt es im Code? lohnt es
sich?). **136 Befunde bleiben** (bestätigt, plausibel oder Frage an Bini; zusammengeführte Doppelte stehen beim
Hauptbefund), **10 sind verworfen** (§5). Wo die Prüfer einen besseren Weg nannten, gilt dieser. Danach haben drei
Prüfer den Plan selbst gegengelesen (KR1 Datensicherheit und Sync, KR2 Texte und Bedienung, KR3 Umsetzbarkeit); ihre
Punkte stehen als **KR1-n, KR2-n, KR3-n** beim Paketpunkt, den sie ändern, oder als eigener Punkt; verworfene stehen in
§5. Dazu Binis Entscheidungen und Wünsche:

1. **„Über 8“ = ab 8,00** – bestätigt (so umgesetzt in `GoalTrack.threshold`).
2. **Schonfrist-Woche** vor einem neuen Abschnitt und **Notiz an einem abgeleiteten Haken** (macht ihn zum eigenen) –
   bestätigt.
3. **Finn:** Vermögen bei **jeder Änderung** (kein „monatlich“); in Finn ist **alles einzeln wählbar**, was an Thalia
   geht (jede Ausgaben-Gruppe, Vermögen, Sparquote, optional Kontostände einzelner Konten/Kontogruppen), und Finn zeigt
   je Zeile, welchen Thalia-Messwert bzw. welches Ergebnis sie speist.
4. **Health am Mac = Variante B:** ein Schalter am iPhone („Health-Werte mit Mac und Watch teilen“) teilt die
   Health-Werte mit Mac und Watch – **nur in der TestFlight-Version**, an einer klar markierten Stelle (eigenes Paket P9,
   Marke `HEALTHSHARE`), vor einem App-Store-Release entfernbar.

**Keine CloudKit-Schemaänderung** (wie v8–v10): neue Daten liegen als JSON in `AppSetting` (`rescore.<Woche>`,
`hshare.<Tag>`, `hshare.state`, `sync.build.<installID>`, `backup.last`) oder als neue JSON-Felder (`list.item` →
`startAt`); neue CSV-Zeilenarten (`sicherung`, `wertung`, `change`). Das Austauschformat bleibt v1 und wächst nur
(Kennzahl `account_balance`, Katalog-Feld `source`). `Shared/Models.swift` wird nicht geändert.

## 0. Grundregeln für v11
1. **Keine Schemaänderung, nur JSON.** Keiner der neuen Schlüssel kommt in `SettingKeys.all` (also nie in die Sicherung,
   in `record`-Zeilen oder die Präfix-Abfragen der Woche); `SettingKeys.week(of:)` liefert für sie nil, ältere Builds
   übergehen sie (`sync.build.` beginnt nicht mit `sync.seen.`, dem einzigen Geräte-Präfix, den 1.9.0 liest). Prüfung:
   `tools/schema-from-models.py Shared/Models.swift HealthValue` vor und nach v11 gleich.
2. **Ältere Builds auf anderen Geräten bleiben heil.** Unbekannte JSON-Felder bleiben beim Speichern erhalten
   (`SettingRecord`), unbekannte CSV-Zeilen liest 1.9.0 als „Nicht gelesen“, unbekannte Kennzahlen behält 1.9.0 als
   „nicht verwendet“ im Eingang. **1.9.0 rechnet anders** (P1.2, P1.3, P1.9, P1.12 nennen den Unterschied) und speichert
   nach jedem Import die Note der letzten 3 abgeschlossenen Wochen neu (AppModel.swift:434, TrackerStore.swift:1583);
   ein 1.9.0-iPhone und ein selbst wertender 1.10.0-Mac würden sich dort bei jedem Abgleich überschreiben. Deshalb werten
   Mac, Watch und iPad erst selbst, wenn alle Geräte der letzten 30 Tage 1.10.0 melden (`sync.build.`, P2.1 (d), KR1-9).
   TESTING v11 beginnt mit „alle Geräte auf 1.10.0“.
3. **Anzeige ist nicht Wertung.** Texte, Rundung, Status und Farben ändern keine gespeicherte Note. Wo sich die Wertung
   ändert (P1.2, P1.3, P1.9, P1.12), wirkt das beim nächsten regulären Neuwerten; eingefrorene Wochen (v10 Grundregel 2)
   bleiben, bis jemand „Neu berechnen“ drückt. STATUS und der Tour-Schritt „Genauer gerechnet“ (P1.19) sagen das.
4. **Wartung ohne Undo, Eingaben mit Undo.** Hintergrundarbeit (Zusammenführen, Neuwertung, Nachtragen, Eingang,
   Geräte-Meldung, Health-Teilen) läuft in `TrackerStore.withoutUndo`; hat sie etwas gelöscht oder vereint, leert sie
   danach den Undo-Stapel (P2.4). Speicherungen in `withoutUndo` gelten als Wartung – Mac, Watch und iPad werten dabei nie
   selbst (P2.1). Jede Nutzeraktion, die etwas entfernt oder ersetzt, hat „Widerrufen“ (so heißt es überall, auch in
   neuen Texten – nicht „Rückgängig“).
5. **Hauptthread schonen.** Keine neuen Vollscans im Body; neue Abfragen mit Prädikat (IN, Präfix) – keine
   Bereichsvergleiche auf Texten (`>=` in `#Predicate` ist im Projekt ungeprüft, P2.13). Zeichenketten (CSV,
   PDF-Seitenfolge) abseits bauen; SwiftData-Lesen bleibt auf dem Hauptkontext (TrackerStore ist `@MainActor`, ein
   zweiter löschender Kontext brächte den 1.6.1-Zusammenführungsfehler zurück).
6. **Health bleibt geschützt.** Health-Werte gehen nie in den Austausch (`x.`), nie in „Sicherung erstellen“, nie in
   `catalog.json`. Das Teilen (§1.4) gibt es nur, wenn das Tor `.allowed` ist (Debug/TestFlight), und nur in Paket P9
   (Core-Datensätze `HealthShare.swift` und Tour-Schritt baut P1 vorab, ebenso markiert): jede Stelle, die
   `HealthShareGate`, `HealthShare.*`, `healthShareCovers`, `sharedHealthSuggestion` oder einen `hshare.`-Schlüssel
   benutzt, trägt den Kommentar `// HEALTHSHARE` (höchstens drei Zeilen darüber, KR3-8). Ein App-Store-Build löscht alle
   `hshare.`-Datensätze.
7. **Nie** `Vendor/BinisoftKit` oder `scripts/ci` ändern. Öffentliches Repo: keine echten Namen, Beträge, Gewichte,
   Ziele in Code, Tests, Fixtures, Doku – Beispiele neutral.
8. **Jeder Befund steht genau einmal** in diesem Plan (als Paketpunkt mit Lösung, Dateien und Abnahme, in §4, in §2.11
   „Später“ oder in §5). Andere Stellen verweisen mit der Punktnummer („→ P2.1“). Braucht ein Punkt eine Datei eines
   anderen Pakets, steht das in §2.10 „Zuarbeit“: der Besitzer der Datei setzt es in seiner Runde nach dem Vertrag §2.1 um.
9. **Schnittstellen wachsen nur, Vertragscommit zuerst** (KR3-4, KR3-5). Runden 1–3 ändern bestehende Signaturen nur
   additiv (Überladung oder Standardwert): `isHealthElsewhere(_:)` bleibt neben `(_:on:)`, `ThaliaTour.catalog` bleibt
   (= `catalog(healthShare: false)`), `restoreMarks(_:day:)` (AppModel.swift:586, :617) bleibt neben der neuen Fassung,
   `firstFour`/`lastFour` behalten ihre Namen. Alte Namen entfernt der Besitzer der Aufrufer, wenn keiner sie mehr nutzt.
   Jede Runde beginnt mit den **Vertragscommits** aus §2.1: wer für ein Paket derselben Runde etwas baut, legt es zuerst
   mit Signatur und einfacher, lauffähiger Fassung an; die anderen verzweigen erst danach. So kann die Mac-CI jedes Paket
   für sich prüfen.
10. **Plattformen** (KR3-22). Das Watch-Ziel baut ganz `Shared` mit (project.yml:100-105), die Widget-Erweiterungen nur
    einzelne Dateien (`WidgetBridge`, `AppInfo`, `RouteIntents`, `GoalPalette`, `WidgetActions`): `UIApplication` nur
    hinter `#if os(iOS)` und nie in diesen Dateien; `NSApp` nur macOS; `AppTransaction` gibt es auf allen drei.
    `App/Sources/Intents.swift` wird auch für macOS gebaut – `BackgroundGrace` hat dort eine leere Fassung.

## 1. Entscheidungen

### 1.1 Binis Entscheidungen festhalten
1. „Über 8“ zählt ab 8,00 (gerundet auf zwei Stellen) – aus den offenen Fragen in CONNECTED_APPS §5, TASKS-v10 und
   STATUS in „Entschieden“ (→ P8.1). Die Bezeichnung bleibt bis zur Antwort auf §4 F2 „über 8“ (Binis Begriff aus
   TASKS-v10); Fußnoten und Tour sagen „ab 8,00“ (→ P1.15, P7.8).
2. Schonfrist (die Woche direkt vor einem neuen Abschnitt friert erst nach dessen erster Woche ein) und die Notiz am
   abgeleiteten ✓ (legt die Markierung mit ✓ an) bleiben wie in TASKS-v10 „Lückenschluss“ – jetzt als entschieden
   (→ P8.2).

### 1.2 Wertung und Anzeige
1. **Zeitziele über Mitternacht** werden nur beim Vergleich umgerechnet (bei einem Nacht-Ziel zählen Messwert und
   Grenzen unter 12:00 als +24 h). Nacht-Ziel ist ein Einzelvergleich mit Wert ≥ 12:00 (wie heute) oder < 04:00 (neu),
   ein Bereich nur, wenn **beide** Grenzen ≥ 12:00 oder < 04:00 sind – Tagesfenster wie „10:00–18:00“ rechnen wie heute
   (KR3-3). Gespeichertes (`targetRaw`, Editor) bleibt, ältere Builds lesen denselben Text (→ P1.2).
2. **Verpasste Wochenquote:** der Fehlbetrag bleibt am letzten möglichen Tag gebucht (WORKFLOW-Regel); ist die Woche
   vorbei, bekommt dieser Tag seine Wertung auch mit leeren Punkten – die leeren zählen nicht, der Fehlbetrag schon
   (→ P1.9).
3. **Ergebnis aus der Leseliste** zählt „fertige Einträge der Art ∪ ausdrücklich zugeordnete“ (→ P1.11); ein Buch
   kann mit „Schon gelesen bis Seite“ starten, auch der Fortschrittstext zählt ab dort (→ P1.12).
4. **Ein Tempo-Status** für Wochenziele (`PaceStatus`: erreicht · im Plan · hinter dem Plan · noch offen · nicht
   erreicht; Grenzen weiter „im Rahmen“/„überschritten“) und **eine Farbzuordnung** `StatusTint` für Wochenziele und
   Ergebnisse, nur nach Status, ohne wertabhängige Zwischenfarbe (KR2-5): grün erreicht/eingehalten, Akzent im Plan/auf
   Kurs/im Rahmen, orange hinter dem Plan/im Rückstand/zu schnell/noch offen, rot nicht erreicht/überschritten, grau ohne
   Wert. Ergebnisse sagen „auf Kurs“/„im Rückstand“ (statt „hinten“), Grenz-Ergebnisse „im Rahmen“/„zu schnell“/
   „überschritten“/„eingehalten“ (KR2-13) (→ P1.10, P1.16, P7.2).
5. **Anteilige Wochenziele** werden nur in der Anzeige gerundet, ganze Einheiten in Richtung des Vergleichs (≥ auf, >
   ab, Bereich innen) – ein gezeigter ganzer Wert ist genau dann „erreicht“, wenn der ungerundete es ist (KR3-6);
   `effectiveTarget` und damit alle Noten bleiben (→ P1.7).
6. **Trend** erst ab 4 gewerteten Wochen, Fenster ohne Überlappung (→ P1.17); „je 10 %“ wird „gleich gewichtet“
   (→ P6.3).
7. **Eingefrorene abgeschlossene Wochen** zeigen überall die gespeicherte Note; „Nach heutigem Stand“ nur als zweite
   Zeile (→ P6.1).

### 1.3 Abgeschlossene Wochen neu werten (iPhone, Mac, Watch, iPad, Neuinstallation)
1. **Wer automatisch wertet.** Das iPhone (Geräteart `.phone`, `HealthDevice.scoresHealth`) wertet abgeschlossene, nicht
   eingefrorene Wochen wie heute. Mac, Watch und **iPad** (KR1-16: zwei Geräte mit verschiedenen übernommenen Health-
   Werten überschrieben sich heute nach jedem Import) werten eine solche Woche selbst nur, wenn (a) die Speicherung aus
   eigener Eingabe kommt – nicht aus Wartung wie Eingang, Zusammenführen, Nachtragen, Import (KR1-6) –, (b) die Woche
   keine Health-Werte liest (kein Fortschrittspunkt auf einem `health:`-Messwert) oder geteilte Werte (§1.4) sie
   abdecken, (c) der erste iCloud-Abgleich des Geräts fertig ist (`sync.firstImportDone`) und (d) alle Geräte der letzten
   30 Tage 1.10.0 melden (KR1-9). Jede eigene Wertung schreibt zusätzlich eine Anfrage `rescore.<Woche>`, damit das
   iPhone mit vollem Stand nachrechnet; in allen anderen Fällen schreiben sie nur die Anfrage (→ P2.1).
2. **Anfragen** arbeitet das iPhone nach dem Abgleich ab (höchstens 8 je Lauf). Abschließen am Mac/auf der Watch/am iPad
   speichert die eigene Note und schreibt eine Anfrage mit `force` (der Abschluss ist die erste Wertung, auch in einem
   früheren Abschnitt, KR1-5); „Am iPhone neu berechnen“ ebenso (→ P2.1, P7.1).
3. Vor dem ersten fertigen Abgleich wertet kein Gerät automatisch; eine frische Installation wertet Health-Wochen, die
   vor ihr endeten, nicht neu – auch nicht auf Anfrage (→ P2.2, P3.2).
4. Ein iPad bleibt damit beim gespeicherten Stand der Health-Wochen; ob es selbst werten soll, klärt §4 F1.

### 1.4 Health-Werte mit Mac und Watch teilen (Variante B, nur TestFlight)
Umsetzung: Paket **P9** (Runde 4) – alles an einer Stelle; Core-Datensätze `HealthShare.swift` P1 (Vertrag); Doku
P1.22. Eingearbeitet: KR1-3, KR1-4, KR1-7, KR1-8, KR1-11, KR1-12, KR1-18, KR1-19, KR2-1, KR3-1, KR3-7, KR3-8, KR3-9.
1. **Schalter** (nur Geräte, die Health lesen – iPhone/iPad –, nur bei Tor `.allowed`): Einstellungen → Apple Health,
   eigener Abschnitt ohne Überschrift (der Schalter sagt es), Toggle **„Health-Werte mit Mac und Watch teilen“** (Binis
   Wortlaut), Fuß: „Nur in der TestFlight-Version – Apple erlaubt Gesundheitsdaten in iCloud im App Store nicht.
   Geteilt werden deine übernommenen Health-Werte der letzten 5 Wochen und die Health-Vorschläge der letzten 3 Tage;
   Ausschalten löscht sie wieder aus iCloud.“ Standard **aus**, je Gerät (UserDefaults `thalia.health.share`). Teilt
   schon ein anderes Gerät (`hshare.state` an, `by` ≠ dieses Gerät): Rückfrage „Teilen läuft schon auf einem anderen
   Gerät (iPhone, zuletzt heute 08:12). Hier übernehmen?“ – „Übernehmen“ / „Abbrechen“ (Art und Zeit aus
   `sync.seen.<by>`).
2. **Tor `HealthShareGate`** (Shared, auch Watch) mit drei Zuständen: `.allowed` (Debug; `AppTransaction.shared`
   verifiziert mit `environment` `.sandbox` oder `.xcode`), `.denied` (verifiziert `.production`), `.unknown` (Fehler,
   nicht verifiziert, noch nicht geprüft). Das letzte verifizierte Ergebnis liegt je Gerät in UserDefaults
   (`thalia.health.shareGate`); der Start beginnt damit und prüft im Hintergrund neu; ändert es sich, sendet das Tor
   `HealthShareGate.changed`, App und Watch erhöhen `syncTick` (Ansichten zeichnen neu – ein statischer Wert wird nicht
   beobachtet). **Schreiben und Lesen nur bei `.allowed`; Bereinigung nur bei frisch bestätigtem `.denied`** – ein
   TestFlight-iPhone, das offline startet, löscht nichts. Die Tour wartet höchstens 2 s auf `await
   HealthShareGate.resolve()`, bevor sie die Schritte baut (sonst wäre Tour 11 ohne `health-share` als gesehen markiert).
3. **App-Store-Bereinigung (bleibt dauerhaft im Code):** jedes Gerät mit `.denied` – iPhone, iPad, Mac, Watch – löscht
   beim Start alle Schlüssel mit Präfix `hshare.` (eine Präfix-Abfrage, egal welches `by`) und schreibt `hshare.state`
   aus (mit eigenem `by`). Sobald irgendein Gerät die App-Store-Version hat, endet das Teilen; nichts bleibt verwaist in
   iCloud (neue installID nach Neuinstallation, abgelaufener TestFlight-Build, übersprungene Version – TestFlight und
   App Store schreiben in denselben Produktions-Container).
4. **Daten (keine Schemaänderung):** `hshare.state` =
   `{"v":1,"on":true,"by":"<installID>","from":"2026-10-20","through":"2026-11-23","modifiedAt":"…"}`; je Tag
   `hshare.<JJJJ-MM-TT>` = `{"v":1,"day":"…","by":"…","counted":{"<code>":72.5},"read":{"<code>":72.6},"modifiedAt":"…"}`.
   `counted` = die am iPhone **übernommenen** Health-Werte (`HealthValue`), an allen Tagen des Fensters; `read` = was
   Thalia dort aus Health **gelesen** hat (Vorschläge), **nur heute und die 2 Tage davor** (KR1-18 – nur dafür gebraucht:
   „Health am iPhone: … – dort übernehmen“). Nur Codes der Messwerte mit `health:`-Quelle aus der Woche des Tags.
   **Fenster: heute und die 34 Tage davor** (laufende Woche + 4; deckt Schonfrist und das 3-Wochen-Neuwerten ab).
   `hshare.` steht nicht in `SettingKeys.all`: nie in Sicherung, `record`-Zeilen, Austausch, Katalog; `PlanCSV` lehnt
   `record`-Zeilen mit `hshare.`/`rescore.` ab.
5. **Schreiber** (genau ein Gerät, App-Datei `HealthShareSettings.swift`): `counted` **synchron aus den lokalen
   `HealthValue`** – nach jedem Speichern, das eine `HealthValue` enthält (deckt auch ⌘Z/Schütteln nach `adoptHealth`,
   das mit Undo einfügt, TrackerStore.swift:727-734, KR1-12), und bei jedem Aktivieren für alle 35 Tage; `read` über
   `HealthService.readValues(days:measures:) async` (neu, berührt die beobachteten `values` nicht, KR3-9) beim Aktivieren
   höchstens alle 30 min für die 3 Tage, je Tag mit den Messwerten seiner Woche. Geschrieben wird nur bei Änderung
   (verglichen werden die dekodierten `counted`/`read`, nicht der JSON-Text mit `modifiedAt`), in `withoutUndo`, nie aus
   `-Demo`, Übung, In-Memory. Beim Einschalten zuerst Tag-Datensätze mit anderem `by` löschen, dann Zustand und Fenster
   schreiben. Beim Aktivieren: Zustand fehlt oder ist eigener, aber aus → Zustand und Fenster neu schreiben
   (Selbstheilung); `by` ≠ dieses Gerät (übernommen oder anderswo beendet, auch durch die App-Store-Bereinigung) → eigenen
   Schalter aus, nichts schreiben, Fuß „Teilen wurde auf einem anderen Gerät beendet oder übernommen.“ (KR1-8: zwei
   Schreiber löschten sich gegenseitig die Kopien, TrackerStore+Records.swift:146-160).
6. **Aufräumen (TestFlight):** jedes Gerät mit `.allowed` löscht höchstens einmal am Tag `hshare.<Tag>`, die nach der
   eigenen Uhr älter als 35 Tage sind – iCloud hält so auch ohne laufenden Schreiber nie mehr als das Fenster.
7. **Leser** (jedes Gerät, das nicht der Schreiber ist – Mac, Watch, iPad): WeekReader liest `hshare.state` und die 7
   Tagesschlüssel der Woche; genommen werden nur Tage mit `by == state.by` innerhalb `from…through`, solange der Zustand
   an ist. WeekContext gibt `counted` als Health-Eingabe in `WeekExtras` (genau wie `HealthValue`; eine eigene
   `HealthValue` je Code+Tag geht vor; eigene Einträge gewinnen wie immer über `Measures.merged`). Damit rechnen Mac und
   Watch dieselbe Note wie das iPhone; für abgedeckte Tage ist `isHealthElsewhere` falsch, `countsAsMissing` wie am
   iPhone, und `canScore` erlaubt das Werten abgedeckter Wochen. `weekContext(for:)`, `lastValue`, Messwert- und
   Ergebnis-Reihen lesen dieselben Werte; Berichte und PDFs am Mac zeigen damit nur, was die am iPhone schon zeigen –
   Prompts und Ergebnis-Berichte verbergen Health-Werte weiter (`hidesHealth`, P7.5), die Sicherung enthält sie nie.
8. **Nur lesen** (KR1-7): ein geteilter Wert ist auf Mac und Watch kein Eingabefeld – Anzeige mit „aus Health am
   iPhone“, kein Feld, kein −/+; ein eigener Wert über „Eigenen Wert eintragen…“ (leeres Feld). Die Krone der Watch
   schreibt nur, wenn sie bewegt wurde. `read` ohne `counted`: „Health am iPhone: 72,6 kg – dort übernehmen“ (nur lesen).
   So landet kein geteilter Wert still als eigener Eintrag in iCloud, Sicherung oder Prompt.
9. **Ausschalten:** alle `hshare.<Tag>` über die Präfix-Abfrage löschen (nicht nur die Fensterliste), `hshare.state` →
   `{"on":false,"by":<dieses Gerät>,…}` (Grabstein: Leser übergehen Tag-Datensätze, solange der Zustand aus ist oder
   fehlt). Mac und Watch zeigen wieder den bisherigen Hinweis.
10. **Texte zum Datenschutz:** fünf Stellen sagen heute „nie in iCloud“ bzw. „bleibt auf dem Gerät“ (SettingsView.swift:349
    und :473, Editors.swift:468 und :471, ConnectedApps.swift:1150). Solange das Tor `.allowed` und der Zustand an ist,
    zeigen sie die markierte Fassung (→ P9.4); sonst bleiben sie.
11. **Ältere Builds:** 1.9.0 fragt die Schlüssel nie ab – Verhalten wie heute.
12. **Vor App-Store entfernen – Pflicht vor dem ersten Einreichen eines Builds zum App Store** (KR1-19): kein Build mit
    HEALTHSHARE-Stellen außer der Bereinigung geht in die App-Prüfung – TestFlight und App Store nutzen dieselbe
    hochgeladene Binärdatei, und die App-Prüfung läuft nach Apples Kauf-Doku in der Sandbox (das Tor könnte dort offen
    sein; vor dem ersten Einreichen bestätigen). Solange das Teilen im Build ist, geht er nur an interne
    TestFlight-Tester (externe durchlaufen die Beta-App-Prüfung). Checkliste (auch in TESTING v11 und STATUS):
    (a) `grep -rn HEALTHSHARE` – jede markierte Stelle entfernen: WeekReader-Schlüssel, WeekContext-Eingabe und
    `isHealthElsewhere`-Ausnahme, `sharedHealthSuggestion`, `weekContext(for:)`, `lastValue`, Reihen, `canScore`-Zweig,
    Einstellungs-Abschnitt, Schreiber, `readValues`, Tor-Prüfung beim Start (bis auf die Bereinigung), Tour-Schritt
    `health-share` und `catalog(healthShare:)`, `-DemoScreen health`, `health` in Config/ci.env, Nur-Lesen-Anzeige am Mac
    und auf der Watch, „Health am iPhone: …“, die fünf Datenschutz-Texte, die von P9.3 ergänzten Bedingungen in
    `FrozenWeekNote` (P6.1, P7.1), den Mac-Hinweisen (P6.14) und `loadKey` (P7.11); (b) die Dateien
    `Packages/ThaliaCore/Sources/ThaliaCore/HealthShare.swift`, `Shared/HealthShareStore.swift`,
    `App/Sources/HealthShareSettings.swift` bis auf die **Bereinigung** löschen (Präfix, Löschen aller `hshare.`,
    Zustand aus – bleibt dauerhaft, eine Präfix-Abfrage beim Start); (c) Tests der Core-Datei bis auf Schlüssel- und
    Bereinigungs-Tests löschen; (d) Absätze in TESTING, STATUS, SYNC, TOUR streichen; (e) App-Review-Notiz: keine
    Gesundheitsdaten in iCloud.

### 1.5 Finn: alles einzeln wählbar, Vermögen bei jeder Änderung, Kontostände (Format v1, nur Zusätze)
Umsetzung: Auftrag und Doku P8.3; Core P1 (Vertrag); Editoren P7 (Ergebnis- und Messwert-Quelle liegen in
GoalResults.swift und ConnectedApps.swift).
1. **Was Finn liefert – je Zeile ein Schalter in Finn, Standard aus:** jede Ausgaben-Gruppe einzeln (`spending` wie
   bisher); **Vermögen** `aus` / `bei jeder Änderung` – an jedem Tag, an dem es sich ändert, eine Tatsache mit dem Stand
   am Tagesende, id `nw-<JJJJ-MM-TT>` (kein „monatlich“ mehr; ältere `nw-<JJJJ-MM>` im Eingang bleiben lesbar);
   **Sparquote** `aus` / `an` – je Monat `sr-<JJJJ-MM>` in der Datei des Monatsletzten (der laufende Monat, sobald er
   vorbei ist); **Kontostände** je Konto oder Kontogruppe `aus` / `an` – neue Kennzahl `account_balance` (`agg: last`,
   €, „Kontostand“), `ref` = Konto- bzw. Gruppen-id, `refTitle` = Name, id `kb-<ref>-<JJJJ-MM-TT>`, an jedem Tag mit
   Änderung der Stand am Tagesende; `source.json` → `refs` mit `"kind":"account"`. Nur eigene Konten, nie die
   Haushaltszone.
2. **Schalter synchronisiert:** die Auswahl liegt als JSON in einem vorhandenen, synchronisierten Einstellungs-Datensatz
   von Finn (z. B. `thalia.delivery`), nie in UserDefaults – jedes Gerät schreibt dieselben Tagesdateien (sonst
   schrieben iPhone und Mac abwechselnd verschiedene Fassungen).
3. **Anzeige in Finn:** Einstellungen → „Thalia“ listet jede Zeile mit Schalter und darunter, wofür sie in Thalia
   zählt, aus `catalog.json`: ein Messwert mit passendem `link` (`app:finn:spending=<Gruppe>`, `app:finn:spending` =
   „alle Gruppen“) oder ein Ergebnis mit passendem neuem Feld `source` (`app:finn:net_worth`, `app:finn:savings_rate`,
   `app:finn:account_balance=<Konto>`): „→ Thalia: Ergebnis „Vermögen“ (Ziel 2)“, „→ Thalia: Messwert
   „Ausgaben“ (alle Gruppen)“; sonst „noch nicht in Thalia verknüpft“; Katalog fehlt → „Thalia hier einmal öffnen“;
   Katalog ohne `results[].source` (Thalia vor 1.10) → „Thalia auf diesem Gerät aktualisieren – dann steht hier,
   wofür der Wert zählt“.
4. **Thalia-Seite (Format bleibt v1):** `ExchangeMetric.table` + `account_balance`; `AppSource.refChoices` bietet dafür
   die refs mit `kind` `account` (und ohne kind) an; `AppSource.requiresRef` (wahr für `account_balance`: Ergebnis- und
   Messwert-Editor bieten kein „alle“ – der letzte Wert irgendeines Kontos wäre sinnlos); `ExchangeCatalog.ResultEntry`
   bekommt `source: String?` (nur geschrieben, wenn nicht leer; tolerant gelesen), `ExchangeCatalog.thalia` füllt es;
   „Was kommt an“ zeigt bei Kennzahlen mit ref den Titel („Kontostand 1.234 € · Girokonto“). Vermögen, Sparquote und
   Kontostände sind **Ergebnis-Quellen** (Art „Zielwert“, letzter Wert): neu `AppSource.resultOnlyKinds` (`net_worth`,
   `savings_rate`, `account_balance`; Thalia-eigen in Exchange.swift, nicht in der kopierten ExchangeFormat.swift). Die
   Messwert-Quelle (ConnectedApps.swift:1105-1111, bietet heute alle `AppSource.kindChoices`) bietet sie **nicht** an –
   ein Messwert in € gilt als Ausgabe (`isExpense`, Records.swift:182-183); nur ein vorhandener Messwert mit einer solchen
   Kennzahl bekommt den Hinweis „Für ein Jahresziel-Ergebnis gedacht – ein Messwert in € zählt als Ausgabe.“ (KR2-25).
5. **Ältere Builds:** 1.9.0 behält `account_balance`-Tatsachen als „nicht verwendet“ im Eingang (keine Wirkung, kein
   Verlust); ein Katalog ohne `source` stört Finn nicht (Hinweis oben). `ExchangeFormat.swift` ändert sich nur additiv
   (Tabelle, Katalog-Feld, toleranteres Lesen aus P1.1) – CONNECTED_APPS §4 sagt den anderen Apps, die neue Fassung zu
   holen.

### 1.6 Sicherung
1. Jede volle Sicherung beginnt mit einer Zeile `sicherung` (Datum, Version, Geräteart – nie der Gerätename) (→ P3.6)
   und trägt je abgeschlossener Woche ihre gespeicherte Wertung in voller Genauigkeit (`wertung`, → P3.3) und das
   Zieljahr (`record`, Import füllt nur auf, → P3.7); Archiv-Schnappschüsse tragen ihre Planänderungen (`change`).
2. Eingespielte Kopien werden mit ihren Originalen zusammengeführt (nach `recordID`, in `mergeDuplicates` vor dem
   `importID`-Zusammenführen), und solange der erste iCloud-Abgleich eines Geräts fehlt, warnt der Import (→ P3.2).
3. iPhone und Mac legen wöchentlich selbst eine Sicherung in `Application Support/Sicherungen` ab (ohne Entitlement-
   oder Info.plist-Änderung; Gerätesicherung bzw. Time Machine erfassen sie) – mit **Datum im Namen**, nie überschrieben,
   nur im Modus iCloud/lokal und nach dem ersten Abgleich, kein Aufräumen nach einer auffällig kleinen Datei (KR1-13)
   (→ P3.13). Sichtbarkeit in „Dateien“/iCloud Drive klärt §4 F12.
4. **„Letzte Sicherung“ gilt für alle Geräte** (KR2-2): synchronisierter JSON-Datensatz `backup.last` = `{"at","device"}`
   (nicht in `SettingKeys.all`, nie in der Sicherung); Einstellungen → Deine Daten zeigt „Letzte Sicherung: 22.11.2026
   am iPhone (vor 3 Tagen) · automatisch: 23.11.2026 auf diesem Gerät“; der Wochenabschluss mahnt nur, wenn **kein**
   Gerät seit 30 Tagen von Hand gesichert hat (→ P3.13).
5. **Ein Name** (KR2-17): „Sicherung erstellen…“ überall (Einstellungen, Mac-Ablage, ImportView „Sicherung erstellen
   (alles als CSV)“); Toast „Sicherung gespeichert“; in der Liste „Teilen…“ (→ P3.13, P3.14, P4.9).

### 1.7 Mac
1. Fenster: das Mindestmaß bleibt 900 pt; Inspektoren („Heute im Blick“, „Wochenübersicht“) zeigen sich nur, solange
   sie passen (Detailbreite unabhängig vom Inspektor gemessen, 40 pt Spielraum); die gespeicherte Wahl bleibt. Passt er
   nicht, öffnen ⌘0, Symbolleistenknopf, Tagesring und Seitenleisten-Karte ihn als Blatt (KR2-3) (→ P4.1).
2. Menübefehle, Erinnerungen und Kurzbefehle holen das Hauptfenster nach vorn oder öffnen es (→ P4.2); Wochenbefehle
   folgen dem gezeigten Tag (→ P4.3); Tasten 1–4 wirken ohne Klick, auch nach ⌘1 und dem Aktivieren der App, mit
   sichtbarer Auswahl (→ P5.12); „Jahresziel eintragen…“ ⌥⌘J und „Lesen…“ ⌥⌘L (→ P4.21); ein „Zu heute“ ⌘T (→ P6.15).

### 1.8 Version, Tour, Screenshots
1. `MARKETING_VERSION = 1.10.0`. Tour 11 mit drei Schritten `since: 11`: `backup` („Sicherung“), `rules-11` („Genauer
   gerechnet“ – die Regeln aus P1.2, P1.9, P1.11 und warum sich die letzten drei Wochen einmal ändern können, KR2-6) und
   `health-share` („Health am Mac und auf der Watch“, nur bei Tor `.allowed`) (→ P1.19). „Neu in Thalia“ nach 1.9 hat
   also 2 oder 3 Schritte.
2. CI-Screenshots zusätzlich iPhone `goals`, `review`, `close-week`, `settings`, `backup` und Mac `review`, `settings` –
   eingetragen von P4 in Runde 3b, damit die Abnahmen von Runde 3 sie schon haben (KR3-10); iPhone `health` trägt P9 in
   Runde 4 ein (CI baut Debug, das Tor ist dort offen) (→ P1.21). `backup` und `health` öffnen das `.settings`-Blatt mit
   `SettingsView(initialPage:)`, das per `navigationDestination` die Seite „Sicherungen“ bzw. HealthSettingsView
   (SettingsView.swift:447) zeigt.

## 2. Pakete

### 2.0 Runden und Besitz
Innerhalb einer Runde sind die Dateien der Pakete disjunkt; spätere Runden dürfen Dateien früherer Runden ändern. Jede
Runde beginnt mit den Vertragscommits (§0.9); in Runde 1 wird P1 vor P3 und P8 gemergt. Neun Pakete (eins mehr als
üblich): das Health-Teilen hat ein eigenes, damit es vor dem App Store an einer Stelle herauskommt (KR3-11).

| Runde | Pakete (parallel) | Dateien |
|---|---|---|
| 1 | **P1** Core | `Packages/ThaliaCore/Sources/ThaliaCore/*` außer `PlanCSV.swift`, `ImportPreview.swift`; neu `HealthShare.swift`; Tests (neu `V11Tests.swift`, Anpassungen in `V10Tests`, `CSVTests`, `ScoringTests`, `V7Tests`, `V8Tests`, `CalendarTests`, `SyncDeviceTests`); Fixtures `exchange/Finn/*`, `exchange/Thalia/catalog.json`, Fixtures-`README.md` |
| 1 | **P3** (Core-Teil) | `Packages/ThaliaCore/Sources/ThaliaCore/PlanCSV.swift`, `ImportPreview.swift`; neu `Tests/ThaliaCoreTests/V11BackupTests.swift` |
| 1 | **P8** (Doku-Teil) | `docs/CONNECTED_APPS.md`, `docs/TASKS-v10.md`, `docs/ARCHITECTURE.md`, `docs/WORKFLOW.md`, `docs/SETUP.md`, `docs/HANDBOOK_PROPOSALS.md` (nur Zeile 21), `README.md` |
| 2 | **P2** Shared | `Shared/TrackerStore.swift`, `TrackerStore+Records.swift`, `TrackerStore+Range.swift`, `WeekContext.swift`, `WeekReader.swift`, `ExchangeInboxReader.swift`, `Persistence.swift`, `DemoData.swift` |
| 2 | **P3** (Shared/App-Teil) | `Shared/TrackerStore+Import.swift`; `App/Sources/ImportView.swift`, `PastImport.swift`, neu `App/Sources/Backups.swift`; `docs/IMPORT.md` |
| 3a | **P4** Vertragscommit und Breitenmessung | wie 3b, zuerst |
| 3b | **P4** App-Rahmen, Mac, System | `App/Sources/AppModel.swift`, `RootView.swift`, `ThaliaApp.swift`, `Services.swift`, `MenuBar.swift`, `SettingsView.swift`, `SheetChrome.swift`, `TourView.swift`, `Style.swift`, `AppPlatform.swift`, `LaunchDiagnostics.swift`; neu `BackgroundGrace.swift`; `Config/ci.env` (Bildschirme) |
| 3b | **P5** Heute & Erfassen | `App/Sources/TodayView.swift`, `Glance.swift`, `Focus.swift`, `Expenses.swift`, `Editors.swift`, `CloseDayView.swift` |
| 3b | **P6** Woche, Abschluss, Rückblick, PDF | `App/Sources/WeekView.swift`, `WeekTable.swift`, `Components.swift`, `ArchiveCard.swift`, `CloseWeekView.swift`, `ReviewView.swift`, `Sharing.swift`, `PDFExport.swift`, `RangePDF.swift` |
| 3b | **P7** Ziele, Leseliste, Verbundene Apps | `App/Sources/GoalsView.swift`, `GoalResults.swift`, `ReadingList.swift`, `Segments.swift`, `ConnectedApps.swift`, `Explainers.swift` |
| 3b | **P8** (Code-Teil) | `Watch/Sources/*`, `Widgets/Sources/*`, `WatchWidgets/Sources/*`, `App/Sources/Intents.swift`, `Shared/WidgetPublisher.swift`, `WidgetBridge.swift`, `WidgetActions.swift`, `RouteIntents.swift` |
| 4 | **P9** Health teilen (allein) | neu `Shared/HealthShareStore.swift`, `App/Sources/HealthShareSettings.swift`; die `HEALTHSHARE`-Stellen in `Shared/WeekContext.swift`, `WeekReader.swift`, `TrackerStore.swift`, `TrackerStore+Range.swift`, `App/Sources/AppModel.swift`, `SettingsView.swift`, `Services.swift`, `TodayView.swift`, `Editors.swift`, `ConnectedApps.swift`, `Segments.swift`, `WeekTable.swift`, `GoalResults.swift`, `Watch/Sources/WatchValues.swift`, `ThaliaWatchApp.swift`; Core-Tests `HealthShare`; `Config/ci.env` (`health`) |
| 5 | **P1** Abschluss | alle `docs/*` außer CONNECTED_APPS, `Config/Base.xcconfig`, `README.md`; danach CI und TestFlight |

Prüfungen je Paket: **P1, P3 (Runde 1)** Linux (Docker `swift:6.2-noble`, `swift test`), kein Mac; **P2, P3 (Runde 2),
P9** Harness (Typprüfung + Szenarien in einem eigenen Ordner unter dem Scratchpad, nie im Repo) und **Mac-CI**;
**P4–P8** `swiftc -parse` lokal (WatchWidgets eigens, KR3-25) und **Mac-CI** (Typprüfung, Build, Screenshots);
**Gerät** nötig für P2.1, P2.2, P2.4, P3.2, P3.10, P3.13, P4.1, P4.2, P4.11, P4.12, P4.14, P4.17, P5.12, P6.11,
P8.5–P8.18, P9.1–P9.3 (Details §3.4).

### 2.1 Vertrag (Schnittstellen, die ein Paket für andere baut)
**P1 baut (Runde 1; zuerst, was P3 in Runde 1 braucht):**
- `Format.parse` streng (gleiche Signatur); Grenzen in `Format.number/euro/clock/duration`, `WorkTotals.netText` (→ P1.1)
- `Units.decimals(_:) -> Int`, `Units.dative(_:) -> String`, `Units.singular(_:) -> String`,
  `Format.amount(_ value: Double, unit: String) -> String`, `Format.amount(target: Target, unit: String) -> String`
  (Rundung in Richtung des Vergleichs) (→ P1.6, P1.7, P1.14)
- `Target.isNight: Bool`, `static Target.nightMinutes(_:) -> Double` (→ P1.2); `Target.parse(_:strict: Bool)` neben dem
  unveränderten `Target.parse(_:)` (→ P1.3)
- `WeekKey.rangeLabelWithYear: String` (→ P1.8); `static WeekKey.toClose(on: DayKey, isClosed: (WeekKey) -> Bool,
  hasData: (WeekKey) -> Bool) -> WeekKey` (→ P4.16)
- `enum PaceStatus` (Fälle, `label`, `label(remaining:unit:)`), `Pace.plannedLeft`, `Pace.status`, `Pace.init(…,
  weekOver: Bool)` und `Measures.weeklyPace(…, weekOver:)` mit Standard `today > week.sunday` (→ P1.16)
- `ResultProgress.isLimit` und Labels („im Rahmen“, „zu schnell“, „überschritten“, „eingehalten“, „im Rückstand“)
  (→ P1.10); `GoalResultLine.statusKind: ResultProgress.Status`, `GoalResultLine.init(…, hiddenText: String? = nil)`
  (→ P7.2, P7.5)
- `ListItem.startAt: Double?`, `ListMath.current(_:progress:through:) -> Double`, `progressText` über `current` (→ P1.12)
- `window: Int` in `PeriodReport.GoalLine` und `RangeReport.GoalLine` (Namen `firstFour`/`lastFour` bleiben) (→ P1.17);
  `WeekLine.closedDays` ohne entschuldigte Tage (→ P6.2); Bericht „(gleich gewichtet)“ (→ P6.3)
- `PlanPrompt.text(…, setDays: [DayRecord] = [])` („Schon eingetragen für KWnn: …“) (→ P3.4); Zahlenregel „ohne
  Tausenderpunkt (8000, nicht 8.000)“ in Plan- und Vergangene-Woche-Prompt (Reports.swift:506, :662) (→ P3.1)
- `ReminderSettings.morningRequests(from:count:isSkipped:) -> [DatedRequest]`,
  `weeklyRequests(from:count:isClosed:hasPlan:) -> [DatedRequest]`, `requests()` ohne Wiederholungen (→ P4.17)
- `SyncGerman.isPersistentProblem(mode:account:quotaExceeded:) -> Bool` (→ P4.18)
- `SettingKeys.rescoreRequest = "rescore."`, `struct RescoreRequest: Codable` (`v`, `by`, `at`, `force`);
  `SettingKeys.buildPrefix = "sync.build."`, `struct SyncBuild: Codable` (`v`, `build`, `version`),
  `SyncDevice.firstV11Build`, `static SyncDevice.allCurrent(seen:builds:now:) -> Bool` (30 Tage) (→ P2.1);
  `SettingKeys.backupLast = "backup.last"`, `struct BackupStamp: Codable` (`v`, `at`, `device`) (→ P3.13) – keiner davon
  in `SettingKeys.all`
- `SettingKeys.goalYearKeys` (`goal.start`, `goal.end`, `goal.review`, `goal.motto`), `SettingKeys.catalogSwitch`
  (`exchange.catalog`) (→ P3.7)
- `SettingRecords.decode`: für `goalEntry`/`listProgress` je id die neueste Kopie (Gleichstand: größerer Schlüssel)
  (→ P3.5)
- `HealthShare` (HEALTHSHARE): `prefix = "hshare."`, `stateKey`, `window = 35`, `readDays = 3`, `struct HealthShareDay`,
  `struct HealthShareState` (mit `by` auch bei aus), `key(day:)`, `keys(week:)`, `entries(_ days:state:) ->
  [EntryRecord]` (nur Tage mit `by == state.by` in `from…through`, Notiz „Apple Health“), `read(_:code:day:) -> Double?`,
  `covers(_ day:state:) -> Bool`, `expired(keys:today:) -> [String]` (älter als 35 Tage) (→ P9.1)
- Austausch: `ExchangeMetric.table` + `account_balance`; `AppSource.requiresRef`; `refChoices` für `account`;
  `AppSource.resultOnlyKinds`; `ExchangeCatalog.ResultEntry.source: String?` und Füllen in `ExchangeCatalog.thalia`;
  Ref-Titel in `arrivals`; `ExchangeInbox.value(_:) -> String?`; `extension ExchangeFact { var powerHoursValue:
  Double? }` in Exchange.swift (→ P8.3, P1.1, P1.4)
- `ThaliaTour.version = 11`, `static func catalog(healthShare: Bool)`, `static var catalog` bleibt (→ P1.19); Test
  `TodaySummary.resolved` ohne `nextDay` (→ P8.13)

**P3 baut (Runde 1):** CSV-Zeilen `sicherung`, `wertung` (volle Genauigkeit), `change`; `PlanCSV.number(_:)`;
`PlanCSV.Document.finalScores`, `backupInfo`, `referencedWeeks`; `ImportPreview` `Sendable`.

**P2 baut (Runde 2; zuerst, was P3 in Runde 2 braucht):**
- `withoutUndo(_:)` mit `isMaintenance` (→ P2.4); `commit(rescoring:origin:)` mit `enum SaveOrigin { user, maintenance }`
  (Standard `.user`); `weekReadsHealth(_:)`, `canScore(_:)`, `processRescoreRequests() -> [WeekKey]`,
  `requestRescore(_:force:)`, `allDevicesCurrent(now:)` (→ P2.1); `HealthDevice.scoresHealth`,
  `HealthDevice.installedAt` (→ P2.1, P2.2); `SyncProgress.noteImport(_:)`, `SyncProgress.firstImportDone` (→ P3.2)
- `struct MarkSnapshot`, `setMarks`/`apply(suggestions:)` → `[MarkSnapshot]`, `restoreMarks(_ snapshots:)` neben
  `restoreMarks(_:day:)` (→ P2.5); `restoreConflicts(_:) -> [String]` (Titel) (→ P2.6)
- `TrackerStore.saveFailed` (Notification), `saveQuietly()` (→ P2.9); `mergeDuplicates(since:)` mit
  `mergeImportedCopies()`, `maintenance(today:)` (→ P2.13, P3.2); `WeekReader(week:today:goalYear:content:)` (→ P2.14)
- `resultLines(today:hidesHealth: Bool = true)` (→ P7.5); `struct ClosedWeekSnapshot`, `closedWeekSnapshot(_:)`,
  `restore(_: ClosedWeekSnapshot)` (→ P6.8, P7.1); `recompute(_:)` mit Health-Wächter (→ P7.1)
- `WeekContext.isHealthElsewhere(_:on:)` neben `(_:)` (→ P6.14)

**P3 baut (Runde 2):** `cleanRestoreDuplicates()` (→ P3.2); UserDefaults `restore.window`, `backup.lastAuto`;
`BackupWriter` in `Backups.swift` (`exportText(store:) async -> String`, `writeWeeklyIfDue(store:today:mode:)`,
`files() -> [BackupFile]`, `stamp(store:)` für `backup.last`) (→ P3.11, P3.13); `existingState(weeks:includeRecords:)`
(→ P3.12).

**P4 baut (Runde 3a, ein Commit vor P5–P8):** `AppModel.mainWindowWidth`, `detailWidth`, `fitsGlanceInspector`,
`fitsWeekSummary`, `showDayOverview(_:)`, `showsWeekSummary`, `focusTodayPage`, `reopenWeek(_:)`, `lastSaveError`,
`lastSent`/`lastReceived`, `backupFile`; `BackgroundGrace.holdForExport(after:timeout:)` (iOS; leere macOS-Fassung);
`MainWindow.showWithoutEnvironment()`; in Style.swift `StatusTint` (`PaceStatus` und `ResultProgress.Status` → Farbe);
`PracticeUnavailableView`; `SettingsView(initialPage:)`, `-DemoScreen backup`.

**P9 baut (Runde 4):** nichts für andere Pakete – es ist das letzte Code-Paket.

### P1 – Core (Runde 1; Abschluss in Runde 5)
Prüfung: Linux-Tests (`V11Tests.swift`), keine Mac-CI nötig bis Runde 5. Vertragscommit zuerst (§0.9): was P3 in Runde 1
braucht (`SettingKeys.goalYearKeys`, `catalogSwitch`, strenges `Format.parse` mit alter Signatur), dann der Rest. P1
wird in Runde 1 vor P3 gemergt (§2.0).

- [x] **P1.1 CORE-1** (hoch) Riesige oder ungültige Zahlen lassen Thalia abstürzen (`Int(Double)` in Format,
  WorkTotals, Austausch, CSV). Lösung: (a) `Format.parse` (Format.swift:97-112): nach dem Säubern nur `0-9 . , + -`
  zulassen (weist `nan`, `inf`, Exponent, Hex ab), dann `guard let v = Double(cleaned), v.isFinite, abs(v) < 1e12 else
  { return nil }` – deckt Heute, Ausgaben, Menüleiste, Editoren ab; die „nicht lesbar“-Wege und das Zurücksetzen des
  Heute-Felds (TodayView.swift:1977-1979) behandeln nil schon. (b) `Format.number`, `euro`, `clock`, `duration` und
  `WorkTotals.netText` (Measures.swift:201): `guard value.isFinite, abs(value) < 1e15 else { return "–" }` („– €“) vor
  jeder Int-Umwandlung. (c) `ExchangeRead.number` (ExchangeFormat.swift:682-685): Textzweig
  `.flatMap { $0.isFinite && abs($0) < 1e12 ? $0 : nil }`, dieselbe Grenze im JSON-Zweig; `v` (:326, :390, :503) als
  `ExchangeRead.number(c, .v).flatMap { Int(exactly: $0.rounded()) } ?? BinisoftExchange.version` – nur toleranteres
  Lesen, Ausgabe unverändert. (d) `ExchangeInbox.value(_:)` (Exchange.swift:313-316) → `String?`, nicht kodierbare
  Tatsachen fallen weg, nie `"{}"`; Aufrufer überspringen nil (Zuarbeit P2, P3). (e) Reports.swift:263
  `Int((min(max(ratio, 0), 1) * 100).rounded())`; CSV-Zählspalte (PlanCSV.swift:581) → Zuarbeit P3.
  Abnahme: Tests `Format.number(1e19)`, `euro(1e17)` → „–“; `Format.parse("nan"/"inf"/"12345678901234567890")` == nil;
  Tagesdatei mit `"v":"nan"` und Wert „1e999“ liest sich (Tatsache ohne Wert); `ExchangeInbox.value` einer lesbaren
  Datei ist nie „{}“.
- [x] **P1.2 CORE-3** (mittel) Zeitziele über Mitternacht verkehrt („≤ 00:00“ nie erfüllt, „23:00–00:30“ wird
  00:30–23:00, Mittel 12:00). Lösung nur beim Vergleich (keine Daten- oder `raw`-Änderung, ältere Builds lesen dasselbe):
  `Target.isNight` – Zeitziel und **Einzelvergleich**: Wert ≥ 12:00 (wie heute über `normalizedTime`,
  Vocabulary.swift:217-220) oder < 04:00 (neu); **Bereich**: nur, wenn beide Grenzen ≥ 12:00 oder < 04:00 sind (KR3-3:
  „Wert oder Obergrenze“ machte „10:00–18:00“ zum Nachtfenster – 12:00 und 17:00 ✗, 09:00 und 19:00 ✓; heute rechnet
  es richtig). `Target.nightMinutes(t) = t < 720 ? t + 1440 : t` (Vocabulary.swift); `isMet` bildet bei Nacht-Zielen
  Messwert und Grenzen ab, `.range` sortiert die abgebildeten Grenzen – „23:00–00:30“, das schon vertauscht gespeicherte
  „00:30-23:00“ und ein verkehrt getipptes „23:00-22:30“ heißen alle Abendfenster; `label` zeigt Nachtbereiche
  abgebildet sortiert. `Target.parse` und Editor-Speicher (Editors.swift:1369-1371) bleiben. `Measures.weekValue`
  (Measures.swift:30) mittelt bei Nacht-Zielen über `nightMinutes` (Standardbezug 23:00 bleibt). Behebt nebenbei ein
  CSV-„<=24:00“, das als „<=00:00“ zurückgeschrieben wird. GoalsView-Mittel → Zuarbeit P7. 1.9.0 rechnet „≤ 00:30“ und
  „23:00–00:30“ weiter falsch (§0.2). Abnahme: Tests ≤ 00:00 (23:30 ✓, 00:15 ✗), ≤ 00:30, 23:00–00:30 (23:30 ✓, 00:15 ✓,
  12:00 ✗), Wochenmittel von 23:30 und 00:30 = 00:00; „10:00–18:00“: 12:00 ✓, 09:00 ✗, 19:00 ✗; „11:30–13:00“: 12:00 ✓;
  ≤ 23:00, 22:30–23:00, ≤ 06:30 unverändert.
- [x] **P1.3 CORE-10** (niedrig) „spätestens 23:00“ wird ≥, „bis 23:00“ unlesbar. Lösung (Vocabulary.swift:165-191):
  nur ganze führende Wörter (gefolgt von Leerzeichen, Ziffer oder Ende): „spätestens“, „bis“, „bis zu“, „höchstens“,
  „maximal“, „max“, „nicht mehr als“ → `.atMost`; „weniger als“, „unter“ → `.below`; „frühestens“, „ab“, „mindestens“,
  „min“ → `.atLeast`; „mehr als“, „über“ → `.above`. „bis“ wird nur zwischen zwei Zahlen zu „-“. Beginnt der Text mit
  einem Buchstaben und passt kein bekanntes Wort → nil (vorhandene Warnung „Ziel „…“ nicht lesbar – ignoriert“) – aber
  **nur streng** (KR3-18): neue Überladung `Target.parse(_:strict: Bool)`; streng lesen nur Editoren und die CSV-Prüfung
  (Warnung). `Target.parse(_:)` (gespeicherte Ziele: Core GoalResults.swift:475-476, App GoalResults.swift:91/96/129,
  Messwerte) kennt die neue Wortliste, fällt bei einem unbekannten Wort aber wie heute auf die Zahl zurück – ein altes
  „ca. 10“ verliert sein Ziel nicht still. Einheiten hinten bleiben erlaubt. Ergebnis-Ziele aus `record`-Zeilen speichert
  der Import normalisiert (`Target.parse(text)?.raw`) → Zuarbeit P3. „spätestens 23:00“ zählt in 1.10.0 als ≤, in 1.9.0
  als ≥ (§0.2). Abnahme: Tests „spätestens 23:00“ → ≤ 23:00, „bis 23:00“ → ≤ 23:00, „weniger als 6“ → < 6, „22:30 bis
  23:00“ → Bereich, „≥150 g“ → ≥ 150, „ca 150“ streng → nil, nicht streng → wie in 1.9.0.
- [x] **P1.4 CORE-11** (niedrig) „Was kommt an“ zeigt PH in Minuten als PH („55 PH“). Lösung: Thalia-eigene
  `extension ExchangeFact { var powerHoursValue: Double? }` in Exchange.swift (nicht in `ExchangeFormat.swift`, die
  kopieren die anderen Apps), benutzt in Exchange.swift :157, :656 und `arrivals` :980 („55 min = 1,1 PH“).
  Abnahme: Test ph-Tatsache 55 min → Ankunft 1,1 PH, Woche 1,1 PH.
- [x] **P1.5 PERF-3** (niedrig) Tages-/Wochenschlüssel über `String(format:)`. Lösung: privates `pad(_:_:)` in
  Calendar.swift für `DayKey.string` (:84-87) und `WeekKey.string` (:254), optional `Format.clock` (:55);
  ExchangeFormat.swift:142 bleibt (Kopie der anderen Apps). Abnahme: Test vergleicht alte und neue Ausgabe (Tage
  1999–2100 als Stichprobe, alle Wochen 2026 inkl. W53); alle Tests grün.
- [x] **P1.6 DISPLAY-2** (mittel) PH in Viertelstunden auf eine Stelle gerundet („heute +0,3 PH“). Lösung:
  `Units.decimals(_ unit:)` (ph 2, l 2, kg/h 1, Stk., Seiten, Schritte, min, kcal, g, ml 0; € über `euro`) in
  `Format.measure` (Format.swift:92) – wirkt in Heute, Tag abschließen, PDF, Bericht, Watch, Widgets. Abnahme: Tests
  `Format.measure(0.25, "PH") == "0,25 PH"`, `(12.75, "PH") == "12,75 PH"`, `(6.4, "PH") == "6,4 PH"`; P8 prüft im
  nächsten CI-Lauf, dass Komplikation und Widget-Zeilen „12,75 PH“ fassen.
- [x] **P1.7 DISPLAY-6** (mittel, mit UIPHONE-9) Anteilige Wochenziele mit krummen Stellen („150 von 85,71 Stk.“) und je
  Bildschirm anders. Lösung **nur Anzeige** (kein Aufrunden in `Measures.effectiveTarget` – das änderte gespeicherte
  Noten und brächte Geräte auseinander): `Format.amount(_ value:unit:)` (Wert gerundet nach `Units.decimals`; ph 2,
  kg/h 1) und `Format.amount(target: Target, unit:)` für Ziele (KR3-6 – `effectiveTarget` skaliert alle Vergleiche außer
  Grenzen und Zeiten, Measures.swift:121): bei ganzen Einheiten **in Richtung des Vergleichs** gerundet – ≥ auf, > ab,
  Bereich untere Grenze auf und obere ab, = nach `Units.decimals`; so ist ein gezeigter ganzer Wert genau dann
  „erreicht“, wenn der ungerundete es ist. Bericht `Target.label` (Reports.swift:172-174) über dieselbe Funktion.
  „erreicht“ kommt weiter aus dem ungerundeten Wert. Anzeige-Stellen → Zuarbeit P2, P5, P6, P8. Ergebnis „Ziel 86 statt
  100 Stk. – 1 Tag krank“, „150 von 86 Stk. – erreicht“, „Ziel 103 statt 120 min“. Abnahme: Tests 100 × 6/7 Stk. ≥ →
  „86“, > → „> 85“, Bereich 150–180 g × 6/7 → „129–154 g“; Note der Demo-Woche unverändert; Screenshot `weekly-goals`
  ohne Hundertstel.
- [x] **P1.8 DISPLAY-7** (niedrig) Wochen-PDF KW53: „28. Dez. – 3. Jan. 2026“. Lösung: `WeekKey.rangeLabelWithYear`
  (gleiches Jahr „16.–22. Nov. 2026“, sonst „28. Dez. 2026 – 3. Jan. 2027“, Logik aus `RangePDFWeeks.dateText`), benutzt
  in Reports.swift:412 (Zielüberprüfung); PDF-Stellen → Zuarbeit P6. Abnahme: Tests 2026-W53, 2027-W01, 2026-W47.
- [x] **P1.9 CORE-2** (hoch) Verpasste Wochenquote verschwindet, wenn am Buchungstag ein Punkt leer ist (leerer Sonntag
  hebt 9,05 auf 10). Lösung: Buchung bleibt am letzten möglichen Tag (WORKFLOW, dort zeigt die Oberfläche den
  Fehlbetrag); `Scorer.score` (Scoring.swift:266-272): `entry.score = (entry.isComplete || (data.isComplete &&
  (entry.shortfall > 0 || entry.excused > 0))) ? calculated : nil` – leere Punkte zählen an diesem Tag wie überall
  nicht, der Fehlbetrag schon. Kein eigener Pseudotag (gewichtet falsch). Abnahme: ScoringTests (1) Beispiel des Befunds
  (Punkt „woche:2“ nie gemacht, ein täglicher Punkt immer ✓): Sonntag leer ≤ 9,05, nicht 10; (2) am Sonntag mit Lücken
  abgeschlossene Woche enthält den Fehlbetrag; (3) entschuldigter Anteil behält die ½-Regel. STATUS (P1.22): nicht
  eingefrorene abgeschlossene Wochen können sich beim Neuwerten einmal ändern; 1.9.0 speichert weiter die alte Note –
  solange ein Gerät 1.9.0 hat, werten Mac und Watch nicht selbst (§0.2).
- [x] **P1.10 CORE-5** (mittel) „höchstens“-Zählergebnisse zeigen bei 0 „erreicht“ und nach dem Überschreiten „auf
  Kurs“. Lösung (Core GoalResults.swift:573-595), nur `kind == .count` mit `.atMost`/`.below`: `isLimit = true`; Wert >
  Grenze → `.missed` („überschritten“); Zeitraum vorbei und Wert ≤ Grenze → `.reached` („eingehalten“); laufend: Wert >
  Grenze × verstrichener Anteil × 1,15 → `.behind` („zu schnell“, KR2-13), sonst `.onTrack` („im Rahmen“); nie
  `.reached` vor dem Ende; Text „5 von höchstens 20 Packungen“; Balken = Wert/Grenze. Zählergebnisse ohne Grenze sagen
  bei `.behind` „im Rückstand“ statt „hinten“ (KR2-13; auch Tour ThaliaTour.swift:120-121, Tests; App-Texte →
  Zuarbeit P7). `value`-Ziele („≤ x kg“) unverändert. Farben nur über den Status (`StatusTint`, §1.2.4 – kein
  wertabhängiges Gelb) → Zuarbeit P7. Status wird berechnet, nicht gespeichert. Abnahme: Tests 0, 5, 25 im Zeitraum; 15
  danach; Abschnitts-Ziel mit ≤; Labels „zu schnell“, „im Rückstand“.
- [x] **P1.11 CORE-6** (mittel) „Zählt für“ an einem Buch wirft alle anderen fertigen Bücher aus der Zählung (Ziel 5
  „Hörbücher zählen“). Lösung (Core GoalResults.swift:495-505, `.list(kind)`): zugeordnete ∪ fertige nicht zugeordnete
  der Art (`resultID` nil/leer; Einträge eines anderen Ergebnisses bleiben draußen; Zuordnung auf ein gelöschtes Ergebnis
  gilt als nicht zugeordnet), ohne Doppel nach id. Zählung wird berechnet – 1.9.0 zeigt bis zum Update die alte Zahl.
  Fußtext → Zuarbeit P7; TASKS-v10 §1.2.1 und TESTING (P1.22) nennen die neue Regel; eine Auswahl von Hand geht über eine
  eigene Art („Fachbuch“) und `list:fachbuch`. Abnahme: Test B2 umgeschrieben (Bücher = 2) und 2 Buch + 1 Hörbuch mit
  „Zählt für“ → 3.
- [x] **P1.12 CORE-7** (mittel) Der erste Seitenstand zählt alle Seiten als an diesem Tag gelesen. Lösung:
  `ListItem.startAt: Double?` (JSON `startAt` in `fieldNames`, `init(fields:)`, `fields`; ältere Builds behalten das
  Feld). `ListMath.dailyAmounts` beginnt mit `highest = item.startAt ?? 0` (die `items`-Variante reicht das Element
  durch); `ListMath.current(item, progress, through:) = max(reached ?? 0, startAt ?? 0)` in `fraction`,
  `suggestsFinish` und `progressText` (Lists.swift:323-334 – sonst „noch nicht begonnen“ bei `startAt` 120, KR3-12);
  `status` = `.running` bei `startAt > 0`. Store (`addPages`, `WeekContext.reached(_:through:)`,
  WeekContext.swift:1123-1125) und Buch-Fenster → Zuarbeit P2, P7. Nachträglich gesetzt repariert es einen aufgeblähten
  ersten Tag (die betroffenen Wochen werden neu gewertet). 1.9.0 behält `startAt`, rechnet aber ohne (§0.2). Abnahme:
  Tests erster Stand unter/gleich/über `startAt`; „+ Seiten“ ohne Stände; `progressText` mit `startAt` ohne Stände;
  unbekanntes Feld bleibt.
- [x] **P1.13 CORE-8** (mittel) Bericht, PDF und Rückblick ignorieren die verborgenen Messwerte von Punkten mit
  `list:`/`app:`. Lösung (Reports.swift:59-65): `let all = measures + ExchangeDerivation.virtualMeasures(items: items,
  measures: measures)` nur für `progressRatio`/`workedDays`; `input.measures` bleibt (keine verborgenen Messwerte in
  „Messwerte“ und Wochenziel-Zeilen, :152, :859). Deckt alle Aufrufer ab. Abnahme: Test: dieselbe Woche über
  `WeekExtras + Scorer` und über `WeekReportInput.weekData` gibt gleiche Gesamt- und Kategorienote (Punkt mit
  `list:buch` und mit `app:theo:ph`).
- [x] **P1.14 CORE-9** (niedrig, mit UIPHONE-6) „1 von 10 Bücher“, „1 Punkte in 1 Kategorien“, „1 fällige Punkte“.
  Lösung: `Units.dative(_:)` nur nach „von“ (Wort auf -e/-er/-el, nicht schon -n/-s → +n: Büchern, Kursen, Kapiteln,
  Litern; Kürzel PH, km, kg, Stk., min, € bleiben); `Units.singular(_:)` mit kleiner Tabelle (Bücher→Buch, Seiten→Seite,
  Packungen→Packung, Workouts→Workout, Lektionen→Lektion, Folgen→Folge, Kurse→Kurs, Filme→Film, Minuten→Minute,
  Stunden→Stunde, Schritte→Schritt; Unbekanntes bleibt) für den Wert 1 ohne Ziel, in `ResultProgress.text`
  (GoalResults.swift:399-402, `unitSuffix` :428-431). „davon 0 in Abschnitt 2“ bleibt. Bericht Reports.swift:195 über
  `Format.count` („1 fälliger Punkt“). Import-Kopf und CSV-Prüfung → Zuarbeit P3. V10Tests.swift:1002 und Doc-Kommentar
  von `text` anpassen. Abnahme: Tests 1/0/10 mit und ohne Ziel („1 von 10 Büchern“, „1 Buch“).
- [x] **P1.15 CORE-12** (niedrig) Kommentar nennt „über 8“ noch offene Frage. Lösung: GoalTrack.swift:9
  `/// "über 8" – decided: counts from 8,00 (rounded to two places)`; die veraltete erste Doc-Zeile in Format.swift:31
  löschen. Bezeichnung „über 8“ bleibt (§1.1); die Tour sagt schon jetzt die Regel (ThaliaTour.swift:120-121: „Eine
  Kategorie mit einer Wochennote ab 8,00 ist gut dabei: Die Zielkarte zeigt „✓ über 8“ …“). Antwort auf §4 F2 = „ab 8“ →
  alle Stellen auf einmal ändern; die Liste kommt aus `grep -rn "[üu]ber 8" App Shared Watch Widgets Packages` (KR2-22 –
  die feste Liste fehlte u. a. bei GoalResults.swift:328 `.accessibilityLabel("über 8 diese Woche")` und
  Explainers.swift:505). Abnahme: keine „open question“ mehr im Code; Tour nennt „ab 8,00“.
- [x] **P1.16 DISPLAY-1** (hoch) Wochenziele zeigen „im Plan“, obwohl sie nicht mehr erreichbar oder verpasst sind;
  der Bericht sagt „nicht erreicht“. Lösung: `Pace` bekommt `plannedLeft` (geplante Tage nach heute) und `weekOver`
  (vom Aufrufer `isClosed || today > week.sunday`; Parameter mit Standard `today > week.sunday` in `Pace.init`/
  `Measures.weeklyPace`); `PaceStatus`: erreicht → „erreicht“; nicht erreicht und `weekOver` → „nicht erreicht“;
  nicht erreicht, `plannedLeft == 0`, laufende Woche → „noch offen“; sonst „hinter dem Plan“/„im Plan“
  (Scoring.swift:478-497); Grenzen unverändert. Zwei Labels (KR2-12): `PaceStatus.label` kurz („noch offen“) für Zeilen,
  die schon „x von y“ zeigen (sonst „12 von 12,8 PH – noch 0,8 PH offen“, bricht um), `label(remaining:unit:)` mit Menge
  („noch 0,8 PH offen“) nur, wo kein „von“ steht (Fokus, Watch). `Pace.label` nutzt es. Farbe einmal in der App
  (Zuarbeit P4), Anzeige → Zuarbeit P2, P5, P6. Abnahme: Tests Samstag 90 % mit geplantem Sonntag „im Plan“; letzter
  geplanter Tag 93 % „noch offen“ bzw. „noch 0,8 PH offen“; abgeschlossene oder vergangene Woche 93 % „nicht erreicht“;
  Bericht (Reports.swift:174) und App gleich.
- [x] **P1.17 DISPLAY-5** (mittel, mit UIPHONE-5) Trend „gleichbleibend“ bei weniger als 8 Wochen (Fenster überlappen).
  Lösung (Reports.swift:345-347, :982-985): `k = min(4, scores.count / 2)`; k < 2 → erste/letzte nil, Trend nil; sonst
  `prefix(k)`/`suffix(k)` ohne Überlappung; `window: Int` neu in **beiden** `GoalLine` (`PeriodReport`, Reports.swift:293,
  und `RangeReport`, :884); die Felder `firstFour`/`lastFour` behalten ihre Namen (schon `Double?`; GoalsView.swift:1136/
  :1162 lesen sie, KR3-5). Markdown: „erste Wochen“/„letzte Wochen“
  mit „(je k)“, Trend „–“; Kopfzeile behält den Zeitraum und bekommt „· Ø aus abgeschlossenen Wochen“. Anzeige →
  Zuarbeit P7 (Zielüberprüfung), P6 (PDF). Abnahme: Tests n = 2, 3, 4, 5, 8.
- [x] **P1.18 GAP-14** (niedrig) Tour nennt „Plan übernehmen“, der Schalter heißt „Vom Plan“. Lösung:
  ThaliaTour.swift:106-107 (body, macBody) „„Vom Plan“ – Punkte einer geplanten Woche übernehmen, dann selbst abhaken
  und abschließen“; CSVTests.swift:372 erwartet „Vom Plan“. Nur Text, kein `since`-Sprung. Abnahme: Tour-Tests grün.
- [x] **P1.19 Tour 11** (kein Befund, §1.8, mit KR2-6, KR2-14, KR3-13, KR3-15): `ThaliaTour.version = 11`; nach
  `connected-apps` drei Schritte `since: 11`:
  (1) `backup` („Sicherung“, Symbol `externaldrive`): „Einstellungen → Deine Daten zeigt, wann und auf welchem Gerät
  zuletzt gesichert wurde, und hat „Sicherung erstellen…“. iPhone und Mac legen außerdem jede Woche selbst eine Sicherung
  an (Einstellungen → Deine Daten → Sicherungen).“; macBody mit „Ablage → Sicherung erstellen…“.
  (2) `rules-11` („Genauer gerechnet“, Symbol `function`): „Eine verpasste Wochenquote zählt jetzt auch, wenn der letzte
  Tag leer bleibt. Zeitziele über Mitternacht stimmen. „10 Bücher“ zählt alle fertigen Bücher. Die letzten drei
  abgeschlossenen Wochen können sich dadurch einmal leicht ändern; eingefrorene bleiben.“ (gleich für Mac).
  (3) `health-share` (HEALTHSHARE, „Health am Mac und auf der Watch“): „Einstellungen → Apple Health → „Health-Werte mit
  Mac und Watch teilen“. Dann zählen Mac und Watch die übernommenen Health-Werte wie das iPhone. Nur in der
  TestFlight-Version.“ (ohne „deine“ – CSVTests.swift:385-386 verbietet „ du “/„deine“ ab `since: 8`); macBody „Ist am
  iPhone „Health-Werte mit Mac und Watch teilen“ an, zeigt und zählt der Mac Gewicht, Schlaf und Co. vom iPhone.“
  `static func catalog(healthShare: Bool)` lässt (3) bei false weg; `static var catalog` bleibt als
  `catalog(healthShare: false)` (§0.9). Außerdem im Schritt `goal-results` (ThaliaTour.swift:118-121) Symbol `trophy`
  statt `flag.checkered` (P7.9), „im Rückstand“ statt „hinten“ (P1.10) und „ab 8,00“ (P1.15). Aufrufer mit Tor → P9.2;
  TOUR.md → P1.22. Abnahme: `tourCatalogIsValid` mit und ohne (3); „Neu in Thalia“ nach 1.9 hat 3 bzw. 2 Schritte;
  der „du/deine“-Test bleibt grün.

**Runde 5 (Abschluss):**
- [x] **P1.20 SYNC-20** (niedrig) docs/SYNC.md steht bei 1.6.1. Lösung: „Stand 1.10.0“, nur was der Code dann tut;
  Zeilen „Jahresziel-Ergebnisse, Einträge, Abschnitte, Leseliste, Zuordnungen, Kategorie-Noten → über iCloud als
  Einstellungs-Datensätze (ältere Versionen übergehen sie)“; „Verbundene Apps → nur über ein Gerät, auf dem beide Apps
  laufen und Thalia nachsieht (Start, Vordergrund, alle 5 Min. – am Mac auch im Hintergrund –, nach dem Abgleich,
  Tageswechsel, Meldung der App)“; „Wertung abgeschlossener Wochen → das iPhone wertet; Mac, Watch und iPad werten selbst
  nur nach eigener Eingabe, für Wochen ohne Health-Punkte (oder geteilt abgedeckt), nach ihrem ersten Abgleich und wenn
  alle Geräte 1.10.0 haben – und schicken dem iPhone immer eine Anfrage; eingefrorene nur über „Neu berechnen““ (§1.3);
  Watch-Komplikation „… und nach einem iCloud-Import“; Health-Zeile mit dem TestFlight-Teilen (§1.4: ein Schreiber,
  App-Store-Bereinigung); „Bekannte Grenzen“: Neuinstallation, dieselbe CSV auf zwei Geräten (PH und Notizen werden
  zusammengeführt), gemischte Versionen (§0.2), Siri-Zeile erst nach dem Gerätetest von P4.14, Wiederöffnen gegen
  Offline-Schließen; Zeile 32 nach der Antwort auf §4 F1. Abnahme: jede Zeile mit dem Code abgeglichen.
- [x] **P1.21 UIPHONE-21** (niedrig) CI-Screenshots: zwei leer (`iphone-week-light`, `iphone-work-dark`), Ziele,
  Rückblick, Einstellungen, Woche abschließen fehlen. Lösung (KR3-10: die Bildschirme müssen schon für die Abnahmen von
  Runde 3 da sein): Config/ci.env `SCREENSHOT_SCREENS` + „goals review close-week settings backup“, `MAC_SCREENS` +
  „review settings“ → Zuarbeit P4 (Runde 3b, mit den Demo-Bildschirmen); „health“ → Zuarbeit P9 (Runde 4). Hier:
  docs/HANDBOOK_PROPOSALS.md neuer Vorschlag „screenshots.sh: fast einfarbiges Bild (z. B. < 100 KB bei 1206 × 2622)
  nach 3 s einmal neu aufnehmen, sonst melden“ (scripts/ci bleibt). Ist `iphone-week-light` wieder leer: als möglichen
  Start-Hänger in den Startprotokollen ansehen. Abnahme: Lauf nach Runde 3 und nach Runde 4 ohne leeres Bild.
- [ ] **P1.22 Abschluss und Release** (kein Befund): `MARKETING_VERSION = 1.10.0`; die Build-Nummer von 1.10.0 als
  `SyncDevice.firstV11Build` prüfen (P2.1); TOUR.md Tour 11 (drei Schritte); TESTING.md „v11 (ab Version 1.10.0)“ aus
  den Berichten aller Pakete (§3.4) samt Checkliste „Vor App-Store entfernen“ (§1.4.12) als Pflichtschritt vor jedem
  App-Store-Einreichen; STATUS „Stand v11“ (einmaliges Neuwerten, „Was 1.9.0 anders rechnet“ aus §0.2, Mac-Layout,
  offene Fragen inkl. §1.1, Checkliste §1.4.12, Hinweise der Pakete an STATUS aus §2.10); ARCHITECTURE (neue Dateien,
  Schlüssel `rescore.`, `hshare.`, `sync.build.`, `backup.last`); SYNC (P1.20); HANDBOOK_PROPOSALS (Kennzahl
  `account_balance`, Katalog-Feld `source`, Wartung ohne Undo, Drei-Zustands-Tor für TestFlight-Funktionen, P1.21);
  TASKS-v10-Hinweis zur neuen „zählt für“-Regel; unten in diesem Plan „Nachträge“ wie in v10;
  `scripts/ci/local-check.sh` plus `swiftc -parse WatchWidgets/Sources/*.swift` (das Skript prüft WatchWidgets nicht,
  KR3-25); `[screenshots]` und Bilder prüfen (§3.3); P8.1-Abnahme (§3.5); dann `[testflight]`.

### P2 – Shared: Wertung, Sync, Speicher (Runde 2)
Prüfung: `swiftc -parse`, Harness-Szenarien, Mac-CI; Gerät für P2.1, P2.2, P2.4. Vertragscommit zuerst (§0.9, §2.1).
`mergeImportedCopies` (P3.2) baut P2 selbst in `mergeDuplicates` (KR3-4: kein Aufruf über Paketgrenzen in derselben
Runde).

- [x] **P2.1 SYNC-1** (hoch, mit STORE-1; KR1-5, KR1-6, KR1-9, KR1-16) Änderungen am Mac/auf der Watch an abgeschlossenen
  Wochen ab 3 Wochen zurück werden nie neu gewertet (Rückblick, Ziele, „Wochen über 8“, PDF behalten die alte Note).
  Lösung (§1.3):
  (a) `weekReadsHealth(_ week:)` (ein Fortschrittspunkt der Woche hat als `measure` einen Messwert mit `health:`-Quelle –
  nur dann ändern Werte, die nur ein Gerät hat, die Note). `HealthDevice.scoresHealth` = iOS mit Geräteart `.phone`
  (`UIDevice.current.userInterfaceIdiom`, hinter `#if os(iOS)`); ein iPad wertet wie der Mac (KR1-16 – zwei Geräte mit
  verschiedenen übernommenen Health-Werten überschrieben sich heute nach jedem Import, weil `readsHealth` auf jedem
  iOS-Gerät wahr ist, WeekContext.swift:7-15). `readsHealth` bleibt für Vorschläge und Anzeige; jede Stelle, die heute
  mit `readsHealth` über das **Werten** entscheidet (TrackerStore.swift:1566, :1584, `recompute`), nimmt `scoresHealth`.
  `canScore(_ week:) = !weekReadsHealth(week) || HealthDevice.scoresHealth` (P9.1 ergänzt `|| healthShareCovers(week)`).
  (b) `commit(rescoring:)` (TrackerStore.swift:1551-1575), abgeschlossene, nicht eingefrorene Wochen: **iPhone** wertet wie
  heute (ab `firstImportDone`, P3.2). **Mac, Watch, iPad** werten nur, wenn die Speicherung aus eigener Eingabe kommt,
  `canScore` gilt, `firstImportDone` gesetzt ist und `allDevicesCurrent` (d) – dann werten **und** eine Anfrage schreiben
  (das iPhone rechnet mit vollem Stand nach); sonst nur die Anfrage. Wartung wertet dort nie (KR1-6: `storeInbox` endet
  in `commit`, TrackerStore+Records.swift:861, `x.<Quelle>.<Tag>` zählt zur Woche, und `shouldStore` speichert auch, solange
  die neuere Kopie des anderen Geräts noch nicht importiert ist – Exchange.swift:331): Speicherungen innerhalb von
  `withoutUndo` (P2.4 setzt den Merker `isMaintenance`) und Import-`apply` (`commit(rescoring:origin: .maintenance)`,
  Zuarbeit P3) gelten als Wartung. Anfrage = `rescore.<Woche>` (`{"v":1,"by":<installID>,"at":<ISO>,"force":false}`),
  eingefügt **vor** `context.save()` (geht mit der Änderung in derselben Übertragung zu iCloud); `scoredWeek(settingKey:)`
  gibt für `rescore.` nil. `closeWeek` (:349-357) auf Mac/Watch/iPad speichert die eigene Note wie heute (der Abschluss
  braucht eine) und schreibt eine Anfrage mit `force: true` – der Abschluss ist die erste Wertung, auch in einem früheren
  Abschnitt (KR1-5: `touchedWeeks` kennt `WeekPlan` nicht, :1597-1612, und das iPhone repariert nur 3 Wochen).
  `recompute` → P7.1. Keine Anfrage für eingefrorene Wochen ohne `force`.
  (c) `processRescoreRequests() -> [WeekKey]` nur auf dem iPhone, in `afterSync` nach `mergeDuplicates` und in der
  8-s-Startaufgabe neben `backfillCategoryScores` (Zuarbeit P4), in `withoutUndo`, erst ab `firstImportDone` (ebenso
  `rescoreRecentClosedWeeks`). Höchstens 8 Anfragen je Lauf (älteste zuerst), der Rest beim nächsten Lauf – jede baut
  einen WeekContext auf dem Hauptthread, und eine am Mac eingespielte Sicherung schreibt viele. `storeFinalScore`, wenn
  abgeschlossen und (nicht eingefroren oder `force`) und nicht durch P2.2 geschützt (geschützte `force`-Wochen gibt die
  Funktion für den Toast zurück). Die Anfrage
  (`writeSetting(key, nil)`, alle Kopien) wird gelöscht, sobald sie älter als 10 min ist; sofort nur bei eingefroren ohne
  `force`. Eine noch nicht abgeschlossene Woche wartet wie alle die 10 min (ihr `closedAt` kann nach der Anfrage ankommen,
  KR1-5); eine Anfrage, die vor ihren Markierungen ankam, wiederholt sich so beim nächsten Abgleich (schreibt nur bei
  Änderung).
  (d) **Versions-Tor** (KR1-9, §0.2): `recordDeviceSeen` (:1487) schreibt zusätzlich `sync.build.<installID>` =
  `{"v":1,"build":58,"version":"1.10.0"}` – ein eigener Schlüssel, denn an den `sync.seen.`-Wert angehängt verwürfe
  1.9.0 das Gerät (`SyncDevice.parse` teilt am ersten „|“, SyncDevices.swift:29-35). `allDevicesCurrent(now:)` = jedes
  Gerät mit `sync.seen.` der letzten 30 Tage hat `sync.build.` ≥ `SyncDevice.firstV11Build` (Core, Zuarbeit P1); die
  Watch schreibt beides über denselben Weg (ThaliaWatchApp.swift:30). Sonst werten Mac/Watch/iPad nicht selbst, und
  P4.15 zeigt beim Gerät „Thalia 1.9 – bitte dort aktualisieren“.
  (e) Kein „gespeichert vs. heute“-Vergleich für nicht eingefrorene Wochen (eingefrorene → P6.1).
  Abnahme (Harness): Mac ändert per Eingabe eine abgeschlossene Woche 5 Wochen zurück mit Health-Fortschrittspunkt → nur
  Anfrage → iPhone `afterSync` → `finalScore` und `score.<Woche>` neu, Anfrage nach dem Fenster weg; dieselbe Woche ohne
  Health-Punkt → Mac wertet selbst **und** schreibt eine Anfrage; Eingang oder Zusammenführen am Mac berührt eine
  abgeschlossene Woche → nur Anfrage, keine Note; Mac schließt eine alte Woche eines früheren Abschnitts → iPhone wertet
  sie mit `force` nach; Anfrage vor `closedAt` → beim nächsten Abgleich bearbeitet; ein Gerät mit `sync.seen.`, aber ohne
  `sync.build.` → Mac wertet nicht; 20 Anfragen → 8 je Lauf; iPad wertet keine Health-Woche. Gerät: TESTING v11.
- [x] **P2.2 SYNC-2** (mittel, mit STORE-16, BACKUP-11; KR1-10, KR3-2) Ein neu installiertes iPhone (oder ein iPad)
  wertet abgeschlossene Wochen ohne die übernommenen Health-Werte und senkt sie überall. Lösung jetzt:
  `HealthDevice.installedAt` wird **im Getter von `TrackerStore.installID`** gesetzt (TrackerStore.swift:1477-1484), wenn
  er die id neu anlegt (`health.installedAt = Date()`, UserDefaults). Der Leser nimmt den gespeicherten Wert; fehlt er,
  ruft er einmal `installID` (legt bei einer frischen Installation beides an) und liest erneut; fehlt er dann noch, gab es
  die id schon (Update von 1.9.0) → `.distantPast`. So hängt das Ergebnis nicht davon ab, wer `installID` zuerst anfasst
  (RootView.swift:29, Health-Teilen). Automatisches Neuwerten (`commit`, `rescoreRecentClosedWeeks`,
  `processRescoreRequests` – **auch mit `force`**, sonst senkte ein „Am iPhone neu berechnen“ vom Mac eine eingefrorene
  Woche auf einem frischen iPhone für immer) überspringt abgeschlossene Wochen, die vor `installedAt` endeten **und**
  Health lesen, Log „kept score: week before this install reads Health“; für eine übersprungene `force`-Anfrage Toast
  „KW44: Auf diesem iPhone fehlen die Health-Werte von damals – die Wertung bleibt.“ (Zuarbeit P4). „Neu berechnen“ von
  Hand am iPhone geht weiter. Dasselbe Signal setzt für Updates sofort `sync.firstImportDone` (P3.2). Nicht: Wertung vom
  Health-Schalter abhängig machen (Health ist standardmäßig aus – das hebelte R11 aus); keine Regel „keine HealthValue →
  überspringen“ (träfe jede Woche ohne übernommene Werte); kein Erinnerungs-Hinweis (Erinnerungen sind nach
  Neuinstallation an, nur eigene Zeiten fehlen). Ein iPad wertet nach P2.1 Health-Wochen ohnehin nicht automatisch; ob es
  das soll, klärt §4 F1 (bei „ja“: `health.scorer` – das iPhone wertet immer, ein iPad nur als gespeicherter
  `health.scorer`). Abnahme (Harness): frischer Speicher, abgeschlossene Woche mit Health-Punkt kommt per Import → Note
  bleibt, auch mit `force`-Anfrage (Toast-Rückgabe); ohne Health-Punkt → gewertet; `installedAt` richtig, egal ob zuerst
  `installID` oder `installedAt` gelesen wird; vorhandene id ohne Datum → `.distantPast`.
- [x] **P2.3 STORE-4** (niedrig, mit SYNC-17) Verschieben aus einer abgeschlossenen Woche wertet die alte nicht neu;
  Health übernehmen/entfernen wertet gar nicht. Lösung: alten Tag vor dem Zuweisen merken und bei Unterschied
  `commit(rescoring: [alt.week])` statt `save()` in `update(_ block:…day:)` (TrackerStore.swift:754-766), `editExpense`
  (:643-655), `move(_:to:)` (:711-716), `restore(_ snapshot:)` (:626-629); `touchedWeeks` (:1597-1612) bekommt
  `else if let value = model as? HealthValue { add(day: value.dayKey) }` (deckt `adoptHealth`/`removeHealth`). Geräte
  ohne Health folgen P2.1. Abnahme (Harness): Block Sonntag → Montag wertet die alte Woche neu; Health für Sonntag
  übernommen → Woche neu gewertet.
- [x] **P2.4 STORE-3** (mittel) ⌘Z/Schütteln widerruft Wartung im Hintergrund (Geräte-Meldung, Eingang, Zusammenführen).
  Lösung: `func withoutUndo<T>(_ body: () -> T) -> T`: ohne Undo-Manager direkt; sonst `context.processPendingChanges()`,
  `disableUndoRegistration()`, `defer { context.processPendingChanges(); enableUndoRegistration() }` (das Speichern liegt
  im abgeschalteten Block – SwiftData registriert beim Verarbeiten). Eingepackt: `recordDeviceSeen`,
  `ExchangeMonitor.finish` (storeInbox + writeCatalog, ExchangeInboxReader.swift:277-278), `processRescoreRequests`,
  `backfillCategoryScores`, Health-Teilen-Schreiben (P9); AppModel-Wartung → Zuarbeit P4. Registriert bleiben die
  Neuwertung in `commit`, `beginSegment`, `setGoalPeriod`. Init-Zusammenführung braucht nichts (läuft vor dem
  Undo-Manager). `withoutUndo` setzt für seine Dauer `isMaintenance` (P2.1). Hat eine Wartung etwas gelöscht oder
  vereint (`mergeDuplicates` > 0, `collapse` TrackerStore.swift:383-390, `mergeWork`/`mergeDays`/`mergePlans`), danach
  `undoManager?.removeAllActions()` (KR1-14, needsDevice: R28 – Haken am Mac, Notiz am iPhone – vereint genau das
  Objekt, das ⌘Z am Mac zurücknehmen würde; ein Undo auf ein gelöschtes Objekt ist nur am Gerät zu prüfen). Abnahme
  (Mac): abhaken, 10+ min warten oder Eingang lesen lassen, einmal ⌘Z → der Haken ist weg; nach einem Vereinen (R28-Fall)
  tut ⌘Z nichts und stürzt nicht ab.
- [x] **P2.5 STORE-7** (niedrig) Widerrufen von „Alle offenen ✓/½/✗“ und „Vorschläge übernehmen“ hinterlässt leere
  eigene Markierungen, die künftige ✓ aus verbundenen Apps verdecken. Lösung: `struct MarkSnapshot { item; mark: Mark?;
  existed: Bool }` als Rückgabe von `setMarks` und `apply(suggestions:)` (TrackerStore.swift:437-462); `restoreMarks`
  löscht bei `existed == false` jede `ItemMark` mit weekKey/itemCode/dayKey, sonst `writeMark(mark)` wie bisher.
  Aufrufer → Zuarbeit P4. Abnahme (Harness): Punkt ohne Markierung, `setMarks(.done)` + `restoreMarks` → keine
  ItemMark; abgeleiteter ✓ erscheint.
- [x] **P2.6 STORE-10** (niedrig) Doppelte Punkte/Messwerte einer Woche werden nie zusammengeführt; Löschen und
  Wiederherstellen ignorieren Kopien. Lösung: (a) `trash(_ items:)`/`trash(_ measures:)` (TrackerStore.swift:988-996)
  legen jede andere lebende Kopie mit gleicher Woche + Code mit in den Papierkorb (ein `PlanChange`); (b) `restore`
  (:1020-1026): `restoreConflicts(_:)` nennt die **Titel** mit lebender Kopie (der Papierkorb zeigt Titel, nicht Codes,
  SettingsView.swift:807-811, KR2-23); die Papierkorb-Ansicht fragt („„Lesen am Abend“ gibt es in KW48 schon.“ /
  „Wiederherstellen ersetzt den Punkt aus dem letzten Import.“ / „Trotzdem wiederherstellen“ / „Abbrechen“) → Zuarbeit
  P4. Nummern neuer Ziele bleiben (hälfe nicht gegen zwei Geräte offline); Zusammenführen lebender Kopien in
  `mergeDuplicates` → Später. Abnahme (Harness): zwei Kopien, eine löschen → beide im Papierkorb.
- [x] **P2.7 STORE-11** (niedrig, mit SYNC-14) „Wieder öffnen“ schreibt auf die neueste Kopie; die Zusammenführung
  schließt wieder. Lösung: `reopenDay`: `guard planDay(day) != nil …; let info = ensureDay(day); info.closedAt = nil …`,
  `reopenWeek` ebenso mit `ensurePlan` (TrackerStore.swift:341-370); Import-`apply` → Zuarbeit P3. `DuplicateMerge`
  bleibt („abgeschlossen gewinnt“, R28; ein „neuer offen gewinnt“ öffnete Tage durch Offline-Notizen) – Grenze in
  SYNC.md (P1.20). Abnahme (Harness): zwei Kopien eines abgeschlossenen Tages, öffnen, `mergeDuplicates` → offen.
- [x] **P2.8 STORE-12** (niedrig) Eingang je Quelle liest die ganze Geschichte. Lösung: `inboxFiles(source:from:through:)`
  (TrackerStore+Records.swift:808-816) mit beiden Grenzen → Tage bauen, `inboxFiles(days:sources:)` (IN, :800-804) in
  Stücken zu 62 Tagen; ohne Quelle `exchangeSources().ids`. Präfix-Weg nur noch für das unbegrenzte `weeksWithFacts`.
  Abnahme (Harness): 400 Tagesdateien, Jahresreihe gleich wie vorher.
- [x] **P2.9 STORE-13** (niedrig) Speicher- und Lesefehler bleiben stumm. Lösung: im `catch` von `commit`
  `TrackerStore.saveFailed` senden (`userInfo` mit dem Text); `try? context.save()` in `closeWeek`,
  `rescoreRecentClosedWeeks`, `recompute`, `backfillCategoryScores` über `saveQuietly()` (meldet ebenso). Lese- und
  Schreiblogik bleibt (Doppelte heilen über `mergeDuplicates`). Anzeige → Zuarbeit P4. Abnahme (Harness): erzwungener
  Fehler → Benachrichtigung.
- [x] **P2.10 SYNC-15** (niedrig) `setSetting` behält eine zufällige Kopie und löscht die anderen. Lösung:
  `setSetting` (TrackerStore.swift:1460-1470) = `writeSetting` in einer `RecordChange`, bei leerer Änderung nichts,
  sonst `commit(change)` – die neueste Kopie bleibt, Gleiches schreibt nicht. `setGoalPeriod` (:1532-1537) schreibt alle
  vier Schlüssel in **einer** Änderung (Grundlage für P4.20). Abnahme (Harness): zwei Kopien von `goal.start` → eine,
  die neueste; gleicher Wert → kein Speichern.
- [x] **P2.11 PERF-2** (mittel) `WeekContext` als View-Eingabe wird tief verglichen – und doch immer neu gezeichnet.
  Lösung: in WeekContext.swift `extension WeekContext: Equatable { static func == (l, r) -> Bool { l.records ===
  r.records } }` mit Kommentar „gleich nur Kopien desselben Aufbaus – ein neuer Aufbau ist nie gleich, wie heute; so
  geht keine Änderung verloren“. Keine Revision, kein Cache. Abnahme: Mac-CI: `mac-log.txt` ohne Stapel
  `WeekExtras ==`/`AGDispatchEquatable`; Verhalten gleich.
- [x] **P2.12 PERF-4** (mittel) `PlanItem.record`/`MeasureDefinition.record` werden bei jedem Helfer neu gebaut. Lösung:
  in `WeekContext.init` die gebauten Datensätze behalten – `[ObjectIdentifier: ItemRecord]` für die `PlanItem`-Instanzen
  (nicht nach Code: eine Doppel-Kopie bekäme sonst die falsche) und `[String: MeasureRecord]` (eigene +
  `extras.measures`); `record(_ item:) = itemRecords[ObjectIdentifier(item)] ?? item.record` (Rückfall für fremde
  Instanzen, z. B. Editors.swift:804), ebenso für Messwerte; benutzt in `mark`, beiden `applies`, `isDerived`,
  `isQuotaMetElsewhere`, `quotaShare`, `suggestion`, `measureRecord`, `dayValue`, `weekValue`, `options`,
  `allWeeklyTargets`; `measure(code:)` nachschlagen. Liegt in der Referenz-Box `WeekRecords`. Kein statischer
  `Target.parse`-Speicher (PDFs lesen abseits). Heute-Seiten → Zuarbeit P5. Abnahme (Harness): alle Helfer liefern auf
  der Demo-Woche dasselbe wie vorher.
- [x] **P2.13 PERF-5** (hoch, mit STORE-9, SYNC-7) Start und jeder iCloud-Import räumen die ganze Datenbank auf dem
  Hauptthread auf. Lösung (Hauptkontext bleibt): `mergeDuplicates(since minWeek: WeekKey? = nil)` – nil wie heute;
  sonst **IN-Prädikate** (KR1-17, KR3-19: ein `>=` auf Texten wäre das erste Bereichs-Prädikat im Projekt, und ein
  fehlgeschlagener Abruf gibt still `[]`, TrackerStore.swift:67-69 – R28 käme für bis zu 24 h zurück): ItemMark mit
  `recentWeeks.contains($0.weekKey)` (4 Wochenschlüssel), WorkBlock mit `importID != "" && deletedAt == nil &&
  recentDays.contains($0.dayKey)` (28 Tage); PlanDay/WeekPlan ganz (wenige). `mergeImportedCopies` (P3.2) läuft immer
  voll (schon per Prädikat auf `importID != ""` begrenzt).
  `maintenance(today:)`: einmal je 24 h (UserDefaults `maintenance.lastFull`) `purgeExpired()` + volles
  `mergeDuplicates()`, sonst `mergeDuplicates(since: today.week.adding(weeks: -3))`; Log „Maintenance: full/recent, N ms“
  (`AppLog.info` – die einzige Messung am echten Speicher, TestFlight ist Release). Aufrufer → Zuarbeit P4.
  Doc-Kommentare anpassen. Nicht: „vom Import berührte Wochen“ (das Ereignis nennt keine Objekte), keine Purge-Speicherung
  ohne `commit`. Abnahme (Harness): doppelte Markierung der laufenden Woche → von `afterSync` zusammengeführt; 10 Wochen
  zurück → erst im täglichen Lauf; Lesen dazwischen richtig.
- [x] **P2.14 PERF-7** (niedrig, mit WATCH-15) Kleine Leser laden alle Ziel-, Lese- und Noten-Datensätze; die Watch
  rechnet je Änderung dreimal. Lösung: `WeekReader(week:today:goalYear: Bool = true, content:)` – bei false zeigen
  `_goalRecords` und `_scoreRecords` auf eine IN-Abfrage über `TrackerStore.goalPeriodKeys`; `list.`, `link.rule.`,
  `x.sources`/archive und Eingang bleiben (die Leseliste speist Watch-Werte); Doc-Kommentar „keine Ergebnisse,
  Abschnitte, Einträge, Kategorie-Wochennoten – wie der Widget-Schnappschuss“. `widgetSummary` (TrackerStore.swift:
  155-158): Abruf und Aufbau trennen, bei `tomorrow.week == today.week` einmal abrufen, zwei Kontexte bauen. Keine
  Schlüsselbereich-Abfragen (die Leseliste braucht alle früheren Stände). Aufrufer → Zuarbeit P4, P5, P8. Abnahme
  (Harness): Note und `todaySummary` mit `goalYear: false` gleich wie mit true.
- [x] **P2.15 DISPLAY-16** (niedrig) Großes Widget nennt Wochenziele anders als die App. Lösung: `todaySummary`
  (WeekContext.swift:510-512) `title: target.item?.title ?? target.measure.title` wie App und PDF. Abnahme: Code-Review;
  P8 prüft die ForEach-id im Widget.
- (P2.16 der ersten Fassung – Health-Teilen, Shared-Kern – ist jetzt **P9.1**: das ganze Teilen liegt in einem Paket,
  KR3-11.)

### P3 – Sicherung und Import (Runde 1: Core-Teil; Runde 2: Shared/App-Teil)
Prüfung: Linux-Tests (`V11BackupTests.swift`) am Ende von Runde 1, Harness und Mac-CI am Ende von Runde 2; Gerät für
P3.2, P3.10, P3.13. **Runde 1** (KR3-11b, nur `PlanCSV.swift`, `ImportPreview.swift`, `V11BackupTests.swift`, auf Linux
prüfbar): P3.1 (1)(2), Zeile und Parse von P3.3, Vorschau von P3.4 (a)(b), P3.5 (3), Zeile/Parse/Vorschau-Texte von
P3.6, Zeilen von P3.7, P3.8, P3.9, Leser von P3.10, `referencedWeeks` von P3.12, Zuarbeit an P1.1/P1.3/P1.14 in diesen
Dateien. **Runde 2:** der Rest
(`TrackerStore+Import.swift`, `ImportView.swift`, `PastImport.swift`, `Backups.swift`, `docs/IMPORT.md`). Neue Tests nur
in `V11BackupTests.swift`; bricht eine P3-Änderung eine Erwartung in einer P1-Testdatei (z. B. CSVTests), passt P3 sie
nach dem Merge von P1 an (P1 wird in Runde 1 zuerst gemergt).

- [x] **P3.1 CORE-4** (niedrig) Drei Zahlenleser in einer CSV: 1,125 kommt nach Sicherung und Einspielen als 1125
  zurück, „≥8.000“ heißt 8. Lösung: (1) Schreiber: nur in den Exportzeilen von PlanCSV (nicht `Format.plain` global – das
  schreibt auch synchronisierte Einstellungstexte) bekommt ein Wert mit genau drei Nachkommastellen eine vierte Null
  („1.1250“) – jeder Leser und jeder ältere Build liest das richtig, Sicherungen sind sofort heil. (2) Leser:
  `PlanCSV.number(_:)` (einzelner Punkt = Dezimalpunkt, einzelnes Komma = Dezimalkomma, beide = deutsche Gruppierung;
  endlich, < 1e12) für Wert-, Noten-, Zählspalten und Zielzahlen der CSV (PlanCSV.swift:439, :469, :509, Ziele); ein
  einzelner Punkt mit genau drei Stellen bringt eine Vorschau-Warnung „Zeile n: „8.000“ als 8 gelesen – Tausenderpunkt?
  Bitte 8000 schreiben“. `Format.parse` bleibt für die Oberfläche. (3) Prompts → Zuarbeit P1. Abnahme: Tests Rundreise
  1.125, 0.125, 81.125; „8.000“ → 8 plus Warnung.
- [x] **P3.2 BACKUP-2** (hoch, mit SYNC-16; KR1-2, KR1-20, KR3-2) Eingespielte PH, Werte und Notizen doppeln sich
  (Einspielen während iCloud noch lädt, dieselbe CSV auf zwei Geräten). Lösung: (1) `mergeImportedCopies()` baut **P2**
  in TrackerStore.swift (Zuarbeit; dort liegen `mergeDuplicates` und `mergeWork`): läuft in `mergeDuplicates` **vor** dem
  Zusammenführen nach `importID` und gruppiert Original und alle eingespielten Kopien in einem Schritt; immer voll (nicht
  mit `since:`, P2.13). WorkBlock und DayNote mit `importID != ""`; UUID-artige importIDs → Originale per `#Predicate {
  ids.contains($0.uuid) && $0.deletedAt == nil }` (kein Vollscan); nach `recordID` gruppieren; Behalter = die Kopie mit
  `uuid.uuidString == recordID` (Original), sonst die älteste (createdAt, uuid) wie `mergeWork`; Felder einer anderen
  Kopie nur übernehmen, wenn sie nach dem Anlegen bearbeitet wurde (`modifiedAt > createdAt + 2 s`) und neuer ist – eine
  eingespielte Kopie rollt nie Änderungen nach der Sicherung zurück; Notizen ebenso; Ergebnis auf jedem Gerät gleich.
  `mergeWork` (TrackerStore.swift:1329-1346) setzt `keeper.modifiedAt = newest.modifiedAt` statt `keeper.touch()`
  (KR1-2: sonst sieht eine zusammengeführte eingespielte Kopie „bearbeitet und neuer“ aus, und die Sicherung überschriebe
  spätere Änderungen am Original auf jedem Gerät). (2) Wächter: `sync.firstImportDone` (UserDefaults, Shared-Helfer
  `SyncProgress.noteImport(_ event:)` in P2, aufgerufen vom Import-Beobachter in Shared/WidgetPublisher.swift – ein Ort
  für App und Watch, Zuarbeit P8) wird gesetzt, wenn ein `.import` erfolgreich endete, 60 s lang kein weiterer Import
  begann und ein `sync.seen.`-Eintrag eines anderen Geräts im Speicher ist (KR1-20, needsDevice: der erste Abgleich
  eines frischen Geräts braucht oft mehrere Import-Ereignisse); spätestens 24 h nach `installedAt`; nach einem Update
  von 1.9.0 (`installedAt == .distantPast`, P2.2) sofort (KR3-2 – sonst warnte der Import direkt nach dem Update).
  ImportView zeigt bei aktivem iCloud, fehlendem Merker und einer Datei mit `record`-Zeilen oder `abgeschlossen` orange
  „iCloud lädt noch deine Daten. Lies die Sicherung erst ein, wenn der Abgleich fertig ist – sonst zählen Power-Hours,
  Werte und Notizen doppelt.“, Einlesen fragt („Trotzdem einlesen“). Derselbe Merker hält das automatische Neuwerten
  (P2.1) und die automatische Sicherung (P3.13) zurück. (3) Einträge (ohne id): `restore.window` (Beginn/Ende von
  `apply`, 7 Tage in UserDefaults); `cleanRestoreDuplicates()` (in `afterSync`, Zuarbeit P4): je Code + Tag, wenn die im
  Fenster angelegten Einträge dieselbe Menge (Wert, Text, Notiz, Schätzung) haben wie die vorher angelegten → die aus dem
  Fenster in den Papierkorb; keine Minuten vergleichen. (4) TESTING.md:467 (ohne frischen Speicher prüfen, „Nie in ein
  Gerät einlesen, dessen erster iCloud-Abgleich noch läuft.“) und SYNC.md-Grenzen → P1.22/P1.20. Abnahme (Harness):
  Original + eingespielte Kopie → einer; bearbeitetes Original behält die Änderung; **Original nach der Sicherung
  bearbeitet + eingespielte Kopien von zwei Geräten → das Original behält die Änderung**; Wächterzeile ohne Merker.
  Gerät: frisches Gerät, Sicherung früh einlesen → Warnung; Merker erst nach dem ganzen ersten Abgleich (§3.4.7).
- [x] **P3.3 BACKUP-4** (mittel; KR1-15) Einspielen wertet jede abgeschlossene Woche mit heutigen Regeln und Gerät neu
  (auch am Mac ohne Health). Lösung: neue Zeile `wertung` nach jeder abgeschlossenen Woche mit `finalScore`: `id =
  <Woche>`, `value = String(finalScore)` – **volle Genauigkeit**, nicht `Format.plain` (schreibt höchstens 4 Stellen,
  Format.swift:44-51) –, `note = finalGoalScores` („1=8.2;2=7.5“, ebenso mit `String`; Anzahl = `finalGoalsScored`,
  Test). Parse → `Document.finalScores[week]` (Runde 1). In `apply` (TrackerStore+Import.swift:412-419, Runde 2) für
  **jede** Woche mit Zeile – in `newClosedWeeks` und schon abgeschlossene (KR1-15: `commit(rescoring: [])` läuft vor den
  Abschlüssen, und `newClosedWeeks` enthält nur neu geschlossene Wochen, ImportPreview.swift:292): `closedAt` (falls
  offen) und die drei Felder setzen, `score.<Woche>` der Datei behalten, **kein** `storeFinalScore` und keine Anfrage
  (eigener Helfer in dieser Datei; `apply` speichert als Wartung, P2.1). Ohne Zeile (alte Sicherungen) wie bisher; ältere
  Builds listen die Zeile unter „Nicht gelesen“. Nach dem Wächter aus P3.2. Abnahme: Rundreise-Test der drei Felder mit
  7,123456 (bitgleich); Harness: Einspielen auf dem Mac ändert keine Note, auch nicht in schon abgeschlossenen Wochen,
  und schreibt für Wochen mit Zeile keine Anfrage.
- [x] **P3.4 BACKUP-5** (mittel, mit STORE-6) Widerrufen eines Imports ist unvollständig; ein Plan macht ein vorher
  gesetztes „Urlaub“ zu „Arbeitstag“. Lösung: (a) ImportPreview löst eingehend über vorhanden auf wie
  `SettingRow.resolved`: eine leere Notiz der Datei behält die vorhandene Markierungs- und Tagesnotiz (wie R21/K1);
  Markierungswerte bleiben „Datei gewinnt“, auch geleerte (v10 Grundregel 1). (b) **Krank/Urlaub bleiben:** ist der
  vorhandene Tagestyp entschuldigt und der eingehende nicht, bleibt er, orange Vorschauzeile „Fr 27.11.: bleibt
  „Urlaub“ – die Datei sagt „Arbeitstag“.“ (c) Planungs-Prompt nennt gesetzte Tage der Zielwoche („Schon eingetragen für
  KW48: Fr 27.11. Urlaub – so übernehmen.“) → Zuarbeit P1, P2. (d) `ImportResult` merkt die uuids eingefügter
  WorkBlocks, DayNotes, Reflections und die vorigen (Typ, Notiz) geänderter PlanDays; `undoImport` löscht bzw. stellt
  zurück; „Widerrufen“ erscheint, sobald es so etwas gibt (ImportView.swift:466-478). Kein allgemeines Umkehr-Dokument.
  Abnahme: Tests (Vorschau idempotent; leere Notiz löscht nicht; Urlaub bleibt mit Zeile); Harness: Vergangene Woche
  nachtragen → Widerrufen entfernt eingefügte Notizen/Reflexionen, Tagestypen zurück.
- [x] **P3.5 BACKUP-6** (niedrig) Ein älteres Backup bringt den alten Schlüssel eines verschobenen Eintrags oder
  Seitenstands zurück – er zählt doppelt. Lösung: (1) `SettingRecords.decode` neueste je id (Zuarbeit P1);
  (2) `storedRecordRows` exportiert nach derselben Regel; (3) ImportPreview: hält die App dieselbe id unter anderem
  Schlüssel → App-Stempel neuer = unverändert, Datei neuer = schreiben und den anderen Schlüssel löschen (wie `write`);
  (4) `mergeDuplicates` löscht den veralteten Schlüssel einer doppelten id (Zuarbeit P2). Abnahme: Tests decode und
  Vorschau.
- [x] **P3.6 BACKUP-7** (niedrig) Sicherung ohne Datum, Version, Gerät. Lösung: erste Datenzeile
  `sicherung,<ISO Datum-Zeit>,,Thalia 1.10.0 (<Build>),<Geräteart>` nur bei „Alles als CSV“ (Geräteart =
  `SyncDeviceKind.current`). Vorschau-Kopf „Sicherung vom 22.11.2026, 18:03 · Thalia 1.10.0 (58) · iPhone“; älter als
  1 Tag mit Änderungen: orange „Die Sicherung ist 9 Tage alt – 37 Markierungen und 12 Werte in der App weichen ab und
  werden auf den Stand der Sicherung gesetzt.“; weder `sicherung` noch `record`: „Diese Sicherung stammt von einer
  älteren Thalia-Version – Ergebnisse, Leseliste und verbundene Apps fehlen darin.“ Kein „neuer gewinnt“-Modus.
  Abnahme: Tests Zeile hin und zurück; alte Datei ohne Zeile liest sich.
- [x] **P3.7 BACKUP-8** (niedrig, mit STORE-8, BACKUP-10) Sicherung ohne Zieljahr und Katalog-Schalter; Archivieren
  löscht Planänderungen. Lösung: (1) `SettingKeys.goalYearKeys` und `catalogSwitch` (Zuarbeit P1) als `record`-Zeilen
  exportieren und lesen; Import **füllt nur auf**, wo die App keinen Wert hat (ohne Stempel überschriebe ein altes Backup
  sonst ein neues Zieljahr); abweichend: Vorschauzeile „Zieljahr in der Datei: 1.6.2026–31.5.2027 – in der App bleibt
  1.6.2027–31.5.2028.“; vor Ergebnissen und Abschnitten geschrieben. (2) `archiveWeek` (TrackerStore+Import.swift:549)
  schreibt die `PlanChange` als `change`-Zeilen (kind, target, code, title, detail, carryOver) in den Schnappschuss;
  `restore(archive)` und `undoImport` legen sie wieder an; ältere Builds übergehen die Zeile. (3) `WeekArchive` nicht
  exportieren. Text → P3.14. Abnahme: Tests (Zeilen hin und zurück, Auffüllen statt Ersetzen); Harness: Woche neu
  importieren + Widerrufen → „Auch in den nächsten Wochen“ wieder da.
- [x] **P3.8 BACKUP-12** (niedrig) Eine Woche vor KW42 mit neuem Modell kommt als „alt“ zurück. Lösung:
  `PlanCSV.export` (:797) schreibt `neu` für Wochen vor `WeekRecord.scoringChange` mit Modell „“; ältere Builds ohne
  `neu` fallen auf den heutigen Standard zurück. Abnahme: Test export → parse gleiches Modell für KW41 mit „“ und „alt“,
  auch über `exportDocument(weeks:)`.
- [x] **P3.9 BACKUP-15** (niedrig) Einspielen verliert Uhrzeiten und Reihenfolge und bringt Markierungen gelöschter
  Punkte als Waisen. Lösung: (1) Einzelner Eintrag: `aggregate()` setzt `order = recordedAt.timeIntervalSince1970`,
  Export schreibt `title = Format.clock(minutes)` auf die einfache Eintragszeile, Parse setzt `order` aus `title`; der
  Vergleich nullt `order` beidseitig (ImportPreview.swift:247-251, :351) – Re-Import bleibt „unverändert“; ältere Builds
  ignorieren `title`. (2) `exportDocument` sortiert Arbeit und Notizen nach `createdAt`, `PlanCSV.export` nach (Tag,
  Position) statt (Tag, id). (3) Nur in der vollen Sicherung (`weeks == nil`) Markierungen auf `doc.items` beschränken,
  nie in Archiv-Schnappschüssen. Abnahme: Rundreise-Test (07:10 bleibt 07:10, Reihenfolge zweier Notizen); volle
  Sicherung ohne Warnung „Markierungen für unbekannte Punkte“.
- [x] **P3.10 BACKUP-3** (mittel) Jahres-Sicherung einlesen: quadratisches Lesen, alles im Hauptthread, ganze Datei im
  Textfeld. Lösung: Core: in `PlanCSV.parse` nur suchen, wenn der Schlüssel schon vorkam (Arten mit `warnDuplicate`
  über `seen`; Markierungen :378/:429 gemeinsam, Einträge :450 – neuer Schlüssel direkt anhängen –, Arbeit, Notizen,
  Reflexionen, Noten, Datensätze je ein `Set<String>`): „letzte Zeile gewinnt“ und Reihenfolge exakt wie heute. App:
  Datei > ~200 KB nicht ins TextField – Zeile „Thalia Sicherung 2026-11-22.csv · 3,7 MB“ mit „Datei entfernen“
  (Wächter `previewText == text` anpassen); Vorschau „Sicherung wird gelesen …“: `existingState()` auf dem Hauptthread,
  `ImportPreview(text:existing:)` in `Task.detached` (`ImportPreview` `Sendable`). `apply` bleibt **eine** Speicherung
  (Teilspeicherungen schöben halbe Stände zu iCloud), davor ein blockierender Hinweis „Sicherung wird eingespielt –
  bitte warten“ (50 ms zeichnen lassen). Abnahme: Test doppelte Zeilen je Art → letzte gewinnt, Reihenfolge wie vorher;
  synthetisches Jahr (52 Wochen) mit lockerer Grenze (< 5 s); Gerät: Jahres-Sicherung ohne Einfrieren.
- [x] **P3.11 PERF-13** (niedrig) „Alles als CSV (Sicherung)“ (künftig „Sicherung erstellen (alles als CSV)“, P3.14)
  wird im Knopf auf dem Hauptthread gebaut. Lösung:
  `BackupWriter.exportText(store:)`: `exportDocument()` auf dem Hauptthread, `PlanCSV.export(doc)` in
  `Task.detached(priority: .userInitiated)` (Muster RangePDF.swift:311); Knopf mit `isBackingUp`, ProgressView
  „Sicherung wird erstellt …“, deaktiviert. `storedRecordRows`/`syncableValue` bleiben (Health-Schutz). Derselbe Weg für
  P3.13 und P4.9. Abnahme: Gerät: Fortschritt sichtbar, kein Doppeltipp.
- [x] **P3.12 PERF-6** (mittel, mit STORE-14) Prompt kopieren, Woche wiederholen, Woche als CSV und jede Vorschau lesen
  die ganze Datenbank samt Eingang. Lösung: (1) `existingState(includeRecords:)`: `storedRecordRows()` nur bei voller
  Sicherung oder wenn die Datei `record`-Zeilen hat; bei `exportDocument(weeks: nicht nil)` nie. (2)
  `existingState(weeks:includeRecords:)`: ganz wie heute Ziele, Kategorien, Pläne, **Messwerte aller Wochen**
  (`keepingSources` sucht die nächste frühere Woche, ImportPreview.swift:459-470) und Archivnoten; beschränkt Punkte,
  Markierungen (`weekKeys.contains`), Tage, Einträge, Noten (`dayKeys.contains`), Reflexionen (`scope`); Arbeit und
  Notizen nur, wenn die Datei solche Zeilen hat, dann alle (sie hängen an der id). Wochen aus
  `PlanCSV.Document.referencedWeeks` (alle Zeilenarten). (3) `preview(text)`: erst billig mit Zielen/Kategorien/
  Messwerten lesen → `referencedWeeks` → beschränkter Zustand → `ImportPreview` wie heute. (4) `apply`, `archiveWeek`,
  `weekChanged` (:516-531, :641-650) mit Prädikaten und dem schon gebauten Zustand. Volle Sicherung und Wiederherstellen
  bleiben voll. Abnahme: Test `referencedWeeks` je Zeilenart; Harness: gleiche Vorschau wie mit vollem Zustand (Demo,
  ChatGPT-Plan, Vergangene Woche); Log-Zeiten am Gerät < 200 ms.
- [x] **P3.13 BACKUP-1** (hoch, mit UIPHONE-8; KR1-13, KR2-2, KR2-17) Keine automatische Sicherung, keine Erinnerung,
  kein „zuletzt gesichert“. Lösung (§1.6): **Schritt 1:** Einstellungen → „Deine Daten“ erste Zeile „Sicherung
  erstellen…“ (gleicher Export, ein Name überall, §1.6.5). „Letzte Sicherung“ gilt für **alle** Geräte (KR2-2: eine
  Sicherung enthält alle synchronisierten Daten – ein Mac sollte nicht mahnen, wenn das iPhone gestern gesichert hat):
  synchronisierter JSON-Datensatz `backup.last` = `{"v":1,"at":"…","device":"iPhone"}` (`AppSetting`, nicht in
  `SettingKeys.all`, nie in der Sicherung; Geräteart, nie der Name), geschrieben nach jeder erfolgreichen **vollen**
  Sicherung von Hand (`exportIsBackup`, ImportView.swift:82-85; Mac-Befehl P4.9) über `writeSetting` (neueste gewinnt);
  dazu je Gerät `backup.lastAuto` (UserDefaults) für die automatische Datei. Fuß: „Letzte Sicherung: 22.11.2026 am
  iPhone (vor 3 Tagen) · automatisch: 23.11.2026 auf diesem Gerät“ bzw. „Noch keine Sicherung“ und „Die Sicherung ist
  deine Kopie außerhalb von iCloud – auch für die Daten verbundener Apps.“ Im Wochenabschluss nach den Berichtsknöpfen
  eine ruhige Zeile, wenn **kein** Gerät seit 30 Tagen von Hand gesichert hat: „Letzte Sicherung vor 34 Tagen – jetzt
  sichern?“. **Schritt 2:** `BackupWriter.writeWeeklyIfDue(store:today:mode:)` – Datei mit **Datum**, „Thalia Sicherung
  2026-11-23.csv“, in `Application Support/Sicherungen` (iPhone, Mac; nicht Watch), nie überschrieben, höchstens alle 7
  Tage, ausgelöst beim Wechsel in den Hintergrund (iOS mit `BackgroundGrace`, Mac bei Inaktiv), nie im
  Abschluss-Fenster; atomar schreiben. **Nur** im Modus `.iCloud`/`.local`, nie `-Demo`, Übung oder `.memory` (dort ist
  der Speicher leer, Vendor SyncStatus.swift:13-14), mit iCloud erst nach `sync.firstImportDone` (P3.2) (KR1-13: sonst
  ersetzt ein fast leerer Stand gute Dateien). Behalten: 4 neueste + je Monat eine für 6 Monate; **kein Aufräumen**, wenn
  die neue Datei kleiner als die Hälfte der größten behaltenen ist – dann orange Zeile „Letzte automatische Sicherung
  auffällig klein – ältere bleiben“. Liste „Sicherungen“ (Datum, Größe, „Teilen…“). Einstellungszeilen, Auslöser,
  Wochenabschluss-Zeile → Zuarbeit P4, P6. „Dateien“/iCloud Drive → §4 F12; Wiederherstellen aus der Liste → Später.
  Abnahme (Harness): `backup.last` wird geschrieben und nie exportiert; `.memory`/Demo → keine Datei; halbe Größe → kein
  Aufräumen. Gerät: Sicherung erstellen am iPhone → Mac zeigt „am iPhone“; nach dem Wechsel in den Hintergrund liegt eine
  datierte Datei in Application Support; die achte Woche räumt richtig auf.
- [x] **P3.14 BACKUP-16** (niedrig; KR2-17) Daten-Texte versprechen mehr als Sicherung und Papierkorb. Lösung (nach
  P3.7): SettingsView.swift:356 Titel „Sicherung“: „Einstellungen → Deine Daten → „Sicherung erstellen…“: Pläne,
  Einträge, Ergebnisse, Leseliste, Zieljahr und die Daten verbundener Apps im Importformat. Nicht darin: das Archiv
  ersetzter Wochen, übernommene Health-Werte und Einstellungen dieses Geräts.“; :357 „Gelöschte Punkte, Messwerte,
  Einträge, Power-Hours, Notizen, Ergebnisse, Bücher und Abschnitte bleiben 30 Tage in „Zuletzt gelöscht“; einzelne
  Jahresziel-Einträge und Lesestände lassen sich direkt danach im Hinweis widerrufen. Ganz löschen: …“ (beides Zuarbeit
  P4); ImportView.swift:279 heißt „Sicherung erstellen (alles als CSV)“ (ein Name, §1.6.5); ImportView.swift:294 „Die
  CSV hat dasselbe Format wie der Import – bearbeiten und wieder importieren funktioniert. Eine Sicherung erst
  einspielen, wenn iCloud auf diesem Gerät abgeglichen hat (Einstellungen → iCloud & Daten).“ Abnahme: Texte passen zu
  P3.7 (Code-Review); `grep -rn "Alles als CSV\|Sicherung exportieren" App` leer.
- [x] **P3.15 GAP-5** (niedrig) Die gewählte Woche steuert nur den Prompt; eine CSV für eine andere Woche wird ohne
  Warnung importiert. Lösung: `previewSection`: bei `showPrompt` und genau einer geplanten Woche der Datei ≠
  `targetWeek` orange „Die CSV ist für KW49 – gewählt ist KW48.“; Einlesen über Bestätigung „Trotzdem KW49 importieren“ /
  „Abbrechen“, Fuß „ChatGPT bitten, die Woche zu korrigieren“. Mehrwochen-Dateien ohne Warnung. Nicht über
  `repeated(from:to:)` umschreiben (verliert Struktur-, Notiz- und `record`-Zeilen). Abnahme: Gerät: falsche KW zeigt
  die Zeile.
- [x] **P3.16 SYNC-12** (niedrig) Leere Zustände bieten Anlegen/Wiederholen, während iCloud noch abgleicht – ein zweiter
  Plan mischt sich mit dem echten. Lösung: (1) `ImportView.apply` baut die Vorschau direkt vor dem Anwenden neu aus
  `text`; weichen die Ersetzungen ab (die Zielwoche hat inzwischen einen Plan), `preview = fresh` und zurück – der
  vorhandene Dialog „KW48 ersetzen?“ mit Archiv und Widerrufen greift. (2) NoPlanView-Hinweis → Zuarbeit P5 (Text nach
  Zustand, KR2-27). (3) `AppModel.categoryTitle` und Intents.swift:95 über `latest(by: \.key, modified: \.modifiedAt)` →
  Zuarbeit P4, P8. (4) Vorlagen-Kopien von AnnualGoal/TrackCategory (`seedStructure` setzt `createdAt = modifiedAt =
  1970`, TrackerStore.swift:248-260) je Schlüssel nur löschen, wenn eine lebende Kopie mit `modifiedAt` nach dem 2. Jan.
  1970 existiert; sind alle lebenden Kopien von 1970, bleibt genau eine (kleinste uuid – auf jedem Gerät dieselbe); nie
  die letzte lebende Kopie (KR1-1: zwei Geräte, die vor dem ersten Abgleich angelegt haben, oder nie bearbeitete Ziele
  haben überall 1970 – die alte Regel löschte beide, eine fehlende Kategorie wird nicht gewertet, Scoring.swift:256) →
  Zuarbeit P2. Abnahme (Harness): Plan kommt nach der Vorschau an → Ersetzen-Dialog statt stiller Mischung; zwei
  1970-Kopien → eine bleibt, in beiden Speichern dieselbe uuid; 1970 + bearbeitet → die bearbeitete bleibt.

### P4 – App-Rahmen, Mac und System (Runde 3a: Vertrag und Messung; Runde 3b: Rest)
Prüfung: `swiftc -parse`, Mac-CI (Typprüfung, Screenshots 1024 × 768); Gerät für P4.1, P4.2, P4.11, P4.12, P4.14,
P4.17. **Runde 3a** (ein Commit, bevor P5–P8 verzweigen, KR3-4): alle Schnittstellen aus §2.1 „P4 baut“ mit einfacher
Fassung (u. a. `StatusTint`, `focusTodayPage`, `reopenWeek`, `showsWeekSummary`, `mainWindowWidth`/`detailWidth`,
`showDayOverview`, `BackgroundGrace.holdForExport` samt leerer macOS-Fassung) und die Debug-Breitenmessung aus P4.1 (1)
als eigener CI-Lauf (KR3-11c); P5–P8 bauen auf dem Ergebnis auf. **Runde 3b:** der Rest, parallel zu P5–P8; dazu
Config/ci.env (P1.21).

- [x] **P4.1 UIMAC-1** (hoch; KR2-3, KR3-20) Heute und Woche sind breiter als das Fenster: Seitenleiste verdeckt, „Nicht
  erledigt“/„Entfällt“ abgeschnitten (mac-today, mac-week). Lösung: (1) Ursache zuerst messen (nur Debug, Runde 3a):
  `onGeometryChange` → `diagNote` für die Breiten von Seitenleiste, Heute-Liste und -Seite, beiden Inspektoren und der
  WeekTable-ScrollView; CI bei 1024 zeigt, welche Spalte über ihrem Minimum bleibt (Verdacht: HSplitView hält die Liste
  bei maxWidth 400, Hero der Wochenübersicht). (2) HSplitView bleibt (R60), Liste `maxWidth: 340` (Zuarbeit P5); die
  300-pt-Spalte der Markierungen bleibt ab 640 pt Seitenbreite (kein abgeschnittenes „Nicht erledigt“). (3) Minima
  addieren sich: MacRoot misst neben der Höhe die Breite (`app.mainWindowWidth`) und **die Detailbreite im
  Detail-Abschluss von MacRoot**, also unabhängig davon, ob ein Inspektor gerade Platz nimmt (`app.detailWidth`; die
  Seitenleiste ist ziehbar, RootView.swift:247). Ein Inspektor zeigt sich nur, solange er passt –
  `.inspector(isPresented: Binding(get: { app.showsGlanceInspector && app.fitsGlanceInspector }, set: {
  app.showsGlanceInspector = $0 }))`; „passt“ = Detailbreite ≥ Liste + Seite + Inspektor-Minimum (Heute ≈ 900, Woche ≈
  750) mit **40 pt Spielraum** (an ab Schwelle + 20, aus unter Schwelle − 20 – kein Flackern beim Ziehen). Die
  gespeicherte Wahl bleibt, die Spalte kommt mit genug Breite zurück. **Passt er nicht, öffnen ⌘0, der
  Symbolleistenknopf, der Tagesring und die Seitenleisten-Karte „Heute im Blick“ als Blatt** (`app.showDayOverview(day)`
  → `app.sheet = .dayOverview(day)`, der vorhandene Weg ohne Spalte, TodayView.swift:486-490), ebenso die
  Wochenübersicht (KR2-3: sonst tun vier Bedienelemente bei 1024 pt sichtbar nichts – ThaliaApp.swift:317-322,
  TodayView.swift:3033-3037, Glance.swift:940-944); Tooltip „Fenster breiter ziehen, um die Spalte zu zeigen“ bleibt
  (Zuarbeit P5, P6). (4) MacRoot `minWidth` bleibt 900. (5) STATUS.md:195 → P1.22. Abnahme: CI `mac-today` und `mac-week`
  bei 1024 × 768 zeigen ganze Seitenleiste und alle vier Markierungsknöpfe; in CI bei 1024 pt zeigt ⌘0 „Heute im Blick“
  als Blatt; Bini prüft 1180 und 900 pt, je mit und ohne „Heute im Blick“/„Wochenübersicht“, und zieht die
  Seitenleiste (kein Flackern).
- [x] **P4.2 UIMAC-2** (mittel) Ohne Hauptfenster (oder mit Einstellungen vorne) tun Menübefehle, Erinnerungen und
  Kurzbefehle nichts Sichtbares; das Fenster öffnet später mit einem alten Blatt. Lösung: (1) `ThaliaCommands`:
  `@Environment(\.openWindow)`; auf macOS zuerst `MainWindow.show(openWindow)` in `present()`, `closeDay()`,
  `closeWeek()`, `showGlance()`, `startTour()` und den „Gehe zu“-Befehlen ⌘1–4. (2) `MainWindow.showWithoutEnvironment()`
  (ThaliaApp.swift): `makeKeyAndOrderFront` + `NSApp.activate()`, wenn ein Fenster existiert, sonst dasselbe
  kAEReopenApplication-Apple-Event wie der Kit-Wächter (die ~10 Zeilen in App-Code kopieren, Vendor bleibt). (3) Am
  Anfang von `AppModel.route(_:)` auf macOS aufrufen (nicht in Übung/Tour). (4) `AppModel.init` (macOS) beobachtet
  `.thaliaRoute` ebenso; `PendingRoute.destination` bleibt, RootView.task leitet weiter, sobald das Fenster da ist –
  Shared/RouteIntents.swift unverändert. Abnahme (Mac): ⌘W, dann ⌘N → Fenster mit „Power-Hours erfassen“; Einstellungen
  vorne, ⌘↩ → Hauptfenster mit „Tag abschließen“; Fenster zu, Abend-Erinnerung tippen → Fenster mit „Tag abschließen“.
- [x] **P4.3 UIMAC-4** (niedrig) Woche-Befehle ignorieren den in Heute gezeigten Tag (⇧⌘↩ schließt die falsche Woche,
  ⇧⌘[ zeigt nichts, ⌘6/⌘0 uneinheitlich). Lösung nur in `ThaliaCommands` – Tag und Woche bleiben unabhängig (kein
  `didSet`, R1 bleibt): `moveWeek` auf Heute `selectedDay += 7 × offset` (wie das Titelmenü), auf Woche wie bisher, auf
  Ziele/Rückblick deaktiviert; `closeWeek` → `.closeWeek(isOnToday ? selectedDay.week : selectedWeek)`; ⌘6 →
  `.expenses(captureDay)`; `showGlance` (macOS) zeigen oder ausblenden wie Glance.swift:938-943. Abnahme (Mac): Montag
  ⌘[ auf Sonntag, ⇧⌘↩ öffnet die Vorwoche.
- [x] **P4.4 UIMAC-5** (niedrig) Ein Klick in den leeren Seitenleisten-Bereich hebt die Auswahl auf, die Seite fällt auf
  Heute. Lösung: MacRoot `List(selection: Binding<AppTab?>(get: { app.sidebar }, set: { if let tab = $0 { app.sidebar =
  tab } }))` (Muster TodaySplit); `sidebar` bleibt optional. Abnahme (Mac): auf Ziele in die Leere klicken → Ziele bleibt.
- [x] **P4.5 UIMAC-6** (niedrig) Menükürzel bleiben aktiv, während ein lokales Fenster (Ziele, Zielseite, Leseliste)
  Eingaben hält (R14-Lücke). Lösung: `var blocksSheetCommands: Bool { hasUnsavedInput }` (AppModel.swift:273) –
  `hasUnsavedInput` setzt nur `UnsavedInputModifier` und setzt es beim Verschwinden zurück (SheetChrome.swift:133-140);
  die lokalen v10-Fenster bleiben lokal (TASKS-v10 P3). Abnahme: Ziele → … → „Jahresziel eintragen…“, Wert tippen →
  ⌘N/⌘↩/⇧⌘N grau; nach Sichern/Abbrechen wieder aktiv (TESTING).
- [x] **P4.6 UIMAC-11** (niedrig) „Darstellung“ ohne Seitenleisten-Befehl; ⌥⌘0 steht in keinem Menü. Lösung:
  (1) macOS-Szene `.commands { SidebarCommands(); ThaliaCommands(app: app) }`. (2) `AppModel.showsWeekSummary` nach dem
  Muster von `showsGlanceInspector` (Schlüssel `week.summary`, `UserDefaults.standard.object(forKey:) as? Bool ?? true` –
  `bool(forKey:)` drehte den Standard um; nicht in der Übung schreiben); WeekTable bindet daran (Zuarbeit P6).
  (3) „Gehe zu“ unter „Heute im Blick“ ⌘0 (bleibt dort, TESTING.md:96): „Wochenübersicht“ ⌥⌘0 (sidebar/tab = .week,
  umschalten). (4) Das Kürzel am Symbolleistenknopf fällt weg (P6). Abnahme (Mac): Darstellung → Seitenleiste
  ausblenden; ⌥⌘0 wirkt auch mit Knopf im Überlauf.
- [x] **P4.7 UIMAC-12** (niedrig) Menüleisten-Fenster: kein Widerrufen, Bestätigung bleibt ewig, PH-Bereich ≠
  PH-Fenster. Lösung: `confirmation` wird eine Zeile, die nach `addPowerHours`/`addExpense` sichtbar ist, solange
  `app.toasts.current?.id == lastToastID` (Text + „Widerrufen“ → `app.toasts.performUndo()`; ToastCenter räumt nach
  4,5 s); kein eigener Toast-Host (nähme Hauptfenster und Einstellungen die Toasts). Stepper und `fill` auf `0.25...16`
  (MenuBar.swift:100, :125) – eine „Zuletzt“-Kombination mit 10 PH wird nicht mehr still 8. Optional „Einstellungen…“
  über `@Environment(\.openSettings)` + `NSApp.activate()`. Abnahme (Mac): PH in der Menüleiste → „Widerrufen“ entfernt
  sie; Zeile verschwindet nach ~5 s; TESTING R96 anpassen (P1.22).
- [x] **P4.8 UIMAC-13** (niedrig) Mac-Einstellungen zeigen die iPhone-Anleitung für Kartenzahlungen. Lösung:
  SettingsView.swift:85 unter `#if os(macOS)`: „Auf dem iPhone: Kurzbefehle → Automation → Transaktion → Aktion
  „Ausgabe in Thalia“, Betrag = Betrag, Wofür = Händler. Die Zahlungen erscheinen dann auch hier.“; iOS unverändert.
  Kein Umbau in Reiter (→ Später). Abnahme: Mac-Screenshot `settings`.
- [x] **P4.9 BACKUP-13** (niedrig; KR2-17) Mac: kein Menübefehl für die Sicherung. Lösung: Ablage nach „Zeitraum als
  PDF…“: Trenner, „Sicherung erstellen…“ (ein Name überall, §1.6.5; ohne Kürzel), deaktiviert bei `isBlocked` oder
  offener Tour; arbeitet mit dem **echten** `app` (nie `commandTarget` = Übungsspeicher), `BackupWriter.exportText`
  (P3.11) → `app.backupFile`; Mac-RootView `.fileExporter` („Thalia Sicherung <Tag>“, `.commaSeparatedText`, Toasts
  „Sicherung gespeichert“ / Fehlertext), schreibt `backup.last` (P3.13). Kein „Sicherung einlesen…“ (das ist ⇧⌘I).
  Abnahme (Mac): Ablage → Sicherung erstellen… legt die CSV ab, „Letzte Sicherung … am Mac“ springt – auch am iPhone.
- [x] **P4.10 PERF-10** (niedrig, mit UIMAC-10) Der Menüleisten-Titel baut nach jedem Speichern die ganze Woche, auch
  mit ausgeschalteter Menüleiste. Lösung: `updateMenuBarTitle`: `guard !isSandbox, menuBarEnabled`,
  `weekContext(for:today:goalYear: false)` (`dayStatusText` braucht kein Zieljahr); der Setter von `menuBarEnabled`
  ruft beim Einschalten einmal auf; nur der didSave-Weg entprellt (300 ms, abbrechbare Task), andere Aufrufer sofort.
  Abnahme: Code-Review; Log: aus → kein Aufbau.
- [x] **P4.11 SYNC-5** (mittel, plausibel) Nach einem Hintergrund-Push läuft `afterSync` erst nach 1,5 s ohne
  Hintergrundzeit – Abend-Erinnerung trotz Abschluss am Mac. Lösung: neue Datei `BackgroundGrace.swift` (`#if os(iOS)`):
  höchstens eine `UIBackgroundTaskIdentifier`; `afterSyncSoon` beginnt sie nur, wenn keine läuft, beendet sie nur aus der
  Task, die `afterSync()` wirklich ausführte, oder im Ablauf-Handler (nie je abgebrochener Task). Im Import-Beobachter
  einmal sofort `clearRemindersOfClosedDays()` (entfernt nur Mitteilungen; `afterSync` wiederholt mit zusammengeführten
  Daten). Abnahme (Gerät): iPhone gesperrt, Tag am Mac kurz vor der Abend-Erinnerung abschließen → keine Erinnerung.
- [x] **P4.12 SYNC-8** (mittel, plausibel) Am Mac schaut Thalia nicht mehr in die App Group, sobald eine andere App vorn
  ist. Lösung (macOS, `startConnectedApps`): den didResignActive-Beobachter nicht registrieren; nach `monitor.start()`
  einmal `monitor.setActive(true)` – der 5-min-Takt läuft, solange der Prozess läuft; didBecomeActive → `setActive(true)`
  bleibt. iOS unverändert; App Nap darf strecken. Der Text „alle 5 Minuten, solange sie offen ist“ stimmt dann;
  CONNECTED_APPS §5 Frage 3 → Zuarbeit P8. Abnahme (Mac): Theo schreibt, Thalia im Hintergrund → Menüleiste spätestens
  nach 5 min aktuell.
- [x] **P4.13 SYNC-9** (niedrig, mit WATCH-16) Kein Zeichen, ob eigene Änderungen gesendet sind; der Notspeicher der
  Watch ist unsichtbar. Lösung: (1) AppModel beobachtet `NSPersistentCloudKitContainer.eventChangedNotification` selbst
  (Kit unverändert): `lastSent` (.export erfolgreich), `lastReceived` (.import) in UserDefaults, beobachtbar;
  Einstellungen → iCloud & Daten: „Gesendet: vor 1 Min. · Empfangen: vor 4 Min.“ (Stil `SyncDevice.seenText`).
  (2) Warnung nur, wenn verlässlich: Speichern synchronisierter Modelle (didSave-userInfo ohne HealthValue und
  `sync.seen.*`) älter als 15 min, seitdem kein erfolgreicher Export, Account verfügbar → orange „Letzte Änderung noch
  nicht an iCloud gesendet“. (3) Watch → Zuarbeit P8. Watch-SyncMonitor und Menüleisten-Zeile → Später. Abnahme
  (Gerät): Haken am iPhone → „Gesendet“ springt; 20 min Flugmodus → Warnung.
- [x] **P4.14 SYNC-10** (mittel) Siri, Kurzbefehle und Widget-✓ warten nicht auf den iCloud-Export (andere Geräte sehen
  es erst nach dem Öffnen). Lösung: `BackgroundGrace.holdForExport(after: saveDate, timeout: .seconds(20))` (App-Ziel,
  iOS): Hintergrundaufgabe, endet bei einem `.export` mit `startDate >= saveDate` und `endDate != nil`, bei Zeitablauf
  oder Ablauf; „fire and forget“ nach dem Speichern in `LogPowerHourIntent`, `LogMeasureIntent`, `AddExpenseIntent`
  (Zuarbeit P8) und in `AppModel.applyWidgetAction`; der Siri-Dialog kommt sofort. Nicht in Shared/WidgetActions.swift
  (die Erweiterung hat kein `UIApplication.shared`). SYNC.md-Grenze erst nach Gerätetest (P1.20). Abnahme (Gerät):
  iPhone zu, Ausgabe per Kurzbefehl → Mac zeigt sie, ohne dass die App offen war.
- [x] **P4.15 SYNC-19** (niedrig) „Geräte im Abgleich“: ein Menüleisten-Mac meldet sich nie, alte Installationen
  bleiben, Zeiten laufen nicht weiter. Lösung: `recordDeviceSeen()` am Ende von `refreshToday()` (Mac: jedes
  didBecomeActive; iOS schon auf 10 min begrenzt) und in `MenuBarContent.onAppear`; nie aus `afterSync` (sonst
  Ping-Pong). Zeilen in `TimelineView(.periodic(from: .now, by: 60))`; Geräte, 60 Tage nicht gesehen, in einer
  zugeklappten Gruppe „Früher“; optional „Entfernen“ (`writeSetting(key, nil)` + Speichern; ein aktives Gerät meldet
  sich wieder – auch `sync.build.<id>` mit löschen). Jede Zeile nennt die Version aus `sync.build.` („iPhone · 1.10.0 ·
  vor 2 Min.“); fehlt sie bei einem Gerät der letzten 30 Tage: „Thalia 1.9 – bitte dort aktualisieren. Bis dahin werten
  Mac und Watch abgeschlossene Wochen nicht selbst.“ (orange, P2.1 (d), KR1-9). Abnahme: Mac nur über die Menüleiste
  benutzt → aktuelle Zeit am iPhone; Gerät ohne `sync.build.` → Hinweis.
- [x] **P4.16 GAP-1** (hoch) Die „Wochenabschluss“-Erinnerung öffnet am Montag (oder bei einem anderen Wochentag) die
  neue, leere Woche. Lösung: `case "close-week"` ohne Argument → `argument.flatMap(WeekKey.init) ?? weekToCloseNow()`
  über `WeekKey.toClose(on: dayToClose(), isClosed:, hasData:)` (Zuarbeit P1, Linux-Test): Sonntag → diese Woche; sonst
  die Vorwoche, wenn sie Plan oder Archivdaten hat (`hasItems || archiveGrades != nil || recordedScore != nil`) und offen
  ist; sonst diese Woche (eine Urlaubswoche ohne Plan wird nicht angeboten). `CloseWeekForm`: bei `!closed && week ==
  today.week && today.weekday != .sunday` orange „Diese Woche läuft noch bis Sonntag.“ über dem Knopf (Zuarbeit P6;
  ein Samstag-Abschluss bleibt möglich). Datierte Wochen-Erinnerungen tragen ihre Woche ohnehin (P4.17). Abnahme:
  Core-Test der Regel (So; Mo mit offener Vorwoche; Mo mit geschlossener; Vorwoche ohne Plan).
- [x] **P4.17 WATCH-5** (niedrig, mit SYNC-4) Morgen-Erinnerung an Krank/Urlaub-Tagen; „Wochenabschluss“ kommt nach dem
  Abschluss (auch am Mac) und öffnet die geschlossene Woche. Lösung: Core (Zuarbeit P1): `morningRequests` (ids
  `thalia.morning.<JJJJ-MM-TT>`, 7 Tage, `morningDays` beachtet, entschuldigte Tage aus) und `weeklyRequests` (Woche der
  Erinnerung = Woche des Erinnerungstags bei Fr–So, sonst Vorwoche; ausgelassen, wenn sie abgeschlossen ist und die
  nächste einen Plan hat; abgeschlossen ohne nächsten Plan → „Nächste Woche planen“ / „Planungs-Prompt kopieren und den
  Plan importieren.“ mit Ziel `import`; sonst heutiger Text mit Ziel `close-week:<KW>`); `requests()` ohne
  Wiederholungen (`apply()` entfernt zuerst alle `thalia.*`). App: `ReminderScheduler.weekClosed(week)` entfernt
  anstehende und zugestellte `thalia.weekly.<KW>`, aus `AppModel.closeWeek` und `afterSync` für abgeschlossene Wochen;
  neues `AppModel.reopenWeek(_:)` (für P6.8) plant neu. TESTING: Morgen- und Wochen-Erinnerungen enden nach ~7 Tagen
  ohne Öffnen, wie die Abende. Abnahme: Tests neben `eveningRequests` (V7Tests); Gerät: Woche am Sonntagvormittag am Mac
  abschließen → keine 17-Uhr-Erinnerung; Krank-Tag → keine Morgen-Erinnerung.
- [x] **P4.18 GAP-2** (mittel) Notspeicher und kaputtes iCloud sind nur tief in Einstellungen sichtbar. Lösung:
  `SyncGerman.isPersistentProblem` (Zuarbeit P1); eine kompakte, nicht blockierende Zeile nur bei dauerhaften Zuständen
  (nie bei kurzen Netzfehlern oder Account `.unknown` beim Start, nie in `.demo`/Übung): `.memory` „Thalia kann gerade
  nicht speichern – Einträge gehen beim Beenden verloren.“ (rot, nicht wegklickbar); `.local` „Nur auf diesem Gerät –
  iCloud-Abgleich ist aus.“; kein Account „Nicht bei iCloud angemeldet – Thalia gleicht nicht ab.“; Speicher voll
  „iCloud voll – Thalia gleicht nicht mehr ab.“ (orange, je Start wegklickbar). Ort: iPhone über dem Inhalt (RootView),
  Mac Fuß der Seitenleiste und Menüleisten-Fenster; Tippen öffnet Einstellungen → iCloud & Daten. Watch: mit P4.13
  (Zuarbeit P8). „iCloud voll“ erkennt AppModel im vorhandenen `eventChangedNotification`-Beobachter
  (AppModel.swift:324) an `CKError.Code.quotaExceeded`, auch in `partialErrorsByItemID` (KR3-21: `SyncState.lastError`
  trägt nur den englischen Kit-Text, Vendor SyncStatus.swift:101); Merker `quotaExceeded` bis zum nächsten
  erfolgreichen Export. Signatur `SyncGerman.isPersistentProblem(mode:account:quotaExceeded:)`. Die Debug-Startoption ist
  eine eigene: `-FakeSyncProblem local|memory|quota`, gelesen in AppModel (`LaunchOptions` liegt in Vendor und bleibt).
  Abnahme: `-FakeSyncProblem local`, `memory` und `quota` zeigen je die Zeile.
- [x] **P4.19 GAP-3** (mittel) Die Übungsseite der Tour bietet Echtes an (Sicherung mit Übungsdaten, Import, Einstellungen
  mit echten Erinnerungen). Lösung: `SheetContent` (RootView.swift) zeigt bei `app.isSandbox` für `.importPlan`,
  `.importPast`, `.planWeek`, `.rangePDF`, `.trash`, `.archive`, `.settings` eine kleine `PracticeUnavailableView`: „In der
  Übung nicht verfügbar – nach der Tour mit deinen eigenen Daten.“ mit „Schließen“ (KR2-20: „Mehr“ gibt es nur auf
  iOS, TodayView.swift:3076/:3193, WeekView.swift:481) (deckt Menüs, „2 · CSV einfügen“ und Mac-Befehle);
  `.connectedApps` und die anderen Tour-Vorführungen bleiben (ConnectedApps.swift:1210-1220). Ablage-Befehle grau bei
  `app.tourModel != nil`. Heute-„Mehr“-Menüs → Zuarbeit P5. Abnahme: Tour → Mehr ohne Import; ⇧⌘I während der Tour grau.
- [x] **P4.20 STORE-5** (niedrig) „Beginn“ des Zieljahrs ändern versteckt alle Ergebnisse und Abschnitte; jede Eingabe
  schreibt vier synchronisierte Einstellungen. Lösung: Einstellungen → Jahresziele hält „Beginn“, „Ende“,
  „Zielüberprüfung“ lokal und speichert mit „Zieljahr sichern“ (Knopf nur bei Änderung – kein ungültiger Zwischenstand
  geht zu iCloud); Motto bei `.onSubmit` und beim Verlassen. Weicht „Beginn“ ab und gibt es Ergebnisse oder gespeicherte
  Abschnitte des alten Beginns: „Beginn des Zieljahrs ändern?“ / „3 Ergebnisse und 2 Abschnitte gehören zum Zieljahr ab
  1. Juni 2026. Mit dem neuen Beginn werden sie nicht mehr angezeigt – stellst du den alten Beginn wieder ein, sind sie
  zurück.“ / „Neues Zieljahr beginnen“ / „Abbrechen“. Speichern über `setGoalPeriod` (eine Änderung, P2.10).
  „Mitnehmen“ → Später. Abnahme (Gerät): Motto tippen schreibt bis zum Bestätigen nichts; Beginn ändern fragt.
- [x] **P4.21 KR2-8** (niedrig–mittel) Mac: „Jahresziel eintragen…“ und „Lesen…“ haben kein Kürzel
  (ThaliaApp.swift:176, :178) – die Abnahme „Mac ohne Maus“ von P7.4 geht so kaum. Lösung: ⌥⌘J „Jahresziel eintragen…“,
  ⌥⌘L „Lesen…“ in `ThaliaCommands` (beide in der App frei); `isBlocked`/`blocksSheetCommands` (P4.5) gelten mit.
  TESTING-Kürzelliste → P1.22. Abnahme (Mac): ⌥⌘L öffnet „Lesen“ mit vorgewähltem Buch und Fokus (P7.4), Zahl, ↩ trägt
  ein.

### P5 – Heute, Erfassen, Tag abschließen (Runde 3b)
Prüfung: `swiftc -parse`, Mac-CI; Screenshots `today`, `overview`, `focus`, `close-day`, `create`, `mac-today`; Gerät für
P5.12.

- [x] **P5.1 PERF-1** (mittel) Dieselbe Woche wird je Änderung 3- (iPhone) bis 7-mal (Mac) gelesen und gewertet. Lösung:
  `YesterdayBanner(today:style:context: WeekContext? = nil)`: ist `context.week == yesterday.week && context.today ==
  today`, `content(context)`, sonst eigener `WeekReader(week:today:goalYear: false)` (nur montags); Übergabe an
  TodayView.swift:151, :289, :363 und Glance.swift:151, :960. Kein globaler WeekCache (→ Später). Danach einen ✓ auf
  iPhone und Mac im TestFlight-Build messen (Instruments oder `os_signpost` um `WeekContext.init`); ein Cache nur, wenn
  ein Tipp dann noch > 30 ms Hauptthread kostet. Abnahme: Code-Review (Di–So ohne eigenen Banner-Leser); Mac-CI ohne
  neue Hänger-Hinweise.
- [x] **P5.2 PERF-17** (niedrig) „Heute im Blick“ liest dieselbe Woche zweimal (zweiter Leser nur für den PDF-Knopf).
  Lösung: ein Leser – `.toolbar { Schließen; PDFButton(kind: .day(day), context: context, title: "PDF") }` an `GlanceList`
  innerhalb des Leser-Blocks (Glance.swift:78-100); Titel und Ziele bleiben, wo sie sind. Mit P5.1 von 3 auf 1 Leser.
  Abnahme: Screenshot `overview` unverändert.
- [x] **P5.3 UIPHONE-7** (mittel) „Diese Woche noch“: Titel abgeschnitten, Quote bricht um. Lösung (nur
  `WeeklyOpenSection`, Glance.swift:688-713): Titel und Quote untereinander (`VStack`, Titel `.subheadline`
  `lineLimit(2)`, Quote `.caption .monospacedDigit() .secondary`), Quote ohne „ diese Woche“ („0 von 1“; bei
  entschuldigten Tagen „0 von 1 · Rest zählt halb (krank)“ statt des rätselhaften „· ½ krank“, Glance.swift:707-711,
  KR2-11). Kein `fixedSize`. Heute und Tag abschließen behalten ihren Text. Abnahme: Screenshot `overview` hell/dunkel.
- [x] **P5.4 UIPHONE-10** (niedrig) „Messwert eintragen“: flache Liste aller Messwerte, Feld ohne Fokus. Lösung:
  `MeasurePicker` mit „Heute“ (`applies && period != .week`) und „Diese Woche“ (wöchentliche und heute nicht fällige),
  je Zeile KeyBadge und aktueller Wert; `ContentUnavailableView` bleibt. `MeasureForm(autofocus: Bool = false)`, nur aus
  dem Picker true: `.onAppear { if autofocus && !isTime && !isText && !isWork && !isExpense && !isList { valueFocused =
  true } }`; direkte Aufrufe (Heute-Info, „Verlauf und Einträge…“) ohne Fokus. Gilt auch für Mac ⇧⌘E. Abnahme: Gerät:
  Feld hat Fokus nach der Wahl.
- [x] **P5.5 UIPHONE-11** (niedrig) „Tag abschließen“ sagt nicht, dass Leeres nicht zählt. Lösung: `heroSubtitle`
  (CloseDayView.swift:341-344): offen, nicht entschuldigt, `requiredBlanks` nicht leer → „Noch \(n) offen – zählen
  nicht mit“; unterer Knopf „Tag abschließen · \(n) bleiben offen“ (KR2-19: dasselbe Wort wie die Leiste darunter,
  „7 offen“); beide aus `requiredBlanks.count` (=
  `overall.blank`, R5). Kein Dialog (Abendablauf bleibt schnell). Abnahme: Screenshot `close-day`.
- [x] **P5.6 UIPHONE-13** (niedrig) VoiceOver-Lücken: tippbare Zeilen ohne Knopf-Merkmal, fester Text am Abschluss-Knopf,
  „tippen zum Eintippen“. Lösung: `.accessibilityAddTraits(.isButton)` + kurzer Hinweis („Öffnet die Notiz“ …) an
  TodayView.swift:2370 und :2820 (Hinweis dort vorhanden); WeekView/WeekTable → Zuarbeit P6, GoalsView → P7, RootView
  (`context.isClosed(day) ? "Tagesabschluss ansehen" : "Tag abschließen"`) → P4; TodayView.swift:1903 Label „\(title) in
  \(unit)“ ohne Hinweis. Tippverhalten unverändert. Abnahme: VoiceOver am Gerät (TESTING v11).
- [x] **P5.7 UIPHONE-14** (niedrig) Fokus und Wochenziele sagen an freien, Krank- und Urlaubstagen „heute noch nichts“.
  Lösung nur bei Wert 0: Fokus `dayLine` (Focus.swift:490-495) – entschuldigt → „\(label) \(context.excusedWord([day]))“,
  `!context.applies(measure, on: day)` → „\(label) frei“, sonst wie bisher; `WeeklyGoalRow.todayText`
  (TodayView.swift:2211-2213) ebenso mit `goal.measure`, nur bei Arbeit. Abnahme: Screenshot `focus` (Erholungstag) zeigt
  „heute frei“.
- [x] **P5.8 UIPHONE-15** (niedrig) „Eigene Wertung entfernen“ und „Wertung entfernen“ (Vergangene Woche) ohne
  Widerrufen. Lösung: `OverrideSheet` (CloseDayView.swift:612-614) merkt alte Note und Grund, zeigt nach dem Entfernen
  `app.toasts.show("\(category.key): eigene Wertung entfernt", symbol: "trash") { setOverride(…, score: old, reason:
  oldReason) }` (neuer Datensatz derselben Art), dann schließen; Vergangene Woche → Zuarbeit P3. Kein extra Dialog.
  Abnahme (Gerät): entfernen → Widerrufen bringt Note und Grund zurück.
- [x] **P5.9 UIPHONE-17** (niedrig) Uneinheitliche Texte. Lösung: `workText` (CloseDayView.swift:418) „Arbeitsfrei –
  keine PH nötig“; „…“ an „Vergangene Woche nachtragen“ und „Mehrere Wochen als PDF“ in beiden Heute-Menüs
  (TodayView.swift:3067-3068, :3184-3185); „IDs“, „Messwert-IDs“, „CSV-Block“ → Zuarbeit P3. Die Fokus-Kachel bleibt
  kompakt „Woche 23 / 22,4 PH“; „hinten“ wird „im Rückstand“ (§1.2.4, P1.10, P7.2). Abnahme: Screenshot `close-day`.
- [x] **P5.10 UIPHONE-18** (niedrig) Erfassen: „Fokus ansehen“ (nur Ansicht) steht oben, „Lesen“ weiter unten. Lösung
  (Editors.swift:1774-1797): Listen-Optionen in der Reihenfolge Lesen, Tag abschließen, Jahresziel eintragen, Punkt
  anlegen, Messwert anlegen, Wochenplan importieren, Fokus ansehen; die vier Kacheln bleiben, keine wechselnde Kachel.
  TESTING.md:93 gilt weiter. Abnahme: Screenshot `create`.
- [x] **P5.11 UIPHONE-20** (niedrig) Der Hero-Titel bricht im Datum um („Sonntag, 22. / November 2026“). Lösung:
  `heroTitle` in CloseDayView: „\(weekday.name), \(day).\u{00A0}\(Monat)“, Jahr nur bei einem anderen Jahr; Core
  `longLabel` bleibt (PDF, Prompt, Tests). Abnahme: Screenshot `close-day`.
- [x] **P5.12 UIMAC-3** (mittel; KR2-7) Tasten 1–4 wirken erst nach einem Mausklick und enden nach jedem
  Kategoriewechsel. Lösung: (1) **Sichtbare Auswahl vor dem ersten Tastendruck:** bekommt die Liste den Fokus ohne
  Auswahl, setzt `CategoryPage` `selectedItemCode` auf den ersten offenen Punkt (`nextOpenItem`-Regel) – er ist markiert,
  bevor „1“ wirkt (KR2-7: ein Tastendruck auf einen nicht markierten Punkt wäre blind; `handleKey` braucht heute
  `selectedItemCode`, TodayView.swift:1173); nach einer Taste den nächsten offenen auswählen. (2) `@FocusState
  listFocused` mit `.focused` an der auswählbaren Liste. (3) `AppModel.focusTodayPage` (Zuarbeit P4), gesetzt von
  `moveTodayPage` (⌥⌘↓/↑), den „Weiter: 1.2“-Knöpfen, **„Gehe zu → Heute“ ⌘1** (ThaliaApp.swift:199) und wenn das
  Hauptfenster auf Heute zum Hauptfenster wird; `CategoryPage.onAppear`/`onChange(of: app.focusTodayPage)`: `if
  selectable && app.focusTodayPage { listFocused = true; app.focusTodayPage = false }` – ein Klick in die
  Kategorienliste lässt den Fokus dort (↑/↓ blättert weiter). ⌫/Return/Escape und Zellen-Fokus der Woche → Später;
  TESTING.md:176 → P1.22. Abnahme (Mac): App aktivieren, ⌘1 – der erste offene Punkt ist markiert –, „1“ → erledigt,
  ohne Klick; ⌥⌘↓, dann 1 → ebenso.
- [x] **P5.13 UIMAC-14** (niedrig) Notizen lassen sich mit der Maus nur über ihr Fenster löschen. Lösung: Notizzeile
  (TodayView.swift:2357-2373) `.contextMenu { Bearbeiten… ; Löschen (destruktiv, app.trash([note])) }` wie alle anderen
  Wisch-Zeilen. Kein Hover-Modifier, kein `pointerStyle`, kein Kontextmenü an `CategoryListRow` (→ Später). Abnahme (Mac):
  Rechtsklick → Löschen mit Widerrufen.
- [x] **P5.14 DISPLAY-15** (niedrig) Mac-Liste zeigt bei einer vollständigen Kategorie ohne Wertung „100 %“ statt ✓.
  Lösung: `CategoryListRow` (TodayView.swift:877-888) `else if entry.isComplete { Image(systemName: "checkmark") …
  .help("Alles erfasst – heute nichts zu werten").accessibilityLabel("alles erfasst") }`; iPhone `CategoryPicker` (:812)
  dasselbe statt „–“; Wochentabelle behält „–“. Abnahme: Screenshot `mac-today`.
- [x] **P5.15 DISPLAY-17** (niedrig) Ausgaben genau am Limit: rotes „+0 €“ bei „< 50 €“. Lösung: `ExpenseGoal.init`
  (Expenses.swift:359) vergleicht in Cent; `target.isLimit && totalCents == limitCents` → bei `.below` „nicht unter
  50 €“ (rot), bei `.atMost` „Limit ausgeschöpft“ (orange) (KR2-28: ein rotes „am Limit“ war mehrdeutig); „noch X €“/„+X €“
  auf Cent-Basis; VoiceOver „genau 50 €, Ziel unter 50 €“. Core `Target.isMet` bleibt (Wertung). Abnahme: 20,10 + 29,90
  bei „< 50“ → „nicht unter 50 €“; bei „≤ 50“ → „Limit ausgeschöpft“.
- [x] **P5.16 SYNC-18** (niedrig) Reflexionsfelder in „Tag/Woche abschließen“ übernehmen Änderungen des anderen Geräts
  nicht und überschreiben sie beim Tippen. Lösung: `stored[f] = context.reflection(scope:field:)`;
  `.onChange(of: stored)`: Felder mit `answers[f] == loadedAnswers[f]` folgen still; bearbeitete Felder mit abweichendem
  gespeichertem Text bekommen „Am anderen Gerät geändert“ mit „Übernehmen“ (setzt Text und `loadedAnswers[f]`); sonst
  gewinnt wie heute der eigene Text. CloseWeekView → Zuarbeit P6. Abnahme (Gerät): Tagebuch am iPhone, Fenster am Mac
  offen → Mac zeigt den neuen Text.
- [x] **P5.17 GAP-10** (niedrig) Ein Zukunftstag lässt sich abschließen (morgen angesehen, Mond getippt). Lösung:
  `dayToClose(showing:)` → `if let day, day < today { return day }` (Zuarbeit P4, AppModel.swift:404-405) – heute und
  Zukunft fallen auf `closingDay`; `CloseDayForm` bei `day > app.today` (z. B. Link `close-day:<Zukunft>`) statt der
  Knöpfe „Abschließen geht erst am \(day.shortLabel).“ (KR2-16: „Morgen liegt in der Zukunft …“ sagte dasselbe
  zweimal), ⌘↩ wirkungslos. Abnahme (Gerät): zu morgen blättern, Mond → heutiger Tag.
- [x] **P5.18 KR2-9** (niedrig–mittel) Der Heute-Hero schneidet den Kategorietitel ab („1.1 Ernährung und…“, Screenshot
  `iphone-today-light`) – Hauptbildschirm, jeden Tag gesehen; Ursache `.lineLimit(1)` mit fünf festen Elementen dahinter
  (TodayView.swift:1229-1233). Lösung: Titel `.lineLimit(2)` und `.fixedSize(horizontal: false, vertical: true)`; die
  Elemente dahinter bleiben. (Aus P6.6, wo der Hero „blieb“.) Abnahme: Screenshot `today` zeigt „Ernährung und
  Gewicht“ ganz.
- [x] **P5.19 KR1-7** (mittel) Fokus allein schreibt einen eigenen Wert: `MeasureInput` speichert beim Verlassen des
  Felds (TodayView.swift:1897), sobald der Text mit zwei Stellen vom ungerundeten Wert abweicht (`guard parsed != value`,
  :1981) – Hinein- und Herausklicken bei 7,316 h legt einen eigenen Eintrag 7,32 an, der einen übernommenen Health-Wert
  dauerhaft (iCloud, Sicherung, Prompt) überdeckt. Lösung: `commit` vergleicht mit dem **gezeigten** Wert –
  `guard parsed != value.flatMap { Format.parse(Format.number($0)) } else { return }`; leeres Feld bei vorhandenem Wert
  löscht wie bisher. Die Nur-Lesen-Anzeige geteilter Werte am Mac → P9.3. Abnahme: Code-Review; Gerät: in ein Feld mit
  Health-Wert tippen und heraus → kein Eintrag.

### P6 – Woche, Abschluss, Rückblick, PDF (Runde 3b)
Prüfung: `swiftc -parse`, Mac-CI; Screenshots `week`, `weekly-goals`, `close-week`, `review`, `range-pdf`, `mac-week`;
Gerät für P6.11.

- [x] **P6.1 DISPLAY-4** (mittel) Eingefrorene Woche: Wochenblatt und Wochen-PDF zeigen eine neu gerechnete Note,
  Rückblick/Ziele/PDF-Bericht die gespeicherte – neben „ihre Wertung bleibt, wie sie ist“. Lösung nur für eingefrorene
  abgeschlossene Wochen (`context.isClosed && context.isFrozen`): `heroScore` (ArchiveCard.swift:80-82), `GoalBars`
  (`plan.finalGoalScoreMap[goal.key]`), Ring des Wochen-PDFs (PDFExport.swift:626) und Teilen-Bild zeigen
  `recalculatedScore` bzw. die gespeicherten Zielnoten. Laufende, offene, nicht eingefrorene Wochen bleiben live (P2.1
  wertet sie neu). `FrozenWeekNote` bekommt die zweite Zeile „Nach heutigem Stand: 7,41“ nur bei Abweichung ≥ 0,01 und
  wenn das Gerät Health-Wochen wertet (`scoresHealth`) oder die Woche keine Health-Werte liest (Zuarbeit P7,
  Segments.swift; „oder geteilt abgedeckt“ ergänzt P9.3). Kategoriezeilen bleiben live. Abnahme (Harness/Gerät):
  eingefrorene Woche ändern → Hero bleibt, Zeile „Nach heutigem Stand“.
- [x] **P6.2 DISPLAY-3** (hoch) PDF-Bericht „4/3 Wochen abgeschlossen“, Tage zählen Krank-Tage mit. Lösung: Wochen
  (RangePDF.swift:626-634): `finished = data.rows.filter { $0.line.isClosed || !$0.hasPages }.count`,
  `"\(finished)/\(data.rows.count)"`; `isFinishedWithoutPlan` entfällt; laufende Woche zählt offen. Tage: `WeekLine
  .closedDays` ohne entschuldigte (Zuarbeit P1, Reports.swift:873, Doc-Kommentar); `RangePDFData.closedCountedDays =
  planRows.reduce(0) { $0 + $1.line.closedDays }` statt `report.closedDays` (:636, :920). Abnahme: Test in `V8RangeTests`
  (Suite „v8 report over several weeks“, V8Tests.swift:699, KR3-25)
  (geschlossener kranker Donnerstag → `closedDays == 2`); Screenshot `range-pdf` „n/n Wochen“; TESTING-Schritt mit
  abgeschlossener Archivwoche.
- [x] **P6.3 DISPLAY-8** (niedrig, mit WATCH-19; KR2-21, KR3-14) „x/10 Ziele bewertet“, „je 10 %“, „10 Jahresziele“
  fest – falsch mit entschuldigten oder neuen Zielen. Lösung: (1) Rückblick: wie `excusedClosed` für abgeschlossene
  Zeilen mit `finalGoalsScored < goals.count` den `score.goalsTotal` über weekContext holen (wenige); „n/total Ziele
  bewertet“ nur bei n < total. (2) Texte ohne Zahl: CloseWeekView :262 – nur der erste Satz wird „Jedes Jahresziel zählt
  gleich viel.“, der Rest („Die Wertung misst Verhalten … Seit KW42 2026 gleich gewichtet …“) bleibt; PDF :655
  „Jahresziele · gleich gewichtet“, WeekView :149 / WeekTable :473 „Ziele gleich gewichtet“; Components.swift:326
  `.accessibilityLabel("Jahresziele, gleich gewichtet")` statt „Zehn Jahresziele, je 10 Prozent der Woche“; GoalsView
  :226 und Explainers.swift:50 („Jedes Ziel ist 10 %“ → „Jedes Jahresziel zählt gleich viel“) und :57 („9/10 Ziele
  bewertet“ → „z. B. „9 von 10 Zielen bewertet““) → Zuarbeit P7, Bericht „(gleich gewichtet)“ → P1, Widget „Alle
  Jahresziele gleich gewichtet“ und Beschreibung „Wochenwertung und deine Jahresziele“ → P8. Kein „je 9,09 %“.
  (3) Teilen-Bild „\(goals.count) Jahresziele“ (Sharing.swift:332). Balken nach Zielschlüssel → Später. Abnahme (nach
  Runde 3b): `grep -rnE "10 %|10 Prozent|[Zz]ehn Jahresziele" App Widgets` leer; Screenshots `review`, `week`.
- [x] **P6.4 DISPLAY-10** (niedrig) PDF-Bericht mischt Genauigkeit (Ring 6,81, Zeile 6,8; 7,95 erscheint als „8“). Lösung:
  `Format.score(score, outOf: false)` statt `oneDecimal` in `RangeBar.valueText` (:458), `RangeScoreChip` (:766),
  `RangeGoalCell` (:796) (Regel V6: bis zu zwei Stellen); `oneDecimal` nur für `PowerHoursCell` (:814); Zelle 19 pt mit
  `minimumScaleFactor(0.6)`, Chip 38 pt. Abnahme: Screenshot `range-pdf`.
- [x] **P6.5 DISPLAY-12** (niedrig, mit WATCH-10) Krank/Urlaub: Siri sagt „100 % erfasst, nichts offen“, das Teilen-Bild
  zeigt einen vollen Ring. Lösung: Intents → Zuarbeit P8 (erste Zeile in `sentence()`: `summary.isExcusedDay` →
  „Heute: \(excusedName) – der Tag zählt nicht. \(PH).“; `count == 0` und `score.days[today]?.due == 0` → „Heute ist
  nichts fällig.“; Rückgabewert bleibt, `IntentDescription` ergänzt „Ergebnis: nach dem Abschluss die Tageswertung
  (0–10), sonst der erfasste Anteil in %.“). Sharing: `ShareContent.ringText`/`ringCaption` (optional); `day()` bei
  `context.isExcused(day)` fill 0, „–“, `excusedName`; ShareCard nutzt sie. Abnahme (Gerät): Krank-Tag teilen → Ring
  „–“ mit „Krank“.
- [x] **P6.6 DISPLAY-13** (niedrig) Kategorienamen werden vom „✓ über 8“ abgeschnitten. Lösung: WeekView.swift:317
  `Text(context.title(of: category)).lineLimit(2).layoutPriority(1)`; die Zielkarte (GoalsView.swift:366) → Zuarbeit P7.
  Nicht `shortTitle` (verlöre den abschnittsgenauen Titel), kein Nur-Symbol (kollidiert mit dem Siegel geschlossener
  Tage). Der Heute-Hero hat eine andere Ursache (→ P5.18). Abnahme: Screenshot `week` dunkel.
- [x] **P6.7 GAP-4** (niedrig) Der Abschluss einer vergangenen Woche bietet „Nächste Woche · KWn+1 – Prompt kopieren /
  CSV einfügen“ für eine längst vergangene Woche an. Lösung: `planningSection` (CloseWeekView.swift:152-172) nur, wenn
  `next >= context.today.week`; sonst nichts. Montags nach der letzten Woche bleibt die Planung. Abnahme: Rückblick →
  alte Woche abschließen → keine Planung.
- [x] **P6.8 GAP-7** (mittel) „Woche wieder öffnen“: ein Tipp, keine Rückfrage, kein Widerrufen; in eingefrorenen Wochen
  ist die alte Note danach weg. Lösung: `CloseWeekView.reopen` ruft `app.reopenWeek(week)` (Zuarbeit P4): Schnappschuss
  (`ClosedWeekSnapshot`, Zuarbeit P2: `closedAt`, `finalScore`, `finalGoalScores`, `finalGoalsScored`,
  `categoryScores`), öffnen, Toast „\(week.label) wieder geöffnet“ mit Widerrufen (schreibt alles zurück, ohne
  `storeFinalScore`), Erinnerungen neu planen (P4.17). Bei `isFrozen` zuerst `confirmationDialog("\(week.label) wieder
  öffnen?")`: „Die Woche gehört zu einem früheren Abschnitt. Ihre Wertung \(score) wird beim erneuten Abschließen nach
  heutigen Regeln neu berechnet.“ Knopf `.borderless`, `.secondary` (nicht gleichrangig neben „Fertig“). Abnahme
  (Gerät): öffnen → Widerrufen stellt Note und Kategorie-Noten exakt her.
- [x] **P6.9 GAP-11** (niedrig) Das Wochen-Bild zeigt den Zwischenstand einer laufenden Woche als Endnote. Lösung:
  `ShareContent.week`: `subtitle: context.isClosed ? "Meine Woche" : "Zwischenstand"`, Ring-Unterschrift „bisher“ statt
  „von 10“ (über `ringCaption`, P6.5). Abnahme: Mittwoch teilen → „Zwischenstand“.
- [x] **P6.10 PERF-8** (niedrig) Rückblick baut im Body je offener Woche einen ganzen Kontext. Lösung: `let weeks =
  self.weeks` einmal je Body und an `unclosed`, `excusedClosed`, `chartPoints` übergeben; in beiden Schleifen
  `weekContext(for:today:goalYear: false)` (gelesen werden nur Note und `isExcused`); `archivedWeeks`: ein Abruf der
  PlanItem-Wochen aller Archivwochen in ein Set statt `items(week)` je Woche. Kein `@State`-Speicher (eine offene
  Vorwoche muss live bleiben). Abnahme: Screenshot `review` unverändert; Code-Review.
- [x] **P6.11 PERF-12** (mittel) Der bewegte Verlauf läuft dauernd mit 20 fps (Woche, Fokus, Mac-Panel); die
  Feier-Animation endet nie. Lösung: (1) `CelebrationView`: `@State finished`, `TimelineView(.animation(paused:
  finished))`, `.task { 2,3 s; finished = true }` – sichtbar gleich. (2) `AuroraBackground`: `paused: !isLive`, `isLive`
  = `scenePhase == .active` (iOS) bzw. zusätzlich `controlActiveState` `.key`/`.active` (macOS). (3) Ruhe nach 10 s auf
  Woche/Fokus/Mac-Panel nur nach §4 F13 (V12 wollte Bewegung). Abnahme (Mac-Gerät): Energieverbrauch von „Woche“ im
  Hintergrund ≈ 0.
- [x] **P6.12 PERF-14** (niedrig) Wochen- und Tages-PDF entstehen in einem Zug auf dem Hauptthread. Lösung:
  `static func make(_:context:progress:) async -> URL?` (PDFExport.swift:159-168): nach jeder Seite `progress(drawn,
  total)` und `guard await pause() else { pdf.closePDF(); return nil }` (`pause()` aus RangePDF.swift von `private` auf
  intern); `.task { url = await PDFExport.make(kind, context: context) { page = $0 } }` (:1509); solange `url == nil`
  „PDF wird erstellt … Seite x von y“; Schließen bricht ab. Rendern bleibt auf dem Hauptthread (ImageRenderer). Abnahme
  (Gerät): Woche als PDF → Fortschritt, Vorschau scrollt.
- [x] **P6.13 PERF-16** (niedrig) Das Mehrwochen-PDF lädt je Woche das ganze Zieljahr. Lösung: RangePDF.swift:1451
  `store.weekContext(for: week, today: today, goalYear: false)` – die Seiten lesen keine abschnittsgenauen Titel oder
  Ergebnisse. Abnahme: Screenshot `range-pdf` unverändert.
- [x] **P6.14 SYNC-13** (niedrig) Der Mac erklärt nur teilweise, was ihm fehlt (Wochentabelle, Ergebnisse, Wochennote).
  Lösung, alles hinter `context.isHealthElsewhere(measure, on:)` (P2 baut die Überladung; P9.1 macht sie für geteilt
  abgedeckte Tage falsch – dann verschwinden die Hinweise an einer Stelle): (1) `WeekTableValueRow`
  (WeekTable.swift:319-340): caption2 „aus Health am iPhone“ neben dem Titel, `.help(WeekContext.healthElsewhereHint)`
  an den Zellen. (2) `GoalResultRow` bekommt `usesHealthElsewhere` mit caption „Wert aus Health auf dem iPhone – hier
  ohne“ (Zuarbeit P7). (3) Nur laufende Woche auf Mac/Watch/iPad (`!scoresHealth`), wenn die Woche Health liest: unter
  dem Hero „Ohne Werte aus Apple Health – am iPhone kann die Wertung höher sein.“ („und nicht geteilt abgedeckt“ ergänzt
  P9.3). Keine neue DataFacts-Rubrik. Abnahme: Screenshot `mac-week` mit aufgeklappten Werten.
- [x] **P6.15 UIMAC-8** (niedrig) Woche-Symbolleiste schiebt „Wochenübersicht“ und „Erfassen“ in den Überlauf;
  „Erfassen“ mal mit, mal ohne Text; zwei Kürzel für „zurück zu jetzt“. Lösung: (1) Mac-WeekTable
  `.navigationTitle(context.week.label)` + `.navigationSubtitle(context.week.rangeLabel)` wie Heute
  (TodayView.swift:259) – ~100 pt frei; die drei Knöpfe behalten Text (R62). (2) **Ein** Befehl „Zu heute“ ⌘T in „Gehe
  zu“ (KR2-29: heute zwei Kürzel – „Diese Woche“ ⌘T am Knopf, WeekTable.swift:95, und „Zu heute“ ⇧⌘T,
  ThaliaApp.swift:224-225): auf Woche springt er zur laufenden Woche, sonst zu heute (Zuarbeit P4); ⇧⌘T entfällt,
  `.keyboardShortcut("t")` am Knopf und ⌥⌘0 (P4.6) am Knopf fallen weg, `.help("Zur aktuellen Woche (⌘T)")` bleibt;
  TESTING-Kürzel → P1.22.
  (3) Heute „Erfassen“ `.labelStyle(.titleAndIcon)` (Zuarbeit P5, TodayView.swift:3024-3031); Rückblick „PDF-Bericht“
  `.titleAndIcon` auf macOS (ReviewView.swift:19-26). Kein Split-Knopf, keine ControlGroup (Toolbar-Absturz Build 47).
  Abnahme: Screenshot `mac-week` bei 1024 mit sichtbarer „Wochenübersicht“; TESTING.md:180 → P1.22.

### P7 – Ziele, Leseliste, Verbundene Apps (Runde 3b)
Prüfung: `swiftc -parse`, Mac-CI; Screenshots `goals`, `goal-detail`, `goal-review`, `reading`, `connected-apps`,
`mac-goals`, `mac-goal-detail`, `mac-reading`.

- [x] **P7.1 STORE-2** (mittel, mit SYNC-6, UIPHONE-3; KR2-4, KR2-14) „Neu berechnen“ und Abschließen am Mac speichern
  eine Note ohne Apple-Health-Werte – in eingefrorenen Wochen für immer, ohne Hinweis. Lösung (§1.3), **entschieden für
  den schnellen Weg** (KR2-4 – „statt des Knopfs … zusätzlich darf“ ließ parallele Umsetzer Verschiedenes bauen):
  (1) Store (Zuarbeit P2): `recompute` speichert auf einem Gerät ohne `scoresHealth` für eine Woche, die Health liest,
  nichts, gibt false zurück und loggt; `requestRescore(_ week:, force: true)` schreibt die Anfrage. (2) `FrozenWeekNote`
  (Segments.swift) auf Mac/Watch/iPad für eine solche Woche: Zeile „Hier fehlen die Werte aus Apple Health.“ und Knopf
  **„Am iPhone neu berechnen“** → `requestRescore(week, force: true)`, Toast „KW44 wird nach dem Abgleich am iPhone neu
  berechnet.“; Wochen ohne Health-Fortschrittspunkte behalten „Neu berechnen“. (3) Wochenabschluss am Mac/auf der
  Watch/am iPad, wenn die Woche Health liest: Zeile unter dem Hero „Hier ohne Werte aus Apple Health gewertet – das iPhone
  rechnet nach dem Abgleich nach.“ (Zuarbeit P6) – stimmt jetzt, weil `closeWeek` dort eine `force`-Anfrage schreibt
  (P2.1 (b)); die Abschlusslogik bleibt (Schonfrist + iPhone). (4) iPhone: Toast mit beiden Werten „KW44: 7,84 → 8,02“ und
  „Widerrufen“ (das Wort der App, SheetChrome.swift:92; stellt `finalScore`, `finalGoalScores`, `finalGoalsScored`,
  `score.<Woche>` über `ClosedWeekSnapshot` her); kein weiterer Dialog. Geteilt abgedeckte Wochen (Knopf wie am iPhone)
  ergänzt P9.3. Abnahme: Mac: eingefrorene Woche mit Health-Punkt → Zeile und „Am iPhone neu berechnen“, keine lokale
  Note; iPhone nach dem Abgleich: neue Note; iPhone: Neu berechnen → Widerrufen stellt die alte Note her.
- [x] **P7.2 DISPLAY-9** (niedrig) Zwei Wortschätze und Farbschemata für denselben Status; die Zielüberprüfung ist ganz
  grau. Lösung (§1.2.4): (1) `GoalResultLine.statusKind` (Zuarbeit P1; nur im Speicher, der Prompt nutzt weiter den
  Text); `GoalReviewView.resultRow` (GoalsView.swift:1076-1078) färbt damit. (2) Eine Farbzuordnung `StatusTint` in
  Style.swift (Zuarbeit P4, mit `PaceStatus`) für Ergebnisse (statt `Status.tint`, App GoalResults.swift:280-287),
  `WeeklyTargetRow`, Fokus und PDF – nur nach Status, keine wertabhängige Zwischenfarbe (KR2-5). (3) Wörter (KR2-13):
  Ergebnisse „auf Kurs“/„im Rückstand“ (statt „hinten“: App GoalResults.swift:321, Explainers.swift:450; Core-Label und
  Tour → P1.10, P1.19), Grenzen „im Rahmen“/„zu schnell“/„überschritten“/„eingehalten“. Abnahme: Screenshot
  `goal-review` – „im Rückstand“ orange, „erreicht“ grün; `grep -rn "„hinten“\|\"hinten\"" App Packages` leer.
- [x] **P7.3 DISPLAY-14** (niedrig) Die Verlaufslinie der Zielkarte zeigt die laufende Woche wie eine abgeschlossene.
  Lösung: `history(for:)` (GoalsView.swift:148-150) `ScorePoint(week:score:isLive: true)`; die Sparkline behält die
  Füllregel (gefüllt ab 8 – passt zum Live-Abzeichen), zeichnet den Live-Punkt aber in `tint.opacity(0.45)` wie
  „laufend“ im Rückblick, optional letzte Strecke gestrichelt; `spokenText` „KW47 laufend 7,8“. Abnahme: Screenshot
  `goals`.
- [x] **P7.4 UIPHONE-1** (mittel, mit UIMAC-15) „Lesen“ und „Jahresziel eintragen“ öffnen immer auf „Bitte wählen“ mit
  einem Feld ohne Fokus (am Mac nie ohne Maus). Lösung: `ReadingProgressSheet` (ReadingList.swift:429-514):
  `@FocusState numberFocused`; `.onAppear`: ist nichts gewählt, das zuletzt gelesene **laufende** Buch vorwählen
  (`ReadingTexts.byLastReading(context.runningListItems, …).first`; nie ein geplantes – der erste Stand startet ein Buch
  bewusst), dann Fokus; `.onChange(of: chosenID)` setzt Fokus; am Feld `.onSubmit { save(context) }` (Mac) und
  `.keypadButton("Eintragen", isActive: numberFocused) { save(context) }` (iPhone-Ziffernblock, R31 – dort feuert
  `.onSubmit` nie). Auswahl bleibt änderbar. `GoalEntrySheet` (GoalResults.swift:764-810): vorwählen nur bei genau einer
  Wahl; bei `.count`/`.value` Fokus mit denselben Übergaben; kein „zuletzt benutzt“ (der Standard „1“ machte einen
  falschen Rat zum Ein-Tipp-Fehler). Keine Store-/Sync-Änderung. Abnahme (Gerät): Erfassen → Lesen → Zahl → Eintragen;
  Mac ohne Maus.
- [x] **P7.5 UIPHONE-2** (mittel) Die Zielüberprüfung am iPhone zeigt beim Gewicht „Wert nur auf dem Gerät“ statt des
  Werts. Lösung: Store (Zuarbeit P2) `resultLines(today:hidesHealth: Bool = true)` mit `hidesValue: hidesHealth &&
  resultUsesHealth(result)` – Prompt und Berichte behalten den Standard; `GoalReviewView`: `results` (verborgen) nur für
  `copyReport()`, neu `screenResults` aus `resultLines(today:hidesHealth: !HealthDevice.readsHealth)`; am Mac zeigt ein
  verborgener Wert `WeekContext.healthElsewhereHint` über `hiddenText:` (Zuarbeit P1). Abnahme: Screenshot `goal-review`
  mit Gewichtswert.
- [x] **P7.6 UIPHONE-4** (niedrig) Leseliste: Tippen auf ein laufendes Buch öffnet das Bearbeiten, „Fortschritt
  eintragen…“ steht ganz unten. Lösung: `ReadingListContent.row` (ReadingList.swift:274-304): laufend → Fortschritt
  (`.progress(itemID:day: app.captureDay)`), geplant/fertig/abgebrochen → `BookEditor`; bei laufenden „Bearbeiten“ statt
  „Fortschritt“ im führenden Wischen (geplante behalten „Fortschritt“); Kontextmenü bleibt;
  `.accessibilityHint("Fortschritt eintragen")`. Zusammenfassung „Gelesen in Abschnitt 2: 120 Seiten“ / „Gelesen im
  Zieljahr: …“ (einziger Aufrufer `summaryLine`, :255-258). Abnahme: Screenshot `reading`.
- [x] **P7.7 UIPHONE-12** (niedrig) Der Fuß der Zielseite nennt „Eintrag mit Datum…“, auch wenn es keinen solchen Knopf
  gibt. Lösung: Fuß (GoalResults.swift:464-468) aus dem Gezeigten: `quick = results.filter { quickAction != nil }`,
  `dated = quick.contains { $0.kind != .value }`; ohne quick, mit Listen-Ergebnis: „Bücher zählen über die Leseliste:
  fertig ist ein Buch mit der letzten Seite unter „Lesen“ oder mit „Fertig“ im Buch-Fenster.“; ohne quick ohne Liste:
  kein Fuß; sonst wie bisher plus `dated ? "; ein anderes Datum geht über „Eintrag mit Datum…“." : "; „Wert eintragen“
  fragt nach dem Datum."`. Abnahme: Screenshot `goal-detail`.
- [x] **P7.8 UIPHONE-16** (niedrig) Fuß „Wochen über 8“ spricht von 12 Wochen und zeigt 0/5. Lösung: `weeksFooter`
  (GoalsView.swift:738-741): „0/5 = Wochen ab 8,00 von 5 gewerteten – aus bis zu 12 abgeschlossenen Wochen \(scope).
  Krank- und Urlaubswochen zählen nicht.“ (KR2-26: „je Kategorie „über 8 / gewertet““ war rätselhaft; Zahlen aus der
  ersten Zeile). Regel ≥ 8,00 bleibt. Abnahme: Screenshot
  `goal-detail`.
- [x] **P7.9 UIPHONE-19** (niedrig) Die Zielflagge heißt „Woche abschließen“ und „Ergebnis“. Lösung: `flag.checkered`
  bleibt nur beim Wochenabschluss (WeekView :370, WeekTable :15/:602, CloseWeekView :115, ReviewView :238/:245,
  PastImport :217); Ergebnisse bekommen `trophy`: GoalResults.swift :520/:561/:889/:971/:1441, GoalsView :241/:386/:752,
  ConnectedApps :835, Explainers :251; Erfassen-Option Editors.swift:1787 → Zuarbeit P5; Tour-Schritt `goal-results`
  (ThaliaTour.swift:119) → P1.19 (KR3-15). Nicht `target` (= Ziele-Tab). Abnahme (nach Runde 3b): grep –
  `flag.checkered` nur an Abschluss-Stellen.
- [x] **P7.10 PERF-9** (mittel) Ziele-Seite: je Body ~16 Zieljahr-Abrufe und bis zu 20 Abrufe aller Wochen. Lösung:
  `GoalsContent.period` = `context.goalPeriod` (GoalsView.swift:27); die Ziel-Verläufe einmal je Body aus der
  vorhandenen `@Query plans`: `plans.latest(by: \.weekKey, modified: \.modifiedAt).values`, Wochen bis
  `context.week.adding(weeks: -1)`, `finalGoalScoreMap` je Plan einmal → `[goalKey: [WeekScorePoint]]`, an
  `history(for:)` und `recentAverage(for:)` (gleiche Regel und Reihenfolge wie `goalScoreHistory`). `excusedWeeks` bleibt.
  Kein `.task`/`@State` (die Karten bleiben live). `GoalReviewView` liest `goalPeriod` einmal je Body. Abnahme:
  Screenshot `goals` gleich; kein `allPlans()` mehr im Body.
- [x] **P7.11 SYNC-3** (niedrig) Ergebnisse mit Quelle `measure:`/`app:` (Gewicht, Vermögen aus Finn) aktualisieren
  nicht, wenn sich ein Wert ändert. Lösung: (1) `ResultSeriesReader` `.task(id: loadKey + "|\(app.syncTick)")`. (2)
  `ResultProgressTable.loadKey` (GoalResults.swift:244-249) mit Inhalts-Fingerabdruck statt Anzahlen: gespeiste
  `measure:`-Codes max(`modifiedAt`) und Wertsumme; `app:`-Quellen die `generatedAt` ihrer Tagesdateien; die
  Health-Anzahl bleibt drin (die geteilten Werte ergänzt P9.3). (3) `GoalHistoryCharts.loadKey` (GoalsView.swift:1277) +
  `app.syncTick`. GoalReviewView, ReportView, NoPlanView bleiben. Abnahme (Gerät): Gewicht am iPhone ändern, Ziele am
  Mac offen → neuer Wert nach dem Abgleich.
- [x] **P7.12 UIMAC-7** (niedrig) CI-Screenshots `mac-goal-detail`/`mac-reading` zeigen die Ziele-Seite. Lösung (nur
  Demo-Weg): `GoalsContent` `.task { guard app.launch.isDemo …; 1,5 s; openLaunchScreen() }` statt `.onAppear`;
  `GoalsLaunch.handled = true` erst im `.onAppear` von `ReadingListView`/`GoalDetailView` (hinter `isDemo`). Kein Umbau
  der Navigation. Abnahme: nächster CI-Lauf zeigt Zielseite und Leseliste; STATUS.md:92-94 → P1.22.

### P8 – Verbundene-Apps-Doku (Runde 1), Watch, Widgets, Siri (Runde 3b)
Prüfung: Runde 1 Doku-Abgleich mit den Fixtures von P1 (am Ende der Runde, nach dem Merge von P1); Runde 3b `swiftc
-parse` (auch `WatchWidgets/Sources` – `local-check.sh` prüft es nicht, KR3-25), Mac-CI (Watch/Widgets/Intents),
Screenshot `watch-today`, Gerät (Watch, Siri) für P8.5–P8.18. Plattformen (§0.10): `WidgetPublisher.swift` wird auch für
die Watch gebaut – `UIApplication` dort nur hinter `#if os(iOS)`; `Intents.swift` auch für macOS – `BackgroundGrace` hat
dort die leere Fassung aus P4.

**Runde 1 (Doku):**
- [x] **P8.1 E1 „Über 8“ = ab 8,00 (entschieden)** (Wunsch 1, §1.1): CONNECTED_APPS §5 Frage 1 → „Entschieden
  (23. Nov. 2026): ab 8,00, gerundet auf zwei Stellen“, §2 Schritt 10 entfällt; TASKS-v10 „Offene Fragen“ 1 und die
  Nachträge-Zeile „Annahme, siehe offene Fragen“ (TASKS-v10.md:94, KR3-16) → „entschieden“; STATUS (STATUS.md:89) →
  P1.22. Code unverändert (P1.15). Abnahme **nach Runde 5** (STATUS ändert sich erst dort): „8,01“ steht in den Docs
  (außer alten TASKS-Dateien) nur noch im Entscheidungssatz.
- [x] **P8.2 E2 Schonfrist und Notiz am abgeleiteten Haken (entschieden)** (Wunsch 2, §1.1): TASKS-v10 „Lückenschluss“
  – beide Absätze „von Bini bestätigt (23. Nov. 2026)“; CONNECTED_APPS §1 „Eigenes gewinnt“ um „Eine Notiz an einem
  abgeleiteten ✓ macht ihn zum eigenen – er bleibt, auch wenn die Tatsache später verschwindet.“; TESTING-Schritte →
  P1.22. Abnahme: Code-Review der Texte.
- [x] **P8.3 N1 Finn – alles einzeln wählbar, Vermögen bei jeder Änderung, Kontostände** (Wunsch 3, §1.5): CONNECTED_APPS
  §3.4 Finn-Auftrag neu – §2 „Was Finn liefert“ (je Zeile ein Schalter, Standard aus; Gruppen, Vermögen `aus`/`bei jeder
  Änderung` mit `nw-<Tag>`, Sparquote `aus`/`an` mit `sr-<Monat>`, Konten/Kontogruppen mit `account_balance` und
  `kb-<ref>-<Tag>`; Schalter in einem synchronisierten Einstellungs-Datensatz, nie UserDefaults), §4 Kennzahl-Tabelle
  (+ `account_balance`), §6 `source.json`-Beispiel mit `"kind":"account"`, §7 Katalog mit `results[].source` und die
  Anzeige „→ Thalia: …“ / „noch nicht in Thalia verknüpft“ / „Thalia hier einmal öffnen“ / „Thalia auf diesem Gerät
  aktualisieren“ (§1.5.3), §10 Test 8 neu (Schalter je Zeile, Vermögen je Änderungstag, Konto ein/aus, Katalog mit und
  ohne `source`), §11 „Schalter synchronisiert“; §1 Tabelle Zeilen Vermögen/Sparquote/Kontostand als Ergebnis-Quelle;
  §2 Schritt 5 „in Finn jede Zeile einzeln einschalten (Standard aus) – daneben steht, wofür sie in Thalia zählt“;
  §5 Frage 2 → entschieden. Die anderen Aufträge (Theo, George, Nina, Allgemein) bekommen dieselbe Kennzahl-Tabelle und
  das Katalog-Feld `source`; §4 „Für Entwickler“: `ExchangeFormat.swift` hat sich additiv geändert (Kennzahl, Katalog-
  Feld, toleranteres Lesen aus P1.1) – Apps, die die Datei kopiert haben, holen die neue Fassung; §5 Frage 3 bekommt den
  Satz aus P4.12. Thalia-Seite → Zuarbeit P1 (Core, Fixtures, `AppSource.resultOnlyKinds`), P7 (Ergebnis-Editor ohne
  „alle“ bei `requiresRef`; Messwert-Quelle in ConnectedApps.swift ohne die Ergebnis-Kennzahlen, Hinweis nur bei
  vorhandenen, §1.5.4). **Reihenfolge** (KR3-24): die Beispiele im Auftrag werden am Ende von Runde 1 aus den fertigen
  Fixtures von P1 kopiert (nicht parallel geschrieben); Tests können `docs/` nicht lesen (Package.swift kopiert nur
  `Fixtures`). Abnahme: die Beispiele im Auftrag sind Kopien der Fixtures; ein P1-Test vergleicht die Fixtures
  `Finn/exchange/*` und `Thalia/catalog.json` mit dem, was der Encoder schreibt; alle fünf Aufträge nennen dieselbe
  Tabelle.
- [x] **P8.4 WATCH-21** (niedrig) Die Doku verspricht Timer und Live Activity, die es seit v2 nicht mehr gibt. Lösung:
  ARCHITECTURE.md:33 „work (power-hours)“, :45 „WidgetBridge, WidgetPublisher, WidgetActions – Widget-Schnappschuss in
  der App Group, ✓ aus dem Widget“, :49 „+PH, „aus Theo““, :72 ohne „Live Activity“, :74 „Watch: Ring, Offen, Zähler,
  Power-Hours mit Bereich und Wofür, Messwerte“, :75 „Heute- und Woche-Widgets (Home und Sperrbildschirm),
  Kontrollzentrum (Erfassen, Power-Hours, Ausgabe), Watch-Komplikation“; WORKFLOW.md:18 „+ PH (50 min) mit Bereich und
  Wofür“, :37-39 Timer-Satz weg; README.md:14/25/44 ebenso; SETUP.md:21 ohne „Live Activity (widget extension)“;
  HANDBOOK_PROPOSALS.md:21 (Vorschlag 14 „Live Activity for a running timer“) als „entfällt – Thalia hat seit v2 keinen
  Timer“ markieren (KR3-16); STATUS „Architektur (Kurz)“ (STATUS.md:235) → P1.22. Ungenutzte Schemafelder (`isRunning` …)
  bleiben (TASKS-v2 U20). Abnahme (nach Runde 5): „Live Activity|WorkActivity|Timer“ in docs/README nur noch in alten
  TASKS-Dateien und im „entfällt“-Vermerk.

**Runde 3b (Code):**
- [x] **P8.5 WATCH-1** (mittel) Auf der Watch sieht ein ✓ aus einer verbundenen App aus wie ein eigener; ein Tipp
  entfernt ihn ohne Hinweis. Lösung: `WatchItemRow` (WatchHomeView.swift:355-389): caption2 `.secondary` aus
  `context.derivedMarkLabel(item, on: day)` („⇄ George · Push“); Tippen bleibt „leeren“ wie am iPhone
  (TodayView.swift:1516, v10 Grundregel 1 – eine Übernahme durch Tippen würde dieselbe Geste je Gerät verschieden
  machen); VoiceOver „Erledigt aus verbundener App – tippen zum Ausblenden“. `WatchMarkPicker`: dieselbe Zeile,
  „Haken der App ausblenden“ statt „Leeren“ bei `isDerivedMark`. `WatchMeasureRow.valueRow`: caption2 „aus <Quelle>“
  aus `context.valueSource`; solange der Tageswert aus einer App kommt, nur lesen (wie `listRow`, WatchValues.swift:
  173-174). Text inline (ConnectedAppsTexts liegt im App-Ziel). Abnahme (Gerät): Demo-Krafttraining zeigt „⇄ …“.
- [x] **P8.6 WATCH-4** (mittel) Auf Seite 1 lässt sich nichts direkt abhaken; Kategorieseiten mischen Erledigtes und
  Offenes. Lösung jetzt: Planreihenfolge bleibt (springende Zeilen am kleinen Bildschirm vermeiden); beantwortete Zeilen
  gedämpft: `WatchItemRow` Titel `.foregroundStyle(mark == nil ? .primary : .secondary)` (wie iPhone R36). Direktes
  Abhaken auf Seite 1 nur nach §4 F4 (dann unter „Offen“ höchstens 3 Zeilen der ersten Kategorie mit offenen Punkten,
  `WatchItemRow`, Zähler bleiben darunter). Abnahme: Screenshot `watch-today`.
- [x] **P8.7 WATCH-6** (mittel) Watch-PH: kein Widerrufen, keine Liste der heutigen Einträge. Lösung:
  `WatchPowerHourEntry.save`: `let block = store.addWork(...)`; `onSaved`/`WatchRouteView`/`powerHoursSaved` tragen
  (WorkBlock, Double, String); `WatchHomeView` `@State lastBlock`; Banner als Knopf „+1 PH · <Bereich> – Widerrufen“
  (das Wort der App, KR2-14),
  ~4 s (Schlaf 2 → 4 s): `store.trash([block])`, Klick-Haptik, „Power-Hours gelöscht“. `WatchPowerHourPicker`:
  Abschnitt „Heute erfasst“ aus `context.work(on: today)` (nur eigene, nicht „aus Theo“), Zeile „1 PH · 3.2 · Aufgabe“
  mit `.swipeActions` „Löschen“ (wiederherstellbar in „Zuletzt gelöscht“). Abnahme (Gerät/Watch).
- [x] **P8.8 WATCH-12** (niedrig; KR1-7) Der Kronen-Editor für Health-Werte startet bei 0 und endet bei 1000. Lösung:
  `healthRow` (WatchValues.swift:170-193, `openEditor` :205-209): Start = eigener Tageswert, sonst
  `store.lastValue(...)`; ohne Startwert nur Anzeige (kein Knopf), Hinweis `WeekContext.healthElsewhereHint`; Grenzen
  bleiben (R81). **„Sichern“ schreibt nur, wenn die Krone bewegt wurde** (Wert ≠ Startwert; heute ruft `save`
  `setDayValue` auch ohne Änderung, :211-214) – so wird ein angezeigter Wert nie still zum eigenen Eintrag. Geteilte
  Werte (Anzeige, Start) → P9.3. Abnahme (Watch): Gewicht ohne Wert → kein Editor; mit Wert → Start beim Wert;
  öffnen und „Sichern“ ohne Drehen → kein Eintrag.
- [x] **P8.9 WATCH-13** (niedrig) Watch-Zeilen ohne Ziel und ohne Wochenquote. Lösung: `valueRow` caption2 `.secondary`
  mit „ · “ verbunden: „Ziel \(target.label)“ und ggf. „aus <Quelle>“ (P8.5); grünes `checkmark.circle.fill` nur bei
  `Measures.isMet == true` (kein Orange – am iPhone ist „noch nicht“ neutral). `WatchItemRow`: aus
  `context.quotaProgress(item)` nur „\(done)/\(target)×“ als caption2 („2/3×“, ohne den Zusatz „· ½ krank“ aus
  `quotaText`, KR2-11), grün ab Ziel. Abnahme: Screenshot `watch-today`.
- [x] **P8.10 WATCH-14** (niedrig) Die PH-Bereiche auf der Watch zeigen keinen Wochenstand. Lösung:
  `WatchPowerHourPicker`: je Bereich das Wochenziel mit `.work(key)`-Quelle aus `context.weeklyTargets` → caption2
  „\(value)/\(Ziel) PH · Woche“ (skaliertes Ziel, wie das Widget), grün bei `isMet`. Abnahme (Watch).
- [x] **P8.11 WATCH-17** (niedrig) Leere Zustände ohne nächsten Schritt. Lösung: `WatchTodayPage` bei `!hasPlan` Zeile
  „Wochenplan am iPhone oder Mac importieren – danach kommt er über iCloud.“ (Status bleibt kurz „Kein Plan“); leerer
  PH-Picker: „Noch keine Bereiche. Öffne Thalia am iPhone und warte kurz auf iCloud.“ Widgets bleiben (sie öffnen schon
  „Heute im Blick“ mit Import); höchstens Medium-Überschrift „Kein Plan – tippen“. Abnahme: Watch-Vorschau.
- [x] **P8.12 WATCH-18** (niedrig) Der Schnappschuss trägt Tages-Messwerte und „diese Woche noch“, die nichts zeigt.
  Lösung: (1) `WidgetText.openHeading`/`largeStatus`: `openCount == 0 && weeklyOpenCount > 0` → „Alles Wichtige erfasst
  · diese Woche noch \(n)“. (2) Nur großes Widget: eine Zeile mit bis zu 3 Messwert-Chips („Zähler 3 / ≤ 6“) – dafür
  eine offene Zeile weniger; `todaySummary` stellt Tages-Summenzähler ohne Health voran (Zuarbeit P2); rot nur bei
  verfehltem Limit (≤/<), grün bei erfüllt, sonst neutral. (3) Komplikation unverändert (kein Punkt-Titel auf dem
  Zifferblatt). Kein Formatwechsel. Abnahme: Widget-Vorschau.
- [x] **P8.13 WATCH-3** (mittel, mit SYNC-11) Die Komplikation aktualisiert nur mit laufender Watch-App und zeigt Montag
  früh „Kein Plan“. Lösung jetzt: `widgetSummary` (Zuarbeit P2) schreibt keinen `nextDay` voraus, der eine neue Woche
  ohne Plan beginnt (`nextDay = (tomorrow.week != today.week && !nextContext.hasPlan) ? nil : [next]` – der
  `WeekContext`-Wert `hasPlan: Bool`, WeekContext.swift:232; `TodaySummary.hasPlan` ist `Bool?`, ThaliaTour.swift:233,
  KR3-23) – `resolved(for:)` fällt
  auf „Neuer Tag – Thalia öffnen“ zurück, iPhone-Widget wie Watch; Core-Test (Zuarbeit P1). Ein Hintergrund-Refresh der
  Watch allein brächte nichts (rechnet nur aus dem eigenen Speicher); der WatchConnectivity-Push vom iPhone nur nach
  §4 F6. Abnahme: Core-Test; Gerät: Sonntag vor dem Import → Montag „Neuer Tag“ statt „Kein Plan“.
- [x] **P8.14 WATCH-11** (niedrig, plausibel) Nach einem iCloud-Import wird der Schnappschuss sofort ohne zweiten
  Durchgang geschrieben. Lösung: Import-Beobachter (WidgetPublisher.swift:44-56) `publishNow(); publishSoon()` – Gleiches
  wird übersprungen (WidgetBridge.swift:49), kostet kein Reload-Budget; am iPhone bricht `afterSync.publishNow` das
  ausstehende ab. P8.14, P8.15, P8.16 und P3.2 (2) ändern denselben Beobachter – zusammen (KR3-22):
  `SyncProgress.noteImport(event)` (Beginn und Ende, P3.2); `guard finishedImport`; `isDirty = true` (P8.16); `#if
  os(iOS)`: `UIApplication.shared.applicationState == .active ? publishSoon() : { publishNow(); publishSoon() }`;
  sonst (Watch, Mac) `publishNow(); publishSoon()`. Abnahme (Gerät): Tag am iPhone abschließen → Komplikation
  „Abgeschlossen“ ohne Öffnen der Watch-App.
- [x] **P8.15 PERF-11** (niedrig) Das iPhone schreibt nach jedem Import den Schnappschuss doppelt. Lösung: iOS-Import-
  Beobachter aktiv nur `publishSoon()` (Code bei P8.14; Hintergrund-Weckruf behält das „sofort“ aus 1.6.1, `.inactive`
  zählt als Hintergrund); `afterSync` mit begrenztem Zusammenführen (P2.13);
  Ordner-Scan und Katalog bleiben (der Scan läuft schon abseits, der Katalog muss Änderungen anderer Geräte sehen).
  Abnahme: Code-Review.
- [x] **P8.16 PERF-18** (niedrig) Die Watch baut bei jedem Phasenwechsel zwei volle Wochen. Lösung: `WidgetPublisher`
  `isDirty` (gesetzt von didSave- und Import-Beobachter) und `lastDay`; `publishNow()` setzt beides; `publishIfNeeded()`
  = `isDirty || lastDay != DayKey.today()`; ThaliaWatchApp ruft bei **jedem** Phasenwechsel `publishIfNeeded()` (nicht
  nur `.background` – nach dem Senken bleibt die App oft in `.inactive`, SYNC.md 1.6.1). Abnahme (Watch): Heben/Senken
  ohne Änderung → kein Schreiben (Log).
- [x] **P8.17 WATCH-2** (mittel) Siri „Messwert eintragen“ speichert ohne Rückfrage 1 (Gewicht 1 kg, Schlaf 1 h).
  Lösung: (1) `@Parameter(title: "Wert", requestValueDialog: IntentDialog("Welcher Wert?")) var value: Double?` ohne
  Standard (Double → Double? hält gespeicherte Kurzbefehle mit Wert gültig). (2) `amount = value ?? (isPlainCounter ? 1
  : nil)` mit `isPlainCounter = ["", "stück"].contains(Units.normalized(unit)) && aggregation == .sum` (KR3-17:
  `Units.step` gibt für jede unbekannte Einheit 1, Vocabulary.swift:372-385 – „km“, „%“ bekämen still 1), sonst `throw
  $value.needsValueError("Welcher Wert für „\(definition.title)“ (\(Units.display(unit)))?")` → „Welcher Wert für
  „Gewicht“ (kg)?“ (KR2-15: „Wie viel Zweite Aufschläge?“ war falsch) – nur reine Zähler bekommen 1. (3) `measure`
  bleibt String (eine Entity bräche gespeicherte Kurzbefehle), mit `optionsProvider: MeasureOptions()` (wie
  `ExpensePurposeOptions`, Intents.swift:222-233) aus den Messwerten der Woche, für die `refusal(for:) == nil`. Abnahme
  (Gerät): „Messwert eintragen“ → Gewicht → Siri fragt „Welcher Wert für „Gewicht“ (kg)?“; ein Zähler ohne Einheit
  speichert 1.
- [x] **P8.18 KR2-10** (niedrig) Die Watch sagt an arbeitsfreien, Krank- und Urlaubstagen „Noch keine PH“
  (WatchHomeView.swift:232; `watch-today` zeigt es an einem Erholungstag) – P5.7 deckt nur das iPhone. Lösung: leere
  Arbeit → entschuldigt: `context.excusedName(today)` („Krank“/„Urlaub“, WeekContext.swift:428); arbeitsfrei
  (`DayTypes.isWorkFree`): „Arbeitsfrei“; sonst „Noch keine PH“. Abnahme: Screenshot `watch-today` (Sonntag)
  „Arbeitsfrei“.

### P9 – Health teilen (Runde 4, allein; HEALTHSHARE)
Prüfung: Harness (Typprüfung + Szenarien), Linux-Tests der Core-Datei (C14, von P1), Mac-CI mit Screenshot `health`,
Gerät (TestFlight-Build auf iPhone, Mac, Watch – §3.4.2). Jede geänderte Stelle trägt `// HEALTHSHARE` (§0.6). P9 ist das
einzige Paket der Runde und darf deshalb die Dateien der Runden 2–3 an den markierten Stellen ändern (§2.0).

- [x] **P9.1 N2 Health-Werte teilen – Shared-Kern** (Wunsch 4, §1.4; bisher P2.16; KR1-3, KR1-4, KR1-12, KR3-1, KR3-8)
  Lösung: neue Datei `Shared/HealthShareStore.swift`: `HealthShareGate` (drei Zustände `.allowed`/`.denied`/`.unknown`,
  Cache `thalia.health.shareGate`, `resolve(timeout:) async`, Benachrichtigung `changed`; Debug immer `.allowed`, dazu
  nur in Debug die Startoption `-HealthShareGate allowed|denied|unknown`, um Bereinigung und Offline-Start zu prüfen);
  `writeHealthShare(day:counted:read:)` (nur bei Änderung der dekodierten Werte, in `withoutUndo`),
  `writeHealthShareWindow(today:days:)` (`counted` aus den lokalen `HealthValue`), `stopHealthShare()` (§1.4.9, über die
  Präfix-Abfrage), `cleanUpHealthShare(gate:today:)` (`.denied`: alle `hshare.`, egal welches `by`, Zustand aus;
  `.allowed`: höchstens täglich `HealthShare.expired`), `healthShareState`, `healthShareCovers(_ week:)`,
  `healthShareWriterCheck()` (Zustand mit fremdem `by` → eigener Schalter aus). Markierte Stellen: WeekReader liest
  `hshare.state` und `HealthShare.keys(week:)` mit (zu `ArchiveWeek.settingKey`/`x.sources`, WeekReader.swift:55-56);
  WeekContext: ist das Tor `.allowed`, der Zustand an und dieses Gerät nicht der Schreiber, gehen `HealthShare.entries`
  (nur `by == state.by`, in `from…through`) als `health` in `WeekExtras` (WeekContext.swift:152, :194; eigene
  `HealthValue` je Code+Tag vor); `isHealthElsewhere(_:on:)` falsch für abgedeckte Tage (`countsAsMissing` nutzt es);
  `sharedHealthSuggestion(_:on:)` = `read` ohne `counted`; dieselben Werte in `weekContext(for:)`
  (TrackerStore.swift:110-131), `lastValue` (:661-679), `measureSeries`/`resultSeries`; `canScore` (P2.1)
  `|| healthShareCovers(week)`. Abnahme (Harness): iPhone-Speicher schreibt `counted` für 35 Tage und `read` nur für 3;
  Mac-Speicher rechnet dieselbe Wochennote wie das iPhone; Tag mit fremdem `by` oder außerhalb `from…through` zählt nicht;
  Tag älter als 35 Tage wird gelöscht; Zustand aus → Tage gelöscht, Mac zeigt den Hinweis; Tor `.unknown` → nichts
  geschrieben, gelesen oder gelöscht; Tor `.denied` → alle `hshare.` gelöscht, auch fremde; ⌘Z nach `adoptHealth` →
  `counted` ohne den Wert; Export (P3) ohne `hshare.`.
- [x] **P9.2 Schalter, Schreiber und Start** (§1.4.1, §1.4.2, §1.4.5, §1.4.6; KR1-8, KR1-18, KR3-1, KR3-9) Lösung:
  `App/Sources/HealthShareSettings.swift`: Abschnitt in HealthSettingsView (SettingsView.swift:447-480) nur bei
  `readsHealth` und `.allowed`; Schalter, Fuß und Übernehmen-Rückfrage nach §1.4.1. Schreiber: nach jedem `didSave`, das
  eine `HealthValue` enthält, die betroffenen Tage; beim Aktivieren alle 35 Tage (nur bei Änderung) und höchstens alle
  30 min `read` für 3 Tage über neues `HealthService.readValues(days:measures:) async -> [DayKey: [String: Double]]`
  (Services.swift; berührt `values` nicht, je Tag die Messwerte seiner Woche); beim Tageswechsel aufräumen;
  Selbstheilung und „auf einem anderen Gerät beendet“ nach §1.4.5. AppModel: Tor beim Start aus dem Cache, Neuprüfung
  abseits, `HealthShareGate.changed` → `syncTick` erhöhen; `cleanUpHealthShare` beim Start; Tour: `offerTourIfNeeded`
  wartet `await HealthShareGate.resolve(timeout: .seconds(2))` und baut dann `ThaliaTour.catalog(healthShare:
  HealthShareGate.isAllowed)` (AppModel.swift:675, :684, :690, :696 – nicht TourView, KR3-1). Watch: ThaliaWatchApp
  prüft das Tor ebenso, bereinigt bei `.denied`, zeichnet bei `changed` neu. `-DemoScreen health` (§1.8.2) und `health`
  in Config/ci.env (P1.21). Abnahme: Harness (zweiter Schreiber übernimmt, der erste schaltet ab; Selbstheilung nach
  gelöschtem Zustand; offline-Start mit `.unknown` löscht nichts); Screenshot `health`; Gerät §3.4.2.
- [x] **P9.3 Anzeige auf Mac, Watch und iPad – nur lesen** (§1.4.7, §1.4.8; KR1-7) Lösung: Heute (TodayView.swift:1696,
  :1738-1740): für einen `health:`-Messwert mit geteiltem Wert und ohne eigenen Eintrag statt `MeasureInput` der Wert mit
  caption „aus Health am iPhone“ und Knopf „Eigenen Wert eintragen…“ (öffnet `MeasureForm` mit leerem Feld); `read`
  ohne `counted`: „Health am iPhone: 72,6 kg – dort übernehmen“. Watch `healthRow` (WatchValues.swift:170-193): geteilter
  Wert mit caption2 „aus Health am iPhone“; die Krone startet beim eigenen, sonst geteilten, sonst letzten Wert und
  schreibt nur, wenn sie bewegt wurde (P8.8). Ergänzt „oder geteilt abgedeckt“ in `FrozenWeekNote` (Segments.swift: zweite
  Zeile P6.1; „Neu berechnen“ statt „Am iPhone neu berechnen“, P7.1), im Hinweis unter dem Hero (P6.14 (3),
  WeekTable.swift) und im `loadKey` der Ergebnisse (P7.11, GoalResults.swift: Anzahl und `modifiedAt` der geteilten
  Tage). Abnahme: Harness/Mac-CI; Gerät: am Mac in einen geteilten Schlafwert klicken → kein Feld, kein Eintrag;
  „Eigenen Wert eintragen…“ → eigener Wert gewinnt; Watch: Editor öffnen und „Sichern“ ohne Drehen → kein Eintrag.
- [x] **P9.4 Datenschutz-Texte** (§1.4.10; KR1-11, KR2-1, KR3-7) Lösung: solange `HealthShareGate.isAllowed &&
  healthShareState.on`, je markiert: SettingsView.swift:349 Titel „Bleibt auf dem Gerät – außer beim Teilen
  (TestFlight)“, Text „Übernommene Health-Werte bleiben auf diesem Gerät – außer „Health-Werte mit Mac und Watch teilen“
  ist an (nur TestFlight): dann liegen die letzten 5 Wochen in deiner iCloud. Was sonst synchronisiert, ist deine eigene
  Bewertung.“; SettingsView.swift:473 „Übernommene Werte gehen an Mac und Watch (Schalter oben, nur TestFlight).
  Ausschalten löscht sie aus iCloud.“; Editors.swift:468 „Übernehmen“; Editors.swift:471 „Ein Vorschlag, kein
  automatischer Eintrag. Übernommene Werte gehen an Mac und Watch (nur TestFlight); ein eigener Eintrag hat Vorrang.“;
  ConnectedApps.swift:1150 „Apple Health schlägt den Wert auf dem iPhone vor; bestätigt wird er hier. Übernommene Werte
  teilt das iPhone mit Mac und Watch (nur TestFlight).“ Sonst bleiben die heutigen Texte. Abnahme: Screenshot `health`
  (Demo mit Schalter an) zeigt die geänderten Texte; Schalter aus → die alten.
- [x] **P9.5 Doku und Checkliste** (kein Befund, §1.4.12) Lösung: Bericht an P1.22 mit STATUS-Absatz „Health teilen
  (nur TestFlight)“, SYNC-Zeile, TESTING-Schritten (§3.4.2) und der Checkliste „Vor App-Store entfernen“ mit den echten
  Stellen aus `grep -rn HEALTHSHARE`. Abnahme: jede Fundstelle des greps steht in der Checkliste und umgekehrt; der
  Abgleich aus §3.5 (Bezeichner ohne Marke) ist leer.

### 2.10 Zuarbeit (der Besitzer der Datei setzt es in seiner Runde um)
| macht | für | was (Datei) |
|---|---|---|
| P1 | P1.7 | `Target.label` im Bericht über `Format.amount(target:unit:)` (Reports.swift:172-174) – im eigenen Punkt |
| P1 | P2.1, P3.1, P3.4, P3.5, P3.7, P3.13, P4.16, P4.17, P4.18, P6.2, P6.3, P7.2, P7.5, P8.3, P8.13, P9.1 | Vertrag §2.1 „P1 baut“ (Core-Schnittstellen, Prompt-Texte, Fixtures, Tests) |
| P1 | P7.9 | Tour-Schritt `goal-results` mit `trophy` (ThaliaTour.swift:119) – in P1.19 |
| P2 | P1.1 | `storeInbox` überspringt `ExchangeInbox.value == nil`, nie „{}“ über eine gespeicherte Kopie (TrackerStore+Records.swift:846) |
| P2 | P1.7 | `scaledHint` über `Format.amount(target:unit:)` (WeekContext.swift:49) |
| P2 | P1.12 | `addPages` (TrackerStore+Records.swift:516) und `WeekContext.reached(_:through:)` (WeekContext.swift:1123-1125) über `ListMath.current`; `saveListItem` wertet bei geänderter `startAt` die Wochen der Seitenstände neu |
| P2 | P1.16 | `weekOver` (`isClosed || today > week.sunday`) an `weeklyPace`/`allWeeklyTargets` (WeekContext.swift:688-713) |
| P2 | P3.2 | `mergeImportedCopies()` in `mergeDuplicates` vor dem `importID`-Zusammenführen, immer voll; `mergeWork` setzt `modifiedAt` des neuesten statt `touch()`; `SyncProgress` (`sync.firstImportDone`) |
| P2 | P3.5, P3.16 | `mergeDuplicates` löscht veraltete Schlüssel doppelter ids und Vorlagen-Kopien nach der 1970-Regel aus P3.16 (4) |
| P2 | P3.4 | `planningPrompt` (TrackerStore.swift:195-217) reicht gesetzte Tage der Zielwoche an `PlanPrompt` |
| P2 | P6.8, P7.1, P7.5, P6.14 | Vertrag §2.1 „P2 baut“ |
| P2 | P8.12, P8.13 | `todaySummary`: Summenzähler ohne Health zuerst; `widgetSummary`: kein `nextDay` einer neuen Woche ohne Plan (`nextContext.hasPlan`) |
| P3 | P1.1 | Zählspalte `(1.0...7.0).contains(number)` vor `Int(number)` (PlanCSV.swift:581); Import-Weg überspringt nil (TrackerStore+Import.swift:97) |
| P3 | P1.3 | Ergebnis-Ziele aus `record`-Zeilen als `Target.parse(text)?.raw` speichern; CSV-Prüfung mit `strict: true` |
| P3 | P1.14 | Import-Kopf über `Format.count` (ImportPreview.swift:446-447); „1 Jahresziel“ (PlanCSV.swift:695) |
| P3 | P2.1 | Import-`apply` speichert mit `origin: .maintenance` |
| P3 | P2.7 | `apply` nimmt für vorhandene Schlüssel `ensurePlan`/`ensureDay` (TrackerStore+Import.swift:200-227) |
| P3 | P5.8 | `PastImport.removeScore`: Toast „KW45: Wertung entfernt“ mit „Widerrufen“ (`setPaperScore(previous)`, `refreshWeek()`) |
| P3 | P5.9 | „IDs“ (PastImport.swift:245, :332), „Messwert-IDs“, „CSV-Block“ (ImportView.swift:163) |
| P4 | P1.16, P7.2 | `StatusTint` in Style.swift (eine Farbzuordnung, nur nach Status) – Runde 3a |
| P4 | P1.21 | Config/ci.env: iPhone + `goals review close-week settings backup`, Mac + `review settings`; `-DemoScreen backup` und `settings` über `SettingsView(initialPage:)` |
| P4 | P2.1 | `processRescoreRequests()` in `afterSync` und in der 8-s-Startaufgabe |
| P4 | P2.2 | Toast „KW44: Auf diesem iPhone fehlen die Health-Werte von damals – die Wertung bleibt.“ für die Rückgabe von `processRescoreRequests()` |
| P4 | P2.4 | `afterSync`-Wartung und Nachtragen nach dem Start in `store.withoutUndo` |
| P4 | P2.5 | `setAll`/`applySuggestions` mit `[MarkSnapshot]`; danach `restoreMarks(_:day:)` entfernen (§0.9) |
| P4 | P2.6 | Papierkorb-Ansicht (SettingsView) fragt bei `restoreConflicts` mit Titeln |
| P4 | P2.9 | `lastSaveError`, Toast höchstens alle 10 min „Konnte nicht speichern – Details unter Einstellungen → iCloud & Daten“, Zeile „Letzter Speicherfehler: <Datum> – <Text>“ |
| P4 | P2.13 | `store.purgeExpired()` und `store.mergeDuplicates()` (AppModel.swift:211-212) aus `AppModel.init` entfernen; `maintenance(today:)` in der 8-s-Aufgabe; `afterSync` mit `mergeDuplicates(since:)` |
| P4 | P2.14 | `TodayAccessory` (RootView.swift:105) und `MenuBarContent` mit `goalYear: false` |
| P4 | P3.2 | `afterSync` ruft `cleanRestoreDuplicates()` |
| P4 | P3.13, P3.14 | Einstellungen „Deine Daten“: „Sicherung erstellen…“, „Letzte Sicherung … am <Gerät> · automatisch …“, Liste „Sicherungen“, Texte :356/:357; Auslöser beim Wechsel in den Hintergrund (nur iCloud/lokal, nach `firstImportDone`) |
| P4 | P3.16 | `AppModel.categoryTitle` über `latest(by:)` |
| P4 | P5.6 | Zubehör-Knopf „Tagesabschluss ansehen“/„Tag abschließen“ (RootView.swift:125-134) |
| P4 | P5.12, P5.17 | `focusTodayPage` (auch von ⌘1 und wenn das Hauptfenster auf Heute zum Hauptfenster wird); `dayToClose` mit `day < today` |
| P4 | P6.8 | `AppModel.reopenWeek(_:)` (Schnappschuss, Toast mit Widerrufen, Erinnerungen) |
| P4 | P6.15 | ein Befehl „Zu heute“ ⌘T in „Gehe zu“ (auf Woche zur laufenden Woche, sonst zu heute); ⇧⌘T entfällt |
| P5 | P1.7 | `amountsText` (TodayView.swift:2206), `targetLine` (Glance.swift:502) über `Format.amount` |
| P5 | P1.16 | Fokus `AreaRow` mit `PaceStatus`/`StatusTint` (Menge im Label, kein „von“), „Wochenziel“ statt „Soll bis heute“ in vergangenen Wochen; Heute-Chip orange bei hinten/offen (TodayView.swift:2150-2158), kurzes Label neben „x von y“ |
| P5 | P2.12 | `TodayContent`: `let pages = context.todayCategories(day)` einmal je Body |
| P5 | P2.14 | `SidebarGlance` (Glance.swift:898) und der Montags-Leser des `YesterdayBanner` mit `goalYear: false` |
| P5 | P3.16 | NoPlanView-Zeile: bei `isSyncing` „iCloud gleicht gerade ab – ein Plan von einem anderen Gerät kann gleich ankommen.“; bei `lastSync` älter als 10 min „Letzter Abgleich vor 2 Std. – ein Plan von einem anderen Gerät ist vielleicht noch unterwegs.“ (KR2-27) |
| P5 | P4.1 | Heute-Liste `maxWidth: 340`; Heute-Inspektor mit „passt“-Binding und Tooltip; Tagesring und Symbolleistenknopf über `app.showDayOverview` |
| P5 | P4.19 | Import, Nachtragen, PDF, Papierkorb, Einstellungen in beiden „Mehr“-Menüs bei `app.isSandbox` ausblenden |
| P5 | P6.15 | Heute „Erfassen“ `.labelStyle(.titleAndIcon)` |
| P5 | P7.9 | Erfassen-Option „Jahresziel eintragen“ mit `trophy` (Editors.swift:1787) |
| P6 | P1.7 | `WeeklyTargetRow` (Components.swift:725-726), PDF (PDFExport.swift:882) über `Format.amount` |
| P6 | P1.8 | PDFExport.swift:637 und `RangePDFWeeks.dateText` (RangePDF.swift:83-88) über `rangeLabelWithYear` |
| P6 | P1.16 | `WeeklyTargetRow` (Components.swift:729-741) und PDF `WeeklyTargetLine` (PDFExport.swift:885-889) mit `PaceStatus`/`StatusTint` |
| P6 | P1.17 | RangePDF-Köpfe „erste/letzte Wochen (je k)“, Trend „–“ |
| P6 | P3.13 | Wochenabschluss-Zeile „Letzte Sicherung vor 34 Tagen – jetzt sichern?“, nur wenn kein Gerät seit 30 Tagen von Hand gesichert hat (`backup.last`) |
| P6 | P4.1, P4.6 | Wochenübersicht-Inspektor mit „passt“ und `app.showsWeekSummary`; passt er nicht, öffnet der Knopf die Übersicht als Blatt; Kürzel am Knopf entfernen |
| P6 | P4.16 | `CloseWeekForm`-Zeile „Diese Woche läuft noch bis Sonntag.“ |
| P6 | P5.6 | Knopf-Merkmal an WeekView.swift:796 und WeekTable.swift:392 |
| P6 | P5.16 | Reflexionen in CloseWeekView folgen dem anderen Gerät |
| P6 | P7.1 | Wochenabschluss-Zeile „Hier ohne Werte aus Apple Health gewertet – das iPhone rechnet nach dem Abgleich nach.“ (`!scoresHealth`, Woche liest Health) |
| P7 | P1.2 | Durchschnitt der Zeitwerte (GoalsView.swift:1449-1452) mit `nightMinutes` |
| P7 | P1.10 | Ergebnis-Balken: Wörter „im Rahmen“/„zu schnell“/„überschritten“/„eingehalten“, Farbe nur über `StatusTint(statusKind)` (kein „gelb ab 85 %“, KR2-5) |
| P7 | P1.11 | Fuß im Buch-Fenster: „Ein Ergebnis wie „10 Bücher“ zählt alle fertigen Einträge seiner Art – dazu jeden, der ausdrücklich dafür zählt (z. B. ein Hörbuch).“ |
| P7 | P1.12 | Buch-Fenster „Schon gelesen bis Seite (optional)“, Fuß „Zählt nicht als gelesen – nur was danach dazukommt.“; `ReadingTexts.reached` `.pages` über `ListMath.current` |
| P7 | P1.15 | nur bei §4 F2 = „ab 8“: die App-Stellen aus dem grep (u. a. GoalResults.swift:328, Explainers.swift:505) |
| P7 | P1.17 | Zielüberprüfung „erste k Wo. 7,4 → letzte k Wo. 8,1“ bzw. „noch zu wenige Wochen für einen Trend“ |
| P7 | P5.6 | Knopf-Merkmal an GoalsView.swift:691 |
| P7 | P6.1 | `FrozenWeekNote` zweite Zeile „Nach heutigem Stand: …“ (Segments.swift) |
| P7 | P6.3, P6.6 | GoalsView.swift:226 und Explainers.swift:50 „Jedes Jahresziel zählt gleich viel“, Explainers.swift:57 ohne „9/10“; Zielkarte :366 `lineLimit(2)` |
| P7 | P6.14 | `GoalResultRow` mit `usesHealthElsewhere` |
| P7 | P8.3 | Ergebnis-Editor bietet bei `requiresRef` kein „alle“, die refs vom Typ `account` (GoalResults.swift:1327-1340); Messwert-Quelle (ConnectedApps.swift:1105-1145) ohne `AppSource.resultOnlyKinds`, Hinweis nur bei vorhandenen (§1.5.4) |
| P8 | P1.6 | im CI-Lauf prüfen, dass Komplikation und Widget-Zeilen „12,75 PH“ fassen |
| P8 | P1.7 | `WidgetText.targetAmount` (ThaliaWidgets.swift:143) über `Format.amount` |
| P8 | P2.14 | `WatchHomeView` (Watch/Sources/WatchHomeView.swift:21) mit `goalYear: false` |
| P8 | P2.15 | ForEach-id der Wochenziel-Zeilen im Widget eindeutig (Kategorie + Index) |
| P8 | P3.2 | Import-Beobachter in WidgetPublisher.swift ruft `SyncProgress.noteImport` (Beginn und Ende; App und Watch) – Code bei P8.14 |
| P8 | P3.16 | Intents.swift:95 über `latest(by:)` |
| P8 | P4.13, P4.18 | Watch Seite 1 bei `Persistence.shared.mode` `.local`/`.memory`: „Nur auf der Watch gespeichert – iCloud nicht verfügbar“ (caption2, orange) |
| P8 | P4.14 | `BackgroundGrace.holdForExport` nach dem Speichern in `LogPowerHourIntent`, `LogMeasureIntent`, `AddExpenseIntent` (macOS: leere Fassung) |
| P8 | P6.3 | Widget-Texte „Alle Jahresziele gleich gewichtet“, Beschreibung „Wochenwertung und deine Jahresziele“ (ThaliaWidgets.swift:640, :657) |
| P8 | P6.5 | `TodayStatusIntent.sentence()` und `IntentDescription` |
| P9 | P1.21 | `health` in Config/ci.env und `-DemoScreen health` – in P9.2 |

### 2.11 Später (bewusst nicht in v11)
- Gemeinsamer WeekCache (aus P5.1) – erst, wenn die Messung nach v11 noch > 30 ms je Tipp zeigt; eine eigene Revision
  kann CloudKit-Merges verpassen.
- Gleichwertige Zellzustände mit `.equatable()` in Woche/Heute (aus P2.11) – viel Arbeit, Gefahr veralteter Aktionen.
- Lebende Punkt-/Messwert-Kopien in `mergeDuplicates` zusammenführen (aus P2.6) – selten, Lesen nimmt schon die neueste.
- Wiederherstellen aus der Liste „Sicherungen“ (aus P3.13) – erst nach Erfahrung mit den Dateien.
- „Mitnehmen“ beim Ändern des Zieljahr-Beginns (aus P4.20) – nur, wenn Bini das braucht.
- Watch-SyncMonitor, Menüleisten-Zeile „iCloud: alles gesendet“ (aus P4.13), Mac-Einstellungen als Reiter (aus P4.8).
- ⌫/Return/Escape und Zellen-Fokus in der Woche, Hover-Rückmeldung am Mac (aus P5.12, P5.13).
- Widget- und Bild-Balken nach Zielschlüssel (`goalKeys` im Schnappschuss) (aus P6.3) – nur, wenn Bini Ziele umnummeriert.
- Allgemeines Umkehr-Dokument für jeden Import (aus P3.4) – groß, die eingefügten Zeilen deckt P3.4 (d) schon.

## 3. Tests und Abnahme

### 3.1 Core (Linux, `swift test --package-path Packages/ThaliaCore` in `swift:6.2-noble`)
- **P1 `V11Tests.swift`:** C1 Zahlen (P1.1) · C2 Zeitziele inkl. Tagesfenster „10:00–18:00“, „11:30–13:00“ (P1.2) ·
  C3 Zielwörter streng und nicht streng (P1.3) · C4 PH in Minuten (P1.4) · C5 Schlüssel alt = neu (P1.5) · C6 Einheiten,
  Rundung (`Format.amount(target:)` je Vergleich), Dativ/Einzahl (P1.6, P1.7, P1.14) · C7 Kalender (`rangeLabelWithYear`,
  `WeekKey.toClose`) · C8 Wochenquote bei leerem Buchungstag (P1.9) · C9 Ergebnisse inkl. „zu schnell“, „im Rückstand“
  (P1.10–P1.12, `progressText` mit `startAt`) · C10 Berichte (P1.13, P1.17 mit `window`, `WeekLine.closedDays`) · C11
  Tempo, kurzes und langes Label (P1.16) · C12 Erinnerungen (`morningRequests`, `weeklyRequests`) · C13 Datensätze
  (`decode` neueste je id; `rescore.`/`hshare.`/`sync.build.`/`backup.last` nicht in `SettingKeys.all`,
  `SettingKeys.week(of:)` nil; `SyncDevice.parse` unberührt) · C14 Health-Teilen (Fenster 35, `read` 3 Tage, `entries`
  nur `by == state.by` in `from…through`, `expired`, `covers`, Zustand aus → nichts) · C15 Finn (Kennzahl,
  `refChoices`, `requiresRef`, `resultOnlyKinds`, Katalog mit/ohne `source`, unbekannte Kennzahl bleibt „nicht
  verwendet“, Fixtures = Encoder) · C16 Tour 11 (3 bzw. 2 Schritte, „du/deine“-Test, `catalog` = `catalog(healthShare:
  false)`) · C17 `TodaySummary.resolved` ohne `nextDay`, `SyncGerman.isPersistentProblem(mode:account:quotaExceeded:)` ·
  C18 `SyncDevice.allCurrent` (Gerät ohne Build → nein; älter als 30 Tage → zählt nicht).
- **P3 `V11BackupTests.swift`:** Rundreisen (P3.1, P3.3 bitgleich mit 7,123456, P3.7, P3.8, P3.9), Vorschau
  (P3.4–P3.6), Leser (P3.10: doppelte Zeilen je Art, 52 Wochen mit lockerer Grenze), `referencedWeeks` (P3.12),
  `record`-Zeilen mit `hshare.`/`rescore.` werden abgelehnt, volle Sicherung enthält kein `hshare.`/`backup.last`.
- Bestehende Tests angepasst (V10Tests :246/:1002, CSVTests :372/:385 und Tour-Katalog, V7Tests Erinnerungen,
  `V8RangeTests` in V8Tests.swift:699, SyncDeviceTests); alle grün, Anzahl in STATUS.

### 3.2 Shared (Harness wie in v10)
Typprüfung der geänderten Shared-Dateien mit Platzhaltern und Verhaltensszenarien in einem eigenen Ordner unter dem
Scratchpad (nie im Repo): die Abnahme-Zeilen von P2.1–P2.15, P3.2, P3.3, P3.4, P3.7, P3.12, P3.13, P3.16 und P9.1–P9.3.
Besonders: Mac ändert Health-Woche per Eingabe → Anfrage → iPhone wertet; Eingang/Zusammenführen am Mac → keine Mac-Note
(KR1-6); Mac schließt alte Woche → `force`-Anfrage → iPhone wertet (KR1-5); Gerät ohne `sync.build.` → Mac wertet nicht
(KR1-9); `installedAt` unabhängig von der Aufrufreihenfolge (KR3-2); zwei 1970-Kopien → eine, gleiche uuid (KR1-1);
Original nach der Sicherung bearbeitet + Kopien von zwei Geräten → Änderung bleibt (KR1-2); Undo-Gruppierung mit
`withoutUndo` und leerer Undo-Stapel nach Vereinen (KR1-14); Health geteilt → Mac-Note = iPhone-Note; Tor
`.unknown`/`.denied` (P9.1).

### 3.3 Mac-CI und Screenshots
- Ende jeder Runde: `scripts/ci/local-check.sh` (Core-Tests + `swiftc -parse` für App, Shared, Watch, Widgets) und
  `swiftc -parse WatchWidgets/Sources/*.swift` (das Skript prüft den Ordner nicht); neue Dateien
  (`HealthShareStore.swift`, `HealthShareSettings.swift`, `BackgroundGrace.swift`, `Backups.swift`) mitprüfen.
- Runde 3a: ein CI-Lauf mit der Debug-Breitenmessung (P4.1 (1)); `mac-log.txt` nennt die Breiten.
- Fallen wie TASKS-v7 §6.6 (lange `??`-Ketten im Body, `Section(…) footer:`, Plattform-APIs nach §0.10 gekapselt).
- `[screenshots]` nach Runde 3b (Bildschirmliste aus P4): iPhone `today`, `overview`, `focus`, `expenses`, `work`,
  `week`, `weekly-goals`, `close-day`, `close-week`, `create`, `goals`, `goal-detail`, `goal-review`, `review`,
  `reading`, `connected-apps`, `settings`, `backup`, `range-pdf`, `past-import`, `archive`; Mac `today`, `week` (1024:
  ganze Seitenleiste, vier Knöpfe, „Wochenübersicht“ sichtbar), `goals`, `goal-detail`, `reading`, `review`,
  `settings`, `close-day`, `overview`; Watch `today`. Nach Runde 4 zusätzlich iPhone `health`. Keine leeren Bilder;
  `mac-log.txt` ohne `WeekExtras ==`-Stapel und ohne neue Hänger.

### 3.4 Gerät (TESTING.md „v11 (ab Version 1.10.0)“, geschrieben von P1.22)
1. **Zuerst alle Geräte auf 1.10.0** (iPhone, Mac, Watch, ggf. iPad). Vorher prüfen: solange ein Gerät 1.9 hat, zeigt
   „Geräte im Abgleich“ den Hinweis und der Mac wertet abgeschlossene Wochen nicht selbst.
2. **Health teilen (TestFlight):** iPhone → Einstellungen → Apple Health → Schalter an → Mac und Watch zeigen Gewicht und
   Schlaf mit „aus Health am iPhone“, die Wochennote am Mac = iPhone, kein „Wert aus Health auf dem iPhone“; in einen
   geteilten Wert am Mac klicken → kein Eintrag; Gewicht am iPhone übernehmen und mit ⌘Z/Schütteln widerrufen → Mac nach
   dem Abgleich ohne den Wert; Datenschutz-Texte zeigen die TestFlight-Fassung; iPhone im Flugmodus starten → nichts
   gelöscht; zweites Gerät (iPad) einschalten → Rückfrage, das erste schaltet ab; Schalter aus → Mac zeigt wieder den
   Hinweis, App-Protokoll meldet gelöschte Tage; Debug-Build mit `-HealthShareGate denied` am Mac → alle `hshare.` weg,
   das iPhone schaltet ab. Checkliste „Vor App-Store entfernen“ steht in TESTING und STATUS.
3. **Neuwerten:** Mac ändert eine Woche 5 Wochen zurück → iPhone wertet nach dem Abgleich (Rückblick); Mac schließt eine
   alte Woche → iPhone wertet sie nach; eingefrorene Woche am Mac → „Am iPhone neu berechnen“; neu installiertes iPhone
   senkt keine alten Noten (auch nicht auf Anfrage, Toast).
4. **Mac:** Fenster 1180 und 900 pt mit/ohne Inspektoren, Seitenleiste ziehen (kein Flackern), bei 1024 pt ⌘0 → Blatt;
   ⌘W + ⌘N, Einstellungen vorne + ⌘↩, Erinnerung bei geschlossenem Fenster; App aktivieren, ⌘1, „1“ ohne Klick; ⌥⌘L,
   ⌥⌘J; ⌘T auf Woche und Heute; Menüleiste „Widerrufen“; Theo im Vordergrund, Thalia liest im Hintergrund; ⌘Z nach 10 min
   widerruft den Haken, nicht die Wartung; ⌘Z nach einem Vereinen (R28-Fall) tut nichts.
5. **Erinnerungen:** Krank-Tag ohne Morgen-Erinnerung; Woche am Sonntagvormittag abgeschlossen → keine 17-Uhr-Erinnerung;
   Montag die Sonntags-Erinnerung tippen → Vorwoche; iPhone gesperrt, Tag am Mac abgeschlossen → keine
   Abend-Erinnerung.
6. **Siri, Widgets, Watch:** „Messwert eintragen“ fragt „Welcher Wert für „Gewicht“ (kg)?“; Ausgabe per Kurzbefehl bei
   gesperrtem iPhone erscheint am Mac; Krank-Tag: „Stand des Tages“ und Teilen-Bild; Watch: „⇄ …“-Zeile, PH Widerrufen,
   „Arbeitsfrei“ am Sonntag, Kronen-Editor ohne Drehen schreibt nichts, Komplikation „Abgeschlossen“ ohne Öffnen, Montag
   „Neuer Tag“ statt „Kein Plan“.
7. **Sicherung:** „Sicherung erstellen…“ am iPhone → am Mac „Letzte Sicherung … am iPhone“; nach einer Woche liegt eine
   datierte automatische Datei vor; auf einem frischen Gerät warnt der Import, bis der ganze erste Abgleich fertig ist
   (Merker erst nach 60 s ohne weiteren Import); Jahres-Sicherung ohne Einfrieren; Original nach der Sicherung
   bearbeiten, dieselbe Sicherung auf zwei Geräten einspielen → die Änderung bleibt.
8. **Finn:** nach Finns Build: jede Zeile einzeln schaltbar mit „→ Thalia: …“; Vermögen ändert sich → Thalia-Ergebnis
   „Vermögen“ am selben Tag; ein Konto → Ergebnis mit Quelle „Finn · Kontostand · <Konto>“; der Messwert-Editor bietet
   Vermögen und Kontostand nicht an.

### 3.5 Regeln
- `tools/schema-from-models.py Shared/Models.swift HealthValue` unverändert; `git diff --stat Shared/Models.swift` leer.
- `git status --porcelain Vendor scripts/ci` leer; keine Namen von KI-Modellen im Repo; keine echten Namen, Beträge,
  Gewichte, Ziele in neuen Texten, Tests, Fixtures.
- `grep -rn HEALTHSHARE` listet genau die Stellen der Checkliste §1.4.12; jede Fundstelle von
  `grep -rnE "HealthShareGate|healthShareCovers|sharedHealthSuggestion|HealthShare\.|hshare\." App Shared Watch
  Packages` hat höchstens drei Zeilen darüber `// HEALTHSHARE` (P9.5).
- Nach Runde 5: Doku-Greps aus P8.1 („8,01“), P8.4 („Live Activity“), P6.3 („10 %“), P7.9 (`flag.checkered`), P7.2
  („hinten“), P3.14 („Alles als CSV“).
- Jeder Punkt dieses Plans abgehakt; Abweichungen unten als „Nachträge“ wie in v10.

## 4. Offene Fragen an Bini
Jede Frage hat einen Vorschlag und eine Regel ohne Antwort, damit v11 nicht wartet (KR2-24).
1. **F1 – iPad oder zweites iPhone?** Ein iPad wertet ab v11 abgeschlossene Health-Wochen nicht selbst (wie der Mac,
   P2.1). Nutzt du Thalia auf einem iPad oder zweiten iPhone und übernimmst dort Health-Werte – soll es dann selbst
   werten? Vorschlag: nein. Ohne Antwort gilt: iPad wie Mac. Bei „ja“: `health.scorer` (P2.2).
2. **F2 – „über 8“ oder „ab 8“?** 8,00 zählt (entschieden). Soll das Abzeichen weiter „✓ über 8“ heißen (dein Begriff)
   oder überall „ab 8“? Vorschlag: „ab 8“ – passt zur Regel und zur Tour. Ohne Antwort gilt: „✓ über 8“ bleibt, Fußnoten
   und Tour sagen „ab 8,00“ (→ P1.15, dann alle Stellen aus dem grep auf einmal).
3. **F3 – Mac: „Schließen“ statt ×?** (UIMAC-9) Am Mac steht unten in 22 Fenstern nur ein × in einer blassen Kapsel
   (R73: überall das System-×). Soll dort am Mac „Schließen“ stehen (iPhone bleibt beim ×) – außer im Tages- und
   Wochenabschluss, wo das × bleibt, damit „Schließen“ nicht neben „Abschließen“ steht? Bei „ja“: nur `SheetCloseButton`
   (`#if os(macOS)` Text, Parameter `symbolOnly` für CloseDay/CloseWeek), kein „Fertig“, R73-Zeile in TESTING anpassen.
   Vorschlag: ja. Ohne Antwort gilt: × bleibt.
4. **F4 – Watch: direkt auf Seite 1 abhaken?** Offene Punkte direkt auf Seite 1 (dann rutschen die Zähler weiter nach
   unten) oder reicht der Sprung zur Kategorie mit einem Tipp? (→ P8.6) Vorschlag: der Sprung reicht (P8.6 dämpft
   Erledigtes). Ohne Antwort gilt: so.
5. **F5 – Notizen und Lesen auf der Watch?** (WATCH-7) Willst du am Handgelenk Notizen diktieren (Beobachtung, Auslöser,
   Erfolg, Kontakt, Idee) und/oder Seiten mit „Lesen“ eintragen? Die 1.9.0-Regel sagt, Seiten nur über „Lesen“ am
   iPhone. Bei „ja“: Seite 1 „Notiz“ (Diktat, Art, Sichern mit Widerrufen) bzw. Buchwahl + Krone „bis Seite“ über
   `addReading`. Vorschlag: zuerst „Lesen“ (kurz, oft), Notizen danach. Ohne Antwort gilt: nichts davon in v11.
6. **F6 – Ist die Komplikation zu alt?** Zeigt sie nach Haken am iPhone/Mac im Alltag zu lange alte Stände? Dann baut v12
   den Push vom iPhone zur Watch (WatchConnectivity, gedrosselt auf ~50 am Tag) (→ P8.13). Vorschlag: zwei Wochen mit
   P8.13/P8.14 beobachten, dann entscheiden. Ohne Antwort gilt: kein Push.
7. **F7 – Siri: Notiz, Seiten, Abhaken – auch auf der Watch?** (WATCH-8) Was willst du per Stimme erfassen? Vorschlag in
   dieser Reihenfolge: „Notiz in Thalia“ (Text, Art), „Gelesen in Thalia“ (laufendes Buch, bis Seite); Abhaken per
   Stimme eher nicht (zu viele lange Titel). Für die Watch kämen die Intents in eine Datei für alle drei Ziele. Ohne
   Antwort gilt: nichts davon in v11.
8. **F8 – Sperrbildschirm:** (WATCH-20) Sollen Punkt-Titel und Tagesnotiz auf dem gesperrten iPhone (Sperrbildschirm,
   StandBy) ausgeblendet werden? Ring, Anzahl offen und PH bleiben sichtbar; mit Face ID siehst du sie wie bisher. Bei
   „ja“: `.privacySensitive()` an Titelzeile, offenen Zeilen und Notiz im Widget (die Watch zeigt keine Titel).
   Vorschlag: ja (Titel und Notizen sind privat, Ring und PH reichen). Ohne Antwort gilt: wie bisher sichtbar.
9. **F9 – Größere Schrift?** (GAP-9) Hast du am iPhone eine größere Textgröße eingestellt? Dann bekommen Woche und
   Rückblick mitwachsende Schriften und Zellen (`@ScaledMetric` für Schrift **und** Zellgröße). Vorschlag: nur bei „ja“.
   Ohne Antwort gilt: bleibt.
10. **F10 – „Stand des Tages“ im Kurzbefehl?** (GAP-12) Nutzt du den Rückgabewert der Aktion in einem Kurzbefehl? Heute
    ist er vor dem Abschluss ein Prozentwert, danach die Note. Bei „ja“: immer Prozent, die Note als eigene Aktion
    „Tageswertung“ (ohne die 10 App-Kurzbefehle zu berühren). Vorschlag: bleibt, die Beschreibung erklärt es (P6.5).
    Ohne Antwort gilt: bleibt.
11. **F11 – „Jänner“ oder „Januar“?** (GAP-13) Datumswähler und PDF-Fuß schreiben österreichisch („Jänner“, „Jän.“), alle
    anderen Texte „Januar“ – die App setzt für Datumsformate bewusst `de_AT` (Style.swift:52, PDFExport.swift:419),
    `DayKey.monthNames` sagt „Januar“ (Calendar.swift:181). Eine Form für alles – welche? Vorschlag: „Jänner“ überall
    (passt zum gesetzten `de_AT`; nur `monthNames` und ihre Tests ändern sich). Ohne Antwort gilt: bleibt gemischt.
12. **F12 – Sicherungen sichtbar?** Sollen die wöchentlichen Sicherungen auch in der App „Dateien“ (Auf meinem iPhone →
    Thalia) erscheinen und/oder zusätzlich in iCloud Drive liegen? Beides braucht eine Info.plist- bzw.
    Capability-Änderung (→ P3.13). Vorschlag: „Dateien“ ja (`UIFileSharingEnabled` und
    `LSSupportsOpeningDocumentsInPlace`), iCloud Drive nein (die Daten liegen schon in iCloud). Ohne Antwort gilt: nur
    Application Support.
13. **F13 – Bewegter Verlauf:** Soll der bewegte Farbverlauf auf Woche, Fokus und der Mac-Seitenleiste nach etwa 10
    Sekunden zur Ruhe kommen (bei Abschlüssen bleibt er bewegt)? (→ P6.11) Vorschlag: ja. Ohne Antwort gilt: bleibt
    bewegt (im Hintergrund pausiert, P6.11).

## 5. Verworfen
- **STORE-15** – Das Nachtragen fasst nur Wochen ohne `score.` an; diese Zeilen kommen per Sync, die Lücke entsteht in
  Binis Aufbau nicht, und die Abhilfe kostete nach jedem Import Hauptthread-Zeit.
- **BACKUP-9** – Ein iCloud-Kontowechsel ist bei Bini praktisch ausgeschlossen, die Daten bleiben im alten Konto, „Nicht
  angemeldet“ zeigt Thalia schon (P4.18 macht es sichtbar); die Prüfung brächte Fehlalarme, die Sicherung (P3.13) deckt
  den Fall.
- **BACKUP-14** – Widerspricht der v10-Entscheidung (Einträge, Seitenstände, Zuordnungen nur per Widerrufen, nach 30
  Tagen weg); ein Wiederherstellen müsste Folgewochen neu werten; die echte Lücke (eigene Wertung entfernen) schließt
  P5.8, den Text P3.14.
- **PERF-15** – Der Katalog ist klein, wird nur bei Änderung und schon abseits geschrieben; der Vorschlag ließe
  Änderungen anderer Geräte im Katalog fehlen.
- **PERF-19** – Unsichtbar (nur wenige Zeilen zeichnen neu); „einmal zuweisen“ verwürfe Vorschläge anderer Tage.
- **DISPLAY-11** – Kategorie-Tagesnoten bei vollständiger Kategorie sind gewollt (TASKS-v2 U18.1) und gleich wie in
  Heute; nur die Tages-Gesamtnote wartet aufs Abschließen.
- **UIMAC-16** – Nur im Debug-CI mit Diagnose gemessen; ein Öffnen per Zeitgeber kann zwei Hauptfenster erzeugen, und die
  Verzögerung liegt im Kit (nicht änderbar).
- **WATCH-9** – Die Watch hat ± für Zähler seit v7; ein Kurzbefehl auf der Aktionstaste zählt am iPhone ohne neuen Code;
  ein eigenes Control bräuchte Speicherzugriff in der Erweiterung und hätte kein Widerrufen.
- **GAP-6** – Bewusst so (REVIEW-v7: die 4-Uhr-Regel gilt nur für „Tag abschließen“); eine Kartenzahlung um 00:30 gehört
  zum neuen Tag.
- **GAP-8** – Das Protokoll ist bereits deutsch (de.lproj); die Reste (Stufennamen, „Leeren“ ohne Rückfrage, kein
  Watch-Protokoll) sind zu klein.

Aus der Plan-Prüfung (KR) nicht oder nur teilweise übernommen:
- **KR2-18** (Schalter „Mit Mac und Watch teilen“, Fuß umgestellt) – Schalterwortlaut und erster Fußsatz sind Binis
  Vorgabe; übernommen ist nur: keine doppelte Abschnittsüberschrift, und der zweite Satz nennt, was geteilt wird (§1.4.1).
- **KR1-7, Teil P8.8** („Start beim eigenen Wert oder 0, nie beim geteilten“) – brächte WATCH-12 (Start bei 0) zurück;
  stattdessen schreibt die Krone nur, wenn sie bewegt wurde (P8.8, P9.3) – derselbe Schutz.
- **KR3-11, Teil „P3 in zwei Pakete“** – übernommen als ein Paket über zwei Runden (gleicher Umsetzer, Dateien je Runde
  getrennt); ein zehntes Paket brächte nur Übergaben.
- **KR3-19** (Bereichs-Prädikat zur Laufzeit prüfen, sonst voller Lauf) – überflüssig, P2.13 nimmt IN-Prädikate (KR1-17).
- **KR3-18, Variante „gespeicherte Ziele einmal in `maintenance` normalisieren“** – schriebe Daten um, die 1.9.0 anders
  liest; das nachsichtige Lesen (P1.3) ändert nichts Gespeichertes.
- **KR3-4, Variante „`StatusTint` nach Shared verschieben“** – nicht nötig; der Vertragscommit in Runde 3a deckt alle
  P4-Schnittstellen.
- **KR3-10, Teil „ci.env ganz in P4“** – `health` gehört zum entfernbaren Teilen und kommt mit P9 (Runde 4).

## Nachträge (Umsetzung)

Was bei der Umsetzung genauer oder anders wurde als oben geplant. Der Plan oben bleibt stehen; bei Abweichungen gilt
dieser Abschnitt.

**Stand je Punkt** (die Kästchen oben sind abgehakt bis auf P1.22): P1.1–P1.21, P2.1–P2.15, P3.1–P3.16,
P4.1–P4.21, P5.1–P5.19, P6.1–P6.15, P7.1–P7.12, P8.1–P8.18 und P9.1–P9.5 sind umgesetzt und lokal geprüft (Linux-Tests,
`swiftc -parse`, Typprüfung gegen nachgebildete Apple-Module, Verhaltensprüfungen in Shared); die Lücken der Prüfung
danach sind geschlossen (unten „Lückenschluss nach der Prüfung“). Ausnahmen nach §4 ohne Antwort: P6.11 (3) nicht
gebaut (F13), P1.15 ohne Codeänderung (F2), P8.6 ohne Abhaken auf Seite 1 (F4). P8.13 haben P2 (`widgetSummary`) und P1
(Test) erledigt. Abnahmen, die Mac-CI, Screenshots oder ein Gerät brauchen (P1.6, P1.21, die Geräte-Punkte aus §2.0),
stehen mit P1.22 aus: CI, Screenshots und TestFlight (unten „Offen nach Runde 5“).

### P1 Core (Runde 1)
- `ExchangeInbox.value(_:) -> String?` wie im Vertrag, dazu eine `@_disfavoredOverload value(_:) -> String` (gibt
  „“, nie „{}“), damit die Aufrufer aus 1.9.0 übersetzen; deshalb brauchten V10GapFixTests.swift:105 und :116 eine
  Angabe `: String`. Shared (`storeInbox`, P2) und Import (P3) überspringen nil.
- `Pace.init(…, weekOver:)` und `Measures.weeklyPace(…, weekOver:)` nehmen `weekOver: Bool? = nil` (nil heißt
  `today > week.sunday`) – Swift erlaubt keinen Standardwert aus einem anderen Parameter.
- `Format.amount(_:unit:)` und `Format.amount(target:unit:)` geben die Zahl ohne Einheit zurück (€ wie `euro` ohne
  Zeichen); bei ≥ fehlt das „≥“ (nach „von“ sagt es „von“ schon, „86“), die anderen Vergleiche behalten ihr Zeichen
  („> 85“, „≤ 6“, „< 50“, „= 3“), ein Bereich ist „129–154“ (die Stelle hängt „ g“ an), Zeiten geben `Target.label`; der
  Bericht setzt „≥ “ davor. Die Rundungsrichtung gilt bei den Stellen aus `Units.decimals` für jede Einheit; ≤ rundet
  ab, < auf.
- `ResultProgress.compute(…, resultIDs: Set<String>? = nil)` – sonst wüsste Core nicht, welches Ergebnis gelöscht ist
  (P1.11). `ResultProgress.Status` bekam keine neuen Fälle (die App unterscheidet sie); die Grenz-Wörter kommen aus
  `limitLabel` und `label(isLimit:)`, `isLimit` ist berechnet.
- `PaceStatus` hat zusätzlich `withinLimit` und `overLimit` (eine Farbzuordnung für alles); `label(remaining:unit:)`
  hängt die Menge nur bei `.open` an.
- `HealthShare.read(_:code:day:state: HealthShareState? = nil)` – mit Zustand gelten dieselben Regeln wie bei `entries`.
- `SyncDevice.allCurrent(seen:builds:now:)` nimmt `builds` als `[String: SyncBuild]` (installID → Datensatz,
  `SyncBuild.builds(_:)`); `firstV11Build = 58` (in Runde 5 bestätigt, siehe dort).
- `ReminderSettings.requests()` gibt `[]`; Wochen-Erinnerungen haben die id `thalia.weekly.<JJJJ-Www>`, das Ziel
  `close-week:<JJJJ-Www>` bzw. `import` (abgeschlossen ohne nächsten Plan).
- P1.16: das Wochenziel-Wort im Bericht ist jetzt das der App („im Plan“, „hinter dem Plan“, „noch offen“, „nicht
  erreicht“, „im Rahmen“, „überschritten“); vorher immer „erreicht“/„nicht erreicht“. Noten unverändert.
- `Units.dative` ändert nur großgeschriebene Wörter mit mehr als 3 Buchstaben auf -e/-er/-el (Kürzel wie „kcal“
  bleiben).
- Tour: den macBody des Schritts `backup` hat P1 formuliert; Symbol von `health-share` `heart.text.square` (der Plan
  nennt keins); „Deine Daten“ ist der Name des Abschnitts (der Test prüft nur kleines „deine“).
- P3.4: die Zeile „Schon eingetragen für KWnn: …“ nennt eine Tagesnotiz in „…“, schreibt Tag und Monat zweistellig
  („Fr 20.11.“) und steht direkt vor „## Mein Rückblick und Plan für KWnn:“.
- Testorte: P1.9 in V11 C8 (nicht ScoringTests), P4.17 in V11 C12, P1.7 „Note der Demo-Woche unverändert“ in V11 C6
  (`demoWeekNotesAsBefore` hält 6 Wochen auf den Noten von 1.9.0, gemessen an einem nur gelesenen Export von HEAD –
  ändern sich Demo oder Wertungsregeln absichtlich, neu messen); SyncDeviceTests und CalendarTests unverändert (ihre
  Prüfungen stehen in V11 C7, C13, C18). Angepasst, weil der Plan das Verhalten ändert: V7Tests, V10Tests, CSVTests,
  V8Tests.
- Fixtures: `nw-2026-11` heißt `nw-2026-11-22`; Kontostände, `days/2026-10-31.json` und `source.json` (Gruppen und
  Konten) neu; `catalog.json` hat Ziel 8, Kategorie 8.1, Messwert `ausgaben`, Ergebnisse `res-worth`, `res-giro` und
  `source` bei `res-books` (`list:buch`). Alle Werte neutral.
- Sichtbar neu: `Format.measure` mit Stellen je Einheit; Ergebnis-Status „im Rückstand“ (auch in Prompt und Bericht).

### P3 Sicherung und Import (Runde 1 und 2)
- `ImportPreview` ist `@unchecked Sendable` (`ImportPlan` im Kit ist nicht Sendable; alle Felder sind `let` aus
  einfachen Werten).
- Vom Vertrag offen gelassene Namen: `PlanCSV.BackupInfo(date, app, device)` mit `appName(version:build:)` und
  `headline(timeZone:)`, `PlanCSV.FinalScore(score, goalScores, goalsScored)`, `Document.changes`,
  `PlanCSV.plainSettings`, `isBackupSetting(_:)`, `ExistingState.finalScores`; an `ImportPreview` `finalScores`,
  `notices`, `removedRecords`, `backupHeadline`, `backupAgeNotice(now:timeZone:)`, `olderBackupNotice`; Zeilenarten
  `.backup = "sicherung"`, `.finalScore = "wertung"`, `.change`.
- Zeilen: `sicherung` – id ISO 8601 UTC mit Millisekunden; `wertung` am Ende ihres Wochenblocks, Anzahl in der Spalte
  `count` (die Kopfzeile hat sie, sobald es Wertungen gibt); `change` – parent Punkt/Messwert, value
  neu/geändert/gelöscht, flags dauerhaft/einmalig, nur nach einer `week`-Zeile. Die Notiz der `wertung` übernimmt
  `finalGoalScores` wörtlich; deren Zielnoten haben höchstens 4 Stellen (`storeFinalScore` schreibt sie mit
  `Format.plain`), nur die Gesamtnote ist bitgenau.
- P3.1: mehr als ein Komma ist unlesbar, mehrere Punkte ohne Komma sind deutsche Gruppierung. **Verhalten neu:**
  „8.000“ in einer CSV heißt 8 mit Hinweis (1.9.0 las 8000).
- P3.4: ein leerer Tagestyp der Datei behält einen entschuldigten Typ ohne Zeile; `fillingPastBlanks` setzt auf einen
  behaltenen Krank-/Urlaubstag kein ✗. P3.5: bei Gleichstand bleibt die Kopie der App, ein fehlender Stempel gilt als
  sehr alt. P3.6: die Alterszeile zählt geänderte Markierungen, Werte und „weitere Angaben“, erst nach mehr als 24 h; die
  Zeile „ältere Thalia-Version“ ist eine Schätzung. P3.7: nur Beginn und Ende geben die Zieljahr-Zeile. P3.9: `title`
  nur, wenn `order` auf den eigenen Tag fällt, Minute abgerundet; die Vorschau übernimmt `order` der Datei auf die
  verglichene App-Kopie.
- P1.3 (Zuarbeit): Ergebnis-Ziele werden schon in `PlanCSV.parse` normalisiert. `PlanCSV.export` schreibt
  `record`-Zeilen nur für Sicherungs-Schlüssel; `referencedWeeks` lässt `record`- und `sicherung`-Zeilen weg.
  V10Tests `recordRowsRoundTripOnlyWhenThere` angepasst (`goal.start` wird gelesen, P3.7).
- Runde 2: `existingState(weeks:includeRecords:includeWork: Bool = true)`, dazu `existingState(for:adding:)`,
  `readState(weeks:includeRecords:work:)` (`StateWork`, `StateRead`). `BackupWriter.writeWeeklyIfDue(store:today:mode:in:
  now:)` ist `async` und gibt `BackupFile?` zurück; `files(in:)`, `stamp(store:now:)` mit Standardwerten. Weitere Namen:
  `backgroundPreview`, `probe`, `preview(_:probe:existing:)`, `backupInfo(now:)`, `olderDatedCopies`, `sameValues`,
  `weekPart`, `restoreChanges`, `RestoreWindow`; an `ImportResult` `insertedWork`, `insertedNotes`,
  `insertedReflections`, `daysBefore`, `keptScores`, `canUndo`; App-Typen `LoadedFile`, `LoadedFileRow`,
  `ImportReadingRow`, `ImportApplyingHint`, `BackupFile`, `BackupExportButton`, `BackupsPage`, `BackupFileRow`,
  `BackupProgressLabel`; UserDefaults `backup.lastAutoSmall` (orange Zeile „auffällig klein“).
- `restore.window` hält bis zu 8 Fenster (Beginn, Ende, Tage) je 7 Tage statt eines Paars; `cleanRestoreDuplicates`
  vergleicht auf 4 Stellen gerundet und nie die Uhrzeit.
- `apply` ist eine Speicherung ohne frühes Zwischenspeichern; der v9-Durchgang, der Archivwochen beim Import neu wertete,
  ist weg (die eine Wartungs-Speicherung deckt ihn; vorher wertete er auch am Mac – gegen P2.1). Folge: ein iPhone vor
  seinem ersten Abgleich wertet eine Archivwoche beim Import nicht neu.
- `wertung`-Zeilen nur in der vollen Sicherung. „Widerrufen“ erscheint, sobald ein Import einen Tag geändert hat; nach
  dem Import eines neuen Wochenplans nimmt es Tagestypen, Notizen, Blöcke und Reflexionen zurück (kein allgemeines
  Umkehr-Dokument, §2.11). `undoImport` endet mit `commit(rescoring:)` für die Wochen der zurückgenommenen Tage und
  Blöcke (vorher blieb dort die Note des Imports).
- Ohne jede Sicherung von Hand sagt der Wochenabschluss „Noch keine Sicherung – jetzt sichern?“; Gerätewörter „am
  iPhone/am iPad/am Mac/an der Apple Watch“; Fuß- und Leertexte der Seite „Sicherungen“ von P3. Aufbewahren: die
  neueste Datei je Kalendermonat der letzten 6 Monate (dieser eingeschlossen); „Hälfte der größten“ gegen die
  behaltenen Dateien ohne die neue; gibt es die Datei von heute schon, wird nichts geschrieben.
- Mehrere Prüfungen zugleich → ein Bestätigungsdialog mit allen Texten; Knopf „KWnn ersetzen“ (destruktiv), sonst
  „Trotzdem KWnn importieren“, sonst „Trotzdem einlesen“. Für Dateien ohne Sicherung heißen die Hinweise „Wird gelesen …“
  und „Wird importiert – bitte warten“. Die gezeigte Größe einer großen Datei ist die UTF-8-Länge des Texts. P3.16 (1)
  zeigt die neue Vorschau und kehrt zurück; der nächste Tipp fragt „KWnn ersetzen?“. IMPORT.md hat zusätzlich „Who
  scores after an import“.

### P8 Doku (Runde 1)
- Anzeige-Beispiel „→ Thalia: Ergebnis „Vermögen“ (Ziel 8)“ statt „(Ziel 2)“, passend zum Fixture-Katalog.
- ARCHITECTURE, README, WORKFLOW, SETUP und HANDBOOK sind englisch – der deutsche Wortlaut des Plans ist übersetzt;
  HANDBOOK Zeile 14 behält „entfällt – Thalia hat seit v2 keinen Timer“ wörtlich. README ohne „50-minute stop“;
  `WatchWidgets/` in README und ARCHITECTURE; SETUP nennt die Kontrollzentrum-Knöpfe statt Live Activity.
- CONNECTED_APPS: „Alles als CSV“ (zwei Stellen) heißt „Sicherung erstellen…“ (§1.6.5). TASKS-v10 „Offene Fragen“ 2
  (Finn) ist ebenfalls entschieden.
- In allen fünf Aufträgen ist der §6-Text zu ref-Arten berichtigt (`account` für Kontostand, Kennzahl-refs werden nie
  angeboten), die Zeile `app:<quelle>:<metric>[=<ref>]` und „…, Konto“ ergänzt; §9/§4 „sobald 1.9.0 auf main ist“ →
  „auf main“ mit „Stand Thalia 1.10.0“.
- Finn-Auftrag zusätzlich: ein Absatz zum Umstieg („monatlich“ gilt als „bei jeder Änderung“, Schalter aus
  UserDefaults einmal in den synchronisierten Datensatz), Beispiel-JSON für `thalia.delivery`; `source.json` ohne
  Kennzahl-refs (wie das Fixture); ein Katalog ganz ohne `results[].source` zeigt „Thalia auf diesem Gerät
  aktualisieren …“. Der allgemeine Auftrag verlangt ebenfalls einen Schalter je Zeile und eine synchronisierte Auswahl.

### P2 Shared (Runde 2)
- `MarkSnapshot` trägt zusätzlich `day` (`restoreMarks(_ snapshots:)` hat keinen Tag); die Brücke
  `restoreMarks(_:day:)` mit Schnappschüssen und die alte Tupel-Fassung sind nach Runde 3 entfernt (siehe Querverweise).
- `commit(rescoring:origin:keeping:)` mit `keeping: Set<WeekKey> = []` – Wochen mit `wertung`-Zeilen (P3.3) werden
  weder gewertet noch angefragt.
- `SyncProgress.noteImport(_:container: ModelContainer? = nil)` mit `isFirstImportDone(now:)` und
  `confirmFirstImport(context:)`; die Rückfälle (Update von 1.9.0, 24 h) setzen den Merker beim ersten Lesen.
- `resultLines(today:hidesHealth:hiddenText: String? = nil)` für den Mac-Hinweis (P7.5).
- `processRescoreRequests(now:limit:)` nimmt im laufenden Start noch nicht bearbeitete Anfragen zuerst (20 Anfragen →
  8, 16, 20); eine geschützte `force`-Woche kommt je Anfrage und Start einmal zurück (ein Toast).
- In-Memory-Speicher (Demo, Übung) schreiben keine Anfragen und haben kein Erst-Abgleich-Tor; sie werten eine berührte
  abgeschlossene Woche, wenn `canScore` (vorher wertete die Mac-Demo nur Wochen ohne Punkte).
- `backfillCategoryScores` wartet auf den ersten Abgleich, überspringt P2.2-geschützte Wochen und nimmt
  `scoresHealth` (ein iPad trägt Wochen mit Punkten nicht mehr nach); `rescoreRecentClosedWeeks` nur am iPhone.
- Eigene `withoutUndo` haben `mergeDuplicates`, `rescoreRecentClosedWeeks`, `backfillCategoryScores`,
  `processRescoreRequests`, `recordDeviceSeen`, `maintenance`; `storeInbox` speichert immer als Wartung.
- `mergeImportedCopies` gruppiert jeden Block und jede Notiz mit `importID` nach `recordID`, immer voll, auch
  übernommene `x:…`-ids (zwei übernommene Kopien behalten die Felder der ältesten, außer eine wurde später bearbeitet);
  wirft der UUID-IN-Abruf, liest es die lebenden Blöcke bzw. Notizen ganz. Die 1970-Regel (P3.16 (4)) läuft bei jedem
  `mergeDuplicates`, veraltete Schlüssel (P3.5 (4)) nur im vollen Lauf.
- `ClosedWeekSnapshot.categoryScores` ist der gespeicherte Text (`String?`); `restore(_:)` speichert ohne Wertung.
  `HealthDevice.scoresHealth`/`installedAt` sind `@MainActor`, `saveFailed`/`saveFailedMessageKey` nonisolated.
- Weitere Namen: `WeekInputs`, `weekInputs(for:goalYear:)`, `WeekContext.weekOver`, `isDayCounter(_:)`,
  `record(_ item:)`, `record(_ measure:)`, `ScoringDecision`, `scoringDecision(for:fromMaintenance:)`,
  `keepsScoreBeforeInstall(_:)`, `writeRescoreRequest(_:force:now:)`, `mergeTemplateCopies()`,
  `TrackerStore.currentBuild`, `weekKeys(from:through:)`, `lastFullMaintenanceKey`; UserDefaults `health.installedAt`,
  `sync.firstImportDone`, `sync.buildWritten`, `maintenance.lastFull`.
- `recordDeviceSeen` schreibt `sync.build.` nach einem Build-Wechsel sofort (ohne die 10 Minuten). P8.12 „Tageszähler“ =
  ein täglicher, summierender Messwert ohne Health; er steht zuerst.

### P4 App-Rahmen, Mac, System (Runde 3a und 3b)
- Runde 3a: fünf Debug-Zeilen `.diagWidth` in TodayView.swift und WeekTable.swift (Dateien von P5/P6; P4.1 (1) gibt
  die Messung P4). Neuer Blatt-Fall `AppSheet.settingsPage(SettingsPage)` statt eines Arguments an `.settings` (alle
  `.settings`-Aufrufer bleiben, §0.9); `SettingsPage.health` (iOS) ohne Marke, weil es nicht das Teilen ist.
- `showDayOverview(_:)` blendet am Mac auch die Spalte ein und aus, solange sie passt (ein Weg für ⌘0, Knopf, Ring und
  Karte). Zusätzliche Namen: `SaveFailure`, `showsGlanceColumn`, `showsWeekSummaryColumn`, `AppModel.fits(_:detail:
  width:)`, die festen Breiten und Schlüssel, `diagMeasure`, `View.diagWidth`, `PracticeUnavailableView.text` und
  `init(onClose:)`, `StatusTint.Kind` mit `init(kind:)` (beschriftet, weil `StatusTint(.behind)` mehrdeutig wäre).
  `StatusTint` nimmt die lesbaren Farben `MarkDoneText`/`MarkPartialText`/`MarkMissedText` und `Brand.accent` für „im
  Plan“. `lastSent`/`lastReceived` sind `private(set)`, nur Gerät, nur erfolgreich beendete Ereignisse.
  PracticeUnavailableView behält „deinen eigenen Daten“ (Blatt, kein Tour-Schritt). Kein Blatt-Fall für die
  Wochenübersicht (`WeekSummaryPanel` ist privat in WeekTable, P6 zeigt sie lokal).
- P4.1: ob ein Inspektor passt, entscheidet `AppModel.roomWidth` = max(Detailbreite, Fenster − sichtbare Seitenleiste
  − 1), neue Glieder `sidebarWidth`, `showsSidebar`, `roomWidth`; `mainWindowWidth` berechnet; dazu ein Sprungschutz
  (ändert sich „passt“ innerhalb 0,5 s, wird ein Breitensprung ≥ 200 pt übergangen).
- P4.6: passt die Spalte nicht, schaltet ⌥⌘0 `showsWeekSummary` sofort aus und nach 100 ms (auf Woche) bzw. 350 ms
  (von einer anderen Seite) wieder ein, damit WeekTable das Blatt zeigt.
- P4.2: ⌘↩/⇧⌘↩ schließen ein offenes Abschluss-Fenster nur, wenn das Hauptfenster schon vorne war (mit Einstellungen
  vorne holen sie es nur nach vorn). `MainWindow.remember(_:)` merkt sich `openWindow`; ist ein anderes Thalia-Fenster
  sichtbar, öffnet `showWithoutEnvironment()` damit statt mit dem Apple-Event.
- P4.13: eine „Änderung“ ist ein Speichern mit mehr als HealthValue und den eigenen `sync.seen.`/`sync.build.`;
  ihre Zeit liegt in `sync.lastChange`; fehlt eine Zeit, steht „noch nicht“.
- P4.15: „Entfernen“ nur unter „Früher“, löscht auch `sync.build.`, Hinweis mit „Widerrufen“. P4.17: anderswo
  abgeschlossene Wochen einmal je Woche; der Planer bekommt den Wochenzustand über `isWeekClosed`/`weekHasPlan`.
- P4.18: AppModel fragt das iCloud-Konto beim Start ab (sonst käme „Nicht bei iCloud angemeldet“ nie); Symbole, das ×
  mit „Bis zum nächsten Start ausblenden“ und VoiceOver-Texte von P4; Tippen öffnet am Mac das Einstellungsfenster, am
  iPhone das `.settings`-Blatt; die Debug-Option wirkt auch mit `-Demo`, `quota` spielt iCloud mit Konto vor.
- P4.7: „Einstellungen…“ gebaut; die Bestätigung zeigt den Text des Hinweises („1 PH · Wofür“). P4.9: der Exporter
  hängt an einem Hintergrund von MacRoot, Abbrechen zeigt keinen Hinweis. P3.13-Auslöser am Mac bei jedem
  didResignActive (erst `isDue`, nie zwei Schreiber), nie auf der Watch.
- P2.6: für Messwerte lautet die Rückfrage „Wiederherstellen ersetzt den Messwert aus dem letzten Import.“ (nach dem
  Muster des Punkts). P4.20: „Zieljahr sichern“ nur bei geänderten Beginn/Ende/Zielüberprüfung, grau bei Ende ≤
  Beginn mit „Das Ende liegt vor dem Beginn.“; gezählt werden Ergebnisse und Abschnitte mit dem gespeicherten Beginn;
  nach „Neues Zieljahr beginnen“ Hinweis „Neues Zieljahr ab <Datum>“ mit „Widerrufen“ (§0.4). P2.9: Datum
  „dd.MM.yyyy, HH:mm“, leerer Fehlertext „unbekannter Fehler“.
- ⌘0 am iPad zeigt den gezeigten Tag (`captureDay`); „Zuletzt gelöscht“ während der Tour grau. P3.2: am Mac ruft
  AppModel `SyncProgress.noteImport` selbst (WidgetPublisher läuft dort nicht).

### P5 Heute, Erfassen, Tag abschließen (Runde 3b)
- P5.4: der erste Abschnitt heißt nur für heute „Heute“, sonst wie der Tag („So, 22. Nov.“); Wochenzeilen „Woche 6
  PH“; der Fokus kommt 0,35 s nach dem Erscheinen (`.task`), sonst ginge er beim Einschieben verloren.
- P5.5 in der Einzahl „Noch 1 offen – zählt nicht mit“ und „Tag abschließen · 1 bleibt offen“; ein künftiger Tag zeigt
  keine Zahl.
- P1.16 Fokus: `label(remaining:unit:)` in `StatusTint`, darunter klein „6 / 8 PH“. WeeklyGoalRow: ein Grenz-Ziel ist nie
  „erreicht“ (behebt einen Fehler aus 1.9.0); das kurze Wort neben „x von y“ nur, solange nicht erreicht. P1.7: ein Ziel,
  das nicht ≥ ist, zeigt sein Zeichen („3 von ≤ 6 Stk.“, „32,50 €/< 50 €“).
- P5.6: Notizzeile und Ausgabenzeile sind je ein VoiceOver-Element; der Hinweis der Ausgabe bleibt „Tippen zum
  Bearbeiten“. P5.11 aus `DayKey.longLabel` gekürzt („Sonntag, 22. November“).
- P5.12: nur die sichtbare Seite nimmt den Fokus; „Abschluss & Notizen“ löscht eine offene Anforderung; ohne offenen
  Punkt wird nichts vorgewählt. P5.15: VoiceOver über `SummaryTile(…, spoken:)` (additiv), bei ≤ „genau 50 €, Ziel
  höchstens 50 €“. P5.16: die Zeile kommt auch, wenn ein getipptes Feld auf den geladenen Text zurückgesetzt wurde.
  P5.17: graue Zeile mit `calendar.badge.clock`, die Leiste hat dann nur das ×.
- P4.19: beide „Mehr“-Menüs teilen `MoreMenuDataItems`; in der Übung ist das „Mehr“ der MainToolbar ganz weg (es wäre
  leer). P4.1: der VoiceOver-Hinweis des Rings folgt dem Platz; die Seitenleisten-Karte hat denselben Tooltip.
  P6.15: Tooltip „Zu heute (⌘T)“.

### P6 Woche, Abschluss, Rückblick, PDF (Runde 3b)
- P6.1 gilt überall, wo die Note steht (§1.2.7): auch Abschluss-Fenster und Bericht, Zielliste der Mac-Spalte und
  „Bestes Ziel“ im PDF; `keepsStoredScore` verlangt Punkte; ohne gespeicherte Zielnoten zeigen sich die heutigen.
  Weil Kontexte mit `goalYear: false` nicht wissen, ob sie eingefroren sind, reicht RangePDF die Einfrier-Regel durch
  (`RangePDFData(…, isFrozen:)`, `RangePDFRow.isFrozen`, `PDFExport.weekPages(…, frozen: Bool? = nil)`).
- Namen: `keepsStoredScore`, `shownScore`, `storedGoalScores`, `shownGoalScores(_:)`, `scoredGoalScore(_:)`,
  `shownGoalsScored`, `readsHealthProgress`, `lacksHealthValues`, `lacksHealthHint`, `WeeklyTarget.shownStatus`,
  `amountUnit`, `amountSuffix`, `amountsText(joiner:)`, `ShareContent.ringText`/`ringCaption`/`shownRingText`/
  `shownRingCaption`, `RangePDFData.closedCountedDays`/`finishedWeeks`, `ClosedWeekFacts`, `WeekHistoryRow(goalsTotal:)`,
  `WeekSummarySections(heroNote:)`, `WeekSummarySheet`, `BackupReminderRow`. `PDFExport.make(_:context:progress:)` ist
  `async`, die synchrone Fassung ist weg.
- P6.2: `finishedWeeks` zählt die laufende Woche immer offen (`state != .running`), zusätzlich zur Formel des Plans.
- P6.14: am Mac ersetzt „aus Health am iPhone“ die Zeile „Ziel …“ (das Ziel steht im Tooltip); der Satz unter der Note
  steht auch im Wochenblatt des schmalen iPads. Die P7.1-Zeile im Abschluss erst nach dem Abschließen, aus dem Kontext
  berechnet.
- Anzeige: € ohne „€“ vor „von“, Grenzen mit Zeichen („32,50 von ≤ 50 €“); „im Plan“ in der Akzentfarbe; PDF-Kacheln
  „steigend (je k)“ bzw. „Trend –“ (keine Spalten erste/letzte); Fortschritt als Kapsel unten; eine Woche nur aus
  Krank-/Urlaubstagen hat im Teilen-Bild „–“ und „zählt nicht“; Knöpfe der Wiederöffnen-Frage „Woche wieder öffnen“ /
  „Abbrechen“; die Sicherungs-Zeile fehlt in der Übung.

### P7 Ziele, Leseliste, Verbundene Apps (Runde 3b)
- `FrozenWeekNote` entscheidet mit `TrackerStore.canScore(week)` – Knopf, „Hier fehlen …“ und „Nach heutigem Stand“
  folgen genau `recompute`; P9 deckt geteilte Wochen über `canScore` ohne Änderung in Segments.swift.
- „Neu berechnen“ mit Schnappschuss und Hinweis samt „Widerrufen“ auf jedem Gerät (§0.4), nicht nur am iPhone; ohne
  sichtbare Änderung „KWnn neu berechnet · 7,84“, ohne Änderung „KWnn: Wertung unverändert“. P6.1 vergleicht die
  gezeigten (gerundeten) Noten.
- P7.4: Fokus nach 350 ms über `.task(id: chosenID)`. P7.8: hat die erste Kategorie keine gewertete Woche, beginnt der Fuß
  mit „Je Kategorie: Wochen ab 8,00 von den gewerteten – …“. P6.14: der Messwert eines Ergebnisses wird in den
  Messwerten dieser Woche gesucht. P7.11: der Fingerabdruck enthält auch die Arbeitsblöcke.
- P1.12: für andere Einheiten „Schon erledigt bis (optional)“; keine Zahl oder mehr als der Umfang → „Sichern“ grau
  mit oranger Zeile. §1.5.4: der Ergebnis-Editor heißt bei `requiresRef` „Konto“ mit „Bitte wählen“, ohne bekannte
  Konten ein Textfeld mit Hinweis; ohne Konto kein Sichern; im Messwert-Editor ist der Hinweis eine orange Zeile.
- `GoalResultRow` behält `tint` (§0.9), der Balken nimmt die Status-Farbe; `ResultStatusTag(isLimit: Bool = false)`.
- Zusätzliche Texte für den P6.3-grep (Leerzustand der Ziele, Erklärung zum PDF-Bericht), die Grenz-Wörter und der
  Finn-Satz in den Erklärungen, „Öffnet das Buch“. Ein entschuldigter Live-Punkt bleibt blasse Säule (nicht `isLive`).
- P7.3: die gestrichelte letzte Strecke ist gebaut (`GoalScoreSparkline.liveStep`). P7.10: entschuldigte Wochen und
  Verläufe kommen aus den beobachteten Plänen (`GoalsContent.excusedWeeks`, `goalScores`) – „excusedWeeks bleibt“ als
  „das Verhalten bleibt“ gelesen (mit dem Store verglichen).

### P8 Watch, Widgets, Siri (Runde 3b)
- P1.7: der Schnappschuss trägt nur die Zielzahl; `WidgetText.targetAmount` rundet sie wie ein ≥-Ziel (obere Grenze
  eines Bereichs auf); € bleibt `Format.euro`; ohne Einheit kein Leerzeichen. Kein Formatwechsel (P8.12).
- P8.8: „nur nach Drehen“ gilt im Health-Editor (`requiresChange`, „Sichern“ grau bis bewegt); eigene Wertzeilen
  bleiben bei R81; der letzte Wert wird in `.task(id: today)` gelesen. P8.9: Wochenziele „Ziel ≥ 20 pro Woche“. P8.10
  über `Format.amount`.
- P8.11: nur die mittlere Überschrift wird „Kein Plan – tippen“. P8.12: keine Chips an einem neuen Tag, ohne Plan oder
  abgeschlossen; eine offene Zeile weniger nur mit Chips; die mittlere Überschrift darf zwei Zeilen haben.
- P6.5: auch „Heute ist nichts fällig.“ bekommt die PH des Tags („… 0 PH.“); die Krank-Zeile kommt vor der
  Abschluss-Zeile. P8.17: `MeasureOptions` bietet Titel (ohne Doppelte), der Kurzbefehl nimmt Code oder Titel;
  Intents.swift hat ein ausdrückliches `import Foundation`. P8.7: das Banner darf zwei Zeilen haben, „Power-Hours
  gelöscht“ steht ebenfalls 4 s.

### Querverweise nach Runde 3
- §2.10 P4–P2.5: die Tupel-Fassung `restoreMarks(_:day:)` und die Brücke mit Schnappschüssen sind aus
  Shared/TrackerStore.swift entfernt (P4 besitzt die Datei nicht); nur `restoreMarks(_ snapshots:)` bleibt.
- P5.9 ohne Wortlaut im Plan: ImportView sagt „die Messwerte mit ihren IDs“ und „zurück kommt eine CSV.“; PastImport
  unverändert. P6.3: ImportView „deine Jahresziele mit Kategorien“, Style.swift-Kommentare „light tint (opacity 0.1)“.

### P9 Health teilen (Runde 4)
- Namen über den Vertrag hinaus: `HealthShareGate.verdict(for:)`, `thisDevice`, `switchIsOn`, `endedElsewhere`,
  `setSwitch(_:endedElsewhere:)`, die Schlüssel `thalia.health.share`, `thalia.health.shareEndedElsewhere`,
  `thalia.health.shareCleaned`, die Startoption; `HealthShareWeek`; an TrackerStore `readHealthShareState`,
  `sharedHealthEntries`, `writesHealthShare`, `startHealthShare(today:read:now:)`, `removeAllHealthShare(now:)`; an
  WeekContext `healthShare`, `sharedHealthValue(_:on:)`; App `HealthShareController` (mit `syncArrived(store:)`),
  `HealthShareSection`, `SharedHealthInput`, `AppModel.healthShare`.
- Signaturen: `writeHealthShare(day:counted:read:now:) -> Bool`, `writeHealthShareWindow(today:days:read:now:)` mit
  zusätzlichem `read` (gibt die Zahl der geschriebenen Datensätze), `healthShareCovers(_:today:)` (jeder Tag der Woche
  bis heute liegt im Fenster des Schreibers), `cleanUpHealthShare(gate:today:now:)` gibt die Zahl der gelöschten zurück,
  `readValues(days:measures: [WeekKey: [MeasureRecord]])`. Das Fenster des Zustands wandert mit dem Tag.
- Ein Tag ohne `counted` und `read` verliert seinen Datensatz. Die App-Store-Bereinigung schreibt den Zustand nur aus,
  wenn etwas geteilt war – eine App-Store-Installation, die nie teilte, schreibt nichts. In `-Demo` steht der Schalter
  an (nur im Speicher).
- Geänderte markierte Stellen außerhalb der §2.0-Liste (wie der P9-Kopf erlaubt): CloseWeekView `healthNote`, Glance
  `valueLines`, CloseDayView `healthElsewhereMeasures`, V11Tests C14; in MeasureForm die Zeile zum geteilten Wert, in
  MeasureMenu kein „Wert leeren“ dafür; ThaliaWatchApp `import ThaliaCore`. Segments, WeekTable und
  TrackerStore+Range brauchten keine Änderung (sie folgen über `canScore`, `isHealthElsewhere(_:on:)`,
  `weekContext(for:)`).
- Die Watch zeigt auch „Health am iPhone: … – dort übernehmen“; ein Wechsel des Tors baut ihre Startseite neu
  (`.id(gateTick)`). Nach einem Abgleich schaltet sich ein übernommener Schreiber gleich ab (nicht erst beim Aktivieren),
  und die Datenschutz-Texte der Leser folgen sofort; die tägliche Bereinigung auf der Watch läuft auch beim Aktivieren.
- Bericht und Planungs-Prompt nennen am Mac, auf der Watch und am iPad unter „Messwerte“ die geteilten Werte – genau wie
  der Bericht am iPhone die übernommenen schon in 1.9.0 nennt (§1.4.7); Ergebnis-Zeilen verbergen Health weiter
  (`hidesHealth`). Ob Health-Werte überhaupt in einen Prompt dürfen, ist eine Frage an das iPhone-Verhalten (nicht in
  v11 geändert). Nachtrag: der Planungs-Prompt und die Kopie der Zielüberprüfung nehmen die geteilten Werte seit dem
  Lückenschluss nicht mehr mit (unten „Lückenschluss nach der Prüfung“); der Wochenbericht nennt sie weiter.

### P1 Abschluss (Runde 5)
- `MARKETING_VERSION = 1.10.0`. `SyncDevice.firstV11Build = 58` ist die nächste TestFlight-Build-Nr. (STATUS v10:
  „Nächste Build-Nr.: 58“); das Tor verlangt ≥ 58 – jede höhere Nummer passt, eine kleinere ließe 1.10.0 als alt
  gelten (Mac, Watch und iPad werteten nie selbst). Ein Build aus Xcode meldet Build 1 und zählt wie eine alte Version
  (STATUS, SYNC).
- SYNC.md „Stand 1.10.0“ – jede Zeile am Code abgeglichen (Auslöser des Eingangs in `ExchangeMonitor`, Mac-Takt in
  `AppModel.startConnectedApps`, Import-Beobachter in `WidgetPublisher`, `ThaliaWatchApp`, `scoringDecision`,
  `closeWeek`, `SyncProgress`, `maintenance(today:)`, `BackupWriter`, Erinnerungen); dazu ein Abschnitt „1.10.0 – was
  sich am Abgleich geändert hat“ und ein entfernbarer Abschnitt „Health teilen (nur TestFlight)“. Die Siri-Grenze bleibt
  bis zum Gerätetest von P4.14; die alte Zeile 32 hat den F1-Zusatz.
- TESTING.md „v11 (ab Version 1.10.0)“ aus §3.4 und den Berichten aller Pakete samt Pflicht-Checkliste „Vor App-Store
  entfernen“ mit den gezählten Stellen (172 Zeilen `HEALTHSHARE` – P9s Bericht nannte als Summe 170, seine Liste je
  Datei ergibt 172, und so viele findet `grep`). Ältere Zeilen nachgezogen: ⇧⌘T → ⌘T, Menüleiste
  (R96), Tasten ohne Klick (:176), Spalte oder Blatt (:177), Woche-Leiste (:180), Health am Mac (:16), „Alles als CSV“
  → „Sicherung erstellen…“ (v9/v10), „im Rückstand“ (v10), :467 nach P3.2 (4).
- STATUS „Stand v11“ über v10; STATUS:89 (entschieden), :92-94 (P7.12), :195 (P4.1), :234-235 (Architektur ohne
  WorkActivity/Live Activity, mit WidgetPublisher, WidgetActions, neuen Dateien; „ThaliaTips“ gab es nicht mehr). Die
  Prüf-Hinweise der Pakete stehen ohne die Pfade der Prüf-Ordner (die lagen nur in der Sitzung).
- ARCHITECTURE (neue Dateien, Schlüssel, UserDefaults, wer wertet, Startoptionen), TOUR.md (Tour 11, 23 bzw. 24 Karten),
  HANDBOOK_PROPOSALS 36–40, TASKS-v10 §1.2.1 und Nachträge zur neuen „zählt für“-Regel, README und WORKFLOW „equally
  weighted“ (P6.3). Config/ci.env von P4/P9 geprüft: iPhone + `goals review close-week settings backup health`, Mac +
  `review settings`; AppModel kennt alle diese Bildschirme.
- Doku-Greps (§3.5, ohne alte TASKS-Dateien): „8,01“ nur im Entscheidungssatz (CONNECTED_APPS); „Live
  Activity|WorkActivity|Timer“ nur im „entfällt“-Vermerk; „10 %|10 Prozent|zehn Jahresziele“, `flag.checkered`,
  „hinten“ und „Alles als CSV“ leer.

### Lückenschluss nach der Prüfung
Die Prüfung nach Runde 5 (Code, Verhaltensszenarien, Typprüfung) fand diese Lücken; geschlossen (Core-Tests in V11 C3,
C10, C11, C14, C16; Szenarien und Typprüfung im Prüf-Ordner der Sitzung):
- P1.16 „Bericht und App gleich“: neu `PaceStatus.of(target:value:pace:)` (die Regel des Berichts: Grenze → im Rahmen /
  überschritten; Ziel erfüllt → erreicht; vom Tempo „erreicht“, aber nicht erfüllt – über einem Bereich, „= 3“ mit 4 →
  nach dem Wochenende „nicht erreicht“, sonst „im Plan“; sonst das Tempo). `WeekReport.targetStatus`,
  `WeeklyTarget.shownStatus` (Woche, Mac-Spalte, Heute im Blick, Wochen-PDF), WeeklyGoalRow (Chip, „erreicht“ aus
  `target.isMet`) und der Fokus nehmen sie. Vorher zeigte die App bei „150–180“ mit 160 „nicht erreicht“, mit 200
  „erreicht“.
- P1.3: eine Einheit mit Punkt am Ende („≤ 6 Stk.“, „bis zu 6 Stk.“) ist lesbar – nach der letzten Ziffer fällt alles
  weg (1.9.0 las das nicht).
- P6.15/P1.19: Tour-Schritt `day` (Mac) sagt „⌘T führt zu heute“ (nur Text, `since` bleibt). P6.3: im Planungs-Prompt
  „Die Jahresziele sind die Grundlage.“ ohne „zehn“.
- P9.3: WeeklyGoalRow zeigt unter „Heute eintragen“ einen geteilten Wert als `SharedHealthInput` (kein Feld, kein −/+).
  Die Zielüberprüfung zeigt am Mac mit abgedeckter Woche die geteilten Werte (`hidesHealth` nur ohne Health und ohne
  Teilen). Die Texte nennen das teilende Gerät: `HealthShareState.device` (neues JSON-Feld, Geräteart, nie der Name;
  ohne Feld „iPhone“), `HealthShare.sharedCaption`/`suggestionText`, an `HealthShareWeek` `sharedCaption` und
  `suggestionText(_:unit:)` – „aus Health am iPad“, „Health am iPad: … – dort übernehmen“. Neben einem eigenen
  Health-Vorschlag des Geräts steht kein zweiter vom anderen Gerät. Das Messwert-Fenster zeigt dazu das Symbol des
  teilenden Geräts (`HealthShareWeek.writerSymbol`); die nicht mehr benutzte `HealthShareController.phoneSuggestionText`
  ist entfernt (§0.9).
- Prompts ohne geteilte Health-Werte (§1.4.7, §1.4.8, Regel der Aufgabe): `WeekContext.sharedHealthKeys`,
  `reportInput(results:sharedHealth: Bool = true)`, `periodReport(…, sharedHealth: Bool = true)`. Der Planungs-Prompt
  und „Bericht kopieren“ der Zielüberprüfung nehmen `false` – am Mac, auf der Watch und am iPad wie in 1.9.0 ohne
  Health-Werte. Der Wochenbericht („Bericht kopieren“ im Abschluss, Rückblick, Import) zeigt sie weiter wie am iPhone
  (§1.4.7). Die eigenen übernommenen Werte des iPhones stehen dort wie seit 1.9.0 im Prompt (nicht geändert – Frage an
  Bini, ob Health-Werte überhaupt in Prompts sollen).
- P9.1 (§1.4.6): ein Leser zählt das Fenster des Schreibers nur bis 34 Tage vor dem eigenen heute
  (`HealthShareState.readable(today:)`, `HealthShare.covers(_:state:today:)`; `HealthShareWeek(settings:week:today:)`,
  `healthShareCovers`, `sharedHealthEntries(…, today:)`) – Tage, die die tägliche Bereinigung schon löschen darf, gelten
  nicht als abgedeckt, `canScore` lässt den Mac eine solche Woche nicht werten.
- §1.4.3: ein in diesem Start bestätigter App-Store-Build (`HealthShareGate.isConfirmedDenied`) bereinigt auch nach
  jedem Abgleich (AppModel `afterSync`, Watch bei `.active`) – Datensätze, die erst mit dem ersten Abgleich kommen,
  gehen, und das teilende Gerät schaltet sich beim nächsten Abgleich ab. Bleibt mit der Bereinigung. `resolve(timeout:)`
  nimmt `Swift.Duration` (am Mac kann der C-Typ `Duration` aus MacTypes sichtbar sein).
- P2.1 (b)/P3.3: `closeImportedWeek(_:fillsIn:)` statt `closeWeek` für die Wochen, die ein Import schließt (auch
  „Widerrufen“): Mac, Watch und iPad geben einer Woche, die sie nicht werten können (`canScore`), keine eigene Note,
  nur die Anfrage mit `force`; das iPhone wertet keine Woche vor seiner Installation, die Health liest (P2.2). Wochen
  ohne Health-Punkt wertet der Abschluss wie bisher auf jedem Gerät. Vorher speicherte der Mac seine Note ohne Health,
  die überall galt.
- P3.7: was eine Sicherung nur auffüllt – die einfachen Einstellungen (Zieljahr, Katalog-Schalter) und eine Woche, die
  das Einspielen erst anlegt (`wertung`, Abschluss) –, trägt den Zeitstempel 1970: eine später über iCloud ankommende
  echte Kopie gilt (`goalPeriod(from:)`, `writeSetting`, `DuplicateMerge.week`).
- P3.13: `BackupWriter.isDue` gilt auch, wenn `backup.lastAuto` in der Zukunft liegt (eine einmal vorgehende Uhr hielt
  die Sicherung sonst bis dahin an). §1.8.2: Demo und Übung (In-Memory) zeigen in „Sicherungen“ keine echten Dateien und
  im Fuß kein „automatisch: …“ (`BackupWriter.showsSmallNotice(store:)`, `statusLine` ohne `lastAuto`).
- P4.5/P4.6/P4.21: ⌘1–⌘4, ⌥⌘0 „Wochenübersicht“ und ⌘T „Zu heute“ sind grau, solange ein lokales Fenster Eingaben
  hält (`isBlocked`); ⌘0 außerhalb von Heute ebenso (der Seitenwechsel schlösse das Fenster).
- `HEALTHSHARE` steht jetzt in 196 Zeilen (TESTING und STATUS nennen die Stellen je Datei); jede Fundstelle des
  §3.5-greps hat die Marke höchstens drei Zeilen darüber.

### Offen nach Runde 5
- CI am Mac (Typprüfung, Build gegen das echte SDK), `[screenshots]` mit den neuen Bildschirmen und `[testflight]`
  (Build 58) – macht der Orchestrator; STATUS bekommt dann den Satz dazu. Die SDK-Stellen, die nur nachgebildet geprüft
  sind, nennen die Paketberichte (u. a. `withoutUndo`, CloudKit-Ereignisse, `AppTransaction`, HealthKit, App Intents,
  `onGeometryChange`, `NavigationSplitView(columnVisibility:)`).
- Gerätetests (TESTING v11); P5.1 einen ✓ mit `os_signpost` messen; P4.1 „diag: detail check“ im Mac-Protokoll (R ≈ 0);
  P4.2 Erinnerung bei geschlossenem Hauptfenster und offenen Einstellungen; §1.4.12 vor dem ersten App-Store-Einreichen
  (läuft die App-Prüfung in der Sandbox?).
- Freiwillig: `ExistingState.entries`-Kommentar in ImportPreview.swift („(`order` 0)“) an P3.9 anpassen;
  `storeFinalScore` mit `String(value)` für bitgenaue Zielnoten in `wertung` (nicht verlangt).

### Nach den CI-Läufen 38–40 (Mac-Breite, P4.1)
- `AppModel.roomWidth` = Fenster minus Seitenleiste; die gemessene Detailspalte zählt nur, solange die Seitenleiste
  noch nicht gemessen ist (Lauf 38: Detail 1117 pt im 1024-pt-Fenster ließ „Heute im Blick“ „passen“).
- Abweichung von P4.1 (2) „HSplitView bleibt“: am Mac stehen Heute-Liste (`AppModel.todayListWidth` = 250 pt, nicht
  mehr ziehbar) und Seite (`todayPageMinWidth` = 400 pt) in einem `HStack`; die `HSplitView` wuchs über das Fenster,
  auch als die Zeilen schmal genug waren (Lauf 40: Zeile 451 pt, Detail 1117 pt). `glanceInspectorWidth` = 910.
- `ItemMarkRow` wählt am Mac „Knöpfe neben dem Titel“ ab 640 pt nach der gemessenen Zeilenbreite (kein `ViewThatFits`
  mit Mindestbreite mehr); darunter stehen am Mac die flachen 300-pt-Knöpfe unter dem Titel (die großen brauchten
  nebeneinander 580 pt, Lauf 41: Seite 638 pt bei 542 pt Platz); iPhone/iPad unverändert.
- Lauf 43–45 (AppKit-Protokoll „layout at 8 s“): eine Wunschbreite und eine aus dem Fenster gerechnete Seitenbreite
  änderten nichts; das Fenster startet in CI mit 1180 pt (Spalte „Heute im Blick“ offen) und wird dann auf 1024 pt
  verkleinert. Versuch in Lauf 46: `glanceInspectorWidth` = 1000, die Spalte öffnet sich bei 1180 pt nicht (Blatt).
- `weekSummaryWidth` = 1000: die Wochentabelle belegt am Mac rund 750 pt (Lauf 39/40: Inhalt 729 pt), bei 1024 pt
  öffnet die „Wochenübersicht“ als Blatt (Lauf 40: Woche passt).
