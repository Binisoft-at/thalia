import Foundation
import BinisoftKitCore
import ThaliaCore
#if os(iOS)
import WidgetKit
#endif

/// The widget snapshot in the shared App Group: `<group>/Thalia/today.json`.
/// Only this small summary goes there – never the app's data.
enum WidgetBridge {
    nonisolated(unsafe) private static var lastPublished: TodaySummary?

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
            #if os(iOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            AppLog.warning("Widget snapshot not written: \(error.localizedDescription)", category: "widgets")
        }
    }

    static func read() -> TodaySummary? {
        guard let folder else { return nil }
        return SnapshotFile<TodaySummary>(folder: folder, name: TodaySummary.fileName).read()
    }
}
