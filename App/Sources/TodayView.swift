import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// "Heute": one page per category – mark items with one tap, type values right where they are,
/// see how much of the day is filled in. Details sit behind ⓘ, the day overview opens on tap, the
/// day score appears once the day is closed. iPhone: pager; iPad (wide) and Mac: list + page.
struct TodayView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: app.selectedDay.week, today: app.today) { context in
            TodayContent(context: context)
        }
    }
}

/// 0.62 → 62
func percent(_ fill: Double) -> Int {
    let scaled: Double = fill * 100
    return Int(scaled.rounded())
}

/// Bedingte Punkte zuerst abfragen (U12.9) – a device setting.
enum TodaySettings {
    static let askConditionalsKey = "today.askConditionals"
}

extension WeekContext {
    /// Categories with something to mark, enter or show on a day, in plan order (free days: only
    /// what fits such a day, V11).
    func todayCategories(_ day: DayKey) -> [TrackCategory] {
        categories.filter { category in
            items.contains { $0.categoryKey == category.key && applies($0, on: day) }
                || measures.contains { $0.categoryKey == category.key && applies($0, on: day) }
                || work.contains { $0.categoryKey == category.key && $0.dayKey == day.string }
        }
    }

    func items(in category: TrackCategory, on day: DayKey) -> [PlanItem] {
        items.filter { $0.categoryKey == category.key && applies($0, on: day) }
    }

    /// Weekly targets of a category (V2): progress items with their measurement, and weekly
    /// measurements with a target that no progress item covers.
    func weeklyGoals(categoryKey: String, on day: DayKey) -> [WeeklyGoal] {
        var goals: [WeeklyGoal] = []
        var covered: Set<String> = []
        for item in items where item.categoryKey == categoryKey && item.schedule == .progress {
            guard let measure = measure(code: item.measureCode) else { continue }
            goals.append(WeeklyGoal(measure: measure, item: item))
            covered.insert(measure.code)
        }
        for measure in measures where measure.categoryKey == categoryKey && !covered.contains(measure.code) {
            guard let record = measure.record, record.period == .week, record.target != nil, applies(measure, on: day) else { continue }
            goals.append(WeeklyGoal(measure: measure, item: nil))
        }
        return goals
    }

    /// A category's daily measurements, grouped by how they are filled in (U13); weekly goals and
    /// secondary ones are shown elsewhere.
    func measureGroups(categoryKey: String, on day: DayKey, secondary: Bool = false) -> [(group: MeasureGroup, measures: [MeasureDefinition])] {
        let weekly = Set(weeklyGoals(categoryKey: categoryKey, on: day).map(\.measure.code))
        let list = measures.filter {
            $0.categoryKey == categoryKey && applies($0, on: day) && !weekly.contains($0.code) && $0.isSecondary == secondary
        }
        let grouped = Dictionary(grouping: list) { measure in measure.record.map { MeasureGroup($0) } ?? .count }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    /// Conditional items of the day nobody has answered yet.
    func unansweredConditionals(on day: DayKey) -> [PlanItem] {
        openConditionals(on: day)
    }

    /// Items one tap can set (V4): visible, tickable, not derived.
    func tickable(_ items: [PlanItem], on day: DayKey) -> [PlanItem] {
        items.filter { !options($0, on: day).isEmpty && !isDerived($0) }
    }

    /// The first category that still has something blank – where Today opens.
    func firstOpenPage(_ day: DayKey) -> TodayPage {
        let pages = todayCategories(day)
        if let open = pages.first(where: { score.category($0.key, on: day).blank > 0 }) { return .category(open.key) }
        return pages.first.map { .category($0.key) } ?? .day
    }
}

/// A weekly target on a category page: the measurement and, if any, the progress item it drives.
struct WeeklyGoal: Identifiable {
    let measure: MeasureDefinition
    let item: PlanItem?
    var id: String { measure.code }
}

struct TodayContent: View {
    let context: WeekContext

    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var day: DayKey { app.selectedDay }
    private var pages: [TrackCategory] { context.todayCategories(day) }

    private var usesSplit: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    private var page: Binding<TodayPage> {
        Binding(get: { app.todayPage ?? context.firstOpenPage(day) },
                set: { app.todayPage = $0 })
    }

    var body: some View {
        Group {
            if !context.hasPlan {
                List {
                    Section { NoPlanView(week: context.week) }
                    DayPageSections(context: context, day: day, showsMeasures: true)
                }
                .compactListSections()
            } else if usesSplit {
                TodaySplit(context: context, day: day, pages: pages, page: page)
            } else {
                TodayPager(context: context, day: day, pages: pages, page: page)
            }
        }
        .navigationTitle(day == app.today ? "Heute" : day.weekday.name)
        .inlineNavigationTitle()
        .toolbar { TodayToolbar(context: context, day: day) }
        .onChange(of: day) { _, _ in app.todayPage = nil }
        .task(id: day) {
            await health.load(day: day, measures: context.measures.compactMap(\.record))
        }
    }
}

// MARK: Layouts

/// iPhone: compact header, category chips, one page per category (swipe or tap a chip).
private struct TodayPager: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage

    var body: some View {
        VStack(spacing: 0) {
            TodayHeader(context: context, day: day)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            CategoryChips(context: context, day: day, pages: pages, page: $page)
                .padding(.vertical, 8)
            #if os(iOS)
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.element.key) { index, category in
                    CategoryPage(context: context, category: category, day: day,
                                 next: index + 1 < pages.count ? pages[index + 1] : nil, page: $page)
                        .tag(TodayPage.category(category.key))
                }
                DayPage(context: context, day: day)
                    .tag(TodayPage.day)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)
            #endif
        }
    }
}

