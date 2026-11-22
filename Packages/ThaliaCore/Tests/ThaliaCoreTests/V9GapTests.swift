import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

// v9 gaps (review after TASKS-v9): archive weeks stay without measurements, rows stay in their block,
// the value laut Unterlagen and the motto are never lost, "Archivdaten ersetzen" replaces only weeks of
// the file that change, shifted columns are caught, the prompt. Neutral labels only.

@Suite("v9 gaps: reading")
struct V9GapReadingTests {
    let week = WeekKey(year: 2026, week: 43)

    /// One answer row with the prompt's columns, written without quoting (as an answer might).
    func line(_ values: [String: String]) -> String {
        PastWeekPrompt.columns.map { values[$0] ?? "" }.joined(separator: ",")
    }

    /// Rows before the first week row name that reason – not "nicht lesbar".
    @Test func rowsBeforeTheFirstWeekRowSayWhy() {
        let doc = PlanCSV.parse("type,id,title,date,value\ncategory_score,1.1,X,Mo,5\nday,Di,Krank,,\n"
                                + "category_score,1.1,X,2026-10-19,5\nweek,2026-W43,,,\n")
        #expect(doc.skipped.contains("Zeile 2: Kategoriennote \u{201C}X\u{201D} steht vor der ersten week-Zeile"), "\(doc.skipped)")
        #expect(doc.skipped.contains("Zeile 3: Tag \u{201C}Di\u{201D} steht vor der ersten week-Zeile"), "\(doc.skipped)")
        #expect(doc.skipped.contains("Zeile 4: Kategoriennote \u{201C}X\u{201D} steht vor der ersten week-Zeile"), "a full date too")
        #expect(!doc.skipped.contains { $0.contains("nicht lesbar") })
        #expect(doc.grades.isEmpty && doc.days.isEmpty)
    }

    /// Day rows and grades dated in another week are skipped with the reason – never moved there.
    @Test func rowsStayInTheirBlock() {
        let text = """
        type,id,title,date,value,note
        week,2026-W43,,,9.28,Scan
        day,2026-11-10,Urlaub,,,
        category_score,1.1,Sport / Verein,2026-11-10,7,Scan
        goal_score,1,Gesundheit,2026-10-27,8,Scan
        goal_score,1,Gesundheit,2026-10-21,6,Scan
        category_score,1.1,Sport / Verein,2026-10-19,9,Scan
        day,Sa,Urlaub,,,
        """
        let doc = PlanCSV.parse(text)
        #expect(doc.days.map(\.day) == [week.day(.saturday)])
        #expect(doc.grades.count == 2 && doc.grades.allSatisfy { $0.week == week })
        #expect(doc.grades.first { $0.kind == .goal }?.value == 6, "a goal's date in its week is fine")
        #expect(doc.skipped.filter { $0.contains("gehört in den Block seiner Woche") }.count == 3, "\(doc.skipped)")
        #expect(doc.skipped.contains("Zeile 3: Tag 2026-11-10 liegt nicht in KW43 – gehört in den Block seiner Woche"))
        #expect(doc.fileWeeks == [week])
        #expect(doc.closingPast(today: DayKey(year: 2026, month: 11, day: 18)).closedWeeks == [week])
    }

