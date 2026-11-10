import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

// MARK: Work

/// Record or edit power-hours (U9): area, how many PH (quick chips or free), what for – with the
/// descriptions used before in that area as suggestions. Result and next step are optional.
struct WorkEditor: View {
    let draft: WorkDraft
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<TrackCategory> { $0.deletedAt == nil }) private var categories: [TrackCategory]

    @State private var categoryKey: String
    @State private var powerHours: Double
    @State private var task: String
    @State private var result: String
    @State private var nextStep: String
    @State private var showsMore: Bool
    @FocusState private var taskFocused: Bool

    init(draft: WorkDraft) {
        self.draft = draft
        _categoryKey = State(initialValue: draft.block?.categoryKey ?? draft.categoryKey)
        _powerHours = State(initialValue: draft.block?.hours ?? draft.powerHours)
        _task = State(initialValue: draft.block?.task ?? "")
        _result = State(initialValue: draft.block?.result ?? "")
        _nextStep = State(initialValue: draft.block?.nextStep ?? "")
        _showsMore = State(initialValue: !(draft.block?.result.isEmpty ?? true) || !(draft.block?.nextStep.isEmpty ?? true))
    }

    private var sortedCategories: [TrackCategory] {
        Array(categories.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }

    /// Business areas first (where PH are planned), the rest after.
    private var workCategories: [TrackCategory] {
        let business = sortedCategories.filter { $0.goalKey == "3" && $0.key != "3.1" }
        return business + sortedCategories.filter { !business.contains($0) }
    }

    private var suggestions: [String] {
        app.store.workSuggestions(categoryKey: categoryKey).filter { $0 != task }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bereich") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(workCategories.prefix(6)) { category in
                                ChipButton(title: "\(category.key) \(category.title)", isSelected: category.key == categoryKey) {
                                    categoryKey = category.key
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    if workCategories.count > 6 {
                        Picker("Anderer Bereich", selection: $categoryKey) {
                            ForEach(workCategories) { category in
                                Text("\(category.key) \(category.title)").tag(category.key)
                            }
                        }
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
                    TextField("Wofür? (z. B. Lena – Mathe)", text: $task)
                        .focused($taskFocused)
                        .submitLabel(.done)
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    ChipButton(title: suggestion, isSelected: false, symbol: "clock.arrow.circlepath") {
                                        task = suggestion
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } header: {
                    Text("Beschreibung")
                } footer: {
                    Text("Vorschläge kommen aus deinen bisherigen Einträgen in diesem Bereich.")
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
            .navigationTitle(draft.block == nil ? "Power-Hours" : "Power-Hours bearbeiten")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save).disabled(powerHours <= 0 || categoryKey.isEmpty)
                }
            }
            .onAppear {
                if categoryKey.isEmpty || !sortedCategories.contains(where: { $0.key == categoryKey }) {
                    categoryKey = workCategories.first?.key ?? ""
                }
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 520)
    }

    private func save() {
        if let block = draft.block {
            app.store.update(block, categoryKey: categoryKey, task: task, powerHours: powerHours, result: result,
                             nextStep: nextStep, day: draft.day)
        } else {
            app.store.addWork(day: draft.day, categoryKey: categoryKey, task: task, powerHours: powerHours,
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol { Image(systemName: symbol).font(.caption2) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(isSelected ? Brand.accent : Color.secondary.opacity(0.14), in: .capsule)
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
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 600)
    }
}

struct MeasurePicker: View {
    let context: WeekContext
    let day: DayKey
    @State private var chosen: String?

    var body: some View {
        List(context.measures) { measure in
            NavigationLink {
                MeasureForm(measure: measure, day: day, context: context)
            } label: {
                LabeledContent(measure.title, value: context.dayValue(measure, on: day).map { Format.measure($0, unit: measure.unit) } ?? "–")
            }
        }
        .overlay {
            if context.measures.isEmpty {
                ContentUnavailableView("Keine Messwerte", systemImage: "ruler", description: Text("Der Wochenplan legt die Messwerte fest."))
            }
        }
        .navigationTitle("Messwert erfassen")
        .inlineNavigationTitle()
    }
}

struct MeasureForm: View {
    let measure: MeasureDefinition
    let day: DayKey
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Query private var history: [MeasureEntry]
    @State private var valueText = ""
    @State private var time = Date()
    @State private var text = ""
    @State private var estimate = false
    @State private var note = ""

    init(measure: MeasureDefinition, day: DayKey, context: WeekContext) {
        self.measure = measure
        self.day = day
        self.context = context
        let code = measure.code
        let days = (0..<14).map { day.adding(days: -$0).string }
        _history = Query(filter: #Predicate<MeasureEntry> { $0.code == code && $0.deletedAt == nil && days.contains($0.dayKey) })
    }

    private var record: MeasureRecord? { measure.record }
    private var isTime: Bool { record?.isTime ?? false }
    private var isText: Bool { record?.isText ?? false }
    private var todays: [MeasureEntry] { context.entries.filter { $0.code == measure.code && $0.dayKey == day.string }.sorted { $0.recordedAt < $1.recordedAt } }

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
                    Text(context.dayValue(measure, on: day).map { Format.measure($0, unit: measure.unit) } ?? "–")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
                if let target = record?.target {
                    LabeledContent("Ziel", value: "\(target.label) \(record?.period.label ?? "")")
                    if record?.period == .week {
                        LabeledContent("Diese Woche", value: context.weekValue(measure).map { Format.measure($0, unit: measure.unit) } ?? "–")
                    }
                }
                if !measure.details.isEmpty {
                    Text(measure.details).font(.caption).foregroundStyle(.secondary)
                }
            }

            if case .work? = record?.source {
                Section {
                    Text("Dieser Wert kommt aus den Power-Hours (\(MeasureSource(raw: measure.sourceRaw).raw)). Erfasse sie mit + auf der Kachel oder unten.")
                        .font(.subheadline)
                }
            }

            Section {
                if isText {
                    TextField("Text", text: $text, axis: .vertical)
                } else if isTime {
                    DatePicker("Uhrzeit", selection: $time, displayedComponents: .hourAndMinute)
                } else {
                    HStack {
                        TextField("Wert", text: $valueText)
                            .decimalKeyboard()
                        Text(Units.display(measure.unit)).foregroundStyle(.secondary)
                    }
                    HStack {
                        ForEach([1.0, 2.0, 5.0].map { $0 * Units.step(measure.unit) }, id: \.self) { step in
                            Button("+\(Format.number(step))") { app.add(step, to: measure, day: day) }
                                .buttonStyle(.bordered)
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
                .disabled(!isText && !isTime && Format.parse(valueText) == nil)
            } header: {
                Text("Neuer Eintrag")
            } footer: {
                Text(record?.aggregation == .sum ? "Mehrere Einträge eines Tages werden addiert." : "Der letzte Eintrag des Tages zählt.")
            }

            if let suggestion = health.suggestion(code: measure.code, day: day) {
                Section {
                    LabeledContent("Apple Health", value: Format.measure(suggestion, unit: measure.unit))
                    Button {
                        app.store.adoptHealth(code: measure.code, day: day, value: suggestion)
                    } label: {
                        Label("Übernehmen (bleibt auf diesem Gerät)", systemImage: "heart.text.square")
                    }
                } footer: {
                    Text("Ein Vorschlag, kein automatischer Eintrag. Gesundheitsdaten werden nie in iCloud gespeichert; ein eigener Eintrag hat Vorrang.")
                }
            }
            if context.health.contains(where: { $0.code == measure.code && $0.dayKey == day.string }) {
                Section {
                    Button("Übernommenen Health-Wert entfernen", role: .destructive) {
                        app.store.removeHealth(code: measure.code, day: day)
                    }
                }
            }

            if !todays.isEmpty {
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
        .navigationTitle(measure.title)
        .inlineNavigationTitle()
        .onAppear {
            if isTime {
                var components = DateComponents()
                components.hour = 22
                components.minute = 45
                time = Calendar.current.date(from: components) ?? Date()
            }
        }
    }

    private func addEntry() {
        var value: Double?
        if isTime {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: time)
            value = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        } else if !isText {
            value = Format.parse(valueText)
            guard value != nil else { return }
        }
        app.store.addEntry(code: measure.code, day: day, value: value, text: isText ? text : "", estimate: estimate, note: note)
        valueText = ""
        text = ""
        note = ""
        estimate = false
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
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var kind: NoteKind
    @State private var text: String
    @FocusState private var focused: Bool

    init(note: DayNote?, day: DayKey) {
        self.note = note
        self.day = day
        _kind = State(initialValue: note?.kind ?? .observation)
        _text = State(initialValue: note?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Art", selection: $kind) {
                    ForEach(NoteKind.allCases, id: \.self) { kind in
                        Label(kind.label, systemImage: kind.symbol).tag(kind)
                    }
                }
                TextField(kind == .idea ? "Idee – geparkt, kein neues Projekt" : "Was ist passiert?", text: $text, axis: .vertical)
                    .lineLimit(3...10)
                    .focused($focused)
                if let note {
                    Button("Notiz löschen", systemImage: "trash", role: .destructive) {
                        app.trash([note])
                        dismiss()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(note == nil ? "Notiz" : "Notiz bearbeiten")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        if let note {
                            app.store.update(note, kind: kind, text: text)
                        } else {
                            app.store.addNote(day: day, kind: kind, text: text)
                        }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { if note == nil { focused = true } }
        }
        .sheetFrame(minWidth: 440, minHeight: 320)
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
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 600)
    }
}

struct ItemDetailForm: View {
    let item: PlanItem
    let day: DayKey
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var note = ""
    @State private var editing = false
    @State private var confirmsDelete = false

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
                    let measure = context.measure(code: item.measureCode)
                    LabeledContent("Messwert", value: (measure?.title ?? item.measureCode) + (item.targetRaw.isEmpty ? " (erfasst)" : " \(Target.parse(item.targetRaw)?.label ?? "")"))
                }
                if item.isKnockout {
                    Label("Persönliche Null-Regel: ✗ setzt die Kategorie an diesem Tag auf 0. Die Daten bleiben erhalten.", systemImage: "exclamationmark.octagon")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                HStack(spacing: 10) {
                    ForEach(context.options(item, on: day), id: \.self) { option in
                        Button {
                            app.setMark(mark == option ? nil : option, item: item, day: day)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: Optional(option).symbolName)
                                    .font(.title2)
                                    .foregroundStyle(Optional(option).color)
                                Text(option == .notApplicable ? "N/A" : option.symbol)
                                    .font(.caption.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(mark == option ? Optional(option).color.opacity(0.18) : Color.clear,
                                        in: .rect(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.label)
                    }
                }
                if let suggestion = context.suggestion(item, on: day) {
                    Button {
                        app.setMark(suggestion, item: item, day: day)
                    } label: {
                        Label("Vorschlag aus dem Messwert: \(suggestion.symbol) \(suggestion.label)", systemImage: "wand.and.stars")
                    }
                }
                TextField("Notiz zu \(day.weekday.name)", text: $note, axis: .vertical)
                    .onSubmit { app.store.setMarkNote(note, item: item, day: day, current: mark) }
            } header: {
                Text(day.longLabel)
            } footer: {
                Text(item.schedule == .progress
                     ? "✓ heute daran gearbeitet · N/A heute nicht. Am Wochenende zählt, wie weit das Wochenziel erreicht ist."
                     : "✓ erledigt · ½ teilweise · ✗ fällig, nicht erledigt · N/A nicht fällig · leer = noch nicht erfasst")
            }

            Section("Woche") {
                HStack(spacing: 4) {
                    ForEach(context.week.days, id: \.self) { d in
                        VStack(spacing: 3) {
                            Text(d.weekday.short).font(.caption2).foregroundStyle(.secondary)
                            MarkCell(mark: context.mark(item, on: d), applies: item.days.contains(d.weekday), isToday: d == context.today,
                                     onSet: { app.setMark($0, item: item, day: d) })
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
            Button("Löschen – auch künftig weglassen", role: .destructive) { app.trash([item], carryOver: true) }
            Button("Nur diese Woche löschen", role: .destructive) { app.trash([item], carryOver: false) }
        } message: {
            Text("Der nächste Planungs-Prompt sagt der KI, ob der Punkt dauerhaft wegfällt.")
        }
        .formStyle(.grouped)
        .navigationTitle("Punkt")
        .inlineNavigationTitle()
        .onAppear { note = context.markNote(item, on: day) }
        .onDisappear {
            if note != context.markNote(item, on: day) {
                app.store.setMarkNote(note, item: item, day: day, current: context.mark(item, on: day))
            }
        }
        .sheet(isPresented: $editing) {
            ItemEditor(week: context.week, item: item)
                .environment(app)
        }
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
                        Picker("Messwert", selection: $measureCode) {
                            Text("keiner").tag("")
                            ForEach(weekMeasures) { measure in
                                Text(measure.title).tag(measure.code)
                            }
                        }
                    }
                    Toggle("Persönliche Null-Regel (✗ → Kategorie 0)", isOn: $knockout)
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
                if categoryKey.isEmpty { categoryKey = sortedCategories.first?.key ?? "" }
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 520)
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
    @State private var targetText: String
    @State private var period: TargetPeriod
    @State private var days: Set<Weekday>
    @State private var carryOver = true
    @State private var confirmsDelete = false
    @State private var secondary: Bool
    @State private var dayRule: DayRule

    static let units = ["", "kg", "g", "l", "min", "h", "PH", "Uhrzeit", "€", "Stück", "Seiten", "Schritte", "Text"]

    init(week: WeekKey, measure: MeasureDefinition?, presetCategory: String? = nil) {
        self.week = week
        self.measure = measure
        self.presetCategory = presetCategory
        _categoryKey = State(initialValue: measure?.categoryKey ?? presetCategory ?? "")
        _title = State(initialValue: measure?.title ?? "")
        _details = State(initialValue: measure?.details ?? "")
        _unit = State(initialValue: measure?.unit ?? "")
        _targetText = State(initialValue: measure?.targetRaw ?? "")
        _period = State(initialValue: TargetPeriod(raw: measure?.periodRaw ?? "tag"))
        _days = State(initialValue: Set(measure?.days.days ?? Weekday.allCases))
        _secondary = State(initialValue: measure?.record?.secondary ?? false)
        _dayRule = State(initialValue: measure?.record?.dayRule ?? .auto)
    }

    private var sortedCategories: [TrackCategory] {
        Array(categories.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }

    private var target: Target? {
        let trimmed = targetText.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Target.parse(trimmed)
    }

    private var isWork: Bool {
        if let measure, case .work = MeasureSource(raw: measure.sourceRaw) { return true }
        return false
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
                Section {
                    if isWork {
                        LabeledContent("Einheit", value: "PH aus den Einträgen")
                    } else {
                        Picker("Einheit", selection: $unit) {
                            ForEach(Self.units, id: \.self) { unit in
                                Text(unit.isEmpty ? "Zahl" : unit).tag(unit)
                            }
                        }
                    }
                    TextField("Ziel (z. B. >=8, <=23:00, 150-180)", text: $targetText)
                    if !targetText.trimmingCharacters(in: .whitespaces).isEmpty && target == nil {
                        Label("Das Ziel verstehe ich nicht – z. B. >=8, <=6, 22:30-23:00.", systemImage: "exclamationmark.triangle")
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
                Section {
                    Toggle("Auch in den nächsten Wochen", isOn: $carryOver)
                } footer: {
                    Text(carryOver ? "Der nächste Planungs-Prompt übernimmt die Änderung dauerhaft."
                         : "Gilt nur für diese Woche – der Prompt sagt der KI, dass sie nicht übernommen wird.")
                }
                if measure != nil {
                    Section {
                        Button("Messwert löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(measure == nil ? "Neuer Messwert" : "Messwert bearbeiten")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || days.isEmpty
                                  || (!targetText.trimmingCharacters(in: .whitespaces).isEmpty && target == nil))
                }
            }
            .confirmationDialog("„\(title)“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Löschen – auch künftig weglassen", role: .destructive) { delete(carryOver: true) }
                Button("Nur diese Woche löschen", role: .destructive) { delete(carryOver: false) }
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 560)
    }

    private func save() {
        let mask = DayMask(Array(days))
        if let measure, var record = measure.record {
            record.categoryKey = categoryKey
            record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            record.details = details
            if !isWork {
                record.unit = unit
                record.aggregation = .default(forUnit: unit)
            }
            record.target = target
            record.period = period
            record.days = mask
            record.secondary = secondary
            record.dayRule = dayRule
            app.store.update(measure, with: record, carryOver: carryOver)
        } else {
            let added = app.store.addMeasure(week: week, categoryKey: categoryKey, title: title, details: details, unit: unit,
                                             target: target, period: period, days: mask, carryOver: carryOver)
            if (secondary || dayRule != .auto), var record = added.record {
                record.secondary = secondary
                record.dayRule = dayRule
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tagestyp", selection: $type) {
                        Text("Kein Tagestyp").tag("")
                        ForEach(DayTypes.presets, id: \.self) { preset in
                            Label(preset, systemImage: DayTypes.symbol(for: preset)).tag(preset)
                        }
                        if !type.isEmpty && !DayTypes.presets.contains(type) {
                            Text(type).tag(type)
                        }
                    }
                    TextField("Eigener Tagestyp", text: $type)
                } footer: {
                    Text("Ein Arbeits-, Reise-, Familien- oder Erholungstag ist nicht dasselbe. Null Arbeit an einem geplanten freien Tag ist genau richtig.")
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
                        app.store.setDayInfo(day, type: type, note: note)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let info = app.store.planDay(day)
                type = info?.dayType ?? ""
                note = info?.note ?? ""
            }
        }
        .sheetFrame(minWidth: 440, minHeight: 380)
    }
}

struct WeekInfoEditor: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""

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
                let plan = app.store.plan(week)
                title = plan?.title ?? ""
                details = plan?.details ?? ""
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 420)
    }
}

// MARK: The central "+"

struct ThaliaCreateSheet: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let day = app.selectedDay
        CreateSheet(
            title: "Erfassen",
            options: [
                CreateOption(id: "ph", title: "Power-Hours", subtitle: "Bereich, Anzahl, wofür – Nachhilfe inklusive",
                             symbol: "bolt.fill") { app.sheet = .work(WorkDraft(day: day)) },
                CreateOption(id: "expense", title: "Ausgabe", subtitle: "Betrag und wofür – Tag und Woche im Blick",
                             symbol: "eurosign.circle.fill", tint: .green) { app.sheet = .expenses(day) },
                CreateOption(id: "focus", title: "Fokus ansehen", subtitle: "Power-Hours heute und diese Woche, je Bereich",
                             symbol: "chart.bar.fill", tint: .orange, isFeatured: false) { app.sheet = .focus(day.week) },
                CreateOption(id: "measure", title: "Messwert eintragen", subtitle: "Gewicht, Aufschläge, Schlaf, TEREA …",
                             symbol: "ruler.fill", tint: .teal) { app.sheet = .measure(code: "", day: day) },
                CreateOption(id: "note", title: "Notiz", subtitle: "Beobachtung, Auslöser, Erfolg, Idee",
                             symbol: "note.text", tint: .indigo) { app.sheet = .note(nil, day) },
                CreateOption(id: "close", title: "Tag abschließen", subtitle: "Offenes ergänzen, Journal abhaken, Wertung sehen",
                             symbol: "moon.stars.fill", tint: .purple, isFeatured: false) { app.sheet = .closeDay(day) },
                CreateOption(id: "item", title: "Punkt hinzufügen", subtitle: "Ein bewerteter Punkt für diese Woche",
                             symbol: "checklist", tint: .green, isFeatured: false) { app.sheet = .newItem(day.week, categoryKey: nil) },
                CreateOption(id: "new-measure", title: "Messwert anlegen", subtitle: "Neuer Wert mit Ziel – auch für die nächsten Wochen",
                             symbol: "plus.forwardslash.minus", tint: .mint, isFeatured: false) { app.sheet = .editMeasure(nil, day.week, categoryKey: nil) },
                CreateOption(id: "import", title: "Wochenplan importieren", subtitle: "Planungs-Prompt kopieren, CSV aus ChatGPT einfügen, Vorschau",
                             symbol: "square.and.arrow.down", tint: .pink, isFeatured: false) { app.sheet = .importPlan(prompt: true) },
            ],
            footnote: "Am Mac und iPad: ⌘N erfasst Power-Hours, ⇧⌘I importiert den Wochenplan."
        )
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
