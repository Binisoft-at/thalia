import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

// v8 (version 1.7.0): sick and holiday days, past weeks, reports over several weeks.

@Suite("v8 Krank und Urlaub")
struct V8ScoringTests {
    let week = WeekKey(year: 2026, week: 47)
    let goals = [GoalRecord(key: "1", title: "Ziel A"), GoalRecord(key: "2", title: "Ziel B")]
    let categories = [CategoryRecord(key: "1.2", goalKey: "1", title: "Thema A"), CategoryRecord(key: "2.1", goalKey: "2", title: "Thema B")]

    func day(_ weekday: Weekday) -> DayKey { week.day(weekday) }
    func days(_ list: [Weekday]) -> Set<DayKey> { Set(list.map(day)) }
    var friToSun: Set<DayKey> { days([.friday, .saturday, .sunday]) }

    func quota(days: DayMask = .everyDay) -> ItemRecord {
        ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", title: "Workout", days: days, schedule: .weekly(3))
    }

    func marks(_ item: ItemRecord, _ list: [(Weekday, Mark)]) -> [String: Mark] {
        var result: [String: Mark] = [:]
        for (weekday, mark) in list { result[WeekData.markKey(item.code, day(weekday))] = mark }
        return result
    }

    func data(_ items: [ItemRecord], marks: [String: Mark] = [:], excused: Set<DayKey>, complete: Bool = true) -> WeekData {
        WeekData(week: week, goals: [goals[0]], categories: [categories[0]], items: items, marks: marks, isComplete: complete,
                 excusedDays: excused)
    }

    @Test func t1QuotaShareOfSickDaysCountsHalf() {
        let item = quota()
        let data = data([item], marks: marks(item, [(.monday, .done), (.wednesday, .done)]), excused: friToSun)
        let score = Scorer.score(data)
        let thursday = score.category("1.2", on: day(.thursday))
        #expect(thursday.applicable == 1)
        #expect(thursday.earned == 0.5)
        #expect(thursday.excused == 1)
        #expect(thursday.shortfall == 0.5)
        #expect(thursday.score == 5)
        #expect(score.category("1.2", on: day(.sunday)).score == nil, "nothing booked on a sick day")
        #expect(abs((score.categoryWeek["1.2"] ?? 0) - 25.0 / 3) < 1e-9)
        // Without the rule the missing one is a zero on Sunday: 6,67.
        var plain = data
        plain.excusedDays = []
        #expect(abs((Scorer.score(plain).categoryWeek["1.2"] ?? 0) - 20.0 / 3) < 1e-9)
    }

    @Test func t2BookedOnTheLastDayThatStillCounts() {
        let item = quota(days: DayMask([.monday, .wednesday, .friday]))
        let data = data([item], marks: marks(item, [(.monday, .done), (.wednesday, .done)]), excused: days([.friday]))
        let score = Scorer.score(data)
        let wednesday = score.category("1.2", on: day(.wednesday))
        #expect(wednesday.applicable == 2)
        #expect(wednesday.earned == 1.5)
        #expect(wednesday.score == 7.5)
        #expect(score.categoryWeek["1.2"] == 8.75)
    }

    @Test func t3OnlyTheSickShareCountsHalf() {
        let item = quota()
        let score = Scorer.score(data([item], excused: friToSun))
        let thursday = score.category("1.2", on: day(.thursday))
        #expect(thursday.applicable == 3)
        #expect(abs(thursday.excused - 9.0 / 7) < 1e-9)
        #expect(abs(thursday.earned - 4.5 / 7) < 1e-9)
        #expect(abs((thursday.score ?? 0) - 15.0 / 7) < 1e-9, "≈ 2,14")
    }

    @Test func t4WholeWeekOnHolidayHasNoScore() {
        let item = quota()
        let fixed = ItemRecord(week: week, code: "1.2-02", categoryKey: "1.2", title: "Dehnen")
        let all = days(Weekday.allCases)
        let data = data([item, fixed], excused: all)
        let score = Scorer.score(data)
        #expect(week.days.allSatisfy { score.category("1.2", on: $0).applicable == 0 && score.category("1.2", on: $0).shortfall == 0 })
        #expect(score.categoryWeek["1.2"] == nil)
        #expect(score.goalWeek["1"]?.score == nil)
        #expect(score.overall == nil)
        #expect(score.isExcused)
        #expect(score.excusedDays == all)
        #expect(score.goalsExcused == 1)
        #expect(score.goalsTotal == 0)
        #expect(score.coverageText == "Woche zählt nicht (krank/Urlaub)")
        #expect(week.days.allSatisfy { score.days[$0]?.isExcused == true && score.days[$0]?.blank == 0 })
    }

    @Test func t5QuotaMetMeansNoDeduction() {
        let item = quota()
        let score = Scorer.score(data([item], marks: marks(item, [(.monday, .done), (.tuesday, .done), (.wednesday, .done)]),
                                      excused: friToSun))
        #expect(week.days.allSatisfy { score.category("1.2", on: $0).shortfall == 0 && score.category("1.2", on: $0).excused == 0 })
        #expect(score.categoryWeek["1.2"] == 10)
        #expect(!score.isExcused)
    }

    @Test func t6NotApplicableLeavesTheSickShareOut() {
        let item = quota()
        let data = data([item], excused: friToSun, complete: false)
        // needed = ⌈3 − 9/7⌉ = 2: Tuesday leaves Wednesday and Thursday, Wednesday only Thursday.
        #expect(Scorer.canMarkNotApplicable(item, on: day(.tuesday), data: data))
        #expect(!Scorer.canMarkNotApplicable(item, on: day(.wednesday), data: data))
        #expect(Scorer.options(for: item, on: day(.wednesday), data: data) == [.done, .partial, .missed])
        #expect(Scorer.options(for: item, on: day(.friday), data: data).isEmpty, "nothing to mark on a sick day")
        #expect(abs(Scorer.quotaShare(item, data: data) - 9.0 / 7) < 1e-9)
        // Unchanged without sick days: N/A until Thursday.
        var plain = data
        plain.excusedDays = []
        #expect(Scorer.canMarkNotApplicable(item, on: day(.thursday), data: plain))
        #expect(!Scorer.canMarkNotApplicable(item, on: day(.friday), data: plain))
    }

