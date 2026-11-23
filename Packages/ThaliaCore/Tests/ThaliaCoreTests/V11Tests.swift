import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

// TASKS-v11 §3.1 (C1–C18): numbers, times around midnight, target words, power-hours in minutes, keys, units
// and rounding, calendar, missed weekly quotas, results, reports, pace, reminders, records, Health sharing
// (TestFlight), Finn, tour 11, the snapshot and the sync line, device builds. Neutral labels and values only.

/// Week 47 of 2026 (Monday 16 – Sunday 22 Nov.).
enum V11 {
    static let week = WeekKey(year: 2026, week: 47)
    static func day(_ month: Int, _ day: Int, _ year: Int = 2026) -> DayKey { DayKey(year: year, month: month, day: day) }
    static var vienna: TimeZone { TimeZone(identifier: "Europe/Vienna") ?? .current }
}

/// "23:30" → minutes since midnight.
private func hm(_ text: String) -> Double { Format.parse(text, isTime: true) ?? -1 }

/// C1: huge or broken numbers never trap (P1.1).
@Suite("v11 C1 numbers")
struct V11NumberTests {
    @Test func hugeNumbersShowADash() {
        #expect(Format.number(1e19) == "–" && Format.number(.infinity) == "–" && Format.number(.nan) == "–")
        #expect(Format.euro(1e17) == "– €" && Format.euro(-.infinity) == "– €")
        #expect(Format.clock(.infinity) == "–" && Format.clock(1e300) == "–")
        #expect(Format.duration(minutes: Int.max) == "–")
        var huge = WorkTotals()
        huge.powerHours = 1e18
        #expect(huge.netText == "–" && huge.shortText == "– PH")
        // Normal values as before.
        #expect(Format.number(8000) == "8.000" && Format.euro(1234.5) == "1.234,50 €" && Format.clock(1470) == "00:30")
        #expect(Format.duration(minutes: 80) == "1 h 20 min")
    }

    @Test func parseIsStrict() {
        for text in ["nan", "inf", "-inf", "infinity", "1e5", "0x10", "12345678901234567890", "1000000000000", "abc", "2,5 kg", ""] {
            #expect(Format.parse(text) == nil, "\(text)")
        }
        #expect(Format.parse("2,5") == 2.5 && Format.parse("1.200") == 1200 && Format.parse("1.5") == 1.5 && Format.parse(" 7 ") == 7)
        #expect(Format.parse("-3,25") == -3.25 && Format.parse("+4") == 4 && Format.parse("1.234,5") == 1234.5)
        #expect(Format.parse("999999999999") == 999_999_999_999 && Format.parse("23:10") == 1390)
    }

    @Test func exchangeNumbersAreBounded() throws {
        let json = #"{"v":"nan","source":"nina","day":"2026-11-22","generatedAt":"2026-11-22T10:00:00Z","facts":[{"id":"k1","kind":"value","metric":"kcal","value":"1e999","origin":"app"},{"id":"k2","kind":"value","metric":"kcal","value":"1e13","origin":"app"},{"id":"k3","kind":"value","metric":"kcal","value":"650","origin":"app"}]}"#
        guard case .success(let read) = ExchangeReader.dayFile(Data(json.utf8)) else {
            Issue.record("the file must be read")
            return
        }
        #expect(read.file.v == BinisoftExchange.version, "an unreadable version counts as this file's")
        #expect(read.file.facts.map(\.value) == [nil, nil, 650], "facts without a value")
        guard case .success(let big) = ExchangeReader.dayFile(Data(#"{"v":1e300,"source":"nina","day":"2026-11-22","facts":[]}"#.utf8)) else {
            Issue.record("a huge version must not trap")
            return
        }
        #expect(big.file.v == BinisoftExchange.version)
        // The inbox's value of a readable file is never "{}"; a fact that can't be encoded is left out.
        var broken = read.file
        broken.facts.append(ExchangeFact(id: "inf", kind: "value", value: .infinity, metric: "kcal"))
        guard let text = ExchangeInbox.value(broken) else {
            Issue.record("a value")
            return
        }
        #expect(text != "{}" && ExchangeInbox.file(text)?.facts.map(\.id) == ["k1", "k2", "k3"])
        guard let plain = ExchangeInbox.value(read.file) else {
            Issue.record("a value")
            return
        }
        #expect(ExchangeInbox.file(plain) == read.file)
        // The 1.9.0 form (a text) stays for its callers.
        let legacy: String = ExchangeInbox.value(read.file)
        #expect(legacy == plain)
    }
}

/// C2: times around midnight (P1.2).
@Suite("v11 C2 times around midnight")
struct V11NightTests {
    func target(_ raw: String) throws -> Target { try #require(Target.parse(raw)) }

    @Test func nightTargets() throws {
        let midnight = try target("<=00:00")
        #expect(midnight.isNight && midnight.isMet(hm("23:30")) && !midnight.isMet(hm("00:15")))
        let half = try target("<=00:30")
        #expect(half.isMet(hm("23:30")) && half.isMet(hm("00:15")) && half.isMet(hm("00:30")) && !half.isMet(hm("00:45")))
        let window = try target("23:00–00:30")
        #expect(window.isNight && window.isMet(hm("23:30")) && window.isMet(hm("00:15")) && !window.isMet(hm("12:00")) && !window.isMet(hm("22:45")))
        #expect(window.label == "23:00–00:30" && window.raw == "00:30-23:00", "stored as before, shown in its order")
        #expect(try target("00:30-23:00") == window, "stored the other way round: the same evening window")
        let typo = try target("23:00-22:30")
        #expect(typo.isMet(hm("22:45")) && !typo.isMet(hm("23:15")) && typo.label == "22:30–23:00")
        // "<=24:00" goes back to the CSV as "<=00:00" – now both mean the same.
        let full = try target("<=24:00")
        #expect(full.raw == "<=00:00" && full.isMet(hm("23:30")) == midnight.isMet(hm("23:30")) && !full.isMet(hm("00:15")))
        #expect(Target.nightMinutes(30) == 1470 && Target.nightMinutes(1380) == 1380)
    }

    @Test func dayWindowsAndOthersAsBefore() throws {
        let day = try target("10:00–18:00")
        #expect(!day.isNight && day.isMet(hm("12:00")) && day.isMet(hm("17:00")) && !day.isMet(hm("09:00")) && !day.isMet(hm("19:00")))
        let noon = try target("11:30–13:00")
        #expect(!noon.isNight && noon.isMet(hm("12:00")))
        let eleven = try target("<=23:00")
        #expect(eleven.isMet(hm("22:30")) && !eleven.isMet(hm("23:30")) && !eleven.isMet(hm("00:30")))
        let late = try target("22:30-23:00")
        #expect(late.isNight && late.isMet(hm("22:45")) && !late.isMet(hm("00:15")) && !late.isMet(hm("21:00")))
        let morning = try target("<=06:30")
        #expect(!morning.isNight && morning.isMet(hm("06:00")) && !morning.isMet(hm("07:00")) && !morning.isMet(hm("23:00")))
        let plain = try target(">=150")
        #expect(!plain.isNight && plain.isMet(150))
    }

    @Test func weekAverageAroundMidnight() {
        let week = V11.week
        let bed = MeasureRecord(week: week, code: "bett", title: "Bettzeit", unit: "Uhrzeit", target: Target.parse("<=00:30"))
        let entries = [EntryRecord(code: "bett", day: week.monday, value: hm("23:30")), EntryRecord(code: "bett", day: week.day(.tuesday), value: hm("00:30"))]
        #expect(Measures.weekValue(bed, days: week.days, entries: entries).map(Format.clock) == "00:00")
        let plain = MeasureRecord(week: week, code: "bett", title: "Bettzeit", unit: "Uhrzeit")
        #expect(Measures.weekValue(plain, days: week.days, entries: entries).map(Format.clock) == "00:00", "without a target: 23:00 as before")
        let window = MeasureRecord(week: week, code: "bett", title: "Bettzeit", unit: "Uhrzeit", target: Target.parse("23:00-00:30"))
        #expect(Measures.weekValue(window, days: week.days, entries: entries).map(Format.clock) == "00:00", "1.9.0 averaged this to 12:00")
        let wake = MeasureRecord(week: week, code: "auf", title: "Aufstehen", unit: "Uhrzeit", target: Target.parse("<=06:30"))
        let mornings = [EntryRecord(code: "auf", day: week.monday, value: hm("06:00")), EntryRecord(code: "auf", day: week.day(.tuesday), value: hm("07:00"))]
        #expect(Measures.weekValue(wake, days: week.days, entries: mornings) == hm("06:30"))
    }
}

/// C3: words in front of a target, strict and loose (P1.3).
@Suite("v11 C3 target words")
struct V11TargetWordTests {
    @Test func wordsMeanTheirComparison() {
        #expect(Target.parse("spätestens 23:00") == Target(.atMost, 1380, isTime: true))
        #expect(Target.parse("bis 23:00") == Target(.atMost, 1380, isTime: true))
        #expect(Target.parse("bis zu 5") == Target(.atMost, 5) && Target.parse("nicht mehr als 3") == Target(.atMost, 3))
        #expect(Target.parse("weniger als 6") == Target(.below, 6) && Target.parse("unter 50") == Target(.below, 50))
        #expect(Target.parse("mehr als 3") == Target(.above, 3) && Target.parse("über 8") == Target(.above, 8))
        #expect(Target.parse("frühestens 6:30") == Target(.atLeast, 390, isTime: true) && Target.parse("ab 8") == Target(.atLeast, 8))
        #expect(Target.parse("höchstens 6 Stück") == Target(.atMost, 6) && Target.parse("maximal 6") == Target(.atMost, 6))
        #expect(Target.parse("max. 6") == Target(.atMost, 6) && Target.parse("max6") == Target(.atMost, 6) && Target.parse("min 100") == Target(.atLeast, 100))
        #expect(Target.parse("mindestens 150") == Target(.atLeast, 150) && Target.parse("mind. 150") == Target(.atLeast, 150))
        #expect(Target.parse("22:30 bis 23:00") == Target(.range, 1350, upper: 1380, isTime: true))
        #expect(Target.parse("≥150 g") == Target(.atLeast, 150) && Target.parse("<=6") == Target(.atMost, 6))
        #expect(Target.parse("") == nil && Target.parse("bis") == nil)
    }

