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
        CaptureControl()
        PowerHoursControl()
        ExpenseControl()
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
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(URL(string: "thalia://glance"))
        }
        .configurationDisplayName("Heute")
        .description("Was heute läuft: wie viel erfasst ist, was noch offen ist, Power-Hours, Ausgaben – groß auch die Wochenziele.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// A soft tint behind the home-screen widgets (the system draws its own on the Lock Screen).
struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [accent.opacity(0.16), accent.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// The goal colours (same as the app's palette).
func widgetGoalColor(_ key: String) -> Color {
    let colors: [Color] = [
        Color(red: 0.93, green: 0.42, blue: 0.33), Color(red: 0.55, green: 0.38, blue: 0.86), Color(red: 0.05, green: 0.55, blue: 0.60),
        Color(red: 0.30, green: 0.36, blue: 0.80), Color(red: 0.88, green: 0.62, blue: 0.12), Color(red: 0.90, green: 0.36, blue: 0.58),
        Color(red: 0.36, green: 0.52, blue: 0.62), Color(red: 0.20, green: 0.62, blue: 0.36), Color(red: 0.95, green: 0.50, blue: 0.18),
        Color(red: 0.76, green: 0.28, blue: 0.44),
    ]
    let number: Int = Int(key.split(separator: ".").first.map(String.init) ?? key) ?? 1
    return colors[(max(1, number) - 1) % colors.count]
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
                Text(summary.dayScore.map { Format.score($0) } ?? "\(Int((summary.fill * 100).rounded()))")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.isClosed ? "Tag \(Format.score(summary.dayScore, outOf: true))" : "Heute \(summary.fillText) · \(summary.openCount) offen")
                    .font(.headline)
                    .lineLimit(1)
                Text(summary.open.first ?? "Alles Wichtige erfasst")
                    .font(.caption)
                    .lineLimit(1)
                Text(moneyAndFocus)
                    .font(.caption)
                    .lineLimit(1)
            }
        case .systemSmall:
            small
        case .systemMedium:
            medium
        default:
            large
        }
    }

    private var inlineText: String {
        if summary.isClosed { return "Tag \(Format.score(summary.dayScore, outOf: false)) · \(Format.powerHours(summary.powerHours))" }
        return "\(summary.fillText) · \(summary.openCount) offen · \(Format.powerHours(summary.powerHours))"
    }

    private var moneyAndFocus: String {
        var parts: [String] = [Format.powerHours(summary.powerHours)]
        if let expenses = summary.expensesToday { parts.append(Format.measure(expenses, unit: "€")) }
        return parts.joined(separator: " · ")
    }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                WidgetRing(summary: summary, lineWidth: 6)
                    .frame(width: 58, height: 58)
                Spacer(minLength: 0)
                Text(summary.day)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            Spacer(minLength: 0)
            Text(summary.isClosed ? "Abgeschlossen" : (summary.openCount == 0 ? "Alles erfasst" : "\(summary.openCount) offen"))
                .font(.subheadline.weight(.bold))
            Label(Format.powerHours(summary.powerHours), systemImage: "bolt.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(widgetGoalColor("3"))
        }
    }

    // MARK: Medium

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetRing(summary: summary, lineWidth: 7)
                    .frame(width: 70, height: 70)
                Text(summary.isClosed ? "abgeschlossen" : summary.day)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(summary.openCount == 0 ? "Alles Wichtige erfasst" : "Noch zu tun · \(summary.openCount)")
                    .font(.caption.weight(.bold))
                ForEach(summary.open.prefix(3), id: \.self) { line in
                    OpenLine(text: line)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Link(destination: URL(string: "thalia://focus")!) {
                        FocusChip(summary: summary)
                    }
                    if let expenses = summary.expensesToday {
                        Link(destination: URL(string: "thalia://expense")!) {
                            Label(Format.measure(expenses, unit: "€"), systemImage: "eurosign.circle.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(widgetGoalColor("8"))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Large

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                WidgetRing(summary: summary, lineWidth: 7)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heute · \(summary.day)")
                        .font(.headline)
                    Text(summary.isClosed ? "Abgeschlossen" : "\(summary.fillText) erfasst · \(summary.openCount) offen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let next = summary.nextCategory, !summary.isClosed {
                        Text("Weiter: \(next)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            if !summary.open.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(summary.open.prefix(4), id: \.self) { line in
                        OpenLine(text: line)
                    }
                }
            }
            if !summary.weekly.isEmpty {
                Divider()
                Text("Wochenziele · \(summary.weekLabel)")
                    .font(.caption.weight(.bold))
                ForEach(summary.weekly.prefix(3), id: \.title) { line in
                    WeeklyLine(line: line)
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Link(destination: URL(string: "thalia://focus")!) {
                    WidgetTile(symbol: "bolt.fill", title: "Fokus", value: Format.powerHours(summary.powerHoursWeek),
                               detail: summary.powerHoursTarget.map { "von \(Format.number($0)) PH" } ?? "Woche", tint: widgetGoalColor("3"))
                }
                Link(destination: URL(string: "thalia://expense")!) {
                    WidgetTile(symbol: "eurosign.circle.fill", title: "Ausgaben",
                               value: Format.measure(summary.expensesToday ?? 0, unit: "€"),
                               detail: summary.expensesWeek.map { "Woche \(Format.measure($0, unit: "€"))" } ?? "erfassen", tint: widgetGoalColor("8"))
                }
                Link(destination: URL(string: "thalia://week")!) {
                    WidgetTile(symbol: "calendar", title: "Woche", value: Format.score(summary.weekScore, outOf: false),
                               detail: summary.weekLabel, tint: accent)
                }
            }
        }
    }
}

private struct OpenLine: View {
    let text: String

    var body: some View {
        let key: String = String(text.split(separator: " ").first ?? "")
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(widgetGoalColor(key), lineWidth: 1.5)
                .frame(width: 9, height: 9)
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

private struct WeeklyLine: View {
    let line: TodaySummary.GoalLine

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(line.title)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(Format.number(line.value)) / \(Format.number(line.target)) \(line.unit)")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(widgetGoalColor(line.categoryKey).opacity(0.18))
                    Capsule().fill(widgetGoalColor(line.categoryKey))
                        .frame(width: max(4, geometry.size.width * CGFloat(line.fraction)))
                }
            }
            .frame(height: 5)
        }
    }
}

