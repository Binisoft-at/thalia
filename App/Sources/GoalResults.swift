import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

// v10 (TASKS-v10 §1.2): the results of the annual goals – what a goal is meant to achieve, next to the
// score that measures behaviour. On the goal page: "Ergebnisse" with anlegen, bearbeiten, abhaken, +1,
// Wert; the entries with their date can be changed or deleted (also back in time). "Jahresziel
// eintragen" records on `app.captureDay` (the day the app shows), the date stays changeable.

// MARK: Helpers (no SwiftUI – checked on Linux)

/// Texts and choices around results, as plain values.
enum ResultTexts {
    /// The quick action of a result row: "Abhaken", "+1", "Wert eintragen"; nil when the value comes
    /// from a source (the reading list, a measure, a connected app).
    static func quickAction(_ result: GoalResult) -> String? {
        switch result.kind {
        case .check:
            return "Abhaken"
        case .count:
            switch result.resultSource {
            case .entries, .other: return "+1"
            default: return nil
            }
        case .value:
            return "Wert eintragen"
        }
    }

    /// Own entries count for the result: everything except a count fed by a source.
    static func takesEntries(_ result: GoalResult) -> Bool {
        guard result.kind == .count else { return true }
        switch result.resultSource {
        case .entries, .other: return true
        default: return false
        }
    }

    /// " Bücher" – the unit after a number, nothing for € (the amount carries it).
    static func unitSuffix(_ unit: String) -> String {
        let shown: String = Units.display(unit)
        return shown.isEmpty || Units.normalized(unit) == "€" ? "" : " " + shown
    }

    /// One entry: "erledigt", "+1", "+2 Bücher", "86,4 kg".
    static func entryText(_ entry: GoalEntry, result: GoalResult) -> String {
        switch result.kind {
        case .check:
            return "erledigt"
        case .count:
            let value: Double = entry.value ?? 1
            if Units.normalized(result.unit) == "€" { return "+" + Format.euro(value) }
            return "+" + Format.number(value, decimals: 2) + unitSuffix(result.unit)
        case .value:
            return entry.value.map { Format.measure($0, unit: result.unit) } ?? "–"
        }
    }

    /// "Zählt für Di, 17. Nov." – only when the day isn't today.
    static func dayHint(_ day: DayKey, today: DayKey) -> String? {
        day == today ? nil : "Zählt für \(day.shortLabel)"
    }

    /// The toast after an entry: "Website online ✓", "Bücher +1 · Di, 17. Nov.", "Gewicht 86,4 kg".
    static func entryToast(_ result: GoalResult, value: Double?, day: DayKey, today: DayKey) -> String {
        var text: String
        switch result.kind {
        case .check:
            text = "\(result.title) ✓"
        case .count:
            text = "\(result.title) +\(Format.number(value ?? 1, decimals: 2))"
        case .value:
            text = "\(result.title) \(value.map { Format.measure($0, unit: result.unit) } ?? "")"
        }
        if day != today { text += " · \(day.shortLabel)" }
        return text
    }

    /// "Soll heute 4,2 von 10" – what an even pace would have reached by today; nil without a target.
    static func paceText(_ progress: ResultProgress) -> String? {
        guard progress.kind != .check, let expected = progress.expected, progress.targetValue != nil else { return nil }
        let unit: String = progress.unit
        let shown: String = Units.normalized(unit) == "€" ? Format.euro(expected) : Format.number(expected, decimals: 1) + unitSuffix(unit)
        return "Soll heute \(shown)"
    }

    /// "Ziel ≥ 10 · in Abschnitt 2: ≥ 6" – a result's targets in the settings list.
    static func targetSummary(_ result: GoalResult, segment: SegmentSpan?) -> String {
        var parts: [String] = []
        if let target = Target.parse(result.target) {
            parts.append("Ziel \(target.label)\(unitSuffix(result.unit))")
        } else {
            parts.append("ohne Ziel")
        }
        if let segment, let own = result.targets[segment.id].flatMap({ Target.parse($0) }) {
            parts.append("in \(segment.title): \(own.label)")
        }
        return parts.joined(separator: " · ")
    }

    /// The results on a goal card: "Bücher 3/10 · Website ✓ · +1"; nil without results.
    static func cardLine(_ lines: [(title: String, short: String)], limit: Int = 3) -> String? {
        guard !lines.isEmpty else { return nil }
        var parts: [String] = lines.prefix(limit).map { "\($0.title) \($0.short)" }
        if lines.count > limit { parts.append("+\(lines.count - limit)") }
        return parts.joined(separator: " · ")
    }

    /// A target text from the editor's fields: ">=10", "<=85"; "" without a comparison or a number.
    static func targetRaw(comparison raw: String, number: String) -> String {
        guard let comparison = Target.Comparison(rawValue: raw), let value = Format.parse(number) else { return "" }
        return Target(comparison, value).raw
    }

    /// "Ziel in Abschnitt 2 (ab KW48, optional)" – the field for a segment that hasn't begun yet.
    static func upcomingTargetPrompt(_ segment: SegmentSpan) -> String {
        "Ziel in \(segment.title) (ab \(segment.startWeek.label), optional)"
    }

    /// "Gilt ab Abschnitt 2 (KW48)" – a result new from a segment that hasn't begun yet.
    static func upcomingNote(_ result: GoalResult, segments: Segments) -> String {
        guard let from = result.fromSegment.flatMap({ segments.span(id: $0) }) else { return "Gilt ab einem späteren Abschnitt" }
        return "Gilt ab \(from.title) (\(from.startWeek.label))"
    }

    /// The number of a stored target for the editor's field ("10", "60.000").
    static func targetNumber(_ raw: String) -> String {
        guard let target = Target.parse(raw) else { return "" }
        return Format.number(target.value, decimals: 4)
    }

    /// The default unit for a new result: "Bücher" for the reading list, the measure's unit, the app's.
    static func suggestedUnit(type: ResultSourceType, measure: MeasureRecord?, app: AppSource?) -> String? {
        switch type {
        case .list: return "Bücher"
        case .measure: return measure.map { Units.display($0.unit) }
        case .app: return app?.suggestedUnit
        default: return nil
        }
    }

    /// "5 · Bücher gelesen" in a picker.
    static func choiceLabel(_ result: GoalResult) -> String {
        "\(result.goalKey) · \(result.title)"
    }

    /// v11 P7.7: the footer of "Ergebnisse" without a quick action, when a result counts through the reading list.
    static let listFooter = "Bücher zählen über die Leseliste: fertig ist ein Buch mit der letzten Seite unter „Lesen“ oder mit „Fertig“ im Buch-Fenster."

    /// v11 P7.7: the footer of the goal page's "Ergebnisse" from what it shows – nil when nothing needs saying.
    /// With quick actions the capture day, and how another date goes: "Eintrag mit Datum…" where a tick or +1 is
    /// shown, else "Wert eintragen" asks for the date.
    static func sectionFooter(_ results: [GoalResult], captureDay: DayKey, today: DayKey) -> String? {
        let quick: [GoalResult] = results.filter { quickAction($0) != nil }
        guard !quick.isEmpty else {
            let hasList: Bool = results.contains { ResultSourceType($0.resultSource) == .list }
            return hasList ? listFooter : nil
        }
        let dated: Bool = quick.contains { $0.kind != .value }
        let base: String = captureDay == today
            ? "Abhaken, +1 und Werte zählen für heute"
            : "Abhaken, +1 und Werte zählen für \(captureDay.shortLabel) – den Tag, den Thalia gerade zeigt"
        return base + (dated ? "; ein anderes Datum geht über „Eintrag mit Datum…“." : "; „Wert eintragen“ fragt nach dem Datum.")
    }

