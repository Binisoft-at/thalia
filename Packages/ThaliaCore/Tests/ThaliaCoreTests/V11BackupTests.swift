import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

/// v11 P3 (round 1): the CSV of backups and imports – one number reader, exact final scores, the backup's
/// date, goal year and plan changes, times of single values, the order of notes, the preview resolving the
/// file over the app, a year's backup read fast, the weeks a file is about (TASKS-v11 §3.1 "P3").
enum V11Backup {
    static let week = WeekKey(year: 2026, week: 47)
    static let utc = TimeZone(secondsFromGMT: 0) ?? .current
    static let categories = ["1.1": "Ernährung", "3.2": "Projekt"]

    static func date(_ text: String) -> Date { ExchangeDate.parse(text) ?? Date(timeIntervalSince1970: 0) }

    /// The app as the import finds it when it holds exactly `doc` (what `existingState()` builds in the store).
    static func state(_ doc: PlanCSV.Document) -> ExistingState {
        var state = ExistingState()
        for goal in doc.goals { state.goals[goal.key] = goal }
        for category in doc.categories { state.categories[category.key] = category }
        for record in doc.weeks { state.weeks[record.week.string] = record }
        for day in doc.days { state.days[day.day.string] = day }
        for item in doc.items { state.items[item.key] = item }
        for measure in doc.measures { state.measures[measure.key] = measure }
        for mark in doc.marks { state.marks[mark.key] = mark }
        for entry in doc.entries { state.entries[entry.key] = entry }
        for block in doc.work { state.work[block.id] = block }
        for note in doc.notes { state.notes[note.id] = note }
        for review in doc.reviews { state.reviews[review.key] = review }
        for score in doc.scores { state.scores[score.key] = score }
        for row in doc.records { state.records[row.key] = row }
        state.closedDays = doc.closedDays
        state.closedWeeks = doc.closedWeeks
        state.finalScores = doc.finalScores
        return state
    }

    /// The data lines of an export (without the header).
    static func rows(_ text: String) -> [String] { Array(text.components(separatedBy: "\n").dropFirst().filter { !$0.isEmpty }) }
}

@Suite("v11 P3.1 numbers")
struct V11BackupNumberTests {
    let week = V11Backup.week

    @Test func oneReader() {
        #expect(PlanCSV.number("1.125") == 1.125, "a single dot is a decimal point")
        #expect(PlanCSV.number("1,125") == 1.125)
        #expect(PlanCSV.number("8.000,5") == 8000.5, "both: German grouping")
        #expect(PlanCSV.number("1.234.567") == 1_234_567)
        #expect(PlanCSV.number(" -2,5 ") == -2.5)
        #expect(PlanCSV.number("8 000") == 8000)
        for bad in ["", "nan", "inf", "-inf", "1e5", "0x10", "12345678901234", "1,2,3", "acht", "8.000 €"] {
            #expect(PlanCSV.number(bad) == nil, "\(bad)")
        }
        // The older reader (`Format.parse`, the app's fields) reads what the writer writes the same way.
        #expect(Format.parse("1.1250") == 1.125)
        #expect(Format.parse("81.1250") == 81.125)
    }

    @Test func threeDecimalsGetAFourth() {
        #expect(PlanCSV.csvNumber(1.125) == "1.1250")
        #expect(PlanCSV.csvNumber(0.125) == "0.1250")
        #expect(PlanCSV.csvNumber(-81.125) == "-81.1250")
        #expect(PlanCSV.csvNumber(1.25) == "1.25")
        #expect(PlanCSV.csvNumber(8000) == "8000")
        #expect(PlanCSV.csvTarget(Target(.atMost, 81.125)) == "<=81.1250")
        #expect(PlanCSV.csvTarget(Target(.range, 1.125, upper: 2.5)) == "1.1250-2.5")
        #expect(PlanCSV.csvTarget(Target(.atMost, 23 * 60, isTime: true)) == "<=23:00")
    }

