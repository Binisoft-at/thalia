#if os(iOS)
import Foundation
import AppIntents
import ThaliaCore

/// R87: ✓ for an open item straight from the medium and large widget. A `LiveActivityIntent`, so
/// `perform()` runs in the app's process: the app's handler writes the mark. Should it run in the
/// widget extension after all (no handler), the tick waits in the App Group queue until the app
/// starts. Either way the widget shows the tick at once (optimistic snapshot).
/// Compiled into the iOS app and the iOS widget extension.
struct MarkDoneFromWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Punkt erledigt"
    static let isDiscoverable: Bool = false

    /// "2026-W47|1.1-03"
    @Parameter(title: "Punkt")
    var itemKey: String

    /// "2026-11-16"
    @Parameter(title: "Tag")
    var dayKey: String

    init() {}

    init(itemKey: String, dayKey: String) {
        self.itemKey = itemKey
        self.dayKey = dayKey
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        let action = WidgetMarkAction(itemKey: itemKey, dayKey: dayKey)
        // The optimistic row first, so a real snapshot written by the handler is never overwritten.
        WidgetBridge.applyOptimistic(action)
        if let handler = WidgetActions.handler {
            handler(action)
        } else {
            WidgetBridge.enqueue(action)
        }
        return .result()
    }
}

/// Set by the app at launch (P2): applies a widget tick to the store.
@MainActor
enum WidgetActions {
    static var handler: ((WidgetMarkAction) -> Void)?
}
#endif
