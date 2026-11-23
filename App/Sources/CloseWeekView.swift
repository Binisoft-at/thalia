import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// "Woche abschließen": the score and the reality behind it, the four questions, then the report
/// and the planning prompt for the next Sunday conversation. A manageable next week, not a
/// punishment plan for this one.
struct CloseWeekView: View {
    let week: WeekKey
    @Environment(AppModel.self) private var app

    var body: some View {
        NavigationStack {
            WeekReader(week: week, today: app.today) { context in
                CloseWeekForm(context: context)
            }
        }
        .thaliaSheetFrame(width: 640, height: 760)
    }
}

struct CloseWeekForm: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var sharing: ShareRequest?
    @State private var answers: [String: String] = [:]
    /// The answers as last loaded or saved – typed text differs until it is saved (R14).
    @State private var loadedAnswers: [String: String] = [:]
    @State private var loaded = false
    @State private var copiedReport = false
    @State private var copiedPrompt = false
    /// True only in the moment of closing: the celebration runs then, not on every later look (R72).
    @State private var justClosed = false
    /// v11 P6.8: "Woche wieder öffnen" of a frozen week asks first.
    @State private var confirmsReopen = false

    private var week: WeekKey { context.week }
    private var next: WeekKey { week.adding(weeks: 1) }
    private var closed: Bool { context.isClosed }

    /// v11 P6.7: planning the week after this one only while that week isn't over yet (Monday after a week still
    /// plans this week) – an old week closed from the Rückblick offers none.
    private var plansNextWeek: Bool { next >= context.today.week }

    /// v11 P4.16: closing the running week before Sunday is possible, but said.
    private var runsUntilSunday: Bool {
        !closed && week == context.today.week && context.today.weekday != .sunday
    }

    /// v11 P7.1 (3): Mac, Watch and iPad scored a week that reads Apple Health without those values; closing there
    /// asked the iPhone to score it again.
    private var healthNote: String? {
        guard closed, !HealthDevice.scoresHealth, context.readsHealthProgress else { return nil }
        // HEALTHSHARE: scored with the values the iPhone shares – nothing missing (P9.3, P7.1 (3)).
        guard !app.store.healthShareCovers(week) else { return nil }
        return "Hier ohne Werte aus Apple Health gewertet – das iPhone rechnet nach dem Abgleich nach."
    }

    /// v11 P6.8: "Ihre Wertung 7,84 wird …" – the stored score of the frozen week.
    private var reopenMessage: String {
        let score: String = Format.score(context.recalculatedScore, outOf: false)
        return "Die Woche gehört zu einem früheren Abschnitt. Ihre Wertung \(score) wird beim erneuten Abschließen nach heutigen Regeln neu berechnet."
    }

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
                // ⇧⌘↩ again on the Mac closes the week; once closed it finishes (R39, R40).
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
        Form {
            WeekSummarySections(context: context, celebrate: celebrates, showsReflection: false, heroNote: healthNote)

            Section {
                HStack {
                    Button {
                        sharing = ShareRequest(content: .week(context))
                    } label: {
                        Label("Woche teilen", systemImage: "square.and.arrow.up")
                    }
                    Spacer()
                    PDFShareButton(context: context)
                }
                .buttonStyle(.borderless)
            }

            Section {
                ForEach(ReflectionQuestion.week) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.question).font(.subheadline.weight(.semibold))
                        TextField(question.hint, text: binding(question.id), axis: .vertical)
                            .lineLimit(1...8)
                        if let other = changedElsewhere(question.id) {
                            // v11 P5.16: typed here, changed on another device meanwhile – the own text wins unless taken.
                            HStack(spacing: 8) {
                                Label("Am anderen Gerät geändert", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Spacer(minLength: 6)
                                Button("Übernehmen") { takeOver(question.id, text: other) }
                                    .font(.caption.weight(.semibold))
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Wochenreflexion")
            } footer: {
                Text("Ein gutes Ergebnis ist kein Grund, den Plan zu erhöhen. Oft ist die beste Antwort: dieselbe Woche wiederholen.")
            }

            Section {
                if closed {
                    Button(action: finish) {
                        Label("Fertig", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .thaliaPrimaryAction()
                    // v11 P6.8: quieter than "Fertig"; Widerrufen in the toast, a frozen week asks first.
                    Button(action: reopen) {
                        Label("Woche wieder öffnen", systemImage: "lock.open")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                } else {
                    if runsUntilSunday {
                        // v11 P4.16: a Saturday closing stays possible.
                        Label("Diese Woche läuft noch bis Sonntag.", systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        close(proxy)
                    } label: {
                        Label("Woche abschließen", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .thaliaPrimaryAction()
                }
                Button(action: copyReport) {
                    Label(copiedReport ? "Wochenbericht kopiert" : "Wochenbericht kopieren", systemImage: copiedReport ? "checkmark" : "doc.on.doc")
                }
                if !app.isSandbox {
                    // v11 P3.13: only when no device has made a backup by hand for 30 days.
                    BackupReminderRow()
                }
            } header: {
                Text("Abschluss")
            }

            if plansNextWeek {
                planningSection
            }
        }
        .confirmationDialog("\(week.label) wieder öffnen?", isPresented: $confirmsReopen, titleVisibility: .visible) {
            Button("Woche wieder öffnen", action: reopenNow)
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text(reopenMessage)
        }
        .sheet(item: $sharing) { request in
            ShareSheet(content: request.content)
                .environment(app)
                .toastHost(app)
        }
        .formStyle(.grouped)
        .navigationTitle("Woche abschließen")
        .inlineNavigationTitle()
        .onAppear {
            guard !loaded else { return }
            answers = storedAnswers
            loadedAnswers = answers
            loaded = true
        }
        // v11 P5.16: what another device saves meanwhile – untouched fields follow, typed ones ask.
        .onChange(of: storedAnswers) { _, stored in follow(stored) }
        .onDisappear(perform: saveAnswers)
        .unsavedInput(answers != loadedAnswers, in: app)
    }

    // MARK: Reflection from another device (v11 P5.16)

    /// The week's saved answers as the week reads them now – also what another device saved after this one opened.
    private var storedAnswers: [String: String] {
        var stored: [String: String] = [:]
        for question in ReflectionQuestion.week {
            stored[question.id] = context.reflection(scope: week.string, field: question.id)
        }
        return stored
    }

    /// A field nobody typed in here follows the saved text silently; a typed one keeps its text (it wins on saving, as
    /// before) and shows "Am anderen Gerät geändert" (`changedElsewhere`).
    private func follow(_ stored: [String: String]) {
        guard loaded else { return }
        for (field, text) in stored where answers[field] == loadedAnswers[field] && answers[field] != text {
            answers[field] = text
            loadedAnswers[field] = text
        }
    }

    /// The other device's text when the saved one changed after this field was loaded and differs from what it shows.
    private func changedElsewhere(_ field: String) -> String? {
        guard loaded else { return nil }
        let typed: String = answers[field] ?? ""
        let loadedText: String = loadedAnswers[field] ?? ""
        let saved: String = context.reflection(scope: week.string, field: field)
        guard saved != loadedText, saved != typed else { return nil }
        return saved
    }

    /// "Übernehmen": the other device's text, as if loaded now.
    private func takeOver(_ field: String, text: String) {
        answers[field] = text
        loadedAnswers[field] = text
    }

    // MARK: Next week (R56)

    /// After closing: "1 · Prompt kopieren", "2 · CSV einfügen". Before: the prompt with a hint.
    private var planningSection: some View {
        Section {
            if closed {
                Button(action: copyPrompt) {
                    Label(copiedPrompt ? "1 · Prompt kopiert" : "1 · Prompt kopieren", systemImage: copiedPrompt ? "checkmark" : "sparkles")
                }
                Button(action: pastePlan) {
                    Label("2 · CSV einfügen", systemImage: "doc.on.clipboard")
                }
            } else {
                Label("Erst abschließen – dann kennt der Prompt verfehlte Ziele.", systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Button(action: copyPrompt) {
                    Label(copiedPrompt ? "Planungs-Prompt kopiert" : "Planungs-Prompt für \(next.label) kopieren",
                          systemImage: copiedPrompt ? "checkmark" : "sparkles")
                }
            }
        } header: {
            Text("Nächste Woche · \(next.label)")
        } footer: {
            Text("Der Prompt enthält das CSV-Format, deine Struktur, den Plan und den Bericht dieser Woche. In ChatGPT einfügen, deine Sonntagsnachricht anhängen und die Antwort unter „2 · CSV einfügen“ einsetzen.")
        }
    }

    /// Saved first, so the answers just typed are in the prompt.
    private func copyPrompt() {
        saveAnswers()
        Clipboard.copy(app.store.planningPrompt(for: next, today: context.today))
        copiedPrompt = true
    }

    private func pastePlan() {
        saveAnswers()
        app.sheet = .planWeek(next)
    }

    private func copyReport() {
        saveAnswers()
        let store: TrackerStore = app.store
        // v10 (§1.2.5): with the block "Jahresziel-Ergebnisse".
        let input: WeekReportInput = store.weekContext(for: week, today: context.today).reportInput(results: store.resultLines(today: context.today))
        Clipboard.copy(WeekReport.markdown(input))
        copiedReport = true
    }

    // MARK: Closing (R39, R72, R80)

    private var celebrates: Bool {
        justClosed && closed && (context.score.overall ?? 0) >= 8
    }

    /// Closes the week and stays open: it scrolls up to the score and the celebration (R39).
    private func close(_ proxy: ScrollViewProxy) {
        guard !closed, !justClosed else { return }
        saveAnswers()
        withAnimation(.snappy) { app.closeWeek(week) }
        justClosed = true
        withAnimation(.snappy) { proxy.scrollTo("hero", anchor: .top) }
    }

    private func finish() {
        saveAnswers()
        dismiss()
    }

    /// v11 P6.8: a week of an earlier segment asks first – its stored score is computed again under today's rules
    /// when it is closed again.
    private func reopen() {
        saveAnswers()
        if context.isFrozen {
            confirmsReopen = true
        } else {
            reopenNow()
        }
    }

    /// v11 P6.8: `AppModel.reopenWeek` keeps a snapshot – the toast "KW45 wieder geöffnet" with "Widerrufen" writes back
    /// the score, the goal and category scores; the reminders are planned again.
    private func reopenNow() {
        justClosed = false
        app.reopenWeek(week)
    }

    private func binding(_ field: String) -> Binding<String> {
        Binding(get: { answers[field] ?? "" }, set: { answers[field] = $0 })
    }

    private func saveAnswers() {
        guard loaded, answers != loadedAnswers else { return }
        for (field, text) in answers where text != loadedAnswers[field] {
            app.store.setReflection(scope: week.string, field: field, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        loadedAnswers = answers
    }
}

/// R57: the designed week overview – score with the goals in their colours, what really happened
/// and (read-only) the reflection. The closing sheet and the report both show it.
struct WeekSummarySections: View {
    let context: WeekContext
    var celebrate = false
    var showsReflection = true
    /// v11 P7.1: a line under the hero ("Hier ohne Werte aus Apple Health gewertet – …"); nil shows none.
    var heroNote: String? = nil

    private var week: WeekKey { context.week }

    /// v11 P6.1: a frozen closed week shows the score it stored; every other week the live one.
    private var heroScore: Double? { context.shownScore }

    private var heroProgress: Double {
        let value: Double = heroScore ?? 0
        return value / 10
    }

    var body: some View {
        Section {
            HeroCard(title: "Woche \(week.label)", subtitle: context.score.coverageText,
                     value: Format.score(heroScore, outOf: false), caption: "Woche",
                     progress: heroProgress, facts: facts, celebrate: celebrate)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .id("hero")
            if let heroNote {
                Label(heroNote, systemImage: "heart.text.square")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            GoalBars(scores: context.goals.map { context.scoredGoalScore($0.key) }, height: 48,
                     keys: context.goals.map(\.key))
            ForEach(context.goals) { goal in
                goalRow(goal)
            }
        } header: {
            Text("Wertung")
        } footer: {
            // v11 P6.3: no fixed share – a goal can be excused or added.
            Text("Jedes Jahresziel zählt gleich viel. Die Wertung misst Verhalten, nicht Ergebnisse. Seit KW42 2026 gleich gewichtet – ältere Wochen sind nicht direkt vergleichbar.")
        }

        Section {
            Label(context.workTotals().explanation, systemImage: "briefcase")
            ForEach(targetMeasures) { measure in
                LabeledContent(measure.title) {
                    Text(measureLine(measure))
                        .monospacedDigit()
                }
            }
            if !context.excusedDayList.isEmpty {
                // v8: sick and holiday days are left out of the score.
                Label(excusedDaysText, systemImage: DayTypes.symbol(for: context.dayType(context.excusedDayList[0])))
                    .foregroundStyle(.secondary)
            }
            if !openDays.isEmpty {
                Label(openDaysText, systemImage: "moon")
                    .foregroundStyle(.orange)
            }
            let missed: [MissedMark] = missedMarks
            if !missed.isEmpty {
                DisclosureGroup("Verpasste Zusagen (\(missed.count))") {
                    ForEach(missed) { entry in
                        Text("\(entry.day.weekday.short) · \(entry.item.categoryKey) \(entry.item.title)")
                            .font(.caption)
                    }
                }
            }
        } header: {
            Text("Was wirklich passiert ist")
        }

        if showsReflection {
            Section {
                let answered: [ReflectionQuestion] = answeredQuestions
                if answered.isEmpty {
                    Text("Noch keine Wochenreflexion.")
                        .foregroundStyle(.secondary)
                }
                ForEach(answered) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.question)
                            .font(.subheadline.weight(.semibold))
                        Text(context.reflection(scope: week.string, field: question.id))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Wochenreflexion")
            }
        }
    }

    private var facts: [(String, String)] {
        let totals = context.workTotals()
        // v8: sick and holiday days don't need closing ("3/5 · 2 krank").
        var list: [(String, String)] = [("Fokus", totals.isEmpty ? "–" : totals.shortText), ("Tage abgeschlossen", context.closedDaysText)]
        let targets: Int = context.weeklyTargets.count
        if targets > 0 { list.append(("Wochenziele erreicht", "\(context.weeklyTargetsMet)/\(targets)")) }
        return list
    }

    /// A goal in its colour with its week score (v11 P6.1: a frozen closed week's stored one).
    private func goalRow(_ goal: AnnualGoal) -> some View {
        let score: Double? = context.scoredGoalScore(goal.key)
        return HStack(spacing: 10) {
            Text(goal.key)
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(goal.color, in: .circle)
            Text(goal.title)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(Format.score(score, outOf: false))
                .monospacedDigit()
                .fontWeight(.semibold)
                .foregroundStyle(score == nil ? Color.secondary : goal.color)
        }
        .accessibilityElement(children: .combine)
    }

    private var targetMeasures: [MeasureDefinition] {
        context.measures.filter { $0.record?.target != nil }
    }

    /// "Ø 7,2 h · Ziel ≥ 7/Tag", "–" without a value. v8: a weekly target scaled for sick and
    /// holiday days: "3 · Ziel ≥ 4,8/Woche (statt 8 – 2 Tage krank)".
    private func measureLine(_ measure: MeasureDefinition) -> String {
        guard let record = measure.record, let full = record.target else { return "–" }
        let target: Target = record.period == .week ? (context.effectiveTarget(record) ?? full) : full
        var shown = "–"
        if let value = context.weekValue(measure) {
            let prefix: String = record.aggregation == .sum ? "" : "Ø "
            shown = prefix + Format.measure(value, unit: measure.unit)
        }
        let per: String = record.period == .week ? "/Woche" : "/Tag"
        let excused: String = context.excusedDaysText(context.excusedDays(of: measure))
        let fullText: String = targetText(full, record: record, unit: measure.unit)
        if record.period == .week, context.targetShare(record) <= 1e-9 {
            // v8: every day of the target was a sick or holiday day – not scored (Decision 4).
            let reason: String = excused.isEmpty ? "zählt nicht" : "zählt nicht – \(excused)"
            return "\(shown) · Ziel \(fullText)\(per) (\(reason))"
        }
        let base: String = "\(shown) · Ziel \(targetText(target, record: record, unit: measure.unit))\(per)"
        guard target != full else { return base }
        let note: String = excused.isEmpty ? "statt \(fullText)" : "statt \(fullText) – \(excused)"
        return base + " (\(note))"
    }

    /// v11 P1.7: a weekly target as every screen rounds it – "≥ 86" (not "≥ 85,71"), "> 85", "129–154"; a daily
    /// target as written ("≥ 7").
    private func targetText(_ target: Target, record: MeasureRecord, unit: String) -> String {
        guard record.period == .week else { return target.label }
        let shown: String = Format.amount(target: target, unit: unit)
        let isTime: Bool = target.isTime || Units.isTime(unit)
        return target.comparison == .atLeast && !isTime ? "≥ " + shown : shown
    }

    /// v8: "Krank/Urlaub: Fr, Sa, So – zählen nicht in die Wertung".
    private var excusedDaysText: String {
        let days: [DayKey] = context.excusedDayList
        let names: String = days.map(\.weekday.short).joined(separator: ", ")
        let verb: String = days.count == 1 ? "zählt" : "zählen"
        return "\(context.excusedDaysText(days)): \(names) – \(verb) nicht in die Wertung"
    }

    /// Days not closed yet – sick and holiday days don't need closing (v8).
    private var openDays: [DayKey] {
        week.days.filter { $0 <= context.today && !context.isClosed($0) && !context.isExcused($0) }
    }

    private var openDaysText: String {
        let days: [DayKey] = openDays
        let noun: String = days.count == 1 ? "Tag" : "Tage"
        return "\(days.count) \(noun) nicht abgeschlossen: \(days.map(\.weekday.short).joined(separator: ", "))"
    }

    private var missedMarks: [MissedMark] {
        context.items.flatMap { item -> [MissedMark] in
            week.days.filter { context.mark(item, on: $0) == .missed }.map { MissedMark(item: item, day: $0) }
        }
    }

    private var answeredQuestions: [ReflectionQuestion] {
        ReflectionQuestion.week.filter { !context.reflection(scope: week.string, field: $0.id).isEmpty }
    }
}

/// v11 P3.13: the calm line after the report buttons – "Letzte Sicherung vor 34 Tagen – jetzt sichern?" when no
/// device has made a backup by hand for 30 days ("Noch keine Sicherung – jetzt sichern?" without any); a tap makes
/// one ("Sicherung erstellen…"). The synced stamp is observed, so the line goes once a backup is saved.
private struct BackupReminderRow: View {
    @Query private var stamps: [AppSetting]

    init() {
        let key: String = SettingKeys.backupLast
        _stamps = Query(filter: #Predicate<AppSetting> { $0.key == key })
    }

    private var line: String? {
        BackupWriter.closingReminder(stamp: BackupStamp.latest(stamps.map(\.value)), now: Date())
    }

    var body: some View {
        if let line {
            BackupExportButton(title: line)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// An item marked ✗ on a day.
private struct MissedMark: Identifiable {
    let item: PlanItem
    let day: DayKey
    var id: String { "\(item.code)|\(day.string)" }
}
