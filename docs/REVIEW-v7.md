# Thalia – App-Durchsicht v7 (Optimierungen)

Stand: 16. November 2026, nach TestFlight 1.5.0 (36).

**Wie geprüft wurde:** Neun Bereiche (Heute, Heute im Blick, Abschluss & Rückblick, Woche, Erfassen & Import, Mac & iPad, Fokus/Ausgaben/Widgets/Watch, Daten & Sync, Gestaltung & Barrierefreiheit) wurden je von einem Prüfer anhand von Code, Screenshots und den Entscheidungen in `docs/TASKS-v2.md` … `docs/TASKS-v6.md` durchgesehen. Jeder Fund ging an einen eigenen, skeptischen Gegenprüfer, der ihn widerlegen sollte. Von 124 Funden blieben 121, zusammengefasst zu 89 Punkten (R1–R89). Eine abschließende Vollständigkeitsprüfung hat 8 weitere Punkte ergänzt (R90–R97) und Hinweise zur Umsetzung gegeben.

Aufwand: S = klein (Stunden), M = mittel (ein Tag), L = groß. Wirkung: 1–5, wie stark es Bini im Alltag hilft.

## Zusammenfassung

Thalia bildet den Papier-Tracker und Binis Entscheidungen schon sehr genau ab: direkte Knöpfe mit Wörtern, eine Wertung erst nach dem Abschluss, Power-Hours nur mit Bereich und „Wofür“, Zielfarben und eine Mac-App mit Seitenleiste und Menüs. Die Rechenlogik ist sauber getrennt und gut getestet, und fast überall gibt es „Rückgängig“. Am meisten lässt sich an den Rändern gewinnen. Erstens beim Tageswechsel: Mitternacht, Widgets und Mitteilungen hängen am alten Tag. Zweitens bei Nebenwegen, die Binis eigene Regeln umgehen, nämlich Watch-Ausgaben, das Messwert-Fenster und Kurzbefehle. Drittens bei Zahlen, die je nach Bildschirm Verschiedenes sagen („11 offen“ gegenüber „16“, eine Wertung vor dem Abschluss). Bei der täglichen Eingabe bringen eine Fertig-Taste, Vorschläge über die Woche hinaus, ruhigere beantwortete Zeilen und mehr Platz auf „Heute“ am meisten. Am Mac fehlen vor allem die Bedienung per Tastatur und Fenster, die ins Hauptfenster passen.

## Bugs

1. **R1 „Heute“ springt um Mitternacht nicht weiter, solange die App offen ist** – Bleibt das Mac-Fenster über Nacht offen, gilt am Morgen noch gestern als „Heute“, und alles Abgehakte landet still auf dem Vortag. Künftig wechselt die App beim Tageswechsel und beim Zurückkehren ins Fenster automatisch auf den neuen Tag. (Daten & Sync · S · Wirkung 5)
2. **R2 Werte setzen löscht Einträge endgültig – auf der Watch verschwinden so alle Ausgaben samt „Wofür“** – Ein Tipp auf −/+ bei „Ausgaben“ ersetzt auf der Watch alle Ausgaben des Tages durch einen Betrag ohne Zweck. Es gibt kein Rückgängig und keinen Papierkorb. Am iPhone stellt „Rückgängig“ nur die Summe wieder her. Künftig hat die Watch keine ±-Knöpfe mehr für Ausgaben. Werte werden im bestehenden Eintrag geändert, Ersetztes geht in den Papierkorb, und „Rückgängig“ stellt alles exakt wieder her. (Watch & Daten · M · Wirkung 4)
3. **R3 Messwert-Fenster und Kurzbefehl umgehen die Regeln für Power-Hours und Ausgaben** – Über „+ → Messwert eintragen“, ⇧⌘E oder ⓘ lassen sich Power-Hours ohne Beschreibung und Ausgaben ohne „Wofür“ eintragen. Die Schnellknöpfe setzen das Gewicht auf 0,1 kg, und „Thalia Messwert“ scheitert an der Vorgabe „Wasser“. Künftig führt das Fenster bei Power-Hours und Ausgaben auf die normalen Eingabewege. Der Kurzbefehl lehnt diese Fälle freundlich ab und fragt nach dem Messwert. (Erfassen · M · Wirkung 4)
4. **R4 Widgets zeigen nach Mitternacht den Vortag und übersehen Einträge von Mac und Watch** – Bis Bini am iPhone etwas ändert, steht im Widget gestern als „Heute“, manchmal sogar als „Abgeschlossen“. Künftig wechselt das Widget um Mitternacht selbst auf „Neuer Tag“. Die App aktualisiert den Stand außerdem beim Öffnen und nach dem iCloud-Abgleich. (Widgets · M · Wirkung 4)
5. **R5 „offen“ hat zwei Bedeutungen, und die Zubehörleiste sagt manchmal das Falsche** – Leiste und Watch sagen „11 offen“, während „Heute im Blick“, die Mac-Seitenleiste und die Widgets am selben Tag „16“ zeigen. Ohne Plan zeigt die Leiste „100 %“ mit grünem Haken. Künftig zählt „offen“ überall nur die Pflichtpunkte. n×/Woche-Punkte bekommen einen eigenen Abschnitt, und ohne Plan erscheint „Wochenplan importieren“. (Heute · S · Wirkung 4)
6. **R6 Die Seiten auf „Heute“ springen beim Abhaken von allein weiter** – Nach dem letzten offenen Punkt rutscht die Seite ungefragt zur nächsten Kategorie oder zurück zur ersten, obwohl unten noch Werte fehlen. Künftig wird die Startseite einmal am Tag gewählt, danach blättert nur Bini selbst. (Heute · S · Wirkung 4)
7. **R7 Die Zubehörleiste schließt „heute“, während Bini gestern nachträgt** – Die Leiste zeigt „Heute 73 %“, und der Mond schließt den heutigen Tag, das „+“ daneben bucht aber auf gestern. Künftig folgt die Leiste dem gewählten Tag und bekommt einen Knopf „Zu heute“. (Heute · S · Wirkung 3)
8. **R8 Die iPhone-Woche zeigt die Tageswertung vor dem Abschluss** – Im Streifen steht „Mo 7,5“ neben „0/7 abgeschlossen“, was gegen Binis Entscheidung U4 verstößt. Der Mac zeigt dagegen % auch für Tage, die noch kommen. Künftig zeigen beide vor dem Abschluss „% erfasst“, danach die Wertung und für kommende Tage „–“. (Woche · S · Wirkung 3)
9. **R9 Wochenzellen ohne erlaubte Markierung überschreiben still** – Bei automatischen Punkten und freien Tagen tut ein Tipp sichtbar nichts, löscht aber eine gespeicherte Markierung. Künftig sind diese Zellen gedämpft und nicht antippbar. Bei automatischen Punkten öffnet ein Tipp stattdessen das Eintragen des Werts. (Woche · S · Wirkung 3)
10. **R10 In der Mac-Wochentabelle steht der Tageskopf eine Spalte neben den Häkchen** – Bei schmalerem Fenster steht „Di“ über Montags Häkchen, ein Klick markiert also den falschen Tag, und die Spalte „Woche“ ist abgeschnitten. Künftig teilen sich Kopf und Zeilen ein gemeinsames Raster. (Mac & iPad · S · Wirkung 3)
11. **R11 Die Wertung einer abgeschlossenen Woche bleibt nach Nachträgen stehen** – Rückblick und Ziele zeigen die alte Zahl, Wochenblatt, Bericht und PDF die neue. Künftig wird die gespeicherte Wertung neu berechnet, sobald sich in dieser Woche etwas ändert. Beim Archivieren wird sie zurückgesetzt. (Abschluss & Rückblick · S · Wirkung 3)
12. **R12 „Vorschläge übernehmen“ überschreibt eigene Markierungen ohne Rückgängig** – Ein bewusst gesetztes ½ oder „Entfällt“ wird im Tagesabschluss still zu ✓ oder ✗. Künftig füllt der Knopf nur leere Punkte. Abweichungen erscheinen einzeln und eingeklappt, dazu kommt „Rückgängig“. (Abschluss & Rückblick · S · Wirkung 3)
13. **R13 Rückgängig-Hinweise sind hinter Fenstern versteckt** – Was Bini in einem Fenster löscht, bekommt den Hinweis hinter dem Fenster, also unsichtbar oder nicht klickbar. Das Punkt-Fenster bleibt nach dem Löschen offen. Künftig erscheinen Hinweise im obersten Fenster, das Punkt-Fenster schließt sich, und neue Power-Hours aus dem Fenster bekommen ebenfalls „Rückgängig“. (Erfassen · S · Wirkung 3)
14. **R14 Mac-Kürzel ersetzen ein offenes Eingabefenster, der Text geht verloren** – Drückt Bini beim Schreiben der Abendnotiz ⌘↩, verschwindet die Notiz ohne Rückfrage. Künftig sind die Befehle, die ein anderes Fenster öffnen, ausgegraut, solange ungespeicherte Eingaben offen sind. (Mac & iPad · S · Wirkung 3)
15. **R15 Mac-Fenster sind höher als das Hauptfenster** – „Tag abschließen“, PDF und Import ragen über den Rand oder hinter das Dock, sodass „Schließen“ und „Abschließen“ nicht erreichbar sind. Künftig öffnen die Fenster in passender Höhe und scrollen. (Mac & iPad · S · Wirkung 3)
16. **R16 Die Kachel „Ziele“ öffnet Fokus statt der Wochenziele** – Die Kachel zählt 6 Ziele, Fokus zeigt aber nur die 4 PH-Bereiche, und Wochenlimits werden falsch gezählt. Künftig heißt sie „Wochenziele“, öffnet eine eigene Liste mit Tempo und zählt wie das PDF. (Fokus & Ausgaben · S · Wirkung 3)
17. **R17 €-Beträge werden auf eine Nachkommastelle gerundet** – 12,99 € erscheint überall als „13 €“, 49,96 € als „50 €“ neben dem Ziel „< 50 €“. Künftig stehen Beträge immer centgenau da. (Fokus & Ausgaben · S · Wirkung 3)
18. **R18 „Tag abschließen“ nach Mitternacht öffnet den neuen, leeren Tag** – Abend-Mitteilung, Siri und Link öffnen um 0:20 den neuen Tag mit 0 %. Künftig gilt bis 4 Uhr der noch offene Vortag. (Mitteilungen · S · Wirkung 3)
19. **R19 Papierkorb leeren und Archiv löschen geschehen ohne Rückfrage** – Ein Tipp auf „Leeren“ oder ein langes Wischen löscht endgültig. Der Papierkorb zeigt dabei nur Kürzel wie „2026-W47 · 3.2“. Künftig gibt es eine Rückfrage, lesbare Zeilen mit „Wofür“, und das Neueste steht oben. (Erfassen & Import · S · Wirkung 3)
20. **R20 Beim Import wird eine korrigierte CSV ignoriert** – Eine Korrektur im Textfeld nach der Vorschau wird nicht importiert, und „Prompt kopiert“ bleibt auch nach einem Wochenwechsel stehen. Künftig aktualisiert sich die Vorschau beim Tippen, und der Kopiert-Status wird zurückgesetzt. (Erfassen & Import · S · Wirkung 3)
21. **R21 Die PH-Beschreibung in der Zeile lässt sich leer speichern** – Eine geleerte Beschreibung wird gespeichert, und ein veralteter Text überschreibt eine neuere Beschreibung. Künftig stellt ein leeres Feld den alten Text wieder her, und die Zeile übernimmt Änderungen von anderen Geräten. (Heute · S · Wirkung 2)
22. **R22 Fokus einer vergangenen Woche zeigt „Heute“ = Montag** – Blättert Bini zurück, zeigt Fokus unter „Heute“ den Montag jener Woche, und „+“ bucht ohne Hinweis auf das echte Heute. Künftig übernimmt Fokus den gewählten Tag und zeigt ihn an. (Fokus & Ausgaben · S · Wirkung 2)
23. **R23 Eine Notiz im Punkt-Fenster legt automatische Markierungen fest** – Eine Notiz an einem freien Tag speichert „Entfällt“ dauerhaft, die Wertung stimmt danach nicht mehr. Künftig ändert eine Notiz nie die Markierung. (Erfassen · S · Wirkung 2)
24. **R24 Import, Papierkorb und Tour öffnen aus den Einstellungen am falschen Ort** – Auf dem iPhone verschwinden dabei die Einstellungen, am Mac passiert scheinbar nichts. Künftig öffnen Import und Papierkorb innerhalb der Einstellungen, und die Tour holt zuerst das Hauptfenster nach vorn. (Mac & iPad · S · Wirkung 2)
25. **R25 Bei bedingten Punkten behält „Abbrechen“ die Änderungen** – Das Ausschalten einer Situation löscht ihre Markierung sofort. Künftig wirkt es erst bei „Fertig“, und der linke Knopf heißt „Später“. (Heute · S · Wirkung 2)
26. **R26 Das PDF hat drei Lücken** – Vergangene Tage stehen als „Heute“, der Wochenrückblick verliert seine zwei letzten Antworten, und die „Notiz zum Tag“ fehlt. Künftig steht dort Wochentag und Datum, der Rückblick bekommt eine eigene Seite, und die Tagesnotiz kommt aufs Deckblatt. (Abschluss & Rückblick · S · Wirkung 2)
27. **R27 Archiv und Sicherung verlieren Details** – Beim Wiederherstellen werden drei Ausgaben zu einer Zeile, alle Abschlüsse (und damit die Tageswertungen) fehlen, und bei Duplikaten landet eine ältere Fassung in der Sicherung. Künftig wird jede Ausgabe einzeln gesichert, Abschlüsse bleiben erhalten, und es zählt immer die neueste Fassung. (Daten & Sync · M · Wirkung 2)
28. **R28 Doppelte Tage und Wochen aus Offline-Sync werden nie zusammengeführt** – Ein Tagestyp kann dadurch verschwinden, oder ein abgeschlossener Tag ist wieder offen. Künftig werden Duplikate nach dem Abgleich zusammengeführt, wobei „abgeschlossen“ gewinnt. (Daten & Sync · M · Wirkung 2)
29. **R29 Die Uhrzeit-Auswahl ist an Tagen der Zeitumstellung eine Stunde falsch** – Die Bettzeit zeigt 22:00 statt 23:00, ein ✓ speichert diese falsche Zeit, und das Ziel zählt als verfehlt. Künftig wird die Uhrzeit korrekt gebildet und mit einem Test abgesichert. (Daten & Sync · S · Wirkung 2)
30. **R30 Zwei Thalia-Fenster teilen sich alles** – Fenster und Tour erscheinen doppelt, und Sichern im einen Fenster schließt das andere samt Eingabe. Künftig ist Thalia bewusst eine App mit einem einzigen Fenster. (Mac & iPad · S · Wirkung 2)