    @Test func t7ProgressTargetShrinksWithSickDays() throws {
        let measure = MeasureRecord(week: week, code: "stammloop_ph", categoryKey: "1.2", title: "stammloop", unit: "PH",
                                    target: Target.parse(">=8"), period: .week, source: .work(category: "1.2"), days: .workdays)
        let item = ItemRecord(week: week, code: "p", categoryKey: "1.2", title: "An stammloop gearbeitet", days: .workdays,
                              schedule: .progress, measure: "stammloop_ph")
        let sick = days([.thursday, .friday])
        let share = Measures.targetShare(days: .workdays, week: week, notPlanned: [], excused: sick)
        #expect(abs(share - 0.6) < 1e-9)
        let target = try #require(Target.parse(">=8"))
        #expect(abs(Measures.effectiveTarget(target, share: share).value - 4.8) < 1e-9)
        #expect(abs((Measures.effectiveTarget(for: measure, week: week, excused: sick)?.value ?? 0) - 4.8) < 1e-9)

        func monday(powerHours: Double) throws -> CategoryDay {
            let work = [WorkRecord(id: "1", day: week.monday, categoryKey: "1.2", task: "", powerHours: powerHours)]
            let ratio = try #require(Measures.progressRatio(for: item, measures: [measure], days: week.days, entries: [], work: work,
                                                            excused: sick))
            let worked = try #require(Measures.workedDays(for: item, measures: [measure], days: week.days, entries: [], work: work))
            let data = WeekData(week: week, goals: [goals[0]], categories: [categories[0]], items: [item], isComplete: true,
                                progress: ["p": ratio], worked: ["p": worked], excusedDays: sick)
            return Scorer.score(data).category("1.2", on: week.monday)
        }
        let ratio = Measures.progressRatio(for: item, measures: [measure], days: week.days, entries: [],
                                           work: [WorkRecord(id: "1", day: week.monday, categoryKey: "1.2", task: "", powerHours: 4)],
                                           excused: sick)
        #expect(abs((ratio ?? 0) - 4 / 4.8) < 1e-9, "≈ 0,83")
        #expect(try monday(powerHours: 4).score == 5, "partly")
        #expect(try monday(powerHours: 5).score == 10, "reached")
        // Every planned day sick: not scored.
        let allSick = Measures.progressRatio(for: item, measures: [measure], days: week.days, entries: [], work: [],
                                             excused: days([.monday, .tuesday, .wednesday, .thursday, .friday]))
        #expect(allSick == nil)
        // Without sick days nothing changes.
        let plain = Measures.progressRatio(for: item, measures: [measure], days: week.days, entries: [],
                                           work: [WorkRecord(id: "1", day: week.monday, categoryKey: "1.2", task: "", powerHours: 4)])
        #expect(plain == 0.5)
    }

    @Test func t8DailyItemOnHolidayWeekend() {
        let item = ItemRecord(week: week, code: "1.2-03", categoryKey: "1.2", title: "Spaziergang")
        let weekdays: [(Weekday, Mark)] = [(.monday, .done), (.tuesday, .done), (.wednesday, .done), (.thursday, .done), (.friday, .done)]
        let weekend = days([.saturday, .sunday])
        let data = data([item], marks: marks(item, weekdays), excused: weekend)
        let score = Scorer.score(data)
        #expect(score.categoryWeek["1.2"] == 10)
        for holiday in weekend {
            #expect(score.category("1.2", on: holiday).score == nil)
            #expect(!data.isOpenRequired(item, on: holiday))
            #expect(score.days[holiday]?.blank == 0)
            #expect(score.days[holiday]?.isExcused == true)
            #expect(data.mark(item, on: holiday) == .notApplicable)
        }
        #expect(score.overall == 10)
        #expect(!score.isExcused)
    }

    @Test func t9OverridesAndGoalsOnSickDaysDontCount() {
        let daily = ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", title: "Täglich", days: .workdays)
        let fridayOnly = ItemRecord(week: week, code: "2.1-01", categoryKey: "2.1", title: "Nur freitags", days: DayMask([.friday]))
        let weekdays: [(Weekday, Mark)] = [(.monday, .done), (.tuesday, .done), (.wednesday, .done), (.thursday, .done)]
        var data = WeekData(week: week, goals: goals, categories: categories, items: [daily, fridayOnly], marks: marks(daily, weekdays),
                            isComplete: true, excusedDays: days([.friday]))
        data.overrides[WeekData.overrideKey("1.2", day(.friday))] = 2
        let score = Scorer.score(data)
        let friday = score.category("1.2", on: day(.friday))
        #expect(!friday.overridden)
        #expect(friday.score == nil)
        #expect(score.categoryWeek["1.2"] == 10)
        #expect(score.goalsExcused == 1)
        #expect(score.goalsTotal == 1)
        #expect(score.goalsScored == 1)
        #expect(score.isComplete)
        #expect(score.coverageText == "1/1 Ziele bewertet")
        // A goal without any items still counts (missingGoalCoverageIsVisible stays true).
        let more = WeekData(week: week, goals: goals + [GoalRecord(key: "3", title: "Ziel C")], categories: categories,
                            items: [daily, fridayOnly], marks: marks(daily, weekdays), isComplete: true, excusedDays: days([.friday]))
        #expect(Scorer.score(more).goalsTotal == 2)
        // Back to a work day: the override counts again.
        data.excusedDays = []
        #expect(Scorer.score(data).category("1.2", on: day(.friday)).score == 2)
    }

    @Test func marksBeforeTheSickNoteStayButDontCount() {
        let sleep = ItemRecord(week: week, code: "1.2-04", categoryKey: "1.2", title: "Schlaf", knockout: true)
        let data = data([sleep], marks: marks(sleep, [(.friday, .missed), (.monday, .done)]), excused: days([.friday]), complete: false)
        let friday = Scorer.score(data).category("1.2", on: day(.friday))
        #expect(!friday.knockedOut)
        #expect(friday.due == 0 && friday.blank == 0 && friday.applicable == 0)
        #expect(data.mark(sleep, on: day(.friday)) == .notApplicable)
        #expect(data.recordedMark(sleep, on: day(.friday)) == .missed, "kept, shown dimmed")
        #expect(Scorer.options(for: sleep, on: day(.friday), data: data).isEmpty)
        #expect(data.isPlanned(sleep, on: day(.friday)) && !data.applies(sleep, on: day(.friday)))
    }

    @Test func openMatchesBlankWithSickDays() {
        let items = [
            ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", title: "Fest"),
            ItemRecord(week: week, code: "1.2-02", categoryKey: "1.2", title: "Dreimal", schedule: .weekly(3)),
            ItemRecord(week: week, code: "1.2-03", categoryKey: "1.2", title: "Fortschritt", schedule: .progress),
            ItemRecord(week: week, code: "2.1-01", categoryKey: "2.1", title: "Nebenbei", secondary: true),
        ]
        let data = WeekData(week: week, goals: goals, categories: categories, items: items,
                            marks: [WeekData.markKey("1.2-01", day(.monday)): .done], excusedDays: days([.tuesday, .wednesday]))
        let score = Scorer.score(data)
        for shown in week.days {
            let open = data.items.filter { data.isOpenRequired($0, on: shown) }.count
            #expect(open == score.days[shown]?.blank, "\(shown)")
        }
        #expect(score.days[day(.tuesday)]?.blank == 0)
        #expect(score.days[day(.thursday)]?.blank == 2)
    }

    @Test func limitsAndTimesAreNeverScaled() throws {
        let limit = try #require(Target.parse("<=6"))
        #expect(Measures.effectiveTarget(limit, share: 0.5) == limit)
        let below = try #require(Target.parse("<50"))
        #expect(Measures.effectiveTarget(below, share: 0.5) == below)
        let bedtime = try #require(Target.parse("<=23:00"))
        #expect(Measures.effectiveTarget(bedtime, share: 0.5) == bedtime)
        let range = try #require(Target.parse("100-200"))
        #expect(Measures.effectiveTarget(range, share: 0.5) == Target(.range, 50, upper: 100))
        let pages = try #require(Target.parse(">=100"))
        #expect(Measures.effectiveTarget(pages, share: 1) == pages)
        #expect(Measures.targetShare(days: .everyDay, week: week, notPlanned: [], excused: []) == 1)
    }

    @Test func paceLeavesHolidaysOut() throws {
        let measure = MeasureRecord(week: week, code: "seiten", categoryKey: "2.1", title: "Seiten", unit: "Seiten",
                                    target: Target.parse(">=100"), period: .week)
        let pace = try #require(Measures.weeklyPace(measure, done: 40, week: week, today: day(.wednesday),
                                                    excused: days([.saturday, .sunday])))
        #expect(abs(pace.target - 500.0 / 7) < 1e-9, "≈ 71,4")
        #expect(abs(pace.expected - 500.0 / 7 * 3 / 5) < 1e-9, "≈ 42,9")
        let direct = Pace(done: 40, target: 70, days: .everyDay, week: week, today: day(.wednesday), excused: days([.saturday, .sunday]))
        #expect(abs(direct.expected - 42) < 1e-9)
        // Work measurements: a holiday that's also work-free still shrinks the target.
        let work = MeasureRecord(week: week, code: "ph", categoryKey: "1.2", title: "PH", unit: "PH", target: Target.parse(">=8"),
                                 period: .week, source: .work(category: "1.2"), days: .workdays)
        let holiday = days([.monday, .tuesday])
        #expect(abs(Measures.targetShare(for: work, week: week, excused: holiday, workFree: holiday) - 0.6) < 1e-9)
        #expect(Measures.weeklyPace(MeasureRecord(week: week, code: "x", title: "X", target: Target.parse(">=1")), done: 0, week: week,
                                    today: day(.monday), excused: []) == nil, "daily measurement")
    }

    @Test func dayTypes() {
        #expect(DayTypes.presets.contains("Krank"))
        #expect(DayTypes.presets.contains("Urlaub"))
        #expect(DayTypes.excusedPresets == ["Krank", "Urlaub"])
        #expect(DayTypes.isExcused("Krank"))
        #expect(DayTypes.isExcused("Urlaubstag"))
        #expect(DayTypes.isExcused("krank – Erkältung"))
        #expect(!DayTypes.isExcused("Frei"))
        #expect(!DayTypes.isExcused("Feiertag"))
        #expect(!DayTypes.isExcused("Erholungstag"))
        #expect(DayTypes.isWorkFree("Krank"), "unchanged")
        #expect(DayTypes.isWorkFree("Urlaub"))
        #expect(DayTypes.symbol(for: "Krank") == "cross.case")
        #expect(DayTypes.symbol(for: "Urlaub") == "beach.umbrella")
        #expect(DayTypes.symbol(for: "Erholungstag") == "leaf")
        #expect(DayTypes.symbol(for: "Frei") == "sun.max")
        #expect(DayTypes.excusedHint == "Krank/Urlaub: Der Tag zählt nicht in die Wochenwertung")
        let types = [week.monday: "Krank", week.sunday: "Frei"]
        #expect(DayTypes.excusedDays(week.days, types: { types[$0] ?? "" }) == [week.monday])
    }

    @Test func reportSaysWhatDoesntCount() {
        let item = quota()
        let input = WeekReportInput(
            week: WeekRecord(week: week), goals: [goals[0]], categories: [categories[0]], items: [item], measures: [],
            marks: [MarkRecord(week: week, itemCode: item.code, day: day(.monday), mark: .done),
                    MarkRecord(week: week, itemCode: item.code, day: day(.friday), mark: .missed)],
            days: [DayRecord(day: day(.friday), dayType: "Krank"), DayRecord(day: day(.saturday), dayType: "Krank"),
                   DayRecord(day: day(.sunday), dayType: "Krank")],
            isClosed: true, today: week.sunday.adding(days: 1)
        )
        #expect(input.excusedDays == friToSun)
        #expect(input.weekData.excusedDays == friToSun)
        let text = WeekReport.markdown(input)
        #expect(text.contains("Krank/Urlaub: Fr Krank, Sa Krank, So Krank – diese Tage zählen nicht"))
        #expect(text.contains("| Fr, 20. Nov. | Krank | zählt nicht |"), "\(text)")
        #expect(text.contains("Workout 1 von 3/Woche (1,29 wegen Krank/Urlaub halb gezählt)"), "\(text)")
        #expect(!text.contains("Workout ✗"), "a ✗ on a sick day isn't a missed commitment")
    }

    /// Decision 4: a progress item in a work category (goal 3, plan without day rules) scales like its
    /// pace and weekly target – work-free days left out – in the live week and in the report.
    @Test func progressInAWorkCategoryScalesLikeItsPace() throws {
        let business = [CategoryRecord(key: "3.2", goalKey: "3", title: "Akquise")]
        let measure = MeasureRecord(week: week, code: "anrufe", categoryKey: "3.2", title: "Anrufe", unit: "Anrufe",
                                    target: Target.parse(">=8"), period: .week, days: .workdays)
        let item = ItemRecord(week: week, code: "p", categoryKey: "3.2", title: "Angerufen", days: .workdays,
                              schedule: .progress, measure: "anrufe")
        let workCategories = WeekData.workCategories(items: [item], categories: business)
        #expect(workCategories == ["3.2"])
        // Do Krank (also work-free), Fr Feiertag: 3 of 4 planned work days count.
        let sick = days([.thursday])
        let free = days([.thursday, .friday])
        let entries = [EntryRecord(code: "anrufe", day: week.monday, value: 3)]
        let share = Measures.targetShare(for: measure, week: week, excused: sick, workFree: free, workCategories: workCategories)
        #expect(abs(share - 0.75) < 1e-9)
        let ratio = try #require(Measures.progressRatio(for: item, measures: [measure], days: week.days, entries: entries, work: [],
                                                        excused: sick, workFree: free, workCategories: workCategories))
        #expect(abs(ratio - 0.5) < 1e-9, "3 of 8 × 3/4 = 6")
        let pace = try #require(Measures.weeklyPace(measure, done: 3, week: week, today: day(.monday), excused: sick, workFree: free,
                                                    workCategories: workCategories))
        #expect(abs(pace.target - 6) < 1e-9, "pace and progress agree")
        let input = WeekReportInput(
            week: WeekRecord(week: week), goals: [GoalRecord(key: "3", title: "Business")], categories: business, items: [item],
            measures: [measure], marks: [],
            days: [DayRecord(day: day(.thursday), dayType: "Krank"), DayRecord(day: day(.friday), dayType: "Feiertag")],
            entries: entries, isClosed: true, today: week.sunday.adding(days: 1)
        )
        #expect(abs((input.weekData.progress["p"] ?? 0) - 0.5) < 1e-9, "the report scores it the same way")
    }

    /// Decision 4: share 0 – every day of a weekly measurement is excused – isn't scored: no pace, not
    /// counted in the week's targets, the report says "nicht bewertet".
    @Test func weeklyTargetWithOnlySickDaysIsNotScored() {
        let measure = MeasureRecord(week: week, code: "ph", categoryKey: "1.2", title: "stammloop", unit: "PH", target: Target.parse(">=8"),
                                    period: .week, source: .work(category: "1.2"), days: .workdays)
        let sick = days([.monday, .tuesday, .wednesday, .thursday, .friday])
        #expect(Measures.targetShare(for: measure, week: week, excused: sick) == 0)
        #expect(Measures.weeklyPace(measure, done: 0, week: week, today: day(.wednesday), excused: sick) == nil)
        let input = WeekReportInput(
            week: WeekRecord(week: week), goals: [goals[0]], categories: [categories[0]], items: [], measures: [measure], marks: [],
            days: sick.map { DayRecord(day: $0, dayType: "Krank") },
            work: [WorkRecord(id: "w", day: week.monday, categoryKey: "1.2", task: "", powerHours: 1)],
            isClosed: true, today: week.sunday.adding(days: 1)
        )
        let text = WeekReport.markdown(input)
        #expect(text.contains("nicht bewertet, alle Tage Krank/Urlaub"), "\(text)")
        #expect(!text.contains("Ziel ≥ 0"), "\(text)")
        let line = WeekLine(input)
        #expect(line.weeklyTargetsCount == 0 && line.weeklyTargetsMet == 0)
        #expect(line.powerHoursTarget == nil)
    }
}

