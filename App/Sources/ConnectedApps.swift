import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

// v10 (TASKS-v10 §1.5): the connected apps in the app – Einstellungen → "Verbundene Apps" (§1.5.5) and the
// pieces other screens show: power-hours "aus Theo" with "Übernehmen", the tick "⇄ George · Push", spending
// "aus Finn", the measure editor's "Quelle", the item's link and "zählt für …". Everything that comes from
// another app is computed (Grundregel 1): these views only show it; "Übernehmen" and "Zuordnen" are the only
// writes, and both are the owner's own records.

// MARK: Texts

enum ConnectedAppsTexts {
    static let intro = "Theo, George, Nina, Finn und weitere Binisoft-Apps liefern Erledigtes und Werte auf demselben Gerät. Thalia rechnet sie in die Woche ein, legt dafür aber nie eigene Einträge an – eigene Markierungen, Einträge und Power-Hours gehen immer vor. Werte aus Apple Health gehen nie in den Austausch."
    static let empty = "Noch keine verbundene App gesehen"
    static let emptyDetail = "Sobald eine Binisoft-App auf diesem Gerät etwas für Thalia bereitlegt, erscheint sie hier."
    static let unassignedFooter = "Kategorie wählen: Power-Hours und Aufgaben dieser Gruppe zählen dann dort. Abgeschlossene Wochen vor dem aktuellen Abschnitt bleiben, wie sie waren."
    static let mappingsFooter = "„Zuordnung aus …“ wurde in der anderen App gewählt und geht vor; dort ändern. „Zuordnung in Thalia“ lässt sich hier ändern oder entfernen."
    static let arrivalsFooter = "Nur zum Ansehen – geändert wird in der App, aus der es kommt."
    static let catalogFooter = "Andere Apps lesen daraus Ziele, Kategorien, Messwerte und Ergebnisse – nur die Namen, keine Werte und kein Fortschritt. So lässt sich dort eine Thalia-Kategorie wählen."
    static let demoFooter = "Beispieldaten der Quelle „Demo“ – hier liest Thalia keine anderen Apps."
    static let watchFooter = "Thalia sieht beim Start nach, wenn sie nach vorne kommt, alle 5 Minuten, solange sie offen ist, nach dem iCloud-Abgleich, am Tageswechsel und wenn eine andere App Neues meldet."

    /// "Mo, 16. Nov., 18:04"
    static func stamp(_ date: Date) -> String {
        DayKey(date: date).shortLabel + ", " + Format.clock(DayKey.minutes(of: date).rounded(.down))
    }

    /// "Zuletzt gesehen: Mo, 16. Nov., 18:04"; without `source.json` yet: "Noch keine Statusdatei".
    static func lastSeen(_ date: Date?) -> String {
        guard let date else { return "Noch keine Statusdatei (source.json)" }
        return "Zuletzt gesehen: " + stamp(date)
    }

    /// "Format v1"; a newer format is read as far as this build knows it.
    static func format(_ version: Int?) -> String? {
        guard let version else { return nil }
        if version > BinisoftExchange.version { return "Format v\(version) – neuer als diese Thalia-Version" }
        return "Format v\(version)"
    }

    static func isNewerFormat(_ version: Int?) -> Bool {
        (version ?? 0) > BinisoftExchange.version
    }

    /// "12 Meldungen an 9 Tagen · letzte 30 Tage" / "Keine Meldungen in den letzten 30 Tagen".
    static func facts(count: Int, days: Int, window: Int = 30) -> String {
        guard count > 0 || days > 0 else { return "Keine Meldungen in den letzten \(window) Tagen" }
        return "\(Format.count(count, "Meldung", "Meldungen")) an \(Format.count(days, "Tag", "Tagen")) · letzte \(window) Tage"
    }

