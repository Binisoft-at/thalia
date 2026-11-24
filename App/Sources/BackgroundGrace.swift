import Foundation
import CoreData
import BinisoftKit
#if os(iOS)
import UIKit
#endif

/// v11 P4.14: a little background time on the iPhone, so that a save from Siri, a Shortcut or the widget's ✓
/// reaches iCloud before iOS suspends Thalia – the other devices see it without the app being opened. Also for
/// `AppModel.afterSync` after a push from iCloud (P4.11) and the weekly automatic backup (P3.13, `run`).
/// The Mac keeps running in the background: there every call does nothing, so the same calls compile in
/// `App/Sources/Intents.swift`, which is also built for macOS (§0.10). App target only – the widget extensions
/// have no `UIApplication.shared`; `Shared/WidgetActions.swift` never calls this.
@MainActor
enum BackgroundGrace {
    /// Fire and forget, right after saving (take `saveDate` just before the save): a background task that ends
    /// at the first CloudKit export that started at or after `saveDate` and has ended, after `timeout`, or when
    /// iOS ends the background time – whichever comes first. Several holds can run at once. macOS: nothing.
    /// `Swift.Duration` here and below: never MacTypes' C typedef `Duration` (SInt32), which the Mac SDK also has.
    static func holdForExport(after saveDate: Date, timeout: Swift.Duration = .seconds(20)) {
        #if os(iOS)
        let hold = ExportHold(saveDate: saveDate)
        holds[ObjectIdentifier(hold)] = hold
        hold.start(timeout: timeout)
        #endif
    }

    /// v11 P4.11: background time for `AppModel.afterSync` after a push from iCloud (it runs 1.5 s after the
    /// import ended – without this iOS may suspend Thalia first, and the evening reminder of a day closed on the
    /// Mac comes anyway). At most one at a time: a new import while one runs begins nothing.
    static func beginAfterSync() {
        #if os(iOS)
        guard afterSyncTask == .invalid else { return }
        afterSyncTask = UIApplication.shared.beginBackgroundTask(withName: "Thalia after sync") {
            // iOS calls this on the main thread when the background time runs out.
            MainActor.assumeIsolated { BackgroundGrace.endAfterSync() }
        }
        #endif
    }

    /// Ends the background time of `beginAfterSync` – called only by the task that really ran `afterSync`, or
    /// when iOS ends the time (never by a cancelled task). Nothing when none runs.
    static func endAfterSync() {
        #if os(iOS)
        guard afterSyncTask != .invalid else { return }
        let task = afterSyncTask
        afterSyncTask = .invalid
        UIApplication.shared.endBackgroundTask(task)
        #endif
    }

    /// v11 P3.13: `work` with a little background time on the iPhone (the weekly backup when Thalia goes to the
    /// background); the Mac runs it as it is.
    static func run(_ name: String, _ work: @escaping @MainActor () async -> Void) {
        #if os(iOS)
        let grace = GraceTask(name: name)
        Task { @MainActor in
            await work()
            grace.end()
        }
        #else
        Task { @MainActor in await work() }
        #endif
    }

    #if os(iOS)
    /// Holds that are running, kept alive until they end.
    fileprivate static var holds: [ObjectIdentifier: ExportHold] = [:]
    /// The background task of `beginAfterSync` (P4.11).
    private static var afterSyncTask: UIBackgroundTaskIdentifier = .invalid
    #endif
}

#if os(iOS)
/// The background task of one `BackgroundGrace.run`: ends after the work, or when iOS ends the time.
@MainActor
private final class GraceTask {
    private var id: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        id = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// One `holdForExport`: its background task, the export observer and the time limit.
@MainActor
private final class ExportHold {
    let saveDate: Date
    private var taskID: UIBackgroundTaskIdentifier = .invalid
    private var observer: NSObjectProtocol?
    private var timer: Task<Void, Never>?
    private var isDone = false

    init(saveDate: Date) {
        self.saveDate = saveDate
    }

    func start(timeout: Swift.Duration) {
        taskID = UIApplication.shared.beginBackgroundTask(withName: "Thalia iCloud export") { [weak self] in
            // iOS calls this on the main thread when the background time runs out.
            MainActor.assumeIsolated { self?.end("background time over") }
        }
        guard taskID != .invalid else {
            end("no background time")
            return
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .export, event.endDate != nil else { return }
            let started: Date = event.startDate
            Task { @MainActor in self?.exportEnded(startedAt: started) }
        }
        timer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.end("timeout")
        }
    }

    private func exportEnded(startedAt started: Date) {
        guard started >= saveDate else { return }
        end("exported")
    }

    func end(_ reason: String) {
        guard !isDone else { return }
        isDone = true
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        timer?.cancel()
        timer = nil
        if taskID != .invalid {
            UIApplication.shared.endBackgroundTask(taskID)
            taskID = .invalid
        }
        BackgroundGrace.holds[ObjectIdentifier(self)] = nil
        AppLog.info("Export hold ended: \(reason)", category: "sync")
    }
}
#endif
