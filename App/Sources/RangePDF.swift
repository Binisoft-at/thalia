import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
#endif

// v8 (decision 10): "PDF-Bericht" over several weeks. A cover with the average, the weeks as bars
// and the ten goals with their trend; one table line per week; power-hours per area and per week;
// then – if chosen – each week's own pages (cover and tables, the review texts). Pages are numbered
// through, drawn one by one with progress, and the finished file is shown with PDFKit.

// MARK: Choices

/// "Letzte 4 Wochen" … "Eigener Zeitraum".
enum PDFRangePreset: String, CaseIterable, Identifiable {
    case fourWeeks, eightWeeks, thirteenWeeks, segment, goalYear, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fourWeeks: "Letzte 4 Wochen"
        case .eightWeeks: "Letzte 8 Wochen"
        case .thirteenWeeks: "Letzte 13 Wochen"
        case .segment: "Aktueller Abschnitt"
        case .goalYear: "Zieljahr bis heute"
        case .custom: "Eigener Zeitraum"
        }
    }

    /// v10 (§1.4.3): "Aktueller Abschnitt" only when the goal year has more than one.
    static func choices(hasSegments: Bool) -> [PDFRangePreset] {
        hasSegments ? allCases : allCases.filter { $0 != .segment }
    }

    /// The weeks; nil for the own range. `lastWeek` is the last finished week (this week once it
    /// is closed), the goal year runs through this week. v10: `segment` – the current segment, from its
    /// first week through this week (the goal year without one).
    func range(lastWeek: WeekKey, today: DayKey, period: GoalPeriod, segment: SegmentSpan? = nil) -> RangePDFWeeks? {
        switch self {
        case .fourWeeks: return RangePDFWeeks(from: lastWeek.adding(weeks: -3), through: lastWeek)
        case .eightWeeks: return RangePDFWeeks(from: lastWeek.adding(weeks: -7), through: lastWeek)
        case .thirteenWeeks: return RangePDFWeeks(from: lastWeek.adding(weeks: -12), through: lastWeek)
        case .segment: return RangePDFWeeks(from: segment?.startWeek ?? period.start.week, through: today.week)
        case .goalYear: return RangePDFWeeks(from: period.start.week, through: today.week)
        case .custom: return nil
        }
    }
}

/// The weeks a report covers, oldest first.
struct RangePDFWeeks: Hashable {
    let from: WeekKey
    let through: WeekKey

    /// The earlier week becomes `from`.
    init(from: WeekKey, through: WeekKey) {
        if through < from {
            self.from = through
            self.through = from
        } else {
            self.from = from
            self.through = through
        }
    }

    var id: String { from.string + "|" + through.string }

    /// Calendar weeks in the range.
    var count: Int { (through.monday.ordinal - from.monday.ordinal) / 7 + 1 }

    /// "KW40–KW47 2026", "KW52 2026 – KW3 2027", "KW45 2026".
    var title: String {
        if from == through { return from.longLabel }
        if from.year == through.year { return "\(from.label)–\(through.label) \(through.year)" }
        return "\(from.longLabel) – \(through.longLabel)"
    }

    /// "28. Sep. – 22. Nov. 2026", "28. Dez. 2026 – 3. Jan. 2027"; v11 P1.8: one week as `rangeLabelWithYear`
    /// ("16.–22. Nov. 2026").
    var dateText: String {
        if from == through { return from.rangeLabelWithYear }
        let start: DayKey = from.monday
        let end: DayKey = through.sunday
        if start.year == end.year { return "\(RangePDFWeeks.dayText(start)) – \(RangePDFWeeks.dayText(end)) \(end.year)" }
        return "\(RangePDFWeeks.dayText(start)) \(start.year) – \(RangePDFWeeks.dayText(end)) \(end.year)"
    }

    /// "Thalia-2026-W40-bis-2026-W47.pdf".
    var fileName: String {
        from == through ? "Thalia-\(from.string)-Bericht.pdf" : "Thalia-\(from.string)-bis-\(through.string).pdf"
    }

    /// "28. Sep." (the short label without the weekday).
    static func dayText(_ day: DayKey) -> String {
        let label: String = day.shortLabel
        guard let comma = label.firstIndex(of: ",") else { return label }
        return String(label[label.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
    }
}

/// What the report holds besides the overview pages.
enum RangePDFScope: String, CaseIterable, Identifiable {
    case overview, weeks, reviews

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Nur Übersicht"
        case .weeks: "+ Wochenübersicht je Woche"
        case .reviews: "+ Rückblick-Texte"
        }
    }

    var detail: String {
        switch self {
        case .overview: "Deckblatt, eine Zeile je Woche und die Power-Hours."
        case .weeks: "Dazu je Woche mit Plan ihr Deckblatt und die Tabellen mit ✓ ½ ✗ –."
        case .reviews: "Dazu die beantworteten Fragen der Wochenreflexion und die Notizen zum Tag."
        }
    }

    /// The pages of each week with a plan (none for the overview only).
    var sections: WeekPDFSections {
        switch self {
        case .overview: []
        case .weeks: [.cover, .tables]
        case .reviews: [.cover, .review, .answeredOnly, .tables]
        }
    }
}

// MARK: Data

/// How a week counts in the report: the tag in the table and the colour of its bar.
enum RangeWeekState: Equatable {
    case closed, running, open, paper, archive, old, excused, unscored

    /// "" · "läuft" · "offen" · "Papier" · "Archiv" · "vor KW42" · "entschuldigt" · "ohne Wertung".
    var tag: String {
        switch self {
        case .closed: ""
        case .running: "läuft"
        case .open: "offen"
        case .paper: "Papier"
        case .archive: "Archiv"
        case .old: "vor KW42"
        case .excused: WeekScore.excusedLabel
        case .unscored: "ohne Wertung"
        }
    }

    /// The same order as the Rückblick: sick/holiday week, running week, archive grades (v9), paper
    /// score, earlier model, never closed (R70), no score.
    static func of(_ line: WeekLine, context: WeekContext, current: WeekKey) -> RangeWeekState {
        if line.isExcused { return .excused }
        if line.week >= current, !line.isClosed { return .running }
        if line.isArchive, !context.hasPlan { return .archive }
        if line.isPaperOnly { return .paper }
        if line.isOldScoring { return .old }
        if !line.isClosed, context.plan?.recordedScore == nil { return .open }
        if line.score == nil { return .unscored }
        return .closed
    }

