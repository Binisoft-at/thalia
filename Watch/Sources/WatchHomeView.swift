import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// Today on the wrist (U16): how much is filled in, quick power-hours, then one page per category
/// with something open – ✓ with one tap, everything else with two, values with − / +.
struct WatchHomeView: View {
    @State private var today = DayKey.today()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        WeekReader(week: today.week, today: today) { context in
            let pages = context.categories.filter { category in
                context.items.contains { $0.categoryKey == category.key && context.applies($0, on: today) && !context.isDerived($0) }
                    || context.measures.contains { $0.categoryKey == category.key && context.applies($0, on: today) && WatchMeasureRow.isQuick($0) }
            }
            TabView {
                NavigationStack { WatchTodayPage(context: context, pages: pages) }
                ForEach(pages) { category in
                    NavigationStack { WatchCategoryPage(context: context, category: category) }
                }
            }
            .tabViewStyle(.verticalPage)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { today = .today() }
        }
    }
}

private struct WatchTodayPage: View {
    let context: WeekContext
    let pages: [TrackCategory]

    private var day: DayKey { context.today }

    var body: some View {
        let overall = context.score.days[day]
        let closed = context.isClosed(day)
        let work = context.workTotals(on: day)
        let coverage: Double = overall?.coverage ?? 0
        let score: Double = overall?.score ?? 0
        let gaugeValue: Double = closed ? score / 10 : coverage
        let percent: Int = Int((coverage * 100).rounded())
        let label: String = closed ? Format.score(overall?.score, outOf: false) : "\(percent)"
        let tint: Color = (!closed && coverage >= 1) ? .green : Brand.accent
        let status: String = Self.status(overall, closed: closed)
        ScrollView {
            VStack(spacing: 10) {
                Gauge(value: gaugeValue, in: 0...1) {
                    Text(closed ? "Tag" : "%")
                } currentValueLabel: {
                    Text(label)
                }
                .gaugeStyle(.accessoryCircular)
                .tint(tint)
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(work.isEmpty ? "Noch keine PH" : work.shortText)
                    .font(.footnote.weight(.semibold))
                NavigationLink {
                    WatchPowerHourPicker(context: context)
                } label: {
                    Label("Power-Hours", systemImage: "bolt.fill")
                }
                .tint(Brand.accent)
                if !pages.isEmpty {
                    Text("Nach oben wischen: \(pages.count) Kategorien")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .navigationTitle(day.weekday.name)
    }

    static func status(_ overall: DayOverall?, closed: Bool) -> String {
        if closed { return "Abgeschlossen" }
        guard let overall else { return "Nichts fällig" }
        return overall.blank == 0 ? "Alles erfasst" : "\(overall.blank) offen"
    }
}

/// Area, then amount – two taps for "+1 PH stammloop".
private struct WatchPowerHourPicker: View {
    let context: WeekContext

    var body: some View {
        let business = context.categories.filter { $0.goalKey == "3" && $0.key != "3.1" }
        List {
            ForEach(business.isEmpty ? context.categories : business) { category in
                NavigationLink("\(category.key) \(category.title)") {
                    WatchPowerHourAmounts(category: category, day: context.today)
                }
            }
        }
        .navigationTitle("Bereich")
    }
}

private struct WatchPowerHourAmounts: View {
    let category: TrackCategory
    let day: DayKey
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(PowerHour.quick, id: \.self) { value in
                Button {
                    TrackerStore(context: modelContext).addWork(day: day, categoryKey: category.key, task: "", powerHours: value)
                    dismiss()
                } label: {
                    Label("+ \(Format.powerHours(value))", systemImage: "bolt.fill")
                }
            }
        }
        .navigationTitle(category.title)
    }
}

private struct WatchCategoryPage: View {
    let context: WeekContext
    let category: TrackCategory

    private var day: DayKey { context.today }

    var body: some View {
        let entry = context.score.category(category.key, on: day)
        let items = context.items.filter {
            $0.categoryKey == category.key && context.applies($0, on: day) && !context.isDerived($0) && !context.isQuotaMetElsewhere($0, on: day)
        }
        let measures = context.measures.filter { $0.categoryKey == category.key && context.applies($0, on: day) && WatchMeasureRow.isQuick($0) }
        List {
            Section {
                ForEach(items) { item in
                    WatchItemRow(item: item, context: context)
                }
            } header: {
                HStack {
                    Text(category.title)
                    Spacer()
                    if entry.due > 0 {
                        Text(entry.isComplete ? "✓" : "\(entry.due - entry.blank)/\(entry.due)")
                            .monospacedDigit()
                    }
                }
            }
            if !measures.isEmpty {
                Section("Werte") {
                    ForEach(measures) { measure in
                        WatchMeasureRow(measure: measure, context: context)
                    }
                }
            }
        }
        .navigationTitle(category.key)
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
        HStack(spacing: 8) {
            Button {
                TrackerStore(context: modelContext).setMark(mark == .done ? nil : .done, item: item, day: day)
            } label: {
                Image(systemName: mark.watchSymbol)
                    .font(.title3)
                    .foregroundStyle(mark.watchColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mark == .done ? "Erledigt – tippen zum Leeren" : "Als erledigt markieren")
            NavigationLink {
                WatchMarkPicker(item: item, context: context)
            } label: {
                Text(item.title)
                    .font(.footnote)
                    .lineLimit(3)
            }
        }
    }
}

private struct WatchMarkPicker: View {
    let item: PlanItem
    let context: WeekContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let day = context.today
        let options = item.record.map { Scorer.options(for: $0, on: day, data: context.data) } ?? Mark.allCases
        ScrollView {
            VStack(spacing: 8) {
                Text(item.title)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            TrackerStore(context: modelContext).setMark(option, item: item, day: day)
                            dismiss()
                        } label: {
                            Text(item.schedule == .progress ? (option == .done ? "✓" : "Nicht heute") : (option == .notApplicable ? "N/A" : option.symbol))
                                .font(.title3.weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .tint(Optional(option).watchColor)
                    }
                }
                if context.mark(item, on: day) != nil {
                    Button("Leeren", role: .destructive) {
                        TrackerStore(context: modelContext).setMark(nil, item: item, day: day)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// A number with − / + (time and text values stay on the phone).
struct WatchMeasureRow: View {
    let measure: MeasureDefinition
    let context: WeekContext
    @Environment(\.modelContext) private var modelContext

    static func isQuick(_ measure: MeasureDefinition) -> Bool {
        guard let record = measure.record else { return false }
        if case .work = record.source { return false }
        return !record.isText && !record.isTime
    }

    var body: some View {
        let day = context.today
        let value = context.dayValue(measure, on: day)
        let step = Units.step(measure.unit)
        VStack(alignment: .leading, spacing: 4) {
            Text(measure.title)
                .font(.footnote)
            HStack {
                Button {
                    TrackerStore(context: modelContext).setDayValue(code: measure.code, day: day, value: max(0, (value ?? 0) - step))
                } label: {
                    Image(systemName: "minus")
                }
                .disabled((value ?? 0) <= 0)
                Text(value.map { Format.measure($0, unit: measure.unit) } ?? "–")
                    .font(.headline.monospacedDigit())
                    .frame(maxWidth: .infinity)
                Button {
                    TrackerStore(context: modelContext).setDayValue(code: measure.code, day: day, value: (value ?? 0) + step)
                } label: {
                    Image(systemName: "plus")
                }
                .tint(Brand.accent)
            }
            .buttonStyle(.bordered)
        }
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
