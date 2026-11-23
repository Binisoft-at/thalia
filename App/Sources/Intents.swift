import Foundation
import AppIntents
import SwiftData
import BinisoftKit
import ThaliaCore

// Shortcuts, Siri and the Action button: capture without opening the app.

@MainActor
private func intentStore() -> TrackerStore {
    TrackerStore(context: Persistence.shared.container.mainContext)
}

/// A work area for Siri and Shortcuts (R89): id = category key, shown as "3.2 Titel". Siri asks for it
/// and offers the business areas first.
struct WorkAreaEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bereich"
    static let defaultQuery = WorkAreaQuery()

    /// The category key ("3.2").
    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id) \(title)")
    }
}

/// The areas from the live categories: business areas (goal 3 without the morning routine) first,
/// then all others, each in plan order.
struct WorkAreaQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [WorkAreaEntity] {
        let all = WorkAreaQuery.areas()
        return identifiers.compactMap { id in all.first { $0.id == id } }
    }

    @MainActor
    func suggestedEntities() async throws -> [WorkAreaEntity] {
        WorkAreaQuery.areas()
    }

    @MainActor
    func entities(matching string: String) async throws -> [WorkAreaEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = WorkAreaQuery.areas()
        guard !needle.isEmpty else { return all }
        return all.filter { $0.id == needle || $0.title.lowercased().contains(needle) }
    }

    @MainActor
    static func areas() -> [WorkAreaEntity] {
        // v11 P3.16 (3): one copy per key, the most recently changed one (copies made on two devices offline).
        let categories = Array(intentStore().liveCategories().latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
        let business = categories.filter { isBusiness($0) }
        let others = categories.filter { !isBusiness($0) }
        return (business + others).map { WorkAreaEntity(id: $0.key, title: $0.title) }
    }

    static func isBusiness(_ category: TrackCategory) -> Bool {
        category.goalKey == "3" && category.key != "3.1"
    }
}

/// "Power-Hour in Thalia erfassen" – power-hours (50 minutes each) for an area, always with what they
/// were for (K1). Siri asks for the area (R89).
struct LogPowerHourIntent: AppIntent {
    static let title: LocalizedStringResource = "Power-Hour erfassen"
    static let description: IntentDescription? = IntentDescription("Erfasst Power-Hours (je 50 Fokusminuten) für einen Bereich in Thalia – mit Wofür.")

    /// No default (R89): Siri asks and lists the areas.
    @Parameter(title: "Bereich")
    var area: WorkAreaEntity

    /// No default (R89): Siri asks for the amount, too.
    @Parameter(title: "Menge")
    var count: Double

    /// Required (K1): power-hours always say what they were for.
    @Parameter(title: "Wofür")
    var task: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$count) Power-Hour für \(\.$area): \(\.$task)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = intentStore()
        let what = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !what.isEmpty else {
            return .result(dialog: "Woran hast du gearbeitet? Ohne Beschreibung trage ich keine Power-Hours ein.")
        }
        guard let category = store.liveCategories().latest(by: \.key, modified: \.modifiedAt)[area.id] else {
            return .result(dialog: "Den Bereich „\(area.id) \(area.title)“ gibt es nicht mehr.")
        }
        let powerHours = max(0.25, min(12, (count * 4).rounded() / 4))
        let today = DayKey.today()
        // v11 P4.14: a little background time until iCloud has the save (the dialog doesn't wait).
        let saveDate = Date()
        store.addWork(day: today, categoryKey: category.key, task: what, powerHours: powerHours)
        BackgroundGrace.holdForExport(after: saveDate)
        store.publishWidget(today: today)
        let total = store.weekContext(for: today.week, today: today).workTotals(on: today)
        return .result(dialog: "\(Format.powerHours(powerHours)) für \(category.title) (\(what)) erfasst. Heute: \(total.shortText).")
    }
}

/// "Messwert in Thalia eintragen" – water, pages, steps … Power-hours, spending and times have their
/// own ways (R3).
struct LogMeasureIntent: AppIntent {
    static let title: LocalizedStringResource = "Messwert eintragen"
    static let description: IntentDescription? = IntentDescription("Trägt einen Wert für einen Messwert der aktuellen Woche ein, z. B. Wasser 0,5 oder Seiten 10.")

