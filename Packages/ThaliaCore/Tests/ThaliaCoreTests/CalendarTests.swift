import Foundation
import Testing
@testable import ThaliaCore

@Suite("Days and ISO weeks")
struct CalendarTests {
    @Test func knownWeekdays() {
        #expect(DayKey(year: 2026, month: 11, day: 1).weekday == .sunday)
        #expect(DayKey(year: 2026, month: 6, day: 1).weekday == .monday)
        #expect(DayKey(year: 1970, month: 1, day: 1).weekday == .thursday)
        #expect(DayKey(year: 2000, month: 2, day: 29).weekday == .tuesday)
    }

    @Test func parsesAndPrintsDays() {
        #expect(DayKey("2026-11-02")?.string == "2026-11-02")
        #expect(DayKey("02.11.2026") == DayKey(year: 2026, month: 11, day: 2))
        #expect(DayKey("2026-02-30") == nil)
        #expect(DayKey("Montag") == nil)
        #expect(DayKey(year: 2026, month: 11, day: 2).adding(days: 30).string == "2026-12-02")
        #expect(DayKey(year: 2026, month: 11, day: 2).longLabel == "Montag, 2. November 2026")
        #expect(DayKey(year: 2026, month: 11, day: 2).shortLabel == "Mo, 2. Nov.")
    }

    @Test func goalYearWeeks() {
        // 1 June 2026 is Monday of ISO week 23; the KW49 review runs 30 Nov – 6 Dec.
        #expect(DayKey(year: 2026, month: 6, day: 1).week == WeekKey(year: 2026, week: 23))
        let review = WeekKey(year: 2026, week: 49)
        #expect(review.monday == DayKey(year: 2026, month: 11, day: 30))
        #expect(review.sunday == DayKey(year: 2026, month: 12, day: 6))
        #expect(GoalPeriod.foundationYear.weekNumber(of: WeekKey(year: 2026, week: 23)) == 1)
        #expect(GoalPeriod.foundationYear.weekNumber(of: review) == 27)
    }

    @Test func week53AndYearBoundaries() {
        #expect(WeekKey.weeksIn(year: 2026) == 53)
        #expect(WeekKey.weeksIn(year: 2027) == 52)
        #expect(WeekKey(year: 2026, week: 53).monday == DayKey(year: 2026, month: 12, day: 28))
        #expect(DayKey(year: 2027, month: 1, day: 3).week == WeekKey(year: 2026, week: 53))
        #expect(DayKey(year: 2027, month: 1, day: 4).week == WeekKey(year: 2027, week: 1))
        #expect(DayKey(year: 2025, month: 12, day: 29).week == WeekKey(year: 2026, week: 1))
        #expect(WeekKey(year: 2026, week: 53).adding(weeks: 1) == WeekKey(year: 2027, week: 1))
        #expect(WeekKey(year: 2026, week: 53).rangeLabel == "28. Dez. – 3. Jan.")
        #expect(WeekKey("2027-W53") == nil)
    }

    @Test func parsesWeekSpellings() {
        let w45 = WeekKey(year: 2026, week: 45)
        for text in ["2026-W45", "2026-KW45", "KW45 2026", "KW 45/2026", "w45-2026"] {
            #expect(WeekKey(text) == w45, "\(text)")
        }
        #expect(w45.string == "2026-W45")
        #expect(w45.rangeLabel == "2.–8. Nov.")
        #expect(w45.days.count == 7)
        #expect(w45.contains(DayKey(year: 2026, month: 11, day: 8)))
        #expect(!w45.contains(DayKey(year: 2026, month: 11, day: 9)))
    }

    @Test func dayMasks() {
        #expect(DayMask.parse("") == .everyDay)
        #expect(DayMask.parse("täglich") == .everyDay)
        #expect(DayMask.parse("Mo-Fr") == .workdays)
        #expect(DayMask.parse("Mo - Fr") == .workdays)
        #expect(DayMask.parse("Mo bis Fr") == .workdays)
        #expect(DayMask.parse("werktags") == .workdays)
        #expect(DayMask.parse("Sa,So") == .weekend)
        #expect(DayMask.parse("Sa+So") == .weekend)
        #expect(DayMask.parse("Mo, Mi, Fr")?.days == [.monday, .wednesday, .friday])
        #expect(DayMask.parse("So-Do")?.days == [.monday, .tuesday, .wednesday, .thursday, .sunday])
        #expect(DayMask.parse("Mon-Fri") == .workdays)
        #expect(DayMask.parse("irgendwann") == nil)
        #expect(DayMask.workdays.label == "Mo–Fr")
        #expect(DayMask.parse("Mo,Mi,Fr")?.label == "Mo, Mi, Fr")
        #expect(DayMask.parse("Di-Do,Sa")?.csv == "Di-Do,Sa")
        #expect(DayMask.everyDay.csv == "täglich")
    }

    @Test func appleWeekdayNumbers() {
        #expect(Weekday.sunday.gregorianWeekday == 1)
        #expect(Weekday.monday.gregorianWeekday == 2)
        #expect(Weekday.saturday.gregorianWeekday == 7)
    }

    @Test func dayFromDateUsesTheTimeZone() throws {
        // 2026-11-01 23:30 UTC is already 2 November in Vienna.
        let date = Date(timeIntervalSince1970: 1_793_575_800)
        let vienna = try #require(TimeZone(identifier: "Europe/Vienna"))
        let utc = try #require(TimeZone(identifier: "UTC"))
        #expect(DayKey(date: date, timeZone: utc).string == "2026-11-01")
        #expect(DayKey(date: date, timeZone: vienna).string == "2026-11-02")
    }
}

