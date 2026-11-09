import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// "Tag abschließen": during the day you captured what happened; now you decide what it means.
/// 1 check the evidence · 2 fill in what's missing · 3 confirm the categories · 4 reflect.
/// Deliberate, never automatic.
struct CloseDayView: View {
    let day: DayKey
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            WeekReader(week: day.week, today: app.today) { context in
                CloseDayForm(day: day, context: context)
            }
        }
        .sheetFrame(minWidth: 620, minHeight: 720)
    }
}

struct CloseDayForm: View {
    let day: DayKey
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: String] = [:]
    @State private var loaded = false
    @State private var overrideCategory: TrackCategory?
    /// Sheets on top of this sheet (the app-wide sheet slot is taken by this one).
    @State private var measureCode: MeasureRequest?
    @State private var sharing: ShareRequest?
    @State private var itemSheet: PlanItem?

    private var closed: Bool { context.isClosed(day) }

    var body: some View {
        let overall = context.score.days[day]
        let conditionals = context.openConditionals(on: day)
        let suggestions = context.items(on: day).compactMap { item in context.suggestion(item, on: day).map { (item, $0) } }
        Form {
            Section {
                HeroCard(title: day.longLabel, subtitle: closed ? "Tag abgeschlossen" : "Noch offen – die Wertung kommt mit dem Abschluss",
                         value: closed ? Format.score(overall?.score, outOf: false) : (overall?.coverageText ?? "0 %"),
                         caption: closed ? "Tag" : "erfasst",
                         progress: closed ? (overall?.score ?? 0) / 10 : (overall?.coverage ?? 0),
                         facts: dayFacts(overall),
                         celebrate: closed && (overall?.score ?? 0) >= 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                if closed {
                    Button {
                        sharing = ShareRequest(content: .day(day, context: context))
                    } label: {
                        Label("Tag als Bild teilen", systemImage: "square.and.arrow.up")
                    }
                }
            } footer: {
                Text("Tagsüber erfassen, was passiert. Abends bewerten, was es bedeutet.")
            }

            Section {
                let totals = context.workTotals(on: day)
                LabeledContent("Power-Hours", value: totals.isEmpty ? (DayTypes.isWorkFree(context.dayType(day)) ? "Frei – null PH ist richtig" : "keine") : totals.explanation)
                ForEach(context.work(on: day).filter { !$0.result.isEmpty }) { block in
                    Label("\(block.task.isEmpty ? block.categoryKey : block.task): \(block.result)", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                ForEach(filledMeasures) { measure in
                    evidenceRow(measure)
                }
                if !missingMeasures.isEmpty {
                    DisclosureGroup("Fehlt noch (\(missingMeasures.count)) – direkt ergänzen") {
                        ForEach(missingMeasures) { measure in
                            HStack {
                                Text(measure.title)
                                Spacer(minLength: 6)
                                MeasureInput(measure: measure, context: context, day: day)
                            }
                        }
                    }
                }
            } header: {
                Text("1 · Belege prüfen")
            }

            Section {
                if !suggestions.isEmpty {
                    Button {
                        app.store.apply(suggestions: suggestions, day: day)
                    } label: {
                        Label("\(suggestions.count) Vorschläge aus Messwerten übernehmen", systemImage: "wand.and.stars")
                    }
                }
                if requiredBlanks.isEmpty {
                    Label("Alle Pflichtpunkte haben einen Eintrag.", systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                }
                ForEach(requiredBlanks) { item in
                    quickRow(item)
                }
                if !secondaryBlanks.isEmpty {
                    DisclosureGroup("Nebensachen offen (\(secondaryBlanks.count)) – zählen nur, wenn ausgefüllt") {
                        ForEach(secondaryBlanks) { item in
                            quickRow(item)
                        }
                    }
                }
                if !conditionals.isEmpty {
                    DisclosureGroup("Bedingte Punkte (\(conditionals.count))") {
                        ForEach(conditionals) { item in
                            quickRow(item)
                        }
                    }
                    Button {
                        app.store.settleConditionals(conditionals, occurred: [], day: day)
                    } label: {
                        Label("Situation trat nicht auf → alle N/A", systemImage: "minus.circle")
                    }
                }
                if !weeklyOpen.isEmpty {
                    DisclosureGroup("Wochenpunkte noch offen (\(weeklyOpen.count))") {
                        ForEach(weeklyOpen) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                if let quota = context.quotaProgress(item) {
                                    Text("\(quota.done) von \(quota.target) diese Woche – heute nur eintragen, wenn erledigt; Fehlendes zählt erst am Wochenende.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                quickRow(item)
                            }
                        }
                    }
                }
            } header: {
                Text("2 · Fehlendes ergänzen")
            } footer: {
                Text("Leer heißt „nicht erfasst“ – kein automatisches Versäumnis. Was fällig war und nicht passiert ist, ist ✗, nicht N/A. Automatische Wochenziele (z. B. stammloop) rechnet Thalia selbst.")
            }

            Section {
                ForEach(context.goals) { goal in
                    ForEach(context.categories(of: goal)) { category in
                        let entry = context.score.category(category.key, on: day)
                        if entry.score != nil || entry.due > 0 {
                            HStack {
                                KeyBadge(key: category.key)
                                Text(category.title).lineLimit(1)
                                Spacer()
                                if entry.knockedOut {
                                    Text("Null-Regel").font(.caption2).foregroundStyle(.orange)
                                }
                                if entry.overridden, let calculated = entry.calculated {
                                    Text("statt \(Format.score(calculated))").font(.caption2).foregroundStyle(.secondary)
                                }
                                Text(Format.score(entry.score, outOf: false))
                                    .monospacedDigit()
                                    .fontWeight(.semibold)
                                Button {
                                    overrideCategory = category
                                } label: {
                                    Image(systemName: entry.overridden ? "hand.raised.fill" : "hand.raised")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Eigene Wertung für \(category.title)")
                            }
                        }
                    }
                }
            } header: {
                Text("3 · Kategorien bestätigen")
            } footer: {
                Text("Berechnet: 10 × erreichte ÷ zählende Punkte. Mit der Hand setzt du deine eigene Wertung – sie ersetzt die Rechnung, die Einträge bleiben.")
            }

            Section {
                Toggle(isOn: Binding(get: { answers[ReflectionQuestion.journalField] == "ja" },
                                     set: { answers[ReflectionQuestion.journalField] = $0 ? "ja" : "nein" })) {
                    Label("Ins Journal eingetragen", systemImage: "book.closed")
                }
                ForEach(ReflectionQuestion.day) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.question).font(.subheadline.weight(.semibold))
                        TextField(question.hint, text: binding(question.id), axis: .vertical)
                            .lineLimit(1...6)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("4 · Journal")
            }

            Section {
                if closed {
                    Button {
                        saveAnswers()
                        app.store.reopenDay(day)
                    } label: {
                        Label("Tag wieder öffnen", systemImage: "lock.open")
                    }
                    Button("Fertig") {
                        saveAnswers()
                        dismiss()
                    }
                } else {
                    Button {
                        saveAnswers()
                        // Stays open: the closed day shows its score, a small celebration and "teilen".
                        withAnimation(.snappy) { app.store.closeDay(day) }
                    } label: {
                        Label("Tag abschließen", systemImage: "moon.stars.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(closed ? "Tag abgeschlossen" : "Tag abschließen")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") {
                    saveAnswers()
                    dismiss()
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            for question in ReflectionQuestion.day {
                answers[question.id] = context.reflection(scope: day.string, field: question.id)
            }
            answers[ReflectionQuestion.journalField] = context.reflection(scope: day.string, field: ReflectionQuestion.journalField)
            loaded = true
        }
        .onDisappear(perform: saveAnswers)
        .sheet(item: $sharing) { request in
            ShareSheet(content: request.content)
        }
        .sheet(item: $measureCode) { request in
            MeasureSheet(code: request.code, day: request.day)
                .environment(app)
                .environment(health)
        }
        .sheet(item: $itemSheet) { item in
            ItemDetailView(item: item, day: day)
                .environment(app)
                .environment(health)
        }
        .sheet(item: $overrideCategory) { category in
            OverrideSheet(category: category, day: day, entry: context.score.category(category.key, on: day),
                          reason: context.overrides["\(category.key)|\(day.string)"]?.reason ?? "")
        }
    }

    private func binding(_ field: String) -> Binding<String> {
        Binding(get: { answers[field] ?? "" }, set: { answers[field] = $0 })
    }

    private func dayFacts(_ overall: DayOverall?) -> [(String, String)] {
        var facts: [(String, String)] = [("Typ", context.dayType(day).isEmpty ? "Tag" : context.dayType(day))]
        if let overall, overall.due > 0 { facts.append(("Punkte", "\(overall.due - overall.blank) von \(overall.due)")) }
        let totals = context.workTotals(on: day)
        if !totals.isEmpty { facts.append(("Fokus", totals.shortText)) }
        return facts
    }

    private var dayMeasures: [MeasureDefinition] {
        context.measures.filter { context.applies($0, on: day) && $0.record?.period == .day }
    }

    /// V9.1: what's there is shown, what's missing waits folded away.
    private var filledMeasures: [MeasureDefinition] { dayMeasures.filter { context.dayValue($0, on: day) != nil } }
    private var missingMeasures: [MeasureDefinition] { dayMeasures.filter { context.dayValue($0, on: day) == nil } }

    private var requiredBlanks: [PlanItem] { context.blanks(on: day).filter { !$0.isSecondary } }
    private var secondaryBlanks: [PlanItem] { context.blanks(on: day).filter(\.isSecondary) }
    /// V9.2: n×/week items still short – shown for completeness.
    private var weeklyOpen: [PlanItem] { context.openWeekly(on: day) }

    private func evidenceRow(_ measure: MeasureDefinition) -> some View {
        let value: Double? = context.dayValue(measure, on: day)
        return Button {
            measureCode = MeasureRequest(code: measure.code, day: day)
        } label: {
            LabeledContent(measure.title) {
                HStack(spacing: 6) {
                    Text(value.map { Format.measure($0, unit: measure.record?.isWork == true ? "PH" : measure.unit) } ?? "–")
                    if let met = measure.record.flatMap({ Measures.isMet($0, value: value) }) {
                        Image(systemName: met ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(met ? .green : .secondary)
                    }
                }
                .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    /// An open item with its marks as direct buttons; the title opens the details.
    private func quickRow(_ item: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                itemSheet = item
            } label: {
                HStack(spacing: 6) {
                    KeyBadge(key: item.categoryKey)
                    Text(item.title)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            MarkBar(mark: context.mark(item, on: day), options: context.options(item, on: day),
                    suggestion: context.suggestion(item, on: day), isProgress: item.schedule == .progress) {
                app.setMark($0, item: item, day: day)
            }
        }
        .padding(.vertical, 2)
    }

    private func saveAnswers() {
        guard loaded else { return }
        for (field, text) in answers {
            app.store.setReflection(scope: day.string, field: field, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}

struct MeasureRequest: Identifiable {
    let code: String
    let day: DayKey
    var id: String { "\(code)|\(day.string)" }
}

/// The person's own score for a category on a day.
struct OverrideSheet: View {
    let category: TrackCategory
    let day: DayKey
    let entry: CategoryDay
    @State var reason: String
    @State private var score: Double = 0
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    init(category: TrackCategory, day: DayKey, entry: CategoryDay, reason: String) {
        self.category = category
        self.day = day
        self.entry = entry
        _reason = State(initialValue: reason)
        _score = State(initialValue: entry.score ?? 5)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Berechnet", value: Format.score(entry.overridden ? entry.calculated : entry.score, outOf: true))
                    Stepper(value: $score, in: 0...10, step: 0.5) {
                        LabeledContent("Eigene Wertung", value: Format.score(score) + "/10")
                    }
                    TextField("Grund (z. B. persönliche Null-Regel)", text: $reason, axis: .vertical)
                } footer: {
                    Text("Subjektive Urteile gehören dir. Objektive Daten schlagen nur vor – die Einträge selbst bleiben unverändert.")
                }
                if entry.overridden {
                    Section {
                        Button("Eigene Wertung entfernen", role: .destructive) {
                            app.store.setOverride(categoryKey: category.key, day: day, score: nil, reason: "")
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("\(category.key) \(category.title)")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        app.store.setOverride(categoryKey: category.key, day: day, score: score, reason: reason)
                        dismiss()
                    }
                }
            }
        }
        .sheetFrame(minWidth: 440, minHeight: 320)
    }
}
