import SwiftUI
import SwiftData
import UserNotifications
import BinisoftKit
import ThaliaCore

@main
struct ThaliaApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MainWindowGuard.self) private var windowGuard
    #endif
    @State private var app: AppModel
    @State private var health = HealthService()

    init() {
        AppLog.bootstrap(appName: AppInfo.name)
        BinisoftTips.configure()
        let opened = Persistence.shared
        let model = AppModel(container: opened.container, mode: opened.mode)
        _app = State(initialValue: model)
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        NotificationRouter.shared.route = { destination in model.route(destination) }
        if !model.launch.isDemo {
            Task { @MainActor in
                _ = await ReminderScheduler.apply(ReminderScheduler.load())
            }
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .environment(app)
                .environment(health)
                .modelContainer(app.container)
                .appearanceFromSettings()
                .tint(Brand.accent)
        }
        .defaultSize(width: 1180, height: 820)
        #if os(macOS)
        // macOS may otherwise finish launching without the main window (see MainWindowGuard).
        .defaultLaunchBehavior(.presented)
        #endif
        .commands {
            ThaliaCommands(app: app)
        }

        #if os(macOS)
        Settings {
            NavigationStack {
                SettingsView()
            }
            .environment(app)
            .environment(health)
            .modelContainer(app.container)
            .appearanceFromSettings()
            .frame(minWidth: 540, minHeight: 640)
        }
        #endif
    }
}

/// Menu bar commands and keyboard shortcuts (Mac, iPad with a keyboard). While the tour is open
/// they act on its practice page.
struct ThaliaCommands: Commands {
    let app: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Power-Hours erfassen…") {
                let target = app.commandTarget
                target.sheet = .work(WorkDraft(day: target.selectedDay))
            }
            .keyboardShortcut("n")
            Button("Erstellen…") { app.commandTarget.sheet = .create }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("Notiz…") {
                let target = app.commandTarget
                target.sheet = .note(nil, target.selectedDay)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            Button("Messwert erfassen…") {
                let target = app.commandTarget
                target.sheet = .measure(code: "", day: target.selectedDay)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            Divider()
            Button("Tag abschließen…") {
                let target = app.commandTarget
                target.sheet = .closeDay(target.selectedDay)
            }
            .keyboardShortcut(.return, modifiers: [.command])
            Button("Woche abschließen…") {
                let target = app.commandTarget
                target.sheet = .closeWeek(target.selectedWeek)
            }
            Divider()
            Button("Wochenplan importieren…") { app.commandTarget.sheet = .importPlan(prompt: true) }
                .keyboardShortcut("i", modifiers: [.command, .shift])
        }
        CommandMenu("Gehe zu") {
            Button("Heute") { app.sidebar = .today; app.tab = .today }
                .keyboardShortcut("1")
            Button("Woche") { app.sidebar = .week; app.tab = .week }
                .keyboardShortcut("2")
            Button("Ziele") { app.sidebar = .goals; app.tab = .goals }
                .keyboardShortcut("3")
            Button("Rückblick") { app.sidebar = .review; app.tab = .review }
                .keyboardShortcut("4")
            Divider()
            Button("Heute im Blick") { app.commandTarget.sheet = .dayOverview(app.commandTarget.today) }
                .keyboardShortcut("0")
            Button("Fokus (Power-Hours)") { app.commandTarget.sheet = .focus(app.commandTarget.today.week) }
                .keyboardShortcut("5")
            Button("Ausgaben") { app.commandTarget.sheet = .expenses(app.commandTarget.today) }
                .keyboardShortcut("6")
            Divider()
            Button("Vorheriger Tag") { app.selectedDay = app.selectedDay.adding(days: -1) }
                .keyboardShortcut("[")
            Button("Nächster Tag") { app.selectedDay = app.selectedDay.adding(days: 1) }
                .keyboardShortcut("]")
            Button("Zu heute") {
                app.refreshToday()
                app.selectedDay = app.today
                app.selectedWeek = app.today.week
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Zuletzt gelöscht") { app.sheet = .trash }
        }
        CommandGroup(replacing: .help) {
            Button("Thalia-Tour") { app.startTour() }
            Button("Wie wird gerechnet?") { app.sheet = .explainer(.scoring) }
            Button("Power-Hours") { app.sheet = .explainer(.powerHours) }
        }
    }
}
