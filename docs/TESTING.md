# Thalia – was Bini selbst testen muss

Dinge, die nur auf echten Geräten mit deinem Account gehen. Abhaken und bei Problemen:
Einstellungen → Diagnose → App-Protokoll → Protokoll kopieren → in den Chat.

## iCloud-Sync
- [ ] iPhone: einen Punkt abhaken → am Mac nach ein paar Sekunden sichtbar? (App am Mac im Vordergrund)
- [ ] Mac: einen Messwert eintragen → am iPhone sichtbar?
- [ ] Beide gleichzeitig: denselben Punkt auf beiden Geräten unterschiedlich setzen → es gewinnt die zuletzt gemachte Änderung (achten: keine doppelten Einträge).
- [ ] Einstellungen → iCloud & Daten zeigt „On · synced …“.
- Hinweis: Wann iCloud synchronisiert, bestimmen iOS/macOS (meist Sekunden, manchmal länger, schneller wenn die App offen ist). Thalia speichert jede Änderung sofort und hört auf iCloud-Push; schneller erzwingen lässt es sich von der App aus nicht. Tippst du auf beiden Geräten in **denselben** Wert, gewinnt die zuletzt gespeicherte Änderung.

## Apple Health (nur iPhone)
- [ ] Einstellungen → Apple Health → Vorschläge einschalten → „Zugriff erlauben“ → Health-Dialog erscheint, Kategorien freigeben.
- [ ] Bei einem Messwert mit Health-Quelle (Schlaf, Gewicht, Wasser …) erscheint ein rosa „Health: …“-Vorschlag, wenn es dort Daten gibt.
- [ ] Vorschlag übernehmen → Wert zählt; am Mac erscheint **kein** Health-Wert (bleibt auf dem iPhone, so gewollt), deine Markierung aber schon. (Ausnahme nur in der TestFlight-Version mit „Health-Werte mit Mac und Watch teilen“ – siehe „v11“.)
- [ ] Eigener Wert eingetragen → Vorschlag verschwindet, eigener Wert hat Vorrang.

## Erinnerungen
- [ ] Einstellungen → Erinnerungen: Mitteilungen erlauben; Testzeit 2 Minuten in die Zukunft stellen → Mitteilung kommt.
- [ ] Tippen auf „Tagesabschluss“-Mitteilung öffnet direkt „Tag abschließen“.

## Widgets
- [ ] Home-Bildschirm: Widget „Heute“ (klein + mittel) und „Woche“ (mittel + groß) hinzufügen – Werte stimmen mit der App?
- [ ] Sperrbildschirm: rundes und rechteckiges „Heute“-Widget.
- [ ] Tippen aufs Widget öffnet Thalia am richtigen Ort.
- [ ] Nach einer Änderung in der App aktualisiert sich das Widget (kann ein paar Sekunden dauern).

- [ ] **Kontrollzentrum (v2):** Kontrollzentrum bearbeiten → „+ Steuerelement“ → Thalia „Power-Hours erfassen“ hinzufügen → tippen öffnet Thalia direkt im Power-Hours-Fenster (auch aus geschlossener App). Geht auch auf dem Sperrbildschirm und auf der Aktionstaste.
- [ ] Widget zeigt Prozent ausgefüllt und „Weiter: <Kategorie>“; erst nach „Tag abschließen“ die Tageswertung.

## Kurzbefehle / Siri
- [ ] Kurzbefehle-App → Thalia: „Power-Hour erfassen“ (Anzahl auch 0,5), „Messwert eintragen“, „Stand des Tages“, „Power-Hours mit Beschreibung“, „Tag abschließen“ ausprobieren.
- [ ] „Hey Siri, Thalia Power-Hour“.

## Apple Watch
- [ ] Watch-App installieren (iPhone → Watch-App → Verfügbare Apps).
- [ ] Erste Seite: Ring = Prozent ausgefüllt; „Power-Hours“ → Bereich → Anzahl (2 Tipps).
- [ ] Nach oben wischen: eine Seite pro Kategorie. Kreis links tippen = ✓ (nochmal = leeren); Titel tippen → ✓ ½ ✗ N/A.
- [ ] Werte mit − / + ändern → am iPhone sichtbar.

## Mac
- [ ] Heute: links Kategorien mit Prozent, rechts die Kategorie, rechts außen die Tagesübersicht (Symbolleiste blendet sie ein/aus). Wirkt es wie eine Mac-App? Was fehlt?
- [ ] Symbolleiste: ‹ Heute › (auch ⌘[ ⌘] und „Zu heute“ ⌘T – seit 1.10.0 statt ⇧⌘T), „Tag abschließen“, „+“.
- [ ] Menü „Gehe zu“ (⌘1–4), ⌘N (Power-Hours), ⇧⌘I, ⌘↩ (Tag abschließen).
- [ ] Einstellungen über ⌘,.

- [ ] **Woche am Mac (ab dem nächsten Build):** Tabelle aller Punkte × Mo–So, Kopfzeile bleibt oben; rechts Wochenwertung, Ziele, Wochenziele (Symbolleiste blendet ein/aus); Klick auf eine Zelle schaltet durch die erlaubten Markierungen; Rechtsklick → alle; ⇧⌘[ / ⇧⌘] wechselt die Woche. Gleiches auf dem iPad quer.

## Heute (v2) – iPhone
- [ ] Oben: Datum (antippen → anderer Tag), rechts Prozent ausgefüllt; Ring antippen → Tagesübersicht.
- [ ] Kategorie-Chips antippen oder seitlich wischen; ✓ ½ ✗ N/A mit **einem** Tipp, nochmal tippen leert.
- [ ] Wochenpunkt (z. B. 3×/Woche): N/A verschwindet, sobald die restlichen Tage nicht mehr reichen.
- [ ] Fortschrittspunkt (stammloop): „✓ Gearbeitet“ / „Nicht heute“, Balken „Wochenziel x %“; ab 100 % zählen alle „Gearbeitet“-Tage als ✓.
- [ ] Messwert: Zahl direkt eintippen, − / +; Uhrzeit mit „Jetzt“ bzw. Zeitwähler; PH-Kachel: + = 1 PH, halten = 0,25–2 PH.
- [ ] Kategorie-„Zwischenstand“ erscheint erst, wenn alle Punkte der Kategorie ausgefüllt sind.
- [ ] Unten (über der Tableiste): Prozent, Mond = Tag abschließen, „+“ = Erfassen.
- [ ] „Tag abschließen“: offene Punkte direkt bewerten, „Ins Journal eingetragen“ abhaken, Notiz optional → danach erst die Tageswertung.
- [ ] Einstellungen → „Bedingte Punkte zuerst abfragen“ ein → in der Kategorie „Gab es die Situation heute?“ → nur Vorgekommenes bewerten, Rest wird N/A.

## Import / Woche
- [ ] Planungs-Prompt in ChatGPT → CSV zurück → einfügen → Vorschau → Importieren.
- [ ] Dieselbe Woche nochmal importieren (überarbeitet) → Vorschau sagt „ersetzt den bisherigen Plan“; danach Einstellungen → Archiv ersetzter Wochen → alte Woche da, „Wiederherstellen“ tauscht zurück.
- [ ] Punkt oder Messwert in der App anlegen/ändern/löschen (mit/ohne „Auch in den nächsten Wochen“) → Einstellungen → „Meine Änderungen am Plan“ listet sie → nächster Planungs-Prompt enthält „Meine Änderungen in der App“ mit „dauerhaft übernehmen“ / „nur diese Woche“.
- [ ] Power-Hours: + unten → Power-Hours → Bereich, 0,25/0,5/0,75/1/2, Beschreibung (Vorschläge aus früheren Einträgen) → in der Liste steht immer die Kategorie dabei.


## v3 (ab Version 1.2.0)
- [ ] Kategorie mit Wochenziel (stammloop, Aufschläge …): oben „Wochenziele“ mit Balken, „x von y“, „heute +x“, Tempo-Strich; Wert direkt eintragen → „An … gearbeitet“ wird **automatisch** ✓ (nicht abhakbar), Text erklärt, wie es zählt.
- [ ] PH-Kachel: − / Zahl tippen / +; + halten = 0,25–2 PH. Abziehen funktioniert (verkleinert den letzten Eintrag).
- [ ] „Power-Hours heute“: Beschreibung direkt in der Zeile tippen; neue Zeile „1 PH · Neu: wofür? · +“ mit Vorschlägen.
- [ ] Uhrzeit (Bettzeit): Zeitwähler direkt (blass = noch nicht gespeichert), ✓ übernimmt den Vorschlag; kein „Jetzt“ mehr.
- [ ] Listen-Symbol im Kategoriekopf / „Alle offenen Punkte des Tages …“ auf der Tag-Seite: ✓ ½ ✗ für alle, „Alle leeren“; Widerrufen im Hinweis.
- [ ] Nebensachen (von der KI markiert oder per Rechtsklick/langem Druck „Als Nebensache“) liegen unter „Weitere“; leer blockieren sie nichts. „Doch wichtig“ landet im nächsten Prompt.
- [ ] 3×/Woche-Punkt nach 3 Mal: verschwindet aus den Folgetagen, steht unter „Diese Woche schon erfüllt“.
- [ ] Tagestyp „Familientag“/„Erholungstag“: Business-Punkte (außer Morgenroutine) und PH-Kacheln verschwinden, Hinweis oben; Fülle erreicht trotzdem 100 %.
- [ ] Tag abschließen: Kopf mit Verlauf; Fehlende Werte eingeklappt mit Eingabe; nach dem Abschließen bleibt das Fenster offen → Wertung, kleine Feier ab 8, „Tag als Bild teilen“.
- [ ] Woche abschließen / Bericht: „Woche teilen“ (Vorlagen Aurora, Klar, Nacht; Zielnamen optional) und „PDF erstellen → PDF teilen“ (Zusammenfassung + alle Kategorien × Mo–So).
- [ ] Zahlen: Wertungen mit bis zu 2 Nachkommastellen (7,25 · 8,5 · 10).

## v4 (ab Version 1.3.0)
- [ ] Heute: Pillen oben zeigen Nummer + Kurzname in Zielfarbe; Raster-Symbol links → alle Kategorien nach Ziel, Tippen springt hin.
- [ ] Kategorie-Kopf farbig mit Ring (Prozent, nach Abschluss der Kategorie die Wertung) und „Alle …“.
- [ ] Knöpfe „Erledigt · Teilweise · Nicht · Entfällt“ – ein Tipp setzt, nochmal tippen leert.
- [ ] Zahlen: „− 0,5“ / „+ 0,5“ (Schritt steht drauf), Feld mit Einheit, „…“ für mehr Mengen und „Auf 0 setzen“.
- [ ] Wochenziel-Balken: Strich = „Soll bis heute“, Erklärung darunter.
- [ ] PDF: Tag abschließen → „Tag als PDF“, Woche abschließen/Bericht → „Woche als PDF“, Tagesübersicht → „PDF“: Vorschau prüfen (Titelseite, Ziele in Farbe, Tabellen), dann teilen (Dateien, AirDrop, Mail).

## v5 (ab Version 1.4.0)
- [ ] Heute → Ring oben (oder unten „Heute …“) → „Heute im Blick“: Kacheln Fokus / Ausgaben / Wochenziele, „Noch zu tun“ (tippen springt in die Kategorie).
- [ ] Fokus: PH heute/Woche gegen Ziel, Balken Mo–So je Bereich in Farbe, Bereiche gegen ihr Wochenziel, Einträge (tippen bearbeitet, wischen löscht).
- [ ] Ausgaben: Betrag sofort eintippen, „wofür“ optional (Vorschläge), „Hinzufügen“; heute/Woche, Balken, Liste. Ohne €-Messwert: „„Ausgaben“ anlegen“.
- [ ] „+“ unten → „Ausgabe“ und „Fokus ansehen“.
- [ ] Widgets neu hinzufügen (alte entfernen): klein, mittel (offene Punkte, PH, €), groß (Tag + Wochenziele + Kacheln Fokus/Ausgaben/Woche – jede Kachel öffnet ihre Ansicht), Sperrbildschirm rechteckig/inline.
- [ ] Kontrollzentrum: „Thalia erfassen“ (öffnet Erfassen) und „Ausgabe“ (öffnet Ausgaben) zusätzlich zu „Power-Hours“.
- [ ] Mac: unten links in der Seitenleiste grauer Überblick (Heute, Fokus, Ausgaben, Woche) – Klick öffnet die Ansicht; Menü „Gehe zu“: ⌘0 Heute im Blick, ⌘5 Fokus, ⌘6 Ausgaben.

## v6 (ab Version 1.5.0)
- [ ] Kategorie mit PH (stammloop, Nachhilfe …): Kachel zeigt nur die Summe + „Erfassen“; kein + / − mehr ohne Beschreibung.
- [ ] „Power-Hours heute“: „1 PH · Wofür? (Pflicht) · +“ – der Knopf wird erst mit Beschreibung aktiv; Menge eines Eintrags über „PH ▾“ ändern; alte Einträge ohne Text zeigen „Beschreibung fehlt“.
- [ ] „+“ unten → Power-Hours: Bereich muss gewählt werden, „Sichern“ erst mit Beschreibung.
- [ ] Kategorie mit Ausgaben (Finanzen): „Betrag € · Wofür? · +“ direkt in der Liste, jede Ausgabe steht einzeln darunter (wischen = löschen); Vorschläge beim Tippen.
- [ ] Watch: Power-Hours → Bereich → Menge → „Zuletzt“ antippen oder diktieren.
- [ ] Siri/Kurzbefehl „Power-Hour in Thalia erfassen“ fragt nach „Wofür“.

## 1.6.1 – Sync (siehe [SYNC.md](SYNC.md))

- [ ] Einstellungen → iCloud & Daten → „Geräte im Abgleich“: iPhone, Mac (und Watch, nachdem ihre App offen war) stehen da, mit aktueller Zeit.
- [ ] Mac: Hauptfenster schließen (⌘W), nur die Menüleiste bleibt. Am iPhone 3 Punkte abhaken → „☀ … %“ am Mac ändert sich nach dem Abgleich, ohne Thalia anzuklicken.
- [ ] Tag am Mac abschließen → am iPhone kommt am Abend keine „Tag abschließen“-Erinnerung (iPhone-App einmal geöffnet oder im Hintergrund geweckt).
- [ ] iPhone: Thalia morgens öffnen, abends wieder öffnen → der Health-Vorschlag (Schritte, Wasser) zeigt den Abendstand.
- [ ] Punkt löschen, neuen Punkt in derselben Kategorie anlegen → der neue Punkt ist leer (übernimmt keine Haken).
- [ ] Watch: ✓ auf der Watch, gleichzeitig am iPhone eine Notiz zum selben Punkt → nach dem Abgleich sind ✓ und Notiz beide da.
- [ ] Am Mac etwas abhaken → das iPhone-Widget zeigt es, ohne die iPhone-App zu öffnen (kann ein paar Minuten dauern).