## Sofort

1. **R31 Fertig-Taste über dem Ziffernblock** – Nach einer Eingabe wie „72,5“ gibt es keine Fertig-Taste, der Wert wird erst beim Scrollen gespeichert, und bei Ausgaben muss Bini „Wofür?“ von Hand antippen. Künftig steht über dem Ziffernblock „Fertig“, das sofort speichert, und bei Beträgen „Weiter“ zum „Wofür“. (Heute · S · Wirkung 3)
2. **R32 „Wofür“-Vorschläge über die Woche hinaus und überall gleich** – Montags gibt es keine Vorschläge, und das Ausgaben-Fenster sortiert anders als die Zeile. Künftig kommen die Vorschläge aus den letzten Monaten, nach Häufigkeit sortiert und beim Tippen gefiltert, in Zeile und Fenster gleich. (Fokus & Ausgaben · S · Wirkung 3)
3. **R33 Power-Hours über „+“ mit „Zuletzt“** – Ein Eintrag braucht 5–6 Schritte, und die Bereichsleiste schneidet HAEB und „Sonstige“ ab. Künftig stehen oben die letzten drei Kombinationen zum Antippen, alle Geschäftsbereiche sind sichtbar, und Return sichert. (Erfassen · M · Wirkung 4)
4. **R34 Offenes und Zähler direkt auf Seite 1 der Watch** – Für eine TEREA muss Bini bis zu 15-mal wischen. Künftig listet Seite 1 die Kategorien mit Offenem zum Springen und die einfachen Zähler mit ±. (Watch · M · Wirkung 4)
5. **R35 Punkte am Mac per Tastatur bewerten** – Heute geht das nur mit der Maus, Knopf für Knopf. Künftig setzen 1/2/3/4 die Markierung, die Auswahl springt zum nächsten offenen Punkt, und ⌥⌘↓ wechselt die Kategorie. Die Knöpfe mit Wörtern bleiben. (Mac & iPad · M · Wirkung 4)
6. **R36 Beantwortete Zeilen ruhiger** – Auch nach „Erledigt“ bleiben drei bunte Knöpfe stehen, sodass Offenes kaum auffällt. Künftig werden die nicht gewählten Knöpfe grau, offene Zeilen bleiben bunt. (Heute · S · Wirkung 3)
7. **R37 Ein Eingabeweg für Power-Hours auf den Arbeits-Kategorien** – Heute PH erscheint doppelt, es gibt zwei verschiedene Knöpfe dafür, und jeden Tag steht mehrzeiliger Erklärtext da. Künftig zeigt die Karte den Stand nur zum Lesen, die Eingabezeile steht direkt darunter, und die Erklärung kommt auf Tipp. (Heute · S · Wirkung 3)
8. **R38 Mehr Punkte auf dem iPhone-Bildschirm „Heute“** – Kopfzeile und eine hohe Kategorie-Karte lassen nur drei Punkte sichtbar. Künftig wandern Datum und Tagestyp in die Titelzeile, und die Karte wird flacher, bei gleichem Inhalt. (Heute · M · Wirkung 3)
9. **R39 Tag abschließen: Wertung zeigen, Abschluss oben** – Der Knopf steht ganz unten, die Wertung erscheint danach oben außer Sicht. Künftig scrollt das Fenster zur Wertung, „Abschließen“ steht oben rechts, und am Mac schließt ein zweites ⌘↩ ab. (Abschluss & Rückblick · S · Wirkung 3)
10. **R40 Sonntags direkt zum Wochenabschluss** – Nach dem Tagesabschluss muss Bini erst die Woche suchen. Künftig führt „Weiter: Woche abschließen“ dorthin, dazu kommen ⇧⌘↩ und eine Erinnerung, die direkt den Abschluss öffnet. (Abschluss & Rückblick · S · Wirkung 3)
11. **R41 PH- und Notiz-Fenster zeigen den Tag** – „+“ bucht auf den zuletzt gewählten Tag, ohne ihn zu nennen. Künftig gibt es eine Zeile „Tag: Heute · Gestern · Datum“ mit einem Hinweis, sobald es nicht heute ist. (Erfassen · S · Wirkung 3)
12. **R42 Wochentag antippen öffnet den Tag** – Auf dem iPhone öffnet der Tipp den Tagestyp-Editor, und Lücken sieht man nicht. Künftig öffnet der Tipp überall den Tag, offene vergangene Tage zeigen „5 offen“, und langes Drücken bietet Abschließen und Tagestyp. (Woche · S · Wirkung 3)
13. **R43 Markierungen überall gleich benennen** – Je nach Ort heißen sie „Nicht“, „Fällig, nicht erledigt“, „N/A“ oder sind nur Icons. Künftig gilt ein Wortschatz (Erledigt · Teilweise · Nicht erledigt · Entfällt), und das Punkt-Fenster hat dieselben Knöpfe wie Heute. (Konsistenz · S · Wirkung 3)
14. **R44 Bessere Lesbarkeit hell und dunkel** – „Erledigt“ und „Teilweise“ haben im Hellmodus etwa Kontrast 2:1, und weiße Schrift auf hellem Türkis im Dunkelmodus ist kaum lesbar. Künftig sind die Schriftfarben im Hellmodus dunkler und die Füllung im Dunkelmodus dunkler. Die Zielfarben bleiben. (Barrierefreiheit · S · Wirkung 3)
15. **R45 Ausgaben: Ziel mit Restbetrag, Diagramm mit Ziellinie** – „< 50 € Ziel“ wirkt wie ein Wochenbudget, und ein leeres Diagramm sieht kaputt aus. Künftig steht dort „Tagesziel · noch 38 €“ beziehungsweise „+12 €“, das Diagramm bekommt eine Achse und eine Ziellinie. (Fokus & Ausgaben · S · Wirkung 3)
16. **R46 Ausgaben bearbeiten** – Bei einem Tippfehler bleibt nur Löschen und neu Eingeben. Künftig füllt ein Tipp auf die Ausgabe die Eingabe vor, „Sichern“ ändert sie, und „Rückgängig“ gibt es auch. (Fokus & Ausgaben · S · Wirkung 3)
17. **R47 Fokus mit Soll-Strich und „im Plan / hinter dem Plan“** – Ob ein Bereich zurückliegt, muss Bini im Kopf rechnen. Künftig zeigt Fokus das Tempo wie überall sonst, ein Tipp auf den Bereich öffnet die Erfassung, und das Soll zählt nur Arbeitstage. (Fokus & Ausgaben · S · Wirkung 3)
18. **R48 Watch: nach „Sichern“ zurück zu Heute** – Nach dem Sichern muss Bini zweimal zurückwischen und bekommt keine Bestätigung. Künftig geht es zurück zur ersten Seite mit „+1 PH · stammloop“ und Vibration, und Menge und „Wofür“ stehen auf einem Bildschirm. (Watch · S · Wirkung 3)
19. **R49 Import über eine laufende Woche: Ersetzen sichtbar machen** – „1 geändert“ ersetzt in Wahrheit die ganze Woche samt Markierungen. Künftig steht dort deutlich „KW47 wird ersetzt – 23 Markierungen gehen ins Archiv“, mit Rückfrage und „Rückgängig“. (Erfassen & Import · M · Wirkung 3)

