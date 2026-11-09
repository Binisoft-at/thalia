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
    public static func progressRatio(for item: ItemRecord, measures: [MeasureRecord], days: [DayKey],
                                     entries: [EntryRecord], work: [WorkRecord]) -> Double? {
        guard item.schedule == .progress, let measure = measures.first(where: { $0.code == item.measure }) else { return nil }
        let target = item.target ?? measure.target
        guard let target, target.scaleMax > 0 else { return nil }
        let value = weekValue(measure, days: days, entries: entries, work: work) ?? 0
        return value / target.scaleMax
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

    /// "12 PH × 50 min = 10 h netto"
    public var explanation: String {
        guard !isEmpty else { return "Keine Arbeit erfasst." }
        return "\(Format.number(powerHours, decimals: 2)) PH × 50 min = \(Format.number(netHours, decimals: 2)) h netto"
    }

    /// "3,5 PH"
    public var shortText: String { "\(Format.number(powerHours, decimals: 2)) PH" }

    public static func byCategory(_ blocks: [WorkRecord]) -> [String: WorkTotals] {
        Dictionary(grouping: blocks, by: \.categoryKey).mapValues { WorkTotals($0) }
    }
}
