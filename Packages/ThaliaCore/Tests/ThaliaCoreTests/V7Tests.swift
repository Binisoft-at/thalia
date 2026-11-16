import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

// v7 (version 1.6.0): days, numbers, backups, merges, German texts.

@Suite("v7 days and numbers")
struct V7CalendarTests {
    let week = WeekKey(year: 2026, week: 47)
    let vienna = TimeZone(identifier: "Europe/Vienna")!

    func date(_ day: DayKey, _ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = vienna
        return calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: hour, minute: minute))!
    }

    @Test func closingDayUsesFourOClock() {
        let day = DayKey(year: 2026, month: 11, day: 17)
        let yesterday = day.adding(days: -1)
        #expect(DayKey.closingDay(now: date(day, 3, 30), timeZone: vienna, isClosed: { _ in false }) == yesterday)
        #expect(DayKey.closingDay(now: date(day, 3, 30), timeZone: vienna, isClosed: { $0 == yesterday }) == day)
        #expect(DayKey.closingDay(now: date(day, 4, 0), timeZone: vienna, isClosed: { _ in false }) == day)
        #expect(DayKey.closingDay(now: date(day, 23, 0), timeZone: vienna, isClosed: { _ in false }) == day)
    }

    @Test func clockTimesOnDaysTheClocksChange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = vienna
        for day in [DayKey(year: 2026, month: 10, day: 25), DayKey(year: 2026, month: 3, day: 29)] {
            let late = day.date(minutes: 23 * 60, timeZone: vienna)
            #expect(calendar.component(.hour, from: late) == 23, "\(day)")
            #expect(DayKey(date: late, timeZone: vienna) == day)
            #expect(DayKey.minutes(of: late, timeZone: vienna) == 1380)
            let folded = day.date(minutes: 1470, timeZone: vienna)
            #expect(calendar.component(.hour, from: folded) == 0, "\(day)")
            #expect(calendar.component(.minute, from: folded) == 30)
            #expect(DayKey(date: folded, timeZone: vienna) == day)
        }
    }

    @Test func lettersAndRelativeDays() {
        #expect(Weekday.allCases.map(\.letter).joined() == "MDMDFSS")
        let today = week.monday
        #expect(today.relativeLabel(today: today) == "Heute")
        #expect(today.adding(days: -1).relativeLabel(today: today) == "Gestern")
        #expect(today.adding(days: 1).relativeLabel(today: today) == "Morgen")
        #expect(today.adding(days: 2).relativeLabel(today: today) == today.adding(days: 2).shortLabel)
    }

    @Test func euroToTheCent() {
        #expect(Format.euro(12.99) == "12,99 €")
        #expect(Format.euro(2.5) == "2,50 €")
        #expect(Format.euro(13) == "13 €")
        #expect(Format.euro(49.96) == "49,96 €")
        #expect(Format.euro(1234.5) == "1.234,50 €")
        #expect(Format.euro(-3.5) == "-3,50 €")
        #expect(Format.measure(2.5, unit: "€") == "2,50 €")
        #expect(Format.measure(4.5, unit: "Euro") == "4,50 €")
    }

    @Test func paceSkipsFreeDays() {
        let thursday = week.day(.thursday)
        let pace = Pace(done: 4, target: 8, days: .workdays, week: week, today: thursday, excluding: [week.day(.wednesday)])
        #expect(abs(pace.expected - 8 * 3 / 4) < 1e-9)
        let plain = Pace(done: 4, target: 8, days: .workdays, week: week, today: thursday)
        #expect(abs(plain.expected - 8 * 4 / 5) < 1e-9)
    }
}

@Suite("v7 vocabulary")
struct V7VocabularyTests {
    let week = WeekKey(year: 2026, week: 47)

    @Test func markWords() {
        #expect(Mark.allCases.map(\.label) == ["Erledigt", "Teilweise", "Nicht erledigt", "Entfällt"])
        #expect(Mark.done.label(progress: true) == "Gearbeitet")
        #expect(Mark.notApplicable.label(progress: true) == "Nicht heute")
        #expect(Mark.partial.label(progress: true) == "Teilweise")
        #expect(Mark.done.label(progress: false) == "Erledigt")
    }

