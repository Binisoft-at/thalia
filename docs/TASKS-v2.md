# Thalia v2 – Korrekturen aus „Thalia Korrekturen und Notizen v1“ (4. Nov. 2026)

**Hauptziel:** schnelle, vereinfachte Nutzung und besserer Überblick. Es soll sich anfühlen, als
könne man alles sehr schnell ausfüllen. Apple HIG beachten. Bestehende Daten/Importe sind
Testdaten – keine Migration nötig; Prompt, Struktur, Vorlage dürfen frei angepasst werden
(CloudKit: Production kennt das Schema schon → **nur additive** Änderungen; neue Felder/Typen
brauchen 5.2 Schema-Import + 5.3 Deploy durch Bini vor dem nächsten TestFlight).

Status: `[ ]` offen · `[~]` in Arbeit · `[x]` erledigt · `[-]` entfällt/ersetzt

## Allgemein
- [~] **G1** Stand in .md-Dateien halten (STATUS.md, diese Datei, TESTING.md) und nach jedem Schritt aktualisieren.
- [~] **G2** Testliste für Bini (alles, was nur auf Geräten testbar ist) → `docs/TESTING.md`.
- [x] **G3** Schnellerer iCloud-Sync bei parallelem Tippen: jede Änderung sofort speichern (ist so), Konflikte pro Schlüssel (letzte Änderung gewinnt), Grenzen ehrlich dokumentieren (iOS/CloudKit bestimmen das Timing, keine API zum Erzwingen).

## Mac
- [~] **M1** Mac-UI deutlich besser, nicht wie eine Handy-App: echte Mac-Layouts (Kategorien-Spalte + breiter Inhalt, Fenster-Toolbar mit Aktionen, Inspector für Tagesüberblick, Wochen-Raster als dichte Tabelle, Hover, Tastatur).

## Mobil / allgemein
- [x] **U1** Hinweis „Tag abschließen“ erscheint bei jedem Scrollen → entfernen (keine Tips in Listen).
- [x] **U2** Heute aufräumen:
  - [x] U2.1 Infos/Details hinter ⓘ, nur wichtige Übersichtsdaten des Tages sichtbar.
  - [x] U2.2 Nicht die ganze Woche (Tagesleiste) im Tag zeigen.
  - [x] U2.3 Guter Gesamtüberblick des Tages – sichtbar auf Klick, nicht automatisch.
  - [x] U2.4 Messwerte/Punkte ausfüllen ohne langes Scrollen: pro Kategorie blättern (Slider/Pager).
- [x] **U3** Statt Anzahl offener Dinge: Prozent, wie viel schon ausgefüllt ist.
- [x] **U4** Tagesscore nicht laufend zeigen – erst nach „Tag abschließen“ mit allen Daten berechnen und anzeigen.
- [x] **U5** Schneller ausfüllen (Handy + Mac):
  - [x] U5.1 Messwert-Kacheln einheitlich; Wert sofort eintragbar (Detailfenster nur optional); kein Fokus/Unterricht/Ersatz – nur PH.
  - [x] U5.2 Punkte: Haltedauer kürzer → Optionen ohne Halten (direkte Buttons ✓ ½ ✗ –).
  - [x] U5.3 Pro Kategorie auswählen; Messwerte nach Kategorie, darin nach Typ sortiert.
  - [x] U5.4 Kategorie-Zwischenergebnis pro Tag beim Tag sichtbar.
- [x] **U6** Nachhilfe standardmäßig in 50- oder 100-min-Blöcken (1 / 2 PH), individuell änderbar.
- [-] **U7** Timer nur als Vorschlag → ersetzt durch U20 (Timer ganz raus).
- [x] **U8** Wichtige Eingabefelder klar hervorheben, sekundäre verstecken (wenig kognitive Last).
- [x] **U9** Arbeit erfassen:
  - [x] U9.1 Unterricht zählt auch als PH (keine Art-Unterscheidung). Primärfelder: Kategorie, Anzahl PH (Quick 0,25/0,5/0,75/1/2 oder frei), Beschreibung (z. B. Schüler; Vorschläge aus Historie passend zur Kategorie).
  - [x] U9.2 In der Liste immer die Kategorie zeigen, auch mit Beschreibung.
