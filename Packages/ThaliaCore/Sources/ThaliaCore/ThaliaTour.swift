import Foundation
import BinisoftKitCore

/// What the tour's practice page looks like right now (built from the practice store after every change).
public struct ThaliaTourSnapshot: Equatable, Sendable {
    /// "✓ 12 · ½ 3 · ✗ 2 · – 1": changes with every tap on a mark.
    public var markSummary = ""
    public var workCount = 0
    public var trashedWorkCount = 0
    public var entryCount = 0
    /// Changes whenever a value is typed, stepped or cleared (typing replaces the day's entry).
    public var entrySummary = ""
    public var noteCount = 0
    public var isCreateOpen = false
    public var isCloseDayOpen = false
    /// "Heute im Blick" is open: the sheet on iPhone/iPad, the right column on the Mac (v7).
    public var isGlanceOpen = false

    public init() {}
}

/// Thalia's interactive tour (German). To teach a new feature: add a step with
/// `since: version + 1` and bump `version`; people who took the tour get only the new steps.
public enum ThaliaTour {
    public static let version = 9

    /// v9: 17 cards in the full tour (welcome, 15 steps, finish); the step with `since: 9` (Archiv-Wochen)
    /// makes up "Neu in Thalia" after 1.7. v8 added three (Krank & Urlaub, Vergangene Wochen, PDF-Bericht).
    /// v7 had 13 cards: colours, the "Wofür" rule, weekly goals, sharing and PDF moved into other cards then.
    public static let catalog = TourCatalog<ThaliaTourSnapshot>(
        version: version,
        welcome: TourStep(
            id: "welcome", symbol: "hand.wave", title: "Willkommen bei Thalia",
            body: "Zwei Minuten, zum Ausprobieren. Das ist eine Übungsseite mit einer Beispielwoche – nichts hier berührt deine echten Einträge. Jeder Schritt hakt sich selbst ab, sobald du ihn probiert hast."
        ),
        whatsNew: TourStep(
            id: "whats-new", symbol: "sparkles", title: "Neu in Thalia",
            body: "Ein paar neue Dinge zum Ausprobieren – auf einer Übungsseite, ohne deine echten Einträge."
        ),
        finish: TourStep(
            id: "finish", symbol: "checkmark.seal", title: "Bereit",
            body: "Die Tour findest du jederzeit wieder unter Einstellungen → Thalia-Tour (am Mac: Hilfe → Thalia-Tour). Neue Funktionen erscheinen hier als kurzes „Neu in Thalia“."
        ),
        steps: [
            TourStep(
                id: "create", since: 2, symbol: "plus.circle", title: "Alles beginnt unten bei +",
                body: "Tippe unten auf +. Von dort erfasst du Power-Hours, Ausgaben und Notizen – jedes Fenster zeigt oben, für welchen Tag es zählt.",
                macBody: "Klicke in der Symbolleiste auf „Erfassen“ oder drücke ⇧⌘N. Jedes Fenster zeigt oben, für welchen Tag es zählt.",
                goal: .isTrue(\.isCreateOpen)
            ),
            TourStep(
                id: "day", since: 7, symbol: "calendar", title: "Welcher Tag gerade gilt",
                body: "Oben stehen Datum, Tagestyp und die Besonderheit aus dem Plan. Um Mitternacht springt Thalia selbst auf den neuen Tag. Blätterst du zurück, zeigt die Leiste unten „Zu heute“. Ist gestern noch offen, erinnert dich morgens ein Hinweis mit „Nachtragen“ und „Abschließen“.",
                macBody: "Oben stehen Datum, Tagestyp und die Besonderheit aus dem Plan. Um Mitternacht springt Thalia selbst auf den neuen Tag, ⇧⌘T führt zu heute. Ist gestern noch offen, steht links unten „Nachtragen“ und „Abschließen“."
            ),
            TourStep(
                id: "excused", since: 8, symbol: "cross.case", title: "Krank & Urlaub",
                body: "Oben auf den Titel tippen → Tagestyp → „Krank“ oder „Urlaub“ (in der Woche: lange auf den Tag drücken). Der Tag zählt dann nicht in die Wochenwertung: nichts ist fällig, keine Abend-Erinnerung, die Spalte in der Woche ist grau. Was deshalb in der Woche nicht mehr ging, zählt halb – 3× Training, 2 gemacht, ab Freitag krank: das dritte zählt als Teilweise. Wochenziele schrumpfen mit, etwa „4,8 statt 8 PH – 2 Tage krank“.",
                macBody: "Titelmenü in der Symbolleiste → Tagestyp → „Krank“ oder „Urlaub“ (in der Woche: Rechtsklick auf den Tag). Der Tag zählt dann nicht in die Wochenwertung: nichts ist fällig, keine Abend-Erinnerung, die Spalte in der Woche ist grau. Was deshalb nicht mehr ging, zählt halb – 3× Training, 2 gemacht, ab Freitag krank: das dritte zählt als Teilweise. Wochenziele schrumpfen mit („4,8 statt 8 PH – 2 Tage krank“)."
            ),
            TourStep(
                id: "mark", since: 7, symbol: "checkmark.circle", title: "Punkte mit einem Tipp",
                body: "Tippe bei einem Punkt auf Erledigt, Teilweise, Nicht erledigt oder Entfällt. Beantwortete Zeilen werden ruhig, offene bleiben bunt. Wische zur nächsten Kategorie oder tippe unten auf „Weiter“.",
                macBody: "Klicke auf Erledigt, Teilweise, Nicht erledigt oder Entfällt – oder drücke 1, 2, 3, 4. Die Auswahl springt zum nächsten offenen Punkt, ⌥⌘↓ wechselt die Kategorie.",
                goal: .changed(\.markSummary)
            ),
            TourStep(
                id: "work", since: 7, symbol: "bolt.fill", title: "Power-Hours mit „Wofür“",
                body: "+ → Power-Hours: oben stehen deine letzten drei Einträge zum Antippen. Sonst Bereich, Menge und Wofür – Return sichert. In den Arbeits-Kategorien steht die Zeile „Menge · Wofür · +“ direkt unter dem Wochenziel, das von selbst mitzählt.",
                macBody: "⌘N: oben die letzten drei Einträge zum Anklicken, sonst Bereich, Menge und Wofür – Return sichert. Das Wochenziel zählt von selbst mit.",
                goal: .increased(\.workCount)
            ),
            TourStep(
                id: "measure", since: 7, symbol: "plus.forwardslash.minus", title: "Werte und Ausgaben eintragen",
                body: "Bei einem Messwert die Zahl eintippen – „Fertig“ über dem Ziffernblock speichert sofort. Ausgaben: Betrag, „Weiter“, Wofür – Vorschläge kommen aus den letzten Monaten. Ein Tipp auf eine Ausgabe ändert sie.",
                macBody: "Bei einem Messwert die Zahl eintippen, Return speichert. Ausgaben: Betrag und Wofür – Vorschläge aus den letzten Monaten; ein Klick auf eine Ausgabe ändert sie.",
                goal: .changed(\.entrySummary)
            ),
            TourStep(
                id: "undo", symbol: "arrow.uturn.backward", title: "Fehler sind kein Problem",
                body: "Einen Power-Hour-Eintrag nach links wischen und löschen – dann im Hinweis auf „Widerrufen“. Der Hinweis erscheint immer im obersten Fenster.",
                macBody: "Rechtsklick auf einen Power-Hour-Eintrag → Löschen, dann im Hinweis auf „Widerrufen“ – oder ⌘Z.",
                goal: .undone(\.trashedWorkCount)
            ),
            TourStep(
                id: "close", since: 2, symbol: "moon.stars", title: "Den Tag abschließen",
                body: "Abends: „Tag abschließen“. Erst dann rechnet Thalia die Tageswertung. Danach kannst du den Tag als Bild teilen oder als PDF ansehen.",
                macBody: "Abends: „Tag abschließen“ (⌘↩, zum Bestätigen nochmal ⌘↩). Danach als Bild teilen oder als PDF sichern (⌘S) und drucken (⌘P).",
                goal: .isTrue(\.isCloseDayOpen)
            ),
            TourStep(
                id: "glance", since: 7, symbol: "eye", title: "Heute im Blick",
                body: "Tippe oben auf den Ring: was noch zu tun ist, „Diese Woche noch“, die Wochenziele mit Tempo und – sobald alles erfasst ist – „Tag abschließen“. Fokus und Ausgaben öffnen sich darin; Fokus blättert durch die Wochen und zeigt die letzten 8.",
                macBody: "⌘0 blendet „Heute im Blick“ rechts ein, während du weiterarbeitest. Fokus (⌘5) blättert durch die Wochen und zeigt die letzten 8, Ausgaben (⌘6) die ganze Woche nach Zweck.",
                goal: .isTrue(\.isGlanceOpen)
            ),
            TourStep(
                id: "week", since: 7, symbol: "calendar.badge.plus", title: "Sonntag: Woche abschließen und planen",
                body: "Nach dem Tagesabschluss am Sonntag führt „Weiter: Woche abschließen“ direkt dorthin. Dann „1 · Prompt kopieren“ – er enthält den Plan der letzten Woche – und „2 · CSV einfügen“. Fällt die Planung aus: „Wie KW … wiederholen“. Eine ersetzte Woche kommt ins Archiv und lässt sich widerrufen.",
                macBody: "Nach dem Tagesabschluss am Sonntag führt „Weiter: Woche abschließen“ dorthin, ⇧⌘↩ schließt sie ab. Dann „1 · Prompt kopieren“ und „2 · CSV einfügen“; fällt die Planung aus: „Wie KW … wiederholen“."
            ),
            TourStep(
                id: "past-weeks", since: 8, symbol: "clock.arrow.circlepath", title: "Vergangene Wochen",
                body: "Woche → … → „Vergangene Woche nachtragen…“, drei Wege: „Plan übernehmen“, dann selbst abhaken und abschließen; „Mit ChatGPT“ – Prompt kopieren, Fotos, PDFs oder Tabellen auch vieler Wochen dazulegen, die CSV einfügen, Vorschau je Woche – die Wochen werden gleich abgeschlossen; oder „Nur Wertung“ für eine Zahl vom Papier. Abgeschlossene Wochen zählen im Rückblick und bei den Zielen.",
                macBody: "Ablage → „Vergangene Woche nachtragen…“, drei Wege: „Plan übernehmen“, dann in der Tabelle abhaken und abschließen; „Mit ChatGPT“ – Prompt kopieren, Fotos, PDFs oder Tabellen auch vieler Wochen dazulegen, die CSV einfügen, Vorschau je Woche – die Wochen werden gleich abgeschlossen; oder „Nur Wertung“ für eine Zahl vom Papier. Abgeschlossene Wochen zählen im Rückblick und bei den Zielen."
            ),
            TourStep(
                id: "archive", since: 9, symbol: "archivebox", title: "Archiv-Wochen",
                body: "Woche → … → „Vergangene Woche nachtragen…“ → „Mit ChatGPT“: Eine alte Woche darf nur den Wochenwert und Noten 0–10 der Kategorien und Jahresziele haben – ohne Punkte ist nichts offen oder verpasst. Die Woche zeigt dann die Karte „Archiv“: Die Wertung laut Unterlagen bleibt, wie sie war; „Nach heutigen Regeln“ rechnet aus den Kategoriennoten, ohne Krank- und Urlaubstage. Alte Bezeichnungen stehen unter „Ohne Zuordnung (Archiv)“. Für einen erneuten Import: „Archivdaten dieser Wochen ersetzen“ – Widerrufen holt alles zurück.",
                macBody: "Ablage → „Vergangene Woche nachtragen…“ → „Mit ChatGPT“: Eine alte Woche darf nur den Wochenwert und Noten 0–10 der Kategorien und Jahresziele haben – ohne Punkte ist nichts offen oder verpasst. Die Woche zeigt dann „Archiv“ (Noten Mo–So mit Ø (n), rechts beide Wertungen): Die Wertung laut Unterlagen bleibt, wie sie war; „Nach heutigen Regeln“ rechnet aus den Kategoriennoten, ohne Krank- und Urlaubstage. Alte Bezeichnungen stehen unter „Ohne Zuordnung (Archiv)“. Für einen erneuten Import: „Archivdaten dieser Wochen ersetzen“ – Widerrufen (⌘Z) holt alles zurück."
            ),
            TourStep(
                id: "review", since: 7, symbol: "flag", title: "Ziele über Monate",
                body: "Im Ziel-Detail zeigt der Verlauf 12 Wochen, ein Halbjahr oder das ganze Zieljahr – mit Messwerten und Ziellinie. Drei Wochen vor der Zielüberprüfung hilft „Zielüberprüfung vorbereiten“, samt aller geparkten Ideen."
            ),
            TourStep(
                id: "range-pdf", since: 8, symbol: "doc.richtext", title: "PDF-Bericht",
                body: "Rückblick → „PDF-Bericht“ (oder Woche → … → „Mehrere Wochen als PDF…“): Zeitraum wählen – letzte 4, 8 oder 13 Wochen, Zieljahr bis heute oder von–bis – und den Umfang. Thalia baut den Bericht Seite für Seite: Deckblatt mit Ø und Trend je Ziel, eine Zeile je Woche, Power-Hours je Bereich, auf Wunsch jede Woche mit ihren Tabellen. Dann teilen.",
                macBody: "Ablage → „Zeitraum als PDF…“ (⌥⌘P) oder Rückblick → „PDF-Bericht“: Zeitraum und Umfang wählen. Thalia baut den Bericht Seite für Seite – Deckblatt mit Ø und Trend je Ziel, eine Zeile je Woche, Power-Hours je Bereich, Lesezeichen je Woche. Dann sichern (⌘S), drucken (⌘P) oder teilen."
            ),
            TourStep(
                id: "everywhere", since: 7, symbol: "applewatch", title: "Überall dabei",
                body: "Auf der Watch stehen Offenes und Zähler auf der ersten Seite, Werte stellst du mit der Krone ein; die Komplikation zeigt Ring, Offenes und PH. Im Widget hakst du offene Punkte direkt ab. Siri fragt bei Power-Hours nach dem Bereich, „Ausgabe in Thalia“ bucht Betrag und Wofür – auf Wunsch automatisch nach jeder Kartenzahlung.",
                macBody: "Oben in der Menüleiste zeigt Thalia den Tag und erfasst Power-Hours und Ausgaben, ohne das Fenster zu öffnen. Auf iPhone und Watch: Widgets zum Abhaken, Komplikation, Siri."
            ),
        ]
    )
}

