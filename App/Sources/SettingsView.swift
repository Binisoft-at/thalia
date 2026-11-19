import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
#endif

/// Einstellungen: appearance, reminders, Apple Health, goal year and structure, help, Siri, iCloud &
/// data, import/export, trash, the app log, version. Import and trash open right here (R24).
struct SettingsView: View {
    /// The Mac's own settings window (not a sheet on the main window).
    var inSettingsWindow = false
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @AppStorage(TodaySettings.askConditionalsKey) private var askConditionals = false

    var body: some View {
        Form {
            Section("Darstellung") {
                GermanAppearancePicker()
                #if os(macOS)
                Toggle("Thalia in der Menüleiste", isOn: Binding(
                    get: { app.menuBarEnabled },
                    set: { app.menuBarEnabled = $0 }
                ))
                #endif
            }

            Section {
                Toggle("Bedingte Punkte zuerst abfragen", isOn: $askConditionals)
            } header: {
                Text("Erfassen")
            } footer: {
                Text("Statt jeden bedingten Punkt einzeln zu bewerten, fragt Thalia: „Gab es diese Situation heute?“ – nur was vorkam, markierst du, der Rest zählt automatisch als „Entfällt“.")
            }

            Section {
                NavigationLink {
                    RemindersSettingsView()
                } label: {
                    Label("Erinnerungen", systemImage: "bell.badge")
                }
                #if os(iOS)
                NavigationLink {
                    HealthSettingsView()
                } label: {
                    Label("Apple Health", systemImage: "heart.text.square")
                }
                #endif
                NavigationLink {
                    GoalYearSettingsView()
                } label: {
                    Label("Jahresziele und Zieljahr", systemImage: "target")
                }
            } header: {
                Text("Tracking")
            }

            Section {
                Button("Thalia-Tour", systemImage: "graduationcap") { startTour() }
                NavigationLink { ExplainerView(explainer: .scoring) } label: { Label("Wie wird gerechnet?", systemImage: "function") }
                NavigationLink { ExplainerView(explainer: .powerHours) } label: { Label("Power-Hours", systemImage: "bolt") }
                NavigationLink { ExplainerView(explainer: .marks) } label: { Label("Erledigt, Teilweise, Nicht erledigt, Entfällt", systemImage: "checklist") }
                NavigationLink { ExplainerView(explainer: .suggestions) } label: { Label("Was Thalia rechnet – und was du entscheidest", systemImage: "wand.and.stars") }
            } header: {
                Text("Hilfe")
            } footer: {
                Text("Die Tour läuft auf einer Übungsseite mit einer Beispielwoche – deine Einträge bleiben unberührt.")
            }

            Section {
                Text("„Hey Siri, Power-Hour in Thalia erfassen“ – Siri fragt nach Bereich, Menge und Wofür. „Ausgabe in Thalia“ fragt nach Betrag und Wofür.")
                    .font(.subheadline)
                Text("Kartenzahlungen automatisch: Kurzbefehle → Automation → Transaktion → Aktion „Ausgabe in Thalia“, Betrag = Betrag, Wofür = Händler. Dann landet jede Kartenzahlung von selbst in Thalia; von Hand bleiben nur Barzahlungen.")
                    .font(.subheadline)
            } header: {
                Text("Siri und Kurzbefehle")
            }

            ThaliaSyncSection()

            Section("Deine Daten") {
                NavigationLink {
                    ImportView(showPrompt: true, embedded: true)
                } label: {
                    Label("Wochenplan importieren & exportieren…", systemImage: "square.and.arrow.up.on.square")
                }
                NavigationLink {
                    PlanChangesView(week: app.today.week)
                } label: {
                    Label("Meine Änderungen am Plan", systemImage: "pencil.and.list.clipboard")
                }
                NavigationLink {
                    ArchiveView()
                } label: {
                    Label("Archiv ersetzter Wochen", systemImage: "archivebox")
                }
                NavigationLink {
                    TrashView(embedded: true)
                } label: {
                    Label("Zuletzt gelöscht", systemImage: "trash")
                }
            }

            Section {
                NavigationLink {
                    LogView(appName: AppInfo.name, mode: app.mode)
                } label: {
                    Label("App-Protokoll", systemImage: "doc.text.magnifyingglass")
                }
            } header: {
                Text("Diagnose")
            } footer: {
                Text("Wenn etwas nicht funktioniert: App-Protokoll → Protokoll kopieren, und in den Chat einfügen. Es enthält keine Einträge, nur Abläufe.")
            }

            Section("Über") {
                LabeledContent("Version", value: AppVersion.main.display)
                LabeledContent("Speicher", value: SyncGerman.storage(app.mode))
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        .toolbar {
            if !inSettingsWindow {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
    }

    /// Mac settings window: the tour runs in the main window, so that comes to the front first and
    /// the settings window closes (it is the key window right now) (R24).
    private func startTour() {
        #if os(macOS)
        if inSettingsWindow {
            let settings = NSApp.keyWindow
            MainWindow.show(openWindow)
            settings?.close()
        }
        #endif
        app.startTour()
    }
}

/// "iCloud & Daten" in German (R79), in place of the kit's English section.
struct ThaliaSyncSection: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Section {
            LabeledContent("iCloud-Abgleich") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                    Text(ThaliaSyncText.summary(app.sync.state))
                }
            }
            LabeledContent("Speicher", value: SyncGerman.storage(app.mode))
            if app.sync.state.mode.isSynced {
                LabeledContent("iCloud-Account", value: SyncGerman.account(app.sync.state.account))
            }
            if let error = app.sync.state.lastError {
                Text(SyncGerman.error(error, appName: AppInfo.name))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            NavigationLink {
                ThaliaDataLocationView()
            } label: {
                Label("Wo deine Daten liegen", systemImage: "lock.icloud")
            }
        } header: {
            Text("iCloud & Daten")
        } footer: {
            Text("Thalia hat keine Server und keine Konten. Deine Daten synchronisieren über dein privates iCloud zwischen iPhone, iPad, Mac und Apple Watch.")
        }
        .task { await app.sync.refreshAccount() }
        if app.sync.state.mode.isSynced {
            SyncDevicesSection()
        }
    }

    private var dotColor: Color {
        app.sync.state.isHealthy ? Color.green : Color.orange
    }
}

/// "Geräte im Abgleich": when each device last opened Thalia, as this device knows it from iCloud.
/// A recent time for another device means its data arrives here.
private struct SyncDevicesSection: View {
    @Environment(AppModel.self) private var app
    @State private var devices: [SyncDevice] = []