@Suite("v8 CSV for past weeks")
struct V8CSVTests {
    let week = WeekKey(year: 2026, week: 45)
    let known = ["1.1": "Ernährung", "3.2": "stammloop"]

    @Test func matrixColumnsBecomeMarks() {
        let text = """
        type,id,parent,title,days,schedule,mo,di,mi,do,fr,sa,so
        week,2026-W45,,,,,,,,,,,
        day,2026-11-06,,Krank,,,,,,,,,
        item,1.1-01,1.1,Protein,täglich,fix,✓,½,✗,–,,1,x
        item,1.1-02,1.1,Wasser,täglich,fix,,,,,,,vielleicht
        """
        let doc = PlanCSV.parse(text, knownCategories: known)
        func mark(_ code: String, _ weekday: Weekday) -> Mark? {
            doc.marks.first { $0.itemCode == code && $0.day == week.day(weekday) }?.mark
        }
        #expect(doc.items.count == 2)
        #expect(mark("1.1-01", .monday) == .done)
        #expect(mark("1.1-01", .tuesday) == .partial)
        #expect(mark("1.1-01", .wednesday) == .missed)
        #expect(mark("1.1-01", .thursday) == .notApplicable)
        #expect(mark("1.1-01", .friday) == nil, "blank stays blank")
        #expect(mark("1.1-01", .saturday) == .done)
        #expect(mark("1.1-01", .sunday) == .missed)
        #expect(doc.marks.filter { $0.itemCode == "1.1-01" }.count == 6)
        #expect(doc.marks.allSatisfy { $0.week == week })
        #expect(doc.skipped.count == 1 && doc.skipped[0].contains("So") && doc.skipped[0].contains("vielleicht"), "\(doc.skipped)")
        #expect(doc.days.first?.dayType == "Krank")
        #expect(doc.warnings.isEmpty, "\(doc.warnings)")
        // Long day names work too; the export stays in the long format.
        let long = PlanCSV.parse("""
        type,id,parent,title,montag,sonntag,fri
        week,2026-W45,,,,,
        item,1.1-01,1.1,Protein,1,0,0.5
        """, knownCategories: known)
        #expect(long.marks.count == 3)
        #expect(long.marks.first { $0.day == week.day(.friday) }?.mark == .partial)
        let exported = PlanCSV.export(long)
        #expect(exported.hasPrefix(PlanCSV.header + "\n"))
        #expect(exported.contains("mark,1.1-01,,,,,,,,,,,2026-11-02,1,"))
        #expect(PlanCSV.matrixHeader == PlanCSV.header + ",mo,di,mi,do,fr,sa,so")
    }

