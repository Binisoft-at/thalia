import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// iPhone/iPad: tab bar (a sidebar on iPad) with a bottom accessory. Mac: split view.
struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        navigation
            .modifier(AppChrome(app: app, health: health))
            .modifier(TourPresenter(app: app, health: health))
            .onOpenURL { url in app.open(url) }
            .onReceive(NotificationCenter.default.publisher(for: .thaliaRoute)) { note in
                if let destination = note.object as? String { app.route(destination) }
                PendingRoute.destination = nil
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { app.refreshToday() }
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
        @Bindable var app = app
        TabView(selection: $app.tab) {
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
    }
}

/// The bottom accessory, right under the thumb (U10): today's fill, "+" to capture, closing the day.
private struct TodayAccessory: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.today.week, today: app.today) { context in
            let overall = context.score.days[app.today]
            let closed = context.isClosed(app.today)
            HStack(spacing: 12) {
                Button {
                    app.sheet = .dayOverview(app.today)
                } label: {
                    HStack(spacing: 10) {
                        FillRing(fill: overall?.coverage ?? 0, score: closed ? overall?.score : nil, size: 28, lineWidth: 3.5)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(closed ? "Tag abgeschlossen" : "Heute \(overall?.coverageText ?? "0 %")")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Text(subtitle(context))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Öffnet die Tagesübersicht")
                Spacer(minLength: 4)
                Button {
                    app.sheet = .closeDay(app.today)
                } label: {
                    Image(systemName: closed ? "checkmark.seal.fill" : "moon.stars")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Brand.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tag abschließen")
                Button {
                    app.sheet = .create
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.bold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.white)
                        .background(Brand.accent, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Erfassen")
            }
            .padding(.leading, 16)
            .padding(.trailing, 6)
        }
    }

    private func subtitle(_ context: WeekContext) -> String {
        let totals = context.workTotals(on: app.today)
        var parts: [String] = []
        if let overall = context.score.days[app.today], overall.blank > 0 { parts.append("\(overall.blank) offen") }
        if !totals.isEmpty { parts.append(totals.shortText) }
        return parts.isEmpty ? "Noch nichts erfasst" : parts.joined(separator: " · ")
    }
}
#endif

#if os(macOS)
private struct MacRoot: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            List(selection: $app.sidebar) {
                Label("Heute", systemImage: "sun.max").tag(AppTab.today)
                Label("Woche", systemImage: "tablecells").tag(AppTab.week)
                Label("Ziele", systemImage: "target").tag(AppTab.goals)
                Label("Rückblick", systemImage: "chart.bar.xaxis").tag(AppTab.review)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 300)
        } detail: {
            NavigationStack {
                switch app.sidebar ?? .today {
                case .today: TodayView()
                case .week: WeekView()
                case .goals: GoalsView()
                case .review: ReviewView()
                }
            }
        }
    }
}
#endif

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
            .toasts(app.toasts)
            .undoableChanges(in: app.container.mainContext)
    }
}

private struct SheetContent: View {
    let sheet: AppSheet

    var body: some View {
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
            DayOverviewSheet(day: day)
        case .conditionals(let day):
            ConditionalsSheet(day: day)
        case .archive:
            NavigationStack { ArchiveView() }
                .sheetFrame(minWidth: 520, minHeight: 560)
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
            .sheetFrame(minWidth: 540, minHeight: 640)
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
                .appearanceFromSettings()
        }
        #else
        content.sheet(item: $app.tour) { request in
            TourView(steps: request.steps, host: app) { app.finishTour() }
                .frame(minWidth: 760, idealWidth: 900, minHeight: 680, idealHeight: 800)
        }
        #endif
    }
}
