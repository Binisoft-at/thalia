import Foundation
import SwiftUI
import UserNotifications
import BinisoftKit
import ThaliaCore
#if os(iOS)
import HealthKit
#endif

// MARK: Reminders

/// Local notifications from `ReminderSettings` (Core): morning start, evening review, weekly
/// review. Tapping one opens the right screen.
enum ReminderScheduler {
    static func load() -> ReminderSettings {
        guard let data = UserDefaults.standard.data(forKey: ReminderSettings.storageKey),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else { return ReminderSettings() }
        return settings
    }

    static func save(_ settings: ReminderSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: ReminderSettings.storageKey)
        }
    }

    /// Replaces the repeating reminders. Returns a short status line for Settings.
    @MainActor
    static func apply(_ settings: ReminderSettings) async -> String {
        let center = UNUserNotificationCenter.current()
        let requests = settings.requests()
        let old = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("thalia.") }
        center.removePendingNotificationRequests(withIdentifiers: old)
        guard !requests.isEmpty else { return "Keine Erinnerungen geplant." }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return "Mitteilungen sind für Thalia ausgeschaltet (Systemeinstellungen → Mitteilungen)." }
        } catch {
            AppLog.warning("Notification permission failed: \(error.localizedDescription)", category: "reminders")
            return "Mitteilungen konnten nicht erlaubt werden."
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
        }
        AppLog.info("Reminders scheduled: \(requests.count)", category: "reminders")
        return "\(requests.count) Erinnerungen geplant."
    }
}

/// Opens the screen a notification or a Shortcut points to.
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    /// Set by `ThaliaApp`; receives "today", "close-day", "week" …
    var route: (@MainActor (String) -> Void)?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let destination = response.notification.request.content.userInfo["destination"] as? String ?? "today"
        let route = self.route
        await MainActor.run { route?(destination) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
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
