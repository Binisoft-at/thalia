import Foundation
import BinisoftKitCore

/// Thalia's CSV contract: the weekly plan ChatGPT writes (week, days, goals, categories, items,
/// measurements) and – for export, backups and history – the results (marks, measurements, work
/// blocks, notes, reflections, own scores). One table, one `type` per row. See docs/IMPORT.md.
///
///     type,id,parent,title,description,days,schedule,unit,target,period,link,flags,date,value,note
///
/// Rows after a `week` row belong to that week. Importing the same file twice changes nothing;
/// importing a revised plan for a week updates it and removes items the new plan no longer has.
public enum PlanCSV {
    public static let columns = ["type", "id", "parent", "title", "description", "days", "schedule", "unit",
                                 "target", "period", "link", "flags", "date", "value", "note"]

    public static var header: String { columns.joined(separator: ",") }

    /// Optional weekday columns on item rows (v8): one mark per day (✓ ½ ✗ –), e.g. for a past week
    /// copied from a paper tracker. The export stays in the long format (one mark row per day).
    public static let matrixColumns = ["mo", "di", "mi", "do", "fr", "sa", "so"]

    /// The header with the weekday columns: `type,…,note,mo,di,mi,do,fr,sa,so`.
    public static var matrixHeader: String { (columns + matrixColumns).joined(separator: ",") }

    /// Header names read as weekday columns (German short and long, English short and long).
    static let matrixAliases: [(Weekday, [String])] = [
        (.monday, ["mo", "montag", "mon", "monday"]),
        (.tuesday, ["di", "dienstag", "tue", "tuesday"]),
        (.wednesday, ["mi", "mittwoch", "wed", "wednesday"]),
        (.thursday, ["do", "donnerstag", "thu", "thursday"]),
        (.friday, ["fr", "freitag", "fri", "friday"]),
        (.saturday, ["sa", "samstag", "sat", "saturday"]),
        (.sunday, ["so", "sonntag", "sun", "sunday"]),
    ]

    public enum RowType: String, CaseIterable, Sendable {
        case week, day, goal, category, item, measure, mark, entry, work, note, review, score

        public init?(token: String) {
            let t = token.trimmingCharacters(in: .whitespaces).lowercased()
            if let direct = RowType(rawValue: t) { self = direct; return }
            switch t {
            case "woche", "kw", "plan": self = .week
            case "tag", "tagestyp": self = .day
            case "ziel", "jahresziel": self = .goal
            case "kategorie", "bereich": self = .category
            case "punkt", "aufgabe", "task": self = .item
            case "messwert", "messung", "metric": self = .measure
            case "markierung", "bewertung", "haken": self = .mark
            case "wert", "eintrag", "erfassung": self = .entry
            case "arbeit", "arbeitsblock", "block": self = .work
            case "notiz", "beobachtung": self = .note
            case "reflexion", "rückblick", "rueckblick": self = .review
            case "kategoriewert", "override", "eigenwertung": self = .score
            default: return nil
            }
        }
    }

    /// German header names some AIs write instead of the English ones.
    static let headerAliases: [String: String] = [
        "typ": "type", "art": "type", "schlüssel": "id", "schluessel": "id", "kennung": "id",
        "eltern": "parent", "gehört_zu": "parent", "gehoert_zu": "parent", "titel": "title", "name": "title",
        "beschreibung": "description", "tage": "days", "rhythmus": "schedule", "einheit": "unit",
        "zielwert": "target", "zeitraum": "period", "verknüpfung": "link", "verknuepfung": "link", "quelle": "link",
        "merkmale": "flags", "datum": "date", "wert": "value", "notiz": "note", "anmerkung": "note",
    ]

    /// Everything a file contains.
    public struct Document: Sendable {
        public var goals: [GoalRecord] = []
        public var categories: [CategoryRecord] = []
        public var weeks: [WeekRecord] = []
        public var days: [DayRecord] = []
        public var items: [ItemRecord] = []
        public var measures: [MeasureRecord] = []
        public var marks: [MarkRecord] = []
        public var entries: [EntryRecord] = []
        public var work: [WorkRecord] = []
        public var notes: [NoteRecord] = []
        public var reviews: [ReviewRecord] = []
        public var scores: [ScoreRecord] = []
        /// Things to look at that don't stop the import ("2.3 has 9 items").
        public var warnings: [String] = []
        /// Rows that couldn't be read, with the reason.
        public var skipped: [String] = []
        /// Weeks whose item list is in the file: their other items are removed on import.
        public var plannedWeeks: Set<WeekKey> = []
        /// Weeks whose measurement list is in the file.
        public var measuredWeeks: Set<WeekKey> = []
        /// Closed days and weeks (flag `abgeschlossen` on day and week rows, R27).
        public var closedDays: Set<DayKey> = []
        public var closedWeeks: Set<WeekKey> = []

