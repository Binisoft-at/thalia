import AppIntents
import SwiftData
import BinisoftKit
import ThaliaCore

// Shortcuts, Siri and the Action button: capture without opening the app.

@MainActor
private func intentStore() -> TrackerStore {
    TrackerStore(context: Persistence.shared.container.mainContext)
}

/// "Power-Hour in Thalia erfassen" – power-hours (50 minutes each) for an area (stammloop, Nachhilfe …).
struct LogPowerHourIntent: AppIntent {
    static let title: LocalizedStringResource = "Power-Hour erfassen"
    static let description: IntentDescription? = IntentDescription("Erfasst Power-Hours (je 50 Fokusminuten) für einen Bereich in Thalia.")

    @Parameter(title: "Bereich", default: "stammloop")
    var area: String

    @Parameter(title: "Anzahl", default: 1)
    var count: Double

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$count) Power-Hour für \(\.$area) erfassen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = intentStore()
        let needle = area.trimmingCharacters(in: .whitespaces).lowercased()
        let categories = store.liveCategories()
        guard let category = categories.first(where: { $0.key == needle || $0.title.lowercased() == needle })
                ?? categories.first(where: { $0.title.lowercased().contains(needle) }) else {
            return .result(dialog: "Den Bereich „\(area)“ kenne ich nicht. Zum Beispiel: stammloop, HAEB, Sonstige Aufgaben.")
        }
        let powerHours = max(0.25, min(12, (count * 4).rounded() / 4))
        store.addWork(day: .today(), categoryKey: category.key, task: "", powerHours: powerHours)
        let today = DayKey.today()
        let total = store.weekContext(for: today.week, today: today).workTotals(on: today)
        return .result(dialog: "\(Format.powerHours(powerHours)) für \(category.title) erfasst. Heute: \(total.shortText).")
    }
}

/// "Messwert in Thalia eintragen" – protein, water, TEREA, pages …
struct LogMeasureIntent: AppIntent {
    static let title: LocalizedStringResource = "Messwert eintragen"
    static let description: IntentDescription? = IntentDescription("Trägt einen Wert für einen Messwert der aktuellen Woche ein, z. B. Wasser 0,5 oder TEREA 1.")

    @Parameter(title: "Messwert", default: "Wasser")
    var measure: String

    @Parameter(title: "Wert", default: 1)
    var value: Double

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$value) bei \(\.$measure) eintragen")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = intentStore()
        let today = DayKey.today()
        let needle = measure.trimmingCharacters(in: .whitespaces).lowercased()
        let measures = store.measures(today.week)
        guard let definition = measures.first(where: { $0.code == needle || $0.title.lowercased() == needle })
                ?? measures.first(where: { $0.title.lowercased().contains(needle) }) else {
            return .result(dialog: "Den Messwert „\(measure)“ gibt es diese Woche nicht.")
        }
        store.addEntry(code: definition.code, day: today, value: value)
        let context = store.weekContext(for: today.week, today: today)
        let total = context.dayValue(definition, on: today).map { Format.measure($0, unit: definition.unit) } ?? "–"
        return .result(dialog: "\(definition.title): \(Format.measure(value, unit: definition.unit)) eingetragen, heute \(total).")
    }
}

/// "Wie steht mein Tag in Thalia?"
struct TodayStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stand des Tages"
    static let description: IntentDescription? = IntentDescription("Sagt dir, wie viel heute erfasst ist (nach dem Abschluss die Tageswertung) und die Power-Hours von heute.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let store = intentStore()
        let today = DayKey.today()
        let context = store.weekContext(for: today.week, today: today)
        let summary = context.todaySummary()
        let status = summary.dayScore.map { "Tag abgeschlossen mit \(Format.score($0))" } ?? "\(summary.fillText) erfasst"
        return .result(value: summary.dayScore ?? summary.fill * 100,
                       dialog: "Heute: \(status), \(context.workTotals(on: today).shortText).")
    }
}

/// Opens Thalia at the evening review.
struct CloseDayIntent: AppIntent {
    static let title: LocalizedStringResource = "Tag abschließen"
    static let description: IntentDescription? = IntentDescription("Öffnet den Tagesabschluss in Thalia.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingRoute.open("close-day")
        return .result()
    }
}

struct ThaliaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogPowerHourIntent(),
                    phrases: ["Power-Hour in \(.applicationName) erfassen", "\(.applicationName) Power-Hour"],
                    shortTitle: "Power-Hour", systemImageName: "bolt.fill")
        AppShortcut(intent: LogMeasureIntent(),
                    phrases: ["Messwert in \(.applicationName) eintragen", "\(.applicationName) Messwert"],
                    shortTitle: "Messwert", systemImageName: "ruler")
        AppShortcut(intent: TodayStatusIntent(),
                    phrases: ["Wie steht mein Tag in \(.applicationName)", "\(.applicationName) Stand"],
                    shortTitle: "Stand des Tages", systemImageName: "chart.bar")
        AppShortcut(intent: OpenPowerHoursIntent(),
                    phrases: ["Power-Hours in \(.applicationName) eintragen"],
                    shortTitle: "PH mit Beschreibung", systemImageName: "square.and.pencil")
        AppShortcut(intent: OpenExpenseIntent(),
                    phrases: ["Ausgabe in \(.applicationName) erfassen", "\(.applicationName) Ausgabe"],
                    shortTitle: "Ausgabe", systemImageName: "eurosign.circle")
        AppShortcut(intent: CloseDayIntent(),
                    phrases: ["Tag in \(.applicationName) abschließen", "\(.applicationName) Tagesabschluss"],
                    shortTitle: "Tag abschließen", systemImageName: "moon.stars")
    }
}
