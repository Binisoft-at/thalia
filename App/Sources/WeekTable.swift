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
    /// v11 P4.1: "Wochenübersicht" as a sheet while the window is too narrow for the column.
    @State private var showsSummarySheet = false

    private var closeTitle: String { context.isClosed ? "Abgeschlossen" : "Woche abschließen" }
    private var closeSymbol: String { context.isClosed ? "checkmark.seal.fill" : "flag.checkered" }

    /// v11 P4.1, P4.6: the column follows the stored choice (`AppModel.showsWeekSummary`, key "week.summary") while
    /// it fits; closing it by hand changes the choice.
    private var summaryColumn: Binding<Bool> {
        let model: AppModel = app
        return Binding(get: { model.showsWeekSummaryColumn }, set: { model.showsWeekSummary = $0 })
    }

    private var summaryHelp: String {
        guard app.fitsWeekSummary else { return "Fenster breiter ziehen, um die Spalte zu zeigen" }
        return "Wochenwertung, Ziele und Wochenziele ein- oder ausblenden (⌥⌘0)"
    }

    /// v11 P4.1: the column while it fits, else the overview as a sheet.
    private func toggleSummary() {
        if app.fitsWeekSummary {
            app.showsWeekSummary.toggle()
        } else {
            showsSummarySheet = true
        }
    }

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
                        // v9: grades of a planned week (rare) below the table.
                        if context.archive?.hasGrades ?? false {
                            archiveCard
                        }
                        Button {
                            app.sheet = .newItem(context.week, categoryKey: nil)
                        } label: {
                            Label("Punkt anlegen", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                        .padding(.vertical, 12)
                    } else if context.isArchiveWeek {
                        // v9: a week from old records – its grades instead of "Noch kein Plan".
                        archiveCard
                        if context.week < app.today.week {
                            Button {
                                app.sheet = .importPast(context.week)
                            } label: {
                                Label("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.bordered)
                            .padding(.vertical, 8)
                        } else {
                            // A week that isn't over keeps the way to its plan, even with grades.
                            NoPlanView(week: context.week)
                                .padding(.vertical, 20)
                        }
                    } else {
                        NoPlanView(week: context.week)
                            .padding(.vertical, 20)
                    }
                } header: {
                    WeekTableHeader(context: context)
                        .diagWidth("week table header")
                }
            }
            // R10: the table never gets narrower than its columns.
            .frame(minWidth: WeekTableColumns.minWidth)
            .diagWidth("week table content")
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .weekTableWindowMinWidth(WeekTableColumns.minWidth + 40)
        .diagWidth("week table scroll")
        .weekTableTitle(context.week)
        .inspector(isPresented: summaryColumn) {
            WeekSummaryPanel(context: context)
                .diagWidth("week inspector")
                .inspectorColumnWidth(min: 240, ideal: 270, max: 360)
        }
        .sheet(isPresented: $showsSummarySheet) {
            WeekSummarySheet(context: context) { showsSummarySheet = false }
                .thaliaLocalSheet(app)
        }
        // v11 P4.1, P4.6: ⌥⌘0 switches the choice on afresh while the column doesn't fit – the sheet shows then.
        .onChange(of: app.showsWeekSummary) { _, shown in
            if shown && !app.fitsWeekSummary { showsSummarySheet = true }
        }
        // An action in the sheet opens another one from the main window: this one goes first.
        .onChange(of: app.sheet?.id) { _, id in
            if id != nil { showsSummarySheet = false }
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
                // v11 P6.15: ⌘T is Gehe zu → "Zu heute" (on Woche the running week) – no second shortcut here.
                Button {
                    app.selectedWeek = app.today.week
                } label: {
                    Label("Diese Woche", systemImage: "calendar")
                }
                .labelStyle(.titleAndIcon)
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
            // v11 P4.6: ⌥⌘0 lives in Gehe zu → "Wochenübersicht" (it also works with the button in the overflow).
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleSummary) {
                    Label("Wochenübersicht", systemImage: "sidebar.trailing")
                }
                .labelStyle(.titleAndIcon)
                .help(summaryHelp)
            }
            MainToolbar()
        }
    }
}

extension WeekTable {
    /// v9: the "Archiv" card on the table's columns, flat like the table; the two scores only while
    /// the side panel (which shows them) is hidden.
    var archiveCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            ArchiveCard(context: context, wide: true, showsScores: !app.showsWeekSummaryColumn)
                .padding(.vertical, 14)
        }
    }
}