    /// The bar and score colour (the Rückblick's series colours).
    static func tint(_ line: WeekLine, state: RangeWeekState) -> Color {
        if line.isOldScoring { return PDFStyle.muted.opacity(0.55) }
        switch state {
        case .running: return Brand.accent.opacity(0.45)
        case .open: return Color.orange
        default: return Brand.accent
        }
    }
}

/// One week in the report: its line, its context and how it counts.
struct RangePDFRow: Identifiable {
    let line: WeekLine
    let context: WeekContext
    let state: RangeWeekState
    /// v11 P6.1, P6.13: the week lies before the current segment (its context is read without the goal year, so it
    /// can't tell) – a closed one shows its stored score on its own cover too.
    var isFrozen = false

    var id: String { line.week.string }
    var week: WeekKey { line.week }
    /// Week pages only for weeks with a plan; paper weeks are a line in the overview.
    var hasPages: Bool { context.hasPlan }
    var tint: Color { RangeWeekState.tint(line, state: state) }
}

/// Everything the report draws, read once (the sheet reads the weeks one by one).
@MainActor
struct RangePDFData {
    let weeks: RangePDFWeeks
    let rows: [RangePDFRow]
    let report: RangeReport
    let goals: [AnnualGoal]

    /// Weeks per overview page (22 pt rows).
    static let rowsPerPage = 28

    /// `isFrozen`: the freeze rule read once (`TrackerStore.freezeRule`), for weeks read without the goal year (P6.13).
    init(weeks: RangePDFWeeks, contexts: [WeekContext], report: RangeReport, today: DayKey, isFrozen: (WeekKey) -> Bool = { _ in false }) {
        self.weeks = weeks
        self.report = report
        var lines: [String: WeekLine] = [:]
        for line in report.lines { lines[line.week.string] = line }
        self.rows = contexts.compactMap { context -> RangePDFRow? in
            guard let line = lines[context.week.string] else { return nil }
            return RangePDFRow(line: line, context: context, state: RangeWeekState.of(line, context: context, current: today.week),
                               isFrozen: isFrozen(context.week))
        }
        self.goals = contexts.last?.goals ?? []
    }

    var isEmpty: Bool { rows.isEmpty }
    var title: String { weeks.title }

    /// "8 Wochen · 6 bewertet · 1 entschuldigt".
    var countText: String {
        var parts: [String] = [Format.count(rows.count, "Woche", "Wochen"), "\(report.scoredWeeks) bewertet"]
        if report.excusedWeeks > 0 { parts.append("\(report.excusedWeeks) \(WeekScore.excusedLabel)") }
        if let old = report.oldAverage { parts.append("Ø vor KW42 " + Format.score(old)) }
        return parts.joined(separator: " · ")
    }

    var planRows: [RangePDFRow] { rows.filter(\.hasPages) }

    /// Days that count in the weeks with a plan (sick and holiday days don't).
    var countedDays: Int { planRows.reduce(0) { $0 + 7 - $1.line.excusedDays } }

    /// v11 P6.2: closed days of the weeks with a plan – counted like `countedDays`, without sick and holiday days
    /// (`WeekLine.closedDays`), so "Tage abgeschlossen" never shows more than it counts.
    var closedCountedDays: Int { planRows.reduce(0) { $0 + $1.line.closedDays } }

    /// v11 P6.2: weeks that are done – closed, or without items (a paper or archive week has only its score or
    /// grades); the running week counts as open, also before it has a plan.
    var finishedWeeks: Int {
        rows.filter { row in
            guard row.state != .running else { return false }
            return row.line.isClosed || !row.hasPages
        }.count
    }

    func goalLine(_ key: String) -> RangeReport.GoalLine? {
        report.goals.first { $0.key == key }
    }

    /// The overview's pages (at least one).
    var overviewChunks: [[RangePDFRow]] {
        guard !rows.isEmpty else { return [[]] }
        return stride(from: 0, to: rows.count, by: RangePDFData.rowsPerPage).map { start in
            Array(rows[start..<min(rows.count, start + RangePDFData.rowsPerPage)])
        }
    }

    /// The power-hours page, when the weeks have work or a target.
    var hasWorkPage: Bool { report.powerHours > 0 || report.powerHoursTarget != nil }

    /// Cover, overview pages and the power-hours page.
    var summaryPageCount: Int { 1 + overviewChunks.count + (hasWorkPage ? 1 : 0) }

    /// A week's own pages with `scope` (none for paper weeks).
    func weekPageCount(_ row: RangePDFRow, scope: RangePDFScope) -> Int {
        let sections: WeekPDFSections = scope.sections
        guard row.hasPages, !sections.isEmpty else { return 0 }
        return PDFExport.weekPageCount(row.context, sections: sections)
    }

    /// Every page of the report with `scope`.
    func pageCount(_ scope: RangePDFScope) -> Int {
        summaryPageCount + rows.reduce(0) { $0 + weekPageCount($1, scope: scope) }
    }
}

/// A bookmark in the finished PDF (0-based page).
private struct RangePDFBookmark {
    let title: String
    let page: Int
}

// MARK: Rendering