    @Test func measureKinds() {
        let euro = MeasureRecord(week: week, code: "geld", title: "Geld", unit: "€")
        let spending = MeasureRecord(week: week, code: "ausgaben_privat", title: "Privat")
        let sleep = MeasureRecord(week: week, code: "schlaf", title: "Schlaf", unit: "h", source: .health(.sleep))
        let bedtime = MeasureRecord(week: week, code: "bett", title: "Bettzeit", unit: "Uhrzeit", target: Target.parse("<=22:30"))
        let open = MeasureRecord(week: week, code: "bett2", title: "Bettzeit", unit: "Uhrzeit")
        #expect(euro.isExpense)
        #expect(spending.isExpense)
        #expect(!sleep.isExpense)
        #expect(sleep.isHealth)
        #expect(!euro.isHealth)
        #expect(bedtime.defaultClockMinutes == 1350)
        #expect(open.defaultClockMinutes == 1380)
    }

    @Test func targetSentencesAndChoices() throws {
        #expect(try #require(Target.parse("<=6")).sentence(period: .day) == "Erfüllt bei ≤ 6 pro Tag")
        #expect(try #require(Target.parse("<=23:00")).sentence(period: .day, unit: "Uhrzeit") == "Erfüllt bei ≤ 23:00 pro Tag")
        #expect(try #require(Target.parse("150-180")).sentence(period: .week, unit: "g") == "Erfüllt bei 150–180 g pro Woche")
        #expect(Target.Comparison.choices.map(\.choiceLabel) == ["mindestens", "höchstens", "unter", "über", "genau", "zwischen"])
        #expect(!Units.choices.contains("PH"))
        #expect(Units.choices.contains("€") && Units.choices.first == "")
        #expect(Units.crownStep("kg") == 0.1)
        #expect(Units.crownStep("l") == 0.25)
        #expect(Units.crownStep("€") == 0.5)
        #expect(Units.crownStep("Uhrzeit") == 5)
        #expect(Units.crownStep("h") == 0.25)
        #expect(Units.crownStep("Seiten") == 1)
        #expect(DayTypes.workFreeHint == "Arbeitsfreier Tag: Arbeitspunkte zählen heute nicht")
        #expect(NoteKind.listText == "Beobachtung, Auslöser, Erfolg, Kontakt, Idee")
        #expect(ReflectionQuestion.dayNoteField == "notiz")
        #expect(ReflectionQuestion.day.first?.id == ReflectionQuestion.dayNoteField)
        #expect(ReflectionQuestion.isJournalTitle("Ins Journal eingetragen"))
        #expect(ReflectionQuestion.isJournalTitle("JOURNAL"))
        #expect(!ReflectionQuestion.isJournalTitle("Gelesen"))
    }

    @Test func workTotalsInHoursAndMinutes() {
        let blocks = [WorkRecord(id: "a", day: week.monday, categoryKey: "3.2", task: "Thema A", powerHours: 4)]
        #expect(WorkTotals(blocks).netText == "3 h 20 min")
        #expect(WorkTotals(blocks).explanation == "4 PH × 50 min = 3 h 20 min netto")
    }
}

@Suite("v7 scoring and summary")
struct V7SummaryTests {
    let week = WeekKey(year: 2026, week: 47)

    @Test func openMatchesBlank() {
        let goals = [GoalRecord(key: "1", title: "Ziel A"), GoalRecord(key: "3", title: "Ziel B")]
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Thema A"), CategoryRecord(key: "3.2", goalKey: "3", title: "Thema B")]
        let items = [
            ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Fest"),
            ItemRecord(week: week, code: "1.1-02", categoryKey: "1.1", title: "Nebenbei", secondary: true),
            ItemRecord(week: week, code: "1.1-03", categoryKey: "1.1", title: "Dreimal", schedule: .weekly(3)),
            ItemRecord(week: week, code: "1.1-04", categoryKey: "1.1", title: "Fortschritt", schedule: .progress),
            ItemRecord(week: week, code: "1.1-05", categoryKey: "1.1", title: "Erledigt"),
            ItemRecord(week: week, code: "3.2-01", categoryKey: "3.2", title: "Arbeit"),
        ]
        let wednesday = week.day(.wednesday)
        let marks: [String: Mark] = [
            WeekData.markKey("1.1-05", week.monday): .done,
            WeekData.markKey("1.1-01", week.day(.tuesday)): .partial,
            WeekData.markKey("1.1-02", week.day(.tuesday)): .missed,
        ]
        let data = WeekData(week: week, goals: goals, categories: categories, items: items, marks: marks, workFreeDays: [wednesday])
        let score = Scorer.score(data)
        for day in week.days {
            let open = data.items.filter { data.isOpenRequired($0, on: day) }.count
            #expect(open == score.days[day]?.blank, "\(day)")
        }
        #expect(data.isOpenRequired(items[5], on: week.monday))
        #expect(!data.isOpenRequired(items[5], on: wednesday), "work item on a free day")
        #expect(!data.isOpenRequired(items[1], on: week.monday), "Nebensache")
        #expect(!data.isOpenRequired(items[2], on: week.monday), "n× pro Woche")
        #expect(data.isOpenRequired(items[3], on: week.monday), "progress without a measurement")
        #expect(!data.isOpenRequired(items[4], on: week.monday), "marked")
    }