    @Test func strictForEditorsLooseForStored() {
        #expect(Target.parse("ca 150", strict: true) == nil && Target.parse("etwa 10", strict: true) == nil)
        #expect(Target.parse("abends 22:00", strict: true) == nil, "„ab“ only as a whole word")
        #expect(Target.parse("≥150 g", strict: true) == Target(.atLeast, 150))
        #expect(Target.parse("150-180", strict: true) == Target(.range, 150, upper: 180))
        #expect(Target.parse("spätestens 23:00", strict: true) == Target(.atMost, 1380, isTime: true))
        // Stored targets read loosely: the number counts as in 1.9.0.
        #expect(Target.parse("ca 150") == Target(.atLeast, 150) && Target.parse("abends 22:00") == Target(.atLeast, 1320, isTime: true))
    }
}

/// C4: power-hours in minutes (P1.4).
@Suite("v11 C4 power-hours in minutes")
struct V11PowerHourMinuteTests {
    @Test func minutesBecomePowerHours() throws {
        let categories = [CategoryRecord(key: "3.2", goalKey: "3", title: "Kunden")]
        let fact = ExchangeFact(id: "ph-1", kind: "ph", ref: "grp-1", refTitle: "Kunden", value: 55, unit: "min",
                                thalia: ExchangeThaliaHint(category: "3.2"))
        #expect(abs((fact.powerHoursValue ?? 0) - 1.1) < 1e-9)
        #expect(ExchangeFact(id: "ph-2", kind: "ph", value: 1.5, unit: "PH").powerHoursValue == 1.5)
        #expect(ExchangeFact(id: "ph-3", kind: "ph").powerHoursValue == nil)
        let file = ExchangeDayFile(source: "theo", day: "2026-11-18", generatedAt: "2026-11-18T18:00:00Z", facts: [fact])
        let arrivals = ExchangeOverview.arrivals(inbox: [file], categories: categories, today: V11.day(11, 22))
        #expect(arrivals.first?.detail == "55 min = 1,1 PH → 3.2")
        let effect = ExchangeDerivation.week(V11.week, inbox: [file], items: [], measures: [], categories: categories)
        #expect(effect.work.count == 1 && abs((effect.work.first?.powerHours ?? 0) - 1.1) < 1e-9)
        let measure = MeasureRecord(week: V11.week, code: "ph", categoryKey: "3.2", title: "PH aus Theo", unit: "PH",
                                    period: .week, source: MeasureSource(raw: "app:theo:ph"))
        let week = ExchangeDerivation.week(V11.week, inbox: [file], items: [], measures: [measure], categories: categories)
        let value = try #require(Measures.weekValue(measure, days: V11.week.days, entries: week.entries))
        #expect(Format.measure(value, unit: "PH") == "1,1 PH")
    }
}

/// C5: day and week keys without `String(format:)` – the same text as before (P1.5).
@Suite("v11 C5 keys")
struct V11KeyTests {
    @Test func keysAsBefore() {
        var mismatches: [String] = []
        var day = DayKey(year: 1999, month: 1, day: 1)
        let end = DayKey(year: 2100, month: 12, day: 31)
        while day <= end {
            let c = day.components
            let old = String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
            if day.string != old { mismatches.append(old) }
            day = day.adding(days: 3)
        }
        for week in 1...WeekKey.weeksIn(year: 2026) {
            let key = WeekKey(year: 2026, week: week)
            if key.string != String(format: "%04d-W%02d", 2026, week) { mismatches.append(key.string) }
        }
        for minutes in stride(from: -60, through: 1500, by: 7) {
            let total = ((minutes % 1440) + 1440) % 1440
            if Format.clock(Double(minutes)) != String(format: "%02d:%02d", total / 60, total % 60) { mismatches.append("\(minutes)") }
        }
        #expect(mismatches.isEmpty, "\(mismatches.prefix(5))")
        #expect(WeekKey.weeksIn(year: 2026) == 53 && WeekKey(year: 2026, week: 53).string == "2026-W53")
        #expect(Format.pad(5, 4) == "0005" && Format.pad(-5, 4) == String(format: "%04d", -5) && Format.pad(12345, 2) == "12345")
    }
}

/// C6: units, rounding of shown targets, dative and singular (P1.6, P1.7, P1.14).
@Suite("v11 C6 units and rounding")
struct V11UnitTests {
    @Test func decimalsPerUnit() {
        #expect(Format.measure(0.25, unit: "PH") == "0,25 PH" && Format.measure(12.75, unit: "PH") == "12,75 PH" && Format.measure(6.4, unit: "PH") == "6,4 PH")
        #expect(Format.measure(2.25, unit: "l") == "2,25 l" && Format.measure(72.46, unit: "kg") == "72,5 kg" && Format.measure(7.5, unit: "h") == "7,5 h")
        #expect(Format.measure(150.4, unit: "g") == "150 g" && Format.measure(12.6, unit: "Seiten") == "13 Seiten" && Format.measure(3, unit: "Stück") == "3 Stk.")
        #expect(Format.measure(12.5, unit: "€") == "12,50 €" && Format.measure(1390, unit: "Uhrzeit") == "23:10" && Format.measure(2.5, unit: "") == "2,5")
        #expect(Units.decimals("PH") == 2 && Units.decimals("Liter") == 2 && Units.decimals("kg") == 1 && Units.decimals("Stunden") == 1)
        #expect(Units.decimals("Stk.") == 0 && Units.decimals("Schritte") == 0 && Units.decimals("kcal") == 0 && Units.decimals("ml") == 0)
        #expect(Units.decimals("min") == 0 && Units.decimals("%") == 1)
    }

    @Test func targetsRoundedTowardsTheComparison() {
        let share = 6.0 / 7
        let items = Measures.effectiveTarget(Target(.atLeast, 100), share: share)
        #expect(Format.amount(target: items, unit: "Stk.") == "86")
        #expect(Format.amount(target: Measures.effectiveTarget(Target(.above, 100), share: share), unit: "Stk.") == "> 85")
        #expect(Format.amount(target: Measures.effectiveTarget(Target(.range, 150, upper: 180), share: share), unit: "g") == "129–154")
        #expect(Format.amount(target: Measures.effectiveTarget(Target(.atLeast, 120), share: share), unit: "min") == "103")
        #expect(Format.amount(target: Measures.effectiveTarget(Target(.atLeast, 8), share: share), unit: "PH") == "6,86")
        #expect(Format.amount(target: Target(.atLeast, 8 * 0.75), unit: "Stk.") == "6", "no hair above a whole number")
        #expect(Format.amount(target: Target(.equal, 2.5), unit: "Stk.") == "= 3")
        #expect(Format.amount(target: Target(.atMost, 6), unit: "Stk.") == "≤ 6" && Format.amount(target: Target(.below, 50), unit: "€") == "< 50")
        #expect(Format.amount(target: Target(.atMost, 1380, isTime: true), unit: "Uhrzeit") == "≤ 23:00")
        #expect(Format.amount(12.5, unit: "€") == "12,50" && Format.amount(150.4, unit: "g") == "150" && Format.amount(0.25, unit: "PH") == "0,25")
        // "erreicht" still from the exact target: a shown whole number is reached exactly when the exact one is.
        #expect(!items.isMet(85) && items.isMet(86))
        let above = Measures.effectiveTarget(Target(.above, 100), share: share)
        #expect(!above.isMet(85) && above.isMet(86))
    }

    /// The demo week scored the way WeekContext does (own marks and entries, the reading list, the demo app's inbox).
    private static func demoScore(_ content: Demo.Content, week: WeekKey, today: DayKey) -> WeekScore {
        let doc = content.document
        let records = content.records
        let items = doc.items.filter { $0.week == week }
        let measures = doc.measures.filter { $0.week == week }
        let types = Dictionary(doc.days.map { ($0.day, $0.dayType) }, uniquingKeysWith: { _, last in last })
        let excused = DayTypes.excusedDays(week.days) { types[$0] ?? "" }
        let free = Set(week.days.filter { DayTypes.isWorkFree(types[$0] ?? "") })
        let dayStrings = Set(week.days.map(\.string))
        let extras = WeekExtras.compute(WeekExtras.Input(
            week: week, items: items, measures: measures, categories: doc.categories, ownMarks: doc.marks.filter { $0.week == week },
            ownEntries: doc.entries.filter { week.contains($0.day) }, ownWork: doc.work.filter { week.contains($0.day) },
            excusedDays: excused, workFreeDays: free, inbox: records.inbox.filter { dayStrings.contains($0.day) },
            listItems: records.items, listProgress: records.progress))
        let workCategories = WeekData.workCategories(items: items, categories: doc.categories)
        var progress: [String: Double] = [:]
        var worked: [String: Set<DayKey>] = [:]
        for item in items where item.schedule == .progress {
            progress[item.code] = Measures.progressRatio(for: item, measures: extras.measures, days: week.days, entries: extras.entries,
                                                         work: extras.work, excused: excused, workFree: free, workCategories: workCategories)
            worked[item.code] = Measures.workedDays(for: item, measures: extras.measures, days: week.days, entries: extras.entries,
                                                    work: extras.work)
        }
        return Scorer.score(WeekData(week: week, goals: doc.goals, categories: doc.categories, items: items, marks: extras.marks,
                                     isComplete: Scorer.isComplete(week: week, today: today, closed: content.closedWeeks.contains(week)),
                                     progress: progress, worked: worked, workFreeDays: free, excusedDays: excused))
    }

    /// P1.7 "Note der Demo-Woche unverändert": rounding is display only. The demo's running and closed weeks keep
    /// the notes 1.9.0 computes for them (taken from 1.9.0 with the same steps), and the weekly targets of the
    /// week with the sick Friday show no hundredths for whole units.
    @Test func demoWeekNotesAsBefore() {
        let expected: [(DayKey, WeekKey, Double)] = [
            (V11.day(11, 22), WeekKey(year: 2026, week: 47), 8.327986111111),
            (V11.day(11, 22), WeekKey(year: 2026, week: 46), 7.635892857143),
            (V11.day(11, 26), WeekKey(year: 2026, week: 48), 7.908680555556),
            (V11.day(11, 26), WeekKey(year: 2026, week: 47), 7.826785714286),
            (V11.day(12, 31), WeekKey(year: 2026, week: 53), 8.271990740741),
            (V11.day(12, 31), WeekKey(year: 2026, week: 52), 7.283571428571),
        ]
        for (today, week, note) in expected {
            let overall = Self.demoScore(Demo.content(today: today), week: week, today: today).overall ?? -1
            #expect(abs(overall - note) < 1e-9, "\(week.string) on \(today.string): \(overall)")
        }

        let today = V11.day(11, 22)
        let doc = Demo.content(today: today).document
        let types = Dictionary(doc.days.map { ($0.day, $0.dayType) }, uniquingKeysWith: { _, last in last })
        let excused = DayTypes.excusedDays(today.week.days) { types[$0] ?? "" }
        #expect(!excused.isEmpty, "the demo's sick Friday scales the weekly targets")
        let workCategories = WeekData.workCategories(items: doc.items.filter { $0.week == today.week }, categories: doc.categories)
        var shown: [String] = []
        for measure in doc.measures where measure.week == today.week && measure.period == .week && Units.decimals(measure.unit) == 0 {
            guard let target = Measures.effectiveTarget(for: measure, week: today.week, excused: excused, workCategories: workCategories),
                  !target.isTime else { continue }
            shown.append(Format.amount(target: target, unit: measure.unit))
        }
        #expect(shown.contains("86") && shown.contains("103") && !shown.contains { $0.contains(",") }, "\(shown) – 100 Stk. and 120 min × 6/7")
    }