## v7 (ab Version 1.6.0)

**Nach dem Update zuerst**
- [ ] Alle Einträge da: Heute, Woche, Ziele, Rückblick zeigen dieselben Zahlen wie vor dem Update (Indizes, R84).
- [ ] Sync läuft: Einstellungen → iCloud & Daten zeigt „An · zuletzt vor …“; ein Haken am iPhone erscheint am Mac. Steht dort ein Fehler, App-Protokoll kopieren.
- [ ] Die Tour bietet „Neu in Thalia“ mit 8 Karten an (Tag, Punkte, Power-Hours, Werte, Heute im Blick, Sonntag, Ziele, Überall).

**Mitternacht und Widget (R1, R4, R18)**
- [ ] App über Mitternacht offen lassen (iPhone und Mac): danach zeigt „Heute“ den neuen Tag, ohne Neustart; ein Haken landet auf dem neuen Tag.
- [ ] Widget nach Mitternacht, ohne die App zu öffnen: „Neuer Tag“ statt des Vortags (nie „Abgeschlossen“ vom Vortag).
- [ ] Am Mac oder auf der Watch etwas eintragen → das iPhone-Widget zeigt es nach dem Öffnen der App bzw. nach dem iCloud-Abgleich.
- [ ] Zwischen 0 und 4 Uhr: „Tag abschließen“ öffnet den Vortag, solange er offen ist; ab 4 Uhr den neuen Tag.

**Watch (R2, R81, H1, R86)**
- [ ] Ausgaben auf der Watch: keine − / +-Knöpfe, nur der Betrag und „am iPhone erfassen“; vorhandene Ausgaben mit „Wofür“ bleiben unverändert.
- [ ] Werte mit der Krone: Gewicht in 0,1-Schritten, Wasser 0,25, Uhrzeit 5 min; Start beim heutigen oder letzten Wert.
- [ ] Erste Seite: Offenes und Zähler; Health-Messwerte (Schlaf, Gewicht) zählen nicht als offen.
- [ ] Komplikation hinzufügen (Zifferblatt bearbeiten → Thalia): Ring, Offenes, PH; um Mitternacht „Neuer Tag“. Reicht die Aktualität im Alltag? (Sie zeigt den Stand, den die Watch-App zuletzt geschrieben hat.)
- [ ] VoiceOver auf der Watch: die Knöpfe sagen „Erledigt“, „Teilweise“, „Nicht erledigt“, „Entfällt“.

**„offen“ und Heute (R5, R6, R38, R90, R94)**
- [ ] Die Leiste unten, „Heute im Blick“, die Mac-Seitenleiste, Widget und Watch zeigen am selben Tag dieselbe Zahl „offen“.
- [ ] Woche ohne Plan: unten „Kein Plan – Wochenplan importieren“ statt „100 %“.
- [ ] Die Startseite springt beim Abhaken nicht mehr von allein weiter; nur Wischen, Chip oder „Weiter“.
- [ ] Titelzeile auf dem iPhone: Datum, Tagestyp und Besonderheit; das Titelmenü wechselt den Tag. Mindestens fünf Punkte sind ohne Scrollen sichtbar.
- [ ] Besonderheit aus dem Plan (z. B. „Arzttermin“) steht auf Heute, in der Woche, im Widget (mittel/groß) und im PDF.
- [ ] Gestern nicht abgeschlossen: morgens Banner „So, 15. Nov. · 3 offen“ mit „Nachtragen“ und „Abschließen“; × blendet ihn für den Tag aus; nach dem Abschluss weg.

**Eingabe (R31, R32, R33, R46)**
- [ ] iPhone, Messwert mit Ziffernblock: über dem Ziffernblock steht „Fertig“ und speichert sofort. Ausgaben: „Weiter“ springt zu „Wofür“.
- [ ] Vorschläge: bei „Wofür“ erscheinen frühere Einträge der letzten Monate (auch aus anderen Wochen); bei Ausgaben sichert ein Tipp auf einen Vorschlag sofort, wenn der Betrag gültig ist.
- [ ] Power-Hours: oben „Zuletzt“ mit drei Kombinationen; ein Tipp füllt Bereich, Wofür und Menge, Return sichert.
- [ ] Eine Ausgabe antippen → Betrag und Wofür vorbefüllt, „Sichern“ ändert sie, „Widerrufen“ im Hinweis stellt sie wieder her.
- [ ] Jedes Erfassen-Fenster zeigt „Tag: Heute · Gestern · Datum“; ein anderer Tag erscheint orange.

**Wochenplan (R56, R91, R92, R49)**
- [ ] „1 · Prompt kopieren“: der Prompt enthält den Plan der Vorwoche als CSV und vier Zeilen Tendenz.
- [ ] „Wie KW … wiederholen“: Vorschau zeigt die Punkte der Quellwoche für die neue Woche; Import legt sie an.
- [ ] Eine Woche mit Einträgen ersetzen: Vorschau sagt „KW47 wird ersetzt – 23 Markierungen und 9 Werte gehen ins Archiv.“ und der Knopf heißt „KW47 ersetzen“; danach „Widerrufen“ im Hinweis stellt die alte Woche wieder her.

**Papierkorb (R19)**
- [ ] „Papierkorb leeren“ und ein Archiv löschen fragen vorher nach; die Zeilen sind lesbar (mit „Wofür“), das Neueste steht oben.

**Widget abhaken (R87)**
- [ ] Mittleres/großes Widget: einen offenen Punkt antippen → sofort ✓ im Widget, ohne dass die App aufgeht.
- [ ] Danach die App öffnen: der Punkt ist ✓; am Mac und auf der Watch erscheint das ✓ nach dem iCloud-Abgleich.
- [ ] App vorher ganz beenden (aus dem App-Umschalter wischen), dann im Widget abhaken, dann die App öffnen: das ✓ ist da (Warteschlange).

**Mitteilungen (R80)**
- [ ] Auf die Abend-Erinnerung tippen (App geschlossen und im Hintergrund): Thalia öffnet „Tag abschließen“ für diesen Tag, kein Absturz. Ebenso Morgen- und Wochen-Erinnerung.
- [ ] „In 30 Min.“ an der Abend-Erinnerung: sie kommt nach einer halben Stunde wieder.

**Siri und Ausgaben-Automation (R89, R97)**
- [ ] „Hey Siri, Power-Hour in Thalia erfassen“: Siri fragt nach dem Bereich (Liste „3.2 Titel“), Menge und Wofür.
- [ ] Kurzbefehl „Ausgabe in Thalia“ mit 12,50 und „Mittagessen“ bucht ohne App-Öffnen; fehlt der Ausgaben-Messwert der Woche, wird er angelegt.
- [ ] Leeres Wofür oder Betrag 0 → Siri lehnt ab („Wofür war die Ausgabe? …“).
- [ ] Kurzbefehle → Automation → Transaktion → „Ausgabe in Thalia“ (Betrag = Betrag, Wofür = Händler); danach eine echte Kartenzahlung: landet sie mit dem richtigen Betrag in Thalia? Wenn nicht: Protokoll kopieren (Plan B: Betrag als Währung).

**Mac (R14, R15, R35, R59, R62, R96, H1)**
- [ ] Menüleiste: „73 %“ oben rechts; das Fenster zeigt die Statuszeile, Power-Hours mit den letzten Kombinationen, eine Ausgaben-Zeile, „Thalia öffnen“ und „Tag abschließen…“. Abschaltbar in den Einstellungen. Seit 1.10.0: nach PH oder einer Ausgabe steht die Bestätigung mit „Widerrufen“ da (verschwindet nach ~5 s), PH gehen bis 16, dazu „Einstellungen…“.
- [ ] Tastatur auf Heute: ↑/↓ wählt einen Punkt, 1–4 setzt Erledigt/Teilweise/Nicht erledigt/Entfällt, die Auswahl springt zum nächsten offenen Punkt; ⌥⌘↓/↑ wechselt die Kategorie. Gleiches am iPad mit Tastatur. Seit 1.10.0 ohne Klick: App aktivieren oder ⌘1 → der erste offene Punkt ist markiert → „1“ setzt ihn; ⌥⌘↓, dann „1“ ebenso.
- [ ] ⌘0, Klick auf den Ring und auf „HEUTE“ in der Seitenleiste blenden „Heute im Blick“ rechts ein und aus; die Spalte lässt sich ziehen. Seit 1.10.0: ist das Fenster zu schmal für die Spalte, öffnen dieselben Wege „Heute im Blick“ als Blatt.
- [ ] Abendnotiz tippen, dann ⌘N: der Befehl ist ausgegraut, nichts geht verloren. Ebenso im Punkt-Fenster: Notiz tippen, ⌘N / ⇧⌘N / ⌘↩ → nichts passiert.
- [ ] Einstellungen → Archiv → „Wiederherstellen“ bzw. ein Import, der eine Woche ersetzt: der Hinweis mit „Widerrufen“ erscheint im Einstellungsfenster, nicht dahinter.
- [ ] Woche: die Leiste zeigt „Vorige Woche“, „Diese Woche“, „Nächste Woche“ und „Wochenübersicht“ mit Text; der Titel ist „KW47“ mit den Tagen darunter. Seit 1.10.0 stehen die Kürzel im Menü „Gehe zu“: „Zu heute“ ⌘T (auf Woche zur laufenden Woche) und „Wochenübersicht“ ⌥⌘0.
- [ ] Absturz aus Build 47 behoben: Heute am Mac länger offen lassen, Tage wechseln, „Tag abschließen“, ⌘0, Fenster schmal und breit ziehen – kein Absturz (die Leiste ist nicht mehr anpassbar).
- [ ] Ein Hauptfenster (R30): Ablage hat kein „Neues Fenster“, keine Tabs; Menüleiste → „Thalia öffnen“ und die Tour aus den Einstellungen holen das vorhandene Fenster nach vorne. Fenster schließen, dann Dock-Symbol klicken → es geht wieder auf.
- [ ] Fenster („Tag abschließen“, PDF, Import) passen ins Hauptfenster und scrollen; das Hauptfenster lässt sich nicht kleiner als 900 × 620 ziehen.
- [ ] Health-Hinweis: Schlaf/Gewicht stehen am Mac als „Wert aus Health auf dem iPhone“ und zählen im Tagesabschluss nicht als fehlend.

**Erinnerungen (R80)**
- [ ] Abend-Erinnerung kommt mit der Aktion „In 30 Min.“ – antippen → nach 30 Minuten nochmal.
- [ ] Tag abschließen → die Abend-Erinnerung dieses Tages kommt nicht mehr.
- [ ] Mac nach der Neuinstallation: alle Erinnerungen aus; die Erlaubnis wird erst nach der Tour oder beim Einschalten gefragt.

**Lesbarkeit und Bedienung (R43, R44, R66, R67, R73, R75)**
- [ ] Überall dieselben Wörter: Erledigt · Teilweise · Nicht erledigt · Entfällt (Fortschritt: Gearbeitet · Nicht heute); nirgends mehr „N/A“ oder „Nicht“ allein.
- [ ] Hellmodus: „Erledigt“ und „Teilweise“ auf den Knöpfen gut lesbar; Dunkelmodus: weiße Schrift auf Türkis (+, „Tag abschließen“, ausgewählte Chips) gut lesbar.
- [ ] Bei Standardschrift sehen Heute und Woche aus wie vorher; Einstellungen → Bedienungshilfen → größere Schrift (AX1 und größer): die Markier-Knöpfe stehen 2 × 2, kein Wort ist abgeschnitten.
- [ ] VoiceOver in der Woche liest „Mittwoch, Fahrrad fahren, nicht erfasst“; im Tagesabschluss liest ein verfehltes Ziel „verfehlt, Ziel ≤ 23:00“.
- [ ] Reine Ansicht-Fenster (Heute im Blick, Fokus, Ausgaben, Messwert, Punkt, Bericht, PDF, Papierkorb, Import, Erklärungen) haben oben das × (VoiceOver „Schließen“); kein Fenster zeigt „Schließen“ neben „Tag abschließen“.
- [ ] Die Kürzel-Fußnote im „+“-Fenster erscheint am Mac und iPad, nicht auf dem iPhone.


## v8 (ab Version 1.7.0)

Plan und Regeln: [TASKS-v8.md](TASKS-v8.md). CSV-Format für vergangene Wochen: [IMPORT.md](IMPORT.md), Abschnitt „Vergangene Wochen“.

**Nach dem Update zuerst**
- [ ] Rückblick, Ziele und Woche zeigen dieselben Wertungen wie vor dem Update (ohne Krank-/Urlaubstage ändert sich nichts).
- [ ] Die Tour bietet „Neu in Thalia“ mit 3 Karten an: Krank & Urlaub, Vergangene Wochen, PDF-Bericht.
- [ ] Einstellungen → „Wie wird gerechnet?“ endet mit „Neu in 1.7“; die drei Erklärungen öffnen sich (auch aus der Woche und am Mac über Hilfe).
- [ ] Einstellungen → Hilfe listet „Krank & Urlaub“, „Vergangene Wochen“ und „PDF-Bericht“ einzeln unter den vier bisherigen Erklärungen.
- [ ] Einstellungen → Version zeigt 1.7.0.

**Krank & Urlaub setzen (Entscheidung 1)**
- [ ] Heute: Titel antippen (Mac: Titelmenü in der Symbolleiste) → Tagestyp: „Krank“ und „Urlaub“ stehen oben unter „Zählt nicht in die Wochenwertung“, danach die übrigen Typen und „Eigener Typ…“.
- [ ] Woche: lange auf den Tageskopf drücken (Mac: Rechtsklick) → dasselbe Menü. Ebenso im Tagesabschluss.
- [ ] „Tagestyp und Besonderheit…“: Krank und Urlaub sind die ersten Chips; bei Krank steht darunter „Krank/Urlaub: Der Tag zählt nicht in die Wochenwertung“.
- [ ] Eigener Typ „Urlaub Kroatien“ wirkt wie Urlaub (enthält „urlaub“).
- [ ] Familientag und Erholungstag wirken wie bisher: nur Arbeitspunkte entfallen, der Rest bleibt fällig.

