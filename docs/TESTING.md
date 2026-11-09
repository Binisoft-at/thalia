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