    @Test func dativeAndSingular() {
        #expect(Units.dative("Bücher") == "Büchern" && Units.dative("Kurse") == "Kursen" && Units.dative("Kapitel") == "Kapiteln")
        #expect(Units.dative("Liter") == "Litern" && Units.dative("Filme") == "Filmen")
        for same in ["Seiten", "Workouts", "Packungen", "PH", "km", "kg", "Stk.", "min", "€", "kcal", ""] {
            #expect(Units.dative(same) == same, "\(same)")
        }
        #expect(Units.singular("Bücher") == "Buch" && Units.singular("Seiten") == "Seite" && Units.singular("Schritte") == "Schritt")
        #expect(Units.singular("Packungen") == "Packung" && Units.singular("Workouts") == "Workout" && Units.singular("Äpfel") == "Äpfel")

        let segments = Segments.resolve([], period: .foundationYear)
        func text(_ result: GoalResult, _ count: Double) -> String {
            let entries = count > 0 ? [GoalEntry(id: "e", day: V11.day(11, 1), resultID: result.id, value: count)] : []
            return ResultProgress.compute(result, segments: segments, today: V11.day(11, 22), entries: entries).text
        }
        let books = GoalResult(id: "r", goalKey: "5", title: "Bücher", kind: .count, target: ">=10", unit: "Bücher")
        #expect(text(books, 1) == "1 von 10 Büchern" && text(books, 0) == "0 von 10 Büchern" && text(books, 10) == "10 von 10 Büchern")
        var untargeted = books
        untargeted.target = ""
        #expect(text(untargeted, 1) == "1 Buch" && text(untargeted, 0) == "0 Bücher" && text(untargeted, 10) == "10 Bücher")
    }
}

/// C7: calendar (P1.8, P4.16).
@Suite("v11 C7 calendar")
struct V11CalendarTests {
    @Test func rangeWithYear() {
        #expect(WeekKey(year: 2026, week: 53).rangeLabelWithYear == "28. Dez. 2026 – 3. Jan. 2027")
        #expect(WeekKey(year: 2027, week: 1).rangeLabelWithYear == "4.–10. Jan. 2027")
        #expect(WeekKey(year: 2026, week: 47).rangeLabelWithYear == "16.–22. Nov. 2026")
        #expect(WeekKey(year: 2026, week: 44).rangeLabelWithYear == "26. Okt. – 1. Nov. 2026")
        let review = PeriodReport(weeks: [], goalScores: [:], ideas: []).markdown(period: .foundationYear)
        #expect(review.hasPrefix("# Zielüberprüfung KW49 (30. Nov. – 6. Dez. 2026)\n"))
    }

    @Test func weekToClose() {
        let sunday = V11.day(11, 22)
        let monday = V11.day(11, 23)
        let previous = V11.week
        #expect(WeekKey.toClose(on: sunday, isClosed: { _ in false }, hasData: { _ in true }) == previous, "Sunday: this week")
        #expect(WeekKey.toClose(on: monday, isClosed: { _ in false }, hasData: { _ in true }) == previous, "Monday: the open week before")
        #expect(WeekKey.toClose(on: monday, isClosed: { $0 == previous }, hasData: { _ in true }) == monday.week, "closed already")
        #expect(WeekKey.toClose(on: monday, isClosed: { _ in false }, hasData: { $0 != previous }) == monday.week, "no plan the week before")
        #expect(WeekKey.toClose(on: V11.day(11, 27), isClosed: { _ in false }, hasData: { _ in true }) == previous, "Friday: still the week before")
    }
}

/// C8: a missed weekly quota counts even when its day has blanks (P1.9).
@Suite("v11 C8 missed weekly quota")
struct V11QuotaTests {
    let week = V11.week
    let goals = [GoalRecord(key: "1", title: "Ziel A")]
    let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Thema A")]

    var items: [ItemRecord] {
        [ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Täglich"),
         ItemRecord(week: week, code: "1.1-02", categoryKey: "1.1", position: 2, title: "Zweimal", schedule: .weekly(2))]
    }

    func data(sundayBlank: Bool = true, complete: Bool, excused: Set<DayKey> = []) -> WeekData {
        var marks: [String: Mark] = [:]
        for day in week.days where !(sundayBlank && day == week.sunday) { marks[WeekData.markKey("1.1-01", day)] = .done }
        return WeekData(week: week, goals: goals, categories: categories, items: items, marks: marks, isComplete: complete, excusedDays: excused)
    }

    @Test func shortfallCountsOnABlankLastDay() throws {
        let score = Scorer.score(data(complete: true))
        let sunday = score.category("1.1", on: week.sunday)
        #expect(sunday.blank == 1 && sunday.shortfall == 2 && sunday.score == 0)
        let overall = try #require(score.overall)
        #expect(abs(overall - 60.0 / 7) < 1e-9 && overall <= 9.05, "not 10: the missed quota counts")
        // Filled in on Sunday too: as before.
        #expect(abs((Scorer.score(data(sundayBlank: false, complete: true)).overall ?? 0) - (60 + 10.0 / 3) / 7) < 1e-9)
        // While the week runs nothing is booked; the blank Sunday has no score yet.
        let running = Scorer.score(data(complete: false))
        #expect(running.category("1.1", on: week.sunday).score == nil && running.overall == 10)
    }

    @Test func closedOnSundayWithGaps() {
        let complete = Scorer.isComplete(week: week, today: week.sunday, closed: true)
        #expect(complete)
        #expect(abs((Scorer.score(data(complete: complete)).overall ?? 0) - 60.0 / 7) < 1e-9, "the closed week holds the shortfall")
    }

    @Test func excusedShareStillCountsHalf() {
        let score = Scorer.score(data(complete: true, excused: [week.day(.friday)]))
        let sunday = score.category("1.1", on: week.sunday)
        let share = 2.0 / 7
        #expect(abs(sunday.excused - share) < 1e-9 && abs(sunday.earned - 0.5 * share) < 1e-9)
        #expect(abs((sunday.score ?? -1) - 10 * 0.5 * share / 2) < 1e-9, "booked with the blank: ½ for the excused share")
    }
}

/// C9: results – limits, the reading list, a book's start (P1.10–P1.12).
@Suite("v11 C9 results")
struct V11ResultTests {
    let single = Segments.resolve([], period: .foundationYear)

    func limit(_ target: String = "<=20") -> GoalResult {
        GoalResult(id: "lim", goalKey: "1", title: "Packungen", kind: .count, target: target, unit: "Packungen")
    }

    func progress(_ result: GoalResult, _ count: Double, segments: Segments? = nil, today: DayKey = V10.today,
                  day: DayKey = V10.day(11, 10)) -> ResultProgress {
        let entries = count > 0 ? [GoalEntry(id: "e", day: day, resultID: result.id, value: count)] : []
        return ResultProgress.compute(result, segments: segments ?? single, today: today, entries: entries)
    }

    @Test func limitsKeptExceededTooFast() {
        let zero = progress(limit(), 0)
        #expect(zero.isLimit && zero.status == .onTrack && zero.statusText == "im Rahmen", "never „erreicht“ before the end")
        let five = progress(limit(), 5)
        #expect(five.status == .onTrack && five.text == "5 von höchstens 20 Packungen" && five.fraction == 0.25)
        let over = progress(limit(), 25)
        #expect(over.status == .missed && over.statusText == "überschritten" && over.fraction == 1)
        let fast = progress(limit(), 15)
        #expect(fast.status == .behind && fast.statusText == "zu schnell", "15 > 20 × 175/365 × 1,15")
        let after = progress(limit(), 15, today: V10.day(6, 5, 2027))
        #expect(after.status == .reached && after.statusText == "eingehalten")
        #expect(progress(limit("<20"), 20).statusText == "überschritten" && progress(limit("<20"), 19, today: V10.day(6, 5, 2027)).statusText == "eingehalten")
        // In a segment with its own limit: paced in the segment.
        var segmented = limit()
        segmented.targets = [V10.secondID: "<=6"]
        #expect(progress(segmented, 0, segments: V10.segments).statusText == "im Rahmen")
        #expect(progress(segmented, 1, segments: V10.segments).statusText == "zu schnell", "1 > 6 × 21/211 × 1,15")
        #expect(progress(segmented, 3, segments: V10.segments, day: V10.day(10, 1)).statusText == "im Rahmen", "before the segment")
        // Words: "im Rückstand" for a count behind; a value with ≤ is no limit.
        #expect(ResultProgress.Status.behind.label == "im Rückstand" && ResultProgress.Status.behind.label(isLimit: true) == "zu schnell")
        #expect(ResultProgress.Status.onTrack.label(isLimit: false) == "auf Kurs" && ResultProgress.Status.open.limitLabel == "offen")
        let weight = GoalResult(id: "w", goalKey: "1", title: "Gewicht", kind: .value, target: "<=85", start: 89, unit: "kg")
        #expect(!ResultProgress.compute(weight, segments: single, today: V10.today, series: [V10.day(11, 1): 86]).isLimit)
        let books = GoalResult(id: "b", goalKey: "5", title: "Bücher", kind: .count, target: ">=10")
        #expect(progress(books, 3).statusText == "im Rückstand")
    }

