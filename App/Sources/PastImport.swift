import SwiftUI
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore

/// "Vergangene Woche nachtragen" (v8, decision 8): weeks from before the app or from a paper tracker,
/// three ways:
///   a) copy the nearest planned week's items (before or after) into the week, then tick them off in
///      the week table and close the week;
///   b) one prompt for ChatGPT with photos, PDFs or tables of one or many weeks → one CSV with a block
///      per week → preview per week → import. Past weeks and their days with entries are closed
///      (`Document.closingPast`), so they count in Rückblick, Ziele and Ø 4 Wo. v9: a block may hold
///      only the week's value and category or goal grades (an archive week – no items, nothing open or
///      missed); "Archivdaten dieser Wochen ersetzen" replaces what the app has for the file's past
///      weeks (for a repeated import, Undo brings it back);
///   c) only a week's score from paper (`WeekPlan.recordedScore`).
/// The weeks to choose from: last week back to the start of the goal year, at least 52 weeks.
struct PastWeekImportView: View {
    /// Start with this week (week menu); nil: last week, path b with the weeks of the attachments.
    let week: WeekKey?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    enum Way: String, CaseIterable, Identifiable {
        case plan, chat, score

        var id: String { rawValue }

        var title: String {
            switch self {
            case .plan: "Vom Plan"
            case .chat: "Mit ChatGPT"
            case .score: "Nur Wertung"
            }
        }

        var hint: String {
            switch self {
            case .plan:
                "Die Punkte einer geplanten Woche in die vergangene Woche kopieren – ohne Markierungen. Danach in der Woche abhaken, Tagestypen setzen und die Woche abschließen."
            case .chat:
                "Fotos, PDFs oder Tabellen einer oder vieler Wochen in ChatGPT geben. Zurück kommt eine CSV mit einem Block je Woche – auch nur mit Wochenwert und Noten; vergangene Wochen werden beim Import abgeschlossen."
            case .score:
                "Nur die Wochenwertung vom Papier eintragen (0 bis 10). Sie erscheint im Rückblick."
            }
        }
    }

    @State private var way: Way = .chat
    @State private var target: WeekKey
    @State private var choices: [WeekKey] = []
    @State private var didAppear = false
    @State private var problem: String?

    // a) Plan übernehmen
    @State private var source: WeekKey?
    @State private var sourceItemCount = 0
    @State private var targetItemCount = 0
    @State private var targetIsClosed = false
    @State private var confirmingCopy = false

    // b) Mit ChatGPT
    @State private var fixedRange: Bool
    @State private var from: WeekKey
    @State private var through: WeekKey
    @State private var templateWeek: WeekKey?
    @State private var templateItemCount = 0
    @State private var promptCopied = false
    @State private var text = ""
    /// The text and switch the current preview was made with (R20).
    @State private var previewText = ""
    @State private var previewBlanks = false
    @State private var previewReplaces = false
    @State private var preview: ImportPreview?
    @State private var blanksAsMissed = false
    /// v9: "Archivdaten dieser Wochen ersetzen" – off by default (decision 2).
    @State private var replacesArchives = false
    @State private var showFilePicker = false
    @State private var confirmingReplace = false

    // c) Nur Wertung
    @State private var scoreText = ""
    @State private var paperScore: Double?
    @State private var computedScore: Double?

    init(week: WeekKey?) {
        self.week = week
        let last = DayKey.today().week.adding(weeks: -1)
        let start: WeekKey = week.map { min($0, last) } ?? last
        _target = State(initialValue: start)
        _through = State(initialValue: start)
        _from = State(initialValue: week == nil ? start.adding(weeks: -3) : start)
        _fixedRange = State(initialValue: week != nil)
    }

    var body: some View {
        NavigationStack {
            form
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 600, height: 820)
    }

