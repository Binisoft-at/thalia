import SwiftUI
import SwiftData
import CoreData
import CloudKit
import BinisoftKit
import ThaliaCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

enum AppTab: Hashable {
    case today, week, goals, review
}

/// A page of the Today pager: one category, or the day itself (notes, closing).
enum TodayPage: Hashable {
    case category(String)
    case day
}

/// What a work sheet starts with.
struct WorkDraft: Identifiable {
    let id = UUID()
    var block: WorkBlock?
    var day: DayKey
    /// Empty from the global "+": the area is chosen on purpose (K1).
    var categoryKey: String = ""
    var powerHours: Double = 1
}

enum Explainer: String, Identifiable {
    case scoring, powerHours, marks, suggestions
    var id: String { rawValue }
}

/// Every sheet the app can show. One place, so any screen (and the tour) can open any sheet.
enum AppSheet: Identifiable {
    case create
    case importPlan(prompt: Bool)
    case closeDay(DayKey)
    case closeWeek(WeekKey)
    case work(WorkDraft)
    case measure(code: String, day: DayKey)
    case note(DayNote?, DayKey)
    case item(PlanItem, DayKey)
    case newItem(WeekKey, categoryKey: String?)
    case editMeasure(MeasureDefinition?, WeekKey, categoryKey: String?)
    case dayOverview(DayKey)
    case conditionals(DayKey)
    case archive
    case pdf(PDFKind)
    /// Focus for a day (R22).
    case focus(DayKey)
    case expenses(DayKey)
    case dayInfo(DayKey)
    case weekInfo(WeekKey)
    case report(WeekKey)
    case explainer(Explainer)
    case trash
    case settings
    /// All weekly targets with their pace (R16).
    case weeklyGoals(WeekKey)
    /// Plan exactly this week: import with the prompt (R56).
    case planWeek(WeekKey)
    /// Repeat a week's plan for another one, through the normal preview (R92).
    case repeatPlan(from: WeekKey, to: WeekKey)
    /// The item editor straight away (R63).
    case editItem(PlanItem)
    /// Prepare the goal review (R95).
    case goalReview
    /// v8: enter a past week (plan, CSV from documents, or just its score); nil lets the window choose.
    case importPast(WeekKey?)
    /// v8: several weeks as one PDF report.
    case rangePDF
    /// v10 (§1.2.6): "Jahresziel eintragen" for a day – abhaken, +1 or a value (nil lets the sheet choose the result).
    case goalEntry(DayKey, resultID: String?)
    /// v10 (§1.3): "Lesen" – "bis Seite" / "+ Seiten" for a day (nil lets the sheet choose the book).
    case reading(DayKey, itemID: String?)
    /// v10: the book window (nil: a new book).
    case book(ListItem?)
    /// v10: the reading list in a sheet of its own (the tour's practice page).
    case readingList
    /// v10 (§1.4.2): "Neuen Abschnitt beginnen…".
    case beginSegment
    /// v10: a result of an annual goal (nil: a new one for `goalKey`).
    case resultEditor(GoalResult?, goalKey: String)
    /// v10 (§1.5.5): Einstellungen → "Verbundene Apps" as a sheet (screenshots, the tour).
    case connectedApps
    /// v11 (§1.8.2): Einstellungen with one of its pages open on top (`-DemoScreen backup`: "Sicherungen").
    case settingsPage(SettingsPage)

    var id: String {
        switch self {
        case .create: "create"
        case .importPlan(let prompt): "import-\(prompt)"
        case .closeDay(let day): "close-" + day.string
        case .closeWeek(let week): "close-week-" + week.string
        case .work(let draft): "work-" + draft.id.uuidString
        case .measure(let code, let day): "measure-\(code)-\(day.string)"
        case .note(let note, let day): "note-\(note?.uuid.uuidString ?? "new")-\(day.string)"
        case .item(let item, let day): "item-\(item.uuid.uuidString)-\(day.string)"
        case .newItem(let week, let category): "new-item-\(week.string)-\(category ?? "")"
        case .editMeasure(let measure, let week, _): "edit-measure-\(measure?.uuid.uuidString ?? "new")-\(week.string)"
        case .dayOverview(let day): "overview-" + day.string
        case .conditionals(let day): "conditionals-" + day.string
        case .archive: "archive"
        case .pdf(let kind): "pdf-" + kind.id
        case .focus(let day): "focus-" + day.string
        case .expenses(let day): "expenses-" + day.string
        case .dayInfo(let day): "day-" + day.string
        case .weekInfo(let week): "week-" + week.string
        case .report(let week): "report-" + week.string
        case .explainer(let explainer): "explainer-" + explainer.rawValue
        case .trash: "trash"
        case .settings: "settings"
        case .weeklyGoals(let week): "weekly-goals-" + week.string
        case .planWeek(let week): "plan-" + week.string
        case .repeatPlan(let from, let to): "repeat-\(from.string)-\(to.string)"
        case .editItem(let item): "edit-item-" + item.uuid.uuidString
        case .goalReview: "goal-review"
        case .importPast(let week): "import-past-" + (week?.string ?? "any")
        case .rangePDF: "range-pdf"
        case .goalEntry(let day, let resultID): "goal-entry-\(day.string)-\(resultID ?? "any")"
        case .reading(let day, let itemID): "reading-\(day.string)-\(itemID ?? "any")"
        case .book(let item): "book-" + (item?.id ?? "new")
        case .readingList: "reading-list"
        case .beginSegment: "begin-segment"
        case .resultEditor(let result, let goalKey): "result-editor-\(result?.id ?? "new")-\(goalKey)"
        case .connectedApps: "connected-apps"
        case .settingsPage(let page): "settings-" + page.rawValue
        }
    }
}

/// v11 P2.9: the last save that failed on this device – when, and the system's text.
struct SaveFailure: Equatable {
    let date: Date
    let message: String
}

/// v11 P4.18: a lasting reason why Thalia doesn't sync (or doesn't save) – worth a line on the main screen. Never
/// a short network error or an account still being checked (`SyncGerman.isPersistentProblem`).
struct SyncProblem: Equatable {
    enum Kind: Equatable {
        /// The store couldn't be opened: nothing is saved.
        case memory
        /// iCloud is off: only this device.
        case local
        case noAccount
        case quotaFull
    }

    let kind: Kind

    var text: String {
        switch kind {
        case .memory: "Thalia kann gerade nicht speichern – Einträge gehen beim Beenden verloren."
        case .local: "Nur auf diesem Gerät – iCloud-Abgleich ist aus."
        case .noAccount: "Nicht bei iCloud angemeldet – Thalia gleicht nicht ab."
        case .quotaFull: "iCloud voll – Thalia gleicht nicht mehr ab."
        }
    }

    /// Red and not to be dismissed (data is lost); the others are orange and can be hidden until the next launch.
    var isCritical: Bool { kind == .memory }

    var symbol: String {
        switch kind {
        case .memory: "exclamationmark.triangle.fill"
        case .local: "icloud.slash"
        case .noAccount: "person.crop.circle.badge.exclamationmark"
        case .quotaFull: "exclamationmark.icloud"
        }
    }
}

struct TourRequest: Identifiable {
    let id = UUID()
    let steps: [TourStep<ThaliaTourSnapshot>]
}

