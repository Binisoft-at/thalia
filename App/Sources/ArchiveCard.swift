import SwiftUI
import BinisoftKit
import ThaliaCore

// v9 (decisions 5, 6 and 9): archive weeks in the week. The two week scores stand apart and are
// named plainly – "Wertung laut Unterlagen" (the records' value, never calculated) and "Nach heutigen
// Regeln" (the grades under today's rules, without sick and holiday days). Below them the grades as
// the records give them: category grades Mo–So with Ø (n), goal grades and "Ohne Zuordnung (Archiv)".
// Grades on sick and holiday days stay, dimmed – they don't count today. Nothing is split, multiplied
// or turned into marks.

/// How the two week scores and the archive area are named everywhere (decision 5).
enum ArchiveLabels {
    /// "Wertung laut Unterlagen".
    static let recorded = "Wertung " + ImportWeekSummary.recordedLabel
    /// "Nach heutigen Regeln".
    static let recalculated = capitalized(ImportWeekSummary.recalculatedLabel)
    /// Next to a dimmed grade on a sick or holiday day.
    static let notCounted = "zählt heute nicht"
    /// Grades without a category or goal of the app (decision 6).
    static let unmapped = "Ohne Zuordnung (Archiv)"

    static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }
}

/// Grades as written: at most two decimals, a real 0 stays 0.
enum ArchiveFormat {
    /// "10", "0", "6,67".
    static func grade(_ value: Double) -> String { Format.number(value, decimals: 2) }

    /// A cell: the grade, "·" without one.
    static func cell(_ value: Double?) -> String {
        guard let value else { return "·" }
        return grade(value)
    }

    /// "6,67 (3)"; without a count only the grade.
    static func withCount(_ value: Double, _ count: Int?) -> String {
        guard let count else { return grade(value) }
        return grade(value) + " (\(count))"
    }

    /// A line's week value as the records give it, "–" without one.
    static func value(_ line: ArchiveWeek.Line) -> String {
        guard let value = line.value else { return "–" }
        return grade(value)
    }

    /// "n = 3", nil without a count.
    static func count(_ line: ArchiveWeek.Line) -> String? {
        guard line.value != nil, let count = line.count else { return nil }
        return "n = \(count)"
    }
}

/// A small "Archiv" capsule (preview rows of the past-week import, Rückblick).
struct ArchiveTag: View {
    var body: some View {
        Text("Archiv")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .background(Color.secondary.opacity(0.12), in: .capsule)
            .accessibilityLabel("Archiv-Woche")
    }
}

// MARK: The week's helpers for the archive (typed, so view bodies stay short)

extension WeekContext {
    /// A week without items that has something from old records (grades or a value laut Unterlagen):
    /// the "Archiv" card takes the place of "Noch kein Plan".
    var isArchiveWeek: Bool { !hasPlan && showsArchive }

    /// The number in the week's hero (decision 9): the Scorer's for a week with items (v11 P6.1: a frozen
    /// closed week its stored score); for a week without items the value laut Unterlagen, else the recalculation.
    var heroScore: Double? {
        guard !hasPlan else { return shownScore }
        return WeekLine.historyScore(recorded: recordedScore, computed: recalculatedScore)
    }

    /// v11 P6.1 (§1.2.7): a closed week with items before the current segment keeps the score it stored – everywhere
    /// (hero, goal bars, the week's PDF, the share image). "Nach heutigem Stand" is only a second line
    /// (`FrozenWeekNote`); category rows stay live. Running, open and other closed weeks stay live; a week without
    /// items keeps its archive numbers as before.
    var keepsStoredScore: Bool { hasPlan && isClosed && isFrozen }

    /// v11 P6.1: the week's score as shown – the stored one for a frozen closed week (`recalculatedScore`),
    /// else the Scorer's.
    var shownScore: Double? {
        keepsStoredScore ? recalculatedScore : score.overall
    }

