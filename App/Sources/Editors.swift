import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

// MARK: Work

/// Record or edit power-hours (U9): the day, area, how many PH (quick chips or free), what for –
/// with the last combinations and earlier descriptions of the area as one-tap suggestions (R32,
/// R33). Result and next step are optional.
struct WorkEditor: View {
    let draft: WorkDraft
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TrackCategory> { $0.deletedAt == nil }) private var categories: [TrackCategory]

    @State private var day: DayKey
    @State private var categoryKey: String
    @State private var powerHours: Double
    @State private var task: String
    @State private var result: String
    @State private var nextStep: String
    @State private var showsMore: Bool
    /// What the area was used for before – loaded once per area (R32).
    @State private var suggestions: [String] = []
    /// The last three combinations, loaded once (R33).
    @State private var combos: [WorkCombo] = []
    @FocusState private var taskFocused: Bool
    /// Description, result and next step as the sheet opened (R14).
    private let initialTexts: [String]

    init(draft: WorkDraft) {
        self.draft = draft
        let block: WorkBlock? = draft.block
        let blockDay: DayKey? = block.flatMap { DayKey($0.dayKey) }
        let task: String = block?.task ?? ""
        let result: String = block?.result ?? ""
        let nextStep: String = block?.nextStep ?? ""
        _day = State(initialValue: blockDay ?? draft.day)
        _categoryKey = State(initialValue: block?.categoryKey ?? draft.categoryKey)
        _powerHours = State(initialValue: block?.hours ?? draft.powerHours)
        _task = State(initialValue: task)
        _result = State(initialValue: result)
        _nextStep = State(initialValue: nextStep)
        _showsMore = State(initialValue: !result.isEmpty || !nextStep.isEmpty)
        initialTexts = [task, result, nextStep]
    }

    private var sortedCategories: [TrackCategory] {
        Array(categories.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }

    /// Business areas (goal 3 without 3.1) as chips – all of them, wrapping (R33). Without any,
    /// the first six areas.
    private var chipCategories: [TrackCategory] {
        let business: [TrackCategory] = sortedCategories.filter { $0.goalKey == "3" && $0.key != "3.1" }
        return business.isEmpty ? Array(sortedCategories.prefix(6)) : business
    }

    /// Every other area, in the menu "Anderer Bereich".
    private var menuCategories: [TrackCategory] {
        let chips: Set<String> = Set(chipCategories.map(\.key))
        return sortedCategories.filter { !chips.contains($0.key) }
    }

    /// The menu shows the chosen area only when it is one of its own.
    private var menuSelection: Binding<String> {
        let keys: Set<String> = Set(menuCategories.map(\.key))
        let chosen: String = categoryKey
        return Binding(
            get: { keys.contains(chosen) ? chosen : "" },
            set: { if !$0.isEmpty { categoryKey = $0 } }
        )
    }

    private var trimmedTask: String {
        task.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        powerHours > 0 && !categoryKey.isEmpty && !trimmedTask.isEmpty
    }

    /// R14: description, result or next step typed but not saved.
    private var isDirty: Bool {
        [task, result, nextStep] != initialTexts
    }

    private var baseTitle: String {
        draft.block == nil ? "Power-Hours" : "Power-Hours bearbeiten"
    }

    private func categoryLine(_ category: TrackCategory) -> String {
        "\(category.key) \(category.title)"
    }

    /// "3.3 · Thema A · 2 PH".
    private func comboTitle(_ combo: WorkCombo) -> String {
        "\(combo.categoryKey) · \(combo.task) · \(Format.powerHours(combo.powerHours))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CaptureDayRow(day: $day, today: app.today)
                }
                if draft.block == nil, !combos.isEmpty {
                    Section {
                        ForEach(combos) { combo in
                            Button {
                                apply(combo)
                            } label: {
                                Label(comboTitle(combo), systemImage: "clock.arrow.circlepath")
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        Text("Zuletzt")
                    } footer: {
                        Text("Ein Tipp füllt Bereich, Wofür und Menge – „Sichern“ oder Return bucht.")
                    }
                }
                Section {
                    WrapLayout(spacing: 8) {
                        ForEach(chipCategories) { category in
                            ChipButton(title: categoryLine(category), isSelected: category.key == categoryKey) {
                                categoryKey = category.key
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    if !menuCategories.isEmpty {
                        Picker("Anderer Bereich", selection: menuSelection) {
                            Text("–").tag("")
                            ForEach(menuCategories) { category in
                                Text(categoryLine(category)).tag(category.key)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Text("Bereich (Pflicht)")
                } footer: {
                    if categoryKey.isEmpty {
                        Label("Wähle, wofür die Power-Hours zählen.", systemImage: "hand.point.up.left")
                    }
                }
                Section {
                    HStack(spacing: 8) {
                        ForEach(PowerHour.quick, id: \.self) { value in
                            ChipButton(title: Format.number(value), isSelected: abs(powerHours - value) < 0.001) {
                                powerHours = value
                            }
                        }
                    }
                    Stepper(value: $powerHours, in: 0.25...16, step: 0.25) {
                        LabeledContent("Power-Hours", value: Format.powerHours(powerHours))
                    }
                } header: {
                    Text("Power-Hours")
                } footer: {
                    Text("1 PH = \(Format.number(Double(PowerHour.minutes))) Minuten konzentrierte Arbeit – Nachhilfe zählt genauso (\(Format.powerHours(powerHours)) = \(Format.duration(minutes: Int(PowerHour.minutes(powerHours).rounded())))).")
                }
                Section {
                    TextField("Woran? (Pflicht, z. B. Thema A)", text: $task)
                        .focused($taskFocused)
                        .submitLabel(.done)
                        .onSubmit(save)
                    SuggestionChips(suggestions: suggestions, typed: task, selected: task) { suggestion in
                        task = suggestion
                    }
                } header: {
                    Text("Beschreibung (Pflicht)")
                } footer: {
                    Text("Ohne Beschreibung keine Power-Hours: so weißt du später, woran du gearbeitet hast. Vorschläge kommen aus deinen Einträgen der letzten Monate in diesem Bereich.")
                }
                Section {
                    DisclosureGroup("Ergebnis und nächster Schritt", isExpanded: $showsMore) {
                        TextField("Konkretes Ergebnis", text: $result, axis: .vertical)
                            .lineLimit(1...5)
                        TextField("Nächster Schritt oder Blocker", text: $nextStep, axis: .vertical)
                            .lineLimit(1...4)
                    }
                }
                if let block = draft.block {
                    Section {
                        Button("Eintrag löschen", systemImage: "trash", role: .destructive) {
                            app.trash([block])
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(captureTitle(baseTitle, day: day, today: app.today))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                // K1: an unknown area is cleared – the area is always chosen on purpose.
                if !categoryKey.isEmpty, !sortedCategories.contains(where: { $0.key == categoryKey }) { categoryKey = "" }
                loadSuggestions()
                if draft.block == nil {
                    loadCombos()
                    if !categoryKey.isEmpty { taskFocused = true }
                }
            }
            .onChange(of: categoryKey) { _, _ in
                loadSuggestions()
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 480, height: 640)
    }

    /// R32: once per area, not per keystroke.
    private func loadSuggestions() {
        suggestions = categoryKey.isEmpty ? [] : app.store.workSuggestions(categoryKey: categoryKey)
    }

    /// R33: the last three combinations whose area still exists.
    private func loadCombos() {
        let known: Set<String> = Set(sortedCategories.map(\.key))
        combos = app.store.recentWorkCombos().filter { known.contains($0.categoryKey) }
    }

    /// R33: a tap fills area, description and amount; saving stays a deliberate step (K1).
    private func apply(_ combo: WorkCombo) {
        categoryKey = combo.categoryKey
        task = combo.task
        powerHours = combo.powerHours
        taskFocused = true
    }

    private func save() {
        guard canSave else { return }
        if let block = draft.block {
            // R41: a changed day moves the entry.
            app.store.update(block, categoryKey: categoryKey, task: task, powerHours: powerHours, result: result,
                             nextStep: nextStep, day: day)
        } else {
            // R13: new power-hours get the toast with Undo.
            app.addPowerHours(powerHours, categoryKey: categoryKey, task: task, day: day,
                              result: result, nextStep: nextStep)
        }
        dismiss()
    }
}

/// A selectable capsule (quick values, categories, suggestions).
struct ChipButton: View {
    let title: String
    let isSelected: Bool
    var symbol: String?
    let action: () -> Void
    /// R67: grows with the system text size; identical at the standard size.
    @ScaledMetric(relativeTo: .subheadline) private var horizontalPadding: CGFloat = 12
    @ScaledMetric(relativeTo: .subheadline) private var verticalPadding: CGFloat = 7
    @ScaledMetric(relativeTo: .subheadline) private var minHeight: CGFloat = 34

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.caption2) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(minHeight: minHeight)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Color.accentFill : Color.secondary.opacity(0.14), in: .capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: Measurements

/// A measurement on a day: its entries, a new value, Apple Health, the last two weeks.
struct MeasureSheet: View {
    let code: String
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WeekReader(week: day.week, today: app.today) { context in
                if code.isEmpty {
                    MeasurePicker(context: context, day: day)
                } else if let measure = context.measure(code: code) {
                    MeasureForm(measure: measure, day: day, context: context)
                } else {
                    ContentUnavailableView("Messwert nicht gefunden", systemImage: "ruler",
                                           description: Text("In dieser Woche gibt es keinen Messwert „\(code)“."))
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .thaliaSheetFrame(width: 480, height: 720)
    }
}

/// "Messwert eintragen" (also ⇧⌘E on the Mac): v11 P5.4 – "Heute" (due today, not weekly) and "Diese Woche" (weekly
/// ones and those not due today), each row with its key and current value; the chosen one opens with the value
/// field focused.
struct MeasurePicker: View {
    let context: WeekContext
    let day: DayKey
    @State private var chosen: String?

    /// Due on the day and counted per day.
    private var todays: [MeasureDefinition] {
        context.measures.filter { context.applies($0, on: day) && $0.record?.period != .week }
    }

    /// Weekly ones and those not due on the day.
    private var thisWeek: [MeasureDefinition] {
        context.measures.filter { !context.applies($0, on: day) || $0.record?.period == .week }
    }

    /// "Heute", or the shown day's short label when the sheet records on another day (R41).
    private var dayTitle: String {
        day == context.today ? "Heute" : day.shortLabel
    }

    var body: some View {
        let today: [MeasureDefinition] = todays
        let week: [MeasureDefinition] = thisWeek
        let todayTitle: String = dayTitle
        List {
            if !today.isEmpty {
                Section(todayTitle) {
                    ForEach(today) { measure in
                        row(measure, weekly: false)
                    }
                }
            }
            if !week.isEmpty {
                Section("Diese Woche") {
                    ForEach(week) { measure in
                        row(measure, weekly: measure.record?.period == .week)
                    }
                }
            }
        }
        .overlay {
            if context.measures.isEmpty {
                ContentUnavailableView("Keine Messwerte", systemImage: "ruler", description: Text("Der Wochenplan legt die Messwerte fest."))
            }
        }
        .navigationTitle("Messwert eintragen")
        .inlineNavigationTitle()
    }

    private func row(_ measure: MeasureDefinition, weekly: Bool) -> some View {
        NavigationLink {
            MeasureForm(measure: measure, day: day, context: context, autofocus: true)
        } label: {
            HStack(spacing: 10) {
                if !measure.categoryKey.isEmpty {
                    KeyBadge(key: measure.categoryKey)
                }
                Text(measure.title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(currentValue(measure, weekly: weekly))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The day's value, for a weekly one the week's ("Woche 6 PH"); "–" without.
    private func currentValue(_ measure: MeasureDefinition, weekly: Bool) -> String {
        let unit: String = measure.record?.isWork == true ? "PH" : measure.unit
        if weekly {
            guard let value = context.weekValue(measure) else { return "–" }
            return "Woche \(Format.measure(value, unit: unit))"
        }
        guard let value = context.dayValue(measure, on: day) else { return "–" }
        return Format.measure(value, unit: unit)
    }
}

/// One measurement on one day. Power-hours and spendings keep their rules here, too (R3): work
/// measurements list the day's power-hours with what they were for and open the power-hours sheet;
/// spendings use the same row as Today, with "Wofür" required and every spending editable.
struct MeasureForm: View {
    let measure: MeasureDefinition
    let day: DayKey
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Query private var history: [MeasureEntry]
    @State private var valueText = ""
    @State private var time: Date
    @State private var text = ""
    @State private var estimate = false
    @State private var note = ""
    /// Power-hours sheet opened from a work measurement (R3).
    @State private var workDraft: WorkDraft? = nil
    /// The spending being changed in the spending row (R3, R46).
    @State private var editingExpense: MeasureEntry? = nil
    @FocusState private var valueFocused: Bool
    /// v11 P5.4: chosen in "Messwert eintragen" – the value field takes the focus; Today's ⓘ and "Verlauf und
    /// Einträge…" open without.
    private let autofocus: Bool

    init(measure: MeasureDefinition, day: DayKey, context: WeekContext, autofocus: Bool = false) {
        self.measure = measure
        self.day = day
        self.context = context
        self.autofocus = autofocus
        let code = measure.code
        let days = (0..<14).map { day.adding(days: -$0).string }
        _history = Query(filter: #Predicate<MeasureEntry> { $0.code == code && $0.deletedAt == nil && days.contains($0.dayKey) })
        // R3/R29: a new time starts like the tile – the time target, else 23:00 – built for this day.
        let startMinutes: Double = measure.record?.defaultClockMinutes ?? 23 * 60
        _time = State(initialValue: day.date(minutes: startMinutes))
    }

    private var record: MeasureRecord? { measure.record }
    private var isTime: Bool { record?.isTime ?? false }
    private var isText: Bool { record?.isText ?? false }
    private var isWork: Bool { record?.isWork ?? false }
    private var isExpense: Bool { context.isExpense(measure) }
    /// Quick +step buttons only where the day's entries add up (no "+0,1" on a weight).
    private var isSum: Bool { record?.aggregation == .sum }
    private var todays: [MeasureEntry] { context.entries.filter { $0.code == measure.code && $0.dayKey == day.string }.sorted { $0.recordedAt < $1.recordedAt } }

    /// The area a work measurement counts.
    private var workArea: String {
        guard let record, case .work(let category) = record.source else { return "" }
        return category.isEmpty ? measure.categoryKey : category
    }

    /// The day's power-hours of that area, oldest first.
    private var workBlocks: [WorkBlock] {
        let area: String = workArea
        return context.work(on: day).filter { $0.categoryKey == area }.sorted { $0.createdAt < $1.createdAt }
    }

    private var dayValueText: String {
        guard let value = context.dayValue(measure, on: day) else { return "–" }
        return Format.measure(value, unit: measure.unit)
    }

    // HEALTHSHARE: the Apple Health section's texts while Health values are shared (TestFlight only, §1.4.10, P9.4).
    private var sharesHealth: Bool { app.healthShare.sharesHealth(store: app.store) }

    // HEALTHSHARE
    private var adoptTitle: String {
        sharesHealth ? "Übernehmen" : "Übernehmen (bleibt auf diesem Gerät)"
    }

    // HEALTHSHARE
    private var adoptFooter: String {
        guard sharesHealth else {
            return "Ein Vorschlag, kein automatischer Eintrag. Gesundheitsdaten werden nie in iCloud gespeichert; ein eigener Eintrag hat Vorrang."
        }
        return "Ein Vorschlag, kein automatischer Eintrag. Übernommene Werte gehen an Mac und Watch (nur TestFlight); ein eigener Eintrag hat Vorrang."
    }

    private var weekValueText: String {
        guard let value = context.weekValue(measure) else { return "–" }
        return Format.measure(value, unit: measure.unit)
    }

    /// Text needs some text, a number a valid number; a time always has one.
    private var canAdd: Bool {
        if isText { return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if isTime { return true }
        return Format.parse(valueText) != nil
    }

    private var quickSteps: [Double] {
        let step: Double = Units.step(measure.unit)
        return [1.0, 2.0, 5.0].map { $0 * step }
    }

    private var chartPoints: [MeasurePoint] {
        let aggregation = record?.aggregation ?? .sum
        return (0..<14).compactMap { offset -> MeasurePoint? in
            let d = day.adding(days: offset - 13)
            let values = history.filter { $0.dayKey == d.string }.sorted { $0.recordedAt < $1.recordedAt }.compactMap(\.value)
            return aggregation.apply(values).map { MeasurePoint(day: d, value: $0) }
        }
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(day.shortLabel) {
                    Text(dayValueText)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                if day != app.today {
                    // R41: the same hint as every capture sheet.
                    Label("Zählt für \(day.shortLabel) – nicht für heute", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                if let target = record?.target {
                    LabeledContent("Ziel", value: "\(target.label) \(record?.period.label ?? "")")
                    if record?.period == .week {
                        LabeledContent("Diese Woche", value: weekValueText)
                    }
                }
                if !measure.details.isEmpty {
                    Text(measure.details).font(.caption).foregroundStyle(.secondary)
                }
            }

            if isWork {
                workSection
            } else if isExpense {
                expenseSection
            } else if isList {
                listSection
            } else {
                entrySection
            }

            if let suggestion = health.suggestion(code: measure.code, day: day) {
                Section {
                    LabeledContent("Apple Health", value: Format.measure(suggestion, unit: measure.unit))
                    Button {
                        app.store.adoptHealth(code: measure.code, day: day, value: suggestion)
                    } label: {
                        // HEALTHSHARE: `adoptTitle` – "Übernehmen" while Health values are shared (P9.4).
                        Label(adoptTitle, systemImage: "heart.text.square")
                    }
                } footer: {
                    // HEALTHSHARE: `adoptFooter` (P9.4).
                    Text(adoptFooter)
                }
            }
            // HEALTHSHARE: Mac, watch, iPad – the day's value is the one the iPhone shares (§1.4.8).
            if context.sharedHealthValue(measure, on: day) != nil {
                Section {
                    Label(HealthShareController.sharedCaption, systemImage: "iphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Ein eigener Wert für den Tag geht vor.")
                }
                // HEALTHSHARE: read on the iPhone, taken over nowhere – only shown.
            } else if let phone = context.sharedHealthSuggestion(measure, on: day) {
                Section {
                    Label(HealthShareController.phoneSuggestionText(phone, unit: measure.unit), systemImage: "iphone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if context.health.contains(where: { $0.code == measure.code && $0.dayKey == day.string }) {
                Section {
                    Button("Übernommenen Health-Wert entfernen", role: .destructive) {
                        app.store.removeHealth(code: measure.code, day: day)
                    }
                }
            }

            if !isExpense, !todays.isEmpty {
                Section("Einträge \(day.shortLabel)") {
                    ForEach(todays) { entry in
                        HStack {
                            Text(entry.value.map { Format.measure($0, unit: measure.unit) } ?? entry.text)
                                .monospacedDigit()
                            if entry.isEstimate {
                                Text("geschätzt").font(.caption2).foregroundStyle(.orange)
                            }
                            Spacer()
                            Text(entry.recordedAt, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([entry]) }
                        }
                        .contextMenu {
                            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([entry]) }
                        }
                    }
                }
            }

            if !isText, chartPoints.count > 1 {
                Section("Letzte 14 Tage") {
                    Chart {
                        ForEach(chartPoints) { point in
                            BarMark(x: .value("Tag", point.day.weekday.short + " \(point.day.day)."), y: .value(measure.title, point.value))
                                .foregroundStyle(Brand.accent)
                        }
                        if let target = record?.target, !target.isTime {
                            RuleMark(y: .value("Ziel", target.value))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }
                    .chartXAxis {
                        AxisMarks { _ in AxisValueLabel().font(.system(size: 8)) }
                    }
                    .frame(height: 150)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(captureTitle(measure.title, day: day, today: app.today))
        .inlineNavigationTitle()
        .sheet(item: $workDraft) { draft in
            WorkEditor(draft: draft)
                .environment(app)
                .modelContainer(app.container)
                .toastHost(app)
        }
        // v11 P5.4: only a typed number gets the focus – times, text, work, spending and reading have their own ways.
        // A moment after appearing: a focus set while the page is still being pushed can get lost.
        .task {
            guard autofocus, !isTime, !isText, !isWork, !isExpense, !isList else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            valueFocused = true
        }
    }

    /// R3: power-hours only with an area and what they were for – the day's entries and the sheet.
    private var workSection: some View {
        Section {
            ForEach(workBlocks) { block in
                Button {
                    workDraft = WorkDraft(block: block, day: day, categoryKey: block.categoryKey, powerHours: block.hours)
                } label: {
                    WorkBlockLine(block: block)
                }
                .buttonStyle(.plain)
            }
            Button {
                workDraft = WorkDraft(day: day, categoryKey: workArea)
            } label: {
                Label("Power-Hours erfassen", systemImage: "bolt.fill")
            }
        } header: {
            Text("Power-Hours \(day.shortLabel)")
        } footer: {
            Text("Dieser Wert kommt aus den Power-Hours im Bereich \(workArea) – jeder Eintrag mit „Wofür“. Ein Tipp auf einen Eintrag ändert ihn.")
        }
    }

    /// R3: the spending row of Today – amount and "Wofür" (K2) – and the day's spendings to change (R46).
    private var expenseSection: some View {
        Section {
            ExpenseInputRow(measure: measure, context: context, day: day, editing: $editingExpense)
            ForEach(context.expenseEntries(measure, on: day)) { expense in
                ExpenseEntryRow(entry: expense, onEdit: { editingExpense = expense })
            }
        } header: {
            Text("Ausgaben \(day.shortLabel)")
        } footer: {
            Text("Jede Ausgabe mit „Wofür“. Ein Tipp auf eine Ausgabe ändert sie.")
        }
    }

    /// v10 (§1.3.3): the reading list's pages are entered once, in "Lesen" – an own value here would
    /// hide the readings of the day.
    private var isList: Bool { record?.isList ?? false }

    private var listSection: some View {
        Section {
            Button {
                app.sheet = .reading(day, itemID: nil)
            } label: {
                Label("Lesen…", systemImage: "book")
            }
        } header: {
            Text("Leseliste")
        } footer: {
            Text("Dieser Messwert zählt die Seiten der Leseliste. Eingetragen wird über „Lesen“ – so zählen sie nur einmal.")
        }
    }

    private var entrySection: some View {
        Section {
            if isText {
                TextField("Text", text: $text, axis: .vertical)
            } else if isTime {
                DatePicker("Uhrzeit", selection: $time, displayedComponents: .hourAndMinute)
                    .thaliaDateLocale()
            } else {
                HStack {
                    TextField("Wert", text: $valueText)
                        .decimalKeyboard()
                        .focused($valueFocused)
                        .onSubmit(addEntry)
                        .keypadButton("Fertig", isActive: valueFocused) { addEntry() }
                    Text(Units.display(measure.unit)).foregroundStyle(.secondary)
                }
                if isSum {
                    HStack {
                        ForEach(quickSteps, id: \.self) { step in
                            Button("+\(Format.number(step))") { app.add(step, to: measure, day: day) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            Toggle("Schätzung", isOn: $estimate)
            TextField("Notiz (optional)", text: $note)
            Button {
                addEntry()
            } label: {
                Label("Eintragen", systemImage: "plus.circle.fill")
            }
            .disabled(!canAdd)
        } header: {
            Text("Neuer Eintrag")
        } footer: {
            Text(isSum ? "Mehrere Einträge eines Tages werden addiert." : "Der letzte Eintrag des Tages zählt.")
        }
    }

    private func addEntry() {
        guard canAdd else { return }
        var value: Double?
        if isTime {
            // R29: minutes of the picked time on this day, not seconds since midnight.
            value = DayKey.minutes(of: time).rounded(.down)
        } else if !isText {
            value = Format.parse(valueText)
        }
        let typed: String = isText ? text.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        app.store.addEntry(code: measure.code, day: day, value: value, text: typed, estimate: estimate, note: note)
        valueText = ""
        text = ""
        note = ""
        estimate = false
        valueFocused = false
    }
}

/// One power-hours entry: what for, the amount.
private struct WorkBlockLine: View {
    let block: WorkBlock

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(Brand.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(block.task.isEmpty ? "ohne Beschreibung" : block.task)
                    .foregroundStyle(block.task.isEmpty ? Color.orange : Color.primary)
                    .lineLimit(2)
                if !block.result.isEmpty {
                    Text(block.result)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(Format.powerHours(block.hours))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .contentShape(.rect)
    }
}

struct MeasurePoint: Identifiable {
    let day: DayKey
    let value: Double
    var id: String { day.string }
}

// MARK: Notes

struct NoteEditor: View {
    let note: DayNote?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    /// The day the note counts for; editing can move it (R41).
    @State private var day: DayKey
    @State private var kind: NoteKind
    @State private var text: String
    @FocusState private var focused: Bool
    private let initialKind: NoteKind
    private let initialText: String
    private let initialDay: DayKey

    init(note: DayNote?, day: DayKey) {
        self.note = note
        let noteDay: DayKey? = note.flatMap { DayKey($0.dayKey) }
        let start: DayKey = noteDay ?? day
        let kind: NoteKind = note?.kind ?? .observation
        let text: String = note?.text ?? ""
        _day = State(initialValue: start)
        _kind = State(initialValue: kind)
        _text = State(initialValue: text)
        initialKind = kind
        initialText = text
        initialDay = start
    }

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// R14: typed text (or a changed kind/day of an existing note) not saved yet.
    private var isDirty: Bool {
        guard note != nil else { return !trimmedText.isEmpty }
        return text != initialText || kind != initialKind || day != initialDay
    }

    private var baseTitle: String {
        note == nil ? "Notiz" : "Notiz bearbeiten"
    }

    private var placeholder: String {
        kind == .idea ? "Idee – geparkt, kein neues Projekt" : "Was ist passiert?"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CaptureDayRow(day: $day, today: app.today)
                }
                Section {
                    // R78: the kinds as chips with their symbol.
                    WrapLayout(spacing: 8) {
                        ForEach(NoteKind.allCases, id: \.self) { option in
                            ChipButton(title: option.label, isSelected: kind == option, symbol: option.symbol) {
                                kind = option
                            }
                        }
                    }
                    .padding(.vertical, 2)
                } header: {
                    Text("Art")
                }
                Section {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(3...10)
                        .focused($focused)
                }
                if let note {
                    Section {
                        Button("Notiz löschen", systemImage: "trash", role: .destructive) {
                            app.trash([note])
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(captureTitle(baseTitle, day: day, today: app.today))
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear { if note == nil { focused = true } }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 440, height: 440)
    }

    private func save() {
        guard !trimmedText.isEmpty else { return }
        if let note {
            // R41: a changed day moves the note.
            app.store.update(note, kind: kind, text: trimmedText, day: day)
        } else {
            app.store.addNote(day: day, kind: kind, text: trimmedText)
        }
        dismiss()
    }
}

// MARK: Items

/// An item in detail: what counts as done, its week, today's mark and note, editing.
struct ItemDetailView: View {
    let item: PlanItem
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WeekReader(week: WeekKey(item.weekKey) ?? day.week, today: app.today) { context in
                ItemDetailForm(item: item, day: context.week.contains(day) ? day : context.week.monday, context: context)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .thaliaSheetFrame(width: 480, height: 720)
    }
}

struct ItemDetailForm: View {
    let item: PlanItem
    let day: DayKey
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var editing = false
    @State private var confirmsDelete = false
    /// R9: the value behind an automatic item, opened on top of this sheet.
    @State private var valueSheet: AppSheet? = nil
    /// After deleting, the note isn't written back on closing.
    @State private var isDeleted = false

    private var isProgress: Bool { item.schedule == .progress }

    /// "Liegestütze ≥ 20" or "Liegestütze (erfasst)"; v10: an item linked to an `app:` / `list:` text directly
    /// names its source ("George · Workouts · Push ≥ 1").
    private var measureLine: String {
        let title: String = context.measureRecord(code: item.measureCode)?.title ?? item.measureCode
        guard !item.targetRaw.isEmpty else { return "\(title) (erfasst)" }
        let label: String = Target.parse(item.targetRaw)?.label ?? ""
        return "\(title) \(label)"
    }

    /// R43: the words of the marks, the same as on the buttons.
    private var markFooter: String {
        if isProgress {
            return "Gearbeitet · Nicht heute · leer = nicht erfasst. Am Wochenende zählt, wie weit das Wochenziel erreicht ist."
        }
        return "Erledigt · Teilweise · Nicht erledigt · Entfällt · leer = nicht erfasst"
    }

    private var emptyText: String {
        context.isDerived(item) ? "Automatisch aus dem Wochenziel" : "Zählt heute nicht"
    }

    /// A typed note that isn't stored yet blocks the menu commands (R14).
    private var isDirty: Bool {
        !isDeleted && note != context.markNote(item, on: day)
    }

    var body: some View {
        let mark = context.mark(item, on: day)
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        KeyBadge(key: item.categoryKey)
                        Text(context.category(item.categoryKey)?.title ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.title).font(.title3.weight(.bold))
                    if !item.details.isEmpty {
                        Text(item.details).font(.subheadline)
                    }
                }
                LabeledContent("Tage", value: item.days.label)
                LabeledContent("Rhythmus", value: item.schedule.label)
                if let quota = context.quotaProgress(item) {
                    LabeledContent("Diese Woche", value: "\(quota.done) von \(quota.target)")
                }
                if !item.measureCode.isEmpty {
                    LabeledContent("Messwert", value: measureLine)
                    if let source = linkSource {
                        LabeledContent("Quelle", value: source)
                    }
                }
                if item.isKnockout {
                    Label("Persönliche Null-Regel: „Nicht erledigt“ setzt die Kategorie an diesem Tag auf 0. Die Daten bleiben erhalten.", systemImage: "exclamationmark.octagon")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                markButtons(mark: mark)
                if let derived = context.derivedMarkLabel(item, on: day) {
                    // v10 (§1.5.3): an own mark – also clearing this one – always wins.
                    DerivedMarkNote(label: derived + " – eine eigene Markierung geht vor")
                }
                if let suggestion = context.suggestion(item, on: day) {
                    Button {
                        app.setMark(suggestion, item: item, day: day)
                    } label: {
                        Label("Vorschlag aus dem Messwert: \(suggestion.label(progress: isProgress))", systemImage: "wand.and.stars")
                    }
                }
                TextField("Notiz zu \(day.weekday.name)", text: $note, axis: .vertical)
                    .onSubmit(saveNote)
            } header: {
                Text(day.longLabel)
            } footer: {
                Text(markFooter)
            }

            Section("Woche") {
                HStack(spacing: 4) {
                    ForEach(context.week.days, id: \.self) { d in
                        VStack(spacing: 3) {
                            Text(d.weekday.short).font(.caption2).foregroundStyle(.secondary)
                            weekCell(d)
                                .frame(height: 32)
                        }
                    }
                }
            }

            Section {
                Button("Punkt bearbeiten", systemImage: "pencil") { editing = true }
                Button("Punkt löschen", systemImage: "trash", role: .destructive) {
                    confirmsDelete = true
                }
            }
        }
        .confirmationDialog("„\(item.title)“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Löschen – auch künftig weglassen", role: .destructive) { delete(carryOver: true) }
            Button("Nur diese Woche löschen", role: .destructive) { delete(carryOver: false) }
        } message: {
            Text("Der nächste Planungs-Prompt sagt der KI, ob der Punkt dauerhaft wegfällt.")
        }
        .formStyle(.grouped)
        .navigationTitle("Punkt")
        .inlineNavigationTitle()
        .onAppear { note = context.markNote(item, on: day) }
        .onDisappear(perform: saveNote)
        .unsavedInput(isDirty, in: app)
        .sheet(isPresented: $editing) {
            ItemEditor(week: context.week, item: item)
                .environment(app)
                .toastHost(app)
        }
        .sheet(item: $valueSheet) { sheet in
            valueView(sheet)
                .environment(app)
                .environment(health)
                .modelContainer(app.container)
                .toastHost(app)
        }
    }

    /// R43: the same buttons as Today; nothing to mark → why, and for automatic items the value (R9).
    @ViewBuilder
    private func markButtons(mark: Mark?) -> some View {
        let options: [Mark] = context.options(item, on: day)
        if options.isEmpty {
            Label(emptyText, systemImage: "wand.and.stars")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let sheet = MarkCell.valueSheet(for: item, context: context, day: day) {
                Button("Wert eintragen", systemImage: "square.and.pencil") { valueSheet = sheet }
            }
        } else {
            MarkBar(mark: mark, options: options, suggestion: context.suggestion(item, on: day),
                    isProgress: isProgress) { app.setMark($0, item: item, day: day) }
        }
    }

    /// R9: one day of the week – the same rules as the week (no tap on free days, automatic items
    /// open their value).
    private func weekCell(_ d: DayKey) -> some View {
        let mark: Mark? = context.mark(item, on: d)
        let sheet: AppSheet? = MarkCell.valueSheet(for: item, context: context, day: d)
        return MarkCell(
            mark: mark,
            applies: item.days.contains(d.weekday) && item.schedule != .optional,
            isToday: d == context.today,
            suggestion: context.suggestion(item, on: d),
            options: context.options(item, on: d),
            hasNote: !context.markNote(item, on: d).isEmpty,
            accessibilityPrefix: "\(d.weekday.name), \(item.title)",
            help: cellHelp(mark, day: d),
            onOpenValue: opener(sheet),
            onSet: { app.setMark($0, item: item, day: d) }
        )
    }

    /// "Mi, 18. Nov. · Erledigt".
    private func cellHelp(_ mark: Mark?, day: DayKey) -> String {
        let word: String = mark?.label(progress: isProgress) ?? "Nicht erfasst"
        return "\(day.shortLabel) · \(word)"
    }

    private func opener(_ sheet: AppSheet?) -> (() -> Void)? {
        guard let sheet else { return nil }
        return { valueSheet = sheet }
    }

    @ViewBuilder
    private func valueView(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .work(let draft):
            WorkEditor(draft: draft)
        case .expenses(let day):
            ExpensesSheet(day: day)
        case .measure(let code, let day):
            MeasureSheet(code: code, day: day)
        default:
            EmptyView()
        }
    }

    /// R23: only the note – the mark stays as it is stored. v10: a note on a day with a ✓ from a connected
    /// app keeps that ✓ (the new own mark takes it over), so writing a note never removes it.
    private func saveNote() {
        guard !isDeleted, note != context.markNote(item, on: day) else { return }
        app.store.setMarkNote(note, item: item, day: day, derived: derivedMark)
    }

    /// The ✓ shown from a connected app that day (no own mark yet); nil otherwise.
    private var derivedMark: Mark? {
        guard context.isDerivedMark(item, on: day) else { return nil }
        return context.mark(item, on: day)
    }

    /// v10: "George · Workouts · Push" – where the linked measure's value comes from; nil for manual ones.
    private var linkSource: String? {
        guard let record = context.measureRecord(code: item.measureCode) else { return nil }
        return LinkTexts.sourceLabel(record.source, sources: context.exchangeSources)
    }

    /// R13: deleting closes the sheet; the toast with Undo shows on the layer below.
    private func delete(carryOver: Bool) {
        saveNote()
        isDeleted = true
        app.trash([item], carryOver: carryOver)
        dismiss()
    }
}

/// New item for a week, or editing one.
struct ItemEditor: View {
    let week: WeekKey
    let item: PlanItem?
    var presetCategory: String?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TrackCategory> { $0.deletedAt == nil }) private var categories: [TrackCategory]

    @State private var categoryKey: String
    @State private var title: String
    @State private var details: String
    @State private var days: Set<Weekday>
    @State private var scheduleKind: String
    @State private var weeklyCount: Int
    @State private var knockout: Bool
    @State private var measureCode: String
    @State private var carryOver = true
    @State private var secondary: Bool
    @State private var dayRule: DayRule
    /// The fields as the sheet opened (R14); set once on appear.
    @State private var initialFields: [String]? = nil
    /// v10: the connected apps seen, for the link's label ("George · Workouts · Push").
    @State private var exchangeSources = ExchangeSourceList()
    @Query(filter: #Predicate<MeasureDefinition> { $0.deletedAt == nil }) private var allMeasures: [MeasureDefinition]

    init(week: WeekKey, item: PlanItem?, presetCategory: String? = nil) {
        self.week = week
        self.item = item
        self.presetCategory = presetCategory
        _categoryKey = State(initialValue: item?.categoryKey ?? presetCategory ?? "")
        _measureCode = State(initialValue: item?.measureCode ?? "")
        _secondary = State(initialValue: item?.record?.secondary ?? false)
        _dayRule = State(initialValue: item?.record?.dayRule ?? .auto)
        _title = State(initialValue: item?.title ?? "")
        _details = State(initialValue: item?.details ?? "")
        _days = State(initialValue: Set(item?.days.days ?? Weekday.allCases))
        let schedule = item?.schedule ?? .fixed
        switch schedule {
        case .fixed: _scheduleKind = State(initialValue: "fix")
        case .weekly: _scheduleKind = State(initialValue: "woche")
        case .conditional: _scheduleKind = State(initialValue: "bedingt")
        case .optional: _scheduleKind = State(initialValue: "optional")
        case .progress: _scheduleKind = State(initialValue: "fortschritt")
        }
        _weeklyCount = State(initialValue: schedule.weeklyTarget ?? 2)
        _knockout = State(initialValue: item?.isKnockout ?? false)
    }

    private var sortedCategories: [TrackCategory] {
        Array(categories.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }

    private var schedule: ItemSchedule {
        switch scheduleKind {
        case "woche": .weekly(weeklyCount)
        case "bedingt": .conditional
        case "optional": .optional
        case "fortschritt": .progress
        default: .fixed
        }
    }

    private var weekMeasures: [MeasureDefinition] {
        let key = week.string
        return Array(allMeasures.filter { $0.weekKey == key }.latest(by: \.code, modified: \.modifiedAt).values)
            .sorted { $0.title < $1.title }
    }

    /// The measure the item is linked to; v10: also a link straight to "app:…" / "list:…" (from the plan),
    /// and below it what the item is linked to and where its tick comes from (§1.5.4).
    @ViewBuilder
    private var measurePicker: some View {
        Picker("Messwert", selection: $measureCode) {
            Text("keiner").tag("")
            ForEach(weekMeasures) { measure in
                Text(measure.title).tag(measure.code)
            }
            if let direct = directLinkTitle {
                Text(direct).tag(measureCode)
            }
        }
        ItemLinkRow(code: measureCode, measure: linkedMeasure, sources: exchangeSources)
    }

    /// v10: the week's measure the item is linked to.
    private var linkedMeasure: MeasureRecord? {
        weekMeasures.first { $0.code == measureCode }?.record
    }

    /// v10: the item links to an `app:` / `list:` text directly (no measure of the week has that code).
    private var directLinkTitle: String? {
        guard !measureCode.isEmpty, linkedMeasure == nil else { return nil }
        return LinkTexts.itemLink(code: measureCode, measure: nil, sources: exchangeSources)
    }

    /// Everything the form edits, to see whether something changed (R14).
    private func fields(category: String) -> [String] {
        let dayLetters: String = Weekday.allCases.filter { days.contains($0) }.map(\.short).joined(separator: ",")
        return [category, title, details, dayLetters, scheduleKind, String(weeklyCount), String(knockout), measureCode,
                String(secondary), dayRule.rawValue]
    }

    private var isDirty: Bool {
        guard let initialFields else { return false }
        return fields(category: categoryKey) != initialFields
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kategorie", selection: $categoryKey) {
                        ForEach(sortedCategories) { category in
                            Text("\(category.key) \(category.title)").tag(category.key)
                        }
                    }
                    TextField("Kurzer, präziser Titel", text: $title)
                    TextField("Was zählt als erledigt? Ziel, Zeitpunkt, Bedingung", text: $details, axis: .vertical)
                        .lineLimit(2...6)
                }
                Section {
                    HStack(spacing: 4) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            Button(day.short) {
                                if days.contains(day) { days.remove(day) } else { days.insert(day) }
                            }
                            .buttonStyle(.bordered)
                            .tint(days.contains(day) ? Brand.accent : .secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    Picker("Rhythmus", selection: $scheduleKind) {
                        Text("fest").tag("fix")
                        Text("× pro Woche").tag("woche")
                        Text("bedingt").tag("bedingt")
                        Text("optional").tag("optional")
                        Text("Wochenfortschritt").tag("fortschritt")
                    }
                    if scheduleKind == "woche" {
                        Stepper("\(weeklyCount)× pro Woche", value: $weeklyCount, in: 1...7)
                    }
                    if scheduleKind == "fortschritt" || !measureCode.isEmpty {
                        measurePicker
                    }
                    Toggle("Persönliche Null-Regel (Nicht erledigt → Kategorie 0)", isOn: $knockout)
                    Toggle("Nebensache (zählt nur, wenn ausgefüllt)", isOn: $secondary)
                    DayRulePicker(rule: $dayRule)
                } header: {
                    Text("Wann")
                } footer: {
                    if scheduleKind == "fortschritt" {
                        Text("„Daran gearbeitet“ oder „Nicht heute“ – am Wochenende zählt, wie weit der Messwert (z. B. 8 PH) erreicht ist.")
                    }
                }
                Section {
                    Toggle("Auch in den nächsten Wochen", isOn: $carryOver)
                } footer: {
                    Text(carryOver ? "Der nächste Planungs-Prompt übernimmt die Änderung dauerhaft („manuell überschrieben in die nächste Woche“)."
                         : "Gilt nur für diese Woche – der Prompt sagt der KI, dass sie nicht übernommen wird.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(item == nil ? "Neuer Punkt" : "Punkt bearbeiten")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || categoryKey.isEmpty || days.isEmpty)
                }
            }
            .onAppear {
                let category: String = categoryKey.isEmpty ? (sortedCategories.first?.key ?? "") : categoryKey
                categoryKey = category
                if initialFields == nil { initialFields = fields(category: category) }
                exchangeSources = app.store.exchangeSources()
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 480, height: 640)
    }

    private func save() {
        let mask = DayMask(Array(days))
        if let item, var record = item.record {
            record.categoryKey = categoryKey
            record.title = title
            record.details = details
            record.days = mask
            record.schedule = schedule
            record.knockout = knockout
            record.measure = measureCode
            record.secondary = secondary
            record.dayRule = dayRule
            app.store.update(item, with: record, carryOver: carryOver)
        } else {
            let added = app.store.addItem(week: week, categoryKey: categoryKey, title: title, details: details, days: mask,
                                          schedule: schedule, measure: measureCode, knockout: knockout, carryOver: carryOver)
            if (secondary || dayRule != .auto), var record = added.record {
                record.secondary = secondary
                record.dayRule = dayRule
                app.store.update(added, with: record, carryOver: carryOver)
            }
        }
        dismiss()
    }
}

/// A measurement of the week: add, change or delete it (U14). Every change goes into the next
/// planning prompt – permanently or for this week only.
struct MeasureDefinitionEditor: View {
    let week: WeekKey
    let measure: MeasureDefinition?
    var presetCategory: String?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TrackCategory> { $0.deletedAt == nil }) private var categories: [TrackCategory]

    @State private var categoryKey: String
    @State private var title: String
    @State private var details: String
    @State private var unit: String
    /// R77: the target from a choice – "" = no target, else `Target.Comparison.rawValue`.
    @State private var comparisonRaw: String
    @State private var lowerText: String
    @State private var upperText: String
    @State private var lowerTime: Date
    @State private var upperTime: Date
    @State private var period: TargetPeriod
    @State private var days: Set<Weekday>
    @State private var carryOver = true
    @State private var confirmsDelete = false
    @State private var secondary: Bool
    @State private var dayRule: DayRule
    /// v10 (§1.5.4): "Quelle" – Manuell, Power-Hours, Apple Health, Leseliste, Verbundene App.
    @State private var sourceDraft: MeasureSourceDraft
    /// v10: the connected apps seen (`x.sources`) with their refs, for the pickers.
    @State private var exchangeSources = ExchangeSourceList()
    /// The fields as the sheet opened (R14); set once on appear.
    @State private var initialFields: [String]? = nil
    /// The unit the measurement had – still offered when it is no longer a standard choice.
    private let initialUnit: String
    /// The stored target was a time of day.
    private let initialTimeTarget: Bool
    /// v10: the source as stored – saved back unchanged unless "Quelle" changes it.
    private let initialSource: MeasureSource

    init(week: WeekKey, measure: MeasureDefinition?, presetCategory: String? = nil) {
        self.week = week
        self.measure = measure
        self.presetCategory = presetCategory
        let unit: String = measure?.unit ?? ""
        // R77: an existing target is split into the fields.
        let parsed: Target? = Target.parse(measure?.targetRaw ?? "")
        let isTimeTarget: Bool = parsed?.isTime ?? false
        _categoryKey = State(initialValue: measure?.categoryKey ?? presetCategory ?? "")
        _title = State(initialValue: measure?.title ?? "")
        _details = State(initialValue: measure?.details ?? "")
        _unit = State(initialValue: unit)
        _comparisonRaw = State(initialValue: parsed?.comparison.rawValue ?? "")
        _lowerText = State(initialValue: MeasureDefinitionEditor.fieldText(parsed?.value, isTime: isTimeTarget))
        _upperText = State(initialValue: MeasureDefinitionEditor.fieldText(parsed?.upper, isTime: isTimeTarget))
        _lowerTime = State(initialValue: MeasureDefinitionEditor.fieldTime(parsed?.value, isTime: isTimeTarget))
        _upperTime = State(initialValue: MeasureDefinitionEditor.fieldTime(parsed?.upper, isTime: isTimeTarget))
        _period = State(initialValue: TargetPeriod(raw: measure?.periodRaw ?? "tag"))
        _days = State(initialValue: Set(measure?.days.days ?? Weekday.allCases))
        _secondary = State(initialValue: measure?.record?.secondary ?? false)
        _dayRule = State(initialValue: measure?.record?.dayRule ?? .auto)
        initialUnit = unit
        initialTimeTarget = isTimeTarget
        let source: MeasureSource = MeasureSource(raw: measure?.sourceRaw ?? "")
        initialSource = source
        _sourceDraft = State(initialValue: MeasureSourceDraft(source, categoryKey: measure?.categoryKey ?? presetCategory ?? ""))
    }

    /// A number for the value field ("8", "2,5", "1.200"); empty for times and missing values.
    private static func fieldText(_ value: Double?, isTime: Bool) -> String {
        guard let value, !isTime else { return "" }
        return Format.number(value, decimals: 4)
    }

    /// A time for the time picker; 23:00 when there is none.
    private static func fieldTime(_ value: Double?, isTime: Bool) -> Date {
        let minutes: Double = isTime ? (value ?? 23 * 60) : 23 * 60
        return DayKey.today().date(minutes: minutes)
    }

    private var sortedCategories: [TrackCategory] {
        Array(categories.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }

    /// R77: the standard units without "PH" – plus the unit the measurement already had (v10: and the one a
    /// source suggested, e.g. "kcal").
    private var unitChoices: [String] {
        var choices: [String] = Units.choices
        for extra in [initialUnit, unit] where !choices.contains(extra) { choices.append(extra) }
        return choices
    }

    private var comparison: Target.Comparison? {
        Target.Comparison(rawValue: comparisonRaw)
    }

    private var isRange: Bool {
        comparison == .range
    }

    /// Time picker for times of day (unit "Uhrzeit", or a time target kept with its unit).
    private var usesTime: Bool {
        Units.isTime(unit) || (initialTimeTarget && unit == initialUnit)
    }

    /// The target the fields describe; nil without a target or while a number is missing.
    private var target: Target? {
        guard let comparison else { return nil }
        if usesTime {
            let low: Double = DayKey.minutes(of: lowerTime).rounded(.down)
            guard comparison == .range else { return Target(comparison, low, isTime: true) }
            let high: Double = DayKey.minutes(of: upperTime).rounded(.down)
            return Target(.range, min(low, high), upper: max(low, high), isTime: true)
        }
        guard let low = Format.parse(lowerText) else { return nil }
        guard comparison == .range else { return Target(comparison, low) }
        guard let high = Format.parse(upperText) else { return nil }
        return Target(.range, min(low, high), upper: max(low, high))
    }

    /// A target is chosen, but its value is missing or not a number.
    private var targetIncomplete: Bool {
        comparison != nil && target == nil
    }

    /// Counted from power-hours (v10: also when "Quelle" was just set to Power-Hours).
    private var isWork: Bool {
        sourceDraft.choice == .work
    }

    /// Everything the form edits, to see whether something changed (R14).
    private func fields(category: String) -> [String] {
        let dayLetters: String = Weekday.allCases.filter { days.contains($0) }.map(\.short).joined(separator: ",")
        let times: String = "\(DayKey.minutes(of: lowerTime).rounded(.down))-\(DayKey.minutes(of: upperTime).rounded(.down))"
        return [category, title, details, unit, comparisonRaw, lowerText, upperText, times, period.rawValue, dayLetters,
                String(secondary), dayRule.rawValue] + sourceDraft.fields
    }

    /// v10: a new source suggests its unit ("Seiten", "kcal", "Stück"); leaving power-hours drops "PH".
    private func sourceChanged(from old: MeasureSourceDraft, to new: MeasureSourceDraft) {
        guard old.choice != new.choice || old.appKind != new.appKind || old.listKind != new.listKind else { return }
        if let suggested = new.suggestedUnit, new.choice != .work {
            unit = suggested
        } else if old.choice == .work, new.choice != .work, Units.normalized(unit) == "ph" {
            unit = ""
        }
    }

    private var isDirty: Bool {
        guard let initialFields else { return false }
        return fields(category: categoryKey) != initialFields
    }

    private func unitLabel(_ unit: String) -> String {
        unit.isEmpty ? "Zahl" : unit
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kategorie", selection: $categoryKey) {
                        Text("keine").tag("")
                        ForEach(sortedCategories) { category in
                            Text("\(category.key) \(category.title)").tag(category.key)
                        }
                    }
                    TextField("Name (z. B. Liegestütze)", text: $title)
                    TextField("Beschreibung (optional)", text: $details, axis: .vertical)
                        .lineLimit(1...4)
                }
                MeasureSourceSection(draft: $sourceDraft, categories: sortedCategories, sources: exchangeSources)
                goalSection
                Section {
                    Toggle("Auch in den nächsten Wochen", isOn: $carryOver)
                } footer: {
                    Text(carryOver ? "Der nächste Planungs-Prompt übernimmt die Änderung dauerhaft."
                         : "Gilt nur für diese Woche – der Prompt sagt der KI, dass sie nicht übernommen wird.")
                }
                existingSections
            }
            .formStyle(.grouped)
            .navigationTitle(measure == nil ? "Neuer Messwert" : "Messwert bearbeiten")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(cannotSave)
                }
            }
            .onChange(of: sourceDraft) { old, new in sourceChanged(from: old, to: new) }
            .confirmationDialog("„\(title)“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Löschen – auch künftig weglassen", role: .destructive) { delete(carryOver: true) }
                Button("Nur diese Woche löschen", role: .destructive) { delete(carryOver: false) }
            }
            .onAppear {
                if initialFields == nil { initialFields = fields(category: categoryKey) }
                exchangeSources = app.store.exchangeSources()
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 480, height: 680)
    }

    /// Unit, target, period, days (a section of its own, so the body stays small for the type checker).
    private var goalSection: some View {
        Section {
            if isWork {
                LabeledContent("Einheit", value: "PH aus den Einträgen")
            } else {
                Picker("Einheit", selection: $unit) {
                    ForEach(unitChoices, id: \.self) { choice in
                        Text(unitLabel(choice)).tag(choice)
                    }
                }
            }
            Picker("Ziel", selection: $comparisonRaw) {
                Text("kein Ziel").tag("")
                ForEach(Target.Comparison.choices, id: \.self) { choice in
                    Text(choice.choiceLabel).tag(choice.rawValue)
                }
            }
            if comparison != nil {
                targetFields
            }
            if let target {
                Text(target.sentence(period: period, unit: unit))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            } else if targetIncomplete {
                Label("Bitte einen Wert für das Ziel eintragen.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Picker("Zeitraum", selection: $period) {
                Text("pro Tag").tag(TargetPeriod.day)
                Text("pro Woche").tag(TargetPeriod.week)
            }
            .pickerStyle(.segmented)
            HStack(spacing: 4) {
                ForEach(Weekday.allCases, id: \.self) { day in
                    Button(day.short) {
                        if days.contains(day) { days.remove(day) } else { days.insert(day) }
                    }
                    .buttonStyle(.bordered)
                    .tint(days.contains(day) ? Brand.accent : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            Toggle("Nebensache (eingeklappt)", isOn: $secondary)
            DayRulePicker(rule: $dayRule)
        } header: {
            Text("Ziel")
        }
    }

    /// An existing measure: v10's "zählt für Ziel 5 · Bücher 3/10" (§1.2.4) and deleting.
    @ViewBuilder
    private var existingSections: some View {
        if let measure {
            MeasureCountsForSection(week: week, measure: measure)
            Section {
                Button("Messwert löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
            }
        }
    }

    /// A name, a day, a complete target and (v10) a complete source are needed.
    private var cannotSave: Bool {
        title.trimmingCharacters(in: .whitespaces).isEmpty || days.isEmpty || targetIncomplete || sourceDraft.isIncomplete
    }

    /// R77: the target's value – a number, or a time of day; "zwischen" needs a second one.
    @ViewBuilder
    private var targetFields: some View {
        if usesTime {
            DatePicker(isRange ? "Von" : "Uhrzeit", selection: $lowerTime, displayedComponents: .hourAndMinute)
                .thaliaDateLocale()
            if isRange {
                DatePicker("Bis", selection: $upperTime, displayedComponents: .hourAndMinute)
                    .thaliaDateLocale()
            }
        } else {
            HStack {
                TextField(isRange ? "Von" : "Wert", text: $lowerText)
                    .decimalKeyboard()
                Text(Units.display(unit)).foregroundStyle(.secondary)
            }
            if isRange {
                HStack {
                    TextField("Bis", text: $upperText)
                        .decimalKeyboard()
                    Text(Units.display(unit)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func save() {
        let mask = DayMask(Array(days))
        let source: MeasureSource = sourceDraft.resolved(original: initialSource)
        if let measure, var record = measure.record {
            record.categoryKey = categoryKey
            record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            record.details = details
            if !isWork {
                record.unit = unit
                record.aggregation = sourceDraft.aggregation(unit: unit)
            } else if !record.isWork {
                // v10: newly counted from power-hours – always in PH (R77).
                record.unit = "PH"
                record.aggregation = .sum
            }
            record.source = source
            record.target = target
            record.period = period
            record.days = mask
            record.secondary = secondary
            record.dayRule = dayRule
            app.store.update(measure, with: record, carryOver: carryOver)
        } else {
            let added = app.store.addMeasure(week: week, categoryKey: categoryKey, title: title, details: details,
                                             unit: isWork ? "PH" : unit, target: target, period: period, days: mask,
                                             carryOver: carryOver)
            // v10: a source other than the one `addMeasure` picks (manual, or PH → power-hours of the category).
            let needsSource: Bool = source != .manual && added.record?.source != source
            if (secondary || dayRule != .auto || needsSource), var record = added.record {
                record.secondary = secondary
                record.dayRule = dayRule
                if needsSource {
                    record.source = source
                    if !isWork { record.aggregation = sourceDraft.aggregation(unit: unit) }
                }
                app.store.update(added, with: record, carryOver: carryOver)
            }
        }
        dismiss()
    }

    private func delete(carryOver: Bool) {
        guard let measure else { return }
        app.trash([measure], carryOver: carryOver)
        dismiss()
    }
}

// MARK: Days and weeks

struct DayInfoEditor: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var type = ""
    @State private var note = ""
    /// R78: an own day type – only then the text field shows.
    @State private var isCustom = false
    /// Type and note as loaded (R14); nil until loaded.
    @State private var loaded: [String]? = nil

    private var isDirty: Bool {
        guard let loaded else { return false }
        return [type, note] != loaded
    }

    /// v8: Krank and Urlaub first – they take the day out of the week's score.
    private static let presetOrder: [String] =
        DayTypes.excusedPresets + DayTypes.presets.filter { !DayTypes.excusedPresets.contains($0) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WrapLayout(spacing: 8) {
                        ForEach(Self.presetOrder, id: \.self) { preset in
                            ChipButton(title: preset, isSelected: !isCustom && type == preset,
                                       symbol: DayTypes.symbol(for: preset)) {
                                choose(preset)
                            }
                        }
                        ChipButton(title: "Eigener …", isSelected: isCustom, symbol: "pencil") {
                            chooseCustom()
                        }
                    }
                    .padding(.vertical, 2)
                    if isCustom {
                        TextField("Eigener Tagestyp", text: $type)
                    }
                } header: {
                    Text("Tagestyp")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if DayTypes.isExcused(type) {
                            Label(DayTypes.excusedHint, systemImage: DayTypes.symbol(for: type))
                        } else if DayTypes.isWorkFree(type) {
                            Label(DayTypes.workFreeHint, systemImage: "sun.max")
                        }
                        Text("Ein Arbeits-, Reise-, Familien- oder Erholungstag ist nicht dasselbe. Null Arbeit an einem geplanten freien Tag ist genau richtig.")
                    }
                }
                Section("Besonderheit") {
                    TextField("z. B. Arbeit endet um 15:00", text: $note, axis: .vertical)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(day.longLabel)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        app.store.setDayInfo(day, type: type.trimmingCharacters(in: .whitespacesAndNewlines), note: note)
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard loaded == nil else { return }
                let info = app.store.planDay(day)
                let storedType: String = info?.dayType ?? ""
                let storedNote: String = info?.note ?? ""
                type = storedType
                note = storedNote
                isCustom = !storedType.isEmpty && !DayTypes.presets.contains(storedType)
                loaded = [storedType, storedNote]
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 440, height: 500)
    }

    /// A tap on the chosen type clears it again.
    private func choose(_ preset: String) {
        type = (!isCustom && type == preset) ? "" : preset
        isCustom = false
    }

    private func chooseCustom() {
        if DayTypes.presets.contains(type) { type = "" }
        isCustom = true
    }
}

struct WeekInfoEditor: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""
    /// Title and context as loaded (R14); nil until loaded.
    @State private var loaded: [String]? = nil

    private var isDirty: Bool {
        guard let loaded else { return false }
        return [title, details] != loaded
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Wochenmotto", text: $title)
                TextField("Kontext, Prioritäten, Ausnahmen, Annahmen", text: $details, axis: .vertical)
                    .lineLimit(4...14)
            }
            .formStyle(.grouped)
            .navigationTitle(week.longLabel)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        app.store.updatePlan(week, title: title, details: details)
                        dismiss()
                    }
                }
            }
            .onAppear {
                guard loaded == nil else { return }
                let plan = app.store.plan(week)
                let storedTitle: String = plan?.title ?? ""
                let storedDetails: String = plan?.details ?? ""
                title = storedTitle
                details = storedDetails
                loaded = [storedTitle, storedDetails]
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 480, height: 540)
    }
}

// MARK: The central "+"

struct ThaliaCreateSheet: View {
    @Environment(AppModel.self) private var app

    /// R31/R75: every shortcut of the capture commands – Mac and iPad only.
    static let shortcutNote = "⌘N Power-Hours · ⇧⌘N Erfassen · ⌥⌘N Notiz · ⇧⌘E Messwert eintragen · ⌘↩ Tag abschließen · ⇧⌘↩ Woche abschließen · ⇧⌘I Wochenplan importieren"

    private var footnote: String? {
        PlatformInfo.isPhone ? nil : ThaliaCreateSheet.shortcutNote
    }

    var body: some View {
        // R41: every option records on the day the app shows; the title names it when it isn't today.
        let day: DayKey = app.captureDay
        CreateSheet(
            title: captureTitle("Erfassen", day: day, today: app.today),
            options: options(day: day),
            footnote: footnote
        )
    }

    /// The four tiles (Power-Hours, Ausgabe, Messwert eintragen, Notiz), then the list – v11 P5.10: what is entered
    /// often first (Lesen, Tag abschließen, Jahresziel eintragen), creating and importing after, "Fokus ansehen"
    /// (only a view) last.
    private func options(day: DayKey) -> [CreateOption] {
        let app: AppModel = self.app
        return [
            CreateOption(id: "ph", title: "Power-Hours", subtitle: "Bereich, Menge, Wofür – Nachhilfe inklusive",
                         symbol: "bolt.fill") { app.sheet = .work(WorkDraft(day: day)) },
            CreateOption(id: "expense", title: "Ausgabe", subtitle: "Betrag und wofür – Tag und Woche im Blick",
                         symbol: "eurosign.circle.fill", tint: .green) { app.sheet = .expenses(day) },
            CreateOption(id: "measure", title: "Messwert eintragen", subtitle: "Gewicht, Aufschläge, Schlaf, TEREA …",
                         symbol: "ruler.fill", tint: .teal) { app.sheet = .measure(code: "", day: day) },
            CreateOption(id: "note", title: "Notiz", subtitle: NoteKind.listText,
                         symbol: "note.text", tint: .indigo) { app.sheet = .note(nil, day) },
            CreateOption(id: "reading", title: "Lesen", subtitle: "Bis Seite oder + Seiten – für das laufende Buch",
                         symbol: "book", tint: .brown, isFeatured: false) { app.sheet = .reading(day, itemID: nil) },
            CreateOption(id: "close", title: "Tag abschließen", subtitle: "Offenes ergänzen, Journal abhaken, Wertung sehen",
                         symbol: "moon.stars.fill", tint: .purple, isFeatured: false) { app.sheet = .closeDay(app.dayToClose(showing: day)) },
            // v10 (§1.2.6, §1.3): on the day shown – also back in time. v11 P7.9: results have the trophy, the flag
            // stays with closing the week.
            CreateOption(id: "goal-entry", title: "Jahresziel eintragen", subtitle: "Abhaken, +1 oder Wert – auch rückwirkend",
                         symbol: "trophy", tint: .orange, isFeatured: false) { app.sheet = .goalEntry(day, resultID: nil) },
            CreateOption(id: "item", title: "Punkt anlegen", subtitle: "Ein bewerteter Punkt für diese Woche",
                         symbol: "checklist", tint: .green, isFeatured: false) { app.sheet = .newItem(day.week, categoryKey: nil) },
            CreateOption(id: "new-measure", title: "Messwert anlegen", subtitle: "Neuer Wert mit Ziel – auch für die nächsten Wochen",
                         symbol: "plus.forwardslash.minus", tint: .mint, isFeatured: false) { app.sheet = .editMeasure(nil, day.week, categoryKey: nil) },
            CreateOption(id: "import", title: "Wochenplan importieren", subtitle: "Planungs-Prompt kopieren, CSV aus ChatGPT einfügen, Vorschau",
                         symbol: "square.and.arrow.down", tint: .pink, isFeatured: false) { app.sheet = .importPlan(prompt: true) },
            CreateOption(id: "focus", title: "Fokus ansehen", subtitle: "Power-Hours an diesem Tag und in der Woche, je Bereich",
                         symbol: "chart.bar.fill", tint: .orange, isFeatured: false) { app.sheet = .focus(day) },
        ]
    }
}

/// Free days (Familien-, Erholungstag …): automatic, work days only, or also on free days.
struct DayRulePicker: View {
    @Binding var rule: DayRule

    var body: some View {
        Picker("An freien Tagen", selection: $rule) {
            Text("automatisch").tag(DayRule.auto)
            Text("nur Arbeitstage").tag(DayRule.workOnly)
            Text("auch an freien Tagen").tag(DayRule.always)
        }
    }
}
