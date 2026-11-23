import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
#endif

/// iPhone/iPad: tab bar (a sidebar on iPad) with a bottom accessory. Mac: split view.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let _ = diagBody("RootView")
        navigation
            .modifier(AppChrome(app: app, health: health))
            .modifier(TourPresenter(app: app, health: health))
            .onOpenURL { url in app.open(url) }
            .onReceive(NotificationCenter.default.publisher(for: .thaliaRoute)) { note in
                if let destination = note.object as? String { app.route(destination) }
                PendingRoute.destination = nil
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    app.refreshToday()
                    app.drainWidgetActions()
                    app.scheduleReminders()
                    app.clearRemindersOfClosedDays()
                    app.recordDeviceSeen()
                case .background, .inactive:
                    app.publishWidgetNow()
                @unknown default:
                    break
                }
            }
            .task {
                if let destination = PendingRoute.destination {
                    PendingRoute.destination = nil
                    app.route(destination)
                }
                // The tour opens by itself once after install (and as "Neu in Thalia" after updates).
                try? await Task.sleep(for: .milliseconds(800))
                app.offerTourIfNeeded()
            }
    }

    @ViewBuilder
    private var navigation: some View {
        #if os(macOS)
        MacRoot()
        #else
        PhoneRoot()
        #endif
    }
}

#if os(iOS)
private struct PhoneRoot: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Heute", systemImage: "sun.max", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Woche", systemImage: "tablecells", value: AppTab.week) {
                NavigationStack { WeekView() }
            }
            Tab("Ziele", systemImage: "target", value: AppTab.goals) {
                NavigationStack { GoalsView() }
            }
            Tab("Rückblick", systemImage: "chart.bar.xaxis", value: AppTab.review) {
                NavigationStack { ReviewView() }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .minimizingTabBar()
        .tabViewBottomAccessory {
            TodayAccessory()
        }
        // v11 P4.18: a lasting sync problem above the content.
        .safeAreaInset(edge: .top, spacing: 0) {
            SyncProblemBar()
        }
    }

    /// Tapping "Heute" again while it is shown goes back to today (R7).
    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { app.tab },
            set: { newTab in
                if newTab == .today && app.tab == .today {
                    app.goToToday()
                } else {
                    app.tab = newTab
                }
            }
        )
    }
}

