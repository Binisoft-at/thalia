import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

// TASKS-v9 §2: archive weeks, category and goal grades, two week scores, the new prompt.
// Neutral labels only ("Sport / Verein", "Lesen", "Sonderwoche").

/// A1 and A4: means over the values that exist, and the week under today's rules.
@Suite("v9 means and recalculation")
struct V9RecalculationTests {
    let week = WeekKey(year: 2026, week: 43)
    let goals = [GoalRecord(key: "1", title: "Gesundheit"), GoalRecord(key: "2", title: "Lernen"), GoalRecord(key: "3", title: "Arbeit")]
    let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Sport / Verein"), CategoryRecord(key: "1.2", goalKey: "1", title: "Schlaf"),
                      CategoryRecord(key: "2.1", goalKey: "2", title: "Lesen"), CategoryRecord(key: "3.1", goalKey: "3", title: "Fokus")]

    func grade(_ id: String, _ title: String, _ weekday: Weekday? = nil, _ value: Double, kind: ArchiveGrade.Kind = .category,
               count: Int? = nil) -> ArchiveGrade {
        ArchiveGrade(week: week, kind: kind, id: id, title: title, day: weekday.map(week.day), value: value, source: "Scan", count: count)
    }

    /// A1: sum ÷ count of the values that exist; real zeros count; only the display rounds.
    @Test func meanCountsRealZerosAndOnlyTheDisplayRounds() throws {
        let mean = try #require(ArchiveWeek.mean([0, 10, 10]))
        #expect(abs(mean - 20.0 / 3) < 1e-12, "not rounded")
        #expect(Format.score(mean) == "6,67")
        #expect(ArchiveWeek.mean([10, 10, 0, 0]) == 5)
        #expect(ArchiveWeek.mean([]) == nil, "n = 0 stays open")
        // The week value of a label: its day grades (n = their number), or its explicit week row.
        let archive = ArchiveWeek(week: week, grades: [grade("", "Sport / Verein", .monday, 0), grade("", "Sport / Verein", .tuesday, 10),
                                                       grade("", "Sport / Verein", .friday, 10), grade("2.1", "Lesen", nil, 5, count: 4)])
        let sportLine = try #require(archive.categoryLines.first { $0.title == "Sport / Verein" })
        #expect(sportLine.count == 3 && Format.score(sportLine.value) == "6,67")
        #expect(sportLine.sortedDays.map(\.value) == [0, 10, 10])
        #expect(archive.weeklyGrade(.category, id: "2.1") == 5)
        #expect(archive.categoryLines.first { $0.id == "2.1" }?.count == 4)
    }

    /// A4: Saturday is a holiday with grade 0 – it doesn't count today; a goal is the mean of its
    /// categories, a goal with only its own grade keeps it, a grade without mapping changes nothing.
    @Test func recalculationLeavesOutHolidaysAndUnmappedGrades() throws {
        let grades = [
            grade("1.1", "Sport / Verein", .monday, 8), grade("1.1", "Sport / Verein", .tuesday, 6),
            grade("1.1", "Sport / Verein", .saturday, 0),
            grade("1.2", "Schlaf", .monday, 10), grade("1.2", "Schlaf", .saturday, 0),
            grade("1", "Gesundheit", nil, 3, kind: .goal),
            grade("2", "Lernen", nil, 8, kind: .goal),
            grade("", "Sonderwoche", nil, 0),
        ]
        let archive = ArchiveWeek(week: week, grades: grades)
        let saturday = week.day(.saturday)
        let today = archive.recalculated(categories: categories, goals: goals, excusedDays: [saturday])
        #expect(today.categories["1.1"] == 7, "(8 + 6) / 2 – the holiday's 0 is left out")
        #expect(today.categoryCounts["1.1"] == 2)
        #expect(today.categories["1.2"] == 10)
        #expect(today.goals["1"] == 8.5, "mean of its categories – its own grade 3 doesn't count")
        #expect(today.goals["2"] == 8, "no category grades: its own grade")
        #expect(today.goals["3"] == nil, "nothing for goal 3")
        #expect(today.overall == 8.25, "mean of the goals, equally weighted")
        #expect(today.excludedDays == [saturday])
        #expect(today.unmapped == 1)
        #expect(today.excludedText(dayTypes: [saturday: "Urlaub"]) == "ohne 1 Urlaubstag")
        #expect(today.excludedText(dayTypes: [:]) == "ohne 1 Tag Krank/Urlaub")
        #expect(today.goalScoresText == "1=8.5;2=8")
        // The grade without mapping changes nothing.
        let without = ArchiveWeek(week: week, grades: grades.filter { $0.isMapped })
        #expect(without.recalculated(categories: categories, goals: goals, excusedDays: [saturday]).overall == today.overall)
        // Without excused days the real 0 counts: (8 + 6 + 0) / 3.
        let all = archive.recalculated(categories: categories, goals: goals, excusedDays: [])
        #expect(abs((all.categories["1.1"] ?? 0) - 14.0 / 3) < 1e-12)
        #expect(all.excludedDays.isEmpty && all.excludedText() == nil)
        // A category the app doesn't have never counts.
        let unknown = ArchiveWeek(week: week, grades: [grade("9.9", "Alt", .monday, 2)])
        let unknownResult = unknown.recalculated(categories: categories, goals: goals, excusedDays: [])
        #expect(unknownResult.overall == nil && unknownResult.unmapped == 1)
        // Without grades: nothing.
        #expect(ArchiveWeek(week: week).recalculated(categories: categories, goals: goals, excusedDays: []).overall == nil)
        // Only a week grade (only the mean is in the records): that one.
        let weekly = ArchiveWeek(week: week, grades: [grade("1.2", "Schlaf", nil, 6, count: 4)])
        let weeklyResult = weekly.recalculated(categories: categories, goals: goals, excusedDays: [saturday])
        #expect(weeklyResult.categories["1.2"] == 6 && weeklyResult.categoryCounts["1.2"] == 4 && weeklyResult.overall == 6)
        // No goal list: the goals of the categories.
        #expect(archive.recalculated(categories: categories, goals: [], excusedDays: [saturday]).overall == 8.25)
    }
}