    @Test func marksOnUnknownItemsGetAWarning() {
        let text = """
        type,id,date,value
        week,2026-W45,,
        mark,1.1-01,2026-11-02,1
        mark,9.9-01,2026-11-02,1
        mark,9.9-01,2026-11-03,0
        mark,9.9-02,2026-11-03,0
        """
        let doc = PlanCSV.parse(text, knownItems: ["2026-W45|1.1-01"])
        #expect(doc.warnings == ["KW45: Markierungen für unbekannte Punkte 9.9-01, 9.9-02 – sie zählen erst, wenn es diese Punkte in der Woche gibt."])
        #expect(doc.marks.count == 4, "kept – only a warning")
        // Through the preview: the app's items are known.
        var state = ExistingState()
        let item = ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Protein")
        state.items[item.key] = item
        let preview = ImportPreview(text: text, existing: state)
        #expect(preview.document.warnings.count == 1)
        #expect(!preview.document.warnings[0].contains("1.1-01"))
        // A week whose plan is in the file only knows the file's items.
        let planned = PlanCSV.parse("""
        type,id,parent,title,date,value
        week,2026-W45,,,,
        item,1.1-02,1.1,Wasser,,
        mark,1.1-01,,,2026-11-02,1
        """, knownCategories: known, knownItems: ["2026-W45|1.1-01"])
        #expect(planned.warnings.contains { $0.contains("1.1-01") }, "\(planned.warnings)")
    }

