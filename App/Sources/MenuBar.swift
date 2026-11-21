/// Thalia in the Mac menu bar (R96): today's status, power-hours and a spending without opening
/// the window. On by default, switch in Settings. (The key is known on every platform, because
/// AppModel reads it.)
enum MenuBarSettings {
    static let enabledKey = "menubar.enabled"
}

#if os(macOS)
import SwiftUI
import SwiftData
import AppKit
import BinisoftKit
import ThaliaCore

/// The label in the menu bar: the symbol and "73 %" / "7,5" – only the symbol without a plan.
/// Deliberately just text and an image (no query): that is what the menu bar shows reliably.
struct MenuBarLabel: View {
    let title: String

    var body: some View {
        if title.isEmpty {
            Image(systemName: "sun.max")
        } else {
            HStack(spacing: 4) {
                Image(systemName: "sun.max")
                Text(title)
                    .monospacedDigit()
            }
        }
    }
}

/// The menu bar window.
struct MenuBarContent: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openWindow) private var openWindow

    @State private var combos: [WorkCombo] = []
    @State private var categories: [MenuBarCategory] = []
    @State private var categoryKey = ""
    @State private var powerHours: Double = 1
    @State private var task = ""
    @State private var amountText = ""
    @State private var purpose = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WeekReader(week: app.today.week, today: app.today) { context in
                MenuBarStatus(context: context, day: app.today)
            }
            Divider()
            workSection
            Divider()
            expenseSection
            if !confirmation.isEmpty {
                Label(confirmation, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Divider()
            HStack {
                Button("Thalia öffnen", systemImage: "macwindow") { openMain() }
                Spacer()
                Button("Tag abschließen…", systemImage: "moon.stars") { closeDay() }
            }
        }
        .padding(14)
        .frame(width: 330)
        .onAppear(perform: reload)
        // Areas and "recent" combos from other devices (R96).
        .onChange(of: app.syncTick) { _, _ in reload() }
    }

    // MARK: Power-hours

    private var workSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Power-Hours")
                .font(.subheadline.weight(.semibold))
            ForEach(combos) { combo in
                Button {
                    fill(combo)
                } label: {
                    Text(comboText(combo))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .help("Füllt Bereich, Menge und Wofür")
            }
            Picker("Bereich", selection: $categoryKey) {
                Text("Bereich wählen").tag("")
                ForEach(categories) { category in
                    Text(category.label).tag(category.key)
                }
            }
            .pickerStyle(.menu)
            Stepper(value: $powerHours, in: 0.25...8, step: 0.25) {
                Text("Menge: \(Format.powerHours(powerHours))")
                    .monospacedDigit()
            }
            HStack {
                TextField("Wofür?", text: $task)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveWork)
                Button("Erfassen", action: saveWork)
                    .disabled(!canSaveWork)
            }
        }
    }

    private var canSaveWork: Bool {
        !categoryKey.isEmpty && !task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func comboText(_ combo: WorkCombo) -> String {
        "\(combo.categoryKey) · \(combo.task) · \(Format.powerHours(combo.powerHours))"
    }

    /// A tap fills the form; "Erfassen" saves it (the area stays a deliberate choice, K1).
    private func fill(_ combo: WorkCombo) {
        categoryKey = combo.categoryKey
        powerHours = min(max(combo.powerHours, 0.25), 8)
        task = combo.task
    }

    private func saveWork() {
        guard canSaveWork else { return }
        let what: String = task.trimmingCharacters(in: .whitespacesAndNewlines)
        app.addPowerHours(powerHours, categoryKey: categoryKey, task: what, day: app.today)
        confirmation = "\(Format.powerHours(powerHours)) · \(what) erfasst"
        task = ""
        reload()
    }

    // MARK: Spending

    private var expenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ausgabe")
                .font(.subheadline.weight(.semibold))
            HStack {
                TextField("Betrag", text: $amountText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                Text("€")
                    .foregroundStyle(.secondary)
                TextField("Wofür?", text: $purpose)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveExpense)
                Button("Erfassen", action: saveExpense)
                    .disabled(!canSaveExpense)
            }
        }
    }

    private var amount: Double? {
        guard let value = Format.parse(amountText), value > 0, value.isFinite else { return nil }
        return value
    }

    private var canSaveExpense: Bool {
        amount != nil && !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Every spending with what it was for (K2); creates the week's spending measurement if needed (R97).
    private func saveExpense() {
        guard canSaveExpense, let amount else { return }
        let day: DayKey = app.today
        guard let measure = app.store.expenseMeasure(week: day.week, create: true) else { return }
        let what: String = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        app.addExpense(amount, what: what, measure: measure, day: day)
        confirmation = "\(Format.euro(amount)) · \(what) erfasst"
        amountText = ""
        purpose = ""
    }

    // MARK: Window

    private func openMain() {
        MainWindow.show(openWindow)
    }

    private func closeDay() {
        openMain()
        guard !app.blocksSheetCommands else { return }
        app.sheet = .closeDay(app.dayToClose())
    }

    private func reload() {
        let store = app.store
        combos = store.recentWorkCombos(limit: 3)
        categories = Array(store.liveCategories().latest(by: \.key, modified: \.modifiedAt).values)
            .sorted { CategoryRecord.sortKey($0.key).lexicographicallyPrecedes(CategoryRecord.sortKey($1.key)) }
            .map { MenuBarCategory(key: $0.key, title: $0.title) }
    }
}

/// An area in the menu: "3.2 Titel".
struct MenuBarCategory: Identifiable {
    let key: String
    let title: String
    var id: String { key }
    var label: String { title.isEmpty ? key : "\(key) \(title)" }
}

/// "Heute · Mo, 16. Nov." and "73 % erfasst · 11 offen".
private struct MenuBarStatus: View {
    let context: WeekContext
    let day: DayKey

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Heute · \(day.shortLabel)")
                .font(.headline)
            Text(line)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private var line: String {
        guard context.hasPlan else { return "Kein Plan" }
        // v8: "Krank – zählt nicht" names the day type.
        return GlanceText.dayLine(context.score.days[day], closed: context.isClosed(day), open: context.openCount(on: day),
                                  type: context.dayType(day))
    }
}
#endif