    @Test func valuesRoundTrip() throws {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.measures = [MeasureRecord(week: week, code: "strecke", categoryKey: "1.1", position: 1, title: "Strecke", unit: "km",
                                      target: Target(.atMost, 81.125))]
        doc.items = [ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Trinken", target: Target(.atLeast, 1.125),
                                measure: "wasser")]
        doc.entries = [EntryRecord(code: "strecke", day: week.monday, value: 81.125),
                       EntryRecord(code: "wasser", day: week.monday, value: 1.125),
                       EntryRecord(code: "zucker", day: week.monday, value: 0.125)]
        doc.work = [WorkRecord(id: "w1", day: week.monday, categoryKey: "3.2", task: "Text", powerHours: 1.125)]
        doc.scores = [ScoreRecord(categoryKey: "1.1", day: week.monday, score: 7.125)]
        let text = PlanCSV.export(doc)
        for written in ["81.1250", "1.1250", "0.1250", "7.1250", "<=81.1250", ">=1.1250"] {
            #expect(text.contains(written), "\(written)")
        }
        let back = PlanCSV.parse(text, knownCategories: V11Backup.categories)
        #expect(back.warnings.filter { $0.contains("Tausenderpunkt") }.isEmpty, "\(back.warnings)")
        #expect(back.skipped.isEmpty, "\(back.skipped)")
        #expect(back.entries.map(\.value) == [81.125, 1.125, 0.125])
        #expect(back.work.first?.powerHours == 1.125)
        #expect(back.scores.first?.score == 7.125)
        #expect(back.measures.first?.target == Target(.atMost, 81.125))
        #expect(back.items.first?.target == Target(.atLeast, 1.125))
        #expect(PlanCSV.export(back) == text, "the same file again")
    }

    @Test func thousandsDotReadsAsDecimalWithAHint() throws {
        let text = """
        type,id,parent,title,target,date,value,unit
        week,2026-W47,,,,,,
        entry,schritte,,,,2026-11-16,8.000,
        item,1.1-01,1.1,Schritte,≥8.000,,,
        entry,wasser,,,,2026-11-17,"8.000,5",
        entry,strecke,,,,2026-11-18,0.125,
        work,w1,3.2,Text,,2026-11-18,"1,5",PH
        """
        let doc = PlanCSV.parse(text, knownCategories: V11Backup.categories)
        #expect(doc.entries.first { $0.code == "schritte" }?.value == 8)
        #expect(doc.entries.first { $0.code == "wasser" }?.value == 8000.5)
        #expect(doc.entries.first { $0.code == "strecke" }?.value == 0.125)
        #expect(doc.work.first?.powerHours == 1.5)
        #expect(doc.items.first?.target == Target(.atLeast, 8))
        #expect(doc.warnings.contains("Zeile 3: \u{201E}8.000\u{201C} als 8 gelesen – Tausenderpunkt? Bitte 8000 schreiben"))
        #expect(doc.warnings.contains("Zeile 4: \u{201E}8.000\u{201C} als 8 gelesen – Tausenderpunkt? Bitte 8000 schreiben"))
        #expect(doc.warnings.filter { $0.contains("Tausenderpunkt") }.count == 2, "not for 8.000,5 or 0.125: \(doc.warnings)")
    }

    @Test func hugeAndOddNumbersNeverTrap() {
        // P1.1: the count column, a single entry's time and the final score's count with huge or odd numbers.
        let text = """
        type,id,title,date,value,flags,note,count
        week,2026-W47,,,,,,
        category_score,1.1,Ernährung,,7,,,1e300
        category_score,1.2,Sport,,7,,,99999999999999999999
        entry,ausgaben,1e300,2026-11-16,5,einzeln,,
        entry,ausgaben,nan,2026-11-16,6,einzeln,,
        entry,wert,1e300,2026-11-17,nan,,,
        wertung,2026-W47,,,7,,1=7,1e300
        """
        let doc = PlanCSV.parse(text)
        #expect(doc.grades.allSatisfy { $0.count == nil })
        #expect(doc.entries.first { $0.code == "ausgaben" }?.parts.map(\.minutes) == [0, 0])
        #expect(doc.skipped.contains { $0.contains("nan") })
        #expect(doc.finalScores[week]?.goalsScored == 1, "the count from the goal scores")
        #expect(doc.warnings.contains { $0.contains("Anzahl") && $0.contains("1e300") })
    }
}

@Suite("v11 P3.3 final scores")
struct V11BackupFinalScoreTests {
    let week = V11Backup.week

    func closedWeek(_ final: PlanCSV.FinalScore) -> PlanCSV.Document {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week, title: "Ruhig")]
        doc.closedWeeks = [week]
        doc.finalScores[week] = final
        return doc
    }

    @Test func exactToTheBit() throws {
        for score in [7.123456, 20.0 / 3.0, 0.1 + 0.2, 10.0, 0.0] {
            let final = PlanCSV.FinalScore(score: score, goalScores: "1=8.2;2=7.5", goalsScored: 2)
            let text = PlanCSV.export(closedWeek(final))
            #expect(text.hasPrefix(PlanCSV.header + ",count\n"), "the count column comes with the scores")
            let back = try #require(PlanCSV.parse(text).finalScores[week])
            #expect(back == final)
            #expect(back.score.bitPattern == score.bitPattern, "\(score)")
        }
        // Format.plain would have lost it.
        #expect(Format.plain(7.123456) == "7.1235")
        let text = PlanCSV.export(closedWeek(.init(score: 7.123456, goalScores: "1=8.2;2=7.5", goalsScored: 2)))
        #expect(V11Backup.rows(text).last == "wertung,2026-W47,,,,,,,,,,,,7.123456,1=8.2;2=7.5,2")
        #expect(V11Backup.rows(text).first?.hasPrefix("week,2026-W47,,Ruhig,") == true, "after the week's rows")
    }

    @Test func olderFilesAndOddRows() {
        // Without final scores the header and the rows stay as they were.
        var doc = closedWeek(.init(score: 7))
        doc.finalScores = [:]
        let text = PlanCSV.export(doc)
        #expect(text.hasPrefix(PlanCSV.header + "\n") && !text.contains("wertung"))
        #expect(PlanCSV.parse(text).finalScores.isEmpty)
        let odd = PlanCSV.parse("""
        type,id,value,note
        wertung,2026-W47,11,
        wertung,KW47,7,
        wertung,2026-W46,"7,5",1=7;2=8;3=9
        """)
        #expect(odd.skipped.count == 2, "\(odd.skipped)")
        #expect(odd.finalScores == [WeekKey(year: 2026, week: 46): .init(score: 7.5, goalScores: "1=7;2=8;3=9", goalsScored: 3)])
    }

    @Test func previewComparesWithTheStoredScore() {
        let final = PlanCSV.FinalScore(score: 7.123456, goalScores: "1=8.2", goalsScored: 1)
        let doc = PlanCSV.parse(PlanCSV.export(closedWeek(final)))
        var state = V11Backup.state(doc)
        #expect(!ImportPreview(document: doc, existing: state).hasChanges, "the same backup again")
        state.finalScores[week] = .init(score: 7.123457, goalScores: "1=8.2", goalsScored: 1)
        let changed = ImportPreview(document: doc, existing: state)
        #expect(changed.finalScores.updates == 1 && changed.hasChanges)
        #expect(changed.lines.contains("Wochenwertungen: 0 neu · 1 geändert · 0 gleich"))
        // A week that goes to the archive completely ("Archivdaten ersetzen") has no stored score any more.
        state.items["x"] = ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Punkt")
        #expect(ImportPreview(document: doc, existing: state, replacing: [week]).finalScores.creates == 1)
    }
}

