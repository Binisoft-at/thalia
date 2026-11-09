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
        .toolbar { MainToolbar() }
    }
}

struct ReviewContent: View {
    let current: WeekContext
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<WeekPlan> { $0.deletedAt == nil }, sort: \WeekPlan.weekKey, order: .reverse) private var plans: [WeekPlan]

    private var weeks: [WeekPlan] {
        Array(plans.latest(by: \.weekKey, modified: \.modifiedAt).values).sorted { $0.weekKey > $1.weekKey }
    }

    private var points: [ScorePoint] {
        var result: [ScorePoint] = weeks.compactMap { plan in
            guard let week = plan.week, week != current.week, let score = plan.historyScore else { return nil }
            return ScorePoint(week: week, score: score, isOld: plan.isOldScoring)
        }
        if let live = current.score.overall { result.append(ScorePoint(week: current.week, score: live, isLive: true)) }
        return Array(result.sorted { $0.week < $1.week }.suffix(16))
    }

    var body: some View {
        List {
            if points.count > 0 {
                Section {
                    Chart(points) { point in
                        BarMark(x: .value("Woche", point.label), y: .value("Wertung", point.score))
                            .foregroundStyle(by: .value("Modell", point.isOld ? "vor KW42" : (point.isLive ? "laufend" : "gleich gewichtet")))
                            .annotation(position: .top) {
                                Text(Format.score(point.score))
                                    .font(.system(size: 8, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .chartForegroundStyleScale([
                        "vor KW42": Color.secondary.opacity(0.45),
                        "gleich gewichtet": Brand.accent,
                        "laufend": Brand.accent.opacity(0.45),
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
                    Text("Grau: vor KW42 (anderes Bewertungsmodell). Eine steigende Wertung heißt nicht, dass alles besser wurde – Arbeit, Reisen und Erholung waren jede Woche anders.")
                }
            }

            Section("Wochen") {
                if weeks.isEmpty {
                    Text("Noch keine Wochen. Importiere einen Wochenplan – oder deine bisherigen Wochenwertungen (type week mit value).")
                        .foregroundStyle(.secondary)
                }
                ForEach(weeks) { plan in
                    if let week = plan.week {
                        Button {
                            app.sheet = .report(week)
                        } label: {
                            WeekHistoryRow(plan: plan, week: week,
                                           liveScore: week == current.week ? current.score.overall : nil,
                                           isCurrent: week == current.week)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Im Wochenblatt öffnen", systemImage: "tablecells") {
                                app.selectedWeek = week
                                app.tab = .week
                                app.sidebar = .week
                            }
                            Button("Bericht", systemImage: "doc.text") { app.sheet = .report(week) }
                        }
                    }
                }
            }
        }
    }
}

struct WeekHistoryRow: View {
    let plan: WeekPlan
    let week: WeekKey
    let liveScore: Double?
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            ScoreRing(score: liveScore ?? plan.historyScore, size: 44, lineWidth: 4.5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(week.longLabel).font(.headline)
                    if isCurrent {
                        Text("läuft").font(.caption2.weight(.bold)).foregroundStyle(Brand.accent)
                    } else if plan.isClosed {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(Brand.accent)
                    }
                    if plan.isOldScoring {
                        Text("vor KW42").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                            .padding(.horizontal, 5).background(Color.secondary.opacity(0.12), in: .capsule)
                    }
                }
                Text(plan.title.isEmpty ? week.rangeLabel : "\(week.rangeLabel) · \(plan.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if plan.finalGoalsScored > 0, plan.finalGoalsScored < 10 {
                    Text("\(plan.finalGoalsScored)/10 Ziele bewertet")
                        .font(.caption2)
                        .foregroundStyle(.orange)
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

/// The week report as it goes to the next planning conversation.
struct ReportView: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var sharing: ShareRequest?

    var body: some View {
        NavigationStack {
            WeekReader(week: week, today: app.today) { context in
                let text = WeekReport.markdown(context.reportInput())
                ScrollView {
                    Text(text)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc") {
                            Clipboard.copy(text)
                            copied = true
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: text, subject: Text("Wochenbericht \(week.longLabel)")) {
                            Label("Text teilen", systemImage: "square.and.arrow.up")
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        PDFShareButton(context: context)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            sharing = ShareRequest(content: .week(context))
                        } label: {
                            Label("Als Bild teilen", systemImage: "photo")
                        }
                    }
                }
            }
            .navigationTitle("Wochenbericht \(week.label)")
            .inlineNavigationTitle()
            .sheet(item: $sharing) { request in
                ShareSheet(content: request.content)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
        }
        .sheetFrame(minWidth: 620, minHeight: 640)
    }
}