/// A2, A5: the new row types, their checks, the writer and the stored setting.
@Suite("v9 grades in the CSV")
struct V9CSVTests {
    let week = WeekKey(year: 2026, week: 43)
    let header = PlanCSV.header + ",count"

    var sample: String {
        """
        \(header)
        week,2026-W43,,,,,,,,,,,,9.28,Scan S. 19,
        category_score,1.2,,Sport / Verein,,,,,,,,,2026-10-19,10,Scan S. 19,
        category_score,1.2,,Sport / Verein,,,,,,,,,Di,0,Scan S. 19,
        category_score,5,,Lesen,,,,,,,,,,"6,5",Scan S. 19,4
        category_score,,,Sonderwoche,,,,,,,,,,7,Scan S. 19,
        goal_score,5,,Lernen,,,,,,,,,,8,Scan S. 19,
        category_score,1.1,,Zu hoch,,,,,,,,,,11,,
        category_score,1.1,,Unlesbar,,,,,,,,,,abc,,
        category_score,1.1,,,,,,,,,,,,5,,
        kategorie_note,2.1,,Alias,,,,,,,,,,3,,
        zielnote,2,,Alias Ziel,,,,,,,,,,4,,2
        """
    }

    /// A2: day grades (date or weekday), a week grade with count, a grade without id, a comma value,
    /// a goal grade; out of range, unreadable and without title are skipped; the aliases.
    @Test func gradesAreReadWithTheirChecks() throws {
        let doc = PlanCSV.parse(sample)
        #expect(doc.grades.count == 7, "\(doc.grades)")
        #expect(doc.skipped.count == 3, "\(doc.skipped)")
        #expect(doc.skipped.contains { $0.contains("Zeile 8") && $0.contains("nicht zwischen 0 und 10") })
        #expect(doc.skipped.contains { $0.contains("Zeile 9") && $0.contains("abc") && $0.contains("nicht lesbar") })
        #expect(doc.skipped.contains { $0.contains("Zeile 10") && $0.contains("ohne Bezeichnung") })
        #expect(doc.weeks.first?.recordedScore == 9.28)
        #expect(doc.weekNotes[week] == "Scan S. 19")
        let monday = try #require(doc.grades.first { $0.day == week.monday })
        #expect(monday.id == "1.2" && monday.title == "Sport / Verein" && monday.value == 10 && monday.source == "Scan S. 19")
        #expect(doc.grades.first { $0.day == week.day(.tuesday) }?.value == 0, "a real 0, by weekday")
        let reading = try #require(doc.grades.first { $0.title == "Lesen" })
        #expect(reading.day == nil && reading.value == 6.5 && reading.count == 4, "comma value, week grade with count")
        #expect(doc.grades.first { $0.title == "Sonderwoche" }?.isMapped == false)
        let goal = try #require(doc.grades.first { $0.kind == .goal && $0.id == "5" })
        #expect(goal.title == "Lernen" && goal.value == 8 && goal.day == nil)
        #expect(doc.grades.first { $0.title == "Alias" }?.kind == .category)
        #expect(doc.grades.first { $0.title == "Alias Ziel" }?.kind == .goal)
        #expect(doc.grades.first { $0.title == "Alias Ziel" }?.count == 2)
        #expect(doc.grades.allSatisfy { $0.week == week })
        #expect(doc.rowCount == 8, "one week row and seven grades")
        // Without anything to check against, the ids stay; the grade without id is listed once.
        #expect(doc.warnings == ["KW43: ohne Zuordnung, nur im Archiv (zählt nicht): \u{201C}Sonderwoche\u{201D}"], "\(doc.warnings)")
        for alias in ["kategoriennote", "categoryscore", "ziel_note", "goalscore"] {
            #expect(PlanCSV.RowType(token: alias) != nil, "\(alias)")
        }
        #expect(PlanCSV.RowType(token: "category_score") == .categoryScore)
        #expect(PlanCSV.RowType(token: "goal_score") == .goalScore)
        // German column names: "anzahl" and "n" are the count.
        let german = PlanCSV.parse("typ,id,titel,wert,anzahl\nwoche,2026-W43,,,\nkategoriennote,2.1,Lesen,7,3\n")
        #expect(german.grades.first?.count == 3)
        #expect(PlanCSV.parse("type,id,title,value,n\nweek,2026-W43,,,\ngoal_score,1,Ziel,7,5\n").grades.first?.count == 5)
    }