    @Test func resultLineCarriesItsStatus() {
        let worth = GoalResult(id: "nw", goalKey: "8", title: "Vermögen", kind: .value, target: ">=60000", start: 40000, unit: "€",
                               source: "app:finn:net_worth")
        let up = ResultProgress.compute(worth, segments: single, today: V10.today, series: [V10.day(10, 31): 45000])
        let line = GoalResultLine(result: worth, goal: GoalRecord(key: "8", title: "Finanzen"), progress: up)
        #expect(line.statusKind == .behind && line.status == "im Rückstand")
        let hidden = GoalResultLine(result: worth, goal: nil, progress: up, hidesValue: true, hiddenText: "Wert aus Health auf dem iPhone")
        #expect(hidden.text == "Wert aus Health auf dem iPhone" && hidden.statusKind == .untargeted && hidden.status.isEmpty)
        #expect(GoalResultLine(result: worth, goal: nil, progress: up, hidesValue: true).text == "Wert nur auf dem Gerät")
    }

    @Test func booksCountFinishedOfTheKindAndAssigned() {
        let books = GoalResult(id: "books", goalKey: "5", title: "Bücher", kind: .count, target: ">=10", source: "list")
        let items = [ListItem(id: "b1", title: "Buch A", finishedOn: V10.day(10, 5)),
                     ListItem(id: "b2", title: "Buch B", finishedOn: V10.day(11, 5)),
                     ListItem(id: "h1", kind: "Hörbuch", title: "Hörbuch C", finishedOn: V10.day(11, 12), resultID: "books"),
                     ListItem(id: "h2", kind: "Hörbuch", title: "Hörbuch D", finishedOn: V10.day(11, 13)),
                     ListItem(id: "b3", title: "Buch E", finishedOn: V10.day(11, 14), resultID: "alt")]
        #expect(ResultProgress.compute(books, segments: single, today: V10.today, items: Array(items.prefix(3))).current == 3,
                "2 books + 1 audio book counting for it")
        #expect(ResultProgress.compute(books, segments: single, today: V10.today, items: items).current == 3,
                "D: no book; E counts for another result")
        #expect(ResultProgress.compute(books, segments: single, today: V10.today, items: items, resultIDs: ["books"]).current == 4,
                "„alt“ is deleted: E counts as a book")
        let assignedBook = [ListItem(id: "b9", title: "Buch F", finishedOn: V10.day(11, 2), resultID: "books")]
        #expect(ResultProgress.compute(books, segments: single, today: V10.today, items: assignedBook).current == 1, "each once")
    }

    @Test func startAtPage() throws {
        let book = ListItem(id: "b1", title: "Buch", total: 320, startAt: 120)
        func reading(_ id: String, _ day: Int, _ page: Double) -> ListProgress {
            ListProgress(id: id, day: V10.day(11, day), itemID: "b1", reached: page, modifiedAt: V10.day(11, day).startDate())
        }
        #expect(ListMath.status(book, progress: []) == .running)
        #expect(ListMath.progressText(book, progress: []) == "120 von 320 Seiten · 38 %")
        #expect(ListMath.current(book, progress: []) == 120 && ListMath.fraction(book, progress: []) == 0.375)
        #expect(ListMath.dailyAmounts(items: [book], progress: []).isEmpty, "the start isn't read")
        // The first reading counts from the start: below, equal, above.
        #expect(ListMath.dailyAmounts(items: [book], progress: [reading("p", 16, 100)]).isEmpty)
        #expect(ListMath.dailyAmounts(items: [book], progress: [reading("p", 16, 120)]).isEmpty)
        #expect(ListMath.dailyAmounts(items: [book], progress: [reading("p", 16, 150)]) == [V10.day(11, 16): 30])
        #expect(ListMath.dailyAmounts(itemID: "b1", progress: [reading("p", 16, 150)], startAt: 120) == [V10.day(11, 16): 30])
        #expect(ListMath.current(book, progress: [reading("p", 16, 100)]) == 120 && ListMath.current(book, progress: [reading("p", 16, 150)]) == 150)
        #expect(ListMath.current(book, progress: [reading("p", 16, 150)], through: V10.day(11, 15)) == 120)
        // "+ Seiten" without readings: from the start.
        let plus = ListMath.current(book, progress: []) + 20
        #expect(ListMath.dailyAmounts(items: [book], progress: [reading("p", 17, plus)]) == [V10.day(11, 17): 20])
        // Without a total; nothing set: as before.
        #expect(ListMath.progressText(ListItem(id: "b1", title: "Buch", startAt: 120), progress: []) == "120 Seiten")
        #expect(ListMath.progressText(ListItem(id: "b2", title: "Neu", total: 300), progress: []) == "300 Seiten")
        #expect(ListMath.progressText(ListItem(id: "b2", title: "Neu"), progress: []) == "noch nicht begonnen")
        #expect(ListMath.status(ListItem(id: "b2", title: "Neu"), progress: []) == .planned)
        #expect(ListMath.suggestsFinish(ListItem(id: "b3", title: "Fast", total: 300, startAt: 300), reached: 0))
        // A JSON field of its own; unknown fields stay; 0 means none.
        #expect(JSONText.object(book.settingValue)?["startAt"] == .number(120))
        let stored = #"{"id":"b5","title":"Buch","startAt":"80","farbe":"blau","modifiedAt":"2026-11-20T08:00:00Z"}"#
        let read = try #require(ListItem(settingValue: stored))
        #expect(read.startAt == 80 && read.unknown["farbe"] == .string("blau") && read.unknown["startAt"] == nil)
        #expect(JSONText.object(read.settingValue)?["farbe"] == .string("blau"))
        #expect(ListItem(id: "b4", title: "x", startAt: 0).startAt == nil)
    }
}

/// C10: reports – hidden measures, trend windows, closed days, texts (P1.7, P1.13, P1.14, P1.17, P6.2, P6.3).
@Suite("v11 C10 reports")
struct V11ReportTests {
    let week = V11.week

    @Test func reportScoresLikeTheWeek() throws {
        let goals = [GoalRecord(key: "3", title: "Arbeit"), GoalRecord(key: "5", title: "Lesen")]
        let categories = [CategoryRecord(key: "3.2", goalKey: "3", title: "Kunden"), CategoryRecord(key: "5", goalKey: "5", title: "Lesen")]
        let items = [
            ItemRecord(week: week, code: "3.2-01", categoryKey: "3.2", position: 1, title: "An Kunden gearbeitet", schedule: .progress,
                       target: Target.parse(">=4"), measure: "app:theo:ph", dayRule: .always),
            ItemRecord(week: week, code: "5-01", categoryKey: "5", position: 1, title: "Gelesen", schedule: .progress,
                       target: Target.parse(">=100"), measure: "list:buch", dayRule: .always),
            ItemRecord(week: week, code: "5-02", categoryKey: "5", position: 2, title: "Notiz", dayRule: .always),
        ]
        let marks = week.days.map { MarkRecord(week: week, itemCode: "5-02", day: $0, mark: .done) }
        let inbox = [ExchangeDayFile(source: "theo", day: "2026-11-17", generatedAt: "2026-11-17T18:00:00Z", facts: [
            ExchangeFact(id: "p1", kind: "ph", ref: "grp-1", refTitle: "Kunden", value: 2, unit: "PH"),
            ExchangeFact(id: "p2", kind: "ph", ref: "grp-1", refTitle: "Kunden", value: 50, unit: "min"),
        ])]
        let book = ListItem(id: "b1", title: "Buch")
        let readings = [ListProgress(id: "r1", day: week.day(.tuesday), itemID: "b1", reached: 40),
                        ListProgress(id: "r2", day: week.day(.thursday), itemID: "b1", reached: 70)]
        let extras = WeekExtras.compute(WeekExtras.Input(week: week, items: items, measures: [], categories: categories, ownMarks: marks,
                                                         inbox: inbox, listItems: [book], listProgress: readings))
        // As WeekContext scores the week.
        var progress: [String: Double] = [:]
        var worked: [String: Set<DayKey>] = [:]
        for item in items where item.schedule == .progress {
            progress[item.code] = Measures.progressRatio(for: item, measures: extras.measures, days: week.days, entries: extras.entries,
                                                         work: extras.work)
            worked[item.code] = Measures.workedDays(for: item, measures: extras.measures, days: week.days, entries: extras.entries,
                                                    work: extras.work)
        }
        let live = Scorer.score(WeekData(week: week, goals: goals, categories: categories, items: items, marks: extras.marks, isComplete: true,
                                         progress: progress, worked: worked))
        // As the report, the PDF and the review score it.
        let input = WeekReportInput(week: WeekRecord(week: week), goals: goals, categories: categories, items: items, measures: [],
                                    marks: marks + extras.effect.marks, entries: extras.entries, work: extras.work, isClosed: true,
                                    today: week.sunday)
        let reported = Scorer.score(input.weekData)
        #expect(progress["3.2-01"] == 0.75 && progress["5-01"] == 0.7)
        #expect(input.weekData.progress == progress, "the hidden measures of list:/app: links count in the report too")
        #expect(live.overall != nil && reported.overall == live.overall && reported.categoryWeek == live.categoryWeek)
        #expect(!WeekReport.markdown(input).contains("## Messwerte"), "but stay out of „Messwerte“")
    }

    @Test func trendWindowsWithoutOverlap() {
        func windows(_ n: Int) -> (first: Double?, last: Double?, window: Int) {
            PeriodReport.trendWindows((0..<n).map { Double($0 + 1) })
        }
        #expect(windows(2).window == 0 && windows(2).first == nil && windows(3).last == nil)
        #expect(windows(4).window == 2 && windows(4).first == 1.5 && windows(4).last == 3.5)
        #expect(windows(5).window == 2 && windows(5).first == 1.5 && windows(5).last == 4.5)
        #expect(windows(8).window == 4 && windows(8).first == 2.5 && windows(8).last == 6.5)
        #expect(windows(9).window == 4 && windows(9).first == 2.5 && windows(9).last == 7.5)

        let lines = (0..<5).map { WeekLine(week: week.adding(weeks: $0 - 5), score: 7, isClosed: true, goalScores: ["1": Double($0 + 1)]) }
        let goals = [GoalRecord(key: "1", title: "Ziel A")]
        let range = RangeReport(lines: lines, goals: goals, work: []).goals.first
        #expect(range?.window == 2 && range?.firstFour == 1.5 && range?.lastFour == 4.5 && range?.trend == 1)
        let short = RangeReport(lines: Array(lines.prefix(3)), goals: goals, work: []).goals.first
        #expect(short?.firstFour == nil && short?.trend == nil && short?.trendWord == "noch kein Trend" && short?.window == 0)

        func inputs(_ n: Int) -> [WeekReportInput] {
            (0..<n).map { offset in
                let shown = week.adding(weeks: offset - n)
                return WeekReportInput(week: WeekRecord(week: shown), goals: goals, categories: [], items: [], measures: [], marks: [],
                                       today: shown.sunday)
            }
        }
        var scores: [WeekKey: [String: Double]] = [:]
        for (offset, input) in inputs(4).enumerated() { scores[input.week.week] = ["1": Double(offset + 1)] }
        let review = PeriodReport(weeks: inputs(4), goalScores: scores, ideas: []).markdown(period: .foundationYear)
        #expect(review.contains("| Ziel | Ø seit Start | erste Wochen | letzte Wochen | Trend |"))
        #expect(review.contains("| 1 Ziel A | 2,5 | 1,5 (je 2) | 3,5 (je 2) | ↑ |"))
        #expect(review.contains("· Ø aus abgeschlossenen Wochen"))
        let two = PeriodReport(weeks: Array(inputs(4).suffix(2)), goalScores: scores, ideas: []).markdown(period: .foundationYear)
        #expect(two.contains("| 1 Ziel A | 3,5 | – | – | – |"))
    }