## Nächste Runde

1. **R50 „Heute im Blick“ schlanker** – Das Datum steht doppelt, die PH dreimal, und „Noch zu tun“ beginnt erst in der Mitte. Künftig gibt es einen kurzen Kopf, Wochenziele mit Tempo und „Tag abschließen“, sobald alles erfasst ist. (Fokus & Ausgaben · M · Wirkung 3)
2. **R51 Aus Übersicht und Fokus bearbeiten, ohne den Faden zu verlieren** – Ein Tipp auf eine Kachel oder einen Eintrag schließt das Fenster, aus dem Bini kam. Künftig öffnet sich der Inhalt darin, mit einem Zurück-Pfeil. (Fokus & Ausgaben · M · Wirkung 3)
3. **R52 Fokus: Namen in der Legende, gleiche Farben, Nettozeit lesbar** – Die Legende zeigt „3.2 · 3.3“, die Einträge sind alle türkis, die Nettozeit steht als „3,33 h“. Künftig stehen dort Bereichsnamen, Bereichsfarben und „3 h 20 min“. (Fokus & Ausgaben · S · Wirkung 2)
4. **R53 Fokus-Einträge nach Tag und Thema** – Eine flache Liste mit über 20 Einträgen, und das „Ergebnis“ ist auf dem iPhone unsichtbar. Künftig gibt es Tagesabschnitte mit Summe, PH je Thema und das Ergebnis als zweite Zeile. (Fokus & Ausgaben · M · Wirkung 3)
5. **R54 Ausgaben für die ganze Woche, nach Zweck** – Heute ist nur ein Tag zu sehen, und gestern lässt sich nicht nachtragen. Künftig gibt es eine Wochenliste, die Summen nach Zweck, und ein Tipp auf einen Balken wählt den Tag. (Fokus & Ausgaben · M · Wirkung 3)
6. **R55 iPhone-Woche: Kopf verdichten** – „Woche“ steht viermal da, und die erste Zelle liegt einen Bildschirm tief. Künftig sitzen KW und Pfeile in der Titelzeile, der Kontext ist einzeilig, und die Wochenziele lassen sich einklappen. (Woche · M · Wirkung 3)
7. **R56 Planen: Warnung bei offener Woche, CSV-Einfügen als Schritt 2** – Ein Prompt aus der offenen Woche verschweigt verfehlte Ziele, und „Planen“ trifft nicht immer die angezeigte Woche. Künftig gibt es eine Warnung, die Schritte „1 · Prompt“ und „2 · CSV einfügen“, und „KW48 planen“ plant genau KW48. (Abschluss & Rückblick · M · Wirkung 3)
8. **R57 Wochenbericht lesbar statt Rohtext** – Heute erscheinen „#“, „**“ und Tabellenstriche in Schreibmaschinenschrift. Künftig gibt es eine gestaltete Wochenübersicht, und der Text für ChatGPT ist eingeklappt. (Abschluss & Rückblick · M · Wirkung 3)
9. **R58 Journal nur einmal abfragen** – Punkt und Schalter fragen dasselbe, und das PDF zeigt „–“ trotz ✓. Künftig ist der Plan-Punkt die einzige Quelle. (Abschluss & Rückblick · M · Wirkung 3)
10. **R59 Mac: „Heute im Blick“ als Seitenspalte** – ⌘0, der Ring und „HEUTE“ öffnen heute ein blockierendes Fenster. Künftig blenden sie die vorhandene Seitenspalte ein, und die Zeilen links zeigen beim Darüberfahren, dass sie klickbar sind. (Mac & iPad · S · Wirkung 3)
11. **R60 Mac: Kategorienspalte verstellbar** – Namen wie „Ernährung und Gew…“ sind bei jeder Fenstergröße abgeschnitten. Künftig lässt sich die Spalte ziehen, der volle Name steht im Tooltip, und der Kopf wird nicht mehr doppelt angezeigt. (Mac & iPad · M · Wirkung 3)
12. **R61 Mac/iPad breit: Knöpfe neben dem Titel** – Nur fünf Punkte passen ins Fenster. Künftig stehen die Knöpfe ab genügend Breite rechts als feste Spalte, wie auf dem Papier. (Mac & iPad · M · Wirkung 3)
13. **R62 Mac: Symbolleiste mit Text, Kürzel abrunden** – Abschließen ist nur ein Mond, der Tooltip nennt das falsche ⌘N, und der Wochenwechsel fehlt im Menü. Künftig haben die Knöpfe Text, das Kürzel stimmt, und „Gehe zu“ enthält „Vorige/Nächste Woche“. (Mac & iPad · M · Wirkung 2)
14. **R63 Kontextmenü in der Woche: echtes „Bearbeiten“, Löschen mit Wahl** – „Bearbeiten“ öffnet nur die Details, und „Löschen“ fragt nicht nach „auch künftig?“. Künftig öffnet es direkt den Editor, Löschen bietet die Wahl, „Als Nebensache“ ist dabei, und Zellen haben einen Tooltip. (Woche · S · Wirkung 2)
15. **R64 Woche: Punktart benennen** – Automatische Punkte und Nebensachen sind nicht zu erkennen. Künftig tragen sie dieselben Kurzlabels wie Heute und das PDF, dazu „62 %“ auf dem iPhone. (Woche · S · Wirkung 2)
16. **R65 Woche: Notizen sichtbar machen** – In der Woche sieht man nicht, welcher Tag eine Notiz hat. Künftig zeigt ein kleiner Punkt in der Zelle die Notiz an, und „Notiz hinzufügen…“ gilt für genau diesen Tag. (Woche · S · Wirkung 2)
17. **R66 VoiceOver in Woche, Watch und Abschluss** – Die Woche liest siebenmal „Nicht erfasst“ ohne Tag, und ein verfehltes Ziel sieht aus wie „offen“. Künftig nennen die Zellen Tag und Punkt, und im Abschluss steht „verfehlt“ mit dem Ziel. (Barrierefreiheit · S · Wirkung 2)
18. **R67 Knöpfe wachsen mit der Systemschrift** – Bei größerer Schrift wachsen nur die Titel. Künftig wachsen Knöpfe und Chips mit, bei Standardgröße bleibt alles gleich. (Barrierefreiheit · S · Wirkung 2)
19. **R68 Ziele in Zielfarbe, Fortschritt statt „–“** – Karten zeigen „–“ neben Kategorien mit 10, und alle Balken sind türkis. Künftig steht dort „1 von 4 Kategorien bewertet“, mit Ringen und Balken in Zielfarbe. Am Mac fällt die doppelte Liste weg. (Abschluss & Rückblick · S · Wirkung 2)
20. **R69 Ziel-Detail mit Wochentagen** – Sieben Symbole stehen ohne Kopfzeile da. Künftig steht „M D M D F S S“ darüber, und heute ist hervorgehoben. (Abschluss & Rückblick · S · Wirkung 2)
21. **R70 Rückblick: Wochen, die nie abgeschlossen wurden** – Solche Wochen fehlen kommentarlos. Künftig erscheinen sie orange als „nicht abgeschlossen“ und lassen sich direkt abschließen. (Abschluss & Rückblick · S · Wirkung 2)
22. **R71 Mac: PDF sichern und drucken** – Heute geht nur „Teilen“. Künftig gibt es „Sichern…“ (⌘S) und „Drucken…“ (⌘P). (Abschluss & Rückblick · M · Wirkung 2)
23. **R72 Feier nur beim Abschließen** – Konfetti und Vibration kommen bei jedem Ansehen eines guten Tags. Künftig nur im Moment des Abschließens. (Abschluss & Rückblick · S · Wirkung 2)
24. **R73 Fenster einheitlich schließen** – „Schließen“ steht direkt neben „Tag abschließen“, an anderer Stelle heißt es „Fertig“ links oder rechts. Künftig gibt es überall das System-× und „Fertig“ nur dort, wo etwas bestätigt wird. (Konsistenz · S · Wirkung 2)
25. **R74 „Weiter ›“ statt totem „Alle …“** – Ist eine Kategorie fertig, bietet die Karte nur noch „Alle leeren“. Künftig zeigt sie „Weiter: 1.2“, und unten heißt es „Weiter: Abschluss & Notizen“. (Heute · S · Wirkung 2)
26. **R75 Ein Name pro Aktion** – „anlegen/hinzufügen“, „eintragen/erfassen“ und „Erstellen/Erfassen“ wechseln sich ab. Künftig gilt je ein Name, und die Kürzel-Hinweise erscheinen nur am Mac/iPad, dafür vollständig. (Konsistenz · S · Wirkung 2)
27. **R76 Hilfe und Tour an die heutige Bedienung anpassen** – Die Hilfe beschreibt Wischen zum Markieren und „+ = 1 PH“, die Tour „Ausgaben nur mit Betrag“. Künftig sind die Texte korrigiert, die Tour hat 13 statt 16 Karten und nennt Watch und Siri konkret. (Konsistenz · S · Wirkung 2)
28. **R77 Messwert anlegen: Ziel per Auswahl** – Eine bloße „6“ wird still zu „mindestens 6“, und die Einheit „PH“ erzeugt Power-Hours ohne Beschreibung. Künftig wählt Bini „mindestens/höchstens/unter …“ und sieht dazu einen Satz wie „Erfüllt bei ≤ 6“. „PH“ fällt als Einheit weg. (Erfassen & Import · M · Wirkung 2)
29. **R78 Notiz-Art und Tagestyp als Chips** – Beides steckt heute in Menüs, und nichts sagt, ob der Tag arbeitsfrei wird. Künftig gibt es Chips und den Hinweis „Arbeitsfreier Tag: Arbeitspunkte zählen nicht“. (Erfassen & Import · S · Wirkung 2)
30. **R79 Sync-Anzeige auf Deutsch** – Heute steht dort „On · synced“, „Signed in“, und Fehler erscheinen auf Englisch. Künftig sind alle Texte deutsch. (Konsistenz · M · Wirkung 2)
31. **R80 Erinnerungen abrunden** – Die Abend-Erinnerung kommt auch nach dem Abschluss, die Erlaubnis wird mitten in der Tour abgefragt, und am Mac kommt alles doppelt. Künftig verschwindet die Erinnerung beim Abschließen, es gibt „In 30 Min.“, die Erlaubnis wird nach der Tour abgefragt, und am Mac ist die Erinnerung standardmäßig aus. (Mitteilungen · M · Wirkung 3)
32. **R81 Watch: Werte mit der Digital Crown** – Das Gewicht startet bei 0 in 0,1-Schritten. Künftig öffnet ein Tipp einen Krone-Editor, der beim letzten Wert beginnt. Health-Werte bekommen keine ±-Knöpfe. (Watch · M · Wirkung 3)
33. **R82 Watch: aktuelle Markierung sichtbar, Vibration** – Bini sieht nicht, was gesetzt ist, und spürt nicht, ob der Tipp angekommen ist. Künftig ist die gewählte Markierung hervorgehoben, und die Uhr vibriert beim Setzen. (Watch · S · Wirkung 2)
34. **R83 Heute-Widget: PH-Balken beschriften** – Der Balken unter „heute“ zeigt ohne Erklärung den Wochenstand. Künftig steht daneben „14/28 Woche“. (Widgets · S · Wirkung 2)
35. **R84 Auf Dauer schnell bleiben** – Jeder Tipp rechnet die Woche zusätzlich fürs Widget neu, auch am Mac und auf der Watch, und ohne Indizes werden Abfragen mit den Jahren langsamer. Künftig gibt es Indizes, und der Widget-Stand wird nur auf dem iPhone gebündelt geschrieben. (Daten & Sync · S · Wirkung 2)