    @Test func summaryResolvesAfterMidnight() throws {
        let today = week.monday
        let tomorrow = today.adding(days: 1)
        let next = TodaySummary.placeholder.with {
            $0.dayKey = tomorrow.string
            $0.fill = 0.1
        }
        let summary = TodaySummary.placeholder.with {
            $0.dayKey = today.string
            $0.weekLabel = week.label
            $0.fill = 0.5
            $0.isClosed = true
            $0.openCount = 3
            $0.open = ["1.1 Thema A"]
            $0.nextDay = [next]
        }
        #expect(summary.resolved(for: today) == summary)
        #expect(summary.resolved(for: tomorrow) == next)
        let later = summary.resolved(for: today.adding(days: 2))
        #expect(later.isNewDay == true)
        #expect(later.fill == 0)
        #expect(!later.isClosed)
        #expect(later.open.isEmpty && later.openCount == 0)
        #expect(later.dayKey == today.adding(days: 2).string)
        #expect(later.weekLabel == "KW47", "the week's figures stay within the week")
        let nextWeek = summary.resolved(for: today.adding(days: 7))
        #expect(nextWeek.weekLabel == "KW48")
        #expect(nextWeek.weekScore == nil)

        // A snapshot of an older version (no dayKey) counts on the day it was written.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let noon = try #require(calendar.date(from: DateComponents(year: today.year, month: today.month, day: today.day, hour: 12)))
        let old = TodaySummary.placeholder.with { $0.updatedAt = noon }
        #expect(old.resolved(for: today) == old)
        #expect(old.resolved(for: tomorrow).isNewDay == true)
    }

    @Test func oldSummaryFileStaysReadable() throws {
        let json = """
        {"day":"Mo, 16. Nov.","weekLabel":"KW47","weekScore":7.1,"fill":0.5,"powerHours":2,"isClosed":false,
         "measures":[],"goalScores":[7.0,null],"goalTitles":["Ziel A","Ziel B"],"updatedAt":0,
         "open":["1.1 Thema A"],"openCount":1,"weekly":[],"powerHoursWeek":4}
        """
        let decoded = try JSONDecoder().decode(TodaySummary.self, from: Data(json.utf8))
        #expect(decoded.openCount == 1)
        #expect(decoded.dayKey == nil && decoded.nextDay == nil && decoded.isNewDay == nil)
        #expect(decoded.openKeys == nil && decoded.dueCount == nil && decoded.hasPlan == nil)
        let encoded = try JSONEncoder().encode(TodaySummary.placeholder.with { $0.nextDay = [.placeholder] })
        let back = try JSONDecoder().decode(TodaySummary.self, from: encoded)
        #expect(back.nextDay?.count == 1)
    }

    @Test func markingDoneUpdatesSummary() throws {
        let summary = TodaySummary.placeholder.with {
            $0.open = ["1.1 Thema A", "2.1 Thema B"]
            $0.openKeys = ["2026-W47|1.1-01", "2026-W47|2.1-01"]
            $0.openCount = 4
            $0.dueCount = 8
            $0.fill = 0.5
        }
        let done = summary.markingDone(itemKey: "2026-W47|1.1-01")
        #expect(done.open == ["2.1 Thema B"])
        #expect(done.openKeys == ["2026-W47|2.1-01"])
        #expect(done.openCount == 3)
        #expect(abs(done.fill - 0.625) < 1e-9)
        #expect(summary.markingDone(itemKey: "2026-W47|9-01") == summary)

        let action = WidgetMarkAction(itemKey: "2026-W47|1.1-01", dayKey: "2026-11-16", createdAt: Date(timeIntervalSince1970: 0))
        #expect(action.weekKey == "2026-W47")
        #expect(action.itemCode == "1.1-01")
        let back = try JSONDecoder().decode(WidgetMarkAction.self, from: JSONEncoder().encode(action))
        #expect(back == action)
    }