    @Test func closedDaysWithoutSickDays() {
        let goals = [GoalRecord(key: "1", title: "Ziel A")]
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Thema A")]
        let item = ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Täglich")
        let thursday = week.day(.thursday)
        let input = WeekReportInput(week: WeekRecord(week: week), goals: goals, categories: categories, items: [item], measures: [], marks: [],
                                    days: [DayRecord(day: thursday, dayType: "Krank")],
                                    closedDays: [week.monday, week.day(.tuesday), thursday], today: week.sunday)
        let line = WeekLine(input)
        #expect(line.closedDays == 2 && line.excusedDays == 1, "the closed sick Thursday doesn't count as a closed day")
    }

    @Test func reportTexts() {
        let goals = [GoalRecord(key: "1", title: "Ziel A"), GoalRecord(key: "2", title: "Ziel B")]
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Thema A"), CategoryRecord(key: "2.1", goalKey: "2", title: "Thema B")]
        let items = [ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Nur montags", days: DayMask([.monday])),
                     ItemRecord(week: week, code: "2.1-01", categoryKey: "2.1", title: "Täglich")]
        let marks = week.days.filter { $0 != week.day(.thursday) }.map { MarkRecord(week: week, itemCode: "2.1-01", day: $0, mark: .done) }
        let measure = MeasureRecord(week: week, code: "wdh", categoryKey: "2.1", title: "Wiederholungen", unit: "Stück",
                                    target: Target.parse(">=100"), period: .week)
        let input = WeekReportInput(week: WeekRecord(week: week), goals: goals, categories: categories, items: items, measures: [measure],
                                    marks: marks, days: [DayRecord(day: week.day(.thursday), dayType: "Krank")],
                                    entries: [EntryRecord(code: "wdh", day: week.monday, value: 50)], isClosed: true, today: week.sunday)
        let text = WeekReport.markdown(input)
        #expect(text.contains("· Jahresziele (gleich gewichtet) ·") && !text.contains("10 %"))
        #expect(text.contains("(Ziel ≥ 86 anteilig wegen Krank/Urlaub – nicht erreicht)"), "shown like on screen, not 85,71")
        #expect(text.contains("- Nicht ausgefüllt: 1 fälliger Punkt (weder Haken noch N/A)"))
    }

    @Test func promptsNameSetDaysAndTheNumberRule() {
        let template = Template.week(week)
        let days = [DayRecord(day: week.day(.friday), dayType: "Urlaub"), DayRecord(day: week.day(.saturday), dayType: "Reisetag", note: "Flug"),
                    DayRecord(day: week.adding(weeks: 1).monday, dayType: "Krank"), DayRecord(day: week.monday)]
        let text = PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures,
                                   lastWeekReport: nil, setDays: days)
        #expect(text.contains("Schon eingetragen für KW47: Fr 20.11. Urlaub, Sa 21.11. Reisetag („Flug“) – so übernehmen."))
        #expect(text.contains("ohne Tausenderpunkt (8000, nicht 8.000)"))
        let plain = PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures, lastWeekReport: nil)
        #expect(!plain.contains("Schon eingetragen") && plain.hasSuffix("## Mein Rückblick und Plan für KW47:\n"))
        let past = PastWeekPrompt.text(weeks: [week], items: [], categories: template.categories, goals: template.goals, measures: [])
        #expect(past.contains("ohne Tausenderpunkt (8000, nicht 8.000)"))
    }
}

/// C11: the pace of weekly targets (P1.16).
@Suite("v11 C11 pace")
struct V11PaceTests {
    let week = V11.week

    @Test func statusShortAndLong() {
        let saturday = week.day(.saturday)
        let sunday = week.sunday
        let onPlan = Pace(done: 7.2, target: 8, days: .everyDay, week: week, today: saturday)
        #expect(onPlan.plannedLeft == 1 && onPlan.status == .onPlan && onPlan.label(unit: "PH") == "7,2 von 8 PH – im Plan")
        let open = Pace(done: 12, target: 12.8, days: .everyDay, week: week, today: sunday)
        #expect(open.plannedLeft == 0 && !open.weekOver && open.status == .open && open.status.label == "noch offen")
        #expect(open.status.label(remaining: open.remaining, unit: "PH") == "noch 0,8 PH offen")
        #expect(open.label(unit: "PH") == "12 von 12,8 PH – noch offen")
        #expect(Pace(done: 7.5, target: 8, days: .workdays, week: week, today: week.day(.friday)).status == .open, "work days: Friday is the last")
        // Over or closed: not reached.
        let past = Pace(done: 12, target: 12.8, days: .everyDay, week: week, today: sunday.adding(days: 1))
        #expect(past.weekOver && past.status == .missed && past.label(unit: "PH") == "12 von 12,8 PH – nicht erreicht")
        #expect(Pace(done: 12, target: 12.8, days: .everyDay, week: week, today: saturday, weekOver: true).status == .missed)
        #expect(Pace(done: 8, target: 8, days: .everyDay, week: week, today: saturday, weekOver: true).status == .reached)
        #expect(Pace(done: 1, target: 8, days: .everyDay, week: week, today: week.day(.thursday)).status == .behind)
        // Limits keep their words; the amount only where it is open.
        #expect(PaceStatus.limit(isMet: true).label == "im Rahmen" && PaceStatus.limit(isMet: false).label == "überschritten")
        #expect(PaceStatus.behind.label(remaining: 3, unit: "PH") == "hinter dem Plan")
        #expect(PaceStatus.open.label(remaining: 12.5, unit: "€") == "noch 12,50 € offen")
        #expect(PaceStatus.open.label(remaining: 20, unit: "Seiten") == "noch 20 Seiten offen")
        // The measure's pace passes the week's end on.
        let measure = MeasureRecord(week: week, code: "ph", title: "PH", unit: "PH", target: Target.parse(">=8"), period: .week)
        #expect(Measures.weeklyPace(measure, done: 6, week: week, today: saturday, excused: [])?.status == .onPlan)
        #expect(Measures.weeklyPace(measure, done: 6, week: week, today: saturday, excused: [], weekOver: true)?.status == .missed)
    }

    @Test func reportSaysTheSame() {
        let goals = [GoalRecord(key: "1", title: "Ziel A")]
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Thema A")]
        let focus = MeasureRecord(week: week, code: "ph", categoryKey: "1.1", title: "Fokus", unit: "PH", target: Target.parse(">=8"), period: .week)
        let spending = MeasureRecord(week: week, code: "aus", categoryKey: "1.1", position: 1, title: "Ausgaben", unit: "€",
                                     target: Target.parse("<50"), period: .week)
        func report(_ done: Double, today: DayKey, closed: Bool = false) -> String {
            WeekReport.markdown(WeekReportInput(
                week: WeekRecord(week: week), goals: goals, categories: categories, items: [], measures: [focus, spending], marks: [],
                entries: [EntryRecord(code: "ph", day: week.monday, value: done), EntryRecord(code: "aus", day: week.monday, value: 60)],
                isClosed: closed, today: today))
        }
        #expect(report(7.2, today: week.day(.saturday)).contains("- Fokus: 7,2 PH in der Woche (Ziel ≥ 8 – im Plan)"))
        #expect(report(2, today: week.day(.thursday)).contains("(Ziel ≥ 8 – hinter dem Plan)"))
        #expect(report(7.5, today: week.sunday).contains("(Ziel ≥ 8 – noch offen)"))
        #expect(report(7.5, today: week.sunday, closed: true).contains("(Ziel ≥ 8 – nicht erreicht)"))
        #expect(report(7.5, today: week.sunday.adding(days: 1)).contains("(Ziel ≥ 8 – nicht erreicht)"))
        #expect(report(8, today: week.day(.tuesday)).contains("(Ziel ≥ 8 – erreicht)"))
        #expect(report(8, today: week.day(.tuesday)).contains("- Ausgaben: 60 € in der Woche (Ziel < 50 – überschritten)"))
    }
}

/// C12: reminders per day (P4.17).
@Suite("v11 C12 reminders")
struct V11ReminderTests {
    let monday = V11.week.monday

    @Test func morningsPerDay() {
        let settings = ReminderSettings()
        let mornings = settings.morningRequests(from: monday, isSkipped: { $0 == monday.adding(days: 2) })
        #expect(mornings.map(\.id) == ["thalia.morning.2026-11-16", "thalia.morning.2026-11-17", "thalia.morning.2026-11-19",
                                       "thalia.morning.2026-11-20"], "Mo–Fr, the sick Wednesday left out")
        #expect(mornings.allSatisfy { $0.hour == 8 && $0.minute == 15 && $0.destination == "today" && $0.title == "Guten Morgen" })
        var off = settings
        off.morning = false
        #expect(off.morningRequests(from: monday, isSkipped: { _ in false }).isEmpty)
        var everyDay = settings
        everyDay.morningDays = DayMask.everyDay.rawValue
        #expect(everyDay.morningRequests(from: monday, count: 10, isSkipped: { _ in false }).count == 10)
        #expect(ReminderSettings.morningID(monday) == "thalia.morning.2026-11-16")
    }

    @Test func weeklyPerWeek() {
        let settings = ReminderSettings()
        let w47 = V11.week
        let w48 = w47.adding(weeks: 1)
        let open = settings.weeklyRequests(from: monday, isClosed: { _ in false }, hasPlan: { _ in false })
        #expect(open.map(\.id) == ["thalia.weekly.2026-W47"] && open.first?.day == w47.sunday)
        #expect(open.first?.destination == "close-week:2026-W47" && open.first?.title == "Wochenabschluss" && open.first?.hour == 17)
        #expect(settings.weeklyRequests(from: monday, isClosed: { $0 == w47 }, hasPlan: { $0 == w48 }).isEmpty, "closed, next week planned")
        let plan = settings.weeklyRequests(from: monday, isClosed: { $0 == w47 }, hasPlan: { _ in false })
        #expect(plan.first?.title == "Nächste Woche planen" && plan.first?.destination == "import")
        #expect(plan.first?.body == "Planungs-Prompt kopieren und den Plan importieren.")
        var mondays = settings
        mondays.weeklyDay = Weekday.monday.rawValue
        let before = mondays.weeklyRequests(from: monday, count: 14, isClosed: { _ in false }, hasPlan: { _ in false })
        #expect(before.map(\.id) == ["thalia.weekly.2026-W46", "thalia.weekly.2026-W47"], "on Monday it's about the week before")
        var fridays = settings
        fridays.weeklyDay = Weekday.friday.rawValue
        #expect(fridays.weeklyRequests(from: monday, isClosed: { _ in false }, hasPlan: { _ in false }).first?.id == "thalia.weekly.2026-W47")
        var off = settings
        off.weekly = false
        #expect(off.weeklyRequests(from: monday, isClosed: { _ in false }, hasPlan: { _ in false }).isEmpty)
        #expect(settings.requests().isEmpty, "no repeating reminders")
        #expect(ReminderSettings.weeklyID(w47) == "thalia.weekly.2026-W47")
    }
}

