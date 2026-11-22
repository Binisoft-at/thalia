import SwiftUI
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore

/// "Wochenplan importieren": the Sunday hand-off. Copy the planning prompt → ChatGPT writes the
/// week as CSV → paste it here → preview → import. Also: your own file, the template week, repeating
/// last week's plan (R92), export. Everything is read on the device; importing the same file again
/// changes nothing. A week that already has a plan is replaced – its old plan goes to the archive,
/// and the import can be undone (R49).
struct ImportView: View {
    let showPrompt: Bool
    /// Plan exactly this week (R56); nil: a sensible default.
    let week: WeekKey?
    /// Fill in the plan of this week for `week` (R92).
    let repeatFrom: WeekKey?
    /// Inside Settings: no own navigation stack, no close button (R24).
    let embedded: Bool
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var targetWeek: WeekKey
    @State private var text = ""
    /// The text the current preview was made from (R20).
    @State private var previewText = ""
    @State private var preview: ImportPreview?
    @State private var showFilePicker = false
    @State private var exportFile: CSVFile?
    @State private var exportName = "Thalia"
    @State private var promptCopied = false
    @State private var problem: String?
    @State private var didAppear = false
    @State private var confirmingReplace = false
    /// The week the prompt starts from, and whether it is still open (R56).
    @State private var planningSource: WeekKey?
    @State private var sourceIsOpen = false

    init(showPrompt: Bool, week: WeekKey? = nil, repeatFrom: WeekKey? = nil, embedded: Bool = false) {
        self.showPrompt = showPrompt
        self.week = week
        self.repeatFrom = repeatFrom
        self.embedded = embedded
        _targetWeek = State(initialValue: week ?? DayKey.today().week)
    }

    var body: some View {
        if embedded {
            form
        } else {
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
    }

    private var form: some View {
        Form {
            if showPrompt {
                planningSection
            }
            pasteSection
            if let preview {
                previewSection(preview)
            }
            if let problem {
                Section { Text(problem).foregroundStyle(.red) }
            }
            exportSection
        }
        .formStyle(.grouped)
        .navigationTitle("Wochenplan & Daten")
        .inlineNavigationTitle()
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            load(result)
        }
        .fileExporter(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
                      document: exportFile, contentType: .commaSeparatedText, defaultFilename: exportName) { result in
            if case .failure(let error) = result { problem = error.localizedDescription }
        }
        .onAppear(perform: appear)
        .onChange(of: targetWeek) {
            promptCopied = false
            refreshSource()
        }
        // The preview follows the text 0.6 s after the last keystroke (R20).
        .task(id: text) {
            guard text != previewText else { return }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            runPreview(text)
        }
    }

    private func appear() {
        guard !didAppear else { return }
        didAppear = true
        if week == nil { targetWeek = defaultWeek() }
        refreshSource()
        if let repeatFrom {
            text = app.store.repeatPlanCSV(from: repeatFrom, to: targetWeek)
            runPreview(text)
        }
        if let url = app.pendingImport {
            app.pendingImport = nil
            load(.success(url))
        }
    }

    private func refreshSource() {
        let store = app.store
        let source: WeekKey? = store.planningSourceWeek(for: targetWeek)
        planningSource = source
        if let source {
            sourceIsOpen = !store.weekContext(for: source, today: app.today).isClosed
        } else {
            sourceIsOpen = false
        }
    }

    /// Weekend: next week. During the week: this week if it has no plan yet, else the next one.
    private func defaultWeek() -> WeekKey {
        let today = app.today
        if today.weekday == .saturday || today.weekday == .sunday { return today.week.adding(weeks: 1) }
        return app.store.items(today.week).isEmpty ? today.week : today.week.adding(weeks: 1)
    }

    // MARK: Planning

