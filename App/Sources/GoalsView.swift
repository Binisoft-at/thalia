import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

/// "Ziele": the ten annual goals – the permanent foundation. Each is 10 % of the week, however
/// many categories it has. A behaviour score is not an outcome: it doesn't prove the yearly outcome itself.
struct GoalsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            GoalsContent(context: context)
        }
        .navigationTitle("Ziele")
        .toolbar { MainToolbar() }
    }
}

struct GoalsContent: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    /// Observed so the cards refresh when a week is closed or scored again (R11).
    @Query(filter: #Predicate<WeekPlan> { $0.deletedAt == nil }, sort: \WeekPlan.weekKey) private var plans: [WeekPlan]

    private var period: GoalPeriod { app.store.goalPeriod }

    /// v10: the year card's menu and the capture sheets opened from here.
    @State private var sheet: GoalsSheet?
    /// v10: "Leseliste" and "Jahresziele bearbeiten" from the year card's menu (and the CI screens).
    @State private var showsReadingList = false
    @State private var showsGoalSettings = false
    @State private var launchGoal: String?
    /// v10 (§1.2.4): the measures of the latest week with definitions, when this week has none.
    @State private var fallbackMeasures: [MeasureRecord] = []

    var body: some View {
        let excused: Set<WeekKey> = excusedWeeks
        ResultSeriesReader(results: context.activeResults, context: context) { table in
            page(table, excused: excused)
        }
        .background(Color.groupedBackground)
        .navigationDestination(isPresented: $showsReadingList) { ReadingListView() }
        .navigationDestination(isPresented: $showsGoalSettings) { GoalYearSettingsView() }
        .navigationDestination(item: $launchGoal) { key in GoalDetailView(goalKey: key) }
        .sheet(item: $sheet) { sheet in
            GoalsSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
        .task(id: context.measures.isEmpty) { loadFallbackMeasures() }
        .onAppear(perform: openLaunchScreen)
    }

    /// The page: the year card, "Gerade dabei", the goal cards, earlier segments, the weighting (v10: a
    /// function of its own, so the reader's closure stays small for the type checker).
    private func page(_ table: ResultProgressTable, excused: Set<WeekKey>) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                yearCard
                if context.goals.isEmpty {
                    EmptyStateView(title: "Noch keine Jahresziele",
                                   message: "Richte deine zehn Jahresziele und 18 Kategorien aus der Übergabe ein – oder importiere sie mit dem Wochenplan.",
                                   symbol: "target", createTitle: "Meine Struktur einrichten",
                                   onCreate: { app.store.seedStructure() }, onImport: { app.sheet = .importPlan(prompt: true) })
                } else {
                    if !context.listItems.isEmpty {
                        // v10 (§1.3.4): the books being read – a tap enters the progress.
                        CurrentlyReadingCard(context: context)
                    }
                    goalGrid(table, excused: excused)
                    if !context.segments.earlier(today: context.today).isEmpty {
                        // v10 (§1.4.3): earlier segments apart, below the current one.
                        EarlierSegmentsCard(context: context)
                    }
                    weightingCard
                }
            }
            .padding()
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
    }

    /// The goal cards – read only, each opens its goal page.
    private func goalGrid(_ table: ResultProgressTable, excused: Set<WeekKey>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
            ForEach(context.goals) { goal in
                NavigationLink {
                    GoalDetailView(goalKey: goal.key)
                } label: {
                    GoalCard(goal: goal, context: context, history: history(for: goal.key, excused: excused),
                             recentAverage: recentAverage(for: goal.key), resultLine: table.cardLine(goal),
                             measureTitles: measureTitles(goal))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// v10 (§1.2.4): "Gewicht · Protein · Schritte" – the goal's measures (this week's, else the latest week's).
    private func measureTitles(_ goal: AnnualGoal) -> [String] {
        if !context.measures.isEmpty { return context.goalMeasures(goal).map(\.title) }
        return GoalResult.measures(of: goal.key, categories: context.data.categories, measures: fallbackMeasures,
                                   results: context.activeResults).map(\.title)
    }

    private func loadFallbackMeasures() {
        guard context.measures.isEmpty else {
            fallbackMeasures = []
            return
        }
        fallbackMeasures = app.store.latestMeasureRecords(through: context.week)
    }

    /// CI screenshots (`-DemoScreen goal-detail` / `reading`): the goal page of the books result, the reading list.
    private func openLaunchScreen() {
        guard app.launch.isDemo, !app.isSandbox, !GoalsLaunch.handled else { return }
        switch app.launch.screen {
        case "goal-detail":
            GoalsLaunch.handled = true
            let books: GoalResult? = context.results.first { ResultSourceType($0.resultSource) == .list }
            launchGoal = books?.goalKey ?? context.results.first?.goalKey ?? context.goals.first?.key
        case "reading":
            GoalsLaunch.handled = true
            showsReadingList = true
        default:
            break
        }
    }

    /// v8: past weeks (last half year – the cards show 12 points) that were all sick or holiday days
    /// (no score on purpose), once per render.
    private var excusedWeeks: Set<WeekKey> {
        guard !plans.isEmpty else { return [] }
        return app.store.excusedWeeks(from: context.week.adding(weeks: -26), through: context.week.adding(weeks: -1), today: app.today)
    }

    /// Closed weeks' scores for one goal, oldest first, plus this week live – one point per week (R11).
    /// v8: a week of only sick or holiday days is a point marked "entschuldigt", not a gap.
    private func history(for goalKey: String, excused: Set<WeekKey>) -> [ScorePoint] {
        guard !plans.isEmpty else { return [] }
        let closed: [WeekScorePoint] = app.store.goalScoreHistory(goalKey: goalKey, through: context.week.adding(weeks: -1))
        var points: [ScorePoint] = closed.map { ScorePoint(week: $0.week, score: $0.score) }
        let scored: Set<WeekKey> = Set(points.map(\.week))
        for week in excused where !scored.contains(week) {
            points.append(ScorePoint(week: week, score: 10, isExcused: true))
        }
        if let live = context.score.goalWeek[goalKey]?.score {
            points.append(ScorePoint(week: context.week, score: live))
        } else if context.score.isExcused {
            points.append(ScorePoint(week: context.week, score: 10, isExcused: true))
        }
        // v10 (§1.4.3): weeks of an earlier segment stay visible, greyed like "vor KW42".
        if context.segments.hasSeveral, let start = context.currentSegment?.startWeek {
            for index in points.indices where points[index].week < start { points[index].isEarlierSegment = true }
        }
        return Array(points.sorted { $0.week < $1.week }.suffix(12))
    }

    /// R93: "Ø 4 Wo." – the mean of the goal's last four closed weeks, while this week has no score yet.
    /// v10 (§1.4.3): the cards count in the current segment – its weeks only, when there are several.
    private func recentAverage(for goalKey: String) -> Double? {
        guard !plans.isEmpty, context.score.goalWeek[goalKey]?.score == nil else { return nil }
        var closed: [WeekScorePoint] = app.store.goalScoreHistory(goalKey: goalKey, through: context.week.adding(weeks: -1))
        if context.segments.hasSeveral, let start = context.currentSegment?.startWeek {
            closed = closed.filter { $0.week >= start }
        }
        let lastFour: [Double] = closed.suffix(4).map(\.score)
        guard !lastFour.isEmpty else { return nil }
        return lastFour.reduce(0, +) / Double(lastFour.count)
    }

    private var yearCard: some View {
        let weekNumber = period.weekNumber(of: context.week)
        let weeksToReview = period.weekNumber(of: period.reviewWeek) - weekNumber
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Woche \(max(1, weekNumber)) von \(period.totalWeeks)")
                    .font(.title3.weight(.bold))
                Spacer()
                Text(verbatim: "\(period.start.day). \(DayKey.monthShort(period.start.month)) \(period.start.year) – \(period.end.day). \(DayKey.monthShort(period.end.month)) \(period.end.year)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                yearMenu
            }
            if context.segments.hasSeveral {
                // v10 (§1.4.3): "Abschnitt 2 · seit KW50 · Woche 3" – the current segment, no head of its own.
                Label(context.segmentHeadline, systemImage: "flag.2.crossed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.accent)
            }
            ProgressView(value: period.progress(on: context.today))
                .tint(Brand.accent)
            if weeksToReview > 0 {
                Label("Zielüberprüfung \(period.reviewWeek.label) (\(period.reviewWeek.rangeLabel)) – in \(weeksToReview) \(weeksToReview == 1 ? "Woche" : "Wochen"). Bis dahin werden Ziele nicht automatisch schwerer.",
                      systemImage: "flag")
                    .font(.subheadline)
            } else if weeksToReview == 0 {
                Label("Diese Woche: Zielüberprüfung zur Halbzeit.", systemImage: "flag.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.accent)
            }
            if (0...3).contains(weeksToReview) {
                // R95: from three weeks before the review week until its end.
                Button {
                    app.sheet = .goalReview
                } label: {
                    Label("Zielüberprüfung vorbereiten", systemImage: "checklist")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentFill)
            }
            Text(period.motto)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
        }
        .card()
    }

    private var weightingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Gleich gewichtet", systemImage: "scalemass")
                .font(.headline)
            Text("Jedes Jahresziel zählt 10 % der Woche – Fit Body mit zwei Kategorien genauso viel wie Schlaf mit einer. Diese Woche: \(context.score.coverageText).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            GoalBars(scores: context.goals.map { context.score.goalWeek[$0.key]?.score }, height: 48,
                     keys: context.goals.map(\.key))
            Button("Wie wird gerechnet?") { app.sheet = .explainer(.scoring) }
                .font(.subheadline)
        }
        .card()
    }

    /// v10: "Neuen Abschnitt beginnen…" (§1.4.2), the capture options for results and reading, the reading
    /// list and the goal settings – from the year card.
    private var yearMenu: some View {
        Menu {
            Button("Jahresziel eintragen…", systemImage: "flag.checkered") { sheet = .entry(app.captureDay) }
            Button("Lesen…", systemImage: "bookmark") { sheet = .reading(app.captureDay) }
            Divider()
            Button("Leseliste", systemImage: "books.vertical") { showsReadingList = true }
            Button("Jahresziele bearbeiten", systemImage: "pencil") { showsGoalSettings = true }
            Divider()
            Button("Neuen Abschnitt beginnen…", systemImage: "flag.2.crossed") { sheet = .segment }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
                .foregroundStyle(Brand.accent)
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Jahresziele – mehr")
    }
}

/// v10: the sheets the Ziele page opens itself.
enum GoalsSheet: Identifiable {
    case segment
    case entry(DayKey)
    case reading(DayKey)

    var id: String {
        switch self {
        case .segment: "segment"
        case .entry(let day): "entry-" + day.string
        case .reading(let day): "reading-" + day.string
        }
    }
}

struct GoalsSheetContent: View {
    let sheet: GoalsSheet

    var body: some View {
        switch sheet {
        case .segment:
            SegmentWizard()
        case .entry(let day):
            GoalEntrySheet(day: day)
        case .reading(let day):
            ReadingProgressSheet(day: day)
        }
    }
}

/// The CI screens of the Ziele page open once per launch.
@MainActor
enum GoalsLaunch {
    static var handled = false
}

/// One annual goal: this week's score, its categories, the last weeks – in the goal's colour (R68).
struct GoalCard: View {
    let goal: AnnualGoal
    let context: WeekContext
    let history: [ScorePoint]
    /// R93: mean of the last four closed weeks, shown while this week is "–".
    var recentAverage: Double? = nil
    /// v10 (§1.2): "Bücher 3/10 · Website ✓" – the goal's results in the current segment.
    var resultLine: String? = nil
    /// v10 (§1.2.4): the goal's measures – up to three chips, "+2".
    var measureTitles: [String] = []

    private var chips: (shown: [String], more: Int) { GoalResult.chips(measureTitles) }

    /// v10 (§1.2.3): "Wochen über 8: 1.1 9/12 · 1.2 7/12" in the current segment.
    private var trackLine: String? { context.goalTrackLine(goal) }

    /// A week without a score yet shows how many categories are scored, with a thin arc (R68).
    private var pending: GoalWeek? {
        guard let week = context.score.goalWeek[goal.key], week.score == nil, week.categoriesTotal > 0 else { return nil }
        return week
    }

    var body: some View {
        let score = context.score.goalWeek[goal.key]
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if let pending {
                    CategoriesArc(scored: pending.categoriesScored, total: pending.categoriesTotal, tint: goal.color, size: 58)
                } else {
                    ScoreRing(score: score?.score, size: 58, lineWidth: 6, tint: goal.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ziel \(goal.key)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(goal.color)
                    Text(goal.title)
                        .font(.headline)
                    Text(goal.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let pending {
                        Text(CategoriesArc.text(scored: pending.categoriesScored, total: pending.categoriesTotal))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    } else if context.isGoalExcused(goal) {
                        // v8: everything planned fell on sick or holiday days.
                        Text("Diese Woche \(WeekScore.excusedLabel) (krank/Urlaub)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                    if let recentAverage {
                        Text("Ø 4 Wo. \(Format.score(recentAverage))")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(goal.color)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            ForEach(context.categories(of: goal)) { category in
                HStack {
                    KeyBadge(key: category.key)
                    Text(category.title)
                        .font(.caption)
                        .lineLimit(1)
                    if context.isGood(category) {
                        // v10 (§1.2.3): this week's score is above 8 (live).
                        GoodWeekBadge()
                    }
                    Spacer()
                    Text(Format.score(context.score.categoryWeek[category.key], outOf: false))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            if let trackLine {
                Text(trackLine)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if let resultLine {
                Label(resultLine, systemImage: "flag.checkered")
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(goal.color)
            }
            if !chips.shown.isEmpty {
                MeasureChips(titles: chips.shown, more: chips.more)
            }
            if history.count > 1 {
                GoalScoreSparkline(points: history, tint: goal.color)
            }
        }
        .card(padding: 14)
        .contentShape(.rect)
    }
}

/// v10 (§1.2.4): "Gewicht · Protein · Schritte" and "+2" – the measures in a goal, read only.
struct MeasureChips: View {
    let titles: [String]
    let more: Int

    var body: some View {
        WrapLayout(spacing: 4) {
            ForEach(titles, id: \.self) { title in
                chip(title)
            }
            if more > 0 {
                chip("+\(more)")
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Messwerte: " + titles.joined(separator: ", "))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.12), in: .capsule)
    }
}

/// R11: a goal's last weeks as a small line. v8: a week of only sick or holiday days is a pale
/// column ("entschuldigt") instead of a gap, as in the review.
struct GoalScoreSparkline: View {
    let points: [ScorePoint]
    let tint: Color

    private var scored: [ScorePoint] { points.filter { !$0.isExcused } }
    private var excused: [ScorePoint] { points.filter(\.isExcused) }
    /// The weeks in order – two series would otherwise put the pale columns at the end.
    private var labels: [String] { points.map(\.label) }

    /// v10: earlier segments' weeks grey, like "vor KW42".
    private func dotTint(_ point: ScorePoint) -> Color {
        point.isEarlierSegment ? Color.secondary : tint
    }

    var body: some View {
        Chart {
            // v10 (§1.2.3): the line at 8 – weeks at or above it have filled points.
            RuleMark(y: .value("Wertung", GoalTrack.threshold))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            ForEach(excused) { point in
                BarMark(x: .value("Woche", point.label), y: .value("Wertung", 10.0))
                    .foregroundStyle(Color.secondary.opacity(0.16))
            }
            ForEach(scored) { point in
                LineMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(tint)
                PointMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                    .symbol {
                        SparkDot(filled: GoalTrack.isGood(point.score), tint: dotTint(point))
                    }
            }
        }
        .chartXScale(domain: labels)
        .chartYScale(domain: 0...10)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { _ in AxisValueLabel().font(.system(size: 8)) }
        }
        .frame(height: 54)
        .accessibilityLabel(spokenText)
    }

    /// "KW45 7,2, KW46 entschuldigt, KW47 6,8".
    private var spokenText: String {
        points.map { point in
            let value: String = point.isExcused ? WeekScore.excusedLabel : Format.score(point.score)
            return "\(point.label) \(value)"
        }.joined(separator: ", ")
    }
}

/// v10: a point of the goal's line – filled at or above 8, a ring below.
struct SparkDot: View {
    let filled: Bool
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(filled ? tint : Color.clear)
            Circle()
                .strokeBorder(tint, lineWidth: 1.2)
        }
        .frame(width: 5, height: 5)
    }
}

/// A goal in detail: intent, categories with this week's items, related measurements.
struct GoalDetailView: View {
    let goalKey: String
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            if let goal = context.goals.first(where: { $0.key == goalKey }) {
                GoalDetailContent(goal: goal, context: context)
            } else {
                ContentUnavailableView("Ziel nicht gefunden", systemImage: "target")
            }
        }
    }
}

struct GoalDetailContent: View {
    let goal: AnnualGoal
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var editing = false
    @State private var title = ""
    @State private var details = ""
    @State private var range: HistoryRange = .twelveWeeks
    /// v10: the result editor and "Eintrag mit Datum…".
    @State private var resultSheet: ResultSheet?
    /// v10 (§1.2.4): the latest week's measures when this week has none.
    @State private var fallbackMeasures: [MeasureRecord] = []
    /// v10 (§1.4.3): the goal in each earlier segment.
    @State private var earlier: [SegmentPageData.GoalHistoryLine] = []

    /// v10 (§1.2.4): this week's measures of the goal – those of its categories, then those feeding one of
    /// its results.
    private var goalMeasures: [MeasureDefinition] {
        let codes: [String] = context.goalMeasures(goal).map(\.code)
        return codes.compactMap { code in context.measures.first { $0.code == code } }
    }

    var body: some View {
        let categories: [TrackCategory] = context.categories(of: goal)
        let measures: [MeasureDefinition] = goalMeasures
        ResultSeriesReader(results: context.results(of: goal), context: context) { table in
            List {
                headerSection
                // v10 (§1.2.6): results with anlegen, abhaken, +1, Wert and their dated entries.
                GoalResultsSection(goal: goal, context: context, table: table) { sheet in resultSheet = sheet }
                weeksAboveEightSection(categories)
                measuresSection(measures, table: table)
                historySection(measures)
                ForEach(categories) { category in
                    categorySection(category)
                }
                if !earlier.isEmpty {
                    earlierSection
                }
            }
        }
        .task(id: context.measures.isEmpty) {
            fallbackMeasures = context.measures.isEmpty ? app.store.latestMeasureRecords(through: context.week) : []
        }
        .task(id: earlierKey) {
            earlier = SegmentPageData.goalHistory(goal.key, context: context, store: app.store)
        }
        .sheet(item: $resultSheet) { sheet in
            ResultSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
        .navigationTitle("\(goal.key) \(goal.title)")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") {
                    title = goal.title
                    details = goal.details
                    editing = true
                }
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    TextField("Titel", text: $title)
                    TextField("Absicht und Ergebnisziel", text: $details, axis: .vertical)
                        .lineLimit(3...10)
                }
                .formStyle(.grouped)
                .navigationTitle("Jahresziel \(goal.key)")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Sichern") {
                            app.store.update(goal, title: title, details: details)
                            editing = false
                        }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .thaliaSheetFrame(width: 460, height: 320)
            .unsavedInput(title != goal.title || details != goal.details, in: app)
            .environment(app)
            .toastHost(app)
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                ScoreRing(score: context.score.goalWeek[goal.key]?.score, size: 76, caption: context.week.label, tint: goal.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.details.isEmpty ? "Keine Beschreibung" : goal.details)
                        .font(.subheadline)
                    Text("Die Wertung misst Verhalten, nicht das Jahresergebnis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if context.goalIsGood(goal) == true {
                        Label("Diese Woche gut dabei – jede Kategorie über 8", systemImage: "checkmark.seal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("MarkDoneText"))
                    }
                }
            }
            if context.segments.hasSeveral {
                Label(context.segmentHeadline, systemImage: "flag.2.crossed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// This week's measures with "zählt für"; without any, the latest week's names.
    @ViewBuilder
    private func measuresSection(_ measures: [MeasureDefinition], table: ResultProgressTable) -> some View {
        if !measures.isEmpty {
            Section("Messwerte diese Woche") {
                ForEach(measures) { measure in
                    measureRow(measure, table: table)
                }
            }
        } else if !fallbackMeasures.isEmpty {
            Section {
                ForEach(fallbackMeasures, id: \.code) { record in
                    Text(record.title)
                }
            } header: {
                Text("Messwerte")
            } footer: {
                Text("Diese Woche hat noch keine Messwerte – die Liste stammt aus der letzten Woche mit Plan.")
            }
        }
    }

    private func historySection(_ measures: [MeasureDefinition]) -> some View {
        Section {
            Picker("Zeitraum", selection: $range) {
                ForEach(HistoryRange.choices(hasSegments: context.segments.hasSeveral)) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            GoalHistoryCharts(goal: goal, measures: measures, range: range, context: context)
        } header: {
            Text("Verlauf")
        }
    }

    /// "Punkte dieser Woche" of one category, Mo–So.
    private func categorySection(_ category: TrackCategory) -> some View {
        let items: [PlanItem] = context.items(in: category)
        return Section {
            if !items.isEmpty {
                weekdayHeader
            }
            ForEach(items) { item in
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 2) {
                        ForEach(context.week.days, id: \.self) { day in
                            markCell(item, day: day)
                        }
                    }
                }
                .contentShape(.rect)
                .onTapGesture { app.sheet = .item(item, context.today) }
            }
        } header: {
            HStack {
                KeyBadge(key: category.key)
                Text(category.title)
                if context.isGood(category) {
                    GoodWeekBadge()
                }
                Spacer()
                Text(Format.score(context.score.categoryWeek[category.key], outOf: false)).monospacedDigit()
            }
        }
    }

    // MARK: v10 – weeks above 8, measures, earlier segments

    /// "Wochen über 8" (§1.2.3): per category this week's badge and its tally in the current segment.
    private func weeksAboveEightSection(_ categories: [TrackCategory]) -> some View {
        Section {
            ForEach(categories) { category in
                HStack(spacing: 8) {
                    KeyBadge(key: category.key)
                    Text(category.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    if context.isGood(category) {
                        GoodWeekBadge()
                    }
                    Spacer(minLength: 4)
                    Text(GoalDetailContent.tallyText(context.tally(category)))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
        } header: {
            Text("Wochen über 8")
        } footer: {
            Text(weeksFooter)
        }
    }

    /// "9/12" – weeks above 8 of the scored ones; "–" without any.
    static func tallyText(_ tally: GoalTrack.Tally?) -> String {
        guard let tally else { return "–" }
        return "\(tally.good)/\(tally.scored)"
    }

    private var weeksFooter: String {
        let scope: String = context.segments.hasSeveral ? "in \(context.currentSegment?.title ?? "diesem Abschnitt")" : "im Zieljahr"
        return "Die letzten \(GoalTrack.recentWeeks) abgeschlossenen Wochen \(scope): eine Kategorie ist gut dabei ab einer Note von 8,00. Entschuldigte Wochen zählen nicht."
    }

    /// A measure with its week value and, below, the results it feeds ("zählt für Ziel 5 · Bücher 3/10").
    private func measureRow(_ measure: MeasureDefinition, table: ResultProgressTable) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            LabeledContent(measure.title) {
                Text(GoalDetailContent.weekValueText(measure, context: context))
                    .monospacedDigit()
            }
            ForEach(table.countsFor(measure), id: \.self) { line in
                Label(line, systemImage: "flag.checkered")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Ø 86,4 kg · Ziel ≤ 85", "12 Seiten" (a sum), "–" (§1.2.4: week value and target).
    static func weekValueText(_ measure: MeasureDefinition, context: WeekContext) -> String {
        let target: String = measure.record?.target.map { " · Ziel \($0.label)" } ?? ""
        guard let value = context.weekValue(measure) else { return "–" + target }
        let prefix: String = measure.record?.aggregation == .sum ? "" : "Ø "
        return prefix + Format.measure(value, unit: measure.unit) + target
    }

    /// "Frühere Abschnitte" (§1.4.3): the goal in each earlier segment – greyed, never hidden.
    private var earlierSection: some View {
        Section {
            ForEach(earlier) { line in
                NavigationLink {
                    SegmentPage(spanID: line.span.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(GoalDetailContent.earlierTitle(line, goal: goal))
                            .font(.subheadline.weight(.semibold))
                        Text(line.line)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Frühere Abschnitte")
        }
    }

    /// "Abschnitt 1 · KW45–KW49", with the goal's title then when it was different.
    static func earlierTitle(_ line: SegmentPageData.GoalHistoryLine, goal: AnnualGoal) -> String {
        let base: String = "\(line.span.title) · \(line.span.weeksLabel)"
        guard !line.title.isEmpty, line.title != goal.title else { return base }
        return base + " · damals „\(line.title)“"
    }

    private var earlierKey: String {
        let spans: String = context.segments.spans.map(\.id).joined(separator: ",")
        return "\(spans)|\(context.today.string)|\(context.storedCategoryWeeks.count)"
    }

    // MARK: Days (R69)

    /// "M D M D F S S" above the marks, today highlighted.
    private var weekdayHeader: some View {
        HStack {
            Spacer()
            HStack(spacing: 2) {
                ForEach(context.week.days, id: \.self) { day in
                    Text(day.weekday.letter)
                        .font(.system(.caption2, design: .rounded).weight(day == context.today ? .heavy : .semibold))
                        .foregroundStyle(day == context.today ? goal.color : Color.secondary)
                        .frame(width: 13)
                        .background(todayBackground(day), in: .rect(cornerRadius: 3))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func markCell(_ item: PlanItem, day: DayKey) -> some View {
        let mark: Mark? = context.mark(item, on: day)
        return Text(cellSymbol(mark, item: item, day: day))
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(mark.textColor)
            .frame(width: 13)
            .background(todayBackground(day), in: .rect(cornerRadius: 3))
            .accessibilityLabel(cellDescription(mark, item: item, day: day))
    }

    private func cellSymbol(_ mark: Mark?, item: PlanItem, day: DayKey) -> String {
        if let mark { return mark.symbol }
        return item.days.contains(day.weekday) ? "·" : " "
    }

    /// "Mittwoch: Erledigt" · "Mittwoch: nicht erfasst" · "Mittwoch: nicht fällig".
    /// v8: "Freitag: Krank, zählt nicht".
    private func cellDescription(_ mark: Mark?, item: PlanItem, day: DayKey) -> String {
        if context.isExcused(day) { return "\(day.weekday.name): \(context.excusedName(day)), zählt nicht" }
        let state: String
        if let mark {
            state = mark.label(progress: item.schedule == .progress)
        } else if context.applies(item, on: day) {
            state = "nicht erfasst"
        } else {
            state = "nicht fällig"
        }
        return "\(day.weekday.name): \(state)"
    }

    /// Today in the goal's colour; v8: sick and holiday days grey (they don't count).
    private func todayBackground(_ day: DayKey) -> Color {
        if day == context.today { return goal.color.opacity(0.14) }
        return context.isExcused(day) ? Color.secondary.opacity(0.14) : Color.clear
    }
}

// MARK: Goal review (R95)

/// R95: "Zielüberprüfung vorbereiten" – the goal year so far per goal, the most missed items,
/// power-hours per area, measurements then and now, the parked ideas – and a report for ChatGPT.
struct GoalReviewView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var report: PeriodReport?
    @State private var copied = false
    /// v10 (§1.4.3): the review covers the current segment or the whole goal year.
    @State private var scope: GoalReviewScope?
    @State private var segments: Segments?
    /// v10 (§1.2.5): the results of the current segment (no Health values).
    @State private var results: [GoalResultLine] = []
    @State private var showsSegmentWizard = false

    init() {}

    private var period: GoalPeriod { app.store.goalPeriod }

    /// The current segment while the review covers it; nil for the goal year.
    private var segment: SegmentSpan? {
        guard scope == .segment, let segments, segments.hasSeveral else { return nil }
        return segments.current(today: app.today)
    }

    private var scopeBinding: Binding<GoalReviewScope> {
        Binding(get: { scope ?? .goalYear }, set: { scope = $0 })
    }

    var body: some View {
        NavigationStack {
            Group {
                if let report {
                    content(report)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Zielüberprüfung \(period.reviewWeek.label)")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: copyReport) {
                        Label(copied ? "Kopiert" : "Bericht kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .disabled(report == nil)
                }
            }
            .task(id: scope) { load() }
        }
        .sheet(isPresented: $showsSegmentWizard) {
            SegmentWizard()
                .thaliaLocalSheet(app)
        }
        .thaliaSheetFrame(width: 620, height: 760)
    }

    /// The first look picks the current segment when the goal year has several (the focus), else the year.
    private func load() {
        let store: TrackerStore = app.store
        if segments == nil { segments = store.segments() }
        if scope == nil {
            scope = (segments?.hasSeveral ?? false) ? .segment : .goalYear
            return
        }
        report = store.periodReport(period: period, through: app.today.week, from: segment?.startWeek)
        results = store.resultLines(today: app.today)
        copied = false
    }

    private func copyReport() {
        guard let report else { return }
        Clipboard.copy(report.markdown(period: period, segment: segment, results: results))
        copied = true
    }

    private func content(_ report: PeriodReport) -> some View {
        Form {
            scopeSection
            Section {
                Text(spanText(report))
                    .font(.subheadline)
                if !period.motto.isEmpty {
                    Text(period.motto)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Die Wertungen messen Verhalten, nicht Ergebnisse. „Bericht kopieren“ nimmt alles mit – für das Gespräch zur Zielüberprüfung.")
            }

            resultsSection

            Section {
                if report.goals.isEmpty {
                    Text("Noch keine geplanten Wochen im Zieljahr.")
                        .foregroundStyle(.secondary)
                }
                ForEach(report.goals, id: \.key) { line in
                    goalRow(line)
                }
            } header: {
                Text("Jahresziele · Ø seit Start und Trend")
            }

            if !report.missed.isEmpty {
                Section {
                    ForEach(report.missed, id: \.title) { item in
                        HStack(spacing: 8) {
                            KeyBadge(key: item.categoryKey)
                            Text(item.title)
                                .lineLimit(2)
                            Spacer(minLength: 6)
                            Text("\(item.count)×")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Am häufigsten verpasst")
                }
            }

            if !report.work.isEmpty {
                Section {
                    ForEach(report.work, id: \.categoryKey) { line in
                        HStack(spacing: 8) {
                            KeyBadge(key: line.categoryKey)
                            Text(line.title)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(Format.powerHours(line.powerHours))
                                .monospacedDigit()
                                .fontWeight(.semibold)
                        }
                    }
                } header: {
                    Text("Power-Hours je Bereich")
                }
            }

            if !report.measures.isEmpty {
                Section {
                    ForEach(report.measures, id: \.code) { change in
                        LabeledContent(change.title) {
                            Text(GoalReviewView.changeText(change))
                                .monospacedDigit()
                        }
                    }
                } header: {
                    Text("Messwerte · Anfang → jetzt")
                }
            }

            Section {
                if report.ideas.isEmpty {
                    Text("Noch keine geparkten Ideen.")
                        .foregroundStyle(.secondary)
                }
                ForEach(report.ideas, id: \.id) { idea in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(idea.day.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(idea.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: {
                Text("Geparkte Ideen")
            }

            // v10 (§1.4.2): after the review, the goals for the next segment.
            segmentStartSection
        }
        .formStyle(.grouped)
    }

    /// v10 (§1.4.3): "Abschnitt 2 · Zieljahr" when the goal year has several segments.
    @ViewBuilder
    private var scopeSection: some View {
        if let segments, segments.hasSeveral {
            Section {
                Picker("Zeitraum", selection: scopeBinding) {
                    ForEach(GoalReviewScope.allCases) { choice in
                        Text(choice.title(segments.current(today: app.today))).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    /// v10 (§1.2.5): the results with their state (no Health values).
    @ViewBuilder
    private var resultsSection: some View {
        if !results.isEmpty {
            Section {
                ForEach(results, id: \.markdown) { line in
                    GoalReviewView.resultRow(line)
                }
            } header: {
                Text("Ergebnisse")
            }
        }
    }

    static func resultRow(_ line: GoalResultLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(line.goalKey) · \(line.title)")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 6)
                Text(line.status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(line.text)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    private var segmentStartSection: some View {
        Section {
            Button {
                showsSegmentWizard = true
            } label: {
                Label("Neuen Abschnitt beginnen…", systemImage: "flag.2.crossed")
            }
        } footer: {
            Text("Ziele aktualisieren und für den nächsten Abschnitt neu festlegen – was bisher geleistet wurde, bleibt erhalten.")
        }
    }

    /// "Zieljahr seit Montag, 2. November 2026 · ausgewertet KW45 bis KW47"; v10: "Abschnitt 2 seit KW50 · …".
    private func spanText(_ report: PeriodReport) -> String {
        let base: String = segment.map { "\($0.title) seit \($0.startWeek.longLabel)" } ?? "Zieljahr seit \(period.start.longLabel)"
        guard !report.goals.isEmpty || !report.work.isEmpty else { return base }
        return "\(base) · ausgewertet \(report.start.label) bis \(report.end.label)"
    }

    private func goalRow(_ line: PeriodReport.GoalLine) -> some View {
        let color: Color = GoalPalette.color(goal: line.key)
        return HStack(spacing: 10) {
            Text(line.key)
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .lineLimit(1)
                Text(GoalReviewView.trendText(line))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 6)
            Text(Format.score(line.average, outOf: false))
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(color)
            Image(systemName: GoalReviewView.trendSymbol(line))
                .foregroundStyle(.secondary)
                .accessibilityLabel(GoalReviewView.trendWord(line))
        }
    }

    /// The same rule as the report: last four against first four weeks, ± 0,25.
    static func trend(_ line: PeriodReport.GoalLine) -> Int? {
        guard let first = line.firstFour, let last = line.lastFour else { return nil }
        if last - first > 0.25 { return 1 }
        if first - last > 0.25 { return -1 }
        return 0
    }

    static func trendSymbol(_ line: PeriodReport.GoalLine) -> String {
        switch trend(line) {
        case .some(1): return "arrow.up.right"
        case .some(-1): return "arrow.down.right"
        case .some: return "arrow.right"
        case .none: return "minus"
        }
    }

    static func trendWord(_ line: PeriodReport.GoalLine) -> String {
        switch trend(line) {
        case .some(1): return "steigend"
        case .some(-1): return "fallend"
        case .some: return "gleichbleibend"
        case .none: return "noch kein Trend"
        }
    }

    /// "erste 4 Wo. 6,8 → letzte 4 Wo. 7,5".
    static func trendText(_ line: PeriodReport.GoalLine) -> String {
        guard let first = line.firstFour, let last = line.lastFour else { return "noch keine abgeschlossene Woche" }
        return "erste 4 Wo. \(Format.score(first)) → letzte 4 Wo. \(Format.score(last))"
    }

    /// "12 Seiten → 15 Seiten", "–" for a missing end.
    static func changeText(_ change: PeriodReport.MeasureChange) -> String {
        let first: String = change.first.map { Format.measure($0, unit: change.unit) } ?? "–"
        let last: String = change.last.map { Format.measure($0, unit: change.unit) } ?? "–"
        return "\(first) → \(last)"
    }
}

/// v10 (§1.4.3): "Abschnitt 2" or "Zieljahr" in the goal review.
enum GoalReviewScope: String, CaseIterable, Identifiable {
    case segment, goalYear

    var id: String { rawValue }

    func title(_ current: SegmentSpan?) -> String {
        switch self {
        case .segment: current?.title ?? "Abschnitt"
        case .goalYear: "Zieljahr"
        }
    }
}

// MARK: History (R93)

/// "12 Wochen · Halbjahr · Abschnitt · Zieljahr".
enum HistoryRange: String, CaseIterable, Identifiable {
    case twelveWeeks, halfYear, segment, goalYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twelveWeeks: "12 Wochen"
        case .halfYear: "Halbjahr"
        case .segment: "Abschnitt"
        case .goalYear: "Zieljahr"
        }
    }

    /// v10 (§1.4.3): "Abschnitt" only when the goal year has more than one.
    static func choices(hasSegments: Bool) -> [HistoryRange] {
        hasSegments ? allCases : allCases.filter { $0 != .segment }
    }

    /// The first week shown, up to `week`; `segment` is the current one (v10).
    func firstWeek(through week: WeekKey, period: GoalPeriod, segment: SegmentSpan? = nil) -> WeekKey {
        switch self {
        case .twelveWeeks:
            return week.adding(weeks: -11)
        case .halfYear:
            return week.adding(weeks: -25)
        case .segment:
            let start: WeekKey = segment?.startWeek ?? period.start.week
            return start < week ? start : week
        case .goalYear:
            let start: WeekKey = period.start.week
            return start < week ? start : week
        }
    }
}

/// v10 (§1.4.3): a segment's start in a chart – a line with its name.
struct SegmentBoundary: Identifiable {
    let date: Date
    let title: String
    var id: String { title + "|" + String(date.timeIntervalSince1970) }

    /// The starts of the segments after the first one, from `first` through `last`.
    static func boundaries(_ segments: Segments, from first: WeekKey, through last: WeekKey) -> [SegmentBoundary] {
        segments.spans.dropFirst().filter { $0.startWeek > first && $0.startWeek <= last }.map { span in
            SegmentBoundary(date: span.startWeek.monday.date(minutes: 0), title: span.title)
        }
    }
}

/// One value in a history chart.
struct HistoryValue: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// One measurement over the range: day or week values as a line, spending as monthly bars.
struct MeasureHistory: Identifiable {
    let code: String
    let title: String
    let unit: String
    let period: TargetPeriod
    let isTime: Bool
    let isMonthly: Bool
    /// Drawn dashed where it fits the values (not on monthly spending).
    let target: Target?
    let values: [HistoryValue]
    var id: String { code }
}

/// R93: the goal's weekly score and each of its measurements over the chosen range.
struct GoalHistoryCharts: View {
    let goal: AnnualGoal
    let measures: [MeasureDefinition]
    let range: HistoryRange
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var scores: [HistoryValue] = []
    /// v8: weeks of only sick or holiday days – a pale column ("entschuldigt") instead of a gap.
    @State private var excusedScores: [HistoryValue] = []
    @State private var histories: [MeasureHistory] = []
    /// v10 (§1.4.3): the starts of later segments in the range – a line with the segment's name.
    @State private var boundaries: [SegmentBoundary] = []
    @State private var loaded = false

    private var loadKey: String {
        "\(range.rawValue)|\(context.week.string)|\(measures.map(\.code).joined(separator: ","))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            scoreChart
            ForEach(histories) { history in
                measureChart(history)
            }
        }
        .padding(.vertical, 6)
        .task(id: loadKey) { load() }
    }

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Wochenwertung")
                .font(.subheadline.weight(.semibold))
            if scores.isEmpty && excusedScores.isEmpty {
                Text(loaded ? "Noch keine abgeschlossene Woche in diesem Zeitraum." : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    ForEach(excusedScores) { point in
                        BarMark(x: .value("Woche", point.date, unit: .weekOfYear), y: .value("Wertung", point.value))
                            .foregroundStyle(Color.secondary.opacity(0.16))
                    }
                    ForEach(scores) { point in
                        LineMark(x: .value("Woche", point.date), y: .value("Wertung", point.value))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(goal.color)
                        PointMark(x: .value("Woche", point.date), y: .value("Wertung", point.value))
                            .symbolSize(16)
                            .foregroundStyle(goal.color)
                    }
                    ForEach(boundaries) { boundary in
                        RuleMark(x: .value("Woche", boundary.date))
                            .foregroundStyle(Color.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .annotation(position: .top, alignment: .leading) {
                                Text(boundary.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .chartYScale(domain: 0...10)
                .frame(height: 120)
                .accessibilityLabel("Wochenwertung von Ziel \(goal.key)")
                if !excusedScores.isEmpty {
                    Label(excusedLegend, systemImage: "cross.case")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// v8: "Grau = entschuldigt (krank/Urlaub): 2 Wochen".
    private var excusedLegend: String {
        let count: Int = excusedScores.count
        let weeks: String = count == 1 ? "1 Woche" : "\(count) Wochen"
        return "Grau = \(WeekScore.excusedLabel) (krank/Urlaub): \(weeks)"
    }

    private func measureChart(_ history: MeasureHistory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(history.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(GoalHistoryCharts.caption(history))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if history.values.isEmpty {
                Text("Keine Werte in diesem Zeitraum.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if history.isMonthly {
                Chart(history.values) { point in
                    BarMark(x: .value("Monat", point.date, unit: .month), y: .value("Betrag", point.value))
                        .foregroundStyle(goal.color)
                }
                .frame(height: 120)
            } else {
                Chart {
                    ForEach(history.values) { point in
                        LineMark(x: .value("Tag", point.date), y: .value("Wert", point.value))
                            .foregroundStyle(goal.color)
                        PointMark(x: .value("Tag", point.date), y: .value("Wert", point.value))
                            .symbolSize(10)
                            .foregroundStyle(goal.color)
                    }
                    ForEach(GoalHistoryCharts.targetLines(history), id: \.self) { line in
                        RuleMark(y: .value("Ziel", line))
                            .foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(GoalHistoryCharts.axisLabel(number, isTime: history.isTime))
                            }
                        }
                    }
                }
                .frame(height: 120)
            }
        }
    }

    private func load() {
        let period: GoalPeriod = app.store.goalPeriod
        let first: WeekKey = range.firstWeek(through: context.week, period: period, segment: context.currentSegment)
        boundaries = SegmentBoundary.boundaries(context.segments, from: first, through: context.week)
        scores = app.store.goalScoreHistory(goalKey: goal.key, through: context.week)
            .filter { $0.week >= first }
            .map { HistoryValue(date: $0.week.monday.date(minutes: 720), value: $0.score) }
        let scored: Set<Date> = Set(scores.map(\.date))
        excusedScores = app.store.excusedWeeks(from: first, through: context.week, today: context.today)
            .sorted()
            .map { HistoryValue(date: $0.monday.date(minutes: 720), value: 10) }
            .filter { !scored.contains($0.date) }
        let start: DayKey = first.monday
        let end: DayKey = context.today
        histories = measures.compactMap { measure -> MeasureHistory? in
            guard let record = measure.record, !record.isText else { return nil }
            let series: [SeriesPoint] = app.store.measureSeries(code: measure.code, from: start, through: end)
            return GoalHistoryCharts.history(record, series: series)
        }
        loaded = true
    }

    /// "Summe je Monat" · "Erfüllt bei ≤ 23:00 pro Tag" · the unit.
    static func caption(_ history: MeasureHistory) -> String {
        if history.isMonthly { return "Summe je Monat" }
        if let target = history.target { return target.sentence(period: history.period, unit: history.unit) }
        return Units.display(history.unit)
    }

    /// The dashed target line(s): one value, or both ends of a range.
    static func targetLines(_ history: MeasureHistory) -> [Double] {
        guard let target = history.target, !history.isMonthly else { return [] }
        if target.comparison == .range { return [target.value, target.upper ?? target.value] }
        return [target.value]
    }

    static func axisLabel(_ value: Double, isTime: Bool) -> String {
        isTime ? Format.clock(value) : Format.number(value, decimals: 1)
    }

    /// Day values as they are; week targets on week values; spending summed per month.
    static func history(_ record: MeasureRecord, series: [SeriesPoint]) -> MeasureHistory {
        if record.isExpense {
            var months: [String: HistoryValue] = [:]
            for point in series {
                let monthStart: DayKey = point.day.adding(days: 1 - point.day.day)
                let total: Double = (months[monthStart.string]?.value ?? 0) + point.value
                months[monthStart.string] = HistoryValue(date: monthStart.date(minutes: 720), value: total)
            }
            let values: [HistoryValue] = months.values.sorted { $0.date < $1.date }
            return MeasureHistory(code: record.code, title: record.title, unit: record.unit, period: record.period,
                                  isTime: false, isMonthly: true, target: nil, values: values)
        }
        let reference: Double = record.target?.value ?? 1380
        let isTime: Bool = record.isTime
        func shown(_ value: Double) -> Double {
            isTime ? Target.normalizedTime(value, reference: reference) : value
        }
        var values: [HistoryValue] = []
        if record.period == .week {
            var weeks: [String: (date: Date, values: [Double])] = [:]
            for point in series {
                let monday: DayKey = point.day.week.monday
                var group = weeks[monday.string] ?? (date: monday.date(minutes: 720), values: [])
                group.values.append(shown(point.value))
                weeks[monday.string] = group
            }
            values = weeks.values.sorted { $0.date < $1.date }.compactMap { group -> HistoryValue? in
                guard let combined = combine(group.values, record.aggregation) else { return nil }
                return HistoryValue(date: group.date, value: combined)
            }
        } else {
            values = series.map { HistoryValue(date: $0.day.date(minutes: 720), value: shown($0.value)) }
        }
        return MeasureHistory(code: record.code, title: record.title, unit: record.unit, period: record.period,
                              isTime: isTime, isMonthly: false, target: record.target, values: values)
    }

    static func combine(_ values: [Double], _ aggregation: Aggregation) -> Double? {
        guard !values.isEmpty else { return nil }
        switch aggregation {
        case .sum: return values.reduce(0, +)
        case .last: return values.last
        case .average: return values.reduce(0, +) / Double(values.count)
        case .maximum: return values.max()
        case .minimum: return values.min()
        }
    }
}

/// R68: a thin arc for a goal whose week isn't scored yet – how many of its categories are.
struct CategoriesArc: View {
    let scored: Int
    let total: Int
    let tint: Color
    var size: CGFloat = 58

    /// "1 von 4 Kategorien bewertet".
    static func text(scored: Int, total: Int) -> String {
        "\(scored) von \(total) \(total == 1 ? "Kategorie" : "Kategorien") bewertet"
    }

    private var fraction: CGFloat {
        total > 0 ? CGFloat(scored) / CGFloat(total) : 0
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: 2)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(scored)/\(total)")
                .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(2)
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CategoriesArc.text(scored: scored, total: total))
    }
}

/// One week's score in a chart.
struct ScorePoint: Identifiable {
    let week: WeekKey
    let score: Double
    var isOld = false
    var isLive = false
    /// R70: a past week that was never closed (its running score).
    var isUnclosed = false
    /// v8: a week that was all sick or holiday days – no score on purpose ("entschuldigt", not a gap).
    var isExcused = false
    /// v10 (§1.4.3): a week before the current segment – shown greyed, not hidden.
    var isEarlierSegment = false
    var id: String { week.string }
    var label: String { week.label }

    /// The chart series in the review.
    var series: String {
        if isExcused { return WeekScore.excusedLabel }
        if isUnclosed { return "nicht abgeschlossen" }
        if isOld { return "vor KW42" }
        return isLive ? "laufend" : "gleich gewichtet"
    }
}

extension DayKey {
    static func monthShort(_ month: Int) -> String {
        ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."][max(0, min(11, month - 1))]
    }
}