@Suite("v11 P3.6 backup row")
struct V11BackupInfoTests {
    let week = V11Backup.week
    let made = V11Backup.date("2026-11-22T17:03:00Z")

    var info: PlanCSV.BackupInfo {
        .init(date: made, app: PlanCSV.BackupInfo.appName(version: "1.10.0", build: "58"), device: "iPhone")
    }

    @Test func firstRowRoundTrip() throws {
        var doc = PlanCSV.Document()
        doc.goals = [GoalRecord(key: "1", title: "Gesund")]
        doc.weeks = [WeekRecord(week: week)]
        doc.backupInfo = info
        let text = PlanCSV.export(doc)
        #expect(V11Backup.rows(text).first == "sicherung,2026-11-22T17:03:00.000Z,,Thalia 1.10.0 (58),iPhone,,,,,,,,,,")
        let back = PlanCSV.parse(text)
        #expect(back.backupInfo == info)
        #expect(back.skipped.isEmpty)
        #expect(info.headline(timeZone: TimeZone(secondsFromGMT: 3600) ?? .current) == "Sicherung vom 22.11.2026, 18:03 · Thalia 1.10.0 (58) · iPhone")
        #expect(PlanCSV.BackupInfo.appName(version: "1.10.0", build: "") == "Thalia 1.10.0")
        // An older file reads as before; a row without a date is skipped.
        doc.backupInfo = nil
        #expect(PlanCSV.parse(PlanCSV.export(doc)).backupInfo == nil)
        #expect(!PlanCSV.export(doc).contains("sicherung"))
        #expect(PlanCSV.parse("type,id\nsicherung,gestern\n").skipped.count == 1)
    }

    @Test func ageNoticeOnlyWithChanges() {
        let day = week.day(.friday)
        var file = PlanCSV.Document()
        file.backupInfo = info
        file.weeks = [WeekRecord(week: week)]
        file.marks = [MarkRecord(week: week, itemCode: "1.1-01", day: day, mark: .missed),
                      MarkRecord(week: week, itemCode: "1.1-02", day: day, mark: .missed)]
        file.entries = [EntryRecord(code: "strecke", day: day, value: 80)]
        var app = file
        app.marks = file.marks.map { var mark = $0; mark.mark = .done; return mark }
        app.entries = [EntryRecord(code: "strecke", day: day, value: 79)]
        let preview = ImportPreview(document: file, existing: V11Backup.state(app))
        let later = made.addingTimeInterval(9 * 86_400)
        #expect(preview.backupAgeNotice(now: later, timeZone: V11Backup.utc)
            == "Die Sicherung ist 9 Tage alt – 2 Markierungen und 1 Wert in der App weichen ab und werden auf den Stand der Sicherung gesetzt.")
        #expect(preview.backupAgeNotice(now: made.addingTimeInterval(20 * 3600)) == nil, "younger than a day")
        #expect(ImportPreview(document: file, existing: V11Backup.state(file)).backupAgeNotice(now: later) == nil, "nothing differs")
        app.marks.removeLast()
        app.entries = file.entries
        let one = ImportPreview(document: file, existing: V11Backup.state(app))
        #expect(one.backupAgeNotice(now: made.addingTimeInterval(30 * 3600), timeZone: V11Backup.utc)
            == "Die Sicherung ist 1 Tag alt – 1 Markierung in der App weicht ab und wird auf den Stand der Sicherung gesetzt.")
        #expect(preview.backupHeadline != nil)
        #expect(ImportPreview(document: PlanCSV.Document(), existing: ExistingState()).backupHeadline == nil)
    }

    @Test func olderBackupNotice() {
        var old = PlanCSV.Document()
        old.goals = [GoalRecord(key: "1", title: "Gesund")]
        old.categories = [CategoryRecord(key: "1.1", goalKey: "1", title: "Ernährung")]
        old.marks = [MarkRecord(week: week, itemCode: "1.1-01", day: week.monday, mark: .done),
                     MarkRecord(week: week.adding(weeks: -1), itemCode: "1.1-01", day: week.adding(weeks: -1).monday, mark: .done)]
        let notice = "Diese Sicherung stammt von einer älteren Thalia-Version – Ergebnisse, Leseliste und verbundene Apps fehlen darin."
        #expect(ImportPreview(document: old, existing: ExistingState()).olderBackupNotice == notice)
        var current = old
        current.backupInfo = info
        #expect(ImportPreview(document: current, existing: ExistingState()).olderBackupNotice == nil)
        var withRecords = old
        withRecords.records = [SettingRow(key: "score.2026-W47", value: "1.1=8")]
        #expect(ImportPreview(document: withRecords, existing: ExistingState()).olderBackupNotice == nil)
        var oneWeek = old
        oneWeek.marks.removeLast()
        #expect(ImportPreview(document: oneWeek, existing: ExistingState()).olderBackupNotice == nil, "a week's CSV")
        #expect(ImportPreview(document: Template.week(week), existing: ExistingState()).olderBackupNotice == nil, "a plan")
    }
}

@Suite("v11 P3.7 goal year and plan changes")
struct V11BackupSettingsTests {
    let week = V11Backup.week

    var goalYear: [SettingRow] {
        [SettingRow(key: "goal.motto", value: "Ruhig weiter"), SettingRow(key: "exchange.catalog", value: "aus"),
         SettingRow(key: "goal.review", value: "2026-W49"), SettingRow(key: "goal.end", value: "2027-05-31"),
         SettingRow(key: "goal.start", value: "2026-06-01")]
    }

