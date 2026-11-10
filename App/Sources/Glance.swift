import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

// v5: look in once and see what's going on – power-hours and work (F1), spending (F1), what's
// still to do (F4), and on the Mac a grey summary under the navigation (F4.1).

// MARK: Fokus – power-hours and work

/// Power-hours today and this week: totals against the target, Mo–So by area, every area against
/// its weekly goal, and all entries with their descriptions.
struct FocusSheet: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WeekReader(week: week, today: app.today) { context in
                FocusContent(context: context)
            }
            .navigationTitle("Fokus · \(week.label)")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        app.sheet = .work(WorkDraft(day: app.today))
                    } label: {
                        Label("Power-Hours erfassen", systemImage: "plus")
                    }
                }
            }
        }
        .sheetFrame(minWidth: 560, minHeight: 680)
    }
}

struct FocusContent: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app

    private struct DayBar: Identifiable {
        let day: DayKey
        let category: String
        let hours: Double
        var id: String { day.string + category }
    }

    var body: some View {
        let today: DayKey = context.week.contains(app.today) ? app.today : context.week.monday
        let week = context.workTotals()
        let todayTotals = context.workTotals(on: today)
        let target: Double? = context.workTarget
        let bars: [DayBar] = dayBars
        let areaKeys: [String] = Array(Set(bars.map(\.category))).sorted()
        let areas: [MeasureDefinition] = context.measures.filter { $0.record?.isWork == true }
        List {
            Section {
                HeroCard(title: "Power-Hours", subtitle: week.isEmpty ? "Noch nichts erfasst" : week.explanation,
                         value: Format.number(week.powerHours), caption: target.map { "von \(Format.number($0))" } ?? "PH",
                         progress: target.map { $0 > 0 ? week.powerHours / $0 : 0 } ?? 0,
                         facts: [("Heute", todayTotals.isEmpty ? "–" : todayTotals.shortText),
                                 ("Ø pro Arbeitstag", average(week.powerHours)),
                                 ("Einträge", "\(context.workRecords.count)")])
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if !bars.isEmpty {
                Section("Mo–So") {
                    Chart(bars) { bar in
                        BarMark(x: .value("Tag", bar.day.weekday.short), y: .value("PH", bar.hours))
                            .foregroundStyle(by: .value("Bereich", bar.category))
                            .cornerRadius(4)
                    }
                    .chartForegroundStyleScale(domain: areaKeys, range: areaKeys.map { GoalPalette.color(category: $0) })
                    .chartXScale(domain: context.week.days.map(\.weekday.short))
                    .frame(height: 170)
                }
            }
            if !areas.isEmpty {
                Section("Bereiche · Woche gegen Ziel") {
                    ForEach(areas) { measure in
                        AreaRow(context: context, measure: measure, today: today)
                    }
                }
            }
            let entries: [WorkBlock] = context.work.sorted { ($0.dayKey, $0.createdAt) > ($1.dayKey, $1.createdAt) }
            Section {
                if entries.isEmpty {
                    Text("Noch keine Power-Hours diese Woche.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { block in
                    Button {
                        app.sheet = .work(WorkDraft(block: block, day: DayKey(block.dayKey) ?? today, categoryKey: block.categoryKey))
                    } label: {
                        HStack(spacing: 12) {
                            Text(Format.number(block.hours))
                                .font(.system(.headline, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)
                                .frame(width: 46, height: 32)
                                .background(GoalPalette.color(category: block.categoryKey).gradient, in: .rect(cornerRadius: 9, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(block.task.isEmpty ? (context.category(block.categoryKey)?.title ?? block.categoryKey) : block.task)
                                    .foregroundStyle(.primary)
                                Text("\(DayKey(block.dayKey)?.shortLabel ?? block.dayKey) · \(block.categoryKey) \(context.category(block.categoryKey)?.title ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if !block.result.isEmpty {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.secondary)
                                    .help(block.result)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([block]) }
                    }
                }
            } header: {
                Text("Einträge")
            } footer: {
                Text("1 PH = 50 Minuten konzentrierte Arbeit, Nachhilfe inklusive. Tippen bearbeitet einen Eintrag.")
            }
        }
        .compactListSections()
    }

    private var dayBars: [DayBar] {
        var sums: [String: DayBar] = [:]
        for record in context.workRecords {
            let key: String = record.day.string + record.categoryKey
            let previous: Double = sums[key]?.hours ?? 0
            sums[key] = DayBar(day: record.day, category: record.categoryKey, hours: previous + record.powerHours)
        }
        return sums.values.sorted { $0.id < $1.id }
    }

    private func average(_ total: Double) -> String {
        let workdays: Int = context.week.days.filter { $0 <= app.today && !context.isFreeDay($0) && $0.weekday.rawValue <= Weekday.friday.rawValue }.count
        guard workdays > 0, total > 0 else { return "–" }
        return Format.powerHours(total / Double(workdays))
    }
}

private struct AreaRow: View {
    let context: WeekContext
    let measure: MeasureDefinition
    let today: DayKey

    var body: some View {
        let value: Double = context.weekValue(measure) ?? 0
        let target: Double = measure.record?.target?.scaleMax ?? 0
        let todayValue: Double = context.dayValue(measure, on: today) ?? 0
        let reached: Bool = target > 0 && value >= target - 1e-9
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(measure.title)
                    .font(.body.weight(.semibold))
                Spacer()
                Text(target > 0 ? "\(Format.number(value)) von \(Format.number(target)) PH" : "\(Format.number(value)) PH")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(reached ? .green : .primary)
            }
            if target > 0 {
                GoalBar(fraction: min(1, value / target), reached: reached, tint: GoalPalette.color(category: measure.categoryKey))
            }
            Text(todayValue > 0 ? "heute \(Format.powerHours(todayValue))" : "heute noch nichts")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: Ausgaben – spending

/// Type the amount right away, optionally what for, add. Today and the week at a glance.
struct ExpensesSheet: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WeekReader(week: day.week, today: app.today) { context in
                ExpensesContent(context: context, day: day)
            }
            .navigationTitle("Ausgaben")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .sheetFrame(minWidth: 520, minHeight: 640)
    }
}

struct ExpensesContent: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app
    @State private var amount = ""
    @State private var what = ""
    @FocusState private var amountFocused: Bool

    private struct DayAmount: Identifiable {
        let day: DayKey
        let value: Double
        var id: String { day.string }
    }

    var body: some View {
        if let measure = context.expenseMeasure {
            content(measure)
        } else {
            ContentUnavailableView {
                Label("Kein Ausgaben-Messwert", systemImage: "eurosign.circle")
            } description: {
                Text("Diese Woche hat keinen Messwert in €. Leg ihn an – er gilt dann auch für die nächsten Wochen.")
            } actions: {
                Button("„Ausgaben“ anlegen") {
                    let category: String = context.categories.first { $0.goalKey == "8" }?.key ?? ""
                    app.store.addMeasure(week: day.week, categoryKey: category, title: "Ausgaben", unit: "€", target: nil, period: .day)
                }
                .primaryActionStyle()
            }
        }
    }

    private func content(_ measure: MeasureDefinition) -> some View {
        let todayValue: Double = context.dayValue(measure, on: day) ?? 0
        let weekValue: Double = context.weekValue(measure) ?? 0
        let entries: [MeasureEntry] = context.entries.filter { $0.code == measure.code && $0.dayKey == day.string }
            .sorted { $0.recordedAt > $1.recordedAt }
        let perDay: [DayAmount] = context.week.days.map { DayAmount(day: $0, value: context.dayValue(measure, on: $0) ?? 0) }
        let suggestions: [String] = Array(Set(context.entries.filter { $0.code == measure.code && !$0.note.isEmpty }.map(\.note))).sorted().prefix(6).map { $0 }
        return List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        TextField("Betrag", text: $amount)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .decimalKeyboard()
                            .focused($amountFocused)
                            .submitLabel(.done)
                            .onSubmit { add(measure) }
                        Text("€")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    TextField("Wofür? (optional)", text: $what)
                        .submitLabel(.done)
                        .onSubmit { add(measure) }
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    ChipButton(title: suggestion, isSelected: what == suggestion) { what = suggestion }
                                }
                            }
                        }
                    }
                    Button {
                        add(measure)
                    } label: {
                        Label("Hinzufügen", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                    .disabled(Format.parse(amount) == nil)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Neue Ausgabe · \(day.shortLabel)")
            }
            Section {
                HStack(spacing: 12) {
                    SummaryTile(label: day == app.today ? "Heute" : day.shortLabel, value: Format.measure(todayValue, unit: "€"),
                                tint: GoalPalette.color(goal: "8"))
                    SummaryTile(label: context.week.label, value: Format.measure(weekValue, unit: "€"), tint: Brand.accent)
                    if let target = measure.record?.target {
                        SummaryTile(label: "Ziel", value: "\(target.label) €", tint: .orange)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                Chart(perDay) { entry in
                    BarMark(x: .value("Tag", entry.day.weekday.short), y: .value("€", entry.value))
                        .foregroundStyle(entry.day == day ? GoalPalette.color(goal: "8") : GoalPalette.color(goal: "8").opacity(0.35))
                        .cornerRadius(4)
                }
                .frame(height: 140)
            }
            Section {
                if entries.isEmpty {
                    Text("Noch nichts an diesem Tag.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.note.isEmpty ? "Ausgabe" : entry.note)
                            Text(entry.recordedAt, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Format.measure(entry.value ?? 0, unit: "€"))
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([entry]) }
                    }
                    .contextMenu {
                        Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([entry]) }
                    }
                }
            } header: {
                Text("Einträge \(day.shortLabel)")
            }
        }
        .compactListSections()
        .onAppear { amountFocused = true }
    }

    private func add(_ measure: MeasureDefinition) {
        guard let value = Format.parse(amount) else { return }
        let rounded: Double = (value * 100).rounded() / 100
        app.store.addEntry(code: measure.code, day: day, value: rounded, note: what.trimmingCharacters(in: .whitespacesAndNewlines))
        app.toasts.show("\(Format.measure(rounded, unit: "€"))\(what.isEmpty ? "" : " · \(what)")", symbol: "eurosign.circle.fill")
        amount = ""
        what = ""
        amountFocused = true
    }
}