    /// The week value is written exactly, so a backup reads back unchanged.
    @Test func weekValueIsWrittenExactly() {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week, recordedScore: 9.19234)]
        let text = PlanCSV.export(doc)
        #expect(text.contains(",9.19234,"), "\(text)")
        #expect(PlanCSV.parse(text).weeks.first?.recordedScore == 9.19234)
        var state = ExistingState()
        state.weeks[week.string] = WeekRecord(week: week, recordedScore: 9.19234)
        let preview = ImportPreview(text: text, existing: state)
        #expect(preview.weeks.unchanged == 1 && !preview.hasChanges, "\(preview.lines)")
    }

    /// A decimal comma without quotes shifts the columns: the week keeps no wrong value, the grade is
    /// skipped with the reason – also in a short row.
    @Test func unquotedDecimalCommaIsCaught() {
        let text = [PastWeekPrompt.header,
                    line(["type": "week", "id": "2026-W43", "value": "9,28", "note": "Scan S. 3"]),
                    line(["type": "category_score", "id": "1.1", "title": "Sport / Verein", "date": "2026-10-19", "value": "6,67",
                          "note": "Scan S. 3"]),
                    "category_score,2.1,,Lesen,,,,,,,,,,8,5,Scan S. 3,4",
                    line(["type": "category_score", "id": "2.1", "title": "Lesen", "date": "2026-10-20", "value": "\"6,5\"", "note": "Scan S. 3"]),
                    line(["type": "category_score", "id": "1.1", "title": "Sport / Verein", "date": "2026-10-21", "value": "10", "note": "Scan S. 3"])]
            .joined(separator: "\n")
        let doc = PlanCSV.parse(text)
        #expect(doc.weeks.map(\.week) == [week])
        #expect(doc.weeks.first?.recordedScore == nil && doc.weekNotes[week] == nil)
        #expect(doc.warnings.contains { $0.hasPrefix("KW43: Zeile 2 – Spalten verrutscht") }, "\(doc.warnings)")
        #expect(doc.skipped.filter { $0.contains("Spalten verrutscht") }.count == 2, "\(doc.skipped)")
        #expect(doc.grades.map(\.value).sorted() == [6.5, 10], "a quoted comma and a plain value read")
        #expect(!doc.warnings.contains { $0.contains("Anzahl") }, "no confusing count warning")
    }

    /// Day grades in the weekday columns of a category_score row are read; a goal grade has none.
    @Test func weekdayColumnsOfCategoryScoreAreDayGrades() throws {
        let text = [PastWeekPrompt.header,
                    line(["type": "week", "id": "2026-W43"]),
                    line(["type": "category_score", "id": "1.2", "title": "Sport / Verein", "note": "Scan", "mo": "10", "di": "0", "sa": "10"]),
                    line(["type": "category_score", "id": "2.1", "title": "Lesen", "mo": "abc"]),
                    line(["type": "goal_score", "id": "1", "title": "Gesundheit", "value": "8", "mo": "7"])]
            .joined(separator: "\n")
        let doc = PlanCSV.parse(text)
        let sport = try #require(doc.archive(week).categoryLines.first { $0.title == "Sport / Verein" })
        #expect(sport.sortedDays.map(\.day) == [week.monday, week.day(.tuesday), week.day(.saturday)])
        #expect(sport.sortedDays.map(\.value) == [10, 0, 10] && sport.sources == ["Scan"])
        #expect(doc.grades.first { $0.kind == .goal }?.value == 8)
        #expect(doc.skipped.contains { $0.contains("Mo \u{201C}abc\u{201D} nicht lesbar") }, "\(doc.skipped)")
        #expect(doc.skipped.contains { $0.contains("nur für Kategorien") })
        #expect(!doc.skipped.contains { $0.contains("ohne Wert") && $0.contains("Sport") })
    }

    /// Two labels mapped to the same id on the same day: a plain warning under the week.
    @Test func twoLabelsOnOneIdGetAPlainWarning() {
        let doc = PlanCSV.parse("type,id,title,date,value\nweek,2026-W43,,,\ncategory_score,1.1,Sport,Mo,4\ncategory_score,1.1,Verein,Mo,9\n"
                                + "category_score,1.1,Verein,,8\ncategory_score,1.1,Sport,,7\n")
        #expect(doc.grades.count == 2 && doc.grades.first { $0.day != nil }?.title == "Verein")
        #expect(doc.warnings.contains("KW43 Mo: zwei Noten für 1.1 (\u{201E}Sport\u{201C}, \u{201E}Verein\u{201C}) – nur die letzte bleibt; bei unklarer Zuordnung id leer lassen."),
                "\(doc.warnings)")
        #expect(doc.warnings.contains { $0.hasPrefix("KW43: zwei Wochennoten für 1.1") })
        #expect(!doc.warnings.contains { $0.contains("doppelt") })
        let preview = ImportPreview(document: doc, existing: ExistingState())
        #expect(preview.weekSummaries.first?.warnings.count == 2)
    }

    /// Only the first csv block is read: more get a warning.
    @Test func severalCSVBlocksGetAWarning() {
        let answer = "```csv\ntype,id,value\nweek,2026-W43,9\n```\nUnsicher: nichts.\n```csv\ntype,id,value\nweek,2026-W44,8\n```\n"
        let doc = PlanCSV.parse(answer)
        #expect(doc.weeks.map(\.week) == [week])
        #expect(doc.warnings == ["Die Antwort hat 2 CSV-Blöcke – gelesen wird nur der erste. Alle Wochen gehören in einen Block."])
        #expect(PlanCSV.csvBlockCount(in: "```\nkein csv\n```") == 0)
        #expect(PlanCSV.parse("```csv\ntype,id,value\nweek,2026-W43,9\n```").warnings.isEmpty)
    }

    /// German headers: "quelle" is the source of the week value and the grades.
    @Test func germanSourceColumn() {
        let doc = PlanCSV.parse("typ,id,titel,datum,wert,quelle\nwoche,2026-W43,,,9.28,Scan S. 3\nkategoriennote,1.1,Sport / Verein,Mo,6,Scan S. 3\n")
        #expect(doc.weekNotes[week] == "Scan S. 3")
        #expect(doc.grades.first?.source == "Scan S. 3")
    }
}