    private var planningSection: some View {
        Section {
            Picker("Woche", selection: $targetWeek) {
                ForEach(weekChoices, id: \.self) { week in
                    Text("\(week.longLabel) (\(week.rangeLabel))").tag(week)
                }
            }
            if let source = planningSource, sourceIsOpen {
                Label("\(source.label) ist noch nicht abgeschlossen – erst danach kennt der Prompt verfehlte Ziele.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Button("Erst Woche abschließen", systemImage: "checkmark.seal") {
                    app.sheet = .closeWeek(source)
                }
            }
            Button {
                Clipboard.copy(app.store.planningPrompt(for: targetWeek, today: app.today))
                promptCopied = true
            } label: {
                Label(copyTitle, systemImage: copySymbol)
                    .frame(maxWidth: .infinity)
            }
            .thaliaPrimaryAction()
            ChatGPTLink()
        } header: {
            Text("1 · Prompt kopieren")
        } footer: {
            Text("Der Prompt enthält das genaue CSV-Format, deine zehn Jahresziele mit Kategorien, die Messwert-ids, den Plan und den Bericht der letzten Woche und deine Änderungen in der App. In ChatGPT einfügen, deine Sonntagsnachricht darunter – zurück kommt ein csv-Block.")
        }
    }

    private var copyTitle: String { promptCopied ? "Prompt kopiert" : "Planungs-Prompt kopieren" }
    private var copySymbol: String { promptCopied ? "checkmark" : "doc.on.doc" }

    /// Last week to three weeks ahead, plus the week asked for.
    private var weekChoices: [WeekKey] {
        var weeks: [WeekKey] = (-1...3).map { app.today.week.adding(weeks: $0) }
        if !weeks.contains(targetWeek) { weeks.append(targetWeek) }
        return weeks.sorted()
    }

    // MARK: Paste

    private var pasteSection: some View {
        Section {
            CSVInputRows(text: $text, placeholder: "Oder hier einfügen: ChatGPTs ganze Antwort oder nur die CSV") { pasted in
                text = pasted
                runPreview(pasted)
            } onFile: {
                showFilePicker = true
            }
            HStack {
                Button("Vorschau", systemImage: "eye") { runPreview(text) }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Menu {
                    if let source = planningSource {
                        Button("Wie \(source.label) wiederholen") {
                            text = app.store.repeatPlanCSV(from: source, to: targetWeek)
                            runPreview(text)
                        }
                    }
                    Button("Vorlagewoche \(targetWeek.label) (aus der Übergabe)") {
                        text = Template.weekCSV(targetWeek, includeStructure: app.store.liveGoals().isEmpty)
                        runPreview(text)
                    }
                    Button("Nur Jahresziele und Kategorien") {
                        text = Template.structureCSV()
                        runPreview(text)
                    }
                    Divider()
                    // v8: past weeks have their own window (copy a plan, ChatGPT for many weeks, paper score).
                    Button("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath") {
                        app.sheet = .importPast(nil)
                    }
                } label: {
                    Label("Vorlagen", systemImage: "doc.badge.plus")
                }
            }
        } header: {
            Text(showPrompt ? "2 · CSV einfügen" : "Importieren")
        } footer: {
            Text("Spalten: \(PlanCSV.header). Komma, Semikolon oder Tab; die Datei wird auf diesem Gerät gelesen.")
        }
    }

    // MARK: Preview