    func pastDocument() -> PlanCSV.Document {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.days = [DayRecord(day: week.day(.friday), dayType: "Krank"), DayRecord(day: week.day(.saturday), dayType: "Frei")]
        doc.items = [
            ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Protein"),
            ItemRecord(week: week, code: "1.1-02", categoryKey: "1.1", position: 2, title: "Dreimal", schedule: .weekly(3)),
            ItemRecord(week: week, code: "1.1-03", categoryKey: "1.1", position: 3, title: "Nebenbei", secondary: true),
            ItemRecord(week: week, code: "1.1-04", categoryKey: "1.1", position: 4, title: "Wenn nötig", schedule: .conditional),
            ItemRecord(week: week, code: "3.2-01", categoryKey: "3.2", position: 1, title: "Deep Work", dayRule: .workOnly),
        ]
        doc.plannedWeeks = [week]
        doc.marks = [MarkRecord(week: week, itemCode: "1.1-01", day: week.monday, mark: .done),
                     MarkRecord(week: week, itemCode: "1.1-01", day: week.day(.tuesday), mark: nil)]
        return doc
    }

    @Test func fillingBlanksCountsOnlyWhatWasDue() {
        let filled = pastDocument().fillingBlanks(weeks: [week], with: .missed)
        func marked(_ code: String) -> [Weekday: Mark] {
            var result: [Weekday: Mark] = [:]
            for mark in filled.marks where mark.itemCode == code { result[mark.day.weekday] = mark.mark }
            return result
        }
        // Protein: Monday stays ✓, the cleared Tuesday and the other days get ✗, the sick Friday stays blank.
        #expect(marked("1.1-01") == [.monday: .done, .tuesday: .missed, .wednesday: .missed, .thursday: .missed,
                                      .saturday: .missed, .sunday: .missed])
        #expect(filled.marks.filter { $0.itemCode == "1.1-01" && $0.day == week.day(.tuesday) }.count == 1)
        // Work item: not on the free Saturday, not on the sick Friday.
        #expect(Set(marked("3.2-01").keys) == [.monday, .tuesday, .wednesday, .thursday, .sunday])
        #expect(marked("1.1-02").isEmpty && marked("1.1-03").isEmpty && marked("1.1-04").isEmpty)
        // Other weeks are left alone.
        #expect(pastDocument().fillingBlanks(weeks: [week.adding(weeks: 1)], with: .missed).marks.count == 2)
        // The filled week scores: Monday 10 for 1.1, the week isn't blank any more.
        let data = filled.weekData(week)
        #expect(data.excusedDays == [week.day(.friday)])
        #expect(data.workFreeDays.contains(week.day(.saturday)))
        #expect(data.categories.contains { $0.key == "3.2" && $0.goalKey == "3" }, "goal from the id when the file has no categories")
        #expect(week.days.allSatisfy { day in data.items.allSatisfy { !data.isOpenRequired($0, on: day) } })
    }

    @Test func closingPastClosesWeeksBeforeToday() {
        var doc = pastDocument()
        let next = week.adding(weeks: 1)
        let current = week.adding(weeks: 2)
        doc.items.append(ItemRecord(week: next, code: "1.1-01", categoryKey: "1.1", title: "Protein"))
        doc.plannedWeeks.insert(next)
        doc.weeks.append(WeekRecord(week: current))
        doc.marks.append(MarkRecord(week: current, itemCode: "1.1-01", day: current.monday, mark: .done))
        let closed = doc.closingPast(today: current.day(.wednesday))
        #expect(closed.closedWeeks == [week, next])
        // Days with a mark or a type: Monday (✓), Friday (Krank), Saturday (Frei) – not the cleared Tuesday.
        #expect(closed.closedDays == [week.monday, week.day(.friday), week.day(.saturday)])
        #expect(!closed.closedDays.contains(current.monday))
        #expect(closed.items == doc.items && closed.marks == doc.marks)
        // The current week stays open, with a warning.
        #expect(!closed.closedWeeks.contains(current))
        #expect(closed.warnings == ["KW47: noch nicht vorbei – wird nicht abgeschlossen."])
        #expect(doc.closingPast(today: current.adding(weeks: 1).monday).warnings.isEmpty)
    }

    @Test func previewPerWeek() {
        var state = ExistingState()
        let old = ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Protein")
        state.items[old.key] = old
        state.weeks[week.string] = WeekRecord(week: week)
        state.categories["1.1"] = CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung")
        let earlier = week.adding(weeks: -1)
        let paper = week.adding(weeks: -2)
        let text = """
        type,id,parent,title,value,mo,di,mi,do,fr,sa,so
        week,\(paper.string),,,7.5,,,,,,,
        week,\(earlier.string),,,,,,,,,,
        day,Fr,,Krank,,,,,,,,
        day,Sa,,Urlaub,,,,,,,,
        item,1.1-01,1.1,Protein,,✓,✓,✓,½,,,
        week,\(week.string),,,,,,,,,,
        item,1.1-01,1.1,Protein,,✓,,,,,,
        """
        let doc = PlanCSV.parse(text, knownCategories: state.categoryTitles, knownItems: state.itemKeys)
            .closingPast(today: week.adding(weeks: 1).monday)
        let preview = ImportPreview(document: doc, existing: state)
        #expect(preview.weekSummaries.map(\.week) == [paper, earlier, week])
        let first = preview.weekSummaries[0]
        #expect(first.isNew && first.recordedScore == 7.5 && first.items == 0 && first.status == "neu")
        #expect(first.detail == "Wertung 7,5 · wird abgeschlossen", "\(first.detail)")
        let second = preview.weekSummaries[1]
        #expect(second.items == 1 && second.marks == 4)
        #expect(second.excusedDays == [earlier.day(.friday), earlier.day(.saturday)])
        #expect(second.detail == "1 Punkt · 4 Markierungen · 2 Tage Krank/Urlaub · wird abgeschlossen", "\(second.detail)")
        #expect(second.title == "\(earlier.longLabel) (\(earlier.rangeLabel))")
        let third = preview.weekSummaries[2]
        #expect(!third.isNew && !third.isReplaced && third.hasChanges && third.status == "ergänzt", "same plan, a new mark")
        #expect(third.marks == 1 && third.closes)
        // Warnings go to their week.
        let unknown = PlanCSV.parse("""
        type,id,date,value
        week,\(week.string),,
        mark,9.9-01,\(week.monday.string),1
        """).closingPast(today: week.monday)
        let summary = ImportPreview(document: unknown, existing: state).weekSummaries
        #expect(summary.count == 1 && summary[0].warnings.count == 2, "\(summary)")
        #expect(!summary[0].closes)
    }

    func promptInput() -> (items: [ItemRecord], measures: [MeasureRecord]) {
        let source = week.adding(weeks: 1)
        let items = [
            ItemRecord(week: source, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Protein im Zielbereich"),
            ItemRecord(week: source, code: "3.2-01", categoryKey: "3.2", position: 1, title: "An stammloop gearbeitet", days: .workdays,
                       schedule: .progress, measure: "stammloop_ph", dayRule: .workOnly),
        ]
        let measures = [MeasureRecord(week: source, code: "stammloop_ph", categoryKey: "3.2", position: 1, title: "stammloop", unit: "PH",
                                      target: Target.parse(">=8"), period: .week, source: .work(category: "3.2"))]
        return (items, measures)
    }

    @Test func pastWeekPromptCarriesIdsAndFormat() {
        let (items, measures) = promptInput()
        let text = PastWeekPrompt.text(weeks: [week], items: items, categories: Template.categories, goals: Template.goals,
                                       measures: measures)
        #expect(text.contains("KW45 2026 (2.–8. Nov.)"))
        #expect(text.contains(PlanCSV.matrixHeader))
        #expect(text.contains("item,1.1-01,1.1,Protein im Zielbereich"))
        #expect(text.contains("item,3.2-01,3.2,An stammloop gearbeitet"))
        #expect(text.contains("measure,stammloop_ph,3.2,stammloop"))
        #expect(text.contains("week,2026-W45"))
        #expect(text.contains("day,Mo") && text.contains("day,So"))
        #expect(text.contains("Krank") && text.contains("Urlaub"))
        #expect(text.contains("nichts erfinden") && text.contains("keine Markierung für ein leeres Feld"))
        #expect(text.contains("einem Block je Woche"))
        #expect(text.contains("nur die week-Zeile mit dieser Zahl in value"))
        #expect(text.contains("3.2 stammloop"), "the structure")
        #expect(!text.contains("ChatGPT"))
        #expect(text.hasSuffix("## Meine Unterlagen für KW45:\n"))
        // The template reads back as the target week's plan.
        let doc = PlanCSV.parse(PlanCSV.extractCSV(from: text), knownCategories: known)
        #expect(doc.skipped.isEmpty, "\(doc.skipped)")
        #expect(doc.items.map(\.code).sorted() == ["1.1-01", "3.2-01"])
        #expect(doc.items.allSatisfy { $0.week == week })
        #expect(doc.measures.first?.week == week)
        #expect(doc.days.isEmpty, "empty day rows carry nothing")
        #expect(doc.marks.isEmpty)
    }

    @Test func pastWeekPromptForManyWeeks() {
        let (items, measures) = promptInput()
        let weeks = [week.adding(weeks: 2), week, week.adding(weeks: 1), week]
        let text = PastWeekPrompt.text(weeks: weeks, items: items, categories: Template.categories, goals: Template.goals,
                                       measures: measures)
        #expect(text.contains("3 vergangene Wochen"))
        #expect(text.contains("- KW45 2026 (2.–8. Nov.): week-id 2026-W45\n- KW46 2026 (9.–15. Nov.): week-id 2026-W46\n- KW47 2026"))
        #expect(text.contains("Nur die Wochen oben"))
        #expect(text.contains("## Vorlage: Block für KW45"))
        #expect(text.hasSuffix("## Meine Unterlagen:\n"))
        // A filled answer with two blocks: day rows by weekday belong to the week row above.
        let answer = """
        ```csv
        \(PlanCSV.matrixHeader)
        week,2026-W45,,,,,,,,,,,,,,,,,,,,
        day,Fr,,Krank,,,,,,,,,,,,,,,,,,
        item,1.1-01,1.1,Protein im Zielbereich,,täglich,fix,,,,,,,,,✓,✓,½,✗,,,
        week,2026-W46,,,,,,,,,,,,,,,,,,,,
        day,Mo,,Urlaub,,,,,,,,,,,,,,,,,,
        item,1.1-01,1.1,Protein im Zielbereich,,täglich,fix,,,,,,,,,,✓,,,,,
        week,,,,,,,,,,,,2026-11-18,7.5,,,,,,,,
        ```
        """
        let doc = PlanCSV.parse(answer, knownCategories: known)
        #expect(doc.skipped.isEmpty, "\(doc.skipped)")
        #expect(doc.days.map(\.day) == [week.day(.friday), week.adding(weeks: 1).monday])
        #expect(doc.marks.filter { $0.week == week }.count == 4 && doc.marks.filter { $0.week == week.adding(weeks: 1) }.count == 1)
        #expect(doc.weeks.last?.week == week.adding(weeks: 2) && doc.weeks.last?.recordedScore == 7.5, "a date finds the week")
    }

    @Test func pastWeekPromptForTheWeeksOfTheAttachments() {
        let (items, measures) = promptInput()
        let text = PastWeekPrompt.text(weeks: [], items: items, categories: Template.categories, goals: Template.goals, measures: measures)
        #expect(text.contains("KW und Datum jeder Woche liest du dort ab"))
        #expect(text.contains("Woche erkennen"))
        #expect(text.contains("week,\(PastWeekPrompt.weekPlaceholder)"))
        #expect(!text.contains("week,2026-W45") && !text.contains("week,2026-W46"), "no real week in the template, not the source week")
        #expect(text.contains("item,1.1-01,1.1,Protein im Zielbereich"))
        #expect(text.contains("Krank") && text.contains("nichts erfinden") && text.contains("einem Block je Woche"))
        #expect(!text.contains("ChatGPT"))
        #expect(text.hasSuffix("## Meine Unterlagen:\n"))
        // Pasted back unchanged, nothing lands in a wrong week.
        let doc = PlanCSV.parse(PlanCSV.extractCSV(from: text), knownCategories: known)
        #expect(doc.items.isEmpty && doc.weeks.isEmpty && !doc.skipped.isEmpty)
    }
}

