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

    private var closeTitle: String { context.isClosed ? "Abgeschlossen" : "Woche abschließen" }
    private var closeSymbol: String { context.isClosed ? "checkmark.seal.fill" : "flag.checkered" }

    /// R65: the day the titles and "Details…" open.
    private var detailDay: DayKey {
        weekDetailDay(context.week, selected: app.selectedDay, today: app.today)
    }

    var body: some View {
        let day: DayKey = detailDay
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    if context.hasPlan {
                        ForEach(context.goals) { goal in
                            ForEach(context.categories(of: goal)) { category in
                                WeekTableCategory(context: context, category: category, detailDay: day)
                            }
                        }
                        Button {
                            app.sheet = .newItem(context.week, categoryKey: nil)
                        } label: {
                            Label("Punkt anlegen", systemImage: "plus")
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
            // R10: the table never gets narrower than its columns.
            .frame(minWidth: WeekTableColumns.minWidth)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .weekTableWindowMinWidth(WeekTableColumns.minWidth + 40)
        .navigationTitle("\(context.week.label) · \(context.week.rangeLabel)")
        .inspector(isPresented: $showsSummary) {
            WeekSummaryPanel(context: context)
                .inspectorColumnWidth(min: 240, ideal: 270, max: 360)
        }
        .toolbar {
            // R62: buttons with text; the tooltips name the shortcuts (the arrows' live in "Gehe zu").
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    app.selectedWeek = context.week.adding(weeks: -1)
                } label: {
                    Label("Vorige Woche", systemImage: "chevron.left")
                }
                .labelStyle(.titleAndIcon)
                .help("Vorige Woche (⇧⌘[)")
                Button {
                    app.selectedWeek = app.today.week
                } label: {
                    Label("Diese Woche", systemImage: "calendar")
                }
                .labelStyle(.titleAndIcon)
                .keyboardShortcut("t", modifiers: .command)
                .disabled(context.week == app.today.week)
                .help("Zur aktuellen Woche (⌘T)")
                Button {
                    app.selectedWeek = context.week.adding(weeks: 1)
                } label: {
                    Label("Nächste Woche", systemImage: "chevron.right")
                }
                .labelStyle(.titleAndIcon)
                .help("Nächste Woche (⇧⌘])")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    app.sheet = .closeWeek(context.week)
                } label: {
                    Label(closeTitle, systemImage: closeSymbol)
                }
                .labelStyle(.titleAndIcon)
                .help("Woche abschließen (⇧⌘↩)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsSummary.toggle()
                } label: {
                    Label("Wochenübersicht", systemImage: "sidebar.trailing")
                }
                .labelStyle(.titleAndIcon)
                .keyboardShortcut("0", modifiers: [.command, .option])
                .help("Wochenwertung, Ziele und Wochenziele ein- oder ausblenden (⌥⌘0)")
            }
            MainToolbar()
        }
    }
}

/// R10: one column definition for the header, the category and the item rows, so "Di" always
/// stands above Tuesday and the week column is never cut off.
enum WeekTableColumns {
    /// The title column: at least this, flexible.
    static let title: CGFloat = 120
    static let day: CGFloat = 38
    static let week: CGFloat = 44
    static let spacing: CGFloat = 4
    /// Horizontal inset of every row.
    static let inset: CGFloat = 4
    /// Title, seven days, the week column, the eight gaps and both insets.
    static let minWidth: CGFloat = title + 7 * day + week + 8 * spacing + 2 * inset
}

private extension View {
    /// R10 (Mac): the window can't get narrower than the table. The iPad keeps its split layout.
    @ViewBuilder
    func weekTableWindowMinWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width)
        #else
        self
        #endif
    }
}

/// R10: lays a table row out on the shared columns.
struct WeekTableGrid<Title: View, Cell: View, Total: View>: View {
    let days: [DayKey]
    let title: Title
    let cell: (DayKey) -> Cell
    let total: Total