/// C13: records – the newest copy per id, the new keys, requests, builds, backups (P2.1, P3.5, P3.13).
@Suite("v11 C13 records")
struct V11RecordTests {
    func stored<T: SettingRecord>(_ records: [T]) -> [StoredSetting] {
        records.map { StoredSetting(key: $0.settingKey, value: $0.settingValue) }
    }

    @Test func newestCopyPerID() {
        let old = GoalEntry(id: "e1", day: V10.day(11, 10), resultID: "r1", value: 3, modifiedAt: V10.date("2026-11-10T08:00:00Z"))
        var moved = old
        moved.day = V10.day(11, 12)
        moved.modifiedAt = V10.date("2026-11-12T08:00:00Z")
        #expect(SettingRecords.decode(GoalEntry.self, from: stored([old, moved])).map(\.day) == [V10.day(11, 12)],
                "the old key from a backup doesn't count twice")
        var tie = old
        tie.day = V10.day(11, 11)
        #expect(SettingRecords.decode(GoalEntry.self, from: stored([old, tie])).map(\.day) == [V10.day(11, 11)], "a tie: the greater key")
        let trashed = moved.trashed(now: V10.date("2026-11-13T08:00:00Z"))
        #expect(SettingRecords.decode(GoalEntry.self, from: stored([old, trashed])).isEmpty, "the newest copy is in the trash")
        #expect(SettingRecords.decode(GoalEntry.self, from: stored([old, trashed]), includeDeleted: true).map(\.day) == [V10.day(11, 12)])
        let reading = ListProgress(id: "p1", day: V10.day(11, 3), itemID: "b1", reached: 50, modifiedAt: V10.date("2026-11-03T08:00:00Z"))
        var later = reading
        later.day = V10.day(11, 4)
        later.modifiedAt = V10.date("2026-11-04T08:00:00Z")
        let other = ListProgress(id: "p2", day: V10.day(11, 3), itemID: "b1", reached: 20, modifiedAt: V10.date("2026-11-03T09:00:00Z"))
        let readings = SettingRecords.decode(ListProgress.self, from: stored([reading, later, other]))
        #expect(readings.map(\.id).sorted() == ["p1", "p2"] && readings.first { $0.id == "p1" }?.day == V10.day(11, 4))
        // Other records as before: one per key.
        let items = [ListItem(id: "b1", title: "A"), ListItem(id: "b2", title: "B")]
        #expect(SettingRecords.decode(ListItem.self, from: stored(items)).count == 2)
    }

    @Test func newKeysStayOutOfBackupsAndWeeks() {
        // HEALTHSHARE: the sharing's keys are no week's and never in `all`.
        let keys = [RescoreRequest.key(V11.week), SyncBuild.key(installID: "abc"), SettingKeys.backupLast, HealthShare.key(day: V10.today),
                    HealthShare.stateKey]
        for key in keys {
            #expect(!SettingKeys.isV10(key) && SettingKeys.week(of: key) == nil && SettingKeys.day(of: key) == nil, "\(key)")
        }
        #expect(SettingKeys.rescoreRequest == "rescore." && SettingKeys.buildPrefix == "sync.build." && SettingKeys.backupLast == "backup.last")
        #expect(SettingKeys.goalYearKeys == ["goal.start", "goal.end", "goal.review", "goal.motto"] && SettingKeys.catalogSwitch == "exchange.catalog")
        for prefix in [SettingKeys.rescoreRequest, SettingKeys.buildPrefix, SettingKeys.backupLast] {
            #expect(!SettingKeys.all.contains(prefix) && !SettingKeys.records.contains(prefix))
        }
        // 1.9.0 reads only `sync.seen.`: a build record is no device there.
        let build = SyncBuild(build: 58, version: "1.10.0")
        #expect(SyncDevice.parse(key: SyncBuild.key(installID: "abc"), value: build.value) == nil)
        #expect(!SyncBuild.key(installID: "abc").hasPrefix(SyncDevice.keyPrefix))
        #expect(SyncBuild.installID(settingKey: "sync.build.abc") == "abc" && SyncBuild.installID(settingKey: "sync.seen.abc") == nil)
    }

    @Test func requestsBuildsAndBackupStamps() throws {
        let at = V10.date("2026-11-22T18:04:05.123Z")
        let request = RescoreRequest(by: "mac-1", at: at, force: true)
        #expect(RescoreRequest(value: request.value) == request)
        #expect(request.value.hasPrefix(#"{"at":"2026-11-22T18:04:05.123Z","by":"mac-1","force":true,"v":1}"#))
        #expect(RescoreRequest.key(V11.week) == "rescore.2026-W47" && RescoreRequest.week(settingKey: "rescore.2026-W47") == V11.week)
        #expect(RescoreRequest.week(settingKey: "score.2026-W47") == nil)
        let loose = try #require(RescoreRequest(value: #"{"by":"x","force":"ja","extra":1}"#))
        #expect(loose.v == 1 && loose.force && loose.at == Date(timeIntervalSince1970: 0) && loose.isExpired(now: at))
        #expect(RescoreRequest(value: "kein JSON") == nil && RescoreRequest(value: "[1]") == nil)
        #expect(!request.isExpired(now: at.addingTimeInterval(9 * 60)) && request.isExpired(now: at.addingTimeInterval(11 * 60)))
        let merged = RescoreRequest.merged([RescoreRequest(by: "a", at: at), RescoreRequest(by: "b", at: at.addingTimeInterval(-60), force: true)])
        #expect(merged == RescoreRequest(by: "a", at: at, force: true) && RescoreRequest.merged([]) == nil)

        let build = SyncBuild(build: 58, version: "1.10.0")
        #expect(build.value == #"{"build":58,"v":1,"version":"1.10.0"}"#)
        #expect(SyncBuild(value: build.value) == build && SyncBuild(value: #"{"build":"57"}"#)?.build == 57)

        let stamp = BackupStamp(at: at, device: "iPhone")
        #expect(BackupStamp(value: stamp.value) == stamp && stamp.value.contains(#""device":"iPhone""#))
        #expect(BackupStamp.latest([stamp.value, BackupStamp(at: at.addingTimeInterval(-86400), device: "Mac").value, "kaputt"]) == stamp)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = V11.vienna
        #expect(stamp.days(until: at.addingTimeInterval(3 * 86400), calendar: calendar) == 3 && stamp.days(until: at, calendar: calendar) == 0)
    }
}

/// C14: sharing Health values with Mac and watch – TestFlight only (P9.1, §1.4).
// HEALTHSHARE: the whole suite goes with the sharing, except the key and clean-up checks.
@Suite("v11 C14 Health sharing")
struct V11HealthShareTests {
    let today = V10.today
    let now = V10.date("2026-11-22T08:00:00Z")

    // HEALTHSHARE
    @Test func windowAndKeys() {
        // HEALTHSHARE
        #expect(HealthShare.window == 35 && HealthShare.readDays == 3 && HealthShare.prefix == "hshare." && HealthShare.stateKey == "hshare.state")
        // HEALTHSHARE
        #expect(HealthShare.key(day: today) == "hshare.2026-11-22" && HealthShare.keys(week: V11.week).count == 7)
        // HEALTHSHARE
        #expect(HealthShare.day(settingKey: "hshare.2026-11-22") == today && HealthShare.day(settingKey: HealthShare.stateKey) == nil)
        // HEALTHSHARE
        #expect(HealthShare.isKey(HealthShare.stateKey) && !HealthShare.isKey("health.share"))
        // HEALTHSHARE
        let window = HealthShare.windowDays(today: today)
        #expect(window.count == 35 && window.first == today.adding(days: -34) && window.last == today)
        // HEALTHSHARE
        #expect(HealthShare.readWindow(today: today) == [today.adding(days: -2), today.adding(days: -1), today])
        // HEALTHSHARE: older than the window (more than 34 days before today) – only day records.
        let keys = ["hshare.state", "hshare.2026-11-22", "hshare.2026-10-19", "hshare.2026-10-18", "hshare.2026-09-23", "hshare.kaputt"]
        // HEALTHSHARE
        #expect(HealthShare.expired(keys: keys, today: today) == ["hshare.2026-09-23", "hshare.2026-10-18"])
    }