/// Past weeks against what the app already has (`closingKnownDays`, `fillingPastBlanks`; the
/// import of path b uses them through `TrackerStore.pastPreview`).
@Suite("v8 past weeks against the app")
struct V8PastAgainstAppTests {
    let today = DayKey(year: 2026, month: 11, day: 21)
    let week = WeekKey(year: 2026, week: 44)
    var monday: DayKey { week.day(.monday) }
    var tuesday: DayKey { week.day(.tuesday) }
    var friday: DayKey { week.day(.friday) }
    let marksOnly = "type,id,date,value\nweek,2026-W44,,\nmark,4-03,Di,1\n"

    /// The app has KW44 open: two items with ✓ on Monday, Friday "Krank".
    func appState(closed: Bool = false) -> ExistingState {
        var existing = ExistingState()
        existing.weeks[week.string] = WeekRecord(week: week)
        for code in ["4-03", "1.1-01"] {
            let item = ItemRecord(week: week, code: code, categoryKey: String(code.split(separator: "-")[0]), title: code)
            existing.items[item.key] = item
            let mark = MarkRecord(week: week, itemCode: code, day: monday, mark: .done)
            existing.marks[mark.key] = mark
        }
        existing.days[friday.string] = DayRecord(day: friday, dayType: "Krank")
        if closed { existing.closedWeeks = [week] }
        return existing
    }

