import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
#endif

/// v11 (§1.8.2): a page of Einstellungen that `SettingsView(initialPage:)` opens right away on top –
/// "Sicherungen" (`-DemoScreen backup`) and, on iPhone and iPad, Apple Health.
enum SettingsPage: String, Hashable, Identifiable {
    case backups
    #if os(iOS)
    case health
    #endif

    var id: String { rawValue }
}

/// Einstellungen: appearance, reminders, Apple Health, goal year and structure, help, Siri, iCloud &
/// data, import/export, trash, the app log, version. Import and trash open right here (R24).
struct SettingsView: View {
    /// The Mac's own settings window (not a sheet on the main window).
    var inSettingsWindow = false
    /// v11 (§1.8.2): a page shown on top right away (once), e.g. "Sicherungen" for the CI screenshot `backup`.
    var initialPage: SettingsPage?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @AppStorage(TodaySettings.askConditionalsKey) private var askConditionals = false
    @State private var openPage: SettingsPage? = nil
    @State private var openedInitialPage = false

    init(inSettingsWindow: Bool = false, initialPage: SettingsPage? = nil) {
        self.inSettingsWindow = inSettingsWindow
        self.initialPage = initialPage
    }

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
                // v10 (§1.5.5): Theo, George, Nina, Finn … on the same device.
                NavigationLink {
                    ConnectedAppsView()
                } label: {
                    Label("Verbundene Apps", systemImage: "arrow.left.arrow.right")
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
                ForEach(FeatureExplainer.allCases) { feature in
                    NavigationLink { FeatureExplainerView(feature: feature) } label: { Label(feature.title, systemImage: feature.symbol) }
                }
            } header: {
                Text("Hilfe")
            } footer: {
                Text("Die Tour läuft auf einer Übungsseite mit einer Beispielwoche – deine Einträge bleiben unberührt.")
            }

            Section {
                Text("„Hey Siri, Power-Hour in Thalia erfassen“ – Siri fragt nach Bereich, Menge und Wofür. „Ausgabe in Thalia“ fragt nach Betrag und Wofür.")
                    .font(.subheadline)
                // v11 P4.8: the Mac has no Wallet automation – the iPhone's shows up here too.
                #if os(macOS)
                Text("Auf dem iPhone: Kurzbefehle → Automation → Transaktion → Aktion „Ausgabe in Thalia“, Betrag = Betrag, Wofür = Händler. Die Zahlungen erscheinen dann auch hier.")
                    .font(.subheadline)
                #else
                Text("Kartenzahlungen automatisch: Kurzbefehle → Automation → Transaktion → Aktion „Ausgabe in Thalia“, Betrag = Betrag, Wofür = Händler. Dann landet jede Kartenzahlung von selbst in Thalia; von Hand bleiben nur Barzahlungen.")
                    .font(.subheadline)
                #endif
            } header: {
                Text("Siri und Kurzbefehle")
            }

            ThaliaSyncSection()

