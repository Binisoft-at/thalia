import WidgetKit
import SwiftUI
import ThaliaCore

/// R86: Thalia on the watch face and in the Smart Stack – ring, what is open and today's power-hours.
/// It shows the snapshot the watch app wrote last (own changes, iCloud imports, opening the app) and
/// turns into "Neuer Tag" at midnight by itself. A tap opens the watch app.
@main
struct ThaliaWatchWidgets: WidgetBundle {
    var body: some Widget {
        TodayComplication()
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let summary: TodaySummary
    let relevance: TimelineEntryRelevance?
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), summary: .placeholder, relevance: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let now = Date()
        let summary: TodaySummary = context.isPreview ? .placeholder : ComplicationTimeline.stored().resolved(for: DayKey(date: now))
        completion(ComplicationEntry(date: now, summary: summary, relevance: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let plan = ComplicationTimeline.plan(now: Date())
        completion(Timeline(entries: plan.entries, policy: .after(plan.refresh)))
    }
}

/// The iPhone widget's timeline (R4) – now, then "Neuer Tag" at midnight – plus an evening entry:
/// from 20:00 the complication is more relevant while the day is open, so the Smart Stack moves it up.
enum ComplicationTimeline {
    static let eveningHour = 20

    static func stored() -> TodaySummary {
        WidgetBridge.read() ?? .placeholder
    }

    static func plan(now: Date, calendar: Calendar = .current) -> (entries: [ComplicationEntry], refresh: Date) {
        let summary = stored()
        let today = DayKey(date: now)
        let tomorrow = today.adding(days: 1)
        let midnight = tomorrow.startDate()
        let current = summary.resolved(for: today)
        var entries = [ComplicationEntry(date: now, summary: current, relevance: relevance(current, at: now, calendar: calendar))]
        if let evening = calendar.date(bySettingHour: eveningHour, minute: 0, second: 0, of: now), evening > now, evening < midnight {
            entries.append(ComplicationEntry(date: evening, summary: current, relevance: relevance(current, at: evening, calendar: calendar)))
        }
        let next = summary.resolved(for: tomorrow)
        entries.append(ComplicationEntry(date: midnight, summary: next, relevance: relevance(next, at: midnight, calendar: calendar)))
        return (entries, midnight.addingTimeInterval(60))
    }

    static func relevance(_ summary: TodaySummary, at date: Date, calendar: Calendar) -> TimelineEntryRelevance {
        let isEvening = calendar.component(.hour, from: date) >= eveningHour
        if isEvening && !summary.isClosed && !summary.isExcusedDay {
            return TimelineEntryRelevance(score: 1)
        }
        return TimelineEntryRelevance(score: 0.2)
    }
}

private let accent = Color("AccentColor")

/// Texts and states of the complication (same rules as the iPhone widget, R4/R5).
enum ComplicationText {
    static func isNewDay(_ summary: TodaySummary) -> Bool { summary.isNewDay == true }
    static func hasNoPlan(_ summary: TodaySummary) -> Bool { summary.hasPlan == false }

    static func progress(_ summary: TodaySummary) -> Double {
        if isNewDay(summary) || hasNoPlan(summary) || summary.isExcusedDay { return 0 }
        if let score = summary.dayScore { return score / 10 }
        return summary.fill
    }

    static func isComplete(_ summary: TodaySummary) -> Bool {
        guard !isNewDay(summary), !hasNoPlan(summary), !summary.isExcusedDay, summary.dayScore == nil else { return false }
        return summary.fill >= 1
    }

    /// "62", "7,5" or "–" (also on a sick or holiday day, v8).
    static func ringLabel(_ summary: TodaySummary) -> String {
        if isNewDay(summary) || hasNoPlan(summary) || summary.isExcusedDay { return "–" }
        if let score = summary.dayScore { return Format.score(score) }
        return "\(Int((summary.fill * 100).rounded()))"
    }

    static func powerHours(_ summary: TodaySummary) -> String {
        Format.powerHours(summary.powerHours)
    }

    /// Rectangular, first line.
    static func title(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return "Neuer Tag" }
        if hasNoPlan(summary) { return "Kein Plan" }
        if summary.isExcusedDay { return "Heute \(summary.excusedName)" }
        if summary.isClosed { return "Tag \(Format.score(summary.dayScore, outOf: true))" }
        return "Heute \(summary.fillText)"
    }

    /// Rectangular, second line: "11 offen · 4 PH"; v8: "zählt nicht · 0 PH".
    static func line(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return "Thalia öffnen" }
        if hasNoPlan(summary) { return powerHours(summary) }
        if summary.isExcusedDay { return "zählt nicht · \(powerHours(summary))" }
        if summary.isClosed { return "Abgeschlossen · \(powerHours(summary))" }
        return "\(summary.openCount) offen · \(powerHours(summary))"
    }

    static func inline(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return "Neuer Tag – Thalia öffnen" }
        if hasNoPlan(summary) { return "Kein Plan · \(powerHours(summary))" }
        if summary.isExcusedDay { return "\(summary.excusedText) · \(powerHours(summary))" }
        if summary.isClosed { return "Tag \(Format.score(summary.dayScore, outOf: false)) · \(powerHours(summary))" }
        return "\(summary.fillText) · \(summary.openCount) offen · \(powerHours(summary))"
    }

    /// The curved label in a corner.
    static func corner(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return "Neuer Tag" }
        if hasNoPlan(summary) { return "Kein Plan" }
        if summary.isExcusedDay { return summary.excusedName }
        if summary.isClosed { return "Tag \(Format.score(summary.dayScore, outOf: false))" }
        return "\(summary.openCount) offen · \(powerHours(summary))"
    }

    /// VoiceOver for every family.
    static func accessibility(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return "Thalia, neuer Tag" }
        if hasNoPlan(summary) { return "Thalia, kein Plan, \(powerHours(summary))" }
        if summary.isExcusedDay { return "Thalia, \(summary.excusedName), der Tag zählt nicht, \(powerHours(summary))" }
        if summary.isClosed { return "Thalia, Tag abgeschlossen, Wertung \(Format.score(summary.dayScore, outOf: false))" }
        return "Thalia, \(summary.fillText) erfasst, \(summary.openCount) offen, \(powerHours(summary))"
    }
}

struct TodayComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ThaliaWatchToday", provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heute")
        .description("Ring, Offenes und Power-Hours von heute – ein Tipp öffnet Thalia.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry

    private var summary: TodaySummary { entry.summary }

    var body: some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ComplicationText.accessibility(summary))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                ComplicationRing(summary: summary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ComplicationText.title(summary))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(ComplicationText.line(summary))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Text(ComplicationText.inline(summary))
        case .accessoryCorner:
            Text(ComplicationText.ringLabel(summary))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.6)
                .widgetLabel {
                    Text(ComplicationText.corner(summary))
                }
        default:
            ComplicationRing(summary: summary)
        }
    }
}

/// The day as a ring: how much is filled in, the score once closed, empty for a new day.
struct ComplicationRing: View {
    let summary: TodaySummary

    var body: some View {
        let tint: Color = ComplicationText.isComplete(summary) ? Color.green : accent
        Gauge(value: ComplicationText.progress(summary), in: 0...1) {
            Image(systemName: "checklist")
        } currentValueLabel: {
            Text(ComplicationText.ringLabel(summary))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(tint)
    }
}
