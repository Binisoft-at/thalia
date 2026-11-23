import Foundation

// Scoring (equally weighted annual goals since KW42 2026, v2 rules):
//   item:      ✓ = 1 · ½ = 0.5 · ✗ = 0 · N/A and blank don't count
//   category:  day score = 10 × earned ÷ applicable – only once the category is complete for the
//              day (no blank due items). Until then the screen shows how much is filled in.
//   goal:      average of its categories – only when every category with items has a score
//   week:      category = average of its valid days → goal → overall = average of the goals (equally weighted)
// Weekly quotas: each ✓ ½ ✗ uses a slot; what's missing counts as missed once the week is over.
// Progress items (stammloop 8 PH/week): a day with a value in the linked measurement counts as
// "daran gearbeitet" (✓), a day without as N/A – derived, not ticked (v3). Worked days are resolved
// from the weekly target once it's reached or the week is over (reached → 1, partly → 0.5,
// nothing → 0). Marks are never rewritten – the resolution is calculated.
// Free days (Familientag, Erholungstag, Urlaub …): work-only items are not due (N/A).
// Secondary items ("Nebensache"): count when filled in, an empty one blocks nothing.
// Sick and holiday days (Krank, Urlaub – v8): nothing is due, marks and own scores of the day don't
// count, a weekly quota's share of them counts half (rule B3), weekly targets shrink to the days
// that still count (Measures.targetShare). A week with only such days has no score.

/// The inputs for one week.
public struct WeekData: Sendable {
    public var week: WeekKey
    public var goals: [GoalRecord]
    public var categories: [CategoryRecord]
    public var items: [ItemRecord]
    /// Marks by `"<itemCode>|<day>"`.
    public var marks: [String: Mark]
    /// The person's own category scores by `"<categoryKey>|<day>"`.
    public var overrides: [String: Double]
    /// The week is over (or closed): quotas and progress items are settled.
    public var isComplete: Bool
    /// Progress items: share of the weekly target reached, by item code (1 = reached).
    public var progress: [String: Double]
    /// Progress items with a linked measurement: the days it moved (derived ✓).
    public var worked: [String: Set<DayKey>]
    /// Days without work (Familientag, Erholungstag, Urlaub …).
    public var workFreeDays: Set<DayKey>
    /// Categories whose items are work-day-only unless an item says otherwise.
    public let workCategories: Set<String>
    /// Sick and holiday days (`DayTypes.isExcused`, v8): nothing is due, marks and own scores of the
    /// day don't count, a weekly quota's share of them counts half.
    public var excusedDays: Set<DayKey>

    public init(week: WeekKey, goals: [GoalRecord], categories: [CategoryRecord], items: [ItemRecord],
                marks: [String: Mark] = [:], overrides: [String: Double] = [:], isComplete: Bool = false,
                progress: [String: Double] = [:], worked: [String: Set<DayKey>] = [:], workFreeDays: Set<DayKey> = [],
                excusedDays: Set<DayKey> = []) {
        self.week = week
        self.goals = goals
        self.categories = categories
        self.items = items.filter { $0.week == week }
        self.marks = marks
        self.overrides = overrides
        self.isComplete = isComplete
        self.progress = progress
        self.worked = worked
        self.workFreeDays = workFreeDays
        self.excusedDays = excusedDays
        self.workCategories = WeekData.workCategories(items: self.items, categories: categories)
    }

    /// Categories whose items are work-day-only unless an item says otherwise: without any explicit
    /// day rules in the plan, Business (goal 3) except the morning routine. `items` are the week's.
    /// Also for `Measures.progressRatio`, which runs before the `WeekData` exists (v8).
    public static func workCategories(items: [ItemRecord], categories: [CategoryRecord]) -> Set<String> {
        let explicit = items.contains { $0.dayRule != .auto }
        return explicit ? [] : Set(categories.filter { $0.goalKey == "3" && $0.key != "3.1" }.map(\.key))
    }