## Größere Ideen

1. **R85 Tageswerte als Zeile in der Woche** – Gewicht, Bettzeit oder Seiten von Mo bis So nebeneinander sieht Bini heute nirgends. Künftig gibt es eine Wertezeile je Kategorie, in der ein Tipp auf einen Tag direkt den Wert für diesen Tag öffnet. (Woche · M · Wirkung 3)
2. **R86 Komplikation für die Watch / Smart Stack** – Auf dem Zifferblatt ist von Thalia nichts zu sehen. Künftig zeigt eine Komplikation Ring, Offenes und PH, und ein Tipp öffnet die App. (Watch · M · Wirkung 3)
3. **R87 Offene Punkte im Widget direkt abhaken** – Der Kreis im Widget sieht aus wie ein Kästchen, öffnet aber nur die App. Künftig setzt ein Tipp auf die Zeile ✓. (Widgets · M · Wirkung 3)
4. **R88 Fokus: Wochen blättern und Verlauf über 8 Wochen** – Ob die PH steigen oder fallen, sieht Bini nirgends. Künftig lässt sich Fokus wochenweise blättern, und ein Verlauf zeigt „Ziel erreicht in 3 von 8 Wochen“, eine Zahl, die auch für die Sonntagsplanung hilft. (Fokus & Ausgaben · M · Wirkung 3)
5. **R89 Siri und Kurzbefehle ausbauen** – Per Stimme landen Power-Hours immer bei stammloop, und Ausgaben öffnen nur die App. Künftig fragt Siri nach dem Bereich, es gibt einen Kurzbefehl für Ausgaben mit „Wofür“, „Stand des Tages“ nennt das Offene, und die App weist auf Siri hin. (Kurzbefehle · M · Wirkung 3)

## Ergänzungen aus der Vollständigkeitsprüfung

1. **R90 Die „Besonderheit“ des Tages aus dem Plan ist nirgends zu sehen** – ChatGPT schreibt für jeden Tag eine Besonderheit („Arbeit endet um 15:00 – Familienblock“). In der App steht sie nur im Tagestyp-Editor und im Text-Bericht. Künftig steht sie auf Heute unter dem Tagestyp, in „Heute im Blick“, in der Mac-Seitenleiste, im Widget, und Tage mit Besonderheit bekommen in der Woche einen Punkt. (Vorschlag: Sofort · Heute (Morgen) · S · Wirkung 4)
2. **R91 Der Planungs-Prompt enthält den aktuellen Plan nicht** – ChatGPT muss jeden Sonntag rund 40 Punkte neu erfinden, obwohl „dieselbe Woche wiederholen“ der empfohlene Normalfall ist. Titel, ids, Tage und Nebensache-Markierungen verschieben sich, und die ganze Vorschau muss geprüft werden. Künftig hängt der Prompt den Plan der letzten Woche als CSV an („übernimm diese Zeilen, ändere nur, was ich verlange, und nenne jede Änderung“), optional mit einer kurzen Tendenz der letzten 4 Wochen. (Vorschlag: Sofort · Sonntag: Planen · S · Wirkung 4)
3. **R92 „Plan von KW46 wiederholen“ ohne ChatGPT-Runde** – Fällt die Sonntagsplanung aus (Reise, krank), bleibt der Montag leer: Heute, Watch, Widgets, Fokus und Wochenziele zeigen nichts. Künftig bietet „Noch kein Plan“ und das Vorlagen-Menü im Import „Wie KW46 wiederholen“. Das läuft durch die normale Vorschau samt Archiv. (Vorschlag: Nächste Runde · Planen · M · Wirkung 4)
4. **R93 Verlauf je Ziel und je Messwert über Monate** – Jeder Langzeitblick endet nach 12 bis 16 Wochen, das Messwert-Fenster nach 14 Tagen. Ob Gewicht, Bettzeit oder Seiten über Monate besser werden, sieht man nirgends. Künftig zeigt das Ziel-Detail einen Verlauf (12 Wochen · Halbjahr · Zieljahr) mit Wochenwertung, Messwerten samt Ziellinie und für Ausgaben Monatsbalken. Solange die laufende Woche „–“ zeigt, steht auf der Ziel-Karte „Ø 4 Wo.“. (Vorschlag: Nächste Runde · Ziele & Rückblick · M · Wirkung 4)
5. **R94 Morgens: „Gestern ist noch offen“** – Wird die Erinnerung um 21:45 verpasst, bleibt der Tag ohne Wertung, und das fällt erst sonntags auf. Künftig steht morgens auf Heute (und in „Heute im Blick“ und der Mac-Seitenleiste) ein kurzes Banner „So, 15. Nov. · 3 offen“ mit „Nachtragen“ und „Abschließen“. Es verschwindet nach dem Abschluss oder per ×. (Vorschlag: Sofort · Heute (Morgen) · S · Wirkung 3)
6. **R95 Zielüberprüfung KW49 vorbereiten, geparkte Ideen sammeln** – Die App zählt bis zur Zielüberprüfung herunter (KW49, also in zwei Wochen), bietet dafür aber nichts an. Ideen werden „bis zur Zielüberprüfung“ geparkt, sind danach aber nur am eigenen Tag sichtbar. Künftig gibt es ab drei Wochen vorher „Zielüberprüfung vorbereiten“: je Ziel Ø seit Start und Trend, die häufigsten verpassten Punkte, PH je Bereich, Messwerte zu Beginn und jetzt, alle geparkten Ideen und einen Bericht für ChatGPT. Der Rückblick bekommt dauerhaft „Geparkte Ideen“. (Vorschlag: Nächste Runde · Ziele & Rückblick · M · Wirkung 3)
7. **R96 Mac: Thalia in der Menüleiste** – Am Mac gibt es weder Widget noch Kontrollzentrum-Knopf, und die graue Übersicht lebt nur im Hauptfenster. Künftig zeigt ein Menüleisten-Eintrag „73 %“, die Statuszeile, ein kompaktes PH-Formular mit den letzten Kombinationen, eine Ausgaben-Zeile, „Thalia öffnen“ und „Tag abschließen…“. Abschaltbar in den Einstellungen. (Vorschlag: Größere Ideen · Mac · M · Wirkung 3)
8. **R97 Ausgaben automatisch aus Apple Pay** – Die meisten Zahlungen laufen per Karte. Künftig gibt es einen Kurzbefehl „Ausgabe in Thalia“ mit Betrag und Wofür, der ohne App-Öffnen bucht. Mit der Kurzbefehle-Automation „Transaktion“ (Betrag = Betrag, Wofür = Händler) landet jede Kartenzahlung von selbst in Thalia; von Hand bleiben nur Barzahlungen. Eine Zeile in den Einstellungen erklärt die Einrichtung. Das ist die automatisierbare Form von R89. (Vorschlag: Nächste Runde · Fokus & Ausgaben / Kurzbefehle · S · Wirkung 3)

## Hinweise zur Umsetzung

- **Ein Konzept „Welcher Tag ist gemeint?“ statt sechs Einzel-Fixes.** R1, R4, R7, R18, R22 und R41 behandeln dasselbe Problem. Gemeinsam umgesetzt: `AppModel.today` folgt dem Tageswechsel des Systems und der Rückkehr ins Fenster, das Widget bekommt einen Eintrag für Mitternacht, jedes Erfassen-Fenster zeigt seinen Zieltag, und die 4-Uhr-Regel aus R18 gilt nur für „Tag abschließen“. Sonst widersprechen sich die Fixes.
- **R16 und R50** definieren beide die Kachel „Wochenziele“ in „Heute im Blick“ neu und sollten zusammen gebaut werden.
- **R38 und R50** machen Kopf und Hero flacher. Dabei muss Platz für die Besonderheit des Tages (R90) und den Hinweis „arbeitsfrei“ (R78) bleiben.
- **R84** (Indizes) bringt bei rund 25 000 Zeilen im Jahr wenig. Der Teil zum Widget-Stand gehört zu R4.
- **R87** (im Widget abhaken) ist eher L als M: Widgets lesen nur einen Schnappschuss und haben keinen Zugriff auf die Daten. Bis die App öffnet, sähen Mac und Watch das ✓ nicht.
- **R30**: Am Mac ist ein einzelnes Fenster richtig. Auf dem iPad ist die eigentliche Ursache das app-weite Fenster-Routing, niedrige Priorität passt.
- **Health-Werte (braucht eine Entscheidung):** Aus Health übernommene Werte bleiben auf dem iPhone und dürfen nicht über iCloud synchronisiert werden (App-Review-Richtlinie 5.1.3). Mac und Watch sehen Gewicht, Schlaf und Bettzeit vom iPhone daher nicht, zeigen weniger „% erfasst“, und der Tagesabschluss am Mac listet sie als fehlend. Siehe offene Frage unten.

