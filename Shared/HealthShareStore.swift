import Foundation
import SwiftData
import StoreKit
import BinisoftKit
import ThaliaCore

// HEALTHSHARE – TestFlight only (TASKS-v11 §1.4, package P9). The whole file goes before the first App Store
// submission (§1.4.12 (b)) except the App Store clean-up – `HealthShareGate.verdict(for:)` with `.denied`, the launch
// check that calls `cleanUpHealthShare(gate:today:)` and `removeAllHealthShare()` (one prefix query, every `hshare.`
// record deleted, the state off), which stay for good.
//
// HEALTHSHARE
// An iPhone (or iPad) that reads Apple Health and has "Health-Werte mit Mac und Watch teilen" on writes `hshare.state`
// and one record per day (`hshare.<JJJJ-MM-TT>`, Core `HealthShare`) as JSON in `AppSetting` – no schema change, never
// in `SettingKeys.all`, never in a backup, the exchange, the catalog or a prompt. Mac, watch and iPad read them as
// Health values (`HealthShareWeek` in `WeekContext`, `lastValue`, `measureSeries`), so they score a week like the
// iPhone. Writing and reading only while the gate is `.allowed`; maintenance, without Undo.

// MARK: The gate

// HEALTHSHARE: may this build share Health values (§1.4.2)? `.allowed`: a debug build, or a verified app transaction from
// the sandbox (TestFlight) or Xcode; `.denied`: verified from the App Store; `.unknown`: not checked yet, not verified,
// an error. The last verified state is kept per device (`cacheKey`); a launch starts with it and checks again in the
// background (`resolve(timeout:)`), posting `changed` when it differs – App and watch redraw (`syncTick`), a static value
// isn't observed. Writing and reading only with `.allowed`; the App Store clean-up only with a freshly confirmed `.denied`
// (a TestFlight iPhone that starts offline deletes nothing).
// HEALTHSHARE
enum HealthShareGate {
    enum State: String, Sendable {
        case allowed, denied, unknown
    }

    /// UserDefaults (per device): the last verified state.
    static let cacheKey = "thalia.health.shareGate"
    /// Posted on the main thread when the state changed.
    static let changed = Notification.Name("thalia.health.shareGateChanged")
    /// UserDefaults (per device): the switch "Health-Werte mit Mac und Watch teilen" of this iPhone or iPad (off by default).
    static let switchKey = "thalia.health.share"
    /// UserDefaults (per device): the switch went off because another device took over or ended the sharing.
    static let endedElsewhereKey = "thalia.health.shareEndedElsewhere"
    /// UserDefaults (per device): the day the expired day records were last deleted (at most once a day, §1.4.6).
    static let cleanedDayKey = "thalia.health.shareCleaned"
    // HEALTHSHARE
    /// Debug builds: the launch option `-HealthShareGate allowed|denied|unknown` (UserDefaults' argument domain) – to try
    /// the clean-up and an offline start.
    static let launchOptionKey = "HealthShareGate"
    /// The install id `TrackerStore.installID` keeps (read here without creating one – `WeekContext` isn't on the main actor).
    static let installIDKey = "sync.installID"

    /// The state now: in a debug build the launch option, else `.allowed`; otherwise the last verified state, else `.unknown`.
    static var state: State {
        if let debug = debugState { return debug }
        return UserDefaults.standard.string(forKey: cacheKey).flatMap { State(rawValue: $0) } ?? .unknown
    }

    static var isAllowed: Bool { state == .allowed }

    /// This device's install id; nil while none was created (then it has never written anything).
    static var thisDevice: String? { UserDefaults.standard.string(forKey: installIDKey) }

    /// This iPhone's or iPad's switch.
    static var switchIsOn: Bool { UserDefaults.standard.bool(forKey: switchKey) }

    /// The switch went off because the sharing was ended or taken over on another device.
    static var endedElsewhere: Bool { UserDefaults.standard.bool(forKey: endedElsewhereKey) }

    /// Sets the switch (and whether it went off because of another device).
    static func setSwitch(_ on: Bool, endedElsewhere: Bool = false) {
        UserDefaults.standard.set(on, forKey: switchKey)
        UserDefaults.standard.set(!on && endedElsewhere, forKey: endedElsewhereKey)
    }

