import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

/// The interactive tour: the real Today screen on a throwaway practice week, with the coach card
/// on top. Each step watches the page and ticks itself off once you've done what it describes.
struct TourView: View {
    let steps: [TourStep<ThaliaTourSnapshot>]
    /// The real app's model: its menu commands are pointed at the practice page meanwhile.
    let host: AppModel
    let onFinish: () -> Void

    @State private var sandbox: AppModel?
    @State private var health = HealthService()

    var body: some View {
        Group {
            if let sandbox {
                PracticePage(steps: steps, startAt: host.launch.tourStep, onFinish: onFinish)
                    .environment(sandbox)
                    .environment(health)
                    .modelContainer(sandbox.container)
                    .modifier(AppChrome(app: sandbox, health: health))
            } else {
                ProgressView("Übungswoche wird vorbereitet …")
            }
        }
        .onAppear {
            guard sandbox == nil else { return }
            let model = AppModel(container: Persistence.practiceStore(), mode: .demo, isSandbox: true)
            sandbox = model
            host.tourModel = model
        }
        .onDisappear { host.tourModel = nil }
    }
}

private struct PracticePage: View {
    let steps: [TourStep<ThaliaTourSnapshot>]
    let startAt: String?
    let onFinish: () -> Void

    @Environment(AppModel.self) private var app
    @Query private var marks: [ItemMark]
    @Query private var work: [WorkBlock]
    @Query(filter: #Predicate<MeasureEntry> { $0.deletedAt == nil }) private var entries: [MeasureEntry]
    @Query(filter: #Predicate<DayNote> { $0.deletedAt == nil }) private var notes: [DayNote]

    var body: some View {
        NavigationStack {
            // Inside the stack, so the coach sits below the navigation bar and + stays reachable.
            TodayView()
                .thaliaCoach(steps: steps, snapshot: snapshot, startAt: startAt, onClose: onFinish)
                #if os(iOS)
                .safeAreaInset(edge: .bottom) {
                    // The real app has + in the tab bar's accessory; the practice page brings its own.
                    HStack {
                        Spacer()
                        Button {
                            app.sheet = .create
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.bold))
                                .frame(width: 56, height: 56)
                                .foregroundStyle(.white)
                                .background(Brand.accent, in: .circle)
                                .shadow(radius: 4, y: 2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Erfassen")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
                #endif
        }
    }

    private var snapshot: ThaliaTourSnapshot {
        var snapshot = ThaliaTourSnapshot()
        var counts: [String: Int] = [:]
        for mark in marks.latest(by: \.key, modified: \.modifiedAt).values {
            counts[mark.valueRaw, default: 0] += 1
        }
        snapshot.markSummary = counts.keys.sorted().map { "\($0)=\(counts[$0] ?? 0)" }.joined(separator: " ")
        snapshot.workCount = work.filter { $0.deletedAt == nil }.count
        snapshot.trashedWorkCount = work.filter { $0.deletedAt != nil }.count
        snapshot.entryCount = entries.count
        snapshot.entrySummary = "\(entries.count)|" + Format.plain(entries.compactMap(\.value).reduce(0, +))
        snapshot.noteCount = notes.count
        if case .create = app.sheet { snapshot.isCreateOpen = true }
        if case .closeDay = app.sheet { snapshot.isCloseDayOpen = true }
        return snapshot
    }
}

// MARK: German coach card (same behaviour as BinisoftKit's TourCoach)

private struct ThaliaCoachCard: View {
    let step: TourStep<ThaliaTourSnapshot>
    let index: Int
    let count: Int
    let isMet: Bool
    let primaryTitle: String
    let primaryIsProminent: Bool
    let onBack: (() -> Void)?
    let onNext: () -> Void
    let onClose: () -> Void

    @State private var isFolded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: isMet ? "checkmark.circle.fill" : step.symbol)
                    .font(.title2)
                    .foregroundStyle(isMet ? Color.green : Brand.accent)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isMet ? "Genau so!" : step.title)
                        .font(.headline)
                    Text("Schritt \(index + 1) von \(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Button {
                    withAnimation(.snappy) { isFolded.toggle() }
                } label: {
                    Image(systemName: isFolded ? "chevron.down" : "chevron.up")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isFolded ? "Anleitung zeigen" : "Anleitung ausblenden")
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Tour schließen")
            }
            if !isFolded {
                Text(step.instructions)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    ProgressView(value: Double(index + 1), total: Double(max(count, 1)))
                    if let onBack {
                        Button("Zurück", action: onBack)
                            .buttonStyle(.borderless)
                    }
                    if primaryIsProminent {
                        Button(action: onNext) { Text(primaryTitle).lineLimit(1).fixedSize().frame(minWidth: 64) }
                            .buttonStyle(.glassProminent)
                            .tint(Brand.accent)
                    } else {
                        Button(action: onNext) { Text(primaryTitle).lineLimit(1).fixedSize().frame(minWidth: 52) }
                            .buttonStyle(.glass)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .floatingGlass(cornerRadius: 22)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 4)
        .sensoryFeedback(.success, trigger: isMet) { _, new in new }
        .animation(.snappy, value: index)
    }
}

private struct ThaliaCoachModifier: ViewModifier {
    let steps: [TourStep<ThaliaTourSnapshot>]
    let snapshot: ThaliaTourSnapshot
    let startAt: String?
    let onClose: () -> Void

    @State private var progress: TourProgress<ThaliaTourSnapshot>?
    @State private var latest: ThaliaTourSnapshot?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let progress, let step = progress.step {
                    ThaliaCoachCard(
                        step: step, index: progress.index, count: progress.steps.count, isMet: progress.isMet,
                        primaryTitle: title(progress), primaryIsProminent: progress.primaryIsProminent,
                        onBack: progress.isFirst ? nil : { goBack() }, onNext: { advance() }, onClose: onClose
                    )
                }
            }
            .onAppear {
                if progress == nil { progress = TourProgress(steps: steps, start: snapshot, startAt: startAt) }
                latest = snapshot
            }
            .onChange(of: snapshot) { _, newValue in observe(newValue) }
    }

    /// The kit's English button titles, in German.
    private func title(_ progress: TourProgress<ThaliaTourSnapshot>) -> String {
        if progress.isLast { return "Fertig" }
        guard let step = progress.step, !step.goal.isManual else { return progress.isFirst ? "Los geht's" : "Weiter" }
        return progress.isMet ? "Weiter" : "Überspringen"
    }

    private func observe(_ newValue: ThaliaTourSnapshot) {
        latest = newValue
        guard var current = progress else { return }
        let ticked = current.observe(newValue)
        guard ticked else { return }
        withAnimation(.snappy) { progress = current }
        let index = current.index
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.4))
            if progress?.index == index, progress?.isMet == true { advance() }
        }
    }

    private func advance() {
        guard var current = progress else { return }
        if current.next(at: latest ?? snapshot) {
            withAnimation(.snappy) { progress = current }
        } else {
            onClose()
        }
    }

    private func goBack() {
        guard var current = progress else { return }
        current.back(at: latest ?? snapshot)
        withAnimation(.snappy) { progress = current }
    }
}

extension View {
    func thaliaCoach(steps: [TourStep<ThaliaTourSnapshot>], snapshot: ThaliaTourSnapshot, startAt: String?,
                     onClose: @escaping () -> Void) -> some View {
        modifier(ThaliaCoachModifier(steps: steps, snapshot: snapshot, startAt: startAt, onClose: onClose))
    }
}