struct SummaryTile: View {
    let label: String
    let value: String
    var tint: Color = Brand.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
    }
}

// MARK: Heute im Blick – tiles and what's left

/// Short texts shared by the tiles and the Mac sidebar (kept out of view expressions).
enum GlanceText {
    static func weekPowerHours(_ value: Double, target: Double?) -> String {
        guard let target else { return "Woche \(Format.powerHours(value))" }
        return "Woche \(Format.number(value)) / \(Format.number(target)) PH"
    }

    static func euro(_ value: Double?) -> String? {
        value.map { Format.measure($0, unit: "€") }
    }

    static func dayLine(_ overall: DayOverall?, closed: Bool, open: Int) -> String {
        if closed { return "Abgeschlossen · \(Format.score(overall?.score, outOf: true))" }
        return "\(overall?.coverageText ?? "0 %") erfasst · \(open) offen"
    }

    static func focusLine(today: WorkTotals, week: WorkTotals, target: Double?) -> String {
        let todayText: String = today.isEmpty ? "0 PH" : today.shortText
        let weekText: String = target.map { "\(Format.number(week.powerHours)) von \(Format.number($0)) PH" } ?? Format.powerHours(week.powerHours)
        return "Fokus \(todayText) heute · \(weekText) Woche"
    }

    static func expensesLine(today: Double?, week: Double?) -> String {
        "Ausgaben \(Format.measure(today ?? 0, unit: "€")) heute · \(Format.measure(week ?? 0, unit: "€")) Woche"
    }
}