    private static var debugState: State? {
        #if DEBUG
        return UserDefaults.standard.string(forKey: launchOptionKey).flatMap { State(rawValue: $0) } ?? .allowed
        #else
        return nil
        #endif
    }

    /// The state of a verified app transaction's environment: the App Store denies (this stays with the clean-up),
    /// the sandbox (TestFlight) and Xcode allow.
    static func verdict(for environment: AppStore.Environment) -> State {
        if environment == .production { return .denied }
        if environment == .sandbox || environment == .xcode { return .allowed }
        return .unknown
    }

    /// The check running now (one at a time) and its answer once verified this launch.
    @MainActor private static var running: Task<State, Never>?
    @MainActor private static var confirmed: State?

    /// This launch verified an App Store build (`.denied`, never only the cache) – the App Store clean-up then also runs
    /// after each iCloud sync, so records that arrive later go too and a TestFlight device's sharing ends without waiting
    /// for the next launch (§1.4.3; stays with the clean-up).
    @MainActor static var isConfirmedDenied: Bool { confirmed == .denied }

    /// Checks the app transaction – at most `timeout`; a slower check goes on and still caches its answer. Returns the
    /// state confirmed now: `.unknown` when not verified, failed or not answered in time.
    /// `Swift.Duration`: on the Mac MacTypes' C typedef `Duration` (SInt32) can be in scope too.
    @MainActor
    static func resolve(timeout: Swift.Duration = .seconds(30)) async -> State {
        if let confirmed { return confirmed }
        let check: Task<State, Never>
        if let running {
            check = running
        } else {
            check = Task { @MainActor in
                let fresh: State = await verify()
                finish(fresh)
                return fresh
            }
            running = check
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<State, Never>) in
            let answer = GateAnswer(continuation)
            Task { answer.give(await check.value) }
            Task {
                try? await Task.sleep(for: timeout)
                answer.give(.unknown)
            }
        }
    }

    private static func verify() async -> State {
        if let debug = debugState { return debug }
        do {
            let result: VerificationResult<AppTransaction> = try await AppTransaction.shared
            switch result {
            case .verified(let transaction):
                return verdict(for: transaction.environment)
            case .unverified:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }

    /// Keeps a verified answer (UserDefaults) and posts `changed` when the state differs; `.unknown` keeps the cache and
    /// lets the next `resolve` ask again.
    @MainActor
    private static func finish(_ fresh: State) {
        running = nil
        guard fresh != .unknown else {
            AppLog.info("Health sharing gate: not verified", category: "health")
            return
        }
        confirmed = fresh
        let before: State = state
        if debugState == nil { UserDefaults.standard.set(fresh.rawValue, forKey: cacheKey) }
        AppLog.info("Health sharing gate: \(fresh.rawValue)", category: "health")
        if state != before { NotificationCenter.default.post(name: changed, object: nil) }
    }
}

// HEALTHSHARE: the first of the check and the timeout answers `resolve` (exactly once).
private final class GateAnswer: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<HealthShareGate.State, Never>?

    // HEALTHSHARE
    init(_ continuation: CheckedContinuation<HealthShareGate.State, Never>) {
        self.continuation = continuation
    }

    // HEALTHSHARE
    func give(_ state: HealthShareGate.State) {
        lock.lock()
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume(returning: state)
    }
}

// MARK: Reading – Mac, watch, iPad (§1.4.7)

// HEALTHSHARE: what this device reads of the shared Health values for one week – empty unless the gate is allowed, the
// state is on and another device writes it (this device isn't the writer). Only the writer's day records inside its
// window `from…through` count, the newest copy per day.
struct HealthShareWeek {
    static let none = HealthShareWeek(state: nil, records: [])

    /// The state while this device reads it; nil otherwise.
    let state: HealthShareState?
    /// The writer's records of the week by day.
    let days: [DayKey: HealthShareDay]

    init(state: HealthShareState?, records: [HealthShareDay]) {
        guard let state, state.on else {
            self.state = nil
            self.days = [:]
            return
        }
        var newest: [DayKey: HealthShareDay] = [:]
        for record in records where record.by == state.by && state.covers(record.day) {
            if let known = newest[record.day], known.modifiedAt >= record.modifiedAt { continue }
            newest[record.day] = record
        }
        self.state = state
        self.days = newest
    }

