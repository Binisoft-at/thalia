import SwiftUI
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore

/// "Wochenplan importieren": the Sunday hand-off. Copy the planning prompt → ChatGPT writes the
/// week as CSV → paste it here → preview → import. Also: your own file, the template week, export.
/// Everything is read on the device; importing the same file again changes nothing.
struct ImportView: View {
    let showPrompt: Bool
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State private var targetWeek: WeekKey = DayKey.today().week
    @State private var text = ""
    @State private var preview: ImportPreview?
    @State private var showFilePicker = false
    @State private var exportFile: CSVFile?
    @State private var exportName = "Thalia"
    @State private var promptCopied = false
    @State private var problem: String?

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText, .plainText, .text]) { result in
                load(result)
            }
            .fileExporter(isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
                          document: exportFile, contentType: .commaSeparatedText, defaultFilename: exportName) { result in
                if case .failure(let error) = result { problem = error.localizedDescription }
            }
            .onAppear {
                targetWeek = defaultWeek()
                if let url = app.pendingImport {
                    app.pendingImport = nil
                    load(.success(url))
                }
            }
        }
        .sheetFrame(minWidth: 600, minHeight: 700)
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
                ForEach(-1...3, id: \.self) { offset in
                    let week = app.today.week.adding(weeks: offset)
                    Text("\(week.longLabel) (\(week.rangeLabel))").tag(week)
                }
            }
            Button {
                Clipboard.copy(planningPrompt())
                promptCopied = true
            } label: {
                Label(promptCopied ? "Prompt kopiert" : "Planungs-Prompt kopieren", systemImage: promptCopied ? "checkmark" : "doc.on.doc")
            }
            .primaryActionStyle()
        } header: {
            Text("1 · Mit ChatGPT planen")
        } footer: {
            Text("Der Prompt enthält das genaue CSV-Format, deine zehn Jahresziele mit Kategorien, die Messwert-ids, den letzten Wochenbericht und deine Änderungen in der App. In ChatGPT einfügen, deine Sonntagsnachricht darunter – zurück kommt ein csv-Block.")
        }
    }

    private func planningPrompt() -> String {
        let store = app.store
        let structure = store.weekContext(for: targetWeek, today: app.today)
        var measures = structure.measures.compactMap(\.record)
        var report: String?
        var changes: [PlanChangeRecord] = []
        if let last = store.latestPlannedWeek(before: targetWeek) {
            let previous = store.weekContext(for: last, today: app.today)
            if measures.isEmpty { measures = previous.measures.compactMap(\.record) }
            report = WeekReport.markdown(previous.reportInput())
            changes = previous.changes.compactMap(\.record)
        }
        let goals = structure.data.goals.isEmpty ? Template.goals : structure.data.goals
        let categories = structure.data.categories.isEmpty ? Template.categories : structure.data.categories
        AppLog.info("Planning prompt copied for \(targetWeek.string)", category: "import")
        return PlanPrompt.text(for: targetWeek, goals: goals, categories: categories, measures: measures, lastWeekReport: report,
                               changes: changes)
    }

    // MARK: Paste

    private var pasteSection: some View {
        Section {
            HStack {
                PasteButton(payloadType: String.self) { strings in
                    let pasted = strings.joined(separator: "\n")
                    Task { @MainActor in
                        text = pasted
                        runPreview(pasted)
                    }
                }
                .labelStyle(.titleAndIcon)
                Spacer()
                Button("Datei…", systemImage: "doc") { showFilePicker = true }
                    .buttonStyle(.bordered)
            }
            TextField("Oder hier einfügen: ChatGPTs ganze Antwort oder nur die CSV", text: $text, axis: .vertical)
                .lineLimit(4...12)
                .font(.callout.monospaced())
            HStack {
                Button("Vorschau", systemImage: "eye") { runPreview(text) }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Spacer()
                Menu {
                    Button("Vorlagewoche \(targetWeek.label) (aus der Übergabe)") {
                        text = Template.weekCSV(targetWeek, includeStructure: app.store.liveGoals().isEmpty)
                        runPreview(text)
                    }
                    Button("Nur Jahresziele und Kategorien") {
                        text = Template.structureCSV()
                        runPreview(text)
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
            ForEach(preview.lines, id: \.self) { line in
                Text(line).font(.subheadline)
            }
            if !preview.document.warnings.isEmpty {
                DisclosureGroup("Zum Prüfen (\(preview.document.warnings.count))") {
                    ForEach(preview.document.warnings, id: \.self) { warning in
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
                        Text(key.split(separator: "|").last.map(String.init) ?? key).font(.caption)
                    }
                }
            }
            Button {
                apply(preview)
            } label: {
                Label("Importieren", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .primaryActionStyle()
            .disabled(!preview.hasChanges)
        } header: {
            Text("Vorschau")
        } footer: {
            Text("Nichts ändert sich, bevor du Importieren tippst. Erneutes Importieren aktualisiert statt zu verdoppeln; Punkte, die ein überarbeiteter Plan nicht mehr hat, kommen in „Zuletzt gelöscht“.")
        }
    }

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
        let result = app.store.preview(content)
        preview = result
        if result.document.isEmpty && result.document.skipped.isEmpty {
            problem = "Keine Zeilen gefunden. Die erste Zeile muss die Kopfzeile sein: \(PlanCSV.header)"
        }
    }

    private func load(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = CSV.decode(try Data(contentsOf: url))
                text = content
                AppLog.info("Import file read: \(url.lastPathComponent)", category: "import")
                runPreview(content)
            } catch {
                problem = "\(url.lastPathComponent) ließ sich nicht lesen: \(error.localizedDescription)"
                AppLog.warning("Import file not readable", category: "import")
            }
        case .failure(let error):
            problem = error.localizedDescription
        }
    }

    private func apply(_ preview: ImportPreview) {
        let result = app.store.apply(preview)
        app.toasts.show("Importiert: \(result.summary)", symbol: "square.and.arrow.down")
        if let week = result.week {
            app.selectedWeek = week
            if week.contains(app.today) { app.selectedDay = app.today }
        }
        dismiss()
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
