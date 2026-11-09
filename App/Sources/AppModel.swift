import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

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
    var categoryKey: String = "3.2"
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
    case dayInfo(DayKey)
    case weekInfo(WeekKey)
    case report(WeekKey)
    case explainer(Explainer)
    case trash
    case settings

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
        case .dayInfo(let day): "day-" + day.string
        case .weekInfo(let week): "week-" + week.string
        case .report(let week): "report-" + week.string
        case .explainer(let explainer): "explainer-" + explainer.rawValue
        case .trash: "trash"
        case .settings: "settings"
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
    /// Today's date, refreshed when the app becomes active (midnight passes).
    var today: DayKey = .today()

    init(container: ModelContainer, mode: StorageMode, launch: LaunchOptions = .current, isSandbox: Bool = false) {
        self.container = container
        self.mode = mode
        self.launch = launch
        self.isSandbox = isSandbox
        self.sync = SyncMonitor(mode: isSandbox ? .demo : mode, appName: AppInfo.name)
        self.toasts = ToastCenter()
        guard !isSandbox else { return }
        applyLaunchOptions()
        if !launch.isDemo { store.purgeExpired() }
    }

    var store: TrackerStore { TrackerStore(context: container.mainContext) }

    /// Where menu commands act: the practice page during the tour, otherwise this model.
    var commandTarget: AppModel { tourModel ?? self }

    func refreshToday() {
        let now = DayKey.today()
        guard now != today else { return }
        if selectedDay == today { selectedDay = now }
        if selectedWeek == today.week { selectedWeek = now.week }
        today = now
    }

    // MARK: Actions with Undo and feedback

    func setMark(_ mark: Mark?, item: PlanItem, day: DayKey) {
        store.setMark(mark, item: item, day: day)
    }

    func cycleMark(_ current: Mark?, item: PlanItem, day: DayKey) {
        setMark(Mark.cycle(current), item: item, day: day)
    }

    /// Quick power-hours for a category, right away ("+1 PH" on a work tile, the watch, Shortcuts).
    func addPowerHours(_ powerHours: Double, categoryKey: String, task: String = "", day: DayKey) {
        let block = store.addWork(day: day, categoryKey: categoryKey, task: task, powerHours: powerHours)
        let title = task.isEmpty ? categoryTitle(categoryKey) : task
        toasts.show("\(Format.powerHours(powerHours)) · \(title)", symbol: "bolt.fill") { [weak self] in
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

    /// A category's power-hours for a day, set on the tile (− / typed); Undo sets the old total.
    func setWorkTotal(_ powerHours: Double?, categoryKey: String, day: DayKey) {
        let old = store.weekContext(for: day.week, today: today).work(on: day)
            .filter { $0.categoryKey == categoryKey }.reduce(0) { $0 + $1.hours }
        store.setWorkTotal(categoryKey: categoryKey, day: day, powerHours: powerHours ?? 0)
        let new = powerHours ?? 0
        guard abs(new - old) > 1e-9, new < old else { return }
        toasts.show("\(categoryTitle(categoryKey)): \(Format.powerHours(new))", symbol: "bolt") { [weak self] in
            self?.store.setWorkTotal(categoryKey: categoryKey, day: day, powerHours: old)
        }
    }

    /// Sets a measurement's day value (typed into the tile); Undo sets the old value again.
    func setValue(_ value: Double?, for measure: MeasureDefinition, day: DayKey, toast: Bool = true) {
        let aggregation = measure.record?.aggregation ?? .sum
        let old = aggregation.apply(store.entries(code: measure.code, day: day).sorted { $0.recordedAt < $1.recordedAt }.compactMap(\.value))
        guard old != value else { return }
        store.setDayValue(code: measure.code, day: day, value: value)
        guard toast else { return }
        let shown = value.map { Format.measure($0, unit: measure.unit) } ?? "geleert"
        toasts.show("\(measure.title): \(shown)", symbol: "checkmark.circle.fill") { [weak self] in
            self?.store.setDayValue(code: measure.code, day: day, value: old)
        }
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

    func finishTour() {
        TourSchedule().markSeen(ThaliaTour.catalog)
        tour = nil
        tourModel = nil
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

    /// Widget, notification and Shortcut destinations.
    func route(_ destination: String) {
        refreshToday()
        switch destination {
        case "close-day":
            tab = .today
            sidebar = .today
            selectedDay = today
            sheet = .closeDay(today)
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
