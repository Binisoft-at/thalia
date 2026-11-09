import Foundation
import Testing
import BinisoftKitCore
@testable import ThaliaCore

@Suite("Plan CSV")
struct PlanCSVTests {
    let week = WeekKey(year: 2026, week: 45)

    /// What the app would hold after importing `doc`.
    func existing(from doc: PlanCSV.Document) -> ExistingState {
        var state = ExistingState()
        for goal in doc.goals { state.goals[goal.key] = goal }
        for category in doc.categories { state.categories[category.key] = category }
        for week in doc.weeks { state.weeks[week.week.string] = week }
        for day in doc.days { state.days[day.day.string] = day }
        for item in doc.items { state.items[item.key] = item }
        for measure in doc.measures { state.measures[measure.key] = measure }
        for mark in doc.marks { state.marks[mark.key] = mark }
        for entry in doc.entries { var e = entry; e.order = 0; state.entries[entry.key] = e }
        for block in doc.work { state.work[block.id] = block }
        for note in doc.notes { state.notes[note.id] = note }
        for review in doc.reviews { state.reviews[review.key] = review }
        for score in doc.scores { state.scores[score.key] = score }
        return state
    }

    @Test func templateHasTenGoalsEighteenCategoriesAndOnlyTheItemsNeeded() {
        let doc = Template.week(week)
        #expect(doc.goals.count == 10)
        #expect(doc.categories.count == 18)
        let counts = Dictionary(grouping: doc.items, by: \.categoryKey).mapValues(\.count)
        #expect(counts.count == 18, "every category has at least one item")
        #expect(counts.values.allSatisfy { (1...6).contains($0) }, "no filler: \(counts)")
        let codes = Set(doc.measures.map(\.code))
        for item in doc.items where !item.measure.isEmpty {
            #expect(codes.contains(item.measure), "\(item.code) links to \(item.measure)")
        }
        for item in doc.items where item.schedule == .progress {
            #expect(doc.measures.first { $0.code == item.measure }?.period == .week, "\(item.code) needs a weekly target")
        }
        #expect(Set(doc.items.map(\.code)).count == doc.items.count)
        #expect(!doc.measures.contains { ["protein", "kalorien", "wasser", "plank", "training"].contains($0.code) }, "food and training are just checked")
    }