    // HEALTHSHARE
    @Test func onlyTheWritersDaysInTheWindow() {
        let state = HealthShareState.sharing(by: "phone", today: today, now: now)
        #expect(state.on && state.from == today.adding(days: -34) && state.through == today && state.by == "phone")
        let mine = HealthShareDay(day: today, by: "phone", counted: ["gewicht": 72.5], read: ["gewicht": 72.6], modifiedAt: now)
        let older = HealthShareDay(day: today, by: "phone", counted: ["gewicht": 73], modifiedAt: now.addingTimeInterval(-3600))
        let foreign = HealthShareDay(day: today.adding(days: -1), by: "ipad", counted: ["gewicht": 80], modifiedAt: now)
        let outside = HealthShareDay(day: today.adding(days: -40), by: "phone", counted: ["gewicht": 74], modifiedAt: now)
        // HEALTHSHARE
        let entries = HealthShare.entries([older, mine, foreign, outside], state: state)
        #expect(entries == [EntryRecord(code: "gewicht", day: today, value: 72.5, note: "Apple Health")])
        // HEALTHSHARE: off (a tombstone with `by`) or missing – nothing.
        #expect(HealthShare.entries([mine], state: .stopped(by: "phone", now: now)).isEmpty && HealthShare.entries([mine], state: nil).isEmpty)
        // HEALTHSHARE
        #expect(HealthShare.read([mine], code: "gewicht", day: today) == 72.6 && HealthShare.read([mine], code: "puls", day: today) == nil)
        // HEALTHSHARE
        #expect(HealthShare.read([mine], code: "gewicht", day: today, state: .stopped(by: "phone", now: now)) == nil)
        // HEALTHSHARE
        #expect(HealthShare.read([foreign], code: "gewicht", day: today.adding(days: -1), state: state) == nil, "another device")
        // HEALTHSHARE
        #expect(HealthShare.covers(today, state: state) && !HealthShare.covers(today.adding(days: 1), state: state))
        // HEALTHSHARE
        #expect(!HealthShare.covers(today, state: nil) && !HealthShare.covers(today, state: .stopped(by: "phone")))
        #expect(HealthShareState.stopped(by: "mac", now: now).by == "mac", "`by` also when off")
    }

    // HEALTHSHARE: P9 – the window's first and last day count, the days just outside don't; a day record of the writer
    // with an older copy of another writer counts once; `keys(week:)` are the week's seven day keys.
    @Test func windowBoundariesAndWeekKeys() {
        // HEALTHSHARE
        let state = HealthShareState.sharing(by: "phone", today: today, now: now)
        let first = today.adding(days: -(HealthShare.window - 1))
        // HEALTHSHARE
        let days = [first.adding(days: -1), first, today, today.adding(days: 1)].map {
            HealthShareDay(day: $0, by: "phone", counted: ["gewicht": 70], modifiedAt: now)
        }
        // HEALTHSHARE
        #expect(HealthShare.entries(days, state: state).map(\.day) == [first, today])
        // HEALTHSHARE
        #expect(HealthShare.covers(first, state: state) && !HealthShare.covers(first.adding(days: -1), state: state))
        // HEALTHSHARE
        #expect(HealthShare.keys(week: V11.week) == V11.week.days.map { "hshare." + $0.string })
        let mixed = [HealthShareDay(day: today, by: "ipad", counted: ["gewicht": 80], modifiedAt: now.addingTimeInterval(60)),
                     HealthShareDay(day: today, by: "phone", counted: ["gewicht": 70.5], modifiedAt: now)]
        // HEALTHSHARE: the newer copy is another device's – only the writer's own counts.
        #expect(HealthShare.entries(mixed, state: state).map(\.value) == [70.5])
        // HEALTHSHARE: no window (a state written without one) covers nothing.
        #expect(HealthShare.entries(days, state: HealthShareState(on: true, by: "phone", modifiedAt: now)).isEmpty)
    }

    // HEALTHSHARE
    @Test func recordsRoundTripTolerantly() throws {
        let day = HealthShareDay(day: today, by: "phone", counted: ["gewicht": 72.5, "kaputt": .infinity], read: ["schlaf": 7.25], modifiedAt: now)
        #expect(day.counted == ["gewicht": 72.5], "only numbers")
        #expect(HealthShareDay(value: day.value) == day)
        // HEALTHSHARE
        #expect(day.settingKey == HealthShare.key(day: today))
        // HEALTHSHARE: the day from the key when the JSON has none; odd values are left out.
        let loose = try #require(HealthShareDay(value: #"{"by":"phone","counted":{"gewicht":"72,5","x":"y"}}"#, key: "hshare.2026-11-21"))
        #expect(loose.day == today.adding(days: -1) && loose.counted == ["gewicht": 72.5] && loose.read.isEmpty)
        var changed = day
        changed.modifiedAt = now.addingTimeInterval(60)
        #expect(changed.hasSameValues(as: day) && !changed.hasSameValues(as: nil), "only a changed value writes")
        changed.counted["gewicht"] = 72.4
        #expect(!changed.hasSameValues(as: day))
        let state = HealthShareState.sharing(by: "phone", today: today, now: now)
        #expect(HealthShareState(value: state.value) == state && HealthShareState(value: "{}")?.on == false)
        #expect(HealthShareState.newest([state.value, HealthShareState.stopped(by: "mac", now: now.addingTimeInterval(60)).value])?.by == "mac")
        #expect(!state.value.contains("72"), "the state carries no values")
    }
}

/// C15: Finn – account balances, result sources, the fixtures (§1.5, P8.3).
@Suite("v11 C15 Finn")
struct V11FinnTests {
    @Test func accountBalanceAndResultSources() throws {
        let metric = try #require(ExchangeMetric.named("account_balance"))
        #expect(metric.agg == .last && metric.unit == "€" && metric.title == "Kontostand")
        let balance = try #require(AppSource(raw: "app:finn:account_balance=acc-giro"))
        let worth = try #require(AppSource(raw: "app:finn:net_worth"))
        #expect(balance.requiresRef && balance.isKnown && balance.suggestedUnit == "€" && !worth.requiresRef)
        let refs = [ExchangeRef(id: "grp-lebensmittel", title: "Lebensmittel", kind: "group"), ExchangeRef(id: "acc-giro", title: "Girokonto", kind: "account"),
                    ExchangeRef(id: "accgrp-sparen", title: "Sparen", kind: "account"), ExchangeRef(id: "any", title: "Ohne Art")]
        #expect(balance.refChoices(refs).map(\.id) == ["acc-giro", "accgrp-sparen", "any"] && worth.refChoices(refs).isEmpty)
        #expect(balance.label(refs: refs) == "Finn · Kontostand · Girokonto")
        #expect(AppSource.resultOnlyKinds == ["net_worth", "savings_rate", "account_balance"])
        #expect(AppSource.kindChoices.contains("account_balance"), "the measure editor leaves out `resultOnlyKinds` itself")
        // One day per account: that account's balance; the arrivals name it.
        let finn = try V10.dayFile("Finn/exchange/days/2026-11-22.json", folder: "Finn")
        let october = try V10.dayFile("Finn/exchange/days/2026-10-31.json", folder: "Finn")
        #expect(balance.dayValue(finn.facts)?.value == 1234.5 && worth.dayValue(finn.facts)?.value == 52000)
        let result = GoalResult(id: "res-giro", goalKey: "8", title: "Puffer", kind: .value, target: ">=1000", unit: "€",
                                source: "app:finn:account_balance=acc-giro")
        #expect(result.appSeries(inbox: [finn, october]) == [V10.day(11, 22): 1234.5, V10.day(10, 31): 980])
        let savings = try #require(AppSource(raw: "app:finn:savings_rate"))
        #expect(ExchangeDerivation.series(savings, inbox: [finn, october]) == [V10.day(10, 31): 18.5], "once a month")
        let arrivals = ExchangeOverview.arrivals(inbox: [finn], today: V10.today)
        #expect(arrivals.first { $0.title == "Girokonto" }?.detail == "Kontostand 1.234,50 € · Girokonto")
        #expect(arrivals.first { $0.title == "Vermögen" }?.detail == "Vermögen 52.000 €")
        // A metric this build doesn't know stays "nicht verwendet".
        let unknown = ExchangeDayFile(source: "finn", day: "2026-11-22", generatedAt: "2026-11-22T20:00:00Z",
                                      facts: [ExchangeFact(id: "x", kind: "value", ref: "debt", value: 5, metric: "debt_total")])
        #expect(ExchangeDerivation.week(V11.week, inbox: [unknown], items: [], measures: []).unused.map(\.id) == ["x"])
        #expect(ExchangeOverview.arrivals(inbox: [unknown], today: V10.today).first?.detail == "nicht verwendet")
    }

    @Test func catalogWithAndWithoutSource() throws {
        let old = #"{"v":1,"generatedAt":"2026-11-22T06:00:00+01:00","results":[{"id":"r","title":"T","kind":"count","goal":"5"},{"id":"s","title":"U","kind":"value","goal":"8","source":[1]},{"id":"t","title":"W","kind":"value","goal":"8","source":""},{"id":"u","title":"V","kind":"value","goal":"8","source":"app:finn:net_worth"}]}"#
        guard case .success(let catalog) = ExchangeReader.catalog(Data(old.utf8)) else {
            Issue.record("catalog")
            return
        }
        #expect(catalog.results.map(\.id) == ["r", "s", "t", "u"] && catalog.results.map(\.source) == [nil, nil, nil, "app:finn:net_worth"])
        let entry = ExchangeCatalog.ResultEntry(id: "r", title: "T", kind: "count", goal: "5", source: " ")
        #expect(entry.source == nil)
        let text = String(decoding: try BinisoftExchange.encode(entry), as: UTF8.self)
        #expect(text == #"{"goal":"5","id":"r","kind":"count","title":"T"}"#, "written only when set")
    }