@Suite("v9 gaps: past-week import")
struct V9GapImportTests {
    let today = DayKey(year: 2026, month: 11, day: 18)
    let week = WeekKey(year: 2026, week: 43)
    var current: WeekKey { today.week }
    var last: WeekKey { current.adding(weeks: -1) }

    func baseState() -> ExistingState {
        var state = ExistingState()
        state.categories["1.1"] = CategoryRecord(key: "1.1", goalKey: "1", title: "Sport / Verein")
        state.categories["2.1"] = CategoryRecord(key: "2.1", goalKey: "2", title: "Lesen")
        state.goals["1"] = GoalRecord(key: "1", title: "Gesundheit")
        state.goals["2"] = GoalRecord(key: "2", title: "Lernen")
        return state
    }

    /// Last week planned and open in the app: two items, a mark.
    func withLiveWeek(_ state: ExistingState) -> ExistingState {
        var state = state
        state.weeks[last.string] = WeekRecord(week: last, title: "Live")
        for code in ["1.1-01", "2.1-01"] {
            let item = ItemRecord(week: last, code: code, categoryKey: String(code.prefix(3)), title: code)
            state.items[item.key] = item
        }
        let mark = MarkRecord(week: last, itemCode: "1.1-01", day: last.monday, mark: .done)
        state.marks[mark.key] = mark
        return state
    }

    func parse(_ text: String, _ state: ExistingState) -> PlanCSV.Document {
        PlanCSV.parse(text, knownCategories: state.categoryTitles, knownMeasures: state.measureCodes, knownItems: state.itemKeys,
                      knownGoals: Set(state.goals.keys))
    }

