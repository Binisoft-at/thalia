#if !os(watchOS)
import Foundation
import CoreData
import SwiftData
import BinisoftKit
import ThaliaCore
#if os(macOS)
import Security
#endif

// v10 (TASKS-v10 §1.5.1): the connected apps' files in the shared App Group `group.at.binisoft.shared`.
// Every source writes only its own folder – `<Group>/<App>/exchange/source.json` and one file per day
// `days/<YYYY-MM-DD>.json` – and Thalia reads them on each device into its synced inbox
// (`x.<source>.<day>`, `x.sources`; `TrackerStore.storeInbox`). Thalia writes only
// `<Group>/Thalia/exchange/catalog.json` (structure, no values). Never on the watch (Grundregel 6),
// never for `-Demo`, the practice page or in-memory stores (Grundregel 5), on the Mac only when the
// signed app really has the App Group.

/// What one look into the App Group found.
struct ExchangeScan {
    /// The sources' `source.json` that changed since the last look.
    var sources: [ExchangeSourceInfo] = []
    /// The day files that changed since the last look.
    var files: [ExchangeDayFile] = []
    /// Files that couldn't be used, with the reason ("Theo/2026-11-22.json: …").
    var problems: [String] = []
    /// Every file read without a problem, with its modification date (the next look skips those
    /// unchanged). A refused or partly broken file isn't in here: it is read again on every look, so its
    /// reason stays listed until the source fixes it.
    var seen: [String: Date] = [:]

    var isEmpty: Bool { sources.isEmpty && files.isEmpty }
}

/// Reading and writing the exchange folders (file system only – testable with any folder).
enum ExchangeFolders {
    /// A day file or `source.json` larger than this is left out (a synced setting must stay small –
    /// CloudKit records hold about 1 MB); real files are a few KB.
    static let maxFileSize = 256 * 1024

    /// "Die Datei ist zu groß (über 256 KB) – nicht übernommen."
    static let tooLargeReason = "Die Datei ist zu groß (über \(maxFileSize / 1024) KB) – nicht übernommen."

    /// `<Group>/`: the App Group's root (the parent of Thalia's own folder); nil without the group.
    static func groupRoot() -> URL? {
        AppGroupFolder.url(appName: AppInfo.name)?.deletingLastPathComponent()
    }

    /// Reads `<root>/*/exchange/source.json` and `days/*.json` – only files whose modification date
    /// differs from `known` (path → date). Dotfiles and temp files are skipped, Thalia's own folder too;
    /// a file whose `source` doesn't belong to its folder, or whose day doesn't match its name, is refused.
    static func scan(root: URL, known: [String: Date] = [:], ownFolder: String = AppInfo.name) -> ExchangeScan {
        var scan = ExchangeScan()
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey, .fileSizeKey]
        guard let folders = try? manager.contentsOfDirectory(at: root, includingPropertiesForKeys: keys,
                                                             options: [.skipsHiddenFiles]) else { return scan }
        for folder in folders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = folder.lastPathComponent
            guard !name.hasPrefix("."), name != ownFolder, isDirectory(folder) else { continue }
            let exchange = BinisoftExchange.exchangeFolder(appFolder: folder)
            guard isDirectory(exchange) else { continue }

            let sourceURL = exchange.appendingPathComponent(BinisoftExchange.sourceFileName)
            if let date = modificationDate(sourceURL) {
                if known[sourceURL.path] == date {
                    scan.seen[sourceURL.path] = date
                } else if isTooLarge(sourceURL) {
                    scan.problems.append("\(name)/\(BinisoftExchange.sourceFileName): \(tooLargeReason)")
                } else if let data = try? Data(contentsOf: sourceURL) {
                    switch ExchangeReader.source(data, folder: name) {
                    case .success(let info):
                        scan.sources.append(info)
                        scan.seen[sourceURL.path] = date
                    case .failure(let error): scan.problems.append("\(name)/\(BinisoftExchange.sourceFileName): \(error.reason)")
                    }
                }
            }

