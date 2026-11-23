import SwiftUI
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore

// v11 (TASKS-v11 §1.6, P3.11, P3.13): "Sicherung erstellen…" – one name everywhere – and the weekly automatic
// backup. The export is the import format (`TrackerStore.exportDocument()` on the main context, `PlanCSV.export`
// off the main thread); `backup.last` (synced, `BackupStamp`) says when and on which kind of device the last
// backup by hand was made, on every device; the automatic files lie in Application Support/Sicherungen of this
// device ("Thalia Sicherung 2026-11-23.csv"), never overwritten. Never shared Health values (they aren't in the
// export), never from `-Demo`, the tour's practice store or a store that only lives in memory.

/// One automatic backup of this device.
struct BackupFile: Identifiable, Hashable {
    let url: URL
    /// The day in its name.
    let day: DayKey
    /// Bytes.
    let size: Int

    var id: String { url.lastPathComponent }
    var name: String { url.lastPathComponent }
    /// "23.11.2026"
    var dateText: String { BackupWriter.dateText(day) }
    /// "3,7 MB"
    var sizeText: String { BackupWriter.sizeText(size) }
}

@MainActor
enum BackupWriter {
    /// The folder in Application Support.
    nonisolated static let folderName = "Sicherungen"
    /// UserDefaults (this device): when the last automatic backup was written.
    nonisolated static let lastAutoKey = "backup.lastAuto"
    /// UserDefaults (this device): the last automatic backup was unusually small, older ones were kept.
    nonisolated static let smallKey = "backup.lastAutoSmall"
    /// An automatic backup at most every this many days.
    nonisolated static let intervalDays = 7
    /// The closing of a week reminds when no device has made a backup by hand for this many days.
    nonisolated static let reminderDays = 30
    /// Kept: the newest files …
    nonisolated static let keepNewest = 4
    /// … and one per month for this many months (this one included).
    nonisolated static let keepMonths = 6

    nonisolated static let savedToast = "Sicherung gespeichert"
    nonisolated static let smallNotice = "Letzte automatische Sicherung auffällig klein – ältere bleiben"
    nonisolated static let footnote = "Die Sicherung ist deine Kopie außerhalb von iCloud – auch für die Daten verbundener Apps."

    // MARK: Export (P3.11)

    /// The whole backup as text: the state read on the main context, the CSV written off the main thread (a year's
    /// backup doesn't freeze the app). Every way to "Sicherung erstellen…" goes through here.
    static func exportText(store: TrackerStore) async -> String {
        let document: PlanCSV.Document = store.exportDocument()
        return await Task.detached(priority: .userInitiated) {
            PlanCSV.export(document)
        }.value
    }

    /// "Thalia Sicherung 2026-11-23" – the name the save panel suggests.
    static func exportName(today: DayKey) -> String { "Thalia Sicherung \(today.string)" }

    // MARK: "Letzte Sicherung" for all devices (P3.13, KR2-2)

    /// After a full backup by hand was saved: `backup.last` = now and this kind of device (synced, the newest wins).
    /// Without Undo (nothing to take back); not in a store that only lives in memory.
    static func stamp(store: TrackerStore, now: Date = Date()) {
        guard !store.isInMemory else { return }
        if let current = lastStamp(store: store), current.at > now { return }
        let stamp = BackupStamp(at: now, device: SyncDeviceKind.current)
        store.withoutUndo {
            var change = RecordChange()
            store.writeSetting(SettingKeys.backupLast, stamp.value, now: now, change: &change)
            if !change.isEmpty { store.commit(change, origin: .maintenance) }
        }
        AppLog.info("Backup saved by hand (\(stamp.device))", category: "import")
    }

    /// The last backup by hand on any device (two devices before they synced: the later one).
    static func lastStamp(store: TrackerStore) -> BackupStamp? {
        BackupStamp.latest(store.settings(keys: [SettingKeys.backupLast]).map(\.value))
    }

    /// When this device last wrote an automatic backup.
    static var lastAuto: Date? { UserDefaults.standard.object(forKey: lastAutoKey) as? Date }

