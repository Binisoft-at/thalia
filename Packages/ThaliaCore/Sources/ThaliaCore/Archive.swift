import Foundation
import BinisoftKitCore

// Archive weeks (v9): weeks brought in from old records that only say what the records say – the
// week's value, day types and the grades of categories and annual goals (0–10). Nothing is split,
// multiplied or turned into marks or measurements. Two week scores stay apart:
//   "laut Unterlagen"       = `WeekRecord.recordedScore` (the week row's value, never calculated)
//   "nach heutigen Regeln"  = `ArchiveWeek.recalculated(…)`: category = mean of its day grades without
//                             sick and holiday days (only a week grade → that one), goal = mean of its
//                             categories (none → its own grade), week = mean of the goals.
// Means are sum ÷ count of the values that exist; a real 0 counts, nothing is rounded until shown.

/// One grade from old records: a category on a day or in a week, or an annual goal in a week.
public struct ArchiveGrade: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        /// `category_score`: a category's grade on a day (date) or for the week (no date).
        case category = "category_score"
        /// `goal_score`: an annual goal's grade for the week.
        case goal = "goal_score"

        /// "Kategoriennote" / "Zielnote".
        public var noun: String { self == .category ? "Kategoriennote" : "Zielnote" }
        /// "Kategoriennoten" / "Zielnoten".
        public var plural: String { self == .category ? "Kategoriennoten" : "Zielnoten" }
    }

    public var week: WeekKey
    public var kind: Kind
    /// Today's category ("1.1") or goal ("5") when it is clearly the same; empty = without mapping
    /// (kept in the archive with its label, never counted).
    public var id: String
    /// The label exactly as in the records ("Sport / Verein").
    public var title: String
    /// The day of a day grade; nil = a week grade (only the mean is in the records).
    public var day: DayKey?
    /// 0…10, as written (not rounded).
    public var value: Double
    /// Where it comes from ("Scan S. 19").
    public var source: String
    /// Valid days behind a week grade, when the records say (optional).
    public var count: Int?

    public init(week: WeekKey, kind: Kind, id: String = "", title: String, day: DayKey? = nil, value: Double, source: String = "",
                count: Int? = nil) {
        self.week = week
        self.kind = kind
        self.id = id.trimmingCharacters(in: .whitespaces)
        self.title = title
        // A goal's grade is always the week's.
        let gradeDay = kind == .goal ? nil : day
        self.day = gradeDay
        self.value = value
        self.source = source
        self.count = gradeDay == nil ? count : nil
    }

    public var isDayGrade: Bool { day != nil }
    /// Has an id (whether the app has that category or goal is checked where it counts).
    public var isMapped: Bool { !id.isEmpty }

    /// The label's part of the keys: the id, else the normalized title ("t:sport / verein").
    public var labelKey: String {
        id.isEmpty ? "t:" + ImportPlan<ArchiveGrade>.contentKey([title]) : id
    }

    /// One label of one kind in a week: all its day grades and its week grade ("category_score|1.2").
    public var lineKey: String { "\(kind.rawValue)|\(labelKey)" }

    /// The import key (decision 3, the import is repeatable): week · kind · day or "woche" · id or title.
    public var key: String { "\(week.string)|\(kind.rawValue)|\(day?.string ?? "woche")|\(labelKey)" }

    /// A grade as written: "6,67", "6.67", "10", "0" – decimal comma or point, never thousands.
    public static func parseValue(_ text: String) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
        guard !cleaned.isEmpty else { return nil }
        if cleaned.filter({ $0 == "," || $0 == "." }).count <= 1, let value = Double(cleaned.replacingOccurrences(of: ",", with: ".")) {
            return value.isFinite ? value : nil
        }
        return Format.parse(cleaned)
    }

    /// The CSV form of a grade: "6.67", "10" – exact, so a stored archive reads back unchanged even
    /// with more than four decimals (the import stays repeatable).
    public static func csvValue(_ value: Double) -> String {
        let plain = Format.plain(value)
        return Double(plain) == value ? plain : "\(value)"
    }

    public static let range: ClosedRange<Double> = 0...10
}