    @Test func templateRoundTripsThroughTheCSV() {
        let original = Template.week(week)
        let text = PlanCSV.export(original)
        #expect(text.hasPrefix(PlanCSV.header + "\n"))
        let parsed = PlanCSV.parse(text)
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped)")
        #expect(parsed.warnings.isEmpty, "\(parsed.warnings)")
        #expect(parsed.goals == original.goals)
        #expect(parsed.categories.sortedByKey() == original.categories.sortedByKey())
        #expect(parsed.items.sortedForSheet() == original.items.sortedForSheet())
        #expect(parsed.measures.sorted { $0.position < $1.position } == original.measures.sorted { $0.position < $1.position })
        #expect(parsed.days.sorted { $0.day < $1.day } == original.days.sorted { $0.day < $1.day })
        #expect(parsed.weeks == original.weeks)
    }

    @Test func reimportingTheSameFileChangesNothing() {
        let text = Template.weekCSV(week)
        let first = ImportPreview(text: text, existing: ExistingState())
        #expect(first.items.creates == Template.week(week).items.count)
        #expect(first.hasChanges)
        let second = ImportPreview(text: text, existing: existing(from: first.document))
        #expect(!second.hasChanges, "\(second.lines)")
        #expect(second.items.unchanged == Template.week(week).items.count)
        #expect(second.replacedWeeks.isEmpty, "an unchanged file replaces nothing")
        #expect(second.removedItems.isEmpty)
    }

    @Test func revisedPlanUpdatesAndRemoves() {
        let original = Template.week(week)
        var revised = original
        revised.items.removeAll { $0.code == "1.1-05" }
        if let index = revised.items.firstIndex(where: { $0.code == "1.1-03" }) {
            revised.items[index].details = "160–180 g diese Woche."
        }
        let preview = ImportPreview(text: PlanCSV.export(revised), existing: existing(from: original))
        #expect(preview.items.updates == 1)
        #expect(preview.removedItems == ["2026-W45|1.1-05"])
        #expect(preview.replacedWeeks == [week])
        #expect(preview.lines.contains { $0.contains("ersetzt den bisherigen Plan") })
        #expect(!preview.document.warnings.contains { $0.contains("genau 10") }, "no ten-items rule any more")
    }

    @Test func resultsOnlyFileRemovesNothing() {
        let original = Template.week(week)
        let text = """
        type,id,date,value,note
        week,2026-W45,,,
        mark,1.1-01,2026-11-02,1,
        mark,1.1-02,2026-11-02,X,Restaurant
        """
        let preview = ImportPreview(text: text, existing: existing(from: original))
        #expect(preview.removedItems.isEmpty)
        #expect(preview.marks.creates == 2)
        #expect(preview.document.marks.last?.mark == .missed)
        #expect(preview.document.marks.last?.note == "Restaurant")
    }

    @Test func pastedChatGPTAnswerAndGermanHeaders() {
        let answer = """
        Hier ist deine Woche:

        ```csv
        typ,id,eltern,titel,beschreibung,tage,rhythmus,einheit,zielwert,zeitraum,verknüpfung,merkmale,datum,wert,notiz
        woche,KW46 2026,,Ruhige Woche,"Annahme: Mittwoch frei, ersetzt alte Vorgabe",,,,,,,,,,
        tag,Mi,,Frei,Feiertag,,,,,,,,,,
        messwert,protein,1.1,Protein,,,,g,>=150,tag,health:protein,,,,
        punkt,1.1-01,1.1,Protein erfassen,"Menge notieren, Schätzungen kennzeichnen",täglich,fix,,,,protein,,,,
        punkt,1.2-01,1.2,Tennis an der Wand,,"Di,Do,Sa",woche:2,,,,,,,,
        ```

        Annahmen: Mittwoch ist frei.
        """
        let doc = PlanCSV.parse(answer, knownCategories: ["1.1": "Ernährung und Gewicht", "1.2": "Training und Tennis"])
        #expect(doc.skipped.isEmpty, "\(doc.skipped)")
        let w46 = WeekKey(year: 2026, week: 46)
        #expect(doc.weeks.first?.week == w46)
        #expect(doc.weeks.first?.details == "Annahme: Mittwoch frei, ersetzt alte Vorgabe")
        #expect(doc.days.first?.day == w46.day(.wednesday))
        #expect(doc.days.first?.dayType == "Frei")
        #expect(doc.measures.first?.source == .health(.protein))
        #expect(doc.items.count == 2)
        #expect(doc.items[1].schedule == .weekly(2))
        #expect(doc.items[1].days.days == [.tuesday, .thursday, .saturday])
        #expect(doc.items[0].details == "Menge notieren, Schätzungen kennzeichnen")
    }

    @Test func problemsAreExplained() {
        let text = """
        type,id,parent,title,days,target
        item,1.1-01,1.1,Ohne Woche,,
        week,2026-W45,,,,
        item,9.9-01,9.9,Unbekannte Kategorie,,
        item,1.1-02,1.1,Komische Tage,irgendwann,
        item,1.1-03,1.1,Komisches Ziel,,viel
        item,1.1-04,1.1,,,
        quatsch,1,,,,
        """
        let doc = PlanCSV.parse(text, knownCategories: ["1.1": "Ernährung"])
        #expect(doc.skipped.contains { $0.contains("vor der ersten week-Zeile") })
        #expect(doc.skipped.contains { $0.contains("Kategorie 9.9 gibt es nicht") })
        #expect(doc.skipped.contains { $0.contains("Punkt ohne Titel") })
        #expect(doc.skipped.contains { $0.contains("unbekannter Typ") })
        #expect(doc.warnings.contains { $0.contains("Tage") && $0.contains("täglich angenommen") })
        #expect(doc.warnings.contains { $0.contains("Ziel") && $0.contains("ignoriert") })
        #expect(doc.items.count == 2)
    }

    @Test func missingTypeColumn() {
        let doc = PlanCSV.parse("title,notes\nMilk,\n")
        #expect(doc.isEmpty)
        #expect(doc.skipped.first?.contains("type") == true)
    }

    @Test func historyWeeksBeforeKW42UseTheOldModel() {
        let text = """
        type,id,value,flags
        week,2026-W30,6.4,
        week,2026-W43,7.1,
        week,2026-W44,6.9,alt
        """
        let doc = PlanCSV.parse(text)
        #expect(doc.weeks.map(\.isOldScoring) == [true, false, true])
        #expect(doc.weeks.first?.recordedScore == 6.4)
        #expect(ImportPreview(document: doc, existing: ExistingState()).headline.contains("Wertung 6,4"))
    }

    @Test func resultsRoundTrip() {
        var doc = PlanCSV.Document()
        let day = week.monday
        doc.weeks = [WeekRecord(week: week)]
        doc.marks = [MarkRecord(week: week, itemCode: "1.1-01", day: day, mark: .partial, note: "halbe Portion")]
        doc.entries = [EntryRecord(code: "protein", day: day, value: 155, estimate: true),
                       EntryRecord(code: "notiz", day: day, value: nil, text: "Text, mit Komma")]
        doc.work = [WorkRecord(id: "w1", day: day, categoryKey: "3.2", task: "Landingpage", result: "Hero fertig", powerHours: 1, nextStep: "Screenshots"),
                    WorkRecord(id: "w2", day: day, categoryKey: "3.3", task: "Lena – Mathe", powerHours: 0.25)]
        doc.notes = [NoteRecord(id: "n1", day: day, kind: .idea, text: "Newsletter")]
        doc.reviews = [ReviewRecord(scope: day.string, field: "verhalten", text: "Ruhig\nund klar"),
                       ReviewRecord(scope: week.string, field: "wiederholen", text: "Erster Block vor 9")]
        doc.scores = [ScoreRecord(categoryKey: "4", day: day, score: 0, reason: "Persönliche Regel")]
        let parsed = PlanCSV.parse(PlanCSV.export(doc))
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped)")
        #expect(parsed.marks == doc.marks)
        #expect(parsed.entries.sorted { $0.code < $1.code } == doc.entries.sorted { $0.code < $1.code })
        #expect(parsed.work == doc.work)
        #expect(parsed.notes == doc.notes)
        #expect(parsed.reviews.sorted { $0.key < $1.key } == doc.reviews.sorted { $0.key < $1.key })
        #expect(parsed.scores == doc.scores)
    }

    @Test func slugs() {
        #expect(PlanCSV.slug("Zweite Aufschläge") == "zweite_aufschlaege")
        #expect(PlanCSV.slug("Protein (g)") == "protein_g")
    }
}