    /// "3 aus Apple Health – nicht verwendet · 1 unbekannte Art" – nil when everything is used.
    static func unused(ignored: Int, unused: Int) -> String? {
        var parts: [String] = []
        if ignored > 0 { parts.append("\(ignored) aus Apple Health – nicht verwendet") }
        if unused > 0 { parts.append("\(Format.count(unused, "unbekannte Art", "unbekannte Arten")) – nicht verwendet") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "3 Meldungen in 30 Tagen" under a group without a category.
    static func groupCount(_ count: Int) -> String {
        "\(Format.count(count, "Meldung", "Meldungen")) in 30 Tagen"
    }

    /// "→ 3.2 Kunden"
    static func target(_ key: String, title: String?) -> String {
        let shown: String = (title ?? "").isEmpty ? key : "\(key) \(title ?? "")"
        return "→ " + shown
    }

    /// "Zuletzt nachgesehen: Mo, 16. Nov., 18:04" on this device.
    static func lastRead(_ date: Date?, isWatching: Bool) -> String {
        guard isWatching else { return "Auf diesem Gerät liest Thalia keine anderen Apps." }
        guard let date else {
            return "Noch nichts gelesen. Thalia sieht ein paar Sekunden nach dem Start nach – bleibt es dabei, fehlt dieser Thalia-Version der Zugriff auf die gemeinsame App-Gruppe."
        }
        return "Zuletzt nachgesehen: " + stamp(date)
    }

    /// The toast after a mapping: "Arbeit/Kunden → 3.2".
    static func mapped(_ title: String, categoryKey: String) -> String {
        "\(title) → \(categoryKey)"
    }

    /// "Übernommen: 1,5 PH · Rechnung schreiben"
    static func adopted(_ record: WorkRecord) -> String {
        let what: String = record.task.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown: String = what.isEmpty ? "Power-Hours" : what
        return "Übernommen: \(Format.powerHours(record.powerHours)) · \(shown)"
    }

    /// "aus Theo"
    static func fromSource(_ source: String?) -> String {
        guard let source, !source.isEmpty else { return "aus einer verbundenen App" }
        return "aus \(source)"
    }

    /// "aus Finn – in Finn ändern"
    static func expenseSource(_ source: String) -> String {
        "aus \(source) – in \(source) ändern"
    }
}

// MARK: Store data for the screen

/// What "Verbundene Apps" shows, read once per refresh (not per frame).
struct ConnectedAppsData {
    var summaries: [ExchangeSourceSummary] = []
    var arrivals: [ExchangeArrival] = []
    var rules: [LinkRule] = []
    var categories: [CategoryRecord] = []
    var providesCatalog = true
    var lastRead: Date?
    var problems: [String] = []
    /// The monitor reads the App Group on this device (the real store on iPhone, iPad and Mac).
    var isWatching = false

    @MainActor
    static func load(_ app: AppModel) -> ConnectedAppsData {
        let store: TrackerStore = app.store
        var data = ConnectedAppsData()
        data.summaries = store.exchangeSummaries(today: app.today)
        data.arrivals = store.exchangeArrivals(today: app.today)
        data.rules = store.linkRules()
        let categories: [CategoryRecord] = Array(store.liveCategories().latest(by: \.key, modified: \.modifiedAt).values.map(\.record))
        data.categories = categories.sortedByKey()
        data.providesCatalog = store.providesCatalog
        data.lastRead = app.exchangeMonitor?.lastRead
        data.problems = app.exchangeMonitor?.lastProblems ?? []
        data.isWatching = app.exchangeMonitor != nil
        return data
    }

    func categoryTitle(_ key: String) -> String? {
        categories.first { $0.key == key }?.title
    }

    /// Thalia's rule for a group, if any.
    func rule(source: String, ref: String) -> LinkRule? {
        let id: String = LinkRule.id(source: source, ref: ref)
        return rules.first { $0.id == id }
    }

    /// Rules of sources that aren't listed (no file and no `source.json` in 30 days) – still in effect.
    var otherRules: [LinkRule] {
        let listed: Set<String> = Set(summaries.map(\.source))
        return rules.filter { !listed.contains($0.source) && !$0.categoryKey.isEmpty }
            .sorted { ($0.source, $0.refTitle, $0.ref) < ($1.source, $1.refTitle, $1.ref) }
    }
}

// MARK: Einstellungen → "Verbundene Apps"

/// The page in Einstellungen (also a sheet of its own for screenshots and the tour).
struct ConnectedAppsView: View {
    @Environment(AppModel.self) private var app
    @State private var data = ConnectedAppsData()
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                Text(ConnectedAppsTexts.intro)
                    .font(.subheadline)
            } footer: {
                Text(ExchangeOverview.hint)
            }
            sourcesContent
            arrivalsSection
            catalogSection
            deviceSection
        }
        .formStyle(.grouped)
        .navigationTitle("Verbundene Apps")
        .inlineNavigationTitle()
        .task { reload() }
        .task(id: app.syncTick) { if loaded { reload() } }
        .task { await followMonitor() }
    }

    // MARK: Sources

    @ViewBuilder
    private var sourcesContent: some View {
        if data.summaries.isEmpty && loaded {
            Section {
                ContentUnavailableView(ConnectedAppsTexts.empty, systemImage: "app.connected.to.app.below.fill",
                                       description: Text(ConnectedAppsTexts.emptyDetail))
            }
        }
        ForEach(data.summaries, id: \.source) { summary in
            sourceSection(summary)
            if !summary.unassigned.isEmpty {
                unassignedSection(summary)
            }
        }
        if !data.otherRules.isEmpty {
            Section {
                ForEach(data.otherRules, id: \.id) { rule in
                    otherRuleRow(rule)
                }
            } header: {
                Text("Weitere Zuordnungen in Thalia")
            }
        }
    }

    private func sourceSection(_ summary: ExchangeSourceSummary) -> some View {
        Section {
            SourceSummaryRow(summary: summary)
            ForEach(summary.mappings, id: \.ref) { mapping in
                mappingRow(mapping, summary: summary)
            }
        } header: {
            Text(summary.name)
        } footer: {
            if !summary.mappings.isEmpty {
                Text(ConnectedAppsTexts.mappingsFooter)
            }
        }
    }

    private func unassignedSection(_ summary: ExchangeSourceSummary) -> some View {
        Section {
            ForEach(summary.unassigned, id: \.ref) { group in
                CategoryChoiceRow(title: group.title, detail: ConnectedAppsTexts.groupCount(group.count), selection: "",
                                  placeholder: "Kategorie wählen", categories: data.categories) { key in
                    map(source: summary.source, ref: group.ref, title: group.title, categoryKey: key)
                }
            }
        } header: {
            Text("Ohne Zuordnung · \(summary.name)")
        } footer: {
            Text(ConnectedAppsTexts.unassignedFooter)
        }
    }

    @ViewBuilder
    private func mappingRow(_ mapping: ExchangeSourceSummary.Mapping, summary: ExchangeSourceSummary) -> some View {
        if mapping.origin == .thalia {
            CategoryChoiceRow(title: mapping.title, detail: mapping.originLabel, selection: mapping.categoryKey,
                              placeholder: "Kategorie wählen", categories: data.categories, needsCheck: mapping.needsCheck) { key in
                map(source: summary.source, ref: mapping.ref, title: mapping.title, categoryKey: key)
            }
            .swipeActions(edge: .trailing) {
                Button("Entfernen", systemImage: "xmark.circle", role: .destructive) {
                    removeRule(source: summary.source, ref: mapping.ref, title: mapping.title)
                }
            }
            .contextMenu {
                Button("Zuordnung entfernen", systemImage: "xmark.circle", role: .destructive) {
                    removeRule(source: summary.source, ref: mapping.ref, title: mapping.title)
                }
            }
        } else {
            MappingRow(mapping: mapping, categoryTitle: data.categoryTitle(mapping.categoryKey), sourceName: summary.name)
        }
    }

    private func otherRuleRow(_ rule: LinkRule) -> some View {
        let title: String = rule.refTitle.isEmpty ? rule.ref : rule.refTitle
        let detail: String = "\(ExchangeSourceInfo.displayName(rule.source)) · Zuordnung in Thalia"
        return CategoryChoiceRow(title: title, detail: detail, selection: rule.categoryKey, placeholder: "Kategorie wählen",
                                 categories: data.categories) { key in
            map(source: rule.source, ref: rule.ref, title: title, categoryKey: key)
        }
        .contextMenu {
            Button("Zuordnung entfernen", systemImage: "xmark.circle", role: .destructive) {
                removeRule(source: rule.source, ref: rule.ref, title: title)
            }
        }
    }

    // MARK: "Was kommt an", catalog, this device

    @ViewBuilder
    private var arrivalsSection: some View {
        if !data.arrivals.isEmpty {
            Section {
                ForEach(Array(data.arrivals.prefix(ConnectedAppsView.arrivalLimit).enumerated()), id: \.offset) { entry in
                    ArrivalRow(arrival: entry.element)
                }
                if data.arrivals.count > ConnectedAppsView.arrivalLimit {
                    Text("… und \(data.arrivals.count - ConnectedAppsView.arrivalLimit) weitere")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Was kommt an · letzte 7 Tage")
            } footer: {
                Text(ConnectedAppsTexts.arrivalsFooter)
            }
        }
    }

    static let arrivalLimit = 60

    private var catalogSection: some View {
        Section {
            Toggle("Thalia-Katalog bereitstellen", isOn: catalogBinding)
        } footer: {
            Text(ConnectedAppsTexts.catalogFooter)
        }
    }

    private var catalogBinding: Binding<Bool> {
        Binding(
            get: { data.providesCatalog },
            set: { on in
                app.store.setProvidesCatalog(on)
                data.providesCatalog = on
                app.refreshConnectedApps()
            }
        )
    }

    private var deviceSection: some View {
        Section {
            Text(ConnectedAppsTexts.lastRead(data.lastRead, isWatching: data.isWatching))
                .font(.subheadline)
            ForEach(Array(data.problems.prefix(8).enumerated()), id: \.offset) { entry in
                Label(entry.element, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if data.isWatching {
                Button("Jetzt nachsehen", systemImage: "arrow.clockwise") { refreshNow() }
            }
        } header: {
            Text("Auf diesem Gerät")
        } footer: {
            Text(deviceFooter)
        }
    }

    private var deviceFooter: String {
        if app.launch.isDemo || app.isSandbox { return ConnectedAppsTexts.demoFooter }
        return ConnectedAppsTexts.watchFooter
    }

    // MARK: Actions

    private func reload() {
        data = ConnectedAppsData.load(app)
        loaded = true
    }

    /// Reloads when the monitor finished a look (it isn't observable): checks its time stamp every 2 s
    /// while the page is open.
    private func followMonitor() async {
        var seen: Date? = app.exchangeMonitor?.lastRead
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            let current: Date? = app.exchangeMonitor?.lastRead
            if current != seen {
                seen = current
                reload()
            }
        }
    }

    private func refreshNow() {
        app.refreshConnectedApps()
    }

    private func map(source: String, ref: String, title: String, categoryKey: String) {
        guard !categoryKey.isEmpty else { return }
        let change: RecordChange = app.store.mapGroup(source: source, ref: ref, refTitle: title, categoryKey: categoryKey)
        RecordToast.show(app, ConnectedAppsTexts.mapped(title, categoryKey: categoryKey), symbol: "arrow.left.arrow.right",
                         change: change)
        reload()
    }

    private func removeRule(source: String, ref: String, title: String) {
        guard let rule = data.rule(source: source, ref: ref) else { return }
        let change: RecordChange = app.store.trash(rule)
        RecordToast.show(app, "Zuordnung entfernt: \(title)", symbol: "xmark.circle", change: change)
        reload()
    }
}

/// "Verbundene Apps" as a sheet of its own (CI screenshot `connected-apps`, the tour's practice page).
struct ConnectedAppsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ConnectedAppsView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 540, height: 760)
    }
}

