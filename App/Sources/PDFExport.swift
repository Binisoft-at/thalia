import SwiftUI
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
import PDFKit
#endif

// W1: the week (and now the day) as a PDF worth sharing. A4 pages drawn with SwiftUI: a cover with
// the big number, the ten goals in their colours and the days; then designed tables with fixed row
// heights, paginated by height so nothing is ever cut off. A preview shows the pages before sharing.

/// What to export.
enum PDFKind: Hashable, Identifiable {
    case week(WeekKey)
    case day(DayKey)

    var id: String {
        switch self {
        case .week(let week): "week-" + week.string
        case .day(let day): "day-" + day.string
        }
    }

    var week: WeekKey {
        switch self {
        case .week(let week): week
        case .day(let day): day.week
        }
    }

    var title: String {
        switch self {
        case .week(let week): "Wochenbericht \(week.label)"
        case .day(let day): "Tagesbericht \(day.shortLabel)"
        }
    }

    var fileName: String {
        switch self {
        case .week(let week): "Thalia-\(week.string).pdf"
        case .day(let day): "Thalia-\(day.string).pdf"
        }
    }
}

/// The parts of a week's PDF (v8): the single-week PDF has them all; the report over several weeks
/// picks some and numbers its pages through (`PDFExport.weekPages(_:sections:firstPage:total:)`).
struct WeekPDFSections: OptionSet, Hashable {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The cover with the number, the ten goals and the days.
    static let cover = WeekPDFSections(rawValue: 1 << 0)
    /// "Wochenziele & Fokus".
    static let details = WeekPDFSections(rawValue: 1 << 1)
    /// "Rückblick": the weekly answers and the day notes.
    static let review = WeekPDFSections(rawValue: 1 << 2)
    /// The category tables.
    static let tables = WeekPDFSections(rawValue: 1 << 3)
    /// With `.review`: only answered questions and notes, no review page for a week without any
    /// (report over several weeks).
    static let answeredOnly = WeekPDFSections(rawValue: 1 << 4)

    /// The single-week PDF, unchanged since v4.
    static let all: WeekPDFSections = [.cover, .details, .review, .tables]
}

@MainActor
enum PDFExport {
    static let pageSize = CGSize(width: 595, height: 842)
    /// Height for rows on a table page (A4 minus head band, margins and footer).
    static let tableBudget: CGFloat = 660

    /// The review pages a week gets with `sections` (none without `.review`).
    static func reviewPages(_ context: WeekContext, sections: WeekPDFSections) -> [[ReviewBlock]] {
        guard sections.contains(.review) else { return [] }
        let blocks: [ReviewBlock] = reviewBlocks(context)
        guard sections.contains(.answeredOnly) else { return paginateReview(blocks) }
        let answered: [ReviewBlock] = answeredBlocks(blocks)
        return answered.isEmpty ? [] : paginateReview(answered)
    }

    /// Answered blocks only; a group heading moves to the first block that stays.
    static func answeredBlocks(_ blocks: [ReviewBlock]) -> [ReviewBlock] {
        var result: [ReviewBlock] = []
        var heading: String?
        for block in blocks {
            if let own = block.heading { heading = own }
            guard !block.isEmpty else { continue }
            var kept = block
            kept.heading = heading
            heading = nil
            result.append(kept)
        }
        return result
    }

    /// The table pages a week gets with `sections` (none without `.tables`).
    static func tablePages(_ context: WeekContext, sections: WeekPDFSections) -> [[Row]] {
        sections.contains(.tables) ? paginate(weekRows(context)) : []
    }

    /// v8: how many pages a week's PDF has with `sections` – from the pagination only, nothing drawn.
    static func weekPageCount(_ context: WeekContext, sections: WeekPDFSections = .all) -> Int {
        var count = 0
        if sections.contains(.cover) { count += 1 }
        if sections.contains(.details) { count += 1 }
        count += reviewPages(context, sections: sections).count
        count += tablePages(context, sections: sections).count
        return count
    }

    /// v8: a week's pages with `sections`, numbered from `firstPage` of `total` (a report over
    /// several weeks numbers through). The pages themselves are the single-week PDF's. v11 P6.1, P6.13:
    /// `frozen` – whether the week lies before the current segment, for a context read without the goal year
    /// (nil: the context knows).
    static func weekPages(_ context: WeekContext, sections: WeekPDFSections = .all, firstPage: Int = 1, total: Int,
                          frozen: Bool? = nil) -> [AnyView] {
        var pages: [AnyView] = []
        var page: Int = firstPage
        if sections.contains(.cover) {
            pages.append(AnyView(WeekCoverPage(context: context, page: page, total: total, frozen: frozen)))
            page += 1
        }
        if sections.contains(.details) {
            pages.append(AnyView(WeekDetailsPage(context: context, page: page, total: total)))
            page += 1
        }
        for blocks in reviewPages(context, sections: sections) {
            pages.append(AnyView(ReviewPage(context: context, blocks: blocks, page: page, total: total)))
            page += 1
        }
        for rows in tablePages(context, sections: sections) {
            pages.append(AnyView(TablePage(context: context, title: "\(context.week.label) · Kategorien", rows: rows,
                                           days: context.week.days, page: page, total: total)))
            page += 1
        }
        return pages
    }

    static func pages(_ kind: PDFKind, context: WeekContext) -> [AnyView] {
        switch kind {
        case .week:
            return weekPages(context, sections: .all, firstPage: 1, total: weekPageCount(context, sections: .all))
        case .day(let day):
            let tables = paginate(dayRows(context, day: day))
            let total = 1 + tables.count
            var pages: [AnyView] = [AnyView(DayCoverPage(context: context, day: day, page: 1, total: total))]
            for (index, rows) in tables.enumerated() {
                pages.append(AnyView(TablePage(context: context, title: "\(day.shortLabel) · Punkte", rows: rows,
                                               days: [day], page: index + 2, total: total)))
            }
            return pages
        }
    }