    /// Only on work days (explicitly, or by its category when the plan says nothing).
    public func isWorkOnly(_ item: ItemRecord) -> Bool {
        switch item.dayRule {
        case .workOnly: return true
        case .always: return false
        case .auto: return workCategories.contains(item.categoryKey)
        }
    }

    /// A sick or holiday day (v8): it doesn't count in the week's score.
    public func isExcused(_ day: DayKey) -> Bool { excusedDays.contains(day) }

    /// Scheduled that day, not left out because the day is free, and the day isn't excused.
    public func applies(_ item: ItemRecord, on day: DayKey) -> Bool {
        !excusedDays.contains(day) && isPlanned(item, on: day)
    }

    /// Scheduled that day and not left out because the day is free – whether or not the day is
    /// excused (the "planned days" of the v8 rules).
    public func isPlanned(_ item: ItemRecord, on day: DayKey) -> Bool {
        item.applies(on: day) && !(workFreeDays.contains(day) && isWorkOnly(item))
    }

    /// The item's planned days this week (P), excused ones included.
    public func plannedDays(_ item: ItemRecord) -> [DayKey] {
        week.days.filter { isPlanned(item, on: $0) }
    }

    /// The recorded mark, also on an excused day where it doesn't count (shown dimmed).
    public func recordedMark(_ item: ItemRecord, on day: DayKey) -> Mark? {
        marks[WeekData.markKey(item.code, day)]
    }

    /// Left out today only because it's a free day (shown as N/A, never blank).
    public func isFreeDayExcluded(_ item: ItemRecord, on day: DayKey) -> Bool {
        item.applies(on: day) && workFreeDays.contains(day) && isWorkOnly(item)
    }

    /// A required item still blank on `day` (R5) – exactly what `CategoryDay.blank` counts: fixed or
    /// progress, due that day, not a "Nebensache", no mark (derived progress items are never blank).
    public func isOpenRequired(_ item: ItemRecord, on day: DayKey) -> Bool {
        guard item.schedule == .fixed || item.schedule == .progress, !item.secondary, applies(item, on: day) else { return false }
        return mark(item, on: day) == nil
    }

    /// A progress item that follows its measurement (no ticking).
    public func isDerived(_ item: ItemRecord) -> Bool {
        item.schedule == .progress && worked[item.code] != nil
    }

    public static func markKey(_ itemCode: String, _ day: DayKey) -> String { "\(itemCode)|\(day.string)" }
    public static func overrideKey(_ categoryKey: String, _ day: DayKey) -> String { "\(categoryKey)|\(day.string)" }

    /// The mark that counts: N/A on excused days (recorded marks stay stored but don't count),
    /// derived for linked progress items, N/A on free days for work-only items, otherwise the
    /// recorded one.
    public func mark(_ item: ItemRecord, on day: DayKey) -> Mark? {
        if excusedDays.contains(day) {
            let shown = item.applies(on: day) || worked[item.code]?.contains(day) == true || recordedMark(item, on: day) != nil
            return shown ? .notApplicable : nil
        }
        if isFreeDayExcluded(item, on: day) { return .notApplicable }
        if let days = worked[item.code], item.schedule == .progress {
            guard item.applies(on: day) || days.contains(day) else { return nil }
            return days.contains(day) ? .done : .notApplicable
        }
        return marks[WeekData.markKey(item.code, day)]
    }

    /// A progress item's points for a worked day, or nil while it's still open.
    public func progressPoints(_ item: ItemRecord) -> Double? {
        guard item.schedule == .progress else { return nil }
        guard let ratio = progress[item.code] else { return 1 }
        guard ratio >= 1 - 1e-9 || isComplete else { return nil }
        if ratio >= 1 - 1e-9 { return 1 }
        return ratio > 0 ? 0.5 : 0
    }

