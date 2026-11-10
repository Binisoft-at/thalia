import SwiftUI
import BinisoftKit
import ThaliaCore

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

@MainActor
enum PDFExport {
    static let pageSize = CGSize(width: 595, height: 842)
    /// Height for rows on a table page (A4 minus head band, margins and footer).
    static let tableBudget: CGFloat = 660

    static func pages(_ kind: PDFKind, context: WeekContext) -> [AnyView] {
        switch kind {
        case .week:
            let tables = paginate(weekRows(context))
            let total = 2 + tables.count
            var pages: [AnyView] = [
                AnyView(WeekCoverPage(context: context, page: 1, total: total)),
                AnyView(WeekDetailsPage(context: context, page: 2, total: total)),
            ]
            for (index, rows) in tables.enumerated() {
                pages.append(AnyView(TablePage(context: context, title: "\(context.week.label) · Kategorien", rows: rows,
                                               days: context.week.days, page: index + 3, total: total)))
            }
            return pages
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

    static func make(_ kind: PDFKind, context: WeekContext) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(kind.fileName)
        var box = CGRect(origin: .zero, size: pageSize)
        guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        for page in pages(kind, context: context) {
            let renderer = ImageRenderer(content: page
                .frame(width: pageSize.width, height: pageSize.height)
                .environment(\.colorScheme, .light))
            renderer.render { _, draw in
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
            }
        }
        pdf.closePDF()
        return url
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
}

// MARK: Building blocks

private let ink = Color(red: 0.09, green: 0.13, blue: 0.17)
private let muted = Color(red: 0.42, green: 0.47, blue: 0.52)
private let paper = Color.white
private let line = Color(red: 0.90, green: 0.92, blue: 0.93)

private struct PDFFooter: View {
    let page: Int
    let total: Int

    var body: some View {
        HStack {
            Label("Thalia", systemImage: "leaf.fill")
                .font(.system(size: 9, weight: .bold, design: .rounded))
            Text("· erstellt \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 9))
            Spacer()
            Text("Seite \(page) von \(total)")
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(muted)
    }
}

private struct PDFSectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(1.4)
            .foregroundStyle(muted)
    }
}

/// The big ring on a cover.
private struct CoverRing: View {
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
private struct CoverBand<Leading: View>: View {
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
            AuroraBackground(animated: false)
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

private struct StatTile: View {
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

private struct ColourBar: View {
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

    var body: some View {
        HStack(spacing: 10) {
            Text(goal.key)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(goal.color, in: .circle)
            VStack(alignment: .leading, spacing: 5) {
                Text(goal.title)
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

    var body: some View {
        let score: Double? = context.score.overall
        VStack(spacing: 0) {
            CoverBand(height: 270, ringValue: Format.score(score, outOf: false), ringCaption: "von 10", progress: (score ?? 0) / 10) {
                Text("THALIA · WOCHENBERICHT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(2)
                    .opacity(0.85)
                Text(context.week.label)
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                Text("\(context.week.rangeLabel) \(String(context.week.year))")
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
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        StatTile(label: stat.0, value: stat.1, tint: stat.2)
                    }
                }
                PDFSectionTitle(text: "Jahresziele · je 10 % der Woche")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 8) {
                    ForEach(context.goals) { goal in
                        GoalTile(goal: goal, score: context.score.goalWeek[goal.key]?.score)
                    }
                }
                PDFSectionTitle(text: "Die Tage")
                HStack(spacing: 8) {
                    ForEach(context.week.days, id: \.self) { day in
                        DayDot(context: context, day: day)
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

    private var stats: [(String, String, Color)] {
        let totals = context.workTotals()
        let closed: Int = context.week.days.filter { context.isClosed($0) }.count
        let weekly: [MeasureDefinition] = context.measures.filter { $0.record?.period == .week && $0.record?.target != nil }
        let reached: Int = weekly.filter { measure in
            guard let target = measure.record?.target else { return false }
            return target.isMet(context.weekValue(measure) ?? 0)
        }.count
        let best: AnnualGoal? = context.goals.max { ($0.weekScore(context) ?? -1) < ($1.weekScore(context) ?? -1) }
        var list: [(String, String, Color)] = [
            ("Fokus", totals.isEmpty ? "–" : totals.shortText, GoalPalette.color(goal: "3")),
            ("Tage abgeschlossen", "\(closed)/7", Brand.accent),
        ]
        if !weekly.isEmpty { list.append(("Wochenziele erreicht", "\(reached)/\(weekly.count)", GoalPalette.color(goal: "8"))) }
        if let best, let score = best.weekScore(context) {
            let short: String = best.title.split(separator: " ").first.map(String.init) ?? best.title
            list.append(("Bestes Ziel · \(short)", Format.score(score), best.color))
        }
        return list
    }
}

private extension AnnualGoal {
    func weekScore(_ context: WeekContext) -> Double? { context.score.goalWeek[key]?.score }
}

private struct DayDot: View {
    let context: WeekContext
    let day: DayKey

    var body: some View {
        let overall: DayOverall? = context.score.days[day]
        let closed: Bool = context.isClosed(day)
        let progress: Double = closed ? (overall?.score ?? 0) / 10 : (overall?.coverage ?? 0)
        let text: String = closed ? Format.score(overall?.score, outOf: false) : "\(percent(overall?.coverage ?? 0)) %"
        VStack(spacing: 4) {
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
        let weekly: [MeasureDefinition] = Array(context.measures.filter { $0.record?.period == .week && $0.record?.target != nil }.prefix(10))
        let byCategory: [String: WorkTotals] = WorkTotals.byCategory(context.workRecords)
        let workKeys: [String] = byCategory.keys.sorted()
        let answers: [(String, String)] = ReflectionQuestion.week.compactMap { question in
            let text = context.reflection(scope: context.week.string, field: question.id)
            return text.isEmpty ? nil : (question.question, text)
        }
        VStack(alignment: .leading, spacing: 0) {
            BandHeader(title: "Wochenziele & Fokus", subtitle: "\(context.week.label) · \(context.week.rangeLabel)")
            VStack(alignment: .leading, spacing: 14) {
                if !weekly.isEmpty {
                    PDFSectionTitle(text: "Wochenziele")
                    VStack(spacing: 8) {
                        ForEach(weekly) { measure in
                            WeeklyTargetLine(context: context, measure: measure)
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
                if !answers.isEmpty {
                    PDFSectionTitle(text: "Rückblick")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(answers.prefix(4).enumerated()), id: \.offset) { _, answer in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(answer.0)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(ink)
                                Text(answer.1)
                                    .font(.system(size: 10))
                                    .foregroundStyle(muted)
                                    .lineLimit(3)
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

private struct WeeklyTargetLine: View {
    let context: WeekContext
    let measure: MeasureDefinition

    var body: some View {
        let value: Double = context.weekValue(measure) ?? 0
        let target: Double = measure.record?.target?.scaleMax ?? 0
        let met: Bool = measure.record?.target?.isMet(value) ?? false
        let unit: String = measure.record?.isWork == true ? "PH" : measure.unit
        HStack(spacing: 10) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11))
                .foregroundStyle(met ? Color(red: 0.20, green: 0.68, blue: 0.38) : muted)
            Text(measure.title)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
                .frame(width: 172, alignment: .leading)
            ColourBar(fraction: target > 0 ? value / target : 0, tint: GoalPalette.color(category: measure.categoryKey))
            Text("\(Format.measure(value, unit: unit)) / \(Format.measure(target, unit: unit))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 96, alignment: .trailing)
        }
    }
}

/// A slim gradient band at the top of inner pages.
private struct BandHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .leading) {
            AuroraBackground(animated: false)
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
            BandHeader(title: title, subtitle: "✓ erledigt · ½ teilweise · ✗ nicht erledigt · – nicht fällig · ○ offen")
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text("Punkt")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(days, id: \.self) { day in
                        Text(days.count == 1 ? "Heute" : day.weekday.short)
                            .frame(width: days.count == 1 ? 60 : 30)
                    }
                    Text(days.count == 1 ? "Woche" : "Ø")
                        .frame(width: 50, alignment: .trailing)
                }
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(muted)
                .padding(.vertical, 8)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    rowView(row, striped: index % 2 == 0)
                }
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
                    .frame(width: days.count == 1 ? 60 : 30)
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
                MarkChip(mark: context.mark(item, on: day), applies: context.applies(item, on: day))
                    .frame(width: days.count == 1 ? 60 : 30)
            }
            Text(trailing)
                .font(.system(size: 8.5, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(muted)
                .frame(width: 50, alignment: .trailing)
        }
        .frame(height: 20)
        .background(striped ? Color(red: 0.97, green: 0.98, blue: 0.98) : paper)
    }

    private var trailing: String {
        if let quota = context.quotaProgress(item) { return "\(quota.done)/\(quota.target)×" }
        if let progress = context.progress(item) { return "\(percent(progress)) %" }
        return ""
    }

    private var tag: String? {
        if context.isDerived(item) { return "automatisch" }
        if item.isSecondary { return "Nebensache" }
        if case .weekly(let count) = item.schedule { return "\(count)×/Woche" }
        if item.schedule == .optional { return "optional" }
        return nil
    }
}

// MARK: Day cover

private struct DayCoverPage: View {
    let context: WeekContext
    let day: DayKey
    let page: Int
    let total: Int

    var body: some View {
        let overall: DayOverall? = context.score.days[day]
        let closed: Bool = context.isClosed(day)
        let measured: [MeasureDefinition] = Array(context.measures.filter { context.applies($0, on: day) && context.dayValue($0, on: day) != nil }.prefix(12))
        let blocks: [WorkBlock] = Array(context.work(on: day).prefix(6))
        let notes: [DayNote] = Array(context.notes(on: day).prefix(4))
        VStack(spacing: 0) {
            CoverBand(height: 230,
                      ringValue: closed ? Format.score(overall?.score, outOf: false) : "\(percent(overall?.coverage ?? 0)) %",
                      ringCaption: closed ? "von 10" : "erfasst",
                      progress: closed ? (overall?.score ?? 0) / 10 : (overall?.coverage ?? 0)) {
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
                Label(context.dayType(day).isEmpty ? "Tag" : context.dayType(day), systemImage: DayTypes.symbol(for: context.dayType(day)))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2), in: .capsule)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    StatTile(label: "Punkte erfasst", value: overall.map { "\($0.due - $0.blank)/\($0.due)" } ?? "–")
                    StatTile(label: "Fokus", value: context.workTotals(on: day).isEmpty ? "–" : context.workTotals(on: day).shortText,
                             tint: GoalPalette.color(goal: "3"))
                    StatTile(label: "Kategorien komplett", value: "\(completeCategories)/\(context.todayCategories(day).count)",
                             tint: GoalPalette.color(goal: "8"))
                    StatTile(label: "Journal", value: context.reflection(scope: day.string, field: ReflectionQuestion.journalField) == "ja" ? "✓" : "–",
                             tint: GoalPalette.color(goal: "2"))
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

    var body: some View {
        let value: Double? = context.dayValue(measure, on: day)
        let unit: String = measure.record?.isWork == true ? "PH" : measure.unit
        let met: Bool? = measure.record.flatMap { Measures.isMet($0, value: value) }
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(GoalPalette.color(category: measure.categoryKey)).frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(measure.title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                Text(value.map { Format.measure($0, unit: unit) } ?? "–")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
            }
            Spacer(minLength: 0)
            if let met {
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
            .navigationTitle(kind.title)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
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
            .task { url = PDFExport.make(kind, context: context) }
        }
        .sheetFrame(minWidth: 640, minHeight: 760)
    }
}

/// "PDF" anywhere: opens the preview with sharing.
struct PDFButton: View {
    let kind: PDFKind
    let context: WeekContext
    var title: String?
    @State private var shows = false

    var body: some View {
        Button {
            shows = true
        } label: {
            Label(title ?? "PDF ansehen und teilen", systemImage: "doc.richtext")
        }
        .sheet(isPresented: $shows) {
            PDFPreviewSheet(kind: kind, context: context)
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
