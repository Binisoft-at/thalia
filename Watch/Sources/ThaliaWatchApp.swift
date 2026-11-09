import SwiftUI
import SwiftData
import BinisoftKit

/// The watch app syncs on its own through the app's iCloud container (same store code as the phone).
@main
struct ThaliaWatchApp: App {
    let container: ModelContainer

    init() {
        AppLog.bootstrap(appName: AppInfo.name)
        container = Persistence.shared.container
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .modelContainer(container)
    }
}