    @Test func eveningRemindersPerDay() throws {
        let json = #"{"morning":false,"morningMinutes":480,"morningDays":31,"evening":true,"eveningMinutes":1290,"weekly":true,"weeklyDay":7,"weeklyMinutes":1020}"#
        let stored = try JSONDecoder().decode(ReminderSettings.self, from: Data(json.utf8))
        #expect(stored.eveningMinutes == 1290)
        #expect(!stored.morning)
        let partial = try JSONDecoder().decode(ReminderSettings.self, from: Data(#"{"evening":false}"#.utf8))
        #expect(!partial.evening && partial.morning && partial.weeklyMinutes == 17 * 60)

        let start = week.monday
        let closed = start.adding(days: 2)
        let evenings = ReminderSettings().eveningRequests(from: start, isClosed: { $0 == closed })
        #expect(evenings.count == 6)
        #expect(!evenings.contains { $0.day == closed })
        #expect(evenings.first?.destination == "close-day:2026-11-16")
        #expect(evenings.first?.id == ReminderSettings.eveningID(start))
        #expect(ReminderSettings().eveningRequests(from: start, isClosed: { _ in false }).count == 7)
        var off = ReminderSettings()
        off.evening = false
        #expect(off.eveningRequests(from: start, isClosed: { _ in false }).isEmpty)

        let mac = ReminderSettings.macDefault
        #expect(!mac.morning && !mac.evening && !mac.weekly)
        #expect(ReminderSettings.eveningID(start) == "thalia.evening.2026-11-16")
        #expect(ReminderSettings.snoozeActionID == "thalia.snooze")
        #expect(ReminderSettings.eveningCategoryID == "thalia.evening")
        #expect(ReminderSettings.snoozeMinutes == 30)
        #expect(ReminderSettings().requests().first?.body == "Kurz in Thalia schauen: was heute ansteht – und ob gestern noch offen ist.")
    }

    @Test func journalFromItem() {
        let goals = [GoalRecord(key: "2", title: "Ziel C")]
        let categories = [CategoryRecord(key: "2.2", goalKey: "2", title: "Thema C")]
        let item = ItemRecord(week: week, code: "2.2-01", categoryKey: "2.2", title: "Ins Journal eingetragen")
        let monday = week.monday
        let tuesday = week.day(.tuesday)
        let input = WeekReportInput(
            week: WeekRecord(week: week), goals: goals, categories: categories, items: [item], measures: [],
            marks: [MarkRecord(week: week, itemCode: "2.2-01", day: monday, mark: .done)],
            reviews: [ReviewRecord(scope: monday.string, field: ReflectionQuestion.journalField, text: "nein"),
                      ReviewRecord(scope: tuesday.string, field: ReflectionQuestion.journalField, text: "nein")],
            today: tuesday
        )
        let rows = WeekReport.markdown(input).components(separatedBy: "\n")
        let mondayRow = rows.first { $0.hasPrefix("| \(monday.shortLabel) |") }
        let tuesdayRow = rows.first { $0.hasPrefix("| \(tuesday.shortLabel) |") }
        #expect(mondayRow?.contains("| – | ✓ |") == true, "\(mondayRow ?? "")")
        #expect(tuesdayRow?.contains("| – | ✗ |") == true, "\(tuesdayRow ?? "")")
    }
}

@Suite("v7 backup, import, plan")
struct V7ImportTests {
    let week = WeekKey(year: 2026, week: 47)

    func state(from doc: PlanCSV.Document) -> ExistingState {
        var state = ExistingState()
        for week in doc.weeks { state.weeks[week.week.string] = week }
        for day in doc.days { state.days[day.day.string] = day }
        for item in doc.items { state.items[item.key] = item }
        for measure in doc.measures { state.measures[measure.key] = measure }
        for mark in doc.marks { state.marks[mark.key] = mark }
        for entry in doc.entries {
            var copy = entry
            copy.order = 0
            state.entries[entry.key] = copy
        }
        state.closedDays = doc.closedDays
        state.closedWeeks = doc.closedWeeks
        return state
    }

    func spendings(estimate: Bool) -> [EntryPart] {
        [EntryPart(value: 4.5, note: "Kaffee", minutes: 490),
         EntryPart(value: 12.9, note: "Mittagessen", minutes: 750),
         EntryPart(value: 3.2, note: "Bus", minutes: 1080, estimate: estimate)]
    }

    @Test func backupRoundTrip() {
        let day = week.monday
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week, title: "Thema A")]
        doc.measures = [MeasureRecord(week: week, code: "ausgaben", categoryKey: "8", position: 1, title: "Ausgaben", unit: "€")]
        doc.entries = [PlanCSV.combined(EntryRecord(code: "ausgaben", day: day, value: nil, parts: spendings(estimate: true)))]
        doc.closedDays = [day]
        doc.closedWeeks = [week]

        let csv = PlanCSV.export(doc)
        #expect(csv.contains("entry,ausgaben,,12:30,,,,,,,,einzeln,\(day.string),12.9,Mittagessen"))
        #expect(csv.contains("day,\(day.string),,,,,,,,,,abgeschlossen,,,"))
        let parsed = PlanCSV.parse(csv)
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped)")
        #expect(parsed.closedDays == [day])
        #expect(parsed.closedWeeks == [week])
        #expect(parsed.days.isEmpty, "a closing alone leaves the day's type alone")
        let entry = parsed.entries.first
        #expect(parsed.entries.count == 1)
        #expect(entry?.parts.map(\.minutes) == [490, 750, 1080])
        #expect(entry?.parts.map(\.note) == ["Kaffee", "Mittagessen", "Bus"])
        #expect(entry?.parts.last?.estimate == true)
        #expect(entry?.note == "Kaffee; Mittagessen; Bus")