    /// The last automatic backup was less than half the size of the largest kept one – nothing was cleaned up.
    static var lastAutoWasSmall: Bool { UserDefaults.standard.bool(forKey: smallKey) }

    /// "Letzte Sicherung: 22.11.2026 am iPhone (vor 3 Tagen) · automatisch: 23.11.2026 auf diesem Gerät", or
    /// "Noch keine Sicherung" – the footer of Einstellungen → Deine Daten.
    static func statusLine(store: TrackerStore, now: Date = Date()) -> String {
        statusLine(stamp: lastStamp(store: store), lastAuto: lastAuto, now: now)
    }

    nonisolated static func statusLine(stamp: BackupStamp?, lastAuto: Date?, now: Date) -> String {
        var parts: [String] = []
        if let stamp {
            let device = deviceText(stamp.device)
            let when = dateText(DayKey(date: stamp.at)) + (device.isEmpty ? "" : " " + device)
            parts.append("Letzte Sicherung: \(when) (\(agoText(stamp.days(until: now))))")
        } else {
            parts.append("Noch keine Sicherung")
        }
        if let lastAuto { parts.append("automatisch: \(dateText(DayKey(date: lastAuto))) auf diesem Gerät") }
        return parts.joined(separator: " · ")
    }

    /// The calm line in the week's closing: "Letzte Sicherung vor 34 Tagen – jetzt sichern?" when no device has
    /// made a backup by hand for 30 days ("Noch keine Sicherung – jetzt sichern?" when there was none); nil otherwise.
    static func closingReminder(store: TrackerStore, now: Date = Date()) -> String? {
        closingReminder(stamp: lastStamp(store: store), now: now)
    }

    nonisolated static func closingReminder(stamp: BackupStamp?, now: Date) -> String? {
        guard let stamp else { return "Noch keine Sicherung – jetzt sichern?" }
        let days = stamp.days(until: now)
        guard days >= reminderDays else { return nil }
        return "Letzte Sicherung vor \(days) Tagen – jetzt sichern?"
    }

    // MARK: The weekly automatic backup (P3.13 step 2)

    /// Application Support/Sicherungen of this device (made when needed).
    static var folder: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    /// "Thalia Sicherung 2026-11-23.csv"
    nonisolated static func fileName(_ day: DayKey) -> String { "Thalia Sicherung \(day.string).csv" }

    /// The day in a backup's file name; nil for any other file.
    nonisolated static func day(fileName: String) -> DayKey? {
        let prefix = "Thalia Sicherung "
        let suffix = ".csv"
        guard fileName.hasPrefix(prefix), fileName.hasSuffix(suffix) else { return nil }
        let middle = fileName.dropFirst(prefix.count).dropLast(suffix.count)
        guard middle.count == 10 else { return nil }
        return DayKey(String(middle))
    }

    /// Only a real store keeps automatic backups: iCloud once this device's first sync is done (P3.2 – before, a
    /// nearly empty store would replace good files), or local. Never `-Demo`, the tour's practice store or memory.
    static func isAllowed(mode: StorageMode, store: TrackerStore) -> Bool {
        guard !store.isInMemory else { return false }
        switch mode {
        case .iCloud: return SyncProgress.firstImportDone
        case .local: return true
        case .memory, .demo: return false
        }
    }

    /// Due when there is none yet or the last one is at least 7 days old.
    nonisolated static func isDue(today: DayKey, lastAuto: Date?) -> Bool {
        guard let lastAuto else { return true }
        return today.ordinal - DayKey(date: lastAuto).ordinal >= intervalDays
    }

