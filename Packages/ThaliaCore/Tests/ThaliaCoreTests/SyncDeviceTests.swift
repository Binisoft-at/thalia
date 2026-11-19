import Foundation
import Testing
@testable import ThaliaCore

@Suite("Devices in sync")
struct SyncDeviceTests {
    private var vienna: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Vienna")!
        return calendar
    }

    @Test func roundTrip() {
        let date = Date(timeIntervalSince1970: 1_795_000_000)
        let device = SyncDevice(installID: "abc-123", kind: "Mac", seenAt: date)
        #expect(device.key == "sync.seen.abc-123")
        let parsed = SyncDevice.parse(key: device.key, value: device.value)
        #expect(parsed == device)
        #expect(SyncDevice.parse(key: "goal.period", value: device.value) == nil)
        #expect(SyncDevice.parse(key: "sync.seen.x", value: "Mac") == nil)
        #expect(SyncDevice.parse(key: "sync.seen.x", value: "Mac|kein Datum") == nil)
    }

    @Test func labelsNumberSameKinds() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let devices = [
            SyncDevice(installID: "a", kind: "Mac", seenAt: now.addingTimeInterval(-600)),
            SyncDevice(installID: "b", kind: "iPhone", seenAt: now),
            SyncDevice(installID: "c", kind: "Mac", seenAt: now.addingTimeInterval(-60)),
        ]
        let labels = SyncDevice.labelled(devices).map(\.label)
        #expect(labels == ["iPhone", "Mac", "Mac (2)"])
    }

    @Test func seenTexts() {
        let calendar = vienna
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 20, minute: 30))!
        #expect(SyncDevice.seenText(now.addingTimeInterval(-30), now: now, calendar: calendar) == "gerade eben")
        #expect(SyncDevice.seenText(now.addingTimeInterval(-5 * 60), now: now, calendar: calendar) == "vor 5 Min.")
        #expect(SyncDevice.seenText(now.addingTimeInterval(-3 * 3600), now: now, calendar: calendar) == "vor 3 Std.")
        #expect(SyncDevice.seenText(now.addingTimeInterval(-10 * 3600), now: now, calendar: calendar) == "heute, 10:30")
        #expect(SyncDevice.seenText(now.addingTimeInterval(-22 * 3600), now: now, calendar: calendar) == "gestern, 22:30")
        #expect(SyncDevice.seenText(now.addingTimeInterval(-4 * 86400), now: now, calendar: calendar) == "15.11., 20:30")
    }
}