/// App-wide UI state shared by all windows. The tour's practice page gets its own instance on
/// its own in-memory store (`isSandbox`), so nothing done there touches real data.
@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let mode: StorageMode
    let sync: SyncMonitor
    let toasts: ToastCenter
    let launch: LaunchOptions
    let isSandbox: Bool

    var tab: AppTab = .today
    var sidebar: AppTab? = .today
    var sheet: AppSheet?
    var tour: TourRequest?
    /// The day the Today screen records (today unless you look back).
    var selectedDay: DayKey = .today()
    /// The page Today shows (nil: the first category with something open).
    var todayPage: TodayPage?
    /// The week the Week screen shows.
    var selectedWeek: WeekKey = DayKey.today().week
    /// The practice page's model while the tour is open: menu commands act there.
    var tourModel: AppModel?
    /// A CSV opened from Files / "Open in" – the import sheet picks it up.
    var pendingImport: URL?
    /// Today's date; follows the system day (midnight, time zone change, back in the app) (R1).
    var today: DayKey = .today()
    /// Today's pages in order, set by the Today pager; ⌥⌘↓ / ⌥⌘↑ move through them (R35).
    var todayPageOrder: [TodayPage] = []
    /// An open sheet holds typed input that isn't saved yet (R14), set by `unsavedInput(_:in:)`.
    var hasUnsavedInput = false
    /// +1 for ⌘↩ / ⇧⌘↩ while the matching closing sheet is open: it closes instead of reopening (R39).
    var closeRequest = 0
    /// Number of toast layers (main window, sheets on top) – only the topmost shows the toast (R13).
    var toastLevel = 0
    /// The toast layers in the order they appeared; the last one is on top (R13).
    private(set) var toastHosts: [UUID] = []
    /// Height of the Mac main window, so sheets fit into it (R15).
    var mainWindowHeight: CGFloat = 800
    /// v11 P4.1: width of the Mac main window, measured by MacRoot next to its height.
    var mainWindowWidth: CGFloat {
        get { mainWindowWidthStorage }
        set {
            let previous: CGFloat = roomWidth
            mainWindowWidthStorage = newValue
            updateInspectorFits(previousWidth: previous)
        }
    }
    private var mainWindowWidthStorage: CGFloat = 1180
    /// v11 P4.1: width of the Mac main window's detail column, measured in MacRoot's detail closure – the same
    /// whether an inspector takes room in it or not (the sidebar can be dragged). It decides whether the
    /// inspectors fit (`fitsGlanceInspector`, `fitsWeekSummary`). Never measured on iPhone and iPad.
    var detailWidth: CGFloat {
        get { detailWidthStorage }
        set {
            let previous: CGFloat = roomWidth
            detailWidthStorage = newValue
            updateInspectorFits(previousWidth: previous)
        }
    }
    private var detailWidthStorage: CGFloat = 950
    /// v11 P4.1: the Mac sidebar's width (0 until measured) and whether it shows (hidden through Darstellung →
    /// Seitenleiste ausblenden) – MacRoot sets both.
    var sidebarWidth: CGFloat {
        get { sidebarWidthStorage }
        set {
            let previous: CGFloat = roomWidth
            sidebarWidthStorage = newValue
            updateInspectorFits(previousWidth: previous)
        }
    }
    private var sidebarWidthStorage: CGFloat = 0
    var showsSidebar: Bool {
        get { showsSidebarStorage }
        set {
            let previous: CGFloat = roomWidth
            showsSidebarStorage = newValue
            updateInspectorFits(previousWidth: previous)
        }
    }
    private var showsSidebarStorage = true

    /// v11 P4.1: the room next to the sidebar for the page and an inspector together – the window without the
    /// sidebar. It is the same whether an inspector sits inside the detail column or in a column of its own next
    /// to it, so an inspector coming or going never changes whether it fits. The measured detail only counts
    /// before the sidebar is measured, and never wider than the window: content wider than its column makes the
    /// detail overflow the window (CI run 38: detail 1117 in a 1024 window), and that width must not make an
    /// inspector "fit".
    var roomWidth: CGFloat {
        guard sidebarWidthStorage > 0 || !showsSidebarStorage else {
            return min(detailWidthStorage, mainWindowWidthStorage)
        }
        let sidebar: CGFloat = showsSidebarStorage ? sidebarWidthStorage + 1 : 0
        return mainWindowWidthStorage - sidebar
    }
    /// v11 P4.1: "Heute im Blick" fits as the right column next to Today's list and page – the detail is at least
    /// `glanceInspectorWidth` wide (on from 20 pt above, off from 20 pt below: no flicker while dragging). The
    /// stored choice (`showsGlanceInspector`) stays; while the column doesn't fit, ⌘0, the toolbar button, the day
    /// ring and the sidebar card open the sheet (`showDayOverview`). Always true on iPhone and iPad.
    private(set) var fitsGlanceInspector = true
    /// v11 P4.1: the week table's "Wochenübersicht" column fits next to the table (`weekSummaryWidth`, same
    /// margin). Always true on iPhone and iPad.
    private(set) var fitsWeekSummary = true
    /// v11 P5.12: Today's selectable list on the Mac takes the keyboard focus – set by ⌥⌘↓ / ⌥⌘↑ (`moveTodayPage`),
    /// the "Weiter" buttons, ⌘1 and the main window becoming key on Today; the category page sets it back to false
    /// once its list has the focus.
    var focusTodayPage = false
    /// v11 P2.9: the last save that failed (from `TrackerStore.saveFailed`); nil while all went well.
    var lastSaveError: SaveFailure?
    /// v11 P4.13: when CloudKit last sent this device's changes (a successful export) and last received changes
    /// (a successful import) – per device in UserDefaults, observable. Nil: not seen yet on this device.
    private(set) var lastSent: Date? = UserDefaults.standard.object(forKey: AppModel.lastSentKey) as? Date
    private(set) var lastReceived: Date? = UserDefaults.standard.object(forKey: AppModel.lastReceivedKey) as? Date
    /// v11 P4.9: a full backup ready to be saved – the Mac main window's file exporter shows it while set.
    var backupFile: CSVFile?
    /// v11 P4.9: Ablage → "Sicherung erstellen…" is building the backup (the command waits, no second one).
    private(set) var isMakingBackup = false
    /// v11 P4.13: when this device last saved a change that goes to iCloud (device only) – compared with
    /// `lastSent` for "Letzte Änderung noch nicht an iCloud gesendet".
    private(set) var lastSyncedChange: Date? = UserDefaults.standard.object(forKey: AppModel.lastChangeKey) as? Date
    /// v11 P4.18: CloudKit reported a full iCloud storage – until the next successful export.
    private(set) var quotaExceeded = false
    /// v11 P4.18: the orange sync line was closed – hidden until the next launch (the red one stays).
    var syncProblemDismissed = false
    /// Mac menu bar label: "73 %", "7,5" once closed, "" without a plan (R96).
    var menuBarTitle = ""
    /// +1 whenever Thalia comes to the front (and at midnight): Apple Health values are read again.
    private(set) var activationTick = 0
    /// +1 after every import from iCloud: lists loaded once (menu bar panel, devices) reload.
    private(set) var syncTick = 0
    @ObservationIgnored private var pendingSync: Task<Void, Never>?
    /// Mac: Thalia in the menu bar (R96). Kept here and written to UserDefaults only on a real
    /// change – an `@AppStorage` on the App struct bound to `MenuBarExtra(isInserted:)` left the
    /// main thread hanging at launch, before the main window was built (CI runs 21–23).
    private var menuBarStorage: Bool = UserDefaults.standard.object(forKey: MenuBarSettings.enabledKey) as? Bool ?? true

    static let inspectorKey = "today.inspector"
    private var inspectorStorage: Bool = UserDefaults.standard.bool(forKey: AppModel.inspectorKey)
    /// v11 P4.6: the week table's "Wochenübersicht" column (the key `@AppStorage` used before, on by default).
    static let weekSummaryKey = "week.summary"
    private var weekSummaryStorage: Bool = UserDefaults.standard.object(forKey: AppModel.weekSummaryKey) as? Bool ?? true
    /// v11 P4.13: device-only, when CloudKit last finished an export / an import successfully.
    static let lastSentKey = "sync.lastSent"
    static let lastReceivedKey = "sync.lastReceived"
    /// v11 P4.13: device-only, when this device last saved a change for iCloud.
    static let lastChangeKey = "sync.lastChange"
    /// v11 P4.13: a change not sent after this long is worth the orange line.
    static let unsentWarningAfter: TimeInterval = 15 * 60
    /// v11 P2.9: the toast about a failed save at most this often.
    static let saveErrorToastInterval: TimeInterval = 10 * 60
    @ObservationIgnored private var lastSaveErrorToast: Date?
    @ObservationIgnored private var pendingMenuBarTitle: Task<Void, Never>?
    /// v11 P4.17: closed weeks whose weekly reminder was already taken away after a sync.
    @ObservationIgnored private var closedReminderWeeks: Set<WeekKey> = []
    /// v11 P3.13: the weekly automatic backup is being written.
    @ObservationIgnored private var isWritingBackup = false
    #if DEBUG
    /// v11 P4.18: `-FakeSyncProblem local|memory|quota` (debug builds): shows that line without the real state.
    private let fakeSyncProblem: String? = UserDefaults.standard.string(forKey: "FakeSyncProblem")
    #endif
    /// v11 P4.1 (Mac): the width of the "Heute im Blick" column while it shows (it can be dragged, 260–380 pt).
    var glanceColumnWidth: CGFloat = 300
    /// v11 P4.1 (Mac): Today's category list beside the page, and the page's least width.
    static let todayListWidth: CGFloat = 250
    static let todayPageMinWidth: CGFloat = 400
    /// v11 P4.1: the detail width each inspector needs – Today: list 250 + page 400 + column 260; week: the table
    /// as the Mac lays it out (CI runs 38/39: 748 pt with the demo week, more than `WeekTableColumns.minWidth` +
    /// 40) + column 240 – and the margin on either side of it. Below that the column opens as a sheet.
    static let glanceInspectorWidth: CGFloat = 910
    static let weekSummaryWidth: CGFloat = 1000
    static let inspectorMargin: CGFloat = 20
    /// When an inspector last came or went (P4.1): a jump of the width right after it doesn't switch it back.
    @ObservationIgnored private var lastInspectorFitChange: Date = .distantPast
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var widgetPublisher: WidgetPublisher?
    /// v10 (§1.5.1): looks into the shared App Group for the connected apps' day files – the real
    /// store only (never `-Demo`, the practice page or an in-memory store); nil otherwise.
    @ObservationIgnored private(set) var exchangeMonitor: ExchangeMonitor?
    // HEALTHSHARE: "Health-Werte mit Mac und Watch teilen" (TestFlight only, §1.4) – the switch, the writer and the gate as
    // the views show them.
    let healthShare: HealthShareController

    init(container: ModelContainer, mode: StorageMode, launch: LaunchOptions = .current, isSandbox: Bool = false) {
        self.container = container
        self.mode = mode
        self.launch = launch
        self.isSandbox = isSandbox
        self.sync = SyncMonitor(mode: isSandbox ? .demo : mode, appName: AppInfo.name)
        self.toasts = ToastCenter()
        // HEALTHSHARE: the demo and the practice page show the switch but never write.
        self.healthShare = HealthShareController(isDemo: launch.isDemo, isSandbox: isSandbox)
        guard !isSandbox else { return }
        // v8: no evening reminder on sick and holiday days, whoever plans the reminders.
        ReminderScheduler.skipsDay = { [weak self] day in self?.isDayExcused(day) ?? false }
        // v11 P4.17: no "Wochenabschluss" for a closed week; "Nächste Woche planen" when the next one has no plan.
        ReminderScheduler.isWeekClosed = { [weak self] week in self?.store.plan(week)?.isClosed ?? false }
        ReminderScheduler.weekHasPlan = { [weak self] week in !(self?.store.items(week).isEmpty ?? true) }
        applyLaunchOptions()
        startDayWatch()
        startWindowWatch()
        // v11 P4.18: the iCloud account from the start – "Nicht bei iCloud angemeldet" shouldn't wait for Einstellungen.
        if mode.isSynced {
            Task { @MainActor [weak self] in await self?.sync.refreshAccount() }
        }
        if !launch.isDemo {
            // v11 P2.13: merging and emptying the trash run off the first frame, in `maintenance` (8 s after launch).
            let publisher = WidgetPublisher(container: container)
            publisher.start()
            widgetPublisher = publisher
            startConnectedApps()
            startBackupWatch()
        }
        // HEALTHSHARE: the gate from the cache at once, checked again off the start; the clean-up (§1.4.3, §1.4.6).
        startHealthShare()
        updateMenuBarTitle()
    }

    // MARK: HEALTHSHARE – sharing Health values with Mac and watch (TestFlight only, §1.4, P9.2)

    // HEALTHSHARE: views redraw when the gate changes (`syncTick` – a static value isn't observed). Off the first frame the
    // app transaction is checked: a freshly confirmed `.denied` (an App Store build) deletes every `hshare.` record – this
    // clean-up stays when the sharing goes (§1.4.12 (b)); `.unknown` (offline, not verified) deletes nothing. Then the writer's
    // first run. Never in `-Demo`.
    private func startHealthShare() {
        // HEALTHSHARE
        observers.append(NotificationCenter.default.addObserver(forName: HealthShareGate.changed, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.healthShareGateChanged() }
        })
        guard !launch.isDemo else { return }
        Task { @MainActor [weak self] in
            // HEALTHSHARE
            let fresh: HealthShareGate.State = await HealthShareGate.resolve()
            guard let self else { return }
            // HEALTHSHARE
            self.store.cleanUpHealthShare(gate: fresh, today: self.today)
            self.healthShare.gateChanged()
            self.healthShare.activate(store: self.store, today: self.today)
        }
    }

    // HEALTHSHARE: the gate changed – the switch, the shared values and the texts follow.
    private func healthShareGateChanged() {
        healthShare.gateChanged()
        syncTick += 1
    }

    // HEALTHSHARE: a save held an Apple Health value – the writer shares the changed days (§1.4.5).
    private func healthValuesSaved() {
        guard !launch.isDemo else { return }
        healthShare.healthValuesSaved(store: store, today: today)
    }

    // MARK: v10 – connected apps and the one-time backfill

    /// The exchange with the other Binisoft apps (§1.5.1): the monitor reads at start (a few seconds
    /// later), whenever Thalia comes to the front, every 5 minutes while it is active, after its own
    /// iCloud import, at the day change and on the Darwin notification of another app. v11 P4.12: the Mac
    /// keeps the 5-minute look while another app is in front (as long as Thalia runs; App Nap may stretch it).
    /// Also, off the first frame (8 s): maintenance – merging duplicates, emptying the trash (P2.13) –, the
    /// iPhone's work on the rescore requests (P2.1), the one-time category week scores (§1.2.3), all without
    /// Undo (P2.4), and, in debug builds, the check that prefix queries work on this device (§1.1.2).
    private func startConnectedApps() {
        let monitor = ExchangeMonitor(container: container, isDemo: launch.isDemo)
        if monitor.isEnabled {
            monitor.start()
            exchangeMonitor = monitor
            let center = NotificationCenter.default
            #if os(iOS)
            let becameActive: Notification.Name = UIApplication.didBecomeActiveNotification
            let wentAway: Notification.Name = UIApplication.didEnterBackgroundNotification
            observers.append(center.addObserver(forName: wentAway, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.exchangeMonitor?.setActive(false) }
            })
            #else
            let becameActive: Notification.Name = NSApplication.didBecomeActiveNotification
            monitor.setActive(true)
            #endif
            observers.append(center.addObserver(forName: becameActive, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.exchangeMonitor?.setActive(true) }
            })
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, !self.isSandbox, !self.launch.isDemo else { return }
            let store = self.store
            let today: DayKey = self.today
            #if DEBUG
            store.verifyPrefixQuery()
            #endif
            let kept: [WeekKey] = store.withoutUndo { () -> [WeekKey] in
                store.maintenance(today: today)
                let kept: [WeekKey] = store.processRescoreRequests()
                store.backfillCategoryScores(today: today)
                return kept
            }
            self.showKeptScores(kept)
        }
    }

    /// v11 P2.2: weeks the iPhone was asked to score with `force` but keeps – they ended before this install and
    /// read Apple Health, whose values of then aren't here.
    private func showKeptScores(_ weeks: [WeekKey]) {
        guard !weeks.isEmpty else { return }
        let labels: String = weeks.map(\.label).joined(separator: ", ")
        toasts.show("\(labels): Auf diesem iPhone fehlen die Health-Werte von damals – die Wertung bleibt.", symbol: "heart.text.square")
    }

    /// "Jetzt nachsehen" in Einstellungen → "Verbundene Apps".
    func refreshConnectedApps() {
        exchangeMonitor?.refreshNow()
    }

    var store: TrackerStore { TrackerStore(context: container.mainContext) }

    /// Where menu commands act: the practice page during the tour, otherwise this model.
    var commandTarget: AppModel { tourModel ?? self }

    /// The day every capture sheet starts with (R41).
    var captureDay: DayKey { selectedDay }

    /// Menu commands that open a sheet do nothing while a sheet holds unsaved input (R14). v11 P4.5: also a
    /// window opened locally (Ziele, a goal's page, the reading list) – `hasUnsavedInput` is set only by
    /// `unsavedInput(_:in:)` and goes back to false when that window closes.
    var blocksSheetCommands: Bool { hasUnsavedInput }

    /// Mac: "Heute im Blick" as the right column next to Today; the choice survives a restart (R59).
    var showsGlanceInspector: Bool {
        get { inspectorStorage }
        set {
            inspectorStorage = newValue
            if !isSandbox { UserDefaults.standard.set(newValue, forKey: AppModel.inspectorKey) }
        }
    }

    /// v11 P4.6: Mac and the wide iPad – "Wochenübersicht" as the right column of the week table; on by default,
    /// the choice survives a restart. The practice page never writes it.
    var showsWeekSummary: Bool {
        get { weekSummaryStorage }
        set {
            weekSummaryStorage = newValue
            if !isSandbox { UserDefaults.standard.set(newValue, forKey: AppModel.weekSummaryKey) }
        }
    }

    /// v11 P4.1: "Heute im Blick" is on screen as the column – chosen and fitting. For the inspector's binding:
    /// `Binding(get: { app.showsGlanceColumn }, set: { app.showsGlanceInspector = $0 })`.
    var showsGlanceColumn: Bool { showsGlanceInspector && fitsGlanceInspector }

    /// v11 P4.1: the "Wochenübersicht" column is on screen – chosen and fitting.
    var showsWeekSummaryColumn: Bool { showsWeekSummary && fitsWeekSummary }

    /// v11 P4.1 (KR2-3): "Heute im Blick" for `day` – the one way for ⌘0, the toolbar button, the day ring and the
    /// sidebar card. Mac: while the column fits, it shows or hides next to Today (as ⌘0 always did); when the
    /// window is too narrow for it, the sheet opens. iPhone and iPad: the sheet (the iPad's split keeps its own
    /// column button).
    func showDayOverview(_ day: DayKey) {
        #if os(macOS)
        if fitsGlanceInspector {
            let shown: Bool = (sidebar ?? .today) == .today && showsGlanceInspector
            sidebar = .today
            tab = .today
            showsGlanceInspector = !shown
            return
        }
        #endif
        sheet = .dayOverview(day)
    }

    /// v11 P4.6: Gehe zu → "Wochenübersicht" (⌥⌘0) – the week table's right column, shown or hidden like ⌘0 does
    /// for Today. While it doesn't fit, it is switched on afresh, so the week table shows it as a sheet (P6).
    func toggleWeekSummary() {
        #if os(macOS)
        let onWeek: Bool = (sidebar ?? .today) == .week
        #else
        let onWeek: Bool = tab == .week
        #endif
        sidebar = .week
        tab = .week
        guard fitsWeekSummary else {
            // Off now, on again after the next frame: the week table sees the change to "on" (both in one frame
            // would read as no change), and coming from another page it is on screen by then. The column doesn't
            // show meanwhile – it doesn't fit.
            showsWeekSummary = false
            // `Swift.Duration`: on the Mac AppKit brings MacTypes' C typedef `Duration` (SInt32) into scope.
            let wait: Swift.Duration = onWeek ? .milliseconds(100) : .milliseconds(350)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: wait)
                self?.showsWeekSummary = true
            }
            return
        }
        showsWeekSummary = !(onWeek && showsWeekSummary)
    }

    /// v11 P4.1: whether a column that needs `width` fits in `detail` – from `width + margin` on while it is off,
    /// until below `width − margin` while it is on.
    static func fits(_ fitsNow: Bool, detail: CGFloat, width: CGFloat) -> Bool {
        fitsNow ? detail >= width - inspectorMargin : detail >= width + inspectorMargin
    }

    /// After a new width: the inspectors fit or not (`roomWidth`). Should the room ever be measured without the
    /// inspector, its own coming or going changes the width in one jump – that never switches it right back.
    private func updateInspectorFits(previousWidth: CGFloat) {
        let width: CGFloat = roomWidth
        guard width != previousWidth else { return }
        let glance: Bool = AppModel.fits(fitsGlanceInspector, detail: width, width: AppModel.glanceInspectorWidth)
        let week: Bool = AppModel.fits(fitsWeekSummary, detail: width, width: AppModel.weekSummaryWidth)
        guard glance != fitsGlanceInspector || week != fitsWeekSummary else { return }
        let now = Date()
        if abs(width - previousWidth) >= 200 && now.timeIntervalSince(lastInspectorFitChange) < 0.5 {
            diagNote("inspector fit kept at detail \(Int(width)) (jump from \(Int(previousWidth)))")
            return
        }
        lastInspectorFitChange = now
        if glance != fitsGlanceInspector { fitsGlanceInspector = glance }
        if week != fitsWeekSummary { fitsWeekSummary = week }
        diagNote("inspector fits at room \(Int(width)) (detail \(Int(detailWidth))): glance \(glance), week summary \(week)")
    }

    var menuBarEnabled: Bool {
        get { menuBarStorage }
        set {
            guard newValue != menuBarStorage else { return }
            menuBarStorage = newValue
            if !isSandbox { UserDefaults.standard.set(newValue, forKey: MenuBarSettings.enabledKey) }
            // v11 P4.10: the title is built only while the menu bar shows Thalia – once now, when switched on.
            if newValue { updateMenuBarTitle() }
        }
    }

    // MARK: The day (R1, R6, R7, R18)

    /// Watches the system day: midnight, time changes (iPhone) and the app becoming active (Mac).
    private func startDayWatch() {
        let center = NotificationCenter.default
        var names: [Notification.Name] = [.NSCalendarDayChanged]
        #if os(iOS)
        names.append(UIApplication.significantTimeChangeNotification)
        #elseif os(macOS)
        names.append(NSApplication.didBecomeActiveNotification)
        #endif
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshToday() }
            })
        }
        // Delivered on the posting thread and handed to the main actor afterwards: a save on a
        // background context never waits for the main thread here. Mac: the menu bar title (P4.10, at most
        // every 300 ms); everywhere: when this device last saved a change for iCloud (P4.13).
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { [weak self] note in
            let changes: AppModel.SavedChanges = AppModel.SavedChanges(note)
            // HEALTHSHARE: an adopted, removed or undone Apple Health value (§1.4.5, KR1-12).
            let health: Bool = changes.entities.contains("HealthValue")
            Task { @MainActor in
                #if os(macOS)
                self?.updateMenuBarTitleSoon()
                #endif
                self?.noteSaved(changes)
                // HEALTHSHARE
                if health { self?.healthValuesSaved() }
            }
        })
        // v8: a day became sick / holiday (or back): its evening reminder goes away or comes back.
        observers.append(center.addObserver(forName: TrackerStore.dayInfoChanged, object: nil, queue: nil) { [weak self] note in
            let key: String? = note.userInfo?["day"] as? String
            Task { @MainActor in self?.dayInfoChanged(key.flatMap { DayKey($0) }) }
        })
        // Changes from other devices: a finished import from iCloud. Here and not in a view, so it
        // also works on the Mac with only the menu bar open (no main window). v11 P4.13: a finished
        // export or import also notes when this device last sent or received changes.
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  let ended: Date = event.endDate else { return }
            let isImport: Bool = event.type == .import
            let isExport: Bool = event.type == .export
            let succeeded: Bool = event.succeeded
            // v11 P4.18: "iCloud voll" from CloudKit's error code (the kit keeps only an English text).
            let quota: Bool = AppModel.isQuotaExceeded(event.error)
            Task { @MainActor in
                self?.syncEventEnded(isImport: isImport, isExport: isExport, succeeded: succeeded, quota: quota, at: ended)
            }
        })
        #if os(macOS)
        // v11 P3.2: the Mac's first iCloud sync (`SyncProgress.firstImportDone`) – on iPhone and Watch the widget
        // publisher notes it, which doesn't run on the Mac. Every import event, its start and its end.
        let container: ModelContainer = self.container
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            MainActor.assumeIsolated { SyncProgress.noteImport(event, container: container) }
        })
        #endif
        // v11 P2.9: a save that failed (the store posts it; the text is the system's).
        observers.append(center.addObserver(forName: TrackerStore.saveFailed, object: nil, queue: nil) { [weak self] note in
            let message: String = note.userInfo?[TrackerStore.saveFailedMessageKey] as? String ?? ""
            Task { @MainActor in self?.saveFailed(message) }
        })
    }

    /// v11 P4.2, P5.12 (Mac): a destination asked for while the main window is closed (a Shortcut, a control)
    /// opens it – `PendingRoute` keeps the destination and RootView routes it once the window is there; the
    /// main window becoming the main window on Today gives the category list the keys 1–4.
    private func startWindowWatch() {
        #if os(macOS)
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .thaliaRoute, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                if MainWindow.existing == nil { MainWindow.showWithoutEnvironment() }
            }
        })
        observers.append(center.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { [weak self] note in
            let window: NSWindow? = note.object as? NSWindow
            MainActor.assumeIsolated {
                guard let self, window?.identifier?.rawValue.hasPrefix("main") ?? false,
                      (self.sidebar ?? .today) == .today else { return }
                self.focusTodayPage = true
            }
        })
        #endif
    }

    /// A CloudKit export or import ended (P4.13): the times for Einstellungen → iCloud & Daten; after an
    /// import `afterSync` follows as before. P4.11: the evening reminders of days closed elsewhere go at once
    /// (`afterSync` repeats it with the merged data), and the iPhone gets background time for `afterSync`.
    /// P4.18: a full iCloud storage is noted until the next successful export.
    private func syncEventEnded(isImport: Bool, isExport: Bool, succeeded: Bool, quota: Bool, at ended: Date) {
        if succeeded && isExport {
            lastSent = ended
            UserDefaults.standard.set(ended, forKey: AppModel.lastSentKey)
            if quotaExceeded { quotaExceeded = false }
        }
        if quota && !quotaExceeded {
            quotaExceeded = true
            AppLog.warning("iCloud storage is full", category: "sync")
        }
        if succeeded && isImport {
            lastReceived = ended
            UserDefaults.standard.set(ended, forKey: AppModel.lastReceivedKey)
        }
        if isImport {
            clearRemindersOfClosedDays()
            afterSyncSoon()
        }
    }

    /// v11 P4.18: CloudKit's "quota exceeded" – on the error itself, among the per-record errors
    /// (`partialErrorsByItemID`) or underneath Core Data's error.
    nonisolated static func isQuotaExceeded(_ error: Error?) -> Bool {
        guard let error else { return false }
        let ns = error as NSError
        if ns.domain == CKErrorDomain && ns.code == CKError.Code.quotaExceeded.rawValue { return true }
        if let partial = ns.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           partial.values.contains(where: { isQuotaExceeded($0) }) { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error, underlying as NSError !== ns {
            return isQuotaExceeded(underlying)
        }
        return false
    }

    /// v11 P2.9: a save failed – the line in Einstellungen → iCloud & Daten, and a toast at most every 10 minutes.
    private func saveFailed(_ message: String) {
        let now = Date()
        lastSaveError = SaveFailure(date: now, message: message)
        guard !isSandbox else { return }
        if let last = lastSaveErrorToast, now.timeIntervalSince(last) < AppModel.saveErrorToastInterval { return }
        lastSaveErrorToast = now
        toasts.show("Konnte nicht speichern – Details unter Einstellungen → iCloud & Daten", symbol: "exclamationmark.triangle.fill")
    }

    /// What one save changed, read from `ModelContext.didSave` on the posting thread (P4.13): the entities, and
    /// the settings it inserted or changed (to tell a device's own "seen" note from data).
    struct SavedChanges: Sendable {
        var entities: [String] = []
        var settings: [PersistentIdentifier] = []

        init(_ note: Notification) {
            for value in (note.userInfo ?? [:]).values {
                guard let ids = value as? [PersistentIdentifier] else { continue }
                for id in ids {
                    entities.append(id.entityName)
                    if id.entityName == "AppSetting" { settings.append(id) }
                }
            }
        }
    }

    /// v11 P4.13: a save of synced data – not the device-only Health values, not only this device's own
    /// "Geräte im Abgleich" note – is a change iCloud should get. Kept per device.
    private func noteSaved(_ changes: SavedChanges) {
        guard !isSandbox, mode.isSynced else { return }
        let context = container.mainContext
        let counts: Bool = changes.entities.contains { name in name != "HealthValue" && name != "AppSetting" }
            || changes.settings.contains { id in
                guard let setting: AppSetting = context.registeredModel(for: id) else { return true }
                return !(setting.key.hasPrefix(SyncDevice.keyPrefix) || setting.key.hasPrefix(SettingKeys.buildPrefix))
            }
        guard counts else { return }
        let now = Date()
        lastSyncedChange = now
        UserDefaults.standard.set(now, forKey: AppModel.lastChangeKey)
    }

    /// v11 P4.13: the last change is older than 15 minutes and no export has succeeded since, while the iCloud
    /// account is there – "Letzte Änderung noch nicht an iCloud gesendet".
    func hasUnsentChange(now: Date = Date()) -> Bool {
        guard mode.isSynced, sync.state.account == .available, let change = lastSyncedChange,
              now.timeIntervalSince(change) >= AppModel.unsentWarningAfter else { return false }
        guard let sent = lastSent else { return true }
        return sent < change
    }

    /// v8: after `setDayInfo` – no evening reminder on a sick or holiday day; the others planned anew.
    private func dayInfoChanged(_ day: DayKey?) {
        guard !isSandbox, !launch.isDemo else { return }
        if let day, isDayExcused(day) { ReminderScheduler.dayClosed(day) }
        scheduleReminders()
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
    }

    /// After an import: give the main context a moment to merge, then `afterSync`. v11 P4.11: with background
    /// time on the iPhone (one at a time), ended by the task that really ran `afterSync` – never by a cancelled one.
    private func afterSyncSoon() {
        pendingSync?.cancel()
        BackgroundGrace.beginAfterSync()
        pendingSync = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.afterSync()
            BackgroundGrace.endAfterSync()
        }
    }

    /// A new day: the selected day and week move along when they were "today" (a day picked on
    /// purpose stays), Today picks its start page anew, the widget gets the new day.
    func refreshToday() {
        let now = DayKey.today()
        if now != today {
            let previous = today
            if selectedDay == previous {
                selectedDay = now
                todayPage = nil
            }
            if selectedWeek == previous.week { selectedWeek = now.week }
            today = now
            widgetPublisher?.publishNow()
            AppLog.info("New day", category: "app")
        }
        activationTick += 1
        updateMenuBarTitle()
        // v11 P4.15: "Geräte im Abgleich" – also a Mac used only through the menu bar notes itself (every time
        // Thalia comes to the front; the store writes at most every 10 minutes). Never from `afterSync`.
        recordDeviceSeen()
        // HEALTHSHARE: every activation and the new day – the daily clean-up and the writer (§1.4.5, §1.4.6).
        if !isSandbox, !launch.isDemo { healthShare.activate(store: store, today: today) }
    }

    /// Back to today: Today tab / sidebar, today's day and week (R7).
    func goToToday() {
        refreshToday()
        selectedDay = today
        selectedWeek = today.week
        tab = .today
        sidebar = .today
    }

    func isDayClosed(_ day: DayKey) -> Bool {
        store.planDay(day)?.isClosed ?? false
    }

    /// v8: a sick or holiday day ("Krank", "Urlaub"): it doesn't count, so it gets no evening
    /// reminder and no "gestern offen".
    func isDayExcused(_ day: DayKey) -> Bool {
        store.isExcused(day)
    }

    /// v8: no evening reminder for this day – closed, or sick / on holiday.
    func skipsEveningReminder(_ day: DayKey) -> Bool {
        isDayClosed(day) || isDayExcused(day)
    }

    /// v8: sets only the day's type (the quick choice in Today's title menu, the week, closing the day).
    func setDayType(_ type: String, day: DayKey) {
        store.setDayType(day, type: type)
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
    }

    /// The day "Tag abschließen" is about (R18): an earlier day that is on screen, else before 4:00 the day
    /// before while it is still open, else today. v11 P5.17: a day in the future (looked at ahead) is never
    /// closed – today then.
    func dayToClose(showing day: DayKey? = nil) -> DayKey {
        if let day, day < today { return day }
        let store = self.store
        // v8: a sick or holiday day before 4:00 needs no closing – today then.
        return DayKey.closingDay(isClosed: { (store.planDay($0)?.isClosed ?? false) || store.isExcused($0) })
    }

    /// v11 P4.16: the week "Wochenabschluss" without a week is about – on Sunday this week; on other days the week
    /// before while it is open and has a plan or archive data, else this week (a holiday week without a plan isn't
    /// offered).
    func weekToCloseNow() -> WeekKey {
        let store = self.store
        return WeekKey.toClose(
            on: dayToClose(),
            isClosed: { store.plan($0)?.isClosed ?? false },
            hasData: { week in
                !store.items(week).isEmpty || store.archiveGrades(week) != nil || store.plan(week)?.recordedScore != nil
            }
        )
    }

    /// The next / previous page of Today (R35).
    func moveTodayPage(by offset: Int) {
        let order = todayPageOrder
        guard !order.isEmpty, offset != 0 else { return }
        let current: Int? = todayPage.flatMap { order.firstIndex(of: $0) }
        let start: Int = current ?? (offset > 0 ? -1 : order.count)
        let next: Int = min(max(start + offset, 0), order.count - 1)
        todayPage = order[next]
        // v11 P5.12: the page's list takes the keys 1–4 right away.
        focusTodayPage = true
    }

    // MARK: Widget, sync, menu bar (R4, R28, R87, R96)

    /// Writes the widget snapshot now (leaving the app). The Mac and in-memory stores never write.
    func publishWidgetNow() {
        widgetPublisher?.publishNow()
    }

    /// After an iCloud sync, all as maintenance without Undo (P2.4): merge duplicates of the last weeks (the whole
    /// store once a day, P2.13), work through the rescore requests and score the last closed weeks again (iPhone,
    /// P2.1), fill in category week scores, clean up values a backup brought twice (P3.2); then reminders, widget,
    /// menu bar.
    func afterSync() {
        guard !isSandbox, !launch.isDemo else { return }
        let store = self.store
        let today: DayKey = self.today
        let kept: [WeekKey] = store.withoutUndo { () -> [WeekKey] in
            store.mergeDuplicates(since: today.week.adding(weeks: -3))
            let kept: [WeekKey] = store.processRescoreRequests()
            // A week closed or edited on the Mac, Watch or iPad gets its score with Health values (iPhone).
            store.rescoreRecentClosedWeeks(through: today.week)
            // v10 (§1.2.3): closed weeks that arrived only now (a freshly set-up device) get their category
            // week scores – each week is looked at once per device, so this costs nothing afterwards.
            store.backfillCategoryScores(today: today)
            store.cleanRestoreDuplicates()
            return kept
        }
        showKeptScores(kept)
        clearRemindersOfClosedDays()
        clearRemindersOfClosedWeeks()
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
        // HEALTHSHARE: an App Store build (verified this launch) deletes shared records that arrived with this sync and writes
        // the state off – the TestFlight iPhone stops at its next sync, not only after this device's next launch (§1.4.3;
        // stays with the clean-up).
        if HealthShareGate.isConfirmedDenied { store.cleanUpHealthShare(gate: .denied, today: today) }
        // HEALTHSHARE: a sharing state from another device – the writer check and the privacy texts follow (§1.4.5, §1.4.10).
        healthShare.syncArrived(store: store)
        syncTick += 1
    }

    /// v11 P4.17: a week closed on another device – its "Wochenabschluss" reminder goes, and the reminders are
    /// planned anew once ("Nächste Woche planen" when the next week has no plan yet).
    private func clearRemindersOfClosedWeeks() {
        let store = self.store
        var changed = false
        for week in [today.week.adding(weeks: -1), today.week] {
            guard store.plan(week)?.isClosed ?? false else {
                closedReminderWeeks.remove(week)
                continue
            }
            guard closedReminderWeeks.insert(week).inserted else { continue }
            ReminderScheduler.weekClosed(week)
            changed = true
        }
        if changed { scheduleReminders() }
    }

    /// Days closed on another device: their evening reminder (planned, snoozed or shown) goes away.
    func clearRemindersOfClosedDays() {
        guard !isSandbox, !launch.isDemo else { return }
        for offset in -1..<7 {
            let day = today.adding(days: offset)
            if skipsEveningReminder(day) { ReminderScheduler.dayClosed(day) }
        }
    }

    /// "Geräte im Abgleich": this device opened Thalia (at most every 10 minutes).
    func recordDeviceSeen() {
        guard !isSandbox, !launch.isDemo else { return }
        store.recordDeviceSeen(kind: SyncDeviceKind.current)
    }

    /// ✓ from the widget (R87): only when the item is still open on that day.
    func applyWidgetAction(_ action: WidgetMarkAction) {
        guard let week = WeekKey(action.weekKey), let day = DayKey(action.dayKey) else { return }
        let store = self.store
        guard let item = store.items(week).first(where: { $0.code == action.itemCode }) else { return }
        let context = store.weekContext(for: week, today: today, goalYear: false)
        guard context.mark(item, on: day) == nil else { return }
        let saveDate = Date()
        store.setMark(.done, item: item, day: day)
        // v11 P4.14: the iPhone stays awake until the tick has gone to iCloud (at most 20 s).
        BackgroundGrace.holdForExport(after: saveDate)
        widgetPublisher?.publishNow()
        AppLog.info("Widget tick applied", category: "widget")
    }

    /// Ticks the widget queued while the app wasn't reachable (R87).
    func drainWidgetActions() {
        #if os(iOS)
        guard !isSandbox, !launch.isDemo else { return }
        for action in WidgetBridge.drainPending() { applyWidgetAction(action) }
        #endif
    }

    /// v11 P4.10: only while Thalia is in the menu bar, without the goal year (the title needs only the day).
    private func updateMenuBarTitle() {
        #if os(macOS)
        guard !isSandbox, menuBarEnabled else { return }
        pendingMenuBarTitle?.cancel()
        pendingMenuBarTitle = nil
        let context = store.weekContext(for: today.week, today: today, goalYear: false)
        let title: String = context.hasPlan ? context.dayStatusText(today) : ""
        if title != menuBarTitle { menuBarTitle = title }
        #endif
    }

    /// After a save: the title once the saves have settled (300 ms) – a burst of saves builds the week once.
    private func updateMenuBarTitleSoon() {
        guard !isSandbox, menuBarEnabled else { return }
        pendingMenuBarTitle?.cancel()
        pendingMenuBarTitle = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.updateMenuBarTitle()
        }
    }

    // MARK: Toast layers (R13)

    func registerToastHost(_ id: UUID) {
        toastHosts.removeAll { $0 == id }
        toastHosts.append(id)
        toastLevel = toastHosts.count
    }

    func unregisterToastHost(_ id: UUID) {
        toastHosts.removeAll { $0 == id }
        toastLevel = toastHosts.count
    }

    /// 1 for the first layer (the window), 2 for a sheet on it …; 0 when not registered.
    func toastLayer(of id: UUID) -> Int {
        (toastHosts.firstIndex(of: id) ?? -1) + 1
    }

    // MARK: Reminders (R80)

    /// Plans the reminders again (every time the app becomes active, 7 evenings ahead).
    func scheduleReminders(authorize: Bool = false) {
        guard !isSandbox, !launch.isDemo else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            _ = await ReminderScheduler.apply(ReminderScheduler.load(), authorize: authorize, isClosed: { self.skipsEveningReminder($0) })
        }
    }

    // MARK: Actions with Undo and feedback

    func setMark(_ mark: Mark?, item: PlanItem, day: DayKey) {
        store.setMark(mark, item: item, day: day)
    }

    func cycleMark(_ current: Mark?, item: PlanItem, day: DayKey) {
        setMark(Mark.cycle(current), item: item, day: day)
    }

    /// Power-hours always with an area and what they were for (K1); a toast with Undo (R13).
    func addPowerHours(_ powerHours: Double, categoryKey: String, task: String, day: DayKey,
                       result: String = "", nextStep: String = "") {
        let what: String = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryKey.isEmpty, !what.isEmpty else { return }
        let block = store.addWork(day: day, categoryKey: categoryKey, task: what, powerHours: powerHours,
                                  result: result.trimmingCharacters(in: .whitespacesAndNewlines),
                                  nextStep: nextStep.trimmingCharacters(in: .whitespacesAndNewlines))
        toasts.show("\(Format.powerHours(powerHours)) · \(what)", symbol: "bolt.fill") { [weak self] in
            self?.store.trash([block])
        }
    }

    func trash(_ blocks: [WorkBlock]) {
        guard !blocks.isEmpty else { return }
        let trashed = store.trash(blocks)
        toasts.show(trashed.count == 1 ? "Power-Hours gelöscht" : "\(trashed.count) PH-Einträge gelöscht", symbol: "trash.fill") { [weak self] in
            self?.store.restore(trashed)
        }
    }

    func trash(_ notes: [DayNote]) {
        guard !notes.isEmpty else { return }
        let trashed = store.trash(notes)
        toasts.show("Notiz gelöscht", symbol: "trash.fill") { [weak self] in
            self?.store.restore(trashed)
        }
    }

    func trash(_ entries: [MeasureEntry]) {
        guard !entries.isEmpty else { return }
        let trashed = store.trash(entries)
        toasts.show("Eintrag gelöscht", symbol: "trash.fill") { [weak self] in
            self?.store.restore(trashed)
        }
    }

    func trash(_ items: [PlanItem], carryOver: Bool = true) {
        guard !items.isEmpty else { return }
        let trashed = store.trash(items, carryOver: carryOver)
        toasts.show(trashed.count == 1 ? "Punkt gelöscht" : "\(trashed.count) Punkte gelöscht", symbol: "trash.fill") { [weak self] in
            self?.store.restore(trashed)
        }
    }

    func trash(_ measures: [MeasureDefinition], carryOver: Bool = true) {
        guard !measures.isEmpty else { return }
        let trashed = store.trash(measures, carryOver: carryOver)
        toasts.show("Messwert gelöscht", symbol: "trash.fill") { [weak self] in
            self?.store.restore(trashed)
        }
    }

    /// One tap for many items (V4), with Undo.
    func setAll(_ mark: Mark?, items: [PlanItem], day: DayKey, scope: String) {
        guard !items.isEmpty else { return }
        let previous = store.setMarks(mark, items: items, day: day)
        let what = mark.map { "\($0.symbol) \($0.label)" } ?? "geleert"
        toasts.show("\(items.count) \(items.count == 1 ? "Punkt" : "Punkte") · \(what)", symbol: "checklist") { [weak self] in
            // v11 P2.5: a mark that wasn't there goes again (no empty own mark hides a ✓ from a connected app).
            self?.store.restoreMarks(previous)
        }
    }

    /// One spending with what it was for (K2); Undo removes it again.
    func addExpense(_ amount: Double, what: String, measure: MeasureDefinition, day: DayKey) {
        let rounded: Double = (amount * 100).rounded() / 100
        let note: String = what.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = store.addEntry(code: measure.code, day: day, value: rounded, note: note)
        toasts.show("\(Format.measure(rounded, unit: "€")) · \(note)", symbol: "eurosign.circle.fill") { [weak self] in
            self?.store.trash([entry])
        }
    }

    /// Sets a measurement's day value (typed into the tile). Existing entries are changed, what
    /// falls away goes to the trash; Undo puts every entry back exactly (R2).
    func setValue(_ value: Double?, for measure: MeasureDefinition, day: DayKey, toast: Bool = true) {
        let change = store.setDayValue(code: measure.code, day: day, value: value)
        guard toast, !change.isEmpty else { return }
        let shown: String = value.map { Format.measure($0, unit: measure.unit) } ?? "geleert"
        toasts.show("\(measure.title): \(shown)", symbol: "checkmark.circle.fill") { [weak self] in
            self?.store.undo(change)
        }
    }

    /// Takes over suggestions from measurements (R12), with Undo.
    func applySuggestions(_ suggestions: [MarkSuggestion], day: DayKey) {
        guard !suggestions.isEmpty else { return }
        let previous = store.apply(suggestions: suggestions.map { ($0.item, $0.mark) }, day: day)
        let count: String = Format.count(suggestions.count, "Vorschlag", "Vorschläge")
        toasts.show("\(count) übernommen", symbol: "wand.and.stars") { [weak self] in
            self?.store.restoreMarks(previous)
        }
    }

    /// Changes a spending (R46): amount, what for, day; Undo restores it exactly.
    func updateExpense(_ entry: MeasureEntry, amount: Double, what: String, day: DayKey) {
        guard amount > 0, amount.isFinite else { return }
        let before = store.editExpense(entry, amount: amount, what: what, day: day)
        toasts.show("Ausgabe geändert", symbol: "eurosign.circle.fill") { [weak self] in
            self?.store.restore(before)
        }
    }

    /// Closes the day; its evening reminder is no longer needed (R80).
    func closeDay(_ day: DayKey) {
        store.closeDay(day)
        if !isSandbox, !launch.isDemo { ReminderScheduler.dayClosed(day) }
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
    }

    /// Opens the day again; its evening reminder is planned again (R80).
    func reopenDay(_ day: DayKey) {
        store.reopenDay(day)
        if !isSandbox, !launch.isDemo {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await ReminderScheduler.dayReopened(day, isClosed: { self.skipsEveningReminder($0) })
            }
        }
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
    }

    /// Closes the week (its score is kept) with a short confirmation. v11 P4.17: its "Wochenabschluss" reminder
    /// goes (pending or shown); the reminders are planned anew ("Nächste Woche planen" without a next plan).
    func closeWeek(_ week: WeekKey) {
        store.closeWeek(week)
        toasts.show("\(week.label) abgeschlossen", symbol: "checkmark.seal.fill")
        guard !isSandbox, !launch.isDemo else { return }
        ReminderScheduler.weekClosed(week)
        closedReminderWeeks.insert(week)
        weekStateChanged()
    }

    /// v11 P6.8: opens a closed week again. What it stored is kept first, so "Widerrufen" brings back the closed
    /// state, the final score, the goal scores and the category week scores exactly – without scoring. The
    /// reminders are planned anew (P4.17). The question for a frozen week is the caller's (CloseWeekView).
    func reopenWeek(_ week: WeekKey) {
        let store = self.store
        let snapshot: ClosedWeekSnapshot? = store.closedWeekSnapshot(week)
        store.reopenWeek(week)
        closedReminderWeeks.remove(week)
        weekStateChanged()
        guard let snapshot, snapshot.closedAt != nil else { return }
        toasts.show("\(week.label) wieder geöffnet", symbol: "lock.open") { [weak self] in
            guard let self else { return }
            self.store.restore(snapshot)
            self.weekStateChanged()
        }
    }

    /// A week was opened again or restored: reminders, widget and menu bar follow.
    private func weekStateChanged() {
        scheduleReminders()
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
    }

    /// Adds `step` to a measurement (the + on a tile). Undo removes the entry again.
    func add(_ value: Double, to measure: MeasureDefinition, day: DayKey) {
        let entry = store.addEntry(code: measure.code, day: day, value: value)
        let shown = Format.measure(value, unit: measure.unit)
        toasts.show("\(measure.title) +\(shown)", symbol: "plus.circle.fill") { [weak self] in
            self?.store.trash([entry])
        }
    }

    /// v11 P3.16: the newest copy of a category (two devices that set up the structure before they synced).
    func categoryTitle(_ key: String) -> String {
        store.liveCategories().latest(by: \.key, modified: \.modifiedAt)[key]?.title ?? key
    }

    // MARK: Tour

    /// v11 (§1.8.1, P1.19): the tour's steps – Tour 11 with "Sicherung" and "Genauer gerechnet". The one place
    /// that picks the catalog: P9 passes whether sharing Health values is allowed (the step "health-share", after
    /// waiting at most 2 s for the gate in `offerTourIfNeeded`); until then the tour without that step.
    var tourCatalog: TourCatalog<ThaliaTourSnapshot> {
        // HEALTHSHARE: the step "health-share" only where sharing Health values is allowed (TestFlight, debug builds).
        ThaliaTour.catalog(healthShare: HealthShareGate.isAllowed)
    }

    /// Opens the tour once after install, and the "Neu in Thalia" steps after an update that added some.
    func offerTourIfNeeded() {
        guard !isSandbox, !launch.isDemo, tour == nil else { return }
        Task { @MainActor [weak self] in
            // HEALTHSHARE: at most 2 s for the gate – otherwise Tour 11 would be marked seen without "health-share".
            _ = await HealthShareGate.resolve(timeout: .seconds(2))
            guard let self, self.tour == nil else { return }
            let catalog = self.tourCatalog
            let steps = TourSchedule().stepsToOffer(catalog)
            guard !steps.isEmpty else { return }
            AppLog.info("Tour offered (\(steps.count) steps)", category: "tour")
            self.tour = TourRequest(steps: steps)
        }
    }

    /// Replay from Settings or Help → Thalia-Tour. A sheet has to close first.
    func startTour() {
        guard sheet != nil else {
            tour = TourRequest(steps: tourCatalog.allSteps)
            return
        }
        sheet = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard let self else { return }
            self.tour = TourRequest(steps: self.tourCatalog.allSteps)
        }
    }

    /// After the tour Thalia asks for permission to send reminders (R80).
    func finishTour() {
        TourSchedule().markSeen(tourCatalog)
        tour = nil
        tourModel = nil
        scheduleReminders(authorize: true)
    }

    // MARK: v11 – backup (P4.9, P3.13)

    /// Ablage → "Sicherung erstellen…" (Mac): the whole backup, built off the main thread from the real store (never
    /// the tour's practice store); the main window's file exporter then offers to save it (`backupFile`).
    func makeBackup() {
        guard !isSandbox, !isMakingBackup else { return }
        isMakingBackup = true
        let store = self.store
        Task { @MainActor [weak self] in
            let text = await BackupWriter.exportText(store: store)
            guard let self else { return }
            self.isMakingBackup = false
            self.backupFile = CSVFile(text: text)
        }
    }

    /// The file exporter of `backupFile` finished: saved → `backup.last` (on every device "… am Mac") and
    /// "Sicherung gespeichert"; otherwise the reason. Cancelling says nothing.
    func backupSaved(_ result: Result<URL, Error>) {
        backupFile = nil
        switch result {
        case .success:
            BackupWriter.stamp(store: store)
            toasts.show(BackupWriter.savedToast, symbol: "externaldrive.badge.checkmark")
        case .failure(let error):
            if (error as NSError).code == NSUserCancelledError { return }
            toasts.show("Sicherung nicht gespeichert: \(error.localizedDescription)", symbol: "exclamationmark.triangle")
        }
    }

    /// v11 P3.13 step 2: when Thalia goes to the background (iPhone, with a little background time) or another app
    /// comes to the front (Mac), the weekly automatic backup is written if it is due – never from `-Demo` or the
    /// practice page, never while a closing sheet is open. `BackupWriter` checks iCloud or local mode, the first
    /// sync and the 7 days.
    private func startBackupWatch() {
        #if os(iOS)
        let wentAway: Notification.Name = UIApplication.didEnterBackgroundNotification
        #else
        let wentAway: Notification.Name = NSApplication.didResignActiveNotification
        #endif
        observers.append(NotificationCenter.default.addObserver(forName: wentAway, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.writeWeeklyBackupIfDue() }
        })
    }

    private func writeWeeklyBackupIfDue() {
        guard !isSandbox, !launch.isDemo, !isWritingBackup, !isClosingSheetOpen,
              BackupWriter.isDue(today: today, lastAuto: BackupWriter.lastAuto) else { return }
        isWritingBackup = true
        let store = self.store
        let today: DayKey = self.today
        let mode: StorageMode = self.mode
        BackgroundGrace.run("Thalia Sicherung") { [weak self] in
            await BackupWriter.writeWeeklyIfDue(store: store, today: today, mode: mode)
            self?.isWritingBackup = false
        }
    }

    /// "Tag abschließen" or "Woche abschließen" is open – no automatic backup meanwhile ("nie im Abschluss-Fenster").
    private var isClosingSheetOpen: Bool {
        switch sheet {
        case .closeDay?, .closeWeek?: return true
        default: return false
        }
    }

    // MARK: v11 – sync state (P4.15, P4.18)

    /// v11 P4.18: the lasting sync problem to show on the main screen (iPhone above the content, Mac at the foot of
    /// the sidebar and in the menu bar window) – never in the demo or on the practice page, never for short errors.
    var syncProblem: SyncProblem? {
        guard !isSandbox else { return nil }
        let state: SyncState = syncProblemState
        guard SyncGerman.isPersistentProblem(mode: state.mode, account: state.account, quotaExceeded: quotaExceededShown) else {
            return nil
        }
        switch state.mode {
        case .memory: return SyncProblem(kind: .memory)
        case .local: return SyncProblem(kind: .local)
        case .iCloud: return SyncProblem(kind: state.account == .noAccount ? .noAccount : .quotaFull)
        case .demo: return nil
        }
    }

    /// The sync state the line looks at – debug builds can fake one (`-FakeSyncProblem local|memory|quota`).
    private var syncProblemState: SyncState {
        #if DEBUG
        switch fakeSyncProblem {
        case "local": return SyncState(mode: .local(reason: nil))
        case "memory": return SyncState(mode: .memory(reason: nil))
        case "quota": return SyncState(mode: .iCloud(container: ""), account: .available)
        default: break
        }
        #endif
        return sync.state
    }

    private var quotaExceededShown: Bool {
        #if DEBUG
        if fakeSyncProblem == "quota" { return true }
        #endif
        return quotaExceeded
    }

    /// The line as it shows: an orange one closed for this launch is gone, the red one never.
    var visibleSyncProblem: SyncProblem? {
        guard let problem = syncProblem else { return nil }
        return syncProblemDismissed && !problem.isCritical ? nil : problem
    }

    /// v11 P4.15: Einstellungen → "Geräte im Abgleich" → "Entfernen" for an old installation – its entry and its
    /// version go (an active device notes itself again); "Widerrufen" writes them back.
    func forgetDevice(_ device: SyncDevice, label: String) {
        guard !isSandbox else { return }
        let store = self.store
        let buildKey: String = SyncBuild.key(installID: device.installID)
        let seenValue: String? = store.setting(device.key)
        let buildValue: String? = store.setting(buildKey)
        writeDevice(seen: nil, build: nil, device: device)
        AppLog.info("Device removed from the sync list", category: "sync")
        toasts.show("„\(label)“ entfernt", symbol: "trash") { [weak self] in
            self?.writeDevice(seen: seenValue, build: buildValue, device: device)
        }
    }

    private func writeDevice(seen: String?, build: String?, device: SyncDevice) {
        let store = self.store
        let now = Date()
        store.withoutUndo {
            var change = RecordChange()
            store.writeSetting(device.key, seen, now: now, change: &change)
            store.writeSetting(SyncBuild.key(installID: device.installID), build, now: now, change: &change)
            if !change.isEmpty { store.commit(change, origin: .maintenance) }
        }
        syncTick += 1
    }

    // MARK: Opening things

    /// A CSV opened from Files or another app, or a deep link (thalia://close-day …).
    func open(_ url: URL) {
        if url.scheme == AppInfo.urlScheme {
            route(url.host() ?? url.lastPathComponent)
            return
        }
        AppLog.info("Opened \(url.lastPathComponent)", category: "import")
        pendingImport = url
        sheet = .importPlan(prompt: false)
    }

    /// Widget, notification and Shortcut destinations. "close-day:2026-11-16" and
    /// "close-week:2026-W47" carry their day / week (R18, R40). v11 P4.2: on the Mac the main window comes to the
    /// front first – or opens when it was closed (never from the practice page or the tour).
    func route(_ destination: String) {
        #if os(macOS)
        if !isSandbox && tour == nil { MainWindow.showWithoutEnvironment() }
        #endif
        refreshToday()
        let parts: [String] = destination.split(separator: ":", maxSplits: 1).map(String.init)
        let name: String = parts.first ?? destination
        let argument: String? = parts.count > 1 ? parts[1] : nil
        switch name {
        case "close-day":
            let day: DayKey = argument.flatMap { DayKey($0) } ?? dayToClose()
            tab = .today
            sidebar = .today
            selectedDay = day
            selectedWeek = day.week
            sheet = .closeDay(day)
        case "close-week":
            let week: WeekKey = argument.flatMap { WeekKey($0) } ?? weekToCloseNow()
            tab = .week
            sidebar = .week
            selectedWeek = week
            sheet = .closeWeek(week)
        case "week":
            tab = .week
            sidebar = .week
            selectedWeek = today.week
        case "goals":
            tab = .goals
            sidebar = .goals
        case "import":
            sheet = .importPlan(prompt: true)
        case "work":
            tab = .today
            sidebar = .today
            sheet = .work(WorkDraft(day: today))
        case "create":
            tab = .today
            sidebar = .today
            sheet = .create
        case "expense":
            sheet = .expenses(today)
        case "focus":
            sheet = .focus(today)
        case "glance":
            #if os(macOS)
            // The Mac shows "Heute im Blick" as the right column next to Today (R59) – as a sheet while the
            // window is too narrow for it (P4.1).
            tab = .today
            sidebar = .today
            if fitsGlanceInspector {
                showsGlanceInspector = true
            } else {
                sheet = .dayOverview(today)
            }
            #else
            sheet = .dayOverview(today)
            #endif
        case "goal-review":
            sheet = .goalReview
        case "weekly-goals":
            sheet = .weeklyGoals(today.week)
        case "past-import":
            sheet = .importPast(argument.flatMap { WeekKey($0) })
        case "range-pdf":
            sheet = .rangePDF
        case "connected-apps":
            sheet = .connectedApps
        case "reading":
            sheet = .reading(today, itemID: nil)
        case "goal-entry":
            sheet = .goalEntry(today, resultID: nil)
        default:
            tab = .today
            sidebar = .today
            selectedDay = today
        }
    }

    // MARK: Launch arguments (screenshots in CI)

    /// `-Demo -DemoScreen <name>` opens a screen; `-Tour` / `-TourStep <id>` open the tour.
    private func applyLaunchOptions() {
        if launch.resetTour { TourSchedule().reset() }
        switch launch.screen {
        case "week":
            tab = .week
            sidebar = .week
        case "goals":
            tab = .goals
            sidebar = .goals
        case "review":
            tab = .review
            sidebar = .review
        case "create":
            sheet = .create
        case "close-day":
            sheet = .closeDay(today)
        case "close-week":
            tab = .week
            sidebar = .week
            selectedWeek = today.week.adding(weeks: -1)
            sheet = .closeWeek(today.week.adding(weeks: -1))
        case "import":
            sheet = .importPlan(prompt: true)
        case "work":
            sheet = .work(WorkDraft(day: today))
        case "overview":
            sheet = .dayOverview(today)
        case "focus":
            sheet = .focus(today)
        case "expenses":
            sheet = .expenses(today)
        case "weekly-goals":
            sheet = .weeklyGoals(today.week)
        case "goal-review":
            sheet = .goalReview
        case "trash":
            sheet = .trash
        case "pdf-week":
            sheet = .pdf(.week(today.week.adding(weeks: -1)))
        case "pdf-day":
            sheet = .pdf(.day(today))
        case "past-import":
            sheet = .importPast(nil)
        case "range-pdf":
            sheet = .rangePDF
        case "archive":
            // v9: the demo's archive week with its "Archiv" card (grades, a holiday, "Ohne Zuordnung").
            tab = .week
            sidebar = .week
            selectedWeek = Demo.archiveWeek(today: today)
        case "report":
            sheet = .report(today.week.adding(weeks: -1))
        case "explainer":
            sheet = .explainer(.scoring)
        case "settings":
            sheet = .settings
        case "backup":
            // v11 (§1.8.2): Einstellungen → Deine Daten → "Sicherungen".
            sheet = .settingsPage(.backups)
        case "health":
            // HEALTHSHARE: Einstellungen → Apple Health with "Health-Werte mit Mac und Watch teilen" (iPhone; the gate is
            // open in debug builds, the demo shows the switch on).
            #if os(iOS)
            sheet = .settingsPage(.health)
            #else
            break
            #endif
        case "goal-detail", "reading":
            // v10: the Ziele page opens the books goal's page or the reading list by itself (once per launch).
            tab = .goals
            sidebar = .goals
        case "connected-apps":
            // v10: the demo's sample source "Demo" from its records – the App Group is never touched.
            sheet = .connectedApps
        default:
            break
        }
        if launch.startTour { startTour() }
    }
}