    /// v11 P6.1: the goal scores the frozen closed week stored, nil for any other week (and for a frozen
    /// week that stored none – then the live ones show).
    var storedGoalScores: [String: Double]? {
        guard keepsStoredScore, let stored = plan?.finalGoalScoreMap, !stored.isEmpty else { return nil }
        return stored
    }

    /// v11 P6.1: every goal's score as shown, in the order of `goals` (read once for all bars).
    func shownGoalScores(_ goals: [AnnualGoal]) -> [Double?] {
        if hasPlan, let stored = storedGoalScores { return goals.map { stored[$0.key] } }
        return goals.map { shownGoalScore($0.key) }
    }

    /// v11 P6.1: the goal's week score – the stored one of a frozen closed week, else the Scorer's (no archive values:
    /// the closing sheet, the report and the share image as before).
    func scoredGoalScore(_ key: String) -> Double? {
        if let stored = storedGoalScores { return stored[key] }
        return score.goalWeek[key]?.score
    }

    /// v11 P6.3: how many goals the week scored as shown – the stored count for a frozen closed week.
    var shownGoalsScored: Int {
        guard storedGoalScores != nil, let plan else { return score.goalsScored }
        return plan.finalGoalsScored
    }

    /// v11 (P7.1, P6.14): a progress item of the week counts through an Apple Health measure – the same rule as
    /// `TrackerStore.weekReadsHealth`, from what the week already read.
    var readsHealthProgress: Bool {
        items.contains { item in
            guard item.schedule == .progress, !item.measureCode.isEmpty, let source = measure(code: item.measureCode) else { return false }
            return record(source)?.isHealth ?? false
        }
    }

    /// v11 P6.14 (3): the line under the hero of the running week on Mac and iPad (`lacksHealthValues`).
    static let lacksHealthHint = "Ohne Werte aus Apple Health – am iPhone kann die Wertung höher sein."

    /// v11 P6.14 (3): the running week reads Apple Health and this device lacks such a value on a day so far
    /// (Mac, Watch – `isHealthElsewhere(_:on:)`, which P9 turns off for days the iPhone shares).
    var lacksHealthValues: Bool {
        guard !isClosed, week == today.week, readsHealthProgress else { return false }
        let days: [DayKey] = week.days.filter { $0 <= today }
        return measures.contains { measure in
            guard record(measure)?.isHealth ?? false else { return false }
            return days.contains { isHealthElsewhere(measure, on: $0) }
        }
    }

    /// What the hero's number is for a week without items; nil for a week with items or without a number.
    var heroScoreLabel: String? {
        guard !hasPlan else { return nil }
        if recordedScore != nil { return ArchiveLabels.recorded }
        return recalculatedScore == nil ? nil : ArchiveLabels.recalculated
    }

    /// A goal's score as the week shows it: the Scorer's (v11 P6.1: a frozen closed week's stored one); for a
    /// week without items the archive's value under today's rules.
    func shownGoalScore(_ key: String) -> Double? {
        if hasPlan {
            if let stored = storedGoalScores { return stored[key] }
            return score.goalWeek[key]?.score
        }
        return archiveRecalculation?.goals[key]
    }

    /// "26 Kategoriennoten · 10 Zielnoten"; nil without grades.
    var archiveCountsText: String? {
        guard let archive, archive.hasGrades else { return nil }
        var parts: [String] = []
        let categories: Int = archive.categoryGrades.count
        let goals: Int = archive.goalGrades.count
        if categories > 0 { parts.append(Format.count(categories, "Kategoriennote", "Kategoriennoten")) }
        if goals > 0 { parts.append(Format.count(goals, "Zielnote", "Zielnoten")) }
        return parts.joined(separator: " · ")
    }

    /// The hero's facts for an archive week: the other score and the number of grades.
    var archiveHeroFacts: [(String, String)] {
        var facts: [(String, String)] = []
        if recordedScore != nil { facts.append((ArchiveLabels.recalculated, Format.score(recalculatedScore, outOf: false))) }
        let grades: Int = archive?.grades.count ?? 0
        if grades > 0 { facts.append(("Noten", "\(grades)")) }
        return facts
    }

