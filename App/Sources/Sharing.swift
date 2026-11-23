import SwiftUI
import UniformTypeIdentifiers
import BinisoftKit
import ThaliaCore
#if os(macOS)
import AppKit
#endif

// V12: livelier overviews (animated gradient heads, a small celebration), V13: share a day or a
// week as an image in a few designed templates, V1: the week as a PDF with every category.

// MARK: Animated gradient

/// A slowly moving mesh gradient in Thalia's colours. Still when "Bewegung reduzieren" is on. v11 P6.11: it pauses
/// while the scene isn't active (iOS: in the background; Mac: also while the window isn't key or the app isn't in
/// front) – no 20 frames a second for nobody.
struct AuroraBackground: View {
    var palette: [Color] = AuroraBackground.thalia
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @Environment(\.controlActiveState) private var controlActiveState
    #endif

    /// The gradient moves only while someone can see it.
    private var isLive: Bool {
        #if os(macOS)
        return scenePhase == .active && (controlActiveState == .key || controlActiveState == .active)
        #else
        return scenePhase == .active
        #endif
    }

    static let thalia: [Color] = [
        Color(red: 0.05, green: 0.36, blue: 0.42), Color(red: 0.10, green: 0.55, blue: 0.58), Color(red: 0.36, green: 0.30, blue: 0.70),
        Color(red: 0.12, green: 0.62, blue: 0.55), Color(red: 0.20, green: 0.45, blue: 0.75), Color(red: 0.55, green: 0.35, blue: 0.75),
        Color(red: 0.04, green: 0.30, blue: 0.40), Color(red: 0.16, green: 0.50, blue: 0.62), Color(red: 0.30, green: 0.62, blue: 0.70),
    ]

    var body: some View {
        if animated && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 20, paused: !isLive)) { timeline in
                mesh(time: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            mesh(time: 0)
        }
    }

    private func mesh(time: Double) -> some View {
        let wobble: Float = Float(sin(time * 0.35)) * 0.12
        let drift: Float = Float(cos(time * 0.27)) * 0.10
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5 + drift, 0], [1, 0],
            [0, 0.5 - wobble], [0.5 + wobble, 0.5 + drift], [1, 0.5 + wobble],
            [0, 1], [0.5 - drift, 1], [1, 1],
        ]
        return MeshGradient(width: 3, height: 3, points: points, colors: palette)
    }
}

/// The head of an overview: big number, a ring, a title and up to three facts, on the gradient.
struct HeroCard: View {
    let title: String
    let subtitle: String
    /// The big number ("8,25" or "62 %").
    let value: String
    let caption: String
    /// 0…1 for the ring.
    let progress: Double
    var facts: [(String, String)] = []
    var celebrate = false
    /// Still gradient (PDF and images).
    var animated = true
    /// R55: smaller ring and padding, at most two facts (iPhone week).
    var compact = false

    @State private var shown = false

    private var ringSize: CGFloat { compact ? 68 : 96 }
    private var ringWidth: CGFloat { compact ? 7 : 9 }
    private var valueSize: CGFloat { compact ? 20 : 26 }
    private var cardPadding: CGFloat { compact ? 12 : 18 }
    private var maxFacts: Int { compact ? 2 : 3 }

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 14 : 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: ringWidth)
                Circle()
                    .trim(from: 0, to: (shown || !animated) ? CGFloat(min(1, max(0, progress))) : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: valueSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(.caption2.weight(.semibold))
                        .opacity(0.85)
                }
                .padding(compact ? 7 : 10)
            }
            .frame(width: ringSize, height: ringSize)
            .overlay(alignment: .topTrailing) {
                // Always there (hidden), so the bounce sees `celebrate` change (R39).
                Image(systemName: "sparkles")
                    .font(.title3)
                    .opacity(celebrate ? 1 : 0)
                    .symbolEffect(.bounce, value: celebrate)
                    .offset(x: 8, y: -6)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: compact ? 4 : 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.85)
                ForEach(Array(facts.prefix(maxFacts).enumerated()), id: \.offset) { _, fact in
                    HStack(spacing: 6) {
                        Text(fact.0).opacity(0.8)
                        Text(fact.1).fontWeight(.semibold)
                    }
                    .font(.caption)
                    .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(cardPadding)
        .background {
            AuroraBackground(animated: animated)
                .clipShape(.rect(cornerRadius: compact ? 20 : 24, style: .continuous))
        }
        .overlay {
            if celebrate { CelebrationView() }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { shown = true }
        }
        // Only when a closing turns the celebration on – never just for looking at it again (R72).
        .sensoryFeedback(.success, trigger: celebrate) { _, isOn in isOn }
        .accessibilityElement(children: .combine)
    }
}