    /// v11 P6.12: the week's or day's PDF page by page – after each page `progress(drawn, total)` and a short pause, so
    /// the preview stays responsive and shows "Seite x von y". nil when cancelled (closing the preview) or the file
    /// can't be written. Drawing stays on the main thread (ImageRenderer).
    static func make(_ kind: PDFKind, context: WeekContext, progress: (Int, Int) -> Void = { _, _ in }) async -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(kind.fileName)
        var box = CGRect(origin: .zero, size: pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        let all: [AnyView] = pages(kind, context: context)
        var drawn = 0
        for page in all {
            render(page, into: pdf)
            drawn += 1
            progress(drawn, all.count)
            guard await pause() else {
                pdf.closePDF()
                return nil
            }
        }
        pdf.closePDF()
        return url
    }

    /// One A4 page into the PDF, always light (v8: shared with the report over several weeks, which
    /// passes `vectorBands` so its bands stay small).
    static func render(_ page: AnyView, into pdf: CGContext, vectorBands: Bool = false) {
        let renderer = ImageRenderer(content: page
            .frame(width: pageSize.width, height: pageSize.height)
            .environment(\.colorScheme, .light)
            .environment(\.pdfVectorBands, vectorBands))
        renderer.render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
        }
    }

    // MARK: Sick and holiday days (v8)

    /// The table legend; with sick or holiday days among `days` also what the grey column means.
    static func legend(_ context: WeekContext, days: [DayKey]) -> String {
        let base = "✓ erledigt · ½ teilweise · ✗ nicht erledigt · – entfällt · ○ nicht erfasst"
        let excused: [DayKey] = days.filter { context.isExcused($0) }
        guard !excused.isEmpty else { return base }
        return base + " · grau: " + context.excusedWord(excused) + ", " + PDFStyle.excusedNote
    }

    /// The background of a day's column: grey on sick and holiday days.
    static func columnShade(_ context: WeekContext, day: DayKey) -> Color {
        context.isExcused(day) ? PDFStyle.excusedShade : Color.clear
    }

    // MARK: Rows

    enum Row {
        case category(TrackCategory)
        case item(PlanItem)

        var height: CGFloat {
            switch self {
            case .category: 30
            case .item: 20
            }
        }
    }

    static func weekRows(_ context: WeekContext) -> [Row] {
        var rows: [Row] = []
        for goal in context.goals {
            for category in context.categories(of: goal) {
                let items = context.items(in: category)
                guard !items.isEmpty else { continue }
                rows.append(.category(category))
                rows.append(contentsOf: items.map { Row.item($0) })
            }
        }
        return rows
    }

    static func dayRows(_ context: WeekContext, day: DayKey) -> [Row] {
        var rows: [Row] = []
        for category in context.todayCategories(day) {
            let items = context.items(in: category, on: day)
            guard !items.isEmpty else { continue }
            rows.append(.category(category))
            rows.append(contentsOf: items.map { Row.item($0) })
        }
        return rows
    }

    /// Fills pages by height; a category header never ends a page on its own.
    static func paginate(_ rows: [Row]) -> [[Row]] {
        var pages: [[Row]] = []
        var current: [Row] = []
        var used: CGFloat = 0
        for (index, row) in rows.enumerated() {
            var needed = row.height
            if case .category = row, index + 1 < rows.count { needed += rows[index + 1].height }
            if used + needed > tableBudget, !current.isEmpty {
                pages.append(current)
                current = []
                used = 0
            }
            current.append(row)
            used += row.height
        }
        if !current.isEmpty { pages.append(current) }
        return pages
    }

    // MARK: Columns (R26)

    /// A single day's column is wide enough for "Mo, 16. Nov.".
    static func columnWidth(_ dayCount: Int) -> CGFloat {
        dayCount == 1 ? 90 : 30
    }

    /// "Mo, 16. Nov." for the day report, "Mo" in the week table.
    static func columnTitle(_ day: DayKey, single: Bool) -> String {
        single ? day.shortLabel : day.weekday.short
    }

    // MARK: Review page (R26)

    /// One answer (or day note) on the "Rückblick" page; `heading` starts a group.
    struct ReviewBlock {
        var heading: String?
        var title: String
        var text: String
        /// Not answered: shown as "–".
        var isEmpty: Bool { text.isEmpty }
    }

    /// Height for blocks on a review page (A4 minus band, margins and footer).
    static let reviewBudget: CGFloat = 640
    /// Characters per line of answer text across the page (10.5 pt, conservative).
    static let charactersPerLine = 88

    /// Every weekly question (unanswered ones too), then the day notes of the week.
    static func reviewBlocks(_ context: WeekContext) -> [ReviewBlock] {
        var blocks: [ReviewBlock] = []
        for (index, question) in ReflectionQuestion.week.enumerated() {
            let text: String = context.reflection(scope: context.week.string, field: question.id)
            blocks.append(ReviewBlock(heading: index == 0 ? "Wochenreflexion" : nil, title: question.question, text: text))
        }
        var firstNote = true
        for day in context.week.days {
            let text: String = context.reflection(scope: day.string, field: ReflectionQuestion.dayNoteField)
            guard !text.isEmpty else { continue }
            blocks.append(ReviewBlock(heading: firstNote ? "Notizen zum Tag" : nil, title: day.shortLabel, text: text))
            firstNote = false
        }
        return blocks
    }

    static func lineCount(_ text: String) -> Int {
        guard !text.isEmpty else { return 1 }
        return text.split(separator: "\n", omittingEmptySubsequences: false).reduce(0) { total, paragraph in
            total + max(1, Int((Double(paragraph.count) / Double(charactersPerLine)).rounded(.up)))
        }
    }

    static func height(_ block: ReviewBlock) -> CGFloat {
        let heading: CGFloat = block.heading == nil ? 0 : 22
        return heading + 15 + CGFloat(lineCount(block.text)) * 13.5 + 12
    }

    /// A block taller than a page is split by words, so nothing is cut off.
    static func split(_ block: ReviewBlock) -> [ReviewBlock] {
        guard height(block) > reviewBudget else { return [block] }
        let maxLines: Int = Int((reviewBudget - 22 - 15 - 12) / 13.5)
        var parts: [ReviewBlock] = []
        var current = ""
        for word in block.text.split(separator: " ", omittingEmptySubsequences: false) {
            let candidate: String = current.isEmpty ? String(word) : current + " " + String(word)
            if lineCount(candidate) > maxLines, !current.isEmpty {
                parts.append(ReviewBlock(heading: parts.isEmpty ? block.heading : nil,
                                         title: parts.isEmpty ? block.title : block.title + " (Fortsetzung)", text: current))
                current = String(word)
            } else {
                current = candidate
            }
        }
        parts.append(ReviewBlock(heading: parts.isEmpty ? block.heading : nil,
                                 title: parts.isEmpty ? block.title : block.title + " (Fortsetzung)", text: current))
        return parts
    }

    /// Fills review pages by estimated height; always at least one page.
    static func paginateReview(_ blocks: [ReviewBlock]) -> [[ReviewBlock]] {
        var pages: [[ReviewBlock]] = []
        var current: [ReviewBlock] = []
        var used: CGFloat = 0
        for block in blocks.flatMap({ split($0) }) {
            let needed: CGFloat = height(block)
            if used + needed > reviewBudget, !current.isEmpty {
                pages.append(current)
                current = []
                used = 0
            }
            current.append(block)
            used += needed
        }
        if !current.isEmpty || pages.isEmpty { pages.append(current) }
        return pages
    }
}

