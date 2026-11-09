import Foundation
import Testing
@testable import ThaliaCore

@Suite("Scoring")
struct ScoringTests {
    let week = WeekKey(year: 2026, week: 45)
    var monday: DayKey { week.monday }

    /// Ten fixed daily items in a category.
    func items(_ category: String, schedule: ItemSchedule = .fixed, days: DayMask = .everyDay, knockoutAt: Int? = nil) -> [ItemRecord] {
        (1...10).map {
            ItemRecord(week: week, code: "\(category)-\($0)", categoryKey: category, position: $0, title: "Punkt \($0)",
                       days: days, schedule: schedule, knockout: $0 == knockoutAt)
        }
    }

    func marks(_ category: String, on day: DayKey, done: Int, missed: Int, partial: Int = 0, na: Int = 0) -> [String: Mark] {
        var result: [String: Mark] = [:]
        var n = 1
        for (mark, count) in [(Mark.done, done), (.missed, missed), (.partial, partial), (.notApplicable, na)] {
            for _ in 0..<count {
                result[WeekData.markKey("\(category)-\(n)", day)] = mark
                n += 1
            }
        }
        return result
    }

    let fitBody = [GoalRecord(key: "1", title: "Fit Body"), GoalRecord(key: "4", title: "Schlaf")]
    let categories = [
        CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung und Gewicht"),
        CategoryRecord(key: "1.2", goalKey: "1", title: "Training und Tennis"),
        CategoryRecord(key: "4", goalKey: "4", title: "Schlaf"),
    ]

    @Test func handoverExampleNutrition8Training6IsFitBody7() {
        let marks = marks("1.1", on: monday, done: 8, missed: 2).merging(marks("1.2", on: monday, done: 6, missed: 4)) { a, _ in a }
        let data = WeekData(week: week, goals: [fitBody[0]], categories: Array(categories.prefix(2)),
                            items: items("1.1") + items("1.2"), marks: marks)
        let score = Scorer.score(data)
        #expect(score.category("1.1", on: monday).score == 8)
        #expect(score.category("1.2", on: monday).score == 6)
        #expect(score.goalWeek["1"]?.score == 7)
        #expect(score.overall == 7)
    }

    @Test func goalsWeighEquallyRegardlessOfCategoryCount() {
        // Fit Body (two categories, 10 + 10) and Sleep (one category, 4) → (10 + 4) / 2 = 7, not (10+10+4)/3.
        var all = marks("1.1", on: monday, done: 10, missed: 0)
        all.merge(marks("1.2", on: monday, done: 10, missed: 0)) { a, _ in a }
        all.merge(marks("4", on: monday, done: 4, missed: 6)) { a, _ in a }
        let data = WeekData(week: week, goals: fitBody, categories: categories, items: items("1.1") + items("1.2") + items("4"), marks: all)
        let score = Scorer.score(data)
        #expect(score.goalWeek["1"]?.score == 10)
        #expect(score.goalWeek["4"]?.score == 4)
        #expect(score.overall == 7)
        #expect(score.days[monday]?.score == 7)
    }

