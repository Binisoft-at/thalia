import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

// v10 (TASKS-v10 §1.3): the reading list – books and the like with their size and readings ("bis Seite
// 120"). Every reading is its own dated record, so a page can be entered for any day, also afterwards;
// a day's amount is the increase over the readings before it (`ListMath`). Reached from the Ziele page
// ("Gerade dabei") and from a result's page – the same on iPhone and Mac, no sidebar entry of its own.

// MARK: Helpers (no SwiftUI – checked on Linux)

/// "bis Seite" or "+ Seiten" in the progress sheet.
enum ReadingMode: String, CaseIterable, Identifiable {
    case reached, pages

    var id: String { rawValue }

    /// "bis Seite" / "+ Seiten" for books; "Stand" / "+ Minuten" for other units.
    func title(unit: String) -> String {
        switch self {
        case .reached: ReadingTexts.isPages(unit) ? "bis Seite" : "Stand"
        case .pages: "+ " + (unit.isEmpty ? "Menge" : unit)
        }
    }
}

enum ReadingTexts {
    /// A section of the reading list.
    struct Group: Equatable {
        let id: String
        let title: String
        let items: [ListItem]
    }

    static func isPages(_ unit: String) -> Bool {
        Units.normalized(unit) == Units.normalized("Seiten")
    }

    /// The title or the author contains the search text (any case); everything without one.
    static func matches(_ item: ListItem, query: String) -> Bool {
        let text: String = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(text) || item.subtitle.localizedCaseInsensitiveContains(text)
            || item.kind.localizedCaseInsensitiveContains(text)
    }

    /// The reading list's sections (§1.3.4): Läuft, Geplant, Fertig by segment (newest first; "Fertig ·
    /// früher" before the goal year), Abgebrochen. Empty sections are left out.
    static func groups(items: [ListItem], progress: [ListProgress], segments: Segments, query: String) -> [Group] {
        let shown: [ListItem] = items.filter { $0.deletedAt == nil && matches($0, query: query) }
        var running: [ListItem] = []
        var planned: [ListItem] = []
        var abandoned: [ListItem] = []
        var finished: [String: [ListItem]] = [:]
        for item in shown {
            switch ListMath.status(item, progress: progress) {
            case .running: running.append(item)
            case .planned: planned.append(item)
            case .abandoned: abandoned.append(item)
            case .finished:
                let key: String = item.finishedOn.flatMap { segments.span(for: $0)?.id } ?? outside(item, segments: segments)
                finished[key, default: []].append(item)
            }
        }
        var result: [Group] = []
        if !running.isEmpty {
            result.append(Group(id: "running", title: ListStatus.running.label, items: byLastReading(running, progress: progress)))
        }
        if !planned.isEmpty { result.append(Group(id: "planned", title: ListStatus.planned.label, items: planned)) }
        for span in segments.spans.reversed() {
            guard let done = finished[span.id], !done.isEmpty else { continue }
            let title: String = segments.hasSeveral ? "\(ListStatus.finished.label) · \(span.title)" : ListStatus.finished.label
            result.append(Group(id: "finished-" + span.id, title: title, items: newestFinishedFirst(done)))
        }
        if let later = finished["later"], !later.isEmpty {
            result.insert(Group(id: "finished-later", title: "\(ListStatus.finished.label) · nach dem Zieljahr", items: newestFinishedFirst(later)),
                          at: result.firstIndex { $0.id.hasPrefix("finished-") } ?? result.count)
        }
        if let earlier = finished["earlier"], !earlier.isEmpty {
            result.append(Group(id: "finished-earlier", title: "\(ListStatus.finished.label) · früher", items: newestFinishedFirst(earlier)))
        }
        if !abandoned.isEmpty { result.append(Group(id: "abandoned", title: ListStatus.abandoned.label, items: abandoned)) }
        return result
    }

    /// A finished entry outside the goal year: "earlier" or "later".
    static func outside(_ item: ListItem, segments: Segments) -> String {
        guard let day = item.finishedOn else { return "earlier" }
        return day > segments.period.end ? "later" : "earlier"
    }