    /// The line under the Mac hero: for a week without items what the archive holds, else the coverage.
    var archiveCoverageLine: String {
        guard isArchiveWeek else { return coverageLine }
        return archiveCountsText ?? "Archiv-Woche – nur die Wertung"
    }

    /// Some day grade lies on a sick or holiday day (shown dimmed).
    var hasExcusedGrades: Bool {
        let lines: [ArchiveWeek.Line] = archive?.lines ?? []
        return lines.contains { line in line.days.keys.contains { isExcused($0) } }
    }

    /// A day grade on a sick or holiday day: it stays, but doesn't count today.
    func isDimmed(_ line: ArchiveWeek.Line, on day: DayKey) -> Bool {
        line.days[day] != nil && isExcused(day)
    }

    /// The line's value under today's rules where it differs from the records: a category whose day
    /// grades include sick or holiday days ("nach heutigen Regeln 6,67 (2)"), a goal whose value comes
    /// from its categories. nil otherwise (and for lines without mapping).
    func archiveTodayText(_ line: ArchiveWeek.Line) -> String? {
        guard isMapped(line), let recalculation = archiveRecalculation else { return nil }
        switch line.kind {
        case .category:
            guard line.days.keys.contains(where: { isExcused($0) }) else { return nil }
            guard let value = recalculation.categories[line.id] else { return ImportWeekSummary.recalculatedLabel + " –" }
            let count: Int? = recalculation.categoryCounts[line.id]
            return ImportWeekSummary.recalculatedLabel + " " + ArchiveFormat.withCount(value, count)
        case .goal:
            guard let value = recalculation.goals[line.id], let own = line.weekGrade, abs(value - own) > 1e-9 else { return nil }
            return ImportWeekSummary.recalculatedLabel + " " + ArchiveFormat.grade(value) + " aus den Kategoriennoten"
        }
    }

    /// The app's name for a mapped line ("Sport"), nil without mapping.
    func archiveMappedTitle(_ line: ArchiveWeek.Line) -> String? {
        guard isMapped(line) else { return nil }
        switch line.kind {
        case .category: return category(line.id)?.title
        case .goal: return goal(key: line.id)?.title
        }
    }

    /// "Kategoriennote · id 9.9 nicht in der App · Mo 9 · Di 10", "Kategoriennote der Woche" – what an
    /// unmapped line is.
    func archiveUnmappedDetail(_ line: ArchiveWeek.Line) -> String {
        let weekOnly: Bool = line.kind == .category && line.days.isEmpty
        var parts: [String] = [weekOnly ? line.kind.noun + " der Woche" : line.kind.noun]
        if !line.id.isEmpty { parts.append("id \(line.id) nicht in der App") }
        let days: [String] = line.sortedDays.map { entry in
            "\(entry.day.weekday.short) \(ArchiveFormat.grade(entry.value))"
        }
        parts.append(contentsOf: days)
        if line.weekGrade != nil, !line.days.isEmpty { parts.append("Wochennote") }
        return parts.joined(separator: " · ")
    }

    /// The archive lines with a grade on `day`, in sheet order (Today on a day of an archive week).
    func archiveLines(on day: DayKey) -> [ArchiveWeek.Line] {
        let lines: [ArchiveWeek.Line] = archive?.lines ?? []
        return lines.filter { $0.days[day] != nil }
    }

    /// "Urlaub – Noten zählen heute nicht" on a sick or holiday day, else "Mo, 2. Nov." (the day's tooltip).
    func archiveDayHelp(_ day: DayKey) -> String {
        guard isExcused(day) else { return day.shortLabel }
        return excusedName(day) + " – Noten zählen heute nicht"
    }
}

// MARK: The two scores