    // HEALTHSHARE
    /// From the week's settings (`hshare.state`, `HealthShare.keys(week:)`), as far back as this device's window (`today`).
    init(settings: [StoredSetting], week: WeekKey, today: DayKey = .today()) {
        guard HealthShareGate.isAllowed else {
            self = .none
            return
        }
        // HEALTHSHARE
        let state: HealthShareState? = HealthShareState.newest(settings.filter { $0.key == HealthShare.stateKey }.map(\.value))
        guard let state, state.on, state.by != HealthShareGate.thisDevice else {
            self = .none
            return
        }
        // HEALTHSHARE
        let keys = Set(HealthShare.keys(week: week))
        let records: [HealthShareDay] = settings.filter { keys.contains($0.key) }.compactMap { HealthShareDay(value: $0.value, key: $0.key) }
        self.init(state: state.readable(today: today), records: records)
    }

    /// The writer's window holds `day` – its values (or that there are none) are the iPhone's.
    func covers(_ day: DayKey) -> Bool {
        state?.covers(day) ?? false
    }

    // HEALTHSHARE: "aus Health am iPhone" – or "am iPad" when an iPad writes (§1.4.8); `writerSymbol` the device's symbol.
    var sharedCaption: String { HealthShare.sharedCaption(state) }
    var writerSymbol: String { state?.writerKind == "iPad" ? "ipad" : "iphone" }

    // HEALTHSHARE: "Health am iPhone: 72,6 kg – dort übernehmen" (the writer's kind, §1.4.8).
    func suggestionText(_ value: Double, unit: String) -> String {
        HealthShare.suggestionText(Format.measure(value, unit: unit), state: state)
    }

    /// The value the iPhone took over for `code` on `day`.
    func counted(code: String, day: DayKey) -> Double? {
        days[day]?.counted[code]
    }

    /// What the iPhone read from Health for `code` on `day` (a suggestion there).
    func read(code: String, day: DayKey) -> Double? {
        days[day]?.read[code]
    }

    /// The taken-over values of `codes` as Health entries, except the code-and-day keys in `except` (own Health values).
    func entries(codes: Set<String>, except: Set<String>) -> [EntryRecord] {
        guard state != nil else { return [] }
        // HEALTHSHARE
        return HealthShare.entries(Array(days.values), state: state).filter { codes.contains($0.code) && !except.contains($0.key) }
    }

    /// Changes when a shared day of the week changes: their count and the newest `modifiedAt` (P7.11's `loadKey`).
    var fingerprint: String {
        let newest: Double = days.values.map(\.modifiedAt).max()?.timeIntervalSince1970 ?? 0
        return "\(days.count):\(newest)"
    }
}

// MARK: The store

// HEALTHSHARE: reading, writing, ending and cleaning up the sharing (§1.4.3–§1.4.9). Every write is maintenance without Undo
// (`withoutUndo`, saved as `.maintenance`) and only a change is written.
extension TrackerStore {
    /// The sharing's state – the newest copy; nil without one.
    var healthShareState: HealthShareState? {
        // HEALTHSHARE
        HealthShareState.newest(settings(keys: [HealthShare.stateKey]).map(\.value))
    }

    /// The state when this device reads the shared values (gate allowed, on, written by another device); nil otherwise.
    var readHealthShareState: HealthShareState? {
        // HEALTHSHARE
        guard HealthShareGate.isAllowed, let state = healthShareState, state.on, state.by != HealthShareGate.thisDevice else { return nil }
        return state
    }

    /// The week's Health values come from the sharing on this device (Mac, watch, iPad): every day of the week up to today
    /// lies in the writer's window – this device then scores the week like the iPhone (`canScore`, §1.3.1 (b)).
    // HEALTHSHARE
    func healthShareCovers(_ week: WeekKey, today: DayKey = .today()) -> Bool {
        // Not further back than this device's own window – older days may be deleted already (§1.4.6).
        guard let state = readHealthShareState?.readable(today: today) else { return false }
        let days: [DayKey] = week.days.filter { $0 <= today }
        return !days.isEmpty && days.allSatisfy { state.covers($0) }
    }

