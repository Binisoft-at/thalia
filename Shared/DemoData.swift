import Foundation
import SwiftData
import ThaliaCore

/// Sample data. It lives only in separate in-memory stores (`-Demo` launches for screenshots, the
/// tour's practice page) and never syncs. The content comes from ThaliaCore `Demo` (tested on Linux).
/// v10: its records – segments, results, books and readings, category week scores, the inbox of the
/// connected app "Demo" – come as `record` rows of the document, so no App Group is needed
/// (Grundregel 5: the real store never gets sample data).
@MainActor
enum DemoData {
    /// `-Demo` launches: this week up to today, last week closed, earlier weeks as paper scores.
    static func seed(_ context: ModelContext) {
        seed(Demo.content(today: .today()), into: context)
    }

    /// The tour's practice page: this week only.
    static func seedPractice(_ context: ModelContext) {
        seed(Demo.content(today: .today(), history: false), into: context)
    }

    private static func seed(_ content: Demo.Content, into context: ModelContext) {
        let store = TrackerStore(context: context)
        // The demo's segments and results belong to its goal year (the foundation year while today is in it).
        if store.goalPeriod.start != content.records.period.start { store.setGoalPeriod(content.records.period) }
        store.seed(content)
    }
}