/// "Wertung laut Unterlagen 9,28" and "Nach heutigen Regeln 8,93 · ohne 2 Urlaubstage", each with its
/// name; "–" with a short reason when one is missing. Then the source of the value.
struct ArchiveScores: View {
    let context: WeekContext

    private var sourceText: String? {
        let source: String = context.archive?.source.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return source.isEmpty ? nil : "Quelle: " + source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ArchiveScoreLine(title: ArchiveLabels.recorded, value: context.recordedScore, note: context.recordedNote, emphasized: true)
            ArchiveScoreLine(title: ArchiveLabels.recalculated, value: context.recalculatedScore, note: context.recalculatedNote)
            if let sourceText {
                Label(sourceText, systemImage: "doc.text.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// One named score with its note.
private struct ArchiveScoreLine: View {
    let title: String
    let value: Double?
    let note: String?
    var emphasized = false

    private var valueColor: Color {
        if value == nil { return .secondary }
        return emphasized ? Brand.accent : .primary
    }

    private var spoken: String {
        let shown: String = Format.score(value, outOf: false)
        guard let note else { return "\(title): \(shown)" }
        return "\(title): \(shown), \(note)"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(Format.score(value, outOf: false))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}

// MARK: The card

/// The "Archiv" card: the two scores, the category grades Mo–So with Ø (n), the goal grades and the
/// grades without mapping. iPhone: label above its days; Mac and wide iPad (`wide`): the table's columns.
struct ArchiveCard: View {
    let context: WeekContext
    /// Mac and wide iPad: the week table's columns and a title row.
    var wide = false
    /// The two scores at the top (the Mac's side panel shows them while it is open).
    var showsScores = true

    private var categoryLines: [ArchiveWeek.Line] { context.archiveCategoryLines }
    private var goalLines: [ArchiveWeek.Line] { context.archiveGoalLines }
    private var unmappedLines: [ArchiveWeek.Line] { context.archiveUnmappedLines }
    private var hasGrades: Bool { context.archive?.hasGrades ?? false }

    /// Wide: the text outside the table's rows lines up with them (`WeekTableColumns.inset`).
    private var inset: CGFloat { wide ? WeekTableColumns.inset : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if wide { titleRow }
            if showsScores {
                ArchiveScores(context: context)
                    .padding(.horizontal, inset)
            }
            if !categoryLines.isEmpty { categorySection }
            if !goalLines.isEmpty { goalSection }
            if !unmappedLines.isEmpty { unmappedSection }
            if !hasGrades {
                Text("Keine Kategorien- oder Zielnoten in den Unterlagen – nur die Wertung.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, inset)
            }
            if context.hasExcusedGrades {
                Label("Blasse Noten liegen auf Krank- oder Urlaubstagen: Sie bleiben im Archiv und zählen nach heutigen Regeln nicht.",
                      systemImage: "cross.case")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, inset)
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label("Archiv", systemImage: "archivebox")
                .font(.headline)
            Spacer(minLength: 8)
            if let counts = context.archiveCountsText {
                Text(counts)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, inset)
    }

    // MARK: Category grades

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArchiveHeading(title: "Kategoriennoten")
                .padding(.horizontal, inset)
            ArchiveDaysHeader(context: context, wide: wide)
            ForEach(categoryLines, id: \.key) { line in
                ArchiveCategoryRow(context: context, line: line, wide: wide)
            }
        }
    }

    // MARK: Goal grades

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArchiveHeading(title: "Zielnoten")
            ForEach(goalLines, id: \.key) { line in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    ArchiveLineTitle(context: context, line: line)
                    Spacer(minLength: 8)
                    ArchiveMean(line: line)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.horizontal, inset)
    }

    // MARK: Without mapping (decision 6)

    private var unmappedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArchiveHeading(title: ArchiveLabels.unmapped)
            ForEach(unmappedLines, id: \.key) { line in
                ArchiveUnmappedRow(context: context, line: line)
            }
            Text("Mit der Bezeichnung aus den Unterlagen gespeichert. Zählt in keiner Rechnung – nichts wird aufgeteilt oder umgedeutet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, inset)
    }
}

/// A small heading inside the card.
private struct ArchiveHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The record's label, below it the app's category or goal with its key and – where it differs – the
/// value under today's rules.
private struct ArchiveLineTitle: View {
    let context: WeekContext
    let line: ArchiveWeek.Line

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            if let mapped = context.archiveMappedTitle(line) {
                HStack(spacing: 4) {
                    KeyBadge(key: line.id)
                    Text(mapped)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
            }
            if let today = context.archiveTodayText(line) {
                Text(today)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Ø and n of a line as the records give them.
private struct ArchiveMean: View {
    let line: ArchiveWeek.Line

    private var spoken: String {
        let value: String = ArchiveFormat.value(line)
        guard let count = line.count, line.value != nil else { return "Durchschnitt \(value)" }
        return "Durchschnitt \(value) aus \(count)"
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(ArchiveFormat.value(line))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            if let count = ArchiveFormat.count(line) {
                Text(count)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}

/// Mo–So above the category grades; sick and holiday days with their symbol.
private struct ArchiveDaysHeader: View {
    let context: WeekContext
    let wide: Bool

    var body: some View {
        if wide {
            WeekTableGrid(days: context.week.days, shaded: context.data.excusedDays) {
                Text("Bezeichnung in den Unterlagen")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } cell: { day in
                ArchiveDayLabel(context: context, day: day)
            } total: {
                Text("Ø (n)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
        } else {
            HStack(spacing: ArchiveCategoryRow.spacing) {
                ForEach(context.week.days, id: \.self) { day in
                    ArchiveDayLabel(context: context, day: day)
                        .frame(width: ArchiveCategoryRow.cellWidth)
                }
                Spacer(minLength: 4)
                Text("Ø (n)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)
        }
    }
}

/// "Mo", or the day type's symbol under it on a sick or holiday day.
private struct ArchiveDayLabel: View {
    let context: WeekContext
    let day: DayKey

    var body: some View {
        VStack(spacing: 0) {
            Text(day.weekday.short)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if context.isExcused(day) {
                Image(systemName: DayTypes.symbol(for: context.dayType(day)))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .help(context.archiveDayHelp(day))
    }
}

/// One category line: the label (and today's category) and its day grades with Ø (n).
private struct ArchiveCategoryRow: View {
    let context: WeekContext
    let line: ArchiveWeek.Line
    let wide: Bool

    static let cellWidth: CGFloat = 30
    static let spacing: CGFloat = 3

    var body: some View {
        if wide {
            WeekTableGrid(days: context.week.days, shaded: context.data.excusedDays) {
                ArchiveLineTitle(context: context, line: line)
            } cell: { day in
                ArchiveGradeCell(context: context, line: line, day: day, width: WeekTableColumns.day - 4)
            } total: {
                ArchiveMean(line: line)
            }
            .padding(.vertical, 3)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ArchiveLineTitle(context: context, line: line)
                HStack(spacing: ArchiveCategoryRow.spacing) {
                    cells
                    Spacer(minLength: 4)
                    ArchiveMean(line: line)
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// The seven days; a line with only a week grade says so instead.
    @ViewBuilder
    private var cells: some View {
        if line.days.isEmpty {
            Text("nur Wochennote")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ForEach(context.week.days, id: \.self) { day in
                ArchiveGradeCell(context: context, line: line, day: day, width: ArchiveCategoryRow.cellWidth)
            }
        }
    }
}

/// One day grade: as written; "·" without one; dimmed on a sick or holiday day ("zählt heute nicht").
private struct ArchiveGradeCell: View {
    let context: WeekContext
    let line: ArchiveWeek.Line
    let day: DayKey
    let width: CGFloat

    private var value: Double? { line.days[day] }
    private var isDimmed: Bool { context.isDimmed(line, on: day) }

    private var textColor: Color {
        if value == nil { return .secondary }
        return isDimmed ? .secondary : .primary
    }

    private var fill: Color {
        if context.isExcused(day) { return Color.secondary.opacity(0.12) }
        return value == nil ? Color.clear : Color.secondary.opacity(0.07)
    }

    private var helpText: String {
        let base: String = "\(day.shortLabel) · \(line.title): \(ArchiveFormat.cell(value))"
        return isDimmed ? base + " – " + ArchiveLabels.notCounted : base
    }

    private var spoken: String {
        guard let value else { return "\(day.weekday.name): keine Note" }
        let grade: String = "\(day.weekday.name): \(ArchiveFormat.grade(value))"
        return isDimmed ? "\(grade), \(context.excusedName(day)), \(ArchiveLabels.notCounted)" : grade
    }

    var body: some View {
        Text(ArchiveFormat.cell(value))
            .strikethrough(isDimmed, color: Color.secondary)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(textColor)
            .opacity(isDimmed ? 0.55 : 1)
            .frame(width: width, height: 24)
            .background(fill, in: .rect(cornerRadius: 6))
            .help(helpText)
            .accessibilityLabel(spoken)
    }
}

/// A grade without mapping: its label as in the records, what it is, its value – never counted.
private struct ArchiveUnmappedRow: View {
    let context: WeekContext
    let line: ArchiveWeek.Line

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(line.title)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                ArchiveMean(line: line)
                    .foregroundStyle(.secondary)
            }
            Text(context.archiveUnmappedDetail(line))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: Today on a day of an archive week

/// Today on a day of an archive week (no items): what the week holds instead of "Noch kein Plan" –
/// the two scores, the day's grades and the way to the week's "Archiv" card.
struct ArchiveDayNotice: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    private var lines: [ArchiveWeek.Line] { context.archiveLines(on: day) }

    private var gradesTitle: String { "Noten am \(day.weekday.name)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(context.week.label) ist eine Archiv-Woche", systemImage: "archivebox")
                .font(.headline)
            Text("Aus alten Unterlagen, ohne Punkte – nichts ist offen oder verpasst.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ArchiveScores(context: context)
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ArchiveHeading(title: gradesTitle)
                    ForEach(lines, id: \.key) { line in
                        ArchiveDayGradeRow(context: context, line: line, day: day)
                    }
                }
            }
            if context.isExcused(day), !lines.isEmpty {
                Label("\(context.excusedName(day)): Die Noten bleiben im Archiv und zählen nach heutigen Regeln nicht.",
                      systemImage: "cross.case")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button {
                app.selectedWeek = context.week
                app.tab = .week
                app.sidebar = .week
            } label: {
                Label("Archiv-Karte der Woche öffnen", systemImage: "tablecells")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }
}

/// One grade of the day: the label as in the records and its value; dimmed on a sick or holiday day,
/// "ohne Zuordnung" where the app has no such category or goal.
private struct ArchiveDayGradeRow: View {
    let context: WeekContext
    let line: ArchiveWeek.Line
    let day: DayKey

    private var value: Double? { line.days[day] }
    private var isDimmed: Bool { context.isDimmed(line, on: day) }
    private var isMapped: Bool { context.isMapped(line) }
    private var textColor: Color { isDimmed ? Color.secondary : Color.primary }

    private var spoken: String {
        let grade: String = "\(line.title): \(ArchiveFormat.cell(value))"
        guard isDimmed else { return isMapped ? grade : grade + ", ohne Zuordnung" }
        return grade + ", " + ArchiveLabels.notCounted
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(line.title)
                    .font(.subheadline)
                    .lineLimit(2)
                if !isMapped {
                    Text("ohne Zuordnung")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Text(ArchiveFormat.cell(value))
                .strikethrough(isDimmed, color: Color.secondary)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(textColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }
}