    /// The shared values of `code` on the days in `dayKeys` (inside the writer's window, not older than this device's own,
    /// by `today`), except the code-and-day keys in `except` (own Health values) – `lastValue` and `measureSeries` count
    /// them like `HealthValue`s. Empty on the writer.
    func sharedHealthEntries(code: String, dayKeys: [String], except: Set<String> = [], today: DayKey = .today()) -> [EntryRecord] {
        guard let state = readHealthShareState?.readable(today: today) else { return [] }
        let days: [DayKey] = dayKeys.compactMap { DayKey($0) }.filter { state.covers($0) }
        guard !days.isEmpty else { return [] }
        // HEALTHSHARE
        let records: [HealthShareDay] = settings(keys: days.map { HealthShare.key(day: $0) })
            .compactMap { HealthShareDay(value: $0.value, key: $0.key) }
        return HealthShareWeek(state: state, records: records).entries(codes: [code], except: except)
    }

    /// This device writes the sharing: the gate is allowed, its switch is on and it is the real store (never `-Demo`, the
    /// practice page or another in-memory store).
    var writesHealthShare: Bool {
        // HEALTHSHARE
        HealthShareGate.isAllowed && HealthShareGate.switchIsOn && !isInMemory
    }

    /// Writes one day – only when its values changed (`hasSameValues`); a day without values loses its record. Without
    /// Undo, saved as maintenance. Returns whether it wrote.
    @discardableResult
    func writeHealthShare(day: DayKey, counted: [String: Double], read: [String: Double], now: Date = Date()) -> Bool {
        guard writesHealthShare else { return false }
        let me: String = TrackerStore.installID
        return withoutUndo { () -> Bool in
            var change = RecordChange()
            let stored: HealthShareDay? = storedHealthShareDays([day])[day]
            writeHealthShareDay(HealthShareDay(day: day, by: me, counted: counted, read: read, modifiedAt: now), stored: stored,
                                now: now, change: &change)
            guard !change.isEmpty else { return false }
            commit(change, origin: .maintenance)
            return true
        }
    }

    /// `counted` of `days` (nil: the whole window, today and the 34 days before) from this device's own Health values
    /// (`HealthValue`), only codes of the day's week's measures with a `health:` source; `read` for the 3 newest days from
    /// `read` (as `HealthService.readValues` gave it), else as stored; older days lose theirs. The state moves with today
    /// (`from…through`) and is written again when it is missing or this device's but off (self-healing, §1.4.5). Nothing
    /// when another device writes the sharing (`healthShareWriterCheck`). Without Undo. Returns how many records it wrote.
    @discardableResult
    func writeHealthShareWindow(today: DayKey, days: [DayKey]? = nil, read: [DayKey: [String: Double]] = [:], now: Date = Date()) -> Int {
        guard writesHealthShare else { return 0 }
        let me: String = TrackerStore.installID
        let state: HealthShareState? = healthShareState
        if let state, state.by != me { return 0 }
        return withoutUndo { () -> Int in
            var change = RecordChange()
            writeHealthShareDays(today: today, days: days, read: read, by: me, now: now, change: &change)
            // The device's kind goes along ("aus Health am iPad" on the others, §1.4.8).
            let wanted = HealthShareState.sharing(by: me, today: today, now: now, device: SyncDeviceKind.current)
            if state == nil || state?.on == false || state?.from != wanted.from || state?.through != wanted.through
                || state?.device != wanted.device {
                // HEALTHSHARE
                writeSetting(HealthShare.stateKey, wanted.value, now: now, change: &change)
            }
            guard !change.isEmpty else { return 0 }
            commit(change, origin: .maintenance)
            AppLog.info("Health sharing: \(change.before.count) record(s) written", category: "health")
            return change.before.count
        }
    }

    /// Switching on (§1.4.5): first the day records of every other writer go, then the state (on, this device, today's
    /// window) and the window's values. Without Undo. Returns how many records it wrote or deleted.
    @discardableResult
    func startHealthShare(today: DayKey, read: [DayKey: [String: Double]] = [:], now: Date = Date()) -> Int {
        // HEALTHSHARE
        guard HealthShareGate.isAllowed, !isInMemory else { return 0 }
        let me: String = TrackerStore.installID
        return withoutUndo { () -> Int in
            var change = RecordChange()
            // HEALTHSHARE
            for setting in settings(prefix: HealthShare.prefix) where setting.key != HealthShare.stateKey {
                guard HealthShareDay(value: setting.value, key: setting.key)?.by != me else { continue }
                writeSetting(setting.key, nil, now: now, change: &change)
            }
            // HEALTHSHARE
            let state = HealthShareState.sharing(by: me, today: today, now: now, device: SyncDeviceKind.current)
            // HEALTHSHARE
            writeSetting(HealthShare.stateKey, state.value, now: now, change: &change)
            writeHealthShareDays(today: today, days: nil, read: read, by: me, now: now, change: &change)
            guard !change.isEmpty else { return 0 }
            commit(change, origin: .maintenance)
            AppLog.info("Health sharing on: \(change.before.count) record(s) written", category: "health")
            return change.before.count
        }
    }