// MARK: Building blocks

/// The PDF's fixed light colours, also for the report over several weeks (RangePDF.swift).
enum PDFStyle {
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.17)
    static let muted = Color(red: 0.42, green: 0.47, blue: 0.52)
    static let paper = Color.white
    static let line = Color(red: 0.90, green: 0.92, blue: 0.93)
    /// Table stripe.
    static let stripe = Color(red: 0.97, green: 0.98, blue: 0.98)
    /// v8: the column of a sick or holiday day.
    static let excusedShade = Color(red: 0.92, green: 0.93, blue: 0.95)
    static let done = Color(red: 0.20, green: 0.68, blue: 0.38)
    static let partial = Color(red: 0.95, green: 0.62, blue: 0.15)
    static let missed = Color(red: 0.88, green: 0.30, blue: 0.28)
    /// v8: "zählt nicht" next to a sick or holiday day.
    static let excusedNote = "zählt nicht"
    /// v8: the aurora's colours from left to right, for the plain band of the report over several weeks.
    static let bandColors: [Color] = [
        Color(red: 0.05, green: 0.36, blue: 0.42), Color(red: 0.10, green: 0.55, blue: 0.58),
        Color(red: 0.20, green: 0.45, blue: 0.75), Color(red: 0.45, green: 0.33, blue: 0.72),
    ]
}

/// v8: the report over several weeks draws its bands as a plain gradient. The mesh gradient may be
/// drawn as an image on every page, which would make a long report large.
private struct PDFVectorBandsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var pdfVectorBands: Bool {
        get { self[PDFVectorBandsKey.self] }
        set { self[PDFVectorBandsKey.self] = newValue }
    }
}

/// The band behind a cover or a page head: the app's aurora, or (report over several weeks) the
/// same colours as a plain gradient.
struct PDFBandBackground: View {
    @Environment(\.pdfVectorBands) private var vectorBands

    var body: some View {
        if vectorBands {
            LinearGradient(colors: PDFStyle.bandColors, startPoint: .leading, endPoint: .trailing)
        } else {
            AuroraBackground(animated: false)
        }
    }
}

private let ink = PDFStyle.ink
private let muted = PDFStyle.muted
private let paper = PDFStyle.paper
private let line = PDFStyle.line

struct PDFFooter: View {
    let page: Int
    let total: Int

    var body: some View {
        HStack {
            Label("Thalia", systemImage: "leaf.fill")
                .font(.system(size: 9, weight: .bold, design: .rounded))
            Text("· erstellt \(Date().formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: Locale(identifier: "de_AT"))))")
                .font(.system(size: 9))
            Spacer()
            Text("Seite \(page) von \(total)")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(muted)
    }
}

struct PDFSectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(muted)
    }
}

/// The big ring on a cover.
struct CoverRing: View {
    let value: String
    let caption: String
    let progress: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.25), lineWidth: 14)
            Circle()
                .trim(from: 0, to: CGFloat(min(1, max(0, progress))))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value)
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(caption)
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.85)
            }
            .padding(18)
        }
        .frame(width: 150, height: 150)
    }
}

/// The gradient band at the top of a cover.
struct CoverBand<Leading: View>: View {
    let height: CGFloat
    let ringValue: String
    let ringCaption: String
    let progress: Double
    let leading: () -> Leading

    init(height: CGFloat, ringValue: String, ringCaption: String, progress: Double, @ViewBuilder leading: @escaping () -> Leading) {
        self.height = height
        self.ringValue = ringValue
        self.ringCaption = ringCaption
        self.progress = progress
        self.leading = leading
    }

    var body: some View {
        ZStack {
            PDFBandBackground()
            LinearGradient(colors: [.clear, .black.opacity(0.18)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) { leading() }
                Spacer(minLength: 0)
                CoverRing(value: ringValue, caption: ringCaption, progress: progress)
            }
            .padding(.horizontal, 36)
        }
        .frame(height: height)
        .foregroundStyle(.white)
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var tint: Color = Brand.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(ink)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58, alignment: .leading)
        .background(tint.opacity(0.09), in: .rect(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3, height: 30).padding(.leading, 0)
        }
    }
}

