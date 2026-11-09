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

    var body: some View {
        List {
            Section {
                header
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))

            targetsSection

            if context.hasPlan {
                ForEach(context.goals) { goal in
                    ForEach(context.categories(of: goal)) { category in
                        categorySection(category)
                    }
                }
                Section {
                    Button {
                        app.sheet = .newItem(context.week, categoryKey: nil)
                    } label: {
                        Label("Punkt hinzufügen", systemImage: "plus")
                    }
                } footer: {
                    Text("So viele Punkte pro Kategorie wie nötig. Messwerte sind keine Punkte – sie schlagen nur einen Haken vor.")
                }
            } else {
                Section { NoPlanView(week: context.week) }
            }
        }
        .compactListSections()
        .navigationTitle("Woche")
        .toolbar { MainToolbar() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    withAnimation(.snappy) { app.selectedWeek = context.week.adding(weeks: -1) }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Vorige Woche")
                .keyboardShortcut("[", modifiers: [.command, .shift])
                VStack(spacing: 0) {
                    Text(context.week.longLabel)
                        .font(.title3.weight(.bold))
                    Text(context.week.rangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Button {
                    withAnimation(.snappy) { app.selectedWeek = context.week.adding(weeks: 1) }
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Nächste Woche")
                .keyboardShortcut("]", modifiers: [.command, .shift])
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)

            if context.week != app.today.week {
                Button("Zur aktuellen Woche") { app.selectedWeek = app.today.week }
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }

            HeroCard(title: "Woche \(context.week.label)",
                     subtitle: context.score.goalsTotal == 0 ? "Noch keine Ziele" : context.score.coverageText,
                     value: Format.score(context.score.overall, outOf: false), caption: "Woche",
                     progress: (context.score.overall ?? 0) / 10,
                     facts: [("Fokus", context.workTotals().isEmpty ? "–" : context.workTotals().shortText),
                             ("Tage abgeschlossen", "\(context.week.days.filter { context.isClosed($0) }.count)/7")])
            VStack(alignment: .leading, spacing: 6) {
                GoalBars(scores: context.goals.map { context.score.goalWeek[$0.key]?.score })
                Button {
                    app.sheet = .explainer(.scoring)
                } label: {
                    Label("Je Ziel 10 % – wie wird gerechnet?", systemImage: "questionmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Brand.accent)
            }
            .card(padding: 14)

            dayTypes

            if let plan = context.plan, !(plan.title.isEmpty && plan.details.isEmpty) {
                VStack(alignment: .leading, spacing: 6) {
                    if !plan.title.isEmpty {
                        Text(plan.title).font(.headline)
                    }
                    if !plan.details.isEmpty {
                        Text(plan.details)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(showContext ? nil : 3)
                        Button(showContext ? "Weniger" : "Wochenkontext ganz zeigen") {
                            withAnimation(.snappy) { showContext.toggle() }
                        }
                        .font(.caption)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(padding: 14)
                .contextMenu {
                    Button("Bearbeiten…", systemImage: "pencil") { app.sheet = .weekInfo(context.week) }
                }
            }

            actions
        }
    }

    private var dayTypes: some View {
        HStack(spacing: 4) {
            ForEach(context.week.days, id: \.self) { day in
                Button {
                    app.sheet = .dayInfo(day)
                } label: {
                    VStack(spacing: 3) {
                        Text(day.weekday.short)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(day == context.today ? Brand.accent : .secondary)
                        Image(systemName: DayTypes.symbol(for: context.dayType(day)))
                            .font(.caption)
                        Text(Format.score(context.score.days[day]?.score, outOf: false))
                            .font(.system(.caption2, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(context.isClosed(day) ? Brand.accent.opacity(0.12) : Color.clear, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day.weekday.name): \(context.dayType(day).isEmpty ? "kein Tagestyp" : context.dayType(day))")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            if context.isClosed {
                Button {
                    app.sheet = .closeWeek(context.week)
                } label: {
                    Label("Abgeschlossen", systemImage: "checkmark.seal.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Brand.accent)
            } else {
                Button {
                    app.sheet = .closeWeek(context.week)
                } label: {
                    Label("Woche abschließen", systemImage: "flag.checkered")
                        .frame(maxWidth: .infinity)
                }
                .primaryActionStyle()
            }
            HStack(spacing: 8) {
                Button {
                    app.sheet = .report(context.week)
                } label: {
                    Label("Bericht", systemImage: "doc.text")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button {
                    app.sheet = .importPlan(prompt: true)
                } label: {
                    Label("Planen", systemImage: "sparkles")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.subheadline.weight(.semibold))
    }

    // MARK: Weekly targets

    @ViewBuilder
    private var targetsSection: some View {
        let weekly = context.measures.filter { $0.record?.period == .week && $0.record?.target != nil }
        let totals = context.workTotals()
        if !weekly.isEmpty || !totals.isEmpty {
            Section {
                ForEach(weekly) { measure in
                    if let record = measure.record, let target = record.target {
                        let pace = Pace(done: context.weekValue(measure) ?? 0, target: target.scaleMax, days: record.days,
                                        week: context.week, today: context.today)
                        PaceRow(title: measure.title, unit: Units.display(measure.unit), pace: pace, isLimit: target.isLimit)
                    }
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
            } header: {
                SectionHeading(title: "Wochenziele", symbol: "target")
            } footer: {
                Text("Die Linie zeigt ein gleichmäßiges Tempo über die geplanten Tage – keine Aufforderung, mehr zu machen.")
            }
        }
    }

    // MARK: The sheet

    private func categorySection(_ category: TrackCategory) -> some View {
        let items = context.items(in: category)
        let isCollapsed = collapsed.contains(category.key)
        return Section {
            if !isCollapsed && !items.isEmpty {
                DayHeaderRow(context: context, categoryKey: category.key)
                ForEach(items) { item in
                    WeekItemRow(context: context, item: item)
                }
            } else if items.isEmpty {
                Text("Keine Punkte in dieser Woche")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Button {
                withAnimation(.snappy) {
                    if isCollapsed { collapsed.remove(category.key) } else { collapsed.insert(category.key) }
                }
            } label: {
                HStack(spacing: 8) {
                    KeyBadge(key: category.key)
                    Text(category.title).lineLimit(1)
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
                    Text(entry.score.map { Format.score($0) } ?? "·")
                        .font(.system(size: 10, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(entry.knockedOut ? Color.orange : Color.secondary)
                }
                .frame(width: 30)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One item: title and seven cells.
struct WeekItemRow: View {
    let context: WeekContext
    let item: PlanItem
    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(spacing: 3) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.subheadline)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if item.isKnockout {
                        Image(systemName: "exclamationmark.octagon").foregroundStyle(.orange)
                    }
                    if let quota = context.quotaProgress(item) {
                        Text("\(quota.done)/\(quota.target)×")
                            .foregroundStyle(quota.done >= quota.target ? .green : .secondary)
                    } else if item.schedule != .fixed {
                        Text(item.schedule.label).foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .onTapGesture { app.sheet = .item(item, app.today.week == context.week ? app.today : context.week.monday) }
            ForEach(context.week.days, id: \.self) { day in
                MarkCell(
                    mark: context.mark(item, on: day),
                    applies: item.days.contains(day.weekday) && item.schedule != .optional,
                    isToday: day == context.today,
                    suggestion: context.suggestion(item, on: day),
                    options: context.options(item, on: day),
                    onSet: { app.setMark($0, item: item, day: day) }
                )
                .frame(width: 30, height: 30)
            }
        }
        .contextMenu {
            Button("Details…", systemImage: "info.circle") { app.sheet = .item(item, context.today) }
            Button("Löschen", systemImage: "trash", role: .destructive) { app.trash([item]) }
        }
    }
}

/// Weekly target with an even-pace marker (no streaks, no pressure).
struct PaceRow: View {
    let title: String
    let unit: String
    let pace: Pace
    var isLimit = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(pace.label(unit: unit))
                    .font(.caption)
                    .foregroundStyle(pace.isReached ? .green : (pace.isBehind && !isLimit ? .orange : .secondary))
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15))
                    Capsule().fill(pace.isReached ? Color.green : Brand.accent)
                        .frame(width: geometry.size.width * pace.fraction)
                    if pace.target > 0, !pace.isReached {
                        Rectangle()
                            .fill(Color.primary.opacity(0.5))
                            .frame(width: 2, height: 12)
                            .offset(x: geometry.size.width * min(1, pace.expected / pace.target) - 1)
                    }
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(pace.label(unit: unit))")
    }
}
