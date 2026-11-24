# Sync in Thalia – wie es läuft, was geprüft ist, was bekannt ist

Stand 1.10.0 (TASKS-v11). Alle Daten liegen in deinem privaten iCloud (CloudKit, Container
`iCloud.at.binisoft.thalia`). Kein eigener Server. Jedes Gerät hat die ganze Datenbank und gleicht sie über iCloud ab.
1.10.0 ändert das iCloud-Schema nicht: was neu dazukam, liegt als JSON in Einstellungs-Datensätzen (`AppSetting`).

## Wege

| Weg | Wie | Wann es ankommt |
|---|---|---|
| iPhone ↔ Mac ↔ iPad | SwiftData + CloudKit (privat) | Sekunden bis wenige Minuten; iCloud bündelt und drosselt |
| Jahresziel-Ergebnisse, Einträge, Abschnitte, Leseliste, Zuordnungen, Kategorie-Noten | über iCloud als Einstellungs-Datensätze (ältere Versionen übergehen sie) | wie alles andere |
| Apple Watch | eigene Kopie derselben iCloud-Datenbank | wenn die Watch-App offen ist oder iCloud sie im Hintergrund weckt (seit 1.6.1) |
| iPhone-Widgets | Schnappschuss in der App Group, geschrieben von der App | nach jeder Änderung (gebündelt, 1,5 s) und nach jedem iCloud-Import – im Vordergrund gebündelt, im Hintergrund sofort |
| Watch-Komplikation | Schnappschuss der Watch-App | nach Änderungen auf der Watch, beim Öffnen und Schließen der Watch-App (nur nach einer Änderung oder an einem neuen Tag) und nach einem iCloud-Import |
| ✓ im Widget | läuft in der App; sonst Warteschlange, die die App beim Öffnen abarbeitet | sofort im Widget, in der App beim nächsten Öffnen |
| Verbundene Apps (Theo, George, Nina, Finn) | nur über ein Gerät, auf dem beide Apps laufen und Thalia nachsieht (Start, Vordergrund, alle 5 Min. – am Mac auch im Hintergrund –, nach dem Abgleich, Tageswechsel, Meldung der App); Thalia legt das Gelesene als `x.<Quelle>.<Tag>` in iCloud ab | auf den anderen Geräten nach dem nächsten Abgleich |
| Wertung abgeschlossener Wochen | das iPhone wertet; Mac, Watch und iPad werten selbst nur nach eigener Eingabe, für Wochen ohne Health-Punkte (oder geteilt abgedeckt), nach ihrem ersten Abgleich und wenn alle Geräte 1.10.0 haben – und schicken dem iPhone immer eine Anfrage (`rescore.<Woche>`); eingefrorene nur über „Neu berechnen“ | das iPhone rechnet nach seinem nächsten Abgleich nach (höchstens 8 Anfragen je Lauf) |
| Erinnerungen | je Gerät geplant: Morgen, Abend und Woche je für die nächsten 7 Tage | ein anderswo abgeschlossener Tag bzw. eine abgeschlossene Woche nimmt die Erinnerung nach dem Abgleich weg |
| Sicherung | „Sicherung erstellen…“ von Hand; iPhone und Mac legen jede Woche selbst eine Datei in Application Support/Sicherungen ab – nicht in iCloud; nur „Letzte Sicherung“ (`backup.last`) geht über iCloud | „Letzte Sicherung … am iPhone“ nach dem Abgleich auf allen Geräten |
| Apple Health | **nur auf dem iPhone/iPad**, nie in iCloud (App-Store-Regel 5.1.3(ii)) – außer in der TestFlight-Version mit „Health-Werte mit Mac und Watch teilen“ (unten) | Mac und Watch zeigen „Wert aus Health auf dem iPhone“ |

## Health teilen (nur TestFlight)

Ist am iPhone (oder iPad) „Health-Werte mit Mac und Watch teilen“ an, teilt genau ein Gerät die übernommenen
Health-Werte der letzten 35 Tage und die Health-Vorschläge der letzten 3 Tage als `hshare.`-Datensätze. Mac, Watch und
iPad zählen sie wie übernommene Werte (eigene Einträge gehen vor), zeigen sie nur lesend mit „aus Health am iPhone“
(bzw. „am iPad“, wenn das iPad teilt) und werten abgedeckte Wochen selbst. Abgedeckt ist ein Tag nur innerhalb des
Fensters des teilenden Geräts und höchstens 34 Tage vor dem eigenen heute – ältere Tage löscht jedes Gerät einmal am
Tag. Prompts (Planungs-Prompt, „Bericht kopieren“ der Zielüberprüfung) nehmen die geteilten Werte nicht mit; der
Wochenbericht zeigt sie wie am iPhone. Schaltet ein zweites Gerät ein, übernimmt es nach Rückfrage, das erste schaltet
sich ab. Ausschalten löscht alle geteilten Tage. Ein App-Store-Build löscht beim Start und nach jedem Abgleich alle
`hshare.`-Datensätze und schreibt den Zustand aus; das Teilen gibt es nur, solange die TestFlight-Prüfung „erlaubt“
sagt (Debug, TestFlight). Vor dem App Store kommt dieser Abschnitt
weg (TASKS-v11 §1.4.12).