    /// Settled: target reached early or week over.
    public func isProgressSettled(_ item: ItemRecord) -> Bool {
        guard item.schedule == .progress else { return false }
        return progressPoints(item) != nil
    }
}

/// A category on one day.
public struct CategoryDay: Equatable, Sendable {
    /// 0…10 once complete (or overridden), else nil.
    public var score: Double?
    public var earned: Double = 0
    public var applicable: Double = 0
    /// Items due that day (fixed and progress).
    public var due = 0
    /// Of those, how many have no entry yet.
    public var blank = 0
    /// Worked progress days still waiting for the week.
    public var pending = 0
    /// Weekly quota / progress points that were missed and are booked on this day.
    public var shortfall: Double = 0
    /// Quota units booked on this day that couldn't be done because of sick or holiday days:
    /// they count half (rule B3, v8).
    public var excused: Double = 0
    public var knockedOut = false
    public var overridden = false
    /// Score before the person's override, or the provisional score while incomplete.
    public var calculated: Double?

    public init() {}

    public var isComplete: Bool { blank == 0 }
    /// Share of due items filled in (1 when nothing is due).
    public var fill: Double { due == 0 ? 1 : Double(due - blank) / Double(due) }
    /// Something counts or something is still blank. All N/A (or only progress days waiting for
    /// the week) means nothing to score – such a category doesn't hold its goal back.
    public var hasItems: Bool { applicable > 0 || blank > 0 }
}

public struct GoalWeek: Equatable, Sendable {
    public var score: Double?
    public var categoriesScored: Int
    public var categoriesTotal: Int
}

public struct DayOverall: Equatable, Sendable {
    /// Average of the goals that are complete that day.
    public var score: Double?
    public var goalsScored: Int
    /// Goals with something due that day.
    public var goalsDue: Int
    public var due: Int
    public var blank: Int
    /// A sick or holiday day: nothing due, never open (v8).
    public var isExcused: Bool = false

    /// Share of due items filled in.
    public var coverage: Double { due == 0 ? 1 : Double(due - blank) / Double(due) }
    /// "62 %"
    public var coverageText: String { "\(Int((coverage * 100).rounded())) %" }
    /// Every goal with something due has a score.
    public var isComplete: Bool { goalsScored == goalsDue }
}

public struct WeekScore: Sendable {
    public let week: WeekKey
    public var categoryDays: [String: [DayKey: CategoryDay]] = [:]
    /// Weekly average per category (only categories with at least one valid day).
    public var categoryWeek: [String: Double] = [:]
    public var goalWeek: [String: GoalWeek] = [:]
    public var overall: Double?
    public var goalsScored = 0
    /// Goals that count this week: all goals except those whose items fell only on sick or holiday days.
    public var goalsTotal = 0
    public var days: [DayKey: DayOverall] = [:]
    /// The week's sick and holiday days (v8).
    public var excusedDays: Set<DayKey> = []
    /// Goals left out of `goalsTotal` because all their planned days were excused.
    public var goalsExcused = 0
    /// Every day with something planned was excused: the week has no score (v8).
    public var isExcused = false

    public func category(_ key: String, on day: DayKey) -> CategoryDay {
        categoryDays[key]?[day] ?? CategoryDay()
    }

    /// Every goal scored: comparable with other complete weeks.
    public var isComplete: Bool { goalsTotal > 0 && goalsScored == goalsTotal }

    /// Shown instead of the coverage when the whole week was sick or on holiday.
    public static let excusedText = "Woche zählt nicht (krank/Urlaub)"
    /// The short label for such a week in charts and tables (instead of a gap).
    public static let excusedLabel = "entschuldigt"

    /// "10/10 Ziele bewertet" or "9/10 Ziele bewertet – nicht voll vergleichbar";
    /// "Woche zählt nicht (krank/Urlaub)" for a fully excused week.
    public var coverageText: String {
        if isExcused { return WeekScore.excusedText }
        let base = "\(goalsScored)/\(goalsTotal) Ziele bewertet"
        return isComplete ? base : base + " – nicht voll vergleichbar"
    }
}

