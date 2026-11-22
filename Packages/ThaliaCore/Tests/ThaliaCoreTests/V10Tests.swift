import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

// TASKS-v10 §3: results of annual goals, weeks above 8, the reading list, segments, connected apps.
// Neutral labels only ("Sport / Verein", "Lesen", "Arbeit/Kunden", "Push").

/// The goal year 2026/27 with segment 2 from KW45, "today" Sunday 22 Nov. 2026.
enum V10 {
    static let period = GoalPeriod.foundationYear
    static let today = DayKey(year: 2026, month: 11, day: 22)
    static let secondID = "seg-2"
    static func day(_ month: Int, _ day: Int, _ year: Int = 2026) -> DayKey { DayKey(year: year, month: month, day: day) }
    static func date(_ text: String) -> Date { ExchangeDate.parse(text) ?? Date(timeIntervalSince1970: 0) }

    static var second: GoalSegment {
        GoalSegment(id: secondID, title: "Abschnitt 2", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 45),
                    reason: "Zielüberprüfung", goals: [GoalRecord(key: "1", title: "Gesundheit (bis KW44)")],
                    createdAt: date("2026-11-01T18:00:00Z"))
    }

    static var segments: Segments { Segments.resolve([second], period: period) }

    /// The fixture folder (test resource).
    static func fixture(_ path: String) throws -> Data {
        let base = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        return try Data(contentsOf: base.appendingPathComponent("exchange").appendingPathComponent(path))
    }

    static func dayFile(_ path: String, folder: String? = nil) throws -> ExchangeDayFile {
        let name = (path as NSString).lastPathComponent
        let result = ExchangeReader.dayFile(try fixture(path), folder: folder, fileName: name)
        guard case .success(let read) = result else {
            Issue.record("\(path): \(result)")
            throw CancellationError()
        }
        return read.file
    }
}

/// B1: records as JSON in a setting – round trip, defaults, unknown fields kept, keys with a day.
@Suite("v10 B1 SettingRecord")
struct V10SettingRecordTests {
    @Test func roundTripsAndKeepsDefaults() throws {
        let result = GoalResult(id: "r1", periodStart: V10.period.start, goalKey: "5", title: "Bücher gelesen", kind: .count, target: ">=10",
                                targets: [V10.secondID: ">=6"], unit: "Bücher", source: "list", position: 2,
                                modifiedAt: V10.date("2026-11-20T08:00:00.125Z"))
        #expect(result.settingKey == "goal.result.r1")
        let again = try #require(GoalResult(settingValue: result.settingValue, key: result.settingKey))
        #expect(again == result)
        #expect(result.settingValue.contains("\"v\":1"))
        // Codable as such.
        let data = try JSONEncoder().encode(result)
        #expect(try JSONDecoder().decode(GoalResult.self, from: data) == result)

        // Missing fields read as defaults; wrong types are tolerated.
        let sparse = try #require(GoalResult(settingValue: #"{"id":"r2","title":"Website online"}"#))
        #expect(sparse.kind == .count && sparse.target.isEmpty && sparse.targets.isEmpty && sparse.position == 0)
        #expect(sparse.modifiedAt == Date(timeIntervalSince1970: 0) && sparse.deletedAt == nil)
        let loose = try #require(ListItem(settingValue: #"{"id":"b1","title":"Lesen","total":"320","abandoned":"ja"}"#))
        #expect(loose.total == 320 && loose.abandoned && loose.kind == "Buch" && loose.unit == "Seiten")
        #expect(GoalResult(settingValue: "kein JSON") == nil)
        #expect(GoalResult(settingValue: "[1,2]") == nil)
    }

    @Test func unknownFieldSurvivesSaving() throws {
        let stored = #"{"id":"b1","title":"Klarer Kopf","kind":"Buch","color":"blau","tags":["a",{"x":1}],"v":3,"modifiedAt":"2026-11-20T08:00:00Z"}"#
        var item = try #require(ListItem(settingValue: stored))
        #expect(item.unknown["color"] == .string("blau"))
        item.total = 320
        let saved = try #require(JSONText.object(item.settingValue))
        #expect(saved["color"] == .string("blau"))
        #expect(saved["tags"] == .array([.string("a"), .object(["x": .number(1)])]))
        #expect(saved["v"] == .number(3), "the higher version that wrote it stays")
        #expect(saved["total"] == .number(320))
        // A record built anew keeps the stored version's unknown fields too.
        let fresh = ListItem(id: "b1", title: "Klarer Kopf", total: 330)
        let merged = try #require(JSONText.object(fresh.settingValue(preserving: stored)))
        #expect(merged["color"] == .string("blau") && merged["total"] == .number(330))
        // A cleared optional field stays cleared (it isn't brought back from the stored version).
        var finished = ListItem(id: "b2", title: "Lange Wege", finishedOn: V10.day(11, 10))
        let before = finished.settingValue
        finished.finishedOn = nil
        #expect(JSONText.object(finished.settingValue(preserving: before))?["finishedOn"] == nil)
    }

    @Test func datedKeysCarryTheDay() throws {
        let entry = GoalEntry(id: "e1", day: V10.day(11, 17), resultID: "r1")
        #expect(entry.settingKey == "goal.entry.2026-11-17.e1")
        let reading = ListProgress(id: "p1", day: V10.day(11, 18), itemID: "b1", reached: 120)
        #expect(reading.settingKey == "list.progress.2026-11-18.p1")
        #expect(SettingKeys.day(of: entry.settingKey) == V10.day(11, 17))
        #expect(SettingKeys.week(of: reading.settingKey) == WeekKey(year: 2026, week: 47))
        #expect(SettingKeys.week(of: "x.theo.2026-11-22") == WeekKey(year: 2026, week: 47))
        #expect(SettingKeys.week(of: "score.2026-W46") == WeekKey(year: 2026, week: 46))
        #expect(SettingKeys.week(of: "archive.2026-W43") == WeekKey(year: 2026, week: 43))
        #expect(SettingKeys.week(of: "goal.result.r1") == nil && SettingKeys.day(of: "x.sources") == nil)
        #expect(SettingKeys.isV10("goal.segment.s1") && !SettingKeys.isV10("goal.start"))
        // Day and id from the key when the JSON doesn't have them.
        let bare = try #require(GoalEntry(settingValue: #"{"result":"r1"}"#, key: "goal.entry.2026-11-17.e9"))
        #expect(bare.day == V10.day(11, 17) && bare.id == "e9")
    }

    @Test func newestCopyAndTrash() throws {
        let old = ListItem(id: "b1", title: "Alt", modifiedAt: V10.date("2026-11-01T08:00:00Z"))
        let new = ListItem(id: "b1", title: "Neu", modifiedAt: V10.date("2026-11-02T08:00:00Z"))
        let gone = ListItem(id: "b2", title: "Weg", modifiedAt: V10.date("2026-11-02T08:00:00Z")).trashed(now: V10.date("2026-11-03T08:00:00Z"))
        let settings = [
            StoredSetting(key: new.settingKey, value: new.settingValue, modifiedAt: V10.date("2026-11-01T00:00:00Z")),
            StoredSetting(key: old.settingKey, value: old.settingValue, modifiedAt: V10.date("2026-11-05T00:00:00Z")),
            StoredSetting(key: gone.settingKey, value: gone.settingValue),
            StoredSetting(key: "goal.result.r1", value: GoalResult(id: "r1", goalKey: "5", title: "x").settingValue),
        ]
        let items = SettingRecords.decode(ListItem.self, from: settings)
        #expect(items.map(\.title) == ["Neu"], "the newer modifiedAt in the JSON wins over the setting's date; trash left out")
        #expect(SettingRecords.decode(ListItem.self, from: settings, includeDeleted: true).count == 2)
        // Deleting a book sends its readings along; restoring brings exactly those back.
        let now = V10.date("2026-11-22T10:00:00Z")
        let readings = [ListProgress(id: "p1", day: V10.day(11, 1), itemID: "b1", reached: 10),
                        ListProgress(id: "p2", day: V10.day(11, 2), itemID: "b1", reached: 20),
                        ListProgress(id: "p3", day: V10.day(11, 2), itemID: "b9", reached: 5)]
        let trashed = SettingRecords.trashedChildren(of: "b1", in: readings, now: now)
        #expect(trashed.map(\.id) == ["p1", "p2"] && trashed.allSatisfy { $0.deletedAt == now })
        let back = SettingRecords.restoredChildren(of: "b1", deletedAt: now, in: trashed + [readings[2]])
        #expect(back.map(\.id) == ["p1", "p2"] && back.allSatisfy { $0.deletedAt == nil })
    }
}

/// B2: where a result stands.
@Suite("v10 B2 ResultProgress")
struct V10ResultTests {
    let segments = V10.segments
    let today = V10.today

    func entry(_ id: String, _ day: DayKey, result: String = "r1", value: Double? = nil) -> GoalEntry {
        GoalEntry(id: id, day: day, resultID: result, value: value)
    }

    @Test func checkWithItsDate() {
        let result = GoalResult(id: "r1", goalKey: "3", title: "Website online", kind: .check)
        let done = ResultProgress.compute(result, segments: segments, today: today, entries: [entry("e1", V10.day(11, 17))])
        #expect(done.status == .reached && done.doneOn == V10.day(11, 17))
        #expect(done.text == "erledigt am Di, 17. Nov." && done.statusText == "erreicht")
        #expect(done.bySegment[V10.secondID] == 1)
        let open = ResultProgress.compute(result, segments: segments, today: today)
        #expect(open.status == .open && open.text == "offen")
        let late = ResultProgress.compute(result, segments: segments, today: V10.day(6, 5, 2027))
        #expect(late.status == .missed && late.statusText == "nicht erreicht")
    }

