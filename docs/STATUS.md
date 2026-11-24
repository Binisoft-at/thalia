# Thalia – Stand (zum Wiedereinstieg nach Kontext-Kompaktierung)

Letzte Aktualisierung: 2026-11-24 · Arbeitsliste: [TASKS-v11.md](TASKS-v11.md) · Verbundene Apps: [CONNECTED_APPS.md](CONNECTED_APPS.md) · Sync: [SYNC.md](SYNC.md) · Durchsicht v7: [REVIEW-v7.md](REVIEW-v7.md) · Bini-Testliste: [TESTING.md](TESTING.md)

## Stand v11 (Version 1.10.0, Tour-Version 11)
- Anlass: Gesamtprüfung nach 1.9.0 (57) am 23. Nov. 2026 (Code, CI-Screenshots von Lauf 37, Startprotokolle) – 136
  Befunde, je zweimal gegengelesen, dazu Binis Entscheidungen: „über 8“ zählt ab 8,00; Schonfrist-Woche und Notiz am
  abgeleiteten Haken bestätigt; Finn liefert Vermögen bei jeder Änderung und alles einzeln wählbar (auch Kontostände);
  Health am Mac und auf der Watch als „Variante B“ – nur in der TestFlight-Version. Plan, Regeln und alle Abweichungen:
  [TASKS-v11.md](TASKS-v11.md) („Nachträge“ am Ende).
- **Keine CloudKit-Schemaänderung** (`Shared/Models.swift` und `tools/schema-from-models.py` unverändert): neue
  JSON-Schlüssel in `AppSetting` – `rescore.<Woche>` (Bitte ans iPhone, neu zu werten), `sync.build.<installID>`
  (Version je Gerät), `backup.last` (letzte Sicherung von Hand, alle Geräte), `hshare.state` / `hshare.<Tag>` (nur
  TestFlight) –, keiner in `SettingKeys.all` (nie in Sicherung, `record`-Zeilen oder den Präfix-Abfragen der Woche);
  neues JSON-Feld `list.item` → `startAt`; neue CSV-Zeilen `sicherung`, `wertung`, `change`; das Austauschformat bleibt
  v1 und wächst nur (Kennzahl `account_balance`, Katalog-Feld `source`). Ältere Builds übergehen alles davon.
- **Alle neun Pakete umgesetzt** (Runden 1–4; Einzelheiten und Abweichungen in TASKS-v11 „Nachträge“):
  **P1 Core** (strenge Zahlen ohne Absturz, Zeitziele über Mitternacht, Zielwörter wie „spätestens“, PH in Minuten,
  Stellen je Einheit, Anzeige-Rundung in Richtung des Vergleichs, verpasste Wochenquote am leeren letzten Tag,
  Grenz-Ergebnisse, Leseliste „zählt für“ und „Schon gelesen bis Seite“, Tempo-Status `PaceStatus`, Trend ab 4 Wochen,
  datierte Erinnerungen, Versions-Tor, Tour 11, Finn-Kennzahl `account_balance`, neue Datei `HealthShare.swift`);
  **P2 Shared** (wer wertet, Anfragen ans iPhone, Schutz frisch installierter Geräte, Wartung ohne Undo, Zusammenführen
  begrenzt, erster Abgleich `SyncProgress`, Speicherfehler sichtbar, schnellere Wochen-Leser);
  **P3 Sicherung und Import** (Zeilen `sicherung`/`wertung`/`change`, Zieljahr in der Sicherung, ein Zahlenleser,
  Urlaub bleibt, Widerrufen nach dem Nachtragen, große Dateien abseits gelesen, „Sicherung erstellen…“, wöchentliche
  automatische Sicherung, neue Datei `App/Sources/Backups.swift`);
  **P4 App-Rahmen, Mac, System** (Inspektoren nur, wenn sie passen, Hauptfenster für Menübefehle und Erinnerungen,
  Kürzel, Menüleiste mit „Widerrufen“, Sicherung im Ablage-Menü, Gesendet/Empfangen, Geräte mit Version, Sync-Zeile,
  Übung ohne Echtes, Zieljahr mit „Zieljahr sichern“, neue Datei `App/Sources/BackgroundGrace.swift`);
  **P5 Heute, Erfassen, Tag abschließen**; **P6 Woche, Abschluss, Rückblick, PDF**; **P7 Ziele, Leseliste, Verbundene
  Apps**; **P8** Finn-Auftrag und Doku (Runde 1), Watch, Widgets, Siri (Runde 3b); **P9 Health teilen** (nur TestFlight,
  neue Dateien `Shared/HealthShareStore.swift`, `App/Sources/HealthShareSettings.swift`).
- **Wer wertet abgeschlossene Wochen** (§1.3, [SYNC.md](SYNC.md)): das iPhone wertet nach seinem ersten Abgleich wie
  bisher. Mac, Watch und iPad werten selbst nur nach eigener Eingabe, nur Wochen ohne Health-Fortschrittspunkt (oder
  geteilt abgedeckt), nur nach ihrem ersten Abgleich und nur, wenn jedes Gerät der letzten 30 Tage 1.10.0 hat – und
  schicken dem iPhone immer eine Anfrage `rescore.<Woche>` (höchstens 8 je Lauf, nach 10 Minuten gelöscht). Abschließen
  dort schickt eine Anfrage mit `force` (auch für eingefrorene Wochen), ebenso „Am iPhone neu berechnen“. Eingang,
  Zusammenführen, Nachtragen und Import werten dort nie; schließt ein Import eine Health-Woche ab, bleibt sie dort ohne
  eigene Note, bis das iPhone sie wertet. Eine frische Installation wertet Health-Wochen, die vor ihr
  endeten, nicht neu – auch nicht auf Anfrage oder beim Einspielen einer Sicherung („Neu berechnen“ von Hand geht weiter). Vor dem ersten Abgleich wertet kein
  Gerät von selbst und trägt keine Kategorie-Noten nach. Das iPad wertet wie der Mac (§4 F1 ohne Antwort).
  `SyncDevice.firstV11Build = 58` – die nächste TestFlight-Build-Nr. von 1.10.0; ein Build aus Xcode meldet Build 1 und
  zählt wie eine alte Version.
- **Einmaliges Neuwerten:** P1.2, P1.3, P1.9, P1.11 und P1.12 ändern Regeln. Nicht eingefrorene abgeschlossene Wochen
  bekommen die neue Note beim nächsten regulären Neuwerten (das iPhone nach dem Abgleich, die letzten drei abgeschlossenen
  Wochen) – sie können sich einmal leicht ändern; eingefrorene bleiben, bis jemand „Neu berechnen“ drückt. Der
  Tour-Schritt „Genauer gerechnet“ sagt das. Die Demo-Noten sind dieselben wie in 1.9.0 (Test V11 C6).
- **Was 1.9.0 anders rechnet** (§0.2): Nacht-Zeitziele („≤ 00:30“, „23:00–00:30“ – 1.9.0 rechnet sie verkehrt);
  „spätestens 23:00“ (1.10.0 ≤, 1.9.0 ≥); eine verpasste Wochenquote, deren letzter Tag leer blieb (1.9.0 lässt sie
  fallen); „10 Bücher“ mit einem zugeordneten Hörbuch (1.9.0 zählt nur das zugeordnete); „Schon gelesen bis Seite“
  (1.9.0 behält das Feld, rechnet ohne); Zähl-Ergebnisse mit „höchstens“ (1.9.0 zeigt „erreicht“ zu früh). 1.9.0
  speichert außerdem nach jedem Import die Note der letzten 3 abgeschlossenen Wochen neu – darum werten Mac, Watch und
  iPad erst, wenn alle Geräte 1.10.0 haben, und TESTING v11 beginnt mit „alle Geräte auf 1.10.0“.