## Selbst prüfen

Einstellungen → iCloud & Daten → **Geräte im Abgleich**: jedes Gerät meldet sich beim Öffnen von Thalia
(höchstens alle 10 Minuten, nach einem Update sofort; der Mac auch beim Aktivieren und beim Öffnen des
Menüleisten-Fensters) mit seiner Version („iPhone · 1.10.0“). Steht bei einem anderen Gerät eine aktuelle Zeit, kommen
seine Daten an. Ein Gerät der letzten 30 Tage ohne 1.10.0 bekommt „Thalia 1.9 – bitte dort aktualisieren. Bis dahin
werten Mac und Watch abgeschlossene Wochen nicht selbst.“ Darüber steht „Gesendet: vor 1 Min. · Empfangen: vor 4 Min.“;
ist eine eigene Änderung seit 15 Minuten nicht gesendet: „Letzte Änderung noch nicht an iCloud gesendet“. Dauerhafte
Probleme (Notspeicher, nur lokal, nicht bei iCloud angemeldet, iCloud voll) zeigt eine Zeile über dem Inhalt, am Mac
unten in der Seitenleiste.

## 1.10.0 – was sich am Abgleich geändert hat (TASKS-v11)

- **Wer wertet:** siehe Tabelle. Abschließen am Mac, auf der Watch oder am iPad speichert die eigene Note und schickt
  dem iPhone eine Anfrage, auch für eine eingefrorene Woche („Am iPhone neu berechnen“ ebenso). Eingang, Zusammenführen,
  Nachtragen und Import gelten als Wartung: dabei wertet nur das iPhone, die anderen schicken nur die Anfrage. Schließt
  ein Import eine Woche ab (auch „Widerrufen“), gibt der Mac, die Watch oder das iPad ihr nur dann eine eigene Note, wenn
  sie keine Health-Werte liest (oder geteilt abgedeckt ist); sonst bleibt sie bis zum Abgleich ohne Note (die Ansichten
  zeigen den heutigen Stand) und das iPhone wertet sie auf Anfrage – ein frisch installiertes iPhone wertet eine solche
  Woche vor seiner Installation gar nicht. Was eine Sicherung nur auffüllt (Zieljahr, Katalog-Schalter, eine Woche, die
  iCloud noch nicht gebracht hat), trägt einen sehr alten Zeitstempel: kommt das Echte später über iCloud, gilt es.
- **Erster Abgleich:** ein Gerät gilt als abgeglichen, wenn 60 s nach einem erfolgreichen Import kein weiterer begann
  und ein anderes Gerät im Speicher steht; spätestens 24 h nach der Installation, nach einem Update von 1.9.0 sofort.
  Vorher wertet es nicht von selbst, trägt keine Kategorie-Noten nach, legt keine automatische Sicherung an, und der
  Import einer Sicherung warnt.
- **Neuinstallation:** ein frisch installiertes iPhone wertet Wochen mit Health-Punkten, die vor der Installation
  endeten, nicht neu – auch nicht auf Anfrage („KW44: Auf diesem iPhone fehlen die Health-Werte von damals – die
  Wertung bleibt.“). „Neu berechnen“ von Hand geht weiter.
- **Wartung ohne Widerrufen:** Geräte-Meldung, Eingang, Zusammenführen, Nachtragen und Anfragen laufen ohne Undo; ⌘Z
  nimmt nur eigene Eingaben zurück. Hat die Wartung etwas vereint, ist der Undo-Stapel danach leer.
- **Zusammenführen:** beim Start ganz, wenn der letzte volle Lauf 24 h her ist; sonst und nach jedem Abgleich nur die
  letzten 4 Wochen (Protokoll „Maintenance: full/recent, N ms“). Eingespielte
  Kopien von Power-Hours und Notizen werden mit ihren Originalen vereint – eine Änderung am Original nach der Sicherung
  bleibt. Wieder geöffnete Tage und Wochen schreiben auf die Kopie, die alle Geräte behalten. Löschen nimmt doppelte
  Kopien eines Punkts oder Messwerts mit; Wiederherstellen fragt, wenn es den Punkt in der Woche schon gibt.