    @Test func countFromEntriesWithPaceAndSegments() throws {
        let result = GoalResult(id: "r1", goalKey: "5", title: "Bücher", kind: .count, target: ">=10")
        var entries = [entry("e1", V10.day(7, 10)), entry("e2", V10.day(9, 3)), entry("e3", V10.day(11, 10)),
                       entry("e4", V10.day(11, 11), result: "other")]
        entries.append(entry("e5", V10.day(11, 12)).trashed(now: Date()))
        let progress = ResultProgress.compute(result, segments: segments, today: today, entries: entries)
        #expect(progress.current == 3 && progress.targetValue == 10)
        // Soll heute = 10 × 175/365 (1 June – 22 Nov. of a 365-day year).
        let expected = try #require(progress.expected)
        #expect(abs(expected - 10 * 175.0 / 365) < 1e-9)
        #expect(progress.status == .behind, "3 < 85 % of 4,79")
        #expect(progress.text == "3 von 10 · davon 1 in Abschnitt 2")
        #expect(progress.bySegment[GoalSegment.firstID(period: V10.period)] == 2 && progress.bySegment[V10.secondID] == 1)
        #expect(abs((progress.fraction ?? 0) - 0.3) < 1e-9)
        #expect(progress.shortText == "3/10")

        // The target updated for segment 2: counted and paced in the segment only.
        var updated = result
        updated.targets = [V10.secondID: ">=2"]
        let inSegment = ResultProgress.compute(updated, segments: segments, today: today, entries: entries)
        #expect(inSegment.usesSegmentTarget && inSegment.current == 1 && inSegment.total == 3)
        #expect(abs((inSegment.expected ?? 0) - 2 * 21.0 / 211) < 1e-9, "2 Nov. – 31 May: 211 days, 21 gone")
        #expect(inSegment.status == .onTrack)
        #expect(inSegment.text == "1 von 2 in Abschnitt 2 · 3 im Zieljahr")

        // New from segment 2 on: earlier entries don't count.
        var fresh = result
        fresh.fromSegment = V10.secondID
        #expect(ResultProgress.compute(fresh, segments: segments, today: today, entries: entries).current == 1)

        // Without a target only the value; nothing yet at the start of the year is "offen".
        var untargeted = result
        untargeted.target = ""
        let plain = ResultProgress.compute(untargeted, segments: segments, today: today, entries: entries)
        #expect(plain.status == .untargeted && plain.text == "3 · davon 1 in Abschnitt 2" && plain.statusText.isEmpty)
        #expect(ResultProgress.compute(result, segments: segments, today: V10.day(6, 3)).status == .open)
    }

    @Test func countFromTheListAssignedBeforeKind() {
        let items = [
            ListItem(id: "a", title: "A", finishedOn: V10.day(9, 15), resultID: "books"),
            ListItem(id: "b", title: "B", finishedOn: V10.day(11, 5)),
            ListItem(id: "c", title: "C", finishedOn: V10.day(5, 20), resultID: "books"),
            ListItem(id: "d", title: "D", finishedOn: V10.day(10, 1), resultID: "other"),
            ListItem(id: "e", title: "E", finishedOn: V10.day(10, 10), abandoned: true, resultID: "books"),
            ListItem(id: "f", kind: "Film", title: "F", finishedOn: V10.day(10, 20)),
            ListItem(id: "g", title: "G", startedOn: V10.day(11, 1), resultID: "books"),
        ]
        let assigned = GoalResult(id: "books", goalKey: "5", title: "Bücher", kind: .count, target: ">=10", source: "list")
        let counted = ResultProgress.compute(assigned, segments: segments, today: today, items: items)
        #expect(counted.current == 1, "only A: C finished before the goal year, E abandoned, G still running")
        let byKind = GoalResult(id: "books-2", goalKey: "5", title: "Bücher", kind: .count, target: ">=10", source: "list")
        #expect(ResultProgress.compute(byKind, segments: segments, today: today, items: items).current == 1,
                "nothing counts for it: the finished books without a result – B")
        let films = GoalResult(id: "films", goalKey: "9", title: "Filme", kind: .count, source: "list:Film")
        #expect(ResultProgress.compute(films, segments: segments, today: today, items: items).current == 1)
        #expect(films.resultSource == .list(kind: "film"))
    }

    @Test func countFromAMeasure() {
        let result = GoalResult(id: "r1", goalKey: "5", title: "Seiten", kind: .count, target: ">=1000", unit: "Seiten", source: "measure:seiten")
        let series = [V10.day(11, 16): 20.0, V10.day(11, 17): 30, V10.day(10, 1): 50, V10.day(5, 1): 400]
        let progress = ResultProgress.compute(result, segments: segments, today: today, series: series)
        #expect(progress.current == 100, "the day before the goal year doesn't count")
        #expect(progress.text == "100 von 1.000 Seiten · davon 50 in Abschnitt 2")
        #expect(result.uses(measure: "seiten") && !result.uses(measure: "gewicht"))
    }

    @Test func valueTowardsLessAndMore() throws {
        let weight = GoalResult(id: "w", goalKey: "1", title: "Gewicht", kind: .value, target: "<=85", start: 89, unit: "kg",
                                source: "measure:gewicht")
        let series = [V10.day(7, 1): 88.0, V10.day(11, 20): 86]
        let down = ResultProgress.compute(weight, segments: segments, today: today, series: series)
        #expect(down.current == 86 && down.start == 89 && abs((down.fraction ?? 0) - 0.75) < 1e-9)
        #expect(abs((down.expected ?? 0) - (89 - 4 * 175.0 / 365)) < 1e-9)
        #expect(down.status == .onTrack)
        #expect(down.text == "86 kg · Ziel ≤ 85 kg · −2 kg in Abschnitt 2")
        #expect(down.bySegment[GoalSegment.firstID(period: V10.period)] == -1)
        // An own entry of a day wins over the source's value of that day.
        let corrected = ResultProgress.compute(weight, segments: segments, today: today,
                                               entries: [GoalEntry(id: "e", day: V10.day(11, 20), resultID: "w", value: 85.5)], series: series)
        #expect(corrected.current == 85.5)
        // Updated for segment 2: from the value before the segment to its own target.
        var updated = weight
        updated.targets = [V10.secondID: "<=86"]
        let segment = ResultProgress.compute(updated, segments: segments, today: today, series: series)
        #expect(segment.start == 88 && segment.status == .reached)

        let worth = GoalResult(id: "nw", goalKey: "8", title: "Vermögen", kind: .value, target: ">=60000", start: 40000, unit: "€",
                               source: "app:finn:net_worth")
        let up = ResultProgress.compute(worth, segments: segments, today: today, series: [V10.day(10, 31): 45000])
        #expect(up.status == .behind && up.text == "45.000 € · Ziel ≥ 60.000 €")
        #expect(ResultProgress.compute(worth, segments: segments, today: today).text == "noch kein Wert · Ziel ≥ 60.000 €")
        let line = GoalResultLine(result: worth, goal: GoalRecord(key: "8", title: "Finanzen"), progress: up)
        #expect(line.markdown == "- 8 Finanzen · Vermögen: 45.000 € · Ziel ≥ 60.000 € · hinten")
        #expect(GoalResultLine(result: weight, goal: nil, progress: down, hidesValue: true).text == "Wert nur auf dem Gerät")
        #expect(line.countsForText == "zählt für Ziel 8 · Vermögen 45.000 €")
    }

    @Test func measuresOfAGoal() {
        let week = WeekKey(year: 2026, week: 47)
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung"), CategoryRecord(key: "1.2", goalKey: "1", title: "Sport / Verein")]
        let measures = [MeasureRecord(week: week, code: "schritte", categoryKey: "1.2", position: 2, title: "Schritte"),
                        MeasureRecord(week: week, code: "protein", categoryKey: "1.1", position: 1, title: "Protein"),
                        MeasureRecord(week: week, code: "seiten", categoryKey: "5", position: 3, title: "Seiten")]
        let results = [GoalResult(id: "r", goalKey: "1", title: "Seiten", source: "measure:seiten")]
        #expect(GoalResult.measures(of: "1", categories: categories, measures: measures, results: results).map(\.code) == ["protein", "schritte", "seiten"])
        let chips = GoalResult.chips(["Gewicht", "Protein", "Schritte", "Seiten", "Kcal"])
        #expect(chips.shown == ["Gewicht", "Protein", "Schritte"] && chips.more == 2)
    }
}

/// B3: weeks above 8.
@Suite("v10 B3 GoalTrack")
struct V10GoalTrackTests {
    @Test func roundedLikeTheDisplay() {
        #expect(GoalTrack.isGood(8.0))
        #expect(!GoalTrack.isGood(7.994), "shown as 7,99")
        #expect(Format.score(7.994) == "7,99")
        #expect(GoalTrack.isGood(7.996) && Format.score(7.996) == "8")
        #expect(!GoalTrack.isGood(nil) && GoalTrack.isGood(10))
    }

    @Test func textRoundTrip() {
        let scores = ["1.2": 6.5, "1.1": 8.2, "1.10": 9]
        #expect(GoalTrack.text(scores) == "1.1=8.2;1.2=6.5;1.10=9")
        #expect(GoalTrack.scores(GoalTrack.text(scores)) == scores)
        #expect(GoalTrack.scores("1.1=8,2; kaputt ;1.2 = 6.5;") == ["1.1": 8.2, "1.2": 6.5])
        #expect(GoalTrack.settingKey(WeekKey(year: 2026, week: 47)) == "score.2026-W47")
        #expect(GoalTrack.week(settingKey: "score.2026-W47") == WeekKey(year: 2026, week: 47))
    }

    @Test func excusedWeeksAndEveryCategory() {
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung"), CategoryRecord(key: "1.2", goalKey: "1", title: "Sport / Verein"),
                          CategoryRecord(key: "5", goalKey: "5", title: "Lesen")]
        #expect(GoalTrack.goalIsGood("1", categories: categories, scores: ["1.1": 8.5, "1.2": 8]) == true)
        #expect(GoalTrack.goalIsGood("1", categories: categories, scores: ["1.1": 8.5, "1.2": 7.9]) == false)
        #expect(GoalTrack.goalIsGood("1", categories: categories, scores: ["1.1": 8.5]) == true, "only scored categories count")
        #expect(GoalTrack.goalIsGood("5", categories: categories, scores: ["1.1": 9]) == nil)

