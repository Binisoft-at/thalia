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

