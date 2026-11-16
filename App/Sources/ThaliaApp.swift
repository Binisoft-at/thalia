import SwiftUI
import SwiftData
import UserNotifications
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
#endif

@main
struct ThaliaApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MainWindowGuard.self) private var windowGuard
    #endif
    @State private var app: AppModel
    @State private var health = HealthService()
    #if os(macOS)
    /// Thalia in the menu bar (R96), on by default, switch in Settings.
    @AppStorage(MenuBarSettings.enabledKey) private var menuBarEnabled = true
    #endif

    init() {
        AppLog.bootstrap(appName: AppInfo.name)
        #if os(macOS)
        NSWindow.allowsAutomaticWindowTabbing = false
        #if DEBUG
        LaunchDiagnostics.start()
        #endif
        #endif
        BinisoftTips.configure()
        let opened = Persistence.shared
        let model = AppModel(container: opened.container, mode: opened.mode)
        _app = State(initialValue: model)
        UNUserNotificationCenter.current().delegate = NotificationRouter.shared
        NotificationRouter.shared.route = { destination in model.route(destination) }
        #if os(iOS)
        // ✓ from the widget runs in the app's process when it can (R87).
        WidgetActions.handler = { action in model.applyWidgetAction(action) }
        #endif
        if !model.launch.isDemo {
            Task { @MainActor in
                // No permission prompt at launch: that comes after the tour or in Settings (R80).
                _ = await ReminderScheduler.apply(ReminderScheduler.load(), authorize: false,
                                                  isClosed: { model.isDayClosed($0) })
            }
        }
    }

    var body: some Scene {
        let _ = diagBody("App")
        #if os(macOS)
        // One main window (R30): the File menu has no "New Window" (⌘N stays power-hours), tabs
        // are off, and every "open Thalia" goes through MainWindow.show, which brings the existing
        // window to the front. A single `Window` scene did not open at launch next to the menu bar
        // extra – not even after a reopen event – so this stays a WindowGroup.
        WindowGroup(id: "main") {
            mainContent
        }
        .defaultSize(width: 1180, height: 820)
        // macOS may otherwise finish launching without the main window (see MainWindowGuard).
        .defaultLaunchBehavior(.presented)
        .commands {
            ThaliaCommands(app: app)
        }

        Settings {
            NavigationStack {
                SettingsView(inSettingsWindow: true)
            }
            .modifier(SettingsToastLayer(app: app))
            .environment(app)
            .environment(health)
            .modelContainer(app.container)
            .appearanceFromSettings()
            .frame(minWidth: 540, minHeight: 640)
        }

        MenuBarExtra(isInserted: $menuBarEnabled) {
            MenuBarContent()
                .environment(app)
                .environment(health)
                .modelContainer(app.container)
                .appearanceFromSettings()
                .tint(Brand.accent)
        } label: {
            let _ = diagBody("MenuBarLabel")
            MenuBarLabel(title: app.menuBarTitle)
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup(id: "main") {
            mainContent
        }
        .defaultSize(width: 1180, height: 820)
        .commands {
            ThaliaCommands(app: app)
        }
        #endif
    }

    private var mainContent: some View {
        RootView()
            .environment(app)
            .environment(health)
            .modelContainer(app.container)
            .appearanceFromSettings()
            .tint(Brand.accent)
    }
}

#if os(macOS)
/// The one main window on the Mac (R30): shows the existing window if there is one, and opens a
/// new one only when it was closed.
@MainActor
enum MainWindow {
    static var existing: NSWindow? {
        NSApp.windows.first { window in
            (window.identifier?.rawValue.hasPrefix("main") ?? false) && (window.isVisible || window.isMiniaturized)
        }
    }

    static func show(_ openWindow: OpenWindowAction) {
        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate()
    }
}

/// The Mac Settings window is a toast layer while it is in front: import and archive open inside
/// it (R24), so their "Widerrufen" shows there and not behind it on the main window (R13).
/// The host sits on an empty overlay, so the settings content keeps its state when it toggles.
private struct SettingsToastLayer: ViewModifier {
    let app: AppModel
    @Environment(\.controlActiveState) private var activeState

    func body(content: Content) -> some View {
        content.overlay {
            if activeState != .inactive {
                Color.clear.toastHost(app)
            }
        }
    }
}
#endif

/// Menu bar commands and keyboard shortcuts (Mac, iPad with a keyboard). While the tour is open
/// they act on its practice page. A command that opens a sheet is disabled – and does nothing –
/// while a sheet holds unsaved input (R14); ⌘↩ / ⇧⌘↩ in the matching closing sheet close (R39).
struct ThaliaCommands: Commands {
    let app: AppModel