@Suite("Vocabulary and formatting")
struct VocabularyTests {
    @Test func marksFollowTheSheet() {
        #expect(Mark.parse("✓") == .done)
        #expect(Mark.parse("1") == .done)
        #expect(Mark.parse("X") == .missed)
        #expect(Mark.parse("0") == .missed)
        #expect(Mark.parse("0,5") == .partial)
        #expect(Mark.parse("½") == .partial)
        #expect(Mark.parse("N/A") == .notApplicable)
        #expect(Mark.parse("") == nil)
        #expect(Mark.isBlank(" "))
        #expect(Mark.notApplicable.points == nil)
        #expect(Mark.cycle(nil) == .done)
        #expect(Mark.cycle(.notApplicable) == nil)
    }

    @Test func schedules() {
        #expect(ItemSchedule(raw: "fix") == .fixed)
        #expect(ItemSchedule(raw: "") == .fixed)
        #expect(ItemSchedule(raw: "woche:3") == .weekly(3))
        #expect(ItemSchedule(raw: "3x/Woche") == .weekly(3))
        #expect(ItemSchedule(raw: "2× pro Woche") == .weekly(2))
        #expect(ItemSchedule(raw: "bedingt") == .conditional)
        #expect(ItemSchedule(raw: "wenn Stress") == .conditional)
        #expect(ItemSchedule(raw: "optional") == .optional)
        #expect(ItemSchedule(raw: "fortschritt") == .progress)
        #expect(ItemSchedule.progress.raw == "fortschritt")
        #expect(!ItemSchedule.optional.isScored)
        #expect(ItemSchedule.weekly(3).raw == "woche:3")
    }

    @Test func targets() throws {
        let protein = try #require(Target.parse(">=150"))
        #expect(protein.isMet(150))
        #expect(!protein.isMet(149))
        #expect(protein.label == "≥ 150")
        #expect(Target.parse("≤ 6")?.isMet(6) == true)
        #expect(Target.parse("<50")?.isMet(50) == false)
        #expect(Target.parse("min. 2,5")?.isMet(2.5) == true)
        #expect(Target.parse("mindestens 10")?.comparison == .atLeast)
        #expect(Target.parse("max 6")?.comparison == .atMost)
        let range = try #require(Target.parse("150-180"))
        #expect(range.comparison == .range)
        #expect(range.isMet(165))
        #expect(!range.isMet(181))
        #expect(Target.parse("abc") == nil)
        #expect(Target.parse("")?.value == nil)
    }

    @Test func bedtimeAfterMidnightIsLate() throws {
        let bedtime = try #require(Target.parse("<=23:00"))
        #expect(bedtime.isTime)
        #expect(bedtime.isMet(22 * 60 + 45))
        #expect(!bedtime.isMet(23 * 60 + 15))
        #expect(!bedtime.isMet(30), "00:30 is later than 23:00")
        #expect(bedtime.raw == "<=23:00")
        let window = try #require(Target.parse("22:30-23:00"))
        #expect(window.isMet(22 * 60 + 40))
        #expect(!window.isMet(23 * 60 + 20))
    }

    @Test func germanNumbers() {
        #expect(Format.number(150) == "150")
        #expect(Format.number(2.5) == "2,5")
        #expect(Format.number(2.25) == "2,25")
        #expect(Format.number(8000) == "8.000")
        #expect(Format.number(-1.5) == "-1,5")
        #expect(Format.number(0.999, decimals: 1) == "1")
        #expect(Format.score(7.25) == "7,25")
        #expect(Format.score(7.256) == "7,26")
        #expect(Format.score(8.5) == "8,5")
        #expect(Format.score(10) == "10")
        #expect(Format.score(nil, outOf: true) == "–")
        #expect(Format.plain(2.5) == "2.5")
        #expect(Format.plain(150) == "150")
        #expect(Format.clock(1380) == "23:00")
        #expect(Format.clock(1470) == "00:30")
        #expect(Format.duration(minutes: 80) == "1 h 20 min")
        #expect(Format.hours(minutes: 1560) == "26 h")
        #expect(Format.powerHours(12) == "12 PH")
        #expect(Format.powerHours(0.25) == "0,25 PH")
        #expect(Format.measure(2.5, unit: "l") == "2,5 l")
        #expect(Format.measure(23 * 60 + 10, unit: "Uhrzeit") == "23:10")
        #expect(Format.parse("2,5") == 2.5)
        #expect(Format.parse("1.200") == 1200)
        #expect(Format.parse("1.5") == 1.5)
        #expect(Format.parse("23:10") == 1390)
    }

    @Test func sources() {
        #expect(MeasureSource(raw: "arbeit:3.2") == .work(category: "3.2"))
        #expect(MeasureSource(raw: "health:sleep") == .health(.sleep))
        #expect(MeasureSource(raw: "health:Schlaf") == .health(.sleep))
        #expect(MeasureSource(raw: "") == .manual)
        #expect(MeasureSource.work(category: "3.4").raw == "arbeit:3.4")
        #expect(Aggregation.default(forUnit: "kg") == .last)
        #expect(Aggregation.default(forUnit: "g") == .sum)
        #expect(Aggregation.default(forUnit: "Uhrzeit") == .last)
    }

    @Test func dayTypes() {
        #expect(DayTypes.isWorkFree("Frei"))
        #expect(DayTypes.isWorkFree("Geburtstag – frei"))
        #expect(!DayTypes.isWorkFree("Arbeitstag"))
        #expect(DayTypes.symbol(for: "Reisetag") == "airplane")
    }
}