        let preview = ImportPreview(document: parsed, existing: state(from: doc))
        #expect(preview.entries.entries.allSatisfy { $0.action == .unchanged })
        #expect(preview.newClosedDays.isEmpty && preview.newClosedWeeks.isEmpty)
        #expect(!preview.hasChanges, "\(preview.lines)")

        let fresh = ImportPreview(document: parsed, existing: ExistingState())
        #expect(fresh.newClosedDays == [day])
        #expect(fresh.newClosedWeeks == [week])
        #expect(fresh.lines.contains("Abschlüsse: 1 Tag, 1 Woche"), "\(fresh.lines)")
    }

    @Test func oldBackupStillImports() {
        let day = week.monday
        let text = """
        type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
        week,2026-W47,,Thema A,,,,,,,,,,,
        entry,ausgaben,,,,,,,,,,,2026-11-16,20.6,Kaffee; Mittagessen; Bus
        """
        let parsed = PlanCSV.parse(text)
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped)")
        #expect(parsed.entries.first?.parts.isEmpty == true)
        #expect(parsed.closedDays.isEmpty)
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week, title: "Thema A")]
        doc.entries = [PlanCSV.combined(EntryRecord(code: "ausgaben", day: day, value: nil, parts: spendings(estimate: false)))]
        let preview = ImportPreview(document: parsed, existing: state(from: doc))
        #expect(preview.entries.entries.first?.action == .unchanged, "same total → nothing is merged")
        #expect(!preview.hasChanges, "\(preview.lines)")
    }

    @Test func replacementText() {
        var state = ExistingState()
        let first = ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Thema A")
        let second = ItemRecord(week: week, code: "1.1-02", categoryKey: "1.1", position: 2, title: "Thema B")
        state.items = [first.key: first, second.key: second]
        for (index, mark) in [Mark.done, .missed, nil].enumerated() {
            let record = MarkRecord(week: week, itemCode: "1.1-01", day: week.days[index], mark: mark)
            state.marks[record.key] = record
        }
        let entry = EntryRecord(code: "seiten", day: week.monday, value: 12)
        state.entries[entry.key] = entry

        var doc = PlanCSV.Document()
        var changed = first
        changed.title = "Thema A, neu"
        doc.items = [changed, second]
        doc.plannedWeeks = [week]
        let preview = ImportPreview(document: doc, existing: state)
        #expect(preview.replacedWeeks == [week])
        #expect(preview.replacements.first?.text == "KW47 wird ersetzt – 2 Markierungen und 1 Wert gehen ins Archiv.")
        #expect(preview.replacements.first?.buttonTitle == "KW47 ersetzen")
        #expect(preview.replacements.first?.marks == 2 && preview.replacements.first?.values == 1)
        #expect(preview.lines.contains("KW47 wird ersetzt – 2 Markierungen und 1 Wert gehen ins Archiv."))
    }

    @Test func promptCarriesPlan() {
        let source = WeekKey(year: 2026, week: 46)
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: source, title: "Thema A", recordedScore: 7)]
        doc.items = [ItemRecord(week: source, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Thema B geübt")]
        doc.marks = [MarkRecord(week: source, itemCode: "1.1-01", day: source.monday, mark: .done)]
        doc.entries = [EntryRecord(code: "seiten", day: source.monday, value: 12)]
        let planOnly = doc.planOnly(week: source)
        #expect(planOnly.marks.isEmpty && planOnly.entries.isEmpty)
        #expect(planOnly.weeks.first?.recordedScore == nil)
        let plan = PlanCSV.export(planOnly)
        let text = PlanPrompt.text(for: week, goals: Template.goals, categories: Template.categories, measures: [], lastWeekReport: nil,
                                   currentPlan: plan, currentPlanWeek: source,
                                   trend: ["KW43: Wertung 7,1 · 22 von 28 PH", "KW44: Wertung – · 20 PH"])
        #expect(text.contains("## Plan von KW46 (Ausgangspunkt)"))
        #expect(text.contains("Übernimm diese Zeilen für KW47 (Datum in die neue Woche verschieben), ändere nur, was ich unten verlange, und nenne jede Änderung unter dem Codeblock."))
        #expect(text.contains("item,1.1-01,1.1,Thema B geübt"))
        #expect(!text.contains("mark,1.1-01"))
        #expect(text.contains("## Tendenz der letzten 4 Wochen"))
        #expect(text.contains("KW43: Wertung 7,1 · 22 von 28 PH"))
        #expect(text.hasSuffix("## Mein Rückblick und Plan für KW47:\n"))
        let without = PlanPrompt.text(for: week, goals: Template.goals, categories: Template.categories, measures: [], lastWeekReport: nil)
        #expect(!without.contains("Ausgangspunkt") && !without.contains("Tendenz"))
    }

    @Test func repeatPlan() {
        let source = WeekKey(year: 2026, week: 46)
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: source, title: "Thema A", details: "Kontext", recordedScore: 7)]
        doc.days = [DayRecord(day: source.day(.wednesday), dayType: "Frei", note: "Feiertag")]
        doc.measures = [MeasureRecord(week: source, code: "seiten", categoryKey: "5", position: 1, title: "Seiten", unit: "Seiten",
                                      target: Target.parse(">=100"), period: .week)]
        doc.items = [ItemRecord(week: source, code: "5-01", categoryKey: "5", position: 1, title: "Gelesen")]
        doc.marks = [MarkRecord(week: source, itemCode: "5-01", day: source.monday, mark: .done)]
        doc.entries = [EntryRecord(code: "seiten", day: source.monday, value: 20)]
        doc.closedDays = [source.monday]
        doc.closedWeeks = [source]

        let repeated = doc.repeated(from: source, to: week)
        #expect(repeated.days == [DayRecord(day: source.day(.wednesday).adding(days: 7), dayType: "Frei", note: "Feiertag")])
        #expect(repeated.items.map(\.code) == ["5-01"])
        #expect(repeated.items.allSatisfy { $0.week == week })
        #expect(repeated.measures.map(\.code) == ["seiten"])
        #expect(repeated.measures.allSatisfy { $0.week == week })
        #expect(repeated.marks.isEmpty && repeated.entries.isEmpty && repeated.work.isEmpty)
        #expect(repeated.closedDays.isEmpty && repeated.closedWeeks.isEmpty)
        #expect(repeated.weeks.first?.week == week)
        #expect(repeated.weeks.first?.title == "Thema A")
        #expect(repeated.weeks.first?.details == "Kontext")
        #expect(repeated.weeks.first?.recordedScore == nil)
        let parsed = PlanCSV.parse(PlanCSV.export(repeated), knownCategories: ["5": "Thema C"])
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped)")
        #expect(parsed.plannedWeeks == [week])
        #expect(parsed.items.count == 1)
    }

    @Test func periodReport() {
        let first = WeekKey(year: 2026, week: 46)
        let goals = [GoalRecord(key: "1", title: "Ziel A"), GoalRecord(key: "3", title: "Ziel B")]
        let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Thema A"), CategoryRecord(key: "3.2", goalKey: "3", title: "Thema B")]
        func input(_ shown: WeekKey, missed: Int, pages: Double, powerHours: Double) -> WeekReportInput {
            let item = ItemRecord(week: shown, code: "1.1-01", categoryKey: "1.1", title: "Dehnen")
            let measure = MeasureRecord(week: shown, code: "seiten", categoryKey: "1.1", title: "Seiten", unit: "Seiten", period: .week)
            let marks = (0..<missed).map { MarkRecord(week: shown, itemCode: "1.1-01", day: shown.days[$0], mark: .missed) }
            return WeekReportInput(
                week: WeekRecord(week: shown), goals: goals, categories: categories, items: [item], measures: [measure], marks: marks,
                entries: [EntryRecord(code: "seiten", day: shown.monday, value: pages)],
                work: [WorkRecord(id: "w\(shown.week)", day: shown.monday, categoryKey: "3.2", task: "Thema B", powerHours: powerHours)],
                today: shown.sunday
            )
        }
        let report = PeriodReport(
            weeks: [input(week, missed: 1, pages: 40, powerHours: 3), input(first, missed: 2, pages: 20, powerHours: 5)],
            goalScores: [first: ["1": 6, "3": 8], week: ["1": 8]],
            ideas: [NoteRecord(id: "a", day: first.monday, kind: .idea, text: "Idee A"),
                    NoteRecord(id: "b", day: week.monday, kind: .idea, text: "Idee B")]
        )
        #expect(report.start == first && report.end == week)
        #expect(report.goals.first { $0.key == "1" }?.average == 7)
        #expect(report.goals.first { $0.key == "3" }?.average == 8)
        #expect(report.goals.first { $0.key == "1" }?.firstFour == 7)
        #expect(report.missed == [PeriodReport.MissedItem(title: "Dehnen", categoryKey: "1.1", count: 3)])
        #expect(report.work == [PeriodReport.WorkLine(categoryKey: "3.2", title: "Thema B", powerHours: 8)])
        #expect(report.measures.first?.first == 20)
        #expect(report.measures.first?.last == 40)
        #expect(report.ideas.map(\.text) == ["Idee B", "Idee A"])
        let text = report.markdown(period: .foundationYear)
        #expect(text.hasPrefix("# Zielüberprüfung KW49"))
        #expect(text.contains("- 1.1 Dehnen: 3× ✗"))
        #expect(text.contains("- 3.2 Thema B: 8 PH"))
        #expect(text.contains("Idee B"))
        #expect(text.contains("| 1 Ziel A | 7 |"))
    }
}

