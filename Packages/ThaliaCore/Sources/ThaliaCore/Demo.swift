import Foundation

/// Sample data for `-Demo` launches (screenshots) and the tour's practice page: the template week
/// for the current week with realistic entries up to today, the previous week tracked and closed,
/// and earlier weeks as reported scores (across the KW42 scoring change). Deterministic, so
/// screenshots are stable. Never synced.
public enum Demo {
    public struct Content: Sendable {
        public var document: PlanCSV.Document
        public var closedDays: [DayKey]
        public var closedWeeks: [WeekKey]
    }

    public static func content(today: DayKey, history: Bool = true) -> Content {
        let week = today.week
        var doc = Template.week(week)
        var closedDays: [DayKey] = []
        var closedWeeks: [WeekKey] = []

        fill(&doc, week: week, through: today, openDay: today, closed: &closedDays)

        if history {
            let previous = week.adding(weeks: -1)
            let last = Template.week(previous, includeStructure: false)
            doc.weeks.append(contentsOf: last.weeks)
            doc.days.append(contentsOf: last.days)
            doc.items.append(contentsOf: last.items)
            doc.measures.append(contentsOf: last.measures)
            doc.plannedWeeks.insert(previous)
            doc.measuredWeeks.insert(previous)
            fill(&doc, week: previous, through: previous.sunday, openDay: nil, closed: &closedDays)
            closedWeeks.append(previous)
            let answers = [
                ("interpretation", "Viel Nachhilfe, stammloop knapp im Plan. Schlaf unter der Woche gut, am Freitag zu spät."),
                ("wiederholen", "Erster Block vor 9:00 und Power-Hours sofort erfassen."),
                ("reibung", "HAEB-Zahlen am Dienstagabend mitgenommen."),
                ("ausserhalb", "Zwei abgesagte Nachhilfestunden."),
                ("aendern", "HAEB nur im Block, danach bewusst abschließen."),
                ("beibehalten", "Plan nicht erhöhen – die Woche wiederholen."),
            ]
            for (field, text) in answers {
                doc.reviews.append(ReviewRecord(scope: previous.string, field: field, text: text))
            }
            let scores: [Double] = [5.6, 6.1, 5.4, 6.3, 6.0, 6.6, 6.2, 6.8]
            for (index, score) in scores.enumerated() {
                let old = week.adding(weeks: -(scores.count + 1 - index))
                doc.weeks.append(WeekRecord(week: old, title: "", details: "Wertung aus dem Papier-Tracker.", recordedScore: score,
                                            scoringModel: old < WeekRecord.scoringChange ? "alt" : ""))
            }
        }
        return Content(document: doc, closedDays: closedDays, closedWeeks: closedWeeks)
    }

    // MARK: Generating a believable week

    /// `openDay`: the day still being filled in (today in the current week, none in a past week).
    static func fill(_ doc: inout PlanCSV.Document, week: WeekKey, through today: DayKey, openDay: DayKey?, closed: inout [DayKey]) {
        let measures = doc.measures.filter { $0.week == week }
        let items = doc.items.filter { $0.week == week }
        for day in week.days where day <= today {
            let isToday = day == openDay
            var rng = Random(seed: "\(day.string)")
            addEntries(&doc, day: day, isToday: isToday, rng: &rng)
            addWork(&doc, day: day, isToday: isToday)
            let dayValues = Dictionary(uniqueKeysWithValues: measures.map { m in
                (m.code, Measures.dayValue(m, on: day, entries: doc.entries, work: doc.work))
            })
            for (index, item) in items.enumerated() {
                var itemRng = Random(seed: "\(item.code)|\(day.string)")
                if isToday && index % 3 == 2 { continue }
                if let mark = mark(for: item, day: day, isToday: isToday, value: dayValues[item.measure] ?? nil, rng: &itemRng) {
                    doc.marks.append(MarkRecord(week: week, itemCode: item.code, day: day, mark: mark))
                }
            }
            if !isToday {
                closed.append(day)
                doc.reviews.append(ReviewRecord(scope: day.string, field: ReflectionQuestion.journalField, text: rng.unit() < 0.85 ? "ja" : "nein"))
                if rng.unit() < 0.5 {
                    let note = dayNotes[Int(rng.next() % UInt64(dayNotes.count))]
                    doc.reviews.append(ReviewRecord(scope: day.string, field: "notiz", text: note))
                }
            }
        }
        addNotes(&doc, week: week, through: today)
    }

    static func mark(for item: ItemRecord, day: DayKey, isToday: Bool, value: Double?, rng: inout Random) -> Mark? {
        guard item.applies(on: day) else { return nil }
        if item.schedule == .progress {
            // Worked on it when the linked measurement moved that day.
            return (value ?? 0) > 0 ? .done : .notApplicable
        }
        if let suggestion = Measures.suggestion(for: item, dayValue: value) { return suggestion }
        let r = rng.unit()
        switch item.schedule {
        case .fixed, .progress:
            if item.knockout { return day.weekday == .friday ? .missed : .done }
            if r < 0.76 { return .done }
            if r < 0.86 { return .partial }
            if r < 0.97 { return .missed }
            return isToday ? nil : .notApplicable
        case .weekly(let n):
            let chance = Double(n) / Double(max(1, item.days.count)) + 0.1
            return r < chance ? .done : nil
        case .conditional:
            guard !isToday else { return nil }
            if r < 0.18 { return .done }
            if r < 0.25 { return .missed }
            return .notApplicable
        case .optional:
            return r < 0.3 ? .done : nil
        }
    }

