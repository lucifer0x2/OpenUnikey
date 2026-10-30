import AppKit
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
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        prefs.applyToCore()
        ModeBridge.install { [weak self] vietnamese in self?.modeSwitchedByHotkey(vietnamese) }

        statusItem = StatusItemController(
            prefs: prefs,
            makeMenu: { [unowned self] in
                MenuBuilder(prefs: prefs, accessibilityGranted: tapSupervisor.isTrusted,
                            launchAtLogin: LoginItem.isEnabled, actions: self).build()
            },
            onToggle: { [unowned self] in toggleVietnamese() }
        )

        frontmost.start { [unowned self] in
            updateAutocompleteFix()
            vk_reset()
        }
        updateAutocompleteFix()

        tapSupervisor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tapSupervisor.stop()
    }

    // MARK: MenuActions

    func toggleVietnamese() {
        prefs.vietnamese.toggle()
        vk_set_vietnamese(prefs.vietnamese)
        statusItem?.refresh()
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

    private func modeSwitchedByHotkey(_ vietnamese: Bool) {
        prefs.vietnamese = vietnamese
        statusItem?.refresh()
    }

    private func updateAutocompleteFix() {
        vk_set_autocomplete_fix(prefs.browserFix ? frontmost.autocompleteFix : VK_AUTOCOMPLETE_NONE)
    }
}

/// Routes the core's C mode callback (event tap thread) to the main actor.
@MainActor
enum ModeBridge {
    fileprivate static var handler: ((Bool) -> Void)?

    static func install(_ handler: @escaping (Bool) -> Void) {
        self.handler = handler
        vk_set_mode_callback(modeChangedOnTapThread, nil)
    }
}

/// Called by the core on the event tap thread. It must stay nonisolated: a
/// closure written inside the @MainActor ModeBridge inherits main-actor
/// isolation, and Swift 6 traps when it runs on another thread.
private func modeChangedOnTapThread(_ vietnamese: Bool, _ context: UnsafeMutableRawPointer?) {
    DispatchQueue.main.async {
        MainActor.assumeIsolated { ModeBridge.handler?(vietnamese) }
    }
}