        let base = WeekKey(year: 2026, week: 30)
        var weeks: [GoalTrack.Week] = []
        for offset in 0..<14 {
            weeks.append(GoalTrack.Week(week: base.adding(weeks: offset), scores: ["1.1": offset % 2 == 0 ? 8.4 : 7.0, "1.2": 9]))
        }
        weeks.append(GoalTrack.Week(week: base.adding(weeks: 14), scores: ["1.1": 9, "1.2": 9], isExcused: true))
        let tallies = GoalTrack.tallies(weeks, categories: ["1.1", "1.2", "5"])
        #expect(tallies.map(\.text) == ["1.1 6/12", "1.2 12/12"], "the last 12 scored weeks; the excused one and 5 (never scored) left out")
        #expect(GoalTrack.line(tallies) == "Wochen über 8: 1.1 6/12 · 1.2 12/12")
        let range = base.adding(weeks: 10)...base.adding(weeks: 20)
        #expect(GoalTrack.tallies(weeks, categories: ["1.1"], range: range).first?.text == "1.1 2/4")
        #expect(GoalTrack.total(weeks, range: range) == (good: 6, scored: 8))
        #expect(GoalTrack.goalWeeks("1", weeks: weeks, categories: categories) == (good: 7, scored: 14))
        #expect(GoalTrack.line([]) == nil)
    }
}

/// B4: amounts per day from readings.
@Suite("v10 B4 ListMath")
struct V10ListTests {
    func reading(_ id: String, _ day: Int, _ page: Double, item: String = "b1", minute: Double = 0) -> ListProgress {
        ListProgress(id: id, day: V10.day(11, day), itemID: item, reached: page, modifiedAt: V10.day(11, day).date(minutes: 20 * 60 + minute))
    }

    @Test func amountsPerDayRetroactiveNeverNegative() {
        var readings = [reading("p1", 1, 50), reading("p3", 3, 120)]
        #expect(ListMath.dailyAmounts(itemID: "b1", progress: readings) == [V10.day(11, 1): 50, V10.day(11, 3): 70])
        // Entered afterwards for the day in between: the amounts follow the days, not the order of entry.
        readings.append(reading("p2", 2, 80))
        #expect(ListMath.dailyAmounts(itemID: "b1", progress: readings) == [V10.day(11, 1): 50, V10.day(11, 2): 30, V10.day(11, 3): 40])
        // A lower reading counts 0; the next one counts from the highest so far.
        readings += [reading("p4", 4, 100), reading("p5", 5, 150)]
        let amounts = ListMath.dailyAmounts(itemID: "b1", progress: readings)
        #expect(amounts[V10.day(11, 4)] == nil && amounts[V10.day(11, 5)] == 30)
        #expect(amounts.values.reduce(0, +) == 150)
        // Two readings on one day: the one saved last counts.
        readings.append(reading("p6", 5, 140, minute: 30))
        #expect(ListMath.reached(itemID: "b1", progress: readings) == 140 && ListMath.reached(itemID: "b1", progress: readings, through: V10.day(11, 2)) == 80)
        // In the trash: gone.
        readings[0] = readings[0].trashed(now: Date())
        #expect(ListMath.dailyAmounts(itemID: "b1", progress: readings)[V10.day(11, 2)] == 80)
    }

    @Test func finishedInTheSpanAndStatus() {
        let book = ListItem(id: "b1", title: "Klarer Kopf", total: 320)
        let film = ListItem(id: "f1", kind: "Film", title: "Ein Film", finishedOn: V10.day(11, 3))
        let done = ListItem(id: "b2", title: "Kleine Schritte", finishedOn: V10.day(11, 10))
        let dropped = ListItem(id: "b3", title: "Lange Wege", finishedOn: V10.day(11, 11), abandoned: true)
        let items = [book, film, done, dropped]
        let readings = [ListProgress(id: "p", day: V10.day(11, 16), itemID: "b1", reached: 120),
                        ListProgress(id: "q", day: V10.day(11, 17), itemID: "f1", reached: 90)]
        #expect(ListMath.finished(items, from: V10.day(11, 1), through: V10.day(11, 30)).map(\.id) == ["f1", "b2"])
        #expect(ListMath.finished(items, from: V10.day(11, 5), through: V10.day(11, 30), kind: "buch").map(\.id) == ["b2"])
        #expect(ListMath.status(book, progress: readings) == .running && ListMath.status(book, progress: []) == .planned)
        #expect(ListMath.status(done, progress: []) == .finished && ListMath.status(dropped, progress: []) == .abandoned)
        #expect(ListStatus.running.label == "Läuft")
        #expect(ListMath.fraction(book, progress: readings) == 0.375)
        #expect(ListMath.progressText(book, progress: readings) == "120 von 320 Seiten · 38 %")
        #expect(ListMath.suggestsFinish(book, reached: 320) && !ListMath.suggestsFinish(book, reached: 319))
        // A measure with the source list:buch gets the pages of all books per day.
        let week = WeekKey(year: 2026, week: 47)
        let measure = MeasureRecord(week: week, code: "seiten", title: "Seiten", unit: "Seiten", source: MeasureSource(raw: "list:buch"))
        let entries = ListMath.entries(for: [measure], items: items, progress: readings, days: week.days)
        #expect(entries == [EntryRecord(code: "seiten", day: V10.day(11, 16), value: 120)], "the film's minutes don't count")
        #expect(ListMath.perWeek(items: items, progress: readings, kind: "buch") == [week: 120])
    }
}

/// B5: segments of a goal year.
@Suite("v10 B5 Segments")
struct V10SegmentTests {
    let period = V10.period

    @Test func noneGivesOneForTheWholeYear() throws {
        let segments = Segments.resolve([], period: period)
        let only = try #require(segments.spans.first)
        #expect(segments.spans.count == 1 && !segments.hasSeveral)
        #expect(only.id == GoalSegment.firstID(period: period) && only.title == "Abschnitt 1" && !only.isStored)
        #expect(only.startDay == period.start && only.endDay == period.end && only.startWeek == period.start.week)
        #expect(segments.current(today: V10.today)?.number == 1)
        #expect(!segments.isFrozen(WeekKey(year: 2026, week: 30), today: V10.today))
    }

    @Test func twoAreGapless() throws {
        let segments = V10.segments
        #expect(segments.spans.map(\.number) == [1, 2])
        let first = segments.spans[0]
        let second = segments.spans[1]
        #expect(first.endWeek == WeekKey(year: 2026, week: 44) && first.endDay == V10.day(11, 1))
        #expect(second.startDay == V10.day(11, 2) && second.endDay == period.end && second.isStored)
        #expect(first.endDay.adding(days: 1) == second.startDay)
        #expect(segments.span(for: V10.day(11, 1))?.number == 1 && segments.span(for: WeekKey(year: 2026, week: 45))?.id == V10.secondID)
        #expect(second.headline(week: WeekKey(year: 2026, week: 47)) == "Abschnitt 2 · seit KW45 · Woche 3")
        #expect(first.weeksLabel == "KW23–KW44" && first.weekCount == 22)
        #expect(segments.earlier(today: V10.today).map(\.number) == [1])
        // Frozen: weeks before the current segment.
        #expect(segments.isFrozen(WeekKey(year: 2026, week: 44), today: V10.today))
        #expect(!segments.isFrozen(WeekKey(year: 2026, week: 45), today: V10.today))
        #expect(!segments.isFrozen(WeekKey(year: 2026, week: 20), today: V10.day(5, 25)), "the goal year hasn't started")
        // Starting the next one: one week after the current one's start at the earliest, next week by default.
        #expect(segments.earliestStart(today: V10.today) == WeekKey(year: 2026, week: 46))
        #expect(segments.defaultStart(today: V10.today) == WeekKey(year: 2026, week: 48))
        #expect(!segments.canStart(WeekKey(year: 2026, week: 45), today: V10.today) && segments.canStart(WeekKey(year: 2026, week: 46), today: V10.today))
        #expect(segments.nextTitle(today: V10.today) == "Abschnitt 3")
    }

    @Test func retroactivePerYearNewestAndLabels() throws {
        let created = V10.date("2026-11-22T10:00:00Z")
        // Started back in time: from then on, the weeks before are frozen.
        let back = GoalSegment(id: "back", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 40), createdAt: created)
        let resolved = Segments.resolve([back], period: period)
        #expect(resolved.current(today: V10.today)?.id == "back" && resolved.spans[1].title == "Abschnitt 2")
        #expect(resolved.isFrozen(WeekKey(year: 2026, week: 39), today: V10.today))
        // Another goal year's segments don't count; one before the year's start becomes its first.
        let other = GoalSegment(id: "next-year", periodStart: V10.day(6, 1, 2027), startWeek: WeekKey(year: 2027, week: 30), createdAt: created)
        let early = GoalSegment(id: "early", title: "Start", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 10), createdAt: created)
        let mixed = Segments.resolve([other, early], period: period)
        #expect(mixed.spans.map(\.id) == ["early"] && mixed.spans[0].title == "Start" && mixed.spans[0].startWeek == period.start.week)
        // Two on the same week: the newer one; in the trash: left out.
        let newer = GoalSegment(id: "b", title: "Neu", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 40),
                                createdAt: created.addingTimeInterval(60))
        let trashed = GoalSegment(id: "c", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 46), createdAt: created).trashed()
        #expect(Segments.resolve([back, newer, trashed], period: period).spans.map(\.id) == [GoalSegment.firstID(period: period), "b"])

        // Labels of old weeks: as at the end of their segment (the next one's snapshot); the current one live.
        let live = [GoalRecord(key: "1", title: "Gesundheit"), GoalRecord(key: "2", title: "Lernen")]
        let old = V10.segments.labels(for: WeekKey(year: 2026, week: 30), today: V10.today, goals: live, categories: [])
        #expect(old.goals.map(\.title) == ["Gesundheit (bis KW44)", "Lernen"])
        let now = V10.segments.labels(for: WeekKey(year: 2026, week: 47), today: V10.today, goals: live, categories: [])
        #expect(now.goals == live)
        // Stored with its snapshot and read back.
        let first = GoalSegment.first(period: period, goals: live, categories: [CategoryRecord(key: "1.2", goalKey: "1", title: "Sport / Verein")],
                                      now: created)
        let again = try #require(GoalSegment(settingValue: first.settingValue))
        #expect(again == first && again.id == GoalSegment.firstID(period: period) && again.categories.first?.goalKey == "1")
    }
}