    @Test func notApplicableAndBlankDontCountButBlankStaysVisible() {
        let data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[0]], items: items("1.1"),
                            marks: marks("1.1", on: monday, done: 3, missed: 1, partial: 0, na: 2))
        let day = Scorer.score(data).category("1.1", on: monday)
        #expect(day.applicable == 4)
        #expect(day.score == nil, "no score while items are still blank")
        #expect(day.calculated == 7.5)
        #expect(day.due == 10)
        #expect(day.blank == 4)
        #expect(day.fill == 0.6)
    }

    @Test func partialCountsHalf() {
        let data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[0]], items: items("1.1"),
                            marks: marks("1.1", on: monday, done: 8, missed: 0, partial: 2))
        #expect(Scorer.score(data).category("1.1", on: monday).score == 9)
    }

    @Test func notScheduledIsNotMissed() {
        // Work items only Mon–Fri: Saturday has nothing due and no score.
        let data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[0]], items: items("1.1", days: .workdays))
        let saturday = Scorer.score(data).category("1.1", on: week.day(.saturday))
        #expect(saturday.due == 0)
        #expect(saturday.score == nil)
        #expect(Scorer.score(data).categoryWeek["1.1"] == nil)
    }

    @Test func weeklyAverageUsesOnlyValidDays() {
        var all = marks("1.1", on: monday, done: 10, missed: 0)
        all.merge(marks("1.1", on: monday.adding(days: 1), done: 5, missed: 5)) { a, _ in a }
        let data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[0]], items: items("1.1"), marks: all)
        #expect(Scorer.score(data).categoryWeek["1.1"] == 7.5)
    }

    @Test func optionalItemsAreNeverScored() {
        let hobby = items("1.1", schedule: .optional)
        let data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[0]], items: hobby,
                            marks: marks("1.1", on: monday, done: 10, missed: 0))
        let score = Scorer.score(data)
        #expect(score.category("1.1", on: monday).score == nil, "no fabricated ten")
        #expect(score.goalWeek["1"]?.score == nil, "no automatic zero")
        #expect(score.overall == nil)
    }

    @Test func missingGoalCoverageIsVisible() {
        let data = WeekData(week: week, goals: fitBody, categories: categories, items: items("1.1"),
                            marks: marks("1.1", on: monday, done: 9, missed: 1))
        let score = Scorer.score(data)
        #expect(score.goalsScored == 1)
        #expect(score.goalsTotal == 2)
        #expect(!score.isComplete)
        #expect(score.coverageText == "1/2 Ziele bewertet – nicht voll vergleichbar")
    }

    @Test func knockoutRuleZeroesTheCategoryButKeepsTheMarks() {
        let sleep = items("4", knockoutAt: 3)
        var all = marks("4", on: monday, done: 10, missed: 0)
        all[WeekData.markKey("4-3", monday)] = .missed
        let data = WeekData(week: week, goals: [fitBody[1]], categories: [categories[2]], items: sleep, marks: all)
        let day = Scorer.score(data).category("4", on: monday)
        #expect(day.knockedOut)
        #expect(day.score == 0)
        #expect(day.earned == 9, "the entries themselves stay intact")
    }

    @Test func ownScoreOverridesTheCalculation() {
        var data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[0]], items: items("1.1"),
                            marks: marks("1.1", on: monday, done: 6, missed: 4))
        data.overrides[WeekData.overrideKey("1.1", monday)] = 8
        let day = Scorer.score(data).category("1.1", on: monday)
        #expect(day.score == 8)
        #expect(day.overridden)
        #expect(day.calculated == 6)
    }

    @Test func weeklyQuotaShortfallCountsOnlyOnceTheWeekIsOver() {
        let training = [ItemRecord(week: week, code: "1.2-4", categoryKey: "1.2", title: "Tennis an der Wand",
                                   days: DayMask.parse("Di,Do,Sa")!, schedule: .weekly(2))]
        let tuesday = week.day(.tuesday)
        let marks = [WeekData.markKey("1.2-4", tuesday): Mark.done]
        let open = WeekData(week: week, goals: [fitBody[0]], categories: [categories[1]], items: training, marks: marks, isComplete: false)
        #expect(Scorer.score(open).categoryWeek["1.2"] == 10)
        let complete = WeekData(week: week, goals: [fitBody[0]], categories: [categories[1]], items: training, marks: marks, isComplete: true)
        let score = Scorer.score(complete)
        let saturday = score.category("1.2", on: week.day(.saturday))
        #expect(saturday.shortfall == 1)
        #expect(saturday.score == 0)
        #expect(score.categoryWeek["1.2"] == 5)
    }

    @Test func missedMarkUsesAQuotaSlot() {
        let training = [ItemRecord(week: week, code: "q", categoryKey: "1.2", title: "Q", schedule: .weekly(2))]
        let marks = [WeekData.markKey("q", monday): Mark.done, WeekData.markKey("q", monday.adding(days: 1)): Mark.missed]
        let data = WeekData(week: week, goals: [fitBody[0]], categories: [categories[1]], items: training, marks: marks, isComplete: true)
        let score = Scorer.score(data)
        #expect(score.category("1.2", on: week.sunday).shortfall == 0)
        #expect(score.categoryWeek["1.2"] == 5)
    }

    @Test func weekCompleteness() {
        #expect(!Scorer.isComplete(week: week, today: week.sunday, closed: false))
        #expect(Scorer.isComplete(week: week, today: week.sunday.adding(days: 1), closed: false))
        #expect(Scorer.isComplete(week: week, today: monday, closed: true))
    }

    @Test func paceAgainstAnEvenWeek() {
        let wednesday = week.day(.wednesday)
        let pace = Pace(done: 3, target: 8, days: .workdays, week: week, today: wednesday)
        #expect(abs(pace.expected - 4.8) < 0.001)
        #expect(pace.isBehind)
        #expect(pace.label(unit: "PH") == "3 von 8 PH – hinter dem Plan")
        let onTrack = Pace(done: 4.5, target: 8, days: .workdays, week: week, today: wednesday)
        #expect(!onTrack.isBehind)
        #expect(Pace(done: 8, target: 8, days: .workdays, week: week, today: wednesday).isReached)
    }
}