- **Mac und verbundene Apps:** der Mac sieht alle 5 Minuten in der App Group nach, auch wenn eine andere App vorne ist.
- **Nach einem Hintergrund-Push** hat das iPhone Hintergrundzeit für den Abgleich; Erinnerungen an anderswo
  abgeschlossene Tage gehen sofort weg.
- **Siri, Kurzbefehle und Widget-✓** halten am iPhone nach dem Speichern bis zu 20 s Hintergrundzeit, bis iCloud
  gesendet hat (am Gerät noch ungeprüft – bis dahin bleibt die Grenze unten stehen).

## 1.6.1 – Sync-Prüfung (19. Nov. 2026)

Code-Prüfung aller Wege mit Gegenprüfung jedes Befunds; Produktions-Schema in iCloud enthält alle Felder.
Behoben:
- Mac-Menüleiste („☀ 73 %“) blieb nach Änderungen vom iPhone stehen, solange das Hauptfenster zu war.
- Abend-Erinnerung kam auf dem iPhone, obwohl der Tag am Mac schon abgeschlossen war.
- Health-Vorschläge (Schritte, Wasser, Schlaf) wurden nur einmal pro Tag gelesen.
- Ein neuer Punkt konnte die Markierungen eines gelöschten Punkts übernehmen (gleicher Code).
- ✓ von einem Gerät und Notiz vom anderen für denselben Punkt und Tag: eins von beiden ging verloren.
- Zusammenführen doppelter Tage/Wochen und Schreiben passen jetzt zusammen (keine Änderung auf einer Kopie, die gelöscht wird).
- Abgeschlossene Wochen: nur iPhone/iPad berechnen die Wertung neu (mit Health); Mac und Watch schoben sie hin und her.
  Seit 1.10.0 nur noch das iPhone: ein iPad wertet wie der Mac (TASKS-v11 §4 F1 – ohne Antwort gilt „iPad wie Mac“).
- „Meine Struktur einrichten“ auf einem neuen Gerät überschreibt keine eigenen Ziel-/Kategorietitel mehr.
- Widget nach Änderungen von Mac/Watch: Schnappschuss sofort statt nach 1,5 s (iOS konnte die App vorher schlafen legen).
- Watch: wird von iCloud im Hintergrund geweckt; Komplikation wird beim Verlassen der App geschrieben.
- Menüleisten-Fenster: Bereiche und „Zuletzt“ laden nach jedem Import neu.

## Bekannte Grenzen

- Derselbe Tageswert (Summe, z. B. Wasser) auf zwei Geräten **vor** dem Abgleich eingetragen: beide Einträge zählen.
- Woche per Import ersetzt, während ein anderes Gerät noch offline in die alte Woche einträgt: diese Einträge bleiben übrig.
- Dieselbe CSV (z. B. eine Sicherung) auf zwei Geräten eingespielt: Power-Hours und Notizen werden über ihre
  Herkunft zusammengeführt; Werte vergleicht Thalia 7 Tage lang nach jedem Abgleich, gleiche spätere Kopien gehen in
  „Zuletzt gelöscht“. Nie in ein Gerät einlesen, dessen erster iCloud-Abgleich noch läuft – der Import warnt dann.
- Neuinstallation: bis zum ersten fertigen Abgleich wertet das Gerät nicht von selbst; ein frisches iPhone behält die
  gespeicherte Note von Health-Wochen, die vor der Installation endeten.
- Gemischte Versionen: solange ein Gerät der letzten 30 Tage 1.9.0 hat, werten Mac, Watch und iPad nicht selbst.
  1.9.0 rechnet einige Regeln anders (TASKS-v11 §0.2 – Nacht-Zeitziele, „spätestens“, Wochenquote am leeren letzten
  Tag, „Schon gelesen bis Seite“); ein iPhone oder iPad mit 1.9.0 speichert nach jedem Import die Note der letzten 3
  abgeschlossenen Wochen nach den alten Regeln neu – bis alle Geräte 1.10.0 haben, kann eine Note dort zwischen zwei
  Werten wechseln. Ein Build aus Xcode meldet die Build-Nummer 1 und zählt deshalb wie eine alte Version.
- Tag oder Woche an einem Gerät wieder geöffnet, während ein anderes Gerät offline dieselbe noch einmal abschließt:
  nach dem Abgleich ist sie abgeschlossen (beim Zusammenführen gewinnt „abgeschlossen“).
- Siri/Kurzbefehle/Widget-✓ in einem kurzen Hintergrundlauf: andere Geräte sehen es manchmal erst, wenn die App einmal offen war.
- iCloud drosselt Hintergrund-Pushes; „sofort“ heißt meist Sekunden, manchmal Minuten.