/// v11 P4.1: "Wochenübersicht" as a sheet while the window is too narrow for its column.
private struct WeekSummarySheet: View {
    let context: WeekContext
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            WeekSummaryPanel(context: context)
                .navigationTitle("Wochenübersicht")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton(action: onClose)
                    }
                }
        }
        .thaliaSheetFrame(width: 420, height: 640)
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
    /// R10 (Mac): the window can't get narrower than the table. The iPad keeps its split layout. v11 P4.1: the
    /// same ideal width, so long titles don't make the table ask for more than its columns and push the
    /// "Wochenübersicht" column out of the window (CI run 38: table 748 + column 270 in 793 pt).
    @ViewBuilder
    func weekTableWindowMinWidth(_ width: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width, idealWidth: width)
        #else
        self
        #endif
    }

    /// v11 P6.15: Mac – "KW47" as the title and the dates below it, like Today (the toolbar keeps room for its
    /// buttons with text); the wide iPad keeps "KW47 · 16.–22. Nov.".
    @ViewBuilder
    func weekTableTitle(_ week: WeekKey) -> some View {
        #if os(macOS)
        navigationTitle(week.label)
            .navigationSubtitle(week.rangeLabel)
        #else
        navigationTitle("\(week.label) · \(week.rangeLabel)")
        #endif
    }
}

/// R10: lays a table row out on the shared columns.
struct WeekTableGrid<Title: View, Cell: View, Total: View>: View {
    let days: [DayKey]
    /// v8: sick and holiday days – their column is shaded grey.
    let shaded: Set<DayKey>
    let title: Title
    let cell: (DayKey) -> Cell
    let total: Total

    init(days: [DayKey], shaded: Set<DayKey> = [], @ViewBuilder title: () -> Title, @ViewBuilder cell: @escaping (DayKey) -> Cell,
         @ViewBuilder total: () -> Total) {
        self.days = days
        self.shaded = shaded
        self.title = title()
        self.cell = cell
        self.total = total()
    }

    private func shade(_ day: DayKey) -> Color {
        shaded.contains(day) ? Color.secondary.opacity(0.1) : Color.clear
    }

