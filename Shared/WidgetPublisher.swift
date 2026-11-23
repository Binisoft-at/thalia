import Foundation
import CoreData
import SwiftData
import BinisoftKit
import ThaliaCore
#if os(iOS)
import UIKit
#endif

/// Writes the widget snapshot after changes, bundled: 1.5 s after the last save, right away at
/// midnight, and after an iCloud import (changes from other devices – the watch complication needs
/// them). Only iPhone, iPad and Watch write; the Mac and in-memory stores (demo, tour) never do.
/// App and Watch only – not compiled into the widget extensions.
/// v11: the import observer also tells `SyncProgress` about every import (P3.2); `publishIfNeeded` writes only
/// after a change or on a new day (P8.16).
@MainActor
final class WidgetPublisher {
    private let container: ModelContainer
    private var observers: [NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    private var isStarted = false
    /// v11 P8.16: a save or an import since the last write.
    private var isDirty = true
    /// v11 P8.16: the day of the last write.
    private var lastDay: DayKey?

    /// Pause between the last save and the write.
    static let delay: UInt64 = 1_500_000_000

    init(container: ModelContainer) {
        self.container = container
    }

    /// Writing makes sense on this device and store.
    private var isEnabled: Bool {
        #if os(macOS)
        return false
        #else
        return !container.configurations.contains { $0.isStoredInMemoryOnly }
        #endif
    }

    func start() {
        guard isEnabled, !isStarted else { return }
        isStarted = true
        let center = NotificationCenter.default
        let container: ModelContainer = self.container
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.isDirty = true
                self?.publishSoon()
            }
        })
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishNow() }
        })
        // v11 P8.14, P8.15, P8.16 and P3.2 (2) – one observer (KR3-22). The Mac notes its imports in AppModel.
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated {
                // P3.2: every import, its start and its end – the first sync counts as done 60 s after the last one.
                SyncProgress.noteImport(event, container: container)
                // Only a finished import brings other devices' changes.
                let finishedImport = event.type == .import && event.endDate != nil
                guard finishedImport, let self else { return }
                self.isDirty = true
                self.publishAfterImport()
            }
        })
        publishSoon()
    }

    /// v11 P8.14, P8.15: after an iCloud import. In the foreground the iPhone writes once, bundled (`afterSync`
    /// writes anyway, and its write cancels this one); in the background (also `.inactive`) at once – iOS may
    /// suspend the app before a delayed write – and once more after the main context has merged. The watch writes
    /// at once and again: the complication shows other devices' changes without opening the app. An unchanged
    /// snapshot is skipped (`WidgetBridge.publish`), so the second write costs no reload.
    private func publishAfterImport() {
        #if os(iOS)
        if UIApplication.shared.applicationState == .active {
            publishSoon()
        } else {
            publishNow()
            publishSoon()
        }
        #else
        publishNow()
        publishSoon()
        #endif
    }

    /// v11 P8.16: writes only after a save or an import since the last write, or on a new day – raising and
    /// lowering the wrist builds no week.
    func publishIfNeeded() {
        guard isDirty || lastDay != DayKey.today() else { return }
        publishNow()
    }

    /// Bundles writes: the snapshot is written once things have been quiet for 1.5 s.
    func publishSoon() {
        guard isEnabled else { return }
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: WidgetPublisher.delay)
            guard !Task.isCancelled else { return }
            self?.publishNow()
        }
    }

    /// Writes the snapshot now (leaving the app, day change, after a sync).
    func publishNow() {
        pending?.cancel()
        pending = nil
        guard isEnabled else { return }
        let today = DayKey.today()
        TrackerStore(context: container.mainContext).publishWidget(today: today)
        isDirty = false
        lastDay = today
    }
}
