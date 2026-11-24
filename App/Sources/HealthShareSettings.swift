import SwiftUI
import SwiftData
import BinisoftKit
import ThaliaCore

// HEALTHSHARE – TestFlight only (TASKS-v11 §1.4, P9.2). The whole file goes before the first App Store submission
// (§1.4.12 (b)). The App Store clean-up stays: `cleanUpHealthShare` / `removeAllHealthShare` in Shared/HealthShareStore.swift
// and the launch check in AppModel (`startHealthShare`).

// HEALTHSHARE: "Health-Werte mit Mac und Watch teilen" on this device – the switch (iPhone and iPad, only while the gate is
// `.allowed`, §1.4.1), the writer (§1.4.5), the daily clean-up (§1.4.6) and what the views ask about the sharing. One per
// AppModel; the demo and the tour's practice page show it but never write.
@MainActor
@Observable
final class HealthShareController {
    // HEALTHSHARE
    /// The gate as the views show it – read again on `HealthShareGate.changed` (a static value isn't observed).
    private(set) var gate: HealthShareGate.State = HealthShareGate.state
    /// The switch as shown: this device's (UserDefaults `thalia.health.share`, off by default); `-Demo` keeps its own in
    /// memory, on – the CI screenshot `health` shows the TestFlight texts, and nothing is written.
    private(set) var isOn: Bool
    /// The switch went off because another device ended or took over the sharing (the footer says so).
    private(set) var endedElsewhere: Bool
    /// Counts this device's changes of the sharing – the privacy texts read the stored state again.
    private(set) var revision = 0
    /// False in the demo and on the practice page: shown, never written.
    @ObservationIgnored private let writes: Bool
    /// When `read` (the Health suggestions of the 3 newest days) was last read – at most every 30 minutes.
    @ObservationIgnored private var lastRead: Date?
    @ObservationIgnored private var isReading = false
    /// The synced state's `on` as `syncArrived` last saw it (nil before the first sync).
    @ObservationIgnored private var sharedOnSeen: Bool?
    /// Its own reader of Apple Health – `readValues` never touches the screens' suggestions.
    @ObservationIgnored private let health: HealthService

    /// `read` again at most this often (§1.4.5).
    static let readInterval: TimeInterval = 30 * 60
    /// The footer of the switch (§1.4.1, Bini's wording for the first sentence).
    static let footer = "Nur in der TestFlight-Version – Apple erlaubt Gesundheitsdaten in iCloud im App Store nicht. Geteilt werden deine übernommenen Health-Werte der letzten 5 Wochen und die Health-Vorschläge der letzten 3 Tage; Ausschalten löscht sie wieder aus iCloud."
    /// The line after the switch went off because of another device (§1.4.5).
    static let endedElsewhereText = "Teilen wurde auf einem anderen Gerät beendet oder übernommen."
    /// The caption of a shared value on Mac, watch and iPad (§1.4.8).
    static let sharedCaption = "aus Health am iPhone"

    init(isDemo: Bool, isSandbox: Bool) {
        writes = !isDemo && !isSandbox
        // HEALTHSHARE
        isOn = isDemo ? true : HealthShareGate.switchIsOn
        endedElsewhere = isDemo ? false : HealthShareGate.endedElsewhere
        health = HealthService()
    }

    var isAllowed: Bool { gate == .allowed }

    /// The switch shows on a device that reads Apple Health (iPhone, iPad) while the gate is `.allowed` (§1.4.1).
    var showsSwitch: Bool { HealthDevice.readsHealth && isAllowed }

    /// The privacy texts say what is shared (§1.4.10, P9.4): the gate is allowed and the sharing is on – the synced state,
    /// whichever device writes it (in the demo: the switch shown).
    func sharesHealth(store: TrackerStore) -> Bool {
        _ = revision
        guard isAllowed else { return false }
        guard writes else { return isOn }
        return store.healthShareState?.on ?? false
    }

