import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

/// "Rückblick": every week's score and the reality behind it. Scores before KW42 2026 used another
/// model and are shown apart – they aren't directly comparable.
struct ReviewView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            ReviewContent(current: context)
        }
        .navigationTitle("Rückblick")
        .toolbar {
            // v8: several weeks as one PDF.
            ToolbarItem(placement: .primaryAction) {
                Button {
                    app.sheet = .rangePDF
                } label: {
                    Label("PDF-Bericht", systemImage: "doc.richtext")
                }
                .help("Mehrere Wochen als PDF (⌥⌘P)")
            }
            MainToolbar()
        }
    }
}

struct ReviewContent: View {
    let current: WeekContext
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<WeekPlan> { $0.deletedAt == nil }, sort: \WeekPlan.weekKey, order: .reverse) private var plans: [WeekPlan]
    /// Observed so "Geparkte Ideen" follows new ideas ("idee" = `NoteKind.idea.rawValue`) (R95).
    @Query(filter: #Predicate<DayNote> { $0.kindRaw == "idee" && $0.deletedAt == nil }) private var ideaNotes: [DayNote]
    /// v8: "PDF-Bericht ab dieser Woche" from a row's context menu.
    @State private var rangeStart: RangeStart?
    /// v9: the archive settings (`archive.<week>`), observed so the "Archiv" tag follows an import.
    /// v10 (§1.1.2): read with a prefix predicate – the synced inbox and the records stay out.
    @Query private var settings: [AppSetting]

    init(current: WeekContext) {
        self.current = current
        let prefix = ArchiveWeek.settingPrefix
        _settings = Query(filter: #Predicate<AppSetting> { $0.key.starts(with: prefix) })
    }

    /// The week scores as bars; v10: a dashed line with its name where a later segment begins.
    private static func scoreChart(_ points: [ScorePoint], starts: [ReviewSegmentStart]) -> some View {
        Chart {
            ForEach(points) { point in
                BarMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                    .foregroundStyle(by: .value("Modell", point.series))
                    .annotation(position: .top) {
                        Text(ReviewContent.barLabel(point))
                            .font(.system(size: 8, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
            }
            ForEach(starts) { start in
                RuleMark(x: .value("Woche", start.label))
                    .foregroundStyle(Color.secondary.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text(start.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }

    /// v10 (§1.4.3): where a later segment begins among the chart's weeks – a line with its name.
    private func segmentStarts(_ points: [ScorePoint]) -> [ReviewSegmentStart] {
        guard current.segments.hasSeveral else { return [] }
        let labels: Set<String> = Set(points.map(\.label))
        return current.segments.spans.dropFirst().compactMap { span -> ReviewSegmentStart? in
            let label: String = span.startWeek.label
            return labels.contains(label) ? ReviewSegmentStart(label: label, title: span.title) : nil
        }
    }

    private var weeks: [WeekPlan] {
        Array(plans.latest(by: \.weekKey, modified: \.modifiedAt).values).sorted { $0.weekKey > $1.weekKey }
    }

    /// R70: weeks before this one with a plan that were never closed and have no paper score –
    /// with their running score.
    private var unclosed: [String: UnclosedWeek] {
        var result: [String: UnclosedWeek] = [:]
        for plan in weeks {
            guard let week = plan.week, week < current.week, !plan.isClosed, plan.recordedScore == nil else { continue }
            let context: WeekContext = app.store.weekContext(for: week, today: app.today)
            guard context.hasPlan else { continue }
            result[week.string] = UnclosedWeek(score: context.score.overall, isExcused: context.score.isExcused)
        }
        return result
    }

    /// v8: closed weeks without a score because every day with something planned was a sick or
    /// holiday day – shown as "entschuldigt", not as a gap.
    private var excusedClosed: Set<String> {
        var result: Set<String> = []
        for plan in weeks {
            guard let week = plan.week, week < current.week, plan.isClosed, plan.historyScore == nil else { continue }
            if app.store.weekContext(for: week, today: app.today).score.isExcused { result.insert(week.string) }
        }
        return result
    }

    private func chartPoints(_ open: [String: UnclosedWeek], excused: Set<String>) -> [ScorePoint] {
        var result: [ScorePoint] = weeks.compactMap { plan -> ScorePoint? in
            guard let week = plan.week, week != current.week else { return nil }
            if let info = open[week.string] {
                if info.isExcused { return ScorePoint(week: week, score: 10, isExcused: true) }
                guard let score = info.score else { return nil }
                return ScorePoint(week: week, score: score, isUnclosed: true)
            }
            if excused.contains(week.string) { return ScorePoint(week: week, score: 10, isExcused: true) }
            guard let score = plan.historyScore else { return nil }
            return ScorePoint(week: week, score: score, isOld: plan.isOldScoring)
        }
        if let live = current.score.overall {
            result.append(ScorePoint(week: current.week, score: live, isLive: true))
        } else if current.score.isExcused {
            result.append(ScorePoint(week: current.week, score: 10, isExcused: true))
        }
        return Array(result.sorted { $0.week < $1.week }.suffix(16))
    }

    /// The number above a bar; "–" over a sick/holiday week (its bar is a pale full column).
    private static func barLabel(_ point: ScorePoint) -> String {
        point.isExcused ? "–" : Format.score(point.score)
    }

    /// v9: weeks without items whose archive setting holds grades – their rows say "Archiv" (decision 9),
    /// as in the PDF report (a week with items is scored by them). Read once per body.
    private var archivedWeeks: Set<String> {
        var result: Set<String> = []
        let stored = settings.filter { $0.key.hasPrefix(ArchiveWeek.settingPrefix) }.latest(by: \.key, modified: \.modifiedAt)
        for (key, setting) in stored {
            guard let week = ArchiveWeek.week(settingKey: key) else { continue }
            guard ArchiveWeek(csv: setting.value, week: week).hasGrades, app.store.items(week).isEmpty else { continue }
            result.insert(week.string)
        }
        return result
    }

    /// v8: the week was all sick or holiday days.
    private func isExcused(_ week: WeekKey, open: UnclosedWeek?, excused: Set<String>) -> Bool {
        if week == current.week { return current.score.isExcused }
        if let open { return open.isExcused }
        return excused.contains(week.string)
    }

    var body: some View {
        let open: [String: UnclosedWeek] = unclosed
        let excused: Set<String> = excusedClosed
        let archived: Set<String> = archivedWeeks
        let points: [ScorePoint] = chartPoints(open, excused: excused)
        let starts: [ReviewSegmentStart] = segmentStarts(points)
        List {
            if points.count > 0 {
                Section {
                    ReviewContent.scoreChart(points, starts: starts)
                    .chartForegroundStyleScale([
                        "vor KW42": Color.secondary.opacity(0.45),
                        "gleich gewichtet": Brand.accent,
                        "laufend": Brand.accent.opacity(0.45),
                        "nicht abgeschlossen": Color.orange,
                        "entschuldigt": Color.secondary.opacity(0.16), // WeekScore.excusedLabel
                    ])
                    .chartYScale(domain: 0...10)
                    .chartXAxis {
                        AxisMarks { _ in AxisValueLabel().font(.system(size: 9)) }
                    }
                    .frame(height: 190)
                    .padding(.vertical, 6)
                } header: {
                    SectionHeading(title: "Wochenwertungen", symbol: "chart.bar")
                } footer: {
                    Text("Grau: vor KW42 (anderes Bewertungsmodell). Orange: nicht abgeschlossen – laufende Wertung. Hellgrau: entschuldigt (krank/Urlaub) – die Woche zählt nicht. Gibt es eine Wertung laut Unterlagen, zeigt der Balken sie. Eine steigende Wertung heißt nicht, dass alles besser wurde – Arbeit, Reisen und Erholung waren jede Woche anders.")
                }
            }

            Section {
                let ideas: [DayNote] = ideaNotes.isEmpty ? [] : app.store.parkedIdeas()
                if ideas.isEmpty {
                    Text("Noch keine geparkten Ideen. Notizen der Art „Idee“ sammeln sich hier bis zur Zielüberprüfung.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(ideas) { note in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(ideaDate(note))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(note.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: {
                SectionHeading(title: "Geparkte Ideen", symbol: "lightbulb")
            }

            Section("Wochen") {
                if weeks.isEmpty {
                    Text("Noch keine Wochen. Importiere einen Wochenplan – oder trage vergangene Wochen nach: abgehakt, mit Krank/Urlaub-Tagen oder nur mit der Wochenwertung.")
                        .foregroundStyle(.secondary)
                    // v8: past weeks from paper, photos or tables.
                    Button {
                        app.sheet = .importPast(nil)
                    } label: {
                        Label("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath")
                    }
                }
                ForEach(weeks) { plan in
                    if let week = plan.week {
                        let info: UnclosedWeek? = open[week.string]
                        let weekExcused: Bool = isExcused(week, open: info, excused: excused)
                        Button {
                            app.sheet = .report(week)
                        } label: {
                            WeekHistoryRow(plan: plan, week: week,
                                           liveScore: liveScore(week, unclosed: info),
                                           isCurrent: week == current.week, isUnclosed: info != nil, isExcused: weekExcused,
                                           isArchive: archived.contains(week.string))
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            if info != nil {
                                Button {
                                    app.sheet = .closeWeek(week)
                                } label: {
                                    Label("Woche abschließen", systemImage: "flag.checkered")
                                }
                                .tint(.orange)
                            }
                        }
                        .contextMenu {
                            if info != nil {
                                Button("Woche abschließen", systemImage: "flag.checkered") { app.sheet = .closeWeek(week) }
                            }
                            Button("Im Wochenblatt öffnen", systemImage: "tablecells") {
                                app.selectedWeek = week
                                app.tab = .week
                                app.sidebar = .week
                            }
                            Button("Bericht", systemImage: "doc.text") { app.sheet = .report(week) }
                            Button("PDF-Bericht ab dieser Woche", systemImage: "doc.richtext") {
                                rangeStart = RangeStart(week: week)
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $rangeStart) { start in
            RangePDFSheet(from: start.week)
                .environment(app)
                .toastHost(app)
        }
    }

    /// "Mo, 2. Nov." for a parked idea (R95).
    private func ideaDate(_ note: DayNote) -> String {
        DayKey(note.dayKey)?.shortLabel ?? note.dayKey
    }

    /// The running score for this week and for weeks that were never closed (R70).
    private func liveScore(_ week: WeekKey, unclosed: UnclosedWeek?) -> Double? {
        if week == current.week { return current.score.overall }
        return unclosed?.score
    }
}

/// v10 (§1.4.3): a segment's first week in the Rückblick chart.
private struct ReviewSegmentStart: Identifiable {
    let label: String
    let title: String
    var id: String { label }
}

/// v8: the first week of a "PDF-Bericht ab dieser Woche".
private struct RangeStart: Identifiable {
    let week: WeekKey
    var id: String { week.string }
}

/// A past week with a plan that was never closed: its running score (R70).
struct UnclosedWeek {
    let score: Double?
    /// v8: every day with something planned was a sick or holiday day – no score on purpose.
    var isExcused = false
}

struct WeekHistoryRow: View {
    let plan: WeekPlan
    let week: WeekKey
    let liveScore: Double?
    let isCurrent: Bool
    /// R70: a past week with a plan that was never closed – orange with "nicht abgeschlossen".
    var isUnclosed = false
    /// v8: the week was all sick or holiday days – "entschuldigt" instead of a missing score.
    var isExcused = false
    /// v9: the week has archive grades – tagged "Archiv"; its ring shows the value laut Unterlagen.
    var isArchive = false

    private var ringScore: Double? { liveScore ?? plan.historyScore }

    /// v9 (decision 5): both scores where a week has both, clearly named; nil otherwise.
    private var scoresLine: String? {
        guard !isCurrent, let recorded = plan.recordedScore, let computed = plan.finalScore else { return nil }
        return "Laut Unterlagen \(Format.score(recorded)) · \(ImportWeekSummary.recalculatedLabel) \(Format.score(computed))"
    }

    /// "3/10 Ziele bewertet" – orange for a planned week; for an archive week a plain fact about its grades.
    private var goalsColor: Color { isArchive ? Color.secondary : Color.orange }

    private var ringTint: Color { isUnclosed ? Color.orange : Brand.accent }

    var body: some View {
        HStack(spacing: 12) {
            ScoreRing(score: ringScore, size: 44, lineWidth: 4.5, tint: ringTint)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(week.longLabel).font(.headline)
                    if isCurrent {
                        Text("läuft").font(.caption2.weight(.bold)).foregroundStyle(Brand.accent)
                    } else if plan.isClosed {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(Brand.accent)
                    } else if isUnclosed {
                        Text("nicht abgeschlossen")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .background(Color.orange.opacity(0.14), in: .capsule)
                    }
                    if plan.isOldScoring {
                        Text("vor KW42").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).background(Color.secondary.opacity(0.12), in: .capsule)
                    }
                    if isArchive {
                        ArchiveTag()
                    }
                    if isExcused {
                        Label(WeekScore.excusedLabel, systemImage: "cross.case")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .background(Color.secondary.opacity(0.12), in: .capsule)
                            .accessibilityLabel(WeekScore.excusedText)
                    }
                }
                Text(plan.title.isEmpty ? week.rangeLabel : "\(week.rangeLabel) · \(plan.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let scoresLine {
                    Text(scoresLine)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                if plan.finalGoalsScored > 0, plan.finalGoalsScored < 10 {
                    Text("\(plan.finalGoalsScored)/10 Ziele bewertet")
                        .font(.caption2)
                        .foregroundStyle(goalsColor)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }
}

/// The week report: a designed overview to read (R57); the Markdown for the next planning
/// conversation is folded away and copied in full with "Text kopieren".
struct ReportView: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var sharing: ShareRequest?
    @State private var showsPDF = false
    /// v8: "Mehrere Wochen als PDF…" from the share menu.
    @State private var showsRangePDF = false
    /// v10 (§1.2.5): the block "Jahresziel-Ergebnisse", read once when the sheet opens.
    @State private var resultLines: [GoalResultLine] = []

    var body: some View {
        NavigationStack {
            WeekReader(week: week, today: app.today) { context in
                content(context)
            }
            .task { resultLines = app.store.resultLines(today: app.today) }
            .navigationTitle("Wochenbericht \(week.label)")
            .inlineNavigationTitle()
            .sheet(item: $sharing) { request in
                ShareSheet(content: request.content)
                    .environment(app)
                    .toastHost(app)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showsRangePDF) {
            RangePDFSheet()
                .environment(app)
                .toastHost(app)
        }
        .thaliaSheetFrame(width: 620, height: 640)
    }

    private func content(_ context: WeekContext) -> some View {
        let text: String = WeekReport.markdown(context.reportInput(results: resultLines))
        return Form {
            WeekSummarySections(context: context)
            Section {
                DisclosureGroup("Text für ChatGPT") {
                    Text(text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } footer: {
                Text("„Text kopieren“ kopiert den ganzen Bericht für das nächste Planungsgespräch.")
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Clipboard.copy(text)
                    copied = true
                } label: {
                    Label(copied ? "Kopiert" : "Text kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ShareLink(item: text, subject: Text("Wochenbericht \(week.longLabel)")) {
                        Label("Text teilen", systemImage: "text.alignleft")
                    }
                    Button {
                        showsPDF = true
                    } label: {
                        Label("Woche als PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        showsRangePDF = true
                    } label: {
                        Label("Mehrere Wochen als PDF…", systemImage: "rectangle.stack")
                    }
                    Button {
                        sharing = ShareRequest(content: .week(context))
                    } label: {
                        Label("Als Bild teilen", systemImage: "photo")
                    }
                } label: {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showsPDF) {
            PDFPreviewSheet(kind: .week(week), context: context)
                .environment(app)
                .toastHost(app)
        }
    }
}
