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

    private var week: WeekKey { context.week }
    private var next: WeekKey { week.adding(weeks: 1) }
    private var closed: Bool { context.isClosed }

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
            WeekSummarySections(context: context, celebrate: celebrates, showsReflection: false)

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
                    Button(action: reopen) {
                        Label("Woche wieder öffnen", systemImage: "lock.open")
                    }
                } else {
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
            } header: {
                Text("Abschluss")
            }

            planningSection
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
            for question in ReflectionQuestion.week {
                answers[question.id] = context.reflection(scope: week.string, field: question.id)
            }
            loadedAnswers = answers
            loaded = true
        }
        .onDisappear(perform: saveAnswers)
        .unsavedInput(answers != loadedAnswers, in: app)
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
        Clipboard.copy(WeekReport.markdown(app.store.weekContext(for: week, today: context.today).reportInput()))
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

    private func reopen() {
        saveAnswers()
        justClosed = false
        app.store.reopenWeek(week)
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

    private var week: WeekKey { context.week }

    var body: some View {
        Section {
            HeroCard(title: "Woche \(week.label)", subtitle: context.score.coverageText,
                     value: Format.score(context.score.overall, outOf: false), caption: "Woche",
                     progress: (context.score.overall ?? 0) / 10, facts: facts, celebrate: celebrate)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .id("hero")
            GoalBars(scores: context.goals.map { context.score.goalWeek[$0.key]?.score }, height: 48,
                     keys: context.goals.map(\.key))
            ForEach(context.goals) { goal in
                goalRow(goal)
            }
        } header: {
            Text("Wertung")
        } footer: {
            Text("Jedes Jahresziel 10 %. Die Wertung misst Verhalten, nicht Ergebnisse. Seit KW42 2026 gleich gewichtet – ältere Wochen sind nicht direkt vergleichbar.")
        }

        Section {
            Label(context.workTotals().explanation, systemImage: "briefcase")
            ForEach(targetMeasures) { measure in
                LabeledContent(measure.title) {
                    Text(measureLine(measure))
                        .monospacedDigit()
                }
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
        let closedDays: Int = week.days.filter { context.isClosed($0) }.count
        var list: [(String, String)] = [("Fokus", totals.isEmpty ? "–" : totals.shortText), ("Tage abgeschlossen", "\(closedDays)/7")]
        let targets: Int = context.weeklyTargets.count
        if targets > 0 { list.append(("Wochenziele erreicht", "\(context.weeklyTargetsMet)/\(targets)")) }
        return list
    }

    /// A goal in its colour with its week score.
    private func goalRow(_ goal: AnnualGoal) -> some View {
        let score: Double? = context.score.goalWeek[goal.key]?.score
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

    /// "Ø 7,2 h · Ziel ≥ 7/Tag", "–" without a value.
    private func measureLine(_ measure: MeasureDefinition) -> String {
        guard let record = measure.record, let target = record.target else { return "–" }
        var shown = "–"
        if let value = context.weekValue(measure) {
            let prefix: String = record.aggregation == .sum ? "" : "Ø "
            shown = prefix + Format.measure(value, unit: measure.unit)
        }
        let per: String = record.period == .week ? "/Woche" : "/Tag"
        return "\(shown) · Ziel \(target.label)\(per)"
    }

    private var openDays: [DayKey] {
        week.days.filter { $0 <= context.today && !context.isClosed($0) }
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

/// An item marked ✗ on a day.
private struct MissedMark: Identifiable {
    let item: PlanItem
    let day: DayKey
    var id: String { "\(item.code)|\(day.string)" }
}