    var body: some View {
        Section {
            if devices.isEmpty {
                Text("Noch kein Gerät gemeldet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(rows) { row in
                    LabeledContent {
                        Text(SyncDevice.seenText(row.device.seenAt))
                            .monospacedDigit()
                    } label: {
                        Label(row.label, systemImage: symbol(row.device.kind))
                    }
                }
            }
        } header: {
            Text("Geräte im Abgleich")
        } footer: {
            Text("Jedes Gerät meldet sich, wenn Thalia geöffnet wird (höchstens alle 10 Minuten). Steht hier bei einem anderen Gerät eine aktuelle Zeit, kommen seine Daten an. Die Apple Watch meldet sich, wenn ihre Thalia-App offen war.")
        }
        .task(id: app.syncTick) { devices = app.store.syncDevices() }
    }

    private struct Row: Identifiable {
        let device: SyncDevice
        let label: String
        var id: String { device.installID }
    }

    private var rows: [Row] {
        let me: String = TrackerStore.installID
        return SyncDevice.labelled(devices).map { entry in
            let label: String = entry.device.installID == me ? "\(entry.label) (dieses Gerät)" : entry.label
            return Row(device: entry.device, label: label)
        }
    }

    private func symbol(_ kind: String) -> String {
        switch kind {
        case "Mac": return "laptopcomputer"
        case "iPad": return "ipad"
        case "Apple Watch": return "applewatch"
        default: return "iphone"
        }
    }
}

/// The sync wording with German relative dates ("vor 5 Minuten").
enum ThaliaSyncText {
    static func relative(_ date: Date) -> String {
        Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide, locale: Locale(identifier: "de_DE")).format(date)
    }

