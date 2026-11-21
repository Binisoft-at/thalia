import SwiftUI
import SwiftData
import CoreData
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
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var widgetPublisher: WidgetPublisher?

    init(container: ModelContainer, mode: StorageMode, launch: LaunchOptions = .current, isSandbox: Bool = false) {
        self.container = container
        self.mode = mode
        self.launch = launch
        self.isSandbox = isSandbox
        self.sync = SyncMonitor(mode: isSandbox ? .demo : mode, appName: AppInfo.name)
        self.toasts = ToastCenter()
        guard !isSandbox else { return }
        // v8: no evening reminder on sick and holiday days, whoever plans the reminders.
        ReminderScheduler.skipsDay = { [weak self] day in self?.isDayExcused(day) ?? false }
        applyLaunchOptions()
        startDayWatch()
        if !launch.isDemo {
            store.purgeExpired()
            store.mergeDuplicates()
            let publisher = WidgetPublisher(container: container)
            publisher.start()
            widgetPublisher = publisher
        }
        updateMenuBarTitle()
    }

    var store: TrackerStore { TrackerStore(context: container.mainContext) }

    /// Where menu commands act: the practice page during the tour, otherwise this model.
    var commandTarget: AppModel { tourModel ?? self }

    /// The day every capture sheet starts with (R41).
    var captureDay: DayKey { selectedDay }

    /// Menu commands that open a sheet do nothing while a sheet holds unsaved input (R14).
    var blocksSheetCommands: Bool { sheet != nil && hasUnsavedInput }

    /// Mac: "Heute im Blick" as the right column next to Today; the choice survives a restart (R59).
    var showsGlanceInspector: Bool {
        get { inspectorStorage }
        set {
            inspectorStorage = newValue
            if !isSandbox { UserDefaults.standard.set(newValue, forKey: AppModel.inspectorKey) }
        }
    }

    var menuBarEnabled: Bool {
        get { menuBarStorage }
        set {
            guard newValue != menuBarStorage else { return }
            menuBarStorage = newValue
            if !isSandbox { UserDefaults.standard.set(newValue, forKey: MenuBarSettings.enabledKey) }
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
        #if os(macOS)
        // Delivered on the posting thread and handed to the main actor afterwards: a save on a
        // background context never waits for the main thread here.
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in self?.updateMenuBarTitle() }
        })
        #endif
        // v8: a day became sick / holiday (or back): its evening reminder goes away or comes back.
        observers.append(center.addObserver(forName: TrackerStore.dayInfoChanged, object: nil, queue: nil) { [weak self] note in
            let key: String? = note.userInfo?["day"] as? String
            Task { @MainActor in self?.dayInfoChanged(key.flatMap { DayKey($0) }) }
        })
        // Changes from other devices: a finished import from iCloud. Here and not in a view, so it
        // also works on the Mac with only the menu bar open (no main window).
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                  event.type == .import, event.endDate != nil else { return }
            Task { @MainActor in self?.afterSyncSoon() }
        })
    }

    /// v8: after `setDayInfo` – no evening reminder on a sick or holiday day; the others planned anew.
    private func dayInfoChanged(_ day: DayKey?) {
        guard !isSandbox, !launch.isDemo else { return }
        if let day, isDayExcused(day) { ReminderScheduler.dayClosed(day) }
        scheduleReminders()
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
    }

    /// After an import: give the main context a moment to merge, then `afterSync`.
    private func afterSyncSoon() {
        pendingSync?.cancel()
        pendingSync = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.afterSync()
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

    /// The day "Tag abschließen" is about (R18): a day other than today that is on screen, else
    /// before 4:00 the day before while it is still open, else today.
    func dayToClose(showing day: DayKey? = nil) -> DayKey {
        if let day, day != today { return day }
        let store = self.store
        // v8: a sick or holiday day before 4:00 needs no closing – today then.
        return DayKey.closingDay(isClosed: { (store.planDay($0)?.isClosed ?? false) || store.isExcused($0) })
    }

    /// The next / previous page of Today (R35).
    func moveTodayPage(by offset: Int) {
        let order = todayPageOrder
        guard !order.isEmpty, offset != 0 else { return }
        let current: Int? = todayPage.flatMap { order.firstIndex(of: $0) }
        let start: Int = current ?? (offset > 0 ? -1 : order.count)
        let next: Int = min(max(start + offset, 0), order.count - 1)
        todayPage = order[next]
    }

    // MARK: Widget, sync, menu bar (R4, R28, R87, R96)

    /// Writes the widget snapshot now (leaving the app). The Mac and in-memory stores never write.
    func publishWidgetNow() {
        widgetPublisher?.publishNow()
    }

    /// After an iCloud sync: merge duplicated days/weeks, refresh the widget and the menu bar.
    func afterSync() {
        guard !isSandbox, !launch.isDemo else { return }
        let store = self.store
        store.mergeDuplicates()
        // A week closed or edited on the Mac or Watch gets its score with Health values (iPhone/iPad).
        store.rescoreRecentClosedWeeks(through: today.week)
        clearRemindersOfClosedDays()
        widgetPublisher?.publishNow()
        updateMenuBarTitle()
        syncTick += 1
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
        let context = store.weekContext(for: week, today: today)
        guard context.mark(item, on: day) == nil else { return }
        store.setMark(.done, item: item, day: day)
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

    private func updateMenuBarTitle() {
        #if os(macOS)
        guard !isSandbox else { return }
        let context = store.weekContext(for: today.week, today: today)
        let title: String = context.hasPlan ? context.dayStatusText(today) : ""
        if title != menuBarTitle { menuBarTitle = title }
        #endif
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
            self?.store.restoreMarks(previous, day: day)
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
            self?.store.restoreMarks(previous, day: day)
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

    /// Closes the week (its score is kept) with a short confirmation.
    func closeWeek(_ week: WeekKey) {
        store.closeWeek(week)
        toasts.show("\(week.label) abgeschlossen", symbol: "checkmark.seal.fill")
    }

    /// Adds `step` to a measurement (the + on a tile). Undo removes the entry again.
    func add(_ value: Double, to measure: MeasureDefinition, day: DayKey) {
        let entry = store.addEntry(code: measure.code, day: day, value: value)
        let shown = Format.measure(value, unit: measure.unit)
        toasts.show("\(measure.title) +\(shown)", symbol: "plus.circle.fill") { [weak self] in
            self?.store.trash([entry])
        }
    }

    func categoryTitle(_ key: String) -> String {
        store.liveCategories().first { $0.key == key }?.title ?? key
    }

    // MARK: Tour

    /// Opens the tour once after install, and the "Neu in Thalia" steps after an update that added some.
    func offerTourIfNeeded() {
        guard !isSandbox, !launch.isDemo, tour == nil else { return }
        let steps = TourSchedule().stepsToOffer(ThaliaTour.catalog)
        guard !steps.isEmpty else { return }
        AppLog.info("Tour offered (\(steps.count) steps)", category: "tour")
        tour = TourRequest(steps: steps)
    }

    /// Replay from Settings or Help → Thalia-Tour. A sheet has to close first.
    func startTour() {
        guard sheet != nil else {
            tour = TourRequest(steps: ThaliaTour.catalog.allSteps)
            return
        }
        sheet = nil
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            self?.tour = TourRequest(steps: ThaliaTour.catalog.allSteps)
        }
    }

    /// After the tour Thalia asks for permission to send reminders (R80).
    func finishTour() {
        TourSchedule().markSeen(ThaliaTour.catalog)
        tour = nil
        tourModel = nil
        scheduleReminders(authorize: true)
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
    /// "close-week:2026-W47" carry their day / week (R18, R40).
    func route(_ destination: String) {
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
            let week: WeekKey = argument.flatMap { WeekKey($0) } ?? dayToClose().week
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
            // The Mac shows "Heute im Blick" as the right column next to Today (R59).
            tab = .today
            sidebar = .today
            showsGlanceInspector = true
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
        case "report":
            sheet = .report(today.week.adding(weeks: -1))
        case "explainer":
            sheet = .explainer(.scoring)
        case "settings":
            sheet = .settings
        default:
            break
        }
        if launch.startTour { startTour() }
    }
}