    /// A2: written and read again gives the same – the file and the stored setting.
    @Test func writingAndReadingGivesTheSame() {
        let doc = PlanCSV.parse(sample)
        let text = PlanCSV.export(doc)
        #expect(text.hasPrefix(header + "\n"), "the count column only because there are grades")
        let again = PlanCSV.parse(text)
        #expect(again.skipped.isEmpty, "\(again.skipped)")
        #expect(again.archive(week) == doc.archive(week))
        #expect(again.archive(week).grades.count == 7)
        #expect(again.weeks.first?.recordedScore == 9.28 && again.weekNotes[week] == "Scan S. 19")
        // Sheet order: categories by id, then without mapping, then goals.
        #expect(doc.archive(week).grades.map(\.title) == ["Sport / Verein", "Sport / Verein", "Alias", "Lesen", "Sonderwoche",
                                                           "Alias Ziel", "Lernen"])
        // The setting (decision 7).
        let archive = doc.archive(week)
        #expect(ArchiveWeek(csv: archive.csv, week: week) == archive)
        #expect(archive.source == "Scan S. 19")
        #expect(ArchiveWeek.settingKey(week) == "archive.2026-W43")
        #expect(ArchiveWeek.week(settingKey: "archive.2026-W43") == week)
        #expect(ArchiveWeek.week(settingKey: "goalPeriod") == nil)
        #expect(ArchiveWeek(csv: "", week: week).isEmpty)
        #expect(ArchiveWeek(csv: archive.csv, week: week.adding(weeks: 1)).isEmpty, "only the week's grades")
        // Exact values, even with many decimals: a stored archive reads back unchanged.
        let precise = ArchiveWeek(week: week, grades: [ArchiveGrade(week: week, kind: .category, title: "Lesen", value: 20.0 / 3),
                                                      ArchiveGrade(week: week, kind: .goal, id: "1", title: "Ziel", value: 9.19234)])
        #expect(ArchiveWeek(csv: precise.csv, week: week) == precise)
        #expect(ArchiveGrade.csvValue(6.5) == "6.5" && ArchiveGrade.csvValue(10) == "10")
        // Without grades the header stays exactly as before.
        var plain = PlanCSV.Document()
        plain.weeks = [WeekRecord(week: week, recordedScore: 7.5)]
        let plainText = PlanCSV.export(plain)
        #expect(plainText.hasPrefix(PlanCSV.header + "\n") && !plainText.contains("count"))
        #expect(plainText.contains("week,2026-W43,,,,,,,,,,,2026-10-19,7.5,\n"))
    }

    /// Updated by key: the same label and day replaces, a new one is added (decision 3).
    @Test func gradesAreUpdatedByKey() {
        let stored = ArchiveWeek(week: week, grades: [
            ArchiveGrade(week: week, kind: .category, id: "1.2", title: "Sport", day: week.monday, value: 4),
            ArchiveGrade(week: week, kind: .category, title: "Sonderwoche", value: 5),
        ], source: "alt")
        let merged = stored.merging([
            ArchiveGrade(week: week, kind: .category, id: "1.2", title: "Sport / Verein", day: week.monday, value: 9),
            ArchiveGrade(week: week, kind: .category, title: "sonderwoche ", value: 6),
            ArchiveGrade(week: week, kind: .goal, id: "1", title: "Gesundheit", value: 7),
        ], source: "")
        #expect(merged.grades.count == 3)
        #expect(merged.grades.first { $0.id == "1.2" }?.value == 9 && merged.grades.first { $0.id == "1.2" }?.title == "Sport / Verein")
        #expect(merged.grades.first { $0.title.lowercased().hasPrefix("sonderwoche") }?.value == 6, "the title is normalized for the key")
        #expect(merged.source == "alt", "an empty source keeps the stored one")
        #expect(ArchiveGrade(week: week, kind: .goal, title: "Ziel", day: week.monday, value: 5, count: 3).day == nil,
                "a goal's grade is the week's")
        // A row twice: the last one counts, with a warning.
        let twice = PlanCSV.parse("type,id,title,date,value\nweek,2026-W43,,,\ncategory_score,1.2,Sport,Mo,4\ncategory_score,1.2,Sport,Mo,6\n")
        #expect(twice.grades.count == 1 && twice.grades.first?.value == 6)
        #expect(twice.warnings.contains { $0.contains("doppelt") })
    }

    /// A5: an id that is no category (goal) of the app stays without mapping, with a warning.
    @Test func unknownIdsStayWithoutMapping() throws {
        let text = """
        type,id,title,date,value
        week,2026-W43,,,9
        category_score,9.9,Sonderwoche,,7
        category_score,1.1,Sport / Verein,Mo,8
        goal_score,12,Extra,,6
        goal_score,1,Gesundheit,,6
        """
        let doc = PlanCSV.parse(text, knownCategories: ["1.1": "Sport / Verein"], knownGoals: ["1"])
        let special = try #require(doc.grades.first { $0.title == "Sonderwoche" })
        #expect(!special.isMapped)
        #expect(doc.grades.first { $0.title == "Extra" }?.isMapped == false)
        #expect(doc.grades.first { $0.title == "Sport / Verein" }?.id == "1.1")
        #expect(doc.grades.first { $0.title == "Gesundheit" }?.id == "1")
        #expect(doc.warnings.contains("KW43: \u{201C}Sonderwoche\u{201D} – 9.9 ist keine Kategorie der App; die Note bleibt ohne Zuordnung im Archiv."),
                "\(doc.warnings)")
        #expect(doc.warnings.contains { $0.contains("12 ist kein Jahresziel der App") })
        #expect(!doc.warnings.contains { $0.contains("ohne Zuordnung, nur im Archiv") }, "not listed twice")
        // Goals from the known categories when the goals aren't given.
        let byCategory = PlanCSV.parse(text, knownCategories: ["1.1": "Sport / Verein"])
        #expect(byCategory.grades.first { $0.title == "Gesundheit" }?.id == "1")
        #expect(byCategory.grades.first { $0.title == "Extra" }?.id == "")
        // Through the preview: the app's categories and goals; the warning stands under its week.
        var state = ExistingState()
        state.categories["1.1"] = CategoryRecord(key: "1.1", goalKey: "1", title: "Sport / Verein")
        state.goals["1"] = GoalRecord(key: "1", title: "Gesundheit")
        let preview = ImportPreview(text: text, existing: state)
        #expect(preview.weekSummaries.first?.warnings.contains { $0.contains("9.9 ist keine Kategorie") } == true)
        #expect(preview.grades.creates == 4)
    }

    /// The week row's value as written: three decimals are decimals, not thousands (v9). Outside 0–10 or
    /// unreadable it is not taken, with a warning (decision 5: no wrong value laut Unterlagen).
    @Test func weekValueKeepsItsDecimals() {
        let doc = PlanCSV.parse("type,id,value\nweek,2026-W43,9.192\nweek,2026-W44,\"9,19\"\nweek,2026-W45,92\nweek,2026-W46,ca. 9\n")
        #expect(doc.weeks.map(\.recordedScore) == [9.192, 9.19, nil, nil])
        #expect(doc.warnings.contains { $0.hasPrefix("KW45: Wochenwert") && $0.contains("nicht zwischen 0 und 10 – nicht übernommen") },
                "\(doc.warnings)")
        #expect(doc.warnings.contains("KW46: Wochenwert \u{201C}ca. 9\u{201D} (Zeile 5) nicht lesbar – nicht übernommen."), "\(doc.warnings)")
    }
}