    /// Decision 1: an archive week gets no measurement definitions (no weekly target nothing can meet).
    @Test func archiveWeekGetsNoMeasurements() throws {
        let text = """
        type,id,parent,title,unit,target,period,date,value,note
        week,2026-W43,,,,,,,9.28,Scan
        measure,seiten,2.1,Seiten,Seiten,>=70,woche,,,
        category_score,1.1,,Sport / Verein,,,,,6,Scan
        """
        var state = baseState()
        let kept = MeasureRecord(week: week, code: "schritte", categoryKey: "1.1", position: 1, title: "Schritte", unit: "Schritte")
        state.measures[kept.key] = kept
        let doc = parse(text, state)
        #expect(doc.measures.count == 1 && doc.archiveWeeks == [week])
        let preview = ImportPreview.pastWeeks(doc, existing: state, today: today)
        #expect(preview.measures.entries.isEmpty && preview.removedMeasures.isEmpty)
        #expect(preview.document.measuredWeeks.isEmpty)
        let summary = try #require(preview.weekSummaries.first)
        #expect(summary.isArchive)
        #expect(summary.warnings.contains("KW43: Messwert \u{201E}Seiten\u{201C} nicht übernommen – eine Woche ohne Punkte bekommt keine Messwerte."),
                "\(summary.warnings)")
        // A week with items keeps its measurements as before.
        let planned = parse(text + "\nitem,1.1-01,1.1,Training,,,,,,", state)
        #expect(ImportPreview.pastWeeks(planned, existing: state, today: today).measures.creates == 1)
    }

    /// Decision 2: only weeks with a week row are replaced – a stray row never reaches a live week,
    /// with the switch on or off.
    @Test func strayRowsNeverReplaceOrCloseALiveWeek() {
        let state = withLiveWeek(baseState())
        let lastDay = last.day(.tuesday).string
        for stray in ["day,\(lastDay),Urlaub,,,", "category_score,1.1,Sport / Verein,\(lastDay),7,Scan"] {
            let text = "type,id,title,date,value,note\nweek,2026-W43,,,9.28,Scan\n\(stray)\n"
            let doc = parse(text, state)
            for switchOn in [true, false] {
                let preview = ImportPreview.pastWeeks(doc, existing: state, replacingArchives: switchOn, today: today)
                #expect(preview.replacingWeeks.isEmpty, "KW43 has nothing in the app")
                #expect(!preview.document.closedWeeks.contains(last) && !preview.newClosedWeeks.contains(last))
                #expect(!preview.weekSummaries.contains { $0.week == last })
                #expect(preview.document.skipped.contains { $0.contains("gehört in den Block seiner Woche") })
                #expect(!preview.archiveUpdates.keys.contains(last))
            }
        }
    }

    /// The file's empty motto and context keep the app's; a supplementing import keeps the value laut
    /// Unterlagen when the file has none or an unreadable one; replacing takes the file's.
    @Test func mottoAndValueAreKept() throws {
        var state = baseState()
        state.weeks[week.string] = WeekRecord(week: week, title: "Motto", details: "Kontext", recordedScore: 9.28)
        state.closedWeeks = [week]
        for value in ["", "ca. 9"] {
            let doc = parse("type,id,title,date,value,note\nweek,2026-W43,,,\(value),\ncategory_score,1.1,Sport / Verein,Mo,6,Scan\n", state)
            let preview = ImportPreview.pastWeeks(doc, existing: state, today: today)
            let record = try #require(preview.document.weeks.first)
            #expect(record.title == "Motto" && record.details == "Kontext" && record.recordedScore == 9.28)
            #expect(preview.weeks.unchanged == 1, "\(preview.lines)")
            #expect(value.isEmpty || preview.weekSummaries.first?.warnings.contains { $0.contains("nicht lesbar – nicht übernommen") } == true)
        }
        // Replacing: the file's value counts (none), the motto stays.
        let doc = parse("type,id,title,date,value,note\nweek,2026-W43,,,,\ncategory_score,1.1,Sport / Verein,Mo,6,Scan\n", state)
        let replaced = ImportPreview.pastWeeks(doc, existing: state, replacingArchives: true, today: today)
        #expect(replaced.replacingWeeks == [week])
        let record = try #require(replaced.document.weeks.first)
        #expect(record.recordedScore == nil && record.title == "Motto" && record.details == "Kontext")
        // A file motto still wins.
        let titled = parse("type,id,title,date,value\nweek,2026-W43,Neu,,\n", state)
        #expect(ImportPreview.pastWeeks(titled, existing: state, today: today).document.weeks.first?.title == "Neu")
    }

    /// A running week gets no value laut Unterlagen and keeps its motto.
    @Test func runningWeekGetsNoValue() throws {
        var state = baseState()
        state.weeks[current.string] = WeekRecord(week: current, title: "Jetzt")
        let doc = parse("type,id,title,date,value\nweek,\(current.string),,,8\n", state)
        let preview = ImportPreview.pastWeeks(doc, existing: state, replacingArchives: true, today: today)
        let record = try #require(preview.document.weeks.first)
        #expect(record.recordedScore == nil && record.title == "Jetzt")
        #expect(!preview.hasChanges, "\(preview.lines)")
        let warnings = try #require(preview.weekSummaries.first?.warnings)
        #expect(warnings.contains("\(current.label): noch nicht vorbei – der Wochenwert wird nicht übernommen."), "\(warnings)")
        #expect(warnings.contains("\(current.label): noch nicht vorbei – wird nicht ersetzt, nur ergänzt."))
    }

    /// The same file twice with the switch on: the second time nothing is replaced (no identical
    /// second snapshot); a changed grade replaces again.
    @Test func replacingTheSameFileTwiceChangesNothing() {
        let text = "type,id,title,date,value,note\nweek,2026-W43,,,9.28,Scan\nday,Sa,Urlaub,,,\ncategory_score,1.1,Sport / Verein,Mo,10,Scan\n"
        var state = baseState()
        let doc = parse(text, state)
        state.weeks[week.string] = WeekRecord(week: week, recordedScore: 9.28)
        state.days[week.day(.saturday).string] = DayRecord(day: week.day(.saturday), dayType: "Urlaub")
        state.closedWeeks = [week]
        state.closedDays = [week.monday, week.day(.saturday)]
        state.archiveGrades[week] = doc.archive(week)
        let again = ImportPreview.pastWeeks(doc, existing: state, replacingArchives: true, today: today)
        #expect(again.replacingWeeks.isEmpty && again.replacements.isEmpty)
        #expect(!again.hasChanges, "\(again.lines)")
        #expect(again.weekSummaries.first?.status == "unverändert")
        let changed = parse(text.replacingOccurrences(of: "Mo,10", with: "Mo,9"), state)
        #expect(ImportPreview.pastWeeks(changed, existing: state, replacingArchives: true, today: today).replacingWeeks == [week])
        // Something the app has beyond the file (a mark) replaces too.
        var marked = state
        let mark = MarkRecord(week: week, itemCode: "1.1-01", day: week.monday, mark: .done)
        marked.marks[mark.key] = mark
        #expect(ImportPreview.pastWeeks(doc, existing: marked, replacingArchives: true, today: today).replacingWeeks == [week])
    }

    /// The warnings name the app's marks, and the file's items next to grades.
    @Test func warningsNameMarksAndItems() throws {
        var state = baseState()
        for code in ["1.1-01", "1.1-02"] {
            let item = ItemRecord(week: week, code: code, categoryKey: "1.1", title: code)
            state.items[item.key] = item
        }
        let doc = parse("type,id,title,date,value\nweek,2026-W43,,,9\n", state)
        let plain = ImportPreview.pastWeeks(doc, existing: state, today: today)
        #expect(plain.weekSummaries.first?.warnings.contains("KW43: in der App noch 2 Punkte ohne Markierungen – \u{201A}Archivdaten ersetzen\u{2018} entfernt sie.") == true,
                "\(plain.weekSummaries.first?.warnings ?? [])")
        var marked = state
        let mark = MarkRecord(week: week, itemCode: "1.1-01", day: week.monday, mark: .done)
        marked.marks[mark.key] = mark
        let replaced = ImportPreview.pastWeeks(doc, existing: marked, replacingArchives: true, today: today)
        #expect(replaced.weekSummaries.first?.warnings.contains("KW43: 1 Markierung aus der App geht ins Archiv – die Datei bringt keine Einzelhaken.") == true,
                "\(replaced.weekSummaries.first?.warnings ?? [])")
        // Items and grades in one week: only the items count today.
        let both = parse("type,id,parent,title,days,schedule,date,value\nweek,2026-W43,,,,,,\nitem,1.1-01,1.1,Training,täglich,fix,,\n"
                         + "category_score,1.1,,Sport / Verein,,,Mo,6\n", state)
        let preview = ImportPreview.pastWeeks(both, existing: ExistingState(), today: today)
        let warnings = try #require(preview.weekSummaries.first?.warnings)
        #expect(warnings.contains("KW43: Punkte und Noten – nach heutigen Regeln zählen nur die Punkte, die Noten stehen im Archiv."), "\(warnings)")
    }
}