## Verworfen (nach Gegenprüfung)

- **„Noch zu tun“ in der Übersicht direkt abhaken** – Der Tagesabschluss listet jeden offenen Punkt mit Markier-Knöpfen, und Heute öffnet auf der ersten Kategorie mit Offenem. Ein dritter, versteckter Weg zum Markieren würde mehr verwirren als helfen.
- **CSV-Datei ins Import-Fenster ziehen (Mac/iPad)** – Der Weg ist „Kopieren in ChatGPT → Einfügen“, Dateien gehen schon über „Datei…“, das Dock-Symbol und „Öffnen mit“.
- **Plan-Daten zwischenspeichern für Tempo** – Real sind es 63 Punkte, die Woche wird nur sichtbar gebaut, und es gibt keinen Hinweis auf spürbare Langsamkeit. Erst nötig, wenn Messungen Ruckler zeigen.

## Empfohlene Reihenfolge

**Runde v7 „Stimmt immer“** – Datenverlust, falsche Tage und widersprüchliche Zahlen zuerst, dazu die größten Alltags-Bremsen:

1. Tageskonzept: **R1, R4, R7, R18, R22, R41** (siehe Hinweise)
2. **R2** Watch-Ausgaben und endgültiges Löschen
3. **R3** Messwert-Fenster und Kurzbefehl nach den PH- und Ausgaben-Regeln
4. **R5** eine Bedeutung für „offen“
5. **R6** Seiten springen nicht mehr von allein
6. **R17** € centgenau
7. **R31** Fertig-Taste über dem Ziffernblock
8. **R32** „Wofür“-Vorschläge über die Woche hinaus
9. **R90** Besonderheit des Tages sichtbar
10. **R91** aktueller Plan im Planungs-Prompt

**Runde v8:** übrige Bugs R8–R30 (alle S/M), R33 („Zuletzt“ bei PH), R35 (Mac-Tastatur), R94 (Gestern offen), R95 (Zielüberprüfung, zeitlich vor KW49 sinnvoll).

**Danach:** restliche „Sofort“-Punkte, dann „Nächste Runde“ nach Wirkung.

## Offene Fragen

1. **Umfang der nächsten Runde.** A: Runde v7 wie oben empfohlen (10 Punkte, Tage und Zahlen stimmen, schnellere Eingabe). B: zuerst alle 30 Bugs (R1–R30), Komfort danach.
2. **Health-Werte auf Mac und Watch.** A: Messwerte, die aus Health kommen, zählen auf Geräten ohne Health nicht als fehlend, mit dem Hinweis „Wert aus Health auf dem iPhone“. B: so lassen wie jetzt.

## Anhang: Technische Notizen je Punkt

Für die Umsetzung: was sich ändert und welche Dateien betroffen sind.

- **R1** (Bugs) – Die App reagiert auf den Tageswechsel des Systems und auf die Rückkehr ins Fenster und springt automatisch auf den neuen Tag. Ein bewusst gewählter älterer Tag bleibt stehen. 
  Dateien: `App/Sources/RootView.swift, App/Sources/AppModel.swift`
- **R2** (Bugs) – Ausgaben bekommen auf der Watch keine ±-Knöpfe mehr. Ein Wert wird im bestehenden Eintrag geändert statt gelöscht und neu angelegt. Ersetzte Einträge gehen in den Papierkorb, und „Rückgängig“ stellt sie exakt wieder her (mit Notiz und Schätzung). „Wert leeren“ gibt es bei Ausgaben nicht mehr. 
  Dateien: `Shared/TrackerStore.swift, App/Sources/AppModel.swift, Watch/Sources/WatchHomeView.swift, App/Sources/TodayView.swift`
- **R3** (Bugs) – Bei PH-Messwerten zeigt das Fenster die Einträge mit Beschreibung und einen Knopf „Power-Hours erfassen“, bei Ausgaben die Zeile Betrag + „Wofür“. Schnellknöpfe gibt es nur noch, wo Werte addiert werden. Die Startuhrzeit ist wie auf der Kachel, leere Texte werden nicht gespeichert. Der Kurzbefehl lehnt PH, Ausgaben und Uhrzeiten freundlich ab und fragt nach dem Messwert, statt „Wasser“ vorzugeben. 
  Dateien: `App/Sources/Editors.swift, App/Sources/Intents.swift, Shared/WeekContext.swift, App/Sources/TodayView.swift`
- **R4** (Bugs) – Die App schreibt den Stand auch für morgen vor, und das Widget wechselt um Mitternacht selbst auf einen neutralen Zustand „Neuer Tag“. Beim Öffnen und Verlassen der App sowie nach dem iCloud-Abgleich wird der Stand neu veröffentlicht. 
  Dateien: `Shared/TrackerStore.swift, Shared/WidgetBridge.swift, Widgets/Sources/ThaliaWidgets.swift, App/Sources/RootView.swift, App/Sources/AppModel.swift, Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift`
- **R5** (Bugs) – „offen“ zählt überall nur die Pflichtpunkte, wie der Ring und wie im v5-Plan („73 % · 11 offen“). n×/Woche-Punkte stehen in „Heute im Blick“ als eigener Abschnitt „Diese Woche noch“. Ohne Plan zeigt die Leiste „Kein Plan – Wochenplan importieren“, sonst „Alles erfasst“ bzw. die Wertung. 
  Dateien: `Shared/WeekContext.swift, App/Sources/Glance.swift, App/Sources/RootView.swift, Widgets/Sources/ThaliaWidgets.swift, Watch/Sources/WatchHomeView.swift`
- **R6** (Bugs) – Die Startseite wird einmal pro Tag gewählt und bleibt dann. Weiter geht es nur über „Weiter: …“, Wischen oder einen Chip. Ein fertig ausgefüllter Tag öffnet auf „Abschluss“, und verschwindet eine Seite durch einen Wechsel des Tagestyps, wird sauber neu gewählt. 
  Dateien: `App/Sources/TodayView.swift`
- **R7** (Bugs) – Die Leiste folgt dem gewählten Tag („So · 80 %“) und bekommt bei einem anderen Tag einen Knopf „Zu heute“. Ein erneutes Tippen auf den Heute-Tab führt ebenfalls zurück zu heute. 
  Dateien: `App/Sources/RootView.swift, App/Sources/TodayView.swift`
- **R8** (Bugs) – iPhone und Mac zeigen dasselbe: vor dem Abschluss „% erfasst“, danach die Wertung mit Siegel, für kommende Tage „–“. VoiceOver liest den Wert mit vor. 
  Dateien: `App/Sources/WeekView.swift, App/Sources/WeekTable.swift, Shared/WeekContext.swift`
- **R9** (Bugs) – Solche Zellen werden gedämpft und sind nicht antippbar. Bei automatischen Punkten öffnet ein Tipp das Eintragen des Werts, bei PH mit vorgewähltem Bereich. Das Punkt-Fenster nutzt dieselben Regeln, und das Haltemenü bietet dort kein wirkungsloses „Leeren“ mehr an. 
  Dateien: `App/Sources/Components.swift, App/Sources/WeekView.swift, App/Sources/WeekTable.swift, App/Sources/Editors.swift, App/Sources/TodayView.swift`
- **R10** (Bugs) – Kopf, Kategorie- und Punktzeilen teilen sich ein gemeinsames Spaltenraster mit kleinerer Mindestbreite für Titel. Am Mac lässt sich das Fenster nicht schmaler ziehen, als die Tabelle braucht. 
  Dateien: `App/Sources/WeekTable.swift, App/Sources/Components.swift`
- **R11** (Bugs) – Ändert sich etwas in einer abgeschlossenen Woche, wird ihre gespeicherte Wertung zentral beim Speichern neu berechnet. Ältere Wochen bleiben sonst eingefroren. Beim Archivieren wird die Wertung zurückgesetzt, und der Ziele-Verlauf zählt keine Duplikate mehr. 
  Dateien: `Shared/TrackerStore.swift, Shared/TrackerStore+Import.swift, App/Sources/GoalsView.swift`
- **R12** (Bugs) – Der Knopf füllt nur leere Punkte. Abweichungen bei schon markierten Punkten stehen eingeklappt unter „Messwert weicht ab“ und lassen sich einzeln übernehmen. Dazu kommen „Rückgängig“ und die richtige Einzahl („1 Vorschlag“). 
  Dateien: `App/Sources/CloseDayView.swift, App/Sources/AppModel.swift, Shared/TrackerStore.swift`
- **R13** (Bugs) – Hinweise erscheinen im jeweils obersten Fenster. Das Punkt-Fenster schließt sich nach „Punkt löschen“. Neue PH aus dem PH-Fenster bekommen denselben Hinweis mit „Rückgängig“ wie in der Zeile. 
  Dateien: `App/Sources/RootView.swift, Vendor/BinisoftKit/Sources/BinisoftKit/Toasts.swift, App/Sources/Editors.swift, App/Sources/CloseDayView.swift, App/Sources/AppModel.swift`
- **R14** (Bugs) – Solange ein Fenster mit ungespeicherter Eingabe offen ist, sind die Menübefehle, die ein anderes Fenster öffnen, ausgegraut. „Zuletzt gelöscht“ und die Erklärungen zielen wie alle anderen Befehle auf das richtige Fenster. 
  Dateien: `App/Sources/ThaliaApp.swift, App/Sources/AppModel.swift`
- **R15** (Bugs) – Fenster öffnen in einer Höhe, die ins Hauptfenster passt, und scrollen. Das Hauptfenster bekommt eine Mindestgröße. 
  Dateien: `Vendor/BinisoftKit/Sources/BinisoftKit/Platform.swift, App/Sources/RootView.swift`
- **R16** (Bugs) – Die Kachel heißt „Wochenziele“ und öffnet eine eigene Liste aller Wochenziele mit Tempo. Es ist dieselbe Liste wie in der Woche, die dafür zusammengeführt wird. Die Zählung folgt der Regel von PDF und Bericht, und die Mac-Seitenleiste sagt „Ziele bewertet“. 
  Dateien: `App/Sources/Glance.swift, App/Sources/WeekView.swift, App/Sources/WeekTable.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift, Shared/WeekContext.swift`