@Suite("Measurements and work")
struct MeasureTests {
    let week = WeekKey(year: 2026, week: 45)

    @Test func everythingIsPowerHoursTutoringToo() {
        // 8 PH stammloop, 3 PH HAEB, 1 PH other, 16 PH tutoring (50-min lessons) = 28 PH.
        let day = week.monday
        let blocks = [
            WorkRecord(id: "s", day: day, categoryKey: "3.2", task: "Landingpage", powerHours: 8),
            WorkRecord(id: "h", day: day, categoryKey: "3.4", task: "HAEB", powerHours: 3),
            WorkRecord(id: "o", day: day, categoryKey: "3.5", task: "", powerHours: 1),
            WorkRecord(id: "t", day: day, categoryKey: "3.3", task: "Lena – Mathe", powerHours: 16),
        ]
        let totals = WorkTotals(blocks)
        #expect(totals.powerHours == 28)
        #expect(totals.netMinutes == 1400)
        #expect(totals.explanation == "28 PH × 50 min = 23,33 h netto")
        #expect(WorkTotals.byCategory(blocks)["3.3"]?.shortText == "16 PH")
        #expect(PowerHour.quick == [0.25, 0.5, 0.75, 1, 2])
    }

    @Test func workMeasureInPowerHours() {
        let blocks = [WorkRecord(id: "a", day: week.monday, categoryKey: "3.2", task: "", powerHours: 2),
                      WorkRecord(id: "b", day: week.monday, categoryKey: "3.2", task: "", powerHours: 0.25)]
        let stammloop = MeasureRecord(week: week, code: "stammloop_ph", title: "stammloop", unit: "PH", target: Target.parse(">=8"),
                                      period: .week, source: .work(category: "3.2"))
        #expect(Measures.dayValue(stammloop, on: week.monday, entries: [], work: blocks) == 2.25)
        #expect(Measures.weekValue(stammloop, days: week.days, entries: [], work: blocks) == 2.25)
        // v3: work always counts in PH, even when the plan wrote hours.
        let hours = MeasureRecord(week: week, code: "h", title: "h", unit: "h", source: .work(category: "3.2"))
        #expect(Measures.dayValue(hours, on: week.monday, entries: [], work: blocks) == 2.25)
    }

