# Sync in Thalia – wie es läuft, was geprüft ist, was bekannt ist

Stand 1.6.1. Alle Daten liegen in deinem privaten iCloud (CloudKit, Container `iCloud.at.binisoft.thalia`).
Kein eigener Server. Jedes Gerät hat die ganze Datenbank und gleicht sie über iCloud ab.

## Wege

| Weg | Wie | Wann es ankommt |
|---|---|---|
| iPhone ↔ Mac ↔ iPad | SwiftData + CloudKit (privat) | Sekunden bis wenige Minuten; iCloud bündelt und drosselt |
| Apple Watch | eigene Kopie derselben iCloud-Datenbank | wenn die Watch-App offen ist oder iCloud sie im Hintergrund weckt (seit 1.6.1) |
| iPhone-Widgets | Schnappschuss in der App Group, geschrieben von der App | nach jeder Änderung und jedem iCloud-Import |
| Watch-Komplikation | Schnappschuss der Watch-App | nach Änderungen auf der Watch, beim Öffnen und Schließen der Watch-App |
| ✓ im Widget | läuft in der App; sonst Warteschlange, die die App beim Öffnen abarbeitet | sofort im Widget, in der App beim nächsten Öffnen |
| Apple Health | **nur auf dem iPhone/iPad**, nie in iCloud (App-Store-Regel 5.1.3(ii)) | Mac und Watch zeigen „Wert aus Health auf dem iPhone“ |

## Selbst prüfen

Einstellungen → iCloud & Daten → **Geräte im Abgleich**: jedes Gerät meldet sich beim Öffnen von Thalia
(höchstens alle 10 Minuten). Steht bei einem anderen Gerät eine aktuelle Zeit, kommen seine Daten an.

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
- „Meine Struktur einrichten“ auf einem neuen Gerät überschreibt keine eigenen Ziel-/Kategorietitel mehr.
- Widget nach Änderungen von Mac/Watch: Schnappschuss sofort statt nach 1,5 s (iOS konnte die App vorher schlafen legen).
- Watch: wird von iCloud im Hintergrund geweckt; Komplikation wird beim Verlassen der App geschrieben.
- Menüleisten-Fenster: Bereiche und „Zuletzt“ laden nach jedem Import neu.

## Bekannte Grenzen

- Derselbe Tageswert (Summe, z. B. Wasser) auf zwei Geräten **vor** dem Abgleich eingetragen: beide Einträge zählen.
- Woche per Import ersetzt, während ein anderes Gerät noch offline in die alte Woche einträgt: diese Einträge bleiben übrig.
- Dieselbe CSV auf zwei Geräten vor dem Abgleich importiert: Power-Hours und Notizen doppelt (im Papierkorb löschbar).
- Siri/Kurzbefehle/Widget-✓ in einem kurzen Hintergrundlauf: andere Geräte sehen es manchmal erst, wenn die App einmal offen war.
- iCloud drosselt Hintergrund-Pushes; „sofort“ heißt meist Sekunden, manchmal Minuten.
