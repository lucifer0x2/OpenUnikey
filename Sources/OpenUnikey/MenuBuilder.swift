import AppKit

/// Everything the status menu can ask the app to do.
@MainActor
protocol MenuActions: AnyObject {
    func toggleVietnamese()
    func preferencesChanged()
    func toggleLaunchAtLogin()
    func openAccessibilitySettings()
    func showAbout()
}

/// Builds the status item menu from the current settings. The menu is rebuilt
/// each time it opens, so every checkmark reflects the live state.
@MainActor
struct MenuBuilder {
    let prefs: Preferences
    let accessibilityGranted: Bool
    let launchAtLogin: Bool
    unowned let actions: MenuActions

    func build() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ActionMenuItem("Gõ tiếng Việt", symbol: "keyboard",
                                    checked: prefs.vietnamese) { [actions] in
            actions.toggleVietnamese()
        })
        menu.addItem(.hint("Phím chuyển V/E: \(prefs.switchKey.symbol)"))
        menu.addItem(.separator())
        menu.addItem(inputMethodMenu())
        menu.addItem(optionsMenu())
        menu.addItem(switchKeyMenu())
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Khởi động cùng macOS", symbol: "power",
                                    checked: launchAtLogin) { [actions] in
            actions.toggleLaunchAtLogin()
        })
        if !accessibilityGranted {
            menu.addItem(ActionMenuItem("Cấp quyền Trợ năng…", symbol: "lock.shield") { [actions] in
                actions.openAccessibilitySettings()
            })
        }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem("Giới thiệu OpenUnikey", symbol: "info.circle") { [actions] in
            actions.showAbout()
        })
        menu.addItem(ActionMenuItem("Thoát", symbol: "xmark.circle", keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
        return menu
    }

    private func inputMethodMenu() -> NSMenuItem {
        let items = InputMethod.allCases.map { method in
            ActionMenuItem(method.title, checked: prefs.inputMethod == method) { [prefs, actions] in
                prefs.inputMethod = method
                actions.preferencesChanged()
            }
        }
        return .submenu("Kiểu gõ: \(prefs.inputMethod.title)", symbol: "character.textbox",
                        items: items)
    }

    private func switchKeyMenu() -> NSMenuItem {
        let items = SwitchKey.allCases.map { key in
            ActionMenuItem(key.title, checked: prefs.switchKey == key) { [prefs, actions] in
                prefs.switchKey = key
                actions.preferencesChanged()
            }
        }
        return .submenu("Phím chuyển V/E", symbol: "command", items: items)
    }

    private func optionsMenu() -> NSMenuItem {
        let items: [NSMenuItem] = [
            toggle("Bỏ dấu kiểu mới (oà, uý)", \.modernStyle),
            toggle("Cho phép bỏ dấu tự do", \.freeMarking),
            toggle("Kiểm tra chính tả tiếng Việt", \.spellCheck),
            toggle("Tự khôi phục từ không phải tiếng Việt", \.autoRestore),
            toggle("Gõ [ ] { } thành ơ ư Ơ Ư", \.bracketShortcuts),
            .separator(),
            toggle("Sửa lỗi gợi ý trên thanh địa chỉ trình duyệt", \.browserFix),
            toggle("Nhấp chuột trái vào V/E để chuyển nhanh", \.clickToToggle),
        ]
        return .submenu("Tuỳ chọn", symbol: "slider.horizontal.3", items: items)
    }

    private func toggle(_ title: String,
                        _ keyPath: ReferenceWritableKeyPath<Preferences, Bool>) -> NSMenuItem {
        ActionMenuItem(title, checked: prefs[keyPath: keyPath]) { [prefs, actions] in
            prefs[keyPath: keyPath].toggle()
            actions.preferencesChanged()
        }
    }
}