/// B6: the exchange format.
@Suite("v10 B6 ExchangeFormat")
struct V10ExchangeFormatTests {
    @Test func readsTheFixtures() throws {
        let theo = try V10.dayFile("Theo/exchange/days/2026-11-22.json", folder: "Theo")
        #expect(theo.source == "theo" && theo.day == "2026-11-22" && theo.facts.count == 4)
        let task = try #require(theo.facts.first)
        #expect(task.knownKind == .taskDone && task.isFromApp && task.thalia?.category == "3.2" && task.thalia?.categoryTitle == "Kunden")
        let ph = theo.facts[1]
        #expect(ph.knownKind == .powerHours && ph.value == 1.5 && ph.title == nil && ph.at == nil && ph.thalia == nil, "optional fields may be missing")
        #expect(theo.generatedDate == V10.date("2026-11-22T17:04:05Z"))

        let george = try V10.dayFile("George/exchange/days/2026-11-22.json", folder: "George")
        #expect(george.facts.filter { $0.knownOrigin == .health }.count == 1)
        let nina = try V10.dayFile("Nina/exchange/days/2026-11-22.json", folder: "Nina")
        #expect(nina.facts.first?.date == V10.date("2026-11-22T06:15:00.250Z"), "fractional seconds")
        #expect(nina.facts.first { $0.metric == "fiber_g" }?.isKnown == false, "an unknown metric is read but not used")
        let finn = try V10.dayFile("Finn/exchange/days/2026-11-22.json", folder: "Finn")
        #expect(finn.facts.first?.currency == "EUR" && finn.facts.last?.knownMetric?.agg == .last)

        guard case .success(let source) = ExchangeReader.source(try V10.fixture("Theo/exchange/source.json"), folder: "Theo") else {
            Issue.record("source.json")
            return
        }
        #expect(source.displayName == "Theo" && source.appVersion == "2.4.0" && source.refs.map(\.id) == ["grp-91AB", "grp-22CD"])
        guard case .success(let catalog) = ExchangeReader.catalog(try V10.fixture("Thalia/exchange/catalog.json")) else {
            Issue.record("catalog.json")
            return
        }
        #expect(catalog.segment?.title == "Abschnitt 2" && catalog.measures.map(\.link).contains("app:george:workout=tpl-1"))
        #expect(catalog.results.map(\.kind) == ["count", "check"])
        // Written and read back unchanged.
        let data = try theo.encoded()
        guard case .success(let read) = ExchangeReader.dayFile(data) else {
            Issue.record("round trip")
            return
        }
        #expect(read.file == theo && read.skipped.isEmpty)
    }