/// The small snapshot widgets and the watch read from the shared App Group – never the full data.
public struct TodaySummary: Codable, Equatable, Sendable {
    public static let fileName = "today-v3.json"

    public struct MeasureLine: Codable, Equatable, Sendable {
        public var title: String
        public var value: String
        public var target: String
        /// true met · false missed · nil no target/value yet
        public var met: Bool?

        public init(title: String, value: String, target: String, met: Bool?) {
            self.title = title
            self.value = value
            self.target = target
            self.met = met
        }
    }

    public var day: String
    public var weekLabel: String
    /// Only set once the day is closed (the score is calculated when the day is done).
    public var dayScore: Double?
    public var weekScore: Double?
    /// Share of today's due items filled in (0…1).
    public var fill: Double
    public var powerHours: Double
    public var isClosed: Bool
    /// The first category that still has open items ("2.1 Mentale Routinen").
    public var nextCategory: String?
    public var measures: [MeasureLine]
    /// Annual goals 1–10: this week's score (nil = not complete yet).
    public var goalScores: [Double?]
    public var goalTitles: [String]
    public var updatedAt: Date

    /// A weekly target on the large widget (v5).
    public struct GoalLine: Codable, Equatable, Sendable {
        public var title: String
        public var value: Double
        public var target: Double
        public var unit: String
        public var categoryKey: String

