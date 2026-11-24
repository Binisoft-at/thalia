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
        let _ = diagBody("TodayView")
        WeekReader(week: app.selectedDay.week, today: app.today) { context in
            let _ = diagBody("TodayContent")
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
                || derivedWork(on: day).contains { $0.categoryKey == category.key }
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

    /// The first category that still has something blank – where Today opens; with nothing open
    /// "Abschluss & Notizen" (R6).
    func firstOpenPage(_ day: DayKey) -> TodayPage {
        let pages = todayCategories(day)
        if let open = pages.first(where: { score.category($0.key, on: day).blank > 0 }) { return .category(open.key) }
        return .day
    }

    /// Today's pages in order: the categories, then "Abschluss & Notizen" (R35).
    func todayPageOrder(_ day: DayKey) -> [TodayPage] {
        todayCategories(day).map { TodayPage.category($0.key) } + [TodayPage.day]
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

    private var usesSplit: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    /// R6: reads only the stored page – the start page is chosen once per day (`choosePage`), so
    /// ticking an item never moves the page. Until then the first category stands in.
    private func page(_ pages: [TrackCategory]) -> Binding<TodayPage> {
        let model: AppModel = app
        let fallback: TodayPage = pages.first.map { TodayPage.category($0.key) } ?? .day
        return Binding(get: { model.todayPage ?? fallback },
                       set: { model.todayPage = $0 })
    }

    /// iPhone/iPad: "Heute" or the weekday (the title menu shows the date); Mac: the date (R60).
    private var title: String {
        #if os(macOS)
        day.longLabel
        #else
        day == app.today ? "Heute" : day.weekday.name
        #endif
    }

    var body: some View {
        // v11 P2.12: the day's categories once per body – the layouts, the start page and its check share them.
        let pages: [TrackCategory] = context.todayCategories(day)
        Group {
            if !context.hasPlan {
                List {
                    if day == app.today {
                        Section {
                            // v11 P5.1: Tue–Sun yesterday is in this week – no reader of its own.
                            YesterdayBanner(today: app.today, context: context)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                        }
                    }
                    if context.isArchiveWeek, context.week < app.today.week {
                        // v9: a day of a past week from old records – its scores and grades, not "Noch kein Plan".
                        Section { ArchiveDayNotice(context: context, day: day) }
                    } else {
                        Section { NoPlanView(week: context.week) }
                    }
                    DayPageSections(context: context, day: day, showsMeasures: true)
                }
                .compactListSections()
            } else if usesSplit {
                TodaySplit(context: context, day: day, pages: pages, page: page(pages))
            } else {
                TodayPager(context: context, day: day, pages: pages, page: page(pages))
            }
        }
        .navigationTitle(title)
        .inlineNavigationTitle()
        .todayTitleMenu(context: context, day: day)
        .toolbar { TodayToolbar(context: context, day: day, usesSplit: usesSplit) }
        .onChange(of: day) { _, _ in app.todayPage = nil }
        .onChange(of: pages.map(\.key)) { _, _ in choosePage() }
        .task(id: day) {
            choosePage()
            await health.load(day: day, measures: context.measures.compactMap(\.record))
        }
        // Apple Health again whenever Thalia comes to the front: steps, water and sleep change
        // during the day, and a suggestion read at 7:00 must not be adopted at 21:00.
        .onChange(of: app.activationTick) { _, _ in
            Task { await health.load(day: day, measures: context.measures.compactMap(\.record)) }
        }
    }

    /// R6: the start page once per day – the first category with something open, else "Abschluss &
    /// Notizen"; again only when the stored page is gone (e.g. the day type changed). Also tells the
    /// app the page order for ⌥⌘↓ / ⌥⌘↑ (R35).
    private func choosePage() {
        // The week's data may still be the previous week's for a moment after a jump.
        guard context.week == day.week else { return }
        let order: [TodayPage] = context.todayPageOrder(day)
        if app.todayPageOrder != order { app.todayPageOrder = order }
        if let current = app.todayPage, order.contains(current) { return }
        app.todayPage = context.firstOpenPage(day)
    }
}

/// The days of the week, other weeks, back to today and the day's type and note – the title menu
/// on iPhone (R38), the window title on the Mac (R60) and the iPad's list head.
struct TodayDayMenu: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    private func dayTitle(_ other: DayKey) -> String {
        other == app.today ? other.shortLabel + " · heute" : other.shortLabel
    }

    private func daySymbol(_ other: DayKey) -> String {
        if other == day { return "checkmark" }
        return context.isClosed(other) ? "checkmark.seal.fill" : "circle"
    }

    var body: some View {
        ForEach(context.week.days, id: \.self) { other in
            Button {
                app.selectedDay = other
            } label: {
                Label(dayTitle(other), systemImage: daySymbol(other))
            }
        }
        Divider()
        Button("Vorige Woche", systemImage: "chevron.left") { app.selectedDay = day.adding(days: -7) }
        Button("Nächste Woche", systemImage: "chevron.right") { app.selectedDay = day.adding(days: 7) }
        Button("Zu heute", systemImage: "sun.max") { app.goToToday() }
            .disabled(day == app.today)
        Divider()
        // v8: Krank / Urlaub in one step (they're on top).
        DayTypeMenu(app: app, day: day, current: context.dayType(day))
        Button("Tagestyp und Besonderheit…", systemImage: "calendar.badge.clock") { app.sheet = .dayInfo(day) }
    }
}

/// "16. Nov." – the short date without the weekday.
func todayDateText(_ day: DayKey) -> String {
    let label: String = day.shortLabel
    guard let range = label.range(of: ", ") else { return label }
    return String(label[range.upperBound...])
}

/// "16. Nov. · KW47 · Arbeitstag" (R38).
func todayDateLine(_ context: WeekContext, day: DayKey) -> String {
    var parts: [String] = [todayDateText(day), day.week.label]
    let type: String = context.dayType(day)
    if !type.isEmpty { parts.append(type) }
    return parts.joined(separator: " · ")
}

extension View {
    /// Mac: the day menu on the window title and "KW47 · Arbeitstag" below it (R60). iPhone/iPad
    /// have their own title menu (R38).
    @ViewBuilder
    func todayTitleMenu(context: WeekContext, day: DayKey) -> some View {
        #if os(macOS)
        self
            .navigationSubtitle(macSubtitle(context, day: day))
            .toolbarTitleMenu { TodayDayMenu(context: context, day: day) }
        #else
        self
        #endif
    }
}

#if os(macOS)
/// "KW47 · Arbeitstag".
private func macSubtitle(_ context: WeekContext, day: DayKey) -> String {
    let type: String = context.dayType(day)
    return type.isEmpty ? day.week.label : "\(day.week.label) · \(type)"
}
#endif

// MARK: Layouts

/// iPhone: the date sits in the title bar (R38); yesterday's banner, category chips, the day's note,
/// then one page per category (swipe or tap a chip).
private struct TodayPager: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(spacing: 0) {
            if day == app.today {
                YesterdayBanner(today: app.today, context: context)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
            }
            CategoryChips(context: context, day: day, pages: pages, page: $page)
                .padding(.vertical, 8)
            TodayDayHints(context: context, day: day,
                          insets: EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
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

/// iPad (wide) and Mac: categories on the left, the page on the right, "Heute im Blick" as the right
/// column (R59). Mac: the list can be dragged between 220 and 340 pt (R60, v11 P4.1); iPad keeps 270 pt.
/// v11 P4.1: the column shows only while it fits – the stored choice stays, too narrow opens it as a sheet.
private struct TodaySplit: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage
    @Environment(AppModel.self) private var app

    /// Shown while chosen and fitting; closing it (✕, ⌘0) changes the stored choice.
    private var inspectorShown: Binding<Bool> {
        let model: AppModel = app
        return Binding(get: { model.showsGlanceColumn }, set: { model.showsGlanceInspector = $0 })
    }

    var body: some View {
        split
            .inspector(isPresented: inspectorShown) {
                GlanceList(context: context, day: day, onOpen: { page = $0 })
                    .diagWidth("today inspector")
                    .inspectorColumnWidth(min: 260, ideal: 300, max: 380)
            }
    }

    @ViewBuilder
    private var split: some View {
        #if os(macOS)
        HSplitView {
            list
                .frame(minWidth: 220, idealWidth: 270, maxWidth: 340)
                .diagWidth("today list")
            // v11 P4.1: an ideal width of its own – otherwise the page reports the width of its widest row
            // (the marks beside the title need 640 pt) and the split view grows past the window (CI run 38).
            detail
                .frame(minWidth: 420, idealWidth: 420, maxWidth: .infinity)
                .diagWidth("today page")
        }
        #else
        HStack(spacing: 0) {
            list
                .frame(width: 270)
            Divider()
            detail
                .frame(maxWidth: .infinity)
        }
        #endif
    }

    private var selection: Binding<TodayPage?> {
        let current: Binding<TodayPage> = $page
        return Binding<TodayPage?>(get: { current.wrappedValue }, set: { value in
            if let value { current.wrappedValue = value }
        })
    }

    private var list: some View {
        List(selection: selection) {
            if day == app.today {
                Section {
                    YesterdayBanner(today: app.today, context: context)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                listHead
                    .listRowBackground(Color.clear)
            }
            Section("Kategorien") {
                ForEach(pages) { category in
                    CategoryListRow(context: context, category: category, day: day)
                        .tag(TodayPage.category(category.key))
                }
            }
            Section {
                Label("Abschluss & Notizen", systemImage: "moon.stars")
                    .tag(TodayPage.day)
            }
        }
        .listStyle(.sidebar)
    }

    /// Mac: only ring and "73 % erfasst" – date and week are in the window title (R60). iPad: date,
    /// week, day type and ring as before. Both: the day's note and the work-free hint (R90, R78).
    @ViewBuilder
    private var listHead: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 6) {
            TodayFillButton(context: context, day: day, opensColumn: true)
            TodayDayHints(context: context, day: day)
        }
        #else
        VStack(alignment: .leading, spacing: 6) {
            TodayHeader(context: context, day: day, showsOverviewButton: false)
            TodayDayHints(context: context, day: day)
        }
        #endif
    }

    @ViewBuilder
    private var detail: some View {
        switch page {
        case .category(let key):
            if let index = pages.firstIndex(where: { $0.key == key }) {
                CategoryPage(context: context, category: pages[index], day: day,
                             next: index + 1 < pages.count ? pages[index + 1] : nil, page: $page, selectable: true)
                    .id(key)
            } else {
                DayPage(context: context, day: day)
            }
        case .day:
            // v11 P5.12: "Abschluss & Notizen" has no keys – a pending focus request ends here, so a later click in the
            // category list keeps the focus there.
            DayPage(context: context, day: day)
                .onAppear { if app.focusTodayPage { app.focusTodayPage = false } }
        }
    }
}

/// R90/R78: the plan's note for the day and, on a work-free day, that work items don't count –
/// only what there is.
struct TodayDayHints: View {
    let context: WeekContext
    let day: DayKey
    /// Space around the lines – only taken when there is something to show.
    var insets = EdgeInsets()
    @Environment(AppModel.self) private var app

