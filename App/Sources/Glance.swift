import SwiftUI
import SwiftData
import Charts
import BinisoftKit
import ThaliaCore

// v5: look in once and see what's going on – what's still to do (F4), and on the Mac a grey
// summary under the navigation (F4.1). v7: "Heute im Blick" as one sheet that pushes Fokus,
// Ausgaben and the weekly targets (R50, R51). Fokus lives in Focus.swift, Ausgaben in Expenses.swift.

/// A small tile: a value and what it is (Ausgaben). `valueColor` marks "noch 38 €" green or
/// "+12 €" red (R45).
struct SummaryTile: View {
    let label: String
    let value: String
    var tint: Color = Brand.accent
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(valueColor)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
    }
}

// MARK: Heute im Blick (R50, R51)

/// Where a tile of "Heute im Blick" leads (R51).
enum GlanceRoute: Hashable {
    case focus, expenses, weeklyGoals

    /// Pushed inside the "Heute im Blick" sheet; elsewhere (the Mac's right column) its own sheet.
    @MainActor
    func open(day: DayKey, app: AppModel, navigator: GlanceNavigator?) {
        if let navigator {
            navigator.path.append(self)
            return
        }
        switch self {
        case .focus: app.sheet = .focus(day)
        case .expenses: app.sheet = .expenses(day)
        case .weeklyGoals: app.sheet = .weeklyGoals(day.week)
        }
    }
}

/// The navigation path of the "Heute im Blick" sheet; its list finds it in the environment.
@Observable
final class GlanceNavigator {
    var path: [GlanceRoute] = []
}

/// "Heute im Blick" for a day: a short header, what's still to do, the weekly targets. Fokus,
/// Ausgaben and Wochenziele open inside with a back arrow – nothing closes the sheet unasked (R51).
struct GlanceSheet: View {
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var navigator = GlanceNavigator()

    init(day: DayKey) {
        self.day = day
    }

    var body: some View {
        NavigationStack(path: $navigator.path) {
            WeekReader(week: day.week, today: app.today) { context in
                GlanceList(context: context, day: day, onOpen: { page in open(page) })
            }
            .navigationTitle("Heute im Blick")
            .inlineNavigationTitle()
            .navigationDestination(for: GlanceRoute.self) { route in
                destination(route)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    WeekReader(week: day.week, today: app.today) { context in
                        PDFButton(kind: .day(day), context: context, title: "PDF")
                    }
                }
            }
        }
        .environment(navigator)
        .thaliaSheetFrame(width: 460, height: 640)
    }

    @ViewBuilder
    private func destination(_ route: GlanceRoute) -> some View {
        switch route {
        case .focus:
            FocusPage(day: day)
        case .expenses:
            ExpensesPage(day: day)
        case .weeklyGoals:
            WeeklyGoalsPage(week: day.week)
        }
    }

    /// A category or the day's last page: Today shows it and the sheet closes.
    private func open(_ page: TodayPage) {
        if app.selectedDay != day {
            app.selectedDay = day
            app.selectedWeek = day.week
        }
        app.todayPage = page
        app.tab = .today
        app.sidebar = .today
        dismiss()
    }
}

/// The content of "Heute im Blick" (sheet on iPhone/iPad, right column on the Mac): header,
/// yesterday, tiles, "Noch zu tun", "Diese Woche noch", weekly targets, categories, values, notes –
/// and "Tag abschließen" once everything is recorded. No hero card, no power-hour list (R50).
struct GlanceList: View {
    let context: WeekContext
    let day: DayKey
    let onOpen: (TodayPage) -> Void
    @Environment(AppModel.self) private var app
    @Environment(GlanceNavigator.self) private var navigator: GlanceNavigator?

    init(context: WeekContext, day: DayKey, onOpen: @escaping (TodayPage) -> Void) {
        self.context = context
        self.day = day
        self.onOpen = onOpen
    }

