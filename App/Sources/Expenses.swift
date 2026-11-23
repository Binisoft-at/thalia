import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

// MARK: Ausgaben – spending

/// Ausgaben as its own sheet (`.expenses(day)`).
struct ExpensesSheet: View {
    let day: DayKey
    @Environment(\.dismiss) private var dismiss

    init(day: DayKey) {
        self.day = day
    }

    var body: some View {
        NavigationStack {
            ExpensesPage(day: day)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 520, height: 640)
    }
}

/// Ausgaben for a day – its own sheet or pushed inside "Heute im Blick" (R51). The week shown is
/// the week of the day the next spending counts for (R41, R54).
struct ExpensesPage: View {
    @Environment(AppModel.self) private var app
    @State private var day: DayKey

    init(day: DayKey) {
        _day = State(initialValue: day)
    }

    var body: some View {
        WeekReader(week: day.week, today: app.today) { context in
            ExpensesContent(context: context, day: $day)
        }
        .navigationTitle("Ausgaben")
        .inlineNavigationTitle()
    }
}

/// Type the amount right away, what for, add – or change a spending (R46). The day and the week at
/// a glance: the target with what is left (R45), the week by day, the biggest purposes (R54).
struct ExpensesContent: View {
    let context: WeekContext
    /// The day a new spending counts for (R41); a tap on a bar or a day row changes it (R54).
    @Binding var day: DayKey
    @Environment(AppModel.self) private var app
    @State private var amount = ""
    @State private var what = ""
    @State private var editing: MeasureEntry?
    @State private var suggestions: [String] = []
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case amount, what
    }

    init(context: WeekContext, day: Binding<DayKey>) {
        self.context = context
        _day = day
    }

    var body: some View {
        Group {
            if let measure = context.expenseMeasure {
                content(measure)
            } else {
                missingMeasure
            }
        }
        .unsavedInput(!amount.isEmpty || !what.isEmpty, in: app)
    }

    private var missingMeasure: some View {
        ContentUnavailableView {
            Label("Kein Ausgaben-Messwert", systemImage: "eurosign.circle")
        } description: {
            Text("Diese Woche hat keinen Messwert in €. Leg ihn an – er gilt dann auch für die nächsten Wochen.")
        } actions: {
            Button("„Ausgaben“ anlegen") {
                _ = app.store.expenseMeasure(week: day.week, create: true)
            }
            .thaliaPrimaryAction()
        }
    }

    private func content(_ measure: MeasureDefinition) -> some View {
        List {
            inputSection(measure)
            overviewSection(measure)
            weekSection(measure)
            purposeSection(measure)
        }
        .compactListSections()
        .onAppear {
            if editing == nil { focus = .amount }
        }
        .task(id: "\(measure.code)|\(day.string)") {
            loadSuggestions(measure)
        }
        .onChange(of: focus) { old, new in
            // Loaded once when typing starts – never per keystroke (R32).
            if old == nil && new != nil { loadSuggestions(measure) }
        }
    }

    // MARK: Sections

    /// "Neue Ausgabe": day, amount, what for, suggestions, add (R31, R32, R41); "Sichern" while
    /// a spending is being changed (R46).
    private func inputSection(_ measure: MeasureDefinition) -> some View {
        Section {
            CaptureDayRow(day: $day, today: app.today)
            HStack(spacing: 8) {
                TextField("Betrag", text: $amount)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .decimalKeyboard()
                    .focused($focus, equals: .amount)
                    .submitLabel(.next)
                    .onSubmit { amountSubmitted(measure) }
                    .keypadButton("Weiter", isActive: focus == .amount) { focus = .what }
                Text("€")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            TextField("Wofür? (Pflicht)", text: $what)
                .focused($focus, equals: .what)
                .submitLabel(.done)
                .onSubmit { save(measure) }
            SuggestionChips(suggestions: suggestions, typed: what, selected: what) { suggestion in
                pick(suggestion, measure: measure)
            }
            HStack(spacing: 10) {
                Button {
                    save(measure)
                } label: {
                    Label(saveTitle, systemImage: saveSymbol)
                        .frame(maxWidth: .infinity)
                }
                .thaliaPrimaryAction()
                .disabled(!canSave)
                if editing != nil {
                    Button("Abbrechen", action: cancelEditing)
                        .buttonStyle(.bordered)
                }
            }
        } header: {
            Text(inputHeader)
        }
    }

    /// The day, the week and the target with what is left (R45); the week's bars, a tap picks
    /// the day (R54).
    private func overviewSection(_ measure: MeasureDefinition) -> some View {
        let dayTotal: Double = context.dayValue(measure, on: day) ?? 0
        let weekTotal: Double = context.weekValue(measure) ?? 0
        let goal: ExpenseGoal? = ExpenseGoal(measure: measure, dayTotal: dayTotal, weekTotal: weekTotal)
        let perDay: [DayAmount] = context.week.days.map { DayAmount(day: $0, value: context.dayValue(measure, on: $0) ?? 0) }
        return Section {
            HStack(spacing: 12) {
                SummaryTile(label: day.relativeLabel(today: app.today), value: Format.euro(dayTotal),
                            tint: GoalPalette.color(goal: "8"))
                SummaryTile(label: context.week.label, value: Format.euro(weekTotal), tint: Brand.accent)
                if let goal {
                    SummaryTile(label: goal.label, value: goal.value, tint: .orange, valueColor: goal.color, spoken: goal.spoken)
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            ExpenseChart(days: perDay, selected: day, dayTarget: dayTarget(measure)) { picked in
                day = picked
                focus = .amount
            }
        }
    }

    /// "Woche": every day with its sum ("Mo, 16. Nov. · 23,40 €") and its spendings (R54); a tap on a
    /// day picks it for the next spending, a tap on a spending changes it (R46).
    private func weekSection(_ measure: MeasureDefinition) -> some View {
        Section {
            ForEach(context.week.days, id: \.self) { weekDay in
                ExpenseDayRow(day: weekDay, total: context.dayValue(measure, on: weekDay) ?? 0,
                              isSelected: weekDay == day, isPast: weekDay <= app.today) {
                    day = weekDay
                    focus = .amount
                }
                ForEach(context.expenseEntries(measure, on: weekDay)) { entry in
                    ExpenseLine(entry: entry, isEditing: isEditing(entry), onEdit: { startEditing(entry) },
                                onDelete: { delete(entry) })
                }
                // v10 (§1.5.3): spending from another app – counted, never changed here ("in Finn ändern").
                ForEach(context.appExpenseRows(measure, on: weekDay)) { row in
                    AppExpenseLine(row: row)
                }
            }
        } header: {
            Text("Woche · \(context.week.label)")
        } footer: {
            if hasAppRows(measure) {
                Text("Zeilen „aus …“ kommen aus einer verbundenen App und zählen mit – geändert werden sie dort. Eigene Ausgaben kommen dazu.")
            }
        }
    }

    /// "Nach Zweck": the five biggest purposes of the week (R54).
    @ViewBuilder
    private func purposeSection(_ measure: MeasureDefinition) -> some View {
        let purposes: [ExpensePurpose] = context.expensesByPurpose(measure, limit: 5)
        let largest: Double = purposes.map(\.total).max() ?? 0
        if !purposes.isEmpty {
            Section {
                ForEach(purposes) { purpose in
                    PurposeRow(purpose: purpose, share: largest > 0 ? purpose.total / largest : 0)
                }
            } header: {
                Text("Nach Zweck")
            }
        }
    }

    // MARK: Values

    private var inputHeader: String {
        editing == nil ? "Neue Ausgabe" : "Ausgabe bearbeiten"
    }

    private var saveTitle: String {
        editing == nil ? "Erfassen" : "Sichern"
    }

    private var saveSymbol: String {
        editing == nil ? "plus.circle.fill" : "checkmark.circle.fill"
    }

    private var parsedAmount: Double? {
        guard let value = Format.parse(amount), value > 0, value.isFinite else { return nil }
        return value
    }

    private var trimmedWhat: String {
        what.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        parsedAmount != nil && !trimmedWhat.isEmpty
    }

    /// v10: the week has spending rows from a connected app.
    private func hasAppRows(_ measure: MeasureDefinition) -> Bool {
        context.week.days.contains { !context.appExpenseRows(measure, on: $0).isEmpty }
    }

    private func dayTarget(_ measure: MeasureDefinition) -> Double? {
        guard let record = measure.record, record.period == .day, let target = record.target else { return nil }
        return target.scaleMax
    }

    private func isEditing(_ entry: MeasureEntry) -> Bool {
        editing?.persistentModelID == entry.persistentModelID
    }

    /// "4,50" for 4.5, "13" for 13 – what Format.parse reads back.
    static func amountText(_ value: Double) -> String {
        let cents: Int = Int((abs(value) * 100).rounded())
        if cents % 100 == 0 { return String(cents / 100) }
        return String(format: "%d,%02d", cents / 100, cents % 100)
    }

    // MARK: Actions

    private func loadSuggestions(_ measure: MeasureDefinition) {
        suggestions = app.store.expenseSuggestions(code: measure.code, through: day)
    }

    /// Return on the amount: saves when "Wofür" is filled, else goes there.
    private func amountSubmitted(_ measure: MeasureDefinition) {
        if canSave {
            save(measure)
        } else {
            focus = .what
        }
    }

    /// A suggestion fills "Wofür"; with a valid amount it saves right away (R32).
    private func pick(_ suggestion: String, measure: MeasureDefinition) {
        what = suggestion
        if parsedAmount != nil {
            save(measure)
        } else {
            focus = .amount
        }
    }

    private func save(_ measure: MeasureDefinition) {
        guard let value = parsedAmount, !trimmedWhat.isEmpty else { return }
        if let entry = editing {
            app.updateExpense(entry, amount: value, what: trimmedWhat, day: day)
        } else {
            app.addExpense(value, what: trimmedWhat, measure: measure, day: day)
        }
        editing = nil
        amount = ""
        what = ""
        focus = .amount
        loadSuggestions(measure)
    }

    /// Fills amount, what for and day from a spending (R46).
    private func startEditing(_ entry: MeasureEntry) {
        editing = entry
        amount = ExpensesContent.amountText(entry.value ?? 0)
        what = entry.note
        if let entryDay = DayKey(entry.dayKey) { day = entryDay }
        focus = .amount
    }

    private func cancelEditing() {
        editing = nil
        amount = ""
        what = ""
    }

    private func delete(_ entry: MeasureEntry) {
        if isEditing(entry) { cancelEditing() }
        app.trash([entry])
    }
}

/// One day's spending in the chart.
private struct DayAmount: Identifiable {
    let day: DayKey
    let value: Double
    var id: String { day.string }
}

/// R45: "Tagesziel < 50 €" with "noch 38 €" (green) or "+12 €" (red) against the day's or the
/// week's sum. v11 P5.15: compared in cents – exactly at a limit "< 50 €" says "nicht unter 50 €" (red), "≤ 50 €"
/// "Limit ausgeschöpft" (orange), instead of a red "+0 €". The score keeps `Target.isMet`.
private struct ExpenseGoal {
    let label: String
    let value: String
    let color: Color
    /// VoiceOver at the limit: "genau 50 €, Ziel unter 50 €"; nil reads label and value.
    var spoken: String? = nil

    init?(measure: MeasureDefinition, dayTotal: Double, weekTotal: Double) {
        guard let record = measure.record, let target = record.target else { return nil }
        let isDay: Bool = record.period == .day
        let kind: String = isDay ? "Tagesziel" : "Wochenziel"
        let total: Double = isDay ? dayTotal : weekTotal
        let limit: Double = target.scaleMax
        let totalCents: Int = ExpenseGoal.cents(total)
        let limitCents: Int = ExpenseGoal.cents(limit)
        label = "\(kind) \(ExpenseGoal.targetText(target))"
        if target.isLimit {
            if totalCents == limitCents {
                let below: Bool = target.comparison == .below
                value = below ? "nicht unter \(Format.euro(limit))" : "Limit ausgeschöpft"
                color = below ? .red : .orange
                spoken = "genau \(Format.euro(limit)), Ziel \(below ? "unter" : "höchstens") \(Format.euro(limit))"
            } else if totalCents < limitCents {
                value = "noch \(ExpenseGoal.euro(cents: limitCents - totalCents))"
                color = .green
            } else {
                value = "+\(ExpenseGoal.euro(cents: totalCents - limitCents))"
                color = .red
            }
        } else if target.isMet(total) {
            value = "erreicht"
            color = .green
        } else {
            value = "noch \(ExpenseGoal.euro(cents: max(0, limitCents - totalCents)))"
            color = .orange
        }
    }

    /// An amount in whole cents – 20,10 + 29,90 is exactly 50,00 here, not 49,999….
    static func cents(_ value: Double) -> Int {
        guard value.isFinite, abs(value) < 1e12 else { return 0 }
        return Int((value * 100).rounded())
    }

    static func euro(cents: Int) -> String {
        Format.euro(Double(cents) / 100)
    }

    /// "< 50 €", "≤ 12,50 €", "20–40 €" – amounts to the cent (R17).
    static func targetText(_ target: Target) -> String {
        let amount: String = Format.euro(target.value)
        switch target.comparison {
        case .atLeast: return "≥ \(amount)"
        case .atMost: return "≤ \(amount)"
        case .above: return "> \(amount)"
        case .below: return "< \(amount)"
        case .equal: return "= \(amount)"
        case .range: return "\(Format.number(target.value))–\(Format.euro(target.upper ?? target.value))"
        }
    }
}

/// The week's spending by day with an axis, the day target as a dashed line and a hint when
/// nothing is spent yet (R45); a tap on a bar picks that day (R54).
private struct ExpenseChart: View {
    let days: [DayAmount]
    let selected: DayKey
    let dayTarget: Double?
    let onSelect: (DayKey) -> Void

    var body: some View {
        Chart {
            ForEach(days) { entry in
                BarMark(x: .value("Tag", entry.day.weekday.short), y: .value("€", entry.value))
                    .foregroundStyle(barColor(entry))
                    .cornerRadius(4)
            }
            if let dayTarget {
                RuleMark(y: .value("Tagesziel", dayTarget))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.orange)
            }
        }
        .chartXScale(domain: days.map { $0.day.weekday.short })
        .chartYScale(domain: 0...upperBound)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    Text(ExpenseChart.axisText(value.as(Double.self)))
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        select(at: location, proxy: proxy, geometry: geometry)
                    }
            }
        }
        .overlay {
            if isEmpty {
                Text("Noch keine Ausgaben")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 160)
        .accessibilityHint("Ein Tipp auf einen Balken stellt die Eingabe auf diesen Tag")
    }

    private var isEmpty: Bool {
        days.allSatisfy { $0.value <= 0 }
    }

    /// Room above the highest bar and the target line; an axis even without spending.
    private var upperBound: Double {
        let highest: Double = days.map(\.value).max() ?? 0
        let top: Double = max(highest, dayTarget ?? 0)
        return max(10, top * 1.15)
    }

    private func barColor(_ entry: DayAmount) -> Color {
        let base: Color = isOver(entry) ? .red : GoalPalette.color(goal: "8")
        return entry.day == selected ? base : base.opacity(0.4)
    }

    private func isOver(_ entry: DayAmount) -> Bool {
        guard let dayTarget else { return false }
        return entry.value > dayTarget + 1e-9
    }

    static func axisText(_ value: Double?) -> String {
        guard let value else { return "" }
        return Format.euro(value)
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let anchor = proxy.plotFrame else { return }
        let x: CGFloat = location.x - geometry[anchor].origin.x
        guard let label = proxy.value(atX: x, as: String.self),
              let entry = days.first(where: { $0.day.weekday.short == label }) else { return }
        onSelect(entry.day)
    }
}

