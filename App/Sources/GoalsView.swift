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
    @Query(filter: #Predicate<WeekPlan> { $0.deletedAt == nil }, sort: \WeekPlan.weekKey) private var plans: [WeekPlan]

    private var period: GoalPeriod { app.store.goalPeriod }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                yearCard
                if context.goals.isEmpty {
                    EmptyStateView(title: "Noch keine Jahresziele",
                                   message: "Lege deine zehn Jahresziele und 18 Kategorien aus der Übergabe an – oder importiere sie mit dem Wochenplan.",
                                   symbol: "target", createTitle: "Meine Struktur anlegen",
                                   onCreate: { app.store.seedStructure() }, onImport: { app.sheet = .importPlan(prompt: true) })
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                        ForEach(context.goals) { goal in
                            NavigationLink {
                                GoalDetailView(goalKey: goal.key)
                            } label: {
                                GoalCard(goal: goal, context: context, history: history(for: goal.key))
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

    /// Closed weeks' scores for one goal, oldest first, plus this week live.
    private func history(for goalKey: String) -> [ScorePoint] {
        var points: [ScorePoint] = plans.compactMap { plan in
            guard let week = plan.week, week < context.week, let score = plan.finalGoalScoreMap[goalKey] else { return nil }
            return ScorePoint(week: week, score: score)
        }
        if let live = context.score.goalWeek[goalKey]?.score { points.append(ScorePoint(week: context.week, score: live)) }
        return Array(points.suffix(12))
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
            GoalBars(scores: context.goals.map { context.score.goalWeek[$0.key]?.score }, height: 48)
            Button("Wie wird gerechnet?") { app.sheet = .explainer(.scoring) }
                .font(.subheadline)
        }
        .card()
    }
}

/// One annual goal: this week's score, its categories, the last weeks.
struct GoalCard: View {
    let goal: AnnualGoal
    let context: WeekContext
    let history: [ScorePoint]

    var body: some View {
        let score = context.score.goalWeek[goal.key]
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ScoreRing(score: score?.score, size: 58, lineWidth: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ziel \(goal.key)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Brand.accent)
                    Text(goal.title)
                        .font(.headline)
                    Text(goal.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
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
                        .foregroundStyle(Brand.accent)
                    PointMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                        .symbolSize(18)
                        .foregroundStyle(Brand.accent)
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

    var body: some View {
        let categories = context.categories(of: goal)
        let categoryKeys = Set(categories.map(\.key))
        let measures = context.measures.filter { categoryKeys.contains($0.categoryKey) }
        List {
            Section {
                HStack(spacing: 16) {
                    ScoreRing(score: context.score.goalWeek[goal.key]?.score, size: 76, caption: context.week.label)
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
            ForEach(categories) { category in
                Section {
                    ForEach(context.items(in: category)) { item in
                        HStack {
                            Text(item.title)
                                .font(.subheadline)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(context.week.days, id: \.self) { day in
                                    let mark = context.mark(item, on: day)
                                    Text(mark?.symbol ?? (item.days.contains(day.weekday) ? "·" : " "))
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .foregroundStyle(mark.color)
                                        .frame(width: 13)
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
            .sheetFrame(minWidth: 460, minHeight: 320)
        }
    }
}

/// One week's score in a chart.
struct ScorePoint: Identifiable {
    let week: WeekKey
    let score: Double
    var isOld = false
    var isLive = false
    var id: String { week.string }
    var label: String { week.label }
}

extension DayKey {
    static func monthShort(_ month: Int) -> String {
        ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."][max(0, min(11, month - 1))]
    }
}