    init(days: [DayKey], @ViewBuilder title: () -> Title, @ViewBuilder cell: @escaping (DayKey) -> Cell,
         @ViewBuilder total: () -> Total) {
        self.days = days
        self.title = title()
        self.cell = cell
        self.total = total()
    }

    var body: some View {
        HStack(spacing: WeekTableColumns.spacing) {
            title
                .frame(minWidth: WeekTableColumns.title, maxWidth: .infinity, alignment: .leading)
            ForEach(days, id: \.self) { day in
                cell(day)
                    .frame(width: WeekTableColumns.day)
            }
            total
                .frame(width: WeekTableColumns.week, alignment: .trailing)
        }
        .padding(.horizontal, WeekTableColumns.inset)
    }
}

/// Pinned above the table: the weekdays with date, day type or seal, and the status (R8) – a click
/// opens the day in Today, the context menu closes it or edits type and note (R42).
private struct WeekTableHeader: View {
    let context: WeekContext

    var body: some View {
        WeekTableGrid(days: context.week.days) {
            Text("Punkt")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        } cell: { day in
            WeekDayHeader(context: context, day: day, width: WeekTableColumns.day)
        } total: {
            Text("Woche")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// One category: a header line with the category result per day, its items, then the folded
/// "Werte" rows (R85).
private struct WeekTableCategory: View {
    let context: WeekContext
    let category: TrackCategory
    let detailDay: DayKey
    @Environment(AppModel.self) private var app
    @State private var showsValues = false

    var body: some View {
        let items: [PlanItem] = context.items(in: category)
        let values: [MeasureDefinition] = WeekValues.measures(in: category, context: context)
        VStack(alignment: .leading, spacing: 0) {
            WeekTableGrid(days: context.week.days) {
                HStack(spacing: 8) {
                    KeyBadge(key: category.key)
                        .fixedSize()
                    Text(category.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .help("\(category.key) \(category.title)")
            } cell: { day in
                WeekTableCategoryDay(entry: context.score.category(category.key, on: day))
            } total: {
                Text(Format.score(context.score.categoryWeek[category.key], outOf: false))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .padding(.top, 14)
            .padding(.bottom, 4)
            Divider()
            if items.isEmpty {
                Text("Keine Punkte in dieser Woche")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.horizontal, WeekTableColumns.inset)
            }
            ForEach(Array(items.enumerated()), id: \.element.code) { index, item in
                WeekTableRow(context: context, item: item, striped: index % 2 == 1, detailDay: detailDay)
            }
            if !values.isEmpty {
                valuesToggle(count: values.count)
                if showsValues {
                    ForEach(values) { measure in
                        WeekTableValueRow(context: context, measure: measure)
                    }
                }
            }
        }
        .contextMenu {
            Button("Punkt anlegen", systemImage: "plus") { app.sheet = .newItem(context.week, categoryKey: category.key) }
            Button("Messwert anlegen", systemImage: "ruler") { app.sheet = .editMeasure(nil, context.week, categoryKey: category.key) }
        }
    }

    /// R85: "Werte" folds the daily values of the category in and out.
    private func valuesToggle(count: Int) -> some View {
        Button {
            withAnimation(.snappy) { showsValues.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showsValues ? "chevron.down" : "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .frame(width: 10)
                Text("Werte")
                    .font(.caption.weight(.semibold))
                Text("\(count)")
                    .font(.caption)
                    .monospacedDigit()
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, WeekTableColumns.inset)
            .padding(.vertical, 5)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(showsValues ? "Tageswerte ausblenden" : "Tageswerte Mo–So zeigen")
        .accessibilityLabel("Werte, \(count)")
    }
}

/// R85: one daily measurement Mo–So – green met, red missed, "·" empty; a click records that day.
private struct WeekTableValueRow: View {
    let context: WeekContext
    let measure: MeasureDefinition

    var body: some View {
        WeekTableGrid(days: context.week.days) {
            HStack(spacing: 6) {
                Text(measure.title)
                    .font(.callout)
                    .lineLimit(1)
                if let target = measure.record?.target {
                    Text("Ziel \(target.label)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .help(measure.title)
        } cell: { day in
            WeekValueCell(context: context, measure: measure, day: day, width: WeekTableColumns.day - 4)
        } total: {
            EmptyView()
        }
        .padding(.vertical, 2)
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
            .frame(width: WeekTableColumns.day)
    }
}

/// One item: title and kind, seven cells (click cycles through the allowed marks), quota.
private struct WeekTableRow: View {
    let context: WeekContext
    let item: PlanItem
    let striped: Bool
    /// R65: the day the title and "Details…" open.
    let detailDay: DayKey
    @Environment(AppModel.self) private var app
    @State private var hovering = false
    @State private var confirmsDelete = false

    var body: some View {
        WeekTableGrid(days: context.week.days) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.callout)
                    .lineLimit(2)
                    .help(item.title)
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { app.sheet = .item(item, detailDay) }
        } cell: { day in
            WeekMarkCell(context: context, item: item, day: day)
                .frame(width: WeekTableColumns.day - 6, height: 28)
        } total: {
            Text(weekText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .background(rowBackground, in: .rect(cornerRadius: 6))
        .onHover { hovering = $0 }
        .contextMenu {
            WeekItemMenu(app: app, item: item, detailDay: detailDay, confirmsDelete: $confirmsDelete)
        }
        .weekItemDeleteDialog(item, isPresented: $confirmsDelete, app: app)
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
        // R64: the same short label as Today and the PDF.
        let kind: String? = context.kindLabel(item)
        if item.isKnockout || kind != nil {
            HStack(spacing: 4) {
                if item.isKnockout {
                    Image(systemName: "exclamationmark.octagon")
                        .foregroundStyle(.orange)
                }
                KindBadge(text: kind)
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
            }

            // R68: one coloured list – each goal with its bar and score.
            Section("Jahresziele") {
                ForEach(context.goals) { goal in
                    GoalScoreLine(goal: goal, week: context.score.goalWeek[goal.key])
                }
            }

            targetsSection

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
                    Label(closeTitle, systemImage: closeSymbol)
                }
                Button {
                    app.sheet = .report(context.week)
                } label: {
                    Label("Bericht", systemImage: "doc.text")
                }
                // R56: plans exactly the week after this one.
                Button {
                    app.sheet = .planWeek(nextWeek)
                } label: {
                    Label("\(nextWeek.label) planen", systemImage: "sparkles")
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
                .environment(app)
                .toastHost(app)
        }
    }

    private var nextWeek: WeekKey { context.week.adding(weeks: 1) }
    private var closeTitle: String { context.isClosed ? "Abgeschlossen" : "Woche abschließen" }
    private var closeSymbol: String { context.isClosed ? "checkmark.seal.fill" : "flag.checkered" }

    /// R16: the one weekly-target list, plus the power-hours of the week.
    @ViewBuilder
    private var targetsSection: some View {
        let hasTargets: Bool = !context.weeklyTargets.isEmpty
        let totals: WorkTotals = context.workTotals()
        if hasTargets || !totals.isEmpty {
            Section("Wochenziele") {
                if hasTargets {
                    WeeklyTargetsList(context: context, onOpen: weekTargetOpener(context: context, app: app))
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

/// R68: an annual goal in its colour – key, title, a thin bar and the week's score.
private struct GoalScoreLine: View {
    let goal: AnnualGoal
    let week: GoalWeek?

    private var score: Double? { week?.score }

    private var fraction: Double {
        let value: Double = score ?? 0
        return min(1, max(0, value / 10))
    }

    private var spokenText: String {
        guard let score else { return "\(goal.key) \(goal.title): noch keine Wertung" }
        return "\(goal.key) \(goal.title): Wertung \(Format.score(score))"
    }

    var body: some View {
        let tint: Color = GoalPalette.color(goal: goal.key)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                KeyBadge(key: goal.key)
                Text(goal.title)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(Format.score(score, outOf: false))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(score == nil ? Color.secondary : tint)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: geometry.size.width * fraction)
                }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
    }
}