    var body: some View {
        HStack(spacing: WeekTableColumns.spacing) {
            title
                .frame(minWidth: WeekTableColumns.title, maxWidth: .infinity, alignment: .leading)
            ForEach(days, id: \.self) { day in
                cell(day)
                    .frame(width: WeekTableColumns.day)
                    .background(shade(day))
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
            WeekTableGrid(days: context.week.days, shaded: context.data.excusedDays) {
                HStack(spacing: 8) {
                    KeyBadge(key: category.key)
                        .fixedSize()
                    Text(context.title(of: category))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if context.isGood(category) {
                        // v10 (§1.2.3): the category's week score is above 8.
                        GoodWeekBadge()
                    }
                }
                .help("\(category.key) \(context.title(of: category))")
            } cell: { day in
                WeekTableCategoryDay(entry: context.score.category(category.key, on: day), isExcused: context.isExcused(day))
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

    /// v11 P6.14 (1): a Health value only the iPhone has on some day of the week (Mac; P9 turns it off for shared days).
    private var isHealthElsewhere: Bool {
        context.week.days.contains { context.isHealthElsewhere(measure, on: $0) }
    }

    /// The title; where the caption takes the target's place, the target and the hint.
    private var titleHelp: String {
        guard isHealthElsewhere else { return measure.title }
        let target: String = measure.record?.target.map { " · Ziel \($0.label)" } ?? ""
        return "\(measure.title)\(target)\n\(WeekContext.healthElsewhereHint)"
    }

    var body: some View {
        WeekTableGrid(days: context.week.days, shaded: context.data.excusedDays) {
            HStack(spacing: 6) {
                Text(measure.title)
                    .font(.callout)
                    .lineLimit(1)
                if isHealthElsewhere {
                    Text("aus Health am iPhone")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                } else if let target = measure.record?.target {
                    Text("Ziel \(target.label)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            .help(titleHelp)
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
    /// v8: a sick or holiday day – "–", it doesn't count.
    var isExcused = false

    private var text: String {
        if isExcused { return "–" }
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
        WeekTableGrid(days: context.week.days, shaded: context.data.excusedDays) {
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
            // v11 P5.6: VoiceOver reads the title as a button that opens the details.
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Öffnet die Details")
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
        let half: String? = excusedQuotaHint
        if item.isKnockout || kind != nil || half != nil {
            HStack(spacing: 4) {
                if item.isKnockout {
                    Image(systemName: "exclamationmark.octagon")
                        .foregroundStyle(.orange)
                }
                KindBadge(text: kind)
                if let half {
                    Text(half)
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
        }
    }

    /// v8: "½ krank" – what's still missing of the quota counts half because of sick or holiday days.
    private var excusedQuotaHint: String? {
        guard let quota = context.quotaProgress(item), quota.done < quota.target, context.quotaShare(item) > 1e-9 else { return nil }
        return "½ " + context.excusedWord(context.excusedDayList)
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
                HeroCard(title: context.week.label, subtitle: heroSubtitle,
                         value: Format.score(context.heroScore, outOf: false), caption: "Woche",
                         progress: heroProgress)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.archiveCoverageLine)
                            .font(.caption)
                            .foregroundStyle(coverageColor)
                        if lacksHealthValues {
                            // v11 P6.14 (3): the running week reads Apple Health, which only the iPhone has.
                            Label(WeekContext.lacksHealthHint, systemImage: "heart.text.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button {
                            app.sheet = .explainer(.scoring)
                        } label: {
                            Label("Ziele gleich gewichtet", systemImage: "questionmark.circle")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            if context.isClosed && context.isFrozen {
                // v10 (Grundregel 2): a closed week before the current segment – "Neu berechnen".
                Section {
                    FrozenWeekNote(context: context)
                }
            }

            // v9 (decision 9): both scores of a week with grades or a value laut Unterlagen.
            if context.showsArchive {
                Section {
                    ArchiveScores(context: context)
                } header: {
                    Label("Archiv", systemImage: "archivebox")
                }
            }

            // R68: one coloured list – each goal with its bar and score.
            Section {
                ForEach(context.goals) { goal in
                    GoalScoreLine(goal: goal, week: liveGoalWeek(goal), isExcused: context.isGoalExcused(goal),
                                  fallback: archiveGoalScore(goal), title: context.title(of: goal))
                }
            } header: {
                Text(goalsTitle)
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

            // v8: past weeks and several weeks as one PDF.
            Section {
                Button {
                    app.sheet = .importPast(pastWeek)
                } label: {
                    Label("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    app.sheet = .rangePDF
                } label: {
                    Label("Mehrere Wochen als PDF…", systemImage: "doc.richtext")
                }
            }
        }
        .sheet(item: $sharing) { request in
            ShareSheet(content: request.content)
                .environment(app)
                .toastHost(app)
        }
    }

    /// Orange while the week isn't fully comparable; a week of only sick or holiday days isn't a gap (v8).
    /// v9: an archive week isn't a gap either.
    private var coverageColor: Color {
        if context.score.isComplete || context.score.isExcused || context.isArchiveWeek { return .secondary }
        return .orange
    }

    /// v9: "KW45 · Wertung laut Unterlagen" for a week without items.
    private var heroSubtitle: String {
        guard let label = context.heroScoreLabel else { return context.week.rangeLabel }
        return context.week.rangeLabel + " · " + label
    }

    private var heroProgress: Double {
        let value: Double = context.heroScore ?? 0
        return value / 10
    }

    /// v9: a week without items shows its goals under today's rules.
    private var goalsTitle: String {
        context.isArchiveWeek ? "Jahresziele · " + ImportWeekSummary.recalculatedLabel : "Jahresziele"
    }

    /// v11 P6.1: a frozen closed week shows the goal scores it stored (`fallback`), every other week the live ones.
    private func liveGoalWeek(_ goal: AnnualGoal) -> GoalWeek? {
        context.storedGoalScores == nil ? context.score.goalWeek[goal.key] : nil
    }

    /// The goal's score where the live one doesn't show: a week without items (archive), a frozen closed week (stored).
    private func archiveGoalScore(_ goal: AnnualGoal) -> Double? {
        guard !context.hasPlan || context.storedGoalScores != nil else { return nil }
        return context.shownGoalScore(goal.key)
    }

    /// v11 P6.14 (3): Mac, Watch, iPad – the running week reads Apple Health that this device doesn't have.
    private var lacksHealthValues: Bool {
        !HealthDevice.scoresHealth && context.lacksHealthValues
    }

    private var nextWeek: WeekKey { context.week.adding(weeks: 1) }
    /// v8: the week shown when it lies in the past, else nil (the window chooses).
    private var pastWeek: WeekKey? { context.week < app.today.week ? context.week : nil }
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
    /// v8: everything planned for the goal fell on sick or holiday days.
    var isExcused = false
    /// v9: the goal's value from archive grades (a week without items).
    var fallback: Double?
    /// v10 (§1.4.1): the goal's title in this week (a week of an earlier segment: the one of then).
    var title: String?

    private var score: Double? { week?.score ?? fallback }
    private var goalTitle: String { title ?? goal.title }

    /// "7,5" · "–"; v8: "entschuldigt".
    private var scoreText: String {
        if score == nil && isExcused { return WeekScore.excusedLabel }
        return Format.score(score, outOf: false)
    }

    private var fraction: Double {
        let value: Double = score ?? 0
        return min(1, max(0, value / 10))
    }

    private var spokenText: String {
        if score == nil && isExcused { return "\(goal.key) \(goalTitle): \(WeekScore.excusedLabel), krank oder Urlaub" }
        guard let score else { return "\(goal.key) \(goalTitle): noch keine Wertung" }
        return "\(goal.key) \(goalTitle): Wertung \(Format.score(score))"
    }

    var body: some View {
        let tint: Color = GoalPalette.color(goal: goal.key)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                KeyBadge(key: goal.key)
                Text(goalTitle)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(scoreText)
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