- [x] **U10** „+“ unten, mit dem Daumen erreichbar.
- [x] **U11** Quick-Button fürs Kontrollzentrum (Control Widget, iOS 18+): z. B. „PH erfassen“.
- [x] **U12** Inhalt (Prompt + Vorlage):
  - [x] U12.1 Protein: nur „im Zielbereich (≥ x g)“ ja/nein; höher ist ok.
  - [x] U12.2 Fastendauer: nicht in Stunden, nur „eingehalten“ ja/nein.
  - [x] U12.3 Essfenster/Essens-Details: nur „eingehalten“ ja/nein.
  - [x] U12.4 Kein Mahlzeitenprotokoll (andere App).
  - [x] U12.5 Training, Zone 2 …: nur abhaken, keine Details.
  - [x] U12.6 Dinge mit Anzahl (z. B. Aufschläge) bleiben Messwerte.
  - [x] U12.7 Journal: statt Fragen im Tagesabschluss nur abhaken „ins Journal eingetragen“.
  - [x] U12.8 **Nicht mehr genau 10 Punkte pro Kategorie** – so viele wie nötig (auch 2 ist ok); Warnung/Regel entfernen.
  - [x] U12.9 Einstellung „Bedingte Punkte erst abfragen“: Kategorie fragt „Trat heute eine dieser Situationen auf?“ → nur relevante eintragen, Rest automatisch N/A.
- [x] **U13** Messwerte gebündelt: zuerst nach Überkategorie, darin nach Art (wöchentlich, Anzahl, Uhrzeit …) – im selben Kontext, nicht auf einem Haufen.
- [x] **U14** Metriken, Beschreibungen, Ziele in der App ergänzen/bearbeiten/löschen; jede Änderung kommt in den Prompt der nächsten Woche, mit Angabe „dauerhaft übernehmen“ oder „nur diese Woche“.
- [x] **U15** Import einer Woche, die schon existiert: alte Woche inkl. Markierungen und Messwerten archivieren (wiederherstellbar), für Anzeige und Statistik versteckt; die neue Woche ist die einzig relevante.
- [x] **U16** Apple Watch: gute UI/UX zum schnellen Hinzufügen von Messwerten und Abhaken offener Punkte.
- [x] **U17** Widgets nochmal auf UI/UX prüfen (einige durcheinander).
- [x] **U18** Score:
  - [x] U18.1 Kein Score für ein Jahresziel/eine Kategorie, solange die Unterkategorien/Punkte nicht alle ausgefüllt sind.
  - [x] U18.2 Optionen ohne Haltezeit (siehe U5.2).
  - [x] U18.3 Wochen-Punkte (n× pro Woche): „nicht fällig“ nur wählbar, solange noch genug Tage übrig sind (3×/Woche → bis Donnerstag, dann nicht mehr).
- [x] **U19** Fortschritts-Punkte (z. B. stammloop 8 PH/Woche):
  - [x] Tagespunkt „daran gearbeitet“ / „heute nicht“ statt „8 PH bearbeiten“.
  - [x] U19.1 Wochenziel am Ende nicht erreicht → rückwirkend: erreicht = erledigt, teilweise = teilweise, nichts = nicht erledigt.
  - [x] U19.2 Ziel früher erreicht → derselbe rückwirkende Effekt sofort.
- [x] **U20** Timer komplett aus Thalia entfernen (inkl. Live Activity, 50-min-Erinnerung, Watch-Timer).

## Technische Folgen (aus den Punkten oben)
- [x] **T1** Core: Scorer (U4, U18.1, U18.3, U19), Arbeit nur PH mit Dezimalwerten (U6, U9), kein 10er-Check (U12.8), Prompt + Vorlage neu (U12, U14, U19), Tests anpassen.
- [x] **T2** Modelle additiv: `WorkBlock.powerHours`, `WeekArchive` (U15), `PlanChange` (U14) → `cloudkit/schema.ckdb` → 5.2 Import → Bini 5.3 Deploy → TestFlight.
- [x] **T3** CI grün (run 8), `[screenshots]` geprüft, TestFlight 1.1.0 (16) hochgeladen, Bericht.