    @Test func refusesWithAReason() throws {
        func reason(_ path: String, folder: String? = nil, name: String? = nil) throws -> ExchangeReadError? {
            if case .failure(let error) = ExchangeReader.dayFile(try V10.fixture(path), folder: folder, fileName: name) { return error }
            return nil
        }
        let wrongFolder = try reason("Theo/exchange/days/2026-11-22.json", folder: "George")
        #expect(wrongFolder == .sourceMismatch(folder: "George", source: "theo"))
        #expect(wrongFolder?.reason == "Die Quelle \u{201E}theo\u{201C} passt nicht zum Ordner \u{201E}George\u{201C}.")
        #expect(try reason("invalid/not-json.json") == .notJSON)
        #expect(ExchangeReadError.notJSON.reason == "Die Datei ist kein lesbares JSON.")
        #expect(try reason("invalid/missing-source.json") == .missingField("source"))
        #expect(try reason("invalid/bad-day.json") == .badDay("2026-02-30"))
        #expect(try reason("Theo/exchange/days/2026-11-22.json", name: "2026-11-21.json") == .dayMismatch(fileName: "2026-11-21.json", day: "2026-11-22"))
        if case .failure(let error) = ExchangeReader.dayFile(Data()) { #expect(error == .empty) } else { Issue.record("empty") }
        if case .failure(let error) = ExchangeReader.dayFile(Data("[1]".utf8)) { #expect(error == .notAnObject) } else { Issue.record("array") }

        // A broken fact is skipped with its reason, the rest stays; unknown kinds are kept, not used.
        guard case .success(let read) = ExchangeReader.dayFile(try V10.fixture("invalid/partly-broken.json")) else {
            Issue.record("partly broken")
            return
        }
        #expect(read.file.facts.map(\.id) == ["task-1", "sleep-1", "task-2"])
        #expect(read.skipped.count == 2 && read.skipped.first == "Tatsache 2: Das Feld \u{201E}id\u{201C} fehlt.")
        #expect(read.skipped.last?.hasPrefix("Tatsache 3: ") == true)
        #expect(read.file.facts[1].isKnown == false && read.file.facts[2].value == 2.5, "a value written as text \"2,5\"")
    }

    @Test func hashDatesAndFiles() throws {
        #expect(String(ExchangeHash.fnv1a64(""), radix: 16) == "cbf29ce484222325")
        #expect(String(ExchangeHash.fnv1a64("a"), radix: 16) == "af63dc4c8601ec8c")
        #expect(String(ExchangeHash.fnv1a64("foobar"), radix: 16) == "85944171f73967e8")
        #expect(ExchangeHash.hex("a") == "af63dc4c8601ec8c" && ExchangeHash.hex("grp-91AB") == ExchangeHash.hex("grp-91AB"))

        let utc = V10.date("2026-11-22T17:04:05Z")
        #expect(ExchangeDate.parse("2026-11-22T18:04:05+01:00") == utc)
        #expect(ExchangeDate.parse("2026-11-22T18:04:05+0100") == utc)
        #expect(ExchangeDate.parse("2026-11-22T18:04:05.250+01:00") == utc.addingTimeInterval(0.25))
        #expect(ExchangeDate.parse("2026-11-22T13:04:05-04:00") == utc)
        for bad in ["2026-11-22", "2026-11-22T18:04:05", "2026-13-01T00:00:00Z", "gestern", "2026-11-22T25:00:00Z"] {
            #expect(ExchangeDate.parse(bad) == nil, "\(bad)")
        }
        let vienna = try #require(TimeZone(identifier: "Europe/Vienna"))
        #expect(ExchangeDate.string(utc, timeZone: vienna) == "2026-11-22T18:04:05+01:00")
        #expect(ExchangeDate.string(utc, timeZone: try #require(TimeZone(identifier: "UTC"))) == "2026-11-22T17:04:05Z")
        #expect(ExchangeDate.string(utc.addingTimeInterval(0.25), timeZone: vienna, fractional: true) == "2026-11-22T18:04:05.250+01:00")
        #expect(ExchangeDate.day(utc.addingTimeInterval(7 * 3600), timeZone: vienna) == "2026-11-23")

        #expect(BinisoftExchange.day(fromFileName: "2026-11-22.json") == "2026-11-22")
        for name in [".2026-11-22.json", "2026-11-22.json.tmp", "2026-11-22.tmp", "source.json", "2026-02-30.json"] {
            #expect(BinisoftExchange.day(fromFileName: name) == nil, "\(name)")
        }
        #expect(BinisoftExchange.expiredDayFiles(["2026-09-20.json", "2026-09-21.json", "2026-11-22.json", ".x.json"], today: "2026-11-22")
                == ["2026-09-20.json"], "older than 62 days")
        #expect(BinisoftExchange.matches(folder: "Theo", source: "theo") && !BinisoftExchange.matches(folder: "Theo", source: "nina"))
        #expect(BinisoftExchange.day("2026-03-01", adding: -1) == "2026-02-28")
        #expect(ExchangeMetric.named("kcal")?.agg == .sum && ExchangeMetric.named("body_weight_kg")?.agg == .last)
        #expect(ExchangeMetric.table.map(\.id) == ["kcal", "protein_g", "carbs_g", "fat_g", "water_ml", "net_worth", "savings_rate", "body_weight_kg"])
    }
}

/// B7: what the inbox does to a week – computed, own records win.
@Suite("v10 B7 ExchangeDerivation")
struct V10DerivationTests {
    let week = WeekKey(year: 2026, week: 47)
    var items: [ItemRecord] {
        [ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", title: "Krafttraining", days: .workdays, measure: "workouts"),
         ItemRecord(week: week, code: "1.2-02", categoryKey: "1.2", title: "Push gemacht", measure: "app:george:workout=tpl-1"),
         ItemRecord(week: week, code: "3.2-01", categoryKey: "3.2", title: "Kundenaufgabe erledigt", target: Target.parse(">=1"),
                    measure: "kunden_aufgaben"),
         ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Kalorien im Rahmen", target: Target.parse("<=2000"), measure: "kalorien")]
    }
    var measures: [MeasureRecord] {
        [MeasureRecord(week: week, code: "workouts", categoryKey: "1.2", title: "Workouts", unit: "Stück", source: MeasureSource(raw: "app:george:workout=tpl-1")),
         MeasureRecord(week: week, code: "kunden_aufgaben", categoryKey: "3.2", title: "Aufgaben", unit: "Stück", source: MeasureSource(raw: "app:theo:task")),
         MeasureRecord(week: week, code: "kalorien", categoryKey: "1.1", title: "Kalorien", unit: "kcal", source: MeasureSource(raw: "app:nina:kcal")),
         MeasureRecord(week: week, code: "ausgaben", categoryKey: "8", title: "Ausgaben", unit: "€", source: MeasureSource(raw: "app:finn:spending"))]
    }
    let categories = ["1.1", "1.2", "3.2", "3.4", "3.5", "8"].map { CategoryRecord(key: $0, goalKey: String($0.prefix(1)), title: "K \($0)") }
    let rules = [LinkRule(source: "theo", ref: "grp-91AB", refTitle: "Arbeit/Kunden", categoryKey: "3.4"),
                 LinkRule(source: "theo", ref: "grp-22CD", refTitle: "Haushalt", categoryKey: "3.5")]

    func workout(_ day: Int, id: String, origin: ExchangeOrigin = .app, ref: String = "tpl-1") -> ExchangeFact {
        ExchangeFact(id: id, kind: "workout.done", ref: ref, refTitle: ref == "tpl-1" ? "Push" : "Pull", title: "Einheit", origin: origin)
    }

    func file(_ source: String, _ day: Int, _ facts: [ExchangeFact], at time: String = "20:00:00") -> ExchangeDayFile {
        ExchangeDayFile(source: source, day: V10.day(11, day).string, generatedAt: "2026-11-\(day)T\(time)+01:00", facts: facts)
    }

    var inbox: [ExchangeDayFile] {
        [file("george", 16, [workout(16, id: "w16")]),
         file("george", 17, [workout(17, id: "w17")]),
         file("george", 18, [workout(18, id: "w18", origin: .health)]),
         file("george", 20, [workout(20, id: "w20")]),
         file("george", 21, [workout(21, id: "w21"), workout(21, id: "w21b", ref: "tpl-2")]),
         file("theo", 19, [
             ExchangeFact(id: "t1", kind: "task.done", ref: "grp-91AB", refTitle: "Arbeit/Kunden", title: "Rechnung schreiben",
                          thalia: ExchangeThaliaHint(category: "3.2", categoryTitle: "K 3.2")),
             ExchangeFact(id: "t2", kind: "task.done", ref: "grp-22CD", refTitle: "Haushalt", title: "Ablage"),
             ExchangeFact(id: "p1", kind: "ph", ref: "grp-91AB", refTitle: "Arbeit/Kunden", value: 1.5, unit: "PH",
                          thalia: ExchangeThaliaHint(category: "3.2")),
             ExchangeFact(id: "p2", kind: "ph", ref: "grp-22CD", refTitle: "Haushalt", value: 0.5, unit: "PH"),
             ExchangeFact(id: "p3", kind: "ph", ref: "grp-99", refTitle: "Sonstiges", value: 1, unit: "PH"),
             ExchangeFact(id: "p4", kind: "ph", ref: "grp-91AB", value: 1, unit: "PH"),
             ExchangeFact(id: "p5", kind: "ph", ref: "grp-91AB", value: 2, unit: "PH", origin: .health),
             ExchangeFact(id: "x1", kind: "sleep.logged", ref: "night", value: 7),
         ]),
         file("nina", 19, [ExchangeFact(id: "k4", kind: "value", ref: "kcal", value: 2400, metric: "kcal")]),
         file("nina", 21, [ExchangeFact(id: "k1", kind: "value", ref: "kcal", value: 650, metric: "kcal"),
                           ExchangeFact(id: "k2", kind: "value", ref: "kcal", value: 1150, metric: "kcal")]),
         file("nina", 22, [ExchangeFact(id: "k3", kind: "value", ref: "kcal", value: 2500, metric: "kcal")]),
         file("finn", 22, [ExchangeFact(id: "s1", kind: "spending", ref: "grp-lebensmittel", refTitle: "Lebensmittel", title: "Lebensmittel",
                                        value: 23.4, currency: "EUR", at: "2026-11-22T17:45:00+01:00"),
                           ExchangeFact(id: "s2", kind: "spending", ref: "grp-freizeit", refTitle: "Freizeit", value: 12, currency: "EUR")])]
    }

    var effect: ExchangeEffect {
        ExchangeDerivation.week(week, inbox: inbox, items: items, measures: measures, rules: rules, categories: categories,
                                ownMarks: [MarkRecord(week: week, itemCode: "1.2-01", day: V10.day(11, 17), mark: nil)],
                                ownEntries: [EntryRecord(code: "kalorien", day: V10.day(11, 22), value: 1900),
                                             EntryRecord(code: "ausgaben", day: V10.day(11, 22), value: 10)],
                                ownWorkIDs: [ExchangeDerivation.importID(source: "theo", factID: "p4")],
                                excusedDays: [V10.day(11, 20)])
    }

    @Test func ticksOnlyWithoutOwnMarksOnDaysThatCount() {
        let effect = self.effect
        let strength = effect.marks.filter { $0.itemCode == "1.2-01" }.map(\.day)
        #expect(strength == [V10.day(11, 16)], "17: an own (cleared) mark wins · 18: from Health · 20: sick · 21: not a work day")
        #expect(effect.markLabels["1.2-01|2026-11-16"] == "⇄ George · Push")
        #expect(effect.marks.allSatisfy { $0.mark == .done })
        // Linked to the app source directly: a hidden measure of that code.
        #expect(effect.marks.filter { $0.itemCode == "1.2-02" }.map(\.day) == [V10.day(11, 16), V10.day(11, 17), V10.day(11, 21)])
        #expect(effect.entries.contains { $0.code == "app:george:workout=tpl-1" && $0.day == V10.day(11, 21) && $0.value == 1 }, "only tpl-1")
        // Tasks count for the measure's category: from the app's choice and from Thalia's mapping …
        #expect(effect.entries.first { $0.code == "kunden_aufgaben" }?.value == 1, "t2's mapping says 3.5, t1's choice 3.2")
        #expect(effect.marks.contains { $0.itemCode == "3.2-01" && $0.day == V10.day(11, 19) })
        // Within the item's limit: a tick; above it no derived tick (the usual suggestion applies).
        #expect(effect.entries.first { $0.code == "kalorien" && $0.day == V10.day(11, 21) }?.value == 1800)
        #expect(effect.marks.contains { $0.itemCode == "1.1-01" && $0.day == V10.day(11, 21) })
        #expect(effect.entries.first { $0.code == "kalorien" && $0.day == V10.day(11, 19) }?.value == 2400)
        #expect(!effect.marks.contains { $0.itemCode == "1.1-01" && $0.day == V10.day(11, 19) })
        #expect(!effect.marks.contains { $0.itemCode == "1.1-01" && $0.day == V10.day(11, 22) }, "an own entry that day")
        #expect(effect.ignored == 2 && effect.unused.map(\.id) == ["x1"])
    }

    @Test func powerHoursByTheAppsChoiceBeforeTheMapping() throws {
        let effect = self.effect
        #expect(effect.work.map(\.id) == ["x:theo:p1", "x:theo:p2"])
        #expect(effect.work.map(\.categoryKey) == ["3.2", "3.5"], "p1: the app chose 3.2 (the mapping says 3.4); p2: the mapping")
        #expect(effect.unassignedWork.map(\.id) == ["x:theo:p3"])
        #expect(!effect.work.contains { $0.id == "x:theo:p4" }, "an own block with the importID replaces it")
        #expect(effect.workSources["x:theo:p1"] == "Theo" && effect.work.first?.powerHours == 1.5 && effect.work.first?.task == "Arbeit/Kunden")
        let parsed = try #require(ExchangeDerivation.parseImportID("x:theo:p1"))
        #expect(parsed.source == "theo" && parsed.factID == "p1")
    }

    @Test func ownEntriesWinAndSpendingAddsUp() throws {
        let effect = self.effect
        #expect(!effect.entries.contains { $0.code == "kalorien" && $0.day == V10.day(11, 22) })
        let spending = try #require(effect.entries.first { $0.code == "ausgaben" })
        #expect(abs((spending.value ?? 0) - 35.4) < 1e-9 && spending.parts.count == 2 && effect.additiveCodes == ["ausgaben"])
        #expect(effect.entrySources[spending.key] == "Finn")
        let own = [EntryRecord(code: "ausgaben", day: V10.day(11, 22), value: 10)]
        let merged = Measures.merged(own: own, external: effect.entries, additive: effect.additiveCodes)
        let measure = measures[3]
        #expect(abs((Measures.dayValue(measure, on: V10.day(11, 22), entries: merged) ?? 0) - 45.4) < 1e-9, "own spendings add to Finn's")
    }

    @Test func weekExtrasInOneCall() throws {
        let book = ListItem(id: "b1", title: "Klarer Kopf", total: 320)
        let readings = [ListProgress(id: "p1", day: V10.day(11, 16), itemID: "b1", reached: 40),
                        ListProgress(id: "p2", day: V10.day(11, 18), itemID: "b1", reached: 70)]
        var measures = self.measures
        measures.append(MeasureRecord(week: week, code: "seiten", categoryKey: "5", title: "Seiten", unit: "Seiten", source: MeasureSource(raw: "list:buch")))
        let own = [MarkRecord(week: week, itemCode: "1.2-01", day: V10.day(11, 17), mark: nil),
                   MarkRecord(week: week, itemCode: "1.2-02", day: V10.day(11, 16), mark: .partial)]
        let extras = WeekExtras.compute(WeekExtras.Input(
            week: week, items: items, measures: measures, categories: categories, ownMarks: own,
            ownEntries: [EntryRecord(code: "seiten", day: V10.day(11, 18), value: 25)],
            ownWork: [WorkRecord(id: "w1", day: V10.day(11, 19), categoryKey: "3.2", task: "Eigener Block", powerHours: 1)],
            excusedDays: [V10.day(11, 20)], inbox: inbox, rules: rules, listItems: [book], listProgress: readings))
        #expect(extras.marks["1.2-01|2026-11-16"] == .done && extras.isDerived("1.2-01", on: V10.day(11, 16)))
        #expect(extras.marks["1.2-01|2026-11-17"] == nil, "a cleared own mark stays blank")
        #expect(extras.marks["1.2-02|2026-11-16"] == .partial && !extras.isDerived("1.2-02", on: V10.day(11, 16)), "own wins")
        #expect(extras.listEntries.map(\.value) == [40, 30])
        let pages = try #require(measures.last)
        #expect(Measures.dayValue(pages, on: V10.day(11, 16), entries: extras.entries) == 40)
        #expect(Measures.dayValue(pages, on: V10.day(11, 18), entries: extras.entries) == 25, "the own entry replaces the list's 30")
        #expect(extras.work.map(\.id) == ["w1", "x:theo:p1", "x:theo:p2", "x:theo:p4"], "p4: its group's category, chosen in the app on p1")
        #expect(extras.work.last?.categoryKey == "3.2")
        #expect(extras.measures.contains { $0.code == "app:george:workout=tpl-1" && $0.secondary })
        // Into the existing scoring: the derived tick counts like a mark.
        let data = WeekData(week: week, goals: [GoalRecord(key: "1", title: "Gesundheit")], categories: categories, items: items,
                            marks: extras.marks, excusedDays: [V10.day(11, 20)])
        #expect(data.mark(items[0], on: V10.day(11, 16)) == .done)
    }

    @Test func goneFactsAndDuplicateFiles() {
        // The same file twice, and an older version with two workouts: counted once, the newest wins.
        let older = file("george", 16, [workout(16, id: "w16"), workout(16, id: "w16x")], at: "08:00:00")
        let twice = ExchangeDerivation.week(week, inbox: [older] + inbox + inbox, items: items, measures: measures, rules: rules,
                                            categories: categories)
        #expect(twice.entries.first { $0.code == "workouts" && $0.day == V10.day(11, 16) }?.value == 1)
        #expect(twice.marks.filter { $0.itemCode == "1.2-01" && $0.day == V10.day(11, 16) }.count == 1)
        // The fact is gone from a newer file: so is its effect.
        let emptied = file("george", 16, [], at: "21:00:00")
        let after = ExchangeDerivation.week(week, inbox: inbox + [emptied], items: items, measures: measures, rules: rules, categories: categories)
        #expect(!after.marks.contains { $0.itemCode == "1.2-01" && $0.day == V10.day(11, 16) })
        #expect(!after.entries.contains { $0.code == "workouts" && $0.day == V10.day(11, 16) })
        // Nothing in the inbox: nothing at all.
        #expect(ExchangeDerivation.week(week, inbox: [], items: items, measures: measures).isEmpty)
    }

    @Test func aFactIdCountsOnceEverywhere() throws {
        // A writer that repeats a fact id: the last row counts – in the week, in series (results) and the overview.
        let repeated = file("george", 16, [workout(16, id: "w16"), workout(16, id: "w16b"), workout(16, id: "w16")])
        #expect(ExchangeDerivation.uniqueFacts(repeated.facts).map(\.id) == ["w16b", "w16"])
        #expect(ExchangeDerivation.latest([repeated]).first?.facts.count == 2)
        let effect = ExchangeDerivation.week(week, inbox: [repeated], items: items, measures: measures, rules: rules, categories: categories)
        #expect(effect.entries.first { $0.code == "workouts" && $0.day == V10.day(11, 16) }?.value == 2)
        let source = try #require(AppSource(raw: "app:george:workout"))
        #expect(ExchangeDerivation.series(source, inbox: [repeated]) == [V10.day(11, 16): 2])
        let summary = ExchangeOverview.summaries(inbox: [repeated], today: V10.day(11, 22)).first
        #expect(summary?.factCount == 2)
        #expect(ExchangeOverview.arrivals(inbox: [repeated], today: V10.day(11, 22)).count == 2)
    }

    @Test func editorChoicesFromSourceJSON() throws {
        // Messwert-Editor "Verbundene App → Art → Eintrag aus refs".
        let refs = [ExchangeRef(id: "tpl-1", title: "Push", kind: "workout"), ExchangeRef(id: "grp-91AB", title: "Arbeit/Kunden", kind: "group"),
                    ExchangeRef(id: "kcal", title: "Kalorien", kind: "metric"), ExchangeRef(id: "any", title: "Ohne Art")]
        #expect(AppSource.kindChoices.prefix(5) == ["workout", "task", "habit", "ph", "spending"] && AppSource.kindChoices.contains("net_worth"))
        #expect(AppSource.kindChoices.allSatisfy { (AppSource(raw: "app:demo:\($0)")?.isKnown ?? false) })
        let workout = try #require(AppSource(raw: "app:george:workout=tpl-1"))
        let hours = try #require(AppSource(raw: "app:theo:ph"))
        let kcal = try #require(AppSource(raw: "app:nina:kcal"))
        let tasks = try #require(AppSource(raw: "app:theo:task"))
        #expect(workout.refChoices(refs).map(\.id) == ["tpl-1", "any"])
        #expect(hours.refChoices(refs).map(\.id) == ["grp-91AB", "any"])
        // A metric has no "Eintrag": a value fact's ref is the metric itself (Art "Protein" offering
        // "Kalorien" would save a source that matches nothing).
        #expect(kcal.refChoices(refs).isEmpty)
        #expect(workout.label(refs: refs) == "George · Workouts · Push" && workout.label(refs: []) == "George · Workouts · tpl-1")
        #expect(tasks.label(refs: refs) == "Theo · Aufgaben")
    }

    @Test func fixturesInboxAndOverview() throws {
        let theo = try V10.dayFile("Theo/exchange/days/2026-11-22.json", folder: "Theo")
        let george = try V10.dayFile("George/exchange/days/2026-11-22.json", folder: "George")
        // The inbox: one setting per source and day; a newer file replaces, the same content doesn't.
        let key = ExchangeInbox.settingKey(source: theo.source, day: V10.today)
        let parsedKey = try #require(ExchangeInbox.parse(settingKey: key))
        #expect(key == "x.theo.2026-11-22" && parsedKey.source == "theo" && parsedKey.day == V10.today)
        #expect(ExchangeInbox.keys(sources: ["theo", "george"], week: week).count == 14)
        #expect(ExchangeInbox.file(ExchangeInbox.value(theo)) == theo)
        var newer = theo
        newer.generatedAt = "2026-11-22T19:00:00+01:00"
        #expect(ExchangeInbox.shouldStore(newer, over: theo) && !ExchangeInbox.shouldStore(theo, over: newer) && !ExchangeInbox.shouldStore(theo, over: theo))
        let stored = [StoredSetting(key: key, value: ExchangeInbox.value(theo)), StoredSetting(key: key, value: ExchangeInbox.value(newer)),
                      StoredSetting(key: "x.george.2026-11-21", value: ExchangeInbox.value(george)),
                      StoredSetting(key: ExchangeInbox.sourcesKey, value: "{}")]
        #expect(ExchangeInbox.files(from: stored) == [newer], "a file under another day's key is refused")
        // Sources seen.
        let list = ExchangeSourceList().merging(ExchangeSourceInfo(source: "theo", generatedAt: "2026-11-20T08:00:00Z"))
            .merging(ExchangeSourceInfo(source: "theo", app: "Theo", generatedAt: "2026-11-22T08:00:00Z"))
            .merging(ExchangeSourceInfo(source: "theo", appVersion: "alt", generatedAt: "2026-11-01T08:00:00Z"))
        #expect(list.sources.count == 1 && list.info("Theo")?.app == "Theo")
        #expect(ExchangeSourceList(value: list.value) == list)

        // Settings → "Verbundene Apps".
        let categories = [CategoryRecord(key: "3.2", goalKey: "3", title: "Kunden (neu)")]
        let summaries = ExchangeOverview.summaries(inbox: [theo, george], rules: [], categories: categories, today: V10.today)
        let theoSummary = try #require(summaries.first { $0.source == "theo" })
        #expect(theoSummary.name == "Theo" && theoSummary.factCount == 4 && theoSummary.dayCount == 1)
        #expect(theoSummary.unassigned.map(\.ref) == ["grp-22CD"] && theoSummary.unassigned.first?.count == 2)
        let mapping = try #require(theoSummary.mappings.first)
        #expect(mapping.origin == .source && mapping.needsCheck, "the app chose „Kunden“, the category is now „Kunden (neu)“")
        #expect(mapping.originLabel == "Zuordnung aus Theo")
        #expect(summaries.first { $0.source == "george" }?.ignored == 1)
        let ruled = ExchangeOverview.summaries(inbox: [theo], rules: [LinkRule(source: "theo", ref: "grp-22CD", categoryKey: "3.2")],
                                               categories: categories, today: V10.today)
        #expect(ruled.first?.unassigned.isEmpty == true && ruled.first?.mappings.contains { $0.ref == "grp-22CD" && $0.origin == .thalia } == true)
        #expect(LinkRule(source: "Theo", ref: "grp-22CD", categoryKey: "3.2").id == LinkRule(source: "theo", ref: "grp-22CD", categoryKey: "3.4").id)

        // "Was kommt an": every fact with what it does.
        let arrivals = ExchangeOverview.arrivals(inbox: [theo, george], categories: categories, today: V10.today)
        #expect(arrivals.count == 7 && arrivals.filter(\.isUsed).count == 6)
        #expect(arrivals.first { $0.title == "Rechnung schreiben" }?.detail == "Aufgabe · Arbeit/Kunden → 3.2")
        #expect(arrivals.first { $0.title == "Arbeit/Kunden" }?.detail == "1,5 PH → 3.2", "the group's category, chosen in Theo")
        #expect(arrivals.first { $0.title == "Ablage" }?.detail == "0,5 PH · ohne Zuordnung")
        #expect(arrivals.first { !$0.isUsed }?.detail == "aus Apple Health – nicht verwendet")

        // Thalia's catalog: structure only, readable by every app.
        let week = WeekKey(year: 2026, week: 47)
        let catalog = ExchangeCatalog.thalia(
            goals: [GoalRecord(key: "3", title: "Arbeit")], categories: categories,
            measures: [MeasureRecord(week: week, code: "kunden_aufgaben", categoryKey: "3.2", title: "Aufgaben Kunden", unit: "Stück",
                                     source: MeasureSource(raw: "app:theo:task")),
                       MeasureRecord(week: week.adding(weeks: -1), code: "alt", title: "Alt")],
            results: [GoalResult(id: "res-web", goalKey: "3", title: "Website online", kind: .check)],
            segment: V10.segments.spans.last, week: week, generatedAt: V10.date("2026-11-22T05:00:00Z"),
            timeZone: try #require(TimeZone(identifier: "Europe/Vienna")))
        #expect(catalog.generatedAt == "2026-11-22T06:00:00+01:00" && catalog.measures.map(\.link) == ["app:theo:task"])
        #expect(catalog.categories.first?.segment == V10.secondID && catalog.results.first?.kind == "check")
        guard case .success(let read) = ExchangeReader.catalog(try BinisoftExchange.encode(catalog)) else {
            Issue.record("catalog round trip")
            return
        }
        #expect(read == catalog)
    }
}

/// B8: measure sources – new ones read, unknown ones kept as they are.
@Suite("v10 B8 MeasureSource")
struct V10MeasureSourceTests {
    @Test func appAndListRoundTrip() throws {
        #expect(MeasureSource(raw: "app:nina:kcal") == .app(AppSource(source: "nina", kind: "kcal")))
        let george = try #require(MeasureSource(raw: "app:george:workout=tpl-1").appSource)
        #expect(george.source == "george" && george.kind == "workout" && george.ref == "tpl-1" && george.countedKind == .workoutDone)
        #expect(MeasureSource(raw: "list:buch") == .list(kind: "buch"))
        for raw in ["app:nina:kcal", "app:george:workout=tpl-1", "app:theo:task", "app:finn:spending", "list:buch", "", "arbeit:3.2", "health:sleep"] {
            #expect(MeasureSource(raw: raw).raw == raw, "\(raw)")
        }
        // Unknown texts stay exactly as they are.
        for raw in ["health:carbs", "app:nina", "app:nina:kcal:x", "app::kcal", "list:", "x:neu:etwas", "app:Ni na:kcal"] {
            #expect(MeasureSource(raw: raw) == .other(raw), "\(raw)")
            #expect(MeasureSource(raw: raw).raw == raw)
        }
        #expect(MeasureSource(raw: "list:buch").choiceLabel == "Leseliste" && MeasureSource(raw: "app:theo:task").choiceLabel == "Verbundene App")
        #expect(MeasureSource(raw: "app:george:workout=tpl-1").label == "George · Workouts · tpl-1")
        #expect(MeasureSource(raw: "list:buch").label == "Leseliste · Buch")
        #expect(MeasureSource(raw: "app:theo:task").isComputed && !MeasureSource(raw: "health:sleep").isComputed)
        // Through the CSV and back.
        let week = WeekKey(year: 2026, week: 47)
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.measures = [MeasureRecord(week: week, code: "workouts", categoryKey: "1.2", title: "Workouts", unit: "Stück",
                                      source: MeasureSource(raw: "app:george:workout=tpl-1"))]
        let parsed = PlanCSV.parse(PlanCSV.export(doc))
        #expect(parsed.measures.first?.source.raw == "app:george:workout=tpl-1" && parsed.measures.first?.isApp == true)
    }
}

/// B9: own entries replace values of other apps per code and day.
@Suite("v10 B9 Measures.merged")
struct V10MergedTests {
    let week = WeekKey(year: 2026, week: 47)
    let monday = DayKey(year: 2026, month: 11, day: 16)

    @Test func ownReplacesStepperBaseAndClearing() {
        let measure = MeasureRecord(week: week, code: "workouts", title: "Workouts", unit: "Stück", source: MeasureSource(raw: "app:george:workout"))
        let app = [EntryRecord(code: "workouts", day: monday, value: 2)]
        // The stepper starts from the value shown: 2 from the app.
        let base = Measures.dayValue(measure, on: monday, entries: Measures.merged(own: [], external: app)) ?? 0
        #expect(base == 2)
        // "+" writes an own entry of base + 1 – it replaces the app's value, it doesn't add to it.
        let own = [EntryRecord(code: "workouts", day: monday, value: base + 1)]
        let merged = Measures.merged(own: own, external: app)
        #expect(merged == own)
        #expect(Measures.dayValue(measure, on: monday, entries: merged) == 3)
        // "Wert leeren" deletes the own entries: the app's value is back.
        #expect(Measures.dayValue(measure, on: monday, entries: Measures.merged(own: [], external: app)) == 2)
        // Other days and codes are untouched.
        let tuesday = [EntryRecord(code: "workouts", day: monday.adding(days: 1), value: 1)]
        #expect(Measures.merged(own: own, external: app + tuesday).count == 2)
    }

    @Test func healthBeforeAppsOwnBeforeBoth() {
        let health = [EntryRecord(code: "schritte", day: monday, value: 9000)]
        let app = [EntryRecord(code: "schritte", day: monday, value: 7000), EntryRecord(code: "kcal", day: monday, value: 2100)]
        #expect(Measures.merged(own: [], health: health, external: app).map(\.value) == [9000, 2100])
        let own = [EntryRecord(code: "schritte", day: monday, value: 8000)]
        #expect(Measures.merged(own: own, health: health, external: app).map(\.value) == [8000, 2100])
        // Spending from an app adds up with own spendings.
        let finn = [EntryRecord(code: "ausgaben", day: monday, value: 20)]
        let mine = [EntryRecord(code: "ausgaben", day: monday, value: 5)]
        #expect(Measures.merged(own: mine, external: finn, additive: ["ausgaben"]).count == 2)
        #expect(Measures.merged(own: mine, external: finn).count == 1)
    }
}

/// §1.1.4, §1.2.5, §1.5.4: the backup's `record` rows, the prompt and report, links over the weeks.
@Suite("v10 CSV, prompt and import")
struct V10CSVTests {
    let week = WeekKey(year: 2026, week: 47)

    @Test func recordRowsRoundTripOnlyWhenThere() throws {
        var doc = Template.week(week)
        let plain = PlanCSV.export(doc)
        #expect(!plain.contains("\nrecord,") && plain.hasPrefix(PlanCSV.header + "\n"), "without records nothing changes")
        let result = GoalResult(id: "r1", goalKey: "5", title: "Bücher, gelesen \"alle\"", target: ">=10", modifiedAt: V10.date("2026-11-20T08:00:00Z"))
        doc.records = [SettingRow(key: result.settingKey, value: result.settingValue),
                       SettingRow(key: GoalTrack.settingKey(week), value: "1.1=8.2;1.2=6.5"),
                       SettingRow(key: "x.theo.2026-11-22", value: #"{"v":1,"source":"theo","day":"2026-11-22","generatedAt":"2026-11-22T18:04:05+01:00","facts":[]}"#)]
        let text = PlanCSV.export(doc)
        #expect(text.hasPrefix(PlanCSV.header + "\n"))
        let parsed = PlanCSV.parse(text)
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped)")
        #expect(parsed.records == doc.records.sorted { $0.key < $1.key })
        #expect(try #require(GoalResult(settingValue: parsed.records.first { $0.key == result.settingKey }!.value)) == result)
        // Only v10 keys, JSON where a key holds JSON.
        let odd = PlanCSV.parse("type,id,note\nrecord,goal.start,2026-06-01\nrecord,goal.result.x,kein json\nrecord,score.2026-W47,1.1=8\ndatensatz,list.item.b,\"{\"\"id\"\":\"\"b\"\"}\"\n")
        #expect(odd.records.map(\.key) == ["score.2026-W47", "list.item.b"])
        #expect(odd.skipped.count == 2)
        // A plan of one week carries no records (the week's export for the planning conversation).
        #expect(doc.planOnly(week: week).records.isEmpty)
    }

    @Test func importKeepsTheNewerRecord() {
        let older = GoalResult(id: "r1", goalKey: "5", title: "Alt", modifiedAt: V10.date("2026-11-01T08:00:00Z"))
        let newer = GoalResult(id: "r1", goalKey: "5", title: "Neu", modifiedAt: V10.date("2026-11-02T08:00:00Z"))
        var existing = ExistingState()
        existing.records[newer.settingKey] = SettingRow(key: newer.settingKey, value: newer.settingValue)
        var doc = PlanCSV.Document()
        doc.records = [SettingRow(key: older.settingKey, value: older.settingValue),
                       SettingRow(key: "list.item.b1", value: ListItem(id: "b1", title: "Klarer Kopf").settingValue)]
        let preview = ImportPreview(document: doc, existing: existing)
        #expect(preview.records.unchanged == 1 && preview.records.creates == 1)
        #expect(preview.lines.contains("Datensätze: 1 neu · 0 geändert · 1 gleich"))
        existing.records[newer.settingKey] = SettingRow(key: older.settingKey, value: older.settingValue)
        doc.records = [SettingRow(key: newer.settingKey, value: newer.settingValue)]
        #expect(ImportPreview(document: doc, existing: existing).records.updates == 1)
        #expect(SettingRow.wins(SettingRow(key: "score.x", value: "1.1=9"), over: SettingRow(key: "score.x", value: "1.1=8")))
    }

    @Test func linksStayOverTheWeeks() throws {
        var existing = ExistingState()
        let previous = week.adding(weeks: -1)
        let app = MeasureRecord(week: previous, code: "workouts", categoryKey: "1.2", title: "Workouts", unit: "Stück",
                                source: MeasureSource(raw: "app:george:workout=tpl-1"))
        existing.measures[app.key] = app
        existing.categories["1.2"] = CategoryRecord(key: "1.2", goalKey: "1", title: "Sport / Verein")
        let csv = """
        type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
        week,\(week.string),,,,,,,,,,,,,
        measure,workouts,1.2,Workouts,,,,Stück,,tag,,,,,
        measure,seiten,1.2,Seiten,,,,Seiten,,tag,list:buch,,,,
        item,1.2-01,1.2,Krafttraining,,Mo-Fr,fix,,,,workouts,,,,
        item,1.2-02,1.2,Push gemacht,,täglich,fix,,,,app:george:workout=tpl-1,,,,
        item,1.2-03,1.2,Gelesen,,täglich,fix,,,,list:buch,,,,
        item,1.2-04,1.2,Unbekannt,,täglich,fix,,,,fehlt,,,,
        """
        let preview = ImportPreview(text: csv, existing: existing)
        let measures = preview.document.measures
        #expect(measures.first { $0.code == "workouts" }?.source.raw == "app:george:workout=tpl-1", "the source of the week before")
        #expect(measures.first { $0.code == "seiten" }?.source.raw == "list:buch", "the file's own source stays")
        #expect(preview.document.warnings.contains("KW47: bisherige Quelle übernommen, die Datei nennt keine – \u{201E}Workouts\u{201C} (app:george:workout=tpl-1, aus KW46)"))
        // app:/list: links on items need no measure row; an unknown code still gets its warning.
        let linkWarnings = preview.document.warnings.filter { $0.contains("verknüpfter Messwert") }
        #expect(linkWarnings == ["KW47 1.2-04: verknüpfter Messwert \u{201C}fehlt\u{201D} fehlt – kein Vorschlag"])
        // A measure the owner set back to manual in a later week stays manual.
        var manual = existing
        let cleared = MeasureRecord(week: week, code: "workouts", categoryKey: "1.2", title: "Workouts", unit: "Stück")
        manual.measures[cleared.key] = cleared
        #expect(ImportPreview(text: csv, existing: manual).document.measures.first { $0.code == "workouts" }?.source == .manual)
        // The same week again with the source the app has now: nothing changes.
        var again = existing
        for measure in measures { again.measures[measure.key] = measure }
        #expect(ImportPreview(text: csv, existing: again).measures.entries.allSatisfy { $0.action == .unchanged })
    }

    @Test func promptAndReportCarryTheResultsOnlyWhenGiven() throws {
        let template = Template.week(week)
        let plain = PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures,
                                    lastWeekReport: nil)
        #expect(plain == PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures,
                                         lastWeekReport: nil, results: []))
        #expect(!plain.contains(GoalResultLine.heading))
        #expect(plain.contains("app:<app>:<art>[=<ref>]") && plain.contains("list:buch = gelesene Seiten aus der Leseliste"))
        #expect(plain.contains("Verknüpfungen aus dem Ausgangsplan unverändert übernehmen"))
        let lines = [GoalResultLine(goalKey: "5", goalTitle: "Lesen", title: "Bücher gelesen", text: "3 von 10 · davon 1 in Abschnitt 2", status: "auf Kurs")]
        let withResults = PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures,
                                          lastWeekReport: nil, results: lines)
        #expect(withResults.contains("## Jahresziel-Ergebnisse (nur zur Info – nichts unaufgefordert steigern)\n- 5 Lesen · Bücher gelesen: 3 von 10 · davon 1 in Abschnitt 2 · auf Kurs"))
        // The report has the block; the prompt doesn't repeat it then.
        let input = WeekReportInput(week: WeekRecord(week: week), goals: template.goals, categories: template.categories, items: template.items,
                                    measures: template.measures, marks: [], today: V10.today, results: lines)
        let report = WeekReport.markdown(input)
        #expect(report.contains(GoalResultLine.heading))
        let withoutBlock = WeekReport.markdown(WeekReportInput(week: WeekRecord(week: week), goals: template.goals, categories: template.categories,
                                                               items: template.items, measures: template.measures, marks: [], today: V10.today))
        #expect(!withoutBlock.contains(GoalResultLine.heading))
        let both = PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures,
                                   lastWeekReport: report, results: lines)
        #expect(both.components(separatedBy: GoalResultLine.heading).count == 2, "once")