/// What a week's grades give under today's rules (decision 5): the categories the app has, the
/// goals, the week. Grades without a mapping (or whose category or goal the app doesn't have) never count.
public struct ArchiveRecalculation: Equatable, Sendable {
    /// Category key → its value: mean of the day grades that count today, else its week grade.
    public var categories: [String: Double]
    /// Category key → how many values are behind it (day grades that count, or the week grade's count).
    public var categoryCounts: [String: Int]
    /// Goal key → mean of its categories' values, else its own grade.
    public var goals: [String: Double]
    /// Mean of the goal values (equally weighted); nil without any.
    public var overall: Double?
    /// Days with grades that don't count today (Krank, Urlaub).
    public var excludedDays: [DayKey]
    /// Grades that never count: without a mapping or with a category or goal the app doesn't have.
    public var unmapped: Int

    public init(categories: [String: Double] = [:], categoryCounts: [String: Int] = [:], goals: [String: Double] = [:],
                overall: Double? = nil, excludedDays: [DayKey] = [], unmapped: Int = 0) {
        self.categories = categories
        self.categoryCounts = categoryCounts
        self.goals = goals
        self.overall = overall
        self.excludedDays = excludedDays
        self.unmapped = unmapped
    }

    /// `WeekPlan.finalGoalScores` form: "1=7.5;2=8".
    public var goalScoresText: String {
        goals.keys.sorted { (Int($0) ?? 0, $0) < (Int($1) ?? 0, $1) }
            .compactMap { key in goals[key].map { "\(key)=\(Format.plain($0))" } }
            .joined(separator: ";")
    }

    /// "ohne 2 Urlaubstage", "ohne 1 Krankheitstag", "ohne 3 Tage Krank/Urlaub"; nil when no day was left out.
    /// `dayTypes`: the week's day types (to name them), may be empty.
    public func excludedText(dayTypes: [DayKey: String] = [:]) -> String? {
        guard !excludedDays.isEmpty else { return nil }
        let n = excludedDays.count
        let types = excludedDays.map { (dayTypes[$0] ?? "").lowercased() }
        if types.allSatisfy({ $0.contains("urlaub") }) { return "ohne " + Format.count(n, "Urlaubstag", "Urlaubstage") }
        if types.allSatisfy({ $0.contains("krank") }) { return "ohne " + Format.count(n, "Krankheitstag", "Krankheitstage") }
        return "ohne " + Format.count(n, "Tag", "Tage") + " Krank/Urlaub"
    }
}

/// The grades of one archive week, as stored in the setting `archive.<week>` (decision 7) and shown
/// on the week's "Archiv" card. Built from any grades: only the week's are kept, one per key (the last).
public struct ArchiveWeek: Equatable, Sendable {
    public var week: WeekKey
    /// One per key, in sheet order (categories by key, then without mapping; then goals).
    public private(set) var grades: [ArchiveGrade]
    /// Where the week's value comes from (the week row's `note`, "Scan S. 19"); may be empty.
    public var source: String

    public init(week: WeekKey, grades: [ArchiveGrade] = [], source: String = "") {
        self.week = week
        self.source = source
        self.grades = ArchiveWeek.normalized(grades.filter { $0.week == week })
    }

    /// No grades and no source: the setting is removed.
    public var isEmpty: Bool { grades.isEmpty && source.trimmingCharacters(in: .whitespaces).isEmpty }
    public var hasGrades: Bool { !grades.isEmpty }
    public var categoryGrades: [ArchiveGrade] { grades.filter { $0.kind == .category } }
    public var goalGrades: [ArchiveGrade] { grades.filter { $0.kind == .goal } }

    /// The stored grades updated by key with `incoming` (the import without "Archivdaten ersetzen").
    public func merging(_ incoming: [ArchiveGrade], source: String? = nil) -> ArchiveWeek {
        let keys = Set(incoming.filter { $0.week == week }.map(\.key))
        var result = ArchiveWeek(week: week, grades: grades.filter { !keys.contains($0.key) } + incoming, source: self.source)
        if let source, !source.trimmingCharacters(in: .whitespaces).isEmpty { result.source = source }
        return result
    }

