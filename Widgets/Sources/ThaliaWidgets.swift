import WidgetKit
import SwiftUI
import AppIntents
import ThaliaCore

/// Widgets read the small snapshot the app writes to the shared App Group (WidgetBridge).
@main
struct ThaliaWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        WeekWidget()
        PowerHoursControl()
    }
}

struct SummaryEntry: TimelineEntry {
    let date: Date
    let summary: TodaySummary
}

struct SummaryProvider: TimelineProvider {
    func placeholder(in context: Context) -> SummaryEntry {
        SummaryEntry(date: Date(), summary: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SummaryEntry) -> Void) {
        let summary: TodaySummary = context.isPreview ? .placeholder : (WidgetBridge.read() ?? .placeholder)
        completion(SummaryEntry(date: Date(), summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        let summary = WidgetBridge.read() ?? .placeholder
        // The app reloads the timeline whenever the summary changes; refresh after midnight anyway.
        let tomorrow = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [SummaryEntry(date: Date(), summary: summary)], policy: .after(tomorrow)))
    }
}

private let accent = Color("AccentColor")

/// How much of today is filled in; once the day is closed, its score.
struct WidgetRing: View {
    let summary: TodaySummary
    var lineWidth: CGFloat = 6

    var body: some View {
        let progress = summary.dayScore.map { $0 / 10 } ?? summary.fill
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(summary.dayScore == nil && summary.fill >= 1 ? Color.green : accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(summary.dayScore.map { Format.score($0) } ?? summary.fillText)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(lineWidth)
        }
    }
}

/// Week score as a ring (goal bars live next to it).
struct WeekRing: View {
    let score: Double?
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat((score ?? 0) / 10))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(Format.score(score, outOf: false))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
        }
    }
}

// MARK: Today

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThaliaToday", provider: SummaryProvider()) { entry in
            TodayWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "thalia://today"))
        }
        .configurationDisplayName("Heute")
        .description("Wie viel heute erfasst ist, was als Nächstes offen ist, Power-Hours und Messwerte.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SummaryEntry

    private var summary: TodaySummary { entry.summary }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: summary.dayScore.map { $0 / 10 } ?? summary.fill, in: 0...1) {
                Image(systemName: summary.isClosed ? "checkmark.seal" : "checklist")
            } currentValueLabel: {
                Text(summary.dayScore.map { Format.score($0) } ?? summary.fillText.replacingOccurrences(of: " %", with: ""))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryInline:
            Text("\(summary.statusText) · \(Format.powerHours(summary.powerHours))")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.isClosed ? "Tag \(Format.score(summary.dayScore, outOf: true))" : "Heute \(summary.fillText)")
                    .font(.headline)
                Text(next)
                    .font(.caption)
                    .lineLimit(1)
                Text(Format.powerHours(summary.powerHours))
                    .font(.caption)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(spacing: 6) {
                    WidgetRing(summary: summary)
                        .frame(width: 72, height: 72)
                    Text(summary.isClosed ? "abgeschlossen" : summary.day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(next).font(.caption.weight(.semibold)).lineLimit(1)
                    Text(Format.powerHours(summary.powerHours)).font(.caption)
                    ForEach(summary.measures.prefix(3), id: \.title) { line in
                        HStack(spacing: 4) {
                            Image(systemName: line.met == true ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(line.met == true ? .green : .secondary)
                            Text("\(line.title) \(line.value)")
                            Text(line.target).foregroundStyle(.secondary)
                        }
                        .font(.caption2)
                        .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    WidgetRing(summary: summary, lineWidth: 5)
                        .frame(width: 54, height: 54)
                    Spacer()
                    Text(summary.weekLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(next)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                Text(Format.powerHours(summary.powerHours))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Weiter: 2.1 Mentale Routinen" / "Alles erfasst" / "Abgeschlossen".
    private var next: String {
        if summary.isClosed { return "Tag abgeschlossen" }
        if let next = summary.nextCategory { return "Weiter: \(next)" }
        return summary.fill >= 1 ? "Alles erfasst – abschließen" : "Heute"
    }
}

// MARK: Week

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThaliaWeek", provider: SummaryProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "thalia://week"))
        }
        .configurationDisplayName("Woche")
        .description("Wochenwertung und die zehn Jahresziele – jedes 10 %.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SummaryEntry

    var body: some View {
        let summary = entry.summary
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                WeekRing(score: summary.weekScore, lineWidth: 5)
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Woche \(summary.weekLabel)").font(.headline)
                    Text("Jedes Jahresziel 10 %").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(summary.goalScores.enumerated()), id: \.offset) { index, score in
                    VStack(spacing: 2) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.15))
                            RoundedRectangle(cornerRadius: 3).fill(accent)
                                .frame(height: (family == .systemLarge ? 110 : 34) * CGFloat((score ?? 0) / 10))
                        }
                        .frame(height: family == .systemLarge ? 110 : 34)
                        Text("\(index + 1)").font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                    }
                }
            }
            if family == .systemLarge {
                ForEach(Array(zip(summary.goalTitles, summary.goalScores).enumerated()), id: \.offset) { index, pair in
                    HStack {
                        Text("\(index + 1) \(pair.0)").font(.caption)
                        Spacer()
                        Text(Format.score(pair.1, outOf: false)).font(.caption.monospacedDigit())
                    }
                }
            }
        }
    }
}

// MARK: Control Center (U11)

/// "Power-Hours erfassen" in Control Center, on the Lock Screen or the Action button: opens Thalia
/// at the power-hour sheet.
struct PowerHoursControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "at.binisoft.thalia.power-hours") {
            ControlWidgetButton(action: OpenPowerHoursIntent()) {
                Label("Power-Hours", systemImage: "bolt.fill")
            }
        }
        .displayName("Power-Hours erfassen")
        .description("Öffnet Thalia direkt beim Erfassen von Power-Hours.")
    }
}
