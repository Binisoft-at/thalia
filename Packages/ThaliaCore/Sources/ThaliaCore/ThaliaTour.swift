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

    public init() {}
}

/// Thalia's interactive tour (German). To teach a new feature: add a step with
/// `since: version + 1` and bump `version`; people who took the tour get only the new steps.
public enum ThaliaTour {
    public static let version = 3

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
            body: "Die Tour findest du jederzeit wieder unter Einstellungen → Tour (am Mac: Hilfe → Thalia-Tour). Neue Funktionen erscheinen hier als kurzes „Neu in Thalia“."
        ),
        steps: [
            TourStep(
                id: "create", since: 2, symbol: "plus.circle", title: "Alles beginnt unten bei +",
                body: "Tippe unten auf +. Von dort erfasst du Power-Hours, Messwerte und Notizen – mit dem Daumen erreichbar.",
                macBody: "Klicke in der Symbolleiste auf + oder drücke ⇧⌘N. Von dort erfasst du Power-Hours, Messwerte und Notizen.",
                goal: .isTrue(\.isCreateOpen)
            ),
            TourStep(
                id: "mark", since: 2, symbol: "checkmark.circle", title: "Punkte mit einem Tipp",
                body: "Schließe das Fenster und tippe bei einem Punkt direkt auf ✓, ½, ✗ oder –. Kein Halten nötig. Wische zur nächsten Kategorie.",
                macBody: "Klicke bei einem Punkt direkt auf ✓, ½, ✗ oder –. Links wählst du die Kategorie.",
                goal: .changed(\.markSummary)
            ),
            TourStep(
                id: "work", since: 2, symbol: "briefcase", title: "Power-Hours erfassen",
                body: "+ → Power-Hours: Kategorie wählen, Anzahl (0,25 bis 2 PH) tippen, wofür – fertig. Nachhilfe zählt auch in PH.",
                macBody: "⌘N: Kategorie, Anzahl (0,25 bis 2 PH), wofür – fertig. Nachhilfe zählt auch in PH.",
                goal: .increased(\.workCount)
            ),
            TourStep(
                id: "measure", since: 2, symbol: "plus.forwardslash.minus", title: "Messwert eintragen",
                body: "Bei einem Messwert direkt die Zahl eintippen oder + drücken. Messwerte sind keine Punkte – sie schlagen nur einen Haken vor.",
                macBody: "Bei einem Messwert direkt die Zahl eintippen oder + klicken.",
                goal: .changed(\.entrySummary)
            ),
            TourStep(
                id: "undo", symbol: "arrow.uturn.backward", title: "Fehler sind kein Problem",
                body: "Einen Power-Hour-Eintrag (bei seiner Kategorie) nach links wischen und löschen – dann im Hinweis auf Widerrufen.",
                macBody: "Rechtsklick auf einen Power-Hour-Eintrag → Löschen, dann im Hinweis auf Widerrufen – oder ⌘Z.",
                goal: .undone(\.trashedWorkCount)
            ),
            TourStep(
                id: "close", since: 2, symbol: "moon.stars", title: "Den Tag abschließen",
                body: "Abends: „Tag abschließen“. Erst dann rechnet Thalia die Tageswertung – wenn alles ausgefüllt ist. Bewusst, nicht automatisch.",
                macBody: "Abends: „Tag abschließen“ (⌘↩). Erst dann rechnet Thalia die Tageswertung.",
                goal: .isTrue(\.isCloseDayOpen)
            ),
            TourStep(
                id: "weekly-goals", since: 3, symbol: "chart.bar.fill", title: "Wochenziele zählen von selbst",
                body: "Oben in einer Kategorie stehen ihre Wochenziele als Balken: Woche, „heute +x“ und die Tempo-Marke. Trag einfach die Power-Hours oder den Wert ein – „daran gearbeitet“ hakt Thalia selbst ab und bewertet am Wochenende rückwirkend. Nebensachen liegen eingeklappt unter „Weitere“, mit dem Listen-Symbol setzt du alles Offene auf einmal.",
                macBody: "Oben in einer Kategorie stehen ihre Wochenziele als Balken. Trag den Wert ein – „daran gearbeitet“ hakt Thalia selbst ab. Nebensachen liegen unter „Weitere“, das Listen-Symbol setzt alles Offene auf einmal."
            ),
            TourStep(
                id: "share", since: 3, symbol: "square.and.arrow.up", title: "Teilen und PDF",
                body: "Nach „Tag abschließen“ oder „Woche abschließen“: als Bild teilen (Vorlagen Aurora, Klar, Nacht) – oder die Woche als PDF mit allen Kategorien."
            ),
            TourStep(
                id: "week", since: 2, symbol: "calendar.badge.plus", title: "Sonntag: die neue Woche",
                body: "Woche → Woche abschließen → Planungs-Prompt kopieren → ChatGPT → die CSV unter + → Wochenplan importieren einfügen. Eine ersetzte Woche landet im Archiv."
            ),
            TourStep(
                id: "everywhere", since: 2, symbol: "applewatch", title: "Überall dabei",
                body: "Thalia synchronisiert über dein iCloud mit Mac und Apple Watch. Widgets und das Kontrollzentrum bringen dich mit einem Tipp zum Erfassen."
            ),
        ]
    )
}

/// The small snapshot widgets and the watch read from the shared App Group – never the full data.
public struct TodaySummary: Codable, Equatable, Sendable {
    public static let fileName = "today-v2.json"

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
    )

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

    public static let storageKey = "thalia.reminders"

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

    /// The repeating notifications to schedule (block-end reminders are scheduled when a block starts).
    public func requests() -> [Request] {
        var result: [Request] = []
        if morning {
            for day in DayMask(rawValue: morningDays).days {
                result.append(Request(id: "thalia.morning.\(day.rawValue)", gregorianWeekday: day.gregorianWeekday,
                                      hour: morningMinutes / 60, minute: morningMinutes % 60,
                                      title: "Guten Morgen", body: "Der erste geplante Block wartet. Pünktlich starten – der Rest ergibt sich.",
                                      destination: "today"))
            }
        }
        if evening {
            result.append(Request(id: "thalia.evening", gregorianWeekday: nil, hour: eveningMinutes / 60, minute: eveningMinutes % 60,
                                  title: "Tagesabschluss", body: "Belege prüfen, Fehlendes ergänzen, kurz reflektieren.",
                                  destination: "close-day"))
        }
        if weekly, let day = Weekday(rawValue: weeklyDay) {
            result.append(Request(id: "thalia.weekly", gregorianWeekday: day.gregorianWeekday, hour: weeklyMinutes / 60, minute: weeklyMinutes % 60,
                                  title: "Wochenabschluss", body: "Woche abschließen und die nächste planen – wiederholen statt steigern.",
                                  destination: "week"))
        }
        return result
    }

}