    static func addEntries(_ doc: inout PlanCSV.Document, day: DayKey, isToday: Bool, rng: inout Random) {
        func add(_ code: String, _ value: Double, order: Double = 0) {
            doc.entries.append(EntryRecord(code: code, day: day, value: value, order: order))
        }
        let weekday = day.weekday
        let base = Double(day.ordinal % 97)
        if [.monday, .wednesday, .friday].contains(weekday) {
            add("gewicht", 88.4 - base.truncatingRemainder(dividingBy: 9) * 0.1 - rng.unit() * 0.4)
        }
        add("schlaf", 6.3 + rng.unit() * 1.6)
        add("bettzeit", 22 * 60 + 35 + Double(Int(rng.unit() * 70)))
        add("terea", Double(Int(1 + rng.unit() * 3)), order: 1)
        if !isToday {
            add("terea", Double(Int(2 + rng.unit() * 3)), order: 2)
            add("seiten", Double(Int(rng.unit() * 25)))
            add("ausgaben", 12 + Double(Int(rng.unit() * 60)))
            if [.tuesday, .thursday, .saturday].contains(weekday) { add("aufschlaege", 50) }
            if weekday == .saturday { add("hobby", 95) }
            if weekday == .wednesday { add("hobby", 35) }
        }
    }

    static let stammloopTasks: [(String, String)] = [
        ("Landingpage", "Hero-Bereich und Preistabelle neu geschrieben"),
        ("Onboarding", "Registrierung auf zwei Schritte verkürzt"),
        ("Zahlungsanbindung", "Abo-Checkout im Testmodus funktioniert"),
        ("Kundenfeedback", "Fünf Rückmeldungen sortiert"),
        ("Fehlerliste", "Export-Fehler behoben"),
        ("Website-Iteration", "Neue Startseite veröffentlicht"),
    ]

    static let students = ["Lena – Mathe", "Jonas – Englisch", "Mia – Physik", "Elias – Mathe"]

    static func addWork(_ doc: inout PlanCSV.Document, day: DayKey, isToday: Bool) {
        let weekday = day.weekday
        guard weekday.rawValue <= 5 else { return }
        var blocks: [WorkRecord] = []
        let index = day.ordinal
        let id = { (n: Int) in "demo-\(day.string)-\(n)" }
        let task = stammloopTasks[index % stammloopTasks.count]
        blocks.append(WorkRecord(id: id(0), day: day, categoryKey: "3.2", task: task.0, result: task.1,
                                 powerHours: weekday == .wednesday ? 1 : 2))
        if weekday == .tuesday || weekday == .thursday {
            blocks.append(WorkRecord(id: id(1), day: day, categoryKey: "3.4", task: "Liquiditätsplanung",
                                     result: "Zahlungsplan an Partner geschickt", powerHours: weekday == .tuesday ? 2 : 1))
        }
        if weekday == .friday {
            blocks.append(WorkRecord(id: id(2), day: day, categoryKey: "3.5", task: "Buchhaltung", powerHours: 1))
        }
        let lessons: [Weekday: [Double]] = [.monday: [2, 2], .tuesday: [1, 2], .wednesday: [2], .thursday: [2, 1], .friday: [2, 2]]
        for (n, ph) in (lessons[weekday] ?? []).enumerated() {
            blocks.append(WorkRecord(id: id(3 + n), day: day, categoryKey: "3.3", task: students[(index + n) % students.count], powerHours: ph))
        }
        if isToday { blocks = Array(blocks.prefix(2)) }
        doc.work.append(contentsOf: blocks)
    }

    static func addNotes(_ doc: inout PlanCSV.Document, week: WeekKey, through today: DayKey) {
        let notes: [(Weekday, NoteKind, String)] = [
            (.monday, .idea, "Newsletter-Funktion für stammloop – geparkt bis zur Zielüberprüfung in KW49."),
            (.tuesday, .trigger, "HAEB-Zahlen nach dem Block noch im Kopf; Atempause hat geholfen."),
            (.wednesday, .success, "Familienblock pünktlich um 15:00 begonnen."),
            (.thursday, .contact, "Gespräch mit einem erfahrenen Unternehmer über Preise."),
        ]
        for (weekday, kind, text) in notes where week.day(weekday) <= today {
            doc.notes.append(NoteRecord(id: "demo-note-\(week.day(weekday).string)", day: week.day(weekday), kind: kind, text: text))
        }
    }

    static let dayNotes = [
        "Pünktlich gestartet, Blöcke sauber beendet.",
        "Ruhig geblieben, obwohl HAEB Druck gemacht hat.",
        "Präsent beim Familienblock.",
        "Zu lange im zweiten Block – morgen bewusst stoppen.",
    ]

    /// SplitMix64 – small, fast and the same everywhere (Swift's `hashValue` changes per launch).
    struct Random {
        var state: UInt64

        init(seed: String) {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in seed.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01b3
            }
            state = hash
        }

        mutating func next() -> UInt64 {
            state = state &+ 0x9e37_79b9_7f4a_7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
            z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
            return z ^ (z >> 31)
        }

        mutating func unit() -> Double {
            Double(next() >> 11) / Double(1 << 53)
        }
    }
}
