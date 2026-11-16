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
        let now = Date()
        let summary: TodaySummary = context.isPreview ? .placeholder : SummaryTimeline.stored().resolved(for: DayKey(date: now))
        completion(SummaryEntry(date: now, summary: summary))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SummaryEntry>) -> Void) {
        let plan = SummaryTimeline.plan(now: Date())
        completion(Timeline(entries: plan.entries, policy: .after(plan.refresh)))
    }
}

/// R4: one entry for now and one for midnight. The app writes tomorrow's snapshot ahead; without it the
/// widget turns into a neutral "Neuer Tag" by itself – a stale day never shows as "Heute" or
/// "Abgeschlossen".
enum SummaryTimeline {
    static func stored() -> TodaySummary {
        WidgetBridge.read() ?? .placeholder
    }

    static func plan(now: Date) -> (entries: [SummaryEntry], refresh: Date) {
        let summary = stored()
        let today = DayKey(date: now)
        let tomorrow = today.adding(days: 1)
        let midnight = tomorrow.startDate()
        let entries = [
            SummaryEntry(date: now, summary: summary.resolved(for: today)),
            SummaryEntry(date: midnight, summary: summary.resolved(for: tomorrow)),
        ]
        return (entries, midnight.addingTimeInterval(60))
    }
}

private let accent = Color("AccentColor")

/// Texts and states shared by every widget size (R4, R5, R17, R83, R90).
enum WidgetText {
    static func isNewDay(_ summary: TodaySummary) -> Bool { summary.isNewDay == true }
    static func hasNoPlan(_ summary: TodaySummary) -> Bool { summary.hasPlan == false }

    /// Ring fill: the score once closed, else how much is filled in; empty for a new day or without plan.
    static func progress(_ summary: TodaySummary) -> Double {
        if isNewDay(summary) || hasNoPlan(summary) { return 0 }
        if let score = summary.dayScore { return score / 10 }
        return summary.fill
    }

    static func isComplete(_ summary: TodaySummary) -> Bool {
        guard !isNewDay(summary), !hasNoPlan(summary), summary.dayScore == nil else { return false }
        return summary.fill >= 1
    }

    /// "62 %", "7,5" or "–".
    static func ringLabel(_ summary: TodaySummary) -> String {
        if isNewDay(summary) || hasNoPlan(summary) { return "–" }
        if let score = summary.dayScore { return Format.score(score) }
        return summary.fillText
    }

    /// The circular gauge's short value: "62", "7,5" or "–".
    static func gaugeLabel(_ summary: TodaySummary) -> String {
        if isNewDay(summary) || hasNoPlan(summary) { return "–" }
        if let score = summary.dayScore { return Format.score(score) }
        return "\(Int((summary.fill * 100).rounded()))"
    }

