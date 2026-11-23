import Foundation
import Testing
@testable import ThaliaCore

// v10 gap fixes: sync and backup of the inbox, cleared ticks in exports, segment snapshots, the freeze
// at a segment's start, a second "Neuen Abschnitt beginnen…", the measure editor's refs and the
// sources' names. Neutral labels only ("Arbeit/Kunden", "Push", "Lesen").

@Suite("v10 gap fixes – inbox sync and backup")
struct V10InboxSyncTests {
    func info(_ source: String, _ generated: String, app: String? = nil) -> ExchangeSourceInfo {
        ExchangeSourceInfo(source: source, app: app, generatedAt: generated)
    }

    @Test func sourcesFromEveryCopy() {
        // iPhone (Theo) and Mac (Finn) each wrote x.sources before they synced: both count.
        let phone = ExchangeSourceList(sources: [info("theo", "2026-11-22T08:00:00Z")]).value
        let mac = ExchangeSourceList(sources: [info("finn", "2026-11-22T08:10:00Z"), info("theo", "2026-11-21T08:00:00Z")]).value
        let merged = ExchangeSourceList.merged([mac, phone])
        #expect(merged.ids == ["finn", "theo"])
        #expect(merged.info("theo")?.generatedAt == "2026-11-22T08:00:00Z", "the newest source.json of each")
        #expect(ExchangeSourceList.merged([phone, mac]) == merged, "whatever the order")
        #expect(ExchangeSourceList.merged([]).sources.isEmpty && ExchangeSourceList.merged(["kaputt"]).sources.isEmpty)
        // A placeholder (day files before source.json) gives way to the real one.
        let placeholder = ExchangeSourceList(sources: [info("nina", "")]).value
        let real = ExchangeSourceList(sources: [info("nina", "2026-11-22T09:00:00Z", app: "Nina")]).value
        #expect(ExchangeSourceList.merged([real, placeholder]).info("nina")?.app == "Nina")
        #expect(ExchangeSourceList.merged([real]).names == ["nina": "Nina"])
    }

    @Test func olderBackupKeepsNewerSources() {
        let backup = SettingRow(key: ExchangeInbox.sourcesKey, value: ExchangeSourceList(sources: [info("theo", "2026-11-01T08:00:00Z")]).value)
        let now = SettingRow(key: ExchangeInbox.sourcesKey, value: ExchangeSourceList(sources: [
            info("theo", "2026-11-22T08:00:00Z"), info("nina", "2026-11-20T08:00:00Z")]).value)
        // Nothing new in the backup: the app's list stays (unchanged in the preview).
        #expect(!SettingRow.wins(backup, over: now))
        #expect(SettingRow.resolved(backup, over: now) == now)
        // A source only the backup knows comes in – merged, not replacing.
        let withFinn = SettingRow(key: ExchangeInbox.sourcesKey, value: ExchangeSourceList(sources: [
            info("finn", "2026-10-01T08:00:00Z")]).value)
        #expect(SettingRow.wins(withFinn, over: now))
        #expect(ExchangeSourceList(value: SettingRow.resolved(withFinn, over: now).value).ids == ["finn", "nina", "theo"])
        // Through the preview.
        var existing = ExistingState()
        existing.records[now.key] = now
        var doc = PlanCSV.Document()
        doc.records = [backup]
        #expect(!ImportPreview(document: doc, existing: existing).records.hasChanges)
        doc.records = [withFinn]
        let preview = ImportPreview(document: doc, existing: existing)
        #expect(preview.records.entries.first.map { ExchangeSourceList(value: $0.record.value).ids } == ["finn", "nina", "theo"])
    }

