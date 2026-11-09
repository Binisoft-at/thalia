import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// "Woche" on the Mac and the wide iPad (M1): the printed sheet as one dense table – every
/// category with its items × Mo–So, the day header pinned on top, the week's score, goals,
/// weekly targets and actions in a side panel.
struct WeekTable: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @AppStorage("week.summary") private var showsSummary = true

    static let dayWidth: CGFloat = 38

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    if context.hasPlan {
                        ForEach(context.goals) { goal in
                            ForEach(context.categories(of: goal)) { category in
                                WeekTableCategory(context: context, category: category)
                            }
                        }
                        Button {
                            app.sheet = .newItem(context.week, categoryKey: nil)
                        } label: {
                            Label("Punkt hinzufügen", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 12)
                    } else {
                        NoPlanView(week: context.week)
                            .padding(.vertical, 20)
                    }
                } header: {
                    WeekTableHeader(context: context)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("\(context.week.label) · \(context.week.rangeLabel)")
        .inspector(isPresented: $showsSummary) {
            WeekSummaryPanel(context: context)
                .inspectorColumnWidth(min: 240, ideal: 270, max: 360)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    app.selectedWeek = context.week.adding(weeks: -1)
                } label: {
                    Label("Vorige Woche", systemImage: "chevron.left")
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .help("Vorige Woche (⇧⌘[)")
                Button("Diese Woche") { app.selectedWeek = app.today.week }
                    .disabled(context.week == app.today.week)
                Button {
                    app.selectedWeek = context.week.adding(weeks: 1)
                } label: {
                    Label("Nächste Woche", systemImage: "chevron.right")
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .help("Nächste Woche (⇧⌘])")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    app.sheet = .closeWeek(context.week)
                } label: {
                    Label(context.isClosed ? "Abgeschlossen" : "Woche abschließen",
                          systemImage: context.isClosed ? "checkmark.seal.fill" : "flag.checkered")
                }
                .help("Woche abschließen")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsSummary.toggle()
                } label: {
                    Label("Wochenübersicht", systemImage: "sidebar.trailing")
                }
                .help("Wochenwertung, Ziele und Wochenziele ein- oder ausblenden")
            }
            MainToolbar()
        }
    }
}