private struct FocusChip: View {
    let summary: TodaySummary

    var body: some View {
        let fraction: Double = summary.powerHoursTarget.map { $0 > 0 ? min(1, summary.powerHoursWeek / $0) : 0 } ?? 0
        VStack(alignment: .leading, spacing: 3) {
            Label("\(Format.powerHours(summary.powerHours)) heute", systemImage: "bolt.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(widgetGoalColor("3"))
            if summary.powerHoursTarget != nil {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(widgetGoalColor("3").opacity(0.18))
                        Capsule().fill(widgetGoalColor("3")).frame(width: max(4, geometry.size.width * CGFloat(fraction)))
                    }
                }
                .frame(width: 80, height: 4)
            }
        }
    }
}

private struct WidgetTile: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 12, style: .continuous))
    }
}

// MARK: Week

struct WeekWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThaliaWeek", provider: SummaryProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
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

// MARK: Control Center (U11, F3)

/// "Thalia erfassen": opens the app at "Erfassen" (power-hours, spending, measurement, note …).
struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "at.binisoft.thalia.capture") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Thalia erfassen", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Thalia erfassen")
        .description("Öffnet Thalia im Fenster „Erfassen“.")
    }
}

/// "Ausgabe erfassen": opens the app at the spending sheet, amount field ready.
struct ExpenseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "at.binisoft.thalia.expense") {
            ControlWidgetButton(action: OpenExpenseIntent()) {
                Label("Ausgabe", systemImage: "eurosign.circle.fill")
            }
        }
        .displayName("Ausgabe erfassen")
        .description("Öffnet Thalia bei den Ausgaben.")
    }
}

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