**Ein Krank-Tag (Entscheidung 2)**
- [ ] Heute: Karte „Krank – dieser Tag zählt nicht in die Wochenwertung“ mit „Typ ändern“; der Ring zeigt das Symbol, nichts ist offen; die Leiste unten sagt „Krank – zählt nicht“.
- [ ] Heute im Blick: „Krank – heute ist nichts fällig“, kein „Tag abschließen“-Hinweis.
- [ ] Werte (Gewicht, Schlaf, Ausgaben) lassen sich weiter eintragen und zählen in den Wochensummen; der Tagesabschluss meldet nichts als fehlend.
- [ ] Morgens Krank setzen → abends kommt keine Abend-Erinnerung; am nächsten Morgen kein Hinweis „Gestern … offen“.
- [ ] Typ wieder auf „Arbeitstag“ → die Abend-Erinnerung ist wieder geplant (Erinnerung ein paar Minuten in die Zukunft stellen).
- [ ] Widget (klein, mittel, groß, Sperrbildschirm): „Krank – zählt nicht“, „–“, leerer Ring. Watch: „Krank – zählt nicht“, leere Anzeige. Komplikation ohne „offen“. Mac-Menüleiste: „Krank – zählt nicht“.
- [ ] Eigene Kategorie-Wertung im Tagesabschluss an einem Krank-Tag ändert die Wochenwertung nicht.

**„n× pro Woche“ zählt halb (Entscheidung 3)**
- [ ] 3×-Punkt (jeden Tag geplant), Mo und Mi erledigt, Fr–So Krank, Kategorie nur mit diesem Punkt → nach dem Sonntag Kategorie 8,33 (ohne die Regel 6,67); der Punkt zeigt „· ½ krank“.
- [ ] 3×-Punkt nur Mo/Mi/Fr geplant, Mo und Mi erledigt, Fr Krank → Kategorie 8,75.
- [ ] 3×-Punkt dreimal erledigt, danach Krank → kein Abzug, kein Hinweis.
- [ ] 3×-Punkt, Fr–So Krank, noch nichts erledigt: „Entfällt“ geht nur, solange danach noch 2 Tage bis Do frei sind (am Di ja, am Mi nicht mehr).
- [ ] Ganze Woche Urlaub mit einem 3×-Punkt: nichts wird gebucht, die Woche bleibt ohne Wertung.

**Wochenziele schrumpfen (Entscheidung 4)**
- [ ] stammloop 8 PH Mo–Fr, Do und Fr Krank: Fokus, Heute im Blick und Wochenziele zeigen „4,8 statt 8 PH – 2 Tage krank“, Woche abschließen „(statt ≥ 8 – 2 Tage krank)“.
- [ ] Mit 4 PH steht der Fortschrittspunkt auf Teilweise, mit 5 PH auf erreicht.
- [ ] Der Tempo-Strich („Soll bis heute“) lässt Krank-Tage aus; „Ø pro Arbeitstag“ im Fokus auch.
- [ ] Ein Messwert mit Grenze („TEREA ≤ 6“, „Im Bett ≤ 23:00“) bleibt an Krank-Tagen unverändert.
- [ ] stammloop 8 PH Mo–Fr, alle fünf Tage Krank: das Wochenziel zählt nicht – es fehlt in „x von y erreicht“, im Wochen-PDF und in den Widgets; Fokus und die Kategorie-Seite sagen „Ziel zählt nicht – 5 Tage krank“, kein „0 von 0 PH · erreicht“.
- [ ] Ein Business-Fortschrittspunkt (Ziel 3, Plan ohne Tagesregeln), Do Krank und Fr Feiertag: Fortschritt und Tempo rechnen mit demselben Ziel (8 × 3/4 = 6).

**Ganze Woche und Ziele (Entscheidungen 5, 6)**
- [ ] Alle Tage einer Woche Urlaub (Woche → Tagestyp, oder per Vergangene Woche nachtragen): „Woche zählt nicht (krank/Urlaub)“ statt einer Wertung – auch im Wochen-Kopf am iPhone und in der Mac-Seitenleiste (nicht „Noch keine Ziele“).
- [ ] Rückblick: die Woche ist eine blasse Säule „entschuldigt“ statt einer Lücke, die Zeile trägt „entschuldigt“; der Ø 4 Wo. lässt sie aus.
- [ ] Ziele: in der Ziel-Karte und im Ziel-Verlauf ist dieselbe Woche eine graue Säule (Legende „Grau = entschuldigt“), keine Lücke.
- [ ] Wochenplan-Import oder Vergangene Woche nachtragen mit Krank für heute → die heutige Abend-Erinnerung entfällt sofort (nicht erst beim nächsten Öffnen).
- [ ] Ein Ziel, dessen Punkte nur auf Krank-Tage fielen: „x/y Ziele bewertet“ zählt es nicht mit; die Ziel-Karte sagt „Diese Woche entschuldigt (krank/Urlaub)“.
- [ ] Wochenbericht (Text): Zeile „Krank/Urlaub: … zählen nicht“, die Tage-Tabelle sagt „zählt nicht“.

**Markierungen von vorher (Entscheidung 7)**
- [ ] Freitag früh einen Punkt ✓, dann Freitag auf Krank: die Woche zeigt das ✓ gedimmt (VoiceOver: „Krank, zählt nicht“), die Wertung ändert sich wie ohne ✓.
- [ ] Typ zurück auf „Arbeitstag“ → das ✓ zählt wieder, die Wertung ist wie vorher.

**Vergangene Woche nachtragen (Entscheidung 8)**
- [ ] Erreichbar über Woche → … → „Vergangene Woche nachtragen…“, Mac Ablage, Wochenübersicht rechts (Mac/iPad), Import → Vorlagen, leerer Rückblick und eine vergangene Woche ohne Plan.
- [ ] Wochenauswahl: ab Beginn des Zieljahrs, mindestens 52 Wochen zurück, bis letzte Woche; diese Woche ist nicht wählbar.
- [ ] a) „Vom Plan“ in eine leere vergangene Woche: die Punkte der nächstgelegenen geplanten Woche erscheinen ohne Markierungen; „KWnn in der Woche öffnen“ → abhaken, Krank setzen → „KWnn abschließen“ → die Woche steht im Rückblick und in den Zielen.
- [ ] a) „Vom Plan“ in eine Woche mit Plan: Rückfrage, die alte Woche kommt ins Archiv, „Widerrufen“ im Hinweis holt sie zurück.
- [ ] b) „Mit ChatGPT“, Zeitraum „Wochen aus den Unterlagen“: „Prompt kopieren“ → in ChatGPT Fotos oder ein PDF von zwei Papierwochen dazulegen → CSV zurück → einfügen (oder „Datei…“).
- [ ] b) Vorschau je Woche: je Woche eine Zeile (z. B. „KW45 2026 (2.–8. Nov.) · neu“ mit Punkten, Markierungen, Krank/Urlaub-Tagen); Importieren → beide Wochen und ihre Tage sind abgeschlossen und erscheinen im Rückblick, in den Zielen und im Ø 4 Wo.
- [ ] b) Eine CSV mit einer Woche in Matrix-Form (Spalten mo…so) und einer Woche nur mit Wertung (week-Zeile mit Datum und value) → die Vorschau zeigt zwei Zeilen „neu“, der Import schließt beide ab.
- [ ] b) „Fester Zeitraum“ Von–Bis: der kopierte Prompt nennt genau diese Wochen mit Datum und KW.
- [ ] b) „Leere Felder als ✗ zählen“ aus (Standard): leere Felder bleiben leer. An: leere feste Punkte werden ✗ – nie an freien Tagen oder Krank-/Urlaubstagen.
- [ ] b) Die CSV enthält auch diese Woche → Warnung „KWnn: noch nicht vorbei – wird nicht abgeschlossen“, die Woche bleibt offen.
- [ ] b) Eine Markierung auf einen Punkt, den es weder in der Datei noch in der App gibt → Warnung in der Vorschau.
- [ ] b) Nur Markierungen für eine geplante vergangene Woche, die am Montag schon Markierungen aus der App hat → nach dem Import ist auch Montag abgeschlossen.
- [ ] b) Eine Woche ersetzen: Vorschau „ersetzt“, Rückfrage, danach „Widerrufen“ im Hinweis.
- [ ] c) „Nur Wertung“: KW wählen, 7,5 (oder 7.5) → „Wertung eintragen“ → der Rückblick zeigt 7,5; „Wertung entfernen“ nimmt sie wieder weg.
- [ ] Nach einem Import mit Krank-/Urlaubstagen in dieser oder der nächsten Woche kommt an diesen Tagen keine Abend-Erinnerung (spätestens, nachdem die App einmal im Hintergrund war und wieder vorne ist).

**CSV (Entscheidung 9)**
- [ ] Export (Einstellungen → Wochenplan importieren & exportieren) ist im langen Format wie bisher und lässt sich unverändert wieder importieren.
- [ ] Eine Item-Zeile mit Spalten `mo,di,mi,do,fr,sa,so` und ✓ ½ ✗ – importiert als Markierungen; ein unlesbares Feld steht unter „Nicht gelesen“.
- [ ] Eine Tageszeile `day,Fr,,Krank` setzt den Freitag auf Krank.

**PDF-Bericht (Entscheidung 10)**
- [ ] Erreichbar über Rückblick → „PDF-Bericht“, Woche → … → „Mehrere Wochen als PDF…“, Mac Ablage → „Zeitraum als PDF…“ (⌥⌘P), Rückblick-Zeile gedrückt halten (Mac: Rechtsklick) → „PDF-Bericht ab dieser Woche“ und Wochenbericht → Teilen → „Mehrere Wochen als PDF…“.
- [ ] Zeitraum: Letzte 4 / 8 / 13 Wochen (bis zur letzten fertigen Woche), Zieljahr bis heute, Eigener Zeitraum (Von–Bis). Umfang: Nur Übersicht · + Wochenübersicht je Woche · + Rückblick-Texte. Darunter „x Wochen mit Daten · y mit Plan · z Seiten“.
- [ ] Erzeugen zeigt „Seite x von y“; Abbrechen mitten drin geht; danach öffnet die Vorschau und blättert flüssig.
- [ ] Inhalt: Deckblatt (Zeitraum, Ø-Ring, Kacheln, Balken je Woche, 10 Ziele mit Ø und Trend), Übersicht (eine Zeile je Woche: KW, Wertung, 10 Zielfelder in Zielfarbe, PH, abgeschlossene Tage, Krank/Urlaub, Wochenziele), Power-Hours je Bereich, dann die Wochenseiten. Seitenzahlen laufen durch.
- [ ] Papier-Wochen stehen nur als Zeile; entschuldigte Wochen heißen „entschuldigt“ und zählen nicht im Ø; Wochen vor KW42 auch nicht.
- [ ] „PDF teilen“ → in Dateien sichern: Dateiname „Thalia-2026-W43-bis-2026-W46.pdf“; Lesezeichen je Woche (Dateien, Vorschau am Mac); Titel „Thalia · Bericht KW…“.
- [ ] Mac: „Sichern…“ (⌘S) und „Drucken…“ (⌘P).
- [ ] „Zieljahr bis heute“ + „Rückblick-Texte“ (rund 25 Wochen): die Datei ist höchstens ein paar MB groß, die App bleibt währenddessen bedienbar.
- [ ] Einzel-PDF einer Woche und eines Tages sehen aus wie vorher (Aurora-Band oben).
- [ ] Woche mit Fr–So Krank im Wochen-PDF: Spalten grau mit Symbol, auf dem Deckblatt „zählt nicht“, „Tage abgeschlossen … · 3 krank“, „2/3× · ½ krank“, „4,8 statt 8 PH – 2 Tage krank“. Ganz entschuldigte Woche: „–“ / „zählt nicht“.

**Demo und Screenshots (Entscheidung 11)**
- [ ] CI-Screenshots enthalten „past-import“ und „range-pdf“ für iPhone und Mac (der Bericht ist schon erzeugt und in der Vorschau).
- [ ] In der Demo-Woche ist Freitag „Krank“: Woche mit grauer Spalte, ohne Markierungen; ein 3×-Punkt zeigt „· ½ krank“.


## v9 (ab Version 1.8.0)

Plan und Regeln: [TASKS-v9.md](TASKS-v9.md). CSV-Format: [IMPORT.md](IMPORT.md), Abschnitt „Archiv-Wochen (seit 1.8.0)“.
Ziel: alte Wochen aus Scans so übernehmen, wie die Unterlagen sie überliefern – ohne erfundene Haken, mit beiden Wertungen getrennt.

**Nach dem Update zuerst**
- [ ] Einstellungen → Version zeigt 1.8.0.
- [ ] Die Tour bietet „Neu in Thalia“ mit genau einer Karte an: „Archiv-Wochen“.
- [ ] Wochen mit Punkten zeigen in Woche, Ziele und Rückblick dieselben Wertungen wie vor dem Update. Ausnahme (Entscheidung 5): eine Woche mit Plan **und** eingetragener „Nur Wertung“ zeigt im Rückblick, Ø 4 Wo., in den Zielen und im PDF jetzt die Wertung laut Unterlagen; die Woche nennt beide.
- [ ] Hilfe → „Vergangene Wochen“ hat den Schritt „Archiv-Wochen“; „Nur Wertung“ nennt die Wertung laut Unterlagen. „Wie wird gerechnet?“ endet jetzt mit „Neu seit 1.7“.

**Prompt neu schicken (Entscheidung 8)**
- [ ] Vergangene Woche nachtragen → „Mit ChatGPT“ → „Prompt kopieren“ → in Notizen einfügen: Regeln 1–10 („Nichts erfinden“, „echte 0“), die Kopfzeile mit `count` vor `mo`, ein Beispiel mit zwei Wochen, Jahresziele (id · Name), Kategorien (id · Name · Ziel n), Messwerte, die Vorlage für Einzelhaken; kein KI-Modellname.
- [ ] Den Prompt mit den alten Scans erneut in ChatGPT geben → die neue CSV hat `category_score`- und `goal_score`-Zeilen statt Noten im `note`-Text; Wochen, für die nur der Wochenwert belegt ist (z. B. KW30, KW31, KW45, KW46), bestehen nur aus ihrer `week`-Zeile; keine erfundenen `item`- oder `entry`-Zeilen.
- [ ] Eine Woche mit Wochenmittel statt Tagesnoten kommt als `category_score` ohne Datum mit `count`; Jahresziel-Noten stehen je Ziel genau einmal als `goal_score` – nicht auf die Kategorien verteilt.