- **R17** (Bugs) – Euro-Beträge erscheinen überall centgenau („12,99 €“, „2,50 €“, glatt „13 €“). Die Änderung sitzt an einer zentralen Stelle und ist mit Tests abgesichert. 
  Dateien: `Packages/ThaliaCore/Sources/ThaliaCore/Format.swift, Packages/ThaliaCore/Tests/ThaliaCoreTests/CalendarTests.swift, App/Sources/Glance.swift`
- **R18** (Bugs) – Bis 4 Uhr gilt „Tag abschließen“ (Mitteilung, Siri, Link) für den noch offenen Vortag. Die Mitteilung merkt sich ihren Tag. 
  Dateien: `Packages/ThaliaCore/Sources/ThaliaCore/Calendar.swift, App/Sources/Services.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift`
- **R19** (Bugs) – Beides fragt „Endgültig löschen?“, und ein Vollwischen löscht nicht mehr. Die Zeilen sind lesbar, etwa „Mo, 16. Nov. · stammloop · 2 PH“ oder „Ausgaben: 12,50 € · Mittagessen“, und das Neueste steht oben. 
  Dateien: `App/Sources/SettingsView.swift, Shared/TrackerStore.swift`
- **R20** (Bugs) – Die Vorschau aktualisiert sich beim Tippen, und importiert wird nur mit aktueller Vorschau. Ein Wochenwechsel setzt „kopiert“ zurück. Optional kommt ein Knopf „ChatGPT öffnen“ dazu. 
  Dateien: `App/Sources/ImportView.swift, App/Sources/CloseWeekView.swift`
- **R21** (Bugs) – Ein leeres Feld stellt den alten Text wieder her. Die Zeile übernimmt Änderungen aus Fenster, Fokus und Mac, und der Speicher lehnt leere Beschreibungen grundsätzlich ab. 
  Dateien: `App/Sources/TodayView.swift, Shared/TrackerStore.swift`
- **R22** (Bugs) – Fokus bekommt den gewählten Tag mit und zeigt ihn an („So, 15. Nov.“ statt „Heute“). „+“ bucht auf diesen Tag, und das PH-Fenster zeigt das Datum. 
  Dateien: `App/Sources/Glance.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift, App/Sources/TodayView.swift, App/Sources/Editors.swift`
- **R23** (Bugs) – Eine Notiz ändert nie die Markierung. Es wird nur die Notiz gespeichert. 
  Dateien: `App/Sources/Editors.swift, Shared/TrackerStore.swift`
- **R24** (Bugs) – Import und Papierkorb öffnen innerhalb der Einstellungen. Am Mac holt die Tour zuerst das Hauptfenster nach vorn. 
  Dateien: `App/Sources/SettingsView.swift, App/Sources/ImportView.swift, App/Sources/ThaliaApp.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift`
- **R25** (Bugs) – Das Ausschalten einer Situation wirkt erst bei „Fertig“. Der linke Knopf heißt „Später“. 
  Dateien: `App/Sources/TodayView.swift`
- **R26** (Bugs) – Die Spalte zeigt Wochentag und Datum. Der Rückblick bekommt eine eigene Seite mit allen Antworten und Tagesnotizen, und die Tagesnotiz und die Besonderheit kommen aufs Deckblatt des Tages. 
  Dateien: `App/Sources/PDFExport.swift, Packages/ThaliaCore/Sources/ThaliaCore/Vocabulary.swift`
- **R27** (Bugs) – Die Sicherung speichert Tages- und Wochenabschlüsse sowie jede Ausgabe einzeln mit Uhrzeit. Bei Duplikaten nimmt sie immer die neueste Fassung. Ein Rundlauf-Test sichert das ab. 
  Dateien: `Shared/TrackerStore+Import.swift, Packages/ThaliaCore/Sources/ThaliaCore/PlanCSV.swift, Packages/ThaliaCore/Sources/ThaliaCore/ImportPreview.swift, Packages/ThaliaCore/Sources/ThaliaCore/Records.swift`
- **R28** (Bugs) – Nach dem Abgleich werden Duplikate zusammengeführt. Tagestyp und Notiz kommen aus der neuesten ausgefüllten Fassung, „abgeschlossen“ gewinnt. Die Regel wird in den Tests abgesichert. 
  Dateien: `Shared/TrackerStore.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift, Packages/ThaliaCore`
- **R29** (Bugs) – Die Uhrzeit wird aus Datum und Stunde gebildet, statt Sekunden ab Mitternacht zu addieren. Ein Test für Europe/Vienna sichert das ab. 
  Dateien: `App/Sources/TodayView.swift, Packages/ThaliaCore/Sources/ThaliaCore/Calendar.swift`
- **R30** (Bugs) – Thalia wird bewusst eine App mit einem einzigen Fenster: am Mac ein Fenster, auf dem iPad keine Mehrfach-Szenen. 
  Dateien: `App/Sources/ThaliaApp.swift, Config/iOS/Info.plist, App/Sources/AppModel.swift`
- **R31** (Sofort) – Über dem Ziffernblock steht eine Leiste mit „Fertig“, die sofort speichert und den Ring aktualisiert. Bei Beträgen steht dort „Weiter“ zu „Wofür?“. Das gilt in Heute, Abschluss, Ausgaben und im Messwert-Fenster. Ein „+Schritt“ während des Tippens geht nicht mehr verloren. 
  Dateien: `App/Sources/AppPlatform.swift, App/Sources/TodayView.swift, App/Sources/CloseDayView.swift, App/Sources/Glance.swift, App/Sources/Editors.swift`
- **R32** (Sofort) – Vorschläge kommen aus den letzten rund 90 Tagen, nach Häufigkeit sortiert und beim Tippen gefiltert. In Zeile und Ausgaben-Fenster gibt es dieselbe kleine Ansicht. Optional sichert „4,50“ plus ein Tipp auf „Bäcker“ sofort. Dabei werden auch die Abfragen pro Tastendruck für die PH-Vorschläge entfernt. 
  Dateien: `Shared/TrackerStore.swift, Shared/WeekContext.swift, App/Sources/TodayView.swift, App/Sources/Glance.swift, App/Sources/Components.swift, App/Sources/Editors.swift`
- **R33** (Sofort) – Oben stehen die letzten drei Kombinationen zum Antippen („3.3 · Lena – Mathe · 2 PH“). Die Geschäftsbereiche erscheinen als umbrechende Chips, die übrigen Bereiche in einem Menü. Return bzw. „Fertig“ sichert. Der Bereich bleibt bewusst gewählt (K1). 
  Dateien: `App/Sources/Editors.swift, Shared/TrackerStore.swift`
- **R34** (Sofort) – Seite 1 listet die Kategorien mit Offenem; ein Tipp springt dorthin. Darunter stehen die einfachen Zähler (TEREA, Seiten …) mit ±. Leere Seiten verschwinden, und Nebensachen bekommen einen eigenen Abschnitt. 
  Dateien: `Watch/Sources/WatchHomeView.swift`
- **R35** (Sofort) – 1/2/3/4 setzt Erledigt, Teilweise, Nicht oder Entfällt am ausgewählten Punkt. ↑/↓ wählt aus, die Auswahl springt zum nächsten offenen Punkt, und ⌥⌘↓/↑ wechselt die Kategorie. Die Kürzel stehen im Tooltip. Die Knöpfe mit Wörtern bleiben unverändert. 
  Dateien: `App/Sources/TodayView.swift, App/Sources/ThaliaApp.swift`
- **R36** (Sofort) – Ist eine Zeile beantwortet, werden die nicht gewählten Knöpfe grau, offene Zeilen bleiben bunt. Alles bleibt antippbar. Das gilt in Heute, im Abschluss und bei den bedingten Punkten. 
  Dateien: `App/Sources/TodayView.swift`
- **R37** (Sofort) – Die Wochenziel-Karte zeigt den PH-Stand nur zum Lesen. Die Zeile „Menge · Wofür · +“ rückt direkt darunter. Legende und Erklärung werden zu einer kurzen Zeile, die Details kommen per Tipp auf das %-Etikett. 
  Dateien: `App/Sources/TodayView.swift`
- **R38** (Sofort) – Datum, KW und Tagestyp wandern als Untertitel und Menü in die Titelzeile. Die Kategorie-Karte wird einzeilig und flacher, der Inhalt bleibt wie entschieden. Der Tour-Text wird angepasst. 
  Dateien: `App/Sources/TodayView.swift, Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift`
- **R39** (Sofort) – Nach dem Abschließen scrollt das Fenster zur Wertung und zur Feier. „Abschließen“ steht oben rechts; am Mac schließt ein zweites ⌘↩ ab, danach gibt es nur noch „Fertig“. Gleiches gilt am Mac für „Woche abschließen“. Die Sparkles hüpfen wieder. 
  Dateien: `App/Sources/CloseDayView.swift, App/Sources/CloseWeekView.swift, App/Sources/Sharing.swift, App/Sources/ThaliaApp.swift`
- **R40** (Sofort) – Am Sonntag erscheint nach dem Abschließen „Weiter: Woche KW47 abschließen“. ⇧⌘↩ schließt die Woche ab, und die Wochen-Erinnerung öffnet direkt den Abschluss. 
  Dateien: `App/Sources/CloseDayView.swift, App/Sources/ThaliaApp.swift, App/Sources/AppModel.swift`
- **R41** (Sofort) – Beide Fenster bekommen eine Zeile „Tag: Heute · Gestern · Datum“ und einen orangen Hinweis, wenn es nicht heute ist. Der Titel lautet dann „Erfassen · So, 15. Nov.“. Ein falsch datierter Eintrag lässt sich verschieben. 
  Dateien: `App/Sources/Editors.swift, Shared/TrackerStore.swift`
- **R42** (Sofort) – Ein Tipp öffnet überall den Tag in Heute. Vergangene offene Tage zeigen „5 offen“ in Orange, und langes Drücken bietet „Tag abschließen…“ und „Tagestyp und Notiz…“. 
  Dateien: `App/Sources/WeekView.swift, App/Sources/WeekTable.swift`
- **R43** (Sofort) – Es gilt ein Wortschatz: Erledigt · Teilweise · Nicht erledigt · Entfällt, bei Fortschrittspunkten Gearbeitet · Nicht heute. Er gilt für Menüs, Punkt-Fenster (mit denselben Knöpfen wie Heute), Abschluss, Watch, PDF und Hilfe. VoiceOver sagt „Nicht erledigt“. 
  Dateien: `Packages/ThaliaCore/Sources/ThaliaCore/Vocabulary.swift, App/Sources/TodayView.swift, App/Sources/Components.swift, App/Sources/Editors.swift, App/Sources/CloseDayView.swift, App/Sources/SettingsView.swift, App/Sources/Explainers.swift, App/Sources/PDFExport.swift, Watch/Sources/WatchHomeView.swift`
