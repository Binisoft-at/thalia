import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

// MARK: Fokus – power-hours and work

/// Fokus as its own sheet (`.focus(day)`), for the day it was opened from (R22).
struct FocusSheet: View {
    let day: DayKey
    @Environment(\.dismiss) private var dismiss

    init(day: DayKey) {
        self.day = day
    }

    var body: some View {
        NavigationStack {
            FocusPage(day: day)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 560, height: 680)
    }
}

/// Fokus for a day – its own sheet or pushed inside "Heute im Blick" (R51). Pages through the
/// weeks ("‹ KW46 ›", R88); "+", a tap on an area or on an entry open the power-hour editor as a
/// sheet on top, so Fokus stays where it is.
struct FocusPage: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @State private var week: WeekKey
    @State private var draft: WorkDraft?

    init(day: DayKey) {
        self.day = day
        _week = State(initialValue: day.week)
    }

    /// No paging past the current week (or the day's week, if that lies ahead).
    private var latestWeek: WeekKey { max(app.today.week, day.week) }

    var body: some View {
        WeekReader(week: week, today: app.today) { context in
            FocusContent(context: context, day: day, onEdit: { draft = $0 }, onShowWeek: { week = $0 })
        }
        .navigationTitle("Fokus · \(week.label)")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .principal) {
                weekSwitcher
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    draft = WorkDraft(day: day)
                } label: {
                    Label("Power-Hours erfassen", systemImage: "plus")
                }
            }
        }
        .sheet(item: $draft) { editing in
            WorkEditor(draft: editing)
                .environment(app)
                .modelContainer(app.container)
                .toastHost(app)
        }
    }

    /// "‹ KW46 ›" (R88).
    private var weekSwitcher: some View {
        HStack(spacing: 6) {
            Button {
                week = week.adding(weeks: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Vorige Woche")
            Text(week.label)
                .font(.headline)
                .monospacedDigit()
            Button {
                week = week.adding(weeks: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(week >= latestWeek)
            .accessibilityLabel("Nächste Woche")
        }
    }
}

/// The week in power-hours: totals against the target, Mo–So by area, every area against its
/// weekly goal with its pace, the last 8 weeks and all entries by day.
struct FocusContent: View {
    let context: WeekContext
    /// The day Fokus was opened for (R22): its fact and "+" refer to it.
    let day: DayKey
    let onEdit: (WorkDraft) -> Void
    let onShowWeek: (WeekKey) -> Void
    @Environment(AppModel.self) private var app
    @State private var history: [WeekWorkPoint] = []

    init(context: WeekContext, day: DayKey, onEdit: @escaping (WorkDraft) -> Void, onShowWeek: @escaping (WeekKey) -> Void) {
        self.context = context
        self.day = day
        self.onEdit = onEdit
        self.onShowWeek = onShowWeek
    }

    static let siriTip = "Tipp: „Hey Siri, Power-Hour in Thalia erfassen“ – Siri fragt nach Bereich, Menge und Wofür."

    private struct DayBar: Identifiable {
        let day: DayKey
        let category: String
        let hours: Double
        var id: String { day.string + category }
    }

    /// The entries of one day (R53).
    private struct DayGroup: Identifiable {
        let day: DayKey
        let blocks: [WorkBlock]
        let total: Double
        var id: String { day.string }
    }

    var body: some View {
        let totals: WorkTotals = context.workTotals()
        let bars: [DayBar] = dayBars
        let areas: [MeasureDefinition] = workAreas
        // One colour per area, the same in the chart, the rows and the entries (R52).
        let areaKeys: [String] = keys(bars: bars, areas: areas)
        let groups: [DayGroup] = dayGroups
        List {
            Section {
                HeroCard(title: "Power-Hours", subtitle: heroSubtitle(totals), value: Format.number(totals.powerHours),
                         caption: heroCaption, progress: heroProgress(totals), facts: facts(totals, areas: areas))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if !bars.isEmpty {
                Section("Mo–So") {
                    dayChart(bars, keys: areaKeys)
                }
            }
            if !areas.isEmpty {
                Section("Bereiche · Woche gegen Ziel") {
                    ForEach(areas) { measure in
                        areaRow(measure, keys: areaKeys)
                    }
                }
            }
            if !history.isEmpty {
                Section {
                    WorkHistoryChart(points: history, shown: context.week, onSelect: onShowWeek)
                } header: {
                    Text("Letzte 8 Wochen")
                } footer: {
                    if let sentence = historySentence {
                        Text(sentence)
                    }
                }
            }
            if groups.isEmpty {
                Section {
                    Text("Noch keine Power-Hours diese Woche.")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Einträge")
                } footer: {
                    Text(FocusContent.siriTip)
                }
            } else {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.blocks) { block in
                            entryRow(block, keys: areaKeys)
                        }
                    } header: {
                        Text("\(group.day.shortLabel) · \(Format.powerHours(group.total))")
                    } footer: {
                        if group.id == groups.last?.id {
                            Text(FocusContent.siriTip)
                        }
                    }
                }
            }
        }
        .compactListSections()
        .task(id: historyKey) {
            history = app.store.workHistory(through: context.week)
        }
    }

    /// Areas side by side need different colours (several share goal 3's colour elsewhere).
    static let areaPalette: [Color] = [
        Color(red: 0.05, green: 0.55, blue: 0.60), Color(red: 0.95, green: 0.50, blue: 0.18), Color(red: 0.55, green: 0.38, blue: 0.86),
        Color(red: 0.90, green: 0.36, blue: 0.58), Color(red: 0.20, green: 0.62, blue: 0.36), Color(red: 0.30, green: 0.36, blue: 0.80),
    ]

    static func areaColor(_ key: String, among keys: [String]) -> Color {
        let index: Int = keys.firstIndex(of: key) ?? 0
        return areaPalette[index % areaPalette.count]
    }

    /// A category title cut to its first part ("Thema A – lang" → "Thema A"), at most 18 characters.
    static func shortTitle(_ title: String) -> String {
        var text: String = title
        for separator in [" – ", " - ", " (", ", ", ": "] {
            if let range = text.range(of: separator) {
                text = String(text[..<range.lowerBound])
            }
        }
        text = text.trimmingCharacters(in: .whitespaces)
        if text.count > 18 {
            text = String(text.prefix(17)) + "…"
        }
        return text
    }

    // MARK: Parts

    private func dayChart(_ bars: [DayBar], keys: [String]) -> some View {
        let names: [String] = keys.map { areaName($0) }
        let colors: [Color] = keys.map { FocusContent.areaColor($0, among: keys) }
        return Chart(bars) { bar in
            BarMark(x: .value("Tag", bar.day.weekday.short), y: .value("PH", bar.hours))
                .foregroundStyle(by: .value("Bereich", areaName(bar.category)))
                .cornerRadius(4)
        }
        .chartForegroundStyleScale(domain: names, range: colors)
        .chartXScale(domain: context.week.days.map(\.weekday.short))
        .frame(height: 170)
    }

    private func areaRow(_ measure: MeasureDefinition, keys: [String]) -> some View {
        let key: String = workCategory(measure)
        let draft = WorkDraft(day: day, categoryKey: key)
        return AreaRow(context: context, measure: measure, day: day, today: app.today,
                       tint: FocusContent.areaColor(key, among: keys), topics: topics(for: key)) {
            onEdit(draft)
        }
    }

    private func entryRow(_ block: WorkBlock, keys: [String]) -> some View {
        let draft = WorkDraft(block: block, day: DayKey(block.dayKey) ?? day, categoryKey: block.categoryKey)
        return Button {
            onEdit(draft)
        } label: {
            FocusEntryLabel(block: block, area: areaName(block.categoryKey),
                            tint: FocusContent.areaColor(block.categoryKey, among: keys))
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([block]) }
        }
        .contextMenu {
            Button("Bearbeiten", systemImage: "pencil") { onEdit(draft) }
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([block]) }
        }
    }

    // MARK: Values

    private var workAreas: [MeasureDefinition] {
        context.measures.filter { $0.record?.isWork == true }
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

    /// Newest day first, newest entry first (R53).
    private var dayGroups: [DayGroup] {
        let byDay: [String: [WorkBlock]] = Dictionary(grouping: context.work, by: \.dayKey)
        let groups: [DayGroup] = byDay.compactMap { element -> DayGroup? in
            guard let key = DayKey(element.key) else { return nil }
            let blocks: [WorkBlock] = element.value.sorted { $0.createdAt > $1.createdAt }
            let total: Double = blocks.reduce(0) { $0 + $1.hours }
            return DayGroup(day: key, blocks: blocks, total: total)
        }
        return groups.sorted { $0.day > $1.day }
    }

    private func keys(bars: [DayBar], areas: [MeasureDefinition]) -> [String] {
        let all: [String] = bars.map(\.category) + areas.map { workCategory($0) } + context.work.map(\.categoryKey)
        return Array(Set(all)).sorted()
    }

    private func workCategory(_ measure: MeasureDefinition) -> String {
        if case .work(let category)? = measure.record?.source { return category }
        return measure.categoryKey
    }

    /// "3.2 <Kurztitel>" (R52).
    private func areaName(_ key: String) -> String {
        let title: String = context.category(key)?.title ?? ""
        let short: String = FocusContent.shortTitle(title)
        return short.isEmpty ? key : "\(key) \(short)"
    }

    /// The three biggest topics of an area this week: "Thema A 4 · Thema B 2" (R53).
    private func topics(for key: String) -> String {
        var sums: [String: (title: String, hours: Double)] = [:]
        for record in context.workRecords where record.categoryKey == key {
            let task: String = record.task.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !task.isEmpty else { continue }
            let id: String = task.lowercased()
            let current = sums[id] ?? (title: task, hours: 0)
            sums[id] = (title: current.title, hours: current.hours + record.powerHours)
        }
        let top = sums.values.sorted { ($0.hours, $1.title) > ($1.hours, $0.title) }.prefix(3)
        return top.map { "\($0.title) \(Format.number($0.hours))" }.joined(separator: " · ")
    }

    /// "28 PH × 50 min = 23 h 20 min netto" – the net time is `WorkTotals.netText` (R52).
    private func heroSubtitle(_ totals: WorkTotals) -> String {
        totals.isEmpty ? "Noch nichts erfasst" : totals.explanation
    }

    private var heroCaption: String {
        guard let target = context.workTarget else { return "PH" }
        return "von \(Format.number(target))"
    }

    private func heroProgress(_ totals: WorkTotals) -> Double {
        guard let target = context.workTarget, target > 0 else { return 0 }
        return totals.powerHours / target
    }

    /// "Heute" (or the day: "So, 15. Nov.", R22), "Soll bis heute" (R47), "Ø pro Arbeitstag".
    private func facts(_ totals: WorkTotals, areas: [MeasureDefinition]) -> [(String, String)] {
        [(day.relativeLabel(today: app.today), dayText),
         ("Soll bis heute", expectedText(areas)),
         ("Ø pro Arbeitstag", average(totals.powerHours))]
    }

    /// The day's power-hours; "–" in another week (R88).
    private var dayText: String {
        guard context.week.contains(day) else { return "–" }
        let totals: WorkTotals = context.workTotals(on: day)
        return totals.isEmpty ? "–" : totals.shortText
    }

    /// Sum of the areas' even pace by today (R47).
    private func expectedText(_ areas: [MeasureDefinition]) -> String {
        let paces: [Pace] = areas.compactMap { context.pace(for: $0) }
        guard !paces.isEmpty else { return "–" }
        return Format.powerHours(paces.reduce(0) { $0 + $1.expected })
    }

    private func average(_ total: Double) -> String {
        let workdays: Int = context.week.days.filter { isPassedWorkday($0) }.count
        guard workdays > 0, total > 0 else { return "–" }
        return Format.powerHours(total / Double(workdays))
    }

    private func isPassedWorkday(_ day: DayKey) -> Bool {
        day <= context.today && !context.isFreeDay(day) && day.weekday.rawValue <= Weekday.friday.rawValue
    }

    /// "Ziel erreicht in 3 von 8 Wochen" (R88), nil without any weekly PH target.
    private var historySentence: String? {
        guard history.contains(where: { $0.target != nil }) else { return nil }
        let reached: Int = history.filter(\.isReached).count
        return "Ziel erreicht in \(reached) von \(history.count) Wochen"
    }

    /// Reloads the history when the week or its power-hours change.
    private var historyKey: String {
        "\(context.week.string)|\(Format.plain(context.workTotals().powerHours))|\(context.work.count)"
    }
}

