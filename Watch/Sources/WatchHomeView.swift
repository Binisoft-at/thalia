import SwiftUI
import SwiftData
import Combine
import BinisoftKit
import ThaliaCore

/// Today on the wrist (U16, R34): page 1 shows the ring, power-hours, the categories with something
/// open and the simple counters; then one page per category with required items or values –
/// ✓ with one tap, everything else with two, values with − / + or the crown.
struct WatchHomeView: View {
    static let firstPage = "today"

    @State private var today = DayKey.today()
    @State private var page = WatchHomeView.firstPage
    @State private var path = NavigationPath()
    @State private var banner: String?
    @State private var bannerID = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        WeekReader(week: today.week, today: today) { context in
            let pages = WatchPages.categories(context)
            TabView(selection: $page) {
                NavigationStack(path: $path) {
                    WatchTodayPage(context: context, pages: pages, banner: banner) { key in
                        page = key
                    }
                    .navigationDestination(for: WatchRoute.self) { route in
                        WatchRouteView(route: route, context: context) { powerHours, area in
                            powerHoursSaved(powerHours, area: area)
                        }
                    }
                }
                .tag(WatchHomeView.firstPage)
                ForEach(pages) { category in
                    NavigationStack { WatchCategoryPage(context: context, category: category) }
                        .tag(category.key)
                }
            }
            .tabViewStyle(.verticalPage)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshToday() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
            refreshToday()
        }
        .task(id: bannerID) {
            guard banner != nil else { return }
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                return
            }
            banner = nil
        }
    }

    /// R1: follows the system's day – on return and at midnight while the app stays open.
    private func refreshToday() {
        let now = DayKey.today()
        if now != today { today = now }
    }

    /// R48: back to page 1 with "+1 PH · stammloop" for two seconds and a success tap.
    private func powerHoursSaved(_ powerHours: Double, area: String) {
        path = NavigationPath()
        page = WatchHomeView.firstPage
        banner = "+\(Format.powerHours(powerHours)) · \(area)"
        bannerID += 1
        WatchHaptic.success.play()
    }
}

/// Which categories get a page and what page 1 lists (R34, H1).
enum WatchPages {
    /// Required today: fixed, n× per week or progress, due, no "Nebensache", not derived, not already
    /// done often enough on other days.
    static func isRequired(_ item: PlanItem, in context: WeekContext) -> Bool {
        let day = context.today
        guard !item.isSecondary, context.applies(item, on: day), !context.isDerived(item),
              !context.isQuotaMetElsewhere(item, on: day) else { return false }
        switch item.schedule {
        case .fixed, .progress, .weekly: return true
        case .conditional, .optional: return false
        }
    }

    /// A value entered on the watch that is not a page-1 counter (weight …, also from Health – it is never
    /// counted as missing, H1). Spending never calls for a page of its own (R2).
    static func isPageValue(_ measure: MeasureDefinition, in context: WeekContext) -> Bool {
        guard !measure.isSecondary, context.applies(measure, on: context.today) else { return false }
        switch WatchMeasureKind.of(measure, in: context) {
        case .value: return !WatchMeasureKind.isCounter(measure, in: context)
        case .health: return true
        case .expense, .list, .hidden: return false
        }
    }

    /// Pages only for categories with required items or values to enter – no empty pages.
    static func categories(_ context: WeekContext) -> [TrackCategory] {
        context.categories.filter { category in
            context.items.contains { $0.categoryKey == category.key && isRequired($0, in: context) }
                || context.measures.contains { $0.categoryKey == category.key && isPageValue($0, in: context) }
        }
    }

    /// The items listed on a category page (required ones, conditional and optional, "Nebensachen").
    static func items(in category: TrackCategory, context: WeekContext) -> [PlanItem] {
        let day = context.today
        return context.items.filter {
            $0.categoryKey == category.key && context.applies($0, on: day) && !context.isDerived($0)
                && !context.isQuotaMetElsewhere($0, on: day)
        }
    }