- **Was 1.9.0 anders liest** (P3): die Zeilen `sicherung`, `wertung`, `change` und die `record`-Zeilen für Zieljahr
  und Katalog-Schalter stehen dort unter „Nicht gelesen“; die Uhrzeit eines einzelnen Werts übergeht 1.9.0, „1.1250“
  liest es richtig. Neu in 1.10.0: „8.000“ in einer CSV heißt 8 (mit Hinweis „Tausenderpunkt?“), 1.9.0 las 8000.
  Kontostände aus Finn behält 1.9.0 als „nicht verwendet“ im Eingang.
- **Was 1.10.0 anders zeigt** (nur Anzeige, keine Note): Wochenziele und Ergebnisse in einer Farbe je Stand
  (`StatusTint`) mit „im Plan“, „hinter dem Plan“, „noch offen“, „nicht erreicht“, Grenzen „im Rahmen“ / „überschritten“
  (nie „erreicht“), Ergebnisse „auf Kurs“ / „im Rückstand“ / „zu schnell“ / „eingehalten“; anteilige Ziele ohne
  Hundertstel („150 von 86 Stk.“); Stellen je Einheit („0,25 PH“, „6 Stk.“); der Bericht nennt dieselben Wörter wie die
  App; Trend erst ab 4 gewerteten Wochen; „gleich gewichtet“ statt einer festen Prozentzahl je Ziel; eingefrorene Wochen zeigen überall ihre
  gespeicherte Note („Nach heutigem Stand“ nur als zweite Zeile); Ergebnisse mit Pokal statt Zielflagge; das Teilen-Bild
  einer laufenden Woche sagt „Zwischenstand“ (Ring „bisher“), ein Krank-Tag „–“ mit „Krank“; Fokus „noch 0,8 PH
  offen“ und „6 / 8 PH“, in vergangenen Wochen „Wochenziel“; „Tag abschließen · n bleiben offen“, der Titel ohne Jahr
  („Sonntag, 22. November“); „Diese Woche noch“ mit „0 von 1 · Rest zählt halb (krank)“; Wochenziele mit Bereich oder „=“ „erreicht“ genau dann,
  wenn der Wert im Ziel liegt (wie der Bericht); eine vollständige Kategorie
  ohne Wertung zeigt ✓; ein Klick in ein Wertfeld schreibt keinen Wert mehr. PDF-Bericht: „Wochen abgeschlossen“ n/n
  über alle Wochen (die laufende zählt offen), „Tage abgeschlossen“ ohne Krank- und Urlaubstage, Noten mit bis zu zwei
  Stellen. „Woche wieder öffnen“ hat „Widerrufen“ und fragt bei einer eingefrorenen Woche zuerst; der Wochenabschluss
  hat die Sicherungs-Zeile und „Diese Woche läuft noch bis Sonntag.“; der Rückblick zeigt „n/total Ziele bewertet“ nur,
  wenn Ziele fehlen; der bewegte Verlauf pausiert im Hintergrund, das Feiern endet nach 2,3 s. Leseliste „Gelesen in
  Abschnitt 2: …“; auf den Zielkarten ist der Schritt zur laufenden Woche gestrichelt und blasser. Watch mit „⇄ …“,
  Zielen und „Arbeitsfrei“; Widgets mit Messwert-Chips.
- **Mac-Layout** (P4.1, löst die Notiz aus v7 unten): „Heute im Blick“ und „Wochenübersicht“ zeigen sich als Spalte nur,
  solange sie passen – gemessen wird der Platz neben der sichtbaren Seitenleiste (`AppModel.roomWidth` = Fenster minus
  Seitenleiste, nie die gemessene Detailspalte: die war in CI-Lauf 38 mit 1117 pt breiter als das 1024-pt-Fenster),
  Heute braucht 910 pt, Woche 1000 pt (die Wochentabelle belegt am Mac rund 750 pt), je ±20 pt; die gespeicherte Wahl
  bleibt. Passt die Spalte nicht, öffnen ⌘0, Symbolleistenknopf, Tagesring, Seitenleisten-Karte und ⌥⌘0 sie als Blatt.
  Das Mindestfenster bleibt 900 pt. Ursache der zu breiten Heute-Seite (seit mindestens CI-Lauf 27): die geteilte
  Ansicht (`HSplitView`) aus Liste und Seite wurde breiter als das Fenster, auch als die Zeilen schmal genug waren
  (CI-Läufe 38–40). Am Mac stehen Liste (250 pt, nicht mehr ziehbar – Abweichung von P4.1 (2) „HSplitView bleibt“) und
  Seite (ab 400 pt) jetzt nebeneinander, und eine Punktzeile wählt „Knöpfe neben dem Titel“ ab 640 pt nach der Breite,
  die sie bekommt. Prüfen in `mac-log.txt`: „diag: detail check at 8 s: window W − sidebar S − detail D = R“, R ≈ 0. Dazu: Menübefehle, Erinnerungen
  und Kurzbefehle holen das Hauptfenster (auch wenn nur Einstellungen offen sind), ein „Zu heute“ ⌘T (⇧⌘T entfällt),
  ⌥⌘J, ⌥⌘L, ⌥⌘0, Darstellung → „Seitenleiste ausblenden“, Ablage → „Sicherung erstellen…“, Tasten 1–4 ohne Klick.
- **Erinnerungen** (P4.17): Morgen, Abend und Woche sind datierte Mitteilungen für die nächsten 7 Tage; die
  wiederholenden aus 1.9.0 gehen beim ersten Start. Kein Morgen an Krank-/Urlaubstagen; eine abgeschlossene Woche
  bekommt keinen „Wochenabschluss“ (ohne Plan der nächsten Woche statt dessen „Nächste Woche planen“); die Erinnerung
  am Montag öffnet die Vorwoche. Alle enden nach etwa 7 Tagen ohne Öffnen von Thalia.
- **Sicherung** (§1.6, P3.13): „Sicherung erstellen…“ (Einstellungen → Deine Daten, Mac: Ablage) baut die CSV abseits
  des Hauptthreads; „Letzte Sicherung … am iPhone“ gilt für alle Geräte (`backup.last`). iPhone und Mac legen jede Woche
  selbst „Thalia Sicherung JJJJ-MM-TT.csv“ in Application Support/Sicherungen ab (nur iCloud/lokal, nach dem ersten
  Abgleich, nie Demo/Übung – die zeigen auch keine echten Dateien und kein „automatisch: …“; 4 neueste + je Monat eine für 6 Monate; nach einer auffällig kleinen Datei wird nicht
  aufgeräumt). Der Wochenabschluss mahnt, wenn 30 Tage kein Gerät von Hand gesichert hat. Ein Import ist eine
  Speicherung und zählt als Wartung: das iPhone wertet die abgeschlossenen Wochen, die er ändert (auch Archiv-Noten),
  Mac, Watch und iPad fragen nur das iPhone (`rescore.<Woche>`); die `wertung`-Zeilen behalten die gespeicherten Noten,
  das Zieljahr füllt nur auf (mit sehr altem Zeitstempel – ein später über iCloud ankommendes echtes Zieljahr gilt). „Widerrufen“ gibt es auch nach „Vergangene Woche nachtragen“ (abgeschlossene Wochen,
  deren Tage oder PH zurückgehen, werden neu gewertet). „Diese Woche als CSV“ und der Planungs-Prompt lesen nur diese
  Woche; Dateien über 200 KB stehen im Import als eine Zeile, die Vorschau entsteht abseits des Hauptthreads.