    @Test func closingKnownDaysClosesWhatTheAppHasMarkedOrTyped() {
        let existing = appState()
        let doc = PlanCSV.parse(marksOnly, knownItems: existing.itemKeys)
        let closed = doc.closingPast(today: today).closingKnownDays(existing: existing)
        #expect(closed.closedWeeks.contains(week))
        #expect(closed.closedDays == [monday, tuesday, friday], "Mo (app ✓), Di (file), Fr (app Krank)")
        // A week the app has closed already stays as it is.
        let closedApp = appState(closed: true)
        let past = PlanCSV.parse(marksOnly, knownItems: closedApp.itemKeys).closingPast(today: today)
        #expect(past.closingKnownDays(existing: closedApp).closedDays == past.closedDays)
        // The current week: nothing closes.
        let current = PlanCSV.parse("type,id,date,value\nweek,2026-W47,,\nmark,4-03,Mo,1\n").closingPast(today: today)
        let untouched = current.closingKnownDays(existing: existing)
        #expect(untouched.closedWeeks.isEmpty && untouched.closedDays.isEmpty)
    }

    @Test func closingKnownDaysLeavesReplacedMarksAndFileRowsToTheFile() {
        let existing = appState()
        // The file replaces the plan: the app's marks go to the archive, Monday stays open.
        let replacing = "type,id,parent,title,days,schedule,date,value\nweek,2026-W44,,,,,,\nitem,4-03,4,Neu,täglich,fix,,\nmark,4-03,,,,,2026-10-27,1\n"
        let doc = PlanCSV.parse(replacing, knownCategories: ["4": "Schlaf"], knownItems: existing.itemKeys)
        #expect(ImportPreview(document: doc, existing: existing).replacedWeeks == [week])
        let closed = doc.closingPast(today: today).closingKnownDays(existing: existing)
        #expect(!closed.closedDays.contains(monday))
        #expect(closed.closedDays.isSuperset(of: [tuesday, friday]))
        // A day row of the file decides over the app's type; a mark the file sets itself is the file's.
        let typed = "type,id,title,date,value\nweek,2026-W44,,,\nday,Fr,Arbeitstag,,\nmark,4-03,,2026-10-26,0\n"
        let own = PlanCSV.parse(typed, knownItems: existing.itemKeys).closingPast(today: today).closingKnownDays(existing: existing)
        #expect(own.closedDays == [monday, friday])
    }

    @Test func fillingPastBlanksKeepsTheAppsMarksAndSkipsSickDays() {
        let existing = appState()
        let doc = PlanCSV.parse(marksOnly, knownItems: existing.itemKeys).fillingPastBlanks(existing: existing, today: today)
        #expect(!doc.marks.contains { $0.day == monday }, "the app's ✓ stay")
        #expect(!doc.marks.contains { $0.day == friday }, "Krank: nothing due")
        #expect(doc.marks.contains { $0.itemCode == "1.1-01" && $0.day == tuesday && $0.mark == .missed }, "filled on the app's plan")
        #expect(doc.marks.contains { $0.itemCode == "4-03" && $0.day == tuesday && $0.mark == .done }, "the file's mark stays")
        let before = doc.closingPast(today: today)
        #expect(!before.closedDays.contains(monday), "closingPast alone misses Monday")
        let closed = before.closingKnownDays(existing: existing)
        #expect(closed.closedDays == Set(week.days))
        let preview = ImportPreview(document: closed, existing: existing)
        #expect(preview.newClosedDays.count == 7 && preview.newClosedWeeks == [week])
        #expect(preview.replacedWeeks.isEmpty)
        // Weeks from this one on are never filled.
        let current = PlanCSV.parse("type,id,date,value\nweek,2026-W47,,\nmark,4-03,Mo,1\n")
        #expect(current.fillingPastBlanks(existing: existing, today: today).marks == current.marks)
    }
}

