import Foundation
import SwiftUI
import UserNotifications
import BinisoftKit
import ThaliaCore
#if os(iOS)
import HealthKit
#endif

// MARK: Reminders

/// Local notifications from `ReminderSettings` (Core): morning start, the evening review (one per
/// day for the next 7 days, closed days left out) and the weekly review. Tapping one opens the
/// right screen; "In 30 Min." on the evening one brings it back later (R80).
enum ReminderScheduler {
    /// The stored settings; the Mac starts with every reminder off (the iPhone already reminds).
    static func load() -> ReminderSettings {
        guard let data = UserDefaults.standard.data(forKey: ReminderSettings.storageKey),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else { return defaults }
        return settings
    }

    static var defaults: ReminderSettings {
        #if os(macOS)
        return .macDefault
        #else
        return ReminderSettings()
        #endif
    }

    static func save(_ settings: ReminderSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: ReminderSettings.storageKey)
        }
    }

    /// Suffix of a snoozed evening reminder ("thalia.evening.2026-11-16.snooze").
    static let snoozeSuffix = ".snooze"

    /// The "In 30 Min." action on the evening reminder.
    static func registerCategories() {
        let snooze = UNNotificationAction(identifier: ReminderSettings.snoozeActionID, title: "In 30 Min.", options: [])
        let evening = UNNotificationCategory(identifier: ReminderSettings.eveningCategoryID, actions: [snooze],
                                             intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([evening])
    }

    /// Replaces the planned reminders. Asks for permission only with `authorize` (after the tour,
    /// in Settings); otherwise plans only when notifications are already allowed. Returns a short
    /// status line for Settings.
    @MainActor
    static func apply(_ settings: ReminderSettings, authorize: Bool,
                      isClosed: @escaping (DayKey) -> Bool = { _ in false }) async -> String {
        let center = UNUserNotificationCenter.current()
        let requests = settings.requests()
        let evenings = settings.eveningRequests(from: DayKey.today(), isClosed: isClosed)
        let old = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("thalia.") && !$0.hasSuffix(snoozeSuffix) }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard !requests.isEmpty || !evenings.isEmpty else { return "Keine Erinnerungen geplant." }
        let status = await center.notificationSettings().authorizationStatus
        if status != .authorized {
            guard authorize else { return "Mitteilungen sind für Thalia noch nicht erlaubt." }
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                guard granted else { return "Mitteilungen sind für Thalia ausgeschaltet (Systemeinstellungen → Mitteilungen)." }
            } catch {
                AppLog.warning("Notification permission failed: \(error.localizedDescription)", category: "reminders")
                return "Mitteilungen konnten nicht erlaubt werden."
            }
        }
        registerCategories()
        let now = Date()
        var planned = 0
        for evening in evenings {
            let fireDate = evening.day.date(minutes: Double(evening.hour * 60 + evening.minute))
            guard fireDate > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = evening.title
            content.body = evening.body
            content.sound = .default
            content.categoryIdentifier = ReminderSettings.eveningCategoryID
            content.userInfo = ["destination": evening.destination]
            var components = Calendar.current.dateComponents([.year, .month, .day], from: evening.day.startDate())
            components.hour = evening.hour
            components.minute = evening.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: evening.id, content: content, trigger: trigger))
            planned += 1
        }
        for request in requests {
            let content = UNMutableNotificationContent()
            content.title = request.title
            content.body = request.body
            content.sound = .default
            content.userInfo = ["destination": request.destination]
            var components = DateComponents()
            components.hour = request.hour
            components.minute = request.minute
            components.weekday = request.gregorianWeekday
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
            planned += 1
        }
        AppLog.info("Reminders scheduled: \(planned)", category: "reminders")
        return "\(Format.count(planned, "Erinnerung", "Erinnerungen")) geplant."
    }

    /// The day is closed: its evening reminder (pending, shown or snoozed) goes away (R80).
    static func dayClosed(_ day: DayKey) {
        let id = ReminderSettings.eveningID(day)
        let ids = [id, id + snoozeSuffix]
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    /// The day is open again: plan the evenings anew (no permission prompt).
    @MainActor
    static func dayReopened(_ day: DayKey, isClosed: @escaping (DayKey) -> Bool) async {
        _ = await apply(load(), authorize: false, isClosed: isClosed)
    }
}

/// Opens the screen a notification or a Shortcut points to.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    /// Set by `ThaliaApp`; receives "today", "close-day:2026-11-16", "close-week", "week" …
    var route: (@MainActor (String) -> Void)?

    // The completion-handler variants on purpose: with the `async` ones the system's completion
    // ran off the main thread, and tapping a reminder crashed the iPhone app (1.5.0). Everything
    // here hands over to the main queue and calls the completion handler there.

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let request = response.notification.request
        let destination = request.content.userInfo["destination"] as? String ?? "today"
        if response.actionIdentifier == ReminderSettings.snoozeActionID {
            // "In 30 Min.": the same reminder once more, half an hour later (R80).
            let content = UNMutableNotificationContent()
            content.title = request.content.title
            content.body = request.content.body
            content.sound = .default
            content.categoryIdentifier = ReminderSettings.eveningCategoryID
            content.userInfo = ["destination": destination]
            let base = request.identifier.hasSuffix(ReminderScheduler.snoozeSuffix)
                ? String(request.identifier.dropLast(ReminderScheduler.snoozeSuffix.count)) : request.identifier
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(ReminderSettings.snoozeMinutes * 60), repeats: false)
            center.add(UNNotificationRequest(identifier: base + ReminderScheduler.snoozeSuffix, content: content, trigger: trigger)) { _ in
                DispatchQueue.main.async {
                    AppLog.info("Evening reminder snoozed", category: "reminders")
                    completionHandler()
                }
            }
            return
        }
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else {
            DispatchQueue.main.async(execute: completionHandler)
            return
        }
        let route = self.route
        DispatchQueue.main.async {
            MainActor.assumeIsolated { route?(destination) }
            completionHandler()
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        DispatchQueue.main.async { completionHandler([.banner, .sound]) }
    }
}