        public init(title: String, value: Double, target: Double, unit: String, categoryKey: String) {
            self.title = title
            self.value = value
            self.target = target
            self.unit = unit
            self.categoryKey = categoryKey
        }

        public var fraction: Double { target > 0 ? min(1, value / target) : 0 }
    }

    /// The next open items of today ("1.1 Protein im Zielbereich"), at most five (v5).
    public var open: [String] = []
    public var openCount: Int = 0
    public var weekly: [GoalLine] = []
    public var powerHoursWeek: Double = 0
    /// Sum of the weekly power-hour targets, if the plan has any.
    public var powerHoursTarget: Double?
    /// Today's and the week's spending, if the plan has a € measurement.
    public var expensesToday: Double?
    public var expensesWeek: Double?

    // v7 – all optional, so snapshots of older app versions stay readable.
    /// The ISO day ("2026-11-16") this snapshot is about (R4).
    public var dayKey: String? = nil
    /// 0…1 element: the snapshot written ahead for tomorrow (R4).
    public var nextDay: [TodaySummary]? = nil
    /// Neutral "Neuer Tag" state: the app hasn't written today yet (R4).
    public var isNewDay: Bool? = nil
    /// Item keys ("2026-W47|1.1-03"), parallel to `open` (R87).
    public var openKeys: [String]? = nil
    /// Required items due today, for the optimistic fill after a tick in the widget (R87).
    public var dueCount: Int? = nil
    /// Day type and the plan's note for the day ("Besonderheit", R90).
    public var dayType: String? = nil
    public var dayNote: String? = nil
    /// false: no plan for this week (R5).
    public var hasPlan: Bool? = nil
    /// n×-per-week items still missing this week (R5).
    public var weeklyOpenCount: Int? = nil