    @Test func entriesAggregate() {
        let day = week.monday
        let protein = MeasureRecord(week: week, code: "protein", title: "Protein", unit: "g", target: Target.parse(">=150"))
        let weight = MeasureRecord(week: week, code: "gewicht", title: "Gewicht", unit: "kg")
        let entries = [
            EntryRecord(code: "protein", day: day, value: 60, order: 1),
            EntryRecord(code: "protein", day: day, value: 95, order: 2),
            EntryRecord(code: "gewicht", day: day, value: 88.1, order: 1),
            EntryRecord(code: "gewicht", day: day, value: 87.9, order: 2),
        ]
        #expect(Measures.dayValue(protein, on: day, entries: entries) == 155)
        #expect(Measures.dayValue(weight, on: day, entries: entries) == 87.9)
        #expect(Measures.isMet(protein, value: 155) == true)
        #expect(Measures.dayValue(protein, on: day.adding(days: 1), entries: entries) == nil)
    }

    @Test func bedtimesAverageAcrossMidnight() {
        let bedtime = MeasureRecord(week: week, code: "bettzeit", title: "Im Bett", unit: "Uhrzeit", target: Target.parse("<=23:00"))
        let entries = [
            EntryRecord(code: "bettzeit", day: week.monday, value: 23 * 60 + 30),
            EntryRecord(code: "bettzeit", day: week.monday.adding(days: 1), value: 30),
        ]
        #expect(Measures.weekValue(bedtime, days: week.days, entries: entries) == 1440.0)
    }

    @Test func suggestionsNeverInventFailures() {
        let logged = ItemRecord(week: week, code: "a", categoryKey: "1.1", title: "Protein erfassen", measure: "protein")
        let goal = ItemRecord(week: week, code: "b", categoryKey: "1.1", title: "Proteinziel", target: Target.parse(">=150"), measure: "protein")
        let unlinked = ItemRecord(week: week, code: "c", categoryKey: "1.1", title: "Gemüse")
        #expect(Measures.suggestion(for: logged, dayValue: 40) == .done)
        #expect(Measures.suggestion(for: logged, dayValue: nil) == nil, "not logged yet stays blank")
        #expect(Measures.suggestion(for: goal, dayValue: 162) == .done)
        #expect(Measures.suggestion(for: goal, dayValue: 120) == .missed)
        #expect(Measures.suggestion(for: unlinked, dayValue: 120) == nil)
        let progress = ItemRecord(week: week, code: "p", categoryKey: "3.2", title: "An stammloop gearbeitet", schedule: .progress, measure: "stammloop_ph")
        #expect(Measures.suggestion(for: progress, dayValue: 3) == nil, "progress items are resolved from the week")
    }
}

@Suite("Scoring v2")
struct ScoringV2Tests {
    let week = WeekKey(year: 2026, week: 45)
    let goals = [GoalRecord(key: "1", title: "Fit Body"), GoalRecord(key: "3", title: "Binisoft")]
    let categories = [
        CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung"),
        CategoryRecord(key: "1.2", goalKey: "1", title: "Training"),
        CategoryRecord(key: "3.2", goalKey: "3", title: "stammloop"),
    ]

    func item(_ code: String, _ category: String, _ schedule: ItemSchedule = .fixed, days: DayMask = .everyDay) -> ItemRecord {
        ItemRecord(week: week, code: code, categoryKey: category, title: code, days: days, schedule: schedule,
                   measure: schedule == .progress ? "stammloop_ph" : "")
    }

    @Test func goalNeedsAllItsCategoriesComplete() {
        let monday = week.monday
        let items = [item("a", "1.1", days: DayMask([.monday])), item("b", "1.2", days: DayMask([.monday]))]
        var data = WeekData(week: week, goals: goals, categories: categories, items: items,
                            marks: [WeekData.markKey("a", monday): .done])
        var score = Scorer.score(data)
        #expect(score.category("1.1", on: monday).score == 10)
        #expect(score.category("1.2", on: monday).score == nil)
        #expect(score.goalWeek["1"]?.score == nil, "1.2 isn't filled in yet")
        #expect(score.days[monday]?.isComplete == false)
        #expect(score.days[monday]?.coverageText == "50 %")
        data.marks[WeekData.markKey("b", monday)] = .missed
        score = Scorer.score(data)
        #expect(score.goalWeek["1"]?.score == 5)
        #expect(score.days[monday]?.isComplete == true)
    }

