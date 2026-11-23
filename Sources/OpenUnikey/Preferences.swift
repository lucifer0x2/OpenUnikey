import Foundation
import OpenUnikeyShared
import VietCore

typealias InputMethod = TypingMethod
typealias SwitchKey = TypingSwitchKey

extension TypingMethod {
    var title: String {
        switch self {
        case .telex: "Telex"
        case .vni: "VNI"
        case .simpleTelex: "Simple Telex"
        }
    }
}

extension TypingSwitchKey {
    var title: String { self == .controlShift ? "Control + Shift" : "Option + Z" }
    var symbol: String { self == .controlShift ? "⌃⇧" : "⌥Z" }
}

/// User settings stored in UserDefaults and mirrored into the core.
@MainActor
final class Preferences {
    private enum Key {
        static let inputMethod = "inputMethod"
        static let modernStyle = "modernStyle"
        static let freeMarking = "freeMarking"
        static let spellCheck = "spellCheck"
        static let autoRestore = "autoRestore"
        static let bracketShortcuts = "bracketShortcuts"
        static let browserFix = "browserFix"
        static let switchKey = "switchKey"
        static let clickToToggle = "clickToToggle"
        static let mouseSwitchesSpaces = "mouseSwitchesSpaces"
    }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.clickToToggle: true,
            Key.mouseSwitchesSpaces: false,
        ])
    }

    var inputMethod: InputMethod {
        get { typingSettings.engine.method }
        set { defaults.set(newValue.rawValue, forKey: Key.inputMethod) }
    }
    var modernStyle: Bool {
        get { typingSettings.engine.modernStyle }
        set { defaults.set(newValue, forKey: Key.modernStyle) }
    }
    var freeMarking: Bool {
        get { typingSettings.engine.freeMarking }
        set { defaults.set(newValue, forKey: Key.freeMarking) }
    }
    var spellCheck: Bool {
        get { typingSettings.engine.spellCheck }
        set { defaults.set(newValue, forKey: Key.spellCheck) }
    }
    var autoRestore: Bool {
        get { typingSettings.engine.autoRestore }
        set { defaults.set(newValue, forKey: Key.autoRestore) }
    }
    var bracketShortcuts: Bool {
        get { typingSettings.engine.bracketShortcuts }
        set { defaults.set(newValue, forKey: Key.bracketShortcuts) }
    }
    var browserFix: Bool {
        get { typingSettings.browserFix }
        set { defaults.set(newValue, forKey: Key.browserFix) }
    }
    var switchKey: SwitchKey {
        get { typingSettings.switchKey }
        set { defaults.set(newValue.rawValue, forKey: Key.switchKey) }
    }
    var clickToToggle: Bool {
        get { defaults.bool(forKey: Key.clickToToggle) }
        set { defaults.set(newValue, forKey: Key.clickToToggle) }
    }
    /// Beta: mouse buttons 4/5 switch to the Space on the right/left.
    var mouseSwitchesSpaces: Bool {
        get { defaults.bool(forKey: Key.mouseSwitchesSpaces) }
        set { defaults.set(newValue, forKey: Key.mouseSwitchesSpaces) }
    }

    /// Pushes every typing setting to the core.
    func applyToCore() {
        let settings = typingSettings
        var options = settings.engine.coreOptions
        vk_set_options(&options)
        vk_set_switch_key(settings.switchKey.core)
        // The input method types; the taps only catch the switch key while
        // another input source is selected.
        vk_set_vietnamese(false)
        TypingSettings.publishChange(from: defaults)
    }

    private var typingSettings: TypingSettings { TypingSettings(defaults: defaults) }
}