    /// The measurements listed on a category page.
    static func measures(in category: TrackCategory, context: WeekContext) -> [MeasureDefinition] {
        context.measures.filter {
            $0.categoryKey == category.key && context.applies($0, on: context.today) && WatchMeasureKind.of($0, in: context) != .hidden
        }
    }

    /// Page 1 "Zähler": day measurements that add up, with − / +.
    static func counters(_ context: WeekContext) -> [MeasureDefinition] {
        context.measures.filter { context.applies($0, on: context.today) && WatchMeasureKind.isCounter($0, in: context) }
    }

    /// Page 1 "Offen": categories with empty required items today ("1.1 Ernährung · 2").
    static func openGroups(_ context: WeekContext, pages: [TrackCategory]) -> [WatchOpenGroup] {
        let open = context.openToDo(on: context.today)
        return pages.compactMap { (category: TrackCategory) -> WatchOpenGroup? in
            let count = open.filter { $0.categoryKey == category.key }.count
            guard count > 0 else { return nil }
            return WatchOpenGroup(key: category.key, title: "\(category.key) \(shortTitle(category.title))", count: count)
        }
    }

    /// "Ernährung und Gewicht" → "Ernährung" (the app's rule for chips).
    static func shortTitle(_ title: String) -> String {
        let first = title.split(whereSeparator: { $0 == " " || $0 == "&" || $0 == "/" }).first.map(String.init) ?? title
        return first.count > 13 ? String(first.prefix(12)) + "." : first
    }
}

struct WatchOpenGroup: Identifiable {
    let key: String
    let title: String
    let count: Int
    var id: String { key }
}

/// Page 1 (R34): ring and status, power-hours, what is open per category (a tap opens its page) and
/// the counters with − / +.
private struct WatchTodayPage: View {
    let context: WeekContext
    let pages: [TrackCategory]
    let banner: String?
    let onOpen: (String) -> Void

    var body: some View {
        let groups = WatchPages.openGroups(context, pages: pages)
        let counters = WatchPages.counters(context)
        List {
            Section {
                WatchDayStatus(context: context)
                NavigationLink(value: WatchRoute.powerHours) {
                    Label("Power-Hours", systemImage: "bolt.fill")
                }
                .tint(Brand.accent)
            }
            if !groups.isEmpty {
                Section {
                    ForEach(groups) { group in
                        Button {
                            onOpen(group.key)
                        } label: {
                            Text("\(group.title) · \(group.count)")
                                .font(.footnote)
                                .lineLimit(2)
                        }
                        .accessibilityLabel("\(group.title), \(group.count) offen")
                        .accessibilityHint("Öffnet die Seite der Kategorie")
                    }
                } header: {
                    Text("Offen")
                }
            }
            if !counters.isEmpty {
                Section {
                    ForEach(counters) { measure in
                        WatchMeasureRow(measure: measure, context: context)
                    }
                } header: {
                    Text("Zähler")
                }
            }
        }
        .overlay(alignment: .top) {
            if let banner {
                WatchBanner(text: banner)
            }
        }
        .navigationTitle(context.today.weekday.name)
    }
}

/// Ring, status and today's power-hours (R5: "offen" = empty required items).
private struct WatchDayStatus: View {
    let context: WeekContext

