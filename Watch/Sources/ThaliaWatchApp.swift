import SwiftUI
import SwiftData
import BinisoftKit

/// The watch app syncs on its own through the app's iCloud container (same store code as the phone).
@main
struct ThaliaWatchApp: App {
    let container: ModelContainer
    /// Keeps the complication's snapshot fresh (R84, R86): after own changes, after each iCloud
    /// import and whenever the app becomes active.
    let publisher: WidgetPublisher
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppLog.bootstrap(appName: AppInfo.name)
        let opened = Persistence.shared.container
        container = opened
        publisher = WidgetPublisher(container: opened)
        publisher.start()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .onChange(of: scenePhase) { _, phase in
                    // .active: catch up after time away; .inactive/.background: write the pending
                    // snapshot before watchOS suspends the app (wrist down).
                    publisher.publishNow()
                    if phase == .active {
                        TrackerStore(context: container.mainContext).recordDeviceSeen(kind: SyncDeviceKind.current)
                    }
                }
        }
        .modelContainer(container)
    }
}