/// A short burst of dots for a good day or week. Nothing moves with "Bewegung reduzieren". v11 P6.11: the timeline
/// stops once the burst is over (2,3 s) – it looks the same, without drawing on forever.
struct CelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: nil, paused: finished)) { timeline in
                Canvas { context, size in
                    CelebrationView.draw(&context, size: size, elapsed: timeline.date.timeIntervalSince(start))
                }
            }
            .allowsHitTesting(false)
            .onAppear { start = Date() }
            .task {
                try? await Task.sleep(nanoseconds: 2_300_000_000)
                finished = true
            }
        }
    }

    private static func draw(_ context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        guard elapsed < 2.2 else { return }
        let centerX: Double = Double(size.width) / 2
        let centerY: Double = Double(size.height) / 2
        let alpha: Double = max(0, 1 - elapsed / 2.2)
        let fall: Double = 40 * elapsed * elapsed
        let colors: [Color] = [.white, .yellow, .mint, .pink]
        for index in 0..<28 {
            let seed: Double = Double(index) * 12.9898
            let angle: Double = seed.truncatingRemainder(dividingBy: 6.283)
            let speed: Double = 60 + (seed * 7).truncatingRemainder(dividingBy: 90)
            let distance: Double = speed * elapsed
            let x: Double = centerX + cos(angle) * distance
            let y: Double = centerY + sin(angle) * distance + fall
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 5, height: 5)),
                         with: .color(colors[index % colors.count].opacity(alpha)))
        }
    }
}

// MARK: Share images (V13)

/// A share sheet to open (Identifiable for `.sheet(item:)`).
struct ShareRequest: Identifiable {
    let id = UUID()
    let content: ShareContent
}

/// What a share card shows – a day or a week.
struct ShareContent {
    var title: String
    var subtitle: String
    var score: Double?
    var fill: Double
    var goalScores: [Double?]
    var goalTitles: [String]
    var facts: [(String, String)]
    var motto: String
    /// v11 P6.5: the text in the ring instead of the score or the share ("–" on a sick or holiday day); nil: as before.
    var ringText: String? = nil
    /// v11 P6.5, P6.9: the line under it instead of "von 10" / "erfasst" ("Krank", "bisher"); nil: as before.
    var ringCaption: String? = nil