struct ColourBar: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.14))
                Capsule().fill(tint).frame(width: max(4, geometry.size.width * CGFloat(min(1, max(0, fraction)))))
            }
        }
        .frame(height: 6)
    }
}

private struct GoalTile: View {
    let goal: AnnualGoal
    let score: Double?
    /// v8: the goal's items fell only on sick or holiday days – "zählt nicht" instead of a gap.
    var excused = false

    private var title: String {
        excused ? goal.title + " · " + PDFStyle.excusedNote : goal.title
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(goal.key)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(goal.color, in: .circle)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                ColourBar(fraction: (score ?? 0) / 10, tint: goal.color)
            }
            Text(Format.score(score, outOf: false))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(score == nil ? muted : ink)
                .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(goal.color.opacity(0.07), in: .rect(cornerRadius: 10, style: .continuous))
    }
}

/// A mark as a small coloured dot with its symbol.
private struct MarkChip: View {
    let mark: Mark?
    let applies: Bool
    /// v8: a mark recorded on a sick or holiday day – kept, but it doesn't count.
    var dimmed = false

    var body: some View {
        ZStack {
            if let mark {
                Circle().fill(fill(mark))
                Text(mark == .notApplicable ? "–" : mark.symbol)
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundStyle(mark == .notApplicable ? muted : .white)
            } else if applies {
                Circle().stroke(Color(red: 0.75, green: 0.78, blue: 0.80), lineWidth: 1)
            } else {
                Circle().fill(line).frame(width: 3, height: 3)
            }
        }
        .frame(width: 14, height: 14)
        .opacity(dimmed ? 0.35 : 1)
    }

    private func fill(_ mark: Mark) -> Color {
        switch mark {
        case .done: Color(red: 0.20, green: 0.68, blue: 0.38)
        case .partial: Color(red: 0.95, green: 0.62, blue: 0.15)
        case .missed: Color(red: 0.88, green: 0.30, blue: 0.28)
        case .notApplicable: line
        }
    }
}

// MARK: Week cover

private struct WeekCoverPage: View {
    let context: WeekContext
    let page: Int
    let total: Int
    /// v11 P6.1, P6.13: whether the week lies before the current segment. nil asks the week itself; the report over
    /// several weeks reads its weeks without the goal year (no segments) and passes what it knows.
    var frozen: Bool? = nil

    /// v11 P6.1: a frozen closed week shows the score and goal scores it stored, like everywhere in the app.
    private var keepsStoredScore: Bool {
        guard let frozen else { return context.keepsStoredScore }
        return frozen && context.isClosed && context.hasPlan
    }

    private var score: Double? {
        keepsStoredScore ? context.recalculatedScore : context.score.overall
    }

    /// The stored goal scores of a frozen closed week; nil for every other week (and when none were stored).
    private var storedGoalScores: [String: Double]? {
        guard keepsStoredScore, let stored = context.plan?.finalGoalScoreMap, !stored.isEmpty else { return nil }
        return stored
    }

    private func goalScore(_ goal: AnnualGoal, stored: [String: Double]?) -> Double? {
        if let stored { return stored[goal.key] }
        return context.score.goalWeek[goal.key]?.score
    }

    /// v8: a week where every day with something planned was sick or on holiday has no score.
    private var ringCaption: String {
        context.score.isExcused ? PDFStyle.excusedNote : "von 10"
    }

    var body: some View {
        let score: Double? = self.score
        let stored: [String: Double]? = storedGoalScores
        let excusedDays: [DayKey] = context.excusedDayList
        VStack(spacing: 0) {
            CoverBand(height: 270, ringValue: Format.score(score, outOf: false), ringCaption: ringCaption, progress: (score ?? 0) / 10) {
                Text("THALIA · WOCHENBERICHT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .opacity(0.85)
                Text(context.week.label)
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                // v11 P1.8: "28. Dez. 2026 – 3. Jan. 2027" across a new year.
                Text(context.week.rangeLabelWithYear)
                    .font(.system(size: 15, weight: .semibold))
                    .opacity(0.92)
                if let motto = context.plan?.title, !motto.isEmpty {
                    Text("„\(motto)“")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .italic()
                        .lineLimit(2)
                        .opacity(0.92)
                        .padding(.top, 2)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ForEach(Array(stats(stored).enumerated()), id: \.offset) { _, stat in
                        StatTile(label: stat.0, value: stat.1, tint: stat.2)
                    }
                }
                PDFSectionTitle(text: "Jahresziele · gleich gewichtet")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
                    ForEach(context.goals) { goal in
                        GoalTile(goal: goal, score: goalScore(goal, stored: stored), excused: context.isGoalExcused(goal))
                    }
                }
                PDFSectionTitle(text: "Die Tage")
                HStack(spacing: 8) {
                    ForEach(context.week.days, id: \.self) { day in
                        DayDot(context: context, day: day)
                    }
                }
                if !excusedDays.isEmpty {
                    ExcusedNoteLine(text: excusedText(excusedDays))
                }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(paper)
    }

    /// v8: "Fr–So krank: Diese Tage zählen nicht in die Wochenwertung." – or the whole week.
    private func excusedText(_ days: [DayKey]) -> String {
        if context.score.isExcused { return WeekScore.excusedText + "." }
        let names: String = days.map(\.weekday.short).joined(separator: ", ")
        let subject: String = days.count == 1 ? "Der Tag zählt" : "Diese Tage zählen"
        return names + " " + context.excusedWord(days) + ": " + subject + " nicht in die Wochenwertung."
    }

    private func stats(_ stored: [String: Double]?) -> [(String, String, Color)] {
        let totals = context.workTotals()
        // R16: the same list and count as the app. v8: sick and holiday days don't count ("3/5 · 2 krank").
        let weekly: [WeeklyTarget] = context.weeklyTargets
        let reached: Int = context.weeklyTargetsMet
        let best: AnnualGoal? = context.goals.max { (goalScore($0, stored: stored) ?? -1) < (goalScore($1, stored: stored) ?? -1) }
        var list: [(String, String, Color)] = [
            ("Fokus", totals.isEmpty ? "–" : totals.shortText, GoalPalette.color(goal: "3")),
            ("Tage abgeschlossen", context.closedDaysText, Brand.accent),
        ]
        if !weekly.isEmpty { list.append(("Wochenziele erreicht", "\(reached)/\(weekly.count)", GoalPalette.color(goal: "8"))) }
        if let best, let score = goalScore(best, stored: stored) {
            let short: String = best.title.split(separator: " ").first.map(String.init) ?? best.title
            list.append(("Bestes Ziel · \(short)", Format.score(score), best.color))
        }
        return list
    }
}

/// v8: a grey line with the sick/holiday symbol under the days ("Fr, Sa krank: …").
private struct ExcusedNoteLine: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "cross.case")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(muted)
            .lineLimit(2)
    }
}

