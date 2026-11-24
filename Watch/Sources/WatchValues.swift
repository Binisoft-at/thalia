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
    /// v11 P8.8: the Health editor saves only a value the crown moved to.
    @State private var editorRequiresChange = false
    /// v11 P8.8: the last value before today (a Health row's editor starts there when today has none).
    @State private var previousValue: Double?

    private var store: TrackerStore { TrackerStore(context: modelContext) }

    var body: some View {
        row
            .sheet(isPresented: $isEditing) {
                WatchValueEditor(title: measure.title, unit: measure.unit, start: editorStart,
                                 requiresChange: editorRequiresChange) { newValue in
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

    /// v11 P8.5: while today's value comes from a connected app, the row only shows it (like the reading list).
    @ViewBuilder
    private var valueRow: some View {
        if context.valueSource(measure, on: context.today) != nil {
            appValueRow
        } else {
            editableValueRow
        }
    }

    /// v11 P8.9: "Ziel ≥ 8" and "aus Finn" (P8.5) under the row, joined with " · "; empty without either.
    private var caption: String {
        let day = context.today
        let source: String? = context.valueSource(measure, on: day).map { "aus \($0)" }
        let parts: [String?] = [WatchMeasureRow.targetText(context.record(measure)), source]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// v11 P8.9: the day's own target is met – a green ✓ (never orange: "not yet" is neutral, as on the iPhone).
    private var isMet: Bool {
        guard let record = context.record(measure) else { return false }
        return Measures.isMet(record, value: context.dayValue(measure, on: context.today)) == true
    }

    /// The title, with a green ✓ once the day's target is met (v11 P8.9).
    private var titleLine: some View {
        HStack(spacing: 4) {
            Text(measure.title)
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 4)
            if isMet {
                Image(systemName: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .accessibilityLabel("Ziel erreicht")
            }
        }
    }

    /// A value from a connected app today: shown with "aus <App>", no − / + and no editor (v11 P8.5).
    private var appValueRow: some View {
        let text = WatchMeasureRow.valueText(context.dayValue(measure, on: context.today), unit: measure.unit)
        let caption: String = self.caption
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                titleLine
                Text(text)
                    .font(.headline.monospacedDigit())
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var editableValueRow: some View {
        let value = context.dayValue(measure, on: context.today)
        let step = Units.step(measure.unit)
        let text = WatchMeasureRow.valueText(value, unit: measure.unit)
        let caption: String = self.caption
        return VStack(alignment: .leading, spacing: 4) {
            titleLine
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
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

    /// No − / + (H1): the value comes from Health on the iPhone. v11 P8.8: a tap opens the crown editor at today's
    /// own value, else at the last one before today; without either the row only shows the hint (no editor
    /// starting at 0). The editor saves only when the crown moved – a shown value never turns into an own entry.
    @ViewBuilder
    private var healthRow: some View {
        // HEALTHSHARE: `dayValue` is the own value, else the one the iPhone shares (an own entry wins) – the crown starts at
        // the own, else the shared, else the last value and writes only when it moved (P8.8, P9.3).
        let value = context.dayValue(measure, on: context.today)
        let start: Double? = value ?? previousValue
        let text = WatchMeasureRow.valueText(value, unit: measure.unit)
        Group {
            if let start {
                Button {
                    openHealthEditor(start: start)
                } label: {
                    healthLabel(text)
                }
                .buttonStyle(.plain)
                // HEALTHSHARE: `healthCaption` – "aus Health am iPhone" for a shared value.
                .accessibilityLabel("\(measure.title): \(text). \(healthCaption ?? "")")
                .accessibilityHint("Öffnet die Eingabe mit der Krone")
            } else {
                healthLabel(text)
                    .accessibilityElement(children: .combine)
            }
        }
        .task(id: context.today) {
            previousValue = store.lastValue(code: measure.code, before: context.today)
        }
    }

    private func healthLabel(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(measure.title)
                    .font(.footnote)
                Spacer(minLength: 4)
                Text(text)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // HEALTHSHARE: `healthCaption` – the hint, "aus Health am iPhone" or what Health read there.
            if let caption = healthCaption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }

    // HEALTHSHARE: under a Health value – "aus Health am iPhone" when it is the one the iPhone shares, "Health am iPhone:
    // 72,6 kg – dort übernehmen" when Health read it there but nothing was taken over (§1.4.8), the hint "Wert aus Health auf
    // dem iPhone" on a day the iPhone doesn't share; nil on a shared day without anything (missing there, too).
    private var healthCaption: String? {
        let day: DayKey = context.today
        // HEALTHSHARE
        if context.sharedHealthValue(measure, on: day) != nil { return context.healthShare.sharedCaption }
        // HEALTHSHARE
        if let phone = context.sharedHealthSuggestion(measure, on: day) {
            return context.healthShare.suggestionText(phone, unit: measure.unit)
        }
        guard context.isHealthElsewhere(measure, on: day) else { return nil }
        return WeekContext.healthElsewhereHint
    }

    // MARK: Actions

    static func valueText(_ value: Double?, unit: String) -> String {
        guard let value else { return "–" }
        return Format.measure(value, unit: unit)
    }

    /// v11 P8.9: "Ziel ≥ 8" for the day's target, "Ziel ≥ 20 pro Woche" for a week's; nil without a target.
    static func targetText(_ record: MeasureRecord?) -> String? {
        guard let record, let target = record.target else { return nil }
        guard record.period == .day else { return "Ziel \(target.label) \(record.period.label)" }
        return "Ziel \(target.label)"
    }

    /// − / + change the day's value in its entry (R2), never below 0.
    private func change(by delta: Double, from value: Double?) {
        let next = (max(0, (value ?? 0) + delta) * 1000).rounded() / 1000
        save(next)
    }

    /// The editor starts at today's value, else at the last one of the past weeks (R81).
    private func openEditor(current: Double?) {
        editorStart = current ?? store.lastValue(code: measure.code, before: context.today) ?? 0
        editorRequiresChange = false
        isEditing = true
    }

    /// v11 P8.8: a Health value – "Sichern" writes only a value the crown moved to.
    private func openHealthEditor(start: Double) {
        editorStart = start
        editorRequiresChange = true
        isEditing = true
    }

    private func save(_ value: Double) {
        _ = store.setDayValue(code: measure.code, day: context.today, value: value)
        WatchHaptic.success.play()
    }
}

/// R81: the crown sets a value in the unit's step (kg 0,1 · l 0,25 · € 0,5 · h 0,25 · else 1),
/// "Sichern" writes it as the day's value. v11 P8.8: with `requiresChange` (Health values) "Sichern" waits until
/// the value differs from the start – a value only shown never becomes an own entry.
struct WatchValueEditor: View {
    let title: String
    let unit: String
    let start: Double
    let requiresChange: Bool
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var value: Double

    init(title: String, unit: String, start: Double, requiresChange: Bool = false, onSave: @escaping (Double) -> Void) {
        self.title = title
        self.unit = unit
        self.start = start
        self.requiresChange = requiresChange
        self.onSave = onSave
        _value = State(initialValue: start)
    }

    /// v11 P8.8: nothing to save yet – the crown hasn't moved the value away from the start.
    private var isUnchanged: Bool { requiresChange && result == start }

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
                    if !isUnchanged { onSave(result) }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(Brand.accent)
                .disabled(isUnchanged)
            }
        }
    }
}
