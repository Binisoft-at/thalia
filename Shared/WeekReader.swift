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
    /// v9: the week's archive grades (setting `archive.<week>`); v10: the known sources (`x.sources`).
    @Query private var settings: [AppSetting]
    /// v10: the goal year with its segments, results and entries (`goal.`), the reading list (`list.`),
    /// the mappings (`link.rule.`) and the stored category week scores (`score.`) – prefix queries.
    @Query private var goalRecords: [AppSetting]
    @Query private var listRecords: [AppSetting]
    @Query private var linkRecords: [AppSetting]
    @Query private var scoreRecords: [AppSetting]

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
        let keys = [ArchiveWeek.settingKey(week), ExchangeInbox.sourcesKey]
        _settings = Query(filter: #Predicate<AppSetting> { keys.contains($0.key) })
        let goalPrefix = "goal."
        let listPrefix = "list."
        let linkPrefix = LinkRule.prefix
        let scorePrefix = GoalTrack.settingPrefix
        _goalRecords = Query(filter: #Predicate<AppSetting> { $0.key.starts(with: goalPrefix) })
        _listRecords = Query(filter: #Predicate<AppSetting> { $0.key.starts(with: listPrefix) })
        _linkRecords = Query(filter: #Predicate<AppSetting> { $0.key.starts(with: linkPrefix) })
        _scoreRecords = Query(filter: #Predicate<AppSetting> { $0.key.starts(with: scorePrefix) })
    }

    /// The sources seen – their day files of the week are read by the inner reader.
    private var sourceIDs: [String] {
        // Every copy of `x.sources` counts (two devices may each have written one before they synced).
        ExchangeSourceList.merged(settings.filter { $0.key == ExchangeInbox.sourcesKey }.map(\.value)).ids
    }

    var body: some View {
        WeekInboxReader(keys: ExchangeInbox.keys(sources: sourceIDs, week: week)) { inbox in
            content(WeekContext(
                week: week, today: today, plans: plans, goals: goals, categories: categories, items: items, measures: measures,
                marks: marks, days: days, entries: entries, health: health, work: work, notes: notes, overrides: overrides,
                reflections: reflections, changes: changes, settings: allSettings(inbox)
            ))
        }
    }

    /// Every setting the week reads, in one list (`WeekContext` picks them by key).
    private func allSettings(_ inbox: [AppSetting]) -> [AppSetting] {
        var result: [AppSetting] = settings
        result.append(contentsOf: goalRecords)
        result.append(contentsOf: listRecords)
        result.append(contentsOf: linkRecords)
        result.append(contentsOf: scoreRecords)
        result.append(contentsOf: inbox)
        return result
    }
}

/// v10: the week's day files in the synced inbox (`x.<source>.<day>`, an IN query over the known
/// sources × the week's days), read live – a file another device stored shows up by itself.
struct WeekInboxReader<Content: View>: View {
    let content: ([AppSetting]) -> Content
    @Query private var inbox: [AppSetting]

    init(keys: [String], @ViewBuilder content: @escaping ([AppSetting]) -> Content) {
        self.content = content
        _inbox = Query(filter: #Predicate<AppSetting> { keys.contains($0.key) })
    }

    var body: some View {
        content(inbox)
    }
}