        // The goal review can name its segment and carry the results; without them it is as before.
        let review = PeriodReport(weeks: [input], goalScores: [:], ideas: [])
        #expect(review.markdown(period: V10.period) == review.markdown(period: V10.period, segment: nil, results: []))
        let segmentReview = review.markdown(period: V10.period, segment: V10.segments.spans.last, results: lines)
        #expect(segmentReview.contains("Abschnitt: Abschnitt 2 · seit KW45 2026") && segmentReview.contains(GoalResultLine.heading))
    }
}

/// §1.7: tour cards and the demo.
@Suite("v10 tour and demo")
struct V10ContentTests {
    @Test func tourCardsNameTheNewThings() throws {
        let steps = Dictionary(uniqueKeysWithValues: ThaliaTour.catalog.allSteps.map { ($0.id, $0) })
        let expected: [String: [String]] = [
            "goal-results": ["„Ergebnisse“", "„✓ über 8“", "„Wochen über 8“", "„Jahresziel eintragen“"],
            "reading": ["„Gerade dabei“", "„bis Seite“", "„+ Buch“", "„Leseliste“"],
            "segments": ["„Neuen Abschnitt beginnen…“", "„Frühere Abschnitte“", "Einstellungen → Jahresziele"],
            "connected-apps": ["„Verbundene Apps“", "„Übernehmen“", "„⇄ George · Push“", "„Ohne Zuordnung“", "Apple Health"],
        ]
        for (id, phrases) in expected {
            let step = try #require(steps[id])
            #expect(step.since == 10, "\(id)")
            for phrase in phrases {
                #expect(step.body.contains(phrase) && step.macBody.contains(phrase), "\(id): \(phrase)")
            }
        }
        #expect(steps["connected-apps"]?.body.contains(ExchangeOverview.hint) == true)
    }