    // MARK: Means (decision 4)

    /// Sum ÷ count of the values that exist; nil without values. Not rounded (only the display rounds).
    public static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// One label of one kind: its day grades, its week grade and the week value as the records give it.
    public struct Line: Equatable, Sendable {
        public var kind: ArchiveGrade.Kind
        /// Today's category or goal, empty without mapping.
        public var id: String
        /// The label as in the records (the last row's spelling).
        public var title: String
        /// Day grades by day.
        public var days: [DayKey: Double]
        /// The explicit week grade (a row without date), if any.
        public var weekGrade: Double?
        /// Its count of valid days, if the records give one.
        public var weekCount: Int?
        /// The sources of the label's rows, in order, without repeats.
        public var sources: [String]

        public var key: String { "\(kind.rawValue)|\(id.isEmpty ? "t:" + ImportPlan<ArchiveGrade>.contentKey([title]) : id)" }

        /// The week's grade of this label (decision 4): the week row, else the mean of the day grades.
        public var value: Double? { weekGrade ?? ArchiveWeek.mean(Array(days.values)) }

        /// n behind `value`: the week row's count, else the number of day grades (nil for a week row without count).
        public var count: Int? {
            if weekGrade != nil { return weekCount }
            return days.isEmpty ? nil : days.count
        }

        /// The day grades in day order.
        public var sortedDays: [(day: DayKey, value: Double)] {
            days.keys.sorted().map { ($0, days[$0] ?? 0) }
        }
    }

    /// One line per label, in sheet order: categories, then goals.
    public var lines: [Line] {
        var order: [String] = []
        var byKey: [String: Line] = [:]
        for grade in grades {
            let key = grade.lineKey
            var line = byKey[key] ?? Line(kind: grade.kind, id: grade.id, title: grade.title, days: [:], weekGrade: nil,
                                          weekCount: nil, sources: [])
            if byKey[key] == nil { order.append(key) }
            line.title = grade.title
            if let day = grade.day {
                line.days[day] = grade.value
            } else {
                line.weekGrade = grade.value
                line.weekCount = grade.count
            }
            if !grade.source.isEmpty, !line.sources.contains(grade.source) { line.sources.append(grade.source) }
            byKey[key] = line
        }
        return order.compactMap { byKey[$0] }
    }

    public var categoryLines: [Line] { lines.filter { $0.kind == .category } }
    public var goalLines: [Line] { lines.filter { $0.kind == .goal } }

    /// The week grade of a label as the records give it (decision 4), by its id ("1.2", "5"); nil when
    /// there is none.
    public func weeklyGrade(_ kind: ArchiveGrade.Kind, id: String) -> Double? {
        guard !id.isEmpty else { return nil }
        return lines.first { $0.kind == kind && $0.id == id }?.value
    }

    // MARK: Today's rules (decision 5)

