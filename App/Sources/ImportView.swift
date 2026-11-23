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
    /// Asks before importing: weeks are replaced (R49), iCloud is still loading (v11 P3.2), the CSV is for another
    /// week (v11 P3.15).
    @State private var confirmingImport = false
    /// The week the prompt starts from, and whether it is still open (R56).
    @State private var planningSource: WeekKey?
    @State private var sourceIsOpen = false
    /// v11 P3.10: a file too large for the text field (a year's backup) – read from here, shown as one line.
    @State private var file: LoadedFile?
    /// The file the current preview was made from (nil: the text).
    @State private var previewFile: UUID?
    /// v11 P3.10: the file is read and compared off the main thread ("Sicherung wird gelesen …").
    @State private var isReading = false
    @State private var readToken = UUID()
    /// v11 P3.10: the import runs – a blocking hint ("Sicherung wird eingespielt – bitte warten").
    @State private var isApplying = false
    /// v11 P3.2: this device's first iCloud sync isn't done and the file is a backup (records or closings).
    @State private var waitsForSync = false
    /// v11 P3.11: the backup is built off the main thread.
    @State private var isBackingUp = false
    /// v11 P3.13: the file to save is a full backup – saving it notes "Letzte Sicherung" (`backup.last`).
    @State private var exportIsBackup = false

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
        .disabled(isApplying)
        .overlay {
            if isApplying {
                ImportApplyingHint(text: applyingText)
            }
        }
        .navigationTitle("Wochenplan & Daten")
        .inlineNavigationTitle()
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
            load(result)
        }
        .fileExporter(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
                      document: exportFile, contentType: .commaSeparatedText, defaultFilename: exportName) { result in
            exported(result)
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
            Text("Der Prompt enthält das genaue CSV-Format, deine Jahresziele mit Kategorien, die Messwerte mit ihren IDs, den Plan und den Bericht der letzten Woche und deine Änderungen in der App. In ChatGPT einfügen, deine Sonntagsnachricht darunter – zurück kommt eine CSV.")
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
            if let file {
                // v11 P3.10: a large file stays out of the text field.
                LoadedFileRow(file: file) {
                    removeFile()
                }
            } else {
                CSVInputRows(text: $text, placeholder: "Oder hier einfügen: ChatGPTs ganze Antwort oder nur die CSV") { pasted in
                    text = pasted
                    runPreview(pasted)
                } onFile: {
                    showFilePicker = true
                }
            }
            if isReading {
                ImportReadingRow(text: readingText)
            }
            HStack {
                Button("Vorschau", systemImage: "eye") { runPreview(source, file: file) }
                    .disabled(file == nil && Self.isBlank(text))
                Spacer()
                Menu {
                    if let source = planningSource {
                        Button("Wie \(source.label) wiederholen") {
                            useText(app.store.repeatPlanCSV(from: source, to: targetWeek))
                        }
                    }
                    Button("Vorlagewoche \(targetWeek.label) (aus der Übergabe)") {
                        useText(Template.weekCSV(targetWeek, includeStructure: app.store.liveGoals().isEmpty))
                    }
                    Button("Nur Jahresziele und Kategorien") {
                        useText(Template.structureCSV())
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
            Text(previewHead(preview))
                .font(.headline)
            ForEach(preview.replacements, id: \.week) { replacement in
                Label(replacement.text, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            // v11: what to know before reading it in (P3.2, P3.15, P3.6, P3.4, P3.7) – orange.
            ForEach(cautionLines(preview), id: \.self) { line in
                Label(line, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
            ForEach(otherLines(preview), id: \.self) { line in
                Text(line).font(.subheadline)
            }
            ImportPreviewDetails(preview: preview, warnings: preview.document.warnings)
            Button {
                startImport(preview)
            } label: {
                Label(importTitle(preview), systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .thaliaPrimaryAction()
            // Only with a preview of exactly this text or file (R20), never while reading or importing.
            .disabled(!canImport(preview))
            .confirmationDialog(confirmTitle(preview), isPresented: $confirmingImport, titleVisibility: .visible) {
                Button(confirmButton(preview), role: confirmRole(preview)) {
                    if let current = self.preview { apply(current) }
                }
            } message: {
                Text(confirmMessage(preview))
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

    /// v11 P3.6: a backup names itself ("Sicherung vom 22.11.2026, 18:03 · Thalia 1.10.0 (58) · iPhone"), every other
    /// file its weeks.
    private func previewHead(_ preview: ImportPreview) -> String {
        if let backup = preview.backupHeadline { return backup }
        return preview.headline
    }

    /// v11 P3.2: "iCloud lädt noch …" – a backup (records or closings) while this device's first sync isn't done.
    static let syncWarning = "iCloud lädt noch deine Daten. Lies die Sicherung erst ein, wenn der Abgleich fertig ist – sonst zählen Power-Hours, Werte und Notizen doppelt."

    /// v11 P3.15: the week the CSV plans when it is exactly one and not the chosen one (only with the prompt).
    private func otherWeek(_ preview: ImportPreview) -> WeekKey? {
        guard showPrompt, preview.document.plannedWeeks.count == 1, let week = preview.document.plannedWeeks.first,
              week != targetWeek else { return nil }
        return week
    }

    /// "Die CSV ist für KW49 – gewählt ist KW48."
    private func otherWeekLine(_ week: WeekKey) -> String {
        "Die CSV ist für \(week.label) – gewählt ist \(targetWeek.label)."
    }

    /// The orange lines: iCloud still loading (P3.2), another week (P3.15), an old backup that changes the app or one of
    /// an older version (P3.6), what the import keeps against the file (P3.4, P3.7).
    private func cautionLines(_ preview: ImportPreview) -> [String] {
        var lines: [String] = []
        if waitsForSync { lines.append(Self.syncWarning) }
        if let week = otherWeek(preview) { lines.append(otherWeekLine(week)) }
        if let age = preview.backupAgeNotice() { lines.append(age) }
        if let older = preview.olderBackupNotice { lines.append(older) }
        lines.append(contentsOf: preview.notices)
        return lines
    }

    private func canImport(_ preview: ImportPreview) -> Bool {
        preview.hasChanges && isCurrent && !isReading && !isApplying
    }

    /// Whether the preview on screen was made from exactly what is there now (R20).
    private var isCurrent: Bool {
        if let file { return previewFile == file.id }
        return previewFile == nil && previewText == text
    }

    private func needsConfirmation(_ preview: ImportPreview) -> Bool {
        !preview.replacements.isEmpty || waitsForSync || otherWeek(preview) != nil
    }

    private func startImport(_ preview: ImportPreview) {
        if needsConfirmation(preview) {
            confirmingImport = true
        } else {
            apply(preview)
        }
    }

    /// "KW47 ersetzen?", "KW49 importieren?" or "Trotzdem einlesen?"
    private func confirmTitle(_ preview: ImportPreview) -> String {
        if !preview.replacements.isEmpty { return importTitle(preview) + "?" }
        if let week = otherWeek(preview) { return "\(week.label) importieren?" }
        return "Trotzdem einlesen?"
    }

    /// "KW47 ersetzen", "Trotzdem KW49 importieren" or "Trotzdem einlesen".
    private func confirmButton(_ preview: ImportPreview) -> String {
        if !preview.replacements.isEmpty { return importTitle(preview) }
        if let week = otherWeek(preview) { return "Trotzdem \(week.label) importieren" }
        return "Trotzdem einlesen"
    }

    private func confirmRole(_ preview: ImportPreview) -> ButtonRole? {
        preview.replacements.isEmpty ? nil : .destructive
    }

    private func confirmMessage(_ preview: ImportPreview) -> String {
        var parts: [String] = []
        if let week = otherWeek(preview) { parts.append(otherWeekLine(week) + " ChatGPT bitten, die Woche zu korrigieren.") }
        if waitsForSync { parts.append(Self.syncWarning) }
        if !preview.replacements.isEmpty { parts.append(replaceMessage(preview)) }
        return parts.joined(separator: "\n\n")
    }

    // MARK: Export

    private var exportSection: some View {
        Section {
            Button("Diese Woche als CSV", systemImage: "square.and.arrow.up") {
                let week = app.selectedWeek
                exportName = "Thalia \(week.string)"
                exportIsBackup = false
                exportFile = CSVFile(text: app.store.exportCSV(weeks: [week]))
            }
            // v11 P3.14: one name everywhere ("Sicherung erstellen…"); P3.11: built off the main thread.
            Button {
                backUp()
            } label: {
                if isBackingUp {
                    BackupProgressLabel()
                } else {
                    Label("Sicherung erstellen (alles als CSV)", systemImage: "externaldrive")
                }
            }
            .disabled(isBackingUp)
            Button("Wochenbericht \(app.selectedWeek.label) kopieren", systemImage: "doc.on.doc") {
                let store: TrackerStore = app.store
                // v10 (§1.2.5): with the block "Jahresziel-Ergebnisse".
                let input: WeekReportInput = store.weekContext(for: app.selectedWeek, today: app.today)
                    .reportInput(results: store.resultLines(today: app.today))
                Clipboard.copy(WeekReport.markdown(input))
                app.toasts.show("Wochenbericht kopiert", symbol: "doc.on.doc")
            }
        } header: {
            Text("Exportieren")
        } footer: {
            Text("Die CSV hat dasselbe Format wie der Import – bearbeiten und wieder importieren funktioniert. Eine Sicherung erst einspielen, wenn iCloud auf diesem Gerät abgeglichen hat (Einstellungen → iCloud & Daten).")
        }
    }

    // MARK: Actions

    /// v11 P3.10: files above this size (bytes) stay out of the text field.
    static let largeFile = 200_000

    /// What the preview reads: the loaded file or the text.
    private var source: String { file?.text ?? text }

    private static func isBlank(_ value: String) -> Bool {
        value.allSatisfy(\.isWhitespace)
    }

    /// "Sicherung wird gelesen …" for a large file or a backup, else "Wird gelesen …".
    private var readingText: String { file == nil ? "Wird gelesen …" : "Sicherung wird gelesen …" }

    /// "Sicherung wird eingespielt – bitte warten" (a backup or a large file), else "Wird importiert – bitte warten".
    private var applyingText: String {
        let isBackup: Bool = file != nil || preview?.document.backupInfo != nil
        return isBackup ? "Sicherung wird eingespielt – bitte warten" : "Wird importiert – bitte warten"
    }

    /// A text from the templates replaces a loaded file.
    private func useText(_ value: String) {
        file = nil
        text = value
        runPreview(value)
    }

    private func removeFile() {
        file = nil
        preview = nil
        previewFile = nil
        previewText = text
        problem = nil
        readToken = UUID()
        isReading = false
    }

    /// v11 P3.10, P3.12: the preview is read and compared off the main thread (`backgroundPreview`); a newer request
    /// wins. `loaded`: the file it comes from (nil: the text).
    private func runPreview(_ content: String, file loaded: LoadedFile? = nil) {
        problem = nil
        let token = UUID()
        readToken = token
        guard !Self.isBlank(content) else {
            preview = nil
            previewText = content
            previewFile = nil
            isReading = false
            return
        }
        isReading = true
        let store: TrackerStore = app.store
        let synced: Bool = app.mode.isSynced
        Task { @MainActor in
            let result = await store.backgroundPreview(content)
            guard readToken == token else { return }
            isReading = false
            previewText = loaded == nil ? content : ""
            previewFile = loaded?.id
            waitsForSync = Self.backupWaitsForSync(result, synced: synced)
            preview = result
            if result.document.isEmpty && result.document.skipped.isEmpty {
                problem = "Keine Zeilen gefunden. Die erste Zeile muss die Kopfzeile sein: \(PlanCSV.header)"
            }
        }
    }

    /// v11 P3.2: a backup – `record` rows or closings – while iCloud is on and this device's first sync isn't done.
    static func backupWaitsForSync(_ preview: ImportPreview, synced: Bool) -> Bool {
        let document = preview.document
        guard synced, !document.records.isEmpty || !document.closedWeeks.isEmpty || !document.closedDays.isEmpty else { return false }
        return !SyncProgress.firstImportDone
    }

    private func load(_ result: Result<URL, Error>) {
        let read = ImportFile.read(result)
        guard let content = read.text else {
            problem = read.problem
            return
        }
        let size: Int = content.utf8.count
        if size > Self.largeFile {
            var name = "Datei"
            if case .success(let url) = result { name = url.lastPathComponent }
            let loaded = LoadedFile(name: name, size: size, text: content)
            file = loaded
            text = ""
            previewText = ""
            runPreview(content, file: loaded)
        } else {
            file = nil
            text = content
            runPreview(content)
        }
    }

    /// v11: one save for the whole file, with a blocking hint drawn first (P3.10). Right before, the file is read
    /// again (P3.16 (1)): did a week get a plan meanwhile (another device), the preview shows it and asks
    /// "KW48 ersetzen?" instead of mixing the plans.
    private func apply(_ preview: ImportPreview) {
        guard isCurrent, !isApplying else { return }
        let content = source
        let store: TrackerStore = app.store
        let synced: Bool = app.mode.isSynced
        isApplying = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            let fresh = await store.backgroundPreview(content)
            if fresh.replacedWeeks != preview.replacedWeeks {
                AppLog.info("Import: the weeks to replace changed since the preview – asking again", category: "import")
                waitsForSync = Self.backupWaitsForSync(fresh, synced: synced)
                self.preview = fresh
                isApplying = false
                return
            }
            let result = store.apply(fresh)
            isApplying = false
            app.showImported(result)
            if let week = result.week {
                app.selectedWeek = week
                if week.contains(app.today) { app.selectedDay = app.today }
            }
            dismiss()
        }
    }

    /// v11 P3.11: "Sicherung erstellen (alles als CSV)" – built off the main thread, then the save panel.
    private func backUp() {
        guard !isBackingUp else { return }
        isBackingUp = true
        let store: TrackerStore = app.store
        let name: String = BackupWriter.exportName(today: app.today)
        Task { @MainActor in
            let content = await BackupWriter.exportText(store: store)
            isBackingUp = false
            exportName = name
            exportIsBackup = true
            exportFile = CSVFile(text: content)
        }
    }

    /// The save panel closed: a saved backup notes "Letzte Sicherung" for all devices (P3.13).
    private func exported(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            if exportIsBackup {
                BackupWriter.stamp(store: app.store)
                app.toasts.show(BackupWriter.savedToast, symbol: "externaldrive.badge.checkmark")
            }
        case .failure(let error):
            problem = error.localizedDescription
        }
        exportIsBackup = false
    }
}

/// v11 P3.10: a file read in whole but kept out of the text field.
struct LoadedFile: Identifiable {
    let id = UUID()
    let name: String
    /// Bytes of its text.
    let size: Int
    let text: String

    /// "Thalia Sicherung 2026-11-22.csv · 3,7 MB"
    var label: String { "\(name) · \(BackupWriter.sizeText(size))" }
}

/// The loaded file in one line, with "Datei entfernen".
struct LoadedFileRow: View {
    let file: LoadedFile
    let onRemove: @MainActor () -> Void

    var body: some View {
        HStack {
            Label(file.label, systemImage: "doc.text")
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Datei entfernen", systemImage: "xmark.circle", role: .destructive) { onRemove() }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Datei entfernen")
                .accessibilityLabel("Datei entfernen")
        }
    }
}

/// "Sicherung wird gelesen …" under the file or text.
struct ImportReadingRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// v11 P3.10: the blocking hint while an import is applied (one save; the file can be large).
struct ImportApplyingHint: View {
    let text: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            }
        }
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
    /// v11 P3.4 (d): "Widerrufen" also when the import added work, notes or reflections or changed a day.
    func showImported(_ result: TrackerStore.ImportResult, message: String? = nil) {
        scheduleReminders()
        var text: String = message ?? "Importiert: \(result.summary)"
        // v10 (Grundregel 2): closed weeks before the current segment kept their score – say so.
        if let hint = result.frozenToast { text += "\n" + hint }
        guard result.canUndo else {
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