    public init(day: String, weekLabel: String, dayScore: Double?, weekScore: Double?, fill: Double, powerHours: Double,
                isClosed: Bool, nextCategory: String?, measures: [MeasureLine], goalScores: [Double?], goalTitles: [String],
                updatedAt: Date) {
        self.day = day
        self.weekLabel = weekLabel
        self.dayScore = dayScore
        self.weekScore = weekScore
        self.fill = fill
        self.powerHours = powerHours
        self.isClosed = isClosed
        self.nextCategory = nextCategory
        self.measures = measures
        self.goalScores = goalScores
        self.goalTitles = goalTitles
        self.updatedAt = updatedAt
    }

    public static let placeholder = TodaySummary(
        day: "Mo, 2. Nov.", weekLabel: "KW45", dayScore: nil, weekScore: 7.1, fill: 0.62, powerHours: 3.5, isClosed: false,
        nextCategory: "2.1 Mentale Routinen",
        measures: [
            MeasureLine(title: "TEREA", value: "3 Stk.", target: "≤ 6", met: true),
            MeasureLine(title: "Seiten", value: "4 Seiten", target: "≥ 10", met: false),
        ],
        goalScores: [7.0, 8.1, 6.4, 7.8, 6.0, 7.5, 6.9, 8.4, 5.0, 8.8],
        goalTitles: Template.goals.map(\.title),
        updatedAt: Date(timeIntervalSince1970: 0)
    ).with {
        $0.open = ["2.1 Atemübung", "2.2 Ins Journal eingetragen", "4 Bildschirm aus um 22:30"]
        $0.openCount = 7
        $0.weekly = [
            GoalLine(title: "stammloop", value: 5, target: 8, unit: "PH", categoryKey: "3.2"),
            GoalLine(title: "Zweite Aufschläge", value: 60, target: 100, unit: "Stück", categoryKey: "1.2"),
        ]
        $0.powerHoursWeek = 14.5
        $0.powerHoursTarget = 28
        $0.expensesToday = 23.4
        $0.expensesWeek = 141
    }