- **Health teilen (nur TestFlight):** Am iPhone (oder iPad) schaltet Einstellungen → Apple Health → „Health-Werte mit
  Mac und Watch teilen“ das Teilen ein (Standard aus, je Gerät, nur sichtbar, wenn das Tor `.allowed` ist: Debug oder
  TestFlight). Dann schreibt genau ein Gerät `hshare.state` und je Tag `hshare.<Tag>` (JSON in `AppSetting`, keine
  Schemaänderung, nie in `SettingKeys.all`, nie in Sicherung, Austausch, Katalog). Geteilt werden die übernommenen
  Health-Werte (`counted`) von heute und den 34 Tagen davor und die Health-Vorschläge (`read`) nur für heute und die 2
  Tage davor. Geschrieben wird nach jedem Übernehmen oder Entfernen (auch ⌘Z/Schütteln), bei jedem Aktivieren und beim
  Tageswechsel, nur bei Änderung und ohne Undo; `read` höchstens alle 30 min. Mac, Watch und iPad zählen die geteilten
  Werte wie übernommene (eigene Werte gehen vor), werten abgedeckte Wochen selbst wie das iPhone und zeigen sie nur
  lesend mit „aus Health am iPhone“ (bzw. „am iPad“, wenn das iPad teilt) – auch unter „Heute eintragen“ der
  Wochenziele; die Zielüberprüfung am Mac zeigt die geteilten Werte. Prompts (Planungs-Prompt, „Bericht kopieren“ der
  Zielüberprüfung) nehmen geteilte Werte nicht mit; der Wochenbericht zeigt sie wie am iPhone. Abgedeckt ist ein Tag
  nur bis 34 Tage vor dem eigenen heute. Ein zweites Gerät, das einschaltet, übernimmt nach Rückfrage; das erste schaltet
  sich selbst ab. Ausschalten löscht alle geteilten Tage. Das Tor hat drei Zustände (App-Transaktion: Sandbox/Xcode →
  erlaubt, App Store → verweigert, sonst unbekannt); ein App-Store-Build löscht beim Start und nach jedem Abgleich alle
  `hshare.`-Datensätze und schreibt den Zustand aus, ein offline gestartetes TestFlight-iPhone löscht nichts. Kommt der Zustand per Abgleich, folgen die Datenschutz-Texte am
  Mac, auf der Watch und am iPad sofort; ein Gerät, dessen Teilen anderswo übernommen oder beendet wurde, schaltet sich
  gleich nach dem Abgleich ab. Mac, Watch und iPad löschen höchstens einmal am Tag geteilte Tage, die älter als 35 Tage
  sind – die Watch auch, wenn sie im Hintergrund weiterläuft. Solange das Teilen im Build ist, geht der Build nur an
  interne TestFlight-Tester.
- **Vor App-Store entfernen – Pflicht vor jedem Einreichen eines Builds zum App Store** (§1.4.12; die Liste mit allen
  Stellen steht in [TESTING.md](TESTING.md) am Ende von „v11“): (a) `grep -rn HEALTHSHARE App Shared Watch Packages
  Config` – 196 Zeilen (Stand 1.10.0) in SettingsView 7, AppModel 18, Editors 7, CloseDayView 1, TodayView 8,
  GoalsView 2, GoalResults 1, ConnectedApps 2, CloseWeekView 1, Glance 1, Services 2, HealthShareSettings 14,
  HealthShareStore 39, WeekReader 2, WeekContext 13, TrackerStore 7, ThaliaWatchApp 7, WatchValues 6, Core
  HealthShare.swift 13, ThaliaTour.swift 2, V11Tests 40, V11BackupTests 2, Config/ci.env 1 – jede Stelle entfernen bis auf die Bereinigung;
  (b) `App/Sources/HealthShareSettings.swift` löschen, in `Shared/HealthShareStore.swift` und
  `Packages/ThaliaCore/Sources/ThaliaCore/HealthShare.swift` nur Tor und Bereinigung behalten (eine Präfix-Abfrage
  beim Start, bleibt dauerhaft); (c) Core-Tests bis auf Schlüssel- und Bereinigungs-Tests löschen; (d) die Absätze in
  TESTING, STATUS, SYNC und TOUR streichen; (e) App-Review-Notiz: keine Gesundheitsdaten in iCloud. Vor dem ersten
  Einreichen klären, ob die App-Prüfung in der Sandbox läuft (dort wäre das Tor offen).
- **Offene Fragen an Bini** ([TASKS-v11.md](TASKS-v11.md) §4) – jede hat eine Regel, die ohne Antwort gilt; v11 ist so
  gebaut:
  F1 iPad oder zweites iPhone selbst werten lassen? – ohne Antwort: iPad wie Mac.
  F2 „✓ über 8“ oder „ab 8“? – ohne Antwort: „✓ über 8“ bleibt, Fußnoten und Tour sagen „ab 8,00“.
  F3 Mac „Schließen“ statt ×? – ohne Antwort: × bleibt.
  F4 Watch direkt auf Seite 1 abhaken? – ohne Antwort: der Sprung zur Kategorie reicht (Erledigtes ist gedämpft).
  F5 Notizen und Lesen auf der Watch? – ohne Antwort: nichts davon in v11.
  F6 Komplikation zu alt? – ohne Antwort: kein Push vom iPhone; zwei Wochen beobachten.
  F7 Siri für Notiz, Seiten, Abhaken? – ohne Antwort: nichts davon in v11.
  F8 Titel und Notizen auf dem Sperrbildschirm ausblenden? – ohne Antwort: wie bisher sichtbar.
  F9 Größere Schrift? – ohne Antwort: bleibt.
  F10 Rückgabewert von „Stand des Tages“? – ohne Antwort: bleibt, die Beschreibung erklärt ihn.
  F11 „Jänner“ oder „Januar“? – ohne Antwort: bleibt gemischt.
  F12 Sicherungen in „Dateien“ / iCloud Drive? – ohne Antwort: nur Application Support.
  F13 Bewegter Verlauf nach 10 s zur Ruhe? – ohne Antwort: bleibt bewegt (im Hintergrund pausiert).
  Entschieden (§1.1): „über 8“ zählt ab 8,00, gerundet auf zwei Stellen; Schonfrist und Notiz am abgeleiteten Haken
  bestätigt (23. Nov. 2026). Weiter offen aus v10: die Darwin-Benachrichtigung zwischen Mac-Apps.
- **Aufgaben für Bini:** zuerst alle Geräte auf 1.10.0, dann TESTING.md „v11“. Den neuen Finn-Auftrag
  ([CONNECTED_APPS.md](CONNECTED_APPS.md) 3.4) erst in Finns Sitzung geben, wenn 1.10.0 auf `main` ist; Theo, George und
  Nina ersetzen, falls schon gebaut, nur ihre kopierte `ExchangeFormat.swift` (nur Zusätze). Die Fragen F1–F13
  beantworten, wo die Regel ohne Antwort nicht passt.