    /// Switching off (§1.4.9): every day record goes (the prefix query, not only the window), the state becomes a tombstone
    /// with this device (`on` false) – readers skip the day records while it is off or missing. Without Undo. Returns how
    /// many day records it deleted.
    @discardableResult
    func stopHealthShare(now: Date = Date()) -> Int {
        guard !isInMemory else { return 0 }
        let me: String = TrackerStore.installID
        return withoutUndo { () -> Int in
            var change = RecordChange()
            var removed = 0
            // HEALTHSHARE
            for key in Set(settings(prefix: HealthShare.prefix).map(\.key)).sorted() where key != HealthShare.stateKey {
                writeSetting(key, nil, now: now, change: &change)
                removed += 1
            }
            // HEALTHSHARE
            writeSetting(HealthShare.stateKey, HealthShareState.stopped(by: me, now: now).value, now: now, change: &change)
            guard !change.isEmpty else { return 0 }
            commit(change, origin: .maintenance)
            AppLog.info("Health sharing off: \(removed) shared day(s) deleted", category: "health")
            return removed
        }
    }

    /// Another device took the sharing over or ended it (the state's `by` isn't this device, §1.4.5): this device's switch
    /// goes off and it writes nothing ("Teilen wurde auf einem anderen Gerät beendet oder übernommen."). Returns whether
    /// it switched off.
    @discardableResult
    func healthShareWriterCheck() -> Bool {
        // HEALTHSHARE
        guard HealthShareGate.switchIsOn, let state = healthShareState, state.by != TrackerStore.installID else { return false }
        HealthShareGate.setSwitch(false, endedElsewhere: true)
        AppLog.info("Health sharing ended or taken over on another device – switched off here", category: "health")
        return true
    }

    // HEALTHSHARE
    /// The clean-up at launch (§1.4.3, §1.4.6): `.denied` (freshly confirmed – an App Store build) deletes every `hshare.`
    /// record, whoever wrote it, and switches this device off (`removeAllHealthShare`, stays after the TestFlight sharing
    /// goes); `.allowed` deletes day records older than the window, at most once a day; `.unknown` nothing. Returns how
    /// many records it deleted.
    @discardableResult
    // HEALTHSHARE
    func cleanUpHealthShare(gate: HealthShareGate.State, today: DayKey, now: Date = Date()) -> Int {
        guard !isInMemory else { return 0 }
        switch gate {
        case .denied:
            // HEALTHSHARE
            HealthShareGate.setSwitch(false)
            return removeAllHealthShare(now: now)
        case .allowed:
            let defaults = UserDefaults.standard
            // HEALTHSHARE
            guard defaults.string(forKey: HealthShareGate.cleanedDayKey) != today.string else { return 0 }
            defaults.set(today.string, forKey: HealthShareGate.cleanedDayKey)
            let expired: [String] = HealthShare.expired(keys: settings(prefix: HealthShare.prefix).map(\.key), today: today)
            guard !expired.isEmpty else { return 0 }
            return withoutUndo { () -> Int in
                var change = RecordChange()
                for key in Set(expired).sorted() { writeSetting(key, nil, now: now, change: &change) }
                guard !change.isEmpty else { return 0 }
                commit(change, origin: .maintenance)
                AppLog.info("Health sharing: \(expired.count) expired day(s) deleted", category: "health")
                return expired.count
            }
        case .unknown:
            return 0
        }
    }