/// Three tiles at the top of the day overview: focus, spending, weekly goals – each opens its view.
struct GlanceTiles: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    var body: some View {
        let totals = context.workTotals(on: day)
        let week = context.workTotals()
        let expenses: MeasureDefinition? = context.expenseMeasure
        let goals: [TodaySummary.GoalLine] = context.weeklyLines
        let reached: Int = goals.filter { $0.value >= $0.target - 1e-9 }.count
        HStack(spacing: 10) {
            GlanceTile(symbol: "bolt.fill", title: "Fokus", value: totals.isEmpty ? "0 PH" : totals.shortText,
                       detail: GlanceText.weekPowerHours(week.powerHours, target: context.workTarget),
                       tint: GoalPalette.color(goal: "3")) {
                app.sheet = .focus(day.week)
            }
            GlanceTile(symbol: "eurosign.circle.fill", title: "Ausgaben",
                       value: GlanceText.euro(expenses.flatMap { context.dayValue($0, on: day) }) ?? "0 €",
                       detail: GlanceText.euro(expenses.flatMap { context.weekValue($0) }).map { "Woche \($0)" } ?? "erfassen",
                       tint: GoalPalette.color(goal: "8")) {
                app.sheet = .expenses(day)
            }
            GlanceTile(symbol: "chart.bar.fill", title: "Wochenziele", value: goals.isEmpty ? "–" : "\(reached)/\(goals.count)",
                       detail: goals.isEmpty ? "keine" : "erreicht", tint: GoalPalette.color(goal: "2")) {
                app.sheet = .focus(day.week)
            }
        }
    }
}

