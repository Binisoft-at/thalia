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
        .sheetFrame(minWidth: 640, minHeight: 760)
    }
}

struct CloseWeekForm: View {
    let context: WeekContext
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var sharing: ShareRequest?
    @State private var answers: [String: String] = [:]
    @State private var loaded = false
    @State private var copiedReport = false
    @State private var copiedPrompt = false

    private var week: WeekKey { context.week }

    var body: some View {
        let score = context.score
        let openDays = week.days.filter { $0 <= context.today && !context.isClosed($0) }
        let missed: [(PlanItem, DayKey)] = context.items.flatMap { item -> [(PlanItem, DayKey)] in
            week.days.filter { context.mark(item, on: $0) == .missed }.map { (item, $0) }
        }
        Form {
            Section {
                HeroCard(title: "Woche \(week.label)", subtitle: score.coverageText,
                         value: Format.score(score.overall, outOf: false), caption: "Woche",
                         progress: (score.overall ?? 0) / 10,
                         facts: [("Fokus", context.workTotals().isEmpty ? "–" : context.workTotals().shortText),
                                 ("Tage abgeschlossen", "\(week.days.filter { context.isClosed($0) }.count)/7")],
                         celebrate: context.isClosed && (score.overall ?? 0) >= 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                GoalBars(scores: context.goals.map { score.goalWeek[$0.key]?.score }, height: 48)
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
                ForEach(context.goals) { goal in
                    LabeledContent("\(goal.key) \(goal.title)", value: Format.score(score.goalWeek[goal.key]?.score, outOf: false))
                        .monospacedDigit()
                }
            } header: {
                Text("Wertung")
            } footer: {
                Text("Jedes Jahresziel 10 %. Die Wertung misst Verhalten, nicht Ergebnisse. Seit KW42 2026 gleich gewichtet – ältere Wochen sind nicht direkt vergleichbar.")
            }

            Section("Was wirklich passiert ist") {
                let totals = context.workTotals()
                Label(totals.explanation, systemImage: "briefcase")
                ForEach(context.measures.filter { $0.record?.target != nil }) { measure in
                    if let record = measure.record, let target = record.target {
                        let value = context.weekValue(measure)
                        LabeledContent(measure.title) {
                            Text((value.map { (record.aggregation == .sum ? "" : "Ø ") + Format.measure($0, unit: measure.unit) } ?? "–")
                                 + " · Ziel \(target.label)\(record.period == .week ? "/Woche" : "/Tag")")
                                .monospacedDigit()
                        }
                    }
                }
                if !openDays.isEmpty {
                    Label("\(openDays.count) \(openDays.count == 1 ? "Tag" : "Tage") nicht abgeschlossen: \(openDays.map(\.weekday.short).joined(separator: ", "))",
                          systemImage: "moon")
                        .foregroundStyle(.orange)
                }
                if !missed.isEmpty {
                    DisclosureGroup("Verpasste Zusagen (\(missed.count))") {
                        ForEach(Array(missed.enumerated()), id: \.offset) { _, pair in
                            Text("\(pair.1.weekday.short) · \(pair.0.categoryKey) \(pair.0.title)")
                                .font(.caption)
                        }
                    }
                }
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
                if context.isClosed {
                    Button {
                        saveAnswers()
                        app.store.reopenWeek(week)
                    } label: {
                        Label("Woche wieder öffnen", systemImage: "lock.open")
                    }
                } else {
                    Button {
                        saveAnswers()
                        app.store.closeWeek(week)
                        app.toasts.show("\(week.label) abgeschlossen", symbol: "flag.checkered")
                    } label: {
                        Label("Woche abschließen", systemImage: "flag.checkered")
                            .frame(maxWidth: .infinity)
                    }
                    .primaryActionStyle()
                }
                Button {
                    saveAnswers()
                    Clipboard.copy(WeekReport.markdown(app.store.weekContext(for: week, today: context.today).reportInput()))
                    copiedReport = true
                } label: {
                    Label(copiedReport ? "Wochenbericht kopiert" : "Wochenbericht kopieren", systemImage: copiedReport ? "checkmark" : "doc.on.doc")
                }
                Button {
                    saveAnswers()
                    Clipboard.copy(planningPrompt())
                    copiedPrompt = true
                } label: {
                    Label(copiedPrompt ? "Planungs-Prompt kopiert" : "Planungs-Prompt für \(week.adding(weeks: 1).label) kopieren",
                          systemImage: copiedPrompt ? "checkmark" : "sparkles")
                }
            } header: {
                Text("Abschluss und nächste Woche")
            } footer: {
                Text("Der Prompt enthält das CSV-Format, deine Struktur und diesen Wochenbericht. In ChatGPT einfügen, deine Sonntagsnachricht anhängen, die CSV unter + → Wochenplan importieren einfügen.")
            }
        }
        .sheet(item: $sharing) { request in
            ShareSheet(content: request.content)
        }
        .formStyle(.grouped)
        .navigationTitle("Woche abschließen")
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
            for question in ReflectionQuestion.week {
                answers[question.id] = context.reflection(scope: week.string, field: question.id)
            }
            loaded = true
        }
        .onDisappear(perform: saveAnswers)
    }

    /// Read fresh from the store, so the answers just typed are in it.
    private func planningPrompt() -> String {
        let fresh = app.store.weekContext(for: week, today: context.today)
        return PlanPrompt.text(for: week.adding(weeks: 1), goals: fresh.data.goals, categories: fresh.data.categories,
                               measures: fresh.measures.compactMap(\.record), lastWeekReport: WeekReport.markdown(fresh.reportInput()),
                               changes: fresh.changes.compactMap(\.record))
    }

    private func binding(_ field: String) -> Binding<String> {
        Binding(get: { answers[field] ?? "" }, set: { answers[field] = $0 })
    }

    private func saveAnswers() {
        guard loaded else { return }
        for (field, text) in answers {
            app.store.setReflection(scope: week.string, field: field, text: text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