    /// R5: "offen" = the empty required items (`openCount`).
    static func status(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return "Neuer Tag" }
        if hasNoPlan(summary) { return "Kein Plan" }
        if summary.isClosed { return "Abgeschlossen" }
        return summary.openCount == 0 ? "Alles erfasst" : "\(summary.openCount) offen"
    }

    /// Medium widget: the heading over the open rows.
    static func openHeading(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return newDayText }
        if hasNoPlan(summary) { return "Kein Plan" }
        if summary.isClosed { return "Tag abgeschlossen" }
        return summary.openCount == 0 ? "Alles Wichtige erfasst" : "Noch zu tun · \(summary.openCount)"
    }

    /// Large widget: the line under the date.
    static func largeStatus(_ summary: TodaySummary) -> String {
        if isNewDay(summary) { return newDayText }
        if hasNoPlan(summary) { return "Kein Plan" }
        if summary.isClosed { return "Abgeschlossen" }
        return "\(summary.fillText) erfasst · \(summary.openCount) offen"
    }

    static let newDayText = "Neuer Tag – Thalia öffnen"

    /// R90: "Mo, 16. Nov. · Arbeitstag".
    static func dateLine(_ summary: TodaySummary) -> String {
        let type = (summary.dayType ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return type.isEmpty ? summary.day : "\(summary.day) · \(type)"
    }

    /// R90: the plan's note for the day ("Besonderheit"), nil when empty.
    static func note(_ summary: TodaySummary) -> String? {
        let text = (summary.dayNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// R17: amounts to the cent.
    static func money(_ value: Double) -> String { Format.euro(value) }

    /// A weekly target's "value / target": "12,50 € / 50 €" for euros (R17), else "6 / 8 PH".
    static func targetAmount(_ line: TodaySummary.GoalLine) -> String {
        if Units.normalized(line.unit) == "€" {
            return "\(Format.euro(line.value)) / \(Format.euro(line.target))"
        }
        return "\(Format.number(line.value)) / \(Format.number(line.target)) \(line.unit)"
    }

    /// R83: "14/28 Woche" next to the power-hour bar.
    static func focusWeekText(_ summary: TodaySummary) -> String? {
        guard let target = summary.powerHoursTarget, target > 0 else { return nil }
        return "\(Format.number(summary.powerHoursWeek))/\(Format.number(target)) Woche"
    }

    static func focusFraction(_ summary: TodaySummary) -> Double {
        guard let target = summary.powerHoursTarget, target > 0 else { return 0 }
        return min(1, summary.powerHoursWeek / target)
    }

    /// R87: the open rows with their item keys (nil keys: a snapshot of an older app version, or the
    /// day is closed – then the rows only show).
    static func openRows(_ summary: TodaySummary, limit: Int) -> [WidgetOpenRow] {
        guard !isNewDay(summary) else { return [] }
        let keys: [String] = summary.openKeys ?? []
        let canTick = !summary.isClosed && keys.count == summary.open.count
        return summary.open.prefix(limit).enumerated().map { index, text in
            WidgetOpenRow(index: index, text: text, key: canTick ? keys[index] : nil)
        }
    }

    /// Medium widget: three rows, two when the day's note takes a line.
    static func mediumRowLimit(_ summary: TodaySummary) -> Int {
        note(summary) == nil ? 3 : 2
    }
}

/// One open item on the widget (R87).
struct WidgetOpenRow: Identifiable {
    let index: Int
    let text: String
    let key: String?
    var id: String { key ?? "\(index)|\(text)" }

    /// "1.1 Protein" → "1.1" (for the goal colour).
    var categoryKey: String { String(text.split(separator: " ").first ?? "") }
}

/// How much of today is filled in; once the day is closed, its score. Empty for a new day (R4).
struct WidgetRing: View {
    let summary: TodaySummary
    var lineWidth: CGFloat = 6

    var body: some View {
        let progress: Double = WidgetText.progress(summary)
        let tint: Color = WidgetText.isComplete(summary) ? Color.green : accent
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(WidgetText.ringLabel(summary))
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

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SummaryEntry

    private var summary: TodaySummary { entry.summary }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: WidgetText.progress(summary), in: 0...1) {
                Image(systemName: summary.isClosed ? "checkmark.seal" : "checklist")
            } currentValueLabel: {
                Text(WidgetText.gaugeLabel(summary))
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(rectangularTitle)
                    .font(.headline)
                    .lineLimit(1)
                Text(rectangularLine)
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
        let powerHours = Format.powerHours(summary.powerHours)
        if WidgetText.isNewDay(summary) { return WidgetText.newDayText }
        if WidgetText.hasNoPlan(summary) { return "Kein Plan · \(powerHours)" }
        if summary.isClosed { return "Tag \(Format.score(summary.dayScore, outOf: false)) · \(powerHours)" }
        return "\(summary.fillText) · \(summary.openCount) offen · \(powerHours)"
    }

    private var rectangularTitle: String {
        if WidgetText.isNewDay(summary) { return "Neuer Tag" }
        if WidgetText.hasNoPlan(summary) { return "Kein Plan" }
        if summary.isClosed { return "Tag \(Format.score(summary.dayScore, outOf: true))" }
        return "Heute \(summary.fillText) · \(summary.openCount) offen"
    }

    private var rectangularLine: String {
        if WidgetText.isNewDay(summary) || WidgetText.hasNoPlan(summary) { return "Thalia öffnen" }
        return summary.open.first ?? "Alles Wichtige erfasst"
    }

    private var moneyAndFocus: String {
        var parts: [String] = [Format.powerHours(summary.powerHours)]
        if let expenses = summary.expensesToday { parts.append(WidgetText.money(expenses)) }
        return parts.joined(separator: " · ")
    }

    // MARK: Small

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                WidgetRing(summary: summary, lineWidth: 6)
                    .frame(width: 58, height: 58)
                Spacer(minLength: 0)
                Text(WidgetText.dateLine(summary))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            if WidgetText.isNewDay(summary) {
                Text(WidgetText.newDayText)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
            } else {
                Text(WidgetText.status(summary))
                    .font(.subheadline.weight(.bold))
            }
            Label(Format.powerHours(summary.powerHours), systemImage: "bolt.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GoalPalette.color(goal: "3"))
        }
    }

    // MARK: Medium

    private var medium: some View {
        let note = WidgetText.note(summary)
        let rows = WidgetText.openRows(summary, limit: WidgetText.mediumRowLimit(summary))
        let caption: String = summary.isClosed ? "abgeschlossen" : WidgetText.dateLine(summary)
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                WidgetRing(summary: summary, lineWidth: 7)
                    .frame(width: 70, height: 70)
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(WidgetText.openHeading(summary))
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                if let note {
                    NoteLine(text: note)
                }
                ForEach(rows) { row in
                    OpenRowButton(row: row, dayKey: summary.dayKey ?? "")
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    Link(destination: URL(string: "thalia://focus")!) {
                        FocusChip(summary: summary)
                    }
                    if let expenses = summary.expensesToday {
                        Link(destination: URL(string: "thalia://expense")!) {
                            Label(WidgetText.money(expenses), systemImage: "eurosign.circle.fill")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(GoalPalette.color(goal: "8"))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Large

    private var large: some View {
        let note = WidgetText.note(summary)
        let rows = WidgetText.openRows(summary, limit: 4)
        let showsNext = !summary.isClosed && !WidgetText.isNewDay(summary)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                WidgetRing(summary: summary, lineWidth: 7)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heute · \(WidgetText.dateLine(summary))")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(WidgetText.largeStatus(summary))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let note {
                        NoteLine(text: note)
                    }
                    if let next = summary.nextCategory, showsNext {
                        Text("Weiter: \(next)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rows) { row in
                        OpenRowButton(row: row, dayKey: summary.dayKey ?? "")
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
                    WidgetTile(symbol: "bolt.fill", title: "Fokus", value: "\(Format.powerHours(summary.powerHours)) heute",
                               detail: focusDetail, tint: GoalPalette.color(goal: "3"), fraction: focusBar)
                }
                Link(destination: URL(string: "thalia://expense")!) {
                    WidgetTile(symbol: "eurosign.circle.fill", title: "Ausgaben",
                               value: WidgetText.money(summary.expensesToday ?? 0),
                               detail: expensesWeekText, tint: GoalPalette.color(goal: "8"))
                }
                Link(destination: URL(string: "thalia://week")!) {
                    WidgetTile(symbol: "calendar", title: "Woche", value: Format.score(summary.weekScore, outOf: false),
                               detail: summary.weekLabel, tint: accent)
                }
            }
        }
    }

    private var expensesWeekText: String {
        guard let week = summary.expensesWeek else { return "erfassen" }
        return "Woche \(WidgetText.money(week))"
    }

    /// R83: "14/28 Woche" under today's power-hours, else "Woche".
    private var focusDetail: String {
        WidgetText.focusWeekText(summary) ?? "Woche"
    }

    /// The week's power-hour bar, only with a weekly target.
    private var focusBar: Double? {
        guard WidgetText.focusWeekText(summary) != nil else { return nil }
        return WidgetText.focusFraction(summary)
    }
}

/// R87: an open row is a button that ticks the item (✓ only – ½, ✗ and "Entfällt" stay in the app);
/// without an item key it only shows.
private struct OpenRowButton: View {
    let row: WidgetOpenRow
    let dayKey: String

    var body: some View {
        if let key = row.key {
            Button(intent: MarkDoneFromWidgetIntent(itemKey: key, dayKey: dayKey)) {
                OpenLine(text: row.text, categoryKey: row.categoryKey, isButton: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(row.text), als erledigt markieren")
        } else {
            OpenLine(text: row.text, categoryKey: row.categoryKey, isButton: false)
        }
    }
}

private struct OpenLine: View {
    let text: String
    let categoryKey: String
    let isButton: Bool

    var body: some View {
        let tint = GoalPalette.color(category: categoryKey)
        HStack(spacing: 6) {
            if isButton {
                Image(systemName: "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            } else {
                Circle()
                    .strokeBorder(tint, lineWidth: 1.5)
                    .frame(width: 9, height: 9)
            }
            Text(text)
                .font(.caption)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}

/// R90: the plan's note for the day ("Besonderheit").
private struct NoteLine: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
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
                Text(WidgetText.targetAmount(line))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(GoalPalette.color(category: line.categoryKey).opacity(0.18))
                    Capsule().fill(GoalPalette.color(category: line.categoryKey))
                        .frame(width: max(4, geometry.size.width * CGFloat(line.fraction)))
                }
            }
            .frame(height: 5)
        }
    }
}

/// A thin bar in a goal's colour (power-hours of the week, R83).
private struct WidgetBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.18))
                Capsule().fill(tint).frame(width: max(4, geometry.size.width * CGFloat(fraction)))
            }
        }
    }
}

/// Today's power-hours; with a weekly target the week's bar and "14/28 Woche" next to it (R83).
private struct FocusChip: View {
    let summary: TodaySummary

    var body: some View {
        let tint = GoalPalette.color(goal: "3")
        VStack(alignment: .leading, spacing: 3) {
            Label("\(Format.powerHours(summary.powerHours)) heute", systemImage: "bolt.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
            if let week = WidgetText.focusWeekText(summary) {
                HStack(spacing: 5) {
                    WidgetBar(fraction: WidgetText.focusFraction(summary), tint: tint)
                        .frame(width: 56, height: 4)
                    Text(week)
                        .font(.system(size: 9, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)
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
    /// A bar next to the detail (power-hours of the week, R83).
    var fraction: Double? = nil

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
            HStack(spacing: 4) {
                if let fraction {
                    WidgetBar(fraction: fraction, tint: tint)
                        .frame(width: 24, height: 4)
                }
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
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
