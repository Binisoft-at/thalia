import Foundation
#if os(iOS)
import UIKit
#endif

/// Names used in texts and file paths. Identifiers live in Config/Base.xcconfig, not here.
enum AppInfo {
    static let name = "Thalia"
    /// What the app keeps, in Bini's words.
    static let dataNoun = "Wochenpläne, Einträge und Reflexionen"
    /// Deep links (widgets, notifications, Shortcuts): thalia://today, thalia://close-day, thalia://week …
    static let urlScheme = "thalia"
}

/// The kind of device in "Geräte im Abgleich" (Settings → iCloud & Daten).
enum SyncDeviceKind {
    @MainActor
    static var current: String {
        #if os(watchOS)
        return "Apple Watch"
        #elseif os(macOS)
        return "Mac"
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #endif
    }
}