            let days = BinisoftExchange.daysFolder(appFolder: folder)
            let names = ((try? manager.contentsOfDirectory(at: days, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? [])
                .filter { BinisoftExchange.day(fromFileName: $0.lastPathComponent) != nil }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for url in names {
                guard let date = modificationDate(url) else { continue }
                if known[url.path] == date {
                    scan.seen[url.path] = date
                    continue
                }
                if isTooLarge(url) {
                    scan.problems.append("\(name)/\(url.lastPathComponent): \(tooLargeReason)")
                    continue
                }
                guard let data = try? Data(contentsOf: url) else { continue }
                switch ExchangeReader.dayFile(data, folder: name, fileName: url.lastPathComponent) {
                case .success(let read):
                    scan.files.append(read.file)
                    for reason in read.skipped { scan.problems.append("\(name)/\(url.lastPathComponent): \(reason)") }
                    // A file with broken facts is read again next time, so their reasons stay listed.
                    if read.skipped.isEmpty { scan.seen[url.path] = date }
                case .failure(let error):
                    scan.problems.append("\(name)/\(url.lastPathComponent): \(error.reason)")
                }
            }
        }
        return scan
    }

    /// `<root>/Thalia/exchange/catalog.json`
    static func catalogURL(root: URL) -> URL {
        BinisoftExchange.exchangeFolder(appFolder: root.appendingPathComponent(AppInfo.name, isDirectory: true))
            .appendingPathComponent(BinisoftExchange.catalogFileName)
    }

    /// Writes the catalog atomically (temp file and rename).
    static func writeCatalog(_ data: Data, root: URL) throws {
        try BinisoftExchange.write(data, to: catalogURL(root: root))
    }

    static func isDirectory(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }

    static func isTooLarge(_ url: URL) -> Bool {
        let size: Int = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
        return size > maxFileSize
    }

    static func modificationDate(_ url: URL) -> Date? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
    }

    /// The catalog's content without its time stamp (to write it only when the structure changed).
    static func structure(_ catalog: ExchangeCatalog) -> Data? {
        var copy = catalog
        copy.generatedAt = ""
        return try? BinisoftExchange.encode(copy)
    }

    #if os(macOS)
    /// Whether the signed app has the App Group (an unsigned or differently signed Mac build may only get a
    /// path that asks for permission). Call it off the main thread.
    static func hasAppGroupEntitlement(_ group: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let value = SecTaskCopyValueForEntitlement(task, "com.apple.security.application-groups" as CFString, nil)
        guard let groups = value as? [String] else { return false }
        return groups.contains(group)
    }
    #endif
}

/// When Thalia looks into the App Group (§1.5.1): at start (shortly after, not during launch), when the
/// app comes to the foreground, every 5 minutes while it is active, after its own iCloud import (the
/// same hook as `WidgetPublisher`), at the day change and when another app posts
/// `at.binisoft.exchange.changed` (debounced). Reading happens off the main thread; the inbox is stored
/// on the main context. The App creates it for the real store only and calls `start()` and
/// `setActive(_:)`.
@MainActor
final class ExchangeMonitor {
    /// Posted on the main queue when the Darwin notification `at.binisoft.exchange.changed` arrives.
    nonisolated static let changedNotification = Notification.Name("thalia.exchange.changed")
    /// Pause after a trigger before reading (several apps write at once).
    nonisolated static let debounce: UInt64 = 2_000_000_000
    /// The first look waits a little longer, so it never slows the launch.
    nonisolated static let firstDelay: UInt64 = 5_000_000_000
    /// While active: a look every 5 minutes.
    nonisolated static let interval: UInt64 = 300_000_000_000

