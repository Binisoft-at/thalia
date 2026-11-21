import Foundation

// Raw measurements stay separate from the scored items (otherwise categories with more data would
// weigh more). They can *suggest* a mark – "Proteinziel erreicht" from the protein entries – but the
// person confirms it; nothing is silently overwritten.

public enum Measures {
    /// The day's value: entries aggregated, plus work blocks for work-based measurements.
    public static func dayValue(_ measure: MeasureRecord, on day: DayKey, entries: [EntryRecord], work: [WorkRecord] = []) -> Double? {
        let own = entries.filter { $0.code == measure.code && $0.day == day }
            .sorted { $0.order < $1.order }
            .compactMap(\.value)
        var value = measure.aggregation.apply(own)
        if case .work(let category) = measure.source {
            let blocks = work.filter { $0.day == day && $0.categoryKey == category }
            if !blocks.isEmpty {
                value = (value ?? 0) + workValue(blocks, unit: measure.unit)
            }
        }
        return value
    }

    /// The week's value: totals for summed measurements, the average of the days otherwise.
    public static func weekValue(_ measure: MeasureRecord, days: [DayKey], entries: [EntryRecord], work: [WorkRecord] = []) -> Double? {
        let values = days.compactMap { dayValue(measure, on: $0, entries: entries, work: work) }
        guard !values.isEmpty else { return nil }
        if measure.aggregation == .sum { return values.reduce(0, +) }
        if measure.isTime {
            // Average bedtimes around midnight correctly: 23:30 and 00:30 average to 00:00.
            let reference = measure.target?.value ?? 23 * 60
            let normalized = values.map { Target.normalizedTime($0, reference: reference) }
            return normalized.reduce(0, +) / Double(normalized.count)
        }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Work blocks always count in power-hours, whatever unit the plan wrote (v3: "einfach PH").
    public static func workValue(_ blocks: [WorkRecord], unit: String) -> Double {
        WorkTotals(blocks).powerHours
    }

    /// Days on which a progress item's measurement moved (value > 0) – the item counts as worked there.
    public static func workedDays(for item: ItemRecord, measures: [MeasureRecord], days: [DayKey],
                                  entries: [EntryRecord], work: [WorkRecord]) -> Set<DayKey>? {
        guard item.schedule == .progress, let measure = measures.first(where: { $0.code == item.measure }) else { return nil }
        return Set(days.filter { (dayValue(measure, on: $0, entries: entries, work: work) ?? 0) > 1e-9 })
    }

    /// Whether a day value meets the measurement's own daily target (nil: no target or no value).
    public static func isMet(_ measure: MeasureRecord, value: Double?) -> Bool? {
        guard let value, let target = measure.target, measure.period == .day else { return nil }
        return target.isMet(value)
    }

    /// The mark a linked measurement suggests for an item, or nil.
    ///  - item with a target: ✓ when met, ✗ when a value was recorded and missed it
    ///  - item without a target ("Gewicht messen"): ✓ as soon as something was recorded
    /// No value → no suggestion (blank stays blank – maybe it just wasn't logged yet).
    /// Progress items get no suggestion: they are resolved from the week.
    public static func suggestion(for item: ItemRecord, dayValue: Double?) -> Mark? {
        guard !item.measure.isEmpty, item.schedule != .progress, let dayValue else { return nil }
        guard let target = item.target else { return .done }
        return target.isMet(dayValue) ? .done : .missed
    }

    /// How far a progress item's weekly target is reached: week value ÷ target (nil: no target).
    /// With sick or holiday days (`excused`, v8) the target is scaled to the measurement's days that
    /// still count (`targetShare`; for work measurements without the `workFree` days – a measurement in
    /// one of the `workCategories` (`WeekData.workCategories`) counts as work, as in pace and weekly
    /// targets); nil when none count – the item isn't scored then.
    public static func progressRatio(for item: ItemRecord, measures: [MeasureRecord], days: [DayKey],
                                     entries: [EntryRecord], work: [WorkRecord],
                                     excused: Set<DayKey> = [], workFree: Set<DayKey> = [],
                                     workCategories: Set<String> = []) -> Double? {
        guard item.schedule == .progress, let measure = measures.first(where: { $0.code == item.measure }) else { return nil }
        let target = item.target ?? measure.target
        guard let target, target.scaleMax > 0 else { return nil }
        let week = days.first?.week ?? measure.week
        let share = targetShare(for: measure, week: week, excused: excused, workFree: workFree, workCategories: workCategories)
        guard share > 1e-9 else { return nil }
        let effective = effectiveTarget(target, share: share)
        guard effective.scaleMax > 0 else { return nil }
        let value = weekValue(measure, days: days, entries: entries, work: work) ?? 0
        return value / effective.scaleMax
    }

    // MARK: Sick and holiday days (v8)

    /// The share of a weekly target that still counts: |A| ÷ |P|, where P = the measurement's days of
    /// the week without `notPlanned` (work-free days for work measurements – an excused day stays
    /// planned even if it's also work-free) and A = P without the `excused` days.
    /// 1 without excused days (or with nothing planned), 0 when every planned day is excused.
    public static func targetShare(days: DayMask, week: WeekKey, notPlanned: Set<DayKey>, excused: Set<DayKey>) -> Double {
        let planned = week.days.filter { days.contains($0.weekday) && (excused.contains($0) || !notPlanned.contains($0)) }
        guard !planned.isEmpty else { return 1 }
        let available = planned.filter { !excused.contains($0) }
        return Double(available.count) / Double(planned.count)
    }

    /// The target scaled by `share` (8 PH × 0,6 = 4,8 PH). Limits (≤, <, "höchstens") and times of
    /// day are never scaled.
    public static func effectiveTarget(_ target: Target, share: Double) -> Target {
        guard !target.isLimit, !target.isTime, share < 1 - 1e-9 else { return target }
        let factor = max(0, share)
        return Target(target.comparison, target.value * factor, upper: target.upper.map { $0 * factor }, isTime: target.isTime)
    }

    /// Work measurements plan only on work days (R47): from power-hours, flagged "arbeit", or in a
    /// work category (`WeekData.workCategories`).
    public static func isWorkMeasure(_ measure: MeasureRecord, workCategories: Set<String> = []) -> Bool {
        measure.isWork || measure.dayRule == .workOnly || (measure.dayRule == .auto && workCategories.contains(measure.categoryKey))
    }

    /// `targetShare` for a measurement: its days, without work-free days for work measurements.
    public static func targetShare(for measure: MeasureRecord, week: WeekKey, excused: Set<DayKey>, workFree: Set<DayKey> = [],
                                   workCategories: Set<String> = []) -> Double {
        let notPlanned: Set<DayKey> = isWorkMeasure(measure, workCategories: workCategories) ? workFree : []
        return targetShare(days: measure.days, week: week, notPlanned: notPlanned, excused: excused)
    }

    /// A measurement's target as it counts this week (scaled for excused days), nil without a target.
    public static func effectiveTarget(for measure: MeasureRecord, week: WeekKey, excused: Set<DayKey>, workFree: Set<DayKey> = [],
                                       workCategories: Set<String> = []) -> Target? {
        guard let target = measure.target else { return nil }
        guard measure.period == .week else { return target }
        let share = targetShare(for: measure, week: week, excused: excused, workFree: workFree, workCategories: workCategories)
        return effectiveTarget(target, share: share)
    }

    /// A weekly measurement's pace with the v8 rules: scaled target, work-free days left out for work
    /// measurements, excused days left out. nil for daily measurements, without a target, or when
    /// every one of its days is excused (share 0: not scored this week).
    public static func weeklyPace(_ measure: MeasureRecord, done: Double, week: WeekKey, today: DayKey, excused: Set<DayKey>,
                                  workFree: Set<DayKey> = [], workCategories: Set<String> = []) -> Pace? {
        guard measure.period == .week, measure.target != nil,
              targetShare(for: measure, week: week, excused: excused, workFree: workFree, workCategories: workCategories) > 1e-9,
              let target = effectiveTarget(for: measure, week: week, excused: excused, workFree: workFree, workCategories: workCategories)
        else { return nil }
        let notPlanned: Set<DayKey> = isWorkMeasure(measure, workCategories: workCategories) ? workFree : []
        return Pace(done: done, target: target.scaleMax, days: measure.days, week: week, today: today, excluding: notPlanned,
                    excused: excused)
    }
}

/// How a measurement is filled in – the groups inside a category (U13).
public enum MeasureGroup: Int, CaseIterable, Comparable, Sendable {
    case work = 0, count, time, weekly