    static func newestFinishedFirst(_ items: [ListItem]) -> [ListItem] {
        items.sorted { ($0.finishedOn?.ordinal ?? 0, $0.title) > ($1.finishedOn?.ordinal ?? 0, $1.title) }
    }

    /// Running books, the one read last first.
    static func byLastReading(_ items: [ListItem], progress: [ListProgress]) -> [ListItem] {
        items.sorted { a, b in
            let dayA: Int = ListMath.lastReadingDay(itemID: a.id, progress: progress)?.ordinal ?? a.startedOn?.ordinal ?? 0
            let dayB: Int = ListMath.lastReadingDay(itemID: b.id, progress: progress)?.ordinal ?? b.startedOn?.ordinal ?? 0
            return (dayA, b.title) > (dayB, a.title)
        }
    }

    /// "bis Seite 120", "Stand 45 Minuten".
    static func readingText(_ reached: Double, unit: String) -> String {
        let number: String = Format.number(reached, decimals: 0)
        if isPages(unit) { return "bis Seite \(number)" }
        return unit.isEmpty ? "Stand \(number)" : "Stand \(number) \(unit)"
    }

    /// "zuletzt bis Seite 120 · Mo, 16. Nov."; nil without readings.
    static func lastReadingText(_ item: ListItem, progress: [ListProgress]) -> String? {
        guard let last = ListMath.readings(progress, itemID: item.id).last else { return nil }
        return "zuletzt \(readingText(last.reached, unit: item.unit)) · \(last.day.shortLabel)"
    }

    /// The page after this entry: "bis Seite" as typed, "+ Seiten" on top of the highest reading up to `day`.
    static func reached(mode: ReadingMode, number: Double?, item: ListItem, progress: [ListProgress], day: DayKey) -> Double? {
        guard let number, number.isFinite, number >= 0 else { return nil }
        switch mode {
        case .reached: return number
        case .pages:
            guard number > 0 else { return nil }
            return (ListMath.reached(itemID: item.id, progress: progress, through: day) ?? 0) + number
        }
    }

    /// The toast: "Klarer Kopf: bis Seite 140 · fertig · Di, 17. Nov."
    static func toastText(_ item: ListItem, reached: Double, finished: Bool, day: DayKey, today: DayKey) -> String {
        var text: String = "\(item.title): \(readingText(reached, unit: item.unit))"
        if finished { text += " · fertig" }
        if day != today { text += " · \(day.shortLabel)" }
        return text
    }

    /// "Buch", "Kurs" … – shown when it isn't a book.
    static func kindTag(_ item: ListItem) -> String? {
        item.isKind(ListItem.defaultKind) ? nil : item.kind
    }

    /// "Gelesen in Abschnitt 2: 3 Bücher · 840 Seiten" – the amount of a span.
    static func spanLine(items: [ListItem], progress: [ListProgress], from: DayKey, through: DayKey, title: String) -> String? {
        let finished: Int = ListMath.finished(items, from: from, through: through).count
        let amount: Double = ListMath.amount(items: items, progress: progress, kind: ListItem.kindKey(ListItem.defaultKind), from: from, through: through)
        guard finished > 0 || amount > 0 else { return nil }
        var parts: [String] = []
        if finished > 0 { parts.append(Format.count(finished, "Eintrag fertig", "Einträge fertig")) }
        if amount > 0 { parts.append("\(Format.number(amount, decimals: 0)) Seiten") }
        return "\(title): " + parts.joined(separator: " · ")
    }
}

/// What the reading list opens.
struct ReadingSheet: Identifiable {
    enum Kind {
        /// The book's window (nil: a new one).
        case book(ListItem?)
        /// "bis Seite" / "+ Seiten" (nil: choose the book).
        case progress(itemID: String?, day: DayKey)
    }

    let id = UUID()
    let kind: Kind
}

/// The sheets of `ReadingSheet`, for any screen that opens them.
struct ReadingSheetContent: View {
    let sheet: ReadingSheet

