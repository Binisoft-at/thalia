import Foundation

/// Counts body runs on the Mac in debug builds (see LaunchDiagnostics); does nothing elsewhere.
func diagBody(_ name: String) {
    #if os(macOS) && DEBUG
    LaunchDiagnostics.body(name)
    #endif
}

/// A line in the Mac debug log (see LaunchDiagnostics); does nothing elsewhere.
func diagNote(_ message: String) {
    #if os(macOS) && DEBUG
    LaunchDiagnostics.note(message)
    #endif
}

#if os(macOS) && DEBUG
import OSLog

/// Debug builds on the Mac only (CI screenshots): finds out why the main window does not show at
/// launch. Writes to the system log (`log show`, part of the CI Mac log):
/// - how often a view's body runs (1, 2, 3, 10, 100, 1000 … – an endless update loop shows up as
///   a growing count),
/// - whether the main thread stops answering (a hang) and for how long,
/// - which window AppKit has, a few seconds after launch.
/// Not compiled into TestFlight builds.
enum LaunchDiagnostics {
    private static let log = Logger(subsystem: "at.binisoft.thalia", category: "diag")
    private static let lock = NSLock()
    nonisolated(unsafe) private static var counts: [String: Int] = [:]
    nonisolated(unsafe) private static var lastPing = Date()
    nonisolated(unsafe) private static var started = false

    static func note(_ message: String) {
        log.notice("diag: \(message, privacy: .public)")
    }

    /// Call from a body: logs the 1st, 2nd, 3rd, 10th, 100th, 1000th … run.
    static func body(_ name: String) {
        lock.lock()
        let count = (counts[name] ?? 0) + 1
        counts[name] = count
        lock.unlock()
        if count <= 3 || [10, 100, 1000, 10_000, 100_000].contains(count) {
            note("body \(name) #\(count)")
        }
    }

    /// Starts the main-thread watchdog (60 s) and logs the windows after 3, 8 and 15 seconds.
    static func start() {
        lock.lock()
        let first = !started
        started = true
        lock.unlock()
        guard first else { return }
        note("start")
        let queue = DispatchQueue(label: "at.binisoft.thalia.diag")
        var reportedBlock = false
        for second in 1...60 {
            queue.asyncAfter(deadline: .now() + .seconds(second)) {
                DispatchQueue.main.async {
                    lock.lock(); lastPing = Date(); lock.unlock()
                }
                lock.lock(); let since = Date().timeIntervalSince(lastPing); lock.unlock()
                if since > 2.5 {
                    if !reportedBlock || second % 10 == 0 {
                        note("main thread blocked for \(Int(since)) s (at \(second) s)")
                    }
                    reportedBlock = true
                } else if reportedBlock {
                    note("main thread answers again (at \(second) s)")
                    reportedBlock = false
                }
            }
        }
        for second in [3, 8, 15] {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(second)) {
                MainActor.assumeIsolated { logWindows(at: second) }
            }
        }
    }

    @MainActor
    private static func logWindows(at second: Int) {
        let windows = NSAppWindows.describe()
        note("windows at \(second) s: \(windows)")
        lock.lock(); let snapshot = counts; lock.unlock()
        note("body counts at \(second) s: \(snapshot.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
    }
}

import AppKit

private enum NSAppWindows {
    @MainActor
    static func describe() -> String {
        let list = NSApp.windows.map { window -> String in
            let id = window.identifier?.rawValue ?? "-"
            let kind = String(describing: type(of: window))
            let frame = window.frame
            return "\(kind)[\(id)] visible=\(window.isVisible) main=\(window.canBecomeMain) key=\(window.isKeyWindow) frame=\(Int(frame.minX)),\(Int(frame.minY)),\(Int(frame.width))x\(Int(frame.height)) alpha=\(window.alphaValue)"
        }
        return list.isEmpty ? "none" : list.joined(separator: " | ")
    }
}
#endif