**Woche nur mit Wochenwert (Entscheidung 1)**
- [ ] CSV mit nur `week,2026-W30,…,9.19` → Vorschau „KW30 2026 … neu“ mit Kennzeichen „Archiv“ und „Wertung 9,19 laut Unterlagen · wird abgeschlossen“; nach dem Import hat KW30 keine Punkte, nichts ist offen oder ✗, die Woche ist abgeschlossen.
- [ ] Dieselbe Datei mit „Leere Felder als ✗ zählen“: auch dann kein ✗ in KW30 – selbst wenn die App für KW30 einen Plan hätte.
- [ ] Woche KW30 öffnen: der Kopf zeigt 9,19 mit „Archiv · Wertung laut Unterlagen“ (Mac: Seitenleiste „… · Wertung laut Unterlagen“), darunter die Karte „Archiv“ statt „Noch kein Plan“; „Nach heutigen Regeln –“ mit „keine Kategoriennoten“.
- [ ] Eine Woche nur mit `week`- und `day`-Zeilen (z. B. Fr Krank): der Tagestyp ist gesetzt, keine Punkte, nichts verpasst.

**Kategorien- und Zielnoten (Entscheidung 3)**
- [ ] `category_score` mit Datum → erscheint in der Archiv-Karte im Tag Mo–So; ohne Datum mit `count` 4 → „nur Wochennote“, Ø mit „n = 4“.
- [ ] „6,5“ und „6.5“ werden beide gelesen; Wert 11 und „abc“ stehen unter „Nicht gelesen“ mit Grund; eine Zeile ohne `title` ebenso.
- [ ] `id` 9.9 (gibt es nicht) → Warnung „… ist keine Kategorie der App; die Note bleibt ohne Zuordnung im Archiv.“; die Note steht unter „Ohne Zuordnung (Archiv)“.
- [ ] Vorschau je Woche: „12 Kategoriennoten · 10 Zielnoten · Wertung 9,28 laut Unterlagen“.
- [ ] Dieselbe Datei zweimal importieren → beim zweiten Mal „unverändert“, nichts ändert sich. Eine geänderte Note ändert nur diese Note.
- [ ] Einstellungen → „Sicherung erstellen…“ (bis 1.9.0 hieß der Knopf anders) enthält die `category_score`-/`goal_score`-Zeilen, die Spalte `count` und die Quelle in der `week`-Zeile; diese Datei wieder importieren → „unverändert“.

**Mittelwerte (Entscheidung 4)**
- [ ] Tagesnoten 0, 10, 10 einer Kategorie → Ø 6,67, n = 3 (die echte 0 zählt mit).
- [ ] Tagesnoten 10, 10, 0, 0 → Ø 5, n = 4.
- [ ] Nur zwei Tage mit Note, der Rest leer → n = 2; leere Felder zählen nicht.
- [ ] Die Wertung laut Unterlagen bleibt genau der Wert aus der Datei (9,19 bzw. 9,28), auch wenn die Noten etwas anderes ergeben.

**Zwei Wertungen getrennt (Entscheidung 5)**
- [ ] Archiv-Karte: „Wertung laut Unterlagen 9,28“ und „Nach heutigen Regeln …“ mit „ohne 1 Urlaubstag“ – zwei Zeilen, klar benannt; fehlt eine, steht „–“ mit kurzem Grund.
- [ ] Urlaub-Tag mit Note: Samstag „Urlaub“, Note 0 → die Zelle ist blass und durchgestrichen (VoiceOver: „Samstag: 0, Urlaub, zählt heute nicht“); Ø (n) der Unterlagen zählt sie mit, die Zeile „nach heutigen Regeln …“ darunter und „Nach heutigen Regeln“ oben lassen sie aus; die Wertung laut Unterlagen ändert sich nicht.
- [ ] Samstag zurück auf „Arbeitstag“ → „Nach heutigen Regeln“ zählt die Note wieder; die Wertung laut Unterlagen bleibt.
- [ ] Rückblick: die Zeile trägt „Archiv“, der Ring zeigt die Wertung laut Unterlagen, darunter „Laut Unterlagen 9,28 · nach heutigen Regeln …“.
- [ ] Ziele und Zielüberprüfung: die abgeschlossene Archiv-Woche zählt mit ihren Zielwerten nach heutigen Regeln; eine Woche nur mit Wochenwert bleibt dort draußen.
- [ ] Mac-Seitenleiste einer Archiv-Woche: „Jahresziele · nach heutigen Regeln“ mit den Zielwerten aus den Kategoriennoten (ohne Kategoriennoten: die Zielnote).

**Archivbereich und nichts erfinden (Entscheidung 6)**
- [ ] Eine alte Zusatz- oder Sammelkategorie ohne `id` (z. B. „Sonderwoche“) steht unter „Ohne Zuordnung (Archiv)“ mit ihrer Bezeichnung und ihren Tagen; „Nach heutigen Regeln“ ändert sich dadurch nicht.
- [ ] Eine Zielnote steht nur unter „Zielnoten“; die Kategorien dieses Ziels bekommen nichts dazu. Hat das Ziel Kategoriennoten, steht darunter „nach heutigen Regeln … aus den Kategoriennoten“.
- [ ] Nach dem Import einer Archiv-Woche gibt es in ihr keine Haken, keine Messwerte und keine Power-Hours.

**Erneuter Import mit „Archivdaten dieser Wochen ersetzen“ (Entscheidung 2)**
- [ ] Ausgangslage: eine vergangene Woche hat aus einem früheren, fehlerhaften Import Punkte und Markierungen. Die neue CSV (nur Wochenwert und Noten) **ohne** Schalter → Warnung „KWnn: in der App noch n Punkte mit m Markierungen – ‚Archivdaten ersetzen‘ nur wählen, wenn sie aus einem fehlerhaften Import stammen; es verschiebt alles ins Archiv.“ (ohne Markierungen: „… n Punkte ohne Markierungen – ‚Archivdaten ersetzen‘ entfernt sie.“); Punkte und Markierungen bleiben.
- [ ] **Vorsicht bei Wochen, die in der App geführt wurden:** steht so eine Woche in der CSV nur mit ihrem Wochenwert, geht sie mit dem Schalter ebenfalls ins Archiv (Vorschau: „ersetzt“ und „m Markierungen aus der App gehen ins Archiv – die Datei bringt keine Einzelhaken.“). Solche Zeilen vor dem Import aus der CSV löschen oder ohne Schalter importieren; „Widerrufen“ holt sie zurück.
- [ ] Schalter „Archivdaten dieser Wochen ersetzen“ an (Fußtext: „Alles, was die App für die Wochen der Datei hat, kommt ins Archiv … Wochen, die in der App abgehakt wurden, vorher aus der Datei nehmen. …“) → die Vorschau rechnet neu, Status „ersetzt“, orange Zeile „KWnn wird ersetzt – … gehen ins Archiv.“; „Importieren“ fragt nach („Alles, was die App für diese Wochen hat, kommt ins Archiv: …“).
- [ ] Danach hat die Woche keine alten Punkte, Markierungen, Werte, Tagestypen und Abschlüsse mehr – nur, was die Datei bringt; die Woche zeigt die Archiv-Karte und ist abgeschlossen.
- [ ] „Widerrufen“ im Hinweis → alte Punkte, Markierungen, Tagestypen und die frühere Wertung sind wieder da; die Noten der neuen Datei sind weg.
- [ ] Einstellungen → Archiv: der Eintrag der ersetzten Woche („n Punkte · m Markierungen“ bzw. „ohne Punkte“); „Wiederherstellen“ fragt „Was die Woche jetzt hat, kommt dafür ins Archiv.“ und holt alles zurück.
- [ ] Die CSV enthält auch diese Woche → Warnung „KWnn: noch nicht vorbei – wird nicht ersetzt, nur ergänzt.“; ihre Einträge bleiben.
- [ ] Schalter umlegen, ohne neu einzufügen → „Importieren“ geht erst mit der neuen Vorschau.
- [ ] Dieselbe CSV mit Schalter ein zweites Mal → Vorschau „unverändert“, nichts wird ersetzt; Einstellungen → Archiv bekommt keinen zweiten, gleichen Eintrag.
- [ ] Nach dem Ersetzen in der Woche etwas ändern (z. B. einen Tag auf „Urlaub“), dann „Widerrufen“ → die alte Woche ist zurück, und der Stand mit der Änderung steht als Eintrag in Einstellungen → Archiv.
- [ ] Motto und Kontext der Woche bleiben nach dem Import (die CSV schreibt keine); eine `week`-Zeile ohne Wert lässt die Wertung laut Unterlagen stehen (ohne Schalter).
- [ ] Eine `week`-Zeile für diese Woche mit Wert → Warnung „KWnn: noch nicht vorbei – der Wochenwert wird nicht übernommen.“; Motto und laufende Wertung der Woche bleiben.

**Fehler in der Antwort (Lücken nach v9)**
- [ ] Ein Dezimalkomma ohne Anführungszeichen (`…,9,28,Scan S. 3,…` in der `week`-Zeile, `…,6,67,…` in einer Note) → keine falsche Wertung: Warnung „Spalten verrutscht … Wochenwert und Quelle nicht übernommen.“ bzw. die Note steht unter „Nicht gelesen“ mit „Spalten verrutscht“.
- [ ] Ein Wochenwert „ca. 9“ oder „92“ → Warnung „… nicht lesbar – nicht übernommen.“ bzw. „… liegt nicht zwischen 0 und 10 – nicht übernommen.“; die Woche behält ihren Wert.
- [ ] Eine `day`-Zeile oder Note mit einem Datum aus einer anderen Woche → „Nicht gelesen“ mit „… liegt nicht in KWnn – gehört in den Block seiner Woche“; die andere Woche (z. B. die laufende) bleibt unberührt, offen und wird nicht ersetzt.
- [ ] Eine Note mit „Mo“ vor der ersten `week`-Zeile → „steht vor der ersten week-Zeile“ (nicht „nicht lesbar“).
- [ ] `measure`-Zeilen in einer Woche ohne Punkte → Warnung „Messwert „…“ nicht übernommen – eine Woche ohne Punkte bekommt keine Messwerte.“; kein Wochenziel in dieser Woche.
- [ ] Zwei Bezeichnungen mit derselben `id` am selben Tag → Warnung „KWnn Mo: zwei Noten für 1.1 („…“, „…“) – nur die letzte bleibt …“.
- [ ] Die ganze Antwort mit zwei CSV-Blöcken eingefügt → Warnung „Die Antwort hat 2 CSV-Blöcke – gelesen wird nur der erste …“.
- [ ] Den kopierten Prompt selbst als CSV einfügen → keine Woche kommt herein (das Beispiel hat die Platzhalter-Woche `JJJJ-Wnn`), alles unter „Nicht gelesen“.
- [ ] Deutsche Kopfzeile mit Spalte `quelle` → die Quelle erscheint in der Archiv-Karte.

**Woche, Rückblick und PDF (Entscheidung 9)**
- [ ] iPhone, Woche einer Archiv-Woche: Abschnitt „Archiv“ mit beiden Wertungen, Kategoriennoten (Bezeichnung aus den Unterlagen, darunter die heutige Kategorie mit Schlüssel, Mo–So, Ø und n), Zielnoten, „Ohne Zuordnung (Archiv)“, Quelle („Quelle: Scan S. 19“) und „Vergangene Woche nachtragen…“.
- [ ] Mac und iPad quer: die Kategoriennoten stehen in den Spalten der Wochentabelle (Mo–So unter den Tagesköpfen), rechts in der Seitenleiste „Archiv“ mit beiden Wertungen; Seitenleiste ausblenden (⌥⌘0) → die Wertungen stehen in der Karte.
- [ ] Heute auf einem Tag einer Archiv-Woche (über das Titelmenü in die Woche springen): statt „Noch kein Plan“ steht „KWnn ist eine Archiv-Woche“ mit beiden Wertungen und den Noten des Tages (an einem Urlaubstag blass und durchgestrichen, mit Hinweis); „Archiv-Karte der Woche öffnen“ springt in die Woche.
- [ ] PDF-Bericht über einen Zeitraum mit einer Archiv-Woche: ihre Zeile trägt „Archiv“ (nicht „Papier“), Wertung laut Unterlagen, Zielfelder gefüllt; unter der Übersicht die Fußnote „Archiv: Wertung laut Unterlagen; Zielfelder laut Unterlagen oder nach heutigen Regeln aus den Kategoriennoten.“
- [ ] Eine Woche nur mit „Nur Wertung“ und ohne Noten heißt im PDF weiter „Papier“.

**Speicher und Sync (Entscheidung 7)**
- [ ] Nach dem Import am iPhone zeigt der Mac (nach dem Abgleich) dieselbe Archiv-Karte; ein Ersetzen am Mac kommt am iPhone an.

**Demo und Screenshots (Entscheidung 10)**
- [ ] CI-Screenshots enthalten „archive“ für iPhone und Mac: die Demo-Archiv-Woche (zwei Wochen vor der aktuellen) mit Archiv-Karte, blassem Urlaub-Samstag, „Sonderwoche“ unter „Ohne Zuordnung (Archiv)“ und 10 Zielnoten; Quelle „Papier-Tracker“.

## v10 (ab Version 1.9.0)

Plan und Regeln: [TASKS-v10.md](TASKS-v10.md) – bei Abweichungen gilt dort „Nachträge (Umsetzung)“. Verbundene Apps,
deine Aufgaben in der richtigen Reihenfolge und die Aufträge für Theo, George, Nina und Finn:
[CONNECTED_APPS.md](CONNECTED_APPS.md). CSV: [IMPORT.md](IMPORT.md), Abschnitte „Verbundene Apps und Leseliste“ und
„Datensätze“.
Ziel: Jahresziele mit Ergebnissen und „Wochen über 8“, eine Leseliste, Abschnitte als Versionen der Jahresziele und
Werte aus anderen Binisoft-Apps – ohne CloudKit-Schemaänderung.

**Nach dem Update zuerst**
- [ ] Alle Geräte auf 1.9.0 (iPhone, iPad, Mac, Watch), *bevor* Ergebnisse, Bücher, Abschnitte oder Quellen `app:…` / `list:…` angelegt werden (CONNECTED_APPS.md, Aufgabe 1). Einstellungen → Version zeigt 1.9.0.
- [ ] Die Tour bietet „Neu in Thalia“ mit genau vier Karten an: „Ergebnisse und Wochen über 8“, „Leseliste“, „Abschnitte“, „Verbundene Apps“. Jede der vier hat „Ansehen“: öffnet auf der Übungsseite „Jahresziel eintragen“, die Leseliste, „Neuen Abschnitt beginnen…“ bzw. „Verbundene Apps“ mit der Beispielquelle „Demo“ – nach der Tour ist davon nichts im echten Speicher.
- [ ] Einstellungen → Hilfe hat vier neue Erklärseiten: „Ergebnisse und Wochen über 8“, „Leseliste“, „Abschnitte“, „Verbundene Apps“.
- [ ] Woche, Ziele, Rückblick und PDF zeigen dieselben Wertungen wie vor dem Update – solange kein Abschnitt, kein Ergebnis und keine verbundene App dazukommt, ändert sich nichts.
- [ ] Nach dem ersten Start bekommen die abgeschlossenen Wochen des Zieljahrs einmal ihre Kategorie-Wochennoten nachgetragen (Wochen mit Punkten nur auf dem Gerät mit Apple Health, wie bei der Wochenwertung; Archiv-Wochen überall); nach dem Abgleich ist „Wochen über 8“ auf allen Geräten gefüllt – am iPhone zuerst öffnen.