/// A day of the week with its sum: "Mo, 16. Nov. · 23,40 €"; a tap picks it for the next spending.
private struct ExpenseDayRow: View {
    let day: DayKey
    let total: Double
    let isSelected: Bool
    let isPast: Bool
    let onSelect: () -> Void

    private var textStyle: Color {
        isPast ? .primary : .secondary
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text("\(day.shortLabel) · \(Format.euro(total))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(textStyle)
                Spacer(minLength: 6)
                if isSelected {
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Brand.accent)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Stellt die Eingabe auf diesen Tag")
    }
}

/// One spending: what for and how much; a tap or "Bearbeiten" changes it (R46).
private struct ExpenseLine: View {
    let entry: MeasureEntry
    let isEditing: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var title: String {
        entry.note.isEmpty ? "ohne Angabe" : entry.note
    }

    private var titleColor: Color {
        entry.note.isEmpty ? .orange : .primary
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(titleColor)
                    Text(entry.recordedAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                if isEditing {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(Brand.accent)
                }
                Text(Format.euro(entry.value ?? 0))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(.leading, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
        }
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil", action: onEdit)
            Button("Löschen", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

/// A purpose with its sum and a thin bar against the biggest one (R54).
private struct PurposeRow: View {
    let purpose: ExpensePurpose
    let share: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(purpose.purpose)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(Format.count(purpose.count, "Ausgabe", "Ausgaben"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Format.euro(purpose.total))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            GeometryReader { geometry in
                Capsule()
                    .fill(GoalPalette.color(goal: "8").opacity(0.7))
                    .frame(width: max(4, geometry.size.width * min(1, share)))
            }
            .frame(height: 4)
        }
        .padding(.vertical, 2)
    }
}
