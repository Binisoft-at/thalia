import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// Einstellungen: appearance, reminders, Apple Health, goal year and structure, help, iCloud &
/// data, import/export, trash, the app log, version.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @AppStorage(TodaySettings.askConditionalsKey) private var askConditionals = false

    var body: some View {
        Form {
            Section("Darstellung") {
                GermanAppearancePicker()
            }

            Section {
                Toggle("Bedingte Punkte zuerst abfragen", isOn: $askConditionals)
            } header: {
                Text("Erfassen")
            } footer: {
                Text("Statt jeden bedingten Punkt einzeln zu bewerten, fragt Thalia: „Gab es diese Situation heute?“ – nur was vorkam, trägst du ein, der Rest wird automatisch N/A.")
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
                Button("Thalia-Tour", systemImage: "graduationcap") { app.startTour() }
                NavigationLink { ExplainerView(explainer: .scoring) } label: { Label("Wie wird gerechnet?", systemImage: "function") }
                NavigationLink { ExplainerView(explainer: .powerHours) } label: { Label("Power-Hours", systemImage: "bolt") }
                NavigationLink { ExplainerView(explainer: .marks) } label: { Label("✓ ½ ✗ N/A und leer", systemImage: "checklist") }
                NavigationLink { ExplainerView(explainer: .suggestions) } label: { Label("Was Thalia rechnet – und was du entscheidest", systemImage: "wand.and.stars") }
            } header: {
                Text("Hilfe")
            } footer: {
                Text("Die Tour läuft auf einer Übungsseite mit einer Beispielwoche – deine Einträge bleiben unberührt.")
            }

            SyncStatusSection(
                monitor: app.sync,
                footer: "Thalia hat keine Server und keine Konten. Deine Daten synchronisieren über dein privates iCloud zwischen iPhone, iPad, Mac und Apple Watch."
            ) {
                DataLocationView(sections: ThaliaDataFacts.sections, monitor: app.sync)
            }

            Section("Deine Daten") {
                Button("Wochenplan importieren & exportieren…", systemImage: "square.and.arrow.up.on.square") { app.sheet = .importPlan(prompt: true) }
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
                Button("Zuletzt gelöscht", systemImage: "trash") { app.sheet = .trash }
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
                LabeledContent("Speicher", value: app.mode.title)
                LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? "–")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Einstellungen")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Fertig") { dismiss() }
            }
        }
        #endif
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
    @State private var settings = ReminderScheduler.load()
    @State private var status = ""

    var body: some View {
        Form {
            Section {
                Toggle("Morgenstart", isOn: $settings.morning)
                if settings.morning {
                    DatePicker("Uhrzeit", selection: minutesBinding(\.morningMinutes), displayedComponents: .hourAndMinute)
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
                Text("„Der erste geplante Block wartet.“ – pünktlich starten.")
            }
            Section {
                Toggle("Tagesabschluss", isOn: $settings.evening)
                if settings.evening {
                    DatePicker("Uhrzeit", selection: minutesBinding(\.eveningMinutes), displayedComponents: .hourAndMinute)
                }
            } footer: {
                Text("Abends Belege prüfen, Fehlendes ergänzen, reflektieren.")
            }
            Section {
                Toggle("Wochenabschluss", isOn: $settings.weekly)
                if settings.weekly {
                    Picker("Tag", selection: $settings.weeklyDay) {
                        ForEach(Weekday.allCases, id: \.self) { day in Text(day.name).tag(day.rawValue) }
                    }
                    DatePicker("Uhrzeit", selection: minutesBinding(\.weeklyMinutes), displayedComponents: .hourAndMinute)
                }
            }
            if !status.isEmpty {
                Section { Text(status).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Erinnerungen")
        .onChange(of: settings) { _, new in
            ReminderScheduler.save(new)
            Task { status = await ReminderScheduler.apply(new) }
        }
        .task { status = await ReminderScheduler.apply(settings) }
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
                DatePicker("Ende", selection: dayBinding(\.end), displayedComponents: .date)
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
                    Button("Meine Struktur anlegen (10 Ziele, 18 Kategorien)", systemImage: "plus") { app.store.seedStructure() }
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
        .sheetFrame(minWidth: 420, minHeight: 260)
    }
}

// MARK: Trash

struct TrashView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var trash = TrackerStore.Trash()

    var body: some View {
        NavigationStack {
            List {
                if !trash.work.isEmpty {
                    Section("Power-Hours") {
                        ForEach(trash.work) { block in
                            row(title: block.task.isEmpty ? block.categoryKey : block.task, subtitle: "\(block.dayKey) · \(Format.powerHours(block.hours))",
                                deletedAt: block.deletedAt) {
                                app.store.restore([block])
                            } purge: {
                                app.store.purge(TrackerStore.Trash(work: [block]))
                            }
                        }
                    }
                }
                if !trash.items.isEmpty {
                    Section("Punkte") {
                        ForEach(trash.items) { item in
                            row(title: item.title, subtitle: "\(item.weekKey) · \(item.categoryKey)", deletedAt: item.deletedAt) {
                                app.store.restore([item])
                            } purge: {
                                app.store.purge(TrackerStore.Trash(items: [item]))
                            }
                        }
                    }
                }
                if !trash.measures.isEmpty {
                    Section("Messwerte") {
                        ForEach(trash.measures) { measure in
                            row(title: measure.title, subtitle: "\(measure.weekKey) · \(measure.code)", deletedAt: measure.deletedAt) {
                                app.store.restore([measure])
                            } purge: {
                                app.store.purge(TrackerStore.Trash(measures: [measure]))
                            }
                        }
                    }
                }
                if !trash.notes.isEmpty {
                    Section("Notizen") {
                        ForEach(trash.notes) { note in
                            row(title: note.text, subtitle: note.dayKey, deletedAt: note.deletedAt) {
                                app.store.restore([note])
                            } purge: {
                                app.store.purge(TrackerStore.Trash(notes: [note]))
                            }
                        }
                    }
                }
                if !trash.entries.isEmpty {
                    Section("Messwert-Einträge") {
                        ForEach(trash.entries) { entry in
                            row(title: "\(entry.code): \(entry.value.map { Format.number($0) } ?? entry.text)", subtitle: entry.dayKey,
                                deletedAt: entry.deletedAt) {
                                app.store.restore([entry])
                            } purge: {
                                app.store.purge(TrackerStore.Trash(entries: [entry]))
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
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Leeren", role: .destructive) {
                        app.store.purge(trash)
                        reload()
                    }
                    .disabled(trash.isEmpty)
                }
            }
            .onAppear(perform: reload)
        }
        .sheetFrame(minWidth: 480, minHeight: 520)
    }

    private func reload() { trash = app.store.trash() }

    private func row(title: String, subtitle: String, deletedAt: Date?, restore: @escaping () -> Void, purge: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).lineLimit(2)
            Text(subtitle + (deletedAt.map { " · noch \(TrashPolicy().daysLeft(deletedAt: $0)) Tage" } ?? ""))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .swipeActions(edge: .leading) {
            Button("Wiederherstellen", systemImage: "arrow.uturn.backward") {
                restore()
                reload()
            }
            .tint(Brand.accent)
        }
        .swipeActions(edge: .trailing) {
            Button("Endgültig löschen", systemImage: "trash", role: .destructive) {
                purge()
                reload()
            }
        }
        .contextMenu {
            Button("Wiederherstellen", systemImage: "arrow.uturn.backward") {
                restore()
                reload()
            }
            Button("Endgültig löschen", systemImage: "trash", role: .destructive) {
                purge()
                reload()
            }
        }
    }
}

/// Weeks replaced by an import (U15): hidden from every screen and statistic, restorable.
struct ArchiveView: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \WeekArchive.archivedAt, order: .reverse) private var archives: [WeekArchive]
    @State private var restoring: WeekArchive?

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
                .swipeActions(edge: .leading) {
                    Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { restoring = archive }
                        .tint(Brand.accent)
                }
                .swipeActions(edge: .trailing) {
                    Button("Löschen", systemImage: "trash", role: .destructive) { app.store.delete(archive) }
                }
                .contextMenu {
                    Button("Wiederherstellen", systemImage: "arrow.uturn.backward") { restoring = archive }
                    Button("Endgültig löschen", systemImage: "trash", role: .destructive) { app.store.delete(archive) }
                }
            }
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