    /// No default (R3): Siri asks which measurement. v11 P8.17: the week's measurements as choices (a text, so
    /// saved Shortcuts keep working).
    @Parameter(title: "Messwert", requestValueDialog: IntentDialog("Welcher Messwert?"), optionsProvider: MeasureOptions())
    var measure: String

    /// v11 P8.17: no default – Siri asks ("Welcher Wert für „Gewicht“ (kg)?"); only a plain counter takes 1.
    /// Optional, so Shortcuts saved with a value stay valid.
    @Parameter(title: "Wert", requestValueDialog: IntentDialog("Welcher Wert?"))
    var value: Double?

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
        if let refusal = LogMeasureIntent.refusal(for: definition.record) {
            return .result(dialog: "\(refusal)")
        }
        guard let amount = value ?? (LogMeasureIntent.isPlainCounter(definition.record) ? 1 : nil) else {
            throw $value.needsValueError(LogMeasureIntent.valueQuestion(title: definition.title, unit: definition.unit))
        }
        // v11 P4.14: a little background time until iCloud has the save (the dialog doesn't wait).
        let saveDate = Date()
        store.addEntry(code: definition.code, day: today, value: amount)
        BackgroundGrace.holdForExport(after: saveDate)
        store.publishWidget(today: today)
        let context = store.weekContext(for: today.week, today: today)
        let total = context.dayValue(definition, on: today).map { Format.measure($0, unit: definition.unit) } ?? "–"
        return .result(dialog: "\(definition.title): \(Format.measure(amount, unit: definition.unit)) eingetragen, heute \(total).")
    }

    /// v11 P8.17 (KR3-17): only a plain counter – no unit or "Stück", adding up – takes 1 without asking. Every other
    /// unit asks (`Units.step` gives 1 for any unknown unit: "km" or "%" would get 1 silently).
    static func isPlainCounter(_ record: MeasureRecord?) -> Bool {
        guard let record else { return false }
        return ["", "stück"].contains(Units.normalized(record.unit)) && record.aggregation == .sum
    }

    /// v11 P8.17 (KR2-15): "Welcher Wert für „Gewicht“ (kg)?" – without a unit "Welcher Wert für „Gewicht“?".
    static func valueQuestion(title: String, unit: String) -> IntentDialog {
        let shown = Units.display(unit)
        guard !shown.isEmpty else { return "Welcher Wert für „\(title)“?" }
        return "Welcher Wert für „\(title)“ (\(shown))?"
    }

    /// Power-hours need an area and "Wofür" (K1), spending a "Wofür" (K2), times the clock in the app.
    static func refusal(for record: MeasureRecord?) -> String? {
        guard let record else { return nil }
        if record.isWork { return "Power-Hours erfasst du mit „Power-Hour erfassen“ – mit Bereich und Wofür." }
        if record.isExpense { return "Ausgaben gehen mit „Ausgabe in Thalia“ – mit Betrag und Wofür." }
        if record.isTime { return "Uhrzeiten trägst du in der App ein." }
        // v10 (§1.3.3): pages of the reading list are entered once, with "Lesen" (an own value would hide them).
        if record.isList { return "Seiten aus der Leseliste kommen über „Lesen“ in der App – so zählen sie nur einmal." }
        return nil
    }
}

/// v11 P8.17: the choices for "Messwert" – this week's measurements Siri can enter (not power-hours, spending,
/// times or pages from the reading list), by title, one per title.
struct MeasureOptions: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let today = DayKey.today()
        var seen = Set<String>()
        return intentStore().measures(today.week)
            .filter { LogMeasureIntent.refusal(for: $0.record) == nil }
            .map(\.title)
            .filter { seen.insert($0.lowercased()).inserted }
    }
}

