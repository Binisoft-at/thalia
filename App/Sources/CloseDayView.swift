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
        .thaliaSheetFrame(width: 620, height: 720)
    }
}

struct CloseDayForm: View {
    let day: DayKey
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(HealthService.self) private var health
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: String] = [:]
    /// The answers as last loaded or saved – typed text differs until it is saved (R14).
    @State private var loadedAnswers: [String: String] = [:]
    @State private var loaded = false
    @State private var overrideCategory: TrackCategory?
    /// Sheets on top of this sheet (the app-wide sheet slot is taken by this one).
    @State private var measureCode: MeasureRequest?
    @State private var sharing: ShareRequest?
    @State private var itemSheet: PlanItem?
    /// True only in the moment of closing: the celebration runs then, not when a closed day is
    /// opened again later (R72).
    @State private var justClosed = false

    private var closed: Bool { context.isClosed(day) }

    var body: some View {
        ScrollViewReader { proxy in
            form(proxy)
                .toolbar {
                    if closed {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fertig", action: finish)
                        }
                    } else {
                        ToolbarItem(placement: .cancellationAction) {
                            SheetCloseButton(action: finish)
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Abschließen") { close(proxy) }
                        }
                    }
                }
                // A second ⌘↩ on the Mac closes the day; once closed it finishes (R39).
                .onChange(of: app.closeRequest) { _, _ in
                    if closed || justClosed {
                        finish()
                    } else {
                        close(proxy)
                    }
                }
        }
    }

    private func form(_ proxy: ScrollViewProxy) -> some View {
        let overall = context.score.days[day]
        let conditionals = context.openConditionals(on: day)
        let toFill: [MarkSuggestion] = context.suggestionsToFill(on: day)
        let differing: [MarkSuggestion] = context.suggestionsDiffering(on: day)
        return Form {
            heroSection(overall)

            Section {
                LabeledContent("Power-Hours", value: workText)
                ForEach(context.work(on: day).filter { !$0.result.isEmpty }) { block in
                    Label("\(block.task.isEmpty ? block.categoryKey : block.task): \(block.result)", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                ForEach(filledMeasures) { measure in
                    evidenceRow(measure)
                }
                // H1: on the Mac a Health value isn't missing – it comes from the iPhone.
                ForEach(healthElsewhereMeasures) { measure in
                    LabeledContent(measure.title, value: WeekContext.healthElsewhereHint)
                        .foregroundStyle(.secondary)
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
                if !toFill.isEmpty {
                    // R12: fills only blank items; a mark set on purpose stays.
                    Button {
                        app.applySuggestions(toFill, day: day)
                    } label: {
                        Label("\(Format.count(toFill.count, "Vorschlag", "Vorschläge")) aus Messwerten übernehmen", systemImage: "wand.and.stars")
                    }
                }
                if !differing.isEmpty {
                    DisclosureGroup("Messwert weicht ab (\(differing.count))") {
                        ForEach(differing) { suggestion in
                            differingRow(suggestion)
                        }
                    }
                }
                if requiredBlanks.isEmpty && context.isExcused(day) {
                    // v8: nothing is due on a sick or holiday day.
                    Label("\(context.excusedName(day)) – nichts ist fällig.", systemImage: DayTypes.symbol(for: context.dayType(day)))
                        .foregroundStyle(.secondary)
                } else if requiredBlanks.isEmpty {
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
                        Label("Situation trat nicht auf → alle „Entfällt“", systemImage: "minus.circle")
                    }
                }
                if !weeklyOpen.isEmpty {
                    DisclosureGroup("Wochenpunkte noch offen (\(weeklyOpen.count))") {
                        ForEach(weeklyOpen) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                if context.quotaProgress(item) != nil {
                                    Text(weeklyHint(item))
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
                Text("Leer heißt „nicht erfasst“ – kein automatisches Versäumnis. Was dran war und nicht passiert ist, ist „Nicht erledigt“, nicht „Entfällt“. Automatische Wochenziele (z. B. stammloop) rechnet Thalia selbst.")
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
                // R58: the plan's journal item is the one source; the switch only without it.
                if let journal = context.journalItem {
                    journalRow(journal)
                } else {
                    Toggle(isOn: Binding(get: { answers[ReflectionQuestion.journalField] == "ja" },
                                         set: { answers[ReflectionQuestion.journalField] = $0 ? "ja" : "nein" })) {
                        Label("Ins Journal eingetragen", systemImage: "book.closed")
                    }
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
                    Button(action: finish) {
                        Label("Fertig", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .thaliaPrimaryAction()
                    Button(action: reopen) {
                        Label("Tag wieder öffnen", systemImage: "lock.open")
                    }
                } else {
                    Button {
                        close(proxy)
                    } label: {
                        Label("Tag abschließen", systemImage: "moon.stars.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .thaliaPrimaryAction()
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(closed ? "Tag abgeschlossen" : "Tag abschließen")
        .inlineNavigationTitle()
        .onAppear {
            guard !loaded else { return }
            for question in ReflectionQuestion.day {
                answers[question.id] = context.reflection(scope: day.string, field: question.id)
            }
            answers[ReflectionQuestion.journalField] = context.reflection(scope: day.string, field: ReflectionQuestion.journalField)
            loadedAnswers = answers
            loaded = true
        }
        .onDisappear(perform: saveAnswers)
        .unsavedInput(answers != loadedAnswers, in: app)
        .sheet(item: $sharing) { request in
            ShareSheet(content: request.content)
                .environment(app)
                .toastHost(app)
        }
        .sheet(item: $measureCode) { request in
            MeasureSheet(code: request.code, day: request.day)
                .environment(app)
                .environment(health)
                .modelContainer(app.container)
                .toastHost(app)
        }
        .sheet(item: $itemSheet) { item in
            ItemDetailView(item: item, day: day)
                .environment(app)
                .environment(health)
                .modelContainer(app.container)
                .toastHost(app)
        }
        .sheet(item: $overrideCategory) { category in
            OverrideSheet(category: category, day: day, entry: context.score.category(category.key, on: day),
                          reason: overrideReason(category))
                .environment(app)
                .toastHost(app)
        }
    }

    private func binding(_ field: String) -> Binding<String> {
        Binding(get: { answers[field] ?? "" }, set: { answers[field] = $0 })
    }

    private func overrideReason(_ category: TrackCategory) -> String {
        context.overrides["\(category.key)|\(day.string)"]?.reason ?? ""
    }

    // MARK: Hero and closing (R39, R40, R72, R80)

    private func heroSection(_ overall: DayOverall?) -> some View {
        Section {
            HeroCard(title: day.longLabel, subtitle: heroSubtitle, value: heroValue(overall), caption: closed ? "Tag" : "erfasst",
                     progress: heroProgress(overall), facts: dayFacts(overall),
                     celebrate: justClosed && closed && (overall?.score ?? 0) >= 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .id("hero")
            if context.isExcused(day) {
                // v8: the day doesn't count; "Typ ändern" takes it back.
                ExcusedDayCard(app: app, day: day, type: context.dayType(day))
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } else {
                // v8: the day type right here – Krank / Urlaub on top.
                DayTypeMenu(app: app, day: day, current: context.dayType(day))
            }
            if showsWeekNext {
                Button(action: continueToWeek) {
                    Label("Weiter: Woche \(day.week.label) abschließen", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .thaliaPrimaryAction()
            }
            if closed {
                Button {
                    sharing = ShareRequest(content: .day(day, context: context))
                } label: {
                    Label("Tag als Bild teilen", systemImage: "square.and.arrow.up")
                }
            }
            PDFButton(kind: .day(day), context: context, title: "Tag als PDF")
        } footer: {
            Text("Tagsüber erfassen, was passiert. Abends bewerten, was es bedeutet.")
        }
    }

    private var heroSubtitle: String {
        if context.isExcused(day) { return "\(context.excusedName(day)) – zählt nicht in die Wochenwertung" }
        return closed ? "Tag abgeschlossen" : "Noch offen – die Wertung kommt mit dem Abschluss"
    }

    private func heroValue(_ overall: DayOverall?) -> String {
        if context.isExcused(day) { return "–" }
        if closed { return Format.score(overall?.score, outOf: false) }
        return overall?.coverageText ?? "0 %"
    }

    private func heroProgress(_ overall: DayOverall?) -> Double {
        if context.isExcused(day) { return 0 }
        if closed { return (overall?.score ?? 0) / 10 }
        return overall?.coverage ?? 0
    }

    /// R40: a closed Sunday of a week that is still open leads on to the week.
    private var showsWeekNext: Bool {
        closed && day.weekday == .sunday && !context.isClosed
    }

    /// Closes the day and stays open: it scrolls up to the score and the celebration (R39).
    private func close(_ proxy: ScrollViewProxy) {
        guard !closed, !justClosed else { return }
        saveAnswers()
        withAnimation(.snappy) { app.closeDay(day) }
        justClosed = true
        withAnimation(.snappy) { proxy.scrollTo("hero", anchor: .top) }
    }

    private func finish() {
        saveAnswers()
        dismiss()
    }

    private func reopen() {
        saveAnswers()
        justClosed = false
        app.reopenDay(day)
    }

    private func continueToWeek() {
        saveAnswers()
        app.sheet = .closeWeek(day.week)
    }

    private func dayFacts(_ overall: DayOverall?) -> [(String, String)] {
        var facts: [(String, String)] = [("Typ", typeFact)]
        if let overall, overall.due > 0 { facts.append(("Punkte", "\(overall.due - overall.blank) von \(overall.due)")) }
        let totals = context.workTotals(on: day)
        if !totals.isEmpty { facts.append(("Fokus", totals.shortText)) }
        return facts
    }

    /// "2 von 3 diese Woche – heute nur markieren, …"; v8: "… · ½ krank" when sick or holiday days
    /// make the rest count half.
    private func weeklyHint(_ item: PlanItem) -> String {
        guard let quota = context.quotaProgress(item) else { return "" }
        var base: String = "\(quota.done) von \(quota.target) diese Woche"
        if quota.done < quota.target, context.quotaShare(item) > 1e-9 {
            base += " (½ \(context.excusedWord(context.excusedDayList)))"
        }
        return base + " – heute nur markieren, wenn erledigt; Fehlendes zählt erst am Wochenende."
    }

    /// "Arbeitstag" · "Tag"; v8: "Krank – zählt nicht".
    private var typeFact: String {
        let type: String = context.dayType(day)
        if context.isExcused(day) { return "\(context.excusedName(day)) – zählt nicht" }
        return type.isEmpty ? "Tag" : type
    }

    /// "28 PH × 50 min = 23 h 20 min netto" · "Frei – null PH ist richtig" · "keine".
    private var workText: String {
        let totals = context.workTotals(on: day)
        if !totals.isEmpty { return totals.explanation }
        return DayTypes.isWorkFree(context.dayType(day)) ? "Frei – null PH ist richtig" : "keine"
    }

    private var dayMeasures: [MeasureDefinition] {
        context.measures.filter { context.applies($0, on: day) && $0.record?.period == .day }
    }

    /// V9.1: what's there is shown, what's missing waits folded away.
    private var filledMeasures: [MeasureDefinition] { dayMeasures.filter { context.dayValue($0, on: day) != nil } }
    /// H1: only what this device can fill in counts as missing.
    private var missingMeasures: [MeasureDefinition] { dayMeasures.filter { context.countsAsMissing($0, on: day) } }
    private var healthElsewhereMeasures: [MeasureDefinition] {
        dayMeasures.filter { context.dayValue($0, on: day) == nil && context.isHealthElsewhere($0) }
    }

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
                    targetState(measure, value: value)
                }
                .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    /// R66: a met target shows its check; a missed one its own symbol and "verfehlt · Ziel ≤ 23:00".
    @ViewBuilder
    private func targetState(_ measure: MeasureDefinition, value: Double?) -> some View {
        switch targetMet(measure, value: value) {
        case true?:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .accessibilityLabel("erreicht")
        case false?:
            Label(missedText(measure), systemImage: "xmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Optional(Mark.missed).textColor)
                .accessibilityLabel(missedSpoken(measure))
        case nil:
            EmptyView()
        }
    }

    private func targetMet(_ measure: MeasureDefinition, value: Double?) -> Bool? {
        guard let record = measure.record else { return nil }
        return Measures.isMet(record, value: value)
    }

    /// "≤ 23:00", empty without a target.
    private func targetLabel(_ measure: MeasureDefinition) -> String {
        measure.record?.target?.label ?? ""
    }

    /// "verfehlt · Ziel ≤ 23:00".
    private func missedText(_ measure: MeasureDefinition) -> String {
        let goal: String = targetLabel(measure)
        return goal.isEmpty ? "verfehlt" : "verfehlt · Ziel \(goal)"
    }

    /// VoiceOver: "verfehlt, Ziel ≤ 23:00".
    private func missedSpoken(_ measure: MeasureDefinition) -> String {
        let goal: String = targetLabel(measure)
        return goal.isEmpty ? "verfehlt" : "verfehlt, Ziel \(goal)"
    }

    /// R58: the journal item with its marks, like on Today.
    private func journalRow(_ item: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(item.title, systemImage: "book.closed")
            MarkBar(mark: context.mark(item, on: day), options: context.options(item, on: day),
                    suggestion: context.suggestion(item, on: day), isProgress: item.schedule == .progress) {
                app.setMark($0, item: item, day: day)
            }
        }
        .padding(.vertical, 2)
    }

    /// R12: "Fahrrad fahren: Teilweise → Erledigt" with "Übernehmen".
    private func differingRow(_ suggestion: MarkSuggestion) -> some View {
        let isProgress: Bool = suggestion.item.schedule == .progress
        let current: String = suggestion.current.map { $0.label(progress: isProgress) } ?? "nicht erfasst"
        let proposed: String = suggestion.mark.label(progress: isProgress)
        return HStack(spacing: 8) {
            Text("\(suggestion.item.title): \(current) → \(proposed)")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button("Übernehmen") {
                app.setMark(suggestion.mark, item: suggestion.item, day: day)
            }
            .buttonStyle(.borderless)
        }
    }

    /// An open item with its marks as direct buttons; the title opens the details. Wide rows
    /// (≥ 640 pt) keep the buttons on the right like Today (R61).
    private func quickRow(_ item: PlanItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                quickTitle(item)
                    .frame(minWidth: 0, idealWidth: 300, maxWidth: .infinity, alignment: .leading)
                quickMarks(item, compact: true)
                    .frame(width: 300)
            }
            .frame(minWidth: 640)
            VStack(alignment: .leading, spacing: 6) {
                quickTitle(item)
                quickMarks(item, compact: false)
            }
        }
        .padding(.vertical, 2)
    }

    private func quickTitle(_ item: PlanItem) -> some View {
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
    }

    private func quickMarks(_ item: PlanItem, compact: Bool) -> some View {
        MarkBar(mark: context.mark(item, on: day), options: context.options(item, on: day),
                suggestion: context.suggestion(item, on: day), isProgress: item.schedule == .progress, compact: compact) {
            app.setMark($0, item: item, day: day)
        }
    }

    private func saveAnswers() {
        guard loaded, answers != loadedAnswers else { return }
        for (field, text) in answers where text != loadedAnswers[field] {
            app.store.setReflection(scope: day.string, field: field, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        loadedAnswers = answers
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
        .thaliaSheetFrame(width: 440, height: 320)
    }
}