    /// A copy with changes (keeps the long initialiser stable).
    public func with(_ change: (inout TodaySummary) -> Void) -> TodaySummary {
        var copy = self
        change(&copy)
        return copy
    }

    /// Same content ignoring the time, so widgets reload only when something changed.
    public func hasSameContent(as other: TodaySummary?) -> Bool {
        guard var other else { return false }
        other.updatedAt = updatedAt
        return other == self
    }

    /// "62 %"
    public var fillText: String { "\(Int((fill * 100).rounded())) %" }
    /// "62 % ausgefüllt" / "abgeschlossen"
    public var statusText: String { isClosed ? "abgeschlossen" : "\(fillText) ausgefüllt" }

    /// The snapshot to show on `today` (R4): this one when it is about today, the one written ahead
    /// for tomorrow once that has come, a snapshot of an older app version (no `dayKey`) when it was
    /// written today – otherwise a neutral "Neuer Tag".
    public func resolved(for today: DayKey) -> TodaySummary {
        if let dayKey {
            if dayKey == today.string { return self }
            if let next = nextDay?.first, next.dayKey == today.string { return next }
            return newDay(today)
        }
        return DayKey(date: updatedAt) == today ? self : newDay(today)
    }

    /// Neutral state for a day the app hasn't written yet: nothing filled in, nothing open, no score.
    /// The week's figures stay while `today` is in the same week.
    public func newDay(_ today: DayKey) -> TodaySummary {
        let shownDay = dayKey.flatMap { DayKey($0) } ?? DayKey(date: updatedAt)
        let sameWeek = shownDay.week == today.week
        var copy = self
        copy.day = today.shortLabel
        copy.dayKey = today.string
        copy.dayScore = nil
        copy.fill = 0
        copy.powerHours = 0
        copy.isClosed = false
        copy.nextCategory = nil
        copy.measures = measures.map { MeasureLine(title: $0.title, value: "–", target: $0.target, met: nil) }
        copy.open = []
        copy.openKeys = []
        copy.openCount = 0
        copy.dueCount = 0
        copy.expensesToday = nil
        copy.dayType = nil
        copy.dayNote = nil
        copy.nextDay = nil
        copy.isNewDay = true
        if !sameWeek {
            copy.weekLabel = today.week.label
            copy.weekScore = nil
            copy.goalScores = goalScores.map { _ in nil }
            copy.weekly = weekly.map { GoalLine(title: $0.title, value: 0, target: $0.target, unit: $0.unit, categoryKey: $0.categoryKey) }
            copy.powerHoursWeek = 0
            copy.expensesWeek = nil
            copy.weeklyOpenCount = nil
            copy.hasPlan = nil
        }
        return copy
    }