**Ergebnisse (Entscheidung 1.2)**
- [ ] Ziele → ein Ziel → „Ergebnisse“ → „Ergebnis anlegen“: abhaken (z. B. „Website online“), zählen („10 Bücher“, Ziel `>=10`) und Zielwert (Ziel `<=…` oder `>=…`, mit Startwert); Quelle „Eigene Einträge“, „Leseliste“, „Messwert“ oder „Verbundene App“.
- [ ] Die Zeile hat „Abhaken“ (danach „Zurücknehmen“), „+1“ oder „Wert eintragen“ (nichts davon, wenn eine Quelle zählt; bei der Quelle „Leseliste“ steht dort „Leseliste“) und zeigt Stand, Ziel und Status („offen“, „auf Kurs“, „im Rückstand“ (bis 1.9.0 anders benannt), „erreicht“, nach dem Zeitraum „nicht erreicht“), z. B. „7 von 10 · davon 4 in Abschnitt 1“; ohne Ziel nur den Stand.
- [ ] „Eintrag mit Datum…“ legt einen Eintrag für einen anderen Tag an; auf der Seite des Ergebnisses ändert das Antippen eines Eintrags („Einträge“) Datum, Wert und Notiz, auch rückwirkend; „Eintrag löschen“ und dann Widerrufen (⌘Z) holen ihn zurück.
- [ ] Rückwirkend über den bekannten Weg: zu einem früheren Tag gehen, „Erfassen“ → „Jahresziel eintragen“ (auch Ziele → Jahreskarte → ••• → „Jahresziel eintragen…“): das Fenster nennt den Tag, Hinweis „Zählt für Di, 17. Nov.“; der Eintrag trägt dieses Datum.
- [ ] Ein Ergebnis mit Quelle „Messwert“ zählt beim Zählen die Wochenwerte zusammen und nimmt beim Zielwert den letzten Wert.
- [ ] „Erfassen“ (iPhone: +, Mac: ⇧⌘N) hat unten die Zeilen „Jahresziel eintragen“ und „Lesen“; beide nehmen den Tag, den Heute gerade zeigt.
- [ ] Ergebnis löschen → „Zuletzt gelöscht“ zeigt es unter „Ergebnisse“ 30 Tage lang; „Wiederherstellen“ bringt es mit seinen Einträgen zurück. Ebenso ein Buch unter „Leseliste“ (mit seinen Ständen) und ein Abschnitt unter „Abschnitte“; „Leeren“ und „Endgültig löschen“ fragen vorher. Liegt nur so etwas im Papierkorb, steht dort nicht „Nichts gelöscht“.

**Wochen über 8 und die Messwerte im Ziel (Entscheidung 1.2.3–1.2.4)**
- [ ] Zielkarte: an einer Kategorie-Zeile steht „✓ über 8“, wenn ihre Note der laufenden Woche gerundet mindestens 8,00 ist (7,99 nicht); darunter „Wochen über 8: 1.1 9/12 · 1.2 7/12“ für die letzten 12 gewerteten Wochen im aktuellen Abschnitt.
- [ ] Zielseite: „Diese Woche gut dabei – jede Kategorie über 8“ nur, wenn jede gewertete Kategorie des Ziels über 8 ist; der Verlauf hat eine Linie bei 8 und gefüllte Punkte ab 8 (keine zweite Punktreihe). Woche: dasselbe Abzeichen am Kategorie-Kopf.
- [ ] Eine ganz entschuldigte Woche (krank/Urlaub) zählt bei „Wochen über 8“ nicht mit.
- [ ] Zielkarte: bis zu drei Messwert-Chips, dann „+2“; Zielseite „Messwerte diese Woche“ mit Wochenwert und Ziel (ohne Plan diese Woche: die Liste der letzten Woche mit Plan, mit Hinweis). Ein Messwert, der ein Ergebnis speist, trägt „zählt für Ziel 5 · Bücher 3/10“ – auch in Heute unter „Wochenziele“, im Fenster „Wochenziele“ (Abschnitt „Zählt für Jahresziele“) und im Messwert-Editor (Abschnitt „Jahresziele“). Ein Messwert ohne Ergebnis zeigt nichts davon.

**Planung (Entscheidung 1.2.5, 1.5.4)**
- [ ] Woche abschließen → Prompt kopieren → in Notizen einfügen: Block „Jahresziel-Ergebnisse (nur zur Info – nichts unaufgefordert steigern)“ mit Stand, Ziel und Status, ohne Health-Werte; die Regel, Verknüpfungen (`app:…`, `list:…`) aus dem Ausgangsplan unverändert zu übernehmen.
- [ ] Plan-CSV, in der ein Messwert mit Quelle aus der Vorwoche keinen `link` hat → Hinweis in der Vorschau „KWnn: bisherige Quelle übernommen, die Datei nennt keine – …“; die Quelle bleibt.
- [ ] Links `app:…` und `list:…` (auch direkt an einem Punkt) erzeugen in der Vorschau keine Warnung.

**Leseliste (Entscheidung 1.3)**
- [ ] Ziele → „Gerade dabei“ zeigt die laufenden Bücher; Antippen → „bis Seite“ oder „+ Seiten“, Datum änderbar, auch rückwirkend; Hinweis mit dem Buch, dem Stand und dem Tag.
- [ ] „Leseliste“ (Jahreskarte → •••, die Karte „Gerade dabei“ – sie erscheint ab dem ersten Buch – und unter einem Ergebnis mit Quelle „Leseliste“): Läuft, Geplant, Fertig (nach Abschnitt), Abgebrochen, Suche „Titel oder Autor:in“, + („Buch hinzufügen“). Auf iPhone und Mac gleich, kein eigener Eintrag in der Seitenleiste.
- [ ] Buch-Fenster: Titel, Autor:in, Seiten, Art (Buch, Hörbuch, Kurs …), „Zählt für“, Beginn und Ende (rückwirkend), abgebrochen; „bis Seite“ gleich der Seitenzahl schlägt „fertig“ vor.
- [ ] Einen Stand rückwirkend zwischen zwei andere setzen oder auf ein anderes Datum verschieben → die gelesenen Seiten je Tag stimmen, nie negativ.
- [ ] Messwert mit Quelle „Leseliste“ (`list:buch`): Tageswert = gelesene Seiten; ein verknüpfter Punkt „20 Seiten lesen“ bekommt Vorschlag und Fortschritt wie bisher; in Heute zeigt der Messwert die Seiten des Tages, „aus der Leseliste“ und den Knopf „Lesen“ statt − / + – er öffnet „Lesen“ für diesen Tag, Seiten nur einmal eintragen. Im Kontextmenü gibt es „Lesen…“, aber kein „Wert leeren“.
- [ ] Rückwirkend: zu einem Tag der Vorwoche gehen, „Erfassen“ → „Lesen“ → „bis Seite“ eintragen → der Messwert zeigt die Seiten an jenem Tag, der Tag danach nur den Zuwachs darüber; ist die Woche abgeschlossen und im aktuellen Abschnitt, wird sie neu gewertet, sonst bleibt sie (Hinweis „KWnn bleibt, wie sie war“).
- [ ] Ergebnis „Bücher“ mit Quelle „Leseliste“ zählt die fertigen Bücher; ein Buch, das in Abschnitt 1 fertig wurde, zählt dort („davon … in Abschnitt 1“).

**Abschnitte (Entscheidung 1.4)**
- [ ] „Neuen Abschnitt beginnen…“ geht aus der Jahreskarte (•••), aus Einstellungen → Jahresziele und am Ende der Zielüberprüfung.
- [ ] Startwoche („Beginnt mit“): Standard nächste Woche, frühestens eine Woche nach dem Start des aktuellen; eine vergangene Woche (rückwirkend) geht. Titel und Grund (optional), „Beginnen“ → gleich danach Einstellungen → Jahresziele: Ziele umbenennen und beschreiben, neue Ziele und Kategorien; im Ergebnis-Fenster „Ziel in Abschnitt 2 (ab KW…, optional)“, solange der neue noch nicht begonnen hat (sonst „Ziel in Abschnitt 2 (optional)“ für den laufenden), und unter „Abschnitte“ „Gilt ab“ und „Beendet nach“; die Seite des Ergebnisses zeigt „Je Abschnitt“ den Beitrag jedes Abschnitts. Kategorien werden dort nicht umgehängt oder gelöscht.
- [ ] Widerrufen (⌘Z) gleich danach nimmt den ganzen Schritt zurück.
- [ ] Jahreskarte: „Abschnitt 2 · seit KW50 · Woche 3“; die Karten zählen im aktuellen Abschnitt, ältere Werte grau; darunter „Frühere Abschnitte“ (Titel, Wochen, Ø Wertung, Kategorie-Wochen über 8, Ergebnisse erreicht) → Seite mit den damaligen Zielen und Werten.
- [ ] Rückblick: Abschnittsgrenze als Linie mit Namen; Zielseite → Zeitraum „Abschnitt“ (nur mit mehr als einem Abschnitt); Zielüberprüfung: Auswahl Abschnitt oder Zieljahr; PDF-Bericht: Zeitraum „Aktueller Abschnitt“.
- [ ] Eingefroren (Grundregel 2): in einer abgeschlossenen Woche vor dem aktuellen Abschnitt etwas ändern → die Wertung bleibt (die Woche direkt davor erst ab der zweiten Woche des Abschnitts); die Woche zeigt „Vor Abschnitt 2 (seit KWnn): KWmm wird nicht mehr von selbst neu gewertet – …“ mit „Neu berechnen“ → Hinweis „KWmm neu berechnet“ bzw. „KWmm: Wertung unverändert“.
- [ ] Abschnitt löschen (Einstellungen → Jahresziele) → seine Wochen zählen wieder zum Abschnitt davor, gespeicherte Wertungen bleiben; „Zuletzt gelöscht“ holt ihn zurück.

**Verbundene Apps (Entscheidung 1.5) – erst nach den Builds der anderen Apps**
- [ ] Vorher: Einstellungen → Tracking → „Verbundene Apps“ (Mac: ⌘, → „Verbundene Apps“) zeigt „Noch keine verbundene App gesehen“, darüber den Hinweis „Werte aus anderen Apps erscheinen, sobald Thalia auf diesem Gerät geöffnet war.“, der Schalter „Thalia-Katalog bereitstellen“ ist an. Unter „Auf diesem Gerät“ steht nach ein paar Sekunden „Zuletzt nachgesehen: …“ und „Jetzt nachsehen“. Eine echte Quelle „Demo“ gibt es nie.
- [ ] Mac: bleibt es bei „Noch nichts gelesen …“, fehlt der signierten App die App Group (CONNECTED_APPS.md, Aufgabe 3).
- [ ] Nach CONNECTED_APPS.md Aufgaben 3–6: je App ein Abschnitt mit „Zuletzt gesehen: …“, „Format v1“ und „n Meldungen an m Tagen · letzte 30 Tage“; „Was kommt an · letzte 7 Tage“ zeigt jede Meldung mit Tag, App und Wirkung („Aufgabe · Arbeit/Kunden → 3.2“, „1,5 PH · ohne Zuordnung“, „Workout · Push“), nur zum Ansehen.
- [ ] „Ohne Zuordnung · Theo“: je Gruppe „Kategorie wählen“ → Hinweis „Arbeit/Kunden → 3.2“ mit „Widerrufen“; die Gruppe steht danach im Abschnitt der App mit „Zuordnung in Thalia“ (Auswahl änderbar, nach links wischen bzw. Rechtsklick → „Zuordnung entfernen“). Eine in Theo gewählte Zuordnung steht dort als „Zuordnung aus Theo“ und ist hier nicht änderbar.
- [ ] Eigene geleerte Markierung bleibt: ein Punkt mit ✓ „⇄ George · Push“ → in Heute auf „Erledigt“ tippen (wird leer) → George liefert danach eine neuere Tagesdatei für denselben Tag → der Punkt bleibt leer. Ein eigenes ✗ bleibt ebenso.
- [ ] Notiz zu einem Punkt mit abgeleitetem ✓ (Details → Notiz) → der Haken bleibt, jetzt als eigener; das Detailfenster zeigt vorher „⇄ George · Push – eine eigene Markierung geht vor“.
- [ ] Theo: eine Aufgabe einer zugeordneten Gruppe erledigen → Thalia auf demselben Gerät öffnen → ein Messwert `app:theo:task` der Kategorie zählt sie, der verknüpfte Punkt bekommt ✓ „⇄ Theo · …“. Aufgabe wieder öffnen → Haken weg (ohne eigene Markierung).
- [ ] Theo von einem anderen Gerät: Aufgabe am Mac erledigen, Theo am iPhone synchronisiert, Thalia am iPhone öffnen → kommt an.
- [ ] Power-Hours aus Theo: in Heute unter „Power-Hours heute“ ein Block „aus Theo“ in der Kategorie (nur lesen, zählt für das Wochenziel, auch in Fokus unter „Aus anderen Apps“); „Übernehmen“ → ein eigener Block, der abgeleitete verschwindet; „Widerrufen“ im Hinweis bringt den abgeleiteten zurück. Auf zwei Geräten übernommen → nach dem Abgleich nur ein Block.
- [ ] Power-Hours ohne Kategorie stehen in Heute auf der Seite „Abschluss & Notizen“ unter „Aus anderen Apps · ohne Zuordnung“ und zählen nirgends; „Übernehmen in …“ → Kategorie → eigener Block dort.
- [ ] Gruppe ohne Kategorie → „Ohne Zuordnung“ → Kategorie wählen → die Wirkung erscheint, Herkunft „in Thalia“; mit der Wahl in Theo „aus Theo“; „Zuordnung prüfen“, wenn der Kategorie-Titel nicht mehr passt.
- [ ] George: Workout aus einer Vorlage → `app:george:workout=<id>` zählt es, der verknüpfte Punkt bekommt ✓ „⇄ George · <Vorlage>“; ein eigenes ✗ oder eine geleerte Markierung bleibt (eigenes gewinnt). Ein Watch-Workout kommt, sobald es in Georges iPhone-App ist und Thalia am iPhone offen war.
- [ ] Nina: Kalorien und Makros erscheinen als Tageswert mit „aus Nina“ unter dem Namen; ein eigener Eintrag für denselben Tag ersetzt ihn („aus Nina“ verschwindet), „Wert leeren“ bringt den Wert aus Nina zurück. Ohne eigenen Eintrag bietet das Kontextmenü kein „Wert leeren“.
- [ ] Finn: Ausgaben einer eingeschalteten Gruppe erscheinen in Heute und im Fenster „Ausgaben“ als „aus Finn – in Finn ändern“ (nicht bearbeitbar, kein Löschen), eigene Ausgaben kommen dazu und lassen sich wie bisher ändern; Tag, Woche und „Nach Zweck“ zählen beides. Ein Ergebnis mit Quelle `app:finn:net_worth` zeigt den letzten Stand.
- [ ] Kein abgeleiteter Haken an einem Krank-/Urlaubstag oder an einem Tag, an dem der Punkt nicht gilt; späte Tatsachen ändern eine eingefrorene Woche nicht.
- [ ] Mac: Theo oder George am Mac, Thalia am Mac offen → kommt spätestens nach 5 Minuten an (ob die Sofort-Meldung zwischen Mac-Apps wirkt, ist offen: CONNECTED_APPS.md §5).
- [ ] Watch: zeigt die abgeleiteten Haken und Werte nach dem Abgleich.
- [ ] Nichts aus Apple Health: „Was kommt an“ zeigt keine Health-Werte; Thalias eigene Health-Werte bleiben auf dem Gerät.
- [ ] „Thalia-Katalog bereitstellen“ aus → Theo bietet nach Thalias nächstem Nachsehen keine Thalia-Kategorien mehr an; wieder an → wieder da.