    @Test func rowsRoundTripBeforeTheRecords() throws {
        var doc = PlanCSV.Document()
        let result = GoalResult(id: "r1", goalKey: "5", title: "Bücher", target: ">=10", modifiedAt: V11Backup.date("2026-11-20T08:00:00Z"))
        doc.records = [SettingRow(key: result.settingKey, value: result.settingValue)] + goalYear
        let text = PlanCSV.export(doc)
        let keys = V11Backup.rows(text).map { $0.split(separator: ",").dropFirst().first.map(String.init) ?? "" }
        #expect(keys == ["goal.start", "goal.end", "goal.review", "goal.motto", "exchange.catalog", "goal.result.r1"])
        let back = PlanCSV.parse(text)
        #expect(back.skipped.isEmpty, "\(back.skipped)")
        #expect(Set(back.records.map(\.key)) == Set(doc.records.map(\.key)))
        #expect(back.records.first { $0.key == "goal.motto" }?.value == "Ruhig weiter")
        #expect(back.records.first { $0.key == result.settingKey }?.value == result.settingValue, "a plain target stays byte for byte")
        let odd = PlanCSV.parse("type,id,note\nrecord,goal.start,morgen\nrecord,goal.review,KW49\nrecord,exchange.catalog,vielleicht\nrecord,goal.end,2027-05-31\n")
        #expect(odd.skipped.count == 3 && odd.records.map(\.key) == ["goal.end"])
    }

    @Test func importFillsInOnly() throws {
        var file = PlanCSV.Document()
        file.records = goalYear
        var app = ExistingState()
        app.records["goal.start"] = SettingRow(key: "goal.start", value: "2027-06-01")
        app.records["goal.end"] = SettingRow(key: "goal.end", value: "2028-05-31")
        app.records["exchange.catalog"] = SettingRow(key: "exchange.catalog", value: "an")
        let preview = ImportPreview(document: file, existing: app)
        let actions = Dictionary(uniqueKeysWithValues: preview.records.entries.map { ($0.key, $0.action) })
        #expect(actions["goal.start"] == .unchanged && actions["goal.end"] == .unchanged && actions["exchange.catalog"] == .unchanged)
        #expect(actions["goal.review"] == .create && actions["goal.motto"] == .create, "what the app lacks is filled in")
        #expect(preview.notices == ["Zieljahr in der Datei: 1.6.2026–31.5.2027 – in der App bleibt 1.6.2027–31.5.2028."])
        // The same goal year: no line; an app without one takes the file's.
        app.records["goal.start"] = SettingRow(key: "goal.start", value: "2026-06-01")
        app.records["goal.end"] = SettingRow(key: "goal.end", value: "2027-05-31")
        #expect(ImportPreview(document: file, existing: app).notices.isEmpty)
        let fresh = ImportPreview(document: file, existing: ExistingState())
        #expect(fresh.records.creates == 5 && fresh.notices.isEmpty)
    }

    @Test func planChangesRoundTrip() {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.changes = [
            PlanChangeRecord(week: week, kind: .added, target: .measure, code: "plank", title: "Plank", detail: "min, ≥3 pro Tag", carryOver: true),
            PlanChangeRecord(week: week, kind: .deleted, target: .item, code: "1.1-02", title: "Essfenster", carryOver: false),
            PlanChangeRecord(week: week, kind: .edited, target: .item, code: "1.1-01", title: "Protein", detail: "≥150 g", carryOver: true),
        ]
        let text = PlanCSV.export(doc)
        #expect(text.contains("change,plank,Messwert,Plank,\"min, ≥3 pro Tag\",,,,,,,dauerhaft,,neu,"))
        #expect(text.contains("change,1.1-02,Punkt,Essfenster,,,,,,,,einmalig,,gelöscht,"))
        let back = PlanCSV.parse(text)
        #expect(back.changes == doc.changes)
        #expect(back.skipped.isEmpty)
        #expect(!PlanCSV.export(PlanCSV.Document()).contains("change"))
        let odd = PlanCSV.parse("type,id,parent,title,value\nchange,plank,Messwert,Plank,neu\nweek,2026-W47,,,\nchange,plank,Ding,Plank,neu\nchange,,Punkt,X,neu\n")
        #expect(odd.changes.isEmpty && odd.skipped.count == 3, "before the week row, an unknown target, no id")
    }
}

@Suite("v11 P3.8 and P3.9 model, times, order")
struct V11BackupOrderTests {
    let week = V11Backup.week