extension PDFExport {
    /// v8: the report over several weeks as one PDF, drawn page by page (`Task.yield()` and a short
    /// pause after each, so the progress shows); with title, creator and a bookmark per week.
    /// nil when cancelled or the file can't be written.
    static func makeRange(_ data: RangePDFData, scope: RangePDFScope, progress: (Int, Int) -> Void) async -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(data.weeks.fileName)
        let total: Int = data.pageCount(scope)
        let title: String = "Thalia · Bericht " + data.title
        var box = CGRect(origin: .zero, size: pageSize)
        let info: [String: Any] = [kCGPDFContextTitle as String: title, kCGPDFContextCreator as String: "Thalia"]
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, info as CFDictionary) else { return nil }
        var drawn = 0
        var bookmarks: [RangePDFBookmark] = [RangePDFBookmark(title: "Deckblatt", page: 0),
                                             RangePDFBookmark(title: "Übersicht je Woche", page: 1)]
        if data.hasWorkPage { bookmarks.append(RangePDFBookmark(title: "Power-Hours", page: data.summaryPageCount - 1)) }
        for page in rangeSummaryPages(data, total: total) {
            render(page, into: pdf, vectorBands: true)
            drawn += 1
            progress(drawn, total)
            guard await pause() else {
                pdf.closePDF()
                return nil
            }
        }
        for row in data.rows where data.weekPageCount(row, scope: scope) > 0 {
            bookmarks.append(RangePDFBookmark(title: "\(row.week.longLabel) · \(row.week.rangeLabel)", page: drawn))
            // Built only now, one week at a time.
            for page in weekPages(row.context, sections: scope.sections, firstPage: drawn + 1, total: total, frozen: row.isFrozen) {
                render(page, into: pdf, vectorBands: true)
                drawn += 1
                progress(drawn, total)
                guard await pause() else {
                    pdf.closePDF()
                    return nil
                }
            }
        }
        pdf.closePDF()
        // PDFKit reads and writes the whole file once more: off the main thread, so the sheet stays responsive.
        let marks: [RangePDFBookmark] = bookmarks
        let top: CGFloat = pageSize.height
        await Task.detached(priority: .userInitiated) {
            PDFExport.addOutline(to: url, bookmarks: marks, title: title, top: top)
        }.value
        return url
    }

    /// Lets the screen show the progress; false once the task is cancelled (v11 P6.12: also the week's and day's PDF).
    static func pause() async -> Bool {
        await Task.yield()
        try? await Task.sleep(nanoseconds: 1_000_000)
        return !Task.isCancelled
    }

    /// Cover, overview pages, power-hours page – numbered from 1 of `total`.
    static func rangeSummaryPages(_ data: RangePDFData, total: Int) -> [AnyView] {
        var pages: [AnyView] = [AnyView(RangeCoverPage(data: data, page: 1, total: total))]
        let chunks: [[RangePDFRow]] = data.overviewChunks
        for (index, rows) in chunks.enumerated() {
            pages.append(AnyView(RangeOverviewPage(data: data, rows: rows, isLast: index == chunks.count - 1,
                                                   page: 2 + index, total: total)))
        }
        if data.hasWorkPage {
            pages.append(AnyView(RangeWorkPage(data: data, page: 2 + chunks.count, total: total)))
        }
        return pages
    }

    /// Bookmarks and document info through PDFKit; the file stays as it is if that fails. `top` is the
    /// page height (a bookmark opens at the top of its page).
    nonisolated private static func addOutline(to url: URL, bookmarks: [RangePDFBookmark], title: String, top: CGFloat) {
        let temporary = url.deletingLastPathComponent().appendingPathComponent("outline-" + url.lastPathComponent)
        guard let document = PDFDocument(url: url) else { return }
        let root = PDFOutline()
        for bookmark in bookmarks {
            guard let page = document.page(at: bookmark.page) else { continue }
            let item = PDFOutline()
            item.label = bookmark.title
            item.destination = PDFDestination(page: page, at: CGPoint(x: 0, y: top))
            root.insertChild(item, at: root.numberOfChildren)
        }
        document.outlineRoot = root
        var attributes: [AnyHashable: Any] = document.documentAttributes ?? [:]
        attributes[PDFDocumentAttribute.titleAttribute] = title
        attributes[PDFDocumentAttribute.creatorAttribute] = "Thalia"
        document.documentAttributes = attributes
        guard document.write(to: temporary) else { return }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.moveItem(at: temporary, to: url)
    }
}

// MARK: Pieces

private let ink = PDFStyle.ink
private let muted = PDFStyle.muted

/// Column widths of the overview table (523 pt content width).
private enum RangeColumns {
    static let week: CGFloat = 68
    static let score: CGFloat = 38
    static let goals: CGFloat = 214
    static let powerHours: CGFloat = 56
    static let days: CGFloat = 34
    static let excused: CGFloat = 24
    static let targets: CGFloat = 34
    static let goalGap: CGFloat = 2

    /// One goal cell: ten fit with 19 pt.
    static func goalWidth(_ count: Int) -> CGFloat {
        let cells: CGFloat = CGFloat(max(1, count))
        return min(19, (goals - 6 - goalGap * (cells - 1)) / cells)
    }
}

/// "7,3" with one decimal – only the power-hours cells; scores show up to two places (`Format.score`, rule V6).
private func oneDecimal(_ value: Double?) -> String {
    guard let value else { return "–" }
    return Format.number(value, decimals: 1)
}

/// The goal's key in its colour.
private struct GoalKeyDot: View {
    let goal: AnnualGoal
    var size: CGFloat = 22

    var body: some View {
        Text(goal.key)
            .font(.system(size: size * 0.48, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: size, height: size)
            .background(goal.color, in: .circle)
    }
}

/// A goal on the cover: its average over the range, the bar and the trend (±0,25 like the goal review).
private struct RangeGoalTile: View {
    let goal: AnnualGoal
    let line: RangeReport.GoalLine?

    private var average: Double? { line?.average }
    private var trendSymbol: String { line?.trendSymbol ?? "minus" }
    /// v11 P1.17: "steigend (je 3)" – the first and the last k scored weeks, never overlapping; "Trend –" with
    /// fewer than 4 scored weeks.
    private var trendWord: String {
        guard let line, line.window > 0, line.trend != nil else { return "Trend –" }
        return "\(line.trendWord) (je \(line.window))"
    }
    private var hasTrend: Bool { (line?.window ?? 0) > 0 && line?.trend != nil }

    var body: some View {
        HStack(spacing: 9) {
            GoalKeyDot(goal: goal)
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                ColourBar(fraction: (average ?? 0) / 10, tint: goal.color)
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.score(average, outOf: false))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(average == nil ? muted : ink)
                HStack(spacing: 2) {
                    if hasTrend {
                        Image(systemName: trendSymbol)
                    }
                    Text(trendWord)
                }
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(width: 66, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(goal.color.opacity(0.07), in: .rect(cornerRadius: 10, style: .continuous))
    }
}

/// One week's bar on the cover; sick/holiday weeks as a grey dashed column ("entschuldigt").
private struct RangeBar: View {
    let row: RangePDFRow
    let width: CGFloat
    let showsValue: Bool
    let showsLabel: Bool

    static let height: CGFloat = 92

    private var score: Double? { row.line.score }
    /// v11 P6.4: up to two places like the ring and the rows ("6,81", "7,95").
    private var valueText: String { row.state == .excused ? "–" : Format.score(score, outOf: false) }
    private var barHeight: CGFloat { RangeBar.height * CGFloat(min(1, max(0, (score ?? 0) / 10))) }