**Messwert- und Punkt-Editor (Entscheidung 1.5.4)**
- [ ] Messwert bearbeiten → Abschnitt „Quelle“: Manuell, Power-Hours (→ Bereich), Apple Health (→ Wert), Leseliste (→ Art), Verbundene App → App → Art → Eintrag (aus den Vorlagen, Gruppen und Kennzahlen der App, „alle“ für alle); darunter z. B. „George · Workouts · Push“. Die Einheit folgt der Quelle („Seiten“, „Stück“, „kcal“), Sichern geht erst mit App und Art. Ohne gesehene App: Textfelder für App, Art und Eintrag.
- [ ] Einen Messwert sichern, ohne die Quelle anzufassen → die Quelle bleibt genau, wie sie war (auch eine unbekannte, „Andere Quelle“).
- [ ] Punkt bearbeiten → „Messwert“: die Zeile „Verknüpfung“ nennt den Messwert und seine Quelle („Workouts · George · Workouts · Push“) mit dem Hinweis, dass der Haken von selbst kommt; ein Punkt, der direkt auf `app:…` oder `list:…` verweist, zeigt diese Verknüpfung als Auswahl. Das Detailfenster eines Punkts zeigt „Quelle“ unter „Messwert“.

**Speicher, Sync und Sicherung (Entscheidung 1.1)**
- [ ] Ergebnis, Eintrag, Buch, Stand und Abschnitt am iPhone anlegen → am Mac nach dem Abgleich da, umgekehrt ebenso.
- [ ] Am selben Tag auf iPhone und Mac je einen Stand für dasselbe Buch eintragen (eins davon offline) → nach dem Abgleich sind beide da.
- [ ] Ein rückwirkender Stand in einer abgeschlossenen Woche des aktuellen Abschnitts mit verknüpftem Punkt → die Woche wird neu gewertet; vor dem aktuellen Abschnitt nicht.
- [ ] Einstellungen → „Sicherung erstellen…“: am Ende `record`-Zeilen (`goal.…`, `list.…`, `link.rule.…`, `x.…`, `score.…`); dieselbe Datei wieder importieren → Vorschau „Datensätze“, nichts ändert sich. „Diese Woche als CSV“ und der Export für ChatGPT haben keine `record`-Zeilen.
- [ ] Ein Gerät mit 1.8.0 (falls noch eins da ist): einen Messwert mit Quelle `app:…` dort sichern → die Quelle bleibt; nach dem Update wirkt sie.
- [ ] Zwei Geräte mit verschiedenen Apps (z. B. iPhone mit Theo, Mac mit Finn), beide vor dem Abgleich geöffnet → danach kennt jedes Gerät beide Quellen (Verbundene Apps), und die Werte beider erscheinen in der Woche.
- [ ] Einen abgeleiteten Haken „⇄ George · …“ leeren, mit „Sicherung erstellen…“ sichern und auf einem zweiten Gerät einlesen, dessen erster iCloud-Abgleich fertig ist (Demo nicht) → der Haken bleibt leer. Ein älteres Backup einlesen → später verbundene Apps bleiben bekannt. Nie in ein Gerät einlesen, dessen erster iCloud-Abgleich noch läuft.
- [ ] Abschnitt für nächste Woche beginnen → im Ergebnis-Fenster „Ziel in Abschnitt 2 (ab KW…, optional)“; ein neues Ergebnis erscheint auf der Zielseite mit „Gilt ab Abschnitt 2 (KW…)“. „Neuen Abschnitt beginnen…“ noch einmal → frühestens die Woche danach, Titel „Abschnitt 3“.
- [ ] Mac schließt die Woche am Sonntag ab (mit Schritten aus Apple Health im Ziel), am Montag beginnt ein neuer Abschnitt → das iPhone wertet die Woche nach dem Abgleich noch mit den Health-Werten (erst ab der zweiten Woche des Abschnitts eingefroren).
- [ ] Watch: ein Messwert mit Quelle Leseliste zeigt nur den Wert und „mit „Lesen“ am iPhone eintragen“; am iPhone führt „Messwert eintragen“ für ihn zu „Lesen“, der Kurzbefehl „Messwert eintragen“ lehnt ab.

**Demo und Screenshots (Entscheidung 1.7.2–1.7.3)**
- [ ] CI-Screenshots enthalten „goal-detail“, „reading“ und „connected-apps“ für iPhone und Mac: zwei Abschnitte (Abschnitt 2 seit fünf Wochen), die Ergebnisse „Bücher gelesen“, „Website online“ und einen Zielwert, drei Bücher („Kleine Schritte“ fertig, „Klarer Kopf“ läuft, „Lange Wege“ geplant), die Quelle „Demo“ mit dem Workout „Push“, zwei Power-Hours (eine „ohne Zuordnung“ – im Screenshot „connected-apps“ unter „Ohne Zuordnung · Demo“), Kalorien und Protein. Der Fußtext unter „Auf diesem Gerät“ sagt dort „Beispieldaten der Quelle „Demo“ – hier liest Thalia keine anderen Apps.“
- [ ] Einstellungen → Version zeigt 1.9.0 (`Config/Base.xcconfig`).
- [ ] Nach der Tour hat der echte Speicher keine Beispieldaten: keine Quelle „Demo“ unter Verbundene Apps, keine Demo-Bücher, keine Demo-Ergebnisse.

## v11 (ab Version 1.10.0)

Plan und Regeln: [TASKS-v11.md](TASKS-v11.md) – bei Abweichungen gilt dort „Nachträge“. Abgleich: [SYNC.md](SYNC.md)
„Stand 1.10.0“. Sicherung und CSV: [IMPORT.md](IMPORT.md). Finn: [CONNECTED_APPS.md](CONNECTED_APPS.md) Auftrag 3.4.
Ziel: Befunde der Prüfung nach 1.9.0 beheben, Sicherungen, Finn mit Kontoständen und – nur in TestFlight – Health-Werte
am Mac und auf der Watch. Ohne CloudKit-Schemaänderung.

**Nach dem Update zuerst: alle Geräte auf 1.10.0**
- [ ] **Zuerst alle Geräte auf 1.10.0** (iPhone, Mac, Watch, ggf. iPad). Vorher prüfen: solange ein Gerät noch 1.9 hat, zeigt Einstellungen → iCloud & Daten → „Geräte im Abgleich“ bei ihm „Thalia 1.9 – bitte dort aktualisieren. Bis dahin werten Mac und Watch abgeschlossene Wochen nicht selbst.“, und der Mac wertet abgeschlossene Wochen nicht selbst. Danach steht bei jedem Gerät die Version („iPhone · 1.10.0“); Einstellungen → Version zeigt 1.10.0.
- [ ] Die Tour bietet „Neu in Thalia“ an: in der TestFlight-Version mit drei Karten („Sicherung“, „Genauer gerechnet“, „Health am Mac und auf der Watch“), im App Store mit zwei.
- [ ] Vor dem Update die Noten der letzten drei abgeschlossenen Wochen notieren (Rückblick). Nach dem ersten Abgleich am iPhone dürfen sie sich einmal leicht ändern (die Regeln aus „Genauer gerechnet“); eingefrorene Wochen bleiben, bis jemand „Neu berechnen“ drückt. Ältere Wochen ändern sich nicht von selbst.
- [ ] Erinnerungen nach dem ersten Start: die wiederholenden Erinnerungen von 1.9.0 sind weg, statt dessen sind Morgen, Abend und Woche je für die nächsten 7 Tage geplant. Ohne Öffnen von Thalia enden sie nach etwa 7 Tagen (wie die Abende schon in 1.9.0).

**Health teilen (nur TestFlight-Version)**
- [ ] iPhone → Einstellungen → Apple Health: Schalter „Health-Werte mit Mac und Watch teilen“ (aus), Fuß „Nur in der TestFlight-Version – Apple erlaubt Gesundheitsdaten in iCloud im App Store nicht. …“. Einschalten.
- [ ] Mac und Watch zeigen danach Gewicht und Schlaf mit „aus Health am iPhone“; die Wochennote am Mac ist dieselbe wie am iPhone; kein „Wert aus Health auf dem iPhone“ mehr.
- [ ] Am Mac in einen geteilten Schlafwert klicken → kein Feld, kein Eintrag. „Eigenen Wert eintragen…“ → leeres Feld; ein eigener Wert gewinnt.
- [ ] Watch: den Editor eines geteilten Werts öffnen und „Sichern“ ohne Drehen → kein Eintrag (der Knopf bleibt grau).
- [ ] Gewicht am iPhone übernehmen und mit ⌘Z/Schütteln widerrufen → am Mac ist der Wert nach dem Abgleich weg.
- [ ] Etwas, das Health gelesen, aber niemand übernommen hat, steht am Mac als „Health am iPhone: … – dort übernehmen“ (nur lesen).
- [ ] Mac, Heute: ein Fortschrittspunkt oder Wochenziel auf einem Health-Messwert (z. B. Gewicht) zeigt unter „Heute eintragen“ den geteilten Wert ohne Feld und ohne −/+, mit „Eigenen Wert eintragen…“.
- [ ] Mac → Ziele → Zielüberprüfung: ein Ergebnis aus einem Health-Messwert zeigt den geteilten Wert (kein „Wert aus Health auf dem iPhone“); „Bericht kopieren“ und am Mac „Prompt kopieren“ (Woche) enthalten die geteilten Werte nicht (Messwerte „nicht erfasst“ wie in 1.9.0); „Bericht kopieren“ im Wochenabschluss zeigt sie wie am iPhone.
- [ ] Nach dem Übernehmen durch das iPad heißen die geteilten Werte am Mac, auf der Watch und am iPhone „aus Health am iPad“ (bzw. „Health am iPad: … – dort übernehmen“); das Messwert-Fenster zeigt dazu das iPad-Symbol.
- [ ] Die Datenschutz-Texte zeigen die TestFlight-Fassung: Einstellungen → iCloud & Daten → „Wo deine Daten liegen“ („Bleibt auf dem Gerät – außer beim Teilen (TestFlight)“), Einstellungen → Apple Health, Messwert → Apple Health („Übernehmen“), Messwert-Editor → Quelle Apple Health. Am Mac ist „Wo deine Daten liegen“ offen, am iPhone wird eingeschaltet → nach dem Abgleich zeigt der Mac die neue Fassung, ohne den Bildschirm neu zu öffnen; ausschalten → die alte kommt zurück.
- [ ] iPhone im Flugmodus starten → nichts wird gelöscht, die geteilten Werte bleiben.
- [ ] Am iPad einschalten, während das iPhone teilt → Rückfrage „Teilen läuft schon auf einem anderen Gerät (iPhone, zuletzt …). Hier übernehmen?“ → „Übernehmen“ → nach dem Abgleich ist der Schalter am iPhone aus, Fuß „Teilen wurde auf einem anderen Gerät beendet oder übernommen.“ – auch wenn Thalia am iPhone vorne blieb.
- [ ] Schalter aus → der Mac zeigt wieder „Wert aus Health auf dem iPhone“; das App-Protokoll meldet „Health sharing off: n shared day(s) deleted“.
- [ ] Debug-Build am Mac mit `-HealthShareGate denied` starten → alle `hshare.`-Datensätze sind weg, das iPhone schaltet sich ab.
- [ ] Den Mac mit `-HealthShareGate denied` offen lassen und am iPhone wieder einschalten → nach dem nächsten Abgleich am Mac sind die Datensätze wieder weg und das iPhone schaltet sich ab (ohne Neustart des Macs).
- [ ] Erster Start nach der Installation → die Tour hat die Karte „Health am Mac und auf der Watch“ (nur TestFlight).
- [ ] Die Checkliste „Vor App-Store entfernen“ steht unten in diesem Abschnitt und in STATUS.md.