/// A3, A6: archive weeks in the past-week import, "Archivdaten dieser Wochen ersetzen".
@Suite("v9 archive weeks in the import")
struct V9ImportTests {
    let today = DayKey(year: 2026, month: 11, day: 18)
    let week = WeekKey(year: 2026, week: 43)
    var current: WeekKey { today.week }

    /// The app has KW43 from an earlier import: two items, a mark, a paper score, a stored grade, closed.
    func appState() -> ExistingState {
        var state = ExistingState()
        state.categories["1.1"] = CategoryRecord(key: "1.1", goalKey: "1", title: "Sport / Verein")
        state.categories["2.1"] = CategoryRecord(key: "2.1", goalKey: "2", title: "Lesen")
        state.goals["1"] = GoalRecord(key: "1", title: "Gesundheit")
        state.goals["2"] = GoalRecord(key: "2", title: "Lernen")
        state.weeks[week.string] = WeekRecord(week: week, title: "Alt", recordedScore: 7)
        for code in ["1.1-01", "1.1-02"] {
            let item = ItemRecord(week: week, code: code, categoryKey: "1.1", title: code, schedule: code == "1.1-02" ? .weekly(3) : .fixed)
            state.items[item.key] = item
        }
        let mark = MarkRecord(week: week, itemCode: "1.1-01", day: week.monday, mark: .done)
        state.marks[mark.key] = mark
        state.archiveGrades[week] = ArchiveWeek(week: week, grades: [
            ArchiveGrade(week: week, kind: .category, id: "1.1", title: "Falsch", day: week.day(.wednesday), value: 2),
        ])
        state.closedWeeks = [week]
        return state
    }

