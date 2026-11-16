import Foundation
import CoreData
import SwiftData
import BinisoftKit
import ThaliaCore

/// Writes the widget snapshot after changes, bundled: 1.5 s after the last save, right away at
/// midnight, and after an iCloud import (changes from other devices – the watch complication needs
/// them). Only iPhone, iPad and Watch write; the Mac and in-memory stores (demo, tour) never do.
/// App and Watch only – not compiled into the widget extensions.
@MainActor
final class WidgetPublisher {
    private let container: ModelContainer
    private var observers: [NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    private var isStarted = false

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
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishSoon() }
        })
        observers.append(center.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.publishNow() }
        })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            // Only a finished import brings other devices' changes.
            let finishedImport = event.type == .import && event.endDate != nil
            guard finishedImport else { return }
            MainActor.assumeIsolated { self?.publishSoon() }
        })
        publishSoon()
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
        TrackerStore(context: container.mainContext).publishWidget(today: DayKey.today())
    }
}
