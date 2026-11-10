import AppKit
import OpenUnikeyShared
import VietCore

/// Wires the settings, the menu bar item and the core event tap together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, MenuActions {
    private let prefs = Preferences()
    private lazy var tapSupervisor = TapSupervisor(
        wantsMouseTap: { [prefs] in prefs.mouseSwitchesSpaces },
        onChange: { [weak self] in self?.statusItem?.refresh() }
    )
    private let frontmost = FrontmostAppObserver()
    private let inputSource = InputSourceObserver()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyLogSwitch.applyAtLaunch()
        prefs.applyToCore()
        SwitchBridge.install { [weak self] in self?.toggleVietnamese() }

        statusItem = StatusItemController(
            prefs: prefs,
            isVietnamese: { [inputSource] in inputSource.isVietnamese },
            makeMenu: { [unowned self] in
                MenuBuilder(prefs: prefs, vietnamese: inputSource.isVietnamese,
                            accessibilityGranted: tapSupervisor.isTrusted,
                            launchAtLogin: LoginItem.isEnabled, actions: self).build()
            },
            onToggle: { [unowned self] in toggleVietnamese() }
        )

        frontmost.start { [unowned self] in
            KeyLogSwitch.noteActiveApp(frontmost.currentBundleID)
            updateAutocompleteFix()
            vk_reset()
        }
        updateAutocompleteFix()
        inputSource.start { [weak self] in self?.statusItem?.refresh() }

        tapSupervisor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tapSupervisor.stop()
        KeyLogSwitch.stop() // writes what is still in memory
    }

    // MARK: MenuActions

    /// The input source change comes back through InputSourceObserver.
    func toggleVietnamese() {
        if !InputSources.toggle() { NSSound.beep() } // input method not installed
    }

    func preferencesChanged() {
        prefs.applyToCore()
        updateAutocompleteFix()
        tapSupervisor.reconcile() // the mouse tap follows its setting
        statusItem?.refresh()
    }

    func toggleLaunchAtLogin() {
        do {
            try LoginItem.setEnabled(!LoginItem.isEnabled)
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    func openAccessibilitySettings() {
        tapSupervisor.openSettings()
    }

    func showAbout() {
        let credits = NSAttributedString(
            string: "Bộ gõ tiếng Việt cho macOS, dùng ukengine (x-unikey) của Phạm Kim Long.\n"
                + "Cách gửi phím tham khảo OpenKey. Giấy phép GNU GPL phiên bản 2 trở lên."
        )
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    // MARK: Private

    private func updateAutocompleteFix() {
        vk_set_autocomplete_fix(prefs.browserFix ? frontmost.autocompleteFix : VK_AUTOCOMPLETE_NONE)
    }
}

/// Routes the core's C switch callback (event tap thread) to the main actor.
@MainActor
enum SwitchBridge {
    fileprivate static var handler: (() -> Void)?

    static func install(_ handler: @escaping () -> Void) {
        self.handler = handler
        vk_set_switch_callback(switchKeyOnTapThread, nil)
    }
}

/// Called by the core on the event tap thread. It must stay nonisolated: a
/// closure written inside the @MainActor SwitchBridge inherits main-actor
/// isolation, and Swift 6 traps when it runs on another thread.
private func switchKeyOnTapThread(_ context: UnsafeMutableRawPointer?) {
    DispatchQueue.main.async {
        MainActor.assumeIsolated { SwitchBridge.handler?() }
    }
}