    /// The week under today's rules. A category counts when it is mapped and the app has it: the mean
    /// of its day grades without `excusedDays` (sick and holiday days); with only a week grade, that one.
    /// A goal: the mean of its categories' values; without any, its own grade. The week: the mean of
    /// the goal values. Grades without a mapping never count. `goals` empty: the goals of `categories`.
    public func recalculated(categories: [CategoryRecord], goals: [GoalRecord], excusedDays: Set<DayKey>) -> ArchiveRecalculation {
        var result = ArchiveRecalculation()
        let categoryGoal = Dictionary(categories.map { ($0.key, $0.goalKey) }, uniquingKeysWith: { first, _ in first })
        var goalKeys = Set(goals.map(\.key))
        if goalKeys.isEmpty { goalKeys = Set(categories.map(\.goalKey)) }
        var excluded: Set<DayKey> = []
        for line in lines {
            switch line.kind {
            case .category:
                guard !line.id.isEmpty, categoryGoal[line.id] != nil else {
                    result.unmapped += line.days.count + (line.weekGrade == nil ? 0 : 1)
                    continue
                }
                if !line.days.isEmpty {
                    let counting = line.days.filter { !excusedDays.contains($0.key) }
                    excluded.formUnion(line.days.keys.filter(excusedDays.contains))
                    if let value = ArchiveWeek.mean(Array(counting.values)) {
                        result.categories[line.id] = value
                        result.categoryCounts[line.id] = counting.count
                    }
                } else if let value = line.weekGrade {
                    result.categories[line.id] = value
                    if let count = line.weekCount { result.categoryCounts[line.id] = count }
                }
            case .goal:
                if line.id.isEmpty || !goalKeys.contains(line.id) { result.unmapped += line.weekGrade == nil ? 0 : 1 }
            }
        }
        for goal in goalKeys {
            let values = result.categories.filter { categoryGoal[$0.key] == goal }.map(\.value)
            if let value = ArchiveWeek.mean(values) {
                result.goals[goal] = value
            } else if let own = goalLines.first(where: { $0.id == goal })?.weekGrade {
                result.goals[goal] = own
            }
        }
        result.overall = ArchiveWeek.mean(Array(result.goals.values))
        result.excludedDays = excluded.sorted()
        return result
    }

    // MARK: Storage (decision 7)

    /// "archive." – the prefix of every archive setting.
    public static let settingPrefix = "archive."

    /// The setting's key: "archive.2026-W43".
    public static func settingKey(_ week: WeekKey) -> String { settingPrefix + week.string }

    /// The week of a setting key ("archive.2026-W43" → 2026-W43), nil for other settings.
    public static func week(settingKey: String) -> WeekKey? {
        guard settingKey.hasPrefix(settingPrefix) else { return nil }
        return WeekKey(String(settingKey.dropFirst(settingPrefix.count)))
    }

    /// The setting's value: the header, the week row (its `note` = the source) and the grade rows.
    public var csv: String {
        var doc = PlanCSV.Document()
        doc.addArchives([self])
        if doc.grades.isEmpty, doc.weekNotes.isEmpty { doc.weeks = [WeekRecord(week: week)] }
        return PlanCSV.export(doc)
    }

    /// Reads a stored setting back; anything unreadable is left out (an empty archive at worst).
    public init(csv: String, week: WeekKey) {
        let doc = PlanCSV.parse(csv)
        self.init(week: week, grades: doc.grades, source: doc.weekNotes[week] ?? "")
    }

    // MARK: Order

    static func normalized(_ grades: [ArchiveGrade]) -> [ArchiveGrade] {
        var latest: [String: ArchiveGrade] = [:]
        var firstSeen: [String: Int] = [:]
        for (index, grade) in grades.enumerated() {
            latest[grade.key] = grade
            if firstSeen[grade.key] == nil { firstSeen[grade.key] = index }
        }
        return latest.values.sorted { a, b in
            let left = sortKey(a)
            let right = sortKey(b)
            if left.0 != right.0 { return left.0 < right.0 }
            if left.1 != right.1 { return left.1.lexicographicallyPrecedes(right.1) }
            if left.2 != right.2 { return left.2 < right.2 }
            // Week grade before the days, days in order.
            switch (a.day, b.day) {
            case (nil, nil): return (firstSeen[a.key] ?? 0) < (firstSeen[b.key] ?? 0)
            case (nil, _): return true
            case (_, nil): return false
            case let (x?, y?): return x < y
            }
        }
    }

    /// (group, numeric id, label): categories with an id, categories without, goals with an id, goals without.
    static func sortKey(_ grade: ArchiveGrade) -> (Int, [Int], String) {
        let group = (grade.kind == .category ? 0 : 2) + (grade.id.isEmpty ? 1 : 0)
        let number = grade.id.isEmpty ? [] : CategoryRecord.sortKey(grade.id)
        return (group, number, grade.id.isEmpty ? ImportPlan<ArchiveGrade>.contentKey([grade.title]) : grade.id)
    }
}