    var body: some View {
        VStack(spacing: 2) {
            Text(showsValue ? valueText : " ")
                .font(.system(size: 6.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .fixedSize()
                .frame(width: width)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(PDFStyle.line.opacity(0.45))
                if row.state == .excused {
                    excusedColumn
                } else if score != nil {
                    RoundedRectangle(cornerRadius: 2).fill(row.tint).frame(height: barHeight)
                }
            }
            .frame(width: width, height: RangeBar.height)
            Text(showsLabel ? "\(row.week.week)" : " ")
                .font(.system(size: 6.5, weight: .semibold))
                .foregroundStyle(muted)
                .lineLimit(1)
                .fixedSize()
                .frame(width: width)
        }
    }

    private var excusedColumn: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2).fill(PDFStyle.excusedShade)
            RoundedRectangle(cornerRadius: 2).stroke(muted.opacity(0.5), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2]))
            if width >= 12 {
                Text(WeekScore.excusedLabel)
                    .font(.system(size: 6.5, weight: .semibold))
                    .foregroundStyle(muted)
                    .fixedSize()
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

/// A coloured square with its meaning (chart legends).
private struct LegendSwatch: View {
    let color: Color
    let title: String
    var dashed = false

    var body: some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .overlay {
                    if dashed {
                        RoundedRectangle(cornerRadius: 1.5).stroke(muted.opacity(0.6), style: StrokeStyle(lineWidth: 0.6, dash: [1.5, 1.5]))
                    }
                }
                .frame(width: 8, height: 8)
            Text(title)
        }
        .font(.system(size: 7.5, weight: .medium))
        .foregroundStyle(muted)
    }
}

/// The weeks as bars with the Rückblick's colours and their legend.
private struct RangeWeekBars: View {
    let rows: [RangePDFRow]

    private var gap: CGFloat { rows.count > 26 ? 1.5 : 3 }

    private var barWidth: CGFloat {
        let count: CGFloat = CGFloat(max(1, rows.count))
        return min(64, (523 - gap * (count - 1)) / count)
    }

    /// Every week's number up to 13 weeks, every second up to 26, else every fourth.
    private var labelStep: Int {
        if rows.count > 26 { return 4 }
        return rows.count > 13 ? 2 : 1
    }

    private func has(_ state: RangeWeekState) -> Bool { rows.contains { $0.state == state } }
    private var hasOld: Bool { rows.contains { $0.line.isOldScoring } }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .bottom, spacing: gap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    RangeBar(row: row, width: barWidth, showsValue: rows.count <= 16, showsLabel: index % labelStep == 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                LegendSwatch(color: Brand.accent, title: "gleich gewichtet")
                if hasOld { LegendSwatch(color: muted.opacity(0.55), title: "vor KW42") }
                if has(.open) { LegendSwatch(color: Color.orange, title: "nicht abgeschlossen") }
                if has(.running) { LegendSwatch(color: Brand.accent.opacity(0.45), title: "laufend") }
                if has(.excused) { LegendSwatch(color: PDFStyle.excusedShade, title: "entschuldigt (krank/Urlaub)", dashed: true) }
                Spacer(minLength: 0)
                Text("Zahl unter dem Balken: KW")
                    .font(.system(size: 7.5))
                    .foregroundStyle(muted)
            }
        }
    }
}

// MARK: Cover

/// The report's cover: the range, the average ring, the facts, the weeks as bars and the ten goals.
struct RangeCoverPage: View {
    let data: RangePDFData
    let page: Int
    let total: Int

    private var report: RangeReport { data.report }

    var body: some View {
        let average: Double? = report.average
        VStack(spacing: 0) {
            CoverBand(height: 200, ringValue: Format.score(average, outOf: false), ringCaption: "Ø von 10", progress: (average ?? 0) / 10) {
                Text("THALIA · ZEITRAUMBERICHT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .opacity(0.85)
                Text(data.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(data.weeks.dateText)
                    .font(.system(size: 15, weight: .semibold))
                    .opacity(0.92)
                Text(data.countText)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .opacity(0.85)
            }
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        StatTile(label: stat.0, value: stat.1, tint: stat.2)
                    }
                }
                PDFSectionTitle(text: "Wertung je Woche")
                RangeWeekBars(rows: data.rows)
                // v11 P1.17: the trend compares the first and the last weeks (je k).
                PDFSectionTitle(text: "Jahresziele · Ø im Zeitraum · Trend erste/letzte Wochen")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                    ForEach(data.goals) { goal in
                        RangeGoalTile(goal: goal, line: data.goalLine(goal.key))
                    }
                }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(PDFStyle.paper)
    }

    private var stats: [(String, String, Color)] {
        let planWeeks: Int = data.planRows.count
        let scored: String = "\(report.scoredWeeks)/\(data.rows.count)"
        var closedWeeks: String = "–"
        var closedDays: String = "–"
        // v11 P6.2: closed weeks and weeks without items (paper or archive – only a score or grades) are done, of all
        // weeks in the report; the running week counts as open. Never "4/3".
        if !data.rows.isEmpty {
            closedWeeks = "\(data.finishedWeeks)/\(data.rows.count)"
        }
        // v11 P6.2: closed days without sick and holiday days, of the days that count.
        if planWeeks > 0 {
            closedDays = "\(data.closedCountedDays)/\(data.countedDays)"
        }
        var targets: String = "–"
        if report.weeklyTargetsCount > 0 { targets = "\(report.weeklyTargetsMet)/\(report.weeklyTargetsCount)" }
        let work: Color = GoalPalette.color(goal: "3")
        let reach: Color = GoalPalette.color(goal: "8")
        var list: [(String, String, Color)] = []
        list.append(("Wochen bewertet", scored, Brand.accent))
        list.append(("Wochen abgeschlossen", closedWeeks, Brand.accent))
        list.append(("Power-Hours", RangeCoverPage.powerHoursText(report), work))
        list.append(("Tage abgeschlossen", closedDays, reach))
        list.append(("Wochenziele erreicht", targets, reach))
        list.append(("Krank/Urlaub", RangeCoverPage.excusedText(report), muted))
        return list
    }

