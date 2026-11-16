# Thalia v6 – Korrekturen v6 (Bini, 16. Nov. 2026)

Quelle: Binis Nachricht „Thalia Korrekturen v6“ (Punkt 3 war leer). Status: [ ] offen · [~] in Arbeit · [x] erledigt.

## Punkte
- [x] **K1** Arbeitsstunden erfassen ist noch zu zerstückelt: Stunden dürfen nie ohne Angabe, woran gearbeitet wurde, entstehen (kein bloßes + / −). **Bereich und Beschreibung sind Pflicht.**
- [x] **K2** Ausgaben klar erfassen: jede Ausgabe einzeln und eindeutig – auch in der Hauptliste (Kategorieseite), nicht nur über den Schnellzugriff.

## Plan
1. **Ein Weg für Power-Hours**: überall „Menge + Bereich + Beschreibung“. Die PH-Kachel einer Kategorie zeigt die Summe (nur lesen) und darunter die Einträge; neu erfassen nur über die Zeile „Menge · Wofür · +“ (Knopf erst aktiv mit Beschreibung) oder das PH-Fenster.
   - Weg: − / + / Summe tippen auf der PH-Kachel, „+ 1 PH“-Schnellmenü, `setWorkTotal`.
   - PH-Fenster: „Sichern“ erst mit Bereich **und** Beschreibung; vom „+“ aus ohne vorgewählten Bereich (bewusst wählen).
   - Menge eines Eintrags direkt in der Liste ändern (− / +), Beschreibung ebenda; alte Einträge ohne Beschreibung sind markiert („Beschreibung fehlt“).
   - Watch: Bereich → Menge → Wofür (Vorschläge oder diktieren). Kurzbefehl: „Wofür“ ist Pflicht-Parameter.
2. **Ausgaben überall gleich**: Der €-Messwert auf der Kategorieseite ist eine Ausgaben-Zeile: Betrag + Wofür + „Hinzufügen“, darunter die Ausgaben des Tages einzeln (löschen per Wischen). Kein bloßes + / − mehr. „Wofür“ ist Pflicht (Vorschläge mit einem Tipp).

## Jetzt
- [x] Umgesetzt (lokal geprüft): PH-Kachel nur Summe + „Erfassen“; Schnellmenü und `setWorkTotal` entfernt; `addPowerHours` verlangt Bereich + Beschreibung; neue Zeile/PH-Fenster erst mit Beschreibung aktiv, PH-Fenster ohne vorgewählten Bereich; Menge pro Eintrag über „PH ▾“; „Beschreibung fehlt“-Hinweis; Watch: Bereich → Menge → Wofür; Kurzbefehl mit Pflicht-„Wofür“. Ausgaben: Zeile „Betrag · Wofür · +“ auf der Kategorieseite, jede Ausgabe einzeln darunter (wischen löscht), Ausgaben-Fenster verlangt „Wofür“. Tour v6, Version 1.5.0.
- Nächster Schritt: CI-Screenshots prüfen → TestFlight 1.5.0.