extension PlanCSV.Document {
    /// Every week the file touches: week rows, items, measurements, marks, day rows, grades.
    public var fileWeeks: Set<WeekKey> {
        var all = Set(weeks.map(\.week)).union(plannedWeeks).union(measuredWeeks)
        for mark in marks { all.insert(mark.week) }
        for day in days { all.insert(day.day.week) }
        for grade in grades { all.insert(grade.week) }
        return all
    }

    /// Archive weeks (v9, decision 1): weeks of the file (a week row or grades) without item rows and
    /// without marks. The import never creates items for them, "Leere Felder als ✗ zählen" never fills
    /// them (not even on the app's plan), and they are closed like every past week – nothing open,
    /// nothing missed.
    public var archiveWeeks: Set<WeekKey> {
        var result = Set(weeks.map(\.week)).union(grades.map(\.week))
        result.subtract(plannedWeeks)
        result.subtract(marks.map(\.week))
        return result
    }

    /// The archive of one week in the file: its grades and the week row's source.
    public func archive(_ week: WeekKey) -> ArchiveWeek {
        ArchiveWeek(week: week, grades: grades.filter { $0.week == week }, source: weekNotes[week] ?? "")
    }

    /// Puts stored archives into the document (backup, `exportDocument`): their grades and sources.
    public mutating func addArchives(_ archives: [ArchiveWeek]) {
        for archive in archives {
            grades.removeAll { $0.week == archive.week }
            grades.append(contentsOf: archive.grades)
            let source = archive.source.trimmingCharacters(in: .whitespaces)
            if !source.isEmpty { weekNotes[archive.week] = source }
        }
    }
}

extension ExistingState {
    /// Every stored grade by its import key.
    public var gradeRecords: [String: ArchiveGrade] {
        var result: [String: ArchiveGrade] = [:]
        for archive in archiveGrades.values {
            for grade in archive.grades { result[grade.key] = grade }
        }
        return result
    }

    /// Whether the app has anything for `week` that "Archivdaten dieser Wochen ersetzen" moves to the
    /// archive (decision 2): items, measurements, marks, values, own scores, day types and notes,
    /// closings, grades, the reported score.
    public func hasArchiveContent(_ week: WeekKey) -> Bool {
        if items.values.contains(where: { $0.week == week }) || measures.values.contains(where: { $0.week == week }) { return true }
        if marks.values.contains(where: { $0.week == week && $0.mark != nil }) { return true }
        if entries.values.contains(where: { week.contains($0.day) }) || scores.values.contains(where: { week.contains($0.day) }) { return true }
        if days.values.contains(where: { week.contains($0.day) && (!$0.dayType.isEmpty || !$0.note.isEmpty) }) { return true }
        if closedWeeks.contains(week) || closedDays.contains(where: { week.contains($0) }) { return true }
        if archiveGrades[week]?.isEmpty == false { return true }
        return weeks[week.string]?.recordedScore != nil
    }

    /// The state as it is once `weeks` went to the archive ("Archivdaten ersetzen"): without their
    /// items, measurements, marks, values, own scores, day types, closings, grades and reported
    /// score. The week rows (motto, context) stay, as do work blocks, notes and reflections.
    public func clearing(_ weeks: Set<WeekKey>) -> ExistingState {
        guard !weeks.isEmpty else { return self }
        var state = self
        state.items = items.filter { !weeks.contains($0.value.week) }
        state.measures = measures.filter { !weeks.contains($0.value.week) }
        state.marks = marks.filter { !weeks.contains($0.value.week) }
        state.entries = entries.filter { !weeks.contains($0.value.day.week) }
        state.scores = scores.filter { !weeks.contains($0.value.day.week) }
        state.days = days.filter { !weeks.contains($0.value.day.week) }
        state.closedDays = closedDays.filter { !weeks.contains($0.week) }
        state.closedWeeks.subtract(weeks)
        for week in weeks {
            state.archiveGrades[week] = nil
            state.weeks[week.string]?.recordedScore = nil
        }
        return state
    }
}