    /// A3: a file with only a week row – no items, nothing filled, closed, "Wertung 9,19 laut Unterlagen".
    @Test func weekOnlyFileIsAnArchiveWeek() throws {
        let doc = PlanCSV.parse("type,id,value,note\nweek,2026-W43,9.19,Scan S. 2\n")
        #expect(doc.archiveWeeks == [week])
        #expect(doc.items.isEmpty && doc.plannedWeeks.isEmpty)
        #expect(doc.fillingBlanks(weeks: [week], with: .missed).marks.isEmpty)
        // Not even on the app's plan: items alone don't make it a planned week of the file.
        var withAppItems = doc
        withAppItems.items = [ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Fix")]
        #expect(withAppItems.archiveWeeks == [week])
        #expect(withAppItems.fillingBlanks(weeks: [week], with: .missed).marks.isEmpty)
        var state = appState()
        state.closedWeeks = []
        #expect(doc.fillingPastBlanks(existing: state, today: today).marks.isEmpty)
        let closed = doc.closingPast(today: today)
        #expect(closed.closedWeeks == [week])
        // The preview: nothing new for items or marks, the score "laut Unterlagen".
        let preview = ImportPreview.pastWeeks(doc, existing: ExistingState(), blanksAsMissed: true, today: today)
        #expect(preview.items.entries.isEmpty && preview.marks.entries.isEmpty)
        let summary = try #require(preview.weekSummaries.first)
        #expect(summary.isArchive && summary.items == 0 && summary.status == "neu")
        #expect(summary.detail == "Wertung 9,19 laut Unterlagen · wird abgeschlossen", "\(summary.detail)")
        #expect(preview.archiveUpdates[week]?.source == "Scan S. 2")
        #expect(preview.hasChanges)
        // A week with marks is no archive week (v8: filled on the app's plan).
        let marked = PlanCSV.parse("type,id,date,value\nweek,2026-W43,,\nmark,1.1-01,Di,1\n")
        #expect(marked.archiveWeeks.isEmpty)
    }

    /// A3: day grades close their days; the week's items in the app get a warning when not replacing.
    @Test func archiveWeekWithItemsInTheAppGetsAWarning() throws {
        let text = """
        type,id,title,date,value,note
        week,2026-W43,,,9.28,Scan S. 19
        day,Sa,Urlaub,,,
        category_score,1.1,Sport / Verein,Mo,10,Scan S. 19
        category_score,1.1,Sport / Verein,Sa,0,Scan S. 19
        goal_score,1,Gesundheit,,8,Scan S. 19
        """
        let state = appState()
        let doc = PlanCSV.parse(text, knownCategories: state.categoryTitles, knownGoals: Set(state.goals.keys))
        let closed = doc.closingPast(today: today)
        #expect(closed.closedDays == [week.monday, week.day(.saturday)], "the days with grades or a type")
        let preview = ImportPreview.pastWeeks(doc, existing: state, blanksAsMissed: true, today: today)
        #expect(preview.replacingWeeks.isEmpty && preview.replacedWeeks.isEmpty)
        let summary = try #require(preview.weekSummaries.first { $0.week == week })
        #expect(summary.warnings.contains("KW43: in der App noch 2 Punkte mit 1 Markierung – \u{201A}Archivdaten ersetzen\u{2018} nur wählen, "
                                          + "wenn sie aus einem fehlerhaften Import stammen; es verschiebt alles ins Archiv."),
                "\(summary.warnings)")
        #expect(summary.status == "ergänzt")
        #expect(summary.detail == "2 Kategoriennoten · 1 Zielnote · 1 Tag Krank/Urlaub · Wertung 9,28 laut Unterlagen", "\(summary.detail)")
        #expect(!preview.document.marks.contains { $0.week == week }, "no ✗ for the app's items")
        // The stored grade stays, the new ones are added by key.
        let after = try #require(preview.archiveUpdates[week])
        #expect(after.grades.count == 4 && after.grades.contains { $0.title == "Falsch" })
        #expect(preview.lines.contains("Kategoriennoten: 2 neu · 0 geändert · 0 gleich"), "\(preview.lines)")
        #expect(preview.lines.contains("Zielnoten: 1 neu · 0 geändert · 0 gleich"))
    }

    /// A6: "Archivdaten dieser Wochen ersetzen": the past week is replaced ("ersetzt", the grade counts),
    /// the current week is not (a warning, imported as usual).
    @Test func replacingArchivesReplacesOnlyPastWeeks() throws {
        let text = """
        type,id,title,date,value,note
        week,2026-W43,,,9.28,Scan S. 19
        category_score,1.1,Sport / Verein,Mo,10,Scan S. 19
        category_score,2.1,Lesen,,7,Scan S. 19
        goal_score,1,Gesundheit,,8,Scan S. 19
        week,\(current.string),,,,
        """
        let state = appState()
        let doc = PlanCSV.parse(text, knownCategories: state.categoryTitles, knownGoals: Set(state.goals.keys))
        let preview = ImportPreview.pastWeeks(doc, existing: state, replacingArchives: true, today: today)
        #expect(preview.replacingWeeks == [week])
        #expect(preview.replacedWeeks == [week])
        let replacement = try #require(preview.replacements.first)
        #expect(replacement.isArchiveReplacement && replacement.items == 2 && replacement.grades == 1)
        #expect(replacement.text == "KW43 wird ersetzt – 2 Punkte, 1 Markierung, 1 Note und die Wertung gehen ins Archiv.", "\(replacement.text)")
        let summary = try #require(preview.weekSummaries.first { $0.week == week })
        #expect(summary.isReplaced && summary.status == "ersetzt")
        #expect(summary.detail == "2 Kategoriennoten · 1 Zielnote · Wertung 9,28 laut Unterlagen · wird abgeschlossen", "\(summary.detail)")
        #expect(!summary.warnings.contains { $0.contains("früheren Import") }, "replacing removes them – no warning")
        // Only the file's grades afterwards.
        let after = try #require(preview.archiveUpdates[week])
        #expect(after.grades.count == 3 && !after.grades.contains { $0.title == "Falsch" })
        #expect(after.source == "Scan S. 19")
        // Compared with the app as it is after the archive: everything comes in new.
        #expect(preview.grades.creates == 3)
        #expect(preview.weeks.entries.first { $0.record.week == week }?.action == .update)
        // The current week: never replaced, a warning.
        let now = try #require(preview.weekSummaries.first { $0.week == current })
        #expect(!now.isReplaced)
        #expect(now.warnings.contains("\(current.label): noch nicht vorbei – wird nicht ersetzt, nur ergänzt."), "\(now.warnings)")
        #expect(preview.hasChanges)
        // A week the app has nothing for is simply new.
        let fresh = ImportPreview.pastWeeks(doc, existing: ExistingState(), replacingArchives: true, today: today)
        #expect(fresh.replacingWeeks.isEmpty && fresh.weekSummaries.first?.status == "neu")
        // The state the import finds: KW43 without items, marks, grades, score, closing.
        let cleared = state.clearing([week])
        #expect(cleared.items.isEmpty && cleared.marks.isEmpty && cleared.archiveGrades.isEmpty && cleared.closedWeeks.isEmpty)
        #expect(cleared.weeks[week.string]?.recordedScore == nil && cleared.weeks[week.string]?.title == "Alt")
        #expect(state.hasArchiveContent(week) && !cleared.hasArchiveContent(week))
    }

    /// The import is repeatable: the same file against the app that has it changes nothing.
    @Test func sameFileTwiceChangesNothing() {
        let text = "type,id,title,date,value,note\nweek,2026-W43,,,9.28,Scan\ncategory_score,1.1,Sport / Verein,Mo,10,Scan\n"
        let doc = PlanCSV.parse(text)
        var state = ExistingState()
        state.weeks[week.string] = WeekRecord(week: week, recordedScore: 9.28)
        state.closedWeeks = [week]
        state.closedDays = [week.monday]
        state.archiveGrades[week] = doc.archive(week)
        let preview = ImportPreview.pastWeeks(doc, existing: state, today: today)
        #expect(preview.archiveUpdates.isEmpty)
        #expect(preview.grades.unchanged == 1)
        #expect(!preview.hasChanges, "\(preview.lines)")
        #expect(preview.weekSummaries.first?.status == "unverändert")
    }

    /// The week row's note is a source only for a week value or grades: a plan's note makes no archive.
    @Test func planNoteMakesNoArchive() {
        let plan = "type,id,parent,title,days,schedule,note\nweek,2026-W43,,,,,Plan vom Sonntag\nitem,1.1-01,1.1,Fix,täglich,fix,\n"
        let preview = ImportPreview(document: PlanCSV.parse(plan), existing: ExistingState())
        #expect(preview.archiveUpdates.isEmpty)
        let valued = PlanCSV.parse("type,id,value,note\nweek,2026-W43,7.5,Scan S. 4\n")
        #expect(ImportPreview(document: valued, existing: ExistingState()).archiveUpdates[week]?.source == "Scan S. 4")
    }
}