    /// "182/224 PH", "182 PH", "–".
    static func powerHoursText(_ report: RangeReport) -> String {
        if let target = report.powerHoursTarget { return Format.number(report.powerHours, decimals: 1) + "/" + Format.powerHours(target) }
        return report.powerHours > 0 ? Format.powerHours(report.powerHours) : "–"
    }

    /// "5 Tage · 1 Woche", "2 Tage", "–".
    static func excusedText(_ report: RangeReport) -> String {
        guard report.excusedDays > 0 else { return "–" }
        let days: String = Format.count(report.excusedDays, "Tag", "Tage")
        guard report.excusedWeeks > 0 else { return days }
        return days + " · " + Format.count(report.excusedWeeks, "Woche", "Wochen")
    }
}

// MARK: Overview table

/// One line per week: KW, score, the ten goals in their colours, PH, closed days, sick/holiday days,
/// weekly targets met – and the totals on the last page.
struct RangeOverviewPage: View {
    let data: RangePDFData
    let rows: [RangePDFRow]
    let isLast: Bool
    let page: Int
    let total: Int

    static let legend = "Wertung: laut Unterlagen, wo es einen Wert gibt, sonst gespeichert für abgeschlossene Wochen, sonst die laufende. Ø ohne Wochen vor KW42 und ohne entschuldigte Wochen. Zielfelder: je dunkler, desto höher; grau = nur Krank/Urlaub. Tage: abgeschlossene von den zählenden Tagen. Krank/Urlaub-Tage zählen nicht. Ziele: erreichte Wochenziele. PH: Power-Hours von Wochenziel (anteilig bei Krank/Urlaub)."

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BandHeader(title: "Übersicht je Woche", subtitle: data.title + " · " + data.weeks.dateText)
            VStack(alignment: .leading, spacing: 0) {
                RangeTableHeader(goals: data.goals)
                    .padding(.vertical, 7)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    RangeTableRow(row: row, goals: data.goals, striped: index % 2 == 0)
                }
                if rows.isEmpty {
                    Text("Keine Woche mit Plan oder Wertung in diesem Zeitraum.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(muted)
                        .padding(.vertical, 12)
                }
                if isLast, !rows.isEmpty {
                    RangeTableTotal(data: data)
                    Text(legendText)
                        .font(.system(size: 8))
                        .foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(PDFStyle.paper)
    }

    /// v9 (decision 9): archive weeks get their footnote.
    static let archiveNote = "Archiv: Wertung laut Unterlagen; Zielfelder laut Unterlagen oder nach heutigen Regeln aus den Kategoriennoten."

    private var legendText: String {
        guard data.rows.contains(where: { $0.state == .archive }) else { return RangeOverviewPage.legend }
        return RangeOverviewPage.legend + " " + RangeOverviewPage.archiveNote
    }
}

private struct RangeTableHeader: View {
    let goals: [AnnualGoal]

    var body: some View {
        HStack(spacing: 0) {
            Text("Woche").frame(width: RangeColumns.week, alignment: .leading)
            Text("Wertung").lineLimit(1).minimumScaleFactor(0.6).frame(width: RangeColumns.score)
            HStack(spacing: RangeColumns.goalGap) {
                ForEach(goals) { goal in
                    GoalKeyDot(goal: goal, size: 13)
                        .frame(width: RangeColumns.goalWidth(goals.count))
                }
            }
            .frame(width: RangeColumns.goals)
            Text("PH").frame(width: RangeColumns.powerHours, alignment: .trailing)
            Text("Tage").frame(width: RangeColumns.days, alignment: .trailing)
            Image(systemName: "cross.case").frame(width: RangeColumns.excused, alignment: .trailing)
            Text("Ziele").frame(width: RangeColumns.targets, alignment: .trailing)
            Text("").frame(maxWidth: .infinity)
        }
        .font(.system(size: 8.5, weight: .heavy))
        .foregroundStyle(muted)
    }
}

/// A score in a small capsule in the week's colour.
private struct RangeScoreChip: View {
    let score: Double?
    let tint: Color
    var excused = false

    private var fill: Color {
        if excused { return PDFStyle.excusedShade }
        return score == nil ? PDFStyle.line : tint
    }