    // HEALTHSHARE
    /// The gate changed (`HealthShareGate.changed`): the views follow, the switch as stored (a clean-up may have turned it off).
    func gateChanged() {
        gate = HealthShareGate.state
        syncSwitch()
        revision += 1
    }

    /// Before switching on: "Teilen läuft schon auf einem anderen Gerät (iPhone, zuletzt heute 08:12). Hier übernehmen?" –
    /// nil when no other device shares (the state is off, missing or this device's). Kind and time from `sync.seen.<by>`.
    func takeOverQuestion(store: TrackerStore, now: Date = Date()) -> String? {
        guard writes, let state = store.healthShareState, state.on, state.by != TrackerStore.installID else { return nil }
        guard let device = store.syncDevices().first(where: { $0.installID == state.by }) else {
            return "Teilen läuft schon auf einem anderen Gerät. Hier übernehmen?"
        }
        let seen: String = HealthShareController.lastSeen(device.seenAt, now: now)
        return "Teilen läuft schon auf einem anderen Gerät (\(device.kind), zuletzt \(seen)). Hier übernehmen?"
    }

    /// "heute 08:12", "gestern 21:14", "12.11. 08:03".
    static func lastSeen(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
        if calendar.isDate(date, inSameDayAs: now) { return "heute \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "gestern \(time)"
        }
        let day = String(format: "%02d.%02d.", calendar.component(.day, from: date), calendar.component(.month, from: date))
        return "\(day) \(time)"
    }

    /// The switch: on deletes other writers' days and writes the state and the window (§1.4.5); off deletes every shared day
    /// and leaves the state off (§1.4.9). The demo only shows it.
    func setOn(_ on: Bool, store: TrackerStore, today: DayKey) {
        isOn = on
        endedElsewhere = false
        revision += 1
        guard writes else { return }
        // HEALTHSHARE
        HealthShareGate.setSwitch(on)
        if on {
            store.startHealthShare(today: today)
            lastRead = nil
            readSoon(store: store, today: today)
        } else {
            store.stopHealthShare()
        }
        revision += 1
    }

    /// Thalia came to the front, or a new day (`AppModel.refreshToday`): the expired days go (once a day, on every device
    /// with the gate allowed, §1.4.6); the writer checks that it still writes the sharing (else its switch goes off),
    /// writes the window's changes and, at most every 30 minutes, the Health suggestions of the 3 newest days.
    func activate(store: TrackerStore, today: DayKey) {
        guard writes, isAllowed else { return }
        store.cleanUpHealthShare(gate: .allowed, today: today)
        // HEALTHSHARE
        guard HealthDevice.readsHealth, HealthShareGate.switchIsOn else {
            syncSwitch()
            return
        }
        if store.healthShareWriterCheck() {
            syncSwitch()
            revision += 1
            return
        }
        if store.writeHealthShareWindow(today: today) > 0 { revision += 1 }
        readSoon(store: store, today: today)
    }

    /// After an iCloud sync (`AppModel.afterSync`): another device's state may have arrived. A writer whose sharing another
    /// device took over or ended switches itself off at once, as on activation (§1.4.5); the screens with the privacy texts
    /// (`sharesHealth`, on the Mac too) draw again when the synced state went on or off (§1.4.10).
    func syncArrived(store: TrackerStore) {
        // HEALTHSHARE
        guard writes, isAllowed else { return }
        if HealthDevice.readsHealth, HealthShareGate.switchIsOn, store.healthShareWriterCheck() {
            syncSwitch()
            revision += 1
        }
        let on: Bool = store.healthShareState?.on ?? false
        guard on != sharedOnSeen else { return }
        sharedOnSeen = on
        revision += 1
    }

    /// A save with an Apple Health value (adopted, removed, ⌘Z or shaking after `adoptHealth`, KR1-12): `counted` of the
    /// window again from the values on this device – only changed days are written.
    func healthValuesSaved(store: TrackerStore, today: DayKey) {
        // HEALTHSHARE
        guard writes, isAllowed, HealthDevice.readsHealth, HealthShareGate.switchIsOn else { return }
        if store.healthShareWriterCheck() {
            syncSwitch()
            revision += 1
            return
        }
        store.writeHealthShareWindow(today: today)
    }

