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
    let onSaved: (Double, String) -> Void

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

/// Area first – the business areas on top.
struct WatchPowerHourPicker: View {
    let context: WeekContext

    var body: some View {
        let business = context.categories.filter { $0.goalKey == "3" && $0.key != "3.1" }
        let areas: [TrackCategory] = business.isEmpty ? context.categories : business
        List {
            ForEach(areas) { category in
                NavigationLink(value: WatchRoute.powerHourEntry(categoryKey: category.key)) {
                    Text("\(category.key) \(category.title)")
                }
            }
        }
        .navigationTitle("Bereich")
    }
}

/// R48: amount (crown, 0,25–8 PH, starts at 1 PH) and "Wofür" (K1) on one screen. A recent
/// description saves with one tap, a dictated one with "Sichern".
struct WatchPowerHourEntry: View {
    let category: TrackCategory
    let day: DayKey
    let onSaved: (Double, String) -> Void
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
        store.addWork(day: day, categoryKey: category.key, task: description, powerHours: value)
        onSaved(value, category.title)
    }
}