/// A7, A8 and the demo.
@Suite("v9 prompt, two scores, demo")
struct V9PromptTests {
    let week = WeekKey(year: 2026, week: 45)
    let goals = [GoalRecord(key: "1", title: "Gesundheit"), GoalRecord(key: "2", title: "Lernen")]
    let categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Sport / Verein"), CategoryRecord(key: "2.1", goalKey: "2", title: "Lesen")]
    let items = [ItemRecord(week: WeekKey(year: 2026, week: 46), code: "1.1-01", categoryKey: "1.1", position: 1, title: "Training gemacht",
                            days: DayMask.parse("Mo,Mi,Fr") ?? .everyDay, schedule: .weekly(2))]
    let measures = [MeasureRecord(week: WeekKey(year: 2026, week: 46), code: "seiten", categoryKey: "2.1", position: 1, title: "Seiten",
                                  unit: "Seiten")]

    /// A7: the archive rules, the header, the structure with ids, no model names.
    @Test func promptHasTheArchiveRules() throws {
        let text = PastWeekPrompt.text(weeks: [], items: items, categories: categories, goals: goals, measures: measures)
        #expect(PastWeekPrompt.header == "type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note,count,mo,di,mi,do,fr,sa,so")
        #expect(text.contains("\n" + PastWeekPrompt.header + "\n"))
        for phrase in ["category_score", "goal_score", "Nichts erfinden", "echte 0", "nicht selbst berechnen, nicht runden",
                       "Mittelwerte rechnet Thalia selbst", "nie aufteilen oder umdeuten", "Zielnoten nie auf Kategorien verteilen",
                       "fehlende Punkte gelten nicht als verpasst", "Keine score-, measure-, goal-, category- oder work-Zeilen",
                       "Es ist ein Archiv", "note = Quelle", "count = Anzahl gültiger Tage"] {
            #expect(text.contains(phrase), "\(phrase)")
        }
        #expect(text.contains("## Jahresziele (id · Name)\n- 1 · Gesundheit\n- 2 · Lernen"))
        #expect(text.contains("## Kategorien (id · Name · Jahresziel)\n- 1.1 · Sport / Verein · Ziel 1\n- 2.1 · Lesen · Ziel 2"))
        #expect(text.contains("## Messwerte (id · Name · Einheit)\n- seiten · Seiten · Seiten"))
        #expect(text.contains("## Vorlage für Einzelhaken (nur bei belegten Haken) – Punkte von KW46"))
        #expect(text.contains("item,1.1-01,1.1,Training gemacht,,\"Mo,Mi,Fr\",woche:2"))
        #expect(!text.contains("ChatGPT"), "no model names")
        let example = try #require(text.range(of: "## Beispiel (zwei Wochen)"))
        let template = try #require(text.range(of: "## Vorlage für Einzelhaken"))
        #expect(example.lowerBound < template.lowerBound, "the example is the first csv block")
        // One week, several weeks, the weeks of the attachments – as in v8.
        let one = PastWeekPrompt.text(weeks: [week], items: items, categories: categories, goals: goals, measures: measures)
        #expect(one.contains("KW45 2026 (2.–8. Nov.), week-id 2026-W45") && one.hasSuffix("## Meine Unterlagen für KW45:\n"))
        let many = PastWeekPrompt.text(weeks: [week, week.adding(weeks: 1)], items: items, categories: categories, goals: goals,
                                       measures: measures)
        #expect(many.contains("genau diese 2 vergangenen Wochen") && many.contains("- KW46 2026 (9.–15. Nov.): week-id 2026-W46"))
        #expect(many.hasSuffix("## Meine Unterlagen:\n"))
        #expect(text.contains("KW und Datum jeder Woche liest du dort ab") && text.hasSuffix("## Meine Unterlagen:\n"))
        // Nothing to copy: no items, no measurements.
        let bare = PastWeekPrompt.text(weeks: [], items: [], categories: categories, goals: goals, measures: [])
        #expect(bare.contains("keine Punkte in der App") && bare.contains("7. Keine item-Zeilen") && bare.contains("8. Keine entry-Zeilen"))
    }