            Section {
                // v11 P3.13, §1.6.5: one name everywhere – it builds off the main thread and saves `backup.last`.
                BackupExportButton()
                NavigationLink {
                    BackupsPage()
                } label: {
                    Label("Sicherungen", systemImage: "clock.arrow.circlepath")
                }
                if BackupWriter.showsSmallNotice(store: app.store) {
                    Label(BackupWriter.smallNotice, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
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
            } header: {
                Text("Deine Daten")
            } footer: {
                BackupStatusFooter()
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
        .navigationDestination(item: $openPage) { page in
            SettingsPageView(page: page)
        }
        .onAppear(perform: appeared)
    }

    private func appeared() {
        #if os(macOS)
        // v11 P4.2: the Settings window stays when the main window was closed – a reminder or a Shortcut tapped
        // meanwhile opens the main window through this `openWindow`.
        if inSettingsWindow { MainWindow.remember(openWindow) }
        #endif
        showInitialPage()
    }

    /// The page asked for at the start, once – back from it, Einstellungen stays.
    private func showInitialPage() {
        guard !openedInitialPage else { return }
        openedInitialPage = true
        if let initialPage { openPage = initialPage }
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

/// v11 P3.13 (KR2-2): the footer of "Deine Daten" – the last backup by hand on any device, this device's automatic
/// one, and what a backup is for.
private struct BackupStatusFooter: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        // Read again after a sync and after "Sicherung gespeichert" (a toast) – the stamp is a synced record.
        let _ = app.syncTick
        let _ = app.toasts.current?.id
        VStack(alignment: .leading, spacing: 4) {
            Text(BackupWriter.statusLine(store: app.store))
            Text(BackupWriter.footnote)
        }
    }
}

/// The page `SettingsView(initialPage:)` opens on top.
private struct SettingsPageView: View {
    let page: SettingsPage

    var body: some View {
        #if os(iOS)
        if page == .health {
            HealthSettingsView()
        } else {
            BackupsPage()
        }
        #else
        BackupsPage()
        #endif
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
                // v11 P4.13: whether this device's changes went out, and when others' came in.
                SyncTimesRow()
            }
            if let error = app.sync.state.lastError {
                Text(SyncGerman.error(error, appName: AppInfo.name))
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            // v11 P2.9: a save that failed on this device.
            if let failure = app.lastSaveError {
                Text(ThaliaSyncText.saveFailure(failure))
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
/// A recent time for another device means its data arrives here. v11 P4.15: each row names the device's version
/// (`sync.build.`, "iPhone · 1.10.0") and its time runs on; a device of the last 30 days without a 1.10.0 build gets
/// the hint (Mac, Watch and iPad don't score closed weeks meanwhile, P2.1 (d)); devices not seen for 60 days sit
/// under "Früher" and can be removed.
private struct SyncDevicesSection: View {
    @Environment(AppModel.self) private var app
    @State private var devices: [SyncDevice] = []
    @State private var builds: [String: SyncBuild] = [:]

    var body: some View {
        let lines: [SyncDeviceLine] = SyncDeviceLine.lines(devices, builds: builds, me: TrackerStore.installID, now: Date())
        let recent: [SyncDeviceLine] = lines.filter { !$0.isOld }
        let old: [SyncDeviceLine] = lines.filter(\.isOld)
        Section {
            if lines.isEmpty {
                Text("Noch kein Gerät gemeldet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(recent) { line in
                SyncDeviceRow(line: line)
            }
            if !old.isEmpty {
                DisclosureGroup("Früher") {
                    ForEach(old) { line in
                        // Only other installations are old (this device is always recent).
                        SyncDeviceRow(line: line, onRemove: { app.forgetDevice(line.device, label: line.label) })
                    }
                }
            }
        } header: {
            Text("Geräte im Abgleich")
        } footer: {
            Text("Jedes Gerät meldet sich, wenn Thalia geöffnet wird (höchstens alle 10 Minuten). Steht hier bei einem anderen Gerät eine aktuelle Zeit, kommen seine Daten an. Die Apple Watch meldet sich, wenn ihre Thalia-App offen war. Geräte, die 60 Tage nicht gesehen wurden, stehen unter „Früher“.")
        }
        .task(id: app.syncTick) { reload() }
    }

    private func reload() {
        let store = app.store
        devices = store.syncDevices()
        builds = SyncBuild.builds(store.settings(prefix: SettingKeys.buildPrefix).map(\.stored))
    }
}

/// One device in "Geräte im Abgleich" (v11 P4.15).
struct SyncDeviceLine: Identifiable {
    /// Not seen for this long: under "Früher".
    static let oldAfter: TimeInterval = 60 * 24 * 3600

    let device: SyncDevice
    /// "iPhone", "Mac (2)", "iPad (dieses Gerät)"
    let label: String
    /// "1.10.0" from `sync.build.`; nil when the device never wrote one.
    let version: String?
    let isThisDevice: Bool
    /// Seen in the last 30 days without a 1.10.0 build.
    let isOutdated: Bool
    let isOld: Bool

    var id: String { device.installID }

    /// "iPhone · 1.10.0"
    var title: String {
        guard let version, !version.isEmpty else { return label }
        return "\(label) · \(version)"
    }

    var symbol: String {
        switch device.kind {
        case "Mac": return "laptopcomputer"
        case "iPad": return "ipad"
        case "Apple Watch": return "applewatch"
        default: return "iphone"
        }
    }

    static func lines(_ devices: [SyncDevice], builds: [String: SyncBuild], me: String, now: Date) -> [SyncDeviceLine] {
        SyncDevice.labelled(devices).map { entry in
            let device: SyncDevice = entry.device
            let isMe: Bool = device.installID == me
            let build: SyncBuild? = builds[device.installID]
            let age: TimeInterval = now.timeIntervalSince(device.seenAt)
            let current: Bool = (build?.build ?? 0) >= SyncDevice.firstV11Build
            return SyncDeviceLine(device: device, label: isMe ? "\(entry.label) (dieses Gerät)" : entry.label,
                                  version: build?.version, isThisDevice: isMe,
                                  isOutdated: !isMe && !current && age < SyncDevice.currentWindow,
                                  isOld: !isMe && age >= oldAfter)
        }
    }
}

private struct SyncDeviceRow: View {
    let line: SyncDeviceLine
    var onRemove: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent {
                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    Text(SyncDevice.seenText(line.device.seenAt, now: timeline.date))
                        .monospacedDigit()
                }
            } label: {
                Label(line.title, systemImage: line.symbol)
            }
            if line.isOutdated {
                Text("Thalia 1.9 – bitte dort aktualisieren. Bis dahin werten Mac und Watch abgeschlossene Wochen nicht selbst.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let onRemove {
                Button("Entfernen", role: .destructive, action: onRemove)
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
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

    /// v11 P4.13: "Gesendet: vor 1 Min. · Empfangen: vor 4 Min." (the style of "Geräte im Abgleich").
    static func sentReceived(sent: Date?, received: Date?, now: Date) -> String {
        let sentText: String = sent.map { SyncDevice.seenText($0, now: now) } ?? "noch nicht"
        let receivedText: String = received.map { SyncDevice.seenText($0, now: now) } ?? "noch nicht"
        return "Gesendet: \(sentText) · Empfangen: \(receivedText)"
    }

    /// v11 P2.9: "Letzter Speicherfehler: 23.11.2026, 18:03 – <the system's text>".
    static func saveFailure(_ failure: SaveFailure) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_AT")
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        let message: String = failure.message.isEmpty ? "unbekannter Fehler" : failure.message
        return "Letzter Speicherfehler: \(formatter.string(from: failure.date)) – \(message)"
    }
}

/// v11 P4.13: "Gesendet … · Empfangen …", updated every minute; orange when a change of this device is older than 15
/// minutes and no export has gone out since (the iCloud account is there).
private struct SyncTimesRow: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 4) {
                Text(ThaliaSyncText.sentReceived(sent: app.lastSent, received: app.lastReceived, now: timeline.date))
                    .font(.subheadline)
                    .monospacedDigit()
                if app.hasUnsentChange(now: timeline.date) {
                    Label("Letzte Änderung noch nicht an iCloud gesendet", systemImage: "exclamationmark.icloud")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// "Wo deine Daten liegen" – Thalia's own page instead of the kit's English one (R79).
struct ThaliaDataLocationView: View {
    @Environment(AppModel.self) private var app

    // HEALTHSHARE: "Bleibt auf dem Gerät – außer beim Teilen (TestFlight)" while Health values are shared (P9.4).
    private var sections: [DataSection] {
        ThaliaDataFacts.sections(sharingHealth: app.healthShare.sharesHealth(store: app.store))
    }

    var body: some View {
        Form {
            ForEach(sections) { section in
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
        // v11 P3.14: what a backup holds and what the trash keeps, as they are.
        DataSection("Sichern und Löschen", [
            DataFact("externaldrive", "Sicherung", "Einstellungen → Deine Daten → „Sicherung erstellen…“: Pläne, Einträge, Ergebnisse, Leseliste, Zieljahr und die Daten verbundener Apps im Importformat. Nicht darin: das Archiv ersetzter Wochen, übernommene Health-Werte und Einstellungen dieses Geräts."),
            DataFact("trash", "Löschen", "Gelöschte Punkte, Messwerte, Einträge, Power-Hours, Notizen, Ergebnisse, Bücher und Abschnitte bleiben 30 Tage in „Zuletzt gelöscht“; einzelne Jahresziel-Einträge und Lesestände lassen sich direkt danach im Hinweis widerrufen. Ganz löschen: App auf allen Geräten löschen, dann in Einstellungen → dein Name → iCloud → Speicher verwalten die Daten von Thalia entfernen."),
        ]),
    ]

    // HEALTHSHARE: while "Health-Werte mit Mac und Watch teilen" is on (TestFlight only, §1.4.10, P9.4) the fact "Bleibt auf
    // dem Gerät" says the exception; otherwise `sections` as they are.
    static func sections(sharingHealth: Bool) -> [DataSection] {
        guard sharingHealth else { return sections }
        return sections.map { section in
            DataSection(section.title, section.facts.map { fact in fact.symbol == "lock.iphone" ? sharedHealthFact : fact })
        }
    }

    // HEALTHSHARE
    static let sharedHealthFact = DataFact("lock.iphone", "Bleibt auf dem Gerät – außer beim Teilen (TestFlight)", "Übernommene Health-Werte bleiben auf diesem Gerät – außer „Health-Werte mit Mac und Watch teilen“ ist an (nur TestFlight): dann liegen die letzten 5 Wochen in deiner iCloud. Was sonst synchronisiert, ist deine eigene Bewertung.")
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
    // HEALTHSHARE: the sharing's switch and its texts (TestFlight only).
    @Environment(AppModel.self) private var app

    // HEALTHSHARE: the last section while Health values are shared (§1.4.10, P9.4); otherwise as before.
    private var storageText: String {
        guard app.healthShare.sharesHealth(store: app.store) else {
            return "Übernommene Werte bleiben auf diesem iPhone (App-Store-Richtlinie 5.1.3: keine Gesundheitsdaten in iCloud). Andere Geräte sehen deine Bewertung, nicht den Health-Wert."
        }
        return "Übernommene Werte gehen an Mac und Watch (Schalter oben, nur TestFlight). Ausschalten löscht sie aus iCloud."
    }

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
            // HEALTHSHARE: "Health-Werte mit Mac und Watch teilen" – only while the gate is `.allowed` (§1.4.1).
            HealthShareSection()
            Section("Welche Messwerte") {
                ForEach(HealthKind.allCases, id: \.self) { kind in
                    LabeledContent(kind.label, value: "health:\(kind.rawValue)")
                        .font(.subheadline)
                }
            }
            Section {
                // HEALTHSHARE: `storageText` (the TestFlight wording while shared).
                Text(storageText)
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
    /// The stored goal year – segments and results below follow it.
    @State private var period = GoalPeriod.foundationYear
    /// v11 P4.20: what is being typed – "Beginn", "Ende" and "Zielüberprüfung" go to iCloud only with "Zieljahr
    /// sichern", the motto on Return and when the field is left (no half-typed state syncs).
    @State private var draft = GoalPeriod.foundationYear
    @State private var loaded = false
    @State private var asksNewYear = false
    @FocusState private var mottoFocused: Bool
    @State private var editingCategory: TrackCategory?
    /// v10 (§1.4.2): the goal year's records (`goal.`: segments, results, entries) – live.
    @Query private var goalRecords: [AppSetting]
    /// v10: the segment wizard, a segment, a result, a new goal or category.
    @State private var structureSheet: GoalStructureSheet?
    /// v10: opened right after "Neuen Abschnitt beginnen…" – a short note on top, no second wizard.
    let afterSegmentStart: Bool

    init(afterSegmentStart: Bool = false) {
        self.afterSegmentStart = afterSegmentStart
        let prefix = "goal."
        _goalRecords = Query(filter: #Predicate<AppSetting> { $0.key.starts(with: prefix) })
    }

    /// The goal year's segments, gapless (one "Abschnitt 1" without stored ones).
    private var segments: Segments {
        Segments.resolve(SettingRecords.decode(GoalSegment.self, from: goalRecords.map(\.stored)), period: period)
    }

    private var storedSegments: [GoalSegment] {
        SettingRecords.decode(GoalSegment.self, from: goalRecords.map(\.stored))
    }

    /// Stored segments that don't count – a second one on the same week (two devices, or begun twice);
    /// listed so they can be deleted.
    private var hiddenSegments: [GoalSegment] {
        Segments.hidden(storedSegments, period: period)
    }

    private var results: [GoalResult] {
        SettingRecords.decode(GoalResult.self, from: goalRecords.map(\.stored))
            .filter { $0.periodStart == nil || $0.periodStart == period.start }
            .sorted(by: TrackerStore.resultOrder)
    }

    var body: some View {
        let resolved: Segments = segments
        Form {
            if afterSegmentStart {
                Section {
                    Label(GoalStructureSheet.afterStartText(resolved, today: app.today), systemImage: "flag.2.crossed.fill")
                        .font(.subheadline)
                }
            }
            Section {
                DatePicker("Beginn", selection: dayBinding(\.start), displayedComponents: .date)
                    .thaliaDateLocale()
                DatePicker("Ende", selection: dayBinding(\.end), displayedComponents: .date)
                    .thaliaDateLocale()
                Picker("Zielüberprüfung", selection: $draft.reviewWeek) {
                    ForEach(0..<60, id: \.self) { offset in
                        let week = draft.start.week.adding(weeks: offset)
                        Text("\(week.longLabel) (\(week.rangeLabel))").tag(week)
                    }
                }
                TextField("Motto", text: $draft.motto, axis: .vertical)
                    .focused($mottoFocused)
                    .onSubmit(saveMotto)
                if yearChanged {
                    Button("Zieljahr sichern", systemImage: "checkmark.circle") { saveYear() }
                        .disabled(!draftIsValid)
                }
            } header: {
                Text("Zieljahr")
            } footer: {
                Text(yearFooter)
            }

            segmentsSection(resolved)
            goalsSection
            resultsSection(resolved)
            categoriesSection
        }
        .formStyle(.grouped)
        .navigationTitle("Jahresziele")
        .onAppear {
            guard !loaded else { return }
            period = app.store.goalPeriod
            draft = period
            loaded = true
        }
        .onChange(of: mottoFocused) { _, focused in
            if !focused { saveMotto() }
        }
        .onDisappear(perform: saveMotto)
        .confirmationDialog("Beginn des Zieljahrs ändern?", isPresented: $asksNewYear, titleVisibility: .visible) {
            Button("Neues Zieljahr beginnen") { applyYear() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(newYearMessage)
        }
        .sheet(item: $editingCategory) { category in
            CategoryEditor(category: category).environment(app)
        }
        .sheet(item: $structureSheet) { sheet in
            GoalStructureSheetContent(sheet: sheet)
                .thaliaLocalSheet(app)
        }
    }

    /// v10: the goals and the categories as sections of their own (the body stays small for the type checker).
    private var goalsSection: some View {
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
            if !goals.isEmpty {
                Button("Jahresziel hinzufügen", systemImage: "plus") { structureSheet = .newGoal }
            }
        } header: {
            Text("Jahresziele")
        } footer: {
            Text("Die Zahl rechts sind die Kategorien darunter. Ein Ziel mit mehr Kategorien wiegt nicht mehr. Antippen öffnet das Ziel: umbenennen, Beschreibung, Ergebnisse.")
        }
    }

    private var categoriesSection: some View {
        Section {
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
            if !goals.isEmpty {
                Button("Kategorie hinzufügen", systemImage: "plus") { structureSheet = .newCategory }
            }
        } header: {
            Text("Kategorien")
        } footer: {
            Text("Kategorien werden hier umbenannt und ergänzt; umhängen oder löschen geht über den Wochenplan.")
        }
    }

    // MARK: v10 – segments and results (§1.4.2)

    /// "Abschnitte": every segment of the goal year, the running one marked; "Neuen Abschnitt beginnen…".
    private func segmentsSection(_ resolved: Segments) -> some View {
        let current: SegmentSpan? = resolved.current(today: app.today)
        return Section {
            ForEach(resolved.spans, id: \.id) { span in
                if span.isStored {
                    Button {
                        openSegment(span, resolved: resolved)
                    } label: {
                        GoalStructureRow(title: span.title, detail: GoalStructureSheet.segmentDetail(span),
                                         tag: GoalStructureSheet.runningTag(span, current: current))
                    }
                    .buttonStyle(.plain)
                } else {
                    GoalStructureRow(title: span.title, detail: GoalStructureSheet.segmentDetail(span),
                                     tag: GoalStructureSheet.runningTag(span, current: current))
                }
            }
            ForEach(hiddenSegments, id: \.id) { segment in
                Button {
                    structureSheet = .segment(segment, isFirst: false)
                } label: {
                    GoalStructureRow(title: segment.title.isEmpty ? "Abschnitt" : segment.title,
                                     detail: GoalStructureSheet.hiddenDetail(segment), tag: "doppelt")
                }
                .buttonStyle(.plain)
            }
            if !afterSegmentStart {
                Button("Neuen Abschnitt beginnen…", systemImage: "flag.2.crossed") { structureSheet = .wizard }
            }
        } header: {
            Text("Abschnitte")
        } footer: {
            Text("Ein Abschnitt ist eine Version der Jahresziele. Frühere Abschnitte bleiben mit ihren Werten erhalten; abgeschlossene Wochen davor werden nicht automatisch neu gewertet.")
        }
    }

    /// A stored segment opens its editor; the implicit "Abschnitt 1" has nothing to edit yet.
    private func openSegment(_ span: SegmentSpan, resolved: Segments) {
        guard span.isStored, let stored = storedSegments.first(where: { $0.id == span.id }) else { return }
        structureSheet = .segment(stored, isFirst: span.number == 1)
    }

    /// "Ergebnisse": per goal its results with the targets; the current segment's own target ("aktualisiert"),
    /// new from / ended after a segment.
    private func resultsSection(_ resolved: Segments) -> some View {
        let current: SegmentSpan? = resolved.hasSeveral ? resolved.current(today: app.today) : nil
        // Right after "Neuen Abschnitt beginnen…" (for next week) the targets are set for the new one.
        let upcoming: SegmentSpan? = resolved.hasSeveral ? resolved.upcoming(today: app.today) : nil
        let targetSegment: SegmentSpan? = upcoming ?? current
        return Section {
            if results.isEmpty {
                Text("Noch keine Ergebnisse – zum Beispiel „10 Bücher“, „Website online“ oder ein Zielwert.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(results, id: \.id) { result in
                Button {
                    structureSheet = .result(result, goalKey: result.goalKey)
                } label: {
                    GoalStructureRow(title: ResultTexts.choiceLabel(result),
                                     detail: GoalStructureSheet.resultDetail(result, segment: targetSegment, segments: resolved),
                                     tag: GoalStructureSheet.resultTag(result, segment: current, segments: resolved))
                }
                .buttonStyle(.plain)
            }
            if !goals.isEmpty {
                Button("Ergebnis anlegen", systemImage: "plus") {
                    structureSheet = .result(nil, goalKey: sortedGoals.first?.key ?? "")
                }
            }
        } header: {
            Text("Ergebnisse")
        } footer: {
            Text(GoalStructureSheet.resultsFooter(targetSegment))
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
            get: { draft[keyPath: path].startDate() },
            set: { draft[keyPath: path] = DayKey(date: $0) }
        )
    }

    // MARK: v11 P4.20 – the goal year saved on purpose

    /// "Beginn", "Ende" or "Zielüberprüfung" differ from what is stored.
    private var yearChanged: Bool {
        draft.start != period.start || draft.end != period.end || draft.reviewWeek != period.reviewWeek
    }

    private var draftIsValid: Bool { draft.end > draft.start }

    private var yearFooter: String {
        let rule = "Bis zur Zielüberprüfung werden Ziele nicht automatisch schwerer – auch nach einer guten Woche nicht."
        return draftIsValid ? rule : "Das Ende liegt vor dem Beginn. " + rule
    }

    /// The motto on its own (Return, leaving the field, leaving the page) – the dates stay as they are stored.
    private func saveMotto() {
        guard loaded, draft.motto != period.motto else { return }
        var new: GoalPeriod = period
        new.motto = draft.motto
        app.store.setGoalPeriod(new)
        period = new
    }

    /// "Zieljahr sichern": a new "Beginn" while results or segments belong to the old one asks first.
    private func saveYear() {
        guard draftIsValid else { return }
        if draft.start != period.start && !newYearMessage.isEmpty {
            asksNewYear = true
            return
        }
        applyYear()
    }

    /// All four settings in one change (`setGoalPeriod`, P2.10). A new "Beginn" that hides results or segments
    /// offers "Widerrufen" (§0.4): the goal year as it was comes back, and with it what it showed.
    private func applyYear() {
        guard draftIsValid else { return }
        let previous: GoalPeriod = period
        let hidesSomething: Bool = draft.start != previous.start && !newYearMessage.isEmpty
        app.store.setGoalPeriod(draft)
        period = draft
        guard hidesSomething else { return }
        let store: TrackerStore = app.store
        app.toasts.show("Neues Zieljahr ab \(GoalYearSettingsView.dateText(draft.start))", symbol: "calendar") {
            store.setGoalPeriod(previous)
            period = previous
            draft = previous
        }
    }

    /// "1. Juni 2026" – the date without its weekday.
    private static func dateText(_ day: DayKey) -> String {
        String(day.longLabel.split(separator: ",", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// "3 Ergebnisse und 2 Abschnitte gehören zum Zieljahr ab 1. Juni 2026. Mit dem neuen Beginn …"; empty when
    /// nothing belongs to the stored start.
    private var newYearMessage: String {
        let results: Int = SettingRecords.decode(GoalResult.self, from: goalRecords.map(\.stored))
            .filter { $0.periodStart == period.start }.count
        let segments: Int = storedSegments.filter { $0.periodStart == period.start }.count
        var parts: [String] = []
        if results > 0 { parts.append(Format.count(results, "Ergebnis", "Ergebnisse")) }
        if segments > 0 { parts.append(Format.count(segments, "Abschnitt", "Abschnitte")) }
        guard !parts.isEmpty else { return "" }
        let verb: String = results + segments == 1 ? "gehört" : "gehören"
        let start: String = GoalYearSettingsView.dateText(period.start)
        return "\(parts.joined(separator: " und ")) \(verb) zum Zieljahr ab \(start). Mit dem neuen Beginn werden sie nicht mehr angezeigt – stellst du den alten Beginn wieder ein, sind sie zurück."
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
    /// v11 P2.6: restoring an item or measurement whose week has a live copy asks first.
    @State private var restoreQuestion: RestoreQuestion?

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
                            restore(item)
                        }
                    }
                }
            }
            if !trash.measures.isEmpty {
                Section("Messwerte") {
                    ForEach(trash.measures) { measure in
                        row(planLine(measure.title, week: measure.weekKey, category: measure.categoryKey), deletedAt: measure.deletedAt,
                            purge: TrackerStore.Trash(measures: [measure])) {
                            restore(measure)
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
            recordSections
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
        .confirmationDialog(restoreTitle, isPresented: restoreIsPresented, titleVisibility: .visible,
                            presenting: restoreQuestion) { question in
            Button("Trotzdem wiederherstellen") {
                question.restore()
                restoreQuestion = nil
                reload()
            }
            Button("Abbrechen", role: .cancel) { restoreQuestion = nil }
        } message: { question in
            Text(question.message)
        }
        .onAppear(perform: reload)
    }

    // MARK: Restoring next to a live copy (v11 P2.6)

    private struct RestoreQuestion: Identifiable {
        let id = UUID()
        /// "„Lesen am Abend“ gibt es in KW48 schon."
        let title: String
        let message: String
        let restore: () -> Void
    }

    private var restoreTitle: String { restoreQuestion?.title ?? "" }

    private var restoreIsPresented: Binding<Bool> {
        Binding(get: { restoreQuestion != nil }, set: { if !$0 { restoreQuestion = nil } })
    }

    /// An item whose week has a live copy with the same code (two devices, an import) – asked first; else at once.
    private func restore(_ item: PlanItem) {
        let store = app.store
        guard let title = store.restoreConflicts([item]).first else {
            store.restore([item])
            return
        }
        restoreQuestion = RestoreQuestion(title: Self.conflictTitle(title, week: item.weekKey),
                                          message: "Wiederherstellen ersetzt den Punkt aus dem letzten Import.",
                                          restore: { store.restore([item]) })
    }

    private func restore(_ measure: MeasureDefinition) {
        let store = app.store
        guard let title = store.restoreConflicts([measure]).first else {
            store.restore([measure])
            return
        }
        restoreQuestion = RestoreQuestion(title: Self.conflictTitle(title, week: measure.weekKey),
                                          message: "Wiederherstellen ersetzt den Messwert aus dem letzten Import.",
                                          restore: { store.restore([measure]) })
    }

    private static func conflictTitle(_ title: String, week: String) -> String {
        "„\(title)“ gibt es in \(WeekKey(week)?.label ?? week) schon."
    }

    /// v10 (§1.1.3): results, reading-list entries and segments – their entries and readings go and
    /// come back with them.
    @ViewBuilder
    private var recordSections: some View {
        if !trash.results.isEmpty {
            Section("Ergebnisse") {
                ForEach(trash.results, id: \.id) { result in
                    row(TrashRecordTexts.result(result), deletedAt: result.deletedAt, purge: TrackerStore.Trash(results: [result])) {
                        _ = app.store.restore(result)
                    }
                }
            }
        }
        if !trash.listItems.isEmpty {
            Section("Leseliste") {
                ForEach(trash.listItems, id: \.id) { item in
                    row(TrashRecordTexts.book(item), deletedAt: item.deletedAt, purge: TrackerStore.Trash(listItems: [item])) {
                        _ = app.store.restore(item)
                    }
                }
            }
        }
        if !trash.segments.isEmpty {
            Section("Abschnitte") {
                ForEach(trash.segments, id: \.id) { segment in
                    row(TrashRecordTexts.segment(segment), deletedAt: segment.deletedAt, purge: TrackerStore.Trash(segments: [segment])) {
                        _ = app.store.restore(segment)
                    }
                }
            }
        }
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
                    Text(ArchiveView.detail(archive))
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
                app.scheduleReminders()
                app.toasts.show("\(archive.week?.label ?? "Woche") wiederhergestellt · \(result.summary)", symbol: "arrow.uturn.backward")
            }
        } message: { _ in
            // v9: a complete restore ("Archivdaten ersetzen") archives more than the plan.
            Text("Was die Woche jetzt hat, kommt dafür ins Archiv.")
        }
        .navigationTitle("Archiv")
    }

    /// "24 Punkte · 96 Markierungen · archiviert …"; v9: a week without items "ohne Punkte · …".
    static func detail(_ archive: WeekArchive) -> String {
        let date: String = "archiviert " + archive.archivedAt.formatted(date: .abbreviated, time: .shortened)
        guard archive.itemCount > 0 || archive.markCount > 0 else { return "ohne Punkte · " + date }
        return "\(archive.itemCount) Punkte · \(archive.markCount) Markierungen · " + date
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