@Suite("Demo, prompt, report, reminders, tour")
struct ContentTests {
    let today = DayKey(year: 2026, month: 11, day: 4)

    @Test func demoIsDeterministicAndConsistent() {
        let a = Demo.content(today: today)
        let b = Demo.content(today: today)
        #expect(a.document.marks == b.document.marks)
        #expect(a.document.entries == b.document.entries)
        #expect(a.closedDays.contains(today.adding(days: -1)))
        #expect(!a.closedDays.contains(today))
        #expect(a.closedWeeks == [today.week.adding(weeks: -1)])
        #expect(a.document.items.count == 2 * Template.week(today.week).items.count)
        #expect(a.document.weeks.contains { $0.isOldScoring })
        // It survives its own export and re-import.
        let parsed = PlanCSV.parse(PlanCSV.export(a.document))
        #expect(parsed.skipped.isEmpty, "\(parsed.skipped.prefix(3))")
        #expect(parsed.marks.count == a.document.marks.count)
    }

    @Test func demoWeekScoresSensibly() {
        let content = Demo.content(today: today, history: false)
        let doc = content.document
        var marks: [String: Mark] = [:]
        for mark in doc.marks { if let m = mark.mark { marks[WeekData.markKey(mark.itemCode, mark.day)] = m } }
        let score = Scorer.score(WeekData(week: today.week, goals: doc.goals, categories: doc.categories, items: doc.items, marks: marks))
        let overall = score.overall ?? 0
        #expect(overall > 5 && overall < 9.5, "\(overall)")
        // A goal waits while one of its categories has nothing countable and still something blank
        // (U18.1) – mid-week that can be one or two goals.
        #expect(score.goalsScored >= 8)
        #expect((score.days[today]?.blank ?? 0) > 0, "today is still being filled in")
    }