- Geprüft lokal: Core-Tests 285 in 65 Suiten grün (Docker `swift:6.2-noble`; neu `V11Tests.swift` C1–C18 und
  `V11BackupTests.swift`, 28 Tests in 8 Suiten; vorher 207), `swiftc -parse` aller App-, Shared-, Watch- und
  Widgets-Dateien (`scripts/ci/local-check.sh`) und eigens `WatchWidgets/Sources/*.swift`. Jedes Code-Paket hat seine
  Dateien gegen nachgebildete Apple-Module typgeprüft (iOS- und macOS-Zweige je eigens, Watch- und Widget-Ziele mit
  ihrer eigenen Dateiliste) und mit einem absichtlich eingebauten Fehler gezeigt, dass die Prüfung die Dateien sieht.
  Verhaltensprüfungen in Shared mit nachgebildetem SwiftData: P2 (wer wertet, Anfragen, Neuinstallation, Undo,
  Zusammenführen, erster Abgleich – 222 Prüfungen samt v10), P3 (Sicherung hin und zurück auf iPhone und Mac, dieselbe
  Datei auf zwei Geräten, Widerrufen), P7 (Zielverläufe aus den Plänen = Store), P9 (Teilen, Leser, Übernahme, Tor
  `.unknown`/`.denied`, Undo – 55 Prüfungen); App-Verhalten von P3, P4 und P9 ebenso. Die HEALTHSHARE-Prüfung findet
  keine unmarkierte Stelle. SwiftUI, das Aussehen, CloudKit-Ereignisse, HealthKit und `AppTransaction` sind dabei nur
  nachgebildet – das echte SDK prüft erst CI am Mac, das Verhalten das Gerät (TESTING v11).
- Noch offen in v11 (Einzelheiten TASKS-v11 „Nachträge“): ein ✓-Tipp auf iPhone und Mac im TestFlight-Build mit
  `os_signpost` um `WeekContext.init` messen – einen Wochen-Speicher erst, wenn ein Tipp dann noch > 30 ms kostet (P5.1);
  §1.4.12 vor dem App Store; nach dem nächsten CI-Lauf prüfen, ob `mac-goal-detail` und `mac-reading` die Unterseiten
  zeigen (P7.12) und ob `diag: detail check` R ≈ 0 meldet (P4.1).
- CI, Screenshots und TestFlight für 1.10.0: stehen noch aus. Nächste Build-Nr.: 58 (= `SyncDevice.firstV11Build`).

## Stand v10 (Version 1.9.0, Tour-Version 10)
- Anlass: „Thalia Korrekturen v8“ vom 22. Nov. 2026 ([TASKS-v10.md](TASKS-v10.md), vor der Umsetzung von drei
  Prüfern gegengelesen): Jahresziele klarer eintragen und abhaken, Bücher erfassen, rückwirkend eintragen,
  Abschnitte als Versionen der Jahresziele, andere Binisoft-Apps liefern Daten. Abweichungen vom Plan stehen dort in
  „Nachträge (Umsetzung)“.
- **Keine CloudKit-Schemaänderung:** alles Neue ist JSON in `AppSetting` unter eigenen Präfixen (`goal.result.`,
  `goal.entry.<Tag>.`, `goal.segment.`, `list.item.`, `list.progress.<Tag>.`, `link.rule.`, `x.<quelle>.<Tag>`,
  `x.sources`, `score.<Woche>`, Schalter `exchange.catalog`); ältere Builds übergehen die Schlüssel, unbekannte
  Quellen bleiben als `MeasureSource.other` unverändert.
- **P1 Core – fertig:** `SettingRecord` (unbekannte Felder bleiben), Ergebnisse (`GoalResult`, `GoalEntry`,
  `ResultProgress`), „Wochen über 8“ (`GoalTrack`, gerundet ab 8,00), Leseliste (`ListItem`, `ListProgress`,
  `ListMath`), Abschnitte (`GoalSegment`, `Segments`), Austausch-Format v1 (`ExchangeFormat.swift`, zum Kopieren für
  die anderen Apps) und die Wirkung (`ExchangeDerivation`, `LinkRule`), `MeasureSource.app` / `.list`,
  `Measures.merged`, CSV-Zeile `record`, Prompt-Block „Jahresziel-Ergebnisse“ und Link-Regel, Quelle der Vorwoche beim
  Import, Tour 10, Demo-Daten (`DemoV10.swift`, Fixtures unter `Tests/ThaliaCoreTests/Fixtures/exchange`). Tests
  B1–B9 in `V10Tests.swift`.
- **P2 Shared – fertig:** `Shared/TrackerStore+Records.swift` (Datensätze lesen mit Prädikat, speichern, löschen,
  Papierkorb, Widerrufen, Abschnitt beginnen als eine Undo-Gruppe, Einfrieren, `score.` speichern und einmal
  nachtragen), `Shared/ExchangeInboxReader.swift` (`ExchangeScan`, `ExchangeFolders`, `ExchangeMonitor`: App Group
  lesen, Eingang, Katalog schreiben, Entitlement-Prüfung am Mac, Auslöser; nicht auf der Watch), WeekContext v10
  (Abschnitt, Ergebnisse, „Wochen über 8“, abgeleitete Einträge, Arbeit und Haken), WeekReader-Abfragen,
  Export/Backup mit `record`-Zeilen, v9-Abfragen mit Präfix-Prädikat.
- **P3a App – fertig** (Ziele, Leseliste, Abschnitte): neu `App/Sources/GoalResults.swift`, `ReadingList.swift`,
  `Segments.swift`; Ziele-Seite mit Jahreskarte „Abschnitt 2 · seit KW50 · Woche 3“ und Menü ••• (Jahresziel
  eintragen…, Lesen…, Leseliste, Jahresziele bearbeiten, Neuen Abschnitt beginnen…), Ergebnisse, „✓ über 8“ und
  „Wochen über 8“, Messwert-Chips, „Gerade dabei“, frühere Abschnitte; Zielseite mit Ergebnissen und Einträgen,
  „Messwerte diese Woche“ und Zeitraum „Abschnitt“; Zielüberprüfung mit Auswahl Abschnitt/Zieljahr, den Ergebnissen
  und „Neuen Abschnitt beginnen…“; Einstellungen → Jahresziele mit Abschnitten; Rückblick mit Abschnittsgrenzen;
  PDF-Zeitraum „Aktueller Abschnitt“; Woche: „✓ über 8“ am Kategorie-Kopf und „Neu berechnen“ für eingefrorene
  Wochen.
- **P3b App – fertig** (verbundene Apps, Heute, Editoren, Tour): neu `App/Sources/ConnectedApps.swift` –
  Einstellungen → Tracking → „Verbundene Apps“ (je App „Zuletzt gesehen“, Format, Meldungen der letzten 30 Tage;
  „Ohne Zuordnung · …“ mit Kategorie-Auswahl → Zuordnung in Thalia; Zuordnungen mit Herkunft „aus Theo“ / „in
  Thalia“ und „Zuordnung prüfen“; „Was kommt an · letzte 7 Tage“; „Thalia-Katalog bereitstellen“; „Auf diesem Gerät“
  mit „Jetzt nachsehen“). `ExchangeMonitor` läuft für den echten Speicher (iPhone, iPad, Mac; nie `-Demo`, Übung,
  Watch), aktiv/inaktiv über die App-Benachrichtigungen; 8 s nach dem Start einmal `backfillCategoryScores()` und in
  Debug-Builds `verifyPrefixQuery()`. Heute: Power-Hours „aus Theo“ (nur lesen) mit „Übernehmen“, „Aus anderen Apps ·
  ohne Zuordnung“ mit „Übernehmen in …“, Haken „⇄ George · Push“ unter dem Punkt, „aus Nina“ am Messwert, ein
  Messwert mit Quelle Leseliste zeigt „Lesen“ statt − / +; Fokus „Aus anderen Apps“; Ausgaben-Zeilen „aus Finn – in
  Finn ändern“ (Heute und Fenster „Ausgaben“). Messwert-Editor „Quelle“ (Manuell, Power-Hours, Apple Health,
  Leseliste, Verbundene App → App → Art → Eintrag; eine unbekannte Quelle bleibt unverändert) und „Jahresziele“
  („zählt für …“, auch in Heute → Wochenziele und im Fenster „Wochenziele“); Punkt-Editor und Punkt-Details mit der
  Verknüpfung; eine Notiz behält einen abgeleiteten Haken. „Erfassen“ → „Jahresziel eintragen“ / „Lesen“; die
  AppSheet-Fälle für die P3a-Fenster; „Zuletzt gelöscht“ mit Ergebnissen, Leseliste und Abschnitten; vier
  Erklärseiten; Tour-Karten v10 mit „Ansehen“; `-DemoScreen goal-detail | reading | connected-apps` (in
  `Config/ci.env` für iPhone und Mac); Version 1.9.0 (`Config/Base.xcconfig`).