    @Test func newModelBeforeKW42StaysNew() {
        let kw41 = WeekKey(year: 2026, week: 41)
        let kw40 = WeekKey(year: 2026, week: 40)
        let kw39 = WeekKey(year: 2026, week: 39)
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: kw41, scoringModel: ""), WeekRecord(week: kw40, scoringModel: "alt"), WeekRecord(week: week)]
        doc.marks = [MarkRecord(week: kw39, itemCode: "1.1-01", day: kw39.monday, mark: .done)]
        let text = PlanCSV.export(doc)
        #expect(text.contains("week,2026-W41,,,,,,,,,,neu,"))
        #expect(text.contains("week,2026-W40,,,,,,,,,,alt,"))
        #expect(text.contains("week,2026-W39,,,,,,,,,,,"), "a week without a stored row as before")
        #expect(text.contains("week,2026-W47,,,,,,,,,,,"))
        let back = PlanCSV.parse(text)
        #expect(back.weeks.first { $0.week == kw41 }?.scoringModel == "")
        #expect(back.weeks.first { $0.week == kw40 }?.scoringModel == "alt")
        #expect(back.weeks.first { $0.week == kw39 }?.scoringModel == "alt")
        #expect(back.weeks.first { $0.week == week }?.scoringModel == "")
    }

    @Test func singleValueKeepsItsTime() throws {
        let day = week.day(.tuesday)
        let at = day.date(minutes: 7 * 60 + 10).addingTimeInterval(42)
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.entries = [EntryRecord(code: "strecke", day: day, value: 80.5, order: at.timeIntervalSince1970),
                       EntryRecord(code: "puls", day: day, value: 60, order: 2),
                       EntryRecord(code: "laune", day: day, value: nil, text: "gut", order: day.date(minutes: 21 * 60).timeIntervalSince1970)]
        let text = PlanCSV.export(doc)
        #expect(text.contains("entry,strecke,,07:10,"))
        #expect(text.contains("entry,puls,,,"), "a plain position (demo data) is no time")
        #expect(text.contains("entry,laune,,21:00,"))
        let back = PlanCSV.parse(text)
        let timed = try #require(back.entries.first { $0.code == "strecke" })
        #expect(DayKey.minutes(of: Date(timeIntervalSince1970: timed.order)) == 7 * 60 + 10)
        #expect(DayKey(date: Date(timeIntervalSince1970: timed.order)) == day)
        #expect(back.entries.first { $0.code == "puls" }?.order == 0)
        // Re-importing compares without the time and keeps it for the import.
        var app = doc
        app.entries = doc.entries.map { var entry = $0; entry.order = 0; return entry }
        let preview = ImportPreview(document: back, existing: V11Backup.state(app))
        #expect(preview.entries.unchanged == 3 && !preview.hasChanges)
        #expect(preview.entries.entries.first { $0.key == timed.key }?.record.order == timed.order)
        // A file without times reads as before.
        #expect(PlanCSV.parse("type,id,date,value\nentry,strecke,2026-11-17,80\n").entries.first?.order == 0)
    }

    @Test func notesAndWorkKeepTheirOrderWithinADay() {
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.notes = [NoteRecord(id: "zz", day: week.monday, text: "zuerst"), NoteRecord(id: "aa", day: week.monday, text: "danach"),
                     NoteRecord(id: "mm", day: week.day(.sunday), text: "Sonntag"), NoteRecord(id: "bb", day: week.day(.tuesday), text: "Dienstag")]
        doc.work = [WorkRecord(id: "w9", day: week.monday, categoryKey: "3.2", task: "Früh", powerHours: 1),
                    WorkRecord(id: "w1", day: week.monday, categoryKey: "3.2", task: "Spät", powerHours: 2)]
        let back = PlanCSV.parse(PlanCSV.export(doc), knownCategories: V11Backup.categories)
        #expect(back.notes.map(\.text) == ["zuerst", "danach", "Dienstag", "Sonntag"])
        #expect(back.work.map(\.task) == ["Früh", "Spät"])
    }
}

@Suite("v11 P3.4 and P3.5 preview")
struct V11BackupPreviewTests {
    let week = V11Backup.week
    var friday: DayKey { week.adding(weeks: 1).day(.friday) }

    @Test func emptyNotesKeepTheAppsAndHolidaysStay() throws {
        let kw48 = week.adding(weeks: 1)
        #expect(friday.string == "2026-11-27")
        var app = PlanCSV.Document()
        app.days = [DayRecord(day: friday, dayType: "Urlaub", note: "Arzt 15:00")]
        app.marks = [MarkRecord(week: kw48, itemCode: "1.1-01", day: friday, mark: .done, note: "müde")]
        var file = PlanCSV.Document()
        file.days = [DayRecord(day: friday, dayType: "Arbeitstag")]
        file.marks = [MarkRecord(week: kw48, itemCode: "1.1-01", day: friday, mark: .done)]
        let preview = ImportPreview(document: file, existing: V11Backup.state(app))
        #expect(preview.notices == ["Fr 27.11.: bleibt \u{201E}Urlaub\u{201C} – die Datei sagt \u{201E}Arbeitstag\u{201C}."])
        #expect(preview.days.unchanged == 1 && preview.marks.unchanged == 1 && !preview.hasChanges)
        // The file's mark still wins – a cleared one too – with the app's note.
        file.marks = [MarkRecord(week: kw48, itemCode: "1.1-01", day: friday, mark: nil)]
        let cleared = ImportPreview(document: file, existing: V11Backup.state(app))
        let mark = try #require(cleared.marks.entries.first?.record)
        #expect(mark.mark == nil && mark.note == "müde" && cleared.marks.updates == 1)
        // Krank over Urlaub: both excused, the file wins; an empty type keeps the holiday without a line.
        file.days = [DayRecord(day: friday, dayType: "Krank")]
        let sick = ImportPreview(document: file, existing: V11Backup.state(app))
        #expect(sick.days.entries.first?.record == DayRecord(day: friday, dayType: "Krank", note: "Arzt 15:00") && sick.notices.isEmpty)
        file.days = [DayRecord(day: friday, dayType: "", note: "Neu")]
        let noted = ImportPreview(document: file, existing: V11Backup.state(app))
        #expect(noted.days.entries.first?.record == DayRecord(day: friday, dayType: "Urlaub", note: "Neu") && noted.notices.isEmpty)
        #expect(noted.weekSummaries.first?.excusedDays == [friday], "the summary shows what stays")
        // Idempotent: what the import writes, previewed again, is unchanged.
        var applied = app
        applied.days = noted.days.entries.map(\.record)
        applied.marks = cleared.marks.entries.map(\.record)
        file.marks = [MarkRecord(week: kw48, itemCode: "1.1-01", day: friday, mark: nil)]
        #expect(!ImportPreview(document: file, existing: V11Backup.state(applied)).hasChanges)
    }

