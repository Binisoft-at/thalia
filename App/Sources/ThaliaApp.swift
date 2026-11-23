import SwiftUI
import SwiftData
import UserNotifications
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
import CoreServices
#endif

@main
struct ThaliaApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MainWindowGuard.self) private var windowGuard
    #endif
    @State private var app: AppModel
    @State private var health = HealthService()

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
                                                  isClosed: { model.skipsEveningReminder($0) })
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
            // v11 P4.6: Darstellung → "Seitenleiste ausblenden".
            SidebarCommands()
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

        MenuBarExtra(isInserted: menuBarInserted) {
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

    #if os(macOS)
    /// Thalia in the menu bar (R96), on by default, switch in Settings. Writes only real changes.
    private var menuBarInserted: Binding<Bool> {
        let model: AppModel = app
        return Binding(get: { model.menuBarEnabled }, set: { model.menuBarEnabled = $0 })
    }
    #endif

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

    /// v11 P4.2: the `openWindow` a command, the menu bar window or the Settings window handed over last – for
    /// `showWithoutEnvironment` while another Thalia window shows (a "reopen" event then opens nothing).
    private static var opener: OpenWindowAction?

    /// v11 P4.2: keeps `openWindow` of a view that stays on screen without the main window (the Settings window).
    static func remember(_ openWindow: OpenWindowAction) {
        opener = openWindow
    }

    static func show(_ openWindow: OpenWindowAction) {
        opener = openWindow
        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
        NSApp.activate()
    }

    /// v11 P4.2: the same where no `openWindow` is at hand (`AppModel.route`, a tapped reminder, a Shortcut):
    /// the existing window comes to the front; when it was closed, Thalia sends itself the "reopen" Apple event a
    /// click on the Dock icon sends, which makes SwiftUI open it (as the kit's MainWindowGuard does at launch –
    /// copied here, the kit stays unchanged).
    static func showWithoutEnvironment() {
        if NSApp.isHidden { NSApp.unhide(nil) }
        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        NSApp.activate()
        // Einstellungen (or another window) in front: AppKit counts "reopen" as handled then and opens nothing –
        // the remembered `openWindow` opens the main window instead.
        if let opener, NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) {
            opener(id: "main")
            return
        }
        let target = NSAppleEventDescriptor(processIdentifier: ProcessInfo.processInfo.processIdentifier)
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        do {
            _ = try event.sendEvent(options: [.noReply], timeout: 2)
        } catch {
            AppLog.warning("Reopen event failed: \(error.localizedDescription)", category: "launch")
        }
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
/// v11 P4.2: on the Mac every command that shows something brings the main window to the front first – or
/// opens it when it was closed (Einstellungen in front, no window at all).
struct ThaliaCommands: Commands {
    let app: AppModel
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif

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
            // v10: the same as "Erfassen" → "Jahresziel eintragen" / "Lesen", on the day shown; v11 P4.21: ⌥⌘J, ⌥⌘L.
            Button("Jahresziel eintragen…") { present { .goalEntry($0.captureDay, resultID: nil) } }
                .keyboardShortcut("j", modifiers: [.command, .option])
                .disabled(isBlocked)
            Button("Lesen…") { present { .reading($0.captureDay, itemID: nil) } }
                .keyboardShortcut("l", modifiers: [.command, .option])
                .disabled(isBlocked)
            Divider()
            Button("Tag abschließen…") { closeDay() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(isBlocked && !isCloseDayOpen)
            Button("Woche abschließen…") { closeWeek() }
                .keyboardShortcut(.return, modifiers: [.command, .shift])
                .disabled(isBlocked && !isCloseWeekOpen)
            Divider()
            // v11 P4.19: nothing that reaches real data while the tour's practice page is open.
            Button("Wochenplan importieren…") { present { _ in .importPlan(prompt: true) } }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .disabled(isBlocked || isTourOpen)
            // v8: past weeks and several weeks as one PDF.
            Button("Vergangene Woche nachtragen…") { present { _ in .importPast(nil) } }
                .disabled(isBlocked || isTourOpen)
            Button("Zeitraum als PDF…") { present { _ in .rangePDF } }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(isBlocked || isTourOpen)
            #if os(macOS)
            // v11 P4.9: the whole backup (the same as Einstellungen → Deine Daten), always of the real data.
            Divider()
            Button("Sicherung erstellen…") { makeBackup() }
                .disabled(isBlocked || isTourOpen || app.isMakingBackup)
            #endif
        }
        CommandMenu("Gehe zu") {
            Button("Heute") { goTo(.today) }
                .keyboardShortcut("1")
            Button("Woche") { goTo(.week) }
                .keyboardShortcut("2")
            Button("Ziele") { goTo(.goals) }
                .keyboardShortcut("3")
            Button("Rückblick") { goTo(.review) }
                .keyboardShortcut("4")
            Divider()
            Button("Heute im Blick") { showGlance() }
                .keyboardShortcut("0")
                .disabled(isGlanceBlocked)
            // v11 P4.6: the week table's right column (the shortcut moved here from its toolbar button).
            Button("Wochenübersicht") { toggleWeekSummary() }
                .keyboardShortcut("0", modifiers: [.command, .option])
            Button("Fokus (Power-Hours)") { present { .focus($0.selectedDay) } }
                .keyboardShortcut("5")
                .disabled(isBlocked)
            // v11 P4.3: the day shown, like every other capture command.
            Button("Ausgaben") { present { .expenses($0.captureDay) } }
                .keyboardShortcut("6")
                .disabled(isBlocked)
            Divider()
            Button("Vorheriger Tag") { moveDay(by: -1) }
                .keyboardShortcut("[")
                .disabled(!isOnToday)
            Button("Nächster Tag") { moveDay(by: 1) }
                .keyboardShortcut("]")
                .disabled(!isOnToday)
            // v11 P6.15: one "Zu heute" – on Woche the running week, everywhere else today.
            Button("Zu heute") { goToNow() }
                .keyboardShortcut("t")
            Divider()
            Button("Vorige Kategorie") { app.commandTarget.moveTodayPage(by: -1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(!isOnToday)
            Button("Nächste Kategorie") { app.commandTarget.moveTodayPage(by: 1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(!isOnToday)
            Divider()
            // v11 P4.3: on Heute a week back or ahead from the day shown, on Woche the week shown.
            Button("Vorige Woche") { moveWeek(by: -1) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(!canMoveWeek)
            Button("Nächste Woche") { moveWeek(by: 1) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(!canMoveWeek)
            Divider()
            Button("Zuletzt gelöscht") { present { _ in .trash } }
                .disabled(isBlocked || isTourOpen)
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

    /// v11 P4.19: the tour is open (its practice page has the menu commands).
    private var isTourOpen: Bool { app.tour != nil || app.tourModel != nil }

    private var isCloseDayOpen: Bool {
        if case .closeDay = app.commandTarget.sheet { return true }
        return false
    }

    private var isCloseWeekOpen: Bool {
        if case .closeWeek = app.commandTarget.sheet { return true }
        return false
    }

    /// Day and category commands only act on Today (R35, R62).
    private var isOnToday: Bool { isShowing(.today) }

    /// v11 P4.3, P6.15: the week table is shown.
    private var isOnWeek: Bool { isShowing(.week) }

    /// v11 P4.3: "Vorige/Nächste Woche" on Heute and Woche – not on Ziele and Rückblick.
    private var canMoveWeek: Bool { isOnToday || isOnWeek }

    private func isShowing(_ tab: AppTab) -> Bool {
        let target = app.commandTarget
        #if os(macOS)
        return (target.sidebar ?? .today) == tab
        #else
        return target.tab == tab
        #endif
    }

    /// The Mac toggles a column, so nothing is lost – unless the window is too narrow for it and the sheet opens
    /// (P4.1); iPad opens a sheet.
    private var isGlanceBlocked: Bool {
        #if os(macOS)
        return isBlocked && !app.commandTarget.fitsGlanceInspector
        #else
        return isBlocked
        #endif
    }

    // MARK: Actions

    /// v11 P4.2: the main window to the front (opened when it was closed). Returns whether it was the main window
    /// already – a closing sheet on it may then close (⌘↩), otherwise it only comes to the front.
    @discardableResult
    private func showMainWindow() -> Bool {
        #if os(macOS)
        let wasMain: Bool = NSApp.isActive && (MainWindow.existing?.isMainWindow ?? false)
        MainWindow.show(openWindow)
        return wasMain
        #else
        return true
        #endif
    }

    /// Opens a sheet on the command target – unless a sheet with unsaved input is open (R14).
    private func present(_ make: (AppModel) -> AppSheet) {
        let target = app.commandTarget
        guard !target.blocksSheetCommands else { return }
        showMainWindow()
        target.sheet = make(target)
    }

    /// ⌘1–⌘4. v11 P5.12: ⌘1 gives Today's list the keys 1–4 right away.
    private func goTo(_ tab: AppTab) {
        showMainWindow()
        app.sidebar = tab
        app.tab = tab
        if tab == .today { app.focusTodayPage = true }
    }

    /// ⌘↩: in the open day-closing sheet it closes the day (R39), else it opens the right day (R18).
    private func closeDay() {
        let target = app.commandTarget
        let wasMain: Bool = showMainWindow()
        if case .closeDay = target.sheet {
            if wasMain { target.closeRequest += 1 }
            return
        }
        guard !target.blocksSheetCommands else { return }
        target.sheet = .closeDay(target.dayToClose(showing: target.selectedDay))
    }

    /// ⇧⌘↩: the same for the week (R40). v11 P4.3: on Heute the week of the day shown.
    private func closeWeek() {
        let target = app.commandTarget
        let wasMain: Bool = showMainWindow()
        if case .closeWeek = target.sheet {
            if wasMain { target.closeRequest += 1 }
            return
        }
        guard !target.blocksSheetCommands else { return }
        let week: WeekKey = isOnToday ? target.selectedDay.week : target.selectedWeek
        target.sheet = .closeWeek(week)
    }

    /// ⌘0 – Mac: the right column next to Today (R59), the sheet while the window is too narrow (P4.1);
    /// iPad: the sheet. The day shown.
    private func showGlance() {
        let target = app.commandTarget
        #if os(macOS)
        showMainWindow()
        guard target.fitsGlanceInspector || !target.blocksSheetCommands else { return }
        #else
        guard !target.blocksSheetCommands else { return }
        #endif
        target.showDayOverview(target.captureDay)
    }

    /// ⌥⌘0 (P4.6).
    private func toggleWeekSummary() {
        showMainWindow()
        app.commandTarget.toggleWeekSummary()
    }

    private func moveDay(by offset: Int) {
        guard isOnToday else { return }
        let target = app.commandTarget
        target.selectedDay = target.selectedDay.adding(days: offset)
    }

    /// v11 P4.3: day and week stay independent (R1) – on Heute the day shown moves by a week (like its title
    /// menu), on Woche the week shown.
    private func moveWeek(by offset: Int) {
        let target = app.commandTarget
        if isOnToday {
            target.selectedDay = target.selectedDay.adding(days: 7 * offset)
        } else if isOnWeek {
            target.selectedWeek = target.selectedWeek.adding(weeks: offset)
        }
    }

    /// ⌘T (P6.15): on Woche back to the running week, everywhere else to today.
    private func goToNow() {
        showMainWindow()
        let target = app.commandTarget
        if isOnWeek {
            target.refreshToday()
            target.selectedWeek = target.today.week
        } else {
            target.goToToday()
        }
    }

    /// Ablage → "Sicherung erstellen…" (P4.9): the real model, never the practice page.
    private func makeBackup() {
        guard !isTourOpen else { return }
        showMainWindow()
        app.makeBackup()
    }

    private func startTour() {
        guard !app.commandTarget.blocksSheetCommands else { return }
        showMainWindow()
        app.startTour()
    }
}