    @MainActor
    static func day(_ day: DayKey, context: WeekContext) -> ShareContent {
        let overall: DayOverall? = context.score.days[day]
        var goalScores: [Double?] = []
        for goal in context.goals {
            let scores: [Double] = context.categories(of: goal).compactMap { context.score.category($0.key, on: day).score }
            goalScores.append(scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count))
        }
        let complete: Int = context.categories.filter { context.score.category($0.key, on: day).isComplete && context.score.category($0.key, on: day).due > 0 }.count
        let totals = context.workTotals(on: day)
        var facts: [(String, String)] = [("Erfasst", "\(percent(overall?.coverage ?? 0)) %"), ("Kategorien komplett", "\(complete)")]
        let excused: Bool = context.isExcused(day)
        // v8: a sick or holiday day doesn't count.
        if excused { facts = [(context.excusedName(day), "zählt nicht")] }
        if !totals.isEmpty { facts.append(("Fokus", totals.shortText)) }
        var content = ShareContent(title: day.longLabel, subtitle: context.week.label, score: context.isClosed(day) ? overall?.score : nil,
                                   fill: overall?.coverage ?? 0, goalScores: goalScores, goalTitles: context.goals.map(\.title),
                                   facts: facts, motto: context.plan?.title ?? "")
        if excused {
            // v11 P6.5: an empty ring with "–" and "Krank" – not a full one.
            content.score = nil
            content.fill = 0
            content.ringText = "–"
            content.ringCaption = context.excusedName(day)
        }
        return content
    }

    /// v11 P6.1: a frozen closed week shows the score and goal scores it stored; P6.9: a week that isn't closed is a
    /// "Zwischenstand" – its ring says "bisher".
    @MainActor
    static func week(_ context: WeekContext) -> ShareContent {
        let totals = context.workTotals()
        let scored: Int = context.shownGoalsScored
        let total: Int = context.score.goalsTotal
        // v8: "3/5 · 2 krank" – sick and holiday days don't count.
        var facts: [(String, String)] = [("Ziele bewertet", "\(scored)/\(total)"),
                                         ("Tage abgeschlossen", context.closedDaysText)]
        if context.score.isExcused { facts[0] = ("Woche", "zählt nicht") }
        if !totals.isEmpty { facts.append(("Fokus", totals.shortText)) }
        let subtitle: String = context.isClosed ? "Meine Woche" : "Zwischenstand"
        var content = ShareContent(title: "\(context.week.label) · \(context.week.rangeLabel)", subtitle: subtitle,
                                   score: context.shownScore, fill: Double(scored) / Double(max(1, total)),
                                   goalScores: context.goals.map { context.scoredGoalScore($0.key) },
                                   goalTitles: context.goals.map(\.title), facts: facts, motto: context.plan?.title ?? "")
        if context.score.isExcused && content.score == nil {
            // A week of only sick or holiday days has no score – an empty ring, not a share of goals.
            content.fill = 0
            content.ringText = "–"
            content.ringCaption = "zählt nicht"
        } else if !context.isClosed && content.score != nil {
            content.ringCaption = "bisher"
        }
        return content
    }

    /// The number in the ring: the score, else the share recorded ("62 %"), unless `ringText` says otherwise.
    var shownRingText: String {
        if let ringText { return ringText }
        return score.map { Format.score($0) } ?? "\(percent(fill)) %"
    }

    /// The line under the number: "von 10" with a score, "erfasst" without, unless `ringCaption` says otherwise.
    var shownRingCaption: String {
        if let ringCaption { return ringCaption }
        return score == nil ? "erfasst" : "von 10"
    }
}

enum ShareTemplate: String, CaseIterable, Identifiable {
    case aurora, clear, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .aurora: "Aurora"
        case .clear: "Klar"
        case .night: "Nacht"
        }
    }
}

/// A 4:5 card (rendered at 1080 × 1350).
struct ShareCard: View {
    let content: ShareContent
    let template: ShareTemplate
    var showsGoalNames = false