- **P4 Doku – fertig:** [CONNECTED_APPS.md](CONNECTED_APPS.md) (wie es funktioniert, Binis Aufgaben in Reihenfolge,
  je ein vollständiger Auftrag für Theo, George, Nina, Finn und weitere Apps, offene Fragen), [IMPORT.md](IMPORT.md)
  (`link`-Werte `app:` / `list:`, Zeile `record`), [ARCHITECTURE.md](ARCHITECTURE.md),
  [HANDBOOK_PROPOSALS.md](HANDBOOK_PROPOSALS.md) (Vorschläge 31–35), [TOUR.md](TOUR.md) (Tour 10),
  [TESTING.md](TESTING.md) „v10“. Die Bezeichnungen sind mit den Bildschirmen von P3 abgeglichen; P3b hat
  TOUR.md („Ansehen“), TESTING.md „v10“ (Heute, Ausgaben, Editoren, „Verbundene Apps“, Papierkorb, Tour) und diese
  Notiz nachgezogen. In der App heißen die Tatsachen der Austauschdateien „Meldungen“ („12 Meldungen an 9 Tagen ·
  letzte 30 Tage“).
- **Lückenschluss nach der Prüfung – fertig** (Einzelheiten: [TASKS-v10.md](TASKS-v10.md) „Lückenschluss“):
  `x.sources` aus allen Kopien und beim Backup zusammengeführt; Kopien eines Tages überall gleich gewählt; nur
  Tatsachen mit `origin: app` im synchronisierten Eingang (auch aus `record`-Zeilen); geleerte Haken in Backup und
  Wochen-Schnappschuss; Zusammenführen einer Markierung behält einen geleerten Wert; Schonfrist für die Woche vor einem
  neuen Abschnitt (erste Woche); Art eines Buchs geändert → Neuwertung; Nachtragen der Kategorie-Noten je Woche und
  nach jedem Abgleich; Ziel und neue Ergebnisse für einen geplanten Abschnitt; kein zweiter Abschnitt in derselben
  Woche, doppelte löschbar; unbekannte Felder in Schnappschüssen; Bezeichnungen alter Wochen im Wochenblatt; Leseliste
  auf Watch, in „Messwert eintragen“ und den Kurzbefehlen nur über „Lesen“; Wochenberichte mit
  „Jahresziel-Ergebnisse“; „Buch hinzufügen“ in „Lesen“; Import-Hinweis für eingefrorene Wochen; Lesefehler bleiben
  sichtbar, Dateien über 256 KB ausgelassen; Kennzahlen ohne „Eintrag“; Namen aus `source.json`.
- Tour 10: vier Karten `since: 10` – „Ergebnisse und Wochen über 8“, „Leseliste“, „Abschnitte“ (nach „review“),
  „Verbundene Apps“ (nach „everywhere“); 21 Karten in der ganzen Tour.
- Geprüft lokal: 207 Core-Tests in 39 Suiten grün (Stand nach dem Lückenschluss; davor 195 in 36) (Docker `swift:6.2-noble`) und `swiftc -parse` aller App-Dateien
  (`scripts/ci/local-check.sh`); Shared gegen Stub-SwiftData im Docker typgeprüft, 104 Verhaltensprüfungen grün
  (zwei weitere bewusst so belassen: Notiz an einem abgeleiteten ✓, erstes Nachsehen – siehe TASKS-v10
  „Lückenschluss“) und die v9-Prüfungen weiter grün; das Schreiber-Beispiel der Aufträge mit dem echten `ExchangeFormat.swift` in Swift 5 und 6
  übersetzt (7 Prüfungen mit einem temporären Ordner); die CSV-Beispiele aus IMPORT.md durch `PlanCSV` gelesen.
  App-Teile von P3 gegen echtes Core und Shared mit SwiftUI-/Charts-Stubs typgeprüft: P3a die Ziel-, Leseliste- und
  Abschnitt-Ansichten; P3b `ConnectedApps.swift`, `Explainers.swift`, `AppModel.swift`, `TourView.swift`,
  `Expenses.swift` und `Focus.swift` ganz, dazu die geänderten Teile von Heute (Seite einer Kategorie, Punkt-Zeile,
  Messwert-Zeile, -Menü und -Eingabe, Wochenziele, „Abschluss & Notizen“), des Fensters „Wochenziele“, von
  „Erfassen“, Punkt-Details, Punkt- und Messwert-Editor, „Zuletzt gelöscht“, der Fenster-Auswahl (`SheetContent`,
  `AppChrome`) und der Mac-Menübefehle, nach dem Lückenschluss auch die Kopf-Zeile der Kategorie in Wochenblatt
  und Wochentabelle (mit ihren Zeilen), `WatchPages`, `LogMeasureIntent.refusal` und „Bericht kopieren“ /
  „Wochenbericht kopieren“ im Wortlaut der App – ohne Fehler; ein absichtlich eingebauter Fehler wird in jeder dieser Dateien
  gefunden; keine geänderte Ansicht über 160 ms Typprüfung. Die Zweige nur für iOS bzw. nur für macOS
  (`#if os(…)`) dieser P3b-Teile sind in je einem eigenen Lauf mitgeprüft (darin die App-Benachrichtigungen für
  „aktiv/inaktiv“ des Austauschs), mit nachgebildeten UIKit-/AppKit-Namen. SwiftUI ist dabei nur nachgebildet; echtes
  SwiftUI, das Aussehen und der App-Teil des Austauschs (App Group, Darwin-Benachrichtigung, `SecTask`) prüft erst CI
  am Mac bzw. das Gerät.
- Fragen an Bini ([CONNECTED_APPS.md](CONNECTED_APPS.md) §5): „über 8,0“ – Entschieden (23. Nov. 2026): ab 8,00,
  gerundet auf zwei Stellen; Finn-Vermögen – entschieden (23. Nov. 2026): bei jeder Änderung, jede Zeile in Finn einzeln
  wählbar (Sparquote, Kontostände, TASKS-v11 §1.5); offen bleibt nur: Darwin-Benachrichtigung zwischen Mac-Apps
  ungeprüft.
