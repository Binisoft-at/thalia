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

    /// v11 P2.1 (d): the build number of 1.10.0 – Mac, watch and iPad score closed weeks themselves only
    /// when every device seen in the last 30 days runs at least this build (1.9.0 scores differently and
    /// rewrites the last three weeks after every import, §0.2).
    public static let firstV11Build = 58

    /// Devices seen this long ago or longer don't count for `allCurrent` (30 days).
    public static let currentWindow: TimeInterval = 30 * 24 * 3600

    /// Every device seen in the last 30 days (`seen`, from `sync.seen.`) has reported a build of 1.10.0 or
    /// later (`builds`: install id → its `sync.build.` record). A device without a build record ran an older
    /// version (1.9.0 never writes one) – then false. True without devices.
    public static func allCurrent(seen: [SyncDevice], builds: [String: SyncBuild], now: Date = Date()) -> Bool {
        seen.filter { now.timeIntervalSince($0.seenAt) < currentWindow }.allSatisfy { device in
            (builds[device.installID]?.build ?? 0) >= firstV11Build
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

/// `sync.build.<install id>` (v11 P2.1 (d)): the build and version a device runs, written next to its
/// `sync.seen.` entry – a key of its own, because 1.9.0 drops a device whose `sync.seen.` value has more
/// than one "|" part (`SyncDevice.parse`). `{"build":58,"v":1,"version":"1.10.0"}`. Not in
/// `SettingKeys.all`: never in a backup; older builds never read it.
public struct SyncBuild: Codable, Equatable, Sendable {
    public var v: Int
    /// The build number (`CFBundleVersion`), 0 when unreadable.
    public var build: Int
    /// "1.10.0"
    public var version: String

    public init(v: Int = 1, build: Int, version: String) {
        self.v = v
        self.build = build
        self.version = version
    }

    enum CodingKeys: String, CodingKey { case v, build, version }

    /// Tolerant: missing or odd fields read as defaults (a number as text too).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        v = SettingJSON.int(c, .v) ?? 1
        build = SettingJSON.int(c, .build) ?? 0
        version = SettingJSON.text(c, .version) ?? ""
    }

    /// "sync.build.<install id>"
    public static func key(installID: String) -> String { SettingKeys.buildPrefix + installID }

    /// The install id in "sync.build.<install id>"; nil for other keys.
    public static func installID(settingKey key: String) -> String? {
        guard key.hasPrefix(SettingKeys.buildPrefix) else { return nil }
        let id = String(key.dropFirst(SettingKeys.buildPrefix.count))
        return id.isEmpty ? nil : id
    }

    /// The setting's value (JSON, keys sorted).
    public var value: String { SettingJSON.string(self) }

    /// The record in a setting's value; nil when it isn't one.
    public init?(value: String) {
        guard let decoded: SyncBuild = SettingJSON.decode(value) else { return nil }
        self = decoded
    }

    /// Install id → build from `sync.build.` settings; of several copies the highest build counts.
    public static func builds(_ settings: [StoredSetting]) -> [String: SyncBuild] {
        var result: [String: SyncBuild] = [:]
        for setting in settings {
            guard let id = installID(settingKey: setting.key), let build = SyncBuild(value: setting.value) else { continue }
            if let known = result[id], known.build >= build.build { continue }
            result[id] = build
        }
        return result
    }
}