    private var foreground: Color { template == .clear ? Color(red: 0.08, green: 0.16, blue: 0.20) : .white }
    private var accent: Color { template == .clear ? Brand.accent : .white }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Thalia", systemImage: "leaf.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Text(content.subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.8)
            }
            Text(content.title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    Circle().stroke(accent.opacity(0.2), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: CGFloat(content.score.map { $0 / 10 } ?? content.fill))
                        .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text(content.shownRingText)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(content.shownRingCaption)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(0.75)
                    }
                    .padding(16)
                }
                .frame(width: 150, height: 150)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(content.facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(fact.1)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(fact.0)
                                .font(.system(size: 12, weight: .medium))
                                .opacity(0.75)
                        }
                    }
                }
            }
            goals
            Spacer(minLength: 0)
            if !content.motto.isEmpty {
                Text("„\(content.motto)“")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .italic()
                    .opacity(0.85)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(foreground)
        .padding(28)
        .frame(width: 360, height: 450)
        .background { background }
        .environment(\.colorScheme, template == .clear ? .light : .dark)
    }

    @ViewBuilder
    private var background: some View {
        switch template {
        case .aurora:
            AuroraBackground(animated: false)
        case .clear:
            LinearGradient(colors: [Color(red: 0.97, green: 0.98, blue: 0.97), Color(red: 0.88, green: 0.95, blue: 0.94)],
                           startPoint: .top, endPoint: .bottom)
        case .night:
            ZStack {
                Color(red: 0.05, green: 0.07, blue: 0.11)
                RadialGradient(colors: [Brand.accent.opacity(0.55), .clear], center: .topTrailing, startRadius: 10, endRadius: 320)
                RadialGradient(colors: [Color.purple.opacity(0.35), .clear], center: .bottomLeading, startRadius: 10, endRadius: 280)
            }
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 6) {
            // v11 P6.3: as many as there are.
            Text(Format.count(content.goalScores.count, "Jahresziel", "Jahresziele"))
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.75)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(content.goalScores.enumerated()), id: \.offset) { index, score in
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4).fill(accent.opacity(0.15))
                            RoundedRectangle(cornerRadius: 4).fill(accent.opacity(score == nil ? 0 : 0.95))
                                .frame(height: 70 * CGFloat((score ?? 0) / 10))
                        }
                        .frame(height: 70)
                        Text(showsGoalNames ? String(content.goalTitles[safe: index]?.prefix(3) ?? "") : "\(index + 1)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .opacity(0.8)
                    }
                }
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

/// Pick a template, preview, share as an image.
struct ShareSheet: View {
    let content: ShareContent
    @Environment(\.dismiss) private var dismiss
    @State private var template: ShareTemplate = .aurora
    @State private var showsGoalNames = false
    /// Mac: the picture as PNG for the save panel (R71).
    @State private var exportFile: ExportFile?
    @State private var exporting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Picker("Vorlage", selection: $template) {
                        ForEach(ShareTemplate.allCases) { template in
                            Text(template.title).tag(template)
                        }
                    }
                    .pickerStyle(.segmented)
                    ShareCard(content: content, template: template, showsGoalNames: showsGoalNames)
                        .clipShape(.rect(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    Toggle("Zielnamen statt Nummern", isOn: $showsGoalNames)
                    if let image = rendered {
                        ShareLink(item: image, preview: SharePreview(content.title, image: image)) {
                            Label("Bild teilen", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .thaliaPrimaryAction()
                    }
                    #if os(macOS)
                    Button(action: saveImage) {
                        Label("Bild sichern…", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    #endif
                    Text("Das Bild zeigt nur Zahlen und – wenn du willst – die Namen deiner Ziele, keine Einträge oder Notizen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Teilen")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
            .fileExporter(isPresented: $exporting, document: exportFile, contentType: .png,
                          defaultFilename: "Thalia-\(template.title)") { _ in
                exportFile = nil
            }
        }
        .thaliaSheetFrame(width: 480, height: 720)
    }

    #if os(macOS)
    /// R71: the card as a PNG into the save panel.
    @MainActor
    private func saveImage() {
        let renderer = ImageRenderer(content: ShareCard(content: content, template: template, showsGoalNames: showsGoalNames))
        renderer.scale = 3
        guard let cgImage = renderer.cgImage,
              let data = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:]) else { return }
        exportFile = ExportFile(data: data)
        exporting = true
    }
    #endif

    @MainActor
    private var rendered: Image? {
        let renderer = ImageRenderer(content: ShareCard(content: content, template: template, showsGoalNames: showsGoalNames))
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: 1)
    }
}