- CI-Lauf 37 grün (macOS + iOS + watchOS gebaut, 207 Core-Tests); Screenshots `goal-detail`, `reading`,
  `connected-apps` (iPhone) und `goals`, `connected-apps` (Mac) angesehen. Am Mac zeigen `goal-detail` und `reading`
  die Ziele-Seite (mit „Gerade dabei“), nicht die Unterseite – nur das Bildschirmfoto, kein App-Fehler (v11 P7.12: die
  Unterseite öffnet jetzt 1,5 s nach der Ziele-Seite, `GoalsLaunch.handled` erst, wenn sie erschienen ist – nach dem
  nächsten CI-Lauf prüfen). Kein
  CloudKit-Schema-Lauf nötig (`schema.ckdb` und `Shared/Models.swift` unverändert). TestFlight: **1.9.0 (57)**
  hochgeladen (iOS + watchOS + macOS, `testflight-diagnose.yml` Lauf 7); laut `asc-probe` am 22. Nov. 2026 18:35 UTC
  iOS verarbeitet und `IN_BETA_TESTING`; macOS laut `asc-probe` am 23. Nov. 2026 16:38 UTC ebenso. Die Adressen in den Aufträgen (`main`) sind
  erreichbar. Nächste Build-Nr.: 58.
- Nächste Schritte: Bini – Aufgaben aus [CONNECTED_APPS.md](CONNECTED_APPS.md) §2 der Reihe nach, TESTING.md „v10“,
  die Fragen in §5 beantworten.

## Stand v9 (Version 1.8.0, Tour-Version 9)
- Anlass: fünf Import-Probleme beim Nachtragen alter Wochen aus Scans ([TASKS-v9.md](TASKS-v9.md)). Pakete P1 Core,
  P2 Shared und P3 App umgesetzt:
  **Archiv-Wochen** – eine Woche der Datei ohne `item`-Zeilen und ohne Markierungen (nur `week`, `day`, Noten) bekommt
  keine Punkte, wird nie mit ✗ gefüllt und wie jede vergangene Woche abgeschlossen; **neue Zeilentypen**
  `category_score` und `goal_score` (Noten 0–10, ursprüngliche Bezeichnung, Quelle, Spalte `count`), gespeichert als
  CSV im Setting `archive.<Woche>` (keine CloudKit-Schemaänderung), Teil von Backup, Archiv und Widerrufen;
  **zwei Wertungen** – „Wertung laut Unterlagen“ (`recordedScore`, nie berechnet) und „Nach heutigen Regeln“
  (`finalScore`, aus den Kategoriennoten ohne Krank-/Urlaubstage); `historyScore = recordedScore ?? finalScore`
  (bisher umgekehrt); **Mittelwerte** über vorhandene Noten, echte Nullen zählen, erst die Anzeige rundet;
  **„Ohne Zuordnung (Archiv)“** für alte Bezeichnungen – nichts wird aufgeteilt, vervielfacht oder zu Haken;
  **„Archivdaten dieser Wochen ersetzen“** (Schalter im Weg „Mit ChatGPT“) für den erneuten Import: alles, was die
  App für die vergangenen Wochen der Datei hat, kommt ins Archiv, „Widerrufen“ holt es zurück, diese und spätere
  Wochen nie; **neuer Prompt** (`PastWeekPrompt`, Regeln 1–10, Kopfzeile mit `count`, Beispiel mit zwei Wochen,
  Ziele/Kategorien/Messwerte mit ids, Vorlage nur für belegte Einzelhaken) – zum erneuten Schicken der Scans.
- App (P3): neue Datei `App/Sources/ArchiveCard.swift` – Karte „Archiv“ in der Woche (iPhone unter dem Kopf, Mac/iPad
  in den Spalten der Wochentabelle, beide Wertungen in der Seitenleiste), Wochen-Kopf einer Woche ohne Punkte mit
  dem Wert laut Unterlagen; Nachtragen-Fenster mit dem Ersetzen-Schalter und „Archiv“ je Woche in der Vorschau;
  Rückblick-Zeilen mit „Archiv“ und beiden Wertungen; PDF-Bericht mit Kennzeichen „Archiv“ und Fußnote; Archiv-Liste
  „ohne Punkte“ und „Was die Woche jetzt hat, kommt dafür ins Archiv.“; Erklärungen „Vergangene Wochen“ mit
  Schritt „Archiv-Wochen“ (die Karte heißt jetzt „Neu seit 1.7“); Heute an einem Tag einer Archiv-Woche zeigt
  „KWnn ist eine Archiv-Woche“ mit beiden Wertungen und den Noten des Tages statt „Noch kein Plan“.
- Tour 9: eine Karte `archive` („Archiv-Wochen“, `since: 9`), siehe [TOUR.md](TOUR.md). Demo: die Woche zwei Wochen
  vor der aktuellen hat 16 Kategoriennoten mit Urlaub-Samstag, eine Note ohne Zuordnung („Sonderwoche“) und
  10 Zielnoten. CI-Screenshot zusätzlich `archive` (iPhone und Mac).
- Geprüft lokal: 141 Core-Tests grün (Docker `swift:6.2-noble`), `swiftc -parse` aller App-Dateien; Shared und die
  nicht-UI-Teile von `ArchiveCard.swift` gegen Stub-SwiftData im Docker typgeprüft und mit Verhaltensprüfungen
  (Import, Ersetzen, Widerrufen, Demo, Beispiel aus IMPORT.md). SwiftUI-Teile prüft erst CI am Mac.
- Lücken nach der Durchsicht geschlossen ([TASKS-v9.md](TASKS-v9.md) §5): Zeilen bleiben in ihrem Block (Tag oder
  Note mit fremdem Datum → übersprungen, nie in eine andere Woche); „Archivdaten ersetzen“ nur für Wochen mit
  `week`-Zeile und nicht, wenn die Datei genau das bringt, was die App hat; Archiv-Wochen ohne Messwert-Definitionen;
  Motto, Kontext und Wertung laut Unterlagen bleiben bei leerer Datei-Zeile, laufende Woche ohne Wochenwert;
  Dezimalkomma ohne Anführungszeichen, Werte außerhalb 0–10 und Unlesbares werden erkannt statt falsch übernommen;
  Tagesnoten in `mo … so`, deutsche Spalte `quelle`, Warnungen für zwei Bezeichnungen auf einer id und mehrere
  CSV-Blöcke; Wochenwert exakt im Export; Prompt mit Platzhalter-Beispiel (`JJJJ-Wnn`), Dezimalpunkt-Regel, Regeln für
  Zielnoten, Widersprüche und „neu erstellen“; Widerrufen behält einen Schnappschuss, wenn die Woche nach dem Import
  geändert wurde; Rückblick „Archiv“ nur für Wochen ohne Punkte. 156 Core-Tests grün.
- Nicht umgesetzt (bewusst): die Textabschnitte der alten CSV („Kategoriennoten der Übersicht:“ in `day.note`,
  „Kategorienmittel …“ in `week.note`) werden nicht ausgelesen – der neue Prompt lässt ChatGPT die CSV mit echten
  Notenzeilen neu erstellen. Fehlende Einzelhaken, Arbeitszeiten und Messwerte bleiben unbekannt.
- `MeasureSource.other`: Quellen, die dieser Build nicht kennt (`app:…`, `list:…` aus 1.9), bleiben beim Speichern
  unverändert – ein Gerät mit 1.8.0 löscht keine Verknüpfung der nächsten Version.
- CI-Lauf 36 grün (macOS + iOS + watchOS gebaut, Screenshots `archive` iPhone/Mac angesehen). TestFlight:
  **1.8.0 (56)** hochgeladen (iOS + watchOS + macOS, `testflight-diagnose.yml` Lauf 6); laut `asc-probe` am
  22. Nov. 2026 17:01 UTC iOS und macOS verarbeitet und `IN_BETA_TESTING`. Nächste Build-Nr.: 57.