    /// A7: with real week ids the example is valid input – two weeks, grades with and without id, a real
    /// 0, a holiday; as written (placeholder ids) it lands in no week at all.
    @Test func promptExampleReadsBack() throws {
        let (first, second) = (WeekKey(year: 2026, week: 10), WeekKey(year: 2026, week: 11))
        let doc = PlanCSV.parse(PastWeekPrompt.exampleCSV(weekIDs: [first.string, second.string]))
        #expect(doc.skipped.isEmpty && doc.warnings.count == 1, "\(doc.skipped) \(doc.warnings)")
        #expect(doc.weeks.map(\.recordedScore) == [8.75, 7.2])
        #expect(doc.weekNotes[first] == "Scan S. 3" && doc.weekNotes[second] == "Scan S. 4")
        #expect(doc.archiveWeeks == [first, second])
        let archive = doc.archive(first)
        #expect(archive.categoryGrades.count == 5 && archive.goalGrades.count == 1)
        #expect(archive.grades.contains { $0.value == 0 && $0.isDayGrade }, "a real 0")
        #expect(archive.grades.contains { !$0.isMapped && $0.title == "Sonderwoche" })
        #expect(archive.grades.first { $0.title == "Lesen" }?.count == 4)
        #expect(doc.days.first?.dayType == "Urlaub" && doc.days.first?.day == first.day(.saturday))
        #expect(doc.archive(second).grades.isEmpty)
        // The goal grade is no mean of the example's category grades (the answer must not compute it).
        let goal = try #require(archive.goalGrades.first?.value)
        let means = archive.categoryLines.compactMap(\.value)
        #expect(!means.contains { abs($0 - goal) < 0.01 }, "\(goal) \(means)")
        // As written: placeholder ids – nothing comes in.
        let asWritten = PlanCSV.parse(PastWeekPrompt.exampleCSV())
        #expect(asWritten.weeks.isEmpty && asWritten.grades.isEmpty && asWritten.days.isEmpty && !asWritten.skipped.isEmpty)
    }