    @Test func fixturesAreWhatTheWritersBuild() throws {
        let november = ExchangeDayFile(source: "finn", day: "2026-11-22", generatedAt: "2026-11-22T20:00:00Z", facts: [
            ExchangeFact(id: "sp-grp-lebensmittel-2026-11-22", kind: "spending", ref: "grp-lebensmittel", refTitle: "Lebensmittel",
                         title: "Lebensmittel", value: 23.4, currency: "EUR", at: "2026-11-22T17:45:00+01:00"),
            ExchangeFact(id: "sp-grp-freizeit-2026-11-22", kind: "spending", ref: "grp-freizeit", refTitle: "Freizeit", title: "Freizeit",
                         value: 12, currency: "EUR"),
            ExchangeFact(id: "nw-2026-11-22", kind: "value", ref: "net_worth", refTitle: "Vermögen", value: 52000, metric: "net_worth",
                         currency: "EUR"),
            ExchangeFact(id: "kb-acc-giro-2026-11-22", kind: "value", ref: "acc-giro", refTitle: "Girokonto", value: 1234.5,
                         metric: "account_balance", currency: "EUR"),
            ExchangeFact(id: "kb-accgrp-sparen-2026-11-22", kind: "value", ref: "accgrp-sparen", refTitle: "Sparen", value: 8000,
                         metric: "account_balance", currency: "EUR"),
        ])
        let october = ExchangeDayFile(source: "finn", day: "2026-10-31", generatedAt: "2026-10-31T21:30:00Z", facts: [
            ExchangeFact(id: "nw-2026-10-31", kind: "value", ref: "net_worth", refTitle: "Vermögen", value: 51000, metric: "net_worth",
                         currency: "EUR"),
            ExchangeFact(id: "sr-2026-10", kind: "value", ref: "savings_rate", refTitle: "Sparquote", value: 18.5, unit: "%",
                         metric: "savings_rate"),
            ExchangeFact(id: "kb-acc-giro-2026-10-31", kind: "value", ref: "acc-giro", refTitle: "Girokonto", value: 980,
                         metric: "account_balance", currency: "EUR"),
        ])
        #expect(try V10.dayFile("Finn/exchange/days/2026-11-22.json", folder: "Finn") == november)
        #expect(try V10.dayFile("Finn/exchange/days/2026-10-31.json", folder: "Finn") == october)
        for file in [november, october] {
            guard case .success(let read) = ExchangeReader.dayFile(try file.encoded(), folder: "Finn", fileName: "\(file.day).json") else {
                Issue.record("\(file.day)")
                continue
            }
            #expect(read.file == file && read.skipped.isEmpty)
        }
        let source = ExchangeSourceInfo(source: "finn", app: "Finn", appVersion: "1.0", generatedAt: "2026-11-22T20:00:00Z", refs: [
            ExchangeRef(id: "grp-lebensmittel", title: "Lebensmittel", kind: "group"), ExchangeRef(id: "grp-freizeit", title: "Freizeit", kind: "group"),
            ExchangeRef(id: "acc-giro", title: "Girokonto", kind: "account"), ExchangeRef(id: "accgrp-sparen", title: "Sparen", kind: "account"),
        ])
        guard case .success(let info) = ExchangeReader.source(try V10.fixture("Finn/exchange/source.json"), folder: "Finn") else {
            Issue.record("Finn source.json")
            return
        }
        #expect(info == source)

        // Thalia's catalog: exactly what `ExchangeCatalog.thalia` writes, with `source` where a result has one.
        let week = V11.week
        let built = ExchangeCatalog.thalia(
            goals: [GoalRecord(key: "8", title: "Finanzen"), GoalRecord(key: "1", title: "Gesundheit"), GoalRecord(key: "3", title: "Arbeit"),
                    GoalRecord(key: "5", title: "Lesen")],
            categories: [CategoryRecord(key: "8.1", goalKey: "8", title: "Ausgaben"), CategoryRecord(key: "1.2", goalKey: "1", title: "Sport / Verein"),
                         CategoryRecord(key: "3.2", goalKey: "3", title: "Kunden"), CategoryRecord(key: "5", goalKey: "5", title: "Lesen")],
            measures: [
                MeasureRecord(week: week, code: "seiten", categoryKey: "5", position: 3, title: "Seiten", unit: "Seiten", source: MeasureSource(raw: "list:buch")),
                MeasureRecord(week: week, code: "workouts", categoryKey: "1.2", position: 1, title: "Workouts", unit: "Stück",
                              source: MeasureSource(raw: "app:george:workout=tpl-1")),
                MeasureRecord(week: week, code: "kunden_aufgaben", categoryKey: "3.2", position: 2, title: "Aufgaben Kunden", unit: "Stück",
                              source: MeasureSource(raw: "app:theo:task")),
                MeasureRecord(week: week, code: "ausgaben", categoryKey: "8.1", position: 4, title: "Ausgaben", unit: "€",
                              source: MeasureSource(raw: "app:finn:spending")),
            ],
            results: [
                GoalResult(id: "res-giro", goalKey: "8", title: "Puffer Girokonto", kind: .value, source: "app:finn:account_balance=acc-giro", position: 2),
                GoalResult(id: "res-worth", goalKey: "8", title: "Vermögen", kind: .value, source: "app:finn:net_worth", position: 1),
                GoalResult(id: "res-books", goalKey: "5", title: "Bücher gelesen", kind: .count, source: "list:buch"),
                GoalResult(id: "res-web", goalKey: "3", title: "Website online", kind: .check),
            ],
            segment: V10.segments.spans.last, week: week, generatedAt: V10.date("2026-11-22T05:00:00Z"), timeZone: V11.vienna)
        guard case .success(let catalog) = ExchangeReader.catalog(try V10.fixture("Thalia/exchange/catalog.json")) else {
            Issue.record("catalog.json")
            return
        }
        #expect(catalog == built)
        #expect(catalog.results.map(\.source) == [nil, "list:buch", "app:finn:net_worth", "app:finn:account_balance=acc-giro"])
        guard case .success(let again) = ExchangeReader.catalog(try BinisoftExchange.encode(built)) else {
            Issue.record("catalog round trip")
            return
        }
        #expect(again == built)
    }
}

/// C16: tour 11 (P1.18, P1.19).
@Suite("v11 C16 tour 11")
struct V11TourTests {
    @Test func tourElevenWithAndWithoutSharing() throws {
        let plain = ThaliaTour.catalog(healthShare: false)
        let shared = ThaliaTour.catalog(healthShare: true)
        #expect(plain.problems().isEmpty && shared.problems().isEmpty && ThaliaTour.version == 11)
        #expect(ThaliaTour.catalog.allSteps.map(\.id) == plain.allSteps.map(\.id))
        #expect(plain.allSteps.count == 23 && shared.allSteps.count == 24)
        #expect(plain.steps(newerThan: 10).map(\.id) == ["whats-new", "backup", "rules-11", "finish"])
        #expect(shared.steps(newerThan: 10).map(\.id) == ["whats-new", "backup", "rules-11", "health-share", "finish"])
        let steps = Dictionary(uniqueKeysWithValues: shared.allSteps.map { ($0.id, $0) })
        let backup = try #require(steps["backup"])
        #expect(backup.symbol == "externaldrive" && backup.title == "Sicherung" && backup.body.contains("„Sicherung erstellen…“"))
        #expect(backup.body.contains("Einstellungen → Deine Daten → Sicherungen") && backup.macBody.contains("Ablage → „Sicherung erstellen…“"))
        let rules = try #require(steps["rules-11"])
        #expect(rules.symbol == "function" && rules.title == "Genauer gerechnet" && rules.body == rules.macBody)
        #expect(rules.body.contains("„10 Bücher“ zählt alle fertigen Bücher") && rules.body.contains("eingefrorene bleiben"))
        let health = try #require(steps["health-share"])
        #expect(health.title == "Health am Mac und auf der Watch" && health.body.contains("„Health-Werte mit Mac und Watch teilen“"))
        #expect(health.body.contains("Nur in der TestFlight-Version") && health.macBody.contains("Gewicht, Schlaf und Co."))
        let results = try #require(steps["goal-results"])
        #expect(results.symbol == "trophy" && results.body.contains("„auf Kurs“ oder „im Rückstand“"))
        #expect(results.body.contains("ab 8,00") && results.macBody.contains("ab 8,00"))
        #expect(steps["past-weeks"]?.body.contains("„Vom Plan“ – Punkte einer geplanten Woche übernehmen") == true)
        for step in shared.allSteps where step.since >= 8 {
            #expect(!step.body.contains(" du ") && !step.body.contains("deine"), "\(step.id)")
        }
        for step in shared.allSteps where step.since == 11 {
            #expect(!step.macBody.contains(" du ") && !step.macBody.contains("deine"), "\(step.id)")
        }
    }
}

/// C17: the snapshot without `nextDay` (P8.13), lasting sync problems (P4.18).
@Suite("v11 C17 snapshot and sync line")
struct V11SnapshotTests {
    @Test func newWeekWithoutASnapshotAhead() {
        var summary = TodaySummary.placeholder
        summary.dayKey = "2026-11-22"
        summary.nextDay = nil
        summary.hasPlan = true
        let shown = summary.resolved(for: V11.day(11, 23))
        #expect(shown.isNewDay == true && shown.dayKey == "2026-11-23" && shown.weekScore == nil && shown.hasPlan == nil,
                "„Neuer Tag“, not „Kein Plan“")
        #expect(summary.resolved(for: V11.day(11, 22)) == summary)
    }

    @Test func persistentSyncProblems() {
        #expect(SyncGerman.isPersistentProblem(mode: .memory(reason: nil), account: .unknown, quotaExceeded: false))
        #expect(SyncGerman.isPersistentProblem(mode: .local(reason: nil), account: .available, quotaExceeded: false))
        #expect(SyncGerman.isPersistentProblem(mode: .iCloud(container: "c"), account: .noAccount, quotaExceeded: false))
        #expect(SyncGerman.isPersistentProblem(mode: .iCloud(container: "c"), account: .available, quotaExceeded: true))
        for account in [ICloudAccount.unknown, .available, .temporarilyUnavailable, .couldNotDetermine] {
            #expect(!SyncGerman.isPersistentProblem(mode: .iCloud(container: "c"), account: account, quotaExceeded: false), "\(account)")
        }
        #expect(!SyncGerman.isPersistentProblem(mode: .demo, account: .noAccount, quotaExceeded: true))
    }
}

/// C18: Mac, watch and iPad score themselves only when every device runs 1.10.0 (P2.1 (d)).
@Suite("v11 C18 device builds")
struct V11DeviceBuildTests {
    @Test func allDevicesCurrent() {
        let now = V10.date("2026-11-22T12:00:00Z")
        let phone = SyncDevice(installID: "phone", kind: "iPhone", seenAt: now.addingTimeInterval(-3600))
        let mac = SyncDevice(installID: "mac", kind: "Mac", seenAt: now.addingTimeInterval(-86400))
        let old = SyncDevice(installID: "old", kind: "iPad", seenAt: now.addingTimeInterval(-31 * 86400))
        let current = SyncBuild(build: SyncDevice.firstV11Build, version: "1.10.0")
        #expect(SyncDevice.firstV11Build == 58)
        #expect(SyncDevice.allCurrent(seen: [phone, mac, old], builds: ["phone": current, "mac": current], now: now), "older than 30 days: doesn't count")
        #expect(!SyncDevice.allCurrent(seen: [phone, mac], builds: ["phone": current], now: now), "a device without a build ran 1.9")
        #expect(!SyncDevice.allCurrent(seen: [phone], builds: ["phone": SyncBuild(build: 57, version: "1.9.0")], now: now))
        #expect(SyncDevice.allCurrent(seen: [], builds: [:], now: now))
        let settings = [StoredSetting(key: SyncBuild.key(installID: "mac"), value: SyncBuild(build: 57, version: "1.9.0").value),
                        StoredSetting(key: SyncBuild.key(installID: "mac"), value: current.value),
                        StoredSetting(key: "sync.seen.mac", value: "Mac|2026-11-22T10:00:00Z")]
        #expect(SyncBuild.builds(settings) == ["mac": current], "the highest build per device")
    }
}
