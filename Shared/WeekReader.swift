import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// Reads one week live (SwiftData queries, so changes from other devices show up by themselves)
/// and hands the scored `WeekContext` to its content.
struct WeekReader<Content: View>: View {
    let week: WeekKey
    let today: DayKey
    let content: (WeekContext) -> Content

    @Query private var plans: [WeekPlan]
    @Query private var goals: [AnnualGoal]
    @Query private var categories: [TrackCategory]
    @Query private var items: [PlanItem]
    @Query private var measures: [MeasureDefinition]
    @Query private var marks: [ItemMark]
    @Query private var days: [PlanDay]
    @Query private var entries: [MeasureEntry]
    @Query private var health: [HealthValue]
    @Query private var work: [WorkBlock]
    @Query private var notes: [DayNote]
    @Query private var overrides: [ScoreOverride]
    @Query private var reflections: [Reflection]
    @Query private var changes: [PlanChange]

    init(week: WeekKey, today: DayKey, @ViewBuilder content: @escaping (WeekContext) -> Content) {
        self.week = week
        self.today = today
        self.content = content
        let key = week.string
        let dayKeys = week.days.map(\.string)
        _plans = Query(filter: #Predicate<WeekPlan> { $0.weekKey == key })
        _goals = Query(filter: #Predicate<AnnualGoal> { $0.deletedAt == nil })
        _categories = Query(filter: #Predicate<TrackCategory> { $0.deletedAt == nil })
        _items = Query(filter: #Predicate<PlanItem> { $0.weekKey == key && $0.deletedAt == nil })
        _measures = Query(filter: #Predicate<MeasureDefinition> { $0.weekKey == key && $0.deletedAt == nil })
        _marks = Query(filter: #Predicate<ItemMark> { $0.weekKey == key })
        _days = Query(filter: #Predicate<PlanDay> { dayKeys.contains($0.dayKey) })
        _entries = Query(filter: #Predicate<MeasureEntry> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })
        _health = Query(filter: #Predicate<HealthValue> { dayKeys.contains($0.dayKey) })
        _work = Query(filter: #Predicate<WorkBlock> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })
        _notes = Query(filter: #Predicate<DayNote> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })
        _overrides = Query(filter: #Predicate<ScoreOverride> { dayKeys.contains($0.dayKey) && $0.deletedAt == nil })
        _reflections = Query(filter: #Predicate<Reflection> { $0.scope == key || dayKeys.contains($0.scope) })
        _changes = Query(filter: #Predicate<PlanChange> { $0.weekKey == key })
    }

    var body: some View {
        content(WeekContext(
            week: week, today: today, plans: plans, goals: goals, categories: categories, items: items, measures: measures,
            marks: marks, days: days, entries: entries, health: health, work: work, notes: notes, overrides: overrides,
            reflections: reflections, changes: changes
        ))
    }
}