        public init() {}

        public var rowCount: Int {
            goals.count + categories.count + weeks.count + days.count + items.count + measures.count + marks.count
                + entries.count + work.count + notes.count + reviews.count + scores.count
        }

        public var isEmpty: Bool { rowCount == 0 }
    }

    // MARK: Reading

    /// When someone pastes ChatGPT's whole answer, take the ```csv block out of it.
    public static func extractCSV(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        guard let start = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }) else { return text }
        guard let end = lines[(start + 1)...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }) else {
            return lines[(start + 1)...].joined(separator: "\n")
        }
        return lines[(start + 1)..<end].joined(separator: "\n")
    }

    /// Reads a file. `knownCategories` / `knownMeasures` are what the app already has, so items may
    /// refer to them without repeating the structure. `knownItems`: the app's items (`ItemRecord.key`,
    /// "2026-W45|1.1-01", or bare codes) – marks on items that are neither there nor in the file get
    /// a warning (v8).
    public static func parse(_ raw: String, knownCategories: [String: String] = [:], knownMeasures: Set<String> = [],
                             knownItems: Set<String> = []) -> Document {
        var doc = Document()
        let text = extractCSV(from: raw)
        let (rawHeader, rawRows) = CSV.records(text)
        let header = rawHeader.map { headerAliases[$0] ?? $0 }
        guard header.contains("type") else {
            doc.skipped.append("Die erste Zeile braucht die Spalte \u{201C}type\u{201D} (erwartet: \(PlanCSV.header)).")
            return doc
        }
        let rows = rawRows.map { row -> [String: String] in
            var mapped: [String: String] = [:]
            for (key, value) in row { mapped[headerAliases[key] ?? key] = value }
            return mapped
        }

        var currentWeek: WeekKey?
        var positions: [String: Int] = [:]
        var measurePositions: [WeekKey: Int] = [:]
        var seen: [String: Int] = [:]

        func warnDuplicate(_ key: String, line: Int) {
            if let first = seen[key] {
                doc.warnings.append("Zeile \(line): \(key) kommt doppelt vor (auch Zeile \(first)) – die letzte Zeile gilt.")
            } else {
                seen[key] = line
            }
        }

        for (offset, row) in rows.enumerated() {
            let line = offset + 2
            func col(_ name: String) -> String { (row[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
            let typeText = col("type")
            if typeText.isEmpty, row.values.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) { continue }
            guard let type = RowType(token: typeText) else {
                doc.skipped.append("Zeile \(line): unbekannter Typ \u{201C}\(typeText)\u{201D}")
                continue
            }
            let id = col("id")
            let dateText = col("date")

            func day(from text: String) -> DayKey? {
                if let key = DayKey(text) { return key }
                if let week = currentWeek, let weekday = DayMask.weekday(text.lowercased()) { return week.day(weekday) }
                return nil
            }

            switch type {
            case .week:
                guard let week = WeekKey(id) ?? DayKey(dateText)?.week else {
                    doc.skipped.append("Zeile \(line): Woche \u{201C}\(id)\u{201D} nicht lesbar (erwartet z. B. 2026-W45)")
                    currentWeek = nil
                    continue
                }
                currentWeek = week
                warnDuplicate("week:\(week.string)", line: line)
                let flags = col("flags").lowercased()
                let model: String
                if flags.contains("alt") || flags.contains("old") { model = "alt" }
                else if flags.contains("neu") || flags.contains("new") { model = "" }
                else { model = week < WeekRecord.scoringChange ? "alt" : "" }
                let record = WeekRecord(week: week, title: col("title"), details: col("description"),
                                        recordedScore: Format.parse(col("value")), scoringModel: model)
                doc.weeks.removeAll { $0.week == week }
                doc.weeks.append(record)
                if flagSet(col("flags")).contains(closedFlag) { doc.closedWeeks.insert(week) }

            case .day:
                guard let key = day(from: id) ?? day(from: dateText) else {
                    doc.skipped.append("Zeile \(line): Tag \u{201C}\(id.isEmpty ? dateText : id)\u{201D} nicht lesbar (erwartet 2026-11-02 oder Mo)")
                    continue
                }
                warnDuplicate("day:\(key.string)", line: line)
                let isClosed = flagSet(col("flags")).contains(closedFlag)
                if isClosed { doc.closedDays.insert(key) }
                // A row that only says "closed" – or only the date (an unfilled template row, v8) –
                // leaves the day's type and note alone.
                if col("title").isEmpty, col("description").isEmpty { continue }
                doc.days.removeAll { $0.day == key }
                doc.days.append(DayRecord(day: key, dayType: col("title"), note: col("description")))

            case .goal:
                guard !id.isEmpty, !col("title").isEmpty else {
                    doc.skipped.append("Zeile \(line): Jahresziel ohne id oder Titel")
                    continue
                }
                warnDuplicate("goal:\(id)", line: line)
                doc.goals.removeAll { $0.key == id }
                doc.goals.append(GoalRecord(key: id, title: col("title"), details: col("description")))

            case .category:
                let parent = col("parent").isEmpty ? String(id.split(separator: ".").first ?? "") : col("parent")
                guard !id.isEmpty, !col("title").isEmpty, !parent.isEmpty else {
                    doc.skipped.append("Zeile \(line): Kategorie ohne id, Titel oder Jahresziel")
                    continue
                }
                warnDuplicate("category:\(id)", line: line)
                doc.categories.removeAll { $0.key == id }
                doc.categories.append(CategoryRecord(key: id, goalKey: parent, title: col("title"), details: col("description")))

            case .item:
                guard let week = currentWeek else {
                    doc.skipped.append("Zeile \(line): Punkt \u{201C}\(col("title"))\u{201D} steht vor der ersten week-Zeile")
                    continue
                }
                var category = col("parent")
                if category.isEmpty, let dash = id.firstIndex(of: "-") { category = String(id[..<dash]) }
                let title = col("title")
                guard !title.isEmpty else {
                    doc.skipped.append("Zeile \(line): Punkt ohne Titel")
                    continue
                }
                guard !category.isEmpty else {
                    doc.skipped.append("Zeile \(line): \u{201C}\(title)\u{201D} hat keine Kategorie (parent)")
                    continue
                }
                let positionKey = "\(week.string)|\(category)"
                let position = (positions[positionKey] ?? 0) + 1
                positions[positionKey] = position
                let code = id.isEmpty ? "\(category)-" + String(format: "%02d", position) : id
                var days = DayMask.everyDay
                if let parsed = DayMask.parse(col("days")) {
                    days = parsed
                } else {
                    doc.warnings.append("Zeile \(line): Tage \u{201C}\(col("days"))\u{201D} nicht lesbar – täglich angenommen")
                }
                let targetText = col("target")
                let target = Target.parse(targetText)
                if !targetText.isEmpty, target == nil {
                    doc.warnings.append("Zeile \(line): Ziel \u{201C}\(targetText)\u{201D} nicht lesbar – ignoriert")
                }
                warnDuplicate("item:\(week.string)|\(code)", line: line)
                doc.items.removeAll { $0.week == week && $0.code == code }
                doc.items.append(ItemRecord(
                    week: week, code: code, categoryKey: category, position: position, title: title,
                    details: col("description"), days: days, schedule: ItemSchedule(raw: col("schedule")),
                    target: target, measure: col("link"), knockout: flagSet(col("flags")).contains("ko"),
                    secondary: ItemFlags.secondary(Set(flagSet(col("flags")))), dayRule: ItemFlags.dayRule(Set(flagSet(col("flags"))))
                ))
                doc.plannedWeeks.insert(week)
                // Weekday columns (v8): a mark per day right on the item row.
                for (weekday, names) in matrixAliases {
                    guard let cell = names.lazy.map(col).first(where: { !$0.isEmpty }) else { continue }
                    guard let mark = Mark.parse(cell) else {
                        doc.skipped.append("Zeile \(line): \u{201C}\(title)\u{201D} \(weekday.short) \u{201C}\(cell)\u{201D} nicht lesbar (✓, ½, ✗ oder –)")
                        continue
                    }
                    let markDay = week.day(weekday)
                    doc.marks.removeAll { $0.week == week && $0.itemCode == code && $0.day == markDay }
                    doc.marks.append(MarkRecord(week: week, itemCode: code, day: markDay, mark: mark))
                }

            case .measure:
                guard let week = currentWeek else {
                    doc.skipped.append("Zeile \(line): Messwert \u{201C}\(col("title"))\u{201D} steht vor der ersten week-Zeile")
                    continue
                }
                let title = col("title")
                let code = id.isEmpty ? slug(title) : id
                guard !code.isEmpty else {
                    doc.skipped.append("Zeile \(line): Messwert ohne id und Titel")
                    continue
                }
                let targetText = col("target")
                let target = Target.parse(targetText)
                if !targetText.isEmpty, target == nil {
                    doc.warnings.append("Zeile \(line): Ziel \u{201C}\(targetText)\u{201D} nicht lesbar – ignoriert")
                }
                let flags = flagSet(col("flags"))
                let aggregation = flags.compactMap(Aggregation.init(token:)).first
                let position = (measurePositions[week] ?? 0) + 1
                measurePositions[week] = position
                warnDuplicate("measure:\(week.string)|\(code)", line: line)
                doc.measures.removeAll { $0.week == week && $0.code == code }
                doc.measures.append(MeasureRecord(
                    week: week, code: code, categoryKey: col("parent"), position: position, title: title.isEmpty ? code : title,
                    details: col("description"), unit: col("unit"), target: target, period: TargetPeriod(raw: col("period")),
                    source: MeasureSource(raw: col("link")), aggregation: aggregation,
                    days: DayMask.parse(col("days")) ?? .everyDay,
                    secondary: ItemFlags.secondary(Set(flags)), dayRule: ItemFlags.dayRule(Set(flags))
                ))
                doc.measuredWeeks.insert(week)

            case .mark:
                guard let key = day(from: dateText) else {
                    doc.skipped.append("Zeile \(line): Markierung ohne lesbares Datum")
                    continue
                }
                let valueText = col("value")
                let mark = Mark.parse(valueText)
                if mark == nil, !Mark.isBlank(valueText) {
                    doc.skipped.append("Zeile \(line): Markierung \u{201C}\(valueText)\u{201D} nicht lesbar (1, 0.5, 0 oder na)")
                    continue
                }
                guard !id.isEmpty else {
                    doc.skipped.append("Zeile \(line): Markierung ohne Punkt-id")
                    continue
                }
                let week = key.week
                doc.marks.removeAll { $0.week == week && $0.itemCode == id && $0.day == key }
                doc.marks.append(MarkRecord(week: week, itemCode: id, day: key, mark: mark, note: col("note")))

            case .entry:
                guard let key = day(from: dateText), !id.isEmpty else {
                    doc.skipped.append("Zeile \(line): Messwert-Eintrag ohne id oder Datum")
                    continue
                }
                let valueText = col("value")
                let isText = Units.isText(col("unit"))
                let value = isText ? nil : Format.parse(valueText)
                if !isText, value == nil, !valueText.isEmpty {
                    doc.skipped.append("Zeile \(line): Wert \u{201C}\(valueText)\u{201D} nicht lesbar")
                    continue
                }
                let flags = flagSet(col("flags"))
                let estimate = flags.contains { ["schaetzung", "schätzung", "geschätzt", "geschaetzt", "estimate", "~"].contains($0) }
                if flags.contains(singleFlag), !isText {
                    // One of several single entries of the day (R27): time in `title`.
                    let minutes = Format.parse(col("title"), isTime: true).map { Int($0) } ?? 0
                    let part = EntryPart(value: value, note: col("note"), minutes: minutes, estimate: estimate)
                    if let index = doc.entries.firstIndex(where: { $0.code == id && $0.day == key }), !doc.entries[index].parts.isEmpty {
                        doc.entries[index].parts.append(part)
                        doc.entries[index] = combined(doc.entries[index])
                    } else {
                        doc.entries.removeAll { $0.code == id && $0.day == key }
                        doc.entries.append(combined(EntryRecord(code: id, day: key, value: nil, parts: [part])))
                    }
                    continue
                }
                doc.entries.removeAll { $0.code == id && $0.day == key }
                doc.entries.append(EntryRecord(code: id, day: key, value: value, text: isText ? valueText : "", note: col("note"),
                                               estimate: estimate))

            case .work:
                guard let key = day(from: dateText) else {
                    doc.skipped.append("Zeile \(line): Arbeitsblock ohne lesbares Datum")
                    continue
                }
                let valueText = col("value")
                guard var powerHours = Format.parse(valueText, isTime: false), powerHours > 0 else {
                    doc.skipped.append("Zeile \(line): Arbeitsblock ohne Power-Hours (value)")
                    continue
                }
                // Minutes in older files ("unit" min): 50 min = 1 PH.
                if Units.normalized(col("unit")) == "min" { powerHours /= Double(PowerHour.minutes) }
                let task = col("title")
                let workID = id.isEmpty ? ImportPlan<WorkRecord>.contentKey([key.string, col("parent"), task, valueText]) : id
                doc.work.removeAll { $0.id == workID }
                doc.work.append(WorkRecord(id: workID, day: key, categoryKey: col("parent"), task: task, result: col("description"),
                                           powerHours: powerHours, nextStep: col("note")))

            case .note:
                guard let key = day(from: dateText) else {
                    doc.skipped.append("Zeile \(line): Notiz ohne lesbares Datum")
                    continue
                }
                let text = col("description").isEmpty ? col("note") : col("description")
                guard !text.isEmpty else { continue }
                let noteID = id.isEmpty ? ImportPlan<NoteRecord>.contentKey([key.string, text]) : id
                doc.notes.removeAll { $0.id == noteID }
                doc.notes.append(NoteRecord(id: noteID, day: key, kind: NoteKind(raw: col("title")), text: text))

            case .review:
                let scope: String
                if let week = WeekKey(id) { scope = week.string }
                else if let key = day(from: id) ?? day(from: dateText) { scope = key.string }
                else {
                    doc.skipped.append("Zeile \(line): Reflexion ohne Tag oder Woche")
                    continue
                }
                let field = col("title")
                guard !field.isEmpty else {
                    doc.skipped.append("Zeile \(line): Reflexion ohne Frage (title)")
                    continue
                }
                doc.reviews.removeAll { $0.scope == scope && $0.field == field }
                doc.reviews.append(ReviewRecord(scope: scope, field: field, text: col("description")))

            case .score:
                guard let key = day(from: dateText), !id.isEmpty, let value = Format.parse(col("value")) else {
                    doc.skipped.append("Zeile \(line): Kategoriewert braucht id, Datum und Wert")
                    continue
                }
                doc.scores.removeAll { $0.categoryKey == id && $0.day == key }
                doc.scores.append(ScoreRecord(categoryKey: id, day: key, score: value, reason: col("note")))
            }
        }

        validate(&doc, knownCategories: knownCategories, knownMeasures: knownMeasures)
        warnUnknownMarks(&doc, knownItems: knownItems)
        return doc
    }

    /// Marks on items that are neither in the file nor in the app (v8): one warning per week. A week
    /// whose item list is in the file only knows the file's items (the import replaces the others).
    static func warnUnknownMarks(_ doc: inout Document, knownItems: Set<String>) {
        let fileItems = Set(doc.items.map(\.key))
        var unknown: [WeekKey: Set<String>] = [:]
        for mark in doc.marks {
            let key = ItemRecord.key(week: mark.week, code: mark.itemCode)
            if fileItems.contains(key) { continue }
            let known = knownItems.contains(key) || knownItems.contains(mark.itemCode)
            if known, !doc.plannedWeeks.contains(mark.week) { continue }
            unknown[mark.week, default: []].insert(mark.itemCode)
        }
        for week in unknown.keys.sorted() {
            let codes = (unknown[week] ?? []).sorted()
            doc.warnings.append("\(week.label): Markierungen für unbekannte Punkte \(codes.joined(separator: ", ")) – sie zählen erst, wenn es diese Punkte in der Woche gibt.")
        }
    }

    /// The checks behind the preview's warnings: exactly ten items per category, references that exist.
    static func validate(_ doc: inout Document, knownCategories: [String: String], knownMeasures: Set<String>) {
        var categoryTitles = knownCategories
        for category in doc.categories { categoryTitles[category.key] = category.title }
        let goalKeys = Set(doc.goals.map(\.key))
        if !doc.goals.isEmpty, doc.goals.count != 10 {
            doc.warnings.append("Die Datei hat \(doc.goals.count) Jahresziele (bisher immer 10).")
        }
        for category in doc.categories where !goalKeys.isEmpty && !goalKeys.contains(category.goalKey) {
            doc.warnings.append("Kategorie \(category.key) gehört zu Jahresziel \(category.goalKey), das in der Datei fehlt.")
        }

        var unknown: [String] = []
        doc.items.removeAll { item in
            guard categoryTitles[item.categoryKey] == nil else { return false }
            unknown.append("\(item.week.label) \(item.code) \u{201C}\(item.title)\u{201D}: Kategorie \(item.categoryKey) gibt es nicht")
            return true
        }
        doc.skipped.append(contentsOf: unknown)

        for week in doc.plannedWeeks.sorted() {
            // Since v2 a category has as many items as the week needs – no fixed ten.
            let items = doc.items.filter { $0.week == week }
            let measureCodes = Set(doc.measures.filter { $0.week == week }.map(\.code)).union(knownMeasures)
            for item in items where !item.measure.isEmpty && !measureCodes.contains(item.measure) {
                doc.warnings.append("\(week.label) \(item.code): verknüpfter Messwert \u{201C}\(item.measure)\u{201D} fehlt – kein Vorschlag")
            }
            for item in items where item.schedule == .progress && item.measure.isEmpty {
                doc.warnings.append("\(week.label) \(item.code): Fortschritts-Punkt ohne Wochen-Messwert (link) – zählt wie ein fester Punkt")
            }
        }
    }

    /// Flag on day and week rows: the day / week is closed (R27).
    public static let closedFlag = "abgeschlossen"
    /// Flag on entry rows: one of several single entries of the day, its time in `title` (R27).
    public static let singleFlag = "einzeln"

    /// The day's value from its single entries: sum, notes joined with "; ", estimated if any part is.
    static func combined(_ entry: EntryRecord) -> EntryRecord {
        var result = entry
        let values = entry.parts.compactMap(\.value)
        result.value = values.isEmpty ? nil : values.reduce(0, +)
        result.note = entry.parts.map(\.note).filter { !$0.isEmpty }.joined(separator: "; ")
        result.estimate = entry.parts.contains { $0.estimate }
        result.text = ""
        result.order = 0
        return result
    }

    static func flagSet(_ text: String) -> [String] {
        text.lowercased().split(whereSeparator: { " ,;|+".contains($0) }).map(String.init)
    }

    /// "Protein (g)" → "protein", "Bettzeit" → "bettzeit", "Ä" → "ae".
    public static func slug(_ text: String) -> String {
        var result = ""
        for char in text.lowercased() {
            switch char {
            case "ä": result += "ae"
            case "ö": result += "oe"
            case "ü": result += "ue"
            case "ß": result += "ss"
            case "a"..."z", "0"..."9": result.append(char)
            case " ", "-", "_", ".": if !result.hasSuffix("_") && !result.isEmpty { result += "_" }
            default: continue
            }
        }
        while result.hasSuffix("_") { result.removeLast() }
        return result
    }

    // MARK: Writing

    /// Writes a document in the import format (export, backup, the template week).
    public static func export(_ doc: Document) -> String {
        var table: [[String]] = [columns]
        func row(_ values: [String: String]) {
            table.append(columns.map { values[$0] ?? "" })
        }
        for goal in doc.goals.sortedByNumber() {
            row(["type": "goal", "id": goal.key, "title": goal.title, "description": goal.details])
        }
        for category in doc.categories.sortedByKey() {
            row(["type": "category", "id": category.key, "parent": category.goalKey, "title": category.title, "description": category.details])
        }

        var weeks = Set(doc.weeks.map(\.week)).union(doc.closedWeeks)
        for day in doc.days.map(\.day) + doc.marks.map(\.day) + doc.entries.map(\.day) + doc.work.map(\.day) + doc.notes.map(\.day)
            + doc.scores.map(\.day) + Array(doc.closedDays) {
            weeks.insert(day.week)
        }
        for item in doc.items { weeks.insert(item.week) }
        for measure in doc.measures { weeks.insert(measure.week) }

        for week in weeks.sorted() {
            let record = doc.weeks.first { $0.week == week } ?? WeekRecord(week: week)
            var weekFlags: [String] = record.isOldScoring ? ["alt"] : []
            if doc.closedWeeks.contains(week) { weekFlags.append(closedFlag) }
            row(["type": "week", "id": week.string, "title": record.title, "description": record.details,
                 "flags": weekFlags.joined(separator: ","), "value": record.recordedScore.map(Format.plain) ?? "",
                 "date": week.monday.string])
            for day in week.days {
                let info = doc.days.first { $0.day == day }
                let isClosed = doc.closedDays.contains(day)
                guard info != nil || isClosed else { continue }
                row(["type": "day", "id": day.string, "title": info?.dayType ?? "", "description": info?.note ?? "",
                     "flags": isClosed ? closedFlag : ""])
            }
            for measure in doc.measures.filter({ $0.week == week }).sorted(by: { ($0.position, $0.code) < ($1.position, $1.code) }) {
                row(["type": "measure", "id": measure.code, "parent": measure.categoryKey, "title": measure.title,
                     "description": measure.details, "days": measure.days == .everyDay ? "" : measure.days.csv,
                     "unit": measure.unit, "target": measure.target?.raw ?? "", "period": measure.period.rawValue,
                     "link": measure.source.raw,
                     "flags": ItemFlags.text(secondary: measure.secondary, dayRule: measure.dayRule,
                                             extra: measure.aggregation == .default(forUnit: measure.unit) ? [] : [measure.aggregation.rawValue])])
            }
            for item in doc.items.filter({ $0.week == week }).sortedForSheet() {
                row(["type": "item", "id": item.code, "parent": item.categoryKey, "title": item.title, "description": item.details,
                     "days": item.days.csv, "schedule": item.schedule.raw, "target": item.target?.raw ?? "",
                     "link": item.measure, "flags": item.flags])
            }
            for mark in doc.marks.filter({ $0.week == week }).sorted(by: { ($0.day, $0.itemCode) < ($1.day, $1.itemCode) }) {
                row(["type": "mark", "id": mark.itemCode, "date": mark.day.string, "value": mark.mark?.rawValue ?? "", "note": mark.note])
            }
            for entry in doc.entries.filter({ week.contains($0.day) }).sorted(by: { ($0.day, $0.code) < ($1.day, $1.code) }) {
                if !entry.parts.isEmpty {
                    // Every single entry with its time (R27); older versions read only the last row.
                    for part in entry.parts.sorted(by: { $0.minutes < $1.minutes }) {
                        let flags = [singleFlag] + (part.estimate ? ["schaetzung"] : [])
                        row(["type": "entry", "id": entry.code, "date": entry.day.string, "title": Format.clock(Double(part.minutes)),
                             "value": part.value.map(Format.plain) ?? "", "flags": flags.joined(separator: ","), "note": part.note])
                    }
                    continue
                }
                let unitIsText = entry.value == nil && !entry.text.isEmpty
                row(["type": "entry", "id": entry.code, "date": entry.day.string,
                     "value": unitIsText ? entry.text : (entry.value.map(Format.plain) ?? ""),
                     "unit": unitIsText ? "text" : "", "flags": entry.estimate ? "schaetzung" : "", "note": entry.note])
            }
            for block in doc.work.filter({ week.contains($0.day) }).sorted(by: { ($0.day, $0.id) < ($1.day, $1.id) }) {
                row(["type": "work", "id": block.id, "parent": block.categoryKey, "title": block.task, "description": block.result,
                     "unit": "PH", "date": block.day.string, "value": Format.plain(block.powerHours), "note": block.nextStep])
            }
            for note in doc.notes.filter({ week.contains($0.day) }).sorted(by: { ($0.day, $0.id) < ($1.day, $1.id) }) {
                row(["type": "note", "id": note.id, "title": note.kind.rawValue, "description": note.text, "date": note.day.string])
            }
            for score in doc.scores.filter({ week.contains($0.day) }).sorted(by: { ($0.day, $0.categoryKey) < ($1.day, $1.categoryKey) }) {
                row(["type": "score", "id": score.categoryKey, "date": score.day.string, "value": Format.plain(score.score), "note": score.reason])
            }
            let scopes = Set([week.string] + week.days.map(\.string))
            for review in doc.reviews.filter({ scopes.contains($0.scope) }).sorted(by: { ($0.scope, $0.field) < ($1.scope, $1.field) }) {
                row(["type": "review", "id": review.scope, "title": review.field, "description": review.text])
            }
        }
        return CSV.write(table)
    }
}

extension PlanCSV.Document {
    /// Only one week's plan (R91): its week row, day rows, measurements and items – no results.
    public func planOnly(week: WeekKey) -> PlanCSV.Document {
        var doc = PlanCSV.Document()
        doc.weeks = weeks.filter { $0.week == week }.map { record in
            var plan = record
            plan.recordedScore = nil
            return plan
        }
        doc.days = days.filter { week.contains($0.day) }
        doc.measures = measures.filter { $0.week == week }
        doc.items = items.filter { $0.week == week }
        if !doc.items.isEmpty { doc.plannedWeeks = [week] }
        if !doc.measures.isEmpty { doc.measuredWeeks = [week] }
        return doc
    }

    /// The plan of `source` as the plan for `target` (R92): title and context of the source week,
    /// days moved by whole weeks (type and note stay), measurements and items with the same codes.
    /// No results, no closings, no reported score.
    public func repeated(from source: WeekKey, to target: WeekKey) -> PlanCSV.Document {
        let shift = target.monday.ordinal - source.monday.ordinal
        var doc = PlanCSV.Document()
        let sourceRecord = weeks.first { $0.week == source }
        doc.weeks = [WeekRecord(week: target, title: sourceRecord?.title ?? "", details: sourceRecord?.details ?? "",
                                recordedScore: nil, scoringModel: target < WeekRecord.scoringChange ? "alt" : "")]
        doc.days = days.filter { source.contains($0.day) }.map { day in
            DayRecord(day: day.day.adding(days: shift), dayType: day.dayType, note: day.note)
        }
        doc.measures = measures.filter { $0.week == source }.map { measure in
            var copy = measure
            copy.week = target
            return copy
        }
        doc.items = items.filter { $0.week == source }.map { item in
            var copy = item
            copy.week = target
            return copy
        }
        if !doc.items.isEmpty { doc.plannedWeeks = [target] }
        if !doc.measures.isEmpty { doc.measuredWeeks = [target] }
        return doc
    }

    // MARK: Past weeks (v8)

    /// The file's view of a week with the scoring rules: its items, marks, free and excused days.
    /// Categories the file doesn't list are taken from the item ids ("3.2" → goal 3), so the
    /// Business rule for free days still works.
    public func weekData(_ week: WeekKey) -> WeekData {
        var marksByKey: [String: Mark] = [:]
        for mark in marks where mark.week == week {
            if let value = mark.mark { marksByKey[WeekData.markKey(mark.itemCode, mark.day)] = value }
        }
        var allCategories = categories
        let listed = Set(categories.map(\.key))
        for key in Set(items.filter { $0.week == week }.map(\.categoryKey)).subtracting(listed).sorted() {
            allCategories.append(CategoryRecord(key: key, goalKey: String(key.split(separator: ".").first ?? ""), title: key))
        }
        let types = days.filter { week.contains($0.day) }
        return WeekData(week: week, goals: goals, categories: allCategories, items: items, marks: marksByKey,
                        workFreeDays: Set(types.filter { DayTypes.isWorkFree($0.dayType) }.map(\.day)),
                        excusedDays: Set(types.filter { DayTypes.isExcused($0.dayType) }.map(\.day)))
    }

    /// Blank fields of `weeks` filled with `mark` (the switch "Leere Felder als ✗ zählen"): every fixed,
    /// required item due on a day (not a free day for work items, not an excused day) without a mark.
    /// "n× pro Woche", progress, conditional and secondary items stay blank – the week's rules settle them.
    public func fillingBlanks(weeks: Set<WeekKey>, with mark: Mark) -> PlanCSV.Document {
        var doc = self
        for week in weeks.sorted() {
            let data = weekData(week)
            for item in data.items.sortedForSheet() where item.schedule == .fixed {
                for day in week.days where data.isOpenRequired(item, on: day) {
                    doc.marks.removeAll { $0.week == week && $0.itemCode == item.code && $0.day == day }
                    doc.marks.append(MarkRecord(week: week, itemCode: item.code, day: day, mark: mark))
                }
            }
        }
        return doc
    }

    /// Past weeks closed (a past week brought in later): every week of the file before
    /// `today.week` with items, marks or a week row, and its days with a mark or a day type.
    /// The current week and later ones stay open, each with a warning ("KW48: noch nicht vorbei – …").
    public func closingPast(today: DayKey) -> PlanCSV.Document {
        var doc = self
        let current = today.week
        var weeks = Set(self.weeks.map(\.week)).union(plannedWeeks)
        for mark in marks { weeks.insert(mark.week) }
        let past = weeks.filter { $0 < current }
        for week in weeks.subtracting(past).sorted() {
            doc.warnings.append("\(week.label): noch nicht vorbei – wird nicht abgeschlossen.")
        }
        doc.closedWeeks.formUnion(past)
        for week in past {
            for day in week.days {
                let marked = marks.contains { $0.day == day && $0.mark != nil }
                let typed = days.contains { $0.day == day && !$0.dayType.trimmingCharacters(in: .whitespaces).isEmpty }
                if marked || typed { doc.closedDays.insert(day) }
            }
        }
        return doc
    }
}