- Nächste Schritte: Bini testet TESTING.md „v9“; Prompt neu kopieren, Scans erneut schicken, CSV mit „Archivdaten
  dieser Wochen ersetzen“ importieren (vorher die Liste „ersetzt“ in der Vorschau prüfen).

## Stand v8 (Version 1.7.0, Tour-Version 8)
- Drei Wünsche vom 21. Nov. 2026 aus [TASKS-v8.md](TASKS-v8.md), Pakete P1–P5 umgesetzt:
  **Krank & Urlaub** (Tagestypen, die nicht in die Wochenwertung zählen; „n× pro Woche“ zählt den entschuldigten
  Teil halb, Regel B3; Wochenziele skaliert, „4,8 statt 8 PH – 2 Tage krank“; ganze Woche „entschuldigt“),
  **Vergangene Woche nachtragen** (Fenster mit „Vom Plan“, „Mit ChatGPT“ – viele Wochen in einer CSV,
  Vorschau je Woche, Abschluss der importierten Wochen – und „Nur Wertung“; CSV mit Matrix-Spalten `mo…so`) und
  **PDF-Bericht** über mehrere Wochen (Deckblatt, Übersicht je Woche, PH je Bereich, Wochenseiten, seitenweise mit
  Fortschritt, PDFKit-Vorschau, Lesezeichen; Mac ⌥⌘P, Sichern, Drucken).
- Geprüft: 125 Core-Tests in 18 Suiten grün (Docker `swift:6.2-noble`), CI-Läufe 33–35 grün (macOS + iOS gebaut,
  Screenshots angesehen). Nach CI 33 behoben: Wege-Auswahl „Vom Plan“ (statt abgeschnittenem „Plan übernehm…“),
  Prompt-Knöpfe als ganze Zeilen (auch im Planungs-Import), PDF-Spalte „Wertung“ einzeilig, breitere Wochenbalken,
  Papier-Wochen zählen als abgeschlossen, Uhrzeit im PDF-Fuß deutsch (14:43 statt 2:43 PM).
- TestFlight: 1.7.0 (54) hochgeladen, hat aber einen leeren „Prompt kopieren“-Knopf im Nachtragen-Fenster –
  **1.7.0 (55)** ist der Build zum Testen (iOS + watchOS + macOS, `testflight-diagnose.yml`, Build-Nr. als Eingabe;
  laut `asc-probe` am 21. Nov. 2026 für iOS und macOS verarbeitet und `IN_BETA_TESTING`).
- Keine CloudKit-Schemaänderung: Tagestypen bleiben Text (`PlanDay.dayType`), kein neues `@Model`-Feld.
- Neue Dateien: `App/Sources/PastImport.swift`, `App/Sources/RangePDF.swift`, `Shared/TrackerStore+Range.swift`,
  Core-Tests `V8Tests.swift`. Neue Fenster: `AppSheet.importPast(WeekKey?)`, `AppSheet.rangePDF`.
- Tour 8: drei neue Karten `since: 8` (Krank & Urlaub, Vergangene Wochen, PDF-Bericht), siehe [TOUR.md](TOUR.md).
  Erklärungen: „Wie wird gerechnet?“ endet mit „Neu in 1.7“ (drei Seiten). Demo-Daten: Freitag der aktuellen Woche
  ist „Krank“ (nur `-Demo`, nicht die Übungsseite der Tour). Einstellungen → Hilfe nennt die drei Seiten auch einzeln.
  CI-Screenshots zusätzlich `past-import` und `range-pdf` (iPhone und Mac).
- Offen bzw. zu prüfen: Dateigröße langer Berichte (Bänder als einfacher Verlauf, sollte Vektor bleiben) – am Gerät
  mit „Zieljahr bis heute“ + „Rückblick-Texte“. Kleine Lücken: siehe „Offene Punkte v8“ unten.
- Nächste Schritte: Bini testet 1.7.0 (55) nach TESTING.md „v8“. Nächste Build-Nr. für TestFlight: 56 oder höher.

### Offene Punkte v8
- Läuft CI an einem Freitag, zeigen die Demo-Screenshots „today“, „close-day“ und „overview“ den Krank-Tag statt eines
  normalen Tags (Demo-Freitag ist immer „Krank“, so verlangt in Entscheidung 11).
- Erledigt beim Lückenschließen: Import (und Widerrufen, Archiv-Wiederherstellen) plant die Abend-Erinnerungen neu;
  `closingKnownDays`/`fillingPastBlanks` liegen jetzt in ThaliaCore (`PlanCSV.Document`) mit Repo-Tests; ein Wochenziel,
  dessen Tage alle krank/Urlaub sind, wird nicht bewertet (fehlt in „x von y erreicht“, PDF, Widgets; Hinweis „zählt
  nicht“); Wochen-Kopf und Mac-Seitenleiste zeigen „Woche zählt nicht (krank/Urlaub)“; die Ziel-Diagramme zeigen eine
  ganz entschuldigte Woche als graue Säule.

## Stand v7 (Version 1.6.0, Tour-Version 7)
- Alle neun Pakete P1–P9 aus [TASKS-v7.md](TASKS-v7.md) sind umgesetzt (R1–R97 und H1). Lokal geprüft: Core-Tests grün,
  `swiftc -parse` für App, Shared, Watch, Widgets und WatchWidgets. Typprüfung und Build laufen erst in CI am Mac.
- Keine CloudKit-Schemaänderung (nur lokale `#Index`, Schema-Diff leer). Neu: Watch-Komplikation als eigenes Target
  `ThaliaWatchWidgets` – Owner-Schritt vor `[testflight]`: App-ID `…watchkitapp.widgets` mit App Group (siehe [SETUP.md](SETUP.md)).
- Neue Dateien: `App/Sources/SheetChrome.swift` (Toasts im obersten Fenster, `thaliaSheetFrame`, ×-Knopf), `Glance.swift`,
  `Focus.swift`, `Expenses.swift`, `MenuBar.swift`; `Shared/WidgetPublisher.swift`, `WidgetActions.swift`, `GoalPalette.swift`;
  Core `Merge.swift`, `SyncGerman.swift`; `WatchWidgets/`. Kontrastfarben (R44) als Assets `ThaliaAccentFill`, `Mark…Text`.
- CI: Lauf 21 sofort grün (Build), Screenshots geprüft. Mac zeigte in 21–24 kein Fenster: `@AppStorage` im App-Struct an
  `MenuBarExtra(isInserted:)` blockierte den Hauptthread nach dem Start (gefunden mit `LaunchDiagnostics`, nur Debug).
  Behoben in Lauf 25 (Schalter im AppModel). Dazu: Datum/Uhrzeit-Picker immer deutsch, Kategorie-Kopf einzeilig.
- Mac-Layout nur am CI-Bildschirm (1024 × 768) gesehen: dort wird die Seitenleiste schmal und rechts abgeschnitten;
  auf normalen Mac-Bildschirmen (Fenster 1180 pt) prüfen. – v11 (P4.1): Inspektoren zeigen sich nur noch, solange sie
  passen, sonst als Blatt; die Heute-Liste höchstens 340 pt (siehe „Stand v11 – Mac-Layout“; bei 1024, 1180 und 900 pt
  am Gerät prüfen).
- TestFlight: macOS 1.6.0 (47) stürzte am Mac ab (AppKit-Toolbar bei `.toolbar(id:)`); iPhone 1.5.0 stürzte beim Tippen
  auf eine Mitteilung ab (async-Delegate). Beides behoben → **iOS + Watch + macOS 1.6.0 (52)** hochgeladen über
  `testflight-diagnose.yml` (Build-Nr. als Eingabe). Der reguläre TestFlight-Workflow hat als nächste Run-Nr. 52: für
  1.6.0 nicht mehr verwenden (Build 52 existiert), sonst neue Version oder Diagnose-Workflow mit Nummer > 52.
