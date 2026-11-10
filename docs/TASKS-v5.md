# Thalia v5 – Korrekturen v5 (Bini, 10. Nov. 2026)

Quelle: Binis Nachricht „Thalia Korrekturen v5“. Status: [ ] offen · [~] in Arbeit · [x] erledigt.

## Punkte
- [x] **F1** Schnell einsehen: Power-Hours und Arbeitsleistung. Schnell erfassen und einsehen: Tagesausgaben.
- [x] **F2** Brauchbare Widgets: auf einen Blick, was heute läuft (und evtl. die Woche).
- [x] **F3** Kontrollzentrum: Thalia-Knopf, der ins „Erfassen“-Fenster führt (nicht nur Power-Hours).
- [x] **F4** In der App ein schneller Überblick: einmal reinschauen → sofort sehen, was läuft und was noch zu tun ist.
  - [x] F4.1 Mac: unten links in der Navigation ein grauer Text-Überblick, immer sichtbar – pro Tag, pro Woche, Power-Hours usw.

## Plan
1. **Fokus** (Sheet, auch Mac): heute / Woche PH, Ziel der Woche, Netto-Stunden, Mo–So als gestapelte Balken je Bereich, Bereiche gegen ihr Wochenziel, alle Einträge der Woche mit Beschreibung (tippen = bearbeiten), „+ Power-Hours“.
2. **Ausgaben** (Sheet): Betrag sofort eintippen (Tastatur offen), optional „wofür“ mit Vorschlägen, „Hinzufügen“; heute und Woche als Summe, Mo–So-Balken, Liste mit Löschen. Nutzt den €-Messwert der Woche (z. B. `ausgaben`); fehlt er, legt ein Knopf ihn an.
3. **Heute im Blick** (Tagesübersicht ausgebaut): „Noch zu tun“ (offene Pflichtpunkte nach Kategorie, tippen springt hin), Kacheln Fokus / Ausgaben / Wochenziele, Kategorien. Erreichbar über den Ring oben, das Accessory unten und ⌘0 am Mac.
4. **Mac-Seitenleiste unten**: grauer Text „Heute 73 % · 11 offen · 4 PH · 23 €“ / „KW46 8,2 · 18 von 28 PH · 140 €“, Klick öffnet Fokus bzw. Ausgaben bzw. Heute im Blick.
5. **Widgets**: klein (Ring, offen, PH), mittel (Ring + nächste offene Punkte + PH-Balken), groß (Tag + Woche: offene Punkte, Wochenziele-Balken, PH, Ausgaben); Sperrbildschirm. Bereiche tippen → Fokus / Ausgaben / Heute.
6. **Kontrollzentrum**: „Thalia erfassen“ (öffnet „Erfassen“) und „Ausgabe erfassen“, zusätzlich zum PH-Knopf; auch als Kurzbefehle.

## Jetzt
- [x] Umgesetzt (lokal geprüft): TodaySummary v3 (offene Punkte, Wochenziele, PH Woche/Ziel, Ausgaben), WeekContext openToDo/expenseMeasure/workTarget/weeklyLines, Glance.swift (Fokus, Ausgaben, Kacheln, Noch zu tun, Mac-Seitenleiste), Widgets neu (klein/mittel/groß/Sperrbildschirm, Links zu Fokus/Ausgaben/Woche), Controls „Thalia erfassen“ + „Ausgabe“, Kurzbefehl „Ausgabe“, Menü ⌘0/⌘5/⌘6, Tour v5, Version 1.4.0.
- [x] CI run 18 grün; Screenshots geprüft (Heute im Blick, Fokus, Ausgaben, Mac mit grauem Überblick). Nachgebessert: Kacheltitel ohne Umbruch, Bereiche im Fokus mit eigenen Farben (Diagramm = Zeilen).
- [x] **TestFlight 1.4.0 (32)** iOS + macOS: VALID, IN_BETA_TESTING. iOS brauchte bei Apple ~1 h; ein zweiter iOS-Upload (33, identischer Code) folgt als Duplikat.
- Nächster Schritt: Bini testet v5 (TESTING.md „v5“), Feedback → v6.