    var body: some Commands {
        let _ = diagBody("Commands")
        CommandGroup(replacing: .newItem) {
            Button("Power-Hours erfassen…") { present { .work(WorkDraft(day: $0.captureDay)) } }
                .keyboardShortcut("n")
                .disabled(isBlocked)
            Button("Erfassen…") { present { _ in .create } }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(isBlocked)
            Button("Notiz…") { present { .note(nil, $0.captureDay) } }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(isBlocked)
            Button("Messwert eintragen…") { present { .measure(code: "", day: $0.captureDay) } }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(isBlocked)
            Divider()
            Button("Tag abschließen…") { closeDay() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isBlocked && !isCloseDayOpen)
            Button("Woche abschließen…") { closeWeek() }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(isBlocked && !isCloseWeekOpen)
            Divider()
            Button("Wochenplan importieren…") { present { _ in .importPlan(prompt: true) } }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(isBlocked)
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
            Button("Heute im Blick") { showGlance() }
                .keyboardShortcut("0")
                .disabled(isGlanceBlocked)
            Button("Fokus (Power-Hours)") { present { .focus($0.selectedDay) } }
                .keyboardShortcut("5")
                .disabled(isBlocked)
            Button("Ausgaben") { present { .expenses($0.today) } }
                .keyboardShortcut("6")
                .disabled(isBlocked)
            Divider()
            Button("Vorheriger Tag") { moveDay(by: -1) }
                .keyboardShortcut("[")
                .disabled(!isOnToday)
            Button("Nächster Tag") { moveDay(by: 1) }
                .keyboardShortcut("]")
                .disabled(!isOnToday)
            Button("Zu heute") { app.commandTarget.goToToday() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Vorige Kategorie") { app.commandTarget.moveTodayPage(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(!isOnToday)
            Button("Nächste Kategorie") { app.commandTarget.moveTodayPage(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!isOnToday)
            Divider()
            Button("Vorige Woche") { moveWeek(by: -1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Button("Nächste Woche") { moveWeek(by: 1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Divider()
            Button("Zuletzt gelöscht") { present { _ in .trash } }
                .disabled(isBlocked)
        }
        CommandGroup(replacing: .help) {
            Button("Thalia-Tour") { startTour() }
                .disabled(isBlocked)
            Button("Wie wird gerechnet?") { present { _ in .explainer(.scoring) } }
                .disabled(isBlocked)
            Button("Power-Hours") { present { _ in .explainer(.powerHours) } }
                .disabled(isBlocked)
        }
    }

    // MARK: State

    private var isBlocked: Bool { app.commandTarget.blocksSheetCommands }

    private var isCloseDayOpen: Bool {
        if case .closeDay = app.commandTarget.sheet { return true }
        return false
    }

    private var isCloseWeekOpen: Bool {
        if case .closeWeek = app.commandTarget.sheet { return true }
        return false
    }

    /// Day and category commands only act on Today (R35, R62).
    private var isOnToday: Bool {
        let target = app.commandTarget
        #if os(macOS)
        return (target.sidebar ?? .today) == .today
        #else
        return target.tab == .today
        #endif
    }

    /// The Mac toggles a column, so nothing is lost; iPad opens a sheet.
    private var isGlanceBlocked: Bool {
        #if os(macOS)
        return false
        #else
        return isBlocked
        #endif
    }

    // MARK: Actions

    /// Opens a sheet on the command target – unless a sheet with unsaved input is open (R14).
    private func present(_ make: (AppModel) -> AppSheet) {
        let target = app.commandTarget
        guard !target.blocksSheetCommands else { return }
        target.sheet = make(target)
    }

    /// ⌘↩: in the open day-closing sheet it closes the day (R39), else it opens the right day (R18).
    private func closeDay() {
        let target = app.commandTarget
        if case .closeDay = target.sheet {
            target.closeRequest += 1
            return
        }
        guard !target.blocksSheetCommands else { return }
        target.sheet = .closeDay(target.dayToClose(showing: target.selectedDay))
    }

    /// ⇧⌘↩: the same for the week (R40).
    private func closeWeek() {
        let target = app.commandTarget
        if case .closeWeek = target.sheet {
            target.closeRequest += 1
            return
        }
        guard !target.blocksSheetCommands else { return }
        target.sheet = .closeWeek(target.selectedWeek)
    }

    /// ⌘0 – Mac: the right column next to Today (R59); iPad: the sheet.
    private func showGlance() {
        let target = app.commandTarget
        #if os(macOS)
        target.sidebar = .today
        target.tab = .today
        target.showsGlanceInspector.toggle()
        #else
        guard !target.blocksSheetCommands else { return }
        target.sheet = .dayOverview(target.today)
        #endif
    }

    private func moveDay(by offset: Int) {
        guard isOnToday else { return }
        let target = app.commandTarget
        target.selectedDay = target.selectedDay.adding(days: offset)
    }

    private func moveWeek(by offset: Int) {
        let target = app.commandTarget
        target.selectedWeek = target.selectedWeek.adding(weeks: offset)
    }

    private func startTour() {
        guard !app.commandTarget.blocksSheetCommands else { return }
        app.startTour()
    }
}