    static func summary(_ state: SyncState) -> String {
        SyncGerman.summary(state) { relative($0) }
    }
}

/// "Wo deine Daten liegen" – Thalia's own page instead of the kit's English one (R79).
struct ThaliaDataLocationView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Form {
            ForEach(ThaliaDataFacts.sections) { section in
                Section(section.title) {
                    ForEach(section.facts) { fact in
                        ThaliaFactRow(fact: fact)
                    }
                }
            }
            Section("Status auf diesem Gerät") {
                LabeledContent("Synchronisation", value: ThaliaSyncText.summary(app.sync.state))
                LabeledContent("Speicher", value: SyncGerman.storage(app.mode))
                if let container = app.sync.state.mode.containerID {
                    LabeledContent("iCloud-Container", value: container)
                }
                if let reason = SyncGerman.reason(app.mode) {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = app.sync.state.lastError {
                    Text(SyncGerman.error(error, appName: AppInfo.name))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Wo deine Daten liegen")
        .inlineNavigationTitle()
        .task { await app.sync.refreshAccount() }
    }
}

private struct ThaliaFactRow: View {
    let fact: DataFact

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: fact.symbol)
                .font(.title3)
                .foregroundStyle(Brand.accent)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(fact.title)
                    .font(.headline)
                Text(fact.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// System / Hell / Dunkel (the kit's picker is English).
struct GermanAppearancePicker: View {
    @AppStorage(Appearance.storageKey) private var raw = Appearance.system.rawValue

    var body: some View {
        Picker("Erscheinungsbild", selection: $raw) {
            Text("System").tag(Appearance.system.rawValue)
            Text("Hell").tag(Appearance.light.rawValue)
            Text("Dunkel").tag(Appearance.dark.rawValue)
        }
    }
}

/// "Wo deine Daten liegen", in German and with Thalia's specifics (Health stays on the device).
enum ThaliaDataFacts {
    static let sections: [DataSection] = [
        DataSection("Deine Wochenpläne und Einträge", [
            DataFact("iphone", "Auf deinen Geräten", "Thalia speichert alles in einer Datenbank in der App auf jedem Gerät – es funktioniert auch offline."),
            DataFact("icloud.fill", "Über dein iCloud synchronisiert", "Änderungen laufen über deine private iCloud-Datenbank (Apple CloudKit). Nur dein Apple-Account kann sie lesen – nicht Binisoft, niemand sonst."),
            DataFact("server.rack", "Kein Thalia-Server", "Kein Server, kein Login, keine Analyse. iCloud ist das einzige „Backend“."),
            DataFact("eurosign.circle", "Kostenlos", "Die Synchronisation kostet nichts; sie braucht ein wenig iCloud-Speicher."),
        ]),
        DataSection("Apple Health", [
            DataFact("heart.text.square", "Nur Vorschläge", "Werte aus Apple Health erscheinen als Vorschlag. Sie zählen erst, wenn du sie übernimmst – oder du trägst deinen eigenen Wert ein."),
            DataFact("lock.iphone", "Bleibt auf dem Gerät", "Übernommene Health-Werte werden nie in iCloud gespeichert (App-Store-Richtlinie 5.1.3). Was synchronisiert, ist deine eigene Bewertung."),
        ]),
        DataSection("Importe und Übungsdaten", [
            DataFact("doc.text.magnifyingglass", "Auf dem Gerät gelesen", "CSV-Dateien und eingefügte Pläne werden auf dem Gerät gelesen. Nichts wird hochgeladen außer in dein eigenes iCloud."),
            DataFact("graduationcap", "Tour und Demo", "Die Übungsseite der Tour und die Demo-Daten liegen in einem eigenen Speicher, der nie synchronisiert."),
        ]),
        DataSection("Sichern und Löschen", [
            DataFact("square.and.arrow.up", "Export", "Einstellungen → Wochenplan importieren & exportieren gibt dir eine CSV mit allem – im Importformat."),
            DataFact("trash", "Löschen", "Gelöschtes bleibt 30 Tage in „Zuletzt gelöscht“. Ganz löschen: App auf allen Geräten löschen, dann in Einstellungen → dein Name → iCloud → Speicher verwalten die Daten von Thalia entfernen."),
        ]),
    ]
}

// MARK: Reminders

struct RemindersSettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var settings = ReminderScheduler.load()
    @State private var status = ""

    var body: some View {
        Form {
            Section {
                Toggle("Morgenstart", isOn: $settings.morning)
                if settings.morning {
                    DatePicker("Uhrzeit", selection: minutesBinding(\.morningMinutes), displayedComponents: .hourAndMinute)
                        .thaliaDateLocale()
                    HStack(spacing: 4) {
                        ForEach(Weekday.allCases, id: \.self) { day in
                            let on = DayMask(rawValue: settings.morningDays).contains(day)
                            Button(day.short) {
                                settings.morningDays ^= day.bit
                            }
                            .buttonStyle(.bordered)
                            .tint(on ? Brand.accent : .secondary)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } footer: {
                Text("„Kurz in Thalia schauen: was heute ansteht – und ob gestern noch offen ist.“")
            }
            Section {
                Toggle("Tagesabschluss", isOn: $settings.evening)
                if settings.evening {
                    DatePicker("Uhrzeit", selection: minutesBinding(\.eveningMinutes), displayedComponents: .hourAndMinute)
                        .thaliaDateLocale()
                }
            } footer: {
                Text("Abends Belege prüfen, Fehlendes ergänzen, reflektieren. Ist der Tag schon abgeschlossen, kommt keine Erinnerung; „In 30 Min.“ erinnert später noch einmal.")
            }
            Section {
                Toggle("Wochenabschluss", isOn: $settings.weekly)
                if settings.weekly {
                    Picker("Tag", selection: $settings.weeklyDay) {
                        ForEach(Weekday.allCases, id: \.self) { day in Text(day.name).tag(day.rawValue) }
                    }
                    DatePicker("Uhrzeit", selection: minutesBinding(\.weeklyMinutes), displayedComponents: .hourAndMinute)
                        .thaliaDateLocale()
                }
            } footer: {
                #if os(macOS)
                Text("Am Mac standardmäßig aus – das iPhone erinnert dich schon.")
                #endif
            }
            if !status.isEmpty {
                Section { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Erinnerungen")
        .onChange(of: settings) { _, new in
            ReminderScheduler.save(new)
            // Switching a reminder on here may ask for permission (R80).
            Task { status = await ReminderScheduler.apply(new, authorize: true, isClosed: { app.isDayClosed($0) }) }
        }
        .task {
            status = await ReminderScheduler.apply(settings, authorize: false, isClosed: { app.isDayClosed($0) })
        }
    }

    private func minutesBinding(_ path: WritableKeyPath<ReminderSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = settings[keyPath: path] / 60
                components.minute = settings[keyPath: path] % 60
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                settings[keyPath: path] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}

#if os(iOS)
struct HealthSettingsView: View {
    @Environment(HealthService.self) private var health

    var body: some View {
        @Bindable var health = health
        Form {
            Section {
                Toggle("Vorschläge aus Apple Health", isOn: $health.isEnabled)
                if health.isEnabled {
                    Button("Zugriff erlauben…", systemImage: "heart.text.square") {
                        Task { await health.requestAccess() }
                    }
                    if let message = health.message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Schlaf, Einschlafzeit, Gewicht, Protein, Kalorien, Wasser, Training, Achtsamkeit und Schritte erscheinen als Vorschlag neben dem passenden Messwert. Nichts wird automatisch eingetragen; dein eigener Wert hat immer Vorrang.")
            }
            Section("Welche Messwerte") {
                ForEach(HealthKind.allCases, id: \.self) { kind in
                    LabeledContent(kind.label, value: "health:\(kind.rawValue)")
                        .font(.subheadline)
                }
            }
            Section {
                Text("Übernommene Werte bleiben auf diesem iPhone (App-Store-Richtlinie 5.1.3: keine Gesundheitsdaten in iCloud). Andere Geräte sehen deine Bewertung, nicht den Health-Wert.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Apple Health")
    }
}
#endif

// MARK: Goal year and structure

struct GoalYearSettingsView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<AnnualGoal> { $0.deletedAt == nil }) private var goals: [AnnualGoal]
    @Query(filter: #Predicate<TrackCategory> { $0.deletedAt == nil }) private var categories: [TrackCategory]
    @State private var period = GoalPeriod.foundationYear
    @State private var loaded = false
    @State private var editingCategory: TrackCategory?

    var body: some View {
        Form {
            Section {
                DatePicker("Beginn", selection: dayBinding(\.start), displayedComponents: .date)
                    .thaliaDateLocale()
                DatePicker("Ende", selection: dayBinding(\.end), displayedComponents: .date)
                    .thaliaDateLocale()
                Picker("Zielüberprüfung", selection: $period.reviewWeek) {
                    ForEach(0..<60, id: \.self) { offset in
                        let week = period.start.week.adding(weeks: offset)
                        Text("\(week.longLabel) (\(week.rangeLabel))").tag(week)
                    }
                }
                TextField("Motto", text: $period.motto, axis: .vertical)
            } header: {
                Text("Zieljahr")
            } footer: {
                Text("Bis zur Zielüberprüfung werden Ziele nicht automatisch schwerer – auch nach einer guten Woche nicht.")
            }

            Section {
                if goals.isEmpty {
                    Button("Meine Struktur einrichten (10 Ziele, 18 Kategorien)", systemImage: "plus") { app.store.seedStructure() }
                }
                ForEach(sortedGoals) { goal in
                    NavigationLink {
                        GoalDetailView(goalKey: goal.key)
                    } label: {
                        LabeledContent("\(goal.key) \(goal.title)", value: "\(categories.filter { $0.goalKey == goal.key && $0.deletedAt == nil }.count)")
                    }
                }
            } header: {
                Text("Jahresziele")
            } footer: {
                Text("Die Zahl rechts sind die Kategorien darunter. Ein Ziel mit mehr Kategorien wiegt nicht mehr.")
            }

            Section("Kategorien") {
                ForEach(sortedCategories) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        HStack {
                            KeyBadge(key: category.key)
                            Text(category.title).foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Jahresziele")
        .onAppear {
            guard !loaded else { return }
            period = app.store.goalPeriod
            loaded = true
        }
        .onChange(of: period) { _, new in
            if loaded { app.store.setGoalPeriod(new) }
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditor(category: category).environment(app)
        }
    }

    private var sortedGoals: [AnnualGoal] {
        Array(goals.latest(by: \.key, modified: \.modifiedAt).values).sorted { (Int($0.key) ?? 99) < (Int($1.key) ?? 99) }
    }

    private var sortedCategories: [TrackCategory] {
        Array(categories.latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
    }

    private func dayBinding(_ path: WritableKeyPath<GoalPeriod, DayKey>) -> Binding<Date> {
        Binding(
            get: { period[keyPath: path].startDate() },
            set: { period[keyPath: path] = DayKey(date: $0) }
        )
    }
}

struct CategoryEditor: View {
    let category: TrackCategory
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var details = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Titel", text: $title)
                TextField("Notiz", text: $details, axis: .vertical)
            }
            .formStyle(.grouped)
            .navigationTitle("Kategorie \(category.key)")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        app.store.update(category, title: title, details: details)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                title = category.title
                details = category.details
            }
        }
        .thaliaSheetFrame(width: 420, height: 380)
    }
}

// MARK: Trash

/// Two lines of a row in "Zuletzt gelöscht".
struct TrashLine {
    let title: String
    let subtitle: String
}

/// "Zuletzt gelöscht": readable rows, newest first; deleting for good always asks first and a full
/// swipe never deletes (R19). Embedded in Settings without its own stack and close button (R24).
struct TrashView: View {
    let embedded: Bool
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var trash = TrackerStore.Trash()
    @State private var categoryTitles: [String: String] = [:]
    @State private var entryLines: [UUID: TrashLine] = [:]
    @State private var pendingPurge: TrackerStore.Trash?
    @State private var purgesAll = false

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        if embedded {
            trashList
        } else {
            NavigationStack {
                trashList
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SheetCloseButton { dismiss() }
                        }
                    }
            }
            .thaliaSheetFrame(width: 480, height: 640)
        }
    }

    private var trashList: some View {
        List {
            if !trash.work.isEmpty {
                Section("Power-Hours") {
                    ForEach(trash.work) { block in
                        row(workLine(block), deletedAt: block.deletedAt, purge: TrackerStore.Trash(work: [block])) {
                            app.store.restore([block])
                        }
                    }
                }
            }
            if !trash.items.isEmpty {
                Section("Punkte") {
                    ForEach(trash.items) { item in
                        row(planLine(item.title, week: item.weekKey, category: item.categoryKey), deletedAt: item.deletedAt,
                            purge: TrackerStore.Trash(items: [item])) {
                            app.store.restore([item])
                        }
                    }
                }
            }
            if !trash.measures.isEmpty {
                Section("Messwerte") {
                    ForEach(trash.measures) { measure in
                        row(planLine(measure.title, week: measure.weekKey, category: measure.categoryKey), deletedAt: measure.deletedAt,
                            purge: TrackerStore.Trash(measures: [measure])) {
                            app.store.restore([measure])
                        }
                    }
                }
            }
            if !trash.notes.isEmpty {
                Section("Notizen") {
                    ForEach(trash.notes) { note in
                        row(TrashLine(title: note.text, subtitle: Self.dayLabel(note.dayKey)), deletedAt: note.deletedAt,
                            purge: TrackerStore.Trash(notes: [note])) {
                            app.store.restore([note])
                        }
                    }
                }
            }
            if !trash.entries.isEmpty {
                Section("Messwert-Einträge") {
                    ForEach(trash.entries) { entry in
                        row(entryLine(entry), deletedAt: entry.deletedAt, purge: TrackerStore.Trash(entries: [entry])) {
                            app.store.restore([entry])
                        }
                    }
                }
            }
        }
        .overlay {
            if trash.isEmpty {
                ContentUnavailableView("Nichts gelöscht", systemImage: "trash",
                                       description: Text("Gelöschtes bleibt hier 30 Tage, dann ist es endgültig weg."))
            }
        }
        .navigationTitle("Zuletzt gelöscht")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button("Leeren", role: .destructive) {
                    purgesAll = true
                    pendingPurge = trash
                }
                .disabled(trash.isEmpty)
            }
        }
        .confirmationDialog(purgeTitle, isPresented: purgeIsPresented, titleVisibility: .visible, presenting: pendingPurge) { pending in
            Button(purgeButtonTitle, role: .destructive) {
                app.store.purge(pending)
                pendingPurge = nil
                reload()
            }
        } message: { _ in
            Text("Das lässt sich nicht widerrufen.")
        }
        .onAppear(perform: reload)
    }

    // MARK: Asking before deleting for good

    private var purgeTitle: String { purgesAll ? "Papierkorb leeren?" : "Endgültig löschen?" }
    private var purgeButtonTitle: String { purgesAll ? "Leeren" : "Endgültig löschen" }

    private var purgeIsPresented: Binding<Bool> {
        Binding(get: { pendingPurge != nil }, set: { if !$0 { pendingPurge = nil } })
    }

    private func askPurge(_ selection: TrackerStore.Trash) {
        purgesAll = false
        pendingPurge = selection
    }

    // MARK: Rows

    private func row(_ line: TrashLine, deletedAt: Date?, purge: TrackerStore.Trash, restore: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(line.title)
                .lineLimit(2)
            Text(Self.subtitle(line.subtitle, deletedAt: deletedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Wiederherstellen", systemImage: "arrow.uturn.backward") {
                restore()
                reload()
            }
            .tint(Color.accentFill)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No destructive role here: that would remove the row before the question is answered.
            Button("Endgültig löschen", systemImage: "trash") {
                askPurge(purge)
            }
            .tint(.red)
        }
        .contextMenu {
            Button("Wiederherstellen", systemImage: "arrow.uturn.backward") {
                restore()
                reload()
            }
            Button("Endgültig löschen", systemImage: "trash", role: .destructive) {
                askPurge(purge)
            }
        }
    }

    private static func subtitle(_ text: String, deletedAt: Date?) -> String {
        var parts: [String] = []
        if !text.isEmpty { parts.append(text) }
        if let deletedAt { parts.append("noch \(TrashPolicy().daysLeft(deletedAt: deletedAt)) Tage") }
        return parts.joined(separator: " · ")
    }

    /// "Mittagessen vorbereiten" / "Mo, 16. Nov. · Thema A · 2 PH"
    private func workLine(_ block: WorkBlock) -> TrashLine {
        let title: String = block.task.isEmpty ? "Power-Hours" : block.task
        let area: String = categoryTitles[block.categoryKey] ?? block.categoryKey
        let parts: [String] = [Self.dayLabel(block.dayKey), area, Format.powerHours(block.hours)]
        return TrashLine(title: title, subtitle: parts.filter { !$0.isEmpty }.joined(separator: " · "))
    }

    /// Items and measurements: "KW47 · 1.1 Kategorie"
    private func planLine(_ title: String, week: String, category: String) -> TrashLine {
        let weekLabel: String = WeekKey(week)?.label ?? week
        let categoryTitle: String = categoryTitles[category] ?? ""
        let area: String = categoryTitle.isEmpty ? category : "\(category) \(categoryTitle)"
        return TrashLine(title: title, subtitle: "\(weekLabel) · \(area)")
    }

    private func entryLine(_ entry: MeasureEntry) -> TrashLine {
        entryLines[entry.uuid] ?? TrashLine(title: entry.code, subtitle: Self.dayLabel(entry.dayKey))
    }

    private static func dayLabel(_ key: String) -> String {
        DayKey(key)?.shortLabel ?? key
    }

    /// "Ausgaben: 12,50 € · Mittagessen" (spending) or "Wasser: 0,5 l · Mo, 16. Nov.".
    private static func entryLine(_ entry: MeasureEntry, measure: MeasureDefinition?) -> TrashLine {
        let name: String = measure?.title ?? entry.code
        let day: String = dayLabel(entry.dayKey)
        if measure?.record?.isExpense ?? false {
            let amount: String = Format.euro(entry.value ?? 0)
            let what: String = entry.note.trimmingCharacters(in: .whitespacesAndNewlines)
            let title: String = what.isEmpty ? "\(name): \(amount)" : "\(name): \(amount) · \(what)"
            return TrashLine(title: title, subtitle: day)
        }
        let unit: String = measure?.unit ?? ""
        let value: String = entry.value.map { Format.measure($0, unit: unit) } ?? entry.text
        return TrashLine(title: "\(name): \(value) · \(day)", subtitle: "")
    }

    private func reload() {
        let store = app.store
        let current = store.trash()
        var titles: [String: String] = [:]
        for category in store.liveCategories() { titles[category.key] = category.title }
        var measuresByWeek: [WeekKey: [MeasureDefinition]] = [:]
        var lines: [UUID: TrashLine] = [:]
        for entry in current.entries {
            var measure: MeasureDefinition?
            if let day = DayKey(entry.dayKey) {
                if measuresByWeek[day.week] == nil { measuresByWeek[day.week] = store.measures(day.week) }
                measure = measuresByWeek[day.week]?.first { $0.code == entry.code }
            }
            lines[entry.uuid] = Self.entryLine(entry, measure: measure)
        }
        categoryTitles = titles
        entryLines = lines
        trash = current
    }
}

/// Weeks replaced by an import (U15): hidden from every screen and statistic, restorable.
struct ArchiveView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \WeekArchive.archivedAt, order: .reverse) private var archives: [WeekArchive]
    @State private var restoring: WeekArchive?
    @State private var deleting: WeekArchive?

    var body: some View {
        List {
            ForEach(archives) { archive in
                VStack(alignment: .leading, spacing: 3) {
                    Text((archive.week?.label ?? archive.weekKey) + (archive.title.isEmpty ? "" : " · \(archive.title)"))
                        .font(.body.weight(.medium))
                    Text("\(archive.itemCount) Punkte · \(archive.markCount) Markierungen · archiviert \(archive.archivedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { restoring = archive }
                        .tint(Color.accentFill)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Asks first (R19); no destructive role, so the row stays until the answer.
                    Button("Löschen", systemImage: "trash") { deleting = archive }
                        .tint(.red)
                }
                .contextMenu {
                    Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { restoring = archive }
                    Button("Endgültig löschen", systemImage: "trash", role: .destructive) { deleting = archive }
                }
            }
        }
        .confirmationDialog("Endgültig löschen?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { archive in
            Button("Löschen", role: .destructive) {
                app.store.delete(archive)
                deleting = nil
            }
        } message: { _ in
            Text("Das lässt sich nicht widerrufen.")
        }
        .overlay {
            if archives.isEmpty {
                ContentUnavailableView("Kein Archiv", systemImage: "archivebox",
                                       description: Text("Importierst du eine Woche neu, landet der alte Plan mit seinen Markierungen und Werten hier – wiederherstellbar."))
            }
        }
        .confirmationDialog("Woche wiederherstellen?", isPresented: Binding(get: { restoring != nil }, set: { if !$0 { restoring = nil } }),
                            titleVisibility: .visible, presenting: restoring) { archive in
            Button("Wiederherstellen") {
                let result = app.store.restore(archive)
                app.toasts.show("\(archive.week?.label ?? "Woche") wiederhergestellt · \(result.summary)", symbol: "arrow.uturn.backward")
            }
        } message: { _ in
            Text("Der aktuelle Plan dieser Woche kommt dafür ins Archiv.")
        }
        .navigationTitle("Archiv")
    }
}

/// What was changed in the app this week – the next planning prompt lists it (U14).
struct PlanChangesView: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    @Query private var changes: [PlanChange]

    init(week: WeekKey) {
        self.week = week
        let key = week.string
        _changes = Query(filter: #Predicate<PlanChange> { $0.weekKey == key }, sort: \PlanChange.createdAt)
    }

    var body: some View {
        List {
            Section {
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(change.targetRaw) \(change.kindRaw): \(change.title)")
                            .font(.body.weight(.medium))
                        if !change.detail.isEmpty {
                            Text(change.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Toggle("Auch in den nächsten Wochen", isOn: Binding(get: { change.carryOver },
                                                                            set: { app.store.setCarryOver(change, $0) }))
                            .font(.caption)
                    }
                }
            } footer: {
                Text("Der Planungs-Prompt für \(week.adding(weeks: 1).label) nennt jede Änderung – mit dem Hinweis, ob sie dauerhaft übernommen werden soll.")
            }
        }
        .overlay {
            if changes.isEmpty {
                ContentUnavailableView("Keine Änderungen", systemImage: "pencil.and.list.clipboard",
                                       description: Text("Punkte und Messwerte, die du in \(week.label) hinzufügst, änderst oder löschst, erscheinen hier."))
            }
        }
        .navigationTitle("Änderungen \(week.label)")
    }
}