    /// Writes this week's automatic backup when it is due (`isAllowed`, `isDue`): the file with the day in its name,
    /// written atomically, never over an existing one. Then cleans up (`kept`: the 4 newest and one per month for 6
    /// months) – but not after an unusually small file (less than half the largest kept one: something is missing,
    /// older ones stay, `lastAutoWasSmall`). Called when Thalia goes to the background (iPhone, Mac – P4). Returns
    /// the new file; nil when nothing was written. `folder`: another folder (checks).
    @discardableResult
    static func writeWeeklyIfDue(store: TrackerStore, today: DayKey, mode: StorageMode, in folder: URL? = nil,
                                 now: Date = Date()) async -> BackupFile? {
        guard isAllowed(mode: mode, store: store), isDue(today: today, lastAuto: lastAuto),
              let target = folder ?? Self.folder else { return nil }
        let name = fileName(today)
        let url = target.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: url.path) else {
            // Never overwritten – today's file is there already (this device wrote it before).
            UserDefaults.standard.set(now, forKey: lastAutoKey)
            return nil
        }
        let text = await exportText(store: store)
        let problem: String? = await Task.detached(priority: .utility) { () -> String? in
            do {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                try Data(text.utf8).write(to: url, options: .atomic)
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value
        if let problem {
            AppLog.warning("Automatic backup not written: \(problem)", category: "import")
            return nil
        }
        UserDefaults.standard.set(now, forKey: lastAutoKey)
        let all = files(in: target)
        guard let written = all.first(where: { $0.name == name }) else { return nil }
        let keep = kept(all, today: today)
        let largest: Int = all.filter { $0.name != name && keep.contains($0.name) }.map(\.size).max() ?? 0
        if written.size * 2 < largest {
            UserDefaults.standard.set(true, forKey: smallKey)
            AppLog.warning("Automatic backup unusually small (\(written.size) of \(largest) bytes) – older ones kept", category: "import")
            return written
        }
        UserDefaults.standard.set(false, forKey: smallKey)
        var removed = 0
        for file in all where !keep.contains(file.name) {
            if (try? FileManager.default.removeItem(at: file.url)) != nil { removed += 1 }
        }
        AppLog.info("Automatic backup written (\(written.size) bytes), \(removed) older removed", category: "import")
        return written
    }

    /// The automatic backups of this device, newest first.
    static func files(in folder: URL? = nil) -> [BackupFile] {
        guard let target = folder ?? Self.folder,
              let names = try? FileManager.default.contentsOfDirectory(atPath: target.path) else { return [] }
        let found: [BackupFile] = names.compactMap { name in
            guard let day = day(fileName: name) else { return nil }
            let url = target.appendingPathComponent(name)
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size: Int = (attributes?[.size] as? NSNumber)?.intValue ?? 0
            return BackupFile(url: url, day: day, size: size)
        }
        return found.sorted { ($0.day, $0.name) > ($1.day, $1.name) }
    }

    /// The names to keep: the 4 newest, and the newest of each of the last 6 calendar months (this one included).
    nonisolated static func kept(_ files: [BackupFile], today: DayKey) -> Set<String> {
        let newestFirst = files.sorted { ($0.day, $0.name) > ($1.day, $1.name) }
        var keep = Set(newestFirst.prefix(keepNewest).map(\.name))
        let thisMonth = today.year * 12 + today.month - 1
        var months: Set<Int> = []
        for file in newestFirst {
            let month = file.day.year * 12 + file.day.month - 1
            guard month <= thisMonth, month > thisMonth - keepMonths else { continue }
            if months.insert(month).inserted { keep.insert(file.name) }
        }
        return keep
    }

    // MARK: Texts

    /// "23.11.2026"
    nonisolated static func dateText(_ day: DayKey) -> String {
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return "\(two(day.day)).\(two(day.month)).\(day.year)"
    }

    /// "820 KB", "3,7 MB"
    nonisolated static func sizeText(_ bytes: Int) -> String {
        if bytes < 1_000_000 { return "\(max(1, Int((Double(bytes) / 1000).rounded()))) KB" }
        return Format.number(Double(bytes) / 1_000_000, decimals: 1) + " MB"
    }

    /// "am iPhone", "am Mac", "am iPad", "an der Apple Watch"; "" for an unknown kind.
    nonisolated static func deviceText(_ kind: String) -> String {
        switch kind {
        case "": return ""
        case "Apple Watch": return "an der Apple Watch"
        default: return "am \(kind)"
        }
    }

    /// "heute", "gestern", "vor 3 Tagen"
    nonisolated static func agoText(_ days: Int) -> String {
        switch days {
        case ..<1: return "heute"
        case 1: return "gestern"
        default: return "vor \(days) Tagen"
        }
    }
}

// MARK: Views for Einstellungen → Deine Daten (placed by SettingsView, P4)

/// "Sicherung erstellen…": builds the backup off the main thread ("Sicherung wird erstellt …", no second tap), offers
/// to save it ("Thalia Sicherung 2026-11-23.csv"), stamps `backup.last` and says "Sicherung gespeichert". Always the
/// real store (never the tour's practice store).
struct BackupExportButton: View {
    var title: String = "Sicherung erstellen…"
    var systemImage: String = "externaldrive"
    @Environment(AppModel.self) private var app
    @State private var file: CSVFile?
    @State private var fileName = "Thalia Sicherung"
    @State private var isBackingUp = false

