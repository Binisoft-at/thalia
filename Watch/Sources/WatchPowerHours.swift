import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// Page 1's navigation (R48): value based, so "Sichern" can clear the whole stack at once.
enum WatchRoute: Hashable {
    case powerHours
    case powerHourEntry(categoryKey: String)
}

/// The screens behind page 1's navigation path.
struct WatchRouteView: View {
    let route: WatchRoute
    let context: WeekContext
    /// The saved block (for "Widerrufen", v11 P8.7), its power-hours and the area's title.
    let onSaved: (WorkBlock, Double, String) -> Void

    var body: some View {
        switch route {
        case .powerHours:
            WatchPowerHourPicker(context: context)
        case .powerHourEntry(let key):
            if let category = context.category(key) {
                WatchPowerHourEntry(category: category, day: context.today, onSaved: onSaved)
            } else {
                Text("Diesen Bereich gibt es nicht mehr.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Area first – the business areas on top, each with its week (v11 P8.10); below, today's own power-hours with
/// "Löschen" (v11 P8.7).
struct WatchPowerHourPicker: View {
    let context: WeekContext
    @Environment(\.modelContext) private var modelContext

    /// v11 P8.11: no areas yet – the plan comes from the iPhone over iCloud.
    static let emptyText = "Noch keine Bereiche. Öffne Thalia am iPhone und warte kurz auf iCloud."

    var body: some View {
        let areas: [TrackCategory] = WatchPowerHourPicker.areas(context)
        let blocks: [WorkBlock] = WatchPowerHourPicker.todayBlocks(context)
        List {
            if areas.isEmpty {
                Text(WatchPowerHourPicker.emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(areas) { category in
                NavigationLink(value: WatchRoute.powerHourEntry(categoryKey: category.key)) {
                    WatchAreaLabel(category: category, week: WatchPowerHourPicker.weekTarget(for: category, in: context))
                }
            }
            if !blocks.isEmpty {
                Section {
                    ForEach(blocks) { block in
                        Text(WatchPowerHourPicker.blockText(block))
                            .font(.footnote)
                            .lineLimit(2)
                            .swipeActions(edge: .trailing) {
                                Button("Löschen", role: .destructive) {
                                    delete(block)
                                }
                            }
                    }
                } header: {
                    Text("Heute erfasst")
                }
            }
        }
        .navigationTitle("Bereich")
    }

    /// The business areas (goal 3 without the morning routine), else all categories.
    static func areas(_ context: WeekContext) -> [TrackCategory] {
        let business = context.categories.filter { $0.goalKey == "3" && $0.key != "3.1" }
        return business.isEmpty ? context.categories : business
    }

    /// v11 P8.7: today's own power-hours, newest first – never the derived ones ("aus Theo", read only).
    static func todayBlocks(_ context: WeekContext) -> [WorkBlock] {
        context.work(on: context.today).sorted { $0.createdAt > $1.createdAt }
    }

    /// "1 PH · 3.2 · Aufgabe"
    static func blockText(_ block: WorkBlock) -> String {
        "\(Format.powerHours(block.hours)) · \(block.categoryKey) · \(block.task)"
    }

    /// v11 P8.10: the week's target of a measurement fed by this area's power-hours (`arbeit:<area>`), scaled for
    /// sick and holiday days like the widget; nil without one.
    static func weekTarget(for category: TrackCategory, in context: WeekContext) -> WeeklyTarget? {
        context.weeklyTargets.first { target in
            guard case .work(let key)? = context.record(target.measure)?.source else { return false }
            return key == category.key
        }
    }

    /// v11 P8.7: "Löschen" – the block goes to "Zuletzt gelöscht" (restorable there).
    private func delete(_ block: WorkBlock) {
        TrackerStore(context: modelContext).trash([block])
        WatchHaptic.click.play()
    }
}

/// An area in the picker: "3.2 stammloop" and, with a weekly target, "6/8 PH · Woche" (green once met, v11 P8.10).
private struct WatchAreaLabel: View {
    let category: TrackCategory
    let week: WeeklyTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(category.key) \(category.title)")
            if let week {
                Text(WatchAreaLabel.weekText(week))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(WatchAreaLabel.weekColor(week))
            }
        }
    }

    /// "6/8 PH · Woche" – the value and the scaled target as screens show them (P1.7).
    static func weekText(_ week: WeeklyTarget) -> String {
        let value: String = Format.amount(week.value, unit: week.unit)
        let target: String = Format.amount(target: week.target, unit: week.unit)
        return "\(value)/\(target) \(week.unit) · Woche"
    }

    static func weekColor(_ week: WeeklyTarget) -> Color {
        week.isMet ? Color.green : Color.secondary
    }
}

/// R48: amount (crown, 0,25–8 PH, starts at 1 PH) and "Wofür" (K1) on one screen. A recent
/// description saves with one tap, a dictated one with "Sichern".
struct WatchPowerHourEntry: View {
    let category: TrackCategory
    let day: DayKey
    /// The saved block (v11 P8.7: "Widerrufen" on page 1), its power-hours and the area's title.
    let onSaved: (WorkBlock, Double, String) -> Void
    @Environment(\.modelContext) private var modelContext
    @State private var amount: Double = 1
    @State private var task = ""
    @State private var suggestions: [String] = []

    private var store: TrackerStore { TrackerStore(context: modelContext) }
    private var what: String { task.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var powerHours: Double { WatchPowerHourEntry.snap(amount) }

    /// Quarter steps between 0,25 and 8 PH.
    static func snap(_ value: Double) -> Double {
        min(8, max(0.25, (value * 4).rounded() / 4))
    }

    var body: some View {
        let shown = Format.powerHours(powerHours)
        List {
            Section {
                HStack(spacing: 4) {
                    Button {
                        amount = WatchPowerHourEntry.snap(powerHours - 0.25)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Weniger")
                    Text(shown)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .focusable()
                        .digitalCrownRotation($amount, from: 0.25, through: 8, by: 0.25, sensitivity: .low,
                                              isContinuous: false, isHapticFeedbackEnabled: true)
                        .accessibilityLabel("Menge")
                        .accessibilityValue(shown)
                    Button {
                        amount = WatchPowerHourEntry.snap(powerHours + 0.25)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .tint(Brand.accent)
                    .accessibilityLabel("Mehr")
                }
            } header: {
                Text("Menge")
            }
            Section {
                TextField("Wofür? (diktieren)", text: $task)
                Button("Sichern") {
                    save(what)
                }
                .disabled(what.isEmpty)
                .tint(Brand.accent)
            } header: {
                Text("Wofür")
            }
            if !suggestions.isEmpty {
                Section {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) {
                            save(suggestion)
                        }
                    }
                } header: {
                    Text("Zuletzt")
                }
            }
        }
        .navigationTitle(category.title)
        .onAppear {
            suggestions = store.workSuggestions(categoryKey: category.key, limit: 6)
        }
    }

    private func save(_ text: String) {
        let description = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else { return }
        let value = powerHours
        // v11 P8.7: the block goes along, so the banner on page 1 can take it back.
        let block = store.addWork(day: day, categoryKey: category.key, task: description, powerHours: value)
        onSaved(block, value, category.title)
    }
}