    @Test func progressItemsWaitForTheWeekAndResolveBackwards() {
        let progress = item("p", "3.2", .progress, days: .workdays)
        let marks: [String: Mark] = [
            WeekData.markKey("p", week.day(.monday)): .done,
            WeekData.markKey("p", week.day(.tuesday)): .notApplicable,
            WeekData.markKey("p", week.day(.wednesday)): .done,
        ]
        // Week running, 6 of 8 PH: worked days are pending, nothing counts yet.
        var data = WeekData(week: week, goals: goals, categories: categories, items: [progress], marks: marks, progress: ["p": 0.75])
        var monday = Scorer.score(data).category("3.2", on: week.monday)
        #expect(monday.pending == 1)
        #expect(monday.applicable == 0)
        #expect(monday.isComplete)
        // Target reached early (8 of 8): worked days count as done right away.
        data.progress["p"] = 1.0
        monday = Scorer.score(data).category("3.2", on: week.monday)
        #expect(monday.score == 10)
        #expect(Scorer.score(data).category("3.2", on: week.day(.tuesday)).score == nil, "heute nicht stays N/A")
        // Week over, 6 of 8: worked days are partly done.
        data.progress["p"] = 0.75
        data.isComplete = true
        monday = Scorer.score(data).category("3.2", on: week.monday)
        #expect(monday.score == 5)
        // Week over, nothing reached: worked days count 0.
        data.progress["p"] = 0
        #expect(Scorer.score(data).category("3.2", on: week.monday).score == 0)
    }

    @Test func neverWorkedOnAMissedTargetCountsOnceAtTheEnd() {
        let progress = item("p", "3.2", .progress, days: .workdays)
        var marks: [String: Mark] = [:]
        for day in week.days where DayMask.workdays.contains(day.weekday) { marks[WeekData.markKey("p", day)] = .notApplicable }
        let data = WeekData(week: week, goals: goals, categories: categories, items: [progress], marks: marks,
                            isComplete: true, progress: ["p": 0.2])
        let friday = Scorer.score(data).category("3.2", on: week.day(.friday))
        #expect(friday.shortfall == 1)
        #expect(friday.score == 0)
    }

    @Test func notApplicableOnlyWhileEnoughDaysAreLeft() {
        // Stretching 3× a week, nothing done yet: N/A possible until Thursday, not on Friday.
        let stretching = item("s", "1.2", .weekly(3))
        var data = WeekData(week: week, goals: goals, categories: categories, items: [stretching])
        #expect(Scorer.canMarkNotApplicable(stretching, on: week.day(.thursday), data: data))
        #expect(!Scorer.canMarkNotApplicable(stretching, on: week.day(.friday), data: data))
        #expect(Scorer.options(for: stretching, on: week.day(.friday), data: data) == [.done, .partial, .missed])
        // Two done already: one more needed, so Saturday is still fine.
        data.marks[WeekData.markKey("s", week.monday)] = .done
        data.marks[WeekData.markKey("s", week.day(.tuesday))] = .done
        #expect(Scorer.canMarkNotApplicable(stretching, on: week.day(.saturday), data: data))
        #expect(!Scorer.canMarkNotApplicable(stretching, on: week.sunday, data: data))
        #expect(Scorer.options(for: item("p", "3.2", .progress), on: week.monday, data: data) == [.done, .notApplicable])
    }

    @Test func progressRatioFromWork() {
        let measure = MeasureRecord(week: week, code: "stammloop_ph", title: "stammloop", unit: "PH", target: Target.parse(">=8"),
                                    period: .week, source: .work(category: "3.2"))
        let work = [WorkRecord(id: "1", day: week.monday, categoryKey: "3.2", task: "", powerHours: 6)]
        let ratio = Measures.progressRatio(for: item("p", "3.2", .progress), measures: [measure], days: week.days, entries: [], work: work)
        #expect(ratio == 0.75)
        #expect(MeasureGroup(measure) == .work)
    }
}