/// One area against its weekly goal: bar with the even-pace tick, "6 von 8 PH – im Plan" and the
/// three biggest topics; a tap opens the power-hour editor with the area chosen (R47, R53).
private struct AreaRow: View {
    let context: WeekContext
    let measure: MeasureDefinition
    let day: DayKey
    let today: DayKey
    let tint: Color
    let topics: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(measure.title)
                        .font(.body.weight(.semibold))
                    Spacer(minLength: 6)
                    Text(status)
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(statusColor)
                }
                if let pace, pace.target > 0 {
                    GoalBar(fraction: pace.fraction, expected: expectedFraction(pace), reached: pace.isReached, tint: tint)
                }
                if let dayLine {
                    Text(dayLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !topics.isEmpty {
                    Text(topics)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet die Erfassung")
    }

    private var pace: Pace? { context.pace(for: measure) }

    private var status: String {
        guard let pace else { return Format.powerHours(context.weekValue(measure) ?? 0) }
        return pace.label(unit: "PH")
    }

    private var statusColor: Color {
        guard let pace else { return .primary }
        if pace.isReached { return .green }
        return pace.isBehind ? .orange : .primary
    }

    private func expectedFraction(_ pace: Pace) -> Double? {
        guard pace.target > 0 else { return nil }
        return min(1, pace.expected / pace.target)
    }

    /// "heute +2 PH" / "So, 15. Nov. noch nichts"; nothing in another week.
    private var dayLine: String? {
        guard context.week.contains(day) else { return nil }
        let hours: Double = context.dayValue(measure, on: day) ?? 0
        let label: String = day == today ? "heute" : day.shortLabel
        return hours > 0 ? "\(label) +\(Format.powerHours(hours))" : "\(label) noch nichts"
    }
}

/// An entry: the power-hours in the area's colour, what for (orange when missing), then the
/// result or the area (R52, R53).
private struct FocusEntryLabel: View {
    let block: WorkBlock
    let area: String
    let tint: Color

    private var task: String { block.task.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var detail: String {
        let result: String = block.result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? area : result
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(Format.number(block.hours))
                .font(.system(.headline, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .frame(width: 46, height: 32)
                .background(tint.gradient, in: .rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                if task.isEmpty {
                    Text("Beschreibung fehlt")
                        .foregroundStyle(.orange)
                } else {
                    Text(task)
                        .foregroundStyle(.primary)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }
}

/// R88: power-hours of the last 8 weeks against each week's target; a tap on a bar shows that week.
private struct WorkHistoryChart: View {
    let points: [WeekWorkPoint]
    let shown: WeekKey
    let onSelect: (WeekKey) -> Void

    var body: some View {
        let labels: [String] = points.map(\.week.label)
        let uniform: Double? = uniformTarget
        Chart {
            ForEach(points) { point in
                BarMark(x: .value("Woche", point.week.label), y: .value("PH", point.powerHours))
                    .foregroundStyle(barColor(point))
                    .cornerRadius(4)
            }
            if let uniform {
                RuleMark(y: .value("Ziel", uniform))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.primary.opacity(0.6))
            } else {
                ForEach(targetPoints) { point in
                    LineMark(x: .value("Woche", point.week.label), y: .value("Ziel", point.target ?? 0),
                             series: .value("Reihe", "Ziel"))
                        .interpolationMethod(.stepCenter)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(Color.primary.opacity(0.6))
                }
            }
        }
        .chartXScale(domain: labels)
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
        .frame(height: 150)
        .accessibilityHint("Ein Tipp auf einen Balken zeigt diese Woche")
    }

    /// The same target every week: one dashed line; otherwise a stepped line per week.
    private var uniformTarget: Double? {
        let targets: [Double] = points.compactMap(\.target)
        guard let first = targets.first, targets.count == points.count,
              targets.allSatisfy({ abs($0 - first) < 1e-9 }) else { return nil }
        return first
    }

    private var targetPoints: [WeekWorkPoint] {
        points.filter { $0.target != nil }
    }

    private func barColor(_ point: WeekWorkPoint) -> Color {
        let base: Color = point.isReached ? .green : GoalPalette.color(goal: "3")
        return point.week == shown ? base : base.opacity(0.45)
    }

    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let anchor = proxy.plotFrame else { return }
        let x: CGFloat = location.x - geometry[anchor].origin.x
        guard let label = proxy.value(atX: x, as: String.self),
              let point = points.first(where: { $0.week.label == label }) else { return }
        onSelect(point.week)
    }
}