## Plan / Entscheidungen (verbindlich für die Umsetzung)
1. **Core zuerst** (`Packages/ThaliaCore`, Tests): 
   - `ItemSchedule.progress` (raw `fortschritt`, Prompt-Wort `fortschritt`), verknüpft per `link` mit einem Wochen-Messwert; Tagesoptionen nur „gearbeitet“ (✓) / „heute nicht“ (N/A). Auflösung im Scorer, **Markierungen werden nicht überschrieben** (rückwirkend = berechnet): Ziel erreicht → 1, teilweise (0 < Anteil < 1) → 0,5, 0 → 0; nur sobald Ziel erreicht (früh) oder Woche vorbei; vorher zählt der Punkt nicht. Woche vorbei, nie gearbeitet, Ziel verfehlt → 1 verpasster Punkt am letzten Tag.
   - Kategorie-Tagesscore nur wenn vollständig (keine leeren fälligen Punkte); Jahresziel-Score nur wenn alle Unterkategorien einen Score haben (Tag und Woche). Tages-Gesamtscore zeigt die UI erst nach „Tag abschließen“.
   - `Scorer.canMarkNotApplicable(item, day, marks)`: Wochen-Punkte nur solange `Tage nach heute (eigene Tage) ≥ noch nötige Anzahl`.
   - `fillRatio` (Prozent ausgefüllt) pro Tag/Kategorie: erfasst ÷ fällig (fest + Fortschritt; bedingte zählen nicht).
   - Arbeit nur PH: `WorkRecord.powerHours: Double` (statt Minuten/Art), CSV `work`-Zeile `value` = PH. `WorkTotals` = PH-Summe; Netto-Stunden = PH × 50 ÷ 60. `WorkKind` entfällt aus UI.
   - 10er-Regel raus (Warnung + Prompt). Prompt neu: ja/nein statt Details (Protein im Bereich, Essfenster, Fasten, Training), Anzahlen als Messwerte, Journal nur abhaken, Fortschritts-Punkte, Liste manueller Änderungen (U14).
   - Vorlage neu: wenige, nötige Punkte pro Kategorie; Fortschritts-Punkte für stammloop/HAEB/Sonstiges/Nachhilfe; Messwerte nur mit Zahl.
2. **Modelle additiv:** `WorkBlock.powerHours: Double = 0` (0 → aus `minutes`/50 lesen), `WeekArchive` (weekKey, archivedAt, title, csv, counts), `PlanChange` (weekKey, kind added/edited/deleted, target item/measure, code, title, detail, carryOver Bool, createdAt). Schema-Datei neu generieren.
3. **Heute neu (iPhone/iPad):** Kopf (Datum, Tagestyp-Chip, ⓘ für Wochenkontext/Notiz, ‹ › für Tage) · Fortschrittskarte („62 % ausgefüllt“, PH heute, „Tag abschließen“; Score erst danach) · Kategorie-Leiste (Chips mit Füllgrad) + seitliches Blättern (Pager) · Kategorieseite: oben Ergebnis/Füllgrad, dann Punkte mit direkten Buttons ✓ ½ ✗ – (kein Halten), Fortschritts-Punkte, Wochen-Punkte (n/m, N/A-Regel), bedingte (Frage zuerst, wenn Einstellung an), Messwerte gruppiert nach Art (Anzahl/Zahl · Uhrzeit · Woche) mit Inline-Eingabe. Überblick (U2.3) als Sheet über Button „Überblick“.
4. **„+“ unten:** Bottom-Accessory = Füllgrad + großer „+“-Button (Erfassen-Sheet: PH, Messwert, Notiz, Tag abschließen, Import). Kein Tip in Listen.
5. **Arbeit-Sheet:** Kategorie-Chips (3.x zuerst), PH-Quick 0,25/0,5/0,75/1/2 (+ Feld), Beschreibung mit Vorschlägen aus Historie der Kategorie; Nachhilfe-Default 1 PH, Quick 2. Sekundär eingeklappt: Ergebnis, nächster Schritt, Tag.
6. **Timer weg:** startTimer/stopTimer, WorkActivity, Live Activity, Block-Ende-Erinnerung, Watch-Timer entfernen (Felder `isRunning` etc. bleiben ungenutzt im Schema).
7. **Mac:** Heute als zwei Spalten (Kategorienliste mit Füllgrad links, breite Kategorieseite rechts), Toolbar-Aktionen, `.inspector` mit Tagesüberblick; Woche als dichtes Raster.
8. **Archiv (U15):** Import über bestehende Woche → CSV-Snapshot der alten Woche in `WeekArchive`, dann Punkte/Messwerte/Markierungen/Werte/Eigenwertungen der Woche entfernen; Arbeitsblöcke und Notizen bleiben (Fakten). Einstellungen → Archiv → Wiederherstellen (aktuelle Woche wird dabei selbst archiviert).
9. **Änderungen (U14):** Editoren für Messwert (Titel, Einheit, Ziel, Zeitraum, Kategorie, Art) und Punkt; beim Sichern/Löschen `PlanChange` mit Schalter „Auch nächste Woche übernehmen“; Prompt listet sie.
10. **Watch:** Seiten pro Kategorie mit offenen Punkten (Tap ✓, zweiter Button –), Messwerte mit +/− und Digital Crown, PH-Quick.
11. **Widgets:** Heute = Füllgrad (Score erst nach Abschluss), PH, Tag-Status; Woche = Jahresziel-Balken sauber beschriftet; Control Widget „PH erfassen“ (öffnet `thalia://work`).