    private let container: ModelContainer
    private let isDemo: Bool
    private var observers: [NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var reading = false
    /// A trigger came while reading: look again afterwards.
    private var again = false
    private var isStarted = false
    private var known: [String: Date] = [:]
    private var lastCatalog: Data?
    /// nil until checked (the Mac: off the main thread, after launch).
    private var hasGroup: Bool?

    /// The last look: when, what it stored, what couldn't be read (Einstellungen → "Verbundene Apps").
    private(set) var lastRead: Date?
    private(set) var lastProblems: [String] = []

    init(container: ModelContainer, isDemo: Bool = false) {
        self.container = container
        self.isDemo = isDemo
    }

    /// Only the real store reads and writes the App Group – never `-Demo`, the practice page or an
    /// in-memory store.
    var isEnabled: Bool {
        !isDemo && !container.configurations.contains { $0.isStoredInMemoryOnly }
    }

    func start() {
        guard isEnabled, !isStarted else { return }
        isStarted = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSoon() }
        })
        observers.append(center.addObserver(forName: ExchangeMonitor.changedNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshSoon() }
        })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event, event.type == .import, event.endDate != nil else { return }
            MainActor.assumeIsolated { self?.refreshSoon() }
        })
        ExchangeMonitor.observeDarwinNotification()
        refreshSoon(after: ExchangeMonitor.firstDelay)
    }

    /// The app became active (timer on, a look now) or went to the background (timer off).
    func setActive(_ active: Bool) {
        guard isEnabled else { return }
        timer?.cancel()
        timer = nil
        guard active else { return }
        refreshSoon()
        timer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: ExchangeMonitor.interval)
                guard !Task.isCancelled else { return }
                self?.refreshNow()
            }
        }
    }

    /// A look shortly (triggers come in bursts).
    func refreshSoon(after delay: UInt64 = ExchangeMonitor.debounce) {
        guard isEnabled else { return }
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.refreshNow()
        }
    }

    /// Reads the App Group now (off the main thread), stores what changed and writes the catalog.
    func refreshNow() {
        guard isEnabled else { return }
        guard !reading else {
            again = true
            return
        }
        reading = true
        let known = self.known
        let checked = hasGroup
        let group = AppIdentifiers.main.sharedAppGroup ?? BinisoftExchange.appGroup
        Task.detached(priority: .utility) {
            let allowed = checked ?? ExchangeMonitor.mayUseGroup(group)
            let root: URL? = allowed ? ExchangeFolders.groupRoot() : nil
            let scan: ExchangeScan? = root.map { ExchangeFolders.scan(root: $0, known: known) }
            await MainActor.run { [weak self] in
                self?.finish(scan: scan, root: root, allowed: allowed)
            }
        }
    }

    private func finish(scan: ExchangeScan?, root: URL?, allowed: Bool) {
        reading = false
        hasGroup = allowed
        if again {
            again = false
            refreshSoon()
        }
        guard let root, let scan else { return }
        let store = TrackerStore(context: container.mainContext)
        if !scan.isEmpty { store.storeInbox(files: scan.files, sources: scan.sources) }
        known = scan.seen
        lastRead = Date()
        // A refused file is read again on every look (its reason stays listed) – logged only when it is new.
        if scan.problems != lastProblems {
            for problem in scan.problems.prefix(5) { AppLog.warning("Exchange: \(problem)", category: "exchange") }
        }
        lastProblems = scan.problems
        writeCatalog(store: store, root: root)
    }

    /// `catalog.json` when it is switched on and its structure changed (written off the main thread);
    /// switched off, an earlier catalog goes, so no app reads a stale one.
    private func writeCatalog(store: TrackerStore, root: URL) {
        let url = ExchangeFolders.catalogURL(root: root)
        guard store.providesCatalog else {
            lastCatalog = nil
            if FileManager.default.fileExists(atPath: url.path) { try? FileManager.default.removeItem(at: url) }
            return
        }
        let catalog = store.exchangeCatalog()
        let structure = ExchangeFolders.structure(catalog)
        guard structure != lastCatalog || !FileManager.default.fileExists(atPath: url.path),
              let data = try? BinisoftExchange.encode(catalog) else { return }
        lastCatalog = structure
        Task.detached(priority: .utility) {
            do {
                try ExchangeFolders.writeCatalog(data, root: root)
            } catch {
                AppLog.warning("Catalog not written: \(error.localizedDescription)", category: "exchange")
            }
        }
    }

    /// The App Group may be used: on the Mac only when the signed app has it (a missing entitlement would
    /// make macOS ask for access to other apps' data); elsewhere when the build has a group.
    nonisolated static func mayUseGroup(_ group: String) -> Bool {
        #if os(macOS)
        return ExchangeFolders.hasAppGroupEntitlement(group)
        #else
        return !group.isEmpty
        #endif
    }

    private static var observesDarwin = false
    /// Identifies the observer at the Darwin notification center (once per process).
    private static let darwinToken = DarwinToken()

    /// `at.binisoft.exchange.changed` from another app → `changedNotification` on the main queue.
    private static func observeDarwinNotification() {
        #if os(iOS) || os(macOS)
        guard !observesDarwin else { return }
        observesDarwin = true
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: ExchangeMonitor.changedNotification, object: nil)
            }
        }
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(darwinToken).toOpaque())
        CFNotificationCenterAddObserver(center, observer, callback, BinisoftExchange.changedNotification as CFString, nil,
                                        .deliverImmediately)
        #endif
    }
}

/// The observer's identity at the Darwin notification center.
private final class DarwinToken {}
#endif