    var body: some View {
        Button {
            start()
        } label: {
            if isBackingUp {
                BackupProgressLabel()
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .disabled(isBackingUp)
        .fileExporter(isPresented: isExporting, document: file, contentType: .commaSeparatedText,
                      defaultFilename: fileName) { result in
            finish(result)
        }
    }

    private var isExporting: Binding<Bool> {
        Binding(get: { file != nil }, set: { if !$0 { file = nil } })
    }

    private func start() {
        guard !isBackingUp else { return }
        isBackingUp = true
        let store: TrackerStore = app.store
        let name: String = BackupWriter.exportName(today: app.today)
        Task { @MainActor in
            let text = await BackupWriter.exportText(store: store)
            isBackingUp = false
            fileName = name
            file = CSVFile(text: text)
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            BackupWriter.stamp(store: app.store)
            app.toasts.show(BackupWriter.savedToast, symbol: "externaldrive.badge.checkmark")
        case .failure(let error):
            app.toasts.show("Sicherung nicht gespeichert: \(error.localizedDescription)", symbol: "exclamationmark.triangle")
        }
    }
}

/// "Sicherung wird erstellt …" with a small spinner.
struct BackupProgressLabel: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Sicherung wird erstellt …")
        }
    }
}

/// Einstellungen → Deine Daten → "Sicherungen": the automatic backups of this device (date, size, "Teilen…").
struct BackupsPage: View {
    @State private var files: [BackupFile] = []
    @State private var isSmall = false

    var body: some View {
        Form {
            if isSmall {
                Section {
                    Label(BackupWriter.smallNotice, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }
            Section {
                ForEach(files) { file in
                    BackupFileRow(file: file)
                }
            } header: {
                Text("Automatisch auf diesem Gerät")
            } footer: {
                Text(footer)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Sicherungen")
        .inlineNavigationTitle()
        .overlay {
            if files.isEmpty {
                ContentUnavailableView("Noch keine automatische Sicherung", systemImage: "externaldrive",
                                       description: Text(BackupsPage.emptyText))
            }
        }
        .onAppear(perform: refresh)
    }

    private var footer: String {
        "iPhone und Mac legen jede Woche selbst eine Sicherung an. Es bleiben die vier neuesten und je Monat eine für ein halbes Jahr. "
            + BackupWriter.footnote
    }

    static let emptyText = "iPhone und Mac legen jede Woche selbst eine Sicherung an, sobald iCloud auf diesem Gerät abgeglichen hat."

    private func refresh() {
        files = BackupWriter.files()
        isSmall = BackupWriter.lastAutoWasSmall
    }
}

/// "23.11.2026 · 3,7 MB" with "Teilen…".
struct BackupFileRow: View {
    let file: BackupFile

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(file.dateText)
                Text(file.sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            ShareLink(item: file.url) {
                Label("Teilen…", systemImage: "square.and.arrow.up")
            }
        }
        .accessibilityElement(children: .combine)
    }
}
