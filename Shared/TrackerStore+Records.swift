import Foundation
import SwiftData
import BinisoftKit
import ThaliaCore

// v10 (TASKS-v10 §1.1–1.5): the new records – results of the annual goals and their entries, the
// reading list and its readings, segments, mappings of other apps' groups, the inbox and the category
// week scores – are JSON in `AppSetting`s under their own key prefixes (no CloudKit schema change).
// Reading always goes through a prefix or IN predicate; writing goes through here: one copy per key,
// unknown fields kept (Grundregel 4), deleting sets `deletedAt` ("Zuletzt gelöscht"), and every change
// returns what it replaced, so the toast's "Widerrufen" puts it back exactly (⌘Z goes through the
// context's undo manager).

/// What a change of v10 records replaced – `TrackerStore.undo(_:)` puts it back exactly.
struct RecordChange {
    /// Every key the change wrote, with its value before (nil: there was no setting).
    var before: [String: String?] = [:]
    /// Weeks to score again besides those whose keys changed: the week of a book's next reading (its
    /// daily amount changes too), the weeks a new mapping affects.
    var weeks: Set<WeekKey> = []
    /// Closed weeks the change would have scored again but left as they are: they lie before the
    /// current segment (Grundregel 2 – only "Neu berechnen" in the week scores them again).
    var frozenWeeks: Set<WeekKey> = []

    var isEmpty: Bool { before.isEmpty }

    /// Notes the value of `key` before the first write of this change (later writes keep the first).
    mutating func note(_ key: String, previous: String?) {
        guard !before.keys.contains(key) else { return }
        before.updateValue(previous, forKey: key)
    }

    /// Both changes as one (the first value noted for a key wins).
    mutating func merge(_ other: RecordChange) {
        for (key, value) in other.before { note(key, previous: value) }
        weeks.formUnion(other.weeks)
        frozenWeeks.formUnion(other.frozenWeeks)
    }
}

extension AppSetting {
    /// The setting as plain values (Core works on these).
    var stored: StoredSetting { StoredSetting(key: key, value: value, modifiedAt: modifiedAt) }
}

/// A segment before the current one ("Frühere Abschnitte", §1.4.3): its weeks, average score, category
/// weeks above 8 and the results reached in it.
struct SegmentSummary: Identifiable {
    let span: SegmentSpan
    /// Ø of the weeks' scores (laut Unterlagen first, as in the Rückblick); nil without scored weeks.
    let average: Double?
    /// Weeks with a score.
    let scoredWeeks: Int
    /// Category weeks above 8 of all category weeks scored ("23 von 40").
    let categoryWeeksGood: Int
    let categoryWeeksScored: Int
    /// Results reached by the segment's end, of those active in it.
    let resultsReached: Int
    let resultsActive: Int
    var id: String { span.id }

    /// "KW23–KW49 · Ø 7,4 · 23/40 Kategorie-Wochen über 8 · 2 von 3 Ergebnissen"
    var line: String {
        var parts: [String] = [span.weeksLabel]
        if let average { parts.append("Ø " + Format.score(average)) }
        if categoryWeeksScored > 0 { parts.append("\(categoryWeeksGood)/\(categoryWeeksScored) Kategorie-Wochen über 8") }
        if resultsActive > 0 { parts.append("\(resultsReached) von \(resultsActive) Ergebnissen") }
        return parts.joined(separator: " · ")
    }
}

extension TrackerStore {
    // MARK: Reading settings (§1.1.2)

    /// Whether `key.starts(with:)` works in a fetch on this device. `verifyPrefixQuery()` checks it once
    /// (debug builds, at launch); without it prefix reads filter all settings in memory.
    static var prefixQueryWorks = true

