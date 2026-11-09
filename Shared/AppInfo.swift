import Foundation

/// Names used in texts and file paths. Identifiers live in Config/Base.xcconfig, not here.
enum AppInfo {
    static let name = "Thalia"
    /// What the app keeps, in Bini's words.
    static let dataNoun = "Wochenpläne, Einträge und Reflexionen"
    /// Deep links (widgets, notifications, Shortcuts): thalia://today, thalia://close-day, thalia://week …
    static let urlScheme = "thalia"
}