    @Test func blanksAsMissedSkipAKeptHoliday() {
        let past = WeekKey(year: 2026, week: 45)
        let holiday = past.day(.friday)
        var app = PlanCSV.Document()
        app.days = [DayRecord(day: holiday, dayType: "Urlaub")]
        var file = PlanCSV.Document()
        file.weeks = [WeekRecord(week: past)]
        file.items = [ItemRecord(week: past, code: "1.1-01", categoryKey: "1.1", position: 1, title: "Trinken")]
        file.plannedWeeks = [past]
        file.days = [DayRecord(day: holiday, dayType: "Arbeitstag")]
        let preview = ImportPreview.pastWeeks(file, existing: V11Backup.state(app), blanksAsMissed: true,
                                              today: DayKey(year: 2026, month: 11, day: 23))
        let filled = Set(preview.document.marks.filter { $0.mark == .missed }.map(\.day))
        #expect(filled.contains(past.monday) && !filled.contains(holiday), "\(filled)")
        #expect(preview.notices == ["Fr 06.11.: bleibt \u{201E}Urlaub\u{201C} – die Datei sagt \u{201E}Arbeitstag\u{201C}."])
    }

    @Test func movedEntryCountsOnce() throws {
        let older = V11Backup.date("2026-11-20T08:00:00Z")
        let newer = V11Backup.date("2026-11-21T08:00:00Z")
        let moved = GoalEntry(id: "e1", day: week.day(.tuesday), resultID: "r1", value: 1, modifiedAt: newer)
        let before = GoalEntry(id: "e1", day: week.monday, resultID: "r1", value: 1, modifiedAt: older)
        #expect(moved.settingKey != before.settingKey)
        // The file's copy is newer: written, the app's other key goes.
        var file = PlanCSV.Document()
        file.records = [SettingRow(key: moved.settingKey, value: moved.settingValue)]
        var app = ExistingState()
        app.records[before.settingKey] = SettingRow(key: before.settingKey, value: before.settingValue)
        let preview = ImportPreview(document: file, existing: app)
        #expect(preview.records.creates == 1 && preview.removedRecords == [before.settingKey] && preview.hasChanges)
        // The app's copy is newer: nothing to write, nothing to delete.
        var reverse = PlanCSV.Document()
        reverse.records = [SettingRow(key: before.settingKey, value: before.settingValue)]
        var newerApp = ExistingState()
        newerApp.records[moved.settingKey] = SettingRow(key: moved.settingKey, value: moved.settingValue)
        let kept = ImportPreview(document: reverse, existing: newerApp)
        #expect(kept.records.unchanged == 1 && kept.records.creates == 0 && kept.removedRecords.isEmpty && !kept.hasChanges)
        // A reading moved to another day, as new as the app's: the app's stays.
        let reading = ListProgress(id: "p1", day: week.monday, itemID: "b1", reached: 120, modifiedAt: older)
        let readingMoved = ListProgress(id: "p1", day: week.day(.wednesday), itemID: "b1", reached: 120, modifiedAt: older)
        var books = PlanCSV.Document()
        books.records = [SettingRow(key: readingMoved.settingKey, value: readingMoved.settingValue)]
        var bookApp = ExistingState()
        bookApp.records[reading.settingKey] = SettingRow(key: reading.settingKey, value: reading.settingValue)
        let same = ImportPreview(document: books, existing: bookApp)
        #expect(same.records.unchanged == 1 && same.removedRecords.isEmpty)
    }

    @Test func headlineCountsInTheSingular() {
        var doc = PlanCSV.Document()
        doc.goals = [GoalRecord(key: "1", title: "Gesund")]
        doc.items = [ItemRecord(week: week, code: "1.1-01", categoryKey: "1.1", title: "Trinken")]
        doc.measures = [MeasureRecord(week: week, code: "wasser", title: "Wasser")]
        doc.plannedWeeks = [week]
        doc.measuredWeeks = [week]
        #expect(ImportPreview(document: doc, existing: ExistingState()).headline == "KW47 2026 (16.–22. Nov.): 1 Punkt in 1 Kategorie · 1 Messwert")
        let parsed = PlanCSV.parse(PlanCSV.export(doc))
        #expect(parsed.warnings.contains("Die Datei hat 1 Jahresziel (bisher immer 10)."))
    }

    @Test func previewRunsOffTheMainThread() async {
        let text = PlanCSV.export(Template.week(week))
        let state = ExistingState()
        let preview = await Task.detached { ImportPreview(text: text, existing: state) }.value
        #expect(preview.items.creates > 0)
    }
}

@Suite("v11 P1.3 and the records a backup carries")
struct V11BackupRecordTests {
    let week = V11Backup.week

    @Test func targetsReadStrictly() {
        let text = """
        type,id,parent,title,target,link
        week,2026-W47,,,,
        item,1.1-01,1.1,Ungefähr,ca 150,
        item,1.1-02,1.1,Abends,spätestens 23:00,
        item,1.1-03,1.1,Fenster,22:30 bis 23:00,
        measure,protein,1.1,Protein,≥150 g,
        """
        let doc = PlanCSV.parse(text, knownCategories: V11Backup.categories)
        #expect(doc.items.first { $0.code == "1.1-01" }?.target == nil)
        #expect(doc.warnings.contains("Zeile 3: Ziel \u{201C}ca 150\u{201D} nicht lesbar – ignoriert"))
        #expect(doc.items.first { $0.code == "1.1-02" }?.target == Target(.atMost, 23 * 60, isTime: true))
        #expect(doc.items.first { $0.code == "1.1-03" }?.target == Target(.range, 22 * 60 + 30, upper: 23 * 60, isTime: true))
        #expect(doc.measures.first?.target == Target(.atLeast, 150))
    }