@Suite("v7 merges and sync texts")
struct V7MergeTests {
    let early = Date(timeIntervalSince1970: 1_000)
    let middle = Date(timeIntervalSince1970: 2_000)
    let late = Date(timeIntervalSince1970: 3_000)

    @Test func mergeDays() {
        let merged = DuplicateMerge.day([
            DayVersion(dayType: "Familientag", note: "Thema A", closedAt: nil, modifiedAt: early),
            DayVersion(dayType: "", note: "", closedAt: middle, modifiedAt: late),
        ])
        #expect(merged?.dayType == "Familientag", "an empty newer type loses against an older filled one")
        #expect(merged?.note == "Thema A")
        #expect(merged?.closedAt == middle, "closed wins")
        #expect(merged?.modifiedAt == late)
        let reopened = DuplicateMerge.day([
            DayVersion(dayType: "", note: "", closedAt: early, modifiedAt: early),
            DayVersion(dayType: "Frei", note: "", closedAt: nil, modifiedAt: late),
        ])
        #expect(reopened?.closedAt == early)
        #expect(reopened?.dayType == "Frei")
        #expect(DuplicateMerge.day([]) == nil)
    }

    @Test func mergeWeeks() {
        let open = WeekVersion(title: "Thema B", details: "", recordedScore: nil, scoringModel: "", closedAt: nil, importedAt: middle,
                               finalScore: nil, finalGoalScores: "", finalGoalsScored: 0, modifiedAt: late)
        let closed = WeekVersion(title: "", details: "Kontext", recordedScore: nil, scoringModel: "alt", closedAt: middle, importedAt: nil,
                                 finalScore: 7.5, finalGoalScores: "1=7.5", finalGoalsScored: 1, modifiedAt: early)
        let merged = DuplicateMerge.week([open, closed])
        #expect(merged?.finalScore == 7.5, "the score comes from the closed version")
        #expect(merged?.finalGoalScores == "1=7.5")
        #expect(merged?.finalGoalsScored == 1)
        #expect(merged?.closedAt == middle)
        #expect(merged?.title == "Thema B")
        #expect(merged?.details == "Kontext")
        #expect(merged?.scoringModel == "")
        #expect(merged?.importedAt == middle)
        #expect(merged?.modifiedAt == late)
        #expect(DuplicateMerge.week([]) == nil)
    }