- **R44** (Sofort) – Im Hellmodus werden die Schriftfarben der Markier-Knöpfe und Kürzel dunkler, und die Kopf-Verläufe verlieren ihre Transparenz. Im Dunkelmodus kommt ein dunkleres Türkis hinter weiße Schrift. Die Zielfarben bleiben. 
  Dateien: `App/Sources/Style.swift, App/Sources/TodayView.swift, App/Sources/Components.swift, App/Sources/RootView.swift, App/Sources/Editors.swift, App/Resources/Assets.xcassets, Vendor/BinisoftKit/Sources/BinisoftKit/Theme.swift`
- **R45** (Sofort) – Die Kachel heißt „Tagesziel < 50 €“ und zeigt „noch 38 €“ (grün) bzw. „+12 €“ (rot). Das Diagramm bekommt eine Achse, eine gestrichelte Ziellinie und den Hinweis „Noch keine Ausgaben“. 
  Dateien: `App/Sources/Glance.swift`
- **R46** (Sofort) – Ein Tipp auf eine Ausgabe oder „Bearbeiten“ im Menü füllt die Eingabe oben vor. „Sichern“ ändert die Ausgabe, mit „Rückgängig“. Das funktioniert auch von der Kategorieseite aus. 
  Dateien: `App/Sources/Glance.swift, App/Sources/TodayView.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift, Shared/TrackerStore.swift`
- **R47** (Sofort) – Die Bereichszeilen zeigen Soll-Strich und Status wie Woche und Kategorie. Ein Tipp öffnet das PH-Fenster mit vorgewähltem Bereich. Das Soll zählt nur Arbeitstage und wird überall gleich berechnet. Statt „Einträge“ steht „Soll bis heute“. 
  Dateien: `App/Sources/Glance.swift, Shared/WeekContext.swift, App/Sources/TodayView.swift, App/Sources/WeekView.swift, App/Sources/WeekTable.swift`
- **R48** (Sofort) – Nach dem Sichern geht es zurück zur ersten Seite, mit „+1 PH · stammloop“ und Erfolgs-Vibration. Menge (über die Krone, Standard 1 PH) und „Wofür“ stehen auf einem Bildschirm. 
  Dateien: `Watch/Sources/WatchHomeView.swift`
- **R49** (Sofort) – Ein oranger Hinweis sagt „KW47 wird ersetzt – 23 Markierungen und 9 Werte gehen ins Archiv“. Der Knopf heißt „KW47 ersetzen“ und fragt nach, danach gibt es „Rückgängig“. Der Hinweistext wird korrigiert. 
  Dateien: `Packages/ThaliaCore/Sources/ThaliaCore/ImportPreview.swift, App/Sources/ImportView.swift, Shared/TrackerStore+Import.swift`
- **R50** (Nächste Runde) – Der Kopf lautet „Montag · Arbeitstag“, der PH-Abschnitt fällt weg. Dazu kommen ein Abschnitt mit Wochenzielen und Tempo sowie der Knopf „Tag abschließen“, sobald alles erfasst ist. 
  Dateien: `App/Sources/TodayView.swift, App/Sources/Glance.swift, App/Sources/WeekView.swift`
- **R51** (Nächste Runde) – Fokus und Ausgaben öffnen innerhalb der Übersicht mit einem Zurück-Pfeil. Der PH-Editor öffnet über Fokus und kehrt dorthin zurück. 
  Dateien: `App/Sources/Glance.swift, App/Sources/TodayView.swift`
- **R52** (Nächste Runde) – Die Legende nennt stammloop, Nachhilfe und die anderen Bereiche. Die Eintragsplaketten tragen die Bereichsfarbe, die Nettozeit steht überall als „3 h 20 min“, und der doppelte Fußzeilentext fällt weg. 
  Dateien: `App/Sources/Glance.swift, Packages/ThaliaCore/Sources/ThaliaCore/Measures.swift, Packages/ThaliaCore/Tests/ThaliaCoreTests/ScoringTests.swift, App/Sources/Editors.swift`
- **R53** (Nächste Runde) – Es gibt Abschnitte pro Tag mit Tagessumme. Im Bereich stehen die Top-Themen („Lena – Mathe 4 · Tim 2“), das Ergebnis erscheint als zweite Zeile, und fehlt die Beschreibung, steht dort „Beschreibung fehlt“. 
  Dateien: `App/Sources/Glance.swift`
- **R54** (Nächste Runde) – Eine Liste nach Tagen für die Woche, ein Abschnitt „Nach Zweck“ mit den fünf größten Posten, und ein Tipp auf einen Balken wählt den Tag zum Nachtragen. 
  Dateien: `App/Sources/Glance.swift, Shared/WeekContext.swift`
- **R55** (Nächste Runde) – KW und Pfeile sitzen in der Titelzeile mit einem Menü der letzten Wochen. Der Wochenkontext ist einzeilig, „Woche abschließen“ steht in der Leiste, und die Wochenziele lassen sich einklappen. „Planen“ fällt weg, weil es schon im …-Menü steht. 
  Dateien: `App/Sources/WeekView.swift`
- **R56** (Nächste Runde) – Ist die Woche noch offen, warnt ein Hinweis mit Knopf „Erst Woche abschließen“. Nach dem Abschluss folgen „1 · Prompt kopieren“ und „2 · CSV einfügen“. „KW48 planen“ plant genau KW48. Der Prompt wird nur noch an einer Stelle gebaut. 
  Dateien: `App/Sources/CloseWeekView.swift, App/Sources/ImportView.swift, App/Sources/WeekView.swift, App/Sources/WeekTable.swift, App/Sources/TodayView.swift, App/Sources/AppModel.swift, Shared/TrackerStore.swift`
- **R57** (Nächste Runde) – Eine gestaltete Wochenübersicht wie im Wochenabschluss, mit der Reflexion nur zum Lesen. Der Text für ChatGPT ist eingeklappt. In der Leiste stehen nur „Text kopieren“ und ein Menü „Teilen“. 
  Dateien: `App/Sources/ReviewView.swift, App/Sources/CloseWeekView.swift`
- **R58** (Nächste Runde) – Gibt es den Plan-Punkt „Ins Journal eingetragen“, ist er die einzige Quelle für Abschluss, PDF und Bericht. Den Schalter gibt es nur, wenn der Plan keinen solchen Punkt hat. 
  Dateien: `App/Sources/CloseDayView.swift, Shared/WeekContext.swift, App/Sources/PDFExport.swift, Packages/ThaliaCore/Sources/ThaliaCore/Reports.swift, Packages/ThaliaCore/Sources/ThaliaCore/Vocabulary.swift`
- **R59** (Nächste Runde) – ⌘0, der Ring und „HEUTE“ blenden die vorhandene Seitenspalte ein, in der Bini nebenher weiterarbeiten kann. Die grauen Zeilen bekommen Hover und Tooltip. 
  Dateien: `App/Sources/TodayView.swift, App/Sources/Glance.swift, App/Sources/ThaliaApp.swift, App/Sources/AppModel.swift`
- **R60** (Nächste Runde) – Die Spalte lässt sich zwischen 220 und 400 pt ziehen, der volle Name steht im Tooltip. Datum und KW wandern ins Titelmenü, und der Kopf in der Liste wird kompakt. 
  Dateien: `App/Sources/TodayView.swift`
- **R61** (Nächste Runde) – Ab genügend Breite stehen die Knöpfe rechts als feste Spalte, wie auf dem Papier, und am Mac etwas flacher. Rund 70 % mehr Punkte sind ohne Scrollen sichtbar. 
  Dateien: `App/Sources/TodayView.swift, App/Sources/CloseDayView.swift`
- **R62** (Nächste Runde) – Die Abschluss-Knöpfe bekommen Text, der Titel zeigt das Datum, der Tooltip lautet „Erfassen (⇧⌘N)“ und das Menü „Erfassen…“. „Gehe zu“ bekommt „Vorige/Nächste Woche“, und die Tag-Befehle wirken nur in Heute. Optional wird die Leiste anpassbar. 
  Dateien: `App/Sources/TodayView.swift, App/Sources/WeekTable.swift, App/Sources/WeekView.swift, App/Sources/ThaliaApp.swift, App/Sources/AppModel.swift`
- **R63** (Nächste Runde) – „Bearbeiten…“ öffnet den Editor direkt, auch auf dem iPhone und in Heute. „Löschen“ fragt „auch künftig / nur diese Woche“. Dazu kommen ein Schalter für die Nebensache und Zellen mit Hover und Tooltip. 
  Dateien: `App/Sources/WeekTable.swift, App/Sources/WeekView.swift, App/Sources/TodayView.swift, App/Sources/AppModel.swift, App/Sources/RootView.swift, App/Sources/Components.swift`
- **R64** (Nächste Runde) – Dieselben Kurzlabels wie in Heute und im PDF („automatisch“, „Nebensache“, „3× pro Woche“), auf dem iPhone zusätzlich der Fortschritt in %. 
  Dateien: `App/Sources/WeekView.swift, App/Sources/WeekTable.swift, App/Sources/Components.swift, App/Sources/PDFExport.swift`
- **R65** (Nächste Runde) – Zellen mit Notiz bekommen einen kleinen Punkt. Das Kontextmenü bietet „Notiz hinzufügen…“ für genau diesen Tag, und „Details…“ öffnet denselben Tag wie ein Tipp auf den Titel. 
  Dateien: `App/Sources/Components.swift, App/Sources/WeekView.swift, App/Sources/WeekTable.swift`
- **R66** (Nächste Runde) – Wochenzellen sagen „Mittwoch, Fahrrad fahren, nicht erfasst“. Die Watch-Knöpfe sprechen Wörter. Im Abschluss steht bei einem verfehlten Ziel ein eigenes Symbol mit dem Ziel „≤ 23:00“. 
  Dateien: `App/Sources/Components.swift, App/Sources/WeekView.swift, App/Sources/WeekTable.swift, App/Sources/Editors.swift, App/Sources/CloseDayView.swift, Watch/Sources/WatchHomeView.swift`
- **R67** (Nächste Runde) – Die Größen skalieren ausgehend von den heutigen Werten, bei Standardgröße bleibt alles gleich. Bei sehr großer Schrift ordnen sich die Knöpfe 2×2 an. 
  Dateien: `App/Sources/TodayView.swift`
