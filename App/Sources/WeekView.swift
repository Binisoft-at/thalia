import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// "Woche": the printed weekly tracker as a sheet – every category with its ten items, Mo–So,
/// the week's score with the ten equally weighted goals, the weekly targets, and the weekly closing.
struct WeekView: View {
    @Environment(AppModel.self) private var app
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// Mac and iPad (wide): the dense table; iPhone: the list.
    private var usesTable: Bool {
        #if os(macOS)
        true
        #else
        sizeClass == .regular
        #endif
    }

    var body: some View {
        WeekReader(week: app.selectedWeek, today: app.today) { context in
            if usesTable {
                WeekTable(context: context)
            } else {
                WeekSheet(context: context)
            }
        }
    }
}

struct WeekSheet: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @State private var showContext = false
    @State private var collapsed: Set<String> = []
    /// R85: categories whose "Werte" rows are open (folded by default).
    @State private var openValues: Set<String> = []
    /// R55: the weekly targets fold away and stay so.
    @AppStorage("week.goals.expanded") private var goalsExpanded = false

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

            if context.isClosed && context.isFrozen {
                // v10 (Grundregel 2): a closed week before the current segment – "Neu berechnen".
                Section {
                    FrozenWeekNote(context: context)
                }
            }

            targetsSection

            if context.isArchiveWeek {
                // v9: a week from old records – the two scores and the grades instead of "Noch kein Plan".
                archiveSection
            }

            if context.hasPlan {
                ForEach(context.goals) { goal in
                    ForEach(context.categories(of: goal)) { category in
                        categorySection(category)
                    }
                }
                if context.showsArchive {
                    archiveSection
                }
                Section {
                    Button {
                        app.sheet = .newItem(context.week, categoryKey: nil)
                    } label: {
                        Label("Punkt anlegen", systemImage: "plus")
                    }
                } footer: {
                    Text("So viele Punkte pro Kategorie wie nötig. Messwerte sind keine Punkte – sie schlagen nur einen Haken vor.")
                }
            } else if !context.isArchiveWeek || context.week >= app.today.week {
                // v9: a week that isn't over keeps the way to its plan, even with grades.
                Section { NoPlanView(week: context.week) }
            }
        }
        .compactListSections()
        .navigationTitle(context.week.label)
        .inlineNavigationTitle()
        .toolbar { WeekSheetToolbar(context: context, app: app) }
    }

    /// R65: the day the title and "Details…" open.
    private var detailDay: DayKey {
        weekDetailDay(context.week, selected: app.selectedDay, today: app.today)
    }

    // MARK: Header

    /// R55: compact – the week and its arrows sit in the title bar, closing and planning in the bar
    /// and the …-menu, so the first cell shows without scrolling.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HeroCard(title: context.week.rangeLabel, subtitle: heroSubtitle,
                     value: Format.score(context.heroScore, outOf: false), caption: "Woche",
                     progress: heroProgress, facts: heroFacts, compact: true)
            goalBars
            dayStrip
            contextLine
        }
    }

    /// v8: a week of only sick or holiday days says "Woche zählt nicht (krank/Urlaub)".
    /// v9: a week without items names its number ("Archiv · Wertung laut Unterlagen").
    private var heroSubtitle: String {
        if let label = context.heroScoreLabel { return "Archiv · " + label }
        return context.isArchiveWeek ? "Archiv" : context.coverageLine
    }

    private var heroProgress: Double {
        let value: Double = context.heroScore ?? 0
        return value / 10
    }

    private var heroFacts: [(String, String)] {
        // v9: an archive week has no focus or closed days to show – the other score and the grades.
        if context.isArchiveWeek { return context.archiveHeroFacts }
        let totals: WorkTotals = context.workTotals()
        let focus: String = totals.isEmpty ? "–" : totals.shortText
        // v8: sick and holiday days don't need closing ("3/5 · 2 krank").
        return [("Fokus", focus), ("Tage abgeschlossen", context.closedDaysText)]
    }

    /// The ten goals in their colours (R68), with the scoring explainer.
    private var goalBars: some View {
        HStack(alignment: .center, spacing: 10) {
            GoalBars(scores: context.goals.map { context.shownGoalScore($0.key) }, height: 28,
                     keys: context.goals.map(\.key))
            Button {
                app.sheet = .explainer(.scoring)
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Brand.accent)
            .accessibilityLabel("Je Ziel 10 % – wie wird gerechnet?")
        }
        .card(padding: 10)
    }

    /// R8/R42/R90: Mo–So with status, a tap opens the day in Today.
    private var dayStrip: some View {
        HStack(spacing: 4) {
            ForEach(context.week.days, id: \.self) { day in
                WeekDayHeader(context: context, day: day)
            }
        }
    }

    /// R55: the week's context in one line; a tap shows all of it.
    @ViewBuilder
    private var contextLine: some View {
        if let plan = context.plan, !(plan.title.isEmpty && plan.details.isEmpty) {
            Button {
                withAnimation(.snappy) { showContext.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(.secondary)
                        Text(plan.title.isEmpty ? plan.details : plan.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(showContext ? nil : 1)
                        Spacer(minLength: 4)
                        Image(systemName: showContext ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    if showContext && !plan.title.isEmpty && !plan.details.isEmpty {
                        Text(plan.details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .card(padding: 10)
            .contextMenu {
                Button("Bearbeiten…", systemImage: "pencil") { app.sheet = .weekInfo(context.week) }
            }
            .accessibilityHint(showContext ? "Klappt den Wochenkontext zu" : "Zeigt den ganzen Wochenkontext")
        }
    }

    // MARK: Archive (v9)

    /// The "Archiv" card (decision 9): both scores, the grades; for a past week the way to import it again.
    private var archiveSection: some View {
        Section {
            ArchiveCard(context: context)
                .padding(.vertical, 4)
            if context.week < app.today.week {
                Button {
                    app.sheet = .importPast(context.week)
                } label: {
                    Label("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath")
                }
            }
        } header: {
            Label("Archiv", systemImage: "archivebox")
        } footer: {
            Text(archiveFooter)
        }
    }

    private var archiveFooter: String {
        guard context.isArchiveWeek else {
            return "Die Wertung laut Unterlagen bleibt, wie sie war, und zählt im Rückblick. Nach heutigen Regeln rechnet Thalia aus den Punkten dieser Woche."
        }
        return "Die Wertung laut Unterlagen bleibt, wie sie war. Nach heutigen Regeln rechnet Thalia aus den Kategoriennoten – ohne Krank- und Urlaubstage. Fehlende Einzelhaken, Arbeitszeiten und Messwerte bleiben unbekannt."
    }

    // MARK: Weekly targets

    /// R16/R55: the one weekly-target list, folded away on request (remembered).
    @ViewBuilder
    private var targetsSection: some View {
        let targets: [WeeklyTarget] = context.weeklyTargets
        let totals: WorkTotals = context.workTotals()
        if !targets.isEmpty || !totals.isEmpty {
            Section {
                if goalsExpanded {
                    if !targets.isEmpty {
                        WeeklyTargetsList(context: context, onOpen: weekTargetOpener(context: context, app: app))
                    }
                    if !totals.isEmpty {
                        Button {
                            app.sheet = .explainer(.powerHours)
                        } label: {
                            Label(totals.explanation, systemImage: "equal.circle")
                                .font(.subheadline)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Button {
                    withAnimation(.snappy) { goalsExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Label("Wochenziele", systemImage: "target")
                        Spacer()
                        if !targets.isEmpty {
                            Text("\(context.weeklyTargetsMet) von \(targets.count) erreicht")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: goalsExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityHint(goalsExpanded ? "Klappt die Wochenziele zu" : "Zeigt die Wochenziele")
            } footer: {
                if goalsExpanded && !targets.isEmpty {
                    Text("Der Strich zeigt ein gleichmäßiges Tempo über die geplanten Tage – keine Aufforderung, mehr zu machen.")
                }
            }
        }
    }

    // MARK: The sheet

    private func categorySection(_ category: TrackCategory) -> some View {
        let items: [PlanItem] = context.items(in: category)
        let values: [MeasureDefinition] = WeekValues.measures(in: category, context: context)
        let isCollapsed: Bool = collapsed.contains(category.key)
        let showsValues: Bool = openValues.contains(category.key)
        let day: DayKey = detailDay
        return Section {
            if !isCollapsed && !items.isEmpty {
                DayHeaderRow(context: context, categoryKey: category.key)
                ForEach(items) { item in
                    WeekItemRow(context: context, item: item, detailDay: day)
                }
            } else if items.isEmpty {
                Text("Keine Punkte in dieser Woche")
                    .foregroundStyle(.secondary)
            }
            if !isCollapsed && !values.isEmpty {
                valuesToggle(category, count: values.count, isOpen: showsValues)
                if showsValues {
                    if items.isEmpty {
                        DayHeaderRow(context: context, categoryKey: category.key)
                    }
                    ForEach(values) { measure in
                        WeekValueRow(context: context, measure: measure)
                    }
                }
            }
        } header: {
            Button {
                withAnimation(.snappy) {
                    if isCollapsed { collapsed.remove(category.key) } else { collapsed.insert(category.key) }
                }
            } label: {
                HStack(spacing: 8) {
                    KeyBadge(key: category.key)
                    Text(context.title(of: category)).lineLimit(1)
                    if context.isGood(category) {
                        // v10 (§1.2.3): the category's week score is above 8.
                        GoodWeekBadge()
                    }
                    Spacer()
                    Text(Format.score(context.score.categoryWeek[category.key], outOf: false))
                        .monospacedDigit()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    /// R85: "Werte" – folded rows with the category's daily values Mo–So.
    private func valuesToggle(_ category: TrackCategory, count: Int, isOpen: Bool) -> some View {
        Button {
            withAnimation(.snappy) {
                if isOpen { openValues.remove(category.key) } else { openValues.insert(category.key) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.secondary)
                Text("Werte")
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Werte, \(count)")
        .accessibilityHint(isOpen ? "Klappt die Tageswerte zu" : "Zeigt die Tageswerte von Montag bis Sonntag")
    }
}

/// R55: the iPhone week's bar – arrows, "KW47" with the last weeks, closing the week, the …-menu.
struct WeekSheetToolbar: ToolbarContent {
    let context: WeekContext
    let app: AppModel

    private var closeTitle: String { context.isClosed ? "Abgeschlossen" : "Woche abschließen" }
    private var closeSymbol: String { context.isClosed ? "checkmark.seal.fill" : "flag.checkered" }

    var body: some ToolbarContent {
        #if os(iOS)
        ToolbarItemGroup(placement: .topBarLeading) {
            Button {
                withAnimation(.snappy) { app.selectedWeek = context.week.adding(weeks: -1) }
            } label: {
                Label("Vorige Woche", systemImage: "chevron.left")
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
            Button {
                withAnimation(.snappy) { app.selectedWeek = context.week.adding(weeks: 1) }
            } label: {
                Label("Nächste Woche", systemImage: "chevron.right")
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])
        }
        ToolbarItem(placement: .principal) {
            WeekTitleMenu(context: context, app: app)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                app.sheet = .closeWeek(context.week)
            } label: {
                Label(closeTitle, systemImage: closeSymbol)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            WeekMoreMenu(context: context, app: app)
        }
        #else
        MainToolbar()
        #endif
    }
}

/// R55: "KW47" in the title bar – a menu with the last 8 weeks and "Zur aktuellen Woche".
private struct WeekTitleMenu: View {
    let context: WeekContext
    let app: AppModel

    private var recentWeeks: [WeekKey] {
        (0..<8).map { app.today.week.adding(weeks: -$0) }
    }

    private func title(_ week: WeekKey) -> String {
        "\(week.label) · \(week.rangeLabel)"
    }

    var body: some View {
        Menu {
            ForEach(recentWeeks, id: \.self) { week in
                Button {
                    withAnimation(.snappy) { app.selectedWeek = week }
                } label: {
                    if week == context.week {
                        Label(title(week), systemImage: "checkmark")
                    } else {
                        Text(title(week))
                    }
                }
            }
            Divider()
            Button("Zur aktuellen Woche", systemImage: "calendar") {
                withAnimation(.snappy) { app.selectedWeek = app.today.week }
            }
            .disabled(context.week == app.today.week)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Text(context.week.label)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text(context.week.rangeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .accessibilityLabel("\(context.week.label), \(context.week.rangeLabel)")
        .accessibilityHint("Andere Woche wählen")
    }
}

/// R55/R56: the …-menu of the iPhone week – planning the next week, the report, then the usual entries.
private struct WeekMoreMenu: View {
    let context: WeekContext
    let app: AppModel

    var body: some View {
        let next: WeekKey = context.week.adding(weeks: 1)
        Menu {
            Button("\(next.label) planen", systemImage: "sparkles") { app.sheet = .planWeek(next) }
            Button("Bericht", systemImage: "doc.text") { app.sheet = .report(context.week) }
            Button("Wochenkontext bearbeiten…", systemImage: "pencil") { app.sheet = .weekInfo(context.week) }
            Divider()
            // v8: past weeks and several weeks as one PDF.
            Button("Vergangene Woche nachtragen…", systemImage: "clock.arrow.circlepath") { app.sheet = .importPast(pastWeek) }
            Button("Mehrere Wochen als PDF…", systemImage: "doc.richtext") { app.sheet = .rangePDF }
            Divider()
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

    /// v8: the week shown when it lies in the past, else nil (the window chooses).
    private var pastWeek: WeekKey? {
        context.week < app.today.week ? context.week : nil
    }
}

/// R65: the day an item's title and "Details…" open – the chosen day if it is in this week, else
/// today if it is, else Monday.
func weekDetailDay(_ week: WeekKey, selected: DayKey, today: DayKey) -> DayKey {
    if week.contains(selected) { return selected }
    if week.contains(today) { return today }
    return week.monday
}

/// R16: a tap on a weekly target records for today – only in the current week.
@MainActor
func weekTargetOpener(context: WeekContext, app: AppModel) -> ((MeasureDefinition) -> Void)? {
    guard context.week.contains(context.today) else { return nil }
    let day: DayKey = context.today
    return { measure in
        app.sheet = MarkCell.valueSheet(for: measure, context: context, day: day)
    }
}

/// R8/R42/R90: one weekday above the week – day type (or the seal once closed), status ("62 %",
/// the score once closed, "–" to come), "5 offen" for past open days and a dot for the day's note.
/// A tap opens the day in Today; the context menu closes it or edits type and note.
struct WeekDayHeader: View {
    let context: WeekContext
    let day: DayKey
    /// Fixed column width (Mac table); nil fills the strip (iPhone).
    var width: CGFloat?
    @Environment(AppModel.self) private var app

    private var isToday: Bool { day == context.today }
    private var isClosed: Bool { context.isClosed(day) }
    /// v8: a sick or holiday day – the column is dimmed and shows the type's symbol.
    private var isExcused: Bool { context.isExcused(day) }

    private var note: String {
        context.dayNote(day).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Past days with a plan that are still open and have blank required items.
    private var openCount: Int? {
        guard context.hasPlan, day < context.today, !isClosed, !isExcused else { return nil }
        let count: Int = context.openCount(on: day)
        return count > 0 ? count : nil
    }

    private var symbol: String {
        if isExcused { return DayTypes.symbol(for: context.dayType(day)) }
        return isClosed ? "checkmark.seal.fill" : DayTypes.symbol(for: context.dayType(day))
    }

    private var symbolColor: Color {
        isClosed && !isExcused ? Brand.accent : Color.secondary
    }

    private var title: String {
        width == nil ? day.weekday.short : "\(day.weekday.short) \(day.day)."
    }

    private var titleFont: Font {
        width == nil ? .caption2.weight(.semibold) : .caption.weight(.semibold)
    }

    private var titleColor: Color {
        if isToday { return Brand.accent }
        return width == nil ? .secondary : .primary
    }

    private var maxWidth: CGFloat? {
        width == nil ? .infinity : nil
    }

    private var cellFill: Color {
        if isExcused { return Color.secondary.opacity(0.12) }
        if isClosed { return Brand.accent.opacity(0.12) }
        return isToday ? Brand.accent.opacity(0.08) : Color.clear
    }

    private var spokenText: String {
        var parts: [String] = [context.dayStatusAccessibility(day)]
        let type: String = context.dayType(day)
        if !type.isEmpty && !isExcused { parts.append(type) }
        if let openCount { parts.append("\(openCount) offen") }
        if !note.isEmpty { parts.append("Besonderheit: \(note)") }
        return parts.joined(separator: ", ")
    }

    private var tooltip: String {
        var base: String = "\(day.longLabel) in Heute öffnen"
        if isExcused { base += "\n" + DayTypes.excusedHint }
        return note.isEmpty ? base : "\(base)\nBesonderheit: \(note)"
    }

    private var closeTitle: String {
        isClosed ? "Abschluss ansehen…" : "Tag abschließen…"
    }

    var body: some View {
        Button(action: openInToday) {
            label
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .contextMenu {
            if day <= context.today {
                Button(closeTitle, systemImage: "moon.stars") { app.sheet = .closeDay(day) }
            }
            DayTypeMenu(app: app, day: day, current: context.dayType(day))
            Button("Tagestyp und Besonderheit…", systemImage: "calendar") { app.sheet = .dayInfo(day) }
        }
        .accessibilityLabel(spokenText)
        .accessibilityHint("Öffnet den Tag in Heute")
    }

    /// R42: the day in Today.
    private func openInToday() {
        app.selectedDay = day
        app.tab = .today
        app.sidebar = .today
    }

    private var label: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(titleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(titleColor)
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(symbolColor)
            Text(context.dayStatusText(day))
                .font(.system(.caption2, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
            if let openCount {
                Text("\(openCount) offen")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: maxWidth)
        .frame(width: width)
        .padding(.vertical, 5)
        .background(cellFill, in: .rect(cornerRadius: 9))
        .overlay(alignment: .topTrailing) {
            if !note.isEmpty {
                Circle()
                    .fill(Brand.accent)
                    .frame(width: 5, height: 5)
                    .padding(4)
            }
        }
        .contentShape(.rect)
    }
}

/// R85: the daily measurements of a category that have a number or a time (no texts).
enum WeekValues {
    static func measures(in category: TrackCategory, context: WeekContext) -> [MeasureDefinition] {
        context.measures.filter { measure in
            guard measure.categoryKey == category.key, let record = measure.record else { return false }
            return record.period == .day && !record.isText
        }
    }

    /// "70,5 kg", "23:10", "·" without a value.
    static func text(_ value: Double?, measure: MeasureDefinition) -> String {
        guard let value else { return "·" }
        return Format.measure(value, unit: measure.unit)
    }

    /// Green met, red missed; without a target plain, without a value grey.
    static func color(_ value: Double?, measure: MeasureDefinition) -> Color {
        guard value != nil else { return .secondary }
        guard let record = measure.record, let met = Measures.isMet(record, value: value) else { return .primary }
        return met ? .green : .red
    }

    static func spoken(_ value: Double?, measure: MeasureDefinition) -> String {
        guard let value else { return "kein Wert" }
        let shown: String = Format.measure(value, unit: measure.unit)
        guard let record = measure.record, let met = Measures.isMet(record, value: value) else { return shown }
        return met ? "\(shown), erfüllt" : "\(shown), verfehlt"
    }
}

/// R85: one day's value of a measurement; a tap records it for that day.
struct WeekValueCell: View {
    let context: WeekContext
    let measure: MeasureDefinition
    let day: DayKey
    let width: CGFloat
    @Environment(AppModel.self) private var app

    var body: some View {
        let value: Double? = context.dayValue(measure, on: day)
        let applies: Bool = context.applies(measure, on: day)
        Button {
            app.sheet = MarkCell.valueSheet(for: measure, context: context, day: day)
        } label: {
            Text(WeekValues.text(value, measure: measure))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(WeekValues.color(value, measure: measure))
                .frame(width: width, height: 26)
                .background(applies ? Color.cardBackground : Color.clear, in: .rect(cornerRadius: 6))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("\(measure.title) · \(day.shortLabel)")
        .accessibilityLabel("\(day.weekday.name), \(measure.title): \(WeekValues.spoken(value, measure: measure))")
    }
}

/// R85: a measurement's values Mo–So under its category (iPhone).
struct WeekValueRow: View {
    let context: WeekContext
    let measure: MeasureDefinition

    var body: some View {
        HStack(spacing: 3) {
            VStack(alignment: .leading, spacing: 1) {
                Text(measure.title)
                    .font(.subheadline)
                    .lineLimit(2)
                if let target = measure.record?.target {
                    Text("Ziel \(target.label)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(context.week.days, id: \.self) { day in
                WeekValueCell(context: context, measure: measure, day: day, width: 30)
            }
        }
    }
}

/// Mo–So above the cells, with the category's score per day.
struct DayHeaderRow: View {
    let context: WeekContext
    let categoryKey: String

    var body: some View {
        HStack(spacing: 3) {
            Text("Tag")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(context.week.days, id: \.self) { day in
                let entry = context.score.category(categoryKey, on: day)
                VStack(spacing: 0) {
                    Text(day.weekday.short)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(day == context.today ? Brand.accent : .secondary)
                    if context.isExcused(day) {
                        // v8: sick / holiday – the column doesn't count.
                        Image(systemName: DayTypes.symbol(for: context.dayType(day)))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(entry.score.map { Format.score($0) } ?? "·")
                            .font(.system(size: 10, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(entry.knockedOut ? Color.orange : Color.secondary)
                    }
                }
                .frame(width: 30)
                .background(columnFill(day), in: .rect(cornerRadius: 5))
            }
        }
        .accessibilityHidden(true)
    }

    /// v8: sick and holiday days grey – the column doesn't count.
    private func columnFill(_ day: DayKey) -> Color {
        context.isExcused(day) ? Color.secondary.opacity(0.12) : Color.clear
    }
}

/// One item: title, kind and seven cells (iPhone).
struct WeekItemRow: View {
    let context: WeekContext
    let item: PlanItem
    /// R65: the day the title and "Details…" open.
    let detailDay: DayKey
    @Environment(AppModel.self) private var app
    @State private var confirmsDelete = false

    var body: some View {
        HStack(spacing: 3) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(2)
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { app.sheet = .item(item, detailDay) }
            ForEach(context.week.days, id: \.self) { day in
                WeekMarkCell(context: context, item: item, day: day)
                    .frame(width: 30, height: 30)
            }
        }
        .contextMenu {
            WeekItemMenu(app: app, item: item, detailDay: detailDay, confirmsDelete: $confirmsDelete)
        }
        .weekItemDeleteDialog(item, isPresented: $confirmsDelete, app: app)
    }

    /// "2/3×"; v8: "2/3× · ½ krank".
    private var quotaLabel: String {
        context.quotaText(item) ?? ""
    }

    /// R64: the same short label as Today and the PDF; quota and progress of the week.
    @ViewBuilder
    private var meta: some View {
        let kind: String? = context.kindLabel(item)
        let quota: (done: Int, target: Int)? = context.quotaProgress(item)
        let progress: Double? = context.progress(item)
        if item.isKnockout || kind != nil || quota != nil || progress != nil {
            HStack(spacing: 4) {
                if item.isKnockout {
                    Image(systemName: "exclamationmark.octagon").foregroundStyle(.orange)
                }
                KindBadge(text: kind)
                if let quota {
                    Text(quotaLabel)
                        .monospacedDigit()
                        .foregroundStyle(quota.done >= quota.target ? Color.green : Color.secondary)
                } else if let progress {
                    Text("\(percent(progress)) %")
                        .monospacedDigit()
                        .foregroundStyle(progress >= 1 ? Color.green : Color.secondary)
                }
            }
            .font(.caption2)
        }
    }
}

/// R9/R63/R65/R66: one item on one day – the same rules in the iPhone week and the Mac table.
/// Free days and automatic items can't be marked; an automatic item opens its value instead.
struct WeekMarkCell: View {
    let context: WeekContext
    let item: PlanItem
    let day: DayKey
    @Environment(AppModel.self) private var app

    /// "Mi, 18. Nov. · Erledigt".
    static func helpText(_ mark: Mark?, item: PlanItem, day: DayKey) -> String {
        let word: String = mark?.label(progress: item.schedule == .progress) ?? "Nicht erfasst"
        return "\(day.shortLabel) · \(word)"
    }

    private func opener(_ sheet: AppSheet?) -> (() -> Void)? {
        guard let sheet else { return nil }
        let model: AppModel = app
        return { model.sheet = sheet }
    }

    var body: some View {
        let mark: Mark? = context.mark(item, on: day)
        let valueSheet: AppSheet? = MarkCell.valueSheet(for: item, context: context, day: day)
        MarkCell(
            mark: mark,
            applies: item.days.contains(day.weekday) && item.schedule != .optional,
            isToday: day == context.today,
            suggestion: context.suggestion(item, on: day),
            options: context.options(item, on: day),
            hasNote: !context.markNote(item, on: day).isEmpty,
            accessibilityPrefix: "\(day.weekday.name), \(item.title)",
            help: cellHelp(mark),
            onOpenValue: opener(valueSheet),
            onAddNote: { app.sheet = .item(item, day) },
            dimmedMark: context.excusedMark(item, on: day),
            excusedName: excusedName,
            onSet: { app.setMark($0, item: item, day: day) }
        )
    }

    /// "Mi, 18. Nov. · Erledigt"; v8: "Fr, 20. Nov. · Krank – zählt nicht".
    private func cellHelp(_ mark: Mark?) -> String {
        guard context.isExcused(day) else { return WeekMarkCell.helpText(mark, item: item, day: day) }
        return "\(day.shortLabel) · \(context.excusedName(day)) – zählt nicht"
    }

    /// v8: "Krank" / "Urlaub" on a sick or holiday day where the item was planned.
    private var excusedName: String? {
        guard context.isExcused(day), item.days.contains(day.weekday) else { return nil }
        return context.excusedName(day)
    }
}

/// R63: the context menu of an item in the week (iPhone and Mac). `app` is passed in, so the menu
/// doesn't depend on the environment reaching it.
struct WeekItemMenu: View {
    let app: AppModel
    let item: PlanItem
    let detailDay: DayKey
    @Binding var confirmsDelete: Bool

    var body: some View {
        Button("Bearbeiten…", systemImage: "pencil") { app.sheet = .editItem(item) }
        Button("Details…", systemImage: "info.circle") { app.sheet = .item(item, detailDay) }
        if item.isSecondary {
            Button("Doch wichtig", systemImage: "star") { app.store.setSecondary(item, false) }
        } else {
            Button("Als Nebensache", systemImage: "square.stack") { app.store.setSecondary(item, true) }
        }
        Divider()
        Button("Löschen…", systemImage: "trash", role: .destructive) { confirmsDelete = true }
    }
}

extension View {
    /// R63: deleting an item asks whether it should stay away in later weeks, too.
    @MainActor
    func weekItemDeleteDialog(_ item: PlanItem, isPresented: Binding<Bool>, app: AppModel) -> some View {
        confirmationDialog("„\(item.title)“ löschen?", isPresented: isPresented, titleVisibility: .visible) {
            Button("Löschen – auch künftig weglassen", role: .destructive) { app.trash([item], carryOver: true) }
            Button("Nur diese Woche löschen", role: .destructive) { app.trash([item], carryOver: false) }
        } message: {
            Text("Der nächste Planungs-Prompt sagt der KI, ob der Punkt dauerhaft wegfällt.")
        }
    }
}
