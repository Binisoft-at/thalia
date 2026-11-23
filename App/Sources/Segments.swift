import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

// v10 (TASKS-v10 §1.4): segments – self-chosen versions of the annual goals within the goal year. The
// running segment keeps its snapshot, a new one starts with today's goals and categories; weeks before
// the current segment are never scored again by themselves (Grundregel 2). Earlier segments stay with
// their values and are shown apart ("Frühere Abschnitte"); every screen focuses on the current one.

// MARK: Helpers (no SwiftUI – checked on Linux)

enum SegmentTexts {
    /// "KW50 · 7.–13. Dez." with "· diese Woche" / "· rückwirkend" for the start-week picker.
    static func startLabel(_ week: WeekKey, today: DayKey) -> String {
        let base: String = "\(week.label) · \(week.rangeLabel)"
        if week == today.week { return base + " · diese Woche" }
        return week < today.week ? base + " · rückwirkend" : base
    }

    /// What starting in `week` means, in one or two sentences.
    static func startHint(_ week: WeekKey, segments: Segments, today: DayKey) -> String {
        let running: String = segments.current(today: today)?.title ?? "Der laufende Abschnitt"
        let end: String = week.adding(weeks: -1).label
        let frozen: String = "Abgeschlossene Wochen davor werden nicht mehr automatisch neu gewertet – ihre Wertungen bleiben, wie sie sind."
        if week < today.week { return "Rückwirkend: \(running) endet mit \(end). " + frozen }
        if week == today.week { return "Ab dieser Woche: \(running) endet mit \(end). " + frozen }
        return "\(running) läuft bis \(end) und behält seine Ziele. Der neue Abschnitt beginnt mit den Zielen und Kategorien von heute."
    }

    /// "Abschnitt 2 beginnt mit KW50"
    static func toastText(title: String, week: WeekKey) -> String {
        "\(title) beginnt mit \(week.label)"
    }

    /// "3/5 über 8" for a category of an earlier segment; "–" without scored weeks.
    static func tallyText(_ tally: GoalTrack.Tally?) -> String {
        guard let tally else { return "–" }
        return "\(tally.good)/\(tally.scored) über 8"
    }

    /// The goal's line in an earlier segment's page; "–" without data.
    static func goalHeader(_ line: SegmentPageData.GoalLine) -> String {
        goalLine(average: line.average, good: line.weeksGood, scored: line.weeksScored) ?? "–"
    }

