# Thalia v4 – Korrekturen v4 (Bini, 10. Nov. 2026)

Quelle: Binis Nachricht „Thalia Korrekturen v4“ (Punkte 2 und 5 waren leer – nachfragen, falls noch etwas kommt).
Status: [ ] offen · [~] in Arbeit · [x] erledigt.

## Punkte
- [~] **W1** PDF-Export der Woche deutlich schöner; erste Seite ein echter Hingucker (jetzt langweilig und abgeschnitten). Zusätzlich **Tages-Export** als PDF.
- [~] **W2** Design noch zu einfach → UI deutlich aufwerten (UX ist ok, kleine Verbesserungen erlaubt).
  - [~] W2.1 Werte eintragen / schnell hinzufügen klarer (was ist +, was ist −?).
  - [~] W2.2 Klar zeigen, was man drücken muss, um den gewünschten Schritt zu erreichen.
- [~] **W3** Grauer Strich im Fortschrittsbalken mancher Wochenziele: erklären oder entfernen.
- [~] **W4** Kategorie-Pillen: neben der Nummer ein kleiner Text mit der Kategorie; Auswahl insgesamt besser (fortgeschrittener).

## Plan
1. **PDF neu**: Titelseite mit großem Verlauf, Wochenwertung, 10 Ziel-Kacheln (Farbe je Ziel), Tage Mo–So, Highlights (bestes Ziel, Wochenziele erreicht, PH, abgeschlossene Tage); Folgeseiten als gestaltete Tabelle mit fester Zeilenhöhe (nichts wird abgeschnitten). **Tages-PDF**: Titel mit Tageswertung, Kategorien mit Punkten, Werte, PH mit Beschreibung, Notizen. Vorschau vor dem Teilen (auch für die CI-Screenshots `pdf-week`, `pdf-day`).
2. **Farben je Jahresziel** (10 Farbtöne) für Chips, Kategorie-Kopf, Ziel-Kacheln, Balken.
3. **Kategorie-Kopf** als farbige Karte (Ziel-Verlauf, Füllring, „3 von 5“, Zwischenstand, „Alle …“-Knopf mit Text).
4. **Chips** mit Nummer + Kurztitel + Füllstand in Zielfarbe; daneben ein Raster-Knopf → Übersicht aller Kategorien nach Ziel gruppiert (springen).
5. **Markieren**: Knöpfe mit Symbol **und** Wort (Erledigt · Teilweise · Nicht · N/A), ausgewählt = gefüllt.
6. **Werte**: „− 0,5“ / „+ 0,5“ mit Schrittweite und Einheit sichtbar, Feld zeigt „2,5 PH“, separater „…“-Knopf für Schnellmengen (kein verstecktes Halten); Hinweiszeile „heute“.
7. **Wochenziel-Balken**: Strich = „Soll bis heute“ – mit Legende darunter (oder ausgeblendet, wenn schon erreicht).

## Jetzt
- [x] Umgesetzt in c20b7a9 (lokal geprüft): PDFExport.swift (Woche: Titelseite, Details, Tabellen; Tag: Titelseite, Tabellen; Vorschau), Style.swift (Zielfarben), Chips + Kategorie-Übersicht, farbiger Kategorie-Kopf, Markier-Knöpfe mit Wort, Eingaben „− 0,5 / + 0,5“ + „…“, Messwertzeilen zweizeilig, Balken-Legende.
- Nächster Schritt: CI-Screenshots prüfen (today, pdf-week, pdf-day, close-day, mac) → nachbessern → TestFlight 1.3.0.