    /// The settings whose key starts with `prefix` – one prefix query, in memory when the predicate
    /// doesn't work here.
    func settings(prefix: String) -> [AppSetting] {
        if Self.prefixQueryWorks {
            let descriptor = FetchDescriptor<AppSetting>(predicate: #Predicate<AppSetting> { $0.key.starts(with: prefix) })
            if let found = try? context.fetch(descriptor) { return found.filter { $0.key.hasPrefix(prefix) } }
        }
        let all: [AppSetting] = (try? context.fetch(FetchDescriptor<AppSetting>())) ?? []
        return all.filter { $0.key.hasPrefix(prefix) }
    }

    /// The settings with one of `keys` (IN predicate).
    func settings(keys: [String]) -> [AppSetting] {
        guard !keys.isEmpty else { return [] }
        let descriptor = FetchDescriptor<AppSetting>(predicate: #Predicate<AppSetting> { keys.contains($0.key) })
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Checks once whether prefix queries find exactly what an in-memory filter finds (debug builds call
    /// this at launch); a mismatch switches prefix reads to the in-memory filter. Returns whether it works.
    @discardableResult
    func verifyPrefixQuery() -> Bool {
        let all: [AppSetting] = (try? context.fetch(FetchDescriptor<AppSetting>())) ?? []
        var works = true
        for prefix in SettingKeys.all + [ArchiveWeek.settingPrefix, SyncDevice.keyPrefix] {
            let expected = Set(all.filter { $0.key.hasPrefix(prefix) }.map(\.uuid))
            let descriptor = FetchDescriptor<AppSetting>(predicate: #Predicate<AppSetting> { $0.key.starts(with: prefix) })
            guard let found = try? context.fetch(descriptor), Set(found.map(\.uuid)) == expected else {
                works = false
                break
            }
        }
        Self.prefixQueryWorks = works
        if works {
            AppLog.info("Prefix queries on settings work", category: "store")
        } else {
            AppLog.warning("Prefix queries on settings don't match – reading them in memory", category: "store")
        }
        return works
    }

    /// The records of `type` (newest copy per key), those in the trash only with `includeDeleted`.
    func records<T: SettingRecord>(_ type: T.Type, includeDeleted: Bool = false) -> [T] {
        SettingRecords.decode(type, from: settings(prefix: T.prefix).map(\.stored), includeDeleted: includeDeleted)
    }

    /// One record by its setting key (also one in the trash).
    func record<T: SettingRecord>(_ type: T.Type, key: String) -> T? {
        guard let value = storedValue(key) else { return nil }
        return T(settingValue: value, key: key)
    }

    /// The value of the newest copy of `key` (sync duplicates: the later stamp inside the JSON, then the setting's).
    func storedValue(_ key: String) -> String? {
        TrackerStore.newestFirst(settings(keys: [key])).first?.value
    }

    /// Copies of one key, newest first – the same order as `SettingRecords.newest`.
    nonisolated static func newestFirst(_ copies: [AppSetting]) -> [AppSetting] {
        copies.sorted { a, b in
            if let stampA = SettingRecords.stamp(of: a.value), let stampB = SettingRecords.stamp(of: b.value), stampA != stampB {
                return stampA > stampB
            }
            return a.modifiedAt > b.modifiedAt
        }
    }

    // MARK: Writing

    /// Writes `value` under `key` without saving: the newest copy gets it, other copies go; nil deletes
    /// every copy. An unchanged value is left alone. `change` keeps the value before.
    func writeSetting(_ key: String, _ value: String?, now: Date, change: inout RecordChange) {
        let copies = TrackerStore.newestFirst(settings(keys: [key]))
        guard let value else {
            guard !copies.isEmpty else { return }
            change.note(key, previous: copies.first?.value)
            for copy in copies { context.delete(copy) }
            return
        }
        if let keeper = copies.first {
            guard keeper.value != value || copies.count > 1 else { return }
            change.note(key, previous: keeper.value)
            if keeper.value != value {
                keeper.value = value
                keeper.modifiedAt = now
            }
            for duplicate in copies.dropFirst() { context.delete(duplicate) }
        } else {
            change.note(key, previous: nil)
            let created = AppSetting(key: key, value: value)
            created.modifiedAt = now
            context.insert(created)
        }
    }

    /// Writes a record without saving (`modifiedAt` = now), keeping fields of the stored version this
    /// build doesn't know. A dated fact whose day changed loses its old key (one record per fact).
    func write<T: SettingRecord>(_ record: T, now: Date, change: inout RecordChange) {
        var copy = record
        copy.modifiedAt = now
        let key = copy.settingKey
        if key.hasPrefix(GoalEntry.prefix) || key.hasPrefix(ListProgress.prefix) {
            let suffix = "." + copy.id
            let moved = Set(settings(prefix: T.prefix).map(\.key).filter { $0 != key && $0.hasSuffix(suffix) })
            for old in moved.sorted() { writeSetting(old, nil, now: now, change: &change) }
        }
        writeSetting(key, copy.settingValue(preserving: storedValue(key)), now: now, change: &change)
    }

    /// Saves one record.
    @discardableResult
    func save<T: SettingRecord>(_ record: T, rescoring weeks: Set<WeekKey> = []) -> RecordChange {
        var change = RecordChange()
        change.weeks = weeks
        write(record, now: Date(), change: &change)
        return commit(change)
    }

    /// Saves the context; closed weeks the change touched get their score again, except those before the
    /// current segment (Grundregel 2, `frozenWeeks`).
    @discardableResult
    func commit(_ change: RecordChange) -> RecordChange {
        var result = change
        result.frozenWeeks.formUnion(commit(rescoring: change.weeks))
        return result
    }

    /// Takes a change back exactly: every key gets its value before (the record's `modifiedAt` becomes
    /// now, so the restored version is the newest on every device); keys that didn't exist go.
    @discardableResult
    func undo(_ change: RecordChange) -> RecordChange {
        guard !change.isEmpty else { return change }
        let now = Date()
        var inverse = RecordChange()
        inverse.weeks = change.weeks
        for key in change.before.keys.sorted() {
            let previous: String? = change.before[key] ?? nil
            writeSetting(key, previous.map { TrackerStore.restamped($0, now: now) }, now: now, change: &inverse)
        }
        return commit(inverse)
    }

    /// A record's JSON with `modifiedAt` = now; other values (day files, `score.` texts) unchanged.
    static func restamped(_ value: String, now: Date) -> String {
        guard var object = JSONText.object(value), object["modifiedAt"] != nil else { return value }
        object["modifiedAt"] = .string(JSONText.timestamp(now))
        return JSONText.string(object)
    }

    // MARK: Trash (§1.1.3)

    /// The records in "Zuletzt gelöscht": results, list entries and segments (their entries and readings
    /// went with them and come back with them), newest first.
    func trashedRecords() -> (results: [GoalResult], listItems: [ListItem], segments: [GoalSegment]) {
        func newestFirst(_ a: Date?, _ b: Date?) -> Bool { (a ?? .distantPast) > (b ?? .distantPast) }
        let results = records(GoalResult.self, includeDeleted: true).filter(\.isInTrash).sorted { newestFirst($0.deletedAt, $1.deletedAt) }
        let items = records(ListItem.self, includeDeleted: true).filter(\.isInTrash).sorted { newestFirst($0.deletedAt, $1.deletedAt) }
        let segments = records(GoalSegment.self, includeDeleted: true).filter(\.isInTrash).sorted { newestFirst($0.deletedAt, $1.deletedAt) }
        return (results, items, segments)
    }

    /// Deletes records in the trash for good, with their entries and readings in the trash (no save).
    func purgeRecords(results: [GoalResult], listItems: [ListItem], segments: [GoalSegment]) {
        let now = Date()
        var ignored = RecordChange()
        let resultIDs = Set(results.filter(\.isInTrash).map(\.id))
        let itemIDs = Set(listItems.filter(\.isInTrash).map(\.id))
        var keys: [String] = results.filter(\.isInTrash).map(\.settingKey) + listItems.filter(\.isInTrash).map(\.settingKey)
            + segments.filter(\.isInTrash).map(\.settingKey)
        if !resultIDs.isEmpty {
            keys += records(GoalEntry.self, includeDeleted: true).filter { $0.isInTrash && resultIDs.contains($0.resultID) }.map(\.settingKey)
        }
        if !itemIDs.isEmpty {
            keys += records(ListProgress.self, includeDeleted: true).filter { $0.isInTrash && itemIDs.contains($0.itemID) }.map(\.settingKey)
        }
        for key in Set(keys).sorted() { writeSetting(key, nil, now: now, change: &ignored) }
    }

    /// Empties v10 records that have been in the trash longer than 30 days – also single entries,
    /// readings and mappings, which "Zuletzt gelöscht" doesn't list (no save). Returns how many.
    func purgeExpiredRecords(now: Date = Date()) -> Int {
        var ignored = RecordChange()
        var count = 0
        for prefix in SettingKeys.records {
            for setting in settings(prefix: prefix) {
                guard let object = JSONText.object(setting.value), let deleted = object["deletedAt"]?.stringValue.flatMap(ExchangeDate.parse),
                      trashPolicy.isExpired(deletedAt: deleted, now: now) else { continue }
                writeSetting(setting.key, nil, now: now, change: &ignored)
                count += 1
            }
        }
        return count
    }

    // MARK: Results of the annual goals (§1.2)

    /// The goal year's results (those without a goal year too), not in the trash, by goal and position.
    func goalResults(period: GoalPeriod? = nil, includeDeleted: Bool = false) -> [GoalResult] {
        let start = (period ?? goalPeriod).start
        return records(GoalResult.self, includeDeleted: includeDeleted)
            .filter { $0.periodStart == nil || $0.periodStart == start }
            .sorted(by: TrackerStore.resultOrder)
    }

    /// Goal number, position, title.
    nonisolated static func resultOrder(_ a: GoalResult, _ b: GoalResult) -> Bool {
        (Int(a.goalKey) ?? 99, a.goalKey, a.position, a.title) < (Int(b.goalKey) ?? 99, b.goalKey, b.position, b.title)
    }

    /// A new result of `goalKey` in the current goal year, after the goal's other results (not saved).
    func newResult(goalKey: String, title: String = "", kind: GoalResult.Kind = .count) -> GoalResult {
        let period = goalPeriod
        let last = goalResults(period: period, includeDeleted: true).filter { $0.goalKey == goalKey }.map(\.position).max() ?? 0
        return GoalResult(periodStart: period.start, goalKey: goalKey, title: title, kind: kind, position: last + 1, createdAt: Date())
    }

    /// Saves a result (new or changed; title trimmed).
    @discardableResult
    func saveResult(_ result: GoalResult) -> RecordChange {
        var copy = result
        copy.title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.createdAt == nil { copy.createdAt = Date() }
        return save(copy)
    }

    /// The results' own entries (one result's with `resultID`), by day.
    func goalEntries(resultID: String? = nil, includeDeleted: Bool = false) -> [GoalEntry] {
        records(GoalEntry.self, includeDeleted: includeDeleted)
            .filter { resultID == nil || $0.resultID == resultID }
            .sorted { ($0.day, $0.modifiedAt) < ($1.day, $1.modifiedAt) }
    }

    /// "Jahresziel eintragen" (§1.2.6), also back in time: a tick (`check` – a second tick only moves
    /// the day), +1 (`count`, value 1 by default) or a value (`value`).
    @discardableResult
    func addGoalEntry(to result: GoalResult, day: DayKey, value: Double? = nil, note: String = "") -> RecordChange {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        switch result.kind {
        case .check:
            if var existing = goalEntries(resultID: result.id).first {
                existing.day = day
                if !trimmed.isEmpty { existing.note = trimmed }
                return save(existing)
            }
            return save(GoalEntry(day: day, resultID: result.id, note: trimmed))
        case .count:
            return save(GoalEntry(day: day, resultID: result.id, value: value ?? 1, note: trimmed))
        case .value:
            guard let value, value.isFinite else { return RecordChange() }
            return save(GoalEntry(day: day, resultID: result.id, value: value, note: trimmed))
        }
    }

    /// Changes an entry (value, note, day – a new day moves it to its new key).
    @discardableResult
    func saveGoalEntry(_ entry: GoalEntry) -> RecordChange {
        save(entry)
    }

    /// Sends one entry to the trash (Undo: `undo(_:)`).
    @discardableResult
    func trashGoalEntry(_ entry: GoalEntry) -> RecordChange {
        save(entry.trashed())
    }

    /// Takes a tick back: every entry of the result goes to the trash.
    @discardableResult
    func uncheck(_ result: GoalResult) -> RecordChange {
        let now = Date()
        var change = RecordChange()
        for entry in goalEntries(resultID: result.id) { write(entry.trashed(now: now), now: now, change: &change) }
        return commit(change)
    }

    /// Sends a result to "Zuletzt gelöscht", with its entries (Kaskade).
    @discardableResult
    func trash(_ result: GoalResult) -> RecordChange {
        let now = Date()
        var change = RecordChange()
        let stored = record(GoalResult.self, key: result.settingKey) ?? result
        write(stored.trashed(now: now), now: now, change: &change)
        for entry in SettingRecords.trashedChildren(of: stored.id, in: records(GoalEntry.self), now: now) {
            write(entry, now: now, change: &change)
        }
        return commit(change)
    }

    /// Brings a result back, with the entries that went to the trash with it.
    @discardableResult
    func restore(_ result: GoalResult) -> RecordChange {
        let now = Date()
        var change = RecordChange()
        let stored = record(GoalResult.self, key: result.settingKey) ?? result
        guard let deletedAt = stored.deletedAt else { return change }
        write(stored.restored(now: now), now: now, change: &change)
        let entries = records(GoalEntry.self, includeDeleted: true)
        for entry in SettingRecords.restoredChildren(of: stored.id, deletedAt: deletedAt, in: entries, now: now) {
            write(entry, now: now, change: &change)
        }
        return commit(change)
    }

    /// The measures shown with a goal (§1.2.4) when a week has none: those of the latest week up to `week`
    /// that has measure definitions (one look per planned week, newest first).
    func latestMeasureRecords(through week: WeekKey) -> [MeasureRecord] {
        let weeks = Set(allPlans().filter { $0.deletedAt == nil }.compactMap(\.week)).filter { $0 <= week }.sorted(by: >)
        for candidate in weeks {
            let found = measures(candidate).latest(by: \.code, modified: \.modifiedAt).values.compactMap(\.record)
            if !found.isEmpty { return found.sorted { ($0.position, $0.code) < ($1.position, $1.code) } }
        }
        return []
    }

    /// Whether a result's value comes from Apple Health: it is computed on the device only and never
    /// goes into the prompt, the report or the exchange (guideline 5.1.3(ii)).
    func resultUsesHealth(_ result: GoalResult) -> Bool {
        guard case .measure(let code) = result.resultSource else { return false }
        let definitions = fetch(FetchDescriptor<MeasureDefinition>(predicate: #Predicate<MeasureDefinition> {
            $0.code == code && $0.deletedAt == nil
        }))
        return definitions.contains { $0.record?.isHealth ?? false }
    }

    /// The day values a result with a `measure:` or `app:` source counts (§1.2.1) in its goal year up to
    /// `today`: the measure's day values (power-hours too; Apple Health only where this device has them),
    /// the connected app's facts from the inbox. Empty for other sources.
    func resultSeries(_ result: GoalResult, period: GoalPeriod? = nil, today: DayKey = .today()) -> [DayKey: Double] {
        let year = period ?? goalPeriod
        let end = min(today, year.end)
        guard year.start <= end else { return [:] }
        switch result.resultSource {
        case .measure(let code):
            var values: [DayKey: Double] = [:]
            for point in measureSeries(code: code, from: year.start, through: end) { values[point.day] = point.value }
            return values
        case .app(let source):
            let categories = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
            let inbox = inboxFiles(source: source.source, from: year.start, through: end)
            return result.appSeries(inbox: inbox, rules: linkRules(), categories: Array(categories)) ?? [:]
        default:
            return [:]
        }
    }

    /// A result's progress on `today` (§1.2.2), with everything it needs read from the store.
    func resultProgress(_ result: GoalResult, today: DayKey = .today(), segments: Segments? = nil) -> ResultProgress {
        let resolved = segments ?? self.segments()
        let items: [ListItem]
        if case .list = result.resultSource { items = listItems() } else { items = [] }
        return ResultProgress.compute(result, segments: resolved, today: today, entries: goalEntries(resultID: result.id),
                                      items: items, series: resultSeries(result, period: resolved.period, today: today))
    }

    /// The results of the current segment as lines for the planning prompt and the reports (§1.2.5) –
    /// values from Apple Health stay on the device ("Wert nur auf dem Gerät").
    func resultLines(today: DayKey = .today()) -> [GoalResultLine] {
        let resolved = segments()
        let results = goalResults(period: resolved.period)
        guard !results.isEmpty else { return [] }
        let current = resolved.current(today: today)
        let goals = Dictionary(liveGoals().map { ($0.key, $0.record) }, uniquingKeysWith: { first, _ in first })
        return results.filter { result in current.map { result.isActive(in: $0, segments: resolved) } ?? true }.map { result in
            GoalResultLine(result: result, goal: goals[result.goalKey], progress: resultProgress(result, today: today, segments: resolved),
                           hidesValue: resultUsesHealth(result))
        }
    }

    // MARK: The reading list (§1.3)

    /// The list entries (books …), not in the trash, by position and title.
    func listItems(includeDeleted: Bool = false) -> [ListItem] {
        records(ListItem.self, includeDeleted: includeDeleted).sorted { ($0.position, $0.title) < ($1.position, $1.title) }
    }

    /// The readings (one book's with `itemID`), by day.
    func listProgress(itemID: String? = nil, includeDeleted: Bool = false) -> [ListProgress] {
        records(ListProgress.self, includeDeleted: includeDeleted)
            .filter { itemID == nil || $0.itemID == itemID }
            .sorted { ($0.day, $0.modifiedAt) < ($1.day, $1.modifiedAt) }
    }

    /// "Gerade dabei": the entries with readings or a start that aren't finished or abandoned.
    func runningListItems() -> [ListItem] {
        let progress = listProgress()
        return listItems().filter { ListMath.status($0, progress: progress) == .running }
    }

    /// A new entry ("Buch" by default) after the others (not saved).
    func newListItem(title: String = "", kind: String = ListItem.defaultKind) -> ListItem {
        let last = listItems(includeDeleted: true).map(\.position).max() ?? 0
        return ListItem(kind: kind, title: title, position: last + 1, createdAt: Date())
    }

    /// Saves an entry (title, author, pages, kind, "zählt für", start, end, abandoned). A new kind moves
    /// the book's pages to another `list:<art>` measure: the weeks of its readings get their score again
    /// (R11 – the item's key has no day, so `touchedWeeks()` alone wouldn't find them; Grundregel 2 applies).
    @discardableResult
    func saveListItem(_ item: ListItem) -> RecordChange {
        var copy = item
        copy.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.subtitle = item.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.createdAt == nil { copy.createdAt = Date() }
        let stored: ListItem? = record(ListItem.self, key: copy.settingKey)
        var weeks: Set<WeekKey> = []
        if let stored, ListItem.kindKey(stored.kind) != ListItem.kindKey(copy.kind) || stored.deletedAt != copy.deletedAt {
            weeks = Set(listProgress(itemID: copy.id).map(\.day.week))
        }
        return save(copy, rescoring: weeks)
    }

    /// "bis Seite 120" on `day` (also back in time). One reading per book and day: a second one that day
    /// replaces the first. The book counts as started from its first reading.
    @discardableResult
    func addReading(_ item: ListItem, day: DayKey, reached: Double, note: String = "") -> RecordChange {
        guard reached.isFinite, reached >= 0 else { return RecordChange() }
        let progress = listProgress(itemID: item.id)
        let now = Date()
        var change = RecordChange()
        var reading = progress.last { $0.day == day } ?? ListProgress(day: day, itemID: item.id, reached: reached)
        reading.reached = reached
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { reading.note = trimmed }
        write(reading, now: now, change: &change)
        let stored = record(ListItem.self, key: item.settingKey) ?? item
        if stored.startedOn.map({ $0 > day }) ?? true {
            var started = stored
            started.startedOn = day
            write(started, now: now, change: &change)
        }
        change.weeks = TrackerStore.followingWeeks(itemID: item.id, days: [day], progress: progress, except: reading.id)
        return commit(change)
    }

    /// "+ 20 Seiten" on `day`: the highest reading up to that day plus `pages`.
    @discardableResult
    func addPages(_ item: ListItem, day: DayKey, pages: Double, note: String = "") -> RecordChange {
        guard pages.isFinite, pages > 0 else { return RecordChange() }
        let base = ListMath.reached(itemID: item.id, progress: listProgress(itemID: item.id), through: day) ?? 0
        return addReading(item, day: day, reached: base + pages, note: note)
    }

    /// Changes a reading (page, note, day – a new day moves it to its new key).
    @discardableResult
    func saveReading(_ reading: ListProgress) -> RecordChange {
        let progress = listProgress(itemID: reading.itemID)
        let oldDay = progress.first { $0.id == reading.id }?.day
        let days = [reading.day] + (oldDay.map { [$0] } ?? [])
        return save(reading, rescoring: TrackerStore.followingWeeks(itemID: reading.itemID, days: days, progress: progress, except: reading.id))
    }

    /// Sends a reading to the trash (Undo: `undo(_:)`).
    @discardableResult
    func trashReading(_ reading: ListProgress) -> RecordChange {
        let progress = listProgress(itemID: reading.itemID)
        return save(reading.trashed(), rescoring: TrackerStore.followingWeeks(itemID: reading.itemID, days: [reading.day],
                                                                               progress: progress, except: reading.id))
    }

    /// The weeks of the book's next reading after each of `days` (its daily amount is the increase over
    /// the readings before it, so it changes too) – other weeks than the days' own.
    static func followingWeeks(itemID: String, days: [DayKey], progress: [ListProgress], except id: String) -> Set<WeekKey> {
        let others = ListMath.readings(progress.filter { $0.id != id }, itemID: itemID)
        var weeks: Set<WeekKey> = []
        for day in days {
            if let next = others.first(where: { $0.day > day }), next.day.week != day.week { weeks.insert(next.day.week) }
        }
        return weeks
    }

    /// "Fertig" on `day` (the end date, also back in time); a book without a start gets it too.
    @discardableResult
    func finish(_ item: ListItem, on day: DayKey) -> RecordChange {
        var copy = record(ListItem.self, key: item.settingKey) ?? item
        copy.finishedOn = day
        copy.abandoned = false
        if copy.startedOn.map({ $0 > day }) ?? true { copy.startedOn = day }
        return save(copy)
    }

    /// Sends an entry to "Zuletzt gelöscht", with its readings (Kaskade).
    @discardableResult
    func trash(_ item: ListItem) -> RecordChange {
        let now = Date()
        var change = RecordChange()
        let stored = record(ListItem.self, key: item.settingKey) ?? item
        write(stored.trashed(now: now), now: now, change: &change)
        for reading in SettingRecords.trashedChildren(of: stored.id, in: records(ListProgress.self), now: now) {
            write(reading, now: now, change: &change)
        }
        return commit(change)
    }

    /// Brings an entry back, with the readings that went to the trash with it.
    @discardableResult
    func restore(_ item: ListItem) -> RecordChange {
        let now = Date()
        var change = RecordChange()
        let stored = record(ListItem.self, key: item.settingKey) ?? item
        guard let deletedAt = stored.deletedAt else { return change }
        write(stored.restored(now: now), now: now, change: &change)
        let progress = records(ListProgress.self, includeDeleted: true)
        for reading in SettingRecords.restoredChildren(of: stored.id, deletedAt: deletedAt, in: progress, now: now) {
            write(reading, now: now, change: &change)
        }
        return commit(change)
    }

    // MARK: Segments (§1.4)

    /// The stored segments (all goal years).
    func storedSegments(includeDeleted: Bool = false) -> [GoalSegment] {
        records(GoalSegment.self, includeDeleted: includeDeleted)
    }

    /// The segments of the goal year (`goalPeriod` by default): gapless; without stored ones "Abschnitt 1".
    func segments(period: GoalPeriod? = nil) -> Segments {
        Segments.resolve(storedSegments(), period: period ?? goalPeriod)
    }

    /// Grundregel 2: a closed week before the current segment's start is never scored again by itself.
    func isFrozen(_ week: WeekKey, today: DayKey = .today()) -> Bool {
        segments().isFrozen(week, today: today)
    }

    /// The freeze rule read once, for loops over many weeks.
    func freezeRule(today: DayKey = .today()) -> (WeekKey) -> Bool {
        let resolved = segments()
        return { week in resolved.isFrozen(week, today: today) }
    }

    /// "Neuen Abschnitt beginnen…" (§1.4.2), one undo group: when the running segment is the implicit
    /// "Abschnitt 1", it is stored first with a snapshot of the goals and categories; the new segment
    /// gets a snapshot of today's. nil when it can't start in `startWeek` (`Segments.canStart`). A start
    /// back in time freezes the weeks before it (Grundregel 2) – nothing is scored again.
    @discardableResult
    func beginSegment(startWeek: WeekKey, title: String = "", reason: String = "", today: DayKey = .today()) -> RecordChange? {
        let period = goalPeriod
        let current = segments(period: period)
        guard current.canStart(startWeek, today: today) else { return nil }
        let goals = liveGoals().latest(by: \.key, modified: \.modifiedAt).values.map(\.record).sortedByNumber()
        let categories = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record).sortedByKey()
        let now = Date()
        context.undoManager?.beginUndoGrouping()
        defer { context.undoManager?.endUndoGrouping() }
        var change = RecordChange()
        if let running = current.current(today: today), !running.isStored {
            write(GoalSegment.first(period: period, goals: goals, categories: categories, now: now), now: now, change: &change)
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let segment = GoalSegment(title: trimmed.isEmpty ? current.nextTitle(today: today) : trimmed, periodStart: period.start,
                                  startWeek: startWeek, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
                                  goals: goals, categories: categories, createdAt: now)
        write(segment, now: now, change: &change)
        AppLog.info("Segment begun at \(startWeek.string)", category: "store")
        return commit(change)
    }

    /// Saves a segment (title, reason, start).
    @discardableResult
    func saveSegment(_ segment: GoalSegment) -> RecordChange {
        save(segment)
    }

    /// Sends a segment to "Zuletzt gelöscht" (its weeks count to the segment before it again).
    @discardableResult
    func trash(_ segment: GoalSegment) -> RecordChange {
        save(record(GoalSegment.self, key: segment.settingKey).map { $0.trashed() } ?? segment.trashed())
    }

    @discardableResult
    func restore(_ segment: GoalSegment) -> RecordChange {
        let stored = record(GoalSegment.self, key: segment.settingKey) ?? segment
        guard stored.isInTrash else { return RecordChange() }
        return save(stored.restored())
    }

    /// "Frühere Abschnitte" (§1.4.3): the segments before the current one, newest first.
    func earlierSegments(today: DayKey = .today()) -> [SegmentSummary] {
        let resolved = segments()
        let earlier = resolved.earlier(today: today)
        guard !earlier.isEmpty else { return [] }
        let plans = allPlans().filter { $0.deletedAt == nil }.latest(by: \.weekKey, modified: \.modifiedAt)
        let weeks = storedCategoryWeeks()
        let results = goalResults(period: resolved.period)
        return earlier.map { span in
            let scores: [Double] = plans.values.compactMap { plan -> Double? in
                guard let week = plan.week, span.contains(week) else { return nil }
                return plan.historyScore
            }
            let total = GoalTrack.total(weeks, range: span.startWeek...span.endWeek)
            let active = results.filter { $0.isActive(in: span, segments: resolved) }
            let reached = active.filter { resultProgress($0, today: span.endDay, segments: resolved).status == .reached }.count
            return SegmentSummary(span: span, average: scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count),
                                  scoredWeeks: scores.count, categoryWeeksGood: total.good, categoryWeeksScored: total.scored,
                                  resultsReached: reached, resultsActive: active.count)
        }
    }

    // MARK: Category week scores – "Wochen über 8" (§1.2.3)

    /// A closed week's stored category scores (`score.<week>`); nil when none are stored.
    func categoryScores(_ week: WeekKey) -> [String: Double]? {
        storedValue(GoalTrack.settingKey(week)).map(GoalTrack.scores)
    }

    /// Every week's stored category scores (`score.` prefix), oldest first.
    func storedCategoryWeeks() -> [GoalTrack.Week] {
        let newest = SettingRecords.newest(settings(prefix: GoalTrack.settingPrefix).map(\.stored))
        return newest.compactMap { key, setting -> GoalTrack.Week? in
            GoalTrack.week(settingKey: key).map { GoalTrack.Week(week: $0, text: setting.value) }
        }.sorted { $0.week < $1.week }
    }

    /// Writes a week's category scores without saving (empty: the setting goes). Returns whether it changed.
    @discardableResult
    func writeCategoryScores(_ scores: [String: Double], week: WeekKey, now: Date = Date()) -> Bool {
        let text = GoalTrack.text(scores)
        var change = RecordChange()
        writeSetting(GoalTrack.settingKey(week), text.isEmpty ? nil : text, now: now, change: &change)
        return !change.isEmpty
    }

    /// The category scores `storeFinalScore` keeps for a week: the Scorer's for a week with items, the
    /// recalculated archive grades for a week without items (v9); nil leaves the stored ones alone (a
    /// paper week with only a score has none to compute).
    func finalCategoryScores(_ context: WeekContext) -> [String: Double]? {
        if context.items.isEmpty {
            return context.archiveRecalculation.map { GoalTrack.scores(of: $0) }
        }
        return GoalTrack.scores(of: context.score)
    }

    /// The closed weeks this device already looked at for the backfill (week keys, device only).
    static let categoryBackfillKey = "score.backfill.v10.weeks"

    /// The backfill (§1.2.3): closed weeks of the goal year without `score.<week>` get their category
    /// scores – only `score.`, never `finalScore`. Weeks with items only on a device that reads Apple
    /// Health (the same rule as re-scoring); weeks without items (archive grades) everywhere. Each closed
    /// week is looked at once per device (unless `force`) – also one whose plan arrives through iCloud
    /// later (a freshly set-up iPhone): the app runs it after launch and after every sync, and a run
    /// costs nothing once every closed week was seen. Returns the number of weeks written.
    @discardableResult
    func backfillCategoryScores(today: DayKey = .today(), force: Bool = false) -> Int {
        let defaults = UserDefaults.standard
        let seen: Set<String> = force ? [] : Set(defaults.stringArray(forKey: Self.categoryBackfillKey) ?? [])
        let period = goalPeriod
        let plans = allPlans().filter { $0.deletedAt == nil && $0.isClosed }.latest(by: \.weekKey, modified: \.modifiedAt)
        let candidates: [WeekKey] = plans.values.compactMap(\.week)
            .filter { $0 >= period.start.week && $0 <= period.end.week && $0 <= today.week && !seen.contains($0.string) }
            .sorted()
        guard !candidates.isEmpty else { return 0 }
        let stored = Set(storedCategoryWeeks().map(\.week))
        var written = 0
        let now = Date()
        for week in candidates where !stored.contains(week) {
            // Weeks with items need Apple Health (iPhone/iPad) – elsewhere they are left to that device.
            guard HealthDevice.readsHealth || items(week).isEmpty else { continue }
            let closed = weekContext(for: week, today: today, goalYear: false)
            guard let scores = finalCategoryScores(closed), !scores.isEmpty else { continue }
            if writeCategoryScores(scores, week: week, now: now) { written += 1 }
        }
        if written > 0 { try? context.save() }
        if !force { defaults.set(seen.union(candidates.map(\.string)).sorted(), forKey: Self.categoryBackfillKey) }
        AppLog.info("Category week scores backfilled for \(written) of \(candidates.count) week(s)", category: "store")
        return written
    }

    /// "Neu berechnen" in the week (§0.2): a closed week gets its score again under today's rules – also
    /// one before the current segment. Returns whether anything changed.
    @discardableResult
    func recompute(_ week: WeekKey) -> Bool {
        guard let plan = plan(week), plan.isClosed else { return false }
        let changed = storeFinalScore(plan)
        if changed { try? context.save() }
        AppLog.info("Week \(week.string) scored again on request", category: "store")
        return changed
    }

    // MARK: Connected apps – mappings and the inbox (§1.5)

    /// Thalia's mappings of other apps' groups to categories.
    func linkRules(includeDeleted: Bool = false) -> [LinkRule] {
        records(LinkRule.self, includeDeleted: includeDeleted)
    }

    /// "Ohne Zuordnung" → a category (an empty `categoryKey` = ignore the group). Closed weeks with facts
    /// of that group get their score again (not those before the current segment).
    @discardableResult
    func mapGroup(source: String, ref: String, refTitle: String = "", categoryKey: String) -> RecordChange {
        let title = liveCategories().latest(by: \.key, modified: \.modifiedAt)[categoryKey]?.title ?? ""
        let existing = linkRules(includeDeleted: true).first { $0.id == LinkRule.id(source: source, ref: ref) }
        var rule = existing ?? LinkRule(source: source, ref: ref, refTitle: refTitle, categoryKey: categoryKey, categoryTitle: title)
        rule.categoryKey = categoryKey
        rule.categoryTitle = title
        if !refTitle.isEmpty { rule.refTitle = refTitle }
        rule.deletedAt = nil
        return save(rule, rescoring: weeksWithFacts(source: rule.source, ref: rule.ref))
    }

    /// Removes a mapping (its facts are "ohne Zuordnung" again).
    @discardableResult
    func trash(_ rule: LinkRule) -> RecordChange {
        save(rule.trashed(), rescoring: weeksWithFacts(source: rule.source, ref: rule.ref))
    }

    /// The weeks whose inbox has facts of `ref` from `source`.
    func weeksWithFacts(source: String, ref: String) -> Set<WeekKey> {
        var weeks: Set<WeekKey> = []
        for file in inboxFiles(source: source) where file.facts.contains(where: { $0.ref == ref }) {
            if let day = DayKey(file.day) { weeks.insert(day.week) }
        }
        return weeks
    }

    /// The sources seen (`x.sources`): every copy merged – two devices that saw different apps each wrote
    /// one before they synced, and the value has no stamp, so no copy may win over the other.
    func exchangeSources() -> ExchangeSourceList {
        ExchangeSourceList.merged(settings(keys: [ExchangeInbox.sourcesKey]).map(\.value))
    }

    /// The inbox's day files of `days` (IN over the known sources × days).
    func inboxFiles(days: [DayKey], sources: [String]? = nil) -> [ExchangeDayFile] {
        let ids = sources ?? exchangeSources().ids
        guard !ids.isEmpty, !days.isEmpty else { return [] }
        return ExchangeInbox.files(from: settings(keys: ExchangeInbox.keys(sources: ids, days: days)).map(\.stored))
    }

    /// The inbox's day files (of one source; from / through a day), read by prefix – the keys are
    /// filtered by their day before anything is decoded.
    func inboxFiles(source: String? = nil, from start: DayKey? = nil, through end: DayKey? = nil) -> [ExchangeDayFile] {
        let prefix = source.map { ExchangeInbox.prefix + BinisoftExchange.sourceID($0) + "." } ?? ExchangeInbox.prefix
        let kept = settings(prefix: prefix).filter { setting in
            guard let (_, day) = ExchangeInbox.parse(settingKey: setting.key) else { return false }
            if let start, day < start { return false }
            if let end, day > end { return false }
            return true
        }
        return ExchangeInbox.files(from: kept.map(\.stored))
    }

    /// Stores day files and `source.json`s read from the App Group (§1.5.1): one setting `x.<source>.<day>`
    /// per source and day – a newer `generatedAt` wins, the same content changes nothing – and `x.sources`.
    /// Facts from Apple Health (`origin: health`) are left out: the inbox syncs through iCloud, Health
    /// values never do (guideline 5.1.3(ii)); Thalia doesn't use them anyway. Thalia never deletes the
    /// inbox. Closed weeks of changed days get their score again (Grundregel 2 applies). Never for the
    /// demo or the practice page (the caller checks the store).
    @discardableResult
    func storeInbox(files: [ExchangeDayFile], sources: [ExchangeSourceInfo]) -> RecordChange {
        var change = RecordChange()
        let now = Date()
        // One file per source and day, as read (the newest `generatedAt` of equal keys), only with facts
        // recorded in the app itself – never Health values, nor facts without the origin "app".
        var keyed: [String: ExchangeDayFile] = [:]
        for read in files {
            let file = ExchangeInbox.syncable(read)
            guard let day = DayKey(file.day) else { continue }
            let key = ExchangeInbox.settingKey(source: file.source, day: day)
            if let other = keyed[key], !ExchangeInbox.shouldStore(file, over: other) { continue }
            keyed[key] = file
        }
        if !keyed.isEmpty {
            let stored = Dictionary(grouping: settings(keys: Array(keyed.keys)), by: \.key)
            for key in keyed.keys.sorted() {
                guard let file = keyed[key] else { continue }
                // The copy the weeks read (the same pick on every device, whatever the fetch order).
                let current: ExchangeDayFile? = ExchangeInbox.files(from: (stored[key] ?? []).map(\.stored)).first
                guard ExchangeInbox.shouldStore(file, over: current) else { continue }
                writeSetting(key, ExchangeInbox.value(file), now: now, change: &change)
            }
        }
        let copies: [AppSetting] = settings(keys: [ExchangeInbox.sourcesKey])
        let known = ExchangeSourceList.merged(copies.map(\.value))
        var list = known
        for info in sources { list = list.merging(info) }
        // A source with day files but no `source.json` yet: known anyway, so its weeks read its files.
        for file in keyed.values.sorted(by: { $0.source < $1.source }) where list.info(file.source) == nil {
            list = list.merging(ExchangeSourceInfo(v: file.v, source: BinisoftExchange.sourceID(file.source), generatedAt: ""))
        }
        // Written as one merged copy – also when only the copies of two devices differ.
        let merged: Bool = copies.count > 1 && !list.sources.isEmpty
        if list != known || merged { writeSetting(ExchangeInbox.sourcesKey, list.value, now: now, change: &change) }
        guard !change.isEmpty else { return change }
        AppLog.info("Inbox: \(change.before.count) setting(s) from connected apps", category: "exchange")
        return commit(change)
    }

    /// Einstellungen → "Verbundene Apps": one summary per source for the last 30 days.
    func exchangeSummaries(today: DayKey = .today(), days: Int = 30) -> [ExchangeSourceSummary] {
        let categories = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        return ExchangeOverview.summaries(inbox: inboxFiles(from: today.adding(days: -(days - 1)), through: today),
                                          sources: exchangeSources().sources, rules: linkRules(), categories: Array(categories),
                                          today: today, days: days)
    }

    /// "Was kommt an": the facts of the last days (read only).
    func exchangeArrivals(today: DayKey = .today(), days: Int = 7) -> [ExchangeArrival] {
        let categories = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        return ExchangeOverview.arrivals(inbox: inboxFiles(from: today.adding(days: -(days - 1)), through: today), rules: linkRules(),
                                         categories: Array(categories), today: today, days: days, sourceNames: exchangeSources().names)
    }

    /// "Übernehmen" (§1.5.3): an own work block from a derived one, `importID` = the derived block's id
    /// (`x:<source>:<fact id>`) – it replaces the derived one. A block without a category gets `categoryKey`.
    @discardableResult
    func adoptWork(_ derived: WorkRecord, categoryKey: String? = nil) -> WorkBlock {
        let block = WorkBlock(dayKey: derived.day.string, categoryKey: categoryKey ?? derived.categoryKey,
                              task: derived.task.trimmingCharacters(in: .whitespacesAndNewlines), powerHours: max(0.05, derived.powerHours))
        block.importID = derived.id
        block.result = derived.result
        block.nextStep = derived.nextStep
        context.insert(block)
        save()
        return block
    }

    static let catalogSettingKey = "exchange.catalog"

    /// "Thalia-Katalog bereitstellen" (§1.5.5), on unless switched off (synced).
    var providesCatalog: Bool { setting(Self.catalogSettingKey) != "aus" }

    func setProvidesCatalog(_ on: Bool) {
        setSetting(Self.catalogSettingKey, on ? "an" : "aus")
    }

    /// Thalia's `catalog.json` (§1.5.1): structure only – goals, categories, the week's measures, the
    /// results – no values, no progress.
    func exchangeCatalog(today: DayKey = .today(), generatedAt: Date = Date()) -> ExchangeCatalog {
        let resolved = segments()
        let goals = liveGoals().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        let categories = liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)
        let weekMeasures = measures(today.week).latest(by: \.code, modified: \.modifiedAt).values.compactMap(\.record)
        return ExchangeCatalog.thalia(goals: Array(goals), categories: Array(categories), measures: Array(weekMeasures),
                                      results: goalResults(period: resolved.period), segment: resolved.current(today: today),
                                      week: today.week, generatedAt: generatedAt)
    }
}