    /// v11 P1.11: the books a reading-list result counts in `from…through` – every finished entry of its kind that
    /// counts for no result, plus each that counts for this one ("zählt für", e.g. an audio book), each once.
    /// An entry of another result stays out; one counting for a deleted result (not in `resultIDs`) counts by kind.
    /// The same rule as `ResultProgress.compute`.
    static func countedBooks(_ result: GoalResult, items: [ListItem], resultIDs: Set<String>, from: DayKey,
                             through: DayKey) -> [ListItem] {
        guard case .list(let kind) = result.resultSource else { return [] }
        let live: [ListItem] = items.filter { $0.deletedAt == nil }
        func owner(_ item: ListItem) -> String? {
            guard let id = item.resultID?.trimmingCharacters(in: .whitespaces), !id.isEmpty else { return nil }
            if id != result.id, !resultIDs.contains(id) { return nil }
            return id
        }
        let assigned: [ListItem] = ListMath.finished(live.filter { owner($0) == result.id }, from: from, through: through)
        let byKind: [ListItem] = ListMath.finished(live.filter { owner($0) == nil }, from: from, through: through,
                                                   kind: kind ?? ListItem.kindKey(ListItem.defaultKind))
        var seen: Set<String> = []
        let counted: [ListItem] = (assigned + byKind).filter { seen.insert($0.id).inserted }
        return counted.sorted { ($0.finishedOn?.ordinal ?? 0, $0.title) < ($1.finishedOn?.ordinal ?? 0, $1.title) }
    }
}

/// Where a result's value comes from, as the editor offers it.
enum ResultSourceType: String, CaseIterable, Identifiable {
    case entries, list, measure, app, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .entries: "Eigene Einträge"
        case .list: "Leseliste"
        case .measure: "Messwert"
        case .app: "Verbundene App"
        case .other: "Andere Quelle (bleibt)"
        }
    }

    init(_ source: ResultSource) {
        switch source {
        case .entries: self = .entries
        case .list: self = .list
        case .measure: self = .measure
        case .app: self = .app
        case .other: self = .other
        }
    }

    /// The sources that fit a kind: a tick only from own entries; a target value not from the list.
    static func choices(for kind: GoalResult.Kind, current: ResultSourceType) -> [ResultSourceType] {
        var result: [ResultSourceType]
        switch kind {
        case .check: result = [.entries]
        case .count: result = [.entries, .list, .measure, .app]
        case .value: result = [.entries, .measure, .app]
        }
        if current == .other { result.append(.other) }
        return result
    }

    /// The stored source text.
    static func raw(type: ResultSourceType, listKind: String, measureCode: String, app: AppSource?, original: String) -> String {
        switch type {
        case .entries:
            return ""
        case .list:
            let key: String = ListItem.kindKey(listKind)
            return key.isEmpty ? "list" : "list:" + key
        case .measure:
            let code: String = measureCode.trimmingCharacters(in: .whitespaces)
            return code.isEmpty ? "" : "measure:" + code
        case .app:
            return app?.raw ?? ""
        case .other:
            return original
        }
    }
}

/// The result rows of a screen with their progress: results with a `measure:` or `app:` source get
/// their day values from the store once (`TrackerStore.resultSeries`).
struct ResultProgressTable {
    let context: WeekContext
    let series: [String: [DayKey: Double]]

    func progress(_ result: GoalResult) -> ResultProgress {
        context.progress(result, series: series[result.id] ?? [:])
    }

    /// The card line of a goal: up to three results with their short value.
    func cardLine(_ goal: AnnualGoal) -> String? {
        let results: [GoalResult] = context.results(of: goal)
        let lines: [(title: String, short: String)] = results.map { result in
            (title: result.title, short: progress(result).shortText)
        }
        return ResultTexts.cardLine(lines)
    }

    /// v11 P6.14: the result counts a measure from Apple Health that this device doesn't read (Mac, Watch) – its row
    /// says so ("Wert aus Health auf dem iPhone – hier ohne").
    func usesHealthElsewhere(_ result: GoalResult) -> Bool {
        guard case .measure(let code) = result.resultSource,
              let measure = context.measures.first(where: { $0.code == code }) else { return false }
        return context.isHealthElsewhere(measure, on: context.today)
    }

    /// "zählt für Ziel 5 · Bücher 3/10" for each result a measure feeds.
    func countsFor(_ measure: MeasureDefinition) -> [String] {
        context.results(feedBy: measure).map { result in
            let goal: GoalRecord? = context.goal(key: result.goalKey)?.record
            return GoalResultLine(result: result, goal: goal, progress: progress(result)).countsForText
        }
    }

    /// Loads the day values every result in `results` needs.
    @MainActor
    static func loadSeries(_ results: [GoalResult], context: WeekContext, store: TrackerStore) -> [String: [DayKey: Double]] {
        var loaded: [String: [DayKey: Double]] = [:]
        for result in results where context.needsSeries(result) {
            loaded[result.id] = store.resultSeries(result, period: context.goalPeriod, today: context.today)
        }
        return loaded
    }

    /// Changes when a result or the values behind it may have changed (the task loads again).
    /// v11 P7.11 (SYNC-3): a fingerprint of the values, not their counts – a changed weight or a newer Finn file changes
    /// the key; the number of Health values stays in it.
    static func loadKey(_ results: [GoalResult], context: WeekContext) -> String {
        let fed: [GoalResult] = results.filter { context.needsSeries($0) }
        guard !fed.isEmpty else { return "" }
        let ids: String = fed.map { "\($0.id):\($0.source):\($0.modifiedAt.timeIntervalSince1970)" }.joined(separator: ",")
        // HEALTHSHARE: also the shared days' count and newest change (Mac, watch, iPad – P9.3).
        let shared: String = context.healthShare.fingerprint
        return "\(ids)|\(context.today.string)|\(valuesFingerprint(fed, context: context))|\(context.health.count)|\(shared)"
    }

    /// The task's id: `loadKey` plus the sync counter, so values that arrive with iCloud load again (v11 P7.11).
    static func taskKey(_ results: [GoalResult], context: WeekContext, syncTick: Int) -> String {
        let key: String = loadKey(results, context: context)
        return key.isEmpty ? "" : key + "|\(syncTick)"
    }