- iOS-Export scheiterte dreimal mit „Error Downloading App Information“: laut Distribution-Log HTTP 500 von
  `GET /v1/apps?…include=appStoreVersions` (Apple-Serverfehler, kam und ging). `asc-probe.yml` prüft diese Anfragen.
- 1.6.1: Sync-Prüfung (Workflow mit Gegenprüfung) – 4 Fehler und 7 Risiken behoben, „Geräte im Abgleich“ in den
  Einstellungen, Produktions-Schema geprüft (alle Felder da). Details und bekannte Grenzen: [SYNC.md](SYNC.md).
  Health am Mac: bleibt (Regel 5.1.3(ii)) bis Bini A/B entscheidet.
- TestFlight: **1.6.1 (53)** für iOS + Watch + macOS hochgeladen (testflight-diagnose.yml, Build-Nr. 53). Nächste
  Uploads: Build-Nr. > 53 (regulärer Workflow erst ab Run 54 verwenden oder Diagnose-Workflow mit Nummer).
- Nächste Schritte: Bini testet nach TESTING.md „1.6.1“ und „v7“.
- Bekannte Risiken mit Ausweichweg: [TASKS-v7.md](TASKS-v7.md) Abschnitt 7 (Widget-Abhaken aus der Erweiterung, `#Index`
  mit CloudKit, Transaktion-Betrag, Ziffernblock-Leiste).

## Repos und Regeln
- App: `Binisoft-at/thalia` → lokal `/home/user/thalia`. Push auf `claude/gifted-mendel-nn3d4f` **und** `main` (Handbuch: direkt auf main; CI läuft nur auf main).
- Handbuch: `Binisoft-at/binisoft-handbook` (Tag `v1`) → `/home/user/binisoft-handbook`. Regeln: README, HOW_WE_WORK, CONVENTIONS, SETUP_CHECKLIST. Nie `Vendor/BinisoftKit` oder `scripts/ci` in der App ändern.
- Commits enden mit `Co-Authored-By: Claude <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_01GTSNJwt4VJSPttHHHbqj92`. Keine Modellnamen.
- Antworten an Bini: kurz, Deutsch, Format HOW_WE_WORK §6 (gebaut · wo · Build-Nr. · ausprobieren · nächste Schritte · Fragen A/B · verifiziert/nicht).

## Checks
- Lokal: Docker-Daemon ggf. starten (`sudo dockerd &`), dann `make check` (Core-Tests in `swift:6.2-noble` + `swiftc -parse`).
- CI-Ergebnis: `git fetch origin ci-output && git show origin/ci-output:ci/status.txt` (Fehler: `ci/errors.txt`, Screenshots: `ci/shots/`).
- TestFlight: `[testflight]` in der Commit-Nachricht oder Workflow manuell; Ergebnis auf `ci-testflight` (`status.txt`, `uploaded.txt`). Build-Nr. = Run-Nr.
- App-Store-Connect-Status: Workflow `asc-status.yml` (read-only) → `ci-output:asc/status.txt`.
- CloudKit: `cloudkit-schema.yml` → `ci-testflight`? nein: `ci-cloudkit` (`status.txt`, `needs-deploy.txt`). Schema aus Modellen: `tools/schema-from-models.py Shared/Models.swift HealthValue`.
- Achtung: TestFlight und CI gleichzeitig auf main → der Mac-Job kann ohne Runner abgebrochen werden; dann „rerun failed jobs“.

## Stand v1 (erledigt)
- Setup-Checkliste (Artifact): https://claude.ai/artifact/8xyJXeSDbZDD8fMeZF3Air – alles bis 6.2 erledigt (db-Collection `steps`).
- TestFlight **Build 8** (iOS + macOS 1.0.0) hochgeladen, VALID, IN_BETA_TESTING. CloudKit-Schema in Production deployed (14 Record-Typen).
- Bini hat den Grundablauf getestet, Sync iPhone↔Mac funktioniert. Health, Widgets usw. noch nicht.
- Offene A/B-Fragen aus v1 (unbeantwortet): Sprache (A Deutsch), Health-Werte nur Gerät (A), Papier-Historie importieren (A), Erinnerungszeiten (A 08:15/21:45/So 17:00).

## Architektur (Kurz)
- `Packages/ThaliaCore` (Linux-getestet): Calendar (DayKey/WeekKey/DayMask/GoalPeriod), Vocabulary (Mark, ItemSchedule, Target, Units, MeasureSource, WorkKind, DayTypes, NoteKind, ReflectionQuestion), Records, Scoring (Scorer, Pace, v11 PaceStatus), Measures (+WorkTotals), PlanCSV, ImportPreview, Template, Demo, Reports (WeekReport, PlanPrompt, PastWeekPrompt, WeekLine/RangeReport), ThaliaTour (+TodaySummary, ReminderSettings), Format; v10: SettingRecord, GoalResults, GoalTrack, Lists, Segments, ExchangeFormat (Format v1 zum Kopieren), Exchange (ExchangeDerivation, LinkRule), WeekExtras, DemoV10; v11: SyncDevices (SyncBuild, allCurrent), HealthShare (HEALTHSHARE).
- `Shared/`: Models (SwiftData, Schlüssel statt Relationen, HealthValue device-only), TrackerStore(+Import, +Range, +Records), WeekContext/WeekReader, ExchangeInboxReader (nicht auf der Watch), Persistence, DemoData, WidgetBridge, WidgetPublisher, WidgetActions, RouteIntents, GoalPalette; v11 HealthShareStore (HEALTHSHARE).
- `App/Sources`: AppModel, RootView, TodayView, WeekView, GoalsView, GoalResults, ReadingList, Segments, ReviewView, CloseDayView, CloseWeekView, Editors, ImportView, PastImport, PDFExport, RangePDF, SettingsView, Explainers, Services (Reminder, Health), Intents, TourView, Components, AppPlatform, ThaliaApp, Glance, Focus, Expenses, MenuBar, Sharing, SheetChrome, Style, ArchiveCard, ConnectedApps, WeekTable, LaunchDiagnostics; v11 Backups, BackgroundGrace, HealthShareSettings (HEALTHSHARE).
- `Watch/Sources`, `Widgets/Sources`. Screens für CI-Screenshots: `Config/ci.env`.

## v2 – Fortschritt
Siehe Status-Häkchen in [TASKS-v2.md](TASKS-v2.md). Nächster Schritt steht dort unter „Jetzt“.

Stand 9. Nov. 2026: v3 fertig – Repo öffentlich (Historie auf einen Commit neu geschrieben), CI grün,
**TestFlight 1.2.0 (25)**. Aufgaben und Plan: [TASKS-v3.md](TASKS-v3.md).

Stand 4. Nov. 2026: v2 fertig gebaut. CI run 8 grün (4131b80), Screenshots geprüft, CloudKit-Schema
importiert (run 4) und von Bini nach Production deployt (5.3), **TestFlight 1.1.0 (16)** für iOS und
macOS hochgeladen (run 16, 810df85). Tour-Version 2 („Neu in Thalia“ für die geänderten Schritte).
Offen: Bini testet laut [TESTING.md](TESTING.md); M1 (Mac) nach Feedback weiter verfeinern
(z. B. Wochen-Raster als dichte Tabelle).