    var body: some View {
        let day = context.today
        let overall = context.score.days[day]
        let closed = context.isClosed(day)
        let gaugeValue: Double = WatchDayStatus.gaugeValue(overall, closed: closed, hasPlan: context.hasPlan)
        let label: String = WatchDayStatus.ringLabel(overall, closed: closed, hasPlan: context.hasPlan)
        let tint: Color = WatchDayStatus.isComplete(overall, closed: closed, hasPlan: context.hasPlan) ? .green : Brand.accent
        let status: String = WatchDayStatus.status(context, closed: closed)
        let work = context.workTotals(on: day)
        HStack(spacing: 10) {
            Gauge(value: gaugeValue, in: 0...1) {
                Text(closed ? "Tag" : "%")
            } currentValueLabel: {
                Text(label)
            }
            .gaugeStyle(.accessoryCircular)
            .tint(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(status)
                    .font(.footnote.weight(.semibold))
                Text(work.isEmpty ? "Noch keine PH" : work.shortText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// v8: an empty ring on a sick or holiday day.
    static func gaugeValue(_ overall: DayOverall?, closed: Bool, hasPlan: Bool) -> Double {
        if overall?.isExcused == true { return 0 }
        if closed { return (overall?.score ?? 0) / 10 }
        return hasPlan ? (overall?.coverage ?? 0) : 0
    }

    static func ringLabel(_ overall: DayOverall?, closed: Bool, hasPlan: Bool) -> String {
        if overall?.isExcused == true { return "–" }
        if closed { return Format.score(overall?.score, outOf: false) }
        guard hasPlan else { return "–" }
        return "\(Int(((overall?.coverage ?? 0) * 100).rounded()))"
    }

    static func isComplete(_ overall: DayOverall?, closed: Bool, hasPlan: Bool) -> Bool {
        guard !closed, hasPlan, let overall, !overall.isExcused else { return false }
        return overall.coverage >= 1
    }

    static func status(_ context: WeekContext, closed: Bool) -> String {
        // v8: a sick or holiday day is never open.
        if context.isExcused(context.today) { return "\(context.excusedName(context.today)) – zählt nicht" }
        if closed { return "Abgeschlossen" }
        guard context.hasPlan else { return "Kein Plan" }
        guard (context.score.days[context.today]?.due ?? 0) > 0 else { return "Nichts fällig" }
        let open = context.openCount(on: context.today)
        return open == 0 ? "Alles erfasst" : "\(open) offen"
    }
}

/// "+1 PH · stammloop" after saving power-hours (R48).
private struct WatchBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.85), in: Capsule())
            .foregroundStyle(.white)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel(text)
    }
}

/// One category (R34): its items, its values, then "Nebensachen" on their own.
private struct WatchCategoryPage: View {
    let context: WeekContext
    let category: TrackCategory

    var body: some View {
        let entry = context.score.category(category.key, on: context.today)
        let items = WatchPages.items(in: category, context: context)
        let mainItems = items.filter { !$0.isSecondary }
        let secondaryItems = items.filter { $0.isSecondary }
        let measures = WatchPages.measures(in: category, context: context)
        let mainMeasures = measures.filter { !$0.isSecondary }
        let secondaryMeasures = measures.filter { $0.isSecondary }
        let progress: String = WatchCategoryPage.progressText(entry)
        List {
            Section {
                ForEach(mainItems) { item in
                    WatchItemRow(item: item, context: context)
                }
            } header: {
                HStack {
                    Text(category.title)
                    Spacer()
                    if !progress.isEmpty {
                        Text(progress)
                            .monospacedDigit()
                    }
                }
            }
            if !mainMeasures.isEmpty {
                Section {
                    ForEach(mainMeasures) { measure in
                        WatchMeasureRow(measure: measure, context: context)
                    }
                } header: {
                    Text("Werte")
                }
            }
            if !secondaryItems.isEmpty || !secondaryMeasures.isEmpty {
                Section {
                    ForEach(secondaryItems) { item in
                        WatchItemRow(item: item, context: context)
                    }
                    ForEach(secondaryMeasures) { measure in
                        WatchMeasureRow(measure: measure, context: context)
                    }
                } header: {
                    Text("Nebensachen")
                }
            }
        }
        .navigationTitle(category.key)
    }

    /// "✓" when everything due is filled in, else "3/5"; empty when nothing is due.
    static func progressText(_ entry: CategoryDay) -> String {
        guard entry.due > 0 else { return "" }
        return entry.isComplete ? "✓" : "\(entry.due - entry.blank)/\(entry.due)"
    }
}