    /// The fed values of the shown week: per `measure:` code the number, newest change and sum of its own entries
    /// (power-hours: the newest block); per `app:` source the day and `generatedAt` of each of its day files.
    static func valuesFingerprint(_ results: [GoalResult], context: WeekContext) -> String {
        var codes: Set<String> = []
        var sources: Set<String> = []
        for result in results {
            switch result.resultSource {
            case .measure(let code): codes.insert(code)
            case .app(let app): sources.insert(BinisoftExchange.sourceID(app.source))
            default: break
            }
        }
        var parts: [String] = []
        for code in codes.sorted() {
            let entries: [MeasureEntry] = context.entries.filter { $0.code == code && $0.deletedAt == nil }
            let newest: Double = entries.map(\.modifiedAt).max()?.timeIntervalSince1970 ?? 0
            let sum: Double = entries.compactMap(\.value).reduce(0, +)
            parts.append("\(code):\(entries.count):\(newest):\(sum)")
        }
        if !codes.isEmpty {
            let newestWork: Double = context.work.map(\.modifiedAt).max()?.timeIntervalSince1970 ?? 0
            parts.append("work:\(context.work.count):\(newestWork)")
        }
        for source in sources.sorted() {
            let stamps: [String] = context.inbox.filter { BinisoftExchange.sourceID($0.source) == source }
                .map { "\($0.day)@\($0.generatedAt)" }.sorted()
            parts.append("\(source):" + stamps.joined(separator: ","))
        }
        return parts.joined(separator: ";")
    }
}

/// A toast for a change of v10 records – "Widerrufen" puts it back exactly; closed weeks of an earlier
/// segment that stayed as they were are named (Grundregel 2).
enum RecordToast {
    @MainActor
    static func show(_ app: AppModel, _ message: String, symbol: String, change: RecordChange?) {
        guard let change, !change.isEmpty else {
            app.toasts.show(message, symbol: symbol)
            return
        }
        let store: TrackerStore = app.store
        app.toasts.show(message + frozenSuffix(change), symbol: symbol) {
            store.undo(change)
        }
    }

    /// " · KW44 bleibt, wie sie war" for frozen weeks the change didn't score again.
    static func frozenSuffix(_ change: RecordChange) -> String {
        let weeks: [WeekKey] = change.frozenWeeks.sorted()
        guard let first = weeks.first else { return "" }
        if weeks.count == 1 { return " · \(first.label) bleibt, wie sie war" }
        return " · \(weeks.count) frühere Wochen bleiben, wie sie waren"
    }
}

// MARK: Shared pieces

extension View {
    /// A sheet shown from a screen of its own (not through `app.sheet`): the app, its store and the toasts.
    func thaliaLocalSheet(_ app: AppModel) -> some View {
        self
            .environment(app)
            .modelContainer(app.container)
            .toastHost(app)
    }
}

/// "auf Kurs" in a small capsule; nothing for a result without a target.
/// v11 P7.2 (§1.2.4): one word set – "auf Kurs", "im Rückstand", "erreicht", "nicht erreicht"; a limit "im Rahmen",
/// "zu schnell", "eingehalten", "überschritten" – and one colour per status (`StatusTint`).
struct ResultStatusTag: View {
    let status: ResultProgress.Status
    /// A count with a limit ("höchstens 20 Packungen", `ResultProgress.isLimit`).
    var isLimit = false

    private var text: String { status.label(isLimit: isLimit) }
    private var color: Color { StatusTint(status).color }

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .foregroundStyle(color)
                .background(color.opacity(0.12), in: .capsule)
        }
    }
}

/// "✓ über 8" – a category's week score is above 8 (rounded like on screen, `GoalTrack.isGood`).
struct GoodWeekBadge: View {
    var body: some View {
        Text(GoalTrack.badge)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .foregroundStyle(Color("MarkDoneText"))
            .background(Color("MarkDoneText").opacity(0.12), in: .capsule)
            .accessibilityLabel("über 8 diese Woche")
    }
}

/// One result: title, status, "7 von 10 · davon 4 in Abschnitt 2" and a bar towards the target.
struct GoalResultRow: View {
    let result: GoalResult
    let progress: ResultProgress
    var showsGoal = false
    /// The goal's colour (kept for the callers). v11 P7.2, P1.10: the bar takes the status colour (`StatusTint`) –
    /// no colour that depends on the value.
    var tint: Color = Brand.accent
    /// v11 P6.14: the value comes from Apple Health on the iPhone – this device counts without it.
    var usesHealthElsewhere = false

    static let healthElsewhereText = "Wert aus Health auf dem iPhone – hier ohne"

    private var title: String {
        showsGoal ? ResultTexts.choiceLabel(result) : result.title
    }