/// Pinned above the table: the weekdays with date, day type and – once closed – the day score.
private struct WeekTableHeader: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 4) {
            Text("Punkt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(context.week.days, id: \.self) { day in
                Button {
                    app.selectedDay = day
                    app.tab = .today
                    app.sidebar = .today
                } label: {
                    WeekTableDayLabel(context: context, day: day)
                }
                .buttonStyle(.plain)
                .help("\(day.longLabel) in Heute öffnen")
            }
            Text("Woche")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct WeekTableDayLabel: View {
    let context: WeekContext
    let day: DayKey

    /// The score once the day is closed (U4), the share filled in before.
    private var value: String {
        let overall: DayOverall? = context.score.days[day]
        if context.isClosed(day) { return Format.score(overall?.score, outOf: false) }
        let fill: Double = overall?.coverage ?? 0
        return "\(percent(fill)) %"
    }

    var body: some View {
        let closed: Bool = context.isClosed(day)
        let isToday: Bool = day == context.today
        VStack(spacing: 1) {
            Text("\(day.weekday.short) \(day.day).")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isToday ? Brand.accent : .primary)
            Image(systemName: closed ? "checkmark.seal.fill" : DayTypes.symbol(for: context.dayType(day)))
                .font(.system(size: 10))
                .foregroundStyle(closed ? Brand.accent : .secondary)
            Text(value)
                .font(.system(size: 10, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .frame(width: WeekTable.dayWidth)
        .padding(.vertical, 2)
        .background(isToday ? Brand.accent.opacity(0.1) : Color.clear, in: .rect(cornerRadius: 8))
    }
}

/// One category: a header line with the category result per day, then its items.
private struct WeekTableCategory: View {
    let context: WeekContext
    let category: TrackCategory
    @Environment(AppModel.self) private var app

    var body: some View {
        let items: [PlanItem] = context.items(in: category)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                HStack(spacing: 8) {
                    KeyBadge(key: category.key)
                        .fixedSize()
                    Text(category.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                ForEach(context.week.days, id: \.self) { day in
                    WeekTableCategoryDay(entry: context.score.category(category.key, on: day))
                }
                Text(Format.score(context.score.categoryWeek[category.key], outOf: false))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            .padding(.top, 14)
            .padding(.bottom, 4)
            Divider()
            if items.isEmpty {
                Text("Keine Punkte in dieser Woche")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }
            ForEach(Array(items.enumerated()), id: \.element.code) { index, item in
                WeekTableRow(context: context, item: item, striped: index % 2 == 1)
            }
        }
        .contextMenu {
            Button("Punkt hinzufügen", systemImage: "plus") { app.sheet = .newItem(context.week, categoryKey: category.key) }
            Button("Messwert hinzufügen", systemImage: "ruler") { app.sheet = .editMeasure(nil, context.week, categoryKey: category.key) }
        }
    }
}

/// The category's result on a day: the score once the category is complete, a dot otherwise.
private struct WeekTableCategoryDay: View {
    let entry: CategoryDay

    private var text: String {
        guard entry.due > 0 else { return "" }
        guard entry.isComplete else { return "·" }
        guard let score = entry.score else { return "–" }
        return Format.score(score)
    }

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(entry.knockedOut ? Color.orange : Color.secondary)
            .frame(width: WeekTable.dayWidth)
    }
}

/// One item: title and schedule, seven cells (click cycles through the allowed marks), quota.
private struct WeekTableRow: View {
    let context: WeekContext
    let item: PlanItem
    let striped: Bool
    @Environment(AppModel.self) private var app
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.callout)
                    .lineLimit(2)
                    .help(item.title)
                meta
            }
            .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .contentShape(.rect)
            .onTapGesture { app.sheet = .item(item, detailDay) }
            ForEach(context.week.days, id: \.self) { day in
                MarkCell(
                    mark: context.mark(item, on: day),
                    applies: item.days.contains(day.weekday) && item.schedule != .optional,
                    isToday: day == context.today,
                    suggestion: context.suggestion(item, on: day),
                    options: context.options(item, on: day),
                    onSet: { app.setMark($0, item: item, day: day) }
                )
                .frame(width: WeekTable.dayWidth - 6, height: 28)
                .frame(width: WeekTable.dayWidth)
            }
            Text(weekText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(rowBackground, in: .rect(cornerRadius: 6))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Details…", systemImage: "info.circle") { app.sheet = .item(item, detailDay) }
            Button("Bearbeiten…", systemImage: "pencil") { app.sheet = .item(item, detailDay) }
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([item]) }
        }
    }

    private var detailDay: DayKey {
        context.week.contains(app.today) ? app.today : context.week.monday
    }

    private var rowBackground: Color {
        if hovering { return Brand.accent.opacity(0.08) }
        return striped ? Color.secondary.opacity(0.05) : Color.clear
    }

    /// "2/3×" for weekly quotas, "62 %" for progress items.
    private var weekText: String {
        if let quota = context.quotaProgress(item) { return "\(quota.done)/\(quota.target)×" }
        if let progress = context.progress(item) { return "\(percent(progress)) %" }
        return ""
    }

    @ViewBuilder
    private var meta: some View {
        if item.isKnockout || item.schedule != .fixed {
            HStack(spacing: 4) {
                if item.isKnockout {
                    Image(systemName: "exclamationmark.octagon")
                        .foregroundStyle(.orange)
                }
                if item.schedule != .fixed {
                    Text(item.schedule.label)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
        }
    }
}

/// The side panel: week score with the ten goals, weekly targets, power-hours, plan context, actions.
private struct WeekSummaryPanel: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var sharing: ShareRequest?

    var body: some View {
        List {
            Section {
                HeroCard(title: context.week.label, subtitle: context.week.rangeLabel,
                         value: Format.score(context.score.overall, outOf: false), caption: "Woche",
                         progress: (context.score.overall ?? 0) / 10)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.score.goalsTotal == 0 ? "Noch keine Ziele" : context.score.coverageText)
                            .font(.caption)
                            .foregroundStyle(context.score.isComplete ? Color.secondary : Color.orange)
                        Button {
                            app.sheet = .explainer(.scoring)
                        } label: {
                            Label("Je Ziel 10 %", systemImage: "questionmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                GoalBars(scores: context.goals.map { context.score.goalWeek[$0.key]?.score }, height: 44)
            }

            Section("Jahresziele") {
                ForEach(context.goals) { goal in
                    LabeledContent("\(goal.key) \(goal.title)", value: Format.score(context.score.goalWeek[goal.key]?.score, outOf: false))
                        .font(.caption)
                        .monospacedDigit()
                }
            }

            WeekTargetsSection(context: context)

            if let plan = context.plan, !(plan.title.isEmpty && plan.details.isEmpty) {
                Section("Wochenkontext") {
                    if !plan.title.isEmpty {
                        Text(plan.title).font(.subheadline.weight(.semibold))
                    }
                    if !plan.details.isEmpty {
                        Text(plan.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Button("Bearbeiten…") { app.sheet = .weekInfo(context.week) }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }

            Section {
                Button {
                    app.sheet = .closeWeek(context.week)
                } label: {
                    Label(context.isClosed ? "Abgeschlossen" : "Woche abschließen",
                          systemImage: context.isClosed ? "checkmark.seal.fill" : "flag.checkered")
                }
                Button {
                    app.sheet = .report(context.week)
                } label: {
                    Label("Bericht", systemImage: "doc.text")
                }
                Button {
                    app.sheet = .importPlan(prompt: true)
                } label: {
                    Label("Nächste Woche planen", systemImage: "sparkles")
                }
                PDFShareButton(context: context)
                Button {
                    sharing = ShareRequest(content: .week(context))
                } label: {
                    Label("Woche als Bild teilen", systemImage: "photo")
                }
            }
        }
        .sheet(item: $sharing) { request in
            ShareSheet(content: request.content)
        }
    }
}

/// Weekly targets with an even-pace marker and the power-hours of the week.
private struct WeekTargetsSection: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app

    var body: some View {
        let weekly: [MeasureDefinition] = context.measures.filter { $0.record?.period == .week && $0.record?.target != nil }
        let totals: WorkTotals = context.workTotals()
        if !weekly.isEmpty || !totals.isEmpty {
            Section("Wochenziele") {
                ForEach(weekly) { measure in
                    if let record = measure.record, let target = record.target {
                        PaceRow(title: measure.title, unit: Units.display(measure.unit),
                                pace: Pace(done: context.weekValue(measure) ?? 0, target: target.scaleMax, days: record.days,
                                           week: context.week, today: context.today),
                                isLimit: target.isLimit)
                    }
                }
                if !totals.isEmpty {
                    Button {
                        app.sheet = .explainer(.powerHours)
                    } label: {
                        Label(totals.explanation, systemImage: "equal.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }
}
