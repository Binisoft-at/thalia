import Foundation
import AppIntents

/// A destination asked for before the window existed (Shortcuts and controls that open the app).
@MainActor
enum PendingRoute {
    static var destination: String?

    /// Opens a screen: right away when the app runs, at launch otherwise.
    static func open(_ destination: String) {
        self.destination = destination
        NotificationCenter.default.post(name: .thaliaRoute, object: destination)
    }
}

extension Notification.Name {
    static let thaliaRoute = Notification.Name("thalia.route")
}

/// Opens Thalia right at "Power-Hours erfassen" – the Control Center button (U11) and a Shortcut.
/// Compiled into the app and the widget extension, so the control can run it in the app.
struct OpenPowerHoursIntent: AppIntent {
    static let title: LocalizedStringResource = "Power-Hours erfassen"
    static let description: IntentDescription? = IntentDescription("Öffnet Thalia direkt beim Erfassen von Power-Hours.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingRoute.open("work")
        return .result()
    }
}

/// Opens Thalia at "Erfassen" (Control Center, F3).
struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "In Thalia erfassen"
    static let description: IntentDescription? = IntentDescription("Öffnet Thalia im Fenster „Erfassen“: Power-Hours, Ausgabe, Messwert, Notiz …")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingRoute.open("create")
        return .result()
    }
}

/// Opens Thalia at "Ausgaben" with the amount field ready (Control Center, F1/F3).
struct OpenExpenseIntent: AppIntent {
    static let title: LocalizedStringResource = "Ausgabe erfassen"
    static let description: IntentDescription? = IntentDescription("Öffnet Thalia bei den Ausgaben – Betrag eintippen, fertig.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PendingRoute.open("expense")
        return .result()
    }
}