    private var barColor: Color { StatusTint(progress.status).color }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 6)
                ResultStatusTag(status: progress.status, isLimit: progress.isLimit)
            }
            Text(progress.text)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if usesHealthElsewhere {
                Text(GoalResultRow.healthElsewhereText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let fraction = progress.fraction, result.kind != .check {
                ProgressView(value: min(1, max(0, fraction)))
                    .tint(barColor)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The day values of results with a `measure:` or `app:` source, loaded once per screen.
struct ResultSeriesReader<Content: View>: View {
    let results: [GoalResult]
    let context: WeekContext
    let content: (ResultProgressTable) -> Content
    @Environment(AppModel.self) private var app
    @State private var series: [String: [DayKey: Double]] = [:]

    init(results: [GoalResult], context: WeekContext, @ViewBuilder content: @escaping (ResultProgressTable) -> Content) {
        self.results = results
        self.context = context
        self.content = content
    }

    var body: some View {
        content(ResultProgressTable(context: context, series: series))
            // v11 P7.11: also after an iCloud import (`syncTick`) – a weight or a Finn value of another week.
            .task(id: ResultProgressTable.taskKey(results, context: context, syncTick: app.syncTick)) {
                series = ResultProgressTable.loadSeries(results, context: context, store: app.store)
            }
    }
}

// MARK: Goal page – "Ergebnisse"

/// What the goal page opens for results.
struct ResultSheet: Identifiable {
    enum Kind {
        case edit(GoalResult?, goalKey: String)
        case entry(resultID: String, day: DayKey)
    }

    let id = UUID()
    let kind: Kind
}

/// The goal page's "Ergebnisse" (§1.2.6): each result with its progress and its quick action (abhaken,
/// +1, Wert), its page with the dated entries, and "Ergebnis anlegen".
struct GoalResultsSection: View {
    let goal: AnnualGoal
    let context: WeekContext
    let table: ResultProgressTable
    let onSheet: (ResultSheet) -> Void
    @Environment(AppModel.self) private var app

    private var results: [GoalResult] { context.results(of: goal) }
    /// New from a segment that hasn't begun yet.
    private var upcoming: [GoalResult] { context.upcomingResults(of: goal) }

    var body: some View {
        Section {
            if results.isEmpty && upcoming.isEmpty {
                Text("Noch keine Ergebnisse. Ein Ergebnis hält fest, was am Ende stehen soll – zum Beispiel „10 Bücher“, „Website online“ oder ein Zielwert.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(results, id: \.id) { result in
                NavigationLink {
                    ResultDetailView(resultID: result.id)
                } label: {
                    GoalResultRow(result: result, progress: table.progress(result), tint: goal.color,
                                  usesHealthElsewhere: table.usesHealthElsewhere(result))
                }
                .contextMenu { menu(result) }
                if let action = ResultTexts.quickAction(result) {
                    quickRow(result, action: action)
                } else if ResultSourceType(result.resultSource) == .list {
                    // "Bücher 3 von 10 →" – the reading list counts (§1.3.4).
                    NavigationLink {
                        ReadingListView()
                    } label: {
                        Label("Leseliste", systemImage: "books.vertical")
                            .font(.subheadline)
                    }
                }
            }
            ForEach(upcoming, id: \.id) { result in
                NavigationLink {
                    ResultDetailView(resultID: result.id)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                        Text(ResultTexts.upcomingNote(result, segments: context.segments))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contextMenu { menu(result) }
            }
            Button {
                onSheet(ResultSheet(kind: .edit(nil, goalKey: goal.key)))
            } label: {
                Label("Ergebnis anlegen", systemImage: "plus")
            }
        } header: {
            Text("Ergebnisse")
        } footer: {
            if let footer {
                Text(footer)
            }
        }
    }

    /// v11 P7.7: from what the section shows – no "Eintrag mit Datum…" where there is no such button.
    private var footer: String? {
        ResultTexts.sectionFooter(results, captureDay: app.captureDay, today: app.today)
    }

    /// "Abhaken" · "+1" · "Wert eintragen", and "Eintrag mit Datum…".
    private func quickRow(_ result: GoalResult, action: String) -> some View {
        HStack(spacing: 12) {
            if result.kind == .check && table.progress(result).doneOn != nil {
                Button("Zurücknehmen", systemImage: "arrow.uturn.backward") { uncheck(result) }
            } else {
                Button(action, systemImage: quickSymbol(result)) { quick(result) }
            }
            Spacer(minLength: 4)
            if result.kind != .value {
                // A value always opens the sheet (with its date) – no second button for it.
                Button("Eintrag mit Datum…") {
                    onSheet(ResultSheet(kind: .entry(resultID: result.id, day: app.captureDay)))
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(.borderless)
    }

    @ViewBuilder
    private func menu(_ result: GoalResult) -> some View {
        Button("Bearbeiten…", systemImage: "pencil") {
            onSheet(ResultSheet(kind: .edit(result, goalKey: result.goalKey)))
        }
        if ResultTexts.takesEntries(result) {
            Button("Eintrag mit Datum…", systemImage: "calendar.badge.plus") {
                onSheet(ResultSheet(kind: .entry(resultID: result.id, day: app.captureDay)))
            }
        }
        Button("Löschen", systemImage: "trash", role: .destructive) {
            let change: RecordChange = app.store.trash(result)
            RecordToast.show(app, "„\(result.title)“ gelöscht", symbol: "trash.fill", change: change)
        }
    }

    private func quickSymbol(_ result: GoalResult) -> String {
        switch result.kind {
        case .check: "checkmark.circle"
        case .count: "plus.circle"
        case .value: "square.and.pencil"
        }
    }

    /// A tick or +1 on the capture day; a value opens the entry sheet.
    private func quick(_ result: GoalResult) {
        let day: DayKey = app.captureDay
        switch result.kind {
        case .check, .count:
            let change: RecordChange = app.store.addGoalEntry(to: result, day: day)
            RecordToast.show(app, ResultTexts.entryToast(result, value: nil, day: day, today: app.today), symbol: "trophy", change: change)
        case .value:
            onSheet(ResultSheet(kind: .entry(resultID: result.id, day: day)))
        }
    }

    private func uncheck(_ result: GoalResult) {
        let change: RecordChange = app.store.uncheck(result)
        RecordToast.show(app, "\(result.title): wieder offen", symbol: "arrow.uturn.backward", change: change)
    }
}

/// The sheets of `ResultSheet`, for any screen that opens them.
struct ResultSheetContent: View {
    let sheet: ResultSheet

    var body: some View {
        switch sheet.kind {
        case .edit(let result, let goalKey):
            ResultEditor(result: result, goalKey: goalKey)
        case .entry(let resultID, let day):
            GoalEntrySheet(day: day, resultID: resultID)
        }
    }
}

// MARK: A result's page

/// One result: where it stands, the pace, each segment's share, its entries with their dates (change,
/// delete, also back in time); a reading-list result lists the books it counts.
struct ResultDetailView: View {
    let resultID: String
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            if let result = context.results.first(where: { $0.id == resultID }) {
                ResultSeriesReader(results: [result], context: context) { table in
                    ResultDetailContent(result: result, context: context, progress: table.progress(result),
                                        usesHealthElsewhere: table.usesHealthElsewhere(result))
                }
            } else {
                ContentUnavailableView("Ergebnis nicht gefunden", systemImage: "trophy",
                                       description: Text("Vielleicht wurde es gelöscht – „Zuletzt gelöscht“ holt es zurück."))
            }
        }
    }
}

private struct EntryEditTarget: Identifiable {
    let entry: GoalEntry
    var id: String { entry.id }
}

struct ResultDetailContent: View {
    let result: GoalResult
    let context: WeekContext
    let progress: ResultProgress
    /// v11 P6.14: the value comes from Apple Health on the iPhone.
    var usesHealthElsewhere = false
    @Environment(AppModel.self) private var app
    @State private var sheet: ResultSheet?
    @State private var editingEntry: EntryEditTarget?

    private var goal: AnnualGoal? { context.goal(key: result.goalKey) }

    /// "Ziel 5 · Bildung"
    private var goalTitle: String {
        guard let goal else { return "Ziel \(result.goalKey)" }
        return "Ziel \(goal.key) · \(goal.title)"
    }
    private var tint: Color { GoalPalette.color(goal: result.goalKey) }
    private var entries: [GoalEntry] { context.entries(of: result).reversed() }

    /// Books that count for a reading-list result (finished in its time span). v11 P1.11: every finished one of
    /// its kind plus each that counts for it explicitly.
    private var countedBooks: [ListItem] {
        ResultTexts.countedBooks(result, items: context.listItems, resultIDs: Set(context.results.map(\.id)),
                                 from: progress.from, through: progress.through)
    }

    /// "Abschnitt 1: 3 · Abschnitt 2: 4" when the goal year has several segments.
    private var segmentLines: [(title: String, value: String)] {
        guard progress.hasSeveralSegments else { return [] }
        return context.segments.spans.compactMap { span -> (title: String, value: String)? in
            guard let value = progress.bySegment[span.id] else { return nil }
            return (title: span.title, value: ResultDetailContent.amount(value, result: result))
        }
    }

    static func amount(_ value: Double, result: GoalResult) -> String {
        switch result.kind {
        case .check: return value > 0 ? "erledigt" : "–"
        case .count: return Format.number(value, decimals: 2) + ResultTexts.unitSuffix(result.unit)
        case .value:
            let sign: String = value > 0 ? "+" : (value < 0 ? "−" : "")
            return sign + Format.measure(abs(value), unit: result.unit)
        }
    }

    var body: some View {
        List {
            Section {
                GoalResultRow(result: result, progress: progress, tint: tint, usesHealthElsewhere: usesHealthElsewhere)
                if let pace = ResultTexts.paceText(progress) {
                    LabeledContent("Gleichmäßiges Tempo", value: pace)
                }
                LabeledContent("Quelle", value: result.resultSource.label)
                if !result.note.isEmpty {
                    Text(result.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(goalTitle)
            } footer: {
                Text("Ergebnisse messen, was am Ende steht – die Wochenwertung misst das Verhalten. Das Tempo ist nur ein Vergleich, keine Aufforderung.")
            }

            if !segmentLines.isEmpty {
                Section("Je Abschnitt") {
                    ForEach(segmentLines, id: \.title) { line in
                        LabeledContent(line.title, value: line.value)
                    }
                }
            }

            if case .list = result.resultSource {
                Section {
                    if countedBooks.isEmpty {
                        Text("Noch kein Buch fertig in diesem Zeitraum.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(countedBooks, id: \.id) { item in
                        LabeledContent(item.label, value: item.finishedOn?.shortLabel ?? "")
                    }
                    NavigationLink {
                        ReadingListView()
                    } label: {
                        Label("Leseliste", systemImage: "books.vertical")
                    }
                } header: {
                    Text("Zählt")
                }
            }

            if ResultTexts.takesEntries(result) {
                entriesSection
            }
        }
        .navigationTitle(result.title)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Bearbeiten") {
                    sheet = ResultSheet(kind: .edit(result, goalKey: result.goalKey))
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            ResultSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
        .sheet(item: $editingEntry) { target in
            GoalEntryEditor(entry: target.entry, result: result)
                .thaliaLocalSheet(app)
        }
    }

    private var entriesSection: some View {
        Section {
            if entries.isEmpty {
                Text("Noch keine Einträge.")
                    .foregroundStyle(.secondary)
            }
            ForEach(entries, id: \.id) { entry in
                Button {
                    editingEntry = EntryEditTarget(entry: entry)
                } label: {
                    entryRow(entry)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(entry)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Bearbeiten…", systemImage: "pencil") { editingEntry = EntryEditTarget(entry: entry) }
                    Button("Löschen", systemImage: "trash", role: .destructive) { delete(entry) }
                }
            }
            Button {
                sheet = ResultSheet(kind: .entry(resultID: result.id, day: app.captureDay))
            } label: {
                Label("Eintrag mit Datum…", systemImage: "calendar.badge.plus")
            }
        } header: {
            Text("Einträge")
        } footer: {
            Text("Antippen ändert Datum, Wert oder Notiz – auch rückwirkend.")
        }
    }

    private func entryRow(_ entry: GoalEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(entry.day.shortLabel)
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 96, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(ResultTexts.entryText(entry, result: result))
                    .monospacedDigit()
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
        }
        .contentShape(.rect)
    }

    private func delete(_ entry: GoalEntry) {
        let change: RecordChange = app.store.trashGoalEntry(entry)
        RecordToast.show(app, "Eintrag vom \(entry.day.shortLabel) gelöscht", symbol: "trash.fill", change: change)
    }
}

// MARK: "Jahresziel eintragen"

/// "Jahresziel eintragen" (§1.2.6): choose a result, then abhaken, +n or a value – on `day` (the capture
/// day; any other day too, "Zählt für Di, 17. Nov.").
/// v11 P7.4: with exactly one result to choose it is chosen; a count or a value gets the focus, Return (Mac) and
/// "Eintragen" above the iPhone's number pad save.
struct GoalEntrySheet: View {
    let resultID: String?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var day: DayKey
    @State private var chosenID: String
    @State private var amountText = "1"
    @State private var valueText = ""
    @State private var note = ""
    @FocusState private var numberFocused: Bool

    init(day: DayKey, resultID: String? = nil) {
        self.resultID = resultID
        _day = State(initialValue: day)
        _chosenID = State(initialValue: resultID ?? "")
    }

    private var isDirty: Bool {
        !valueText.isEmpty || !note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            WeekReader(week: app.today.week, today: app.today) { context in
                form(context)
            }
            .navigationTitle(captureTitle("Jahresziel eintragen", day: day, today: app.today))
            .inlineNavigationTitle()
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 480, height: 620)
    }

    private func chosen(_ context: WeekContext) -> GoalResult? {
        context.activeResults.first { $0.id == chosenID }
    }

    /// The results that take own entries (a count fed by a source counts there).
    private func choices(_ context: WeekContext) -> [GoalResult] {
        context.activeResults.filter { ResultTexts.takesEntries($0) }
    }

    private func form(_ context: WeekContext) -> some View {
        let result: GoalResult? = chosen(context)
        return Form {
            Section {
                CaptureDayRow(day: $day, today: app.today)
            }
            Section {
                if choices(context).isEmpty {
                    Text("Noch kein Ergebnis zum Eintragen. Ergebnisse entstehen auf der Seite eines Jahresziels (Ziele → Ziel → Ergebnisse).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Ergebnis", selection: $chosenID) {
                        Text("Bitte wählen").tag("")
                        ForEach(choices(context), id: \.id) { choice in
                            Text(ResultTexts.choiceLabel(choice)).tag(choice.id)
                        }
                    }
                }
                if let result {
                    Text(context.progress(result).text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Jahresziel")
            }
            if let result {
                Section {
                    inputs(result, context: context)
                    TextField("Notiz (optional)", text: $note)
                } footer: {
                    Text(footer(result, context: context))
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Eintragen") { save(context) }
                    .disabled(!canSave(result))
            }
        }
        .onAppear { preselect(context) }
        // A moment after appearing (and after each choice): a focus set while the sheet still slides in can get lost.
        .task(id: chosenID) {
            guard GoalEntrySheet.takesNumber(chosen(context)) else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            numberFocused = true
        }
    }

    /// v11 P7.4: only when there is exactly one choice – no "zuletzt benutzt" (a wrong guess would be one tap away).
    private func preselect(_ context: WeekContext) {
        guard chosenID.isEmpty else { return }
        let all: [GoalResult] = choices(context)
        if all.count == 1, let only = all.first { chosenID = only.id }
    }

    /// A count or a value is typed (a tick isn't).
    static func takesNumber(_ result: GoalResult?) -> Bool {
        guard let result else { return false }
        return result.kind != .check
    }

    @ViewBuilder
    private func inputs(_ result: GoalResult, context: WeekContext) -> some View {
        switch result.kind {
        case .check:
            Label("Abhaken: erledigt am \(day.shortLabel)", systemImage: "checkmark.circle")
        case .count:
            HStack {
                TextField("Anzahl", text: $amountText)
                    .decimalKeyboard()
                    .focused($numberFocused)
                    .onSubmit { save(context) }
                    .keypadButton("Eintragen", isActive: numberFocused) { save(context) }
                Text(Units.display(result.unit)).foregroundStyle(.secondary)
            }
        case .value:
            HStack {
                TextField("Wert", text: $valueText)
                    .decimalKeyboard()
                    .focused($numberFocused)
                    .onSubmit { save(context) }
                    .keypadButton("Eintragen", isActive: numberFocused) { save(context) }
                Text(Units.display(result.unit)).foregroundStyle(.secondary)
            }
        }
    }

    private func footer(_ result: GoalResult, context: WeekContext) -> String {
        if result.kind == .check, let done = context.progress(result).doneOn {
            return "Schon erledigt am \(done.shortLabel) – Eintragen verschiebt das Datum."
        }
        if result.kind == .value, ResultSourceType(result.resultSource) != .entries {
            return "Ein eigener Wert ersetzt an diesem Tag den Wert aus „\(result.resultSource.label)“."
        }
        return "Zählt für \(day.shortLabel)."
    }

    private func canSave(_ result: GoalResult?) -> Bool {
        guard let result else { return false }
        switch result.kind {
        case .check: return true
        case .count: return (Format.parse(amountText) ?? 0) > 0
        case .value: return Format.parse(valueText) != nil
        }
    }

    private func save(_ context: WeekContext) {
        guard let result = chosen(context), canSave(result) else { return }
        var value: Double?
        switch result.kind {
        case .check: value = nil
        case .count: value = Format.parse(amountText)
        case .value: value = Format.parse(valueText)
        }
        let change: RecordChange = app.store.addGoalEntry(to: result, day: day, value: value, note: note)
        RecordToast.show(app, ResultTexts.entryToast(result, value: value, day: day, today: app.today), symbol: "trophy", change: change)
        dismiss()
    }
}

/// Changes one entry: its day (moves it), its value, its note; or deletes it.
struct GoalEntryEditor: View {
    let entry: GoalEntry
    let result: GoalResult
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var day: DayKey
    @State private var valueText: String
    @State private var note: String

    init(entry: GoalEntry, result: GoalResult) {
        self.entry = entry
        self.result = result
        _day = State(initialValue: entry.day)
        _valueText = State(initialValue: entry.value.map { Format.number($0, decimals: 4) } ?? "")
        _note = State(initialValue: entry.note)
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { day.startDate() }, set: { day = DayKey(date: $0) })
    }

    private var hasValue: Bool { result.kind != .check }

    private var isDirty: Bool {
        day != entry.day || note != entry.note || valueText != (entry.value.map { Format.number($0, decimals: 4) } ?? "")
    }

    private var canSave: Bool {
        guard hasValue else { return true }
        return Format.parse(valueText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Datum", selection: dateBinding, displayedComponents: .date)
                        .thaliaDateLocale()
                    if hasValue {
                        HStack {
                            TextField(result.kind == .count ? "Anzahl" : "Wert", text: $valueText)
                                .decimalKeyboard()
                            Text(Units.display(result.unit)).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Notiz (optional)", text: $note)
                } header: {
                    Text(result.title)
                } footer: {
                    Text("Ein anderes Datum verschiebt den Eintrag dorthin.")
                }
                Section {
                    Button("Eintrag löschen", systemImage: "trash", role: .destructive) { delete() }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Eintrag")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 440, height: 420)
    }

    private func save() {
        var changed: GoalEntry = entry
        changed.day = day
        changed.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if hasValue { changed.value = Format.parse(valueText) }
        let change: RecordChange = app.store.saveGoalEntry(changed)
        RecordToast.show(app, "Eintrag gesichert · \(day.shortLabel)", symbol: "trophy", change: change)
        dismiss()
    }

    private func delete() {
        let change: RecordChange = app.store.trashGoalEntry(entry)
        RecordToast.show(app, "Eintrag gelöscht", symbol: "trash.fill", change: change)
        dismiss()
    }
}

// MARK: The result editor

/// A result of an annual goal: title, kind, target (and the current segment's own target), start value,
/// unit, source, "neu ab" / "beendet nach" a segment, note.
struct ResultEditor: View {
    let result: GoalResult?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var goalKey: String
    @State private var title: String
    @State private var kind: GoalResult.Kind
    /// "" = without a target, else `Target.Comparison.rawValue`.
    @State private var comparisonRaw: String
    @State private var targetText: String
    @State private var segmentTargetText = ""
    /// The own target of a segment planned after the current one (`Segments.upcoming`).
    @State private var upcomingTargetText = ""
    @State private var startText: String
    @State private var unit: String
    @State private var sourceType: ResultSourceType
    @State private var listKind: String
    @State private var measureCode: String
    @State private var appSourceID: String
    @State private var appKind: String
    @State private var appRef: String
    @State private var fromSegment: String
    @State private var endedAfter: String
    @State private var note: String
    @State private var confirmsDelete = false
    @State private var loaded = false
    @State private var initialFields: [String]?
    @State private var goals: [GoalRecord] = []
    @State private var segments: Segments?
    @State private var measureChoices: [MeasureRecord] = []
    @State private var sources: [ExchangeSourceInfo] = []

    init(result: GoalResult?, goalKey: String) {
        self.result = result
        let target: Target? = Target.parse(result?.target ?? "")
        let source: ResultSource = result?.resultSource ?? .entries
        _goalKey = State(initialValue: result?.goalKey ?? goalKey)
        _title = State(initialValue: result?.title ?? "")
        _kind = State(initialValue: result?.kind ?? .count)
        _comparisonRaw = State(initialValue: target?.comparison.rawValue ?? "")
        _targetText = State(initialValue: target.map { Format.number($0.value, decimals: 4) } ?? "")
        _startText = State(initialValue: result?.start.map { Format.number($0, decimals: 4) } ?? "")
        _unit = State(initialValue: result?.unit ?? "")
        _sourceType = State(initialValue: ResultSourceType(source))
        var list: String = ListItem.defaultKind
        var measure: String = ""
        var parsedApp: AppSource?
        switch source {
        case .list(let listKey): list = listKey.map { ListItem.kindTitle($0) } ?? ListItem.defaultKind
        case .measure(let code): measure = code
        case .app(let parsed): parsedApp = parsed
        default: break
        }
        _listKind = State(initialValue: list)
        _measureCode = State(initialValue: measure)
        _appSourceID = State(initialValue: parsedApp?.source ?? "")
        _appKind = State(initialValue: parsedApp?.kind ?? "")
        _appRef = State(initialValue: parsedApp?.ref ?? "")
        _fromSegment = State(initialValue: result?.fromSegment ?? "")
        _endedAfter = State(initialValue: result?.endedAfter ?? "")
        _note = State(initialValue: result?.note ?? "")
    }

    private var currentSegment: SegmentSpan? {
        guard let segments, segments.hasSeveral else { return nil }
        return segments.current(today: app.today)
    }

    /// A segment begun for next week (or later) – right after "Neuen Abschnitt beginnen…" its target is
    /// set here, before it starts (§1.4.2 "Ziel je Abschnitt setzen").
    private var upcomingSegment: SegmentSpan? {
        guard let segments, segments.hasSeveral else { return nil }
        return segments.upcoming(today: app.today)
    }

    private var comparisonChoices: [Target.Comparison] {
        var choices: [Target.Comparison] = [.atLeast, .atMost]
        if let current = Target.Comparison(rawValue: comparisonRaw), !choices.contains(current) { choices.append(current) }
        return choices
    }

    private var appSource: AppSource? {
        let source: String = appSourceID.trimmingCharacters(in: .whitespaces)
        let kind: String = appKind.trimmingCharacters(in: .whitespaces)
        guard !source.isEmpty, !kind.isEmpty else { return nil }
        let ref: String = appRef.trimmingCharacters(in: .whitespaces)
        return AppSource(source: source, kind: kind, ref: ref.isEmpty ? nil : ref)
    }

    private var sourceInfo: ExchangeSourceInfo? {
        sources.first { BinisoftExchange.sourceID($0.source) == BinisoftExchange.sourceID(appSourceID) }
    }

    private var sourceRaw: String {
        ResultSourceType.raw(type: sourceType, listKind: listKind, measureCode: measureCode, app: appSource,
                             original: result?.source ?? "")
    }

    private var targetRaw: String {
        ResultTexts.targetRaw(comparison: comparisonRaw, number: targetText)
    }

    /// A segment's own target uses the year target's comparison (≥ without one).
    private func ownTargetRaw(_ number: String) -> String {
        let comparison: String = comparisonRaw.isEmpty ? Target.Comparison.atLeast.rawValue : comparisonRaw
        return ResultTexts.targetRaw(comparison: comparison, number: number)
    }

    private var sourceIncomplete: Bool {
        switch sourceType {
        case .measure: return measureCode.isEmpty
        // v11 §1.5.4: a balance needs its account – "alle" would be the latest balance of any account.
        case .app: return appSource.map { $0.requiresRef && ($0.ref ?? "").isEmpty } ?? true
        default: return false
        }
    }

    private var targetIncomplete: Bool {
        !comparisonRaw.isEmpty && Format.parse(targetText) == nil
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && !goalKey.isEmpty && !sourceIncomplete && !targetIncomplete
    }

    private func fields() -> [String] {
        [goalKey, title, kind.rawValue, comparisonRaw, targetText, segmentTargetText, upcomingTargetText, startText, unit,
         sourceType.rawValue, listKind, measureCode, appSourceID, appKind, appRef, fromSegment, endedAfter, note]
    }

    private var isDirty: Bool {
        guard let initialFields else { return false }
        return fields() != initialFields
    }

    var body: some View {
        NavigationStack {
            Form {
                basicsSection
                if kind != .check {
                    targetSection
                }
                sourceSection
                if let segments, segments.hasSeveral {
                    segmentSection(segments)
                }
                Section {
                    TextField("Notiz (optional)", text: $note, axis: .vertical)
                        .lineLimit(1...4)
                }
                if result != nil {
                    Section {
                        Button("Ergebnis löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(result == nil ? "Neues Ergebnis" : "Ergebnis bearbeiten")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("„\(title)“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive, action: delete)
            } message: {
                Text("Mit allen Einträgen. „Zuletzt gelöscht“ holt es 30 Tage lang zurück.")
            }
            .onAppear(perform: load)
            .onChange(of: sourceType) { _, type in suggestUnit(type) }
            .onChange(of: measureCode) { _, _ in suggestUnit(sourceType) }
            .onChange(of: appKind) { _, _ in
                suggestUnit(sourceType)
                // A ref of another kind doesn't fit the new one (a group is no account).
                if sourceInfo != nil, !appRef.isEmpty, !refChoices.contains(where: { $0.id == appRef }) { appRef = "" }
            }
            .onChange(of: kind) { _, newKind in
                let allowed: [ResultSourceType] = ResultSourceType.choices(for: newKind, current: sourceType)
                if !allowed.contains(sourceType) { sourceType = .entries }
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 520, height: 760)
    }

    /// Goal, title and kind (a section of its own, so the body stays small for the type checker).
    private var basicsSection: some View {
        Section {
            Picker("Jahresziel", selection: $goalKey) {
                if goalKey.isEmpty { Text("Bitte wählen").tag("") }
                ForEach(goals, id: \.key) { goal in
                    Text("\(goal.key) \(goal.title)").tag(goal.key)
                }
            }
            TextField("Titel (z. B. Bücher gelesen)", text: $title)
            Picker("Art", selection: $kind) {
                ForEach(GoalResult.Kind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(kindFooter)
        }
    }

    private var kindFooter: String {
        switch kind {
        case .check: "Abhaken: erledigt, sobald es einen Eintrag gibt – sein Datum ist „erledigt am“."
        case .count: "Zählen: die Summe der Einträge – oder fertige Bücher der Leseliste, ein Messwert, eine verbundene App."
        case .value: "Zielwert: der letzte Wert zählt (z. B. Vermögen, Gewicht) – aus eigenen Einträgen, einem Messwert oder einer verbundenen App."
        }
    }

    // MARK: Target

    private var targetSection: some View {
        Section {
            Picker("Ziel", selection: $comparisonRaw) {
                Text("ohne Ziel").tag("")
                ForEach(comparisonChoices, id: \.self) { choice in
                    Text(choice.choiceLabel).tag(choice.rawValue)
                }
            }
            if !comparisonRaw.isEmpty {
                HStack {
                    TextField("Wert", text: $targetText)
                        .decimalKeyboard()
                    Text(Units.display(unit)).foregroundStyle(.secondary)
                }
            }
            if kind == .value {
                HStack {
                    TextField("Startwert (optional)", text: $startText)
                        .decimalKeyboard()
                    Text(Units.display(unit)).foregroundStyle(.secondary)
                }
            }
            TextField("Einheit (z. B. Bücher, kg, €)", text: $unit)
            if let segment = currentSegment {
                HStack {
                    TextField("Ziel in \(segment.title) (optional)", text: $segmentTargetText)
                        .decimalKeyboard()
                    Text(Units.display(unit)).foregroundStyle(.secondary)
                }
            }
            if let upcoming = upcomingSegment {
                HStack {
                    TextField(ResultTexts.upcomingTargetPrompt(upcoming), text: $upcomingTargetText)
                        .decimalKeyboard()
                    Text(Units.display(unit)).foregroundStyle(.secondary)
                }
            }
            if targetIncomplete {
                Label("Bitte einen Wert für das Ziel eintragen.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Ziel")
        } footer: {
            Text(targetFooter)
        }
    }

    private var targetFooter: String {
        guard let segment = upcomingSegment ?? currentSegment else {
            return "Ohne Ziel zeigt Thalia nur den Stand. Das Tempo rechnet über das Zieljahr."
        }
        return "Ein eigenes Ziel für \(segment.title) ersetzt das Ziel des Zieljahrs, solange der Abschnitt läuft – Tempo und Stand rechnen dann im Abschnitt."
    }

    // MARK: Source

    private var sourceSection: some View {
        Section {
            Picker("Quelle", selection: $sourceType) {
                ForEach(ResultSourceType.choices(for: kind, current: sourceType)) { type in
                    Text(type.title).tag(type)
                }
            }
            switch sourceType {
            case .list:
                TextField("Art (z. B. Buch)", text: $listKind)
                Text("Zählt alle fertigen Einträge dieser Art der Leseliste – dazu jeden, der ausdrücklich für dieses Ergebnis zählt (z. B. ein Hörbuch).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .measure:
                measurePicker
            case .app:
                appPickers
            case .other:
                LabeledContent("Quelle", value: result?.source ?? "")
                Text("Diese Quelle kommt aus einer neueren Version von Thalia und bleibt unverändert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .entries:
                EmptyView()
            }
        } header: {
            Text("Quelle")
        }
    }

    @ViewBuilder
    private var measurePicker: some View {
        if measureChoices.isEmpty {
            Text("Noch keine Messwerte – sie kommen mit dem Wochenplan.")
                .foregroundStyle(.secondary)
        } else {
            Picker("Messwert", selection: $measureCode) {
                Text("Bitte wählen").tag("")
                ForEach(measureChoices, id: \.code) { measure in
                    Text(measure.title).tag(measure.code)
                }
                if !measureCode.isEmpty && !measureChoices.contains(where: { $0.code == measureCode }) {
                    Text(measureCode).tag(measureCode)
                }
            }
            Text(kind == .count ? "Zählt die Tageswerte über das Zieljahr (oder den Abschnitt)." : "Der letzte Tageswert zählt.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var appPickers: some View {
        if sources.isEmpty {
            TextField("Quelle (z. B. finn)", text: $appSourceID)
            TextField("Art oder Kennzahl (z. B. net_worth)", text: $appKind)
            if requiresRef {
                TextField("Konto (id aus der App)", text: $appRef)
            }
            Text("Noch keine verbundene App gesehen. Werte erscheinen, sobald Thalia die Daten auf diesem Gerät gelesen hat.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Picker("App", selection: $appSourceID) {
                Text("Bitte wählen").tag("")
                ForEach(sources, id: \.source) { info in
                    Text(info.displayName).tag(BinisoftExchange.sourceID(info.source))
                }
            }
            Picker("Art", selection: $appKind) {
                Text("Bitte wählen").tag("")
                ForEach(AppSource.kindChoices, id: \.self) { choice in
                    Text(AppSource(source: appSourceID, kind: choice).kindTitle).tag(choice)
                }
            }
            refPicker
            if let source = appSource {
                Text(source.label(refs: sourceInfo?.refs ?? []))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The refs that fit the chosen kind (`AppSource.refChoices` – accounts for "Kontostand").
    private var refChoices: [ExchangeRef] {
        guard let info = sourceInfo, let source = appSource else { return [] }
        return source.refChoices(info.refs)
    }

    /// v11 §1.5.4: the chosen kind needs a ref (`AppSource.requiresRef`, an account balance) – no "alle".
    private var requiresRef: Bool { appSource?.requiresRef ?? false }

    /// "Eintrag": "alle" or one ref; for a balance only an account ("Bitte wählen" until one is chosen).
    @ViewBuilder
    private var refPicker: some View {
        let choices: [ExchangeRef] = refChoices
        if !choices.isEmpty || !appRef.isEmpty {
            Picker(requiresRef ? "Konto" : "Eintrag", selection: $appRef) {
                if requiresRef {
                    if appRef.isEmpty { Text("Bitte wählen").tag("") }
                } else {
                    Text("alle").tag("")
                }
                ForEach(choices, id: \.id) { ref in
                    Text(ref.title.isEmpty ? ref.id : ref.title).tag(ref.id)
                }
                if !appRef.isEmpty && !choices.contains(where: { $0.id == appRef }) {
                    Text(appRef).tag(appRef)
                }
            }
        } else if requiresRef {
            TextField("Konto (id aus der App)", text: $appRef)
            Text("Noch kein Konto aus dieser App gesehen – in der App die Kontostände für Thalia einschalten.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Segments

    private func segmentSection(_ segments: Segments) -> some View {
        Section {
            Picker("Gilt ab", selection: $fromSegment) {
                Text("ganzes Zieljahr").tag("")
                ForEach(segments.spans, id: \.id) { span in
                    Text(span.label).tag(span.id)
                }
            }
            Picker("Beendet nach", selection: $endedAfter) {
                Text("läuft weiter").tag("")
                ForEach(segments.spans, id: \.id) { span in
                    Text(span.title).tag(span.id)
                }
            }
        } header: {
            Text("Abschnitte")
        } footer: {
            Text("Ein neues Ergebnis gilt ab seinem Abschnitt; ein beendetes zählt bis zum Ende des gewählten Abschnitts und erscheint danach nur noch bei den früheren Abschnitten.")
        }
    }

    // MARK: Actions

    private func load() {
        guard !loaded else { return }
        loaded = true
        let store: TrackerStore = app.store
        goals = Array(store.liveGoals().latest(by: \.key, modified: \.modifiedAt).values.map(\.record)).sortedByNumber()
        let resolved: Segments = store.segments()
        segments = resolved
        var measures: [MeasureRecord] = Array(store.measures(app.today.week).latest(by: \.code, modified: \.modifiedAt).values.compactMap(\.record))
        if measures.isEmpty { measures = store.latestMeasureRecords(through: app.today.week) }
        measureChoices = measures.filter { !$0.isText }.sorted { ($0.position, $0.code) < ($1.position, $1.code) }
        sources = store.exchangeSources().sources
        if let result, resolved.hasSeveral, let current = resolved.current(today: app.today), let own = result.targets[current.id] {
            segmentTargetText = ResultTexts.targetNumber(own)
        }
        let upcoming: SegmentSpan? = resolved.hasSeveral ? resolved.upcoming(today: app.today) : nil
        if let result, let upcoming, let own = result.targets[upcoming.id] {
            upcomingTargetText = ResultTexts.targetNumber(own)
        }
        if result == nil, resolved.hasSeveral, let current = resolved.current(today: app.today) {
            // A result added in a later segment is new from it (`fromSegment`) – right after a segment
            // was begun for next week, new from that one.
            if let upcoming {
                fromSegment = upcoming.id
            } else if current.number > 1 {
                fromSegment = current.id
            }
        }
        initialFields = fields()
    }

    private func suggestUnit(_ type: ResultSourceType) {
        guard result == nil || unit.isEmpty else { return }
        let measure: MeasureRecord? = measureChoices.first { $0.code == measureCode }
        if let suggested = ResultTexts.suggestedUnit(type: type, measure: measure, app: appSource), !suggested.isEmpty {
            unit = suggested
        }
    }

    private func save() {
        guard canSave else { return }
        let store: TrackerStore = app.store
        var record: GoalResult = result ?? store.newResult(goalKey: goalKey, title: title, kind: kind)
        record.goalKey = goalKey
        record.title = title
        record.kind = kind
        record.target = kind == .check ? "" : targetRaw
        if let segment = currentSegment {
            let own: String = kind == .check ? "" : ownTargetRaw(segmentTargetText)
            if own.isEmpty {
                record.targets.removeValue(forKey: segment.id)
            } else {
                record.targets[segment.id] = own
            }
        }
        if let upcoming = upcomingSegment {
            let own: String = kind == .check ? "" : ownTargetRaw(upcomingTargetText)
            if own.isEmpty {
                record.targets.removeValue(forKey: upcoming.id)
            } else {
                record.targets[upcoming.id] = own
            }
        }
        record.start = kind == .value ? Format.parse(startText) : nil
        record.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        record.source = kind == .check ? "" : sourceRaw
        record.fromSegment = fromSegment.isEmpty ? nil : fromSegment
        record.endedAfter = endedAfter.isEmpty ? nil : endedAfter
        record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let change: RecordChange = store.saveResult(record)
        RecordToast.show(app, result == nil ? "Ergebnis „\(record.title)“ angelegt" : "Ergebnis gesichert", symbol: "trophy", change: change)
        dismiss()
    }

    private func delete() {
        guard let result else { return }
        let change: RecordChange = app.store.trash(result)
        RecordToast.show(app, "„\(result.title)“ gelöscht", symbol: "trash.fill", change: change)
        dismiss()
    }
}
