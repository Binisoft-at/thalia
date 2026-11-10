import SwiftUI
import BinisoftKit
import ThaliaCore

// V12: livelier overviews (animated gradient heads, a small celebration), V13: share a day or a
// week as an image in a few designed templates, V1: the week as a PDF with every category.

// MARK: Animated gradient

/// A slowly moving mesh gradient in Thalia's colours. Still when "Bewegung reduzieren" is on.
struct AuroraBackground: View {
    var palette: [Color] = AuroraBackground.thalia
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let thalia: [Color] = [
        Color(red: 0.05, green: 0.36, blue: 0.42), Color(red: 0.10, green: 0.55, blue: 0.58), Color(red: 0.36, green: 0.30, blue: 0.70),
        Color(red: 0.12, green: 0.62, blue: 0.55), Color(red: 0.20, green: 0.45, blue: 0.75), Color(red: 0.55, green: 0.35, blue: 0.75),
        Color(red: 0.04, green: 0.30, blue: 0.40), Color(red: 0.16, green: 0.50, blue: 0.62), Color(red: 0.30, green: 0.62, blue: 0.70),
    ]

    var body: some View {
        if animated && !reduceMotion {
            TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
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

    @State private var shown = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.22), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: (shown || !animated) ? CGFloat(min(1, max(0, progress))) : 0)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text(caption)
                        .font(.caption2.weight(.semibold))
                        .opacity(0.85)
                }
                .padding(10)
            }
            .frame(width: 96, height: 96)
            .overlay(alignment: .topTrailing) {
                if celebrate {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .symbolEffect(.bounce, value: shown)
                        .offset(x: 8, y: -6)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .opacity(0.85)
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
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
        .padding(18)
        .background {
            AuroraBackground(animated: animated)
                .clipShape(.rect(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            if celebrate { CelebrationView() }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { shown = true }
        }
        .sensoryFeedback(.success, trigger: celebrate && shown)
        .accessibilityElement(children: .combine)
    }
}

/// A short burst of dots for a good day or week. Nothing moves with "Bewegung reduzieren".
struct CelebrationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    CelebrationView.draw(&context, size: size, elapsed: timeline.date.timeIntervalSince(start))
                }
            }
            .allowsHitTesting(false)
            .onAppear { start = Date() }
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
        if !totals.isEmpty { facts.append(("Fokus", totals.shortText)) }
        return ShareContent(title: day.longLabel, subtitle: context.week.label, score: context.isClosed(day) ? overall?.score : nil,
                            fill: overall?.coverage ?? 0, goalScores: goalScores, goalTitles: context.goals.map(\.title),
                            facts: facts, motto: context.plan?.title ?? "")
    }

    @MainActor
    static func week(_ context: WeekContext) -> ShareContent {
        let totals = context.workTotals()
        let closedDays: Int = context.week.days.filter { context.isClosed($0) }.count
        var facts: [(String, String)] = [("Ziele bewertet", "\(context.score.goalsScored)/\(context.score.goalsTotal)"),
                                         ("Tage abgeschlossen", "\(closedDays)/7")]
        if !totals.isEmpty { facts.append(("Fokus", totals.shortText)) }
        return ShareContent(title: "\(context.week.label) · \(context.week.rangeLabel)", subtitle: "Meine Woche",
                            score: context.score.overall, fill: Double(context.score.goalsScored) / Double(max(1, context.score.goalsTotal)),
                            goalScores: context.goals.map { context.score.goalWeek[$0.key]?.score },
                            goalTitles: context.goals.map(\.title), facts: facts, motto: context.plan?.title ?? "")
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
                        Text(content.score.map { Format.score($0) } ?? "\(percent(content.fill)) %")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text(content.score == nil ? "erfasst" : "von 10")
                            .font(.system(size: 13, weight: .semibold))
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
            Text("10 Jahresziele")
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
                        .primaryActionStyle()
                    }
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
                ToolbarItem(placement: .cancellationAction) { Button("Fertig") { dismiss() } }
            }
        }
        .sheetFrame(minWidth: 480, minHeight: 720)
    }

    @MainActor
    private var rendered: Image? {
        let renderer = ImageRenderer(content: ShareCard(content: content, template: template, showsGoalNames: showsGoalNames))
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: 1)
    }
}