/// ✓ in one tap on the leading button; the row opens all marks.
private struct WatchItemRow: View {
    let item: PlanItem
    let context: WeekContext
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let day = context.today
        let mark = context.mark(item, on: day)
        let isProgress = item.schedule == .progress
        HStack(spacing: 8) {
            Button {
                toggleDone(current: mark, day: day)
            } label: {
                Image(systemName: mark.watchSymbol)
                    .font(.title3)
                    .foregroundStyle(mark.watchColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(WatchItemRow.quickLabel(mark, progress: isProgress))
            NavigationLink {
                WatchMarkPicker(item: item, context: context)
            } label: {
                Text(item.title)
                    .font(.footnote)
                    .lineLimit(3)
            }
            .accessibilityValue(WatchItemRow.markText(mark, progress: isProgress))
        }
    }

    /// ✓ on, or off again – each with its own tap on the wrist (R82).
    private func toggleDone(current: Mark?, day: DayKey) {
        let store = TrackerStore(context: modelContext)
        if current == .done {
            store.setMark(nil, item: item, day: day)
            WatchHaptic.click.play()
        } else {
            store.setMark(.done, item: item, day: day)
            WatchHaptic.success.play()
        }
    }

    /// VoiceOver in words (R43): "Erledigt – tippen zum Leeren" · "Als erledigt markieren".
    static func quickLabel(_ mark: Mark?, progress: Bool) -> String {
        let word = Mark.done.label(progress: progress)
        if mark == .done { return "\(word) – tippen zum Leeren" }
        return "Als \(word.lowercased()) markieren"
    }

    static func markText(_ mark: Mark?, progress: Bool) -> String {
        guard let mark else { return "Nicht erfasst" }
        return mark.label(progress: progress)
    }
}

/// All marks of one item (R43, R82): words on the buttons, the current mark highlighted, a success tap
/// when one is set and a click when it is cleared.
private struct WatchMarkPicker: View {
    let item: PlanItem
    let context: WeekContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let day = context.today
        let current = context.mark(item, on: day)
        let options = context.options(item, on: day)
        let isProgress = item.schedule == .progress
        ScrollView {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        WatchMarkButton(option: option, isProgress: isProgress, isSelected: option == current) {
                            set(option, day: day)
                        }
                    }
                }
                if current != nil {
                    Button("Leeren", role: .destructive) {
                        set(nil, day: day)
                    }
                }
            }
        }
    }

    private func set(_ mark: Mark?, day: DayKey) {
        TrackerStore(context: modelContext).setMark(mark, item: item, day: day)
        if mark == nil {
            WatchHaptic.click.play()
        } else {
            WatchHaptic.success.play()
        }
        dismiss()
    }
}

/// One mark as symbol and word; the chosen one filled (`.borderedProminent`), the others outlined.
private struct WatchMarkButton: View {
    let option: Mark
    let isProgress: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            label.buttonStyle(.borderedProminent)
        } else {
            label.buttonStyle(.bordered)
        }
    }

    private var label: some View {
        let word = option.label(progress: isProgress)
        return Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: Optional(option).watchSymbol)
                    .font(.body.weight(.bold))
                Text(word)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .tint(Optional(option).watchColor)
        .accessibilityLabel(word)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension Optional where Wrapped == Mark {
    var watchSymbol: String {
        switch self {
        case .done?: "checkmark.circle.fill"
        case .partial?: "circle.lefthalf.filled"
        case .missed?: "xmark.circle.fill"
        case .notApplicable?: "minus.circle"
        case nil: "circle"
        }
    }

    var watchColor: Color {
        switch self {
        case .done?: .green
        case .partial?: .orange
        case .missed?: .red
        case .notApplicable?: .gray
        case nil: .secondary
        }
    }
}