    /// "Ø 7,4 · 3/5 Wochen gut dabei" for a goal in an earlier segment; nil without data.
    static func goalLine(average: Double?, good: Int, scored: Int) -> String? {
        var parts: [String] = []
        if let average { parts.append("Ø " + Format.score(average)) }
        if scored > 0 { parts.append("\(good)/\(scored) Wochen gut dabei") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// An earlier segment as its page shows it – computed once (plain values).
struct SegmentPageData {
    struct CategoryLine {
        let category: CategoryRecord
        let tally: GoalTrack.Tally?
    }

    struct GoalLine {
        let goal: GoalRecord
        let average: Double?
        let weeksGood: Int
        let weeksScored: Int
        let categories: [CategoryLine]
    }

    struct ResultLine {
        let result: GoalResult
        let progress: ResultProgress
    }

    let span: SegmentSpan
    let summary: SegmentSummary?
    let goals: [GoalLine]
    let results: [ResultLine]
    let books: [ListItem]

    /// The goals and categories as they were at the segment's end (§1.4.1), their scores, the weeks
    /// above 8, the results by the segment's end and the books finished in it.
    @MainActor
    static func make(span: SegmentSpan, context: WeekContext, store: TrackerStore) -> SegmentPageData {
        let segments: Segments = context.segments
        let labels = segments.labels(for: span.startWeek, today: context.today, goals: context.data.goals,
                                     categories: context.data.categories)
        let range: ClosedRange<WeekKey> = span.startWeek...span.endWeek
        let weeks: [GoalTrack.Week] = context.storedCategoryWeeks
        let goals: [GoalLine] = labels.goals.map { goal in
            let scores: [Double] = store.goalScoreHistory(goalKey: goal.key, through: span.endWeek)
                .filter { span.contains($0.week) }.map(\.score)
            let average: Double? = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
            let good = GoalTrack.goalWeeks(goal.key, weeks: weeks, categories: labels.categories, range: range)
            let categories: [CategoryLine] = labels.categories.filter { $0.goalKey == goal.key }.map { category in
                CategoryLine(category: category,
                             tally: GoalTrack.tallies(weeks, categories: [category.key], limit: nil, range: range).first)
            }
            return GoalLine(goal: goal, average: average, weeksGood: good.good, weeksScored: good.scored, categories: categories)
        }
        // v11 P1.11: a book counting for a deleted result counts by its kind.
        let resultIDs: Set<String> = Set(context.results.map(\.id))
        let results: [ResultLine] = context.results.filter { $0.isActive(in: span, segments: segments) }.map { result in
            let series: [DayKey: Double] = context.needsSeries(result)
                ? store.resultSeries(result, period: context.goalPeriod, today: span.endDay) : [:]
            let progress: ResultProgress = ResultProgress.compute(result, segments: segments, today: span.endDay,
                                                                  entries: context.goalEntries, items: context.listItems, series: series,
                                                                  resultIDs: resultIDs)
            return ResultLine(result: result, progress: progress)
        }
        let books: [ListItem] = ListMath.finished(context.listItems, from: span.startDay, through: span.endDay)
        let summary: SegmentSummary? = store.earlierSegments(today: context.today).first { $0.span.id == span.id }
        return SegmentPageData(span: span, summary: summary, goals: goals, results: results, books: books)
    }

    /// A goal in an earlier segment: its title then and "Ø 7,4 · 3/5 Wochen gut dabei".
    struct GoalHistoryLine: Identifiable {
        let span: SegmentSpan
        let title: String
        let line: String
        var id: String { span.id }
    }

    /// A goal's values in each earlier segment, newest first (the goal page's "Frühere Abschnitte").
    @MainActor
    static func goalHistory(_ goalKey: String, context: WeekContext, store: TrackerStore) -> [GoalHistoryLine] {
        let earlier: [SegmentSpan] = context.segments.earlier(today: context.today)
        guard !earlier.isEmpty else { return [] }
        let history: [WeekScorePoint] = store.goalScoreHistory(goalKey: goalKey, through: context.week)
        let weeks: [GoalTrack.Week] = context.storedCategoryWeeks
        return earlier.map { span in
            let labels = context.segments.labels(for: span.startWeek, today: context.today, goals: context.data.goals,
                                                 categories: context.data.categories)
            let scores: [Double] = history.filter { span.contains($0.week) }.map(\.score)
            let average: Double? = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
            let good = GoalTrack.goalWeeks(goalKey, weeks: weeks, categories: labels.categories, range: span.startWeek...span.endWeek)
            let title: String = labels.goals.first { $0.key == goalKey }?.title ?? ""
            let line: String = SegmentTexts.goalLine(average: average, good: good.good, scored: good.scored) ?? "keine abgeschlossene Woche"
            return GoalHistoryLine(span: span, title: title, line: line)
        }
    }
}

// MARK: "Neuen Abschnitt beginnen…"

/// "Neuen Abschnitt beginnen…" (§1.4.2): start week (next week by default, at the earliest one week after
/// the current segment's start; back in time allowed), title, reason. Confirming is one undo group; then
/// Einstellungen → Jahresziele opens right here to rename goals, update results' targets, add or end
/// results.
struct SegmentWizard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var segments: Segments?
    @State private var startWeek: WeekKey = DayKey.today().week
    @State private var title = ""
    @State private var reason = ""
    @State private var begun = false

    var body: some View {
        NavigationStack {
            Group {
                if begun {
                    GoalYearSettingsView(afterSegmentStart: true)
                } else {
                    form
                }
            }
            .toolbar { toolbar }
        }
        .task { load() }
        .unsavedInput(!begun && !reason.trimmingCharacters(in: .whitespaces).isEmpty, in: app)
        .thaliaSheetFrame(width: 540, height: 720)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            if !begun {
                Button("Abbrechen") { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            if begun {
                Button("Fertig") { dismiss() }
            } else {
                Button("Beginnen", action: begin)
                    .disabled(!canBegin)
            }
        }
    }

    private var canBegin: Bool {
        guard let segments else { return false }
        return segments.canStart(startWeek, today: app.today)
    }

    private var choices: [WeekKey] {
        segments?.startChoices(today: app.today) ?? []
    }

    private var currentLine: String {
        guard let current = segments?.current(today: app.today) else { return "" }
        return "Läuft: \(current.headline(week: app.today.week))"
    }

    private var form: some View {
        Form {
            Section {
                Text(currentLine)
                    .font(.subheadline.weight(.semibold))
                Text("Ein Abschnitt ist eine Version der Jahresziele. Was frühere Abschnitte geleistet haben, bleibt erhalten und wird gesondert gezeigt – der Blick liegt immer auf dem aktuellen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section {
                if choices.isEmpty {
                    Text("Im Zieljahr ist keine Woche mehr frei für einen neuen Abschnitt.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Beginnt mit", selection: $startWeek) {
                        ForEach(choices, id: \.self) { week in
                            Text(SegmentTexts.startLabel(week, today: app.today)).tag(week)
                        }
                    }
                }
                TextField("Titel", text: $title)
                TextField("Grund (optional, z. B. neue Arbeitszeiten)", text: $reason, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("Neuer Abschnitt")
            } footer: {
                Text(hint)
            }
            Section {
                Label("Danach: Ziele umbenennen oder beschreiben, neue Ziele und Kategorien, Ergebnisse aktualisieren, neue anlegen oder beenden.", systemImage: "arrow.right.circle")
                    .font(.subheadline)
                Label("Kategorien werden hier nicht umgehängt oder gelöscht – das geht weiter über den Wochenplan.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Neuer Abschnitt")
        .inlineNavigationTitle()
    }

    private var hint: String {
        guard let segments else { return "" }
        return SegmentTexts.startHint(startWeek, segments: segments, today: app.today)
    }

    private func load() {
        guard segments == nil else { return }
        let resolved: Segments = app.store.segments()
        segments = resolved
        startWeek = resolved.defaultStart(today: app.today)
        if title.isEmpty { title = resolved.nextTitle(today: app.today) }
    }

    private func begin() {
        guard canBegin else { return }
        let week: WeekKey = startWeek
        guard let change = app.store.beginSegment(startWeek: week, title: title, reason: reason, today: app.today) else { return }
        let shown: String = title.trimmingCharacters(in: .whitespaces).isEmpty ? (segments?.nextTitle(today: app.today) ?? "Abschnitt") : title
        RecordToast.show(app, SegmentTexts.toastText(title: shown, week: week), symbol: "flag.2.crossed.fill", change: change)
        withAnimation(.snappy) { begun = true }
    }
}

/// A stored segment's title and reason; a later one can go to "Zuletzt gelöscht" (its weeks count to the
/// segment before it again).
struct SegmentEditor: View {
    let segment: GoalSegment
    /// The segment is the year's first (it can't be deleted).
    let isFirst: Bool
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var reason: String
    @State private var confirmsDelete = false

    init(segment: GoalSegment, isFirst: Bool) {
        self.segment = segment
        self.isFirst = isFirst
        _title = State(initialValue: segment.title)
        _reason = State(initialValue: segment.reason)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $title)
                    TextField("Grund (optional)", text: $reason, axis: .vertical)
                        .lineLimit(1...4)
                } footer: {
                    Text("Beginnt mit \(segment.startWeek.longLabel).")
                }
                if !isFirst {
                    Section {
                        Button("Abschnitt löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    } footer: {
                        Text("Seine Wochen zählen dann wieder zum Abschnitt davor. Gespeicherte Wertungen bleiben, wie sie sind.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(segment.title.isEmpty ? "Abschnitt" : segment.title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("„\(segment.title)“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive, action: delete)
            }
        }
        .unsavedInput(title != segment.title || reason != segment.reason, in: app)
        .thaliaSheetFrame(width: 440, height: 420)
    }

    private func save() {
        var changed: GoalSegment = app.store.record(GoalSegment.self, key: segment.settingKey) ?? segment
        changed.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        changed.reason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let change: RecordChange = app.store.saveSegment(changed)
        RecordToast.show(app, "„\(changed.title)“ gesichert", symbol: "flag.2.crossed", change: change)
        dismiss()
    }

    private func delete() {
        let change: RecordChange = app.store.trash(segment)
        RecordToast.show(app, "„\(segment.title)“ gelöscht", symbol: "trash.fill", change: change)
        dismiss()
    }
}

// MARK: "Frühere Abschnitte"

/// "Frühere Abschnitte" on the Ziele page (§1.4.3): per row title, weeks, Ø score, category weeks above 8
/// and the results reached → the segment's page with its goals and values then.
struct EarlierSegmentsCard: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var summaries: [SegmentSummary] = []

    private var loadKey: String {
        let spans: String = context.segments.spans.map { "\($0.id)@\($0.startWeek.string)" }.joined(separator: ",")
        return "\(spans)|\(context.today.string)|\(context.storedCategoryWeeks.count)|\(context.results.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Frühere Abschnitte", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            if summaries.isEmpty {
                ForEach(context.segments.earlier(today: context.today), id: \.id) { span in
                    Text("\(span.title) · \(span.weeksLabel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(summaries) { summary in
                NavigationLink {
                    SegmentPage(spanID: summary.span.id)
                } label: {
                    row(summary)
                }
                .buttonStyle(.plain)
            }
        }
        .card()
        .task(id: loadKey) {
            summaries = app.store.earlierSegments(today: context.today)
        }
    }

    private func row(_ summary: SegmentSummary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.span.title)
                    .font(.subheadline.weight(.semibold))
                Text(summary.line)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if !summary.span.reason.isEmpty {
                    Text(summary.span.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }
}

/// An earlier segment: the goals as they were then, with their Ø score, weeks "gut dabei" and the
/// categories' weeks above 8; the results by the segment's end; the books finished in it.
struct SegmentPage: View {
    let spanID: String
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            if let span = context.segments.span(id: spanID) {
                SegmentPageContent(span: span, context: context)
            } else {
                ContentUnavailableView("Abschnitt nicht gefunden", systemImage: "flag.2.crossed")
            }
        }
    }
}

struct SegmentPageContent: View {
    let span: SegmentSpan
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var data: SegmentPageData?

    var body: some View {
        List {
            Section {
                LabeledContent("Wochen", value: span.weeksLabel)
                if let summary = data?.summary {
                    LabeledContent("Ø Wertung", value: Format.score(summary.average, outOf: false))
                    if summary.categoryWeeksScored > 0 {
                        LabeledContent("Kategorie-Wochen über 8", value: "\(summary.categoryWeeksGood)/\(summary.categoryWeeksScored)")
                    }
                    if summary.resultsActive > 0 {
                        LabeledContent("Ergebnisse erreicht", value: "\(summary.resultsReached) von \(summary.resultsActive)")
                    }
                }
                if !span.reason.isEmpty {
                    Text(span.reason)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Ziele und Kategorien so, wie sie in diesem Abschnitt hießen. Die Werte bleiben, wie sie waren.")
            }
            if let data {
                ForEach(data.goals, id: \.goal.key) { line in
                    goalSection(line)
                }
                if !data.results.isEmpty {
                    Section("Ergebnisse am Ende des Abschnitts") {
                        ForEach(data.results, id: \.result.id) { line in
                            GoalResultRow(result: line.result, progress: line.progress, showsGoal: true,
                                          tint: GoalPalette.color(goal: line.result.goalKey))
                        }
                    }
                }
                if !data.books.isEmpty {
                    Section("Fertig gelesen") {
                        ForEach(data.books, id: \.id) { item in
                            LabeledContent(item.label, value: item.finishedOn?.shortLabel ?? "")
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(span.title)
        .inlineNavigationTitle()
        .task(id: span.id) {
            data = SegmentPageData.make(span: span, context: context, store: app.store)
        }
    }

    private func goalSection(_ line: SegmentPageData.GoalLine) -> some View {
        Section {
            ForEach(line.categories, id: \.category.key) { category in
                HStack(spacing: 8) {
                    KeyBadge(key: category.category.key)
                    Text(category.category.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(SegmentTexts.tallyText(category.tally))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Text("\(line.goal.key) \(line.goal.title)")
                Spacer()
                Text(SegmentTexts.goalHeader(line))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: Einstellungen → Jahresziele (§1.4.2)

enum GoalStructureTexts {
    /// The next goal's key: one more than the highest number ("11").
    static func nextGoalKey(_ goals: [GoalRecord]) -> String {
        String((goals.map(\.number).max() ?? 0) + 1)
    }

    /// The next category key under a goal: "5.3" after "5.1" and "5.2".
    static func nextCategoryKey(goalKey: String, categories: [CategoryRecord]) -> String {
        let numbers: [Int] = categories.filter { $0.goalKey == goalKey }.compactMap { category -> Int? in
            let parts = category.key.split(separator: ".")
            return parts.count == 2 ? Int(parts[1]) : nil
        }
        return "\(goalKey).\((numbers.max() ?? 0) + 1)"
    }
}

/// "Jahresziel hinzufügen": a new goal with the next number – it counts like every other goal.
struct NewGoalEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titel", text: $title)
                    TextField("Absicht und Ergebnisziel", text: $details, axis: .vertical)
                        .lineLimit(3...10)
                } footer: {
                    Text("Jedes Jahresziel zählt gleich viel in der Woche. Kategorien und Punkte dazu kommen mit dem Wochenplan.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Neues Jahresziel")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .unsavedInput(!title.isEmpty || !details.isEmpty, in: app)
        .thaliaSheetFrame(width: 460, height: 360)
    }

    private func save() {
        let store: TrackerStore = app.store
        let existing: [GoalRecord] = store.liveGoals().map(\.record)
        let key: String = GoalStructureTexts.nextGoalKey(existing)
        let goal = AnnualGoal(GoalRecord(key: key, title: title.trimmingCharacters(in: .whitespacesAndNewlines), details: details))
        store.context.insert(goal)
        store.save()
        app.toasts.show("Jahresziel \(key) angelegt", symbol: "target") {
            goal.moveToTrash()
            store.save()
        }
        dismiss()
    }
}

/// "Kategorie hinzufügen": a new category under a goal with the next key – never moved or deleted here.
struct NewCategoryEditor: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var goalKey: String
    @State private var title = ""
    @State private var details = ""
    @State private var goals: [GoalRecord] = []

    init(goalKey: String = "") {
        _goalKey = State(initialValue: goalKey)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Jahresziel", selection: $goalKey) {
                        if goalKey.isEmpty { Text("Bitte wählen").tag("") }
                        ForEach(goals, id: \.key) { goal in
                            Text("\(goal.key) \(goal.title)").tag(goal.key)
                        }
                    }
                    TextField("Titel", text: $title)
                    TextField("Notiz (optional)", text: $details, axis: .vertical)
                } footer: {
                    Text("Die Kategorie bekommt die nächste Nummer unter dem Ziel. Umhängen oder Löschen geht über den Wochenplan.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Neue Kategorie")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Anlegen", action: save)
                        .disabled(goalKey.isEmpty || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if goals.isEmpty {
                    goals = Array(app.store.liveGoals().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)).sortedByNumber()
                }
            }
        }
        .unsavedInput(!title.isEmpty || !details.isEmpty, in: app)
        .thaliaSheetFrame(width: 460, height: 380)
    }

    private func save() {
        let store: TrackerStore = app.store
        let existing: [CategoryRecord] = store.liveCategories().map(\.record)
        let key: String = GoalStructureTexts.nextCategoryKey(goalKey: goalKey, categories: existing)
        let category = TrackCategory(CategoryRecord(key: key, goalKey: goalKey, title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                                    details: details))
        store.context.insert(category)
        store.save()
        app.toasts.show("Kategorie \(key) angelegt", symbol: "square.grid.2x2") {
            category.moveToTrash()
            store.save()
        }
        dismiss()
    }
}

/// What Einstellungen → Jahresziele opens (v10).
enum GoalStructureSheet: Identifiable {
    case wizard
    case segment(GoalSegment, isFirst: Bool)
    case result(GoalResult?, goalKey: String)
    case newGoal
    case newCategory

    var id: String {
        switch self {
        case .wizard: "wizard"
        case .segment(let segment, _): "segment-" + segment.id
        case .result(let result, let goalKey): "result-" + (result?.id ?? "new-" + goalKey)
        case .newGoal: "new-goal"
        case .newCategory: "new-category"
        }
    }

    /// The note on top right after a segment began.
    static func afterStartText(_ segments: Segments, today: DayKey) -> String {
        let newest: SegmentSpan? = segments.spans.last { $0.isStored }
        let name: String = newest.map { "\($0.title) beginnt mit \($0.startWeek.label)." } ?? "Der neue Abschnitt ist angelegt."
        return name + " Jetzt Ziele umbenennen oder beschreiben, Ergebnisse aktualisieren, neue anlegen oder beenden."
    }

    /// "läuft" for the current segment.
    static func runningTag(_ span: SegmentSpan, current: SegmentSpan?) -> String? {
        span.id == current?.id ? "läuft" : nil
    }

    /// "Beginnt mit KW48 – zählt nicht, ein neuerer Abschnitt beginnt in derselben Woche"
    static func hiddenDetail(_ segment: GoalSegment) -> String {
        "Beginnt mit \(segment.startWeek.label) – zählt nicht, ein neuerer Abschnitt beginnt in derselben Woche"
    }

    /// "KW45–KW49 · neue Arbeitszeiten"
    static func segmentDetail(_ span: SegmentSpan) -> String {
        span.reason.isEmpty ? span.weeksLabel : "\(span.weeksLabel) · \(span.reason)"
    }

    /// "Ziel ≥ 10 · in Abschnitt 2: ≥ 6 · Leseliste"
    static func resultDetail(_ result: GoalResult, segment: SegmentSpan?, segments: Segments) -> String {
        var parts: [String] = []
        if result.kind != .check { parts.append(ResultTexts.targetSummary(result, segment: segment)) } else { parts.append(result.kind.label) }
        let source: ResultSource = result.resultSource
        if source != .entries { parts.append(source.label) }
        if let from = result.fromSegment.flatMap({ segments.span(id: $0) }) { parts.append("ab \(from.title)") }
        if let ended = result.endedAfter.flatMap({ segments.span(id: $0) }) { parts.append("bis \(ended.title)") }
        return parts.joined(separator: " · ")
    }

    /// "beendet" for a result that ended before the current segment, "neu" for one new in it.
    static func resultTag(_ result: GoalResult, segment: SegmentSpan?, segments: Segments) -> String? {
        guard let segment else { return nil }
        // New from a segment that hasn't begun yet: "ab KW48", not "beendet".
        if let from = result.fromSegment.flatMap({ segments.span(id: $0) }), from.number > segment.number {
            return "ab \(from.startWeek.label)"
        }
        if !result.isActive(in: segment, segments: segments) { return "beendet" }
        if result.fromSegment == segment.id { return "neu" }
        return nil
    }

    static func resultsFooter(_ current: SegmentSpan?) -> String {
        guard let current else {
            return "Ein Ergebnis hält fest, was am Ende stehen soll. Antippen ändert Ziel, Quelle und Einheit."
        }
        return "Aktualisieren: im Ergebnis ein eigenes Ziel für \(current.title) setzen. Neue Ergebnisse gelten ab \(current.title); „Beendet nach“ schließt eines ab."
    }
}

struct GoalStructureSheetContent: View {
    let sheet: GoalStructureSheet

    var body: some View {
        switch sheet {
        case .wizard:
            SegmentWizard()
        case .segment(let segment, let isFirst):
            SegmentEditor(segment: segment, isFirst: isFirst)
        case .result(let result, let goalKey):
            ResultEditor(result: result, goalKey: goalKey)
        case .newGoal:
            NewGoalEditor()
        case .newCategory:
            NewCategoryEditor()
        }
    }
}

/// A row of Einstellungen → Jahresziele: title, detail and an optional tag ("läuft", "neu", "beendet").
struct GoalStructureRow: View {
    let title: String
    let detail: String
    var tag: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            if let tag {
                Text(tag)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Brand.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Brand.accent.opacity(0.12), in: .capsule)
            }
        }
        .contentShape(.rect)
    }
}

// MARK: Frozen weeks (Grundregel 2)

/// A closed week before the current segment: never scored again by itself – "Neu berechnen" scores it
/// under today's rules on request (`TrackerStore.recompute`).
/// v11 P7.1: on a device that can't score the week (`TrackerStore.canScore` – Mac, Watch, iPad for a week that reads
/// Apple Health) "Hier fehlen die Werte aus Apple Health." and "Am iPhone neu berechnen" (a `force` request) instead;
/// "Neu berechnen" shows the old and the new score with "Widerrufen" (`ClosedWeekSnapshot`).
/// v11 P6.1: a second line "Nach heutigem Stand: 7,41" when today's rules give another score and this device can
/// score the week – the stored score stays what the week shows.
struct FrozenWeekNote: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app

    static let missingHealthText = "Hier fehlen die Werte aus Apple Health."

    var body: some View {
        let canScore: Bool = app.store.canScore(context.week)
        let todayLine: String? = FrozenWeekNote.todayLine(stored: context.plan?.finalScore, live: context.score.overall,
                                                          canScore: canScore)
        VStack(alignment: .leading, spacing: 8) {
            Label(FrozenWeekNote.text(context), systemImage: "snowflake")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let todayLine {
                Text(todayLine)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if canScore {
                Button("Neu berechnen", systemImage: "arrow.clockwise", action: recompute)
                    .buttonStyle(.bordered)
            } else {
                Label(FrozenWeekNote.missingHealthText, systemImage: "heart.text.square")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Am iPhone neu berechnen", systemImage: "iphone", action: requestOnPhone)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    /// "Nach heutigem Stand: 7,41" – only when today's rules differ from the stored score by at least 0,01 (as shown)
    /// and this device can score the week; nil otherwise.
    static func todayLine(stored: Double?, live: Double?, canScore: Bool) -> String? {
        guard canScore, let stored, let live, stored.isFinite, live.isFinite else { return nil }
        guard abs((live * 100).rounded() - (stored * 100).rounded()) >= 1 else { return nil }
        return "Nach heutigem Stand: " + Format.score(live)
    }

    /// The toast after "Neu berechnen": "KW44: 7,84 → 8,02"; "KW44 neu berechnet · 7,84" when the score stays.
    static func recomputedText(_ week: WeekKey, before: Double?, after: Double?) -> String {
        let old: String = Format.score(before, outOf: false)
        let new: String = Format.score(after, outOf: false)
        guard old != new else { return "\(week.label) neu berechnet · \(new)" }
        return "\(week.label): \(old) → \(new)"
    }

    /// "KW44 wird nach dem Abgleich am iPhone neu berechnet."
    static func requestedText(_ week: WeekKey) -> String {
        "\(week.label) wird nach dem Abgleich am iPhone neu berechnet."
    }

    /// "Vor Abschnitt 2 (seit KW50): KW44 wird nicht mehr von selbst neu gewertet."
    static func text(_ context: WeekContext) -> String {
        let rest: String = "\(context.week.label) wird nicht mehr von selbst neu gewertet – ihre Wertung bleibt, wie sie ist."
        if context.week < context.segments.period.start.week { return "Vor dem Zieljahr: " + rest }
        guard let current = context.currentSegment else { return rest }
        return "Vor \(current.title) (seit \(current.startWeek.label)): " + rest
    }

    /// Scores the week again under today's rules; the toast's "Widerrufen" writes the week back as it was.
    private func recompute() {
        let week: WeekKey = context.week
        let store: TrackerStore = app.store
        let snapshot: ClosedWeekSnapshot? = store.closedWeekSnapshot(week)
        guard store.recompute(week) else {
            app.toasts.show("\(week.label): Wertung unverändert", symbol: "arrow.clockwise")
            return
        }
        let after: Double? = store.closedWeekSnapshot(week)?.finalScore
        let message: String = FrozenWeekNote.recomputedText(week, before: snapshot?.finalScore, after: after)
        guard let snapshot else {
            app.toasts.show(message, symbol: "arrow.clockwise")
            return
        }
        app.toasts.show(message, symbol: "arrow.clockwise") {
            store.restore(snapshot)
        }
    }

    /// Mac, Watch, iPad: the iPhone scores the week with its Health values after the next sync (`force`: also a
    /// frozen week); nothing is stored here.
    private func requestOnPhone() {
        let week: WeekKey = context.week
        app.store.requestRescore(week, force: true)
        app.toasts.show(FrozenWeekNote.requestedText(week), symbol: "iphone")
    }
}