    @Test func copiesPickedTheSameWayEverywhere() {
        let key = "x.theo.2026-11-17"
        let a = ExchangeDayFile(source: "theo", day: "2026-11-17", generatedAt: "2026-11-17T10:00:00Z",
                                facts: [ExchangeFact(id: "t1", kind: "task.done", ref: "grp-1", refTitle: "Arbeit/Kunden")])
        var b = a
        b.facts.append(ExchangeFact(id: "t2", kind: "task.done", ref: "grp-1", refTitle: "Arbeit/Kunden"))
        let ab = ExchangeInbox.files(from: [StoredSetting(key: key, value: ExchangeInbox.value(a)), StoredSetting(key: key, value: ExchangeInbox.value(b))])
        let ba = ExchangeInbox.files(from: [StoredSetting(key: key, value: ExchangeInbox.value(b)), StoredSetting(key: key, value: ExchangeInbox.value(a))])
        #expect(ab == ba && ab.count == 1, "same generatedAt, different facts: the same pick in any order")
        #expect(ExchangeDerivation.latest([a, b]) == ExchangeDerivation.latest([b, a]))
        #expect(ExchangeInbox.isPreferred(b, over: a) != ExchangeInbox.isPreferred(a, over: b))
        #expect(!ExchangeInbox.isPreferred(a, over: a))
        // A later generatedAt still wins.
        var later = a
        later.generatedAt = "2026-11-17T11:00:00Z"
        #expect(ExchangeInbox.files(from: [StoredSetting(key: key, value: ExchangeInbox.value(b)),
                                           StoredSetting(key: key, value: ExchangeInbox.value(later))]) == [later])
    }

    @Test func fileWithoutReadableDateStillArrives() {
        // A writer without a time zone: the stored copy must not stay forever.
        let first = ExchangeDayFile(source: "theo", day: "2026-11-17", generatedAt: "2026-11-17T10:00:00",
                                    facts: [ExchangeFact(id: "t1", kind: "task.done")])
        var changed = first
        changed.facts.append(ExchangeFact(id: "t2", kind: "task.done"))
        #expect(first.generatedDate == nil)
        #expect(ExchangeInbox.shouldStore(changed, over: first))
        #expect(!ExchangeInbox.shouldStore(first, over: first), "the same content changes nothing")
        var dated = first
        dated.generatedAt = "2026-11-17T09:00:00Z"
        #expect(ExchangeInbox.shouldStore(changed, over: dated), "a fresh read without a date wins over a dated copy")
        #expect(ExchangeInbox.shouldStore(dated, over: changed))
        // The same for source.json: its refs still change; a placeholder never replaces a real one.
        let real = ExchangeSourceInfo(source: "theo", generatedAt: "2026-11-17T09:00:00Z", refs: [ExchangeRef(id: "grp-1", title: "Alt")])
        let undated = ExchangeSourceInfo(source: "theo", generatedAt: "2026-11-17T10:00:00", refs: [ExchangeRef(id: "grp-1", title: "Neu")])
        let list = ExchangeSourceList(sources: [real])
        #expect(list.merging(undated).info("theo")?.refs.first?.title == "Neu")
        #expect(list.merging(ExchangeSourceInfo(source: "theo", generatedAt: "")) == list)
        #expect(list.merging(real) == list)
        // An older dated file still never replaces a newer one.
        var older = dated
        older.generatedAt = "2026-11-17T08:00:00Z"
        older.facts = []
        #expect(!ExchangeInbox.shouldStore(older, over: dated))
    }

    @Test func onlyAppFactsReachTheSyncedInbox() throws {
        let file = ExchangeDayFile(source: "nina", day: "2026-11-22", generatedAt: "2026-11-22T10:00:00Z", facts: [
            ExchangeFact(id: "kcal-a", kind: "value", value: 2100, metric: "kcal"),
            ExchangeFact(id: "kcal-h", kind: "value", value: 300, metric: "kcal", origin: .health),
        ])
        var raw: String = ExchangeInbox.value(file)
        // Facts without an origin or with another label (written by hand into the JSON).
        raw = raw.replacingOccurrences(of: #""facts":["#, with: #""facts":[{"id":"steps-x","kind":"value","metric":"steps","value":9000},{"id":"w-hk","kind":"workout.done","origin":"healthkit"},"#)
        let parsed = try #require(ExchangeInbox.file(raw))
        #expect(parsed.facts.count == 4)
        #expect(ExchangeInbox.syncable(parsed).facts.map(\.id) == ["kcal-a"])
        let kept = try #require(ExchangeInbox.syncableValue(raw, key: "x.nina.2026-11-22"))
        #expect(ExchangeInbox.file(kept)?.facts.map(\.id) == ["kcal-a"])
        #expect(ExchangeInbox.syncableValue(raw, key: "x.theo.2026-11-22") == nil, "another source's key")
        #expect(ExchangeInbox.syncableValue("{}", key: "x.nina.2026-11-22") == nil)
        #expect(ExchangeInbox.syncableValue("{\"sources\":[]}", key: ExchangeInbox.sourcesKey) == "{\"sources\":[]}")
        let clean: String = ExchangeInbox.value(ExchangeInbox.syncable(parsed))
        #expect(ExchangeInbox.syncableValue(clean, key: "x.nina.2026-11-22") == clean, "a clean value stays byte for byte")
        // A backup row with Health facts comes in without them.
        let csv = PlanCSV.export({ var doc = PlanCSV.Document(); doc.records = [SettingRow(key: "x.nina.2026-11-22", value: raw)]; return doc }())
        let read = PlanCSV.parse(csv)
        #expect(read.records.count == 1 && !read.records[0].value.contains("health") && !read.records[0].value.contains("steps-x"))
        let broken = PlanCSV.parse(PlanCSV.export({ var doc = PlanCSV.Document()
            doc.records = [SettingRow(key: "x.nina.2026-11-22", value: "{\"v\":1}")]; return doc }()))
        #expect(broken.records.isEmpty && broken.skipped.count == 1)
    }

    @Test func sourceNamesFromSourceJSON() {
        let week = WeekKey(year: 2026, week: 47)
        let day = week.day(.monday)
        let file = ExchangeDayFile(source: "timetracker", day: day.string, generatedAt: "2026-11-16T10:00:00Z", facts: [
            ExchangeFact(id: "ph-1", kind: "ph", ref: "grp-1", refTitle: "Arbeit/Kunden", value: 1, unit: "PH",
                         thalia: ExchangeThaliaHint(category: "3.2"))])
        let named = ExchangeDerivation.week(week, inbox: [file], items: [], measures: [], sourceNames: ["timetracker": "TimeTracker"])
        #expect(named.workSources.values.first == "TimeTracker")
        #expect(ExchangeDerivation.week(week, inbox: [file], items: [], measures: []).workSources.values.first == "Timetracker")
        let arrivals = ExchangeOverview.arrivals(inbox: [file], today: day, sourceNames: ["timetracker": "TimeTracker"])
        #expect(arrivals.first?.source == "TimeTracker")
    }

    @Test func laterFileWithoutChoiceEndsIt() {
        // January: the group is mapped in the source; April: unmapped there, Thalia's own rule counts.
        func task(_ id: String, category: String?) -> ExchangeFact {
            ExchangeFact(id: id, kind: "task.done", ref: "grp-g", refTitle: "Arbeit/Kunden", thalia: category.map { ExchangeThaliaHint(category: $0) })
        }
        let january = ExchangeDayFile(source: "theo", day: "2026-01-12", generatedAt: "2026-01-12T10:00:00Z", facts: [task("t1", category: "3.2")])
        let april = ExchangeDayFile(source: "theo", day: "2026-04-14", generatedAt: "2026-04-14T10:00:00Z", facts: [task("t2", category: nil)])
        #expect(ExchangeDerivation.groupChoices([january])["theo"]?["grp-g"] == "3.2")
        #expect(ExchangeDerivation.groupChoices([january, april])["theo"]?["grp-g"] == nil)
        let rule = LinkRule(source: "theo", ref: "grp-g", categoryKey: "3.3")
        let choices = ExchangeDerivation.groupChoices([january, april])["theo"] ?? [:]
        #expect(ExchangeDerivation.category(of: april.facts[0], source: "theo", rules: [rule], choices: choices) == "3.3")
        #expect(ExchangeDerivation.category(of: january.facts[0], source: "theo", rules: [rule], choices: choices) == "3.2",
                "a fact's own choice stays")
        // Within one file one fact naming the category is enough (§1.5.2 names it on the task only).
        let sameDay = ExchangeDayFile(source: "theo", day: "2026-04-15", generatedAt: "2026-04-15T10:00:00Z", facts: [
            task("t3", category: "3.2"), ExchangeFact(id: "ph-1", kind: "ph", ref: "grp-g", refTitle: "Arbeit/Kunden", value: 1)])
        #expect(ExchangeDerivation.groupChoices([january, april, sameDay])["theo"]?["grp-g"] == "3.2")
    }

    @Test func metricsOfferNoRefs() throws {
        let refs = [ExchangeRef(id: "kcal", title: "Kalorien", kind: "metric"), ExchangeRef(id: "protein_g", title: "Protein", kind: "metric"),
                    ExchangeRef(id: "net_worth", title: "Vermögen", kind: "metric")]
        #expect(try #require(AppSource(raw: "app:nina:protein_g")).refChoices(refs).isEmpty)
        #expect(try #require(AppSource(raw: "app:finn:kcal")).refChoices(refs).isEmpty)
        #expect(try #require(AppSource(raw: "app:finn:spending")).refChoices(refs + [ExchangeRef(id: "grp", title: "Lebensmittel", kind: "group")])
            .map(\.id) == ["grp"])
    }
}