    @Test func promptListsManualChanges() {
        let week = WeekKey(year: 2026, week: 46)
        let change = PlanChangeRecord(week: week.adding(weeks: -1), kind: .added, target: .measure, code: "plank", title: "Plank",
                                      detail: "min, ≥3 pro Tag", carryOver: true)
        let temporary = PlanChangeRecord(week: week.adding(weeks: -1), kind: .deleted, target: .item, code: "1.1-02", title: "Essfenster",
                                         carryOver: false)
        let text = PlanPrompt.text(for: week, goals: Template.goals, categories: Template.categories, measures: [], lastWeekReport: nil,
                                   changes: [change, temporary])
        #expect(text.contains("Messwert neu: Plank (plank) – min, ≥3 pro Tag → dauerhaft übernehmen"))
        #expect(text.contains("Punkt gelöscht: Essfenster (1.1-02) → nur diese Woche, nicht übernehmen"))
    }

    @Test func promptDefinesTheFormatAndCarriesTheStructure() {
        let week = WeekKey(year: 2026, week: 46)
        let template = Template.week(week)
        let text = PlanPrompt.text(for: week, goals: template.goals, categories: template.categories, measures: template.measures,
                                   lastWeekReport: "# Wochenbericht KW45")
        #expect(text.contains("\n" + PlanCSV.header + "\n"))
        #expect(text.contains("so viele Punkte wie nötig"))
        #expect(text.contains("schedule fortschritt"))
        #expect(!text.contains("genau 10"))
        #expect(text.contains("- 1 Fit Body: 1.1 Ernährung und Gewicht · 1.2 Training und Tennis"))
        #expect(text.contains("- stammloop_ph: stammloop (PH, >=8 pro Woche, arbeit:3.2)"))
        #expect(text.contains("# Wochenbericht KW45"))
        #expect(text.hasSuffix("## Mein Rückblick und Plan für KW46:\n"))
        // The example in the prompt is valid input.
        let example = PlanCSV.parse(PlanPrompt.exampleCSV(week), knownCategories: ["1.1": "a", "1.2": "b", "2.2": "j", "3.2": "s", "4": "c"])
        #expect(example.skipped.isEmpty, "\(example.skipped)")
        #expect(example.items.count == 6)
        #expect(example.items.contains { $0.secondary } && example.items.contains { $0.dayRule == .workOnly })
        #expect(text.contains("nebensache") && text.contains("„arbeit“"))
    }

    @Test func weekReportShowsScoreAndReality() {
        let content = Demo.content(today: today)
        let doc = content.document
        let previous = today.week.adding(weeks: -1)
        let input = WeekReportInput(
            week: doc.weeks.first { $0.week == previous }!, goals: doc.goals, categories: doc.categories, items: doc.items,
            measures: doc.measures, marks: doc.marks, days: doc.days, entries: doc.entries, work: doc.work, notes: doc.notes,
            reviews: doc.reviews, closedDays: Set(content.closedDays), isClosed: true, today: today
        )
        let text = WeekReport.markdown(input)
        #expect(text.hasPrefix("# Wochenbericht KW44 2026 (26. Okt. – 1. Nov.)"))
        #expect(text.contains("**Wochenwertung: "))
        #expect(text.contains("10/10 Ziele bewertet"))
        #expect(text.contains("| 1 Fit Body |"))
        #expect(text.contains("PH × 50 min"))
        #expect(text.contains("## Wochenreflexion"))
        #expect(text.contains("Wiederholen statt steigern") || text.contains("wiederholen"))
        #expect(text.contains("Verhalten, nicht Ergebnisse"))
    }