    private func syncSwitch() {
        guard writes else { return }
        // HEALTHSHARE
        isOn = HealthShareGate.switchIsOn
        endedElsewhere = HealthShareGate.endedElsewhere
    }

    /// `read` for today and the 2 days before (each with its week's Health measures), at most every 30 minutes.
    private func readSoon(store: TrackerStore, today: DayKey, now: Date = Date()) {
        if let lastRead, now.timeIntervalSince(lastRead) < HealthShareController.readInterval { return }
        guard !isReading else { return }
        isReading = true
        lastRead = now
        // HEALTHSHARE
        let days: [DayKey] = HealthShare.readWindow(today: today)
        var measures: [WeekKey: [MeasureRecord]] = [:]
        for week in Set(days.map(\.week)) {
            measures[week] = store.measures(week).compactMap(\.record).filter(\.isHealth)
        }
        let reader: HealthService = health
        Task { @MainActor [weak self] in
            let read: [DayKey: [String: Double]] = await reader.readValues(days: days, measures: measures)
            self?.isReading = false
            // HEALTHSHARE
            guard !read.isEmpty, HealthShareGate.isAllowed, HealthShareGate.switchIsOn else { return }
            if store.writeHealthShareWindow(today: today, days: days, read: read) > 0 { self?.revision += 1 }
        }
    }
}

// HEALTHSHARE: Heute on Mac and iPad – a value the iPhone shares: shown, with no field and no − / + (a click never turns it into
// an own entry, KR1-7); "Eigenen Wert eintragen…" opens the measure with an empty field – an own value wins (§1.4.8).
struct SharedHealthInput: View {
    let measure: MeasureDefinition
    let day: DayKey
    let value: Double
    /// "aus Health am iPhone" – or the writing device's kind (`HealthShareWeek.sharedCaption`).
    var caption: String = HealthShareController.sharedCaption
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(Format.measure(value, unit: measure.unit))
                .font(.system(.callout, design: .rounded).weight(.bold))
                .monospacedDigit()
                .accessibilityLabel("\(measure.title): \(Format.measure(value, unit: measure.unit)), \(caption)")
            Button("Eigenen Wert eintragen…") {
                app.sheet = .measure(code: measure.code, day: day)
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
    }
}

#if os(iOS)
// HEALTHSHARE: Einstellungen → Apple Health – a section of its own without a title (the switch says it, §1.4.1), only on a
// device that reads Health and only while the gate is `.allowed`.
struct HealthShareSection: View {
    @Environment(AppModel.self) private var app
    @State private var question: String?

    private var isAsking: Binding<Bool> {
        Binding(get: { question != nil }, set: { if !$0 { question = nil } })
    }

    private var isOn: Binding<Bool> {
        let controller: HealthShareController = app.healthShare
        return Binding(get: { controller.isOn }, set: { switchTo($0) })
    }

    var body: some View {
        let controller: HealthShareController = app.healthShare
        if controller.showsSwitch {
            Section {
                Toggle("Health-Werte mit Mac und Watch teilen", isOn: isOn)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(HealthShareController.footer)
                    if controller.endedElsewhere {
                        Text(HealthShareController.endedElsewhereText)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .confirmationDialog(question ?? "", isPresented: isAsking, titleVisibility: .visible) {
                Button("Übernehmen") { takeOver() }
                Button("Abbrechen", role: .cancel) { question = nil }
            }
        }
    }

    /// On asks first when another device shares (§1.4.1); off deletes the shared days at once.
    private func switchTo(_ on: Bool) {
        let controller: HealthShareController = app.healthShare
        if on, let asked = controller.takeOverQuestion(store: app.store) {
            question = asked
            return
        }
        controller.setOn(on, store: app.store, today: app.today)
    }

    private func takeOver() {
        question = nil
        app.healthShare.setOn(true, store: app.store, today: app.today)
    }
}
#endif