    @Test func demoHasSegmentsResultsBooksAndAnInbox() throws {
        let today = DayKey(year: 2026, month: 11, day: 18)
        let content = Demo.content(today: today)
        let records = content.records
        let segments = Segments.resolve(records.segments, period: records.period)
        #expect(segments.spans.count == 2 && segments.spans[1].startWeek == today.week.adding(weeks: -5))
        #expect(segments.spans[0].endWeek == today.week.adding(weeks: -6), "segment 1 ended six weeks ago")
        #expect(records.results.map(\.kind) == [.count, .check, .value])
        let statuses = records.items.map { ListMath.status($0, progress: records.progress) }
        #expect(statuses == [.finished, .running, .planned])
        #expect(segments.span(for: try #require(records.items[0].finishedOn))?.number == 1)
        #expect(Set(ListMath.readings(records.progress, itemID: records.items[1].id).map(\.day)).count == 3)
        #expect(records.scores.count == 8 && records.scores.allSatisfy { $0.scores.count == Template.categories.count })

        // The books result counts the finished book; the weight result has its own target in segment 2.
        let books = ResultProgress.compute(records.results[0], segments: segments, today: today, items: records.items)
        #expect(books.current == 1 && books.text == "1 von 10 Bücher · davon 0 in Abschnitt 2")
        #expect(records.results[2].targets[segments.spans[1].id] == "<=86")
        #expect(ResultProgress.compute(records.results[1], segments: segments, today: today, entries: records.entries).status == .reached)

        // The connected app "Demo": a tick for Krafttraining from the workout, power-hours with and without category.
        let doc = content.document
        let week = today.week
        let excused = Set(doc.days.filter { week.contains($0.day) && DayTypes.isExcused($0.dayType) }.map(\.day))
        let marks = doc.marks.filter { $0.week == week }
        let effect = ExchangeDerivation.week(week, inbox: records.inbox, items: doc.items, measures: doc.measures, categories: doc.categories,
                                             ownMarks: marks, ownEntries: doc.entries.filter { week.contains($0.day) }, excusedDays: excused)
        let workout = try #require(effect.marks.first { $0.itemCode == Demo.workoutItem })
        #expect(workout.day == today && effect.markLabels[WeekData.markKey(Demo.workoutItem, today)] == "⇄ Demo · Push")
        #expect(!marks.contains { $0.itemCode == Demo.workoutItem && $0.day == today }, "no own mark on the workout's day")
        #expect(effect.work.map(\.categoryKey) == ["3.2"] && effect.unassignedWork.count == 1)
        #expect(effect.entries.first { $0.code == "kalorien" }?.value == 1850)

        // Everything is in the document's record rows and survives export and import.
        #expect(doc.records == records.rows && records.rows.contains { $0.key == ExchangeInbox.sourcesKey })
        let parsed = PlanCSV.parse(PlanCSV.export(doc))
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped.prefix(3))")
        #expect(parsed.records.count == records.rows.count)
        #expect(Demo.content(today: today).records == records, "deterministic")
        // The practice page: the same records, no week scores (no history).
        let practice = Demo.content(today: today, history: false).records
        #expect(practice.scores.isEmpty && practice.segments.count == 2 && practice.items.count == 3 && !practice.inbox.isEmpty)
    }

    /// Grundregel 5: the demo's connected app is the fixture folder `Demo` – the files are what the
    /// demo builds (here for Sunday 22 Nov. 2026 in Vienna), read like any other source's files.
    @Test func demoInboxIsTheFixture() throws {
        let vienna = try #require(TimeZone(identifier: "Europe/Vienna"))
        let content = Demo.content(today: V10.today)
        // Friday is sick in the demo, so the workout ("Krafttraining" Mo, Mi, Fr) is on Wednesday and
        // the power-hours on Thursday.
        #expect(content.records.inbox.map(\.day) == ["2026-11-18", "2026-11-19", "2026-11-22"])
        let built = Demo.exchangeInbox(today: V10.today, workout: V10.day(11, 18), workDay: V10.day(11, 19), timeZone: vienna)
        #expect(built.map(\.day) == content.records.inbox.map(\.day))
        for file in built {
            #expect(try V10.dayFile("Demo/exchange/days/\(file.day).json", folder: "Demo") == file, "\(file.day)")
        }
        // The demo's own files are the same apart from the time zone of the times.
        func timeless(_ file: ExchangeDayFile) -> ExchangeDayFile {
            var copy = file
            copy.generatedAt = ""
            copy.facts = file.facts.map { fact in
                var plain = fact
                plain.at = nil
                return plain
            }
            return copy
        }
        #expect(content.records.inbox.map(timeless) == built.map(timeless))
        #expect(content.records.inbox.allSatisfy { file in file.facts.allSatisfy { $0.date.map { DayKey(date: $0).string } == file.day } })

        guard case .success(let source) = ExchangeReader.source(try V10.fixture("Demo/exchange/source.json"), folder: "Demo") else {
            Issue.record("Demo source.json")
            return
        }
        #expect(source == Demo.exchangeSourceInfo(today: V10.today, timeZone: vienna) && source.displayName == "Demo")
        #expect(content.records.sources.sources.map(\.refs) == [source.refs])
    }
}