@Suite("v9 gaps: prompt")
struct V9GapPromptTests {
    /// The rules the review asked for, so the CSV can be made again from the same records.
    @Test func promptHasTheNewRules() {
        let text = PastWeekPrompt.text(weeks: [], items: [], categories: [CategoryRecord(key: "1.1", goalKey: "1", title: "Sport / Verein")],
                                       goals: [GoalRecord(key: "1", title: "Gesundheit")], measures: [])
        for phrase in ["erstelle sie nach diesen Regeln vollständig neu", "nenne ich keine, lass das widersprüchliche Feld weg",
                       "(9,19 → 9.19)", "Jede Zeile hat genau so viele Spalten wie die Kopfzeile",
                       "die Spalten mo … so gibt es nur in item-Zeilen", "Noten nie als Text in note oder description",
                       "auch wenn die Unterlage sie Kategorie nennt", "aus Kategoriennoten berechnen",
                       "ein Datum aus einer anderen Woche liest Thalia nicht", "das Beispiel selbst gehört nicht in die Antwort",
                       "week,\(PastWeekPrompt.weekPlaceholder),"] {
            #expect(text.contains(phrase), "\(phrase)")
        }
        #expect(!text.contains("2026-W10") && !text.contains("Scan S. 19"))
        // Pasted back as a whole: nothing lands in a week.
        let doc = PlanCSV.parse(text)
        #expect(doc.weeks.isEmpty && doc.grades.isEmpty && doc.days.isEmpty && doc.items.isEmpty)
    }
}
