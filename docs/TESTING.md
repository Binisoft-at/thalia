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
- [ ] Vorschlag übernehmen → Wert zählt; am Mac erscheint **kein** Health-Wert (bleibt auf dem iPhone, so gewollt), deine Markierung aber schon.
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
- [ ] Symbolleiste: ‹ Heute › (auch ⌘[ ⌘] ⇧⌘T), „Tag abschließen“, „+“.
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
- [ ] Menüleiste: „73 %“ oben rechts; das Fenster zeigt die Statuszeile, Power-Hours mit den letzten Kombinationen, eine Ausgaben-Zeile, „Thalia öffnen“ und „Tag abschließen…“. Abschaltbar in den Einstellungen.
- [ ] Tastatur auf Heute: ↑/↓ wählt einen Punkt, 1–4 setzt Erledigt/Teilweise/Nicht erledigt/Entfällt, die Auswahl springt zum nächsten offenen Punkt; ⌥⌘↓/↑ wechselt die Kategorie. Gleiches am iPad mit Tastatur.
- [ ] ⌘0, Klick auf den Ring und auf „HEUTE“ in der Seitenleiste blenden „Heute im Blick“ rechts ein und aus; die Spalte lässt sich ziehen (220–400 pt).
- [ ] Abendnotiz tippen, dann ⌘N: der Befehl ist ausgegraut, nichts geht verloren. Ebenso im Punkt-Fenster: Notiz tippen, ⌘N / ⇧⌘N / ⌘↩ → nichts passiert.
- [ ] Einstellungen → Archiv → „Wiederherstellen“ bzw. ein Import, der eine Woche ersetzt: der Hinweis mit „Widerrufen“ erscheint im Einstellungsfenster, nicht dahinter.
- [ ] Woche: die Leiste zeigt „Vorige Woche“, „Diese Woche“ (⌘T), „Nächste Woche“ und „Wochenübersicht“ (⌥⌘0) mit Text.
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
- [ ] Einstellungen → „Alles als CSV“ enthält die `category_score`-/`goal_score`-Zeilen, die Spalte `count` und die Quelle in der `week`-Zeile; diese Datei wieder importieren → „unverändert“.

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