    /// A8: the score "laut Unterlagen" wins over today's calculation – through `WeekLine` with what
    /// Shared hands in (`storedScore` = `WeekPlan.historyScore`, the archive grades).
    @Test func recordedScoreWinsOverTheRecalculation() throws {
        #expect(WeekLine.historyScore(recorded: 9.28, computed: 8.93) == 9.28)
        #expect(WeekLine.historyScore(recorded: nil, computed: 8.93) == 8.93)
        #expect(WeekLine.historyScore(recorded: 7, computed: nil) == 7)
        let saturday = week.day(.saturday)
        let archive = ArchiveWeek(week: week, grades: [
            ArchiveGrade(week: week, kind: .category, id: "1.1", title: "Sport / Verein", day: week.monday, value: 9),
            ArchiveGrade(week: week, kind: .category, id: "1.1", title: "Sport / Verein", day: saturday, value: 0),
            ArchiveGrade(week: week, kind: .goal, id: "2", title: "Lernen", value: 7),
        ])
        let input = WeekReportInput(week: WeekRecord(week: week, recordedScore: 9.28), goals: goals, categories: categories, items: [],
                                    measures: [], marks: [], days: [DayRecord(day: saturday, dayType: "Urlaub")], isClosed: true,
                                    today: week.sunday.adding(days: 1))
        let recalculated = archive.recalculated(categories: categories, goals: goals, excusedDays: [saturday])
        #expect(recalculated.overall == 8, "(9 + 7) / 2 – the holiday's 0 is left out")
        let stored = WeekLine.historyScore(recorded: 9.28, computed: recalculated.overall)
        let line = WeekLine(input, storedScore: stored, storedGoalScores: recalculated.goals, archive: archive)
        #expect(line.score == 9.28 && line.isArchive && line.isPaperOnly)
        #expect(line.goalScores == ["1": 9, "2": 7])
        #expect(line.excusedDays == 1)
        // Without a stored score the week row's value still wins; the goals come from the grades.
        let live = WeekLine(input, archive: archive)
        #expect(live.score == 9.28 && live.goalScores == ["1": 9, "2": 7])
        // Without a value in the records: today's calculation.
        var unrecorded = input
        unrecorded.week.recordedScore = nil
        let calculated = WeekLine(unrecorded, archive: archive)
        #expect(calculated.score == 8 && calculated.isArchive && !calculated.isPaperOnly)
        // In a report the value laut Unterlagen counts.
        let report = RangeReport(lines: [line, WeekLine(week: week.adding(weeks: 1), score: 6)], goals: goals, work: [])
        #expect(abs((report.average ?? 0) - 7.64) < 1e-9)
        #expect(!WeekLine(week: week).isArchive)
    }

    /// Decision 10: the demo's archive week – grades, a holiday Saturday, one without mapping, goal grades.
    @Test func demoHasAnArchiveWeek() throws {
        let today = DayKey(year: 2026, month: 11, day: 18)
        let content = Demo.content(today: today)
        let doc = content.document
        let archiveWeek = Demo.archiveWeek(today: today)
        #expect(archiveWeek == WeekKey(year: 2026, week: 45))
        let archive = doc.archive(archiveWeek)
        #expect(archive.goalGrades.count == 10 && archive.categoryGrades.count == 16)
        #expect(doc.weeks.first { $0.week == archiveWeek }?.recordedScore != nil, "a paper week")
        #expect(doc.days.first { $0.day == archiveWeek.day(.saturday) }?.dayType == Demo.archiveDayType)
        let excused = Set(doc.days.filter { archiveWeek.contains($0.day) && DayTypes.isExcused($0.dayType) }.map(\.day))
        let result = archive.recalculated(categories: doc.categories, goals: doc.goals, excusedDays: excused)
        #expect(result.excludedDays == [archiveWeek.day(.saturday)])
        #expect(result.unmapped == 1)
        #expect(result.goals.count == 10 && result.overall != nil)
        #expect(!content.closedWeeks.contains(archiveWeek))
        // Export and re-import keep the grades.
        let again = PlanCSV.parse(PlanCSV.export(doc))
        #expect(again.skipped.isEmpty)
        #expect(again.archive(archiveWeek) == archive)
        // The tour's practice page has none.
        #expect(Demo.content(today: today, history: false).document.grades.isEmpty)
    }
}