    var body: some View {
        let note: String = context.dayNote(day).trimmingCharacters(in: .whitespacesAndNewlines)
        let isFree: Bool = context.isFreeDay(day)
        if context.isExcused(day) {
            // v8: a sick or holiday day – the card says it doesn't count, "Typ ändern" undoes it.
            VStack(alignment: .leading, spacing: 6) {
                ExcusedDayCard(app: app, day: day, type: context.dayType(day))
                DayNoteLabel(note: note)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(insets)
        } else if !note.isEmpty || isFree {
            VStack(alignment: .leading, spacing: 3) {
                DayNoteLabel(note: note)
                if isFree {
                    Label(DayTypes.workFreeHint, systemImage: DayTypes.symbol(for: context.dayType(day)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(insets)
        }
    }
}

/// Ring and "73 % erfasst" (the score once closed). Mac list head: a click shows or hides the "Heute
/// im Blick" column (R59); elsewhere it opens "Heute im Blick" as a sheet.
struct TodayFillButton: View {
    let context: WeekContext
    let day: DayKey
    var opensColumn = false
    @Environment(AppModel.self) private var app

    private var caption: String {
        let overall: DayOverall? = context.score.days[day]
        if context.isExcused(day) { return "\(context.excusedName(day)) – zählt nicht" }
        if context.isClosed(day) { return "Abgeschlossen · \(Format.score(overall?.score, outOf: true))" }
        return "\(overall?.coverageText ?? "0 %") erfasst"
    }

    private var spoken: String {
        let overall: DayOverall? = context.score.days[day]
        if context.isExcused(day) { return "\(context.excusedName(day)), der Tag zählt nicht" }
        if context.isClosed(day) { return "Tag abgeschlossen, Wertung \(Format.score(overall?.score))" }
        return "\(overall?.coverageText ?? "0 %") erfasst"
    }

    /// v8: the day type's symbol in the ring on a sick or holiday day.
    private var excusedSymbol: String? {
        context.isExcused(day) ? DayTypes.symbol(for: context.dayType(day)) : nil
    }

    /// v11 P4.1: the column only while it fits – otherwise the ring opens "Heute im Blick" as a sheet.
    private var helpText: String {
        guard opensColumn else { return "Heute im Blick" }
        return app.fitsGlanceInspector ? "Heute im Blick ein- oder ausblenden (⌘0)" : "Fenster breiter ziehen, um die Spalte zu zeigen"
    }

    var body: some View {
        let overall: DayOverall? = context.score.days[day]
        let closed: Bool = context.isClosed(day)
        let shownScore: Double? = closed ? overall?.score : nil
        Button {
            if opensColumn {
                app.showDayOverview(day)
            } else {
                app.sheet = .dayOverview(day)
            }
        } label: {
            HStack(spacing: 10) {
                FillRing(fill: overall?.coverage ?? 0, score: shownScore, size: 34, lineWidth: 4, excusedSymbol: excusedSymbol)
                Text(caption)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(spoken)
        .accessibilityHint(opensColumn && app.fitsGlanceInspector ? "Blendet „Heute im Blick“ ein oder aus" : "Öffnet „Heute im Blick“")
    }
}

// MARK: Header

/// Date, day type and how much is filled in (the score once the day is closed) – the iPad's list
/// head. Tapping the ring opens "Heute im Blick".
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
                    TodayDayMenu(context: context, day: day)
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
                        Text(statusCaption(closed: closed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(statusValue(closed: closed, overall: overall))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    FillRing(fill: overall?.coverage ?? 0, score: closed ? overall?.score : nil, size: 44,
                             excusedSymbol: excusedSymbol)
                    if showsOverviewButton {
                        Image(systemName: "info.circle")
                            .font(.body)
                            .foregroundStyle(Brand.accent)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spokenStatus(closed: closed, overall: overall))
            .accessibilityHint("Öffnet „Heute im Blick“")
        }
    }

    /// v8: the day type's symbol in the ring on a sick or holiday day.
    private var excusedSymbol: String? {
        context.isExcused(day) ? DayTypes.symbol(for: context.dayType(day)) : nil
    }

    /// "Abgeschlossen" · "Erfasst"; v8: "Zählt nicht" on a sick or holiday day.
    private func statusCaption(closed: Bool) -> String {
        if context.isExcused(day) { return "Zählt nicht" }
        return closed ? "Abgeschlossen" : "Erfasst"
    }

    /// "7,5/10" · "62 %"; v8: "Krank" / "Urlaub".
    private func statusValue(closed: Bool, overall: DayOverall?) -> String {
        if context.isExcused(day) { return context.excusedName(day) }
        if closed { return Format.score(overall?.score, outOf: true) }
        return overall?.coverageText ?? "–"
    }

    private func spokenStatus(closed: Bool, overall: DayOverall?) -> String {
        if context.isExcused(day) { return "\(context.excusedName(day)), der Tag zählt nicht" }
        if closed { return "Tag abgeschlossen, Wertung \(Format.score(overall?.score))" }
        return "\(overall?.coverageText ?? "0 %") erfasst"
    }
}

/// How much is filled in (0…1) as a ring; with a score (closed day) the ring shows the score.
struct FillRing: View {
    let fill: Double
    var score: Double?
    var size: CGFloat = 44
    var lineWidth: CGFloat = 5
    /// v8: a sick or holiday day – an empty grey ring with the day type's symbol ("zählt nicht").
    var excusedSymbol: String?

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: lineWidth)
            if let excusedSymbol {
                Image(systemName: excusedSymbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                progress
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: fill)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var progress: some View {
        ZStack {
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
    }
}

// MARK: Category navigation

/// The categories of the day as chips; the selected one is filled, a finished one gets a check.
private struct CategoryChips: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage
    @Environment(AppModel.self) private var app
    @State private var showsPicker = false
    /// R67: grows with the system text size; identical at the standard size.
    @ScaledMetric(relativeTo: .caption) private var chipHeight: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var gridWidth: CGFloat = 42
    @ScaledMetric(relativeTo: .caption) private var closingWidth: CGFloat = 70
    @ScaledMetric(relativeTo: .caption) private var closingWord: CGFloat = 9.5

    var body: some View {
        HStack(spacing: 0) {
            Button {
                showsPicker = true
            } label: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: gridWidth, height: chipHeight)
                    .foregroundStyle(Brand.accent)
                    .background(Brand.accent.opacity(0.12), in: .rect(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, 16)
            .accessibilityLabel("Alle Kategorien zeigen")
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pages) { category in
                            CategoryChip(category: category, entry: context.score.category(category.key, on: day),
                                         selected: page == .category(category.key)) {
                                withAnimation(.snappy) { page = .category(category.key) }
                            }
                            .id(TodayPage.category(category.key))
                        }
                        Button {
                            withAnimation(.snappy) { page = .day }
                        } label: {
                            VStack(spacing: 1) {
                                Image(systemName: "moon.stars.fill")
                                    .font(.subheadline.weight(.semibold))
                                Text("Abschluss")
                                    .font(.system(size: closingWord, weight: .semibold))
                            }
                            .frame(width: closingWidth, height: chipHeight)
                            .foregroundStyle(page == .day ? Color.white : Color.primary)
                            .background(page == .day ? AnyShapeStyle(Color.accentFill.gradient) : AnyShapeStyle(Color.secondary.opacity(0.12)),
                                        in: .rect(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(TodayPage.day)
                        .accessibilityLabel("Abschluss & Notizen")
                    }
                    .padding(.horizontal, 8)
                    .padding(.trailing, 8)
                }
                .onChange(of: page) { _, value in
                    withAnimation(.snappy) { proxy.scrollTo(value, anchor: .center) }
                }
                .onAppear { proxy.scrollTo(page, anchor: .center) }
            }
        }
        .sheet(isPresented: $showsPicker) {
            CategoryPicker(context: context, day: day, pages: pages, page: $page)
                .toastHost(app)
                .presentationDetents([.medium, .large])
        }
    }
}

/// Number, short name and fill in the goal's colour (W4).
private struct CategoryChip: View {
    let category: TrackCategory
    let entry: CategoryDay
    let selected: Bool
    let action: () -> Void
    /// R67: grows with the system text size; identical at the standard size.
    @ScaledMetric(relativeTo: .caption) private var keySize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var titleSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var checkSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption) private var fillSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                ZStack {
                    if entry.due > 0, entry.isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: checkSize, weight: .heavy))
                    } else {
                        MiniFill(fill: entry.due > 0 ? entry.fill : 0, inverted: selected, tint: category.color)
                    }
                }
                .frame(width: fillSize, height: fillSize)
                VStack(alignment: .leading, spacing: 0) {
                    Text(category.key)
                        .font(.system(size: keySize, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    Text(category.shortTitle)
                        .font(.system(size: titleSize, weight: .semibold))
                        .lineLimit(1)
                        .opacity(selected ? 0.9 : 0.75)
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: height)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? AnyShapeStyle(GoalPalette.gradient(goal: category.key)) : AnyShapeStyle(category.color.opacity(0.12)))
            }
            .overlay(alignment: .bottom) {
                if !selected {
                    Capsule().fill(category.color).frame(width: 18, height: 3).padding(.bottom, 3)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.key) \(category.title), \(percent(entry.fill)) Prozent erfasst")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Every category of the day, grouped by goal, with fill – tap to jump (W4).
private struct CategoryPicker: View {
    let context: WeekContext
    let day: DayKey
    let pages: [TrackCategory]
    @Binding var page: TodayPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(context.goals) { goal in
                    let categories: [TrackCategory] = pages.filter { $0.goalKey == goal.key }
                    if !categories.isEmpty {
                        Section {
                            ForEach(categories) { category in
                                let entry: CategoryDay = context.score.category(category.key, on: day)
                                Button {
                                    page = .category(category.key)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Text(category.key)
                                            .font(.caption.weight(.heavy))
                                            .monospacedDigit()
                                            .foregroundStyle(.white)
                                            .frame(width: 34, height: 26)
                                            .background(category.color.gradient, in: .rect(cornerRadius: 8, style: .continuous))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(category.title)
                                                .foregroundStyle(.primary)
                                            ProgressView(value: entry.due > 0 ? entry.fill : 0)
                                                .tint(entry.isComplete ? .green : category.color)
                                        }
                                        CategoryEntryTrailing(entry: entry)
                                            .frame(width: 56, alignment: .trailing)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label("\(goal.key) \(goal.title)", systemImage: "circle.fill")
                                .foregroundStyle(goal.color)
                        }
                    }
                }
                Section {
                    Button {
                        page = .day
                        dismiss()
                    } label: {
                        Label("Abschluss & Notizen", systemImage: "moon.stars.fill")
                    }
                }
            }
            .navigationTitle("Kategorien")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
    }
}

/// The picker's right side: "–" with nothing due, the score once complete, ✓ when complete without a score
/// (v11 P5.14: everything recorded, nothing to score today), else "62 %".
private struct CategoryEntryTrailing: View {
    let entry: CategoryDay

    var body: some View {
        if entry.due > 0, entry.isComplete, entry.score == nil {
            Image(systemName: "checkmark")
                .font(.callout.weight(.bold))
                .foregroundStyle(.green)
                .help(CategoryEntryTrailing.completeHelp)
                .accessibilityLabel("alles erfasst")
        } else {
            Text(text)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.isComplete ? .primary : .secondary)
        }
    }

    private var text: String {
        if entry.due == 0 { return "–" }
        if entry.isComplete { return Format.score(entry.score, outOf: false) }
        return "\(percent(entry.fill)) %"
    }

    static let completeHelp = "Alles erfasst – heute nichts zu werten"
}

private struct MiniFill: View {
    let fill: Double
    var inverted = false
    var tint: Color = Brand.accent

