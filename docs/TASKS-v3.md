# Thalia v3 – Korrekturen v3 (Bini, 9. Nov. 2026)

Quelle: Binis Nachricht „Thalia Korrekturen v3“. Jeder Punkt hier, nichts vergessen.
Status: [ ] offen · [~] in Arbeit · [x] erledigt (CI/Gerät-Prüfung steht in „Jetzt“).

## 0. Repo öffentlich (Billing wird nicht bezahlt → öffentliche Repos haben kostenlose Runner)
- [x] Historie aller Branches nach Secrets durchsucht: keine.
- [x] Persönliches aus dem Template (Familiennamen, kg, €) entfernt; CI-Zertifikatsbericht ohne Namen/Seriennummern (`scripts/ci/certificates.py` – Handbuch-Vorschlag 20).
- [ ] Bini: Entscheidung Historie (A neu schreiben / B lassen), CI-Branches löschen, Fork-PR-Freigabe, Sichtbarkeit → öffentlich (Schritte in der Antwort vom 9. Nov.).
- [ ] Danach: CI neu starten, Screenshots (Mac-Woche!), TestFlight.

## Punkte
- [x] **V1** PDF-Export der Kategorien mit Zusammenfassung (schön, teilbar): Woche → Bericht/Teilen → PDF.
- [x] **V2** Wochenübergreifende Ziele (stammloop 10 PH, „5 davon“ …) mit klarer Übersicht (Fortschrittsbalken), für **alle** tagesübergreifenden Ziele, nicht nur stammloop.
  - [x] V2.1 Fortschrittspunkte **nicht abhakbar**: automatisch aus den zugehörigen Werten abgeleitet (Tag mit Wert = gearbeitet; Woche erreicht/teilweise/nicht → rückwirkend).
    - [x] V2.1.1 Schnell tracken, trotzdem alle Optionen; sehen, wie heute zur Woche steht (heute +x, Woche y/z, Tempo-Marke).
  - [x] V2.2 Prompt legt die Beziehungen fest (Wochen-Messwert mit Ziel + Fortschrittspunkt mit `link`), damit die App sie optimal darstellt.
  - [x] V2.3 Journalfragen, Makros, Nebensächliches: beim schnellen Check-in nicht gleich prominent (eingeklappt „Weitere“).
  - [x] V2.4 Wichtig/Nebensache bestimmt die KI (Flag), App weist es aus.
    - [x] V2.4.1 In der App überschreibbar („doch wichtig/unwichtig“) → im Prompt der nächsten Woche, falls der Punkt wieder vorkommt.
- [x] **V3** n×/Woche-Punkte: wenn schon an früheren Tagen erfüllt → nicht mehr im Tages-Tracking; in einem einklappbaren Bereich trotzdem erreichbar.
- [x] **V4** Schnellknopf: mit einem Tipp alles (offene) → ✓ / ½ / ✗ / leeren (pro Kategorie und pro Tag), mit Widerrufen.
- [x] **V5** Klar zeigen, was man ausfüllen muss, was optional ist und was automatisch/rückwirkend gerechnet wird (subtil, aber eindeutig) – v. a. stammloop, Hobby & Co.
- [x] **V6** Zahlen und Scores mit bis zu 2 Nachkommastellen; ab 3 auf 2 runden (Anzeige und Eingabe).
- [x] **V7** Nachhilfe-Zeit: einfach PH, keine komischen Kommazahlen; abziehen muss gehen. HAEB ebenso (nicht nur + in 1er-Schritten): − / Wert tippen / +.
- [x] **V8** Uhrzeiten (Einschlafzeit …): kein „Jetzt“-Knopf; Zeitwähler direkt (meist am nächsten Tag nachgetragen).
- [x] **V9** Tag abschließen:
  - [x] V9.1 Vorhandenes zeigen; Fehlendes, wenn optional, eingeklappt („Fehlt noch“).
  - [x] V9.2 n×/Woche-Punkte, die noch fehlen, zur Vollständigkeit mit Hinweis zeigen.
- [x] **V10** Power-Hours: Beschreibung direkt in der Liste eintippen, ohne Sheet.
  - [x] V10.1 Allgemein: wichtige Werte schnell und klar direkt eintragbar.
  - [x] V10.2 Lesestand & Co.: kein Modal mit „Eintragen“ → „Fertig“; so wenige Schritte wie möglich.