@Suite("v10 gap fixes – cleared ticks in exports")
struct V10ClearedMarkTests {
    let week = WeekKey(year: 2026, week: 47)

    @Test func clearedTickTravels() {
        let monday = week.day(.monday)
        let items = [ItemRecord(week: week, code: "1.2-01", categoryKey: "1.2", position: 1, title: "Krafttraining", measure: "workouts"),
                     ItemRecord(week: week, code: "1.2-02", categoryKey: "1.2", position: 2, title: "Dehnen"),
                     ItemRecord(week: week, code: "1.2-03", categoryKey: "1.2", position: 3, title: "Laufen", measure: "app:george:workout=tpl-run")]
        let measures = [MeasureRecord(week: week, code: "workouts", categoryKey: "1.2", title: "Workouts", unit: "Stück",
                                      source: .app(AppSource(source: "george", kind: "workout")))]
        let marks = [MarkRecord(week: week, itemCode: "1.2-01", day: monday, mark: nil),           // cleared derived ✓
                     MarkRecord(week: week, itemCode: "1.2-02", day: monday, mark: nil),           // cleared, nothing derived
                     MarkRecord(week: week, itemCode: "1.2-02", day: week.day(.tuesday), mark: nil, note: "Knie"),
                     MarkRecord(week: week, itemCode: "1.2-03", day: monday, mark: nil),           // linked to an app: text
                     MarkRecord(week: week, itemCode: "1.2-02", day: week.day(.wednesday), mark: .done)]
        let exported = MarkRecord.exported(marks, items: items, measures: measures)
        #expect(exported.map { "\($0.itemCode)|\($0.day.string)" }.sorted()
                    == ["1.2-01|\(monday.string)", "1.2-02|\(week.day(.tuesday).string)",
                        "1.2-02|\(week.day(.wednesday).string)", "1.2-03|\(monday.string)"])
        // The empty value survives the CSV and comes back as a cleared mark.
        var doc = PlanCSV.Document()
        doc.weeks = [WeekRecord(week: week)]
        doc.items = items
        doc.measures = measures
        doc.plannedWeeks = [week]
        doc.measuredWeeks = [week]
        doc.marks = exported
        let read = PlanCSV.parse(PlanCSV.export(doc))
        let cleared = read.marks.first { $0.itemCode == "1.2-01" && $0.day == monday }
        #expect(cleared != nil && cleared?.mark == nil)
        // In a store without the mark it is created (the clear wins over the app's ✓ again).
        let preview = ImportPreview(document: read, existing: ExistingState())
        #expect(preview.marks.entries.contains { $0.record.itemCode == "1.2-01" && $0.record.mark == nil && $0.action == .create })
    }
}

