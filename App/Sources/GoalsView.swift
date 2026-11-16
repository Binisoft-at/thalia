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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                yearCard
                if context.goals.isEmpty {
                    EmptyStateView(title: "Noch keine Jahresziele",
                                   message: "Richte deine zehn Jahresziele und 18 Kategorien aus der Übergabe ein – oder importiere sie mit dem Wochenplan.",
                                   symbol: "target", createTitle: "Meine Struktur einrichten",
                                   onCreate: { app.store.seedStructure() }, onImport: { app.sheet = .importPlan(prompt: true) })
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                        ForEach(context.goals) { goal in
                            NavigationLink {
                                GoalDetailView(goalKey: goal.key)
                            } label: {
                                GoalCard(goal: goal, context: context, history: history(for: goal.key),
                                         recentAverage: recentAverage(for: goal.key))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    weightingCard
                }
            }
            .padding()
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .background(Color.groupedBackground)
    }

    /// Closed weeks' scores for one goal, oldest first, plus this week live – one point per week (R11).
    private func history(for goalKey: String) -> [ScorePoint] {
        guard !plans.isEmpty else { return [] }
        let closed: [WeekScorePoint] = app.store.goalScoreHistory(goalKey: goalKey, through: context.week.adding(weeks: -1))
        var points: [ScorePoint] = closed.map { ScorePoint(week: $0.week, score: $0.score) }
        if let live = context.score.goalWeek[goalKey]?.score { points.append(ScorePoint(week: context.week, score: live)) }
        return Array(points.suffix(12))
    }

    /// R93: "Ø 4 Wo." – the mean of the goal's last four closed weeks, while this week has no score yet.
    private func recentAverage(for goalKey: String) -> Double? {
        guard !plans.isEmpty, context.score.goalWeek[goalKey]?.score == nil else { return nil }
        let closed: [WeekScorePoint] = app.store.goalScoreHistory(goalKey: goalKey, through: context.week.adding(weeks: -1))
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
}

/// One annual goal: this week's score, its categories, the last weeks – in the goal's colour (R68).
struct GoalCard: View {
    let goal: AnnualGoal
    let context: WeekContext
    let history: [ScorePoint]
    /// R93: mean of the last four closed weeks, shown while this week is "–".
    var recentAverage: Double? = nil

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
                    Spacer()
                    Text(Format.score(context.score.categoryWeek[category.key], outOf: false))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            if history.count > 1 {
                Chart(history) { point in
                    LineMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(goal.color)
                    PointMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                        .symbolSize(18)
                        .foregroundStyle(goal.color)
                }
                .chartYScale(domain: 0...10)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.system(size: 8)) }
                }
                .frame(height: 54)
            }
        }
        .card(padding: 14)
        .contentShape(.rect)
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

    var body: some View {
        let categories = context.categories(of: goal)
        let categoryKeys = Set(categories.map(\.key))
        let measures = context.measures.filter { categoryKeys.contains($0.categoryKey) }
        List {
            Section {
                HStack(spacing: 16) {
                    ScoreRing(score: context.score.goalWeek[goal.key]?.score, size: 76, caption: context.week.label, tint: goal.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.details.isEmpty ? "Keine Beschreibung" : goal.details)
                            .font(.subheadline)
                        Text("Die Wertung misst Verhalten, nicht das Jahresergebnis.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if !measures.isEmpty {
                Section("Messwerte diese Woche") {
                    ForEach(measures) { measure in
                        LabeledContent(measure.title) {
                            Text(context.weekValue(measure).map { value in
                                (measure.record?.aggregation == .sum ? "" : "Ø ") + Format.measure(value, unit: measure.unit)
                            } ?? "–")
                            .monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Picker("Zeitraum", selection: $range) {
                    ForEach(HistoryRange.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                GoalHistoryCharts(goal: goal, measures: measures, range: range, context: context)
            } header: {
                Text("Verlauf")
            }
            ForEach(categories) { category in
                let items: [PlanItem] = context.items(in: category)
                Section {
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
                        Spacer()
                        Text(Format.score(context.score.categoryWeek[category.key], outOf: false)).monospacedDigit()
                    }
                }
            }
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
    private func cellDescription(_ mark: Mark?, item: PlanItem, day: DayKey) -> String {
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

    private func todayBackground(_ day: DayKey) -> Color {
        day == context.today ? goal.color.opacity(0.14) : Color.clear
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

    init() {}

    private var period: GoalPeriod { app.store.goalPeriod }

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
            .task {
                guard report == nil else { return }
                report = app.store.periodReport(period: period, through: app.today.week)
            }
        }
        .thaliaSheetFrame(width: 620, height: 760)
    }

    private func copyReport() {
        guard let report else { return }
        Clipboard.copy(report.markdown(period: period))
        copied = true
    }

    private func content(_ report: PeriodReport) -> some View {
        Form {
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
        }
        .formStyle(.grouped)
    }

    /// "Zieljahr seit Montag, 2. November 2026 · ausgewertet KW45 bis KW47".
    private func spanText(_ report: PeriodReport) -> String {
        guard !report.goals.isEmpty || !report.work.isEmpty else { return "Zieljahr seit \(period.start.longLabel)" }
        return "Zieljahr seit \(period.start.longLabel) · ausgewertet \(report.start.label) bis \(report.end.label)"
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

// MARK: History (R93)

/// "12 Wochen · Halbjahr · Zieljahr".
enum HistoryRange: String, CaseIterable, Identifiable {
    case twelveWeeks, halfYear, goalYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .twelveWeeks: "12 Wochen"
        case .halfYear: "Halbjahr"
        case .goalYear: "Zieljahr"
        }
    }

    /// The first week shown, up to `week`.
    func firstWeek(through week: WeekKey, period: GoalPeriod) -> WeekKey {
        switch self {
        case .twelveWeeks:
            return week.adding(weeks: -11)
        case .halfYear:
            return week.adding(weeks: -25)
        case .goalYear:
            let start: WeekKey = period.start.week
            return start < week ? start : week
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
    @State private var histories: [MeasureHistory] = []
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
            if scores.isEmpty {
                Text(loaded ? "Noch keine abgeschlossene Woche in diesem Zeitraum." : "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(scores) { point in
                    LineMark(x: .value("Woche", point.date), y: .value("Wertung", point.value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(goal.color)
                    PointMark(x: .value("Woche", point.date), y: .value("Wertung", point.value))
                        .symbolSize(16)
                        .foregroundStyle(goal.color)
                }
                .chartYScale(domain: 0...10)
                .frame(height: 120)
                .accessibilityLabel("Wochenwertung von Ziel \(goal.key)")
            }
        }
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
        let first: WeekKey = range.firstWeek(through: context.week, period: period)
        scores = app.store.goalScoreHistory(goalKey: goal.key, through: context.week)
            .filter { $0.week >= first }
            .map { HistoryValue(date: $0.week.monday.date(minutes: 720), value: $0.score) }
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
    var id: String { week.string }
    var label: String { week.label }

    /// The chart series in the review.
    var series: String {
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