- [x] **V11** Familientag/Erholungstag/…: nur, was an solchen Tagen sinnvoll ist (Mentales, Familie, Hobby, Lesen, Morgenroutine, Dehnen …); Arbeitstage komplett. Der Rest zählt an dem Tag nicht (N/A).
- [x] **V12** Wochenübersicht, Wochenabschluss, Tagesabschluss: optisch deutlich spannender (Verläufe, Animationen, schöne Übersichten), Reduce Motion beachten.
- [x] **V13** Teilen-Knopf am Ende: erfolgreiche Tage/Wochen als Bild, mehrere gut gestaltete Vorlagen.

## Plan / Entscheidungen
1. **Merkmale (Flags)** an Punkt und Messwert, neues Feld `flagsRaw` (additiv, Schema → 5.2/5.3 nötig):
   - `nebensache` – zählt nur, wenn ausgefüllt (leer blockiert nichts), in der App eingeklappt unter „Weitere“ (V2.3/V2.4).
   - `arbeit` – nur an Arbeitstagen; an freien Tagen (Familien-, Erholungs-, Urlaubstag …) nicht fällig = N/A (V11).
     Ohne `arbeit`/`frei`-Angaben in der Woche gilt: Ziel 3 (Business) außer 3.1 ist Arbeitstag-only.
   - `ko` bleibt (Null-Regel). CSV-Spalte `flags`, kommagetrennt.
2. **Fortschrittspunkte (V2.1)**: Markierung wird abgeleitet – Tag mit Wert > 0 im verknüpften Messwert = ✓ „gearbeitet“, sonst N/A; Woche: ≥ 100 % → alle ✓ zählen 1, > 0 % → ½, nichts → ✗ am letzten Tag. Gespeicherte Markierungen werden für verknüpfte Fortschrittspunkte ignoriert. Ohne `link` bleibt Abhaken möglich.
3. **Wochenziele-Karte** oben auf jeder Kategorieseite: Fortschrittspunkte + Wochen-Messwerte, Balken Woche, „heute +x“, Tempo-Marke, Eingabe direkt (V2.1.1).
4. **Gewichtung überschreiben** (V2.4.1): Kontextmenü/Detail „Als wichtig / als Nebensache“ → PlanChange „Gewichtung von mir geändert“.
5. **Arbeit**: Messwerte mit Quelle `arbeit:` zählen immer in PH (Einheit egal); − / tippen / +, „−“ verkleinert den letzten Eintrag (V7).
6. **Zahlen**: `Format.score` bis 2 Nachkommastellen ohne Nullen am Ende (7,25 · 8,5 · 10); Eingaben auf 2 Stellen gerundet (V6).
7. **PDF (V1)** und **Teilen-Bilder (V13)** mit `ImageRenderer`; Vorlagen „Aurora“ (Verlauf), „Klar“ (hell), „Nacht“ (dunkel).
8. **Optik (V12)**: animierter MeshGradient-Kopf (Tag/Woche), Ring-Animation, kleine Feier beim Abschluss; ohne Bewegung bei „Bewegung reduzieren“.

## Jetzt
- [x] Core v3 (65 Tests grün): Flags, abgeleitete Fortschrittspunkte, freie Tage, Nebensache, n×/Woche erfüllt, Format 2 Stellen, Arbeit immer PH, Prompt + Beispiel.
- [x] Modelle: `PlanItem.flagsRaw`, `MeasureDefinition.flagsRaw` → `cloudkit/schema.ckdb` (additiv) → **5.2 Import + Bini 5.3 Deploy nötig vor TestFlight**.
- [x] UI: Wochenziele-Karte, eingeklappte Nebensachen/erfüllte Wochenpunkte, Alle-offenen-Menü, Inline-PH, Zeitwähler ohne „Jetzt“, Tagesabschluss neu, Gewichtung überschreiben, Editoren (Nebensache, freie Tage), HeroCard mit animiertem Verlauf + Feier, Teilen-Bilder (Aurora/Klar/Nacht), Wochen-PDF, Tour v3, Version 1.2.0.
- Alles nur lokal geprüft (`make check`): **App-Code ungebaut**, weil GitHub Actions bis zum Öffentlich-Schalten keine Jobs startet.
- [x] Repo öffentlich, Historie von Bini auf einen Commit (d3909a5) neu geschrieben, CI-Branches gelöscht.
- [x] CI run 14: erster Mac-Build von v3 grün (iOS, macOS, Watch, Widgets); Screenshots geprüft → Mac-Wochentabelle: Titel bekommen Vorrang, Tagesspalten 38 pt.
- [x] CloudKit-Import (flagsRaw) erfolgreich → wartet auf Bini 5.3 Deploy.
- Nächster Schritt (alt), sobald Bini „öffentlich“ meldet: CI neu starten → Compile-Fehler beheben → `[screenshots]` prüfen → cloudkit-schema-Workflow (5.2) → Bini 5.3 → TestFlight 1.2.0.