    private func previewSection(_ preview: ImportPreview) -> some View {
        Section {
            Text(preview.headline)
                .font(.headline)
            ForEach(preview.replacements, id: \.week) { replacement in
                Label(replacement.text, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            ForEach(otherLines(preview), id: \.self) { line in
                Text(line).font(.subheadline)
            }
            ImportPreviewDetails(preview: preview, warnings: preview.document.warnings)
            Button {
                if preview.replacements.isEmpty {
                    apply(preview)
                } else {
                    confirmingReplace = true
                }
            } label: {
                Label(importTitle(preview), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .thaliaPrimaryAction()
            // Only with a preview of exactly this text (R20).
            .disabled(!preview.hasChanges || previewText != text)
            .confirmationDialog(importTitle(preview) + "?", isPresented: $confirmingReplace, titleVisibility: .visible) {
                Button(importTitle(preview), role: .destructive) {
                    if let current = self.preview { apply(current) }
                }
            } message: {
                Text(replaceMessage(preview))
            }
        } header: {
            Text("Vorschau")
        } footer: {
            Text("Hat eine Woche schon einen Plan, wird sie ersetzt: der alte Plan kommt mit Markierungen und Werten ins Archiv (Einstellungen → Archiv).")
        }
    }

    private func importTitle(_ preview: ImportPreview) -> String { preview.importTitle }

    private func replaceMessage(_ preview: ImportPreview) -> String { preview.replaceMessage }

    private func otherLines(_ preview: ImportPreview) -> [String] { preview.otherLines }

    // MARK: Export

    private var exportSection: some View {
        Section {
            Button("Diese Woche als CSV", systemImage: "square.and.arrow.up") {
                let week = app.selectedWeek
                exportName = "Thalia \(week.string)"
                exportFile = CSVFile(text: app.store.exportCSV(weeks: [week]))
            }
            Button("Alles als CSV (Sicherung)", systemImage: "externaldrive") {
                exportName = "Thalia Sicherung \(app.today.string)"
                exportFile = CSVFile(text: app.store.exportCSV())
            }
            Button("Wochenbericht \(app.selectedWeek.label) kopieren", systemImage: "doc.on.doc") {
                Clipboard.copy(WeekReport.markdown(app.store.weekContext(for: app.selectedWeek, today: app.today).reportInput()))
                app.toasts.show("Wochenbericht kopiert", symbol: "doc.on.doc")
            }
        } header: {
            Text("Exportieren")
        } footer: {
            Text("Die CSV hat dasselbe Format wie der Import – bearbeiten und wieder importieren funktioniert, auch als Sicherung.")
        }
    }

    // MARK: Actions

    private func runPreview(_ content: String) {
        problem = nil
        previewText = content
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            preview = nil
            return
        }
        let result = app.store.preview(content)
        preview = result
        if result.document.isEmpty && result.document.skipped.isEmpty {
            problem = "Keine Zeilen gefunden. Die erste Zeile muss die Kopfzeile sein: \(PlanCSV.header)"
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
        guard previewText == text else { return }
        let result = app.store.apply(preview)
        app.showImported(result)
        if let week = result.week {
            app.selectedWeek = week
            if week.contains(app.today) { app.selectedDay = app.today }
        }
        dismiss()
    }
}

// MARK: Shared with the past-week import (v8, PastImport.swift)

/// Paste, file and the text field for a CSV.
struct CSVInputRows: View {
    @Binding var text: String
    let placeholder: String
    let onPaste: @MainActor (String) -> Void
    let onFile: @MainActor () -> Void

    var body: some View {
        HStack {
            PasteButton(payloadType: String.self) { strings in
                let pasted = strings.joined(separator: "\n")
                Task { @MainActor in
                    onPaste(pasted)
                }
            }
            .labelStyle(.titleAndIcon)
            Spacer()
            Button("Datei…", systemImage: "doc") { onFile() }
                .buttonStyle(.bordered)
        }
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(4...12)
            .font(.callout.monospaced())
    }
}

/// What to look at before importing: warnings, rows that couldn't be read, items a revised plan drops.
struct ImportPreviewDetails: View {
    let preview: ImportPreview
    /// The warnings listed here (the past-week preview shows a week's own warnings under that week).
    let warnings: [String]

    var body: some View {
        if !warnings.isEmpty {
            DisclosureGroup("Zum Prüfen (\(warnings.count))") {
                ForEach(warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        if !preview.document.skipped.isEmpty {
            DisclosureGroup("Nicht gelesen (\(preview.document.skipped.count))") {
                ForEach(preview.document.skipped, id: \.self) { reason in
                    Label(reason, systemImage: "xmark.octagon")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        if !preview.removedItems.isEmpty {
            DisclosureGroup("Entfallen (\(preview.removedItems.count))") {
                ForEach(preview.removedItems, id: \.self) { key in
                    Text(Self.code(key)).font(.caption)
                }
            }
        }
    }

    /// "2026-W45|1.1-01" → "1.1-01".
    private static func code(_ key: String) -> String {
        guard let last = key.split(separator: "|").last else { return key }
        return String(last)
    }
}

extension ImportPreview {
    /// "Importieren", or "KW47 ersetzen" / "KW47, KW48 ersetzen" when weeks are replaced (R49).
    var importTitle: String {
        if replacements.isEmpty { return "Importieren" }
        if replacements.count == 1, let only = replacements.first { return only.buttonTitle }
        return replacements.map(\.week.label).joined(separator: ", ") + " ersetzen"
    }

    /// "23 Markierungen und 9 Werte gehen ins Archiv. Das lässt sich danach widerrufen."
    /// v9, "Archivdaten dieser Wochen ersetzen": everything the weeks have goes, so the message says so.
    var replaceMessage: String {
        let marks: Int = replacements.reduce(0) { $0 + $1.marks }
        let values: Int = replacements.reduce(0) { $0 + $1.values }
        guard replacements.contains(where: \.isArchiveReplacement) else {
            return "\(Format.count(marks, "Markierung", "Markierungen")) und \(Format.count(values, "Wert", "Werte")) gehen ins Archiv. "
                + "Das lässt sich danach widerrufen."
        }
        let items: Int = replacements.reduce(0) { $0 + $1.items }
        let grades: Int = replacements.reduce(0) { $0 + $1.grades }
        var parts: [String] = []
        if items > 0 { parts.append(Format.count(items, "Punkt", "Punkte")) }
        if marks > 0 { parts.append(Format.count(marks, "Markierung", "Markierungen")) }
        if values > 0 { parts.append(Format.count(values, "Wert", "Werte")) }
        if grades > 0 { parts.append(Format.count(grades, "Note", "Noten")) }
        parts.append("Tagestypen, Abschlüsse und Wertungen laut Unterlagen")
        return "Alles, was die App für diese Wochen hat, kommt ins Archiv: " + parts.joined(separator: ", ") + ". "
            + "Die Datei ersetzt es. Das lässt sich danach widerrufen."
    }

    /// The preview's lines without the replacement sentences (they stand above in orange).
    var otherLines: [String] {
        let shown = Set(replacements.map(\.text))
        return lines.filter { !shown.contains($0) }
    }
}

/// A picked file as text: security-scoped, UTF-8, UTF-16 or Windows-1252.
enum ImportFile {
    /// The file's text, or the problem to show.
    static func read(_ result: Result<URL, Error>) -> (text: String?, problem: String?) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = CSV.decode(try Data(contentsOf: url))
                AppLog.info("Import file read: \(url.lastPathComponent)", category: "import")
                return (content, nil)
            } catch {
                AppLog.warning("Import file not readable", category: "import")
                return (nil, "\(url.lastPathComponent) ließ sich nicht lesen: \(error.localizedDescription)")
            }
        case .failure(let error):
            return (nil, error.localizedDescription)
        }
    }
}

extension AppModel {
    /// The toast after an import – with Undo when weeks were replaced (R49). v8: an import can set
    /// Krank/Urlaub (or close days), so the evening reminders are planned anew, also after Undo.
    func showImported(_ result: TrackerStore.ImportResult, message: String? = nil) {
        scheduleReminders()
        let text: String = message ?? "Importiert: \(result.summary)"
        guard !result.archives.isEmpty else {
            toasts.show(text, symbol: "square.and.arrow.down")
            return
        }
        let model = self
        toasts.show(text, symbol: "square.and.arrow.down") {
            model.store.undoImport(result)
            model.scheduleReminders()
        }
    }
}

/// A CSV for the system's save panel / Files.
struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// "ChatGPT öffnen" as a full-width row under the prompt button (plan and past-week import).
struct ChatGPTLink: View {
    var body: some View {
        Link(destination: URL(string: "https://chatgpt.com")!) {
            Label("ChatGPT öffnen", systemImage: "arrow.up.forward.app")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
