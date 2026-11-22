import Foundation

// One call for WeekContext (TASKS-v10 §2 P2): everything v10 adds to a week, computed – the connected
// apps' values, work blocks and ticks, the reading list's values, and the own records on top
// (Grundregel 1: own records always win). The result plugs into the existing scoring:
// `WeekData(marks: extras.marks, …)`, `Measures.progressRatio(…, entries: extras.entries, work: extras.work)`.

public struct WeekExtras: Equatable, Sendable {
    public struct Input: Sendable {
        public var week: WeekKey
        public var items: [ItemRecord]
        public var measures: [MeasureRecord]
        public var categories: [CategoryRecord]
        /// Every own mark of the week – also cleared ones (`mark == nil`).
        public var ownMarks: [MarkRecord]
        /// Own entries of the week.
        public var ownEntries: [EntryRecord]
        /// Confirmed Health values of the week (device only).
        public var health: [EntryRecord]
        /// Own work blocks of the week.
        public var ownWork: [WorkRecord]
        /// `importID`s of own work blocks ("x:theo:ph-77C0" after "Übernehmen").
        public var ownWorkImportIDs: Set<String>
        public var excusedDays: Set<DayKey>
        public var workFreeDays: Set<DayKey>
        /// Day files of the synced inbox (`x.<source>.<day>`) of the week's days – the watch reads them too.
        public var inbox: [ExchangeDayFile]
        public var rules: [LinkRule]
        public var listItems: [ListItem]
        public var listProgress: [ListProgress]
        /// Source id → the app's name from its `source.json` ("aus TimeTracker").
        public var sourceNames: [String: String]

        public init(week: WeekKey, items: [ItemRecord], measures: [MeasureRecord], categories: [CategoryRecord] = [],
                    ownMarks: [MarkRecord] = [], ownEntries: [EntryRecord] = [], health: [EntryRecord] = [], ownWork: [WorkRecord] = [],
                    ownWorkImportIDs: Set<String> = [], excusedDays: Set<DayKey> = [], workFreeDays: Set<DayKey> = [],
                    inbox: [ExchangeDayFile] = [], rules: [LinkRule] = [], listItems: [ListItem] = [], listProgress: [ListProgress] = [],
                    sourceNames: [String: String] = [:]) {
            self.week = week
            self.items = items
            self.measures = measures
            self.categories = categories
            self.ownMarks = ownMarks
            self.ownEntries = ownEntries
            self.health = health
            self.ownWork = ownWork
            self.ownWorkImportIDs = ownWorkImportIDs
            self.excusedDays = excusedDays
            self.workFreeDays = workFreeDays
            self.inbox = inbox
            self.rules = rules
            self.listItems = listItems
            self.listProgress = listProgress
            self.sourceNames = sourceNames
        }
    }

    /// What the connected apps add (labels, "aus Theo", unassigned power-hours, unused facts).
    public var effect: ExchangeEffect
    /// The week's measures plus hidden ones for items linked to an `app:`/`list:` text directly.
    public var measures: [MeasureRecord]
    /// The reading list's day values of `list:` measures.
    public var listEntries: [EntryRecord]
    /// The entries that count: own > Health > reading list and connected apps (spending adds up).
    public var entries: [EntryRecord]
    /// Own work blocks and the derived ones with a category.
    public var work: [WorkRecord]
    /// The marks that count by `WeekData.markKey`: own ones (set), derived ✓ where there is no own mark.
    public var marks: [String: Mark]

    public init(effect: ExchangeEffect = ExchangeEffect(), measures: [MeasureRecord] = [], listEntries: [EntryRecord] = [],
                entries: [EntryRecord] = [], work: [WorkRecord] = [], marks: [String: Mark] = [:]) {
        self.effect = effect
        self.measures = measures
        self.listEntries = listEntries
        self.entries = entries
        self.work = work
        self.marks = marks
    }

    /// A derived tick (from a connected app) – shown with its label, never stored.
    public func isDerived(_ itemCode: String, on day: DayKey) -> Bool {
        effect.markLabels[WeekData.markKey(itemCode, day)] != nil
    }

    public static func compute(_ input: Input) -> WeekExtras {
        let weekMeasures = input.measures.filter { $0.week == input.week }
        let weekItems = input.items.filter { $0.week == input.week }
        let measures = weekMeasures + ExchangeDerivation.virtualMeasures(items: weekItems, measures: weekMeasures)
        let listEntries = ListMath.entries(for: measures, items: input.listItems, progress: input.listProgress, days: input.week.days)
        // Own values for the apps' rule "own wins": own entries and confirmed Health values.
        let ownValues = Measures.merged(own: input.ownEntries, health: input.health)
        let effect = ExchangeDerivation.week(input.week, inbox: input.inbox, items: weekItems, measures: measures, rules: input.rules,
                                             categories: input.categories, ownMarks: input.ownMarks, ownEntries: ownValues,
                                             ownWorkIDs: input.ownWorkImportIDs, excusedDays: input.excusedDays,
                                             workFreeDays: input.workFreeDays, sourceNames: input.sourceNames)
        let entries = Measures.merged(own: input.ownEntries, health: input.health, external: listEntries + effect.entries,
                                      additive: effect.additiveCodes)
        var marks = effect.markValues
        for mark in input.ownMarks where mark.week == input.week {
            let key = WeekData.markKey(mark.itemCode, mark.day)
            if let value = mark.mark { marks[key] = value } else { marks[key] = nil }
        }
        return WeekExtras(effect: effect, measures: measures, listEntries: listEntries, entries: entries,
                          work: input.ownWork + effect.work, marks: marks)
    }
}

extension GoalResult {
    /// The day values of an `app:` source from the inbox (nil for other sources – `measure:` series come
    /// from the store, Health only on the device).
    public func appSeries(inbox: [ExchangeDayFile], rules: [LinkRule] = [], categories: [CategoryRecord] = []) -> [DayKey: Double]? {
        guard case .app(let source) = resultSource else { return nil }
        let goalCategories = categories.filter { $0.goalKey == goalKey }
        return ExchangeDerivation.series(source, inbox: inbox, rules: rules, categoryKey: goalCategories.count == 1 ? goalCategories[0].key : "",
                                         known: Set(categories.map(\.key)))
    }
}