@Suite("v10 gap fixes – segments")
struct V10SegmentGapTests {
    let period = GoalPeriod.foundationYear
    let created = ExchangeDate.parse("2026-11-20T10:00:00Z") ?? Date(timeIntervalSince1970: 0)

    @Test func snapshotKeepsNewerFields() throws {
        let raw = #"{"id":"s2","title":"Abschnitt 2","period":"2026-06-01","startWeek":"2026-W48","v":1,"#
            + #""goals":[{"key":"1","title":"Gesundheit","color":"grün"}],"#
            + #""categories":[{"key":"1.1","goal":"1","title":"Bewegung","icon":"figure.walk"}],"#
            + #""modifiedAt":"2026-11-20T10:00:00.000Z","createdAt":"2026-11-20T10:00:00.000Z"}"#
        var segment = try #require(GoalSegment(settingValue: raw, key: "goal.segment.s2"))
        #expect(segment.goals.map(\.title) == ["Gesundheit"])
        segment.title = "Neu"
        let saved = try #require(JSONText.object(segment.settingValue))
        let goal = try #require(saved["goals"]?.arrayValue?.first?.objectValue)
        let category = try #require(saved["categories"]?.arrayValue?.first?.objectValue)
        #expect(goal["color"] == .string("grün") && goal["title"] == .string("Gesundheit"))
        #expect(category["icon"] == .string("figure.walk") && category["goal"] == .string("1"))
        let again = try #require(GoalSegment(settingValue: segment.settingValue, key: "goal.segment.s2"))
        #expect(again == segment && again.title == "Neu")
        // A new snapshot has no extras.
        let fresh = GoalSegment(id: "s3", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 50),
                                goals: [GoalRecord(key: "1", title: "Gesundheit")], createdAt: created)
        #expect(JSONText.object(fresh.settingValue)?["goals"]?.arrayValue?.first?.objectValue?.keys.sorted() == ["details", "key", "title"])
    }

    @Test func weekBeforeANewSegmentDuringItsFirstWeek() {
        // Abschnitt 2 starts with KW47; the week before (KW46) was closed on the Mac on Sunday.
        let second = GoalSegment(id: "s2", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 47), createdAt: created)
        let segments = Segments.resolve([second], period: period)
        let monday = DayKey(year: 2026, month: 11, day: 16)
        let nextMonday = DayKey(year: 2026, month: 11, day: 23)
        #expect(!segments.isFrozen(WeekKey(year: 2026, week: 46), today: monday), "the first week of the segment: not yet")
        #expect(segments.isFrozen(WeekKey(year: 2026, week: 45), today: monday))
        #expect(segments.isFrozen(WeekKey(year: 2026, week: 46), today: nextMonday), "from its second week on")
        // Begun back in time (its first week is over): frozen at once.
        let back = GoalSegment(id: "back", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 45), createdAt: created)
        #expect(Segments.resolve([back], period: period).isFrozen(WeekKey(year: 2026, week: 44), today: monday))
        // The goal year's first week: the last week of the year before is still scored with Health values.
        let yearStart = Segments.resolve([], period: period)
        #expect(!yearStart.isFrozen(period.start.week.adding(weeks: -1), today: period.start))
        #expect(yearStart.isFrozen(period.start.week.adding(weeks: -2), today: period.start))
        #expect(yearStart.isFrozen(period.start.week.adding(weeks: -1), today: period.start.adding(days: 7)))
    }

    @Test func plannedSegmentAndASecondStart() throws {
        // Today KW47 in Abschnitt 1; Abschnitt 2 was begun for KW48.
        let today = DayKey(year: 2026, month: 11, day: 18)
        let planned = GoalSegment(id: "s2", title: "Abschnitt 2", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 48),
                                  createdAt: created)
        let first = GoalSegment.first(period: period, goals: [], categories: [], now: created)
        let segments = Segments.resolve([first, planned], period: period)
        #expect(segments.current(today: today)?.id == first.id)
        #expect(segments.upcoming(today: today)?.id == "s2")
        #expect(segments.upcoming(today: DayKey(year: 2026, month: 11, day: 23)) == nil, "once it began it is the current one")
        // Opening the assistant again: never the week of the planned one, the next number.
        #expect(segments.earliestStart(today: today) == WeekKey(year: 2026, week: 49))
        #expect(segments.defaultStart(today: today) == WeekKey(year: 2026, week: 49))
        #expect(!segments.canStart(WeekKey(year: 2026, week: 48), today: today))
        #expect(segments.nextTitle(today: today) == "Abschnitt 3")
        #expect(segments.startChoices(today: today).first == WeekKey(year: 2026, week: 49))
        // Without a planned one nothing changes.
        let plain = Segments.resolve([first], period: period)
        #expect(plain.upcoming(today: today) == nil && plain.earliestStart(today: today) == period.start.week.adding(weeks: 1))
        // Two stored on the same week (two devices): the older one is listed to be deleted.
        let twin = GoalSegment(id: "s2b", title: "Abschnitt 2", periodStart: period.start, startWeek: WeekKey(year: 2026, week: 48),
                               createdAt: created.addingTimeInterval(-60))
        let hidden = Segments.hidden([first, planned, twin], period: period)
        #expect(hidden.map(\.id) == ["s2b"])
        #expect(Segments.hidden([first, planned], period: period).isEmpty)
        #expect(Segments.hidden([first, planned, twin.trashed(now: created)], period: period).isEmpty)
    }
}