**Wer wertet abgeschlossene Wochen**
- [ ] Mac: eine abgeschlossene Woche 5 Wochen zurück mit einem Health-Fortschrittspunkt ändern → der Mac speichert keine Note; nach dem Abgleich zeigt das iPhone (Rückblick) die neue Note.
- [ ] Mac: eine alte Woche abschließen → das iPhone wertet sie nach dem Abgleich nach (auch in einem früheren Abschnitt).
- [ ] Solange ein Gerät 1.9 hat: der Mac wertet nicht selbst (nur das iPhone).
- [ ] Mac, eingefrorene Woche mit Health-Punkt: „Hier fehlen die Werte aus Apple Health.“ und „Am iPhone neu berechnen“ → Hinweis „KWnn wird nach dem Abgleich am iPhone neu berechnet.“, keine Note am Mac; nach dem Abgleich zeigt das iPhone die neue Note.
- [ ] iPhone: „Neu berechnen“ → Hinweis „KWnn: 7,84 → 8,02“ (Beispiel) → „Widerrufen“ stellt die alte Note und die Kategorie-Noten wieder her.
- [ ] Eine eingefrorene Woche, deren Note heute anders wäre, zeigt die gespeicherte Note überall (Woche, Mac-Spalte, Abschluss, Bericht, PDF, Teilen-Bild) und darunter „Nach heutigem Stand: …“.
- [ ] Frisch installiertes iPhone: alte Health-Wochen behalten ihre Note, auch wenn der Mac „Am iPhone neu berechnen“ geschickt hat – Hinweis „KWnn: Auf diesem iPhone fehlen die Health-Werte von damals – die Wertung bleibt.“
- [ ] „Woche wieder öffnen“ einer eingefrorenen Woche fragt zuerst („KWnn wieder öffnen?“); danach „Widerrufen“ im Hinweis „KWnn wieder geöffnet“ stellt die Note genau wieder her.
- [ ] Mac oder schmales iPad, Woche mit Health-Fortschrittspunkt: unter der Note „Ohne Werte aus Apple Health – am iPhone kann die Wertung höher sein.“, in „Werte“ „aus Health am iPhone“; beim Abschluss „Hier ohne Werte aus Apple Health gewertet – das iPhone rechnet nach dem Abgleich nach.“
- [ ] Mac, ⌘Z nach 10 Minuten oder nachdem der Eingang gelesen wurde → nimmt nur den letzten Haken zurück, nicht die Wartung. ⌘Z nach einem Vereinen (Haken am Mac, Notiz am iPhone zum selben Punkt) tut nichts und stürzt nicht ab.
- [ ] Einen Tag auf zwei Geräten abschließen, dann an einem wieder öffnen → nach dem Abgleich bleibt er offen.
- [ ] Einen doppelten Punkt löschen → beide Kopien liegen in „Zuletzt gelöscht“. Wiederherstellen, während es den Punkt in der Woche noch gibt → Rückfrage („„…“ gibt es in KWnn schon.“ / „Trotzdem wiederherstellen“).

**Mac**
- [ ] Fenster 1180 und 900 pt breit, je mit und ohne „Heute im Blick“ bzw. „Wochenübersicht“; die Seitenleiste ziehen und ausblenden → kein Flackern, die Seitenleiste nie verdeckt, alle vier Markierknöpfe sichtbar.
- [ ] Bei 1024 pt: ⌘0, Symbolleistenknopf, Tagesring und Seitenleisten-Karte öffnen „Heute im Blick“ als Blatt; ⌥⌘0 öffnet die „Wochenübersicht“ als Blatt, auch von Heute aus. Tooltip „Fenster breiter ziehen, um die Spalte zu zeigen“.
- [ ] ⌘W, dann ⌘N → das Hauptfenster kommt mit „Power-Hours erfassen“. Einstellungen vorne, ⌘↩ → das Hauptfenster mit „Tag abschließen“ (ist „Tag abschließen“ schon offen, holt ⌘↩ es nur nach vorn – abgeschlossen wird nie aus einem Fenster dahinter).
- [ ] Hauptfenster zu, Einstellungen offen, eine Abend-Erinnerung tippen → das Hauptfenster öffnet mit „Tag abschließen“.
- [ ] App aktivieren, ⌘1 → der erste offene Punkt ist markiert → „1“ setzt ihn ohne Klick; ⌥⌘↓, dann „1“ ebenso.
- [ ] Kürzel: ⌥⌘J „Jahresziel eintragen…“, ⌥⌘L „Lesen…“ (Buch vorgewählt, Zahl, ↩ trägt ein), ⌥⌘0 „Wochenübersicht“, ⌘T „Zu heute“ (auf Woche zur laufenden Woche; ⇧⌘T gibt es nicht mehr), Darstellung → „Seitenleiste ausblenden“, Ablage → „Sicherung erstellen…“.
- [ ] Auf Heute verschieben ⇧⌘[ / ⇧⌘] den gezeigten Tag um eine Woche (auf Ziele und Rückblick grau); ⇧⌘↩ öffnet die Woche des gezeigten Tags; ⌘6 die Ausgaben des gezeigten Tags. Ein Klick in die leere Seitenleiste lässt die Seite stehen.
- [ ] Woche: Titel „KW47“ mit den Tagen darunter; die Knöpfe zeigen ihren Text, „Wochenübersicht“ ist bei 1024 pt sichtbar.
- [ ] Rechtsklick auf eine Notiz → „Löschen“ mit „Widerrufen“. Eine vollständige Kategorie ohne Wertung zeigt ✓ statt „100 %“.
- [ ] Menüleiste: PH oder eine Ausgabe → „Widerrufen“ in der Bestätigung (nach ~5 s weg); PH bis 16; „Einstellungen…“. Nur über die Menüleiste benutzt → am iPhone steht beim Mac unter „Geräte im Abgleich“ eine aktuelle Zeit.
- [ ] Theo (oder eine andere App) im Vordergrund, Thalia im Hintergrund → Thalia liest spätestens nach 5 Minuten (Menüleiste aktuell).
- [ ] Ziele → Jahresziel eintragen: einen Wert tippen → ⌘N, ⌘↩, ⇧⌘N sind grau, bis gesichert oder abgebrochen ist; ebenso ⌘1–⌘4, ⌘T, ⌥⌘0 (und ⌘0 außerhalb von Heute) – der getippte Wert geht nicht verloren.
- [ ] Energieverbrauch von „Woche“ im Hintergrund ≈ 0 (der bewegte Verlauf pausiert).

**Erinnerungen**
- [ ] Ein Krank- oder Urlaubstag bekommt keine Morgen-Erinnerung.
- [ ] Woche am Sonntagvormittag am Mac abschließen → am iPhone keine 17-Uhr-Erinnerung „Wochenabschluss“. Ist die nächste Woche ohne Plan, kommt statt dessen „Nächste Woche planen“.
- [ ] Am Montag die Sonntags-Erinnerung tippen → öffnet die Vorwoche, nicht die neue leere.
- [ ] iPhone gesperrt, Tag am Mac kurz vor der Abend-Erinnerung abschließen → keine Abend-Erinnerung.

**Siri, Widgets, Watch**
- [ ] „Messwert eintragen“ → Gewicht → Siri fragt „Welcher Wert für „Gewicht“ (kg)?“; ein Zähler ohne Einheit (oder „Stück“) speichert 1; Siri bietet die Messwerte der Woche zur Auswahl.
- [ ] Ausgabe per Kurzbefehl bei gesperrtem iPhone → am Mac sichtbar, ohne dass die App offen war (sonst bleibt die Grenze in SYNC.md).
- [ ] Krank-Tag: „Stand des Tages“ sagt „Heute: Krank – der Tag zählt nicht. … PH.“; das Teilen-Bild des Tages zeigt „–“ mit „Krank“.
- [ ] Großes Widget: bis zu 3 Messwert-Chips und „Alles Wichtige erfasst · diese Woche noch n“; mittleres Widget dieselbe Zeile (bis zu zwei Zeilen) und ohne Plan „Kein Plan – tippen“; Woche-Widget „Alle Jahresziele gleich gewichtet“.
- [ ] Watch: ein Punkt mit Haken aus einer verbundenen App zeigt „⇄ …“; Tippen blendet den Haken aus (im Auswahlfenster „Haken der App ausblenden“). Ein Wert aus einer App ist nur zum Lesen („aus <Quelle>“).
- [ ] Watch: PH sichern → „+1 PH · <Bereich> – Widerrufen“ für 4 s; Tippen → „Power-Hours gelöscht“, der Block liegt in „Zuletzt gelöscht“. Die PH-Auswahl zeigt „Heute erfasst“ (wischen → „Löschen“) und je Bereich „6/8 PH · Woche“.
- [ ] Watch: Sonntag oder arbeitsfreier Tag → „Arbeitsfrei“, Krank-Tag → „Krank“ statt „Noch keine PH“. Beantwortete Zeilen sind blasser. Wertzeilen zeigen „Ziel …“ und ein grünes ✓, wenn erreicht; Wochenpunkte „2/3×“.
- [ ] Watch: Gewicht ganz ohne Wert → kein Editor; mit Wert → die Krone startet dort; Editor öffnen und „Sichern“ ohne Drehen → kein Eintrag.
- [ ] Watch ohne Plan: Seite 1 sagt „Wochenplan am iPhone oder Mac importieren – danach kommt er über iCloud.“; leere PH-Auswahl „Noch keine Bereiche. Öffne Thalia am iPhone und warte kurz auf iCloud.“ Eine Watch ohne iCloud zeigt orange „Nur auf der Watch gespeichert – iCloud nicht verfügbar“.
- [ ] Tag am iPhone abschließen → die Komplikation zeigt „Abgeschlossen“, ohne die Watch-App zu öffnen. Sonntag vor dem Import → Montag früh „Neuer Tag“ statt „Kein Plan“. Arm heben und senken ohne Änderung → kein neuer Schnappschuss (Protokoll).

**Sicherung und Import**
- [ ] Einstellungen → Deine Daten: erste Zeile „Sicherung erstellen…“ (Fortschritt „Sicherung wird erstellt …“, Hinweis „Sicherung gespeichert“); darunter „Letzte Sicherung: … am iPhone (vor … Tagen) · automatisch: …“. Am iPhone sichern → am Mac steht nach dem Abgleich „… am iPhone“.
- [ ] Nach einer Woche mit Thalia im Hintergrund liegt eine datierte Datei „Thalia Sicherung JJJJ-MM-TT.csv“ in Application Support/Sicherungen; Einstellungen → Deine Daten → „Sicherungen“ listet sie mit Größe und „Teilen…“. Nach der achten Woche räumt sie richtig auf (4 neueste + je Monat eine).
- [ ] Wochenabschluss: wenn seit 30 Tagen kein Gerät von Hand gesichert hat, steht nach den Berichtsknöpfen „Letzte Sicherung vor … Tagen – jetzt sichern?“ (ohne jede Sicherung „Noch keine Sicherung – jetzt sichern?“).
- [ ] Sicherung einlesen: Kopf „Sicherung vom 22.11.2026, 18:03 · Thalia 1.10.0 (58) · iPhone“ (Beispiel); ist sie älter als einen Tag, sagt eine orange Zeile, wie viele Markierungen und Werte auf den Stand der Sicherung gesetzt werden.
- [ ] Frisches Gerät: der Import warnt „iCloud lädt noch deine Daten. …“, bis der ganze erste Abgleich fertig ist (erst 60 s nach dem letzten Import); „Trotzdem einlesen“ fragt.
- [ ] Jahres-Sicherung (52 Wochen) einlesen: die Datei steht als eine Zeile mit Größe und „Datei entfernen“, „Sicherung wird gelesen …“, dann „Sicherung wird eingespielt – bitte warten“ – kein Einfrieren.
- [ ] Original nach der Sicherung bearbeiten, dieselbe Sicherung auf zwei Geräten einspielen → nach dem Abgleich zählen PH, Notizen und Werte einmal, die Änderung am Original bleibt.
- [ ] Eine Sicherung am Mac einspielen → keine Wochennote ändert sich (die `wertung`-Zeilen behalten die gespeicherten Noten). Eine Datei, die Noten einer abgeschlossenen Archivwoche ändert → der Mac behält seine Note, das iPhone wertet nach dem Abgleich.
- [ ] Mac: „Diese Woche als CSV“ einer abgeschlossenen Woche mit Health-Fortschrittspunkt ändern und wieder importieren (die Woche wird ersetzt), dann „Widerrufen“ → der Mac speichert keine eigene Note (bis zum Abgleich zeigt er die Note nach heutigem Stand), das iPhone wertet die Woche nach dem Abgleich.
- [ ] Frisches Gerät, Sicherung früh einlesen („Trotzdem einlesen“) → kommt danach das echte Zieljahr (oder eine abgeschlossene Woche mit späterer Note) über iCloud, gilt das echte.
- [ ] Demo (`-Demo`): Einstellungen → Deine Daten zeigt kein „automatisch: …“ und „Sicherungen“ keine echten Dateien dieses Geräts.
- [ ] Eine Woche neu importieren, dann „Widerrufen“ → „Auch in den nächsten Wochen“ (Planänderung) ist wieder da. „Vergangene Woche nachtragen“, dann „Widerrufen“ → eingefügte Notizen, PH und Reflexionen sind weg, Tagestypen zurück, die betroffenen abgeschlossenen Wochen neu gewertet.
- [ ] Eine Datei nennt einen Urlaubstag „Arbeitstag“ → der Tag bleibt „Urlaub“, Zeile „Fr 27.11.: bleibt „Urlaub“ – die Datei sagt „Arbeitstag“.“ (Beispiel). Dieselbe Datei noch einmal → „unverändert“.
- [ ] „1,125“ übersteht Sichern und Einlesen (in der Datei „1.1250“); ein einzelner Wert behält seine Uhrzeit; „8.000“ in einer ChatGPT-CSV wird als 8 gelesen, mit dem Hinweis „… Tausenderpunkt? Bitte 8000 schreiben“.
- [ ] Eine CSV für KW49, während KW48 gewählt ist → orange „Die CSV ist für KW49 – gewählt ist KW48.“, Importieren fragt „Trotzdem KW49 importieren“.
- [ ] Ein Plan kommt vom iPad, nachdem die Vorschau gebaut war → beim Importieren „KW48 ersetzen?“ statt einer stillen Mischung.
- [ ] Nie in ein Gerät einlesen, dessen erster iCloud-Abgleich noch läuft.

**Heute, Erfassen, Tag abschließen**
- [ ] Erfassen → „Messwert eintragen“ zeigt „Heute“ und „Diese Woche“; nach der Wahl hat das Feld den Fokus (Mac ⇧⌘E ebenso).
- [ ] Erfassen: Reihenfolge Lesen, Tag abschließen, Jahresziel eintragen (Pokal), Punkt anlegen, Messwert anlegen, Wochenplan importieren, Fokus ansehen; die vier Kacheln bleiben.
- [ ] Wochenziele in Heute in der Farbe ihres Stands, neben „x von y“ das kurze Wort („im Plan“, „hinter dem Plan“, „noch offen“); Grenzen „im Rahmen“ / „überschritten“, nie „erreicht“. Anteilige Ziele ohne Hundertstel („150 von 86 Stk.“, „Ziel 86 statt 100 Stk. – 1 Tag krank“).
- [ ] Fokus: „noch 0,8 PH offen“ und „6 / 8 PH“, in vergangenen Wochen „Wochenziel“; an einem Erholungstag „heute frei“, krank „heute krank“.
- [ ] Wochenziel mit Bereich (z. B. „150–180“) oder „= 3“: im Bereich „erreicht“ (grün), darüber nach dem Wochenende „nicht erreicht“ – in Woche, Heute, Fokus, Wochen-PDF und Bericht gleich.
- [ ] „Heute im Blick“ → „Diese Woche noch“: Titel und darunter „0 von 1“ bzw. „0 von 1 · Rest zählt halb (krank)“.
- [ ] Tag abschließen: Titel „Sonntag, 22. November“ (Jahr nur in einem anderen Jahr), „Noch 3 offen – zählen nicht mit“, unten „Tag abschließen · 3 bleiben offen“; „Arbeitsfrei – keine PH nötig“.
- [ ] Eigene Wertung entfernen → „Widerrufen“ bringt Note und Grund zurück. Vergangene Woche → „Wertung entfernt“ → „Widerrufen“ ebenso.
- [ ] Tagebuch am iPhone schreiben, während am Mac „Tag abschließen“ offen ist → der Mac folgt, oder zeigt bei einem dort getippten Feld „Am anderen Gerät geändert“ mit „Übernehmen“. Ebenso im Wochenabschluss.
- [ ] Zu morgen blättern, Mond tippen → der heutige Tag; ein Link auf einen künftigen Tag zeigt „Abschließen geht erst am …“.
- [ ] In ein Feld mit einem Health-Wert klicken und wieder heraus → kein Eintrag.
- [ ] Ausgaben „< 50 €“ mit 20,10 + 29,90 → „nicht unter 50 €“; „≤ 50 €“ → „Limit ausgeschöpft“.
- [ ] Der Heute-Titel zeigt einen langen Kategorie-Titel ganz (zwei Zeilen). VoiceOver auf Notiz- und Ausgaben-Zeilen: ein Knopf mit Hinweis; das Messwert-Feld heißt „<Titel> in <Einheit>“.

