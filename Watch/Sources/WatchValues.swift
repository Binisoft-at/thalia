import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore
#if os(watchOS)
import WatchKit
#endif

/// Taps on the wrist (R48, R82): success when something is set or saved, a click when it is cleared.
enum WatchHaptic {
    case success
    case click

    func play() {
        #if os(watchOS)
        switch self {
        case .success: WKInterfaceDevice.current().play(.success)
        case .click: WKInterfaceDevice.current().play(.click)
        }
        #endif
    }
}

/// How a measurement shows on the watch.
enum WatchMeasureKind: Equatable {
    /// A number with − / + and the crown editor (R81).
    case value
    /// Spending: only the day's sum – amount and "Wofür" are captured on the iPhone (R2, K2).
    case expense
    /// Apple Health: read on the iPhone only, never "missing" here (H1).
    case health
    /// v10 (§1.3.3): pages from the reading list (`list:<art>`) – entered once, with "Lesen" on the
    /// iPhone or Mac; the watch only shows the day's amount (an own value would hide the readings).
    case list
    /// Power-hours, times and texts stay on the phone.
    case hidden

    static func of(_ measure: MeasureDefinition, in context: WeekContext) -> WatchMeasureKind {
        guard let record = measure.record else { return .hidden }
        if record.isWork || record.isTime || record.isText { return .hidden }
        if context.isExpense(measure) { return .expense }
        if record.isHealth { return .health }
        if record.isList { return .list }
        return .value
    }

    /// "mit „Lesen“ am iPhone eintragen"
    static let listHint = "mit \u{201E}Lesen\u{201C} am iPhone eintragen"

    /// Page-1 counters (R34): day measurements that add up (water, pages …), no "Nebensache".
    static func isCounter(_ measure: MeasureDefinition, in context: WeekContext) -> Bool {
        guard let record = measure.record, !measure.isSecondary, of(measure, in: context) == .value else { return false }
        return record.period == .day && record.aggregation == .sum
    }
}

/// One measurement: − / + and a tap on the value for the crown editor (R81). Spending shows the day's
/// sum without − / + (R2), Apple Health values a hint instead (H1).
struct WatchMeasureRow: View {
    let measure: MeasureDefinition
    let context: WeekContext
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing = false
    @State private var editorStart: Double = 0

    private var store: TrackerStore { TrackerStore(context: modelContext) }

    var body: some View {
        row
            .sheet(isPresented: $isEditing) {
                WatchValueEditor(title: measure.title, unit: measure.unit, start: editorStart) { newValue in
                    save(newValue)
                }
            }
    }

    @ViewBuilder
    private var row: some View {
        switch WatchMeasureKind.of(measure, in: context) {
        case .expense:
            expenseRow
        case .health:
            healthRow
        case .list:
            listRow
        case .value, .hidden:
            valueRow
        }
    }

    // MARK: Rows

    private var valueRow: some View {
        let value = context.dayValue(measure, on: context.today)
        let step = Units.step(measure.unit)
        let text = WatchMeasureRow.valueText(value, unit: measure.unit)
        return VStack(alignment: .leading, spacing: 4) {
            Text(measure.title)
                .font(.footnote)
                .lineLimit(2)
            HStack(spacing: 4) {
                Button {
                    change(by: -step, from: value)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .disabled((value ?? 0) <= 0)
                .accessibilityLabel("Weniger")
                Button {
                    openEditor(current: value)
                } label: {
                    Text(text)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(measure.title): \(text)")
                .accessibilityHint("Öffnet die Eingabe mit der Krone")
                Button {
                    change(by: step, from: value)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .tint(Brand.accent)
                .accessibilityLabel("Mehr")
            }
        }
    }

    private var expenseRow: some View {
        let value = context.dayValue(measure, on: context.today) ?? 0
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(measure.title)
                    .font(.footnote)
                Spacer(minLength: 4)
                Text(Format.euro(value))
                    .font(.headline.monospacedDigit())
            }
            Text("am iPhone erfassen")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// v10: pages from the reading list – only shown; "Lesen" on the iPhone or Mac enters them once.
    private var listRow: some View {
        let text = WatchMeasureRow.valueText(context.dayValue(measure, on: context.today), unit: measure.unit)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(measure.title)
                    .font(.footnote)
                Spacer(minLength: 4)
                Text(text)
                    .font(.headline.monospacedDigit())
            }
            Text(WatchMeasureKind.listHint)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    /// No − / + (H1): the value comes from Health on the iPhone; a tap still opens the crown editor.
    private var healthRow: some View {
        let value = context.dayValue(measure, on: context.today)
        let text = WatchMeasureRow.valueText(value, unit: measure.unit)
        return Button {
            openEditor(current: value)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(measure.title)
                        .font(.footnote)
                    Spacer(minLength: 4)
                    Text(text)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(WeekContext.healthElsewhereHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(measure.title): \(text). \(WeekContext.healthElsewhereHint)")
        .accessibilityHint("Öffnet die Eingabe mit der Krone")
    }

    // MARK: Actions

    static func valueText(_ value: Double?, unit: String) -> String {
        guard let value else { return "–" }
        return Format.measure(value, unit: unit)
    }

    /// − / + change the day's value in its entry (R2), never below 0.
    private func change(by delta: Double, from value: Double?) {
        let next = (max(0, (value ?? 0) + delta) * 1000).rounded() / 1000
        save(next)
    }

    /// The editor starts at today's value, else at the last one of the past weeks (R81).
    private func openEditor(current: Double?) {
        editorStart = current ?? store.lastValue(code: measure.code, before: context.today) ?? 0
        isEditing = true
    }

    private func save(_ value: Double) {
        _ = store.setDayValue(code: measure.code, day: context.today, value: value)
        WatchHaptic.success.play()
    }
}

/// R81: the crown sets a value in the unit's step (kg 0,1 · l 0,25 · € 0,5 · h 0,25 · else 1),
/// "Sichern" writes it as the day's value.
struct WatchValueEditor: View {
    let title: String
    let unit: String
    let start: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(title: String, unit: String, start: Double, onSave: @escaping (Double) -> Void) {
        self.title = title
        self.unit = unit
        self.start = start
        self.onSave = onSave
        _value = State(initialValue: start)
    }

    private var step: Double { Units.crownStep(unit) }
    private var upperBound: Double { max(1000, start * 3) }

    /// The value on the step grid; an untouched start value stays exactly as it was.
    private var result: Double {
        guard value != start else { return start }
        let snapped = (max(0, value) / step).rounded() * step
        return (snapped * 1_000_000).rounded() / 1_000_000
    }

    var body: some View {
        let shown = Format.measure(result, unit: unit)
        ScrollView {
            VStack(spacing: 6) {
                Text(title)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(shown)
                    .font(.title2.monospacedDigit().weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .focusable()
                    .digitalCrownRotation($value, from: 0, through: upperBound, by: step, sensitivity: .medium,
                                          isContinuous: false, isHapticFeedbackEnabled: true)
                    .accessibilityLabel(title)
                    .accessibilityValue(shown)
                Text("Mit der Krone einstellen")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Button {
                        value = max(0, result - step)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .accessibilityLabel("Weniger")
                    Button {
                        value = min(upperBound, result + step)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Mehr")
                }
                .buttonStyle(.bordered)
                Button("Sichern") {
                    onSave(result)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
            }
        }
    }
}