/// The bottom accessory, right under the thumb (U10): the selected day's fill (R7), "+" to capture,
/// closing the day, and "Zu heute" when another day is shown.
private struct TodayAccessory: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let day: DayKey = app.selectedDay
        // v11 P2.14: the day's line needs no goal year.
        WeekReader(week: day.week, today: app.today, goalYear: false) { context in
            HStack(spacing: 12) {
                if context.hasPlan {
                    statusButton(context, day: day)
                } else {
                    noPlanButton(day: day)
                }
                Spacer(minLength: 4)
                if day != app.today {
                    Button {
                        app.goToToday()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Brand.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Zu heute")
                }
                Button {
                    app.sheet = .closeDay(app.dayToClose(showing: app.selectedDay))
                } label: {
                    Image(systemName: context.isClosed(day) ? "checkmark.seal.fill" : "moon.stars")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Brand.accent)
                }
                .buttonStyle(.plain)
                // v11 P5.6: says what the button does on a closed day.
                .accessibilityLabel(context.isClosed(day) ? "Tagesabschluss ansehen" : "Tag abschließen")
                Button {
                    app.sheet = .create
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                        .background(Color.accentFill, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Erfassen")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
        }
    }

    /// Ring and status of the selected day; a tap opens "Heute im Blick".
    private func statusButton(_ context: WeekContext, day: DayKey) -> some View {
        let overall: DayOverall? = context.score.days[day]
        let closed: Bool = context.isClosed(day)
        let shownScore: Double? = closed ? overall?.score : nil
        let detail: String = subtitle(context, day: day)
        return Button {
            app.sheet = .dayOverview(day)
        } label: {
            HStack(spacing: 10) {
                FillRing(fill: overall?.coverage ?? 0, score: shownScore, size: 28, lineWidth: 3.5,
                         excusedSymbol: excusedSymbol(context, day: day))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title(context, day: day))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                    if !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet „Heute im Blick“")
    }

    /// Without a plan: straight to planning the week (R5). The bar follows the selected day (R7),
    /// so it plans the week that has no plan – today's week whenever today is selected.
    private func noPlanButton(day: DayKey) -> some View {
        Button {
            app.sheet = .planWeek(day.week)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down")
                    .font(.title3)
                    .foregroundStyle(Brand.accent)
                    .frame(width: 28, height: 28)
                Text("Kein Plan – Wochenplan importieren")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// "Heute 73 %" · "So · 80 %" · "Tag abgeschlossen" · "Alles erfasst" (R5, R7).
    private func title(_ context: WeekContext, day: DayKey) -> String {
        let isToday: Bool = day == app.today
        let prefix: String = isToday ? "" : "\(day.weekday.short) · "
        // v8: a sick or holiday day has nothing open – it just doesn't count.
        if context.isExcused(day) { return prefix + context.excusedName(day) + " – zählt nicht" }
        if context.isClosed(day) { return isToday ? "Tag abgeschlossen" : prefix + "abgeschlossen" }
        if context.openCount(on: day) == 0 { return isToday ? "Alles erfasst" : prefix + "alles erfasst" }
        let coverage: String = context.score.days[day]?.coverageText ?? "0 %"
        return isToday ? "Heute \(coverage)" : prefix + coverage
    }

    /// v8: the day type's symbol on a sick or holiday day (the ring shows no progress then).
    private func excusedSymbol(_ context: WeekContext, day: DayKey) -> String? {
        context.isExcused(day) ? DayTypes.symbol(for: context.dayType(day)) : nil
    }

    /// "11 offen · 4 PH" – the open count is the ring's (R5).
    private func subtitle(_ context: WeekContext, day: DayKey) -> String {
        let totals = context.workTotals(on: day)
        let open: Int = context.openCount(on: day)
        var parts: [String] = []
        if open > 0 && !context.isClosed(day) { parts.append("\(open) offen") }
        if !totals.isEmpty { parts.append(totals.shortText) }
        return parts.joined(separator: " · ")
    }
}
#endif

#if os(macOS)
private struct MacRoot: View {
    @Environment(AppModel.self) private var app
    /// v11 P4.1: whether the sidebar shows (Darstellung → Seitenleiste ausblenden, P4.6) – for the room the
    /// inspectors have.
    @State private var columns: NavigationSplitViewVisibility = .automatic

    var body: some View {
        let _ = diagBody("MacRoot")
        NavigationSplitView(columnVisibility: $columns) {
            // v11 P4.4: a click into the empty part of the list keeps the page (the sidebar never becomes nil).
            List(selection: sidebarSelection) {
                Label("Heute", systemImage: "sun.max").tag(AppTab.today)
                Label("Woche", systemImage: "tablecells").tag(AppTab.week)
                Label("Ziele", systemImage: "target").tag(AppTab.goals)
                Label("Rückblick", systemImage: "chart.bar.xaxis").tag(AppTab.review)
            }
            .diagWidth("sidebar")
            // v11 P4.1: the sidebar's width (the room for page and inspector is the window without it).
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                if abs(app.sidebarWidth - width) >= 1 { app.sidebarWidth = width }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 320)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    // v11 P4.18: a lasting sync problem at the foot of the sidebar.
                    SyncProblemBar(compact: true)
                    // F4.1: today and the week in a few grey lines, always in view.
                    SidebarGlance()
                }
            }
        } detail: {
            NavigationStack {
                switch app.sidebar ?? .today {
                case .today: TodayView()
                case .week: WeekView()
                case .goals: GoalsView()
                case .review: ReviewView()
                }
            }
            // v11 P4.1: the detail as a whole; with the window and the sidebar it gives the room the inspectors
            // have (`AppModel.roomWidth`) – the same whether an inspector sits inside the detail or next to it.
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                diagMeasure("detail", width)
                if abs(app.detailWidth - width) >= 1 { app.detailWidth = width }
            }
        }
        // One window with a minimum size; sheets are sized to fit into it (R15).
        .frame(minWidth: 900, minHeight: 620)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { size in
            diagNote("main window \(Int(size.width)) × \(Int(size.height))")
            diagMeasure("window", size.width)
            if abs(app.mainWindowHeight - size.height) >= 1 { app.mainWindowHeight = size.height }
            if abs(app.mainWindowWidth - size.width) >= 1 { app.mainWindowWidth = size.width }
        }
        .onChange(of: columns) { _, visibility in
            app.showsSidebar = visibility != .detailOnly
        }
        // v11 P4.9: Ablage → "Sicherung erstellen…" – the save panel, on a view of its own (other windows and
        // sheets keep their own file exporters).
        .background {
            BackupExporter(app: app)
        }
        .onAppear { diagNote("MacRoot appeared") }
    }

    private var sidebarSelection: Binding<AppTab?> {
        let model: AppModel = app
        return Binding(get: { model.sidebar }, set: { tab in
            if let tab { model.sidebar = tab }
        })
    }
}

