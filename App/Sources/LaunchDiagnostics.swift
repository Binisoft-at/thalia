import Foundation
import SwiftUI

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

/// v11 P4.1 (1): a measured width in the Mac debug log – "diag: width today list 270" whenever it changes by a
/// whole point, and all of them in one line ("widths at 8 s: …") with the windows; nothing elsewhere.
func diagMeasure(_ name: String, _ width: CGFloat) {
    #if os(macOS) && DEBUG
    LaunchDiagnostics.width(name, width)
    #endif
}

extension View {
    /// v11 P4.1 (1): logs this view's width under `name` (`diagMeasure`) – Mac debug builds only, so CI's
    /// mac-log shows at 1024 pt which column stays above its minimum. Everywhere else the view as it is.
    @ViewBuilder
    func diagWidth(_ name: String) -> some View {
        #if os(macOS) && DEBUG
        onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            diagMeasure(name, width)
        }
        #else
        self
        #endif
    }
}

#if os(macOS) && DEBUG
import OSLog
import Darwin

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
    nonisolated(unsafe) private static var widths: [String: Int] = [:]
    nonisolated(unsafe) private static var lastPing = Date()
    nonisolated(unsafe) private static var started = false

    static func note(_ message: String) {
        log.notice("diag: \(message, privacy: .public)")
    }

    /// v11 P4.1 (1): a width, logged when it changed by a whole point.
    static func width(_ name: String, _ value: CGFloat) {
        let rounded = Int(value.rounded())
        lock.lock()
        let old = widths[name]
        widths[name] = rounded
        lock.unlock()
        guard old != rounded else { return }
        note("width \(name) \(rounded)")
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
        var capturedStack = false
        prepareStackCapture()
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
                    if !capturedStack && since > 4 {
                        capturedStack = true
                        captureMainStack()
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
        lock.lock(); let snapshot = counts; let measured = widths; lock.unlock()
        note("body counts at \(second) s: \(snapshot.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
        note("widths at \(second) s: \(measured.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ", "))")
        // P4.1: about 0 means an open inspector sits inside the detail column (the premise of `detailWidth`);
        // about the inspector's width means it is a column of its own next to the detail.
        if let window = measured["window"], let sidebar = measured["sidebar"], let detail = measured["detail"] {
            note("detail check at \(second) s: window \(window) − sidebar \(sidebar) − detail \(detail) = \(window - sidebar - detail)")
        }
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

private let diagStackCapacity: Int32 = 96
private let diagStackBuffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 96)
nonisolated(unsafe) private var diagStackFD: Int32 = -1
nonisolated(unsafe) private var diagMainThread: pthread_t?

extension LaunchDiagnostics {
    /// Call on the main thread at launch.
    static func prepareStackCapture() {
        diagMainThread = pthread_self()
        signal(SIGUSR2) { _ in
            guard diagStackFD >= 0 else { return }
            let count = backtrace(diagStackBuffer, diagStackCapacity)
            backtrace_symbols_fd(diagStackBuffer, count, diagStackFD)
        }
    }

    /// From the watchdog thread: interrupts the main thread, which writes its stack to a file;
    /// the lines then go to the log.
    static func captureMainStack() {
        guard let main = diagMainThread else { return }
        let path = NSTemporaryDirectory() + "thalia-main-stack.txt"
        FileManager.default.createFile(atPath: path, contents: nil)
        let fd = open(path, O_WRONLY | O_TRUNC)
        guard fd >= 0 else { note("stack: cannot open \(path)"); return }
        diagStackFD = fd
        pthread_kill(main, SIGUSR2)
        usleep(500_000)
        diagStackFD = -1
        close(fd)
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        let lines = text.split(separator: "\n")
        note("stack: \(lines.count) frames")
        for line in lines.prefix(90) {
            note("stack | \(line)")
        }
    }
}

#endif