    var body: some View {
        switch sheet.kind {
        case .book(let item):
            BookEditor(item: item)
        case .progress(let itemID, let day):
            ReadingProgressSheet(day: day, itemID: itemID)
        }
    }
}

// MARK: The list

/// "Leseliste": Läuft, Geplant, Fertig (by segment), Abgebrochen – with search and "+ Buch".
struct ReadingListView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            ReadingListContent(context: context)
        }
        .navigationTitle("Leseliste")
        .inlineNavigationTitle()
    }
}

struct ReadingListContent: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var search = ""
    @State private var sheet: ReadingSheet?

    private var groups: [ReadingTexts.Group] {
        ReadingTexts.groups(items: context.listItems, progress: context.listProgress, segments: context.segments, query: search)
    }

    var body: some View {
        let shown: [ReadingTexts.Group] = groups
        List {
            if context.listItems.isEmpty {
                Section {
                    Text("Noch nichts auf der Leseliste. Ein Buch mit Seitenzahl anlegen – den Stand dann mit „bis Seite“ oder „+ Seiten“ eintragen, auch rückwirkend.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    addButton
                }
            } else if shown.isEmpty {
                Text("Nichts gefunden für „\(search)“.")
                    .foregroundStyle(.secondary)
            }
            if let line = summaryLine {
                Section {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(shown, id: \.id) { group in
                Section {
                    ForEach(group.items, id: \.id) { item in
                        row(item)
                    }
                } header: {
                    Text(group.title)
                }
            }
        }
        .searchable(text: $search, prompt: "Titel oder Autor:in")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = ReadingSheet(kind: .book(nil))
                } label: {
                    Label("Buch hinzufügen", systemImage: "plus")
                }
            }
        }
        .sheet(item: $sheet) { sheet in
            ReadingSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
    }

    /// "Abschnitt 2: 2 Einträge fertig · 840 Seiten" – the current segment's reading (the goal year with one).
    private var summaryLine: String? {
        guard let span = context.currentSegment else { return nil }
        let title: String = context.segments.hasSeveral ? span.title : "Im Zieljahr"
        return ReadingTexts.spanLine(items: context.listItems, progress: context.listProgress, from: span.startDay,
                                     through: min(span.endDay, context.today), title: title)
    }

    private var addButton: some View {
        Button {
            sheet = ReadingSheet(kind: .book(nil))
        } label: {
            Label("Buch hinzufügen", systemImage: "plus")
        }
    }

    private func isOpen(_ item: ListItem) -> Bool {
        let status: ListStatus = context.status(item)
        return status == .running || status == .planned
    }

    private func row(_ item: ListItem) -> some View {
        Button {
            sheet = ReadingSheet(kind: .book(item))
        } label: {
            BookRow(item: item, context: context)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                trash(item)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            if isOpen(item) {
                Button {
                    sheet = ReadingSheet(kind: .progress(itemID: item.id, day: app.captureDay))
                } label: {
                    Label("Fortschritt", systemImage: "bookmark")
                }
                .tint(Brand.accent)
            }
        }
        .contextMenu {
            if isOpen(item) {
                Button("Fortschritt eintragen…", systemImage: "bookmark") {
                    sheet = ReadingSheet(kind: .progress(itemID: item.id, day: app.captureDay))
                }
            }
            Button("Bearbeiten…", systemImage: "pencil") { sheet = ReadingSheet(kind: .book(item)) }
            Button("Löschen", systemImage: "trash", role: .destructive) { trash(item) }
        }
    }

    private func trash(_ item: ListItem) {
        let change: RecordChange = app.store.trash(item)
        RecordToast.show(app, "„\(item.title)“ gelöscht", symbol: "trash.fill", change: change)
    }
}

/// One entry: title, author, kind, "120 von 320 Seiten · 38 %" and a bar.
struct BookRow: View {
    let item: ListItem
    let context: WeekContext
    var compact = false

    private var fraction: Double? { ListMath.fraction(item, progress: context.listProgress) }

