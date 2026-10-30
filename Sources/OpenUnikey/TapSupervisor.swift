import AppKit
import ApplicationServices
import os
import VietCore

/// Keeps the event taps (keyboard, and the beta mouse tap when enabled)
/// running only while the app holds the Accessibility permission.
///
/// A tap left running after the permission is revoked (or after a rebuild no
/// longer matches the granted entry) stops receiving events, and WindowServer
/// then waits for it on every key press: input freezes system-wide. So the
/// tap is stopped the moment trust is lost, and restarted when it returns.
@MainActor
final class TapSupervisor {
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var clickMonitor: Any?
    private let onChange: () -> Void
    private let wantsMouseTap: () -> Bool
    private let log = Logger(subsystem: "io.github.openunikey", category: "tap")
    private var lastTrusted: Bool?

    var isTrusted: Bool { AXIsProcessTrusted() }

    init(wantsMouseTap: @escaping () -> Bool, onChange: @escaping () -> Void) {
        self.wantsMouseTap = wantsMouseTap
        self.onChange = onChange
    }

    func start() {
        if !isTrusted {
            // "AXTrustedCheckOptionPrompt" is the value of kAXTrustedCheckOptionPrompt.
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
        // Posted when the Accessibility list changes; TCC needs a moment to settle.
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.reconcile() }
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
        // Clicks move the caret, so the word being typed is forgotten. A passive
        // global monitor needs no permission and can never delay a click.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in vk_reset() }
        reconcile()
    }

    func stop() {
        timer?.invalidate()
        if let observer { DistributedNotificationCenter.default().removeObserver(observer) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        vk_mouse_tap_stop()
        vk_tap_stop()
    }

    /// Stops the tap without trust, starts it with trust (vk_tap_start also
    /// refuses for a short cooldown after the tap gave up on timeouts).
    func reconcile() {
        let wasRunning = vk_tap_running()
        let trusted = isTrusted
        let lostTrust = lastTrusted == true && !trusted
        if trusted != lastTrusted {
            log.notice("OpenUnikey: Accessibility trusted = \(trusted, privacy: .public)")
            lastTrusted = trusted
        }
        if lostTrust {
            vk_mouse_tap_stop()
            vk_tap_stop()
            relaunch()
            return
        }
        reconcileMouseTap(trusted: trusted)
        if !trusted {
            if wasRunning {
                vk_tap_stop()
                log.notice("OpenUnikey: permission lost, keyboard tap stopped")
            }
        } else if !wasRunning {
            _ = vk_tap_start() // logs why when it cannot start
        }
        if vk_tap_running() != wasRunning { onChange() }
    }

    private func reconcileMouseTap(trusted: Bool) {
        let wanted = trusted && wantsMouseTap()
        if wanted && !vk_mouse_tap_running() {
            _ = vk_mouse_tap_start() // logs why when it cannot start
        } else if !wanted && vk_mouse_tap_running() {
            vk_mouse_tap_stop()
        }
    }

    /// Once a running process has lost the permission, AXIsProcessTrusted()
    /// keeps answering false there even after it is granted again (seen on
    /// macOS 26). A fresh process sees the grant, so start one and quit.
    private func relaunch() {
        let bundle = Bundle.main.bundleURL
        guard bundle.pathExtension == "app" else { return } // e.g. `swift run`
        log.notice("OpenUnikey: permission lost, relaunching to pick it up again")
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundle, configuration: config,
                                           completionHandler: quitAfterRelaunch)
    }

    func openSettings() {
        let pane = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: pane) { NSWorkspace.shared.open(url) }
    }
}

/// Runs on a background queue, so it must not be a closure written inside the
/// @MainActor supervisor (Swift 6 traps when such a closure runs off main).
private func quitAfterRelaunch(_ app: NSRunningApplication?, _ error: (any Error)?) {
    guard error == nil else { return }
    DispatchQueue.main.async {
        MainActor.assumeIsolated { NSApp.terminate(nil) }
    }
}