private struct GlanceTile: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet \(title)")
    }
}

/// "Noch zu tun": the open required items by category – tap jumps there.
struct OpenToDoSection: View {
    let context: WeekContext
    let day: DayKey
    let onOpen: (TodayPage) -> Void

    var body: some View {
        let open: [PlanItem] = context.openToDo(on: day)
        let byCategory: [String: [PlanItem]] = Dictionary(grouping: open, by: \.categoryKey)
        let keys: [String] = context.categories.map(\.key).filter { byCategory[$0] != nil }
        Section {
            if open.isEmpty {
                Label("Alles Wichtige ist erfasst.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            }
            ForEach(keys, id: \.self) { key in
                Button {
                    onOpen(.category(key))
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        KeyBadge(key: key)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(byCategory[key] ?? []) { item in
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(open.isEmpty ? "Noch zu tun" : "Noch zu tun · \(open.count)")
        }
    }
}

// MARK: Mac sidebar (F4.1)

/// Grey, always visible under the navigation: today and the week in a few lines. Click opens the
/// matching view.
struct SidebarGlance: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            SidebarGlanceText(context: context, day: app.today)
        }
    }
}

private struct SidebarGlanceText: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    var body: some View {
        let overall: DayOverall? = context.score.days[day]
        let closed: Bool = context.isClosed(day)
        let todayWork = context.workTotals(on: day)
        let weekWork = context.workTotals()
        let expenses: MeasureDefinition? = context.expenseMeasure
        let open: Int = context.openToDo(on: day).count
        VStack(alignment: .leading, spacing: 8) {
            Button {
                app.sheet = .dayOverview(day)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HEUTE · \(day.shortLabel.uppercased())")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.6)
                    Text(GlanceText.dayLine(overall, closed: closed, open: open))
                }
            }
            .buttonStyle(.plain)
            Button {
                app.sheet = .focus(day.week)
            } label: {
                Text(GlanceText.focusLine(today: todayWork, week: weekWork, target: context.workTarget))
            }
            .buttonStyle(.plain)
            if let expenses {
                Button {
                    app.sheet = .expenses(day)
                } label: {
                    Text(GlanceText.expensesLine(today: context.dayValue(expenses, on: day), week: context.weekValue(expenses)))
                }
                .buttonStyle(.plain)
            }
            Button {
                app.sidebar = .week
                app.selectedWeek = day.week
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WOCHE · \(context.week.label)")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.6)
                    Text("Wertung \(Format.score(context.score.overall, outOf: true)) · \(context.score.goalsScored)/\(context.score.goalsTotal) Ziele")
                    ForEach(context.weeklyLines.prefix(3), id: \.title) { line in
                        Text("\(line.title) \(Format.number(line.value))/\(Format.number(line.target)) \(line.unit)")
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