## Jetzt
- [x] 1. Core erledigt (60 Tests grün): Fortschritts-Punkte, Score nur wenn vollständig, N/A-Regel, PH-only, Messwert-Gruppen, Prompt/Vorlage v2, Archiv-Erkennung im Import (`replacedWeeks`), `PlanChangeRecord`.
- [x] 2. Modelle + Store (Commit 2a50963, nur Session-Branch): WorkBlock.powerHours, WeekArchive (archiveWeek/restore/delete, apply archiviert replacedWeeks zuerst), PlanChange (recordChange bei add/update/trash von Punkten + Messwerten, carryOver), addMeasure/update/trash/restore, workSuggestions, settleConditionals, Trash mit measures, WorkActivity.swift gelöscht. App kompiliert noch NICHT (UI nutzt alte API).
- [x] 3. UI (Commit 832380d): Heute-Pager/Split, MarkBar, MeasureRow, Tagesübersicht, Bedingte-Punkte-Sheet, „+“ im Accessory, PH-Sheet, Editoren (Punkt, Messwert, carryOver), Einstellungen (Archiv, Änderungen, Schalter), Abschluss mit Journal-Haken, Watch-Seiten, Widgets (Füllstand), Control-Widget, Timer/Live Activity entfernt.
- [x] 4a. CI run 7 grün (c08bb68) nach Fix „Ausdruck zu komplex“; Screenshots geprüft → Korrekturen (Mac ohne Inspector als Standard, Abstand, Füllring im Abschluss, Watch-Label) in 4131b80. CloudKit-Import 5.2 erfolgreich (cloudkit run 4) → **wartet auf Bini: 5.3 Deploy Schema Changes**.
- [x] 4b. Bini: 5.3 Deploy erledigt → Tour-Version 2 + MARKETING_VERSION 1.1.0 → TestFlight run 16: iOS + macOS 1.1.0 (16) hochgeladen.
- [x] 5. (8. Nov.) Bini: „mit den empfohlenen Dingen weiter“ → bedingte Punkte bleiben standardmäßig aus; M1 vorgezogen: Woche als dichte Tabelle (WeekTable, Mac + iPad breit), Zellen nur mit erlaubten Markierungen, „x/10“ entfernt, Tagestyp kompakt (Commit 147dbcf, lokal geprüft).
- **Blockiert:** CI-Lauf 10 für 147dbcf startet keinen einzigen Job (auch Linux: kein Runner, keine Logs, 2 s) – auch nach Neustart. Vermutlich GitHub-Actions-Abrechnung/Ausgabenlimit oder Actions in der Organisation abgeschaltet → Bini prüft. Danach: CI neu starten, Mac-Screenshots „week“ prüfen, TestFlight 1.1.0 (nächster Build).
- Nächster Schritt: Bini testet (TESTING.md), Feedback → v3-Liste. M1 bleibt [~] bis Bini die Mac-Ansicht bestätigt.
- Nächster Schritt (alt): **4. CI** – push main, Mac-Build reparieren bis grün, `[screenshots]` prüfen (Heute-Pager, Mac-Split), dann cloudkit-schema-Workflow (5.2) → Bini 5.3 Deploy → TestFlight. G3: Sync – jede Änderung wird sofort gespeichert, Push (remote-notification) ist aktiv; das Timing bestimmt CloudKit (keine API zum Erzwingen) → in TESTING.md dokumentiert.
- (alt) 3. UI – App/Sources an neue API anpassen (Timer raus: AppModel, TodayView, Editors, Intents, Services, Settings, Explainers, Tour, ThaliaApp), dann Heute-Pager, „+" unten, Arbeits-Sheet, Editoren, Archiv-Liste, Mac-Layout. Danach 4. Watch/Widgets/Control.