    // HEALTHSHARE
    /// The App Store clean-up (stays when the sharing is removed, §1.4.12 (b)): one prefix query; every `hshare.` record
    /// goes, and the state is written off with this device – only when there was something (an App Store install that never
    /// shared writes nothing). Without Undo. Returns how many records it deleted.
    @discardableResult
    func removeAllHealthShare(now: Date = Date()) -> Int {
        // HEALTHSHARE
        let found: [AppSetting] = settings(prefix: HealthShare.prefix)
        let wasOn: Bool = HealthShareState.newest(found.filter { $0.key == HealthShare.stateKey }.map(\.value))?.on ?? false
        let days: [String] = Set(found.map(\.key)).filter { $0 != HealthShare.stateKey }.sorted()
        guard wasOn || !days.isEmpty else { return 0 }
        let me: String = TrackerStore.installID
        return withoutUndo { () -> Int in
            var change = RecordChange()
            for key in days { writeSetting(key, nil, now: now, change: &change) }
            // HEALTHSHARE
            writeSetting(HealthShare.stateKey, HealthShareState.stopped(by: me, now: now).value, now: now, change: &change)
            guard !change.isEmpty else { return 0 }
            commit(change, origin: .maintenance)
            AppLog.info("Health sharing removed (App Store build): \(days.count) day(s) deleted", category: "health")
            return days.count
        }
    }

    // MARK: Helpers

    /// The stored day records of `days` (the newest copy per day).
    private func storedHealthShareDays(_ days: [DayKey]) -> [DayKey: HealthShareDay] {
        var result: [DayKey: HealthShareDay] = [:]
        // HEALTHSHARE
        for setting in settings(keys: days.map { HealthShare.key(day: $0) }) {
            guard let record = HealthShareDay(value: setting.value, key: setting.key) else { continue }
            if let known = result[record.day], known.modifiedAt >= record.modifiedAt { continue }
            result[record.day] = record
        }
        return result
    }

    /// The codes of the week's measures with a `health:` source.
    private func healthCodes(_ week: WeekKey) -> Set<String> {
        Set(measures(week).compactMap(\.record).filter(\.isHealth).map(\.code))
    }

    /// Writes `record` without saving – only when it differs from `stored`; without values it deletes the day's record.
    private func writeHealthShareDay(_ record: HealthShareDay, stored: HealthShareDay?, now: Date, change: inout RecordChange) {
        if record.counted.isEmpty && record.read.isEmpty {
            if stored != nil { writeSetting(record.settingKey, nil, now: now, change: &change) }
            return
        }
        guard !record.hasSameValues(as: stored) else { return }
        writeSetting(record.settingKey, record.value, now: now, change: &change)
    }

    /// The window's day records (or those of `days` inside it) from this device's Health values, without saving.
    private func writeHealthShareDays(today: DayKey, days: [DayKey]?, read: [DayKey: [String: Double]], by me: String, now: Date,
                                      change: inout RecordChange) {
        // HEALTHSHARE
        let window: [DayKey] = HealthShare.windowDays(today: today)
        let inWindow = Set(window)
        let targets: [DayKey] = (days ?? window).filter { inWindow.contains($0) }
        guard !targets.isEmpty else { return }
        let keys: [String] = targets.map(\.string)
        var values: [DayKey: [String: (value: Double, at: Date)]] = [:]
        for value in fetch(FetchDescriptor<HealthValue>(predicate: #Predicate<HealthValue> { keys.contains($0.dayKey) })) {
            guard let day = DayKey(value.dayKey), value.value.isFinite else { continue }
            if let known = values[day]?[value.code], known.at >= value.recordedAt { continue }
            values[day, default: [:]][value.code] = (value.value, value.recordedAt)
        }
        let stored: [DayKey: HealthShareDay] = storedHealthShareDays(targets)
        // HEALTHSHARE
        let readDays = Set(HealthShare.readWindow(today: today))
        var codesOfWeek: [WeekKey: Set<String>] = [:]
        for day in targets {
            let codes: Set<String> = codesOfWeek[day.week] ?? healthCodes(day.week)
            codesOfWeek[day.week] = codes
            var counted: [String: Double] = [:]
            for (code, entry) in values[day] ?? [:] where codes.contains(code) { counted[code] = entry.value }
            var shownRead: [String: Double] = [:]
            if readDays.contains(day) {
                shownRead = (read[day] ?? stored[day]?.read ?? [:]).filter { codes.contains($0.key) }
            }
            let record = HealthShareDay(day: day, by: me, counted: counted, read: shownRead, modifiedAt: now)
            writeHealthShareDay(record, stored: stored[day], now: now, change: &change)
        }
    }
}
