import SwiftUI
import SwiftData
import BinisoftKit
// HEALTHSHARE: `DayKey` for the clean-up below (may stay when the sharing goes).
import ThaliaCore

/// The watch app syncs on its own through the app's iCloud container (same store code as the phone).
@main
struct ThaliaWatchApp: App {
    let container: ModelContainer
    /// Keeps the complication's snapshot fresh (R84, R86): after own changes, after each iCloud
    /// import and whenever the app becomes active.
    let publisher: WidgetPublisher
    @Environment(\.scenePhase) private var scenePhase
    // HEALTHSHARE: +1 when the gate changed – the screens are built again (a static value isn't observed).
    @State private var gateTick = 0

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
                // HEALTHSHARE: the gate changed – shared values come or go (and the complication follows at once).
                .id(gateTick)
                .onReceive(NotificationCenter.default.publisher(for: HealthShareGate.changed)) { _ in
                    gateTick += 1
                    publisher.publishNow()
                }
                // HEALTHSHARE: the gate checked off the start; a freshly confirmed `.denied` (App Store) deletes every
                // `hshare.` record – this clean-up stays (§1.4.3); `.allowed`: the expired days, once a day.
                .task {
                    let fresh: HealthShareGate.State = await HealthShareGate.resolve()
                    // HEALTHSHARE
                    TrackerStore(context: container.mainContext).cleanUpHealthShare(gate: fresh, today: DayKey.today())
                }
                .onChange(of: scenePhase) { _, phase in
                    // .active: catch up after time away; .inactive/.background: write the pending
                    // snapshot before watchOS suspends the app (wrist down) – after the wrist goes down the app
                    // often stays .inactive. v11 P8.16: only when something changed or the day did (no two
                    // week builds for every raise and lower).
                    publisher.publishIfNeeded()
                    if phase == .active {
                        TrackerStore(context: container.mainContext).recordDeviceSeen(kind: SyncDeviceKind.current)
                        // HEALTHSHARE: the expired shared days, at most once a day, also while the app stays alive (§1.4.6).
                        if HealthShareGate.isAllowed {
                            TrackerStore(context: container.mainContext).cleanUpHealthShare(gate: .allowed, today: DayKey.today())
                        }
                    }
                }
        }
        .modelContainer(container)
    }
}