public enum Scorer {
    public static func score(_ data: WeekData) -> WeekScore {
        let days = data.week.days
        var result = WeekScore(week: data.week)
        let itemsByCategory = Dictionary(grouping: data.items, by: \.categoryKey)

        for category in data.categories {
            let items = itemsByCategory[category.key] ?? []
            var perDay: [DayKey: CategoryDay] = [:]
            for day in days {
                perDay[day] = categoryDay(items: items, day: day, data: data)
            }
            if data.isComplete {
                bookShortfalls(items: items, days: days, data: data, into: &perDay)
            }
            for day in days {
                guard var entry = perDay[day] else { continue }
                if entry.applicable > 0 {
                    let calculated = entry.knockedOut ? 0 : 10 * entry.earned / entry.applicable
                    entry.calculated = calculated
                    // v11 P1.9: the day a missed weekly quota is booked on gets its score once the week is
                    // over, even with blank items – they don't count (as everywhere), the shortfall does.
                    let booked = data.isComplete && (entry.shortfall > 0 || entry.excused > 0)
                    entry.score = entry.isComplete || booked ? calculated : nil
                }
                // Own scores don't count on excused days (v8).
                if !data.isExcused(day), let override = data.overrides[WeekData.overrideKey(category.key, day)] {
                    entry.score = min(10, max(0, override))
                    entry.overridden = true
                }
                perDay[day] = entry
            }
            result.categoryDays[category.key] = perDay
            let valid = days.compactMap { perDay[$0]?.score }
            if !valid.isEmpty {
                result.categoryWeek[category.key] = valid.reduce(0, +) / Double(valid.count)
            }
        }

        let categoriesByGoal = Dictionary(grouping: data.categories, by: \.goalKey)
        let excused = Set(days.filter(data.isExcused))
        result.excusedDays = excused
        var goalScores: [Double] = []
        var goalsExcused = 0
        for goal in data.goals {
            let categories = categoriesByGoal[goal.key] ?? []
            // Categories with nothing due or counted this week don't block the goal.
            let relevant = categories.filter { category in
                days.contains { result.category(category.key, on: $0).hasItems }
            }
            let scores = relevant.compactMap { result.categoryWeek[$0.key] }
            let complete = !relevant.isEmpty && scores.count == relevant.count
            let score = complete ? scores.reduce(0, +) / Double(scores.count) : nil
            result.goalWeek[goal.key] = GoalWeek(score: score, categoriesScored: scores.count, categoriesTotal: relevant.count)
            if let score { goalScores.append(score) }
            // A goal whose items fell only on excused days doesn't count (v8); goals without items still do.
            if relevant.isEmpty, !excused.isEmpty {
                let keys = Set(categories.map(\.key))
                let planned = data.items.filter { keys.contains($0.categoryKey) && $0.schedule.isScored }.flatMap(data.plannedDays)
                if !planned.isEmpty, planned.allSatisfy(excused.contains) { goalsExcused += 1 }
            }
        }
        // The whole week excused: every day with something planned was sick or on holiday.
        let plannedDays = Set(data.items.filter(\.schedule.isScored).flatMap(data.plannedDays))
        result.isExcused = !excused.isEmpty && (plannedDays.isEmpty ? excused.count == days.count : plannedDays.isSubset(of: excused))
        result.goalsExcused = goalsExcused
        result.goalsTotal = data.goals.count - goalsExcused
        result.goalsScored = goalScores.count
        result.overall = goalScores.isEmpty || result.isExcused ? nil : goalScores.reduce(0, +) / Double(goalScores.count)

        for day in days {
            var dayGoalScores: [Double] = []
            var goalsDue = 0
            var due = 0
            var blank = 0
            for goal in data.goals {
                let entries = (categoriesByGoal[goal.key] ?? []).map { result.category($0.key, on: day) }.filter(\.hasItems)
                guard !entries.isEmpty else { continue }
                goalsDue += 1
                let scores = entries.compactMap(\.score)
                if scores.count == entries.count { dayGoalScores.append(scores.reduce(0, +) / Double(scores.count)) }
            }
            for category in data.categories {
                let entry = result.category(category.key, on: day)
                due += entry.due
                blank += entry.blank
            }
            result.days[day] = DayOverall(
                score: dayGoalScores.isEmpty ? nil : dayGoalScores.reduce(0, +) / Double(dayGoalScores.count),
                goalsScored: dayGoalScores.count, goalsDue: goalsDue, due: due, blank: blank, isExcused: excused.contains(day)
            )
        }
        return result
    }