**Woche, Abschluss, Rückblick, PDF**
- [ ] Mittwoch die Woche teilen → „Zwischenstand“, Ring „bisher“.
- [ ] Woche als PDF → „PDF wird erstellt … Seite x von y“; Schließen bricht ab.
- [ ] PDF-Bericht über eine abgeschlossene Archivwoche und eine Woche mit abgeschlossenem Krank-Donnerstag → „n/n Wochen abgeschlossen“ (die laufende Woche zählt offen), die Tage ohne den Krank-Tag; Noten mit bis zu zwei Stellen; Trend erst ab 4 gewerteten Wochen („steigend (je k)“, sonst „Trend –“).
- [ ] Wochenabschluss einer längst vergangenen Woche bietet keine Planung an; in der laufenden Woche vor Sonntag steht „Diese Woche läuft noch bis Sonntag.“
- [ ] Rückblick zeigt „n/total Ziele bewertet“ nur, wenn Ziele fehlen. Texte sagen „gleich gewichtet“ statt einer festen Prozentzahl.

**Ziele und Leseliste**
- [ ] Ergebnisse sagen „auf Kurs“ / „im Rückstand“, Grenzen „im Rahmen“ / „zu schnell“ / „überschritten“ / „eingehalten“ – Farbe nur nach Stand; „5 von höchstens 20 Packungen“. Ergebnisse haben das Pokal-Symbol; die Zielflagge gibt es nur noch beim Wochenabschluss.
- [ ] „10 Bücher“ zählt alle fertigen Bücher; ein Hörbuch mit „Zählt für“ kommt dazu (2 Bücher + 1 Hörbuch → 3), ohne die Bücher hinauszuwerfen.
- [ ] Buch-Fenster „Schon gelesen bis Seite 120“, dann „+ Seiten 20“ → Stand 140, gezählt werden 20 Seiten (Fuß „Zählt nicht als gelesen – nur was danach dazukommt.“).
- [ ] Leseliste: Tippen auf ein laufendes Buch trägt Fortschritt ein, Wischen bietet „Bearbeiten“; Zusammenfassung „Gelesen in Abschnitt 2: …“ bzw. „Gelesen im Zieljahr: …“.
- [ ] Erfassen → Lesen: das zuletzt gelesene laufende Buch ist gewählt, die Zahl hat den Fokus, „Eintragen“ (Mac: ↩) sichert. „Jahresziel eintragen“ wählt das Ergebnis, wenn es genau eins gibt.
- [ ] Zielkarte: der Schritt zur laufenden Woche ist gestrichelt und blasser. Zielüberprüfung zeigt am iPhone den Gewichtswert, am Mac „Wert aus Health auf dem iPhone“; Trend „erste k Wo. … → letzte k Wo. …“ bzw. „noch zu wenige Wochen für einen Trend“.
- [ ] Gewicht am iPhone ändern, Ziele am Mac offen → das Ergebnis zeigt nach dem Abgleich den neuen Wert.
- [ ] Zeitziele über Mitternacht: „≤ 00:30“ – 23:30 erreicht, 00:45 nicht; „23:00–00:30“ – 23:30 und 00:15 erreicht; ein Wochenmittel aus 23:30 und 00:30 ist 00:00. „spätestens 23:00“ zählt als ≤ 23:00.
- [ ] Eine verpasste Wochenquote mit leerem Sonntag senkt die Note (vorher konnte ein leerer letzter Tag sie auf 10 heben).

**Einstellungen, iCloud und Übung**
- [ ] Einstellungen → iCloud & Daten: „Gesendet: vor … · Empfangen: vor …“; 20 Minuten Flugmodus mit einer Änderung → orange „Letzte Änderung noch nicht an iCloud gesendet“.
- [ ] „Geräte im Abgleich“: Version je Gerät; Geräte, die 60 Tage nicht gesehen wurden, unter „Früher“ mit „Entfernen“ → „Widerrufen“.
- [ ] Debug-Startoptionen `-FakeSyncProblem local`, `memory` und `quota` zeigen je ihre Zeile (iPhone über dem Inhalt, Mac unten in der Seitenleiste und im Menüleisten-Fenster); `memory` ist rot und bleibt, die anderen lassen sich bis zum nächsten Start ausblenden. Tippen öffnet die Einstellungen.
- [ ] Ein Speicherfehler zeigt höchstens alle 10 Minuten „Konnte nicht speichern – Details unter Einstellungen → iCloud & Daten“ und dort „Letzter Speicherfehler: …“.
- [ ] Während der Tour ist ⇧⌘I grau; Mehr → Import (und Nachtragen, PDF, Papierkorb, Einstellungen) gibt es in der Übung nicht bzw. zeigt „In der Übung nicht verfügbar – nach der Tour mit deinen eigenen Daten.“
- [ ] Einstellungen → Jahresziele: Beginn, Ende und Zielüberprüfung speichert erst „Zieljahr sichern“; das Motto erst mit ↩ oder beim Verlassen. Neuer Beginn, während Ergebnisse dem alten gehören → „Beginn des Zieljahrs ändern?“ → „Neues Zieljahr beginnen“ → der Hinweis „Neues Zieljahr ab …“ hat „Widerrufen“ und bringt den alten Beginn samt Ergebnissen zurück.
- [ ] Mac-Einstellungen: der Text zu Kartenzahlungen nennt den Weg am iPhone (Kurzbefehle → Automation → Transaktion).

**Schonfrist und Notiz am abgeleiteten Haken (von Bini bestätigt, 23. Nov. 2026)**
- [ ] Eine Notiz an einem abgeleiteten ✓ („⇄ George · …“) macht ihn zum eigenen – er bleibt, auch wenn die Tatsache der App später verschwindet.
- [ ] Die Woche direkt vor einem neuen Abschnitt friert erst nach dessen erster Woche ein (Schonfrist): eine Änderung in der ersten Woche des Abschnitts wertet sie noch neu.

**Finn (nach Finns Build, CONNECTED_APPS.md Auftrag 3.4)**
- [ ] In Finn ist jede Zeile einzeln schaltbar (Standard aus), daneben „→ Thalia: …“ bzw. „noch nicht in Thalia verknüpft“.
- [ ] Vermögen ändert sich → das Thalia-Ergebnis „Vermögen“ zeigt am selben Tag den neuen Stand.
- [ ] Ein Konto eingeschaltet → ein Ergebnis mit Quelle „Finn · Kontostand · <Konto>“ zeigt seinen Stand; der Ergebnis-Editor verlangt ein Konto (kein „alle“).
- [ ] Der Messwert-Editor bietet Vermögen, Sparquote und Kontostand nicht an; ein vorhandener Messwert mit einer davon zeigt „Für ein Jahresziel-Ergebnis gedacht – ein Messwert in € zählt als Ausgabe.“

**Demo und Screenshots**
- [ ] CI-Screenshots zusätzlich iPhone `goals`, `review`, `close-week`, `settings`, `backup`, `health` und Mac `review`, `settings`; kein leeres Bild. Im Demo zeigt `close-week` „Noch keine Sicherung – jetzt sichern?“ – so gewollt (der Demo-Speicher hat keine Sicherung).
- [ ] Mac `today` und `week` bei 1024 × 768: ganze Seitenleiste, vier Markierknöpfe, „Wochenübersicht“ sichtbar; `mac-goal-detail` und `mac-reading` zeigen die Zielseite bzw. die Leseliste (nicht die Ziele-Seite).
- [ ] Komplikation und Widget-Zeilen fassen „12,75 PH“; `weekly-goals` zeigt keine Hundertstel.
- [ ] Die Demo-Noten sind dieselben wie in 1.9.0 (nur Texte, Rundung der Anzeige und Status-Wörter sind neu).

**Vor App-Store entfernen – Pflicht vor jedem Einreichen eines Builds zum App Store (TASKS-v11 §1.4.12)**

Solange das Teilen im Build ist, geht er nur an interne TestFlight-Tester. TestFlight und App Store nutzen dieselbe
hochgeladene Datei; die App-Prüfung läuft laut Apple in der Sandbox – vor dem ersten Einreichen bestätigen, ob das
Tor dort offen wäre.
- [ ] (a) `grep -rn HEALTHSHARE App Shared Watch Packages Config` (196 Zeilen, Stand 1.10.0) – jede markierte Stelle entfernen:
  `Shared/WeekReader.swift` (2: die `hshare.`-Schlüssel in `keys`); `Shared/WeekContext.swift` (13: `healthShare`, die
  geteilte Health-Eingabe im init → wieder `self.health.compactMap(\.record)`, `sharedHealthKeys` und der Filter in
  `reportInput(sharedHealth:)` (der Parameter darf bleiben), die Ausnahme in `isHealthElsewhere(_:on:)`,
  `sharedHealthValue`, `sharedHealthSuggestion`); `Shared/TrackerStore.swift` (7:
  `shareKeys` in `weekSettings`, `shared` in `lastValue` und `measureSeries`, `|| healthShareCovers(week)` in
  `canScore`, der Kommentar zu `reportInput(sharedHealth: false)` im Planungs-Prompt); `App/Sources/AppModel.swift` (18: `healthShare` und sein init, `startHealthShare()` – nur Tor-Prüfung
  und `cleanUpHealthShare(gate:)` für `.denied` bleiben, ebenso die Bereinigung nach jedem Abgleich in `afterSync`
  (`isConfirmedDenied`) –, `healthShareGateChanged`, `healthValuesSaved` und sein
  didSave-Haken, der Aufruf in `refreshToday`, `healthShare.syncArrived(store:)` in `afterSync`, `tourCatalog` →
  `ThaliaTour.catalog`, die 2-s-Wartezeit in `offerTourIfNeeded`, `-DemoScreen health`); `App/Sources/SettingsView.swift`
  (7: `ThaliaDataLocationView.sections`, `ThaliaDataFacts.sections(sharingHealth:)` und `sharedHealthFact`, die
  `app`-Umgebung, `storageText` und `HealthShareSection()` in HealthSettingsView); `App/Sources/Services.swift` (2:
  `readValues`, iOS und macOS); `App/Sources/TodayView.swift` (8: MeasureRow `sharedValue`, `phoneSuggestion`, der
  Zweig SharedHealthInput, die Zeile unter dem Titel; WeeklyGoalRow der Zweig SharedHealthInput; MeasureMenu
  `hasOwnValue`); `App/Sources/GoalsView.swift` (2: GoalReviewView `showsHealth` → wieder `HealthDevice.readsHealth`,
  `copyReport` → wieder `report`); `App/Sources/Editors.swift` (7:
  MeasureForm `sharesHealth`, `adoptTitle`, `adoptFooter` → die festen Texte, die Abschnitte für den geteilten Wert und
  den Vorschlag vom iPhone); `App/Sources/ConnectedApps.swift` (2: `app` und der `.health`-Fuß in
  MeasureSourceSection); `App/Sources/GoalResults.swift` (1: `shared` in `loadKey`); `App/Sources/CloseWeekView.swift`
  (1: die `healthShareCovers`-Bedingung in `healthNote`); `App/Sources/Glance.swift` und `CloseDayView.swift` (je 1:
  `(…, on: day)` – darf bleiben); `Watch/Sources/WatchValues.swift` (6: Kommentar und `healthCaption` → wieder
  `WeekContext.healthElsewhereHint`); `Watch/Sources/ThaliaWatchApp.swift` (7: `gateTick`, `.id`, `.onReceive` und die
  tägliche Bereinigung bei `.active` weg; die `.task` mit `resolve()` + `cleanUpHealthShare(gate:)` für `.denied`
  und die `.denied`-Bereinigung bei `.active` (`isConfirmedDenied`) bleiben); `Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift` (2: `healthShareStep`, `catalog(healthShare:)` →
  `catalog`); `Config/ci.env` (1: `health`). Ohne eigene Marke, nichts zu tun: FrozenWeekNote (über `canScore`), die
  Mac-Hinweise (über `isHealthElsewhere(_:on:)`), `resultSeries` (über `measureSeries`).
- [ ] (b) `App/Sources/HealthShareSettings.swift` ganz löschen. In `Shared/HealthShareStore.swift` nur HealthShareGate
  (Zustände, Cache, `verdict(for:)`, `resolve(timeout:)`, `isConfirmedDenied`) und `TrackerStore.cleanUpHealthShare(gate:)` mit dem
  `.denied`-Zweig samt `removeAllHealthShare()` behalten – die **Bereinigung bleibt dauerhaft** (eine Präfix-Abfrage
  beim Start). In `Packages/ThaliaCore/Sources/ThaliaCore/HealthShare.swift` nur `prefix`, `stateKey`, `isKey` und
  `HealthShareState` (`newest`, `stopped`) behalten.
- [ ] (c) Tests: in V11Tests C14 nur die Schlüssel- und Bereinigungs-Tests behalten; die Schlüssel-Tests in
  V11BackupTests bleiben.
- [ ] (d) Die Absätze zum Teilen streichen: hier („Health teilen“ und diese Checkliste nach dem Entfernen), STATUS.md,
  SYNC.md („Health teilen (nur TestFlight)“ und die Ausnahme in der Health-Zeile), TOUR.md (Zeile `health-share`).
- [ ] (e) App-Review-Notiz: keine Gesundheitsdaten in iCloud.
- [ ] Danach: `grep -rn HEALTHSHARE` findet nur noch die Bereinigung; `scripts/ci/local-check.sh` grün.