@Suite("Scoring v3")
struct ScoringV3Tests {
    let week = WeekKey(year: 2026, week: 46)
    let goals = [GoalRecord(key: "2", title: "Strong Mind"), GoalRecord(key: "3", title: "Binisoft")]
    let categories = [
        CategoryRecord(key: "2.1", goalKey: "2", title: "Mentale Routinen"),
        CategoryRecord(key: "3.1", goalKey: "3", title: "Morgenroutine"),
        CategoryRecord(key: "3.2", goalKey: "3", title: "stammloop"),
    ]
    let stammloop = MeasureRecord(week: WeekKey(year: 2026, week: 46), code: "stammloop_ph", title: "stammloop", unit: "PH",
                                  target: Target.parse(">=8"), period: .week, source: .work(category: "3.2"))

    @Test func progressItemsFollowTheirMeasurement() throws {
        let item = ItemRecord(week: week, code: "p", categoryKey: "3.2", title: "An stammloop gearbeitet", days: .workdays,
                              schedule: .progress, measure: "stammloop_ph")
        let work = [WorkRecord(id: "1", day: week.monday, categoryKey: "3.2", task: "", powerHours: 3),
                    WorkRecord(id: "2", day: week.day(.wednesday), categoryKey: "3.2", task: "", powerHours: 5)]
        let worked = try #require(Measures.workedDays(for: item, measures: [stammloop], days: week.days, entries: [], work: work))
        #expect(worked == [week.monday, week.day(.wednesday)])
        // A stored mark is ignored: the measurement decides.
        let data = WeekData(week: week, goals: goals, categories: categories, items: [item],
                            marks: [WeekData.markKey("p", week.day(.tuesday)): .done],
                            progress: ["p": 1], worked: ["p": worked])
        #expect(data.isDerived(item))
        #expect(data.mark(item, on: week.monday) == .done)
        #expect(data.mark(item, on: week.day(.tuesday)) == .notApplicable)
        #expect(Scorer.options(for: item, on: week.monday, data: data).isEmpty, "nothing to tick")
        let score = Scorer.score(data)
        #expect(score.category("3.2", on: week.monday).score == 10, "8 of 8 PH reached → worked days count")
        #expect(score.category("3.2", on: week.day(.tuesday)).blank == 0, "never blank")
    }

    @Test func freeDaysLeaveWorkOut() {
        let familyDay = week.day(.saturday)
        let business = ItemRecord(week: week, code: "b", categoryKey: "3.2", title: "Deep Work")
        let morning = ItemRecord(week: week, code: "m", categoryKey: "3.1", title: "Morgenroutine")
        let mind = ItemRecord(week: week, code: "r", categoryKey: "2.1", title: "Meditation")
        let data = WeekData(week: week, goals: goals, categories: categories, items: [business, morning, mind],
                            workFreeDays: [familyDay])
        // No explicit rules: Business except the morning routine is work-day-only.
        #expect(data.isWorkOnly(business))
        #expect(!data.isWorkOnly(morning))
        #expect(!data.applies(business, on: familyDay))
        #expect(data.applies(business, on: week.monday))
        #expect(data.mark(business, on: familyDay) == .notApplicable)
        #expect(Scorer.options(for: business, on: familyDay, data: data).isEmpty)
        let saturday = Scorer.score(data).days[familyDay]
        #expect(saturday?.due == 2, "morning routine and meditation stay due")
        // Explicit rules in the plan switch the category default off.
        let explicit = ItemRecord(week: week, code: "x", categoryKey: "2.1", title: "Fokus-Block", dayRule: .workOnly)
        let free = ItemRecord(week: week, code: "y", categoryKey: "3.2", title: "Ideen notieren", dayRule: .always)
        let planned = WeekData(week: week, goals: goals, categories: categories, items: [business, explicit, free], workFreeDays: [familyDay])
        #expect(!planned.isWorkOnly(business))
        #expect(planned.isWorkOnly(explicit))
        #expect(planned.applies(free, on: familyDay))
        #expect(DayTypes.isWorkFree("Familientag"))
        #expect(DayTypes.isWorkFree("Erholungstag"))
        #expect(!DayTypes.isWorkFree("Arbeitstag"))
    }