- **R68** (Nächste Runde) – Die Karten zeigen „1 von 4 Kategorien bewertet“ mit einem dünnen Fortschrittsbogen. Ringe, Sparklines und Ziel-Balken tragen die Zielfarbe. Im Mac-Wochenpanel bleibt nur eine farbige Liste. 
  Dateien: `App/Sources/GoalsView.swift, App/Sources/Components.swift, App/Sources/WeekTable.swift, App/Sources/WeekView.swift, App/Sources/CloseWeekView.swift`
- **R69** (Nächste Runde) – Über den Symbolen steht „M D M D F S S“, heute ist hervorgehoben, und VoiceOver nennt den Tag. 
  Dateien: `App/Sources/GoalsView.swift`
- **R70** (Nächste Runde) – Solche Wochen erscheinen als oranger Balken mit dem Etikett „nicht abgeschlossen“ und lassen sich per Wischen oder Kontextmenü abschließen. 
  Dateien: `App/Sources/ReviewView.swift, App/Sources/GoalsView.swift`
- **R71** (Nächste Runde) – Die Vorschau bekommt „Sichern…“ (⌘S) und „Drucken…“ (⌘P), dafür wird die Drucken-Berechtigung ergänzt. Optional lässt sich auch das Teilen-Bild sichern. 
  Dateien: `App/Sources/PDFExport.swift, Config/macOS/Thalia.entitlements, App/Sources/Sharing.swift`
- **R72** (Nächste Runde) – Konfetti und Erfolgs-Vibration gibt es nur im Moment des Abschließens, nicht beim späteren Ansehen. 
  Dateien: `App/Sources/CloseDayView.swift, App/Sources/CloseWeekView.swift, App/Sources/Sharing.swift`
- **R73** (Nächste Runde) – Ansichten bekommen das System-Schließen (×), „Fertig“ steht nur dort, wo etwas bestätigt wird. Nach dem Abschluss wird „Fertig“ unten zum Hauptknopf. 
  Dateien: `App/Sources/Components.swift, App/Sources/CloseDayView.swift, App/Sources/CloseWeekView.swift, App/Sources/ReviewView.swift, App/Sources/ImportView.swift, App/Sources/Glance.swift, App/Sources/Editors.swift, App/Sources/SettingsView.swift`
- **R74** (Nächste Runde) – Bei fertiger Kategorie zeigt die Karte „Weiter: 1.2“ bzw. „Zum Abschluss“, und „Alle leeren“ wandert ins Haltemenü. Unten heißt es „Weiter: Abschluss & Notizen“. 
  Dateien: `App/Sources/TodayView.swift`
- **R75** (Nächste Runde) – „anlegen“ heißt neuer Messwert, „eintragen“ heißt Wert, „erfassen“ heißt PH und „+“. Die letzte Seite heißt „Abschluss & Notizen“. Der Kürzel-Hinweis erscheint nur am Mac und iPad, dafür vollständig. 
  Dateien: `App/Sources/TodayView.swift, App/Sources/WeekTable.swift, App/Sources/Editors.swift, App/Sources/ThaliaApp.swift`
- **R76** (Nächste Runde) – Die Hilfetexte werden korrigiert (direkte Knöpfe, Durchtippen nur in der Woche, PH immer mit „Wofür“). Doppelte Tour-Karten werden zusammengelegt, 13 statt 16, und Watch, Siri und Kontrollzentrum werden konkret genannt. Die Tests werden angepasst. 
  Dateien: `App/Sources/Explainers.swift, Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift, Packages/ThaliaCore/Tests/ThaliaCoreTests/CSVTests.swift, docs/TOUR.md, App/Sources/SettingsView.swift`
- **R77** (Nächste Runde) – Bini wählt „mindestens“, „höchstens“, „unter“ … und gibt einen Wert ein, bei Uhrzeiten über einen Uhrzeitwähler. Live erscheint „Erfüllt bei ≤ 6 pro Tag“. „PH“ fällt aus der Einheitenliste. 
  Dateien: `App/Sources/Editors.swift, Shared/TrackerStore.swift`
- **R78** (Nächste Runde) – Beides wird als Chips angeboten, ein eigenes Feld gibt es nur für eigene Typen. Eine Fußzeile sagt „Arbeitsfreier Tag: Arbeitspunkte zählen heute nicht“. In der Beschreibung fehlt „Kontakt“ nicht mehr. 
  Dateien: `App/Sources/Editors.swift, Packages/ThaliaCore/Sources/ThaliaCore/Vocabulary.swift`
- **R79** (Nächste Runde) – Status, Konto und Fehler erscheinen auf Deutsch, gelöst in der App selbst, ohne das Kit zu ändern. Die Zeile „Bundle“ fällt weg. 
  Dateien: `App/Sources/SettingsView.swift, Packages/ThaliaCore/Sources/ThaliaCore (neue Datei SyncGerman.swift)`
- **R80** (Nächste Runde) – Die Abend-Erinnerung gilt pro Tag und wird beim Abschließen entfernt, dazu gibt es die Aktion „In 30 Min.“. Die Erlaubnis wird nach der Tour abgefragt. Am Mac ist die Erinnerung standardmäßig aus, und es gibt einen neuen Morgentext. 
  Dateien: `App/Sources/Services.swift, Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift, App/Sources/CloseDayView.swift, App/Sources/ThaliaApp.swift, App/Sources/SettingsView.swift, App/Sources/RootView.swift`
- **R81** (Nächste Runde) – Ein Tipp auf den Wert öffnet einen Krone-Editor, der beim zuletzt erfassten Wert beginnt. Health-Messwerte bekommen keine ±-Knöpfe. 
  Dateien: `Watch/Sources/WatchHomeView.swift, Shared/TrackerStore.swift, Packages/ThaliaCore/Sources/ThaliaCore/Vocabulary.swift`
- **R82** (Nächste Runde) – Die gewählte Markierung ist hervorgehoben, und die Uhr vibriert beim Setzen und Leeren unterschiedlich. 
  Dateien: `Watch/Sources/WatchHomeView.swift`
- **R83** (Nächste Runde) – Neben dem Balken steht „14/28 Woche“. Das Widget nutzt direkt die Zielfarben der App. 
  Dateien: `Widgets/Sources/ThaliaWidgets.swift, App/Sources/Style.swift, project.yml`
- **R84** (Nächste Runde) – Indizes auf Wochen- und Tagesschlüsseln. Der Widget-Stand wird nur auf dem iPhone, gebündelt und beim Verlassen der App geschrieben. Die Abfragen für die ganze Woche werden enger. 
  Dateien: `Shared/Models.swift, Shared/TrackerStore.swift, App/Sources/RootView.swift`
- **R85** (Größere Ideen) – Pro Kategorie eine Wertezeile (Gewicht, Bettzeit, Seiten …) in der Farbe für erfüllt bzw. verfehlt. Ein Tipp öffnet den Wert dieses Tags zum Nachtragen. 
  Dateien: `App/Sources/WeekView.swift, App/Sources/WeekTable.swift`
- **R86** (Größere Ideen) – Ein eigenes Watch-Widget mit Ring, Offenem und PH für Kreis, Rechteck, Zeile und Ecke. Es rückt abends nach oben und öffnet per Tipp die Watch-App. 
  Dateien: `project.yml, Widgets/Sources/ThaliaWidgets.swift, Shared/WidgetBridge.swift, Watch/Sources/WatchHomeView.swift`
- **R87** (Größere Ideen) – Jede offene Zeile im mittleren und großen Widget wird zum Knopf, der ✓ setzt. Danach rückt der nächste Punkt nach. ½, ✗ und „Entfällt“ bleiben in der App. 
  Dateien: `Widgets/Sources/ThaliaWidgets.swift, Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift, Shared/WeekContext.swift, project.yml`
- **R88** (Größere Ideen) – In Fokus lässt sich mit ‹ Diese Woche › blättern. Dazu kommt ein Diagramm der letzten 8 Wochen mit Ziel und „Ziel erreicht in 3 von 8“. Ein Tipp auf einen Balken springt zu dieser Woche. 
  Dateien: `App/Sources/Glance.swift, Shared/WeekContext.swift`
- **R89** (Größere Ideen) – Der Bereich wird zur Auswahl, nach der Siri fragt. Ein Kurzbefehl „Ausgabe“ fragt Betrag und „Wofür“ ab, und „Wofür“ bekommt Vorschläge. „Stand des Tages“ nennt das Offene. Der doppelte PH-Kurzbefehl fällt weg, und in Fokus und den Einstellungen gibt es einen Siri-Hinweis. 
  Dateien: `App/Sources/Intents.swift, Shared/RouteIntents.swift, Shared/TrackerStore.swift, App/Sources/SettingsView.swift, App/Sources/Glance.swift`
- **R90** (Sofort) – siehe oben. 
  Dateien: `App/Sources/TodayView.swift (TodayHeader, DayOverviewList), App/Sources/Glance.swift (SidebarGlanceText), App/Sources/WeekView.swift, Packages/ThaliaCore/Sources/ThaliaCore/ThaliaTour.swift (TodaySummary.dayNote)`
- **R91** (Sofort) – siehe oben. 
  Dateien: `Packages/ThaliaCore/Sources/ThaliaCore/Reports.swift (PlanPrompt.text), Shared/TrackerStore+Import.swift (exportDocument), App/Sources/ImportView.swift, App/Sources/CloseWeekView.swift`
- **R92** (Nächste Runde) – siehe oben. 
  Dateien: `Packages/ThaliaCore (PlanCSV.Document.repeated(from:to:) + Tests), Shared/TrackerStore+Import.swift, App/Sources/TodayView.swift (NoPlanView), App/Sources/ImportView.swift`
- **R93** (Nächste Runde) – siehe oben. 
  Dateien: `App/Sources/GoalsView.swift (GoalDetailContent, GoalCard), Shared/TrackerStore.swift (measureSeries)`
- **R94** (Sofort) – siehe oben. 
  Dateien: `App/Sources/TodayView.swift (TodayPager, TodaySplit), App/Sources/Glance.swift`
- **R95** (Nächste Runde) – siehe oben. 
  Dateien: `App/Sources/GoalsView.swift, App/Sources/ReviewView.swift, Packages/ThaliaCore/Sources/ThaliaCore/Reports.swift (PeriodReport + Tests)`
- **R96** (Größere Ideen) – siehe oben. 
  Dateien: `App/Sources/ThaliaApp.swift (MenuBarExtra), App/Sources/Glance.swift, App/Sources/SettingsView.swift`
- **R97** (Nächste Runde) – siehe oben. 
  Dateien: `App/Sources/Intents.swift (AddExpenseIntent), App/Sources/AppModel.swift (addExpense), App/Sources/SettingsView.swift`