    /// One category on one day, before weekly shortfalls and overrides.
    static func categoryDay(items: [ItemRecord], day: DayKey, data: WeekData) -> CategoryDay {
        var entry = CategoryDay()
        for item in items where item.schedule.isScored {
            let mark = data.mark(item, on: day)
            // Secondary items only count once filled in; derived progress items are never blank.
            let mustFill = !(item.secondary && mark == nil)
            if item.schedule == .fixed || item.schedule == .progress, data.applies(item, on: day), mustFill {
                entry.due += 1
                if data.isOpenRequired(item, on: day) { entry.blank += 1 }
            }
            guard let mark, let points = mark.points else { continue }
            if item.schedule == .progress {
                guard mark == .done || mark == .partial else { continue }
                if let resolved = data.progressPoints(item) {
                    entry.applicable += 1
                    entry.earned += resolved
                } else {
                    entry.pending += 1
                }
                continue
            }
            entry.applicable += 1
            entry.earned += points
            if item.knockout, mark == .missed { entry.knockedOut = true }
        }
        return entry
    }

    /// Weekly quotas and progress items that were never worked on, once the week is over.
    ///
    /// Rule B3 (v8) for "n× pro Woche": P = planned days, E = the excused ones, A = the rest.
    /// missing = n − used (✓ ½ ✗ in A), share = n·|E|/|P|, excused = min(missing, share).
    /// Booked on the last day of A: applicable += missing, earned += ½·excused. A empty → nothing.
    static func bookShortfalls(items: [ItemRecord], days: [DayKey], data: WeekData, into perDay: inout [DayKey: CategoryDay]) {
        for item in items {
            let available = data.plannedDays(item).filter { !data.isExcused($0) }
            let lastDay: DayKey
            if let last = available.last {
                lastDay = last
            } else if data.excusedDays.isEmpty {
                // Nothing planned at all (unchanged before v8): the week's last day.
                lastDay = days[days.count - 1]
            } else {
                // Only excused days (or nothing planned in a week with excused days): not scored.
                continue
            }
            var missing = 0.0
            var excused = 0.0
            if let target = item.schedule.weeklyTarget {
                let used = days.filter { data.mark(item, on: $0)?.counts == true }.count
                missing = Double(max(0, target - used))
                excused = min(missing, quotaShare(item, data: data))
            } else if item.schedule == .progress, (data.progress[item.code] ?? 1) < 1 - 1e-9 {
                let worked = days.contains { data.mark(item, on: $0) == .done || data.mark(item, on: $0) == .partial }
                missing = worked ? 0 : 1
            }
            guard missing > 0, var entry = perDay[lastDay] else { continue }
            entry.applicable += missing
            entry.earned += 0.5 * excused
            entry.shortfall += missing - 0.5 * excused
            entry.excused += excused
            perDay[lastDay] = entry
        }
    }