    @Test func resultTargetsStoredPlain() throws {
        let result = GoalResult(id: "r1", goalKey: "1", title: "Spät ins Bett", kind: .value, target: "spätestens 23:00",
                                targets: ["s2": "höchstens 80", "s3": "<=79"], modifiedAt: V11Backup.date("2026-11-20T08:00:00Z"))
        var doc = PlanCSV.Document()
        doc.records = [SettingRow(key: result.settingKey, value: result.settingValue)]
        let back = PlanCSV.parse(PlanCSV.export(doc))
        let row = try #require(back.records.first)
        let stored = try #require(GoalResult(settingValue: row.value))
        #expect(stored.target == "<=23:00")
        #expect(stored.targets == ["s2": "<=80", "s3": "<=79"])
        #expect(stored.modifiedAt == result.modifiedAt && stored.title == result.title)
        #expect(PlanCSV.normalizedResultTargets("kein json") == "kein json")
    }

    @Test func deviceAndHealthRecordsNeverComeIn() {
        // HEALTHSHARE: a key check – it stays when the sharing goes (§1.4.12 (c)).
        let keys = ["hshare.2026-11-20", "hshare.state", "rescore.2026-W47", "backup.last", "sync.build.abc", "sync.seen.abc"]
        for key in keys { #expect(!PlanCSV.isBackupSetting(key), "\(key)") }
        let text = "type,id,note\n" + keys.map { "record,\($0),\"{\"\"v\"\":1,\"\"by\"\":\"\"x\"\"}\"" }.joined(separator: "\n") + "\n"
        let doc = PlanCSV.parse(text)
        #expect(doc.records.isEmpty && doc.skipped.count == keys.count)
        // The writer never lets them through either (a full backup holds no Health values and no device records).
        var backup = PlanCSV.Document()
        backup.records = keys.map { SettingRow(key: $0, value: #"{"v":1}"#) } + [SettingRow(key: "score.2026-W47", value: "1.1=8")]
        let written = PlanCSV.export(backup)
        // HEALTHSHARE: a key check – it stays when the sharing goes.
        #expect(!written.contains("hshare.") && !written.contains("backup.last") && !written.contains("rescore."))
        #expect(written.contains("record,score.2026-W47,,"))
    }
}

@Suite("v11 P3.10 and P3.12 reading")
struct V11BackupReaderTests {
    let week = V11Backup.week

    @Test func lastRowWinsInTheOrderAsBefore() {
        let text = """
        type,id,parent,title,description,date,value,flags,note,mo
        goal,1,,Alt,,,,,,
        goal,2,,Zwei,,,,,,
        goal,1,,Neu,,,,,,
        category,1.1,1,Alt,,,,,,
        category,1.2,1,Zwei,,,,,,
        category,1.1,1,Neu,,,,,,
        week,2026-W47,,Erst,,,,,,
        week,2026-W46,,Andere,,,,,,
        week,2026-W47,,Dann,,,,,,
        day,2026-11-16,,Arbeitstag,,,,,,
        day,2026-11-17,,Frei,,,,,,
        day,2026-11-16,,Urlaub,,,,,,
        item,1.1-01,1.1,Erst,,,,,,✓
        item,1.1-02,1.1,Zwei,,,,,,
        item,1.1-01,1.1,Dann,,,,,,½
        mark,1.1-02,,,,2026-11-16,1,,a,
        mark,1.1-01,,,,2026-11-16,0,,b,
        mark,1.1-02,,,,2026-11-16,0,,c,
        entry,strecke,,,,2026-11-16,80,,,
        entry,wasser,,,,2026-11-16,2,,,
        entry,strecke,,,,2026-11-16,81,,,
        entry,ausgaben,,08:00,,2026-11-16,5,einzeln,,
        entry,ausgaben,,12:00,,2026-11-16,7,einzeln,,
        work,w1,1.1,Erst,,2026-11-16,1,,,
        work,w2,1.1,Zwei,,2026-11-16,1,,,
        work,w1,1.1,Dann,,2026-11-16,2,,,
        note,n1,,,erst,2026-11-16,,,,
        note,n2,,,zwei,2026-11-16,,,,
        note,n1,,,dann,2026-11-16,,,,
        review,2026-W47,,gut,erst,,,,,
        review,2026-W47,,schwer,zwei,,,,,
        review,2026-W47,,gut,dann,,,,,
        score,1.1,,,,2026-11-16,7,,,
        score,1.2,,,,2026-11-16,6,,,
        score,1.1,,,,2026-11-16,8,,,
        record,score.2026-W47,,,,,,,1.1=7,
        record,score.2026-W46,,,,,,,1.1=6,
        record,score.2026-W47,,,,,,,1.1=8,
        """
        let doc = PlanCSV.parse(text)
        #expect(doc.goals.map(\.title) == ["Zwei", "Neu"])
        #expect(doc.categories.map(\.title) == ["Zwei", "Neu"])
        #expect(doc.weeks.map(\.title) == ["Andere", "Dann"])
        #expect(doc.days.map(\.dayType) == ["Frei", "Urlaub"])
        #expect(doc.items.map(\.title) == ["Zwei", "Dann"])
        #expect(doc.marks.map { "\($0.itemCode):\($0.mark?.rawValue ?? "-"):\($0.note)" } == ["1.1-01:0:b", "1.1-02:0:c"])
        #expect(doc.entries.map { "\($0.code)=\(Format.plain($0.value ?? -1))" } == ["wasser=2", "strecke=81", "ausgaben=12"])
        #expect(doc.entries.last?.parts.count == 2)
        #expect(doc.work.map(\.task) == ["Zwei", "Dann"])
        #expect(doc.notes.map(\.text) == ["zwei", "dann"])
        #expect(doc.reviews.map(\.text) == ["zwei", "dann"])
        #expect(doc.scores.map { "\($0.categoryKey)=\(Format.plain($0.score))" } == ["1.2=6", "1.1=8"])
        #expect(doc.records.map(\.value) == ["1.1=6", "1.1=8"])
        #expect(doc.warnings.filter { $0.contains("doppelt") }.count == 6, "\(doc.warnings)")
    }

    /// A year of backups (52 weeks, about 17 000 rows) is written, read and compared in well under 5 s.
    @Test func aYearReadsFast() {
        var doc = PlanCSV.Document()
        doc.goals = (1...10).map { GoalRecord(key: "\($0)", title: "Ziel \($0)") }
        doc.categories = (1...10).flatMap { goal in (1...2).map { CategoryRecord(key: "\(goal).\($0)", goalKey: "\(goal)", title: "Bereich \(goal).\($0)") } }
        let first = WeekKey(year: 2025, week: 48)
        for offset in 0..<52 {
            let week = first.adding(weeks: offset)
            doc.weeks.append(WeekRecord(week: week, title: "Woche \(offset)"))
            doc.closedWeeks.insert(week)
            doc.finalScores[week] = .init(score: 5 + Double(offset % 50) / 10.0 + 0.0123456, goalScores: "1=7.5;2=8", goalsScored: 2)
            for (index, day) in week.days.enumerated() {
                doc.closedDays.insert(day)
                if index == 5 { doc.days.append(DayRecord(day: day, dayType: "Frei", note: "Ausflug")) }
                for code in ["strecke", "wasser", "schritte", "schlaf"] {
                    doc.entries.append(EntryRecord(code: code, day: day, value: Double(index * 7 + offset) + 0.125))
                }
                doc.entries.append(EntryRecord(code: "ausgaben", day: day, value: 12.5, parts: [EntryPart(value: 5, minutes: 480), EntryPart(value: 7.5, minutes: 720)]))
                doc.work.append(WorkRecord(id: "w-\(day.string)", day: day, categoryKey: "3.2", task: "Projekt", powerHours: 1.5))
                doc.notes.append(NoteRecord(id: "n-\(day.string)", day: day, text: "Notiz \(index)"))
                doc.reviews.append(ReviewRecord(scope: day.string, field: "gut", text: "Tag \(index)"))
            }
            for item in 1...30 {
                let category = "\((item - 1) / 3 + 1).\(item % 2 + 1)"
                let code = "\(category)-\(item)"
                doc.items.append(ItemRecord(week: week, code: code, categoryKey: category, position: item, title: "Punkt \(item)"))
                for day in week.days { doc.marks.append(MarkRecord(week: week, itemCode: code, day: day, mark: (item + day.day) % 3 == 0 ? .missed : .done)) }
            }
            doc.measures.append(MeasureRecord(week: week, code: "strecke", title: "Strecke", unit: "km"))
            doc.plannedWeeks.insert(week)
            doc.measuredWeeks.insert(week)
        }
        let clock = ContinuousClock()
        let start = clock.now
        let text = PlanCSV.export(doc)
        let parsed = PlanCSV.parse(text, knownCategories: Dictionary(uniqueKeysWithValues: doc.categories.map { ($0.key, $0.title) }))
        let preview = ImportPreview(document: parsed, existing: V11Backup.state(parsed))
        let elapsed = clock.now - start
        #expect(V11Backup.rows(text).count > 15_000)
        #expect(parsed.skipped.isEmpty)
        #expect(parsed.marks.count == doc.marks.count && parsed.entries.count == doc.entries.count && parsed.finalScores == doc.finalScores)
        #expect(!preview.hasChanges, "the same year again")
        #expect(elapsed < .seconds(5), "\(elapsed)")
    }

    @Test func referencedWeeksPerRowKind() {
        let w47: Set<WeekKey> = [week]
        func weeks(_ rows: String) -> Set<WeekKey> {
            PlanCSV.parse("type,id,parent,title,date,value,note\n" + rows + "\n", knownCategories: V11Backup.categories).referencedWeeks
        }
        #expect(weeks("week,2026-W47,,,,,") == w47)
        #expect(weeks("day,2026-11-18,,Frei,,,") == w47)
        #expect(weeks("week,2026-W47,,,,,\nitem,1.1-01,1.1,Punkt,,,") == w47)
        #expect(weeks("week,2026-W47,,,,,\nmeasure,strecke,,Strecke,,,") == w47)
        #expect(weeks("mark,1.1-01,,,2026-11-18,1,") == w47)
        #expect(weeks("entry,strecke,,,2026-11-18,80,") == w47)
        #expect(weeks("work,w1,3.2,Text,2026-11-18,1,") == w47)
        #expect(weeks("note,n1,,,2026-11-18,,Text") == w47)
        #expect(weeks("review,2026-W47,,gut,,,") == w47)
        #expect(weeks("review,2026-11-18,,gut,,,") == w47)
        #expect(weeks("score,1.1,,,2026-11-18,7,") == w47)
        #expect(weeks("week,2026-W47,,,,,\ncategory_score,1.1,,Ernährung,,7,") == w47)
        #expect(weeks("wertung,2026-W47,,,,7,") == w47)
        #expect(weeks("week,2026-W47,,,,,\nchange,plank,Messwert,Plank,,neu,") == w47)
        #expect(weeks("record,score.2026-W40,,,,,1.1=8").isEmpty, "records are looked up by key")
        #expect(weeks("sicherung,2026-11-22T17:03:00Z,,Thalia,,,").isEmpty)
        // A day row of another week's block is skipped, a mark counts by its date.
        #expect(weeks("week,2026-W46,,,,,\nmark,1.1-01,,,2026-11-18,1,") == [week, week.adding(weeks: -1)])
    }
}