    @Test func secondaryItemsCountOnlyWhenFilled() {
        let monday = week.monday
        let main = ItemRecord(week: week, code: "a", categoryKey: "2.1", title: "Meditation", days: DayMask([.monday]))
        let side = ItemRecord(week: week, code: "j", categoryKey: "2.1", title: "Journalfrage", days: DayMask([.monday]), secondary: true)
        var data = WeekData(week: week, goals: goals, categories: categories, items: [main, side],
                            marks: [WeekData.markKey("a", monday): .done])
        var entry = Scorer.score(data).category("2.1", on: monday)
        #expect(entry.isComplete, "an empty Nebensache blocks nothing")
        #expect(entry.score == 10)
        data.marks[WeekData.markKey("j", monday)] = .missed
        entry = Scorer.score(data).category("2.1", on: monday)
        #expect(entry.score == 5, "filled in, it counts")
    }

    @Test func weeklyItemsLeaveTheDayOnceTheQuotaIsMet() {
        let stretch = ItemRecord(week: week, code: "s", categoryKey: "2.1", title: "Dehnen", schedule: .weekly(2))
        var data = WeekData(week: week, goals: goals, categories: categories, items: [stretch],
                            marks: [WeekData.markKey("s", week.monday): .done])
        #expect(!Scorer.isQuotaMetElsewhere(stretch, on: week.day(.wednesday), data: data))
        data.marks[WeekData.markKey("s", week.day(.tuesday))] = .done
        #expect(Scorer.isQuotaMetElsewhere(stretch, on: week.day(.wednesday), data: data))
        #expect(!Scorer.isQuotaMetElsewhere(stretch, on: week.monday, data: data), "the day that counted keeps it")
    }

    @Test func flagsRoundTripThroughTheCSV() {
        let csv = """
        type,id,parent,title,description,days,schedule,unit,target,period,link,flags
        goal,2,,Strong Mind,,,,,,,,
        goal,3,,Binisoft,,,,,,,,
        category,2.1,2,Mentale Routinen,,,,,,,,
        category,3.2,3,stammloop,,,,,,,,
        week,2026-W46,,KW46,,,,,,,,
        item,2.1-01,2.1,Journalfrage,,täglich,fix,,,,,nebensache
        item,3.2-01,3.2,Deep Work,,Mo-Fr,fix,,,,,"arbeit,ko"
        item,2.1-02,2.1,Spaziergang,,täglich,fix,,,,,frei
        measure,protein,1.1,Protein,,,,g,>=150,tag,,nebensache
        """
        let doc = PlanCSV.parse(csv)
        #expect(doc.skipped.isEmpty, "\(doc.skipped)")
        #expect(doc.items.count == 3, "\(doc.warnings)")
        let side = doc.items.first { $0.code == "2.1-01" }
        let work = doc.items.first { $0.code == "3.2-01" }
        #expect(side?.secondary == true)
        #expect(work?.dayRule == .workOnly)
        #expect(work?.knockout == true)
        #expect(doc.items.first { $0.code == "2.1-02" }?.dayRule == .always)
        #expect(doc.measures.first?.secondary == true)
        let again = PlanCSV.parse(PlanCSV.export(doc))
        #expect(again.items.sorted { $0.code < $1.code } == doc.items.sorted { $0.code < $1.code })
        #expect(again.measures == doc.measures)
        #expect(work?.flags == "ko,arbeit")
    }
}