    @Test func syncStatusInGerman() {
        #expect(SyncGerman.storage(.iCloud(container: "iCloud.example")) == "Auf diesem Gerät + iCloud")
        #expect(SyncGerman.storage(.local(reason: nil)) == "Nur auf diesem Gerät")
        #expect(SyncGerman.storage(.memory(reason: nil)) == "Vorübergehend (nicht gesichert)")
        #expect(SyncGerman.storage(.demo) == "Beispieldaten (nicht gesichert)")
        let accounts: [ICloudAccount] = [.unknown, .available, .noAccount, .restricted, .temporarilyUnavailable, .couldNotDetermine]
        #expect(accounts.map(SyncGerman.account) == ["Wird geprüft …", "Angemeldet", "Nicht angemeldet", "Eingeschränkt",
                                                     "Vorübergehend nicht verfügbar", "Unbekannt"])

        let relative: (Date) -> String = { _ in "vor 5 Minuten" }
        let cloud = StorageMode.iCloud(container: "iCloud.example")
        func summary(_ state: SyncState) -> String { SyncGerman.summary(state, relative: relative) }
        #expect(summary(SyncState(mode: cloud, account: .available, lastSync: late)) == "An · zuletzt vor 5 Minuten")
        #expect(summary(SyncState(mode: cloud, account: .available)) == "An")
        #expect(summary(SyncState(mode: cloud, account: .available, isSyncing: true)) == "Synchronisiert …")
        #expect(summary(SyncState(mode: cloud, account: .available, lastError: "x")) == "Synchronisiert gerade nicht")
        #expect(summary(SyncState(mode: cloud, account: .noAccount)) == "Aus – in iCloud anmelden")
        #expect(summary(SyncState(mode: cloud, account: .restricted)) == "Aus – iCloud ist eingeschränkt")
        #expect(summary(SyncState(mode: .local(reason: nil))) == "Aus – nur dieses Gerät")
        #expect(summary(SyncState(mode: .demo)) == "Aus – Beispieldaten")
        #expect(summary(SyncState(mode: .memory(reason: nil))) == "Aus – Daten können nicht gesichert werden")

        #expect(SyncGerman.reason(.local(reason: "No iCloud container in Info.plist (AppCloudKitContainer)"))
            == "Kein iCloud-Container eingerichtet – deine Daten bleiben auf diesem Gerät.")
        #expect(SyncGerman.reason(.local(reason: "iCloud store couldn't open: error"))
            == "iCloud-Speicher ließ sich nicht öffnen – deine Daten bleiben auf diesem Gerät.")
        #expect(SyncGerman.reason(cloud) == nil)
        #expect(SyncGerman.reason(.demo) == nil)
        #expect(SyncGerman.reason(.memory(reason: "x")) != nil)
    }

    @Test func syncErrorsInGerman() {
        let cases: [(raw: String, german: String)] = [
            ("Cannot create or modify field 'CD_example' in record type", "CloudKit-Schema"),
            ("Quota exceeded", "iCloud-Speicher ist voll"),
            ("Not authenticated", "bei iCloud an"),
            ("The Internet connection appears to be offline.", "Kein Netz"),
            ("Zone not found", "richtet den Speicher"),
        ]
        for (raw, german) in cases {
            #expect(SyncGerman.error(raw, appName: "Thalia").contains(german), "raw: \(raw)")
            let english = SyncErrorText.describe(raw, appName: "Thalia")
            #expect(english != raw, "the kit knows \(raw)")
            #expect(SyncGerman.error(english, appName: "Thalia").contains(german), "kit: \(english)")
        }
        #expect(SyncGerman.error("Etwas Unbekanntes", appName: "Thalia") == "iCloud meldet: Etwas Unbekanntes")
    }
}