private struct DayDot: View {
    let context: WeekContext
    let day: DayKey

    var body: some View {
        if context.isExcused(day) {
            excused
        } else {
            regular
        }
    }

    /// v8: a sick or holiday day – its type in a grey dashed ring, the symbol and "zählt nicht".
    private var excused: some View {
        VStack(spacing: 4) {
            Text("\(day.weekday.short) \(day.day).")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ink)
            ZStack {
                Circle()
                    .fill(PDFStyle.excusedShade)
                Circle()
                    .stroke(muted.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Text(context.excusedName(day))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(muted)
                    .minimumScaleFactor(0.6)
                    .padding(6)
            }
            .frame(width: 50, height: 50)
            HStack(spacing: 2) {
                Image(systemName: DayTypes.symbol(for: context.dayType(day)))
                Text(PDFStyle.excusedNote)
            }
            .font(.system(size: 7, weight: .semibold))
            .foregroundStyle(muted)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var regular: some View {
        let overall: DayOverall? = context.score.days[day]
        let closed: Bool = context.isClosed(day)
        let progress: Double = closed ? (overall?.score ?? 0) / 10 : (overall?.coverage ?? 0)
        let text: String = closed ? Format.score(overall?.score, outOf: false) : "\(percent(overall?.coverage ?? 0)) %"
        return VStack(spacing: 4) {
            Text("\(day.weekday.short) \(day.day).")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(ink)
            ZStack {
                Circle().stroke(Brand.accent.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(closed ? Brand.accent : Brand.accent.opacity(0.45), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(text)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .minimumScaleFactor(0.6)
                    .padding(6)
            }
            .frame(width: 50, height: 50)
            Image(systemName: closed ? "checkmark.seal.fill" : DayTypes.symbol(for: context.dayType(day)))
                .font(.system(size: 9))
                .foregroundStyle(closed ? Brand.accent : muted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: Week details

private struct WeekDetailsPage: View {
    let context: WeekContext
    let page: Int
    let total: Int

    var body: some View {
        let weekly: [WeeklyTarget] = Array(context.weeklyTargets.prefix(10))
        let byCategory: [String: WorkTotals] = WorkTotals.byCategory(context.workRecords)
        let workKeys: [String] = byCategory.keys.sorted()
        VStack(alignment: .leading, spacing: 0) {
            BandHeader(title: "Wochenziele & Fokus", subtitle: "\(context.week.label) · \(context.week.rangeLabel)")
            VStack(alignment: .leading, spacing: 14) {
                if !weekly.isEmpty {
                    PDFSectionTitle(text: "Wochenziele")
                    VStack(spacing: 8) {
                        ForEach(weekly) { target in
                            WeeklyTargetLine(target: target)
                        }
                    }
                }
                if !workKeys.isEmpty {
                    PDFSectionTitle(text: "Power-Hours nach Bereich · \(context.workTotals().explanation)")
                    let maximum: Double = byCategory.values.map(\.powerHours).max() ?? 1
                    VStack(spacing: 7) {
                        ForEach(Array(workKeys.prefix(8)), id: \.self) { key in
                            let totals: WorkTotals = byCategory[key] ?? WorkTotals()
                            HStack(spacing: 10) {
                                Text("\(key) \(context.category(key)?.title ?? "")")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(ink)
                                    .lineLimit(1)
                                    .frame(width: 190, alignment: .leading)
                                ColourBar(fraction: totals.powerHours / max(1, maximum), tint: GoalPalette.color(category: key))
                                Text(totals.shortText)
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(ink)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }
                }
                let notes: [DayNote] = Array(context.notes.prefix(6))
                if !notes.isEmpty {
                    PDFSectionTitle(text: "Notizen")
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(notes) { note in
                            HStack(alignment: .top, spacing: 8) {
                                Text(DayKey(note.dayKey)?.shortLabel ?? note.dayKey)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(muted)
                                    .frame(width: 70, alignment: .leading)
                                Text(note.text)
                                    .font(.system(size: 10))
                                    .foregroundStyle(ink)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(paper)
    }
}

/// A weekly target with the app's pace (R16, R47): bar with the even-pace mark and its state.
private struct WeeklyTargetLine: View {
    let target: WeeklyTarget

    private var title: String { target.item?.title ?? target.measure.title }

    /// v11 P1.7: "12,75 / 14 PH", "150 / 86 Stk." – rounded like the app (`WeeklyTarget.amountsText`).
    private var amounts: String { target.amountsText(joiner: " / ") }

    /// v11 P1.16: the app's word – "erreicht", "im Plan", "hinter dem Plan", "noch offen", "nicht erreicht";
    /// limits "im Rahmen" · "überschritten".
    private var state: String { target.shownStatus.label }

    /// v11 P1.16: the app's status colour (`StatusTint`).
    private var stateColor: Color { StatusTint(target.shownStatus).color }

    private var fraction: Double {
        let goal: Double = target.target.scaleMax
        return goal > 0 ? target.value / goal : 0
    }

    /// Where an even pace stands today, 0…1 of the bar; nil once reached.
    private var marker: Double? {
        let pace: Pace = target.pace
        guard pace.target > 0, pace.expected > 0, !pace.isReached, target.shownStatus != .reached else { return nil }
        return min(1, pace.expected / pace.target)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: target.isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundStyle(target.isMet ? Color(red: 0.20, green: 0.68, blue: 0.38) : muted)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                // v8: "4,8 statt 8 PH – 2 Tage krank" when sick or holiday days scaled the target.
                if let hint = target.scaledHint {
                    Text(hint)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: 150, alignment: .leading)
            ColourBar(fraction: fraction, tint: GoalPalette.color(category: target.measure.categoryKey))
                .overlay {
                    GeometryReader { geometry in
                        if let marker {
                            Rectangle()
                                .fill(ink.opacity(0.55))
                                .frame(width: 1.5, height: 10)
                                .offset(x: geometry.size.width * CGFloat(marker) - 0.75, y: -2)
                        }
                    }
                }
            VStack(alignment: .trailing, spacing: 1) {
                Text(amounts)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(state)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(stateColor)
                    .lineLimit(1)
            }
            .frame(width: 110, alignment: .trailing)
        }
    }
}

// MARK: Review (R26)

/// "Rückblick": every weekly answer in full and the week's day notes.
private struct ReviewPage: View {
    let context: WeekContext
    let blocks: [PDFExport.ReviewBlock]
    let page: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BandHeader(title: "Rückblick", subtitle: "\(context.week.label) · \(context.week.rangeLabel)")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(paper)
    }

    private func blockView(_ block: PDFExport.ReviewBlock) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let heading = block.heading {
                PDFSectionTitle(text: heading)
                    .padding(.bottom, 6)
            }
            Text(block.title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(ink)
            Text(block.isEmpty ? "–" : block.text)
                .font(.system(size: 10.5))
                .foregroundStyle(block.isEmpty ? muted : ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A slim gradient band at the top of inner pages.
struct BandHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .leading) {
            PDFBandBackground()
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.9)
            }
            .padding(.horizontal, 36)
            .foregroundStyle(.white)
        }
        .frame(height: 72)
    }
}

// MARK: Tables

private struct TablePage: View {
    let context: WeekContext
    let title: String
    let rows: [PDFExport.Row]
    let days: [DayKey]
    let page: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BandHeader(title: title, subtitle: PDFExport.legend(context, days: days))
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Punkt")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(days, id: \.self) { day in
                        ColumnTitle(context: context, day: day, single: days.count == 1)
                            .frame(width: PDFExport.columnWidth(days.count))
                    }
                    Text(days.count == 1 ? "Woche" : "Ø")
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(muted)
                .padding(.vertical, 8)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        rowView(row, striped: index % 2 == 0)
                    }
                }
                .background(alignment: .trailing) { excusedColumns }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(paper)
    }

    /// v8: the grey columns of sick and holiday days behind the rows (item rows shade their own cells
    /// on top of the stripes).
    private var excusedColumns: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                PDFExport.columnShade(context, day: day)
                    .frame(width: PDFExport.columnWidth(days.count))
            }
            Color.clear.frame(width: 50)
        }
    }

    @ViewBuilder
    private func rowView(_ row: PDFExport.Row, striped: Bool) -> some View {
        switch row {
        case .category(let category):
            CategoryLine(context: context, category: category, days: days)
        case .item(let item):
            ItemLine(context: context, item: item, days: days, striped: striped)
        }
    }
}

/// A day's column head: "Mo" (or "Mo, 16. Nov."); v8: with the symbol on sick and holiday days.
private struct ColumnTitle: View {
    let context: WeekContext
    let day: DayKey
    let single: Bool

    var body: some View {
        if context.isExcused(day) {
            HStack(spacing: 1) {
                Image(systemName: DayTypes.symbol(for: context.dayType(day)))
                    .font(.system(size: 7))
                Text(PDFExport.columnTitle(day, single: single))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        } else {
            Text(PDFExport.columnTitle(day, single: single))
        }
    }
}

/// One item's mark on a day; v8: on sick and holiday days a mark recorded there shows dimmed.
private struct PDFMarkCell: View {
    let context: WeekContext
    let item: PlanItem
    let day: DayKey

    var body: some View {
        if let recorded = context.excusedMark(item, on: day) {
            MarkChip(mark: recorded, applies: false, dimmed: true)
        } else {
            MarkChip(mark: context.mark(item, on: day), applies: context.applies(item, on: day))
        }
    }
}

private struct CategoryLine: View {
    let context: WeekContext
    let category: TrackCategory
    let days: [DayKey]

    var body: some View {
        let weekScore: Double? = context.score.categoryWeek[category.key]
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(category.color).frame(width: 4, height: 16)
                Text("\(category.key)  \(category.title)")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(ink)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(days, id: \.self) { day in
                let entry: CategoryDay = context.score.category(category.key, on: day)
                Text(entry.isComplete && entry.due > 0 ? Format.score(entry.score, outOf: false) : "")
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(muted)
                    .frame(width: PDFExport.columnWidth(days.count))
            }
            Text(Format.score(weekScore, outOf: false))
                .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(weekScore == nil ? muted.opacity(0.5) : category.color, in: .capsule)
                .frame(width: 50, alignment: .trailing)
        }
        .frame(height: 30, alignment: .bottom)
        .padding(.bottom, 3)
        .overlay(alignment: .bottom) { Rectangle().fill(line).frame(height: 1) }
    }
}

private struct ItemLine: View {
    let context: WeekContext
    let item: PlanItem
    let days: [DayKey]
    let striped: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(item.title)
                    .font(.system(size: 9.5))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                if let tag = tag {
                    Text(tag)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(muted)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(line, in: .capsule)
                }
            }
            .padding(.leading, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(days, id: \.self) { day in
                PDFMarkCell(context: context, item: item, day: day)
                    .frame(width: PDFExport.columnWidth(days.count), height: 20)
                    .background(PDFExport.columnShade(context, day: day))
            }
            Text(trailing)
                .font(.system(size: 8.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 50, alignment: .trailing)
        }
        .frame(height: 20)
        .background(striped ? Color(red: 0.97, green: 0.98, blue: 0.98) : paper)
    }

    /// "2/3×" – v8: "2/3× · ½ krank" when sick or holiday days took part of the quota.
    private var trailing: String {
        if let quota = context.quotaText(item) { return quota }
        if let progress = context.progress(item) { return "\(percent(progress)) %" }
        return ""
    }

    /// The same short label as in Today, Week and the table (R64).
    private var tag: String? {
        guard let label = context.kindLabel(item), !label.isEmpty else { return nil }
        return label
    }
}

// MARK: Day cover

private struct DayCoverPage: View {
    let context: WeekContext
    let day: DayKey
    let page: Int
    let total: Int

    /// v8: a sick or holiday day doesn't count – no score, no share recorded.
    private var excused: Bool { context.isExcused(day) }

    private var ringValue: String {
        let overall: DayOverall? = context.score.days[day]
        if excused { return "–" }
        if context.isClosed(day) { return Format.score(overall?.score, outOf: false) }
        return "\(percent(overall?.coverage ?? 0)) %"
    }

    private var ringCaption: String {
        if excused { return PDFStyle.excusedNote }
        return context.isClosed(day) ? "von 10" : "erfasst"
    }

    private var ringProgress: Double {
        let overall: DayOverall? = context.score.days[day]
        if excused { return 0 }
        return context.isClosed(day) ? (overall?.score ?? 0) / 10 : (overall?.coverage ?? 0)
    }

    /// "Krank · zählt nicht", the type, or "Tag".
    private var typeLabel: String {
        let type: String = context.dayType(day)
        if excused { return type + " · " + PDFStyle.excusedNote }
        return type.isEmpty ? "Tag" : type
    }

    private var recordedText: String {
        guard !excused, let overall = context.score.days[day] else { return "–" }
        return "\(overall.due - overall.blank)/\(overall.due)"
    }

    var body: some View {
        // H1: Health values without a value on this device are listed with the hint, not left out.
        let measured: [MeasureDefinition] = Array(context.measures.filter { measure in
            guard context.applies(measure, on: day) else { return false }
            return context.dayValue(measure, on: day) != nil || context.isHealthElsewhere(measure, on: day)
        }.prefix(12))
        let blocks: [WorkBlock] = Array(context.work(on: day).prefix(6))
        let notes: [DayNote] = Array(context.notes(on: day).prefix(4))
        VStack(spacing: 0) {
            CoverBand(height: 230, ringValue: ringValue, ringCaption: ringCaption, progress: ringProgress) {
                Text("THALIA · TAGESBERICHT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .opacity(0.85)
                Text(day.weekday.name)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text("\(day.longLabel.replacingOccurrences(of: "\(day.weekday.name), ", with: "")) · \(context.week.label)")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.92)
                Label(typeLabel, systemImage: DayTypes.symbol(for: context.dayType(day)))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2), in: .capsule)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatTile(label: "Punkte erfasst", value: recordedText)
                    StatTile(label: "Fokus", value: context.workTotals(on: day).isEmpty ? "–" : context.workTotals(on: day).shortText,
                             tint: GoalPalette.color(goal: "3"))
                    StatTile(label: "Kategorien komplett", value: "\(completeCategories)/\(context.todayCategories(day).count)",
                             tint: GoalPalette.color(goal: "8"))
                    StatTile(label: "Journal", value: journalText, tint: GoalPalette.color(goal: "2"))
                }
                if excused {
                    ExcusedNoteLine(text: DayTypes.excusedHint + ".")
                }
                let special: String = context.dayNote(day)
                if !special.isEmpty {
                    PDFSectionTitle(text: "Besonderheit")
                    Text(special)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ink)
                        .lineLimit(3)
                }
                let dayNote: String = context.reflection(scope: day.string, field: ReflectionQuestion.dayNoteField)
                if !dayNote.isEmpty {
                    PDFSectionTitle(text: "Notiz zum Tag")
                    Text(dayNote)
                        .font(.system(size: 10.5))
                        .foregroundStyle(ink)
                        .lineLimit(4)
                }
                if !measured.isEmpty {
                    PDFSectionTitle(text: "Werte")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 6) {
                        ForEach(measured) { measure in
                            ValueTile(context: context, measure: measure, day: day)
                        }
                    }
                }
                if !blocks.isEmpty {
                    PDFSectionTitle(text: "Power-Hours · \(context.workTotals(on: day).explanation)")
                    VStack(spacing: 5) {
                        ForEach(blocks) { block in
                            HStack(spacing: 8) {
                                Text(Format.powerHours(block.hours))
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(GoalPalette.color(category: block.categoryKey), in: .capsule)
                                Text(block.task.isEmpty ? (context.category(block.categoryKey)?.title ?? block.categoryKey) : block.task)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundStyle(ink)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text("\(block.categoryKey) \(context.category(block.categoryKey)?.title ?? "")")
                                    .font(.system(size: 9))
                                    .foregroundStyle(muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                if !notes.isEmpty {
                    PDFSectionTitle(text: "Notizen")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(notes) { note in
                            Text("• \(note.text)")
                                .font(.system(size: 10))
                                .foregroundStyle(ink)
                                .lineLimit(2)
                        }
                    }
                }
                Spacer(minLength: 0)
                PDFFooter(page: page, total: total)
            }
            .padding(.horizontal, 36)
            .padding(.top, 20)
            .padding(.bottom, 22)
        }
        .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
        .background(paper)
    }

    /// R58: the plan's journal item if there is one, else the evening switch.
    private var journalText: String {
        switch context.journalDone(on: day) {
        case .some(true): return "✓"
        case .some(false): return "✗"
        case .none: return "–"
        }
    }

    private var completeCategories: Int {
        context.todayCategories(day).filter { category in
            let entry = context.score.category(category.key, on: day)
            return entry.due > 0 && entry.isComplete
        }.count
    }
}

private struct ValueTile: View {
    let context: WeekContext
    let measure: MeasureDefinition
    let day: DayKey

    /// The value, or H1's hint for a Health value that only the iPhone reads.
    private func shown(_ value: Double?, unit: String) -> String {
        if let value { return Format.measure(value, unit: unit) }
        return context.isHealthElsewhere(measure, on: day) ? WeekContext.healthElsewhereHint : "–"
    }

    /// The hint small and light, a value big and heavy.
    private func valueFont(isHint: Bool) -> Font {
        if isHint { return .system(size: 9.5, weight: .medium, design: .rounded) }
        return .system(size: 13, weight: .heavy, design: .rounded)
    }

    var body: some View {
        let value: Double? = context.dayValue(measure, on: day)
        let unit: String = measure.record?.isWork == true ? "PH" : measure.unit
        let met: Bool? = measure.record.flatMap { Measures.isMet($0, value: value) }
        let isHint: Bool = value == nil && context.isHealthElsewhere(measure, on: day)
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(GoalPalette.color(category: measure.categoryKey)).frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(measure.title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                Text(shown(value, unit: unit))
                    .font(valueFont(isHint: isHint))
                    .monospacedDigit()
                    .foregroundStyle(isHint ? muted : ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            if !isHint, let met {
                Image(systemName: met ? "checkmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(met ? Color(red: 0.20, green: 0.68, blue: 0.38) : muted)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 40)
        .background(Color(red: 0.97, green: 0.98, blue: 0.98), in: .rect(cornerRadius: 9, style: .continuous))
    }
}

// MARK: Preview and sharing

/// The pages as they will be printed, then "Teilen".
struct PDFPreviewSheet: View {
    let kind: PDFKind
    let context: WeekContext
    @Environment(\.dismiss) private var dismiss
    @State private var url: URL?
    /// v11 P6.12: pages drawn into the file so far, of `pageTotal`.
    @State private var pagesDrawn = 0
    @State private var pageTotal = 0
    /// Mac: the PDF for the save panel (R71).
    @State private var exportFile: ExportFile?
    @State private var exporting = false

    /// "PDF wird erstellt … Seite 2 von 5".
    private var progressText: String {
        guard pageTotal > 0 else { return "PDF wird erstellt …" }
        return "PDF wird erstellt … Seite \(pagesDrawn) von \(pageTotal)"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let scale: CGFloat = min(1, (geometry.size.width - 32) / PDFExport.pageSize.width)
                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(Array(PDFExport.pages(kind, context: context).enumerated()), id: \.offset) { _, page in
                            page
                                .frame(width: PDFExport.pageSize.width, height: PDFExport.pageSize.height)
                                .environment(\.colorScheme, .light)
                                .scaleEffect(scale, anchor: .topLeading)
                                .frame(width: PDFExport.pageSize.width * scale, height: PDFExport.pageSize.height * scale,
                                       alignment: .topLeading)
                                .clipShape(.rect(cornerRadius: 6))
                                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color.secondary.opacity(0.12))
            .safeAreaInset(edge: .bottom) {
                if url == nil {
                    // v11 P6.12: the file is made page by page; closing the sheet stops it.
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(progressText)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: .capsule)
                    .padding(.bottom, 10)
                }
            }
            .navigationTitle(kind.title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
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
                    } else {
                        ProgressView()
                    }
                }
            }
            .fileExporter(isPresented: $exporting, document: exportFile, contentType: .pdf,
                          defaultFilename: kind.fileName) { _ in
                exportFile = nil
            }
            // v11 P6.12: page by page with progress; the task ends with the sheet (nil: cancelled).
            .task {
                url = await PDFExport.make(kind, context: context) { drawn, total in
                    pagesDrawn = drawn
                    pageTotal = total
                }
            }
        }
        .thaliaSheetFrame(width: 640, height: 760)
    }

    /// R71: the finished PDF into the save panel.
    private func savePDF() {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        exportFile = ExportFile(data: data)
        exporting = true
    }

    #if os(macOS)
    /// R71: the system print dialog for the finished PDF.
    private func printPDF() {
        guard let url, let document = PDFDocument(url: url),
              let operation = document.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleToFit, autoRotate: true) else { return }
        _ = operation.run()
    }
    #endif
}

/// A finished file (PDF or PNG) for the save panel (R71).
struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .png] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// "PDF" anywhere: opens the preview with sharing.
struct PDFButton: View {
    let kind: PDFKind
    let context: WeekContext
    var title: String?
    @Environment(AppModel.self) private var app
    @State private var shows = false

    var body: some View {
        Button {
            shows = true
        } label: {
            Label(title ?? "PDF ansehen und teilen", systemImage: "doc.richtext")
        }
        .sheet(isPresented: $shows) {
            PDFPreviewSheet(kind: kind, context: context)
                .environment(app)
                .toastHost(app)
        }
    }
}

/// Kept for existing places: the week as PDF.
struct PDFShareButton: View {
    let context: WeekContext

    var body: some View {
        PDFButton(kind: .week(context.week), context: context, title: "Woche als PDF")
    }
}