    private var detail: String {
        var parts: [String] = []
        if !item.subtitle.isEmpty && !compact { parts.append(item.subtitle) }
        if let kind = ReadingTexts.kindTag(item) { parts.append(kind) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.title.isEmpty ? "Ohne Titel" : item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
            }
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(context.progressText(item))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            if let fraction, context.status(item) == .running {
                ProgressView(value: fraction)
                    .tint(Brand.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// "Gerade dabei" on the Ziele page (§1.3.4): the books being read – a tap enters the progress.
struct CurrentlyReadingCard: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var sheet: ReadingSheet?

    /// "Gerade läuft nichts – 2 geplant." when no book is being read.
    static func idleText(_ context: WeekContext) -> String {
        let planned: Int = context.listItems.filter { context.status($0) == .planned }.count
        guard planned > 0 else { return "Gerade läuft nichts." }
        return "Gerade läuft nichts – \(planned) geplant. Der erste Stand beginnt ein Buch."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Gerade dabei", systemImage: "book")
                    .font(.headline)
                Spacer(minLength: 6)
                NavigationLink {
                    ReadingListView()
                } label: {
                    Text("Leseliste")
                        .font(.subheadline)
                }
            }
            if context.runningListItems.isEmpty {
                Text(CurrentlyReadingCard.idleText(context))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(context.runningListItems, id: \.id) { item in
                Button {
                    sheet = ReadingSheet(kind: .progress(itemID: item.id, day: app.captureDay))
                } label: {
                    BookRow(item: item, context: context, compact: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Fortschritt eintragen")
            }
        }
        .card()
        .sheet(item: $sheet) { sheet in
            ReadingSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
    }
}

// MARK: Progress

/// "Lesen" (§1.2.6, §1.3): "bis Seite" or "+ Seiten" for a book on `day` (the capture day by default;
/// any day, also back in time). "bis Seite = Seitenzahl" suggests "fertig".
struct ReadingProgressSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var day: DayKey
    @State private var chosenID: String
    @State private var mode: ReadingMode = .reached
    @State private var numberText = ""
    @State private var note = ""
    /// nil: follow the suggestion ("fertig" once the last page is reached).
    @State private var finishChoice: Bool?
    /// "Buch hinzufügen" right here when the list is still empty.
    @State private var addsBook = false

    init(day: DayKey, itemID: String? = nil) {
        _day = State(initialValue: day)
        _chosenID = State(initialValue: itemID ?? "")
    }

    var body: some View {
        NavigationStack {
            WeekReader(week: app.today.week, today: app.today) { context in
                form(context)
            }
            .navigationTitle(captureTitle("Lesen", day: day, today: app.today))
            .inlineNavigationTitle()
        }
        .unsavedInput(!numberText.isEmpty, in: app)
        .thaliaSheetFrame(width: 460, height: 600)
    }

    /// Running books first (the one read last on top), then the planned ones.
    private func choices(_ context: WeekContext) -> [ListItem] {
        let running: [ListItem] = ReadingTexts.byLastReading(context.runningListItems, progress: context.listProgress)
        let planned: [ListItem] = context.listItems.filter { context.status($0) == .planned }
        var result: [ListItem] = running + planned
        if let chosen = context.listItems.first(where: { $0.id == chosenID }), !result.contains(where: { $0.id == chosen.id }) {
            result.append(chosen)
        }
        return result
    }

    private func chosen(_ context: WeekContext) -> ListItem? {
        context.listItems.first { $0.id == chosenID }
    }

    private func newReached(_ item: ListItem, context: WeekContext) -> Double? {
        ReadingTexts.reached(mode: mode, number: Format.parse(numberText), item: item, progress: context.listProgress, day: day)
    }

    private func suggestsFinish(_ item: ListItem, context: WeekContext) -> Bool {
        guard let reached = newReached(item, context: context) else { return false }
        return ListMath.suggestsFinish(item, reached: reached)
    }

    private func finishBinding(_ suggested: Bool) -> Binding<Bool> {
        Binding(get: { finishChoice ?? suggested }, set: { finishChoice = $0 })
    }

    private func form(_ context: WeekContext) -> some View {
        let item: ListItem? = chosen(context)
        return Form {
            Section {
                CaptureDayRow(day: $day, today: app.today)
            }
            Section {
                if choices(context).isEmpty {
                    Text("Noch kein Buch auf der Leseliste.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Buch hinzufügen", systemImage: "plus") { addsBook = true }
                } else {
                    Picker("Buch", selection: $chosenID) {
                        Text("Bitte wählen").tag("")
                        ForEach(choices(context), id: \.id) { choice in
                            Text(choice.label).tag(choice.id)
                        }
                    }
                }
                if let item {
                    Text(context.progressText(item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let last = ReadingTexts.lastReadingText(item, progress: context.listProgress) {
                        Text(last)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let item {
                Section {
                    Picker("Art", selection: $mode) {
                        ForEach(ReadingMode.allCases) { choice in
                            Text(choice.title(unit: item.unit)).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField(mode.title(unit: item.unit), text: $numberText)
                        .numberKeyboard()
                    if suggestsFinish(item, context: context) {
                        Toggle("Fertig am \(day.shortLabel)", isOn: finishBinding(true))
                    }
                    TextField("Notiz (optional)", text: $note)
                } footer: {
                    Text(footer(item, context: context))
                }
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Eintragen") { save(context) }
                    .disabled(!canSave(item, context: context))
            }
        }
        .sheet(isPresented: $addsBook) {
            BookEditor(item: nil)
                .thaliaLocalSheet(app)
        }
    }

    private func footer(_ item: ListItem, context: WeekContext) -> String {
        guard let reached = newReached(item, context: context) else {
            return "Eine Angabe je Tag: ein zweiter Stand am selben Tag ersetzt den ersten."
        }
        return "Danach \(ReadingTexts.readingText(reached, unit: item.unit)) am \(day.shortLabel). Eine Angabe je Tag: ein zweiter Stand am selben Tag ersetzt den ersten."
    }

    private func canSave(_ item: ListItem?, context: WeekContext) -> Bool {
        guard let item else { return false }
        return newReached(item, context: context) != nil
    }

    private func save(_ context: WeekContext) {
        guard let item = chosen(context), let reached = newReached(item, context: context) else { return }
        let store: TrackerStore = app.store
        var change: RecordChange
        switch mode {
        case .reached:
            change = store.addReading(item, day: day, reached: reached, note: note)
        case .pages:
            change = store.addPages(item, day: day, pages: Format.parse(numberText) ?? 0, note: note)
        }
        let finishes: Bool = suggestsFinish(item, context: context) && (finishChoice ?? true)
        if finishes {
            change.merge(store.finish(item, on: day))
        }
        RecordToast.show(app, ReadingTexts.toastText(item, reached: reached, finished: finishes, day: day, today: app.today),
                         symbol: "book.fill", change: change)
        dismiss()
    }
}

// MARK: The book's window

private struct ReadingEditTarget: Identifiable {
    let reading: ListProgress
    var id: String { reading.id }
}

/// A book (or course, film …): title, author, pages, kind, "zählt für", start and end (also back in
/// time), abandoned – and its readings.
struct BookEditor: View {
    let item: ListItem?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var subtitle: String
    @State private var kind: String
    @State private var totalText: String
    @State private var unit: String
    @State private var resultID: String
    @State private var hasStart: Bool
    @State private var startDay: DayKey
    @State private var hasEnd: Bool
    @State private var endDay: DayKey
    @State private var abandoned: Bool
    @State private var note: String
    @State private var confirmsDelete = false
    @State private var progressSheet: ReadingSheet?
    @State private var editingReading: ReadingEditTarget?
    private let initialFields: [String]

    init(item: ListItem?) {
        self.item = item
        let today: DayKey = DayKey.today()
        let kind: String = item?.kind ?? ListItem.defaultKind
        let total: String = item?.total.map { Format.number($0, decimals: 0) } ?? ""
        _title = State(initialValue: item?.title ?? "")
        _subtitle = State(initialValue: item?.subtitle ?? "")
        _kind = State(initialValue: kind)
        _totalText = State(initialValue: total)
        _unit = State(initialValue: item?.unit ?? ListItem.defaultUnit(kind: kind))
        _resultID = State(initialValue: item?.resultID ?? "")
        _hasStart = State(initialValue: item?.startedOn != nil)
        _startDay = State(initialValue: item?.startedOn ?? today)
        _hasEnd = State(initialValue: item?.finishedOn != nil)
        _endDay = State(initialValue: item?.finishedOn ?? today)
        _abandoned = State(initialValue: item?.abandoned ?? false)
        _note = State(initialValue: item?.note ?? "")
        initialFields = BookEditor.fields(title: item?.title ?? "", subtitle: item?.subtitle ?? "", kind: kind, total: total,
                                          unit: item?.unit ?? ListItem.defaultUnit(kind: kind), resultID: item?.resultID ?? "",
                                          start: item?.startedOn, end: item?.finishedOn, abandoned: item?.abandoned ?? false,
                                          note: item?.note ?? "")
    }

    static func fields(title: String, subtitle: String, kind: String, total: String, unit: String, resultID: String,
                       start: DayKey?, end: DayKey?, abandoned: Bool, note: String) -> [String] {
        [title, subtitle, kind, total, unit, resultID, start?.string ?? "", end?.string ?? "", String(abandoned), note]
    }

    private var currentFields: [String] {
        BookEditor.fields(title: title, subtitle: subtitle, kind: kind, total: totalText, unit: unit, resultID: resultID,
                          start: hasStart ? startDay : nil, end: hasEnd ? endDay : nil, abandoned: abandoned, note: note)
    }

    private var isDirty: Bool { currentFields != initialFields }

    private var totalValid: Bool {
        let text: String = totalText.trimmingCharacters(in: .whitespaces)
        return text.isEmpty || (Format.parse(text) ?? -1) > 0
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && totalValid
    }

    private func dateBinding(_ day: Binding<DayKey>) -> Binding<Date> {
        Binding(get: { day.wrappedValue.startDate() }, set: { day.wrappedValue = DayKey(date: $0) })
    }

    var body: some View {
        NavigationStack {
            WeekReader(week: app.today.week, today: app.today) { context in
                form(context)
            }
            .navigationTitle(item == nil ? "Neues Buch" : "Buch")
            .inlineNavigationTitle()
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 500, height: 760)
    }

    /// The count results a book can count for ("zählt für").
    private func resultChoices(_ context: WeekContext) -> [GoalResult] {
        context.activeResults.filter { $0.kind == .count }
    }

    /// The window's sections (each a function of its own, so the form stays small for the type checker).
    private func form(_ context: WeekContext) -> some View {
        Form {
            basicsSection
            kindSection
            countsForSection(context)
            periodSection
            if let item {
                readingsSection(item, context: context)
            }
            Section {
                TextField("Notiz (optional)", text: $note, axis: .vertical)
                    .lineLimit(1...4)
            }
            if item != nil {
                Section {
                    Button("Löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: hasEnd) { _, finished in
            if finished { abandoned = false }
        }
        .onChange(of: abandoned) { _, stopped in
            if stopped { hasEnd = false }
        }
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
            Text("Mit allen Ständen. „Zuletzt gelöscht“ holt es 30 Tage lang zurück.")
        }
        .sheet(item: $progressSheet) { sheet in
            ReadingSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
        .sheet(item: $editingReading) { target in
            ReadingEditor(reading: target.reading, unit: unit)
                .thaliaLocalSheet(app)
        }
    }

    /// Title, author and size ("Seitenzahl").
    private var basicsSection: some View {
        Section {
            TextField("Titel", text: $title)
            TextField("Autor:in (optional)", text: $subtitle)
            HStack {
                TextField(ReadingTexts.isPages(unit) ? "Seitenzahl" : "Umfang", text: $totalText)
                    .numberKeyboard()
                Text(unit).foregroundStyle(.secondary)
            }
            if !totalValid {
                Label("Bitte eine Zahl größer als 0 eintragen.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// The kind with suggestions; the unit follows a suggested kind.
    private var kindSection: some View {
        Section {
            TextField("Art", text: $kind)
            SuggestionChips(suggestions: ListItem.kindSuggestions, typed: "", selected: kind, limit: 8) { choice in
                pickKind(choice)
            }
            TextField("Einheit", text: $unit)
        } header: {
            Text("Art")
        } footer: {
            Text("Buch, Hörbuch, Kurs, Film … – die Einheit gilt für Umfang und Stand (Seiten, Minuten, Lektionen).")
        }
    }

    /// "Zählt für": a count result, or every finished entry of the kind.
    private func countsForSection(_ context: WeekContext) -> some View {
        let choices: [GoalResult] = resultChoices(context)
        return Section {
            Picker("Zählt für", selection: $resultID) {
                Text("nach Art (alle fertigen)").tag("")
                ForEach(choices, id: \.id) { result in
                    Text(ResultTexts.choiceLabel(result)).tag(result.id)
                }
                if !resultID.isEmpty && !choices.contains(where: { $0.id == resultID }) {
                    Text("anderes Ergebnis").tag(resultID)
                }
            }
        } footer: {
            Text("Ein Ergebnis wie „10 Bücher“ zählt fertige Einträge, die dafür zählen – ohne solche alle fertigen der Art.")
        }
    }

    /// Begonnen, Fertig (with their dates, also back in time) and Abgebrochen.
    private var periodSection: some View {
        Section {
            Toggle("Begonnen", isOn: $hasStart)
            if hasStart {
                DatePicker("am", selection: dateBinding($startDay), displayedComponents: .date)
                    .thaliaDateLocale()
            }
            Toggle("Fertig", isOn: $hasEnd)
            if hasEnd {
                DatePicker("am", selection: dateBinding($endDay), displayedComponents: .date)
                    .thaliaDateLocale()
            }
            Toggle("Abgebrochen", isOn: $abandoned)
        } header: {
            Text("Zeitraum")
        } footer: {
            Text("Beginn und Ende gehen auch rückwirkend – ein fertiges Buch zählt in dem Abschnitt, in dem es fertig wurde.")
        }
    }

    private func readingsSection(_ item: ListItem, context: WeekContext) -> some View {
        let readings: [ListProgress] = context.readings(of: item).reversed()
        return Section {
            if readings.isEmpty {
                Text("Noch kein Stand eingetragen.")
                    .foregroundStyle(.secondary)
            }
            ForEach(readings, id: \.id) { reading in
                Button {
                    editingReading = ReadingEditTarget(reading: reading)
                } label: {
                    LabeledContent(reading.day.shortLabel, value: ReadingTexts.readingText(reading.reached, unit: item.unit))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        trashReading(reading)
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button("Bearbeiten…", systemImage: "pencil") { editingReading = ReadingEditTarget(reading: reading) }
                    Button("Löschen", systemImage: "trash", role: .destructive) { trashReading(reading) }
                }
            }
            Button {
                progressSheet = ReadingSheet(kind: .progress(itemID: item.id, day: app.captureDay))
            } label: {
                Label("Fortschritt eintragen…", systemImage: "bookmark")
            }
        } header: {
            Text("Stand")
        } footer: {
            Text(context.progressText(item))
        }
    }

    /// A suggested kind; the unit follows it while it wasn't changed by hand.
    private func pickKind(_ choice: String) {
        let previousDefault: String = ListItem.defaultUnit(kind: kind)
        if unit.isEmpty || unit == previousDefault { unit = ListItem.defaultUnit(kind: choice) }
        kind = choice
    }

    private func save() {
        guard canSave else { return }
        let store: TrackerStore = app.store
        let trimmedKind: String = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        // The stored version: a reading entered meanwhile may have set the start, "fertig" the end.
        let stored: ListItem? = item.flatMap { store.record(ListItem.self, key: $0.settingKey) } ?? item
        var record: ListItem = stored ?? store.newListItem(title: title, kind: trimmedKind.isEmpty ? ListItem.defaultKind : trimmedKind)
        record.title = title
        record.subtitle = subtitle
        record.kind = trimmedKind.isEmpty ? ListItem.defaultKind : trimmedKind
        record.total = Format.parse(totalText).flatMap { $0 > 0 ? $0 : nil }
        let trimmedUnit: String = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        record.unit = trimmedUnit.isEmpty ? ListItem.defaultUnit(kind: record.kind) : trimmedUnit
        record.resultID = resultID.isEmpty ? nil : resultID
        let fields: [String] = currentFields
        // Start (index 6), end (7) and abandoned (8) only when changed here.
        if item == nil || fields[7] != initialFields[7] || fields[8] != initialFields[8] {
            record.finishedOn = hasEnd ? endDay : nil
            record.abandoned = abandoned
        }
        if item == nil || fields[6] != initialFields[6] {
            record.startedOn = hasStart ? startDay : nil
        }
        if let end = record.finishedOn, let begun = record.startedOn, begun > end { record.startedOn = end }
        record.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let change: RecordChange = store.saveListItem(record)
        RecordToast.show(app, item == nil ? "„\(record.title)“ auf der Leseliste" : "„\(record.title)“ gesichert", symbol: "book.fill", change: change)
        dismiss()
    }

    private func delete() {
        guard let item else { return }
        let change: RecordChange = app.store.trash(item)
        RecordToast.show(app, "„\(item.title)“ gelöscht", symbol: "trash.fill", change: change)
        dismiss()
    }

    private func trashReading(_ reading: ListProgress) {
        let change: RecordChange = app.store.trashReading(reading)
        RecordToast.show(app, "Stand vom \(reading.day.shortLabel) gelöscht", symbol: "trash.fill", change: change)
    }
}

/// Changes one reading: its day (moves it), the page, the note; or deletes it.
struct ReadingEditor: View {
    let reading: ListProgress
    let unit: String
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var day: DayKey
    @State private var reachedText: String
    @State private var note: String

    init(reading: ListProgress, unit: String) {
        self.reading = reading
        self.unit = unit
        _day = State(initialValue: reading.day)
        _reachedText = State(initialValue: Format.number(reading.reached, decimals: 0))
        _note = State(initialValue: reading.note)
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { day.startDate() }, set: { day = DayKey(date: $0) })
    }

    private var isDirty: Bool {
        day != reading.day || note != reading.note || reachedText != Format.number(reading.reached, decimals: 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Datum", selection: dateBinding, displayedComponents: .date)
                        .thaliaDateLocale()
                    HStack {
                        TextField(ReadingMode.reached.title(unit: unit), text: $reachedText)
                            .numberKeyboard()
                        Text(unit).foregroundStyle(.secondary)
                    }
                    TextField("Notiz (optional)", text: $note)
                } footer: {
                    Text("Ein anderes Datum verschiebt den Stand dorthin; die gelesene Menge der Tage rechnet Thalia neu.")
                }
                Section {
                    Button("Stand löschen", systemImage: "trash", role: .destructive) { delete() }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Stand")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern", action: save)
                        .disabled(Format.parse(reachedText) == nil)
                }
            }
        }
        .unsavedInput(isDirty, in: app)
        .thaliaSheetFrame(width: 420, height: 400)
    }

    private func save() {
        guard let reached = Format.parse(reachedText), reached >= 0 else { return }
        var changed: ListProgress = reading
        changed.day = day
        changed.reached = reached
        changed.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let change: RecordChange = app.store.saveReading(changed)
        RecordToast.show(app, "Stand gesichert · \(day.shortLabel)", symbol: "book.fill", change: change)
        dismiss()
    }

    private func delete() {
        let change: RecordChange = app.store.trashReading(reading)
        RecordToast.show(app, "Stand gelöscht", symbol: "trash.fill", change: change)
        dismiss()
    }
}