    var body: some View {
        ZStack {
            Circle().stroke((inverted ? Color.white : tint).opacity(0.3), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(fill))
                .stroke(inverted ? Color.white : tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
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
                } else if entry.isComplete {
                    // v11 P5.14: complete without a score – ✓, not "100 %".
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                        .help(CategoryEntryTrailing.completeHelp)
                        .accessibilityLabel("alles erfasst")
                } else {
                    Text("\(percent(entry.fill)) %")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        // R60: long names are cut in the narrow column – the tooltip shows them whole.
        .help("\(category.key) \(category.title)")
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
    /// Mac and iPad: items can be selected and marked with 1–4 (R35).
    var selectable = false

    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @AppStorage(TodaySettings.askConditionalsKey) private var askConditionals = false
    @State private var showsInfo = false
    @State private var showsSecondary = false
    @State private var showsDone = false
    /// The selected item (R35).
    @State private var selectedItemCode: String?
    /// v11 P5.12: the selectable list has the keyboard focus – 1–4 work without a click.
    @FocusState private var listFocused: Bool
    /// The spending being changed in the input row (R46).
    @State private var editingExpense: MeasureEntry?

    /// Everything due today in this category except derived progress items (they live in the
    /// weekly card) and unanswered conditionals when they're asked first.
    private var dayItems: [PlanItem] {
        context.items(in: category, on: day).filter { item in
            !context.isDerived(item)
                && !(askConditionals && item.schedule == .conditional && context.mark(item, on: day) == nil)
        }
    }

    /// The day's items split into the main list, "Weitere" and "Diese Woche schon erfüllt".
    private struct ItemGroups {
        let main: [PlanItem]
        let secondary: [PlanItem]
        let doneThisWeek: [PlanItem]
    }

    private func itemGroups() -> ItemGroups {
        let all: [PlanItem] = dayItems
        let done: [PlanItem] = all.filter { context.isQuotaMetElsewhere($0, on: day) }
        let doneCodes: Set<String> = Set(done.map(\.code))
        let secondary: [PlanItem] = all.filter { $0.isSecondary && !doneCodes.contains($0.code) }
        let main: [PlanItem] = all.filter { !$0.isSecondary && !doneCodes.contains($0.code) }
        return ItemGroups(main: main, secondary: secondary, doneThisWeek: done)
    }

    /// The items in the order they are shown (folded groups only when open) – for the keys (R35).
    private func visibleItems() -> [PlanItem] {
        let groups: ItemGroups = itemGroups()
        var items: [PlanItem] = groups.main
        if showsSecondary { items += groups.secondary }
        if showsDone { items += groups.doneThisWeek }
        return items
    }

    /// The power-hours section shows for work categories and wherever work was logged today.
    private var showsWorkSection: Bool {
        let key: String = category.key
        let isWorkCategory: Bool = context.measures.contains { $0.record?.source == .work(category: key) }
        // v10: power-hours "aus Theo" show here too.
        return isWorkCategory || context.work(on: day).contains { $0.categoryKey == key }
            || context.derivedWork(on: day).contains { $0.categoryKey == key }
    }

    var body: some View {
        Group {
            if selectable {
                List(selection: $selectedItemCode) { sections }
                    .focused($listFocused)
            } else {
                List { sections }
            }
        }
        .compactListSections()
        .contentMargins(.top, 4, for: .scrollContent)
        .scrollDismissesKeyboard(.interactively)
        .onKeyPress(characters: CharacterSet(charactersIn: "1234")) { press in
            handleKey(press.characters)
        }
        .environment(\.markKeyHints, selectable)
        // v11 P5.12: ⌘1, ⌥⌘↓ / ⌥⌘↑, "Weiter" and the main window becoming key ask the page's list to take the keys.
        .onAppear(perform: takeFocusIfAsked)
        .onChange(of: app.focusTodayPage) { _, _ in takeFocusIfAsked() }
        .onChange(of: listFocused) { _, focused in
            if focused { selectFirstOpenIfNeeded() }
        }
    }

    // MARK: Focus (v11 P5.12)

    /// The list takes the keyboard focus when the app asks for it (`AppModel.focusTodayPage`); a click into the
    /// category list leaves the focus there.
    private func takeFocusIfAsked() {
        // Only the page on screen – not one that is just being replaced by ⌥⌘↓ / "Weiter".
        guard selectable, app.focusTodayPage, page == .category(category.key) else { return }
        listFocused = true
        app.focusTodayPage = false
        selectFirstOpenIfNeeded()
    }

    /// The list got the focus without a selection: the first open item is marked, before the first key works –
    /// a key on an item that isn't marked would be blind (KR2-7).
    private func selectFirstOpenIfNeeded() {
        guard selectable else { return }
        let items: [PlanItem] = visibleItems()
        if let code = selectedItemCode, items.contains(where: { $0.code == code }) { return }
        selectedItemCode = firstOpenItem(in: items)?.code
    }

    /// The first item without a mark that can be marked (the `nextOpenItem` rule from the top).
    private func firstOpenItem(in items: [PlanItem]) -> PlanItem? {
        items.first { context.mark($0, on: day) == nil && !context.options($0, on: day).isEmpty }
    }

    @ViewBuilder
    private var sections: some View {
        let entry: CategoryDay = context.score.category(category.key, on: day)
        let split: ItemGroups = itemGroups()
        let doneThisWeek: [PlanItem] = split.doneThisWeek
        let secondary: [PlanItem] = split.secondary
        let main: [PlanItem] = split.main
        let goals: [WeeklyGoal] = context.weeklyGoals(categoryKey: category.key, on: day)
        let groups = context.measureGroups(categoryKey: category.key, on: day)
        let secondaryGroups = context.measureGroups(categoryKey: category.key, on: day, secondary: true)
        let secondaryCount: Int = secondary.count + secondaryGroups.reduce(0) { $0 + $1.measures.count }
        let waiting: [PlanItem] = askConditionals ? context.unansweredConditionals(on: day).filter { $0.categoryKey == category.key } : []
        let workSection: Bool = showsWorkSection
        Section {
            header(entry, tickable: context.tickable(main, on: day))
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))

        if !goals.isEmpty {
            Section {
                ForEach(goals) { goal in
                    WeeklyGoalRow(goal: goal, context: context, day: day)
                }
            } header: {
                Text("Wochenziele")
            }
        }

        // R37: one way in for power-hours – right below the weekly target that counts them.
        if workSection {
            Section {
                ForEach(context.work(on: day).filter { $0.categoryKey == category.key }) { block in
                    InlineWorkRow(block: block, categoryTitle: category.title)
                }
                // v10 (§1.5.3): computed from another app, read only – "Übernehmen" makes an own block of it.
                DerivedWorkRows(context: context, day: day, category: category)
                NewWorkRow(categoryKey: category.key, day: day)
            } header: {
                Text("Power-Hours heute")
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
                        .tag(item.code)
                }
            }
        }

        ForEach(groups, id: \.group) { group in
            Section {
                ForEach(group.measures) { measure in
                    if context.isExpense(measure) {
                        // K2: every spending on its own line, with what it was for; a tap changes one (R46).
                        ExpenseInputRow(measure: measure, context: context, day: day, editing: $editingExpense)
                        ForEach(context.expenseEntries(measure, on: day)) { expense in
                            ExpenseEntryRow(entry: expense, onEdit: { editingExpense = expense })
                        }
                        // v10: spending from another app ("aus Finn – in Finn ändern"), read only.
                        AppExpenseRows(context: context, measure: measure, day: day)
                    } else {
                        MeasureRow(measure: measure, context: context, day: day,
                                   healthSuggestion: healthSuggestion(for: measure),
                                   offersWorkButton: !workSection)
                    }
                }
            } header: {
                Text(group.group.label)
            }
        }

        if secondaryCount > 0 {
            Section {
                DisclosureGroup(isExpanded: $showsSecondary) {
                    ForEach(secondary) { item in
                        ItemMarkRow(item: item, context: context, day: day)
                            .tag(item.code)
                    }
                    ForEach(secondaryGroups, id: \.group) { group in
                        ForEach(group.measures) { measure in
                            MeasureRow(measure: measure, context: context, day: day, healthSuggestion: nil,
                                       offersWorkButton: !workSection)
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
                            .tag(item.code)
                    }
                } label: {
                    Label("Diese Woche schon erfüllt (\(doneThisWeek.count))", systemImage: "checkmark.circle")
                        .font(.subheadline)
                }
            }
        }

        Section {
            Button {
                goToNextPage()
            } label: {
                HStack {
                    Text(bottomNextTitle)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
            }
            Menu {
                Button("Punkt anlegen", systemImage: "checklist") {
                    app.sheet = .newItem(day.week, categoryKey: category.key)
                }
                Button("Messwert anlegen", systemImage: "ruler") {
                    app.sheet = .editMeasure(nil, day.week, categoryKey: category.key)
                }
                if category.goalKey == "3" {
                    Button("Power-Hours mit Ergebnis und nächstem Schritt", systemImage: "bolt") {
                        app.sheet = .work(WorkDraft(day: day, categoryKey: category.key))
                    }
                }
            } label: {
                Label("Neu in \(category.key)", systemImage: "plus")
                    .font(.subheadline)
            }
        }
    }

    /// Apple Health's value for a measurement without one of its own.
    private func healthSuggestion(for measure: MeasureDefinition) -> Double? {
        guard context.dayValue(measure, on: day) == nil else { return nil }
        return health.suggestion(code: measure.code, day: day)
    }

    // MARK: Paging (R74)

    private var nextPage: TodayPage {
        guard let next else { return .day }
        return .category(next.key)
    }

    /// "Weiter: 1.2 Titel" – on the last category "Weiter: Abschluss & Notizen".
    private var bottomNextTitle: String {
        guard let next else { return "Weiter: Abschluss & Notizen" }
        return "Weiter: \(next.key) \(next.title)"
    }

    /// The head's button once everything is recorded: "Weiter: 1.2" or "Zum Abschluss".
    private var headNextTitle: String {
        guard let next else { return "Zum Abschluss" }
        return "Weiter: \(next.key)"
    }

    private func goToNextPage() {
        let target: TodayPage = nextPage
        // v11 P5.12: the next page's list takes the keys 1–4 right away (Mac, iPad).
        if selectable { app.focusTodayPage = true }
        withAnimation(.snappy) { page = target }
    }

    // MARK: Keys (R35)

    /// 1 Erledigt/Gearbeitet · 2 Teilweise · 3 Nicht erledigt · 4 Entfällt/Nicht heute.
    static func keyMark(_ characters: String) -> Mark? {
        switch characters {
        case "1": return .done
        case "2": return .partial
        case "3": return .missed
        case "4": return .notApplicable
        default: return nil
        }
    }

    /// Marks the selected item with the key's mark (only one it allows), then selects the next open one.
    private func handleKey(_ characters: String) -> KeyPress.Result {
        guard selectable, let code = selectedItemCode, let mark = CategoryPage.keyMark(characters) else { return .ignored }
        let items: [PlanItem] = visibleItems()
        guard let index = items.firstIndex(where: { $0.code == code }) else { return .ignored }
        let item: PlanItem = items[index]
        guard context.options(item, on: day).contains(mark) else { return .ignored }
        app.setMark(mark, item: item, day: day)
        if let following = nextOpenItem(after: index, in: items) {
            selectedItemCode = following.code
        }
        return .handled
    }

    /// The next item without a mark after `index` (then from the top), skipping the one just marked.
    private func nextOpenItem(after index: Int, in items: [PlanItem]) -> PlanItem? {
        guard items.count > 1 else { return nil }
        for step in 1..<items.count {
            let candidate: PlanItem = items[(index + step) % items.count]
            let isOpen: Bool = context.mark(candidate, on: day) == nil && !context.options(candidate, on: day).isEmpty
            if isOpen { return candidate }
        }
        return nil
    }

    // MARK: Head (R38, R74)

    /// "3 von 5"; the interim score once everything is recorded.
    private func statusText(_ entry: CategoryDay) -> String {
        if entry.due == 0 { return "nichts fällig" }
        if entry.isComplete { return "\(entry.due) von \(entry.due) · \(Format.score(entry.score, outOf: false))" }
        return "\(entry.due - entry.blank) von \(entry.due)"
    }

    private func spokenStatus(_ entry: CategoryDay) -> String {
        if entry.due == 0 { return "Heute nichts zu bewerten" }
        if entry.isComplete { return "Alles erfasst, Zwischenstand \(Format.score(entry.score, outOf: false))" }
        return "\(entry.due - entry.blank) von \(entry.due) erfasst"
    }

    /// The goal and the category's details behind ⓘ.
    private var infoText: String {
        var lines: [String] = []
        if let goal = context.goal(of: category) { lines.append("Ziel \(goal.key) · \(goal.title)") }
        let details: String = category.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !details.isEmpty { lines.append(details) }
        return lines.joined(separator: "\n")
    }

    /// The category head in its goal's colour (R38): key and title, "3 von 5", a small ring, ⓘ for
    /// details, and "Alle …" – or, once everything is recorded, "Weiter: 1.2" / "Zum Abschluss" (R74).
    /// "Alle leeren" sits in the head's context menu. v11 P5.18 (KR2-9): a long title takes a second
    /// line instead of being cut ("Ernährung und Gewicht" whole).
    private func header(_ entry: CategoryDay, tickable: [PlanItem]) -> some View {
        let isComplete: Bool = entry.due > 0 && entry.isComplete
        let marked: [PlanItem] = tickable.filter { context.recordedMark($0, on: day) != nil }
        let info: String = infoText
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(category.key)  \(category.title)")
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                if entry.knockedOut || entry.overridden {
                    Image(systemName: entry.overridden ? "hand.raised.fill" : "exclamationmark.octagon.fill")
                        .font(.caption)
                        .accessibilityLabel(entry.overridden ? "Eigene Wertung" : "Null-Regel")
                }
                Text(statusText(entry))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityLabel(spokenStatus(entry))
                CategoryHeadRing(entry: entry)
                if !info.isEmpty {
                    Button {
                        withAnimation(.snappy) { showsInfo.toggle() }
                    } label: {
                        Image(systemName: showsInfo ? "info.circle.fill" : "info.circle")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Details zu \(category.title)")
                }
                if isComplete {
                    Button(action: goToNextPage) {
                        Text(headNextTitle)
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.22), in: .capsule)
                    }
                    .buttonStyle(.plain)
                } else if !tickable.isEmpty {
                    QuickAllMenu(items: tickable, day: day, context: context, scope: category.title, title: "Alle …",
                                 onTint: true, offersClear: false)
                        .frame(width: 34, height: 28)
                }
            }
            if showsInfo, !info.isEmpty {
                Text(info)
                    .font(.caption)
                    .opacity(0.9)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 48)
        .background(GoalPalette.gradient(goal: category.key), in: .rect(cornerRadius: 16, style: .continuous))
        .shadow(color: category.color.opacity(0.25), radius: 6, y: 3)
        .padding(.vertical, 2)
        .contextMenu {
            if !marked.isEmpty {
                Button("Alle leeren (\(marked.count))", systemImage: "circle.dashed", role: .destructive) {
                    app.setAll(nil, items: marked, day: day, scope: category.title)
                }
            }
        }
    }
}

/// The small ring in a category head (28 pt, R38): white on the goal's colour, a check once
/// everything is recorded.
private struct CategoryHeadRing: View {
    let entry: CategoryDay