    /// The part of an "n× pro Woche" quota that falls on excused days at an even pace: n·|E|/|P|
    /// (0 for other items or without excused days). Up to this many missing units count half.
    public static func quotaShare(_ item: ItemRecord, data: WeekData) -> Double {
        guard let target = item.schedule.weeklyTarget, !data.excusedDays.isEmpty else { return 0 }
        let planned = data.plannedDays(item)
        guard !planned.isEmpty else { return 0 }
        let excused = planned.filter(data.isExcused).count
        return Double(target) * Double(excused) / Double(planned.count)
    }

    /// The quota units that count half because of sick or holiday days, once the week is over:
    /// min(missing, share) – 0 while the week runs or when nothing is missing.
    public static func excusedUnits(_ item: ItemRecord, data: WeekData) -> Double {
        guard let target = item.schedule.weeklyTarget, data.isComplete else { return 0 }
        guard data.plannedDays(item).contains(where: { !data.isExcused($0) }) else { return 0 }
        let used = data.week.days.filter { data.mark(item, on: $0)?.counts == true }.count
        return min(Double(max(0, target - used)), quotaShare(item, data: data))
    }

    /// A week counts as complete once its Sunday is over or it was closed.
    public static func isComplete(week: WeekKey, today: DayKey, closed: Bool) -> Bool {
        closed || today > week.sunday
    }

    /// N/A for an "n× pro Woche" item only while enough of its days are left to still reach n
    /// (3× a week with nothing done: possible until Thursday, not on Friday). With excused days the
    /// quota's share of them is left out: needed = ⌈n − share⌉ − used (v8).
    public static func canMarkNotApplicable(_ item: ItemRecord, on day: DayKey, data: WeekData) -> Bool {
        guard let target = item.schedule.weeklyTarget else { return true }
        let used = data.week.days.filter { $0 != day && data.mark(item, on: $0)?.counts == true }.count
        let required = Int((Double(target) - quotaShare(item, data: data) - 1e-9).rounded(.up))
        let needed = required - used
        guard needed > 0 else { return true }
        let remaining = data.week.days.filter { $0 > day && data.applies(item, on: $0) }.count
        return remaining >= needed
    }

    /// An n×-per-week item whose quota was already met on other days: left out of the daily list.
    public static func isQuotaMetElsewhere(_ item: ItemRecord, on day: DayKey, data: WeekData) -> Bool {
        guard let target = item.schedule.weeklyTarget else { return false }
        let done = data.week.days.filter { $0 != day && (data.mark(item, on: $0) == .done || data.mark(item, on: $0) == .partial) }.count
        return done >= target && data.mark(item, on: day) == nil
    }

    /// The marks that make sense for an item on a day (the buttons in a row).
    public static func options(for item: ItemRecord, on day: DayKey, data: WeekData) -> [Mark] {
        if data.isExcused(day) || data.isFreeDayExcluded(item, on: day) { return [] }
        switch item.schedule {
        case .progress:
            // Derived from the measurement: nothing to tick.
            return data.isDerived(item) ? [] : [.done, .notApplicable]
        case .weekly:
            return canMarkNotApplicable(item, on: day, data: data) ? [.done, .partial, .missed, .notApplicable] : [.done, .partial, .missed]
        default:
            return [.done, .partial, .missed, .notApplicable]
        }
    }
}

/// Where a weekly target stands (v11 P1.16, §1.2.4) – one word set for screens, PDF and report. Limits
/// ("höchstens") keep "im Rahmen" / "überschritten" (`limit(isMet:)`). The colour comes from the status
/// alone (`StatusTint` in the app).
public enum PaceStatus: String, CaseIterable, Sendable {
    case reached
    /// On an even pace.
    case onPlan
    /// Behind an even pace by more than a little.
    case behind
    /// Not reached, today is the last planned day of the running week.
    case open
    /// Not reached and the week is over (or closed).
    case missed
    /// A limit kept so far.
    case withinLimit
    /// A limit exceeded.
    case overLimit

    /// The status of a limit ("TEREA ≤ 6"): "im Rahmen" or "überschritten".
    public static func limit(isMet: Bool) -> PaceStatus { isMet ? .withinLimit : .overLimit }