    var body: some View {
        List {
            Section {
                GlanceHeader(context: context, day: day)
            }
            if day == app.today {
                Section {
                    YesterdayBanner(today: app.today)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                GlanceTiles(context: context, day: day)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            if context.hasPlan {
                OpenToDoSection(context: context, day: day, onOpen: onOpen, onClose: closeAction)
                WeeklyOpenSection(context: context, day: day, onOpen: onOpen)
            } else {
                Section {
                    Button {
                        app.sheet = .planWeek(day.week)
                    } label: {
                        Label("Kein Plan – Wochenplan importieren", systemImage: "square.and.arrow.down")
                    }
                }
            }
            targetsSection
            categoriesSection
            measuresSection
            notesSection
        }
        .compactListSections()
    }

    // MARK: Sections

    @ViewBuilder
    private var targetsSection: some View {
        if !context.weeklyTargets.isEmpty {
            Section {
                WeeklyTargetsList(context: context, limit: 4)
                Button {
                    GlanceRoute.weeklyGoals.open(day: day, app: app, navigator: navigator)
                } label: {
                    HStack {
                        Text("Alle Wochenziele")
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
            } header: {
                Text("Wochenziele")
            }
        }
    }

    @ViewBuilder
    private var categoriesSection: some View {
        let categories: [TrackCategory] = dayCategories
        if !categories.isEmpty {
            Section("Kategorien") {
                ForEach(categories) { category in
                    GlanceCategoryRow(category: category, entry: context.score.category(category.key, on: day)) {
                        onOpen(.category(category.key))
                    }
                }
            }
        }
    }

    /// H1: a Health value on a device without Health shows the hint instead of "fehlt".
    @ViewBuilder
    private var measuresSection: some View {
        let lines: [GlanceValueLine] = valueLines
        if !lines.isEmpty {
            Section("Messwerte") {
                ForEach(lines) { line in
                    GlanceValueRow(line: line)
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        let notes: [DayNote] = context.notes(on: day)
        if !notes.isEmpty {
            Section("Notizen") {
                ForEach(notes) { note in
                    Label(note.text, systemImage: note.kind.symbol)
                }
            }
        }
    }

    // MARK: Values

    /// Everything required is recorded and the day is still open: "Tag abschließen" (R50).
    /// v8: not on a sick or holiday day – there is nothing to close.
    private var closeAction: (() -> Void)? {
        guard context.hasPlan, day <= app.today, !context.isClosed(day), !context.isExcused(day),
              context.openCount(on: day) == 0 else { return nil }
        let model: AppModel = app
        let target: DayKey = day
        return { model.sheet = .closeDay(target) }
    }

    /// Categories with something to mark, enter or show that day, in plan order.
    private var dayCategories: [TrackCategory] {
        let work: [WorkBlock] = context.work(on: day)
        return context.categories.filter { category in
            hasItems(category.key) || hasMeasures(category.key) || work.contains { $0.categoryKey == category.key }
        }
    }

    private func hasItems(_ key: String) -> Bool {
        context.items.contains { $0.categoryKey == key && context.applies($0, on: day) }
    }

    private func hasMeasures(_ key: String) -> Bool {
        context.measures.contains { $0.categoryKey == key && context.applies($0, on: day) }
    }

    /// The day's values (not work and spending – they have their tiles): measured, from Health on
    /// the iPhone (H1), or still missing.
    private var valueLines: [GlanceValueLine] {
        context.measures.compactMap { measure -> GlanceValueLine? in
            guard let record = measure.record, !record.isWork, !record.isExpense, !record.isText,
                  context.applies(measure, on: day) else { return nil }
            if let value = context.dayValue(measure, on: day) {
                return GlanceValueLine(id: measure.code, title: measure.title,
                                       value: Format.measure(value, unit: measure.unit), kind: .value)
            }
            if context.isHealthElsewhere(measure) {
                return GlanceValueLine(id: measure.code, title: measure.title, value: WeekContext.healthElsewhereHint, kind: .health)
            }
            guard record.period == .day, day <= app.today, context.countsAsMissing(measure, on: day) else { return nil }
            return GlanceValueLine(id: measure.code, title: measure.title, value: "fehlt", kind: .missing)
        }
    }
}

/// "Montag · Arbeitstag", "16. Nov. · KW47 · 73 % erfasst", the day's note and the work-free hint
/// (R50, R78, R90) – the date only once.
private struct GlanceHeader: View {
    let context: WeekContext
    let day: DayKey

    private var fill: Double {
        context.score.days[day]?.coverage ?? 0
    }

    private var shownScore: Double? {
        guard context.isClosed(day) else { return nil }
        return context.score.days[day]?.score
    }

    /// v8: the day type's symbol in the ring on a sick or holiday day.
    private var excusedSymbol: String? {
        context.isExcused(day) ? DayTypes.symbol(for: context.dayType(day)) : nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(GlanceText.title(day: day, type: context.dayType(day)))
                    .font(.title3.weight(.bold))
                Text(GlanceText.dateLine(context, day: day))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                DayNoteLabel(note: context.dayNote(day))
                if context.isExcused(day) {
                    // v8: sick or holiday – takes the place of the work-free hint.
                    Label(DayTypes.excusedHint, systemImage: DayTypes.symbol(for: context.dayType(day)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if context.isFreeDay(day) {
                    Label(DayTypes.workFreeHint, systemImage: "sun.max")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if context.hasPlan {
                FillRing(fill: fill, score: shownScore, size: 44, lineWidth: 5, excusedSymbol: excusedSymbol)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A category of the day: fill and "3/5", or its score once complete; a tap opens it in Today.
private struct GlanceCategoryRow: View {
    let category: TrackCategory
    let entry: CategoryDay
    let onOpen: () -> Void

    private var trailing: String {
        if entry.isComplete { return Format.score(entry.score, outOf: false) }
        return "\(entry.due - entry.blank)/\(entry.due)"
    }

    private var trailingStyle: Color {
        entry.isComplete ? .primary : .secondary
    }

    private var fillTint: Color {
        entry.isComplete ? .green : Brand.accent
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                KeyBadge(key: category.key)
                VStack(alignment: .leading, spacing: 3) {
                    Text(category.title)
                        .lineLimit(1)
                    if entry.due > 0 {
                        ProgressView(value: entry.fill)
                            .tint(fillTint)
                    }
                }
                Spacer(minLength: 8)
                if entry.due > 0 {
                    Text(trailing)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(trailingStyle)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// One value of the day in "Messwerte".
private struct GlanceValueLine: Identifiable {
    enum Kind { case value, health, missing }
    let id: String
    let title: String
    let value: String
    let kind: Kind
}

private struct GlanceValueRow: View {
    let line: GlanceValueLine

    private var valueColor: Color {
        switch line.kind {
        case .value: return .primary
        case .health: return .secondary
        case .missing: return .orange
        }
    }

    private var valueFont: Font {
        line.kind == .health ? .caption : .body
    }

    var body: some View {
        LabeledContent(line.title) {
            Text(line.value)
                .font(valueFont)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .foregroundStyle(valueColor)
        }
    }
}

/// Short texts shared by the tiles, the header, the Mac sidebar and the menu bar (kept out of view
/// expressions).
enum GlanceText {
    static func weekPowerHours(_ value: Double, target: Double?) -> String {
        guard let target else { return "Woche \(Format.powerHours(value))" }
        return "Woche \(Format.number(value)) / \(Format.number(target)) PH"
    }

    static func euro(_ value: Double?) -> String? {
        value.map { Format.euro($0) }
    }

    /// "73 % erfasst · 11 offen" – the open count is the ring's (R5); closed: the score.
    /// v8: "Krank – zählt nicht" on a sick or holiday day (`type` gives the word).
    static func dayLine(_ overall: DayOverall?, closed: Bool, open: Int, type: String = "") -> String {
        if overall?.isExcused == true { return excusedLine(type) }
        if closed { return "Abgeschlossen · \(Format.score(overall?.score, outOf: true))" }
        let coverage: String = overall?.coverageText ?? "0 %"
        return "\(coverage) erfasst · \(open) offen"
    }

    static func focusLine(today: WorkTotals, week: WorkTotals, target: Double?) -> String {
        let todayText: String = today.isEmpty ? "0 PH" : today.shortText
        let weekText: String = target.map { "\(Format.number(week.powerHours)) von \(Format.number($0)) PH" } ?? Format.powerHours(week.powerHours)
        return "Fokus \(todayText) heute · \(weekText) Woche"
    }

    static func expensesLine(today: Double?, week: Double?) -> String {
        "Ausgaben \(Format.euro(today ?? 0)) heute · \(Format.euro(week ?? 0)) Woche"
    }

    /// v8: "Krank – zählt nicht"; "Krank/Urlaub – zählt nicht" without the type.
    static func excusedLine(_ type: String) -> String {
        let name: String = DayTypes.isExcused(type) ? WeekContext.excusedName(for: type) : "Krank/Urlaub"
        return "\(name) – zählt nicht"
    }

    /// "Wertung 7,1 · 6/10 Ziele bewertet" (R16); v8: "Woche zählt nicht (krank/Urlaub)".
    static func weekLine(_ score: WeekScore) -> String {
        if score.isExcused { return WeekScore.excusedText }
        return "Wertung \(Format.score(score.overall)) · \(score.goalsScored)/\(score.goalsTotal) Ziele bewertet"
    }

    /// "Montag · Arbeitstag" (R50).
    static func title(day: DayKey, type: String) -> String {
        let trimmed: String = type.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? day.weekday.name : "\(day.weekday.name) · \(trimmed)"
    }

    /// "16. Nov." – the date without the weekday.
    static func date(_ day: DayKey) -> String {
        let parts = day.shortLabel.split(separator: ",", maxSplits: 1)
        guard parts.count == 2, let last = parts.last else { return day.shortLabel }
        return last.trimmingCharacters(in: .whitespaces)
    }

    /// "16. Nov. · KW47 · 73 % erfasst"; closed: "… · Wertung 7,5" (R50).
    static func dateLine(_ context: WeekContext, day: DayKey) -> String {
        var parts: [String] = [date(day), day.week.label]
        if context.hasPlan {
            if context.isExcused(day) {
                parts.append("zählt nicht")
            } else if context.isClosed(day) {
                parts.append("Wertung \(Format.score(context.score.days[day]?.score))")
            } else if day <= context.today {
                let coverage: String = context.score.days[day]?.coverageText ?? "0 %"
                parts.append("\(coverage) erfasst")
            }
        }
        return parts.joined(separator: " · ")
    }

    /// "Lesen 120/150 Seiten", "Ausgaben 32,50 €/50 €" (R17).
    static func targetLine(_ target: WeeklyTarget) -> String {
        let title: String = target.item?.title ?? target.measure.title
        if target.unit != "PH" && Units.normalized(target.measure.unit) == "€" {
            return "\(title) \(Format.euro(target.value))/\(Format.euro(target.target.scaleMax))"
        }
        let unit: String = target.unit.isEmpty ? "" : " \(target.unit)"
        return "\(title) \(Format.number(target.value))/\(Format.number(target.target.scaleMax))\(unit)"
    }
}

/// Three tiles at the top of "Heute im Blick": Fokus, Ausgaben, Wochenziele – each opens its view
/// (pushed inside the sheet, a sheet of its own from the Mac's column).
struct GlanceTiles: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app
    @Environment(GlanceNavigator.self) private var navigator: GlanceNavigator?

    var body: some View {
        HStack(spacing: 10) {
            GlanceTile(symbol: "bolt.fill", title: "Fokus", value: focusValue, detail: focusDetail,
                       tint: GoalPalette.color(goal: "3")) {
                open(.focus)
            }
            GlanceTile(symbol: "eurosign.circle.fill", title: "Ausgaben", value: expensesValue, detail: expensesDetail,
                       tint: GoalPalette.color(goal: "8")) {
                open(.expenses)
            }
            GlanceTile(symbol: "chart.bar.fill", title: "Wochenziele", value: targetsValue, detail: targetsDetail,
                       tint: GoalPalette.color(goal: "2")) {
                open(.weeklyGoals)
            }
        }
    }

    private func open(_ route: GlanceRoute) {
        route.open(day: day, app: app, navigator: navigator)
    }

    private var focusValue: String {
        let totals: WorkTotals = context.workTotals(on: day)
        return totals.isEmpty ? "0 PH" : totals.shortText
    }

    private var focusDetail: String {
        GlanceText.weekPowerHours(context.workTotals().powerHours, target: context.workTarget)
    }

    private var expensesValue: String {
        guard let measure = context.expenseMeasure else { return Format.euro(0) }
        return Format.euro(context.dayValue(measure, on: day) ?? 0)
    }

    private var expensesDetail: String {
        guard let measure = context.expenseMeasure, let week = context.weekValue(measure) else { return "erfassen" }
        return "Woche \(Format.euro(week))"
    }

    /// "6/10" weekly targets met – counted like the PDF and the report (R16).
    private var targetsValue: String {
        let count: Int = context.weeklyTargets.count
        return count == 0 ? "–" : "\(context.weeklyTargetsMet)/\(count)"
    }

    private var targetsDetail: String {
        context.weeklyTargets.isEmpty ? "keine Wochenziele" : "erreicht"
    }
}

private struct GlanceTile: View {
    let symbol: String
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                // Icon and text separately, so a long title ("Wochenziele") shrinks instead of
                // being cut off in a narrow tile.
                HStack(spacing: 4) {
                    Image(systemName: symbol)
                        .imageScale(.small)
                    Text(title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .accessibilityElement(children: .combine)
                Text(value)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: .rect(cornerRadius: 16, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Öffnet \(title)")
    }
}

/// "Noch zu tun": the blank required items by category (R5 – as many as the ring counts); a tap
/// jumps there. With nothing open, `onClose` offers "Tag abschließen" (R50).
struct OpenToDoSection: View {
    let context: WeekContext
    let day: DayKey
    let onOpen: (TodayPage) -> Void
    var onClose: (() -> Void)? = nil

    var body: some View {
        let open: [PlanItem] = context.openToDo(on: day)
        let byCategory: [String: [PlanItem]] = Dictionary(grouping: open, by: \.categoryKey)
        let keys: [String] = context.categories.map(\.key).filter { byCategory[$0] != nil }
        Section {
            if open.isEmpty && context.isExcused(day) {
                // v8: nothing is due on a sick or holiday day.
                Label("\(context.excusedName(day)) – heute ist nichts fällig.", systemImage: DayTypes.symbol(for: context.dayType(day)))
                    .foregroundStyle(.secondary)
            } else if open.isEmpty {
                Label("Alles Wichtige ist erfasst.", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                if let onClose {
                    Button(action: onClose) {
                        Label("Tag abschließen", systemImage: "moon.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .thaliaPrimaryAction()
                }
            }
            ForEach(keys, id: \.self) { key in
                Button {
                    onOpen(.category(key))
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        KeyBadge(key: key)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(byCategory[key] ?? []) { item in
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text(OpenToDoSection.heading(count: open.count))
        }
    }

    /// "Noch zu tun" · "Noch zu tun · 3".
    static func heading(count: Int) -> String {
        count == 0 ? "Noch zu tun" : "Noch zu tun · \(count)"
    }
}

/// "Diese Woche noch · n": n×-per-week items due today whose quota isn't reached yet, with
/// "2 von 3 diese Woche" (R5); a tap jumps to the category.
struct WeeklyOpenSection: View {
    let context: WeekContext
    let day: DayKey
    let onOpen: (TodayPage) -> Void

    var body: some View {
        let open: [PlanItem] = context.openWeeklyToDo(on: day)
        if !open.isEmpty {
            Section {
                ForEach(open) { item in
                    Button {
                        onOpen(.category(item.categoryKey))
                    } label: {
                        HStack(spacing: 10) {
                            KeyBadge(key: item.categoryKey)
                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(quotaText(item))
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Diese Woche noch · \(open.count)")
            }
        }
    }

    /// "2 von 3 diese Woche"; v8: "… · ½ krank" when sick or holiday days make the rest count half.
    private func quotaText(_ item: PlanItem) -> String {
        guard let quota = context.quotaProgress(item) else { return "" }
        let base: String = "\(quota.done) von \(quota.target) diese Woche"
        guard quota.done < quota.target, context.quotaShare(item) > 1e-9 else { return base }
        return base + " · ½ " + context.excusedWord(context.excusedDayList)
    }
}

// MARK: Yesterday (R94)

/// "So, 15. Nov. · 3 offen": yesterday had a plan and isn't closed – catch up or close it. Hidden
/// per day with ×; gone once the day is closed.
struct YesterdayBanner: View {
    enum Style {
        case card, sidebar
    }

    let today: DayKey
    let style: Style
    @Environment(AppModel.self) private var app
    @AppStorage("yesterday.dismissed") private var dismissed = ""

    init(today: DayKey, style: Style = .card) {
        self.today = today
        self.style = style
    }

    private var yesterday: DayKey { today.adding(days: -1) }

    var body: some View {
        WeekReader(week: yesterday.week, today: today) { context in
            if isVisible(context) {
                switch style {
                case .card:
                    card(summary(context))
                case .sidebar:
                    sidebar(summary(context))
                }
            }
        }
    }

    /// v8: never for a sick or holiday day – it doesn't count, so nothing is left open.
    private func isVisible(_ context: WeekContext) -> Bool {
        guard dismissed != yesterday.string, context.hasPlan, !context.isClosed(yesterday),
              !context.isExcused(yesterday) else { return false }
        return !context.items(on: yesterday).isEmpty
    }

    /// "So, 15. Nov. · 3 offen" / "So, 15. Nov. · nicht abgeschlossen".
    private func summary(_ context: WeekContext) -> String {
        let open: Int = context.openCount(on: yesterday)
        if open > 0 { return "\(yesterday.shortLabel) · \(open) offen" }
        return "\(yesterday.shortLabel) · nicht abgeschlossen"
    }

    private func card(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.zzz.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                HStack(spacing: 8) {
                    Button("Nachtragen", action: catchUp)
                        .buttonStyle(.bordered)
                    Button("Abschließen", action: close)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentFill)
                }
                .controlSize(.small)
            }
            Spacer(minLength: 4)
            Button(action: hide) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Ausblenden")
            .help("Ausblenden")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
    }

    /// Mac sidebar: two grey lines, the second with links.
    private func sidebar(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(text, systemImage: "moon.zzz.fill")
                .monospacedDigit()
            HStack(spacing: 10) {
                Button("Nachtragen", action: catchUp)
                Button("Abschließen", action: close)
                Spacer(minLength: 0)
                Button(action: hide) {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Ausblenden")
                .help("Ausblenden")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Brand.accent)
        }
        .padding(.horizontal, 6)
    }

    /// Today on yesterday, to fill in what's missing.
    private func catchUp() {
        if case .dayOverview(_)? = app.sheet { app.sheet = nil }
        app.selectedDay = yesterday
        app.selectedWeek = yesterday.week
        app.todayPage = nil
        app.tab = .today
        app.sidebar = .today
    }

    private func close() {
        app.sheet = .closeDay(yesterday)
    }

    private func hide() {
        dismissed = yesterday.string
    }
}

// MARK: Wochenziele (R16)

/// All weekly targets of a week with their pace – the same list as Week and "Heute im Blick".
struct WeeklyGoalsSheet: View {
    let week: WeekKey
    @Environment(\.dismiss) private var dismiss

    init(week: WeekKey) {
        self.week = week
    }

    var body: some View {
        NavigationStack {
            WeeklyGoalsPage(week: week)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 480, height: 560)
    }
}

/// "Wochenziele · KW47" – its own sheet or pushed inside "Heute im Blick" (R51).
struct WeeklyGoalsPage: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app

    init(week: WeekKey) {
        self.week = week
    }

    var body: some View {
        WeekReader(week: week, today: app.today) { context in
            List {
                Section {
                    WeeklyTargetsList(context: context)
                }
                // v10 (§1.2.4): the measures that feed a result – "zählt für Ziel 5 · Bücher 3/10".
                WeeklyCountsForSection(context: context)
            }
            .compactListSections()
        }
        .navigationTitle("Wochenziele · \(week.label)")
        .inlineNavigationTitle()
    }
}

// MARK: Mac sidebar (F4.1)

/// Grey, always visible under the navigation: today and the week in a few lines. "HEUTE" shows
/// "Heute im Blick" as the right column (R59), the other lines open their view.
struct SidebarGlance: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let _ = diagBody("SidebarGlance")
        WeekReader(week: app.today.week, today: app.today) { context in
            SidebarGlanceText(context: context, day: app.today)
        }
    }
}

private struct SidebarGlanceText: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    /// "73 % erfasst · 11 offen" – the ring's count (R5).
    private var dayLine: String {
        guard context.hasPlan else { return "Kein Plan" }
        return GlanceText.dayLine(context.score.days[day], closed: context.isClosed(day), open: context.openCount(on: day),
                                  type: context.dayType(day))
    }

    /// The plan's note for today (R90).
    private var dayNote: String {
        context.dayNote(day).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var focusLine: String {
        GlanceText.focusLine(today: context.workTotals(on: day), week: context.workTotals(), target: context.workTarget)
    }

    private func expensesLine(_ measure: MeasureDefinition) -> String {
        GlanceText.expensesLine(today: context.dayValue(measure, on: day), week: context.weekValue(measure))
    }

    /// The right column is showing next to Today.
    private var isGlanceShown: Bool {
        (app.sidebar ?? .today) == .today && app.showsGlanceInspector
    }

    private var glanceHelp: String {
        isGlanceShown ? "Heute im Blick ausblenden" : "Heute im Blick einblenden"
    }

    /// Like ⌘0 and the ring (R59): shows the column next to Today, or hides it when it shows.
    private func toggleGlance() {
        let shown: Bool = isGlanceShown
        app.sidebar = .today
        app.showsGlanceInspector = !shown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SidebarLink(help: glanceHelp, action: toggleGlance) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HEUTE · \(day.shortLabel.uppercased())")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.6)
                    Text(dayLine)
                        .monospacedDigit()
                    if !dayNote.isEmpty {
                        Text("Besonderheit: \(dayNote)")
                            .lineLimit(2)
                    }
                }
            }
            YesterdayBanner(today: day, style: .sidebar)
            SidebarLink(help: "Fokus öffnen") {
                app.sheet = .focus(day)
            } content: {
                Text(focusLine)
            }
            if let expenses = context.expenseMeasure {
                SidebarLink(help: "Ausgaben öffnen") {
                    app.sheet = .expenses(day)
                } content: {
                    Text(expensesLine(expenses))
                }
            }
            SidebarLink(help: "Woche öffnen") {
                app.sidebar = .week
                app.selectedWeek = day.week
            } content: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("WOCHE · \(context.week.label)")
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.6)
                    Text(GlanceText.weekLine(context.score))
                    ForEach(context.weeklyTargets.prefix(3)) { target in
                        Text(GlanceText.targetLine(target))
                            .lineLimit(1)
                    }
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
    }
}

/// A grey sidebar line that shows on hover that it can be clicked, with a tooltip (R59).
private struct SidebarLink<Content: View>: View {
    let help: String
    let action: () -> Void
    let content: Content
    @State private var hovering = false

    init(help: String, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.help = help
        self.action = action
        self.content = content()
    }

    private var hoverFill: Color {
        hovering ? Color.primary.opacity(0.07) : Color.clear
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(hoverFill, in: .rect(cornerRadius: 6, style: .continuous))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}