    private var fill: Double { entry.due > 0 ? entry.fill : 0 }
    private var isComplete: Bool { entry.due > 0 && entry.isComplete }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.3), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: CGFloat(fill))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
            }
        }
        .frame(width: 28, height: 28)
        .animation(.snappy, value: entry.fill)
        .accessibilityHidden(true)
    }
}

// MARK: Items

/// One item with its marks as direct buttons – no cycling, no holding (U5.2, U18.2). At least
/// 640 pt wide (Mac, iPad) the buttons stand to the right of the title (R61).
struct ItemMarkRow: View {
    let item: PlanItem
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app
    @State private var confirmsDelete = false

    private var isProgress: Bool { item.schedule == .progress }

    var body: some View {
        let mark: Mark? = context.mark(item, on: day)
        let options: [Mark] = context.options(item, on: day)
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                details
                    .frame(minWidth: 0, idealWidth: 300, maxWidth: .infinity, alignment: .leading)
                marks(mark: mark, options: options, compact: true)
                    .frame(width: 300)
            }
            .frame(minWidth: 640)
            VStack(alignment: .leading, spacing: 8) {
                details
                marks(mark: mark, options: options, compact: false)
            }
        }
        .padding(.vertical, 2)
        .contextMenu { menu(mark: mark, options: options) }
        .weekItemDeleteDialog(item, isPresented: $confirmsDelete, app: app)
    }

    /// Title, kind, week progress and the mark's note.
    private var details: some View {
        let note: String = context.markNote(item, on: day)
        let derived: String? = context.derivedMarkLabel(item, on: day)
        return VStack(alignment: .leading, spacing: 4) {
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
            if let derived {
                // v10 (§1.5.3): the ✓ comes from a connected app while there is no own mark.
                DerivedMarkNote(label: derived)
            }
            if !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func marks(mark: Mark?, options: [Mark], compact: Bool) -> some View {
        if options.isEmpty {
            Label(emptyText, systemImage: "wand.and.stars")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: compact ? .trailing : .leading)
        } else {
            MarkBar(mark: mark, options: options, suggestion: context.suggestion(item, on: day),
                    isProgress: isProgress, compact: compact) { app.setMark($0, item: item, day: day) }
        }
    }

    private var emptyText: String {
        context.isDerived(item) ? "Automatisch aus dem Wochenziel" : "Zählt heute nicht"
    }

    /// R9: marks and "Leeren" only where marking is possible; automatic items open their value.
    /// R63: edit and delete right here.
    @ViewBuilder
    private func menu(mark: Mark?, options: [Mark]) -> some View {
        if !options.isEmpty {
            MarkMenu(current: mark, options: options) { app.setMark($0, item: item, day: day) }
            Divider()
        }
        if let valueSheet = MarkCell.valueSheet(for: item, context: context, day: day) {
            Button("Wert eintragen…", systemImage: "square.and.pencil") { app.sheet = valueSheet }
            Divider()
        }
        Button("Details und Notiz…", systemImage: "info.circle") { app.sheet = .item(item, day) }
        Button("Bearbeiten…", systemImage: "pencil") { app.sheet = .editItem(item) }
        if item.isSecondary {
            Button("Doch wichtig", systemImage: "star") { app.store.setSecondary(item, false) }
        } else {
            Button("Als Nebensache", systemImage: "square.stack") { app.store.setSecondary(item, true) }
        }
        Divider()
        Button("Löschen…", systemImage: "trash", role: .destructive) { confirmsDelete = true }
    }

    /// "2 von 3 diese Woche"; v8: "2 von 3 diese Woche · ½ krank" (what's missing counts half).
    private func quotaLine(_ quota: (done: Int, target: Int)) -> String {
        let base: String = "\(quota.done) von \(quota.target) diese Woche"
        guard quota.done < quota.target, context.quotaShare(item) > 1e-9 else { return base }
        return base + " · ½ " + context.excusedWord(context.excusedDayList)
    }

    /// R64: the short kind label, the week's quota and progress.
    @ViewBuilder
    private var meta: some View {
        let kind: String? = context.kindLabel(item)
        let quota = context.quotaProgress(item)
        let progress = context.progress(item)
        if kind != nil || quota != nil || progress != nil {
            HStack(spacing: 8) {
                KindBadge(text: kind)
                if let quota {
                    Text(quotaLine(quota))
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

/// Erledigt · Teilweise · Nicht erledigt · Entfällt as equal buttons. Tapping the selected one clears
/// it. A measurement's suggestion is outlined. Progress items: "Gearbeitet" / "Nicht heute" – the week
/// decides the result (U19). Once the row has an answer the other buttons turn grey but stay tappable
/// (R36). From accessibility text sizes on, the buttons stand 2 × 2 (R67).
struct MarkBar: View {
    let mark: Mark?
    let options: [Mark]
    var suggestion: Mark?
    var isProgress = false
    /// R61: flat buttons with symbol and word side by side, for the wide row.
    var compact = false
    let onSet: (Mark?) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    /// R67: 2 × 2 from AX1 on, so no word is cut off.
    private var usesGrid: Bool {
        typeSize >= .accessibility1 && options.count > 2
    }

    private var spacing: CGFloat { compact ? 4 : 6 }

    var body: some View {
        Group {
            if usesGrid {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: spacing), GridItem(.flexible(), spacing: spacing)],
                          spacing: spacing) {
                    buttons
                }
            } else {
                HStack(spacing: spacing) {
                    buttons
                }
            }
        }
        .sensoryFeedback(.selection, trigger: mark)
    }

    private var buttons: some View {
        ForEach(options, id: \.self) { option in
            MarkOptionButton(option: option, selected: mark == option, answered: mark != nil,
                             suggested: suggestion == option && mark == nil,
                             isProgress: isProgress, compact: compact) {
                onSet(mark == option ? nil : option)
            }
        }
    }
}

/// R35: where 1–4 mark the selected item (Mac, iPad), the buttons name their key in the tooltip.
private struct MarkKeyHintsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var markKeyHints: Bool {
        get { self[MarkKeyHintsKey.self] }
        set { self[MarkKeyHintsKey.self] = newValue }
    }
}

/// One choice: symbol and word (W2.2 – it says what tapping does). Selected = filled, a
/// measurement's suggestion = dashed outline, answered rows grey (R36). Tapping the selected one
/// clears it.
private struct MarkOptionButton: View {
    let option: Mark
    let selected: Bool
    let answered: Bool
    let suggested: Bool
    let isProgress: Bool
    let compact: Bool
    let action: () -> Void
    @Environment(\.markKeyHints) private var showsKeyHints
    @Environment(\.dynamicTypeSize) private var typeSize
    /// R67: sizes grow with the system text size, identical at the standard size.
    @ScaledMetric(relativeTo: .body) private var regularHeight: CGFloat = 46
    @ScaledMetric(relativeTo: .body) private var regularSymbol: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var regularWord: CGFloat = 10.5
    #if os(macOS)
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 30
    #else
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 34
    #endif
    @ScaledMetric(relativeTo: .body) private var compactSymbol: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var compactWord: CGFloat = 11

    private var tint: Color { Optional(option).color }

    /// R44: the word and symbol in the darker text colour of the mark.
    private var textTint: Color { Optional(option).textColor }

    /// R36: another button of this row is chosen.
    private var isMuted: Bool { answered && !selected }

    private var cornerRadius: CGFloat { compact ? 9 : 12 }

    /// R61: 34 pt in the wide row (a little flatter on the Mac), else 46 pt.
    private var height: CGFloat {
        compact ? compactHeight : regularHeight
    }

    /// R67: two lines for the word at accessibility sizes (2 × 2), else one.
    private var wordLines: Int {
        typeSize >= .accessibility1 ? 2 : 1
    }

    private var foreground: Color {
        if selected { return Color.white }
        return isMuted ? Color.secondary : textTint
    }

    private var fillStyle: AnyShapeStyle {
        if selected { return AnyShapeStyle(tint.gradient) }
        if isMuted { return AnyShapeStyle(Color.secondary.opacity(0.08)) }
        return AnyShapeStyle(tint.opacity(0.1))
    }

    private var hint: String {
        if selected { return "Nochmal tippen leert die Bewertung" }
        return suggested ? "Vorschlag aus dem Messwert" : ""
    }

    var body: some View {
        Button(action: action) {
            face
                .frame(maxWidth: .infinity, minHeight: height)
                .foregroundStyle(foreground)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillStyle)
                }
                .overlay {
                    if suggested {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(tint, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .scaleEffect(selected ? 1.0 : 0.97)
                .animation(.snappy(duration: 0.18), value: selected)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(word)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(hint)
    }

    @ViewBuilder
    private var face: some View {
        if compact {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: compactSymbol, weight: .bold))
                Text(word)
                    .font(.system(size: compactWord, weight: .semibold))
                    .lineLimit(wordLines)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 4)
        } else {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: regularSymbol, weight: .bold))
                Text(word)
                    .font(.system(size: regularWord, weight: .semibold))
                    .lineLimit(wordLines)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 2)
        }
    }

    private var symbol: String {
        switch option {
        case .done: return "checkmark"
        case .partial: return "circle.lefthalf.filled"
        case .missed: return "xmark"
        case .notApplicable: return isProgress ? "moon.zzz" : "minus"
        }
    }

    /// R43: "Erledigt" · "Teilweise" · "Nicht erledigt" · "Entfällt"; progress items "Gearbeitet" ·
    /// "Nicht heute".
    private var word: String {
        option.label(progress: isProgress)
    }

    /// The key that sets this mark (R35).
    private var keyNumber: Int {
        switch option {
        case .done: return 1
        case .partial: return 2
        case .missed: return 3
        case .notApplicable: return 4
        }
    }

    /// "Erledigt (1)" where the keys work, else the word.
    private var helpText: String {
        showsKeyHints ? "\(word) (\(keyNumber))" : word
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
    /// R37: false where the power-hours line sits right on the page – no second "Erfassen".
    var offersWorkButton = true

    @Environment(AppModel.self) private var app

    private var record: MeasureRecord? { measure.record }
    private var value: Double? { context.dayValue(measure, on: day) }
    private var isWeekly: Bool { record?.period == .week }

    /// H1: the value comes from Apple Health on the iPhone – nothing to type in here.
    // HEALTHSHARE: not on a day the iPhone shares (`isHealthElsewhere(_:on:)`, §1.4.7).
    private var isHealthElsewhere: Bool { value == nil && context.isHealthElsewhere(measure, on: day) }
    // HEALTHSHARE: the day's value is the one the iPhone shares – shown, never an input (§1.4.8).
    private var sharedValue: Double? { context.sharedHealthValue(measure, on: day) }
    // HEALTHSHARE: read on the iPhone, taken over nowhere ("Health am iPhone: … – dort übernehmen").
    private var phoneSuggestion: Double? { context.sharedHealthSuggestion(measure, on: day) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
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
                Spacer(minLength: 4)
                Button {
                    app.sheet = .measure(code: measure.code, day: day)
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Verlauf und Details zu \(measure.title)")
            }
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
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
                    // HEALTHSHARE: only read – the iPhone takes it over (not next to this device's own suggestion).
                    if let phoneSuggestion, healthSuggestion == nil {
                        Text(context.healthShare.suggestionText(phoneSuggestion, unit: measure.unit))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 6)
                // HEALTHSHARE: a shared value is shown with "Eigenen Wert eintragen…", never typed over (§1.4.8).
                if let sharedValue {
                    SharedHealthInput(measure: measure, day: day, value: sharedValue, caption: context.healthShare.sharedCaption)
                } else if !isHealthElsewhere {
                    MeasureInput(measure: measure, context: context, day: day, offersWorkButton: offersWorkButton)
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu { MeasureMenu(measure: measure, context: context, day: day) }
    }

    private var subtitle: String {
        if isHealthElsewhere { return WeekContext.healthElsewhereHint }
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
        // v10: a value from a connected app or the reading list says where it comes from.
        // HEALTHSHARE: so does a value the iPhone shares ("aus Health am iPhone").
        if sharedValue != nil {
            parts.append(context.healthShare.sharedCaption)
        } else if let source = context.valueSource(measure, on: day) {
            parts.append(ConnectedAppsTexts.fromSource(source))
        } else if record?.source.listKind != nil {
            parts.append("aus der Leseliste")
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

    /// v10: the day's value is an own one – not the reading list's, not only a connected app's.
    private var hasOwnValue: Bool {
        // HEALTHSHARE: nor the value the iPhone shares.
        measure.record?.source.listKind == nil && context.valueSource(measure, on: day) == nil
            && context.sharedHealthValue(measure, on: day) == nil
    }

    var body: some View {
        Button("Verlauf und Einträge…", systemImage: "chart.bar") { app.sheet = .measure(code: measure.code, day: day) }
        Button("Messwert bearbeiten…", systemImage: "pencil") { app.sheet = .editMeasure(measure, day.week, categoryKey: measure.categoryKey) }
        if measure.isSecondary {
            Button("Doch wichtig", systemImage: "star") { app.store.setSecondary(measure, false) }
        } else {
            Button("Als Nebensache", systemImage: "square.stack") { app.store.setSecondary(measure, true) }
        }
        // R2: spendings are deleted one by one, work comes from power-hours – neither is cleared here.
        if context.dayValue(measure, on: day) != nil, measure.record?.isWork != true, !context.isExpense(measure), hasOwnValue {
            Button("Wert leeren", systemImage: "xmark.circle") { app.setValue(nil, for: measure, day: day) }
        }
        // v10: the reading list's pages are entered in "Lesen".
        if measure.record?.source.listKind != nil {
            Button("Lesen…", systemImage: "book") { app.sheet = .reading(day, itemID: nil) }
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
    /// R37: false where the power-hours line ("Menge · Wofür · +") sits right below – then work
    /// shows only its value.
    var offersWorkButton = true

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
            // K1: no bare + / − – power-hours are always entered with what they were for.
            HStack(spacing: 8) {
                Text(value.map { Format.powerHours($0) } ?? "0 PH")
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .monospacedDigit()
                if offersWorkButton {
                    Button {
                        app.sheet = .work(WorkDraft(day: day, categoryKey: workCategory))
                    } label: {
                        Label("Erfassen", systemImage: "plus")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .foregroundStyle(.white)
                            .background(Color.accentFill.gradient, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Power-Hours für \(measure.title) mit Beschreibung erfassen")
                }
            }
        } else if record?.source.listKind != nil {
            // v10 (§1.3.3): the pages are entered once, in the reading list.
            ReadingMeasureInput(measure: measure, context: context, day: day)
        } else if context.isExpense(measure) {
            Button {
                app.sheet = .expenses(day)
            } label: {
                Label(value.map { Format.euro($0) } ?? "Ausgabe", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .foregroundStyle(.white)
                    .background(GoalPalette.color(goal: "8").gradient, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ausgabe mit Betrag und Zweck erfassen")
        } else if record?.isTime ?? false {
            timeControl
        } else if record?.isText ?? false {
            textControl
        } else {
            stepper(step: Units.step(measure.unit), unitLabel: nil) { app.setValue($0, for: measure, day: day, toast: false) }
        }
    }

    // MARK: Number / PH

    /// W2.1: the buttons say what they do ("− 0,5" / "+ 0,5"), the field shows the unit, and the
    /// quick amounts sit behind a visible "…" instead of a hidden long press.
    private func stepper(step: Double, unitLabel: String?, set: @escaping (Double?) -> Void) -> some View {
        let unit: String = unitLabel ?? Units.display(measure.unit)
        return HStack(spacing: 5) {
            StepButton(title: "− \(Format.number(step))", prominent: false) {
                change(by: -step, set: set)
            }
            .disabled(currentAmount() <= 0)
            .accessibilityLabel("\(measure.title) minus \(Format.number(step)) \(unit)")
            HStack(spacing: 3) {
                TextField("–", text: $text)
                    .multilineTextAlignment(.trailing)
                    .font(.system(.callout, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .decimalKeyboard()
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit { commit(set) }
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit(set) } }
                    // R31: the number pad has no Return – "Fertig" above it saves right away.
                    .keypadButton("Fertig", isActive: focused) {
                        commit(set)
                        focused = false
                    }
                    // v11 P5.6: what the field is – VoiceOver says itself that it can be edited.
                    .accessibilityLabel(unit.isEmpty ? measure.title : "\(measure.title) in \(unit)")
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 74)
            .padding(.vertical, 7)
            .padding(.horizontal, 6)
            .background(Color.secondary.opacity(focused ? 0.18 : 0.09), in: .rect(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(focused ? Brand.accent : Color.clear, lineWidth: 1.5)
            }
            StepButton(title: "+ \(Format.number(step))", prominent: true) {
                change(by: step, set: set)
            }
            .accessibilityLabel("\(measure.title) plus \(Format.number(step)) \(unit)")
            Menu {
                Section("Dazuzählen") {
                    ForEach([1.0, 2.0, 5.0, 10.0].map { $0 * step }, id: \.self) { amount in
                        Button("+ \(Format.number(amount)) \(unit)") { change(by: amount, set: set) }
                    }
                }
                if value != nil {
                    Button("Leeren", systemImage: "arrow.counterclockwise", role: .destructive) {
                        text = ""
                        set(nil)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout.weight(.bold))
                    .frame(width: 30, height: 34)
                    .foregroundStyle(.secondary)
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .accessibilityLabel("Weitere Mengen für \(measure.title)")
        }
        .onAppear { text = value.map { Format.number($0) } ?? "" }
        .onChange(of: value) { _, newValue in
            if !focused { text = newValue.map { Format.number($0) } ?? "" }
        }
    }

    /// The typed text as a value (to the cent); nil when empty or unreadable.
    private func typedValue() -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Format.parse(trimmed).map { ($0 * 100).rounded() / 100 }
    }

    /// What the steps start from: the typed value while typing, else the saved one (R31).
    private func currentAmount() -> Double {
        if focused, let typed = typedValue() { return typed }
        return value ?? 0
    }

    /// "+ 0,5" / "− 0,5" / quick amounts: while typing, the typed value is saved first and the step
    /// counts from it ("4,5" typed, "+ 0,5" → 5) (R31).
    private func change(by delta: Double, set: (Double?) -> Void) {
        let base: Double = currentAmount()
        if focused { commit(set) }
        let result: Double = max(0, ((base + delta) * 100).rounded() / 100)
        text = Format.number(result)
        set(result)
    }

    /// v11 P5.19 (KR1-7): compared with the value as the field shows it, not the exact one – clicking into a field
    /// with 7,316 h and out again saves nothing (an own 7,32 would hide a value from Health for good). An emptied
    /// field still clears the value.
    private func commit(_ set: (Double?) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parsed: Double? = typedValue()
        guard trimmed.isEmpty || parsed != nil else {
            text = value.map { Format.number($0) } ?? ""
            return
        }
        let shown: Double? = value.flatMap { Format.parse(Format.number($0)) }
        guard parsed != shown else { return }
        set(parsed)
    }

    // MARK: Time (V8: no "now" – usually entered the next day)

    /// Minutes since midnight of a picked time, whole minutes (R29).
    private static func pickedMinutes(_ date: Date) -> Double {
        DayKey.minutes(of: date).rounded(.down)
    }

    @ViewBuilder
    private var timeControl: some View {
        if let value {
            DatePicker("", selection: Binding(
                get: { day.date(minutes: value) },
                set: { app.setValue(MeasureInput.pickedMinutes($0), for: measure, day: day, toast: false) }
            ), displayedComponents: .hourAndMinute)
            .labelsHidden()
            .thaliaDateLocale()
        } else {
            HStack(spacing: 6) {
                DatePicker("", selection: Binding(
                    get: { draftTime },
                    set: { newValue in
                        draftTime = newValue
                        app.setValue(MeasureInput.pickedMinutes(newValue), for: measure, day: day, toast: false)
                    }
                ), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .thaliaDateLocale()
                .opacity(0.45)
                .accessibilityLabel("\(measure.title): Uhrzeit wählen")
                Button {
                    app.setValue(MeasureInput.pickedMinutes(draftTime), for: measure, day: day)
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
            .onAppear { draftTime = day.date(minutes: defaultMinutes) }
        }
    }

    /// The target time if there is one ("<=23:00" → 23:00), else 23:00 – a sensible starting point (R29).
    private var defaultMinutes: Double {
        record?.defaultClockMinutes ?? 23 * 60
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
}

/// "− 0,5" / "+ 0,5": the step is written on the button.
struct StepButton: View {
    let title: String
    let prominent: Bool
    let action: () -> Void
    /// R67: grows with the system text size; identical at the standard size.
    @ScaledMetric(relativeTo: .footnote) private var fontSize: CGFloat = 12.5
    @ScaledMetric(relativeTo: .footnote) private var minWidth: CGFloat = 42
    @ScaledMetric(relativeTo: .footnote) private var minHeight: CGFloat = 34

    private var fill: AnyShapeStyle {
        prominent ? AnyShapeStyle(Color.accentFill.gradient) : AnyShapeStyle(Color.secondary.opacity(0.14))
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: minWidth, minHeight: minHeight)
                .padding(.horizontal, 4)
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .background(fill, in: .rect(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Weekly goals (V2)

/// A weekly target: bar for the week with an even-pace marker (R47: work doesn't plan on free
/// days), what today added and, except for work, the value entered right here. Work is read-only –
/// the power-hours line follows right below (R37). The %-label explains how it counts.
struct WeeklyGoalRow: View {
    let goal: WeeklyGoal
    let context: WeekContext
    let day: DayKey
    @State private var showsExplanation = false

    private var record: MeasureRecord? { goal.measure.record }
    private var isWork: Bool { record?.isWork == true }

    var body: some View {
        let weekValue: Double = context.weekValue(goal.measure) ?? 0
        let today: Double = context.dayValue(goal.measure, on: day) ?? 0
        let target: Target? = effectiveTarget
        let targetValue: Double = target?.scaleMax ?? 0
        let isLimit: Bool = target?.isLimit ?? false
        let fraction: Double = targetValue > 0 ? min(1, weekValue / targetValue) : 0
        // A limit ("≤ 6") is never "erreicht" – it is kept or exceeded (`status`). v11 P1.16: "erreicht" from the target
        // itself, like the report – a range or "= 3" compares both ways.
        let reached: Bool = !isLimit && targetValue > 0 && target?.isMet(weekValue) == true
        let pace: Pace? = context.pace(for: goal.measure)
        let status: PaceStatus? = paceStatus(pace, target: target, weekValue: weekValue)
        let hint: String? = scaledHint
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(goal.item?.title ?? goal.measure.title)
                    .font(.body.weight(.semibold))
                Spacer(minLength: 6)
                percentButton(fraction: fraction, reached: reached, pace: pace, status: status)
            }
            GoalBar(fraction: fraction, expected: expectedFraction(pace, target: targetValue), reached: reached,
                    tint: GoalPalette.color(category: goal.measure.categoryKey))
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Text(amountsText(weekValue, target: target))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                    // v11 P1.16: the short word next to "x von y" ("hinter dem Plan", "noch offen") – the chip says "erreicht".
                    if let status, !reached, status != .reached {
                        Text(status.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StatusTint(status).color)
                    }
                }
                Text(todayText(today))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            if let hint {
                // v8: "4,8 statt 8 PH – 2 Tage krank".
                Label("Ziel \(hint)", systemImage: "calendar.badge.minus")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            // v10 (§1.2.4): "zählt für Ziel 5 · Bücher 3/10".
            CountsForLines(measure: goal.measure, context: context)
            if !isWork {
                HStack {
                    Text("Heute eintragen")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    // HEALTHSHARE: a value the iPhone shares is shown with "Eigenen Wert eintragen…", never typed over
                    // (§1.4.8) – as in `MeasureRow`.
                    if let shared = context.sharedHealthValue(goal.measure, on: day) {
                        SharedHealthInput(measure: goal.measure, day: day, value: shared, caption: context.healthShare.sharedCaption)
                    } else {
                        MeasureInput(measure: goal.measure, context: context, day: day)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu { MeasureMenu(measure: goal.measure, context: context, day: day) }
    }

    /// "62 %" / "erreicht" – a tap explains the bar and how the target counts. v11 P1.16: coloured by the status
    /// alone (`StatusTint`) – orange "hinter dem Plan" / "noch offen", red "nicht erreicht"; a limit says "im Rahmen" /
    /// "überschritten".
    private func percentButton(fraction: Double, reached: Bool, pace: Pace?, status: PaceStatus?) -> some View {
        let tint: Color = chipTint(status: status, reached: reached)
        return Button {
            showsExplanation = true
        } label: {
            Text(percentLabel(fraction: fraction, reached: reached, status: status))
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(reached ? Color.white : tint)
                .background(reached ? tint : tint.opacity(0.14), in: .capsule)
        }
        .buttonStyle(.borderless)
        .accessibilityHint("Erklärt, wie das Wochenziel zählt")
        .popover(isPresented: $showsExplanation) {
            explanationView(reached: reached, pace: pace)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func explanationView(reached: Bool, pace: Pace?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(explanation(reached: reached), systemImage: goal.item == nil ? "chart.bar" : "wand.and.stars")
            if let legend = paceLegend(pace, reached: reached) {
                // W3: the grey tick explained.
                Label(legend, systemImage: "line.diagonal")
            }
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 320, alignment: .leading)
        .padding()
    }

    private var unit: String { isWork ? "PH" : goal.measure.unit }

    /// v8: the target as it counts this week – scaled for sick and holiday days.
    private var effectiveTarget: Target? {
        guard let record else { return nil }
        return context.effectiveTarget(record)
    }

    /// v11 P1.16: where the weekly target stands, by the report's rule (`PaceStatus.of`) – a limit "im Rahmen" /
    /// "überschritten", met "erreicht", else the pace's status ("im Plan", "hinter dem Plan", "noch offen", "nicht
    /// erreicht"); nil without a target that counts.
    private func paceStatus(_ pace: Pace?, target: Target?, weekValue: Double) -> PaceStatus? {
        guard let target, target.scaleMax > 0 else { return nil }
        if let pace { return PaceStatus.of(target: target, value: weekValue, pace: pace) }
        if target.isLimit { return PaceStatus.limit(isMet: target.isMet(weekValue)) }
        return target.isMet(weekValue) ? .reached : nil
    }

    /// The chip's colour: green once reached, grey when the target doesn't count, else the status colour.
    private func chipTint(status: PaceStatus?, reached: Bool) -> Color {
        if reached { return StatusTint(kind: .reached).color }
        if let record, record.target != nil, context.targetShare(record) <= 1e-9 { return .secondary }
        guard let status else { return Brand.accent }
        return StatusTint(status).color
    }

    /// v8: "4,8 statt 8 PH – 2 Tage krank" when sick or holiday days scale the target; "zählt nicht
    /// – 5 Tage krank" when none of its days counts.
    private var scaledHint: String? {
        context.weeklyTargetHint(code: goal.measure.code)
    }

    /// "62 %" · "erreicht"; v8: "zählt nicht" when every day of the target is a sick or holiday day; v11: a limit
    /// "im Rahmen" / "überschritten".
    private func percentLabel(fraction: Double, reached: Bool, status: PaceStatus?) -> String {
        if reached { return "erreicht" }
        if let record, record.target != nil, context.targetShare(record) <= 1e-9 { return "zählt nicht" }
        if let status, status == .withinLimit || status == .overLimit { return status.label }
        return "\(percent(fraction)) %"
    }

    /// "3 von 8 PH", "150 von 86 Stk." (v11 P1.7: rounded for the screen, the target in the direction of its
    /// comparison – `Format.amount`); v8: "3 PH in der Woche" when the target doesn't count this week (share 0).
    private func amountsText(_ weekValue: Double, target: Target?) -> String {
        guard let target, target.scaleMax > 0 else { return "\(amount(weekValue)) in der Woche" }
        return "\(Format.amount(weekValue, unit: unit)) von \(Format.amount(target: target, unit: unit))\(unitSuffix)"
    }

    /// The unit after "x von y": " PH", " Stk.", " €"; nothing for times.
    private var unitSuffix: String {
        if Units.isTime(unit) { return "" }
        if Units.normalized(unit) == "€" { return " €" }
        let shown: String = Units.display(unit)
        return shown.isEmpty ? "" : " " + shown
    }

    private func amount(_ value: Double) -> String {
        Format.measure(value, unit: unit)
    }

    /// "heute +2 PH" / "heute noch nichts"; v11 P5.7: work on a sick or holiday day "heute krank", on a free day
    /// "heute frei".
    private func todayText(_ today: Double) -> String {
        if today > 0 { return "heute +\(amount(today))" }
        if isWork {
            if context.isExcused(day) { return "heute \(context.excusedWord([day]))" }
            if !context.applies(goal.measure, on: day) { return "heute frei" }
        }
        return "heute noch nichts"
    }

    /// Where an even pace stands today, 0…1 of the bar.
    private func expectedFraction(_ pace: Pace?, target: Double) -> Double? {
        guard let pace, target > 0 else { return nil }
        return min(1, pace.expected / target)
    }

    private func paceLegend(_ pace: Pace?, reached: Bool) -> String? {
        guard let pace, !reached, pace.expected > 0 else { return nil }
        return "Strich = Soll bis heute: \(amount(pace.expected)) (gleichmäßig über die geplanten Tage)"
    }

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
    var tint: Color = Brand.accent

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(reached ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.65), tint],
                                                                                                       startPoint: .leading, endPoint: .trailing)))
                    .frame(width: max(8, geometry.size.width * fraction))
                if let expected, !reached, expected > 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: 2, height: 18)
                        .offset(x: geometry.size.width * expected - 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(height: 12)
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

    /// "Alles erfasst – bereit zum Abschließen." · "3 Punkte sind noch offen."
    private func openText(_ overall: DayOverall?) -> String {
        // v8: nothing is due on a sick or holiday day; closing it is optional.
        if context.isExcused(day) { return "\(context.excusedName(day)) – der Tag zählt nicht. Abschließen ist nicht nötig." }
        guard let overall else { return "" }
        if overall.blank == 0 { return "Alles erfasst – bereit zum Abschließen." }
        let count: String = overall.blank == 1 ? "1 Punkt ist" : "\(overall.blank) Punkte sind"
        return "\(count) noch offen."
    }

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
                        Text(openText(overall))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        app.sheet = .closeDay(day)
                    } label: {
                        Label(closed ? "Abschluss ansehen" : "Tag abschließen", systemImage: closed ? "checkmark.seal" : "moon.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .thaliaPrimaryAction()
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

        // v10 (§1.5.3): power-hours from another app without a category – shown, counted nowhere.
        UnassignedWorkSection(context: context, day: day)

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
                // v11 P5.6: VoiceOver hears a button that opens the note.
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Öffnet die Notiz")
                .swipeActions(edge: .trailing) {
                    Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([note]) }
                }
                // v11 P5.13: with the mouse, too – like every other swipe row.
                .contextMenu {
                    Button("Bearbeiten…", systemImage: "pencil") { app.sheet = .note(note, day) }
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
            Menu {
                Section("Menge") {
                    ForEach(PowerHour.quick, id: \.self) { value in
                        Button(Format.powerHours(value)) { app.store.setPowerHours(block, value) }
                    }
                }
                Button("+ 0,25 PH", systemImage: "plus") { app.store.setPowerHours(block, block.hours + 0.25) }
                Button("− 0,25 PH", systemImage: "minus") { app.store.setPowerHours(block, block.hours - 0.25) }
                    .disabled(block.hours <= 0.25)
            } label: {
                VStack(spacing: 0) {
                    Text(Format.number(block.hours))
                        .font(.system(.headline, design: .rounded))
                        .monospacedDigit()
                    Text("PH ▾")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 48, height: 40)
                .background(GoalPalette.color(category: block.categoryKey).opacity(0.12), in: .rect(cornerRadius: 9, style: .continuous))
            }
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .accessibilityLabel("Menge \(Format.powerHours(block.hours)) ändern")
            VStack(alignment: .leading, spacing: 2) {
                TextField(block.task.isEmpty ? "Beschreibung fehlt – woran?" : "Wofür?", text: $task)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commitTask)
                    .onChange(of: focused) { _, isFocused in if !isFocused { commitTask() } }
                HStack(spacing: 6) {
                    KeyBadge(key: block.categoryKey)
                    Text(categoryTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if block.task.isEmpty {
                        Label("Beschreibung fehlt", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .onAppear { task = block.task }
        // Changes from elsewhere (sheet, other device) show up while the field isn't being edited.
        .onChange(of: block.task) { _, newValue in
            if !focused { task = newValue }
        }
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

    /// R21/K1: an emptied field puts the old description back – power-hours always say what for.
    private func commitTask() {
        if !app.store.setTask(block, task) {
            task = block.task
        }
    }
}

/// A new entry in one line: amount, description (with suggestions), add (V10). The suggestions are
/// loaded once (on appearing and when typing starts); typing only filters them (R32).
struct NewWorkRow: View {
    let categoryKey: String
    let day: DayKey
    @Environment(AppModel.self) private var app
    @State private var powerHours: Double = 1
    @State private var task = ""
    @State private var suggestions: [String] = []
    @FocusState private var focused: Bool

    var body: some View {
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
                TextField("Wofür? (Pflicht)", text: $task)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(canAdd ? Brand.accent : Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel("Power-Hours erfassen")
                .accessibilityHint(canAdd ? "" : "Erst angeben, woran du gearbeitet hast")
            }
            if focused || !task.isEmpty {
                SuggestionChips(suggestions: suggestions, typed: task, selected: task, limit: 4) { suggestion in
                    task = suggestion
                }
            }
        }
        .padding(.vertical, 2)
        .onAppear(perform: loadSuggestions)
        .onChange(of: focused) { _, isFocused in
            if isFocused { loadSuggestions() }
        }
    }

    private func loadSuggestions() {
        suggestions = app.store.workSuggestions(categoryKey: categoryKey)
    }

    private var canAdd: Bool { !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func add() {
        guard canAdd else { return }
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
    /// White on a coloured head.
    var onTint = false
    /// The category head keeps "Alle leeren" in its context menu instead (R74).
    var offersClear = true
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
            if offersClear {
                Button("Alle leeren (\(marked.count))", systemImage: "circle.dashed", role: .destructive) {
                    app.setAll(nil, items: marked, day: day, scope: scope)
                }
                .disabled(marked.isEmpty)
            }
        } label: {
            if onTint {
                // A small fixed capsule in the one-line category head (R38): the menu label grew to
                // a tall pill and pushed the category title out (CI run 21).
                Image(systemName: "checklist")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 28)
                    .background(Color.white.opacity(0.22), in: .capsule)
            } else if let title {
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

/// K2: a spending in one line – amount, what for (required), add. Suggestions from the last months,
/// loaded once (R32); a valid amount plus a tap on one saves right away. With `editing` set (a tap
/// on a spending, R46) the fields hold that spending and "Sichern" changes it.
struct ExpenseInputRow: View {
    let measure: MeasureDefinition
    let context: WeekContext
    let day: DayKey
    @Binding var editing: MeasureEntry?
    @Environment(AppModel.self) private var app
    @State private var amount = ""
    @State private var what = ""
    @State private var suggestions: [String] = []
    @FocusState private var focus: Field?

    private enum Field: Hashable { case amount, what }

    init(measure: MeasureDefinition, context: WeekContext, day: DayKey, editing: Binding<MeasureEntry?>) {
        self.measure = measure
        self.context = context
        self.day = day
        self._editing = editing
    }

    /// The spending being changed, if it belongs to this measurement.
    private var editedEntry: MeasureEntry? {
        guard let entry = editing, entry.code == measure.code else { return nil }
        return entry
    }

    private var parsedAmount: Double? {
        guard let value = Format.parse(amount), value > 0, value.isFinite else { return nil }
        return value
    }

    private var canAdd: Bool {
        parsedAmount != nil && !what.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var plusColor: Color {
        canAdd ? GoalPalette.color(goal: "8") : Color.secondary.opacity(0.5)
    }

    var body: some View {
        let total: Double = context.dayValue(measure, on: day) ?? 0
        let isEditing: Bool = editedEntry != nil
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(measure.title)
                    .font(.body.weight(.medium))
                Spacer(minLength: 6)
                Text("heute \(Format.euro(total))")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Button {
                    app.sheet = .expenses(day)
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Alle Ausgaben der Woche")
            }
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    TextField("Betrag", text: $amount)
                        .multilineTextAlignment(.trailing)
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .decimalKeyboard()
                        .focused($focus, equals: .amount)
                        .submitLabel(.next)
                        .onSubmit { focus = .what }
                        // R31: the number pad has no Return – "Weiter" goes on to "Wofür".
                        .keypadButton("Weiter", isActive: focus == .amount) { focus = .what }
                    Text("€")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 92)
                .padding(.vertical, 7)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.09), in: .rect(cornerRadius: 9, style: .continuous))
                TextField("Wofür? (Pflicht)", text: $what)
                    .focused($focus, equals: .what)
                    .submitLabel(.done)
                    .onSubmit(submit)
                    .keypadButton("Fertig", isActive: focus == .what) { submit() }
                    .padding(.vertical, 7)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.09), in: .rect(cornerRadius: 9, style: .continuous))
                if !isEditing {
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(plusColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                    .accessibilityLabel("Ausgabe erfassen")
                    .accessibilityHint(canAdd ? "" : "Erst Betrag und Wofür angeben")
                }
            }
            if isEditing {
                HStack(spacing: 10) {
                    Label("Ausgabe ändern", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    Button("Abbrechen", action: cancelEdit)
                        .font(.caption)
                        .buttonStyle(.borderless)
                    Button("Sichern", action: save)
                        .font(.callout.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentFill)
                        .controlSize(.small)
                        .disabled(!canAdd)
                }
            }
            if focus != nil {
                SuggestionChips(suggestions: suggestions, typed: what, selected: what, onPick: pick)
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            loadSuggestions()
            if editedEntry != nil { fillFromEditing() }
        }
        .onChange(of: focus) { previous, current in
            if previous == nil && current != nil { loadSuggestions() }
        }
        .onChange(of: editedEntry?.uuid) { _, _ in
            fillFromEditing()
        }
    }

    /// R32: once per appearance and when typing starts – never per keystroke.
    private func loadSuggestions() {
        suggestions = app.store.expenseSuggestions(code: measure.code, through: day)
    }

    /// A tap on a suggestion: with a valid amount the spending is saved at once (R32).
    private func pick(_ suggestion: String) {
        what = suggestion
        if editedEntry == nil, canAdd {
            add()
        } else if parsedAmount == nil {
            focus = .amount
        }
    }

    private func submit() {
        if editedEntry != nil {
            save()
        } else {
            add()
        }
    }

    private func add() {
        guard canAdd, let value = parsedAmount else { return }
        app.addExpense(value, what: what, measure: measure, day: day)
        amount = ""
        what = ""
        focus = .amount
    }

    /// R46: the spending being edited gets amount and "Wofür"; Undo in the toast.
    private func save() {
        guard canAdd, let value = parsedAmount, let entry = editedEntry else { return }
        let entryDay: DayKey = DayKey(entry.dayKey) ?? day
        app.updateExpense(entry, amount: value, what: what, day: entryDay)
        editing = nil
        amount = ""
        what = ""
        focus = nil
    }

    private func cancelEdit() {
        editing = nil
        amount = ""
        what = ""
        focus = nil
    }

    /// The fields take the spending to change; without one they are emptied.
    private func fillFromEditing() {
        guard let entry = editedEntry else {
            amount = ""
            what = ""
            return
        }
        amount = Format.number(entry.value ?? 0, decimals: 2)
        what = entry.note
        focus = .amount
    }
}

/// One spending of the day: what for and how much; a tap or "Bearbeiten" changes it (R46), swipe or
/// the context menu deletes it.
struct ExpenseEntryRow: View {
    let entry: MeasureEntry
    var onEdit: (() -> Void)?
    @Environment(AppModel.self) private var app

    init(entry: MeasureEntry, onEdit: (() -> Void)? = nil) {
        self.entry = entry
        self.onEdit = onEdit
    }

    private var purpose: String {
        entry.note.isEmpty ? "ohne Angabe" : entry.note
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "eurosign.circle.fill")
                .foregroundStyle(GoalPalette.color(goal: "8"))
            VStack(alignment: .leading, spacing: 1) {
                Text(purpose)
                    .foregroundStyle(entry.note.isEmpty ? Color.orange : Color.primary)
                Text(entry.recordedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Text(Format.euro(entry.value ?? 0))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.leading, 8)
        .contentShape(.rect)
        .onTapGesture {
            onEdit?()
        }
        // v11 P5.6: one element; a button where a tap changes the spending.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(onEdit == nil ? [] : .isButton)
        .accessibilityHint(onEdit == nil ? "" : "Tippen zum Bearbeiten")
        .swipeActions(edge: .trailing) {
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([entry]) }
        }
        .contextMenu {
            if let onEdit {
                Button("Bearbeiten", systemImage: "pencil", action: onEdit)
            }
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([entry]) }
        }
    }
}

// MARK: Conditional items (U12.9)

/// "Gab es heute …?" – the situations that happened get marked, the rest becomes "Entfällt". Switching a
/// situation off changes nothing until "Fertig" (R25); "Später" closes without changes.
struct ConditionalsSheet: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var occurred: Set<String> = []
    /// Situations switched off here; their marks are cleared only with "Fertig" (R25).
    @State private var turnedOff: Set<String> = []

    var body: some View {
        NavigationStack {
            WeekReader(week: day.week, today: app.today) { context in
                let items: [PlanItem] = context.items(on: day).filter { $0.schedule == .conditional }
                Form {
                    Section {
                        ForEach(items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: toggleBinding(item, context: context)) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                        Text(categoryLine(item, context: context))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if isOn(item, context: context) {
                                    MarkBar(mark: context.mark(item, on: day), options: [.done, .partial, .missed]) {
                                        app.setMark($0, item: item, day: day)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Gab es diese Situationen heute?")
                    } footer: {
                        Text("Was nicht vorkam, zählt als „Entfällt“ und verändert die Wertung nicht.")
                    }
                }
                .formStyle(.grouped)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Später") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { finish(items, context: context) }
                    }
                }
            }
            .navigationTitle("Bedingte Punkte")
            .inlineNavigationTitle()
        }
        .toastHost(app)
        .thaliaSheetFrame(width: 460, height: 520)
    }

    /// Recorded as having happened (a mark other than "Entfällt").
    private func hasOccurredMark(_ item: PlanItem, context: WeekContext) -> Bool {
        guard let mark = context.mark(item, on: day) else { return false }
        return mark != .notApplicable
    }

    private func isOn(_ item: PlanItem, context: WeekContext) -> Bool {
        guard !turnedOff.contains(item.code) else { return false }
        return occurred.contains(item.code) || hasOccurredMark(item, context: context)
    }

    private func toggleBinding(_ item: PlanItem, context: WeekContext) -> Binding<Bool> {
        let code: String = item.code
        let marked: Bool = hasOccurredMark(item, context: context)
        return Binding(
            get: { isOn(item, context: context) },
            set: { value in
                if value {
                    occurred.insert(code)
                    turnedOff.remove(code)
                } else {
                    occurred.remove(code)
                    if marked { turnedOff.insert(code) }
                }
            }
        )
    }

    private func categoryLine(_ item: PlanItem, context: WeekContext) -> String {
        let title: String = context.category(item.categoryKey)?.title ?? ""
        return "\(item.categoryKey) · \(title)"
    }

    /// "Fertig": switched-off situations lose their mark; open ones that didn't happen become "Entfällt".
    private func finish(_ items: [PlanItem], context: WeekContext) {
        let answered: Set<String> = Set(items.filter { hasOccurredMark($0, context: context) }.map(\.code))
        let open: [PlanItem] = items.filter { context.mark($0, on: day) == nil }
        app.store.settleConditionals(open, occurred: occurred.union(answered), day: day)
        let cleared: [PlanItem] = items.filter { turnedOff.contains($0.code) }
        if !cleared.isEmpty { app.store.setMarks(nil, items: cleared, day: day) }
        dismiss()
    }
}

// MARK: No plan, toolbar

/// The week has no plan yet: plan exactly this week (R56) or repeat the last planned one (R92).
struct NoPlanView: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app
    /// The last week with a plan before this one, looked up once per week.
    @State private var sourceWeek: WeekKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Noch kein Plan für \(week.label)", systemImage: "calendar.badge.plus")
                .font(.headline)
            Text("Sonntags: Reflexion und Zusagen an ChatGPT schicken – mit dem Planungs-Prompt aus Thalia kommt eine CSV zurück, die du hier einfügst.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let syncLine {
                // v11 P3.16 (KR2-27): a plan from another device may still be on its way – don't plan twice.
                Label(syncLine, systemImage: "icloud")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                app.sheet = .planWeek(week)
            } label: {
                Label("Wochenplan importieren", systemImage: "square.and.arrow.down")
            }
            .thaliaPrimaryAction()
            if let sourceWeek {
                Button {
                    app.sheet = .repeatPlan(from: sourceWeek, to: week)
                } label: {
                    Label("Wie \(sourceWeek.label) wiederholen", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            if week < app.today.week {
                // v8: a week that is over – enter it afterwards (plan, documents or just the score).
                Button {
                    app.sheet = .importPast(week)
                } label: {
                    Label("Vergangene Woche nachtragen", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
        .task(id: week) {
            sourceWeek = app.store.planningSourceWeek(for: week)
        }
    }

    /// v11 P3.16: while iCloud syncs, or when the last sync is more than 10 minutes ago – only where Thalia syncs
    /// (never in the practice or a local store). The time of the last import counts first (`lastReceived`).
    private var syncLine: String? {
        let state: SyncState = app.sync.state
        guard state.mode.isSynced else { return nil }
        if state.isSyncing { return "iCloud gleicht gerade ab – ein Plan von einem anderen Gerät kann gleich ankommen." }
        guard let last = app.lastReceived ?? state.lastSync else { return nil }
        let now = Date()
        guard now.timeIntervalSince(last) > 10 * 60 else { return nil }
        return "Letzter Abgleich \(SyncDevice.seenText(last, now: now)) – ein Plan von einem anderen Gerät ist vielleicht noch unterwegs."
    }
}

/// Toolbar of Today (R62). iPhone: the date as a title menu and the ring (R38); "+" sits at the
/// bottom (accessory). iPad: the title, "Heute im Blick" and the menu. Mac: day navigation, closing
/// the day (with its name), "Erfassen" and the "Heute im Blick" column.
/// A plain toolbar on purpose: the customizable one (`.toolbar(id:)`) crashed the Mac app inside
/// AppKit's toolbar layout (NSToolbarItemViewer minSize, 1.6.0 build 47).
struct TodayToolbar: ToolbarContent {
    let context: WeekContext
    let day: DayKey
    /// iPad (wide) and Mac: list and page side by side.
    var usesSplit = false
    @Environment(AppModel.self) private var app

    private var closeTitle: String { context.isClosed(day) ? "Abgeschlossen" : "Tag abschließen" }
    private var closeSymbol: String { context.isClosed(day) ? "checkmark.seal.fill" : "moon.stars" }

    /// v11 P4.1: says why the button opens a sheet when the window is too narrow for the column.
    @MainActor private var glanceHelp: String {
        app.fitsGlanceInspector ? "Heute im Blick ein- oder ausblenden (⌘0)" : "Fenster breiter ziehen, um die Spalte zu zeigen"
    }

    var body: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .navigation) {
            Button { app.selectedDay = day.adding(days: -1) } label: { Label("Vorheriger Tag", systemImage: "chevron.left") }
                .help("Vorheriger Tag (⌘[)")
        }
        ToolbarItem(placement: .navigation) {
            Button("Zu heute") { app.goToToday() }
                .disabled(day == app.today)
                // v11 P6.15: one command "Zu heute" ⌘T in "Gehe zu".
                .help("Zu heute (⌘T)")
        }
        ToolbarItem(placement: .navigation) {
            Button { app.selectedDay = day.adding(days: 1) } label: { Label("Nächster Tag", systemImage: "chevron.right") }
                .help("Nächster Tag (⌘])")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                app.sheet = .closeDay(app.dayToClose(showing: day))
            } label: {
                Label(closeTitle, systemImage: closeSymbol)
            }
            .labelStyle(.titleAndIcon)
            .help("Tag abschließen (⌘↩)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                app.sheet = .create
            } label: {
                Label("Erfassen", systemImage: "plus")
            }
            // v11 P6.15: with its word, like on Woche, Ziele and Rückblick.
            .labelStyle(.titleAndIcon)
            .help("Erfassen (⇧⌘N)")
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                // v11 P4.1: the column while it fits, else "Heute im Blick" as a sheet.
                app.showDayOverview(day)
            } label: {
                Label("Heute im Blick", systemImage: "sidebar.trailing")
            }
            .help(glanceHelp)
        }
        #else
        ToolbarItem(placement: .principal) {
            if usesSplit {
                Text(day == app.today ? "Heute" : day.weekday.name)
                    .font(.headline)
            } else {
                TodayTitleMenu(context: context, day: day)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            if usesSplit {
                Button {
                    app.showsGlanceInspector.toggle()
                } label: {
                    Label("Heute im Blick", systemImage: "sidebar.trailing")
                }
            } else {
                TodayRingButton(context: context, day: day)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Heute im Blick", systemImage: "info.circle") { app.sheet = .dayOverview(day) }
                Button("Fokus (Power-Hours)", systemImage: "bolt") { app.sheet = .focus(day) }
                Button("Ausgaben", systemImage: "eurosign.circle") { app.sheet = .expenses(day) }
                // v11 P4.19: import, catching up, PDFs, the trash and Settings work on real data – not in the practice.
                if !app.isSandbox {
                    MoreMenuDataItems()
                }
            } label: {
                Label("Mehr", systemImage: "ellipsis")
            }
        }
        #endif
    }
}

/// The "Mehr" menus' entries that work on the real data (Heute, Woche, Ziele, Rückblick): import, catching up,
/// PDFs, the trash, the tour and Settings. v11 P4.19: never in the practice; P5.9: "…" where a window follows.
private struct MoreMenuDataItems: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Button("Wochenplan importieren", systemImage: "square.and.arrow.down") { app.sheet = .importPlan(prompt: true) }
        // v8: past weeks and several weeks as one PDF.
        Button("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath") { app.sheet = .importPast(nil) }
        Button("Mehrere Wochen als PDF…", systemImage: "doc.richtext") { app.sheet = .rangePDF }
        Button("Zuletzt gelöscht", systemImage: "trash") { app.sheet = .trash }
        Divider()
        Button("Thalia-Tour", systemImage: "graduationcap") { app.startTour() }
        Button("Einstellungen", systemImage: "gear") { app.sheet = .settings }
    }
}

#if os(iOS)
/// R38: the date in the title bar – "Heute" (or the weekday) over "16. Nov. · KW47 · Arbeitstag";
/// a menu with the days of the week, other weeks, "Zu heute" and the day's type and note.
private struct TodayTitleMenu: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    private var headline: String { day == app.today ? "Heute" : day.weekday.name }

    var body: some View {
        let line: String = todayDateLine(context, day: day)
        Menu {
            TodayDayMenu(context: context, day: day)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Text(headline)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text(line)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
        }
        .accessibilityLabel("\(headline), \(day.longLabel), \(context.dayType(day))")
        .accessibilityHint("Anderen Tag wählen, Tagestyp und Besonderheit ändern")
    }
}

/// R38: the day's ring with "73 %" (the score once closed) – a tap opens "Heute im Blick".
private struct TodayRingButton: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    private var valueText: String {
        let overall: DayOverall? = context.score.days[day]
        if context.isExcused(day) { return context.excusedName(day) }
        if context.isClosed(day) { return Format.score(overall?.score) }
        return overall?.coverageText ?? "0 %"
    }

    private var spoken: String {
        let overall: DayOverall? = context.score.days[day]
        if context.isExcused(day) { return "\(context.excusedName(day)), der Tag zählt nicht" }
        if context.isClosed(day) { return "Tag abgeschlossen, Wertung \(Format.score(overall?.score))" }
        return "\(overall?.coverageText ?? "0 %") erfasst"
    }

    /// v8: the day type's symbol in the ring on a sick or holiday day.
    private var excusedSymbol: String? {
        context.isExcused(day) ? DayTypes.symbol(for: context.dayType(day)) : nil
    }

    var body: some View {
        let overall: DayOverall? = context.score.days[day]
        let shownScore: Double? = context.isClosed(day) ? overall?.score : nil
        Button {
            app.sheet = .dayOverview(day)
        } label: {
            HStack(spacing: 6) {
                FillRing(fill: overall?.coverage ?? 0, score: shownScore, size: 22, lineWidth: 3, excusedSymbol: excusedSymbol)
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
        }
        .accessibilityLabel(spoken)
        .accessibilityHint("Öffnet „Heute im Blick“")
    }
}
#endif

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
            .labelStyle(.titleAndIcon)
            .help("Erfassen (⇧⌘N)")
        }
        #else
        ToolbarItem(placement: .topBarTrailing) {
            // v11 P4.19: nothing in the practice works on real data – there the menu isn't offered at all.
            if !app.isSandbox {
                Menu {
                    MoreMenuDataItems()
                } label: {
                    Label("Mehr", systemImage: "ellipsis")
                }
            }
        }
        #endif
    }
}
