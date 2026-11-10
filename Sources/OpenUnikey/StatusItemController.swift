import AppKit

/// Owns the V/E item in the menu bar: V while OpenUnikey's input source is
/// selected. Left click switches the input source (like UniKey's tray icon)
/// when enabled; right click or Control-click opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let prefs: Preferences
    private let isVietnamese: () -> Bool
    private let makeMenu: () -> NSMenu
    private let onToggle: () -> Void

    init(prefs: Preferences, isVietnamese: @escaping () -> Bool,
         makeMenu: @escaping () -> NSMenu, onToggle: @escaping () -> Void) {
        self.prefs = prefs
        self.isVietnamese = isVietnamese
        self.makeMenu = makeMenu
        self.onToggle = onToggle
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        refresh()
    }

    func refresh() {
        guard let button = statusItem.button else { return }
        let vietnamese = isVietnamese()
        button.image = StatusIcon.image(vietnamese: vietnamese)
        let mode = vietnamese ? "Tiếng Việt (\(prefs.inputMethod.title))" : "English"
        button.toolTip = "OpenUnikey: \(mode). \(prefs.switchKey.symbol) để đổi nguồn nhập."
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if prefs.clickToToggle && !wantsMenu {
            onToggle()
        } else {
            showMenu()
        }
    }

    private func showMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // keep left click free for toggling
    }
}