/// The reading list as a sheet of its own (the tour's practice page has no Ziele tab).
struct ReadingListSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ReadingListView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        SheetCloseButton { dismiss() }
                    }
                }
        }
        .thaliaSheetFrame(width: 520, height: 760)
    }
}

/// One source: last seen, format, what arrived in 30 days, what isn't used.
struct SourceSummaryRow: View {
    let summary: ExchangeSourceSummary

    private var formatText: String? { ConnectedAppsTexts.format(summary.formatVersion) }
    private var unusedText: String? { ConnectedAppsTexts.unused(ignored: summary.ignored, unused: summary.unused) }
    private var formatColor: Color { ConnectedAppsTexts.isNewerFormat(summary.formatVersion) ? Color.orange : Color.secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(ConnectedAppsTexts.lastSeen(summary.lastSeen))
                .font(.subheadline.weight(.medium))
            if let formatText {
                Text(formatText)
                    .font(.caption)
                    .foregroundStyle(formatColor)
            }
            Text(ConnectedAppsTexts.facts(count: summary.factCount, days: summary.dayCount))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if let unusedText {
                Text(unusedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// A group of another app with a category picker ("Ohne Zuordnung", "Zuordnung in Thalia").
struct CategoryChoiceRow: View {
    let title: String
    let detail: String
    let selection: String
    let placeholder: String
    let categories: [CategoryRecord]
    var needsCheck = false
    let onPick: (String) -> Void

    private var binding: Binding<String> {
        Binding(get: { selection }, set: { key in
            if key != selection { onPick(key) }
        })
    }

    var body: some View {
        Picker(selection: binding) {
            if selection.isEmpty {
                Text(placeholder).tag("")
            }
            ForEach(categories, id: \.key) { category in
                Text("\(category.key) \(category.title)").tag(category.key)
            }
            if !selection.isEmpty && !categories.contains(where: { $0.key == selection }) {
                Text("\(selection) (nicht mehr da)").tag(selection)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if needsCheck {
                    Label("Zuordnung prüfen", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// A mapping chosen in the source app ("Zuordnung aus Theo") – changed there, shown here.
struct MappingRow: View {
    let mapping: ExchangeSourceSummary.Mapping
    let categoryTitle: String?
    let sourceName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(mapping.title)
                Spacer(minLength: 6)
                Text(ConnectedAppsTexts.target(mapping.categoryKey, title: categoryTitle))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(mapping.originLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if mapping.needsCheck {
                Label("Zuordnung prüfen – in \(sourceName) neu wählen", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One fact of "Was kommt an": day, app, what, and what Thalia does with it (read only).
struct ArrivalRow: View {
    let arrival: ExchangeArrival

    private var titleColor: Color { arrival.isUsed ? Color.primary : Color.secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(arrival.title)
                .foregroundStyle(titleColor)
                .lineLimit(2)
            Text("\(arrival.day.shortLabel) · \(arrival.source) · \(arrival.detail)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Heute – power-hours from another app

extension AppModel {
    /// "Übernehmen" (§1.5.3): an own block from a derived one (`importID` = the derived id), so it replaces
    /// it; Undo moves the own block to the trash and the derived one shows again.
    func adoptWork(_ record: WorkRecord, categoryKey: String? = nil) {
        let store: TrackerStore = self.store
        let block: WorkBlock = store.adoptWork(record, categoryKey: categoryKey)
        toasts.show(ConnectedAppsTexts.adopted(record), symbol: "tray.and.arrow.down.fill") {
            store.trash([block])
        }
    }
}

/// A derived power-hour block ("aus Theo", read only) with "Übernehmen".
struct DerivedWorkRow: View {
    let record: WorkRecord
    let source: String?
    let categoryTitle: String
    @Environment(AppModel.self) private var app

    private var task: String {
        let trimmed: String = record.task.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Power-Hours" : trimmed
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Text(Format.number(record.powerHours))
                    .font(.system(.headline, design: .rounded))
                    .monospacedDigit()
                Text("PH")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 48, height: 40)
            .background(GoalPalette.color(category: record.categoryKey).opacity(0.08), in: .rect(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(task)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    KeyBadge(key: record.categoryKey)
                    Text(categoryTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Label(ConnectedAppsTexts.fromSource(source), systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Button("Übernehmen") { app.adoptWork(record) }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Macht einen eigenen Eintrag daraus")
        }
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Übernehmen", systemImage: "tray.and.arrow.down") { app.adoptWork(record) }
        }
    }
}

/// The derived blocks of one category on a day (Heute → "Power-Hours heute").
struct DerivedWorkRows: View {
    let context: WeekContext
    let day: DayKey
    let category: TrackCategory

    private var records: [WorkRecord] {
        let key: String = category.key
        return context.derivedWork(on: day).filter { $0.categoryKey == key }
    }

    var body: some View {
        ForEach(records, id: \.id) { record in
            DerivedWorkRow(record: record, source: context.workSource(record), categoryTitle: category.title)
        }
    }
}

/// Power-hours from another app without a category ("ohne Zuordnung"): shown, counted nowhere, until
/// they are taken over into a category or their group gets one (Einstellungen → "Verbundene Apps").
struct UnassignedWorkSection: View {
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    var body: some View {
        let records: [WorkRecord] = context.unassignedWork(on: day)
        if !records.isEmpty {
            Section {
                ForEach(records, id: \.id) { record in
                    UnassignedWorkRow(record: record, source: context.workSource(record), categories: context.categories)
                }
            } header: {
                Text("Aus anderen Apps · ohne Zuordnung")
            } footer: {
                Text("Zählt nirgends, bis eine Kategorie gewählt ist: „Übernehmen in …“ oder für die ganze Gruppe unter Einstellungen → „Verbundene Apps“.")
            }
        }
    }
}

struct UnassignedWorkRow: View {
    let record: WorkRecord
    let source: String?
    let categories: [TrackCategory]
    @Environment(AppModel.self) private var app

    private var task: String {
        let trimmed: String = record.task.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Power-Hours" : trimmed
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Format.powerHours(record.powerHours)) · \(task)")
                    .lineLimit(2)
                Label(ConnectedAppsTexts.fromSource(source), systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Menu("Übernehmen in …") {
                ForEach(categories) { category in
                    Button("\(category.key) \(category.title)") { app.adoptWork(record, categoryKey: category.key) }
                }
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

/// "⇄ George · Push" under an item whose ✓ comes from a connected app (no own mark that day).
struct DerivedMarkNote: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityLabel("Haken aus einer verbundenen App: \(label)")
    }
}

// MARK: Ausgaben – rows from another app

/// A spending row from another app ("aus Finn – in Finn ändern"): read only.
struct AppExpenseLine: View {
    let row: AppExpenseRow
    var indent: CGFloat = 12

    private var purpose: String {
        let trimmed: String = row.purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "ohne Angabe" : trimmed
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(purpose)
                    .foregroundStyle(.secondary)
                Label(ConnectedAppsTexts.expenseSource(row.source), systemImage: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 6)
            Text(Format.euro(row.amount))
                .font(.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.leading, indent)
        .accessibilityElement(children: .combine)
    }
}

/// A day's spending rows from another app, under the own ones (Heute).
struct AppExpenseRows: View {
    let context: WeekContext
    let measure: MeasureDefinition
    let day: DayKey

    var body: some View {
        ForEach(context.appExpenseRows(measure, on: day)) { row in
            AppExpenseLine(row: row, indent: 8)
        }
    }
}

// MARK: Heute – a measure fed by the reading list

/// The input of a measure with the source `list:<art>` (§1.3.3): the pages read that day, and "+" opens
/// "Lesen" – the pages are entered once, in the reading list.
struct ReadingMeasureInput: View {
    let measure: MeasureDefinition
    let context: WeekContext
    let day: DayKey
    @Environment(AppModel.self) private var app

    private var valueText: String {
        let value: Double = context.dayValue(measure, on: day) ?? 0
        return Format.measure(value, unit: measure.unit)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(valueText)
                .font(.system(.callout, design: .rounded).weight(.bold))
                .monospacedDigit()
            Button {
                app.sheet = .reading(day, itemID: nil)
            } label: {
                Label("Lesen", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .foregroundStyle(.white)
                    .background(Color.accentFill.gradient, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Lesestand für \(measure.title) eintragen")
        }
    }
}

// MARK: Links and "zählt für …"

enum LinkTexts {
    /// "George · Workouts · Push", "Leseliste · Buch", "Apple Health · Schritte", "Power-Hours · 3.2";
    /// nil for a manual source.
    static func sourceLabel(_ source: MeasureSource, sources: ExchangeSourceList) -> String? {
        switch source {
        case .manual:
            return nil
        case .app(let app):
            return app.label(refs: sources.info(app.source)?.refs ?? [])
        default:
            return source.label
        }
    }

    /// The link of an item: "Workouts ≥ 1 · George · Workouts · Push"; nil without one.
    static func itemLink(code: String, measure: MeasureRecord?, sources: ExchangeSourceList) -> String? {
        guard !code.isEmpty else { return nil }
        let direct: MeasureSource = MeasureSource(raw: code)
        if direct.appSource != nil || direct.listKind != nil {
            return sourceLabel(direct, sources: sources) ?? code
        }
        guard let measure else { return code }
        guard let source = sourceLabel(measure.source, sources: sources) else { return measure.title }
        return "\(measure.title) · \(source)"
    }

    /// The footnote for an item with a link to another app or the reading list.
    static func itemFootnote(code: String, measure: MeasureRecord?) -> String? {
        let source: MeasureSource = measure?.source ?? MeasureSource(raw: code)
        if let app = source.appSource {
            return "Der Haken kommt von selbst aus \(app.sourceName), solange kein eigener gesetzt ist – eine eigene Markierung geht immer vor."
        }
        if source.listKind != nil {
            return "Die Seiten kommen aus der Leseliste – dort eintragen, hier zählt es von selbst."
        }
        return nil
    }
}

/// "zählt für Ziel 5 · Bücher 3/10" – the results a measure feeds (§1.2.4); nothing when it feeds none.
struct CountsForLines: View {
    let measure: MeasureDefinition
    let context: WeekContext

    var body: some View {
        let results: [GoalResult] = context.results(feedBy: measure)
        if !results.isEmpty {
            ResultSeriesReader(results: results, context: context) { table in
                CountsForText(lines: table.countsFor(measure))
            }
        }
    }
}

private struct CountsForText: View {
    let lines: [String]

    var body: some View {
        ForEach(lines, id: \.self) { line in
            Label(line, systemImage: "flag.checkered")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// The measure editor's "zählt für …" (§1.2.4), read from the measure's week.
struct MeasureCountsForSection: View {
    let week: WeekKey
    let measure: MeasureDefinition
    @Environment(AppModel.self) private var app

    var body: some View {
        WeekReader(week: week, today: app.today) { context in
            if !context.results(feedBy: measure).isEmpty {
                Section {
                    CountsForLines(measure: measure, context: context)
                } header: {
                    Text("Jahresziele")
                }
            }
        }
    }
}

/// "zählt für …" of the week's measures in "Wochenziele" (§1.2.4).
struct WeeklyCountsForSection: View {
    let context: WeekContext

    private var fed: [MeasureDefinition] {
        context.measures.filter { !context.results(feedBy: $0).isEmpty }
    }

    var body: some View {
        let measures: [MeasureDefinition] = fed
        if !measures.isEmpty {
            Section {
                ForEach(measures) { measure in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(measure.title)
                            .font(.subheadline.weight(.medium))
                        CountsForLines(measure: measure, context: context)
                    }
                }
            } header: {
                Text("Zählt für Jahresziele")
            }
        }
    }
}

// MARK: Messwert-Editor – "Quelle" (§1.5.4)

/// The measure editor's source as plain values: Manuell / Power-Hours / Apple Health / Leseliste /
/// Verbundene App → App → Art → Eintrag. An unknown source ("Andere Quelle") is kept unchanged.
struct MeasureSourceDraft: Equatable {
    enum Choice: String, CaseIterable, Identifiable {
        case manual, work, health, list, app, other
        var id: String { rawValue }

        var label: String {
            switch self {
            case .manual: "Manuell"
            case .work: "Power-Hours"
            case .health: "Apple Health"
            case .list: "Leseliste"
            case .app: "Verbundene App"
            case .other: "Andere Quelle"
            }
        }
    }

    var choice: Choice
    var workCategory: String
    var healthKind: HealthKind = .steps
    var listKind: String = ListItem.kindKey(ListItem.defaultKind)
    var appSourceID: String = ""
    var appKind: String = ""
    var appRef: String = ""
    /// The text of a source this build doesn't know – saved back as it was.
    var otherText: String = ""

    init(_ source: MeasureSource, categoryKey: String) {
        workCategory = categoryKey
        switch source {
        case .manual:
            choice = .manual
        case .work(let category):
            choice = .work
            workCategory = category
        case .health(let kind):
            choice = .health
            healthKind = kind
        case .list(let kind):
            choice = .list
            listKind = kind
        case .app(let app):
            choice = .app
            appSourceID = app.source
            appKind = app.kind
            appRef = app.ref ?? ""
        case .other(let text):
            choice = .other
            otherText = text
        }
    }

    /// The choices offered: "Andere Quelle" only for a measure that has one.
    var choices: [Choice] {
        choice == .other ? Choice.allCases : Choice.allCases.filter { $0 != .other }
    }

    var appSource: AppSource? {
        let source: String = appSourceID.trimmingCharacters(in: .whitespaces)
        let kind: String = appKind.trimmingCharacters(in: .whitespaces)
        guard !source.isEmpty, !kind.isEmpty else { return nil }
        let ref: String = appRef.trimmingCharacters(in: .whitespaces)
        return AppSource(source: source, kind: kind, ref: ref.isEmpty ? nil : ref)
    }

    /// The source the fields describe; nil while something is missing (a work category, an app and its kind).
    var source: MeasureSource? {
        switch choice {
        case .manual:
            return .manual
        case .work:
            let category: String = workCategory.trimmingCharacters(in: .whitespaces)
            return category.isEmpty ? nil : .work(category: category)
        case .health:
            return .health(healthKind)
        case .list:
            let kind: String = ListItem.kindKey(listKind)
            return kind.isEmpty ? nil : .list(kind: kind)
        case .app:
            return appSource.map { MeasureSource.app($0) }
        case .other:
            return .other(otherText)
        }
    }

    var isIncomplete: Bool { source == nil }

    /// What saving writes: the source unchanged when the fields still describe it (so an unknown text or
    /// an alias like "work:" stays exactly as it was), else the new one.
    func resolved(original: MeasureSource) -> MeasureSource {
        guard let source else { return original }
        return source == original ? original : source
    }

    /// The unit a newly chosen source suggests; nil keeps the unit as it is. A metric in € (net worth)
    /// suggests nothing: a measure in € is a spending measure.
    var suggestedUnit: String? {
        switch choice {
        case .work:
            return "PH"
        case .list:
            return ListItem.defaultUnit(kind: listKind)
        case .app:
            guard let app = appSource else { return nil }
            let unit: String = app.suggestedUnit
            if unit.isEmpty { return nil }
            if Units.normalized(unit) == "€" && app.summedKind != .spending { return nil }
            return unit
        default:
            return nil
        }
    }

    /// How the week adds up the days: a metric's own rule (net worth, weight: the last value), otherwise by unit.
    func aggregation(unit: String) -> Aggregation {
        if let metric = appSource?.metric, choice == .app {
            return metric.agg == .last ? .last : .sum
        }
        if choice == .work || choice == .list { return .sum }
        if choice == .app, appSource?.countedKind != nil || appSource?.summedKind != nil { return .sum }
        return .default(forUnit: unit)
    }

    /// "George · Workouts · Push" under the pickers.
    func preview(sources: ExchangeSourceList) -> String? {
        guard let source else { return nil }
        return LinkTexts.sourceLabel(source, sources: sources)
    }

    /// The fields for "something changed" (R14).
    var fields: [String] {
        [choice.rawValue, workCategory, healthKind.rawValue, listKind, appSourceID, appKind, appRef, otherText]
    }
}

/// The section "Quelle" of the measure editor.
struct MeasureSourceSection: View {
    @Binding var draft: MeasureSourceDraft
    let categories: [TrackCategory]
    let sources: ExchangeSourceList

    private var sourceInfo: ExchangeSourceInfo? { sources.info(draft.appSourceID) }

    private var refChoices: [ExchangeRef] {
        guard let app = draft.appSource, let info = sourceInfo else { return [] }
        return app.refChoices(info.refs)
    }

    private var listKinds: [String] {
        var kinds: [String] = ListItem.kindSuggestions.map { ListItem.kindKey($0) }
        if !kinds.contains(draft.listKind) { kinds.append(draft.listKind) }
        return kinds
    }

    var body: some View {
        Section {
            Picker("Quelle", selection: $draft.choice) {
                ForEach(draft.choices) { choice in
                    Text(choice.label).tag(choice)
                }
            }
            details
            if let preview = draft.preview(sources: sources) {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Quelle")
        } footer: {
            Text(footer)
        }
    }

    @ViewBuilder
    private var details: some View {
        switch draft.choice {
        case .work:
            Picker("Bereich", selection: $draft.workCategory) {
                Text("bitte wählen").tag("")
                ForEach(categories) { category in
                    Text("\(category.key) \(category.title)").tag(category.key)
                }
            }
        case .health:
            Picker("Wert", selection: $draft.healthKind) {
                ForEach(HealthKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }
        case .list:
            Picker("Art", selection: $draft.listKind) {
                ForEach(listKinds, id: \.self) { kind in
                    Text(ListItem.kindTitle(kind)).tag(kind)
                }
            }
        case .app:
            appPickers
        case .manual, .other:
            EmptyView()
        }
    }

    @ViewBuilder
    private var appPickers: some View {
        if sources.sources.isEmpty {
            TextField("App (z. B. george)", text: $draft.appSourceID)
            TextField("Art oder Kennzahl (z. B. workout)", text: $draft.appKind)
            TextField("Eintrag (optional, z. B. eine Vorlagen-id)", text: $draft.appRef)
        } else {
            Picker("App", selection: $draft.appSourceID) {
                Text("bitte wählen").tag("")
                ForEach(sourceIDs, id: \.self) { id in
                    Text(sourceName(id)).tag(id)
                }
            }
            Picker("Art", selection: $draft.appKind) {
                Text("bitte wählen").tag("")
                ForEach(kindChoices, id: \.self) { kind in
                    Text(AppSource(source: draft.appSourceID, kind: kind).kindTitle).tag(kind)
                }
            }
            if !refChoices.isEmpty || !draft.appRef.isEmpty {
                Picker("Eintrag", selection: $draft.appRef) {
                    Text("alle").tag("")
                    ForEach(refChoices, id: \.id) { ref in
                        Text(ref.title.isEmpty ? ref.id : ref.title).tag(ref.id)
                    }
                    if !draft.appRef.isEmpty && !refChoices.contains(where: { $0.id == draft.appRef }) {
                        Text(draft.appRef).tag(draft.appRef)
                    }
                }
            }
        }
    }

    /// The known sources, plus the measure's own when it is not (yet) among them.
    private var sourceIDs: [String] {
        var ids: [String] = sources.ids
        let own: String = BinisoftExchange.sourceID(draft.appSourceID)
        if !own.isEmpty && !ids.contains(own) { ids.append(own) }
        return ids
    }

    private func sourceName(_ id: String) -> String {
        sources.info(id)?.displayName ?? ExchangeSourceInfo.displayName(id)
    }

    /// v1's kinds, plus the measure's own when this build doesn't know it.
    private var kindChoices: [String] {
        var kinds: [String] = AppSource.kindChoices
        if !draft.appKind.isEmpty && !kinds.contains(draft.appKind) { kinds.append(draft.appKind) }
        return kinds
    }

    private var footer: String {
        switch draft.choice {
        case .manual: return "Eingetragen in Heute, auf der Watch oder per Kurzbefehl."
        case .work: return "Zählt die Power-Hours des Bereichs von selbst."
        case .health: return "Apple Health schlägt den Wert auf dem iPhone vor; bestätigt wird er hier. Health-Werte bleiben auf dem Gerät."
        case .list: return "Tageswert = gelesene Menge aller Einträge dieser Art in der Leseliste. Das „+“ in Heute öffnet „Lesen“."
        case .app: return "Werte kommen aus der App auf demselben Gerät – ein eigener Eintrag für den Tag geht vor. Ein verknüpfter Punkt bekommt den Haken von selbst."
        case .other: return "Eine Quelle, die diese Thalia-Version nicht kennt – sie bleibt unverändert."
        }
    }
}

/// The item editor's link (§1.5.4): what the item is linked to, and where its tick comes from.
struct ItemLinkRow: View {
    let code: String
    let measure: MeasureRecord?
    let sources: ExchangeSourceList

    var body: some View {
        if let link = LinkTexts.itemLink(code: code, measure: measure, sources: sources) {
            VStack(alignment: .leading, spacing: 3) {
                LabeledContent("Verknüpfung", value: link)
                if let note = LinkTexts.itemFootnote(code: code, measure: measure) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: Zuletzt gelöscht – v10 records

enum TrashRecordTexts {
    /// "Bücher gelesen" / "Ziel 5 · ≥ 10"
    static func result(_ result: GoalResult) -> TrashLine {
        var parts: [String] = ["Ziel \(result.goalKey)"]
        if let target = Target.parse(result.target) { parts.append(target.label) }
        let title: String = result.title.isEmpty ? "Ergebnis" : result.title
        return TrashLine(title: title, subtitle: parts.joined(separator: " · "))
    }

    /// "Kleine Schritte" / "Buch · Autor:in"
    static func book(_ item: ListItem) -> TrashLine {
        var parts: [String] = [item.kind]
        let author: String = item.subtitle.trimmingCharacters(in: .whitespaces)
        if !author.isEmpty { parts.append(author) }
        let title: String = item.title.isEmpty ? "Eintrag der Leseliste" : item.title
        return TrashLine(title: title, subtitle: parts.joined(separator: " · "))
    }

    /// "Abschnitt 2" / "ab KW50 · Grund"
    static func segment(_ segment: GoalSegment) -> TrashLine {
        var parts: [String] = ["ab \(segment.startWeek.label)"]
        let reason: String = segment.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reason.isEmpty { parts.append(reason) }
        let title: String = segment.title.isEmpty ? "Abschnitt" : segment.title
        return TrashLine(title: title, subtitle: parts.joined(separator: " · "))
    }
}

// MARK: Tour – the v10 cards show their screen on the practice page

enum TourShowcase {
    /// The sheet a v10 card opens with "Ansehen" (its screen isn't on the practice page); nil for the others.
    static func sheet(for stepID: String, day: DayKey) -> AppSheet? {
        switch stepID {
        case "goal-results": return .goalEntry(day, resultID: nil)
        case "reading": return .readingList
        case "segments": return .beginSegment
        case "connected-apps": return .connectedApps
        default: return nil
        }
    }
}
