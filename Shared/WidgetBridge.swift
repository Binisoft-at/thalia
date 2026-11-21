import Foundation
import BinisoftKitCore
import ThaliaCore
#if os(iOS) || os(watchOS)
import WidgetKit
#endif

/// v8: sick and holiday days in the snapshot – read from `dayType`, so no new field is needed and
/// older snapshots stay readable.
extension TodaySummary {
    /// Today is "Krank" or "Urlaub" (`DayTypes.isExcused`): nothing is open, the day doesn't count.
    var isExcusedDay: Bool {
        isNewDay != true && DayTypes.isExcused(dayType ?? "")
    }

    /// "Krank" or "Urlaub".
    var excusedName: String {
        (dayType ?? "").lowercased().contains("krank") ? "Krank" : "Urlaub"
    }

    /// "Krank – zählt nicht".
    var excusedText: String { "\(excusedName) – zählt nicht" }
}

/// The widget snapshot in the shared App Group: `<group>/Thalia/today.json`.
/// Only this small summary goes there – never the app's data. Ticks from the widget wait in
/// `<group>/Thalia/pending-marks.json` until the app applies them (R87).
/// Compiled into the app, the watch app and both widget extensions: Foundation, BinisoftKitCore,
/// ThaliaCore and WidgetKit only.
enum WidgetBridge {
    nonisolated(unsafe) private static var lastPublished: TodaySummary?

    static let pendingFileName = "pending-marks.json"

    /// Widgets and complications show the new snapshot (iOS and watchOS, R86).
    static func reloadTimelines() {
        #if os(iOS) || os(watchOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    static var folder: URL? {
        guard let group = AppIdentifiers.main.sharedAppGroup,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return nil }
        return root.appendingPathComponent(AppInfo.name, isDirectory: true)
    }

    /// Writes the summary and reloads the widgets when something changed.
    static func publish(_ summary: TodaySummary) {
        guard !summary.hasSameContent(as: lastPublished), let folder else { return }
        do {
            try SnapshotFile<TodaySummary>(folder: folder, name: TodaySummary.fileName).write(summary)
            lastPublished = summary
            reloadTimelines()
        } catch {
            AppLog.warning("Widget snapshot not written: \(error.localizedDescription)", category: "widgets")
        }
    }

    static func read() -> TodaySummary? {
        guard let folder else { return nil }
        return SnapshotFile<TodaySummary>(folder: folder, name: TodaySummary.fileName).read()
    }

    // MARK: Ticks from the widget (R87)

    private static func pendingFile() -> SnapshotFile<[WidgetMarkAction]>? {
        folder.map { SnapshotFile<[WidgetMarkAction]>(folder: $0, name: pendingFileName) }
    }

    /// Runs `body` while no other process (app, widget) writes the queue file.
    private static func coordinated(_ url: URL, _ body: () -> Void) {
        var error: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: [], error: &error) { _ in body() }
        if let error {
            AppLog.warning("Widget queue not coordinated: \(error.localizedDescription)", category: "widgets")
        }
    }

    /// Queues a tick for the app (when the widget's intent can't reach the app's data).
    static func enqueue(_ action: WidgetMarkAction) {
        guard let file = pendingFile() else { return }
        coordinated(file.url) {
            var queue = file.read() ?? []
            queue.removeAll { $0.itemKey == action.itemKey && $0.dayKey == action.dayKey }
            queue.append(action)
            do {
                try file.write(queue)
            } catch {
                AppLog.warning("Widget tick not queued: \(error.localizedDescription)", category: "widgets")
            }
        }
    }

    /// Reads and empties the queue (the app applies the ticks, oldest first).
    static func drainPending() -> [WidgetMarkAction] {
        guard let file = pendingFile() else { return [] }
        var queue: [WidgetMarkAction] = []
        coordinated(file.url) {
            queue = file.read() ?? []
            if FileManager.default.fileExists(atPath: file.url.path) {
                try? FileManager.default.removeItem(at: file.url)
            }
        }
        return queue.sorted { $0.createdAt < $1.createdAt }
    }

    /// Shows the tick right away: reads the snapshot, marks the item done, writes it back and
    /// reloads the widgets. The app's next snapshot replaces it with the real state.
    static func applyOptimistic(_ action: WidgetMarkAction) {
        guard let folder, var summary = read() else { return }
        if summary.dayKey == action.dayKey {
            summary = summary.markingDone(itemKey: action.itemKey)
        } else if let next = summary.nextDay?.first, next.dayKey == action.dayKey {
            summary.nextDay = [next.markingDone(itemKey: action.itemKey)]
        } else {
            return
        }
        do {
            try SnapshotFile<TodaySummary>(folder: folder, name: TodaySummary.fileName).write(summary)
            // The app's next snapshot must be written even if it equals the one before the tick.
            lastPublished = nil
            reloadTimelines()
        } catch {
            AppLog.warning("Widget snapshot not updated: \(error.localizedDescription)", category: "widgets")
        }
    }
}