    @Test func remindersUseApplesWeekdays() {
        var settings = ReminderSettings()
        let requests = settings.requests()
        #expect(requests.count == 7, "5 mornings, 1 evening, 1 weekly")
        #expect(requests.first { $0.id == "thalia.weekly" }?.gregorianWeekday == 1)
        #expect(requests.first { $0.id == "thalia.morning.1" }?.gregorianWeekday == 2)
        #expect(requests.first { $0.id == "thalia.evening" }?.hour == 21)
        settings.morning = false
        settings.weekly = false
        #expect(settings.requests().map(\.id) == ["thalia.evening"])
    }

    @Test func tourCatalogIsValid() {
        #expect(ThaliaTour.catalog.problems().isEmpty)
        #expect(ThaliaTour.catalog.steps(newerThan: 0).first?.id == "welcome")
        #expect(ThaliaTour.catalog.steps(newerThan: ThaliaTour.version).isEmpty)
        // v1 took the tour → v2 offers "Neu in Thalia" with the reworked steps.
        let whatsNew = ThaliaTour.catalog.steps(newerThan: 1).map(\.id)
        #expect(whatsNew.first == "whats-new")
        #expect(whatsNew.contains("mark") && whatsNew.contains("work") && !whatsNew.contains("undo"))
        // v2 took the tour → v3 offers only the new steps.
        let v3 = ThaliaTour.catalog.steps(newerThan: 2).map(\.id)
        #expect(v3.contains("weekly-goals") && v3.contains("share") && !v3.contains("mark"))
    }

    @Test func tourStepsTickOff() {
        var page = ThaliaTourSnapshot()
        page.markSummary = "✓ 3"
        var progress = TourProgress(steps: ThaliaTour.catalog.allSteps, start: page, startAt: "mark")
        page.markSummary = "✓ 4"
        let marked = progress.observe(page)
        #expect(marked)

        var undo = TourProgress(steps: ThaliaTour.catalog.allSteps, start: page, startAt: "undo")
        page.trashedWorkCount = 1
        let deleted = undo.observe(page)
        page.trashedWorkCount = 0
        let restored = undo.observe(page)
        #expect(!deleted)
        #expect(restored)
    }

    @Test func todaySummaryComparesContent() throws {
        var a = TodaySummary.placeholder
        var b = a
        b.updatedAt = Date(timeIntervalSince1970: 99)
        #expect(a.hasSameContent(as: b))
        a.powerHours = 3
        #expect(!a.hasSameContent(as: b))
        #expect(!a.hasSameContent(as: nil))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("thalia-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = SnapshotFile<TodaySummary>(folder: folder, name: TodaySummary.fileName)
        try file.write(.placeholder)
        #expect(file.read() == .placeholder)
    }

    /// Runs only with a real export: THALIA_REAL_FILE=/path/to/export.csv swift test
    @Test(.enabled(if: ProcessInfo.processInfo.environment["THALIA_REAL_FILE"] != nil))
    func realFileImports() throws {
        let path = try #require(ProcessInfo.processInfo.environment["THALIA_REAL_FILE"])
        let text = CSV.decode(try Data(contentsOf: URL(fileURLWithPath: path)))
        let preview = ImportPreview(text: text, existing: ExistingState())
        print("Real file: \(preview.headline)\n\(preview.lines.joined(separator: "\n"))\n\(preview.document.warnings.joined(separator: "\n"))")
        #expect(preview.hasChanges)
    }
}