    /// Optimistic state right after ✓ in the widget (R87): the row leaves the open list, one less is
    /// open and the fill moves up by one due item. Unknown keys change nothing.
    public func markingDone(itemKey: String) -> TodaySummary {
        guard var keys = openKeys, let index = keys.firstIndex(of: itemKey) else { return self }
        var copy = self
        keys.remove(at: index)
        copy.openKeys = keys
        if index < open.count { copy.open.remove(at: index) }
        copy.openCount = max(0, openCount - 1)
        if let due = dueCount, due > 0 {
            copy.fill = min(1, fill + 1 / Double(due))
        }
        return copy
    }
}

/// A tick from the widget (R87), queued in the App Group until the app applies it.
public struct WidgetMarkAction: Codable, Equatable, Sendable {
    /// "2026-W47|1.1-03"
    public var itemKey: String
    /// "2026-11-16"
    public var dayKey: String
    public var createdAt: Date

    public init(itemKey: String, dayKey: String, createdAt: Date = Date()) {
        self.itemKey = itemKey
        self.dayKey = dayKey
        self.createdAt = createdAt
    }

    /// "2026-W47"
    public var weekKey: String {
        guard let bar = itemKey.firstIndex(of: "|") else { return "" }
        return String(itemKey[..<bar])
    }

    /// "1.1-03"
    public var itemCode: String {
        guard let bar = itemKey.firstIndex(of: "|") else { return itemKey }
        return String(itemKey[itemKey.index(after: bar)...])
    }
}

/// Reminders (local notifications): a prompt start in the morning, the evening review and the
/// Sunday weekly review.
public struct ReminderSettings: Codable, Equatable, Sendable {
    public var morning: Bool = true
    public var morningMinutes: Int = 8 * 60 + 15
    public var morningDays: Int = DayMask.workdays.rawValue
    public var evening: Bool = true
    public var eveningMinutes: Int = 21 * 60 + 45
    public var weekly: Bool = true
    public var weeklyDay: Int = Weekday.sunday.rawValue
    public var weeklyMinutes: Int = 17 * 60

    public init() {}

    enum CodingKeys: String, CodingKey {
        case morning, morningMinutes, morningDays, evening, eveningMinutes, weekly, weeklyDay, weeklyMinutes
    }