// MARK: Apple Health

/// Apple Health values as *suggestions* for measurements linked with `health:<kind>`. Read-only;
/// nothing is stored unless the person adopts a value (then device-only, guideline 5.1.3(ii)).
@MainActor
@Observable
final class HealthService {
    static let enabledKey = "thalia.health.enabled"

    var enabledStorage: Bool = UserDefaults.standard.bool(forKey: HealthService.enabledKey)
    var isEnabled: Bool {
        get { enabledStorage }
        set {
            enabledStorage = newValue
            UserDefaults.standard.set(newValue, forKey: HealthService.enabledKey)
        }
    }
    var message: String?
    private(set) var values: [String: Double] = [:]

    func suggestion(code: String, day: DayKey) -> Double? {
        values["\(code)|\(day.string)"]
    }

    #if os(iOS)
    private static let healthStore = HKHealthStore()
    private var store: HKHealthStore { Self.healthStore }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKCategoryType(.sleepAnalysis), HKCategoryType(.mindfulSession),
        ]
        for identifier: HKQuantityTypeIdentifier in [.bodyMass, .dietaryProtein, .dietaryEnergyConsumed, .dietaryWater, .appleExerciseTime, .stepCount] {
            types.insert(HKQuantityType(identifier))
        }
        return types
    }

    func requestAccess() async {
        guard isAvailable else {
            message = "Apple Health ist auf diesem Gerät nicht verfügbar."
            return
        }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            message = "Freigabe angefragt. Welche Daten Thalia lesen darf, steuerst du in Health → Teilen → Apps → Thalia."
            AppLog.info("Health access requested", category: "health")
        } catch {
            message = "Health-Zugriff fehlgeschlagen: \(error.localizedDescription)"
            AppLog.warning("Health access failed", category: "health")
        }
    }

    /// Reads the suggestions for one day (only for measurements that ask for them).
    func load(day: DayKey, measures: [MeasureRecord]) async {
        guard isEnabled, isAvailable else { return }
        for measure in measures {
            guard case .health(let kind) = measure.source else { continue }
            if let value = try? await read(kind, day: day) {
                values["\(measure.code)|\(day.string)"] = value
            }
        }
    }

    private func read(_ kind: HealthKind, day: DayKey) async throws -> Double? {
        let start = day.startDate()
        let end = day.adding(days: 1).startDate()
        switch kind {
        case .bodyMass:
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
            let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: HKQuantityType(.bodyMass), predicate: predicate)],
                                                     sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
            return try await descriptor.result(for: store).first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
        case .protein:
            return try await sum(.dietaryProtein, unit: .gram(), start: start, end: end)
        case .energy:
            return try await sum(.dietaryEnergyConsumed, unit: .kilocalorie(), start: start, end: end)
        case .water:
            return try await sum(.dietaryWater, unit: .liter(), start: start, end: end)
        case .exercise:
            return try await sum(.appleExerciseTime, unit: .minute(), start: start, end: end)
        case .steps:
            return try await sum(.stepCount, unit: .count(), start: start, end: end)
        case .mindful:
            let samples = try await categorySamples(.mindfulSession, start: start, end: end)
            let minutes = samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60 }
            return minutes > 0 ? minutes.rounded() : nil
        case .sleep, .bedtime:
            // The night that ends on this day: from 18:00 the evening before until noon.
            let nightStart = start.addingTimeInterval(-6 * 3600)
            let nightEnd = start.addingTimeInterval(12 * 3600)
            let samples = try await categorySamples(.sleepAnalysis, start: nightStart, end: nightEnd)
            let asleep = samples.filter { HKCategoryValueSleepAnalysis.allAsleepValues.contains(HKCategoryValueSleepAnalysis(rawValue: $0.value) ?? .awake) }
            guard !asleep.isEmpty else { return nil }
            if kind == .sleep {
                let hours = asleep.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } / 3600
                return (hours * 10).rounded() / 10
            }
            guard let first = asleep.map(\.startDate).min() else { return nil }
            let parts = Calendar.current.dateComponents([.hour, .minute], from: first)
            return Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        }
    }

    private func sum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, start: Date, end: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(identifier), predicate: predicate),
                                                     options: .cumulativeSum)
        guard let value = try await descriptor.result(for: store)?.sumQuantity()?.doubleValue(for: unit), value > 0 else { return nil }
        return (value * 100).rounded() / 100
    }

    private func categorySamples(_ identifier: HKCategoryTypeIdentifier, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(predicates: [.categorySample(type: HKCategoryType(identifier), predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.startDate)])
        return try await descriptor.result(for: store)
    }
    #else
    var isAvailable: Bool { false }
    func requestAccess() async { message = "Apple Health gibt es auf diesem Gerät nicht." }
    func load(day: DayKey, measures: [MeasureRecord]) async {}
    #endif
}