/// iPad (wide) and Mac: categories on the left, the page on the right, the overview as inspector.
private struct TodaySplit: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage
    @Environment(AppModel.self) private var app
    /// Off by default: the category list already shows each category's fill; the overview is extra.
    @AppStorage("today.inspector") private var showsInspector = false

    var body: some View {
        HStack(spacing: 0) {
            List(selection: Binding<TodayPage?>(get: { page }, set: { if let value = $0 { page = value } })) {
                Section {
                    TodayHeader(context: context, day: day, showsOverviewButton: false)
                        .listRowBackground(Color.clear)
                }
                Section("Kategorien") {
                    ForEach(pages) { category in
                        CategoryListRow(context: context, category: category, day: day)
                            .tag(TodayPage.category(category.key))
                    }
                }
                Section {
                    Label("Tag, Notizen, Abschluss", systemImage: "moon.stars")
                        .tag(TodayPage.day)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 270)
            Divider()
            Group {
                switch page {
                case .category(let key):
                    if let index = pages.firstIndex(where: { $0.key == key }) {
                        CategoryPage(context: context, category: pages[index], day: day,
                                     next: index + 1 < pages.count ? pages[index + 1] : nil, page: $page)
                    } else {
                        DayPage(context: context, day: day)
                    }
                case .day:
                    DayPage(context: context, day: day)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .inspector(isPresented: $showsInspector) {
            DayOverviewList(context: context, day: day, onOpen: { page = $0 })
                .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsInspector.toggle()
                } label: {
                    Label("Tagesübersicht", systemImage: "sidebar.trailing")
                }
                .help("Tagesübersicht ein- oder ausblenden")
            }
        }
    }
}

// MARK: Header

/// Date, day type and how much is filled in (the score once the day is closed). Tapping the ring
/// opens the day overview.
struct TodayHeader: View {
    let context: WeekContext
    let day: DayKey
    var showsOverviewButton = true
    @Environment(AppModel.self) private var app

    var body: some View {
        let overall = context.score.days[day]
        let closed = context.isClosed(day)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Menu {
                    ForEach(context.week.days, id: \.self) { other in
                        Button {
                            app.selectedDay = other
                        } label: {
                            Label(other.shortLabel + (other == app.today ? " · heute" : ""),
                                  systemImage: context.isClosed(other) ? "checkmark.seal.fill" : "circle")
                        }
                    }
                    Divider()
                    Button("Vorige Woche", systemImage: "chevron.left") { app.selectedDay = day.adding(days: -7) }
                    Button("Nächste Woche", systemImage: "chevron.right") { app.selectedDay = day.adding(days: 7) }
                    if day != app.today {
                        Button("Zu heute", systemImage: "sun.max") { app.selectedDay = app.today }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(day.shortLabel)
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .accessibilityLabel("Tag wählen, \(day.longLabel)")
                HStack(spacing: 6) {
                    Text(context.week.label)
                    Button {
                        app.sheet = .dayInfo(day)
                    } label: {
                        DayTypeChip(type: context.dayType(day), compact: !showsOverviewButton)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Tagestyp und Notiz ändern")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button {
                app.sheet = .dayOverview(day)
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(closed ? "Abgeschlossen" : "Erfasst")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(closed ? Format.score(overall?.score, outOf: true) : (overall?.coverageText ?? "–"))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    FillRing(fill: overall?.coverage ?? 0, score: closed ? overall?.score : nil, size: 44)
                    if showsOverviewButton {
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundStyle(Brand.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(closed ? "Tag abgeschlossen, Wertung \(Format.score(overall?.score))" : "\(overall?.coverageText ?? "0 %") erfasst")
            .accessibilityHint("Öffnet die Tagesübersicht")
        }
    }
}

/// How much is filled in (0…1) as a ring; with a score (closed day) the ring shows the score.
struct FillRing: View {
    let fill: Double
    var score: Double?
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(score.map { $0 / 10 } ?? fill))
                .stroke(score == nil ? (fill >= 1 ? Color.green : Brand.accent) : Brand.accent,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if score == nil, fill >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(.green)
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: fill)
        .accessibilityHidden(true)
    }
}

// MARK: Category navigation

/// The categories of the day as chips; the selected one is filled, a finished one gets a check.
private struct CategoryChips: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(pages) { category in
                        chip(category)
                            .id(TodayPage.category(category.key))
                    }
                    Button {
                        withAnimation(.snappy) { page = .day }
                    } label: {
                        Image(systemName: "moon.stars")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 40, height: 34)
                            .foregroundStyle(page == .day ? Color.white : Color.primary)
                            .background(page == .day ? Brand.accent : Color.secondary.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .id(TodayPage.day)
                    .accessibilityLabel("Tag abschließen und Notizen")
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: page) { _, value in
                withAnimation(.snappy) { proxy.scrollTo(value, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(page, anchor: .center) }
        }
    }

    private func chip(_ category: TrackCategory) -> some View {
        let entry = context.score.category(category.key, on: day)
        let selected = page == .category(category.key)
        return Button {
            withAnimation(.snappy) { page = .category(category.key) }
        } label: {
            HStack(spacing: 5) {
                Text(category.key)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                if entry.due > 0 {
                    if entry.isComplete {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(selected ? Color.white : Color.green)
                    } else {
                        MiniFill(fill: entry.fill, inverted: selected)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? Brand.accent : Color.secondary.opacity(0.12), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.key) \(category.title), \(percent(entry.fill)) Prozent erfasst")
    }
}

private struct MiniFill: View {
    let fill: Double
    var inverted = false

    var body: some View {
        ZStack {
            Circle().stroke((inverted ? Color.white : Color.secondary).opacity(0.3), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(fill))
                .stroke(inverted ? Color.white : Brand.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 12, height: 12)
    }
}

/// A category in the split layout's list: key, title, fill or result.
private struct CategoryListRow: View {
    let context: WeekContext
    let category: TrackCategory
    let day: DayKey

    var body: some View {
        let entry = context.score.category(category.key, on: day)
        HStack(spacing: 10) {
            KeyBadge(key: category.key)
            Text(category.title)
                .lineLimit(1)
            Spacer(minLength: 4)
            if entry.due > 0 {
                if entry.isComplete, let score = entry.score {
                    Text(Format.score(score))
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                } else {
                    Text("\(percent(entry.fill)) %")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: Category page

/// One category on one day: its items (one tap each), its measurements (typed in place) and the
/// power-hours logged for it. The category result shows once everything is filled in (U18.1).
struct CategoryPage: View {
    let context: WeekContext
    let category: TrackCategory
    let day: DayKey
    let next: TrackCategory?
    @Binding var page: TodayPage

    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @AppStorage(TodaySettings.askConditionalsKey) private var askConditionals = false
    @State private var showsInfo = false
    @State private var showsSecondary = false
    @State private var showsDone = false

    /// Everything due today in this category except derived progress items (they live in the
    /// weekly card) and unanswered conditionals when they're asked first.
    private var dayItems: [PlanItem] {
        context.items(in: category, on: day).filter { item in
            !context.isDerived(item)
                && !(askConditionals && item.schedule == .conditional && context.mark(item, on: day) == nil)
        }
    }

    var body: some View {
        let entry: CategoryDay = context.score.category(category.key, on: day)
        let all: [PlanItem] = dayItems
        let doneThisWeek: [PlanItem] = all.filter { context.isQuotaMetElsewhere($0, on: day) }
        let secondary: [PlanItem] = all.filter { $0.isSecondary && !doneThisWeek.contains($0) }
        let main: [PlanItem] = all.filter { !$0.isSecondary && !doneThisWeek.contains($0) }
        let goals: [WeeklyGoal] = context.weeklyGoals(categoryKey: category.key, on: day)
        let groups = context.measureGroups(categoryKey: category.key, on: day)
        let secondaryGroups = context.measureGroups(categoryKey: category.key, on: day, secondary: true)
        let secondaryCount: Int = secondary.count + secondaryGroups.reduce(0) { $0 + $1.measures.count }
        let waiting: [PlanItem] = askConditionals ? context.unansweredConditionals(on: day).filter { $0.categoryKey == category.key } : []
        let workCategory: Bool = context.measures.contains { $0.record?.source == .work(category: category.key) }
        List {
            Section {
                header(entry, tickable: context.tickable(main, on: day))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

            if context.isFreeDay(day) {
                Section {
                    Label("\(context.dayType(day)): Arbeitspunkte zählen heute nicht.", systemImage: DayTypes.symbol(for: context.dayType(day)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !goals.isEmpty {
                Section {
                    ForEach(goals) { goal in
                        WeeklyGoalRow(goal: goal, context: context, day: day)
                    }
                } header: {
                    Text("Wochenziele")
                }
            }

            if !waiting.isEmpty {
                Section {
                    Button {
                        app.sheet = .conditionals(day)
                    } label: {
                        Label("\(waiting.count) bedingte \(waiting.count == 1 ? "Punkt" : "Punkte"): Gab es die Situation heute?",
                              systemImage: "questionmark.circle")
                    }
                }
            }

            if !main.isEmpty {
                Section {
                    ForEach(main) { item in
                        ItemMarkRow(item: item, context: context, day: day)
                    }
                }
            }

            ForEach(groups, id: \.group) { group in
                Section {
                    ForEach(group.measures) { measure in
                        MeasureRow(measure: measure, context: context, day: day,
                                   healthSuggestion: context.dayValue(measure, on: day) == nil ? health.suggestion(code: measure.code, day: day) : nil)
                    }
                } header: {
                    Text(group.group.label)
                }
            }

            if workCategory || context.work(on: day).contains(where: { $0.categoryKey == category.key }) {
                Section {
                    ForEach(context.work(on: day).filter { $0.categoryKey == category.key }) { block in
                        InlineWorkRow(block: block, categoryTitle: category.title)
                    }
                    NewWorkRow(categoryKey: category.key, day: day)
                } header: {
                    Text("Power-Hours heute")
                } footer: {
                    Text("Beschreibung direkt eintippen – Vorschläge kommen aus deinen bisherigen Einträgen.")
                }
            }

            if secondaryCount > 0 {
                Section {
                    DisclosureGroup(isExpanded: $showsSecondary) {
                        ForEach(secondary) { item in
                            ItemMarkRow(item: item, context: context, day: day)
                        }
                        ForEach(secondaryGroups, id: \.group) { group in
                            ForEach(group.measures) { measure in
                                MeasureRow(measure: measure, context: context, day: day, healthSuggestion: nil)
                            }
                        }
                    } label: {
                        Label("Weitere (\(secondaryCount)) – zählen, wenn ausgefüllt", systemImage: "square.stack")
                            .font(.subheadline)
                    }
                }
            }

            if !doneThisWeek.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showsDone) {
                        ForEach(doneThisWeek) { item in
                            ItemMarkRow(item: item, context: context, day: day)
                        }
                    } label: {
                        Label("Diese Woche schon erfüllt (\(doneThisWeek.count))", systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                }
            }

            Section {
                Button {
                    withAnimation(.snappy) { page = next.map { .category($0.key) } ?? .day }
                } label: {
                    HStack {
                        Text(next.map { "Weiter: \($0.key) \($0.title)" } ?? "Weiter: Tag abschließen")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                }
                Menu {
                    Button("Punkt hinzufügen", systemImage: "checklist") {
                        app.sheet = .newItem(day.week, categoryKey: category.key)
                    }
                    Button("Messwert hinzufügen", systemImage: "ruler") {
                        app.sheet = .editMeasure(nil, day.week, categoryKey: category.key)
                    }
                    if category.goalKey == "3" {
                        Button("Power-Hours mit Ergebnis und nächstem Schritt", systemImage: "bolt") {
                            app.sheet = .work(WorkDraft(day: day, categoryKey: category.key))
                        }
                    }
                } label: {
                    Label("Zu \(category.key) hinzufügen", systemImage: "plus")
                        .font(.subheadline)
                }
            }
        }
        .compactListSections()
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
    }

    private func header(_ entry: CategoryDay, tickable: [PlanItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                KeyBadge(key: category.key)
                Text(category.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                if !tickable.isEmpty {
                    QuickAllMenu(items: tickable, day: day, context: context, scope: category.title)
                }
                if !category.details.isEmpty || context.goal(of: category) != nil {
                    Button {
                        withAnimation(.snappy) { showsInfo.toggle() }
                    } label: {
                        Image(systemName: showsInfo ? "info.circle.fill" : "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Details zu \(category.title)")
                }
            }
            HStack(spacing: 10) {
                if entry.due > 0 {
                    ProgressView(value: entry.fill)
                        .tint(entry.isComplete ? .green : Brand.accent)
                        .frame(maxWidth: 140)
                    Text(entry.isComplete ? "alles erfasst" : "\(entry.due - entry.blank) von \(entry.due) erfasst")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                if entry.knockedOut || entry.overridden {
                    Image(systemName: entry.overridden ? "hand.raised.fill" : "exclamationmark.octagon.fill")
                        .foregroundStyle(.orange)
                        .accessibilityLabel(entry.overridden ? "Eigene Wertung" : "Null-Regel")
                }
                if entry.isComplete, let score = entry.score {
                    Text("Zwischenstand \(Format.score(score))")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Brand.accent.opacity(0.14), in: .capsule)
                }
            }
            if showsInfo {
                VStack(alignment: .leading, spacing: 4) {
                    if let goal = context.goal(of: category) {
                        Text("Ziel \(goal.key): \(goal.title)")
                            .font(.caption.weight(.semibold))
                    }
                    if !category.details.isEmpty {
                        Text(category.details)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: Items

/// One item with its marks as direct buttons – no cycling, no holding (U5.2, U18.2).
struct ItemMarkRow: View {
    let item: PlanItem
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app
    @State private var showsDetails = false

    var body: some View {
        let mark = context.mark(item, on: day)
        let note = context.markNote(item, on: day)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if item.isKnockout {
                    Image(systemName: "exclamationmark.octagon")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Null-Regel")
                }
                Spacer(minLength: 4)
                Button {
                    app.sheet = .item(item, day)
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Details zu \(item.title)")
            }
            meta
            if !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            let options: [Mark] = context.options(item, on: day)
            if options.isEmpty {
                Label(context.isDerived(item) ? "Automatisch aus dem Wochenziel" : "Zählt heute nicht", systemImage: "wand.and.stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                MarkBar(mark: mark, options: options, suggestion: context.suggestion(item, on: day),
                        isProgress: item.schedule == .progress) { app.setMark($0, item: item, day: day) }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            MarkMenu(current: mark, options: context.options(item, on: day)) { app.setMark($0, item: item, day: day) }
            Divider()
            if item.isSecondary {
                Button("Doch wichtig", systemImage: "star") { app.store.setSecondary(item, false) }
            } else {
                Button("Als Nebensache", systemImage: "square.stack") { app.store.setSecondary(item, true) }
            }
            Button("Details und Notiz…", systemImage: "info.circle") { app.sheet = .item(item, day) }
        }
    }

    /// V5: what this item is – subtle, but clear. Plain daily items need no label.
    private var kindText: String? {
        if item.isSecondary { return "Nebensache · zählt, wenn ausgefüllt" }
        switch item.schedule {
        case .fixed: return nil
        case .optional: return "optional · zählt nicht"
        case .conditional: return "bedingt · nur wenn die Situation vorkam"
        case .weekly(let count): return "\(count)× pro Woche"
        case .progress: return context.isDerived(item) ? "automatisch" : "Wochenfortschritt"
        }
    }

    @ViewBuilder
    private var meta: some View {
        let quota = context.quotaProgress(item)
        let progress = context.progress(item)
        if kindText != nil || quota != nil || progress != nil {
            HStack(spacing: 8) {
                if let kindText {
                    Text(kindText)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12), in: .capsule)
                }
                if let quota {
                    Text("\(quota.done) von \(quota.target) diese Woche")
                        .font(.caption2)
                        .foregroundStyle(quota.done >= quota.target ? .green : .secondary)
                }
                if let progress {
                    ProgressView(value: min(1, progress))
                        .tint(progress >= 1 ? .green : Brand.accent)
                        .frame(width: 60)
                    Text("Wochenziel \(percent(progress)) %")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(progress >= 1 ? .green : .secondary)
                }
            }
        }
    }
}

/// ✓ ½ ✗ N/A as equal buttons. Tapping the selected one clears it. A measurement's suggestion is
/// outlined. Progress items: "Gearbeitet" / "Nicht heute" – the week decides the result (U19).
struct MarkBar: View {
    let mark: Mark?
    let options: [Mark]
    var suggestion: Mark?
    var isProgress = false
    let onSet: (Mark?) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = mark == option
                Button {
                    onSet(selected ? nil : option)
                } label: {
                    Text(title(option))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(selected ? Color.white : Optional(option).color)
                        .background(selected ? Optional(option).color : Color.secondary.opacity(0.1),
                                    in: .rect(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if suggestion == option, mark == nil {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Optional(option).color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            }
                        }
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibility(option))
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityHint(selected ? "Nochmal tippen leert die Bewertung" : (suggestion == option ? "Vorschlag aus dem Messwert" : ""))
            }
        }
        .sensoryFeedback(.selection, trigger: mark)
    }

    private func title(_ option: Mark) -> String {
        if isProgress {
            return option == .done ? "✓ Gearbeitet" : "Nicht heute"
        }
        return option == .notApplicable ? "N/A" : option.symbol
    }

    private func accessibility(_ option: Mark) -> String {
        if isProgress { return option == .done ? "Daran gearbeitet" : "Nicht heute" }
        return option.label
    }
}

// MARK: Measurements

/// A measurement, filled in where it is (U5.1): − value + for numbers, a time picker for clock
/// times, quick power-hours for work. ⓘ opens history, Apple Health and single entries.
struct MeasureRow: View {
    let measure: MeasureDefinition
    let context: WeekContext
    let day: DayKey
    var healthSuggestion: Double?

    @Environment(AppModel.self) private var app

    private var record: MeasureRecord? { measure.record }
    private var value: Double? { context.dayValue(measure, on: day) }
    private var isWeekly: Bool { record?.period == .week }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(measure.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if let met = record.flatMap({ Measures.isMet($0, value: isWeekly ? context.weekValue(measure) : value) }) {
                        Image(systemName: met ? "checkmark.circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(met ? .green : .secondary)
                            .accessibilityLabel(met ? "Ziel erreicht" : "Ziel noch nicht erreicht")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                if let healthSuggestion {
                    Button {
                        app.store.adoptHealth(code: measure.code, day: day, value: healthSuggestion)
                    } label: {
                        Label("Health: \(Format.measure(healthSuggestion, unit: measure.unit)) übernehmen", systemImage: "heart.text.square")
                            .font(.caption2.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(.pink)
                }
            }
            .layoutPriority(1)
            Spacer(minLength: 4)
            MeasureInput(measure: measure, context: context, day: day)
            Button {
                app.sheet = .measure(code: measure.code, day: day)
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Verlauf und Details zu \(measure.title)")
        }
        .padding(.vertical, 2)
        .contextMenu { MeasureMenu(measure: measure, context: context, day: day) }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let target = record?.target {
            parts.append("Ziel \(target.label)\(isWeekly ? " / Woche" : "")")
        } else if record?.isWork == true {
            parts.append("PH")
        } else if !measure.unit.isEmpty {
            parts.append(Units.display(measure.unit))
        }
        if isWeekly {
            parts.append("Woche \(context.weekValue(measure).map { Format.measure($0, unit: measure.unit) } ?? "0")")
        }
        if measure.isSecondary { parts.append("Nebensache") }
        return parts.joined(separator: " · ")
    }
}

/// Context menu of a measurement: history, edit, priority, clear.
struct MeasureMenu: View {
    let measure: MeasureDefinition
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    var body: some View {
        Button("Verlauf und Einträge…", systemImage: "chart.bar") { app.sheet = .measure(code: measure.code, day: day) }
        Button("Messwert bearbeiten…", systemImage: "pencil") { app.sheet = .editMeasure(measure, day.week, categoryKey: measure.categoryKey) }
        if measure.isSecondary {
            Button("Doch wichtig", systemImage: "star") { app.store.setSecondary(measure, false) }
        } else {
            Button("Als Nebensache", systemImage: "square.stack") { app.store.setSecondary(measure, true) }
        }
        if context.dayValue(measure, on: day) != nil, measure.record?.isWork != true {
            Button("Wert leeren", systemImage: "xmark.circle") { app.setValue(nil, for: measure, day: day) }
        }
    }
}

/// Entering a measurement in place, in as few steps as possible (V7, V8, V10):
/// power-hours − / typed / + (hold + for quick amounts), clock times straight in the time picker,
/// text and numbers typed right in the row.
struct MeasureInput: View {
    let measure: MeasureDefinition
    let context: WeekContext
    let day: DayKey

    @Environment(AppModel.self) private var app
    @State private var text = ""
    @State private var draftTime = Date()
    @FocusState private var focused: Bool

    private var record: MeasureRecord? { measure.record }
    private var value: Double? { context.dayValue(measure, on: day) }

    private var workCategory: String? {
        if case .work(let category)? = record?.source { return category }
        return nil
    }

    var body: some View {
        if let workCategory {
            stepper(step: 0.5, unitLabel: "PH") { app.setWorkTotal($0, categoryKey: workCategory, day: day) }
        } else if record?.isTime ?? false {
            timeControl
        } else if record?.isText ?? false {
            textControl
        } else {
            stepper(step: Units.step(measure.unit), unitLabel: nil) { app.setValue($0, for: measure, day: day, toast: false) }
        }
    }

    // MARK: Number / PH

    private func stepper(step: Double, unitLabel: String?, set: @escaping (Double?) -> Void) -> some View {
        HStack(spacing: 4) {
            Button {
                set(max(0, (value ?? 0) - step))
            } label: {
                Image(systemName: "minus")
                    .font(.callout.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(Color.secondary.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled((value ?? 0) <= 0)
            .accessibilityLabel("\(measure.title) minus \(Format.number(step))")
            TextField(unitLabel ?? "–", text: $text)
                .multilineTextAlignment(.center)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .monospacedDigit()
                .frame(width: 64)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(focused ? 0.16 : 0.08), in: .rect(cornerRadius: 8, style: .continuous))
                .decimalKeyboard()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { commit(set) }
                .onChange(of: focused) { _, isFocused in if !isFocused { commit(set) } }
                .accessibilityLabel("\(measure.title) in \(unitLabel ?? Units.display(measure.unit))")
            Menu {
                if let workCategory {
                    ForEach(PowerHour.quick, id: \.self) { quick in
                        Button("+ \(Format.powerHours(quick))") { app.addPowerHours(quick, categoryKey: workCategory, day: day) }
                    }
                    Divider()
                    Button("Mit Ergebnis und nächstem Schritt…", systemImage: "square.and.pencil") {
                        app.sheet = .work(WorkDraft(day: day, categoryKey: workCategory))
                    }
                } else {
                    ForEach([1.0, 2.0, 5.0, 10.0].map { $0 * step }, id: \.self) { amount in
                        Button("+ \(Format.number(amount))") { set((value ?? 0) + amount) }
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.callout.weight(.bold))
                    .frame(width: 32, height: 32)
                    .background(Brand.accent.opacity(0.15), in: .circle)
                    .foregroundStyle(Brand.accent)
            } primaryAction: {
                set((value ?? 0) + step)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .accessibilityLabel("\(measure.title) plus \(Format.number(step)); halten für mehr")
        }
        .onAppear { text = value.map { Format.number($0) } ?? "" }
        .onChange(of: value) { _, newValue in
            if !focused { text = newValue.map { Format.number($0) } ?? "" }
        }
    }

    private func commit(_ set: (Double?) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parsed: Double? = trimmed.isEmpty ? nil : Format.parse(trimmed).map { ($0 * 100).rounded() / 100 }
        guard trimmed.isEmpty || parsed != nil else {
            text = value.map { Format.number($0) } ?? ""
            return
        }
        guard parsed != value else { return }
        set(parsed)
    }

    // MARK: Time (V8: no "now" – usually entered the next day)

    @ViewBuilder
    private var timeControl: some View {
        if let value {
            DatePicker("", selection: Binding(
                get: { MeasureInput.date(minutes: value, day: day) },
                set: { app.setValue(MeasureInput.minutes(of: $0), for: measure, day: day, toast: false) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
        } else {
            HStack(spacing: 6) {
                DatePicker("", selection: Binding(
                    get: { draftTime },
                    set: { newValue in
                        draftTime = newValue
                        app.setValue(MeasureInput.minutes(of: newValue), for: measure, day: day, toast: false)
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .opacity(0.45)
                .accessibilityLabel("\(measure.title): Uhrzeit wählen")
                Button {
                    app.setValue(MeasureInput.minutes(of: draftTime), for: measure, day: day)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.callout.weight(.bold))
                        .frame(width: 32, height: 32)
                        .background(Brand.accent.opacity(0.15), in: .circle)
                        .foregroundStyle(Brand.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(measure.title): diese Uhrzeit übernehmen")
            }
            .onAppear { draftTime = MeasureInput.date(minutes: defaultMinutes, day: day) }
        }
    }

    /// The target time if there is one ("<=23:00" → 23:00), else 23:00 – a sensible starting point.
    private var defaultMinutes: Double {
        if let target = record?.target, target.isTime { return target.value }
        return 23 * 60
    }

    // MARK: Text

    private var textControl: some View {
        TextField("eintragen", text: $text)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 180)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit { app.store.setDayText(code: measure.code, day: day, text: text) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { app.store.setDayText(code: measure.code, day: day, text: text) }
            }
            .onAppear { text = context.entries.last { $0.code == measure.code && $0.dayKey == day.string }?.text ?? "" }
    }

    static func date(minutes: Double, day: DayKey) -> Date {
        let normalized = Int(minutes) % (24 * 60)
        return day.startDate().addingTimeInterval(Double(normalized) * 60)
    }

    static func minutes(of date: Date) -> Double {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour: Int = parts.hour ?? 0
        let minute: Int = parts.minute ?? 0
        return Double(hour * 60 + minute)
    }
}

// MARK: Weekly goals (V2)

/// A weekly target: bar for the week with an even-pace marker, what today added, the value
/// entered right here – and, for a progress item, that it counts by itself.
struct WeeklyGoalRow: View {
    let goal: WeeklyGoal
    let context: WeekContext
    let day: DayKey

    private var record: MeasureRecord? { goal.measure.record }

    var body: some View {
        let weekValue: Double = context.weekValue(goal.measure) ?? 0
        let today: Double = context.dayValue(goal.measure, on: day) ?? 0
        let targetValue: Double = record?.target?.scaleMax ?? 0
        let fraction: Double = targetValue > 0 ? min(1, weekValue / targetValue) : 0
        let reached: Bool = targetValue > 0 && weekValue >= targetValue - 1e-9
        let pace: Pace? = record.flatMap { record in
            record.target.map { Pace(done: weekValue, target: $0.scaleMax, days: record.days, week: context.week, today: context.today) }
        }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.item?.title ?? goal.measure.title)
                    .font(.body.weight(.semibold))
                Spacer(minLength: 6)
                Text(reached ? "erreicht" : "\(percent(fraction)) %")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(reached ? Color.white : Brand.accent)
                    .background(reached ? Color.green : Brand.accent.opacity(0.14), in: .capsule)
            }
            GoalBar(fraction: fraction, expected: pace.map { targetValue > 0 ? min(1, $0.expected / targetValue) : 0 }, reached: reached)
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Format.measure(weekValue, unit: unit)) von \(Format.measure(targetValue, unit: unit))")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    Text(today > 0 ? "heute +\(Format.measure(today, unit: unit))" : "heute noch nichts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 6)
                MeasureInput(measure: goal.measure, context: context, day: day)
            }
            Label(explanation(reached: reached), systemImage: goal.item == nil ? "chart.bar" : "wand.and.stars")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu { MeasureMenu(measure: goal.measure, context: context, day: day) }
    }

    private var unit: String { record?.isWork == true ? "PH" : goal.measure.unit }

    /// V5: say plainly what counts and how.
    private func explanation(reached: Bool) -> String {
        guard goal.item != nil else { return "Wochenziel – ein Messwert, zählt nicht in die Wertung." }
        if reached { return "Automatisch: erreicht – jeder Tag mit Eintrag zählt als ✓." }
        if context.data.isComplete { return "Automatisch: Woche vorbei – Tage mit Eintrag zählen ½, ohne Eintrag ✗." }
        return "Automatisch: Tage mit Eintrag zählen als gearbeitet und werden am Wochenende (oder bei Erreichen) rückwirkend bewertet."
    }
}

/// Week bar with an even-pace tick.
struct GoalBar: View {
    let fraction: Double
    var expected: Double?
    var reached = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(reached ? AnyShapeStyle(Color.green) : AnyShapeStyle(LinearGradient(colors: [Brand.accent.opacity(0.7), Brand.accent],
                                                                                              startPoint: .leading, endPoint: .trailing)))
                    .frame(width: max(8, geometry.size.width * fraction))
                if let expected, !reached, expected > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.45))
                        .frame(width: 2, height: 14)
                        .offset(x: geometry.size.width * expected - 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: 10)
        .animation(.snappy, value: fraction)
        .accessibilityElement()
        .accessibilityLabel("\(percent(fraction)) Prozent des Wochenziels")
    }
}

// MARK: Day page

/// The last page: what doesn't belong to a category (notes, other measurements) and closing the day.
struct DayPage: View {
    let context: WeekContext
    let day: DayKey

    var body: some View {
        List {
            DayPageSections(context: context, day: day, showsMeasures: true)
        }
        .compactListSections()
    }
}

struct DayPageSections: View {
    let context: WeekContext
    let day: DayKey
    var showsMeasures = false
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @AppStorage(TodaySettings.askConditionalsKey) private var askConditionals = false

    var body: some View {
        let closed = context.isClosed(day)
        let overall = context.score.days[day]
        let loose = context.measures.filter { $0.categoryKey.isEmpty && $0.days.contains(day.weekday) }
        let waiting = askConditionals ? context.unansweredConditionals(on: day) : []

        if context.hasPlan {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    if closed {
                        Label("Tag abgeschlossen · \(Format.score(overall?.score, outOf: true))", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(Brand.accent)
                    } else {
                        Text(overall.map { $0.blank == 0 ? "Alles erfasst – bereit zum Abschließen." : "\($0.blank) \($0.blank == 1 ? "Punkt ist" : "Punkte sind") noch offen." } ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        app.sheet = .closeDay(day)
                    } label: {
                        Label(closed ? "Abschluss ansehen" : "Tag abschließen", systemImage: closed ? "checkmark.seal" : "moon.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                }
                .padding(.vertical, 4)
                if !waiting.isEmpty {
                    Button {
                        app.sheet = .conditionals(day)
                    } label: {
                        Label("Bedingte Punkte abfragen (\(waiting.count))", systemImage: "questionmark.circle")
                    }
                }
                let tickable: [PlanItem] = context.tickable(context.items(on: day).filter { !$0.isSecondary && !context.isQuotaMetElsewhere($0, on: day) }, on: day)
                if !tickable.isEmpty, !closed {
                    QuickAllMenu(items: tickable, day: day, context: context, scope: "heute", title: "Alle offenen Punkte des Tages …")
                }
            } header: {
                Text("Abschluss")
            } footer: {
                Text("Die Tageswertung erscheint, wenn der Tag abgeschlossen ist.")
            }
        }

        if showsMeasures, !loose.isEmpty {
            Section("Weitere Messwerte") {
                ForEach(loose) { measure in
                    MeasureRow(measure: measure, context: context, day: day,
                               healthSuggestion: context.dayValue(measure, on: day) == nil ? health.suggestion(code: measure.code, day: day) : nil)
                }
            }
        }

        Section {
            ForEach(context.notes(on: day)) { note in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                        Text(note.kind.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: note.kind.symbol)
                        .foregroundStyle(Brand.accent)
                }
                .contentShape(.rect)
                .onTapGesture { app.sheet = .note(note, day) }
                .swipeActions(edge: .trailing) {
                    Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([note]) }
                }
            }
            Button {
                app.sheet = .note(nil, day)
            } label: {
                Label("Notiz, Auslöser, Erfolg oder Idee", systemImage: "plus")
            }
        } header: {
            Text("Notizen")
        }
    }
}

/// A logged power-hour entry with its description editable right in the list (V10).
struct InlineWorkRow: View {
    let block: WorkBlock
    let categoryTitle: String
    @Environment(AppModel.self) private var app
    @State private var task = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Text(Format.number(block.hours))
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                Text("PH")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                TextField("Wofür? (z. B. Lena – Mathe)", text: $task)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { app.store.setTask(block, task) }
                    .onChange(of: focused) { _, isFocused in if !isFocused { app.store.setTask(block, task) } }
                HStack(spacing: 6) {
                    KeyBadge(key: block.categoryKey)
                    Text(categoryTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .onAppear { task = block.task }
        .swipeActions(edge: .trailing) {
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([block]) }
        }
        .contextMenu {
            Button("Ergebnis und nächster Schritt…", systemImage: "square.and.pencil") {
                app.sheet = .work(WorkDraft(block: block, day: DayKey(block.dayKey) ?? app.today, categoryKey: block.categoryKey))
            }
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([block]) }
        }
    }
}

/// A new entry in one line: amount, description (with suggestions), add (V10).
struct NewWorkRow: View {
    let categoryKey: String
    let day: DayKey
    @Environment(AppModel.self) private var app
    @State private var powerHours: Double = 1
    @State private var task = ""
    @FocusState private var focused: Bool

    var body: some View {
        let suggestions: [String] = focused || !task.isEmpty
            ? Array(app.store.workSuggestions(categoryKey: categoryKey).filter { $0 != task && (task.isEmpty || $0.localizedCaseInsensitiveContains(task)) }.prefix(4))
            : []
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(PowerHour.quick, id: \.self) { value in
                        Button(Format.powerHours(value)) { powerHours = value }
                    }
                } label: {
                    Text(Format.powerHours(powerHours))
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Brand.accent.opacity(0.14), in: .capsule)
                        .foregroundStyle(Brand.accent)
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .accessibilityLabel("Menge: \(Format.powerHours(powerHours))")
                TextField("Neu: wofür?", text: $task)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Brand.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Power-Hours hinzufügen")
            }
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            ChipButton(title: suggestion, isSelected: false, symbol: "clock.arrow.circlepath") { task = suggestion }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func add() {
        app.addPowerHours(powerHours, categoryKey: categoryKey, task: task, day: day)
        task = ""
        focused = false
    }
}

/// One tap for all open items (V4): ✓ ½ ✗, or clear – with Undo.
struct QuickAllMenu: View {
    let items: [PlanItem]
    let day: DayKey
    let context: WeekContext
    let scope: String
    /// Shown as a labelled row (day page) instead of the icon (category header).
    var title: String?
    @Environment(AppModel.self) private var app

    var body: some View {
        let open: [PlanItem] = items.filter { context.mark($0, on: day) == nil }
        let marked: [PlanItem] = items.filter { context.recordedMark($0, on: day) != nil }
        Menu {
            Section("Alle offenen (\(open.count))") {
                Button("✓ Erledigt", systemImage: "checkmark.circle") { app.setAll(.done, items: open, day: day, scope: scope) }
                Button("½ Teilweise", systemImage: "circle.lefthalf.filled") { app.setAll(.partial, items: open, day: day, scope: scope) }
                Button("✗ Nicht erledigt", systemImage: "xmark.circle") { app.setAll(.missed, items: open, day: day, scope: scope) }
            }
            .disabled(open.isEmpty)
            Button("Alle leeren (\(marked.count))", systemImage: "circle.dashed", role: .destructive) {
                app.setAll(nil, items: marked, day: day, scope: scope)
            }
            .disabled(marked.isEmpty)
        } label: {
            if let title {
                Label(title, systemImage: "checklist")
            } else {
                Image(systemName: "checklist")
                    .font(.body)
                    .foregroundStyle(Brand.accent)
            }
        }
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .accessibilityLabel("Alle Punkte von \(scope) auf einmal setzen")
    }
}

// MARK: Day overview (U2.3)

/// The whole day on one screen, opened on purpose: fill per category, power-hours, values, notes.
struct DayOverviewSheet: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WeekReader(week: day.week, today: app.today) { context in
                DayOverviewList(context: context, day: day) { page in
                    app.todayPage = page
                    app.tab = .today
                    app.sidebar = .today
                    dismiss()
                }
            }
            .navigationTitle(day.shortLabel)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .sheetFrame(minWidth: 460, minHeight: 600)
    }
}

struct DayOverviewList: View {
    let context: WeekContext
    let day: DayKey
    let onOpen: (TodayPage) -> Void

    var body: some View {
        let overall = context.score.days[day]
        let closed = context.isClosed(day)
        let totals = context.workTotals(on: day)
        List {
            Section {
                HeroCard(title: day.longLabel,
                         subtitle: closed ? "Tag abgeschlossen" : "Die Wertung kommt mit dem Abschluss.",
                         value: closed ? Format.score(overall?.score, outOf: false) : (overall?.coverageText ?? "0 %"),
                         caption: closed ? "Tag" : "erfasst",
                         progress: closed ? (overall?.score ?? 0) / 10 : (overall?.coverage ?? 0),
                         facts: [("Woche", Format.score(context.score.overall, outOf: true)),
                                 ("Fokus", totals.isEmpty ? "–" : totals.shortText)])
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Kategorien") {
                ForEach(context.todayCategories(day)) { category in
                    let entry = context.score.category(category.key, on: day)
                    Button {
                        onOpen(.category(category.key))
                    } label: {
                        HStack(spacing: 10) {
                            KeyBadge(key: category.key)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(category.title)
                                    .lineLimit(1)
                                if entry.due > 0 {
                                    ProgressView(value: entry.fill)
                                        .tint(entry.isComplete ? .green : Brand.accent)
                                }
                            }
                            Spacer(minLength: 8)
                            if entry.due > 0 {
                                Text(entry.isComplete ? Format.score(entry.score, outOf: false) : "\(entry.due - entry.blank)/\(entry.due)")
                                    .font(.callout.weight(entry.isComplete ? .semibold : .regular))
                                    .monospacedDigit()
                                    .foregroundStyle(entry.isComplete ? .primary : .secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !totals.isEmpty {
                Section {
                    ForEach(WorkTotals.byCategory(context.workRecords.filter { $0.day == day }).sorted { $0.key < $1.key }, id: \.key) { pair in
                        LabeledContent("\(pair.key) \(context.category(pair.key)?.title ?? "")", value: pair.value.shortText)
                    }
                } header: {
                    Text("Power-Hours · \(totals.shortText)")
                } footer: {
                    Text(totals.explanation)
                }
            }

            let measured = context.measures.filter { $0.days.contains(day.weekday) && context.dayValue($0, on: day) != nil }
            if !measured.isEmpty {
                Section("Messwerte") {
                    ForEach(measured) { measure in
                        LabeledContent(measure.title, value: context.dayValue(measure, on: day).map { Format.measure($0, unit: measure.unit) } ?? "–")
                    }
                }
            }

            let notes = context.notes(on: day)
            if !notes.isEmpty {
                Section("Notizen") {
                    ForEach(notes) { note in
                        Label(note.text, systemImage: note.kind.symbol)
                    }
                }
            }
        }
        .compactListSections()
    }
}

// MARK: Conditional items (U12.9)

/// "Gab es heute …?" – the situations that happened get marked, the rest becomes N/A.
struct ConditionalsSheet: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var occurred: Set<String> = []

    var body: some View {
        NavigationStack {
            WeekReader(week: day.week, today: app.today) { context in
                let items = context.items(on: day).filter { $0.schedule == .conditional }
                Form {
                    Section {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: Binding(
                                    get: { occurred.contains(item.code) || (context.mark(item, on: day).map { $0 != .notApplicable } ?? false) },
                                    set: { isOn in
                                        if isOn { occurred.insert(item.code) } else {
                                            occurred.remove(item.code)
                                            if context.mark(item, on: day) != nil { app.setMark(nil, item: item, day: day) }
                                        }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                        Text("\(item.categoryKey) · \(context.category(item.categoryKey)?.title ?? "")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if occurred.contains(item.code) || (context.mark(item, on: day).map { $0 != .notApplicable } ?? false) {
                                    MarkBar(mark: context.mark(item, on: day), options: [.done, .partial, .missed]) {
                                        app.setMark($0, item: item, day: day)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Gab es diese Situationen heute?")
                    } footer: {
                        Text("Was nicht vorkam, zählt als N/A und verändert die Wertung nicht.")
                    }
                }
                .formStyle(.grouped)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") {
                            let answered = Set(items.filter { context.mark($0, on: day).map { $0 != .notApplicable } ?? false }.map(\.code))
                            let open = items.filter { context.mark($0, on: day) == nil }
                            app.store.settleConditionals(open, occurred: occurred.union(answered), day: day)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Bedingte Punkte")
            .inlineNavigationTitle()
        }
        .sheetFrame(minWidth: 460, minHeight: 520)
    }
}

// MARK: No plan, toolbar

/// The week has no plan yet.
struct NoPlanView: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Noch kein Plan für \(week.label)", systemImage: "calendar.badge.plus")
                .font(.headline)
            Text("Sonntags: Reflexion und Zusagen an ChatGPT schicken – mit dem Planungs-Prompt aus Thalia kommt eine CSV zurück, die du hier einfügst.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                app.sheet = .importPlan(prompt: true)
            } label: {
                Label("Wochenplan importieren", systemImage: "square.and.arrow.down")
            }
            .primaryActionStyle()
        }
        .padding(.vertical, 6)
    }
}

/// Toolbar of Today. iPhone: "+" sits at the bottom (accessory), here only the menu. Mac and
/// iPad: day navigation, "+" and closing the day in the toolbar.
struct TodayToolbar: ToolbarContent {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItemGroup(placement: .navigation) {
            Button { app.selectedDay = day.adding(days: -1) } label: { Label("Voriger Tag", systemImage: "chevron.left") }
                .help("Voriger Tag (⌘[)")
            Button("Heute") { app.selectedDay = app.today }
                .disabled(day == app.today)
                .help("Zu heute (⇧⌘T)")
            Button { app.selectedDay = day.adding(days: 1) } label: { Label("Nächster Tag", systemImage: "chevron.right") }
                .help("Nächster Tag (⌘])")
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                app.sheet = .closeDay(day)
            } label: {
                Label(context.isClosed(day) ? "Abgeschlossen" : "Tag abschließen",
                      systemImage: context.isClosed(day) ? "checkmark.seal.fill" : "moon.stars")
            }
            .help("Tag abschließen")
            Button {
                app.sheet = .create
            } label: {
                Label("Erfassen", systemImage: "plus")
            }
            .help("Erfassen (⌘N)")
        }
        #else
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Tagesübersicht", systemImage: "info.circle") { app.sheet = .dayOverview(day) }
                Button("Wochenplan importieren", systemImage: "square.and.arrow.down") { app.sheet = .importPlan(prompt: true) }
                Button("Zuletzt gelöscht", systemImage: "trash") { app.sheet = .trash }
                Divider()
                if !app.isSandbox {
                    Button("Thalia-Tour", systemImage: "graduationcap") { app.startTour() }
                }
                Button("Einstellungen", systemImage: "gear") { app.sheet = .settings }
            } label: {
                Label("Mehr", systemImage: "ellipsis")
            }
        }
        #endif
    }
}

/// Toolbar of Woche, Ziele and Rückblick: on the Mac "+" (iPhone has it at the bottom), on
/// iPhone/iPad the menu with import, trash, tour and settings.
struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var app

    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .primaryAction) {
            Button {
                app.sheet = .create
            } label: {
                Label("Erfassen", systemImage: "plus")
            }
            .help("Erfassen (⇧⌘N)")
        }
        #else
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Wochenplan importieren", systemImage: "square.and.arrow.down") { app.sheet = .importPlan(prompt: true) }
                Button("Zuletzt gelöscht", systemImage: "trash") { app.sheet = .trash }
                Divider()
                if !app.isSandbox {
                    Button("Thalia-Tour", systemImage: "graduationcap") { app.startTour() }
                }
                Button("Einstellungen", systemImage: "gear") { app.sheet = .settings }
            } label: {
                Label("Mehr", systemImage: "ellipsis")
            }
        }
        #endif
    }
}