    /// The short word for rows that already show "x von y" (KR2-12): "erreicht", "im Plan",
    /// "hinter dem Plan", "noch offen", "nicht erreicht", "im Rahmen", "überschritten".
    public var label: String {
        switch self {
        case .reached: "erreicht"
        case .onPlan: "im Plan"
        case .behind: "hinter dem Plan"
        case .open: "noch offen"
        case .missed: "nicht erreicht"
        case .withinLimit: "im Rahmen"
        case .overLimit: "überschritten"
        }
    }

    /// With the amount, where no "von" is shown (Fokus, Watch): "noch 0,8 PH offen", "noch 12,50 € offen";
    /// every other status as `label`.
    public func label(remaining: Double, unit: String) -> String {
        guard self == .open, remaining > 1e-9 else { return label }
        let shown = Units.isTime(unit) ? "" : Units.display(unit)
        let normalized = Units.normalized(unit)
        let amount = Format.amount(remaining, unit: unit)
        let suffix = normalized == "€" ? " €" : (shown.isEmpty ? "" : " " + shown)
        return "noch \(amount)\(suffix) offen"
    }
}

/// How far along a weekly item or measurement is, against an even pace through its days.
public struct Pace: Equatable, Sendable {
    public var done: Double
    public var target: Double
    /// What an even pace would have reached by the end of `today`.
    public var expected: Double
    /// Planned days after `today` (v11 P1.16) – 0 on the last planned day.
    public var plannedLeft: Int
    /// The week is over or closed (v11 P1.16): what isn't reached is missed.
    public var weekOver: Bool

    /// `excluding`: days that don't count as planned (work-free days for work measurements, R47).
    /// `excused`: sick and holiday days (v8), left out of the even pace too. `target` is the target
    /// that counts this week – with excused days `Measures.effectiveTarget(_:share:)`'s `scaleMax`.
    /// `weekOver` (v11): the caller's `isClosed || today > week.sunday`; nil means `today > week.sunday`.
    public init(done: Double, target: Double, days: DayMask, week: WeekKey, today: DayKey, excluding: Set<DayKey> = [],
                excused: Set<DayKey> = [], weekOver: Bool? = nil) {
        self.done = done
        self.target = target
        let planned = week.days.filter { days.contains($0.weekday) && !excluding.contains($0) && !excused.contains($0) }
        let passed = planned.filter { $0 <= today }.count
        expected = planned.isEmpty ? target : target * Double(passed) / Double(planned.count)
        plannedLeft = planned.filter { $0 > today }.count
        self.weekOver = weekOver ?? (today > week.sunday)
    }

    public var fraction: Double { target <= 0 ? 1 : min(1, done / target) }
    public var isReached: Bool { done >= target - 1e-9 }
    /// Behind an even pace by more than a little.
    public var isBehind: Bool { !isReached && done + 1e-9 < expected * 0.85 }
    /// What is still missing (0 once reached).
    public var remaining: Double { max(0, target - done) }

    /// v11 P1.16: reached → "erreicht"; not reached and the week over → "nicht erreicht"; not reached on the
    /// last planned day of the running week → "noch offen"; otherwise "hinter dem Plan" or "im Plan".
    public var status: PaceStatus {
        if isReached { return .reached }
        if weekOver { return .missed }
        if plannedLeft == 0 { return .open }
        return isBehind ? .behind : .onPlan
    }

    /// "6 von 8 – im Plan" / "2 von 8 – hinter dem Plan" / "8 von 8 – erreicht" / "7,2 von 8 – noch offen" /
    /// "7,2 von 8 – nicht erreicht".
    public func label(unit: String = "") -> String {
        let u = unit.isEmpty ? "" : " " + unit
        let base = "\(Format.number(done, decimals: 2)) von \(Format.number(target, decimals: 2))\(u)"
        return base + " – " + status.label
    }
}