    var body: some View {
        // v11 P6.4: up to two places (`Format.score`), the chip column is 38 pt.
        Text(Format.score(score, outOf: false))
            .font(.system(size: 8.5, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(score == nil ? muted : Color.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 1.5)
            .background(fill, in: .capsule)
    }
}

/// A goal's score in its colour (darker = higher); grey when its items fell only on sick or holiday days.
private struct RangeGoalCell: View {
    let score: Double?
    let tint: Color
    let width: CGFloat
    var excused = false

    private var strength: Double { 0.16 + 0.64 * min(1, max(0, (score ?? 0) / 10)) }

    private var fill: Color {
        if score == nil { return excused ? PDFStyle.excusedShade : PDFStyle.line.opacity(0.6) }
        return tint.opacity(strength)
    }

    private var textColor: Color {
        guard score != nil else { return muted }
        return strength > 0.55 ? Color.white : ink
    }

    var body: some View {
        // v11 P6.4: up to two places (`Format.score`) in the 19-pt cell, scaled down where needed.
        Text(Format.score(score, outOf: false))
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(textColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width, height: 15)
            .background(fill, in: .rect(cornerRadius: 3))
    }
}

/// "22,5/28" – PH of the week's PH target.
private struct PowerHoursCell: View {
    let powerHours: Double
    let target: Double?

    private var hoursText: String {
        guard powerHours > 0 || target != nil else { return "–" }
        return oneDecimal(powerHours)
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(hoursText)
            if let target {
                Text("/" + Format.number(target, decimals: 1))
                    .foregroundStyle(muted)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

private struct RangeTableRow: View {
    let row: RangePDFRow
    let goals: [AnnualGoal]
    let striped: Bool

    private var line: WeekLine { row.line }

    private var daysText: String {
        guard row.hasPages else { return "–" }
        return "\(line.closedDays)/\(7 - line.excusedDays)"
    }

    private var excusedText: String { line.excusedDays > 0 ? "\(line.excusedDays)" : "" }

    private var targetsText: String {
        line.weeklyTargetsCount > 0 ? "\(line.weeklyTargetsMet)/\(line.weeklyTargetsCount)" : ""
    }

    private func isExcused(_ goal: AnnualGoal) -> Bool {
        line.isExcused || row.context.isGoalExcused(goal)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(row.week.label)
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Text(row.week.rangeLabel)
                    .font(.system(size: 6.5))
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            .frame(width: RangeColumns.week, alignment: .leading)
            RangeScoreChip(score: line.score, tint: row.tint, excused: line.isExcused)
                .frame(width: RangeColumns.score)
            HStack(spacing: RangeColumns.goalGap) {
                ForEach(goals) { goal in
                    RangeGoalCell(score: line.goalScores[goal.key], tint: goal.color, width: RangeColumns.goalWidth(goals.count),
                                  excused: isExcused(goal))
                }
            }
            .frame(width: RangeColumns.goals)
            PowerHoursCell(powerHours: line.powerHours, target: line.powerHoursTarget)
                .frame(width: RangeColumns.powerHours, alignment: .trailing)
            Text(daysText).frame(width: RangeColumns.days, alignment: .trailing)
            Text(excusedText).frame(width: RangeColumns.excused, alignment: .trailing)
            Text(targetsText).frame(width: RangeColumns.targets, alignment: .trailing)
            Text(row.state.tag)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(row.state == .open ? Color.orange : muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(ink)
        .frame(height: 22)
        .background(striped ? PDFStyle.stripe : PDFStyle.paper)
    }
}

/// The totals under the table: Ø score and goals, Σ PH, days, sick/holiday days, weekly targets.
private struct RangeTableTotal: View {
    let data: RangePDFData

    private var report: RangeReport { data.report }

    private var targetsText: String {
        report.weeklyTargetsCount > 0 ? "\(report.weeklyTargetsMet)/\(report.weeklyTargetsCount)" : ""
    }

    private var excusedText: String { report.excusedDays > 0 ? "\(report.excusedDays)" : "" }

    var body: some View {
        HStack(spacing: 0) {
            Text("Ø / Σ")
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .frame(width: RangeColumns.week, alignment: .leading)
            RangeScoreChip(score: report.average, tint: Brand.accent)
                .frame(width: RangeColumns.score)
            HStack(spacing: RangeColumns.goalGap) {
                ForEach(data.goals) { goal in
                    RangeGoalCell(score: data.goalLine(goal.key)?.average, tint: goal.color, width: RangeColumns.goalWidth(data.goals.count))
                }
            }
            .frame(width: RangeColumns.goals)
            PowerHoursCell(powerHours: report.powerHours, target: report.powerHoursTarget)
                .frame(width: RangeColumns.powerHours, alignment: .trailing)
            // v11 P6.2: closed days without sick and holiday days, like each row.
            Text("\(data.closedCountedDays)/\(data.countedDays)").frame(width: RangeColumns.days, alignment: .trailing)
            Text(excusedText).frame(width: RangeColumns.excused, alignment: .trailing)
            Text(targetsText).frame(width: RangeColumns.targets, alignment: .trailing)
            Text("\(report.scoredWeeks) bewertet")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 8.5, weight: .heavy, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(ink)
        .frame(height: 26)
        .overlay(alignment: .top) { Rectangle().fill(ink.opacity(0.6)).frame(height: 1) }
    }
}

// MARK: Power-hours

/// Power-hours over the range: totals, per area and per week against the weekly target.
struct RangeWorkPage: View {
    let data: RangePDFData
    let page: Int
    let total: Int

    private var report: RangeReport { data.report }

    /// Weeks with a PH target and how many reached it.
    private var reached: (met: Int, count: Int) {
        let withTarget: [WeekLine] = data.rows.map(\.line).filter { $0.powerHoursTarget != nil }
        let met: Int = withTarget.filter { $0.powerHours >= ($0.powerHoursTarget ?? 0) - 1e-9 }.count
        return (met, withTarget.count)
    }

    private var stats: [(String, String, Color)] {
        let weeks: Int = max(1, data.planRows.count)
        let goal: Color = GoalPalette.color(goal: "3")
        var list: [(String, String, Color)] = [("Power-Hours", Format.powerHours(report.powerHours), goal)]
        if let target = report.powerHoursTarget { list.append(("Wochenziele zusammen", Format.powerHours(target), goal)) }
        list.append(("Ø je Woche mit Plan", Format.powerHours(report.powerHours / Double(weeks)), goal))
        let state = reached
        if state.count > 0 { list.append(("Wochenziel erreicht", "\(state.met) von \(state.count)", GoalPalette.color(goal: "8"))) }
        return list
    }

    var body: some View {
        let maximum: Double = max(1, report.work.map(\.powerHours).max() ?? 1)
        VStack(alignment: .leading, spacing: 0) {
            BandHeader(title: "Power-Hours", subtitle: data.title + " · je Bereich und je Woche")
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        StatTile(label: stat.0, value: stat.1, tint: stat.2)
                    }
                }
                if !report.work.isEmpty {
                    PDFSectionTitle(text: "Je Bereich")
                    VStack(spacing: 7) {
                        ForEach(Array(report.work.prefix(18).enumerated()), id: \.offset) { _, work in
                            RangeAreaLine(work: work, maximum: maximum)
                        }
                    }
                }
                PDFSectionTitle(text: "Je Woche · Strich = Wochenziel (anteilig bei Krank/Urlaub)")
                RangePowerHourBars(rows: data.rows)
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(PDFStyle.paper)
    }
}

private struct RangeAreaLine: View {
    let work: RangeReport.WorkLine
    let maximum: Double

    var body: some View {
        HStack(spacing: 10) {
            Text("\(work.categoryKey) \(work.title)")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .frame(width: 190, alignment: .leading)
            ColourBar(fraction: work.powerHours / maximum, tint: GoalPalette.color(category: work.categoryKey))
            Text(Format.powerHours(work.powerHours))
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
                .frame(width: 70, alignment: .trailing)
        }
    }
}

/// PH per week as bars, the week's target as a line across its bar.
private struct RangePowerHourBars: View {
    let rows: [RangePDFRow]

    static let height: CGFloat = 130

    private var gap: CGFloat { rows.count > 26 ? 1.5 : 3 }

    private var barWidth: CGFloat {
        let count: CGFloat = CGFloat(max(1, rows.count))
        return min(64, (523 - gap * (count - 1)) / count)
    }

    private var labelStep: Int {
        if rows.count > 26 { return 4 }
        return rows.count > 13 ? 2 : 1
    }

    private var maximum: Double {
        let values: [Double] = rows.map(\.line.powerHours) + rows.compactMap(\.line.powerHoursTarget)
        return max(1, values.max() ?? 1)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                RangePowerHourBar(line: row.line, width: barWidth, maximum: maximum, showsValue: rows.count <= 16,
                                  showsLabel: index % labelStep == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RangePowerHourBar: View {
    let line: WeekLine
    let width: CGFloat
    let maximum: Double
    let showsValue: Bool
    let showsLabel: Bool

    private var isReached: Bool {
        guard let target = line.powerHoursTarget, target > 0 else { return false }
        return line.powerHours >= target - 1e-9
    }

    private func height(_ value: Double) -> CGFloat {
        RangePowerHourBars.height * CGFloat(min(1, max(0, value / maximum)))
    }

    private var valueText: String {
        guard showsValue, line.powerHours > 0 else { return " " }
        return Format.number(line.powerHours, decimals: 0)
    }

    var body: some View {
        let tint: Color = GoalPalette.color(goal: "3")
        VStack(spacing: 2) {
            Text(valueText)
                .font(.system(size: 6.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .fixedSize()
                .frame(width: width)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2).fill(PDFStyle.line.opacity(0.45))
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint.opacity(isReached ? 1 : 0.55))
                    .frame(height: height(line.powerHours))
                if let target = line.powerHoursTarget, target > 0 {
                    Rectangle()
                        .fill(ink.opacity(0.7))
                        .frame(width: width + 2, height: 1.5)
                        .offset(y: -height(target))
                }
            }
            .frame(width: width, height: RangePowerHourBars.height)
            Text(showsLabel ? "\(line.week.week)" : " ")
                .font(.system(size: 6.5, weight: .semibold))
                .foregroundStyle(muted)
                .lineLimit(1)
                .fixedSize()
                .frame(width: width)
        }
    }
}

// MARK: Preview

/// The finished PDF with PDFKit (scales to many pages, unlike live views).
#if os(macOS)
struct RangePDFPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {}
}
#else
struct RangePDFPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displaysPageBreaks = true
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
#endif

// MARK: Sheet

/// "PDF-Bericht": period (last 4 / 8 / 13 weeks, goal year to date, own range), scope, then the PDF
/// page by page with progress, the PDFKit preview and "Teilen" (Mac: also save and print).
struct RangePDFSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var preset: PDFRangePreset = .fourWeeks
    @State private var scope: RangePDFScope = .weeks
    @State private var customFrom: WeekKey?
    @State private var customThrough: WeekKey?
    /// Weeks with a plan or a score, for the own range.
    @State private var choices: [WeekKey] = []
    @State private var lastFinished: WeekKey?
    @State private var period: GoalPeriod?
    /// v10: the goal year's segments ("Aktueller Abschnitt").
    @State private var segments: Segments?
    /// The chosen weeks, read and scored.
    @State private var data: RangePDFData?
    @State private var isGenerating = false
    @State private var done = 0
    @State private var total = 0
    @State private var generation: Task<Void, Never>?
    @State private var url: URL?
    @State private var version = UUID()
    @State private var failed = false
    /// Mac: the PDF for the save panel.
    @State private var exportFile: ExportFile?
    @State private var exporting = false
    /// The own range starts here (Rückblick "PDF-Bericht ab dieser Woche"); nil: `preset`.
    private let firstWeek: WeekKey?
    /// CI screenshots: the PDF was started once by itself.
    @State private var autoStarted = false

    /// - Parameters:
    ///   - preset: the period to start with (the goal review: "Zieljahr bis heute").
    ///   - start: opens the own range from this week through the newest week with data.
    init(preset: PDFRangePreset = .fourWeeks, from start: WeekKey? = nil) {
        firstWeek = start
        _preset = State(initialValue: start == nil ? preset : .custom)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("PDF-Bericht")
                .inlineNavigationTitle()
                .toolbar { toolbar }
                .fileExporter(isPresented: $exporting, document: exportFile, contentType: .pdf, defaultFilename: fileName) { _ in
                    exportFile = nil
                }
        }
        .task { setUp() }
        .task(id: rangeID) { await load() }
        .onDisappear { generation?.cancel() }
        .thaliaSheetFrame(width: 640, height: 760)
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            RangePDFPreview(url: url)
                .id(version)
                .ignoresSafeArea(edges: .bottom)
        } else if isGenerating {
            progressView
        } else {
            options
        }
    }

    // MARK: Options

    private var options: some View {
        Form {
            Section {
                Picker("Zeitraum", selection: $preset) {
                    ForEach(presetChoices) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                if preset == .custom {
                    customPickers
                }
                if let range {
                    LabeledContent(range.title, value: range.dateText)
                }
            } header: {
                Text("Zeitraum")
            } footer: {
                Text(rangeFooter)
            }
            Section {
                Picker("Umfang", selection: $scope) {
                    ForEach(RangePDFScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Umfang")
            } footer: {
                Text(scope.detail)
            }
            Section {
                statusLine
                Button {
                    start()
                } label: {
                    Label("PDF erstellen", systemImage: "doc.richtext")
                }
                .disabled(!canStart)
                if failed {
                    Text("Das PDF konnte nicht erstellt werden.")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text(pagesFooter)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var customPickers: some View {
        if choices.isEmpty {
            Text("Noch keine Woche mit Plan oder Wertung.")
                .foregroundStyle(.secondary)
        } else {
            Picker("Von", selection: $customFrom) {
                ForEach(choices, id: \.self) { week in
                    Text(RangePDFSheet.choiceLabel(week)).tag(week as WeekKey?)
                }
            }
            Picker("Bis", selection: $customThrough) {
                ForEach(choices, id: \.self) { week in
                    Text(RangePDFSheet.choiceLabel(week)).tag(week as WeekKey?)
                }
            }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if let data {
            Text(summaryText(data))
                .monospacedDigit()
        } else if range != nil {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Wochen werden gelesen …")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Zeitraum wählen.")
                .foregroundStyle(.secondary)
        }
    }

    private var progressView: some View {
        VStack(spacing: 14) {
            ProgressView(value: Double(done), total: Double(max(1, total)))
                .frame(maxWidth: 320)
            Text("Seite \(done) von \(total)")
                .font(.headline)
                .monospacedDigit()
            Text("Das PDF entsteht Seite für Seite.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Abbrechen", role: .cancel) {
                generation?.cancel()
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            SheetCloseButton { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            if url != nil {
                Button {
                    url = nil
                } label: {
                    Label("Zeitraum ändern", systemImage: "slider.horizontal.3")
                }
            }
        }
        #if os(macOS)
        ToolbarItem(placement: .primaryAction) {
            Button(action: savePDF) {
                Label("Sichern…", systemImage: "square.and.arrow.down")
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(url == nil)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: printPDF) {
                Label("Drucken…", systemImage: "printer")
            }
            .keyboardShortcut("p", modifiers: .command)
            .disabled(url == nil)
        }
        #endif
        ToolbarItem(placement: .primaryAction) {
            if let url {
                ShareLink(item: url) {
                    Label("PDF teilen", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: State

    /// The chosen weeks; nil until the own range has both ends.
    private var range: RangePDFWeeks? {
        if preset == .custom {
            guard let from = customFrom, let through = customThrough else { return nil }
            return RangePDFWeeks(from: from, through: through)
        }
        guard let lastFinished, let period else { return nil }
        return preset.range(lastWeek: lastFinished, today: app.today, period: period, segment: currentSegment)
    }

    /// v10: the segment `today` is in, when the goal year has several.
    private var currentSegment: SegmentSpan? {
        guard let segments, segments.hasSeveral else { return nil }
        return segments.current(today: app.today)
    }

    private var presetChoices: [PDFRangePreset] {
        PDFRangePreset.choices(hasSegments: currentSegment != nil || preset == .segment)
    }

    private var rangeFooter: String {
        guard let segment = currentSegment else {
            return "„Letzte Wochen“ enden mit der letzten abgeschlossenen Woche, das Zieljahr mit dieser Woche."
        }
        return "„Letzte Wochen“ enden mit der letzten abgeschlossenen Woche, \(segment.title) und das Zieljahr mit dieser Woche."
    }

    private var rangeID: String { range?.id ?? "" }

    private var fileName: String { range?.fileName ?? "Thalia-Bericht.pdf" }

    private var canStart: Bool {
        guard let data, let range else { return false }
        return data.weeks == range && !data.isEmpty && !isGenerating
    }

    /// "8 Wochen mit Daten · 6 mit Plan · 42 Seiten".
    private func summaryText(_ data: RangePDFData) -> String {
        guard !data.isEmpty else { return "Keine Woche mit Plan oder Wertung in diesem Zeitraum." }
        let weeks: String = Format.count(data.rows.count, "Woche", "Wochen") + " mit Daten"
        let plans: String = "\(data.planRows.count) mit Plan"
        let pages: String = Format.count(data.pageCount(scope), "Seite", "Seiten")
        return weeks + " · " + plans + " · " + pages
    }

    private var pagesFooter: String {
        guard let data, data.pageCount(scope) > 120 else {
            return "Seitenzahlen laufen durch. Wochen ohne Punkte (Papier-Wertung oder Archiv) stehen in der Übersicht, ohne eigene Seiten."
        }
        return "Viele Seiten – das Erstellen dauert etwas. „Nur Übersicht“ ist schneller."
    }

    /// "KW45 2026 · 2.–8. Nov.".
    static func choiceLabel(_ week: WeekKey) -> String {
        week.longLabel + " · " + week.rangeLabel
    }

    private func setUp() {
        let store = app.store
        let current: WeekKey = app.today.week
        choices = store.reportableWeeks(through: current)
        period = store.goalPeriod
        if segments == nil { segments = store.segments() }
        let closed: Bool = store.plan(current)?.isClosed ?? false
        lastFinished = closed ? current : current.adding(weeks: -1)
        if customThrough == nil { customThrough = choices.last }
        if customFrom == nil, let firstWeek { customFrom = RangePDFSheet.firstChoice(choices, from: firstWeek) }
        if customFrom == nil { customFrom = choices.suffix(8).first }
    }

    /// The first week with data from `start` on; the newest one if none follows.
    static func firstChoice(_ choices: [WeekKey], from start: WeekKey) -> WeekKey? {
        choices.first { $0 >= start } ?? choices.last
    }

    /// Reads the chosen weeks one by one (the form stays responsive) and builds the report.
    private func load() async {
        guard let range else {
            data = nil
            return
        }
        if data?.weeks == range { return }
        data = nil
        let store = app.store
        let today: DayKey = app.today
        // v11 P6.13: the pages read no segment titles or results – each week without the goal year; which weeks are
        // frozen (their own cover shows the stored score, P6.1) is read once here.
        let isFrozen: (WeekKey) -> Bool = store.freezeRule(today: today)
        var contexts: [WeekContext] = []
        for week in store.rangeWeeks(from: range.from, through: range.through) {
            contexts.append(store.weekContext(for: week, today: today, goalYear: false))
            await Task.yield()
            if Task.isCancelled { return }
        }
        let report: RangeReport = store.rangeReport(contexts: contexts)
        data = RangePDFData(weeks: range, contexts: contexts, report: report, today: today, isFrozen: isFrozen)
        if autoStarts, !autoStarted {
            autoStarted = true
            start()
        }
    }

    /// CI screenshots ("-Demo -DemoScreen range-pdf"): the PDF is made right away, so the shot shows
    /// the finished report and not only the form.
    private var autoStarts: Bool {
        app.launch.isDemo && app.launch.screen == "range-pdf"
    }

    private func start() {
        guard let data, canStart else { return }
        let chosen: RangePDFScope = scope
        failed = false
        done = 0
        total = data.pageCount(chosen)
        isGenerating = true
        generation = Task {
            let made: URL? = await PDFExport.makeRange(data, scope: chosen) { page, all in
                done = page
                total = all
            }
            isGenerating = false
            guard !Task.isCancelled else { return }
            if let made {
                url = made
                version = UUID()
            } else {
                failed = true
            }
        }
    }

    /// Mac: the finished PDF into the save panel.
    private func savePDF() {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        exportFile = ExportFile(data: data)
        exporting = true
    }

    #if os(macOS)
    /// Mac: the system print dialog for the finished PDF.
    private func printPDF() {
        guard let url, let document = PDFDocument(url: url),
              let operation = document.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true) else { return }
        _ = operation.run()
    }
    #endif
}
