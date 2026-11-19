import Foundation

/// "Geräte im Abgleich": every device notes in the synced settings when it last opened Thalia. The
/// list on another device shows whether its data arrives – a recent time means the sync works.
/// Stored as an `AppSetting` with key `sync.seen.<install id>` and value `<kind>|<ISO 8601 date>`.
public struct SyncDevice: Equatable, Sendable {
    public static let keyPrefix = "sync.seen."
    /// A device writes again at most this often (seconds).
    public static let minimumInterval: TimeInterval = 10 * 60

    public let installID: String
    /// "iPhone", "iPad", "Mac", "Apple Watch".
    public let kind: String
    public let seenAt: Date

    public init(installID: String, kind: String, seenAt: Date) {
        self.installID = installID
        self.kind = kind
        self.seenAt = seenAt
    }

    public var key: String { Self.keyPrefix + installID }

    public var value: String {
        let formatter = ISO8601DateFormatter()
        return "\(kind)|\(formatter.string(from: seenAt))"
    }

    public static func parse(key: String, value: String) -> SyncDevice? {
        guard key.hasPrefix(keyPrefix) else { return nil }
        let installID = String(key.dropFirst(keyPrefix.count))
        let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
        guard !installID.isEmpty, parts.count == 2, !parts[0].isEmpty,
              let date = ISO8601DateFormatter().date(from: parts[1]) else { return nil }
        return SyncDevice(installID: installID, kind: parts[0], seenAt: date)
    }

    /// Newest first, with a number when there are several of a kind: "Mac", "Mac (2)".
    public static func labelled(_ devices: [SyncDevice]) -> [(device: SyncDevice, label: String)] {
        let sorted = devices.sorted { $0.seenAt > $1.seenAt }
        var counts: [String: Int] = [:]
        for device in sorted { counts[device.kind, default: 0] += 1 }
        var seen: [String: Int] = [:]
        return sorted.map { device in
            seen[device.kind, default: 0] += 1
            let number = seen[device.kind] ?? 1
            let label = (counts[device.kind] ?? 1) > 1 && number > 1 ? "\(device.kind) (\(number))" : device.kind
            return (device, label)
        }
    }

    /// "gerade eben", "vor 5 Min.", "vor 3 Std.", "gestern, 21:14", "12.11., 08:03".
    public static func seenText(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)
        if seconds < 90 { return "gerade eben" }
        if seconds < 3600 { return "vor \(Int(seconds / 60)) Min." }
        if seconds < 6 * 3600, calendar.isDate(date, inSameDayAs: now) { return "vor \(Int(seconds / 3600)) Std." }
        let time = String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
        if calendar.isDate(date, inSameDayAs: now) { return "heute, \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) {
            return "gestern, \(time)"
        }
        let day = calendar.component(.day, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%02d.%02d., ", day, month) + time
    }
}