/// "Wie steht mein Tag in Thalia?" – how much is filled in, what is open and what comes next (R89).
struct TodayStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Stand des Tages"
    static let description: IntentDescription? = IntentDescription("Sagt dir, wie viel heute erfasst ist, wie viel noch offen ist und was als Nächstes kommt (nach dem Abschluss die Tageswertung) – und die Power-Hours von heute. Ergebnis: nach dem Abschluss die Tageswertung (0–10), sonst der erfasste Anteil in %.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<Double> {
        let store = intentStore()
        let today = DayKey.today()
        let context = store.weekContext(for: today.week, today: today)
        let summary = context.todaySummary()
        let sentence = TodayStatusIntent.sentence(context: context, summary: summary)
        return .result(value: summary.dayScore ?? summary.fill * 100, dialog: "\(sentence)")
    }

    /// "Heute: 73 % erfasst, 11 offen – als Nächstes 1.1 …, 2.1 …. 4 PH."
    static func sentence(context: WeekContext, summary: TodaySummary) -> String {
        let today = context.today
        let powerHours = Format.powerHours(context.workTotals(on: today).powerHours)
        // v11 P6.5: a sick or holiday day isn't "100 % erfasst" – it doesn't count.
        if summary.isExcusedDay {
            return "Heute: \(summary.excusedName) – der Tag zählt nicht. \(powerHours)."
        }
        if let score = summary.dayScore {
            return "Heute: Tag abgeschlossen mit \(Format.score(score)). \(powerHours)."
        }
        guard context.hasPlan else { return "Heute: Kein Plan für diese Woche. \(powerHours)." }
        let count = context.openCount(on: today)
        // v11 P6.5: nothing due today (a free day without items) – not "100 % erfasst".
        if count == 0, (context.score.days[today]?.due ?? 0) == 0 {
            return "Heute ist nichts fällig. \(powerHours)."
        }
        guard count > 0 else { return "Heute: \(summary.fillText) erfasst, nichts offen. \(powerHours)." }
        let next = context.openToDo(on: today).prefix(2).map { "\($0.categoryKey) \($0.title)" }.joined(separator: ", ")
        return "Heute: \(summary.fillText) erfasst, \(count) offen – als Nächstes \(next). \(powerHours)."
    }
}

/// "Ausgabe in Thalia" (R89, R97): amount and what it was for (K2), booked without opening the app –
/// also from the Shortcuts automation "Transaktion" (Betrag = Betrag, Wofür = Händler). Creates the
/// week's spending measurement when it is missing.
struct AddExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Ausgabe in Thalia"
    static let description: IntentDescription? = IntentDescription("Bucht eine Ausgabe mit Betrag und Wofür, ohne Thalia zu öffnen. Mit der Kurzbefehle-Automation „Transaktion“ landet jede Kartenzahlung von selbst in Thalia.")

    @Parameter(title: "Betrag")
    var amount: Double

    /// Required (K2): every spending says what it was for.
    @Parameter(title: "Wofür", optionsProvider: ExpensePurposeOptions())
    var what: String

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$amount) € für \(\.$what)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let purpose = what.trimmingCharacters(in: .whitespacesAndNewlines)
        let cents = (amount * 100).rounded() / 100
        guard !purpose.isEmpty, cents > 0 else {
            return .result(dialog: "Wofür war die Ausgabe? Ohne Zweck trage ich nichts ein.")
        }
        let store = intentStore()
        let today = DayKey.today()
        // v11 P4.14: a little background time until iCloud has the save (the dialog doesn't wait).
        let saveDate = Date()
        guard let entry = store.addExpense(cents, what: purpose, day: today) else {
            return .result(dialog: "Wofür war die Ausgabe? Ohne Zweck trage ich nichts ein.")
        }
        BackgroundGrace.holdForExport(after: saveDate)
        store.publishWidget(today: today)
        let total = store.entries(code: entry.code, day: today).compactMap(\.value).reduce(0, +)
        return .result(dialog: "\(Format.euro(cents)) für \(purpose) erfasst. Heute: \(Format.euro(total)).")
    }
}

/// "Wofür" suggestions: what recent spendings were for (R32), this week's measurement or last week's.
struct ExpensePurposeOptions: DynamicOptionsProvider {
    @MainActor
    func results() async throws -> [String] {
        let store = intentStore()
        let today = DayKey.today()
        let measure = store.expenseMeasure(week: today.week, create: false)
            ?? store.expenseMeasure(week: today.week.adding(weeks: -1), create: false)
        guard let measure else { return [] }
        return store.expenseSuggestions(code: measure.code, through: today)
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
        // The open-the-app intents (power-hours, spending) stay for Control Center only (R89).
        AppShortcut(intent: AddExpenseIntent(),
                    phrases: ["Ausgabe in \(.applicationName)", "\(.applicationName) Ausgabe"],
                    shortTitle: "Ausgabe", systemImageName: "eurosign.circle")
        AppShortcut(intent: CloseDayIntent(),
                    phrases: ["Tag in \(.applicationName) abschließen", "\(.applicationName) Tagesabschluss"],
                    shortTitle: "Tag abschließen", systemImageName: "moon.stars")
    }
}
