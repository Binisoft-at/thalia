import Foundation
import SwiftData
import ThaliaCore

/// Sample data. It lives only in separate in-memory stores (`-Demo` launches for screenshots, the
/// tour's practice page) and never syncs. The content comes from ThaliaCore `Demo` (tested on Linux).
@MainActor
enum DemoData {
    /// `-Demo` launches: this week up to today, last week closed, earlier weeks as paper scores.
    static func seed(_ context: ModelContext) {
        TrackerStore(context: context).seed(Demo.content(today: .today()))
    }

    /// The tour's practice page: this week only.
    static func seedPractice(_ context: ModelContext) {
        TrackerStore(context: context).seed(Demo.content(today: .today(), history: false))
    }
}