    private var form: some View {
        Form {
            waySection
            switch way {
            case .plan:
                planSection
            case .chat:
                promptSection
                pasteSection
                replaceSection
                if let preview {
                    previewSection(preview)
                }
            case .score:
                scoreSection
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Vergangene Woche nachtragen")
        .inlineNavigationTitle()
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            load(result)
        }
        .unsavedInput(hasDraft, in: app)
        .onAppear(perform: appear)
        .onChange(of: way) { problem = nil }
        .onChange(of: target) { refreshWeek() }
        .onChange(of: fixedRange) { refreshTemplate() }
        .onChange(of: from) {
            if from > through { through = from }
            refreshTemplate()
        }
        .onChange(of: through) {
            if through < from { from = through }
            refreshTemplate()
        }
        .onChange(of: blanksAsMissed) {
            if preview != nil { runPreview(text) }
        }
        .onChange(of: replacesArchives) {
            if preview != nil { runPreview(text) }
        }
        // The preview follows the text 0.6 s after the last keystroke (R20).
        .task(id: text) {
            guard text != previewText else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            runPreview(text)
        }
    }

    private var waySection: some View {
        Section {
            Picker("Weg", selection: $way) {
                ForEach(Way.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } footer: {
            Text(way.hint)
        }
    }

    private func weekPicker(_ title: String, selection: Binding<WeekKey>) -> some View {
        Picker(title, selection: selection) {
            ForEach(weekOptions, id: \.self) { week in
                Text(Self.weekTitle(week)).tag(week)
            }
        }
    }

    /// The choices plus whatever is selected (a week passed in from further back).
    private var weekOptions: [WeekKey] {
        var weeks = choices
        for selected in [target, from, through] where !weeks.contains(selected) { weeks.append(selected) }
        return weeks.sorted(by: >)
    }

    /// "KW45 2026 (2.–8. Nov.)"
    static func weekTitle(_ week: WeekKey) -> String { "\(week.longLabel) (\(week.rangeLabel))" }

    /// Last week back to the start of the goal year – at least 52 weeks.
    static func weekChoices(today: DayKey, yearStart: WeekKey) -> [WeekKey] {
        let last = today.week.adding(weeks: -1)
        let first = min(yearStart, today.week.adding(weeks: -52))
        var weeks: [WeekKey] = []
        var week = last
        while week >= first && weeks.count < 160 {
            weeks.append(week)
            week = week.adding(weeks: -1)
        }
        return weeks
    }

    // MARK: a) Plan übernehmen

    private var planSection: some View {
        Section {
            weekPicker("Woche", selection: $target)
            if targetItemCount > 0 {
                Label(planExistsText, systemImage: "checkmark.circle")
                    .font(.subheadline)
                Button("\(target.label) in der Woche öffnen", systemImage: "tablecells") { openWeek(target) }
                if !targetIsClosed {
                    Button("\(target.label) abschließen", systemImage: "flag.checkered") { app.sheet = .closeWeek(target) }
                }
            }
            if let source {
                LabeledContent("Vorlage", value: sourceText(source))
                Button {
                    if targetItemCount > 0 {
                        confirmingCopy = true
                    } else {
                        copyPlan(from: source)
                    }
                } label: {
                    Label("Plan von \(source.label) übernehmen", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .thaliaPrimaryAction()
                .confirmationDialog("\(target.label) ersetzen?", isPresented: $confirmingCopy, titleVisibility: .visible) {
                    Button("\(target.label) ersetzen", role: .destructive) { copyPlan(from: source) }
                } message: {
                    Text("Der bisherige Plan von \(target.label) kommt mit Markierungen und Werten ins Archiv. Das lässt sich danach widerrufen.")
                }
            } else {
                Text("Noch keine Woche mit Plan. Erst einen Wochenplan importieren – oder den Weg „Mit ChatGPT“ nehmen.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Woche")
        } footer: {
            Text("Kopiert Punkte und Messwerte mit ihren IDs – ohne Markierungen, Werte und Tagestypen. Danach öffnet sich die Woche: abhaken, Krank- und Urlaubstage setzen und die Woche abschließen. Erst dann zählt sie im Rückblick und bei den Zielen.")
        }
    }

    /// "KW45 hat schon 24 Punkte – direkt in der Woche abhaken."
    private var planExistsText: String {
        "\(target.label) hat schon \(Format.count(targetItemCount, "Punkt", "Punkte")) – direkt in der Woche abhaken."
    }

    /// "KW46 2026 (9.–15. Nov.) · 24 Punkte"
    private func sourceText(_ week: WeekKey) -> String {
        "\(Self.weekTitle(week)) · \(Format.count(sourceItemCount, "Punkt", "Punkte"))"
    }

    private func copyPlan(from source: WeekKey) {
        let week = target
        let result = app.store.copyPlan(from: source, to: week)
        app.showImported(result, message: "\(week.label): Plan von \(source.label) übernommen")
        openWeek(week)
    }

    /// The week table of `week` (abhaken, Tagestypen, abschließen).
    private func openWeek(_ week: WeekKey) {
        app.selectedWeek = week
        app.tab = .week
        app.sidebar = .week
        dismiss()
    }

    // MARK: b) Mit ChatGPT

    private var promptSection: some View {
        Section {
            Picker("Zeitraum", selection: $fixedRange) {
                Text("Wochen aus den Unterlagen").tag(false)
                Text("Fester Zeitraum").tag(true)
            }
            if fixedRange {
                weekPicker("Von", selection: $from)
                weekPicker("Bis", selection: $through)
            }
            LabeledContent("Vorlage", value: templateText)
            promptButtons
        } header: {
            Text("1 · Prompt kopieren")
        } footer: {
            Text(promptFooter)
        }
    }

    /// Two full-width rows: side by side, the long title wrapped and lost its symbol on the iPhone.
    @ViewBuilder
    private var promptButtons: some View {
        Button {
            Clipboard.copy(app.store.pastWeekPrompt(weeks: rangeWeeks, today: app.today))
            promptCopied = true
        } label: {
            Label(copyTitle, systemImage: copySymbol)
                .frame(maxWidth: .infinity)
        }
        .thaliaPrimaryAction()
        ChatGPTLink()
    }

    private var copyTitle: String { promptCopied ? "Prompt kopiert" : "Prompt kopieren" }
    private var copySymbol: String { promptCopied ? "checkmark" : "doc.on.doc" }

    /// The fixed range, oldest first; empty: the weeks of the attachments.
    private var rangeWeeks: [WeekKey] {
        guard fixedRange else { return [] }
        let end = max(from, through)
        var weeks: [WeekKey] = []
        var week = min(from, through)
        while week <= end && weeks.count < 160 {
            weeks.append(week)
            week = week.adding(weeks: 1)
        }
        return weeks
    }

    /// "Punkte von KW46 (24)"
    private var templateText: String {
        guard let templateWeek else { return "keine Woche mit Plan" }
        return "Punkte von \(templateWeek.label) (\(templateItemCount))"
    }

    private var promptFooter: String {
        var parts = ["Der Prompt enthält Ziele, Kategorien und Messwerte mit ihren IDs, das CSV-Format mit Kategorien- und Zielnoten und die Punkte der Vorlage – nur für wirklich abgehakte Einzelpunkte."]
        if fixedRange {
            parts.append("Zeitraum: genau \(rangeText).")
        } else {
            parts.append("ChatGPT liest KW und Datum jeder Woche aus den Unterlagen.")
        }
        parts.append("In ChatGPT einfügen, Fotos, PDFs oder Tabellen dazulegen – zurück kommt eine CSV mit einem Block je Woche.")
        if templateWeek == nil {
            parts.append("Ohne Woche mit Plan fehlt die Vorlage für Einzelhaken – Wochenwert und Noten gehen trotzdem.")
        }
        return parts.joined(separator: " ")
    }

    /// "KW40 2026 bis KW45 2026", or one week.
    private var rangeText: String {
        let first = min(from, through)
        let last = max(from, through)
        if first == last { return first.longLabel }
        return "\(first.longLabel) bis \(last.longLabel)"
    }

    private var pasteSection: some View {
        Section {
            CSVInputRows(text: $text, placeholder: "ChatGPTs ganze Antwort oder nur die CSV hier einfügen") { pasted in
                text = pasted
                runPreview(pasted)
            } onFile: {
                showFilePicker = true
            }
            Toggle("Leere Felder als ✗ zählen", isOn: $blanksAsMissed)
            Button("Vorschau", systemImage: "eye") { runPreview(text) }
                .disabled(Self.isBlank(text))
        } header: {
            Text("2 · CSV einfügen")
        } footer: {
            Text("Leere Felder bleiben sonst offen. Mit dem Schalter zählen leere Felder fester Punkte als ✗ Nicht erledigt – nie an freien Tagen, an Krank- und Urlaubstagen und in Wochen nur mit Wertung oder Noten.")
        }
    }

    /// v9 (decisions 2 and 9): a repeated import replaces what the app has for the file's past weeks.
    private var replaceSection: some View {
        Section {
            Toggle("Archivdaten dieser Wochen ersetzen", isOn: $replacesArchives)
        } footer: {
            Text("Alles, was die App für die Wochen der Datei hat, kommt ins Archiv und wird durch die Datei ersetzt – für einen erneuten Import. Wochen, die in der App abgehakt wurden, vorher aus der Datei nehmen. Widerrufen holt alles zurück. Diese Woche und spätere werden nie ersetzt.")
        }
    }

    private func previewSection(_ preview: ImportPreview) -> some View {
        Section {
            if preview.weekSummaries.isEmpty {
                Text(preview.headline)
                    .font(.headline)
            }
            ForEach(preview.weekSummaries, id: \.week) { summary in
                PastWeekSummaryRow(summary: summary)
            }
            ForEach(preview.replacements, id: \.week) { replacement in
                Label(replacement.text, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            // v11 P3.4 (b): a set "Krank"/"Urlaub" stays against the file ("Fr 27.11.: bleibt „Urlaub“ – …").
            ForEach(preview.notices, id: \.self) { notice in
                Label(notice, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            if !preview.otherLines.isEmpty {
                DisclosureGroup("Im Einzelnen") {
                    ForEach(preview.otherLines, id: \.self) { line in
                        Text(line).font(.caption)
                    }
                }
            }
            ImportPreviewDetails(preview: preview, warnings: otherWarnings(preview))
            Button {
                if preview.replacements.isEmpty {
                    apply(preview)
                } else {
                    confirmingReplace = true
                }
            } label: {
                Label(preview.importTitle, systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .thaliaPrimaryAction()
            // Only with a preview of exactly this text and switch (R20).
            .disabled(!isCurrent(preview))
            .confirmationDialog(preview.importTitle + "?", isPresented: $confirmingReplace, titleVisibility: .visible) {
                Button(preview.importTitle, role: .destructive) {
                    if let current = self.preview { apply(current) }
                }
            } message: {
                Text(preview.replaceMessage)
            }
        } header: {
            Text("3 · Vorschau je Woche")
        } footer: {
            Text("Vergangene Wochen und ihre Tage mit Einträgen werden abgeschlossen – so zählen sie im Rückblick, bei den Zielen und im Ø 4 Wo. Wochen nur mit Wertung oder Noten bekommen keine Punkte: nichts ist offen oder verpasst. Hat eine Woche schon einen anderen Plan, kommt der alte mit Markierungen und Werten ins Archiv.")
        }
    }

    /// Warnings that belong to no week of the file (the others stand under their week).
    private func otherWarnings(_ preview: ImportPreview) -> [String] {
        let shown = Set(preview.weekSummaries.flatMap(\.warnings))
        return preview.document.warnings.filter { !shown.contains($0) }
    }

    private func isCurrent(_ preview: ImportPreview) -> Bool {
        preview.hasChanges && previewText == text && previewBlanks == blanksAsMissed && previewReplaces == replacesArchives
    }

    // MARK: c) Nur Wertung

    private var scoreSection: some View {
        Section {
            weekPicker("Woche", selection: $target)
            TextField("Wertung, z. B. 7,5", text: $scoreText)
                .decimalKeyboard()
                .onSubmit(saveScore)
            if let paperScore {
                LabeledContent("Laut Unterlagen", value: Format.score(paperScore, outOf: true))
            }
            if let computedScore {
                Label(computedText(computedScore), systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                saveScore()
            } label: {
                Label("Wertung eintragen", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .thaliaPrimaryAction()
            .disabled(parsedScore == nil)
            if paperScore != nil {
                Button("Wertung entfernen", systemImage: "trash", role: .destructive) { removeScore() }
            }
        } header: {
            Text("Wochenwertung")
        } footer: {
            Text("Eine Zahl von 0 bis 10 vom Papier – die Wertung laut Unterlagen. Sie erscheint im Rückblick und in den Trendzeilen des Planungs-Prompts und zählt dort vor einer berechneten Wertung; die Woche zeigt beide.")
        }
    }

    /// "KW45 ist abgeschlossen: nach heutigen Regeln 7,2 – …" (v9: the value laut Unterlagen counts first).
    private func computedText(_ score: Double) -> String {
        let computed: String = "\(target.label) ist abgeschlossen: \(ImportWeekSummary.recalculatedLabel) \(Format.score(score))"
        guard paperScore == nil else { return computed + ". Im Rückblick zählt die Wertung laut Unterlagen." }
        return computed + " – diese Wertung zählt im Rückblick, bis eine laut Unterlagen eingetragen ist."
    }

    /// 0…10, "7,5" or "7.5".
    private var parsedScore: Double? {
        guard let value = Format.parse(scoreText), value >= 0, value <= 10 else { return nil }
        return value
    }

    private func saveScore() {
        guard let score = parsedScore else { return }
        let week = target
        app.store.setPaperScore(score, week: week)
        app.toasts.show("\(week.label): Wertung \(Format.score(score)) eingetragen", symbol: "checkmark.circle.fill")
        scoreText = ""
        refreshWeek()
    }

    /// v11 P5.8: with "Widerrufen" – the score from paper comes back.
    private func removeScore() {
        let week = target
        let store: TrackerStore = app.store
        let previous: Double? = store.plan(week)?.recordedScore
        store.setPaperScore(nil, week: week)
        app.toasts.show("\(week.label): Wertung entfernt", symbol: "trash") {
            store.setPaperScore(previous, week: week)
            refreshWeek()
        }
        refreshWeek()
    }

    // MARK: Actions

    private var hasDraft: Bool { !Self.isBlank(text) || !Self.isBlank(scoreText) }

    private static func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func appear() {
        guard !didAppear else { return }
        didAppear = true
        choices = Self.weekChoices(today: app.today, yearStart: app.store.goalPeriod.start.week)
        refreshWeek()
        refreshTemplate()
    }

    /// What the app has for the chosen week: its plan, the nearest planned week, the paper score.
    private func refreshWeek() {
        let store = app.store
        let weekPlan = store.plan(target)
        paperScore = weekPlan?.recordedScore
        computedScore = weekPlan?.finalScore
        targetIsClosed = weekPlan?.isClosed ?? false
        targetItemCount = store.plannedItemCount(target)
        let nearest = store.nearestPlannedWeek(to: target)
        source = nearest
        if let nearest {
            sourceItemCount = store.plannedItemCount(nearest)
        } else {
            sourceItemCount = 0
        }
        problem = nil
    }

    /// The week whose items the prompt takes as template.
    private func refreshTemplate() {
        promptCopied = false
        let store = app.store
        let week = store.pastTemplateWeek(for: rangeWeeks, today: app.today)
        templateWeek = week
        if let week {
            templateItemCount = store.plannedItemCount(week)
        } else {
            templateItemCount = 0
        }
    }

    private func runPreview(_ content: String) {
        problem = nil
        previewText = content
        previewBlanks = blanksAsMissed
        previewReplaces = replacesArchives
        guard !Self.isBlank(content) else {
            preview = nil
            return
        }
        let result = app.store.pastPreview(content, blanksAsMissed: blanksAsMissed, today: app.today,
                                           replacingArchives: replacesArchives)
        preview = result
        if result.document.isEmpty && result.document.skipped.isEmpty {
            problem = "Keine Zeilen gefunden. Die erste Zeile muss die Kopfzeile sein: \(PastWeekPrompt.header)"
        }
    }

    private func load(_ result: Result<URL, Error>) {
        let file = ImportFile.read(result)
        if let content = file.text {
            text = content
            runPreview(content)
        } else {
            problem = file.problem
        }
    }

    private func apply(_ preview: ImportPreview) {
        guard isCurrent(preview) else { return }
        let result = app.store.apply(preview)
        app.showImported(result)
        if let week = result.week { app.selectedWeek = week }
        dismiss()
    }
}

/// One week of the file: title and status (neu, ersetzt, ergänzt, unverändert), what comes in, and
/// the week's warnings underneath.
private struct PastWeekSummaryRow: View {
    let summary: ImportWeekSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(summary.title)
                    .font(.subheadline.weight(.semibold))
                if summary.isArchive {
                    // v9: only the week's value, day types and grades – no items, nothing missed.
                    ArchiveTag()
                }
                Spacer(minLength: 8)
                Text(summary.status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            if !summary.detail.isEmpty {
                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(summary.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        if summary.isReplaced { return .orange }
        if summary.hasChanges { return Brand.accent }
        return .secondary
    }
}