@Suite("v8 report over several weeks")
struct V8RangeTests {
    let start = WeekKey(year: 2026, week: 40)
    let goals = [GoalRecord(key: "1", title: "Ziel A"), GoalRecord(key: "2", title: "Ziel B"), GoalRecord(key: "3", title: "Ziel C")]

    @Test func averageAndTrend() {
        var lines: [WeekLine] = [WeekLine(week: start, score: 3, isClosed: true, isOldScoring: true, goalScores: ["1": 1])]
        for offset in 1...8 {
            let goal1: Double = offset <= 4 ? 5 : 7
            lines.append(WeekLine(week: start.adding(weeks: offset), score: Double(offset), isClosed: offset < 8,
                                  goalScores: ["1": goal1, "2": 7], powerHours: 10, powerHoursTarget: 8, closedDays: 7,
                                  weeklyTargetsMet: 1, weeklyTargetsCount: 2))
        }
        lines.append(WeekLine(week: start.adding(weeks: 9), isClosed: true, isExcused: true, excusedDays: 7))
        let work = [WorkRecord(id: "a", day: start.monday, categoryKey: "3.2", task: "", powerHours: 6),
                    WorkRecord(id: "b", day: start.monday, categoryKey: "3.1", task: "", powerHours: 2),
                    WorkRecord(id: "c", day: start.sunday, categoryKey: "3.2", task: "", powerHours: 1)]
        let report = RangeReport(lines: lines.reversed(), goals: goals, work: work,
                                 categories: [CategoryRecord(key: "3.2", goalKey: "3", title: "stammloop")])
        #expect(report.lines.first?.week == start, "oldest first")
        #expect(report.average == 4.5, "1…8, without the old and the excused week")
        #expect(report.oldAverage == 3)
        #expect(report.scoredWeeks == 8)
        let goal1 = report.goals.first { $0.key == "1" }
        #expect(goal1?.average == 6)
        #expect(goal1?.firstFour == 5 && goal1?.lastFour == 7)
        #expect(goal1?.trend == 1 && goal1?.trendArrow == "↑" && goal1?.trendWord == "steigend" && goal1?.trendSymbol == "arrow.up.right")
        #expect(report.goals.first { $0.key == "2" }?.trendArrow == "→")
        #expect(report.goals.first { $0.key == "3" }?.trendArrow == "–")
        #expect(report.goals.map(\.key) == ["1", "2", "3"])
        #expect(report.work == [RangeReport.WorkLine(categoryKey: "3.2", title: "stammloop", powerHours: 7),
                                RangeReport.WorkLine(categoryKey: "3.1", title: "3.1", powerHours: 2)])
        #expect(report.powerHours == 80 && report.powerHoursTarget == 64)
        #expect(report.closedWeeks == 9 && report.closedDays == 56)
        #expect(report.excusedWeeks == 1 && report.excusedDays == 7)
        #expect(report.weeklyTargetsMet == 8 && report.weeklyTargetsCount == 16)
        #expect(report.title == "KW40–KW49 2026")
        let falling = RangeReport.GoalLine(key: "1", title: "A", firstFour: 7, lastFour: 6.7)
        #expect(falling.trend == -1)
        #expect(RangeReport.GoalLine(key: "1", title: "A", firstFour: 7, lastFour: 7.2).trend == 0, "±0,25 counts as steady")
    }

    @Test func weekLineFromAReportInput() {
        let week = WeekKey(year: 2026, week: 47)
        let categories = [CategoryRecord(key: "1.2", goalKey: "1", title: "Training"), CategoryRecord(key: "3.2", goalKey: "3", title: "stammloop")]
        let item = ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", title: "Workout", schedule: .weekly(3))
        let measure = MeasureRecord(week: week, code: "ph", categoryKey: "3.2", title: "stammloop", unit: "PH", target: Target.parse(">=8"),
                                    period: .week, source: .work(category: "3.2"), days: .workdays)
        let sick = [DayRecord(day: week.day(.thursday), dayType: "Krank"), DayRecord(day: week.day(.friday), dayType: "Krank")]
        let input = WeekReportInput(
            week: WeekRecord(week: week), goals: [GoalRecord(key: "1", title: "Fit")], categories: categories, items: [item],
            measures: [measure], marks: [MarkRecord(week: week, itemCode: item.code, day: week.monday, mark: .done)], days: sick,
            work: [WorkRecord(id: "w", day: week.monday, categoryKey: "3.2", task: "", powerHours: 5)],
            closedDays: [week.monday, week.day(.tuesday)], isClosed: true, today: week.sunday.adding(days: 1)
        )
        let line = WeekLine(input)
        #expect(line.excusedDays == 2)
        #expect(!line.isExcused)
        #expect(line.closedDays == 2)
        #expect(line.powerHours == 5)
        #expect(abs((line.powerHoursTarget ?? 0) - 4.8) < 1e-9, "8 PH × 3/5")
        #expect(line.weeklyTargetsCount == 1 && line.weeklyTargetsMet == 1, "5 of 4,8 PH")
        #expect(line.score != nil && line.goalScores["1"] != nil)
        #expect(!line.isPaperOnly)
        let stored = WeekLine(input, storedScore: 6.5, storedGoalScores: ["1": 6.5])
        #expect(stored.score == 6.5 && stored.goalScores == ["1": 6.5])
        let paper = WeekLine(WeekReportInput(week: WeekRecord(week: week, recordedScore: 7.2), goals: [], categories: [], items: [],
                                             measures: [], marks: [], today: week.sunday))
        #expect(paper.isPaperOnly && paper.score == 7.2)
    }
}