    public static func < (lhs: MeasureGroup, rhs: MeasureGroup) -> Bool { lhs.rawValue < rhs.rawValue }

    public init(_ measure: MeasureRecord) {
        if case .work = measure.source { self = .work }
        else if measure.period == .week { self = .weekly }
        else if measure.isTime { self = .time }
        else { self = .count }
    }

    public var label: String {
        switch self {
        case .work: "Power-Hours"
        case .count: "Anzahl und Werte"
        case .time: "Uhrzeiten"
        case .weekly: "Wochenziele"
        }
    }
}

/// Work accounting in power-hours: 1 PH = 50 focused minutes, tutoring included.
public struct WorkTotals: Equatable, Sendable {
    public var powerHours: Double = 0

    public init() {}

    public init(_ blocks: [WorkRecord]) {
        powerHours = blocks.reduce(0) { $0 + $1.powerHours }
    }

    public var netMinutes: Double { PowerHour.minutes(powerHours) }
    public var netHours: Double { netMinutes / 60 }
    public var isEmpty: Bool { powerHours <= 0 }

    /// "3 h 20 min": the net time in hours and minutes (R52).
    public var netText: String { Format.duration(minutes: Int(netMinutes.rounded())) }

    /// "28 PH × 50 min = 23 h 20 min netto"
    public var explanation: String {
        guard !isEmpty else { return "Keine Arbeit erfasst." }
        return "\(Format.number(powerHours, decimals: 2)) PH × 50 min = \(netText) netto"
    }

    /// "3,5 PH"
    public var shortText: String { "\(Format.number(powerHours, decimals: 2)) PH" }

    public static func byCategory(_ blocks: [WorkRecord]) -> [String: WorkTotals] {
        Dictionary(grouping: blocks, by: \.categoryKey).mapValues { WorkTotals($0) }
    }
}