/// v11 P4.9: saves the backup Ablage → "Sicherung erstellen…" built (`AppModel.backupFile`): "Thalia Sicherung
/// 2026-11-23.csv", then `backup.last` and "Sicherung gespeichert" (`AppModel.backupSaved`).
private struct BackupExporter: View {
    let app: AppModel

    var body: some View {
        Color.clear
            .fileExporter(isPresented: isExporting, document: app.backupFile, contentType: .commaSeparatedText,
                          defaultFilename: BackupWriter.exportName(today: app.today)) { result in
                app.backupSaved(result)
            }
    }

    private var isExporting: Binding<Bool> {
        let model: AppModel = app
        return Binding(get: { model.backupFile != nil }, set: { if !$0 { model.backupFile = nil } })
    }
}
#endif

/// v11 P4.18: one calm line for a lasting sync problem – the store couldn't be opened (red, stays), iCloud off, no
/// iCloud account, iCloud full (orange, closed until the next launch). A tap opens Einstellungen (iCloud & Daten).
/// Nothing in the demo, on the practice page or for short network errors (`AppModel.syncProblem`).
struct SyncProblemBar: View {
    var compact = false
    @Environment(AppModel.self) private var app
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif

    var body: some View {
        if let problem = app.visibleSyncProblem {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Button {
                    openSyncSettings()
                } label: {
                    Label(problem.text, systemImage: problem.symbol)
                        .font(textFont)
                        .foregroundStyle(tint(problem))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet Einstellungen – iCloud & Daten")
                if !problem.isCritical {
                    Button {
                        app.syncProblemDismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hinweis ausblenden")
                    .help("Bis zum nächsten Start ausblenden")
                }
            }
            .padding(.horizontal, compact ? 10 : 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }

    private var textFont: Font {
        compact ? Font.caption : Font.footnote.weight(.medium)
    }

    /// Red when nothing is saved (the marks' readable red, R44), else orange.
    private func tint(_ problem: SyncProblem) -> Color {
        problem.isCritical ? Color("MarkMissedText") : Color.orange
    }

    private func openSyncSettings() {
        #if os(macOS)
        openSettings()
        NSApp.activate()
        #else
        guard !app.blocksSheetCommands else { return }
        app.sheet = .settings
        #endif
    }
}

/// The sheets any screen can open, toasts and undo. Shared by the window and the tour's practice page.
struct AppChrome: ViewModifier {
    @Bindable var app: AppModel
    let health: HealthService

    func body(content: Content) -> some View {
        content
            .sheet(item: $app.sheet) { sheet in
                SheetContent(sheet: sheet)
                    .environment(app)
                    .environment(health)
                    .modelContainer(app.container)
            }
            .toastHost(app)
            .undoableChanges(in: app.container.mainContext)
    }
}

private struct SheetContent: View {
    let sheet: AppSheet
    @Environment(AppModel.self) private var app

    var body: some View {
        shown
            .toastHost(app)
    }

    /// v11 P4.19: the tour's practice page offers nothing that reaches real things (import, past weeks, the PDF
    /// report, the trash, the archive, settings with the real reminders) – it says so instead.
    @ViewBuilder
    private var shown: some View {
        if app.isSandbox && isUnavailableInPractice {
            PracticeUnavailableView { app.sheet = nil }
        } else {
            content
        }
    }

    private var isUnavailableInPractice: Bool {
        switch sheet {
        case .importPlan, .importPast, .planWeek, .rangePDF, .trash, .archive, .settings, .settingsPage: return true
        default: return false
        }
    }

    @ViewBuilder
    private var content: some View {
        switch sheet {
        case .create:
            ThaliaCreateSheet()
        case .importPlan(let prompt):
            ImportView(showPrompt: prompt)
        case .closeDay(let day):
            CloseDayView(day: day)
        case .closeWeek(let week):
            CloseWeekView(week: week)
        case .work(let draft):
            WorkEditor(draft: draft)
        case .measure(let code, let day):
            MeasureSheet(code: code, day: day)
        case .note(let note, let day):
            NoteEditor(note: note, day: day)
        case .item(let item, let day):
            ItemDetailView(item: item, day: day)
        case .newItem(let week, let category):
            ItemEditor(week: week, item: nil, presetCategory: category)
        case .editMeasure(let measure, let week, let category):
            MeasureDefinitionEditor(week: week, measure: measure, presetCategory: category)
        case .dayOverview(let day):
            GlanceSheet(day: day)
        case .conditionals(let day):
            ConditionalsSheet(day: day)
        case .focus(let day):
            FocusSheet(day: day)
        case .expenses(let day):
            ExpensesSheet(day: day)
        case .pdf(let kind):
            WeekReader(week: kind.week, today: app.today) { context in
                PDFPreviewSheet(kind: kind, context: context)
            }
        case .archive:
            NavigationStack {
                ArchiveView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            SheetCloseButton { app.sheet = nil }
                        }
                    }
            }
            .thaliaSheetFrame(width: 520, height: 680)
        case .dayInfo(let day):
            DayInfoEditor(day: day)
        case .weekInfo(let week):
            WeekInfoEditor(week: week)
        case .report(let week):
            ReportView(week: week)
        case .explainer(let explainer):
            ExplainerSheet(explainer: explainer)
        case .trash:
            TrashView()
        case .settings:
            NavigationStack {
                SettingsView()
            }
            .thaliaSheetFrame(width: 540, height: 760)
        case .settingsPage(let page):
            NavigationStack {
                SettingsView(initialPage: page)
            }
            .thaliaSheetFrame(width: 540, height: 760)
        case .weeklyGoals(let week):
            WeeklyGoalsSheet(week: week)
        case .planWeek(let week):
            ImportView(showPrompt: true, week: week)
        case .repeatPlan(let source, let target):
            ImportView(showPrompt: false, week: target, repeatFrom: source)
        case .editItem(let item):
            ItemEditor(week: WeekKey(item.weekKey) ?? app.selectedWeek, item: item)
        case .goalReview:
            GoalReviewView()
        case .importPast(let week):
            PastWeekImportView(week: week)
        case .rangePDF:
            RangePDFSheet()
        case .goalEntry(let day, let resultID):
            GoalEntrySheet(day: day, resultID: resultID)
        case .reading(let day, let itemID):
            ReadingProgressSheet(day: day, itemID: itemID)
        case .book(let item):
            BookEditor(item: item)
        case .readingList:
            ReadingListSheet()
        case .beginSegment:
            SegmentWizard()
        case .resultEditor(let result, let goalKey):
            ResultEditor(result: result, goalKey: goalKey)
        case .connectedApps:
            ConnectedAppsSheet()
        }
    }
}

/// Full screen on iPhone/iPad, a large sheet on the Mac.
struct TourPresenter: ViewModifier {
    @Bindable var app: AppModel
    let health: HealthService

    func body(content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(item: $app.tour) { request in
            TourView(steps: request.steps, host: app) { app.finishTour() }
                .toastHost(app)
                .appearanceFromSettings()
        }
        #else
        content.sheet(item: $app.tour) { request in
            TourView(steps: request.steps, host: app) { app.finishTour() }
                .toastHost(app)
                .thaliaSheetFrame(width: 760, height: 800)
        }
        #endif
    }
}