    /// Every field optional, so settings stored by older versions stay readable.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = ReminderSettings()
        morning = try container.decodeIfPresent(Bool.self, forKey: .morning) ?? defaults.morning
        morningMinutes = try container.decodeIfPresent(Int.self, forKey: .morningMinutes) ?? defaults.morningMinutes
        morningDays = try container.decodeIfPresent(Int.self, forKey: .morningDays) ?? defaults.morningDays
        evening = try container.decodeIfPresent(Bool.self, forKey: .evening) ?? defaults.evening
        eveningMinutes = try container.decodeIfPresent(Int.self, forKey: .eveningMinutes) ?? defaults.eveningMinutes
        weekly = try container.decodeIfPresent(Bool.self, forKey: .weekly) ?? defaults.weekly
        weeklyDay = try container.decodeIfPresent(Int.self, forKey: .weeklyDay) ?? defaults.weeklyDay
        weeklyMinutes = try container.decodeIfPresent(Int.self, forKey: .weeklyMinutes) ?? defaults.weeklyMinutes
    }

    public static let storageKey = "thalia.reminders"

    /// The Mac starts with every reminder off (R80).
    public static let macDefault: ReminderSettings = {
        var settings = ReminderSettings()
        settings.morning = false
        settings.evening = false
        settings.weekly = false
        return settings
    }()

    /// Notification action "In 30 Min." and the category that carries it (R80).
    public static let snoozeActionID = "thalia.snooze"
    public static let eveningCategoryID = "thalia.evening"
    public static let snoozeMinutes = 30

    /// "thalia.evening.2026-11-16"
    public static func eveningID(_ day: DayKey) -> String { "thalia.evening.\(day.string)" }

    /// A one-off notification on a given day (the evening reminder, R80).
    public struct DatedRequest: Equatable, Sendable {
        public let id: String
        public let day: DayKey
        public let hour: Int
        public let minute: Int
        public let title: String
        public let body: String
        /// "close-day:2026-11-16"
        public let destination: String
    }

    /// The evening reminder as one notification per day from `start` for `count` days, closed days
    /// left out; empty when the evening reminder is off (R80).
    public func eveningRequests(from start: DayKey, count: Int = 7, isClosed: (DayKey) -> Bool) -> [DatedRequest] {
        guard evening, count > 0 else { return [] }
        return (0..<count).map { start.adding(days: $0) }.filter { !isClosed($0) }.map { day in
            DatedRequest(id: ReminderSettings.eveningID(day), day: day, hour: eveningMinutes / 60, minute: eveningMinutes % 60,
                         title: "Tagesabschluss", body: "Belege prüfen, Fehlendes ergänzen, kurz reflektieren.",
                         destination: "close-day:\(day.string)")
        }
    }

    public struct Request: Equatable, Sendable {
        public let id: String
        /// Apple's weekday (Sunday = 1); nil = every day.
        public let gregorianWeekday: Int?
        public let hour: Int
        public let minute: Int
        public let title: String
        public let body: String
        /// Where tapping it leads ("today", "close-day", "week").
        public let destination: String
    }

    /// The repeating notifications to schedule: the mornings and the weekly review. The evening is
    /// planned per day (`eveningRequests`), so a closed day gets none (R80).
    public func requests() -> [Request] {
        var result: [Request] = []
        if morning {
            for day in DayMask(rawValue: morningDays).days {
                result.append(Request(id: "thalia.morning.\(day.rawValue)", gregorianWeekday: day.gregorianWeekday,
                                      hour: morningMinutes / 60, minute: morningMinutes % 60,
                                      title: "Guten Morgen", body: "Kurz in Thalia schauen: was heute ansteht – und ob gestern noch offen ist.",
                                      destination: "today"))
            }
        }
        if weekly, let day = Weekday(rawValue: weeklyDay) {
            result.append(Request(id: "thalia.weekly", gregorianWeekday: day.gregorianWeekday, hour: weeklyMinutes / 60, minute: weeklyMinutes % 60,
                                  title: "Wochenabschluss", body: "Woche abschließen und die nächste planen – wiederholen statt steigern.",
                                  destination: "close-week"))
        }
        return result
    }

}
