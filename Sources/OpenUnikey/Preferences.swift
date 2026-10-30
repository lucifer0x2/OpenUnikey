import Foundation
import VietCore

enum InputMethod: Int, CaseIterable {
    case telex = 0
    case vni = 1
    case simpleTelex = 2

    var title: String {
        switch self {
        case .telex: "Telex"
        case .vni: "VNI"
        case .simpleTelex: "Simple Telex"
        }
    }

    var core: VKInputMethod {
        switch self {
        case .telex: VK_TELEX
        case .vni: VK_VNI
        case .simpleTelex: VK_SIMPLE_TELEX
        }
    }
}

enum SwitchKey: Int, CaseIterable {
    case controlShift = 0
    case optionZ = 1

    var title: String { self == .controlShift ? "Control + Shift" : "Option + Z" }
    var symbol: String { self == .controlShift ? "⌃⇧" : "⌥Z" }
}

/// User settings stored in UserDefaults and mirrored into the core.
@MainActor
final class Preferences {
    private enum Key {
        static let vietnamese = "vietnamese"
        static let inputMethod = "inputMethod"
        static let modernStyle = "modernStyle"
        static let freeMarking = "freeMarking"
        static let spellCheck = "spellCheck"
        static let autoRestore = "autoRestore"
        static let bracketShortcuts = "bracketShortcuts"
        static let browserFix = "browserFix"
        static let switchKey = "switchKey"
        static let clickToToggle = "clickToToggle"
    }

    private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.vietnamese: true,
            Key.inputMethod: InputMethod.telex.rawValue,
            Key.modernStyle: false,
            Key.freeMarking: true,
            Key.spellCheck: true,
            Key.autoRestore: true,
            Key.bracketShortcuts: false,
            Key.browserFix: true,
            Key.switchKey: SwitchKey.controlShift.rawValue,
            Key.clickToToggle: true,
        ])
    }

    var vietnamese: Bool {
        get { defaults.bool(forKey: Key.vietnamese) }
        set { defaults.set(newValue, forKey: Key.vietnamese) }
    }
    var inputMethod: InputMethod {
        get { InputMethod(rawValue: defaults.integer(forKey: Key.inputMethod)) ?? .telex }
        set { defaults.set(newValue.rawValue, forKey: Key.inputMethod) }
    }
    var modernStyle: Bool {
        get { defaults.bool(forKey: Key.modernStyle) }
        set { defaults.set(newValue, forKey: Key.modernStyle) }
    }
    var freeMarking: Bool {
        get { defaults.bool(forKey: Key.freeMarking) }
        set { defaults.set(newValue, forKey: Key.freeMarking) }
    }
    var spellCheck: Bool {
        get { defaults.bool(forKey: Key.spellCheck) }
        set { defaults.set(newValue, forKey: Key.spellCheck) }
    }
    var autoRestore: Bool {
        get { defaults.bool(forKey: Key.autoRestore) }
        set { defaults.set(newValue, forKey: Key.autoRestore) }
    }
    var bracketShortcuts: Bool {
        get { defaults.bool(forKey: Key.bracketShortcuts) }
        set { defaults.set(newValue, forKey: Key.bracketShortcuts) }
    }
    var browserFix: Bool {
        get { defaults.bool(forKey: Key.browserFix) }
        set { defaults.set(newValue, forKey: Key.browserFix) }
    }
    var switchKey: SwitchKey {
        get { SwitchKey(rawValue: defaults.integer(forKey: Key.switchKey)) ?? .controlShift }
        set { defaults.set(newValue.rawValue, forKey: Key.switchKey) }
    }
    var clickToToggle: Bool {
        get { defaults.bool(forKey: Key.clickToToggle) }
        set { defaults.set(newValue, forKey: Key.clickToToggle) }
    }

    /// Pushes every typing setting to the core.
    func applyToCore() {
        var options = VKOptions(
            method: inputMethod.core,
            freeMarking: freeMarking,
            modernStyle: modernStyle,
            spellCheck: spellCheck,
            autoRestore: autoRestore,
            bracketShortcuts: bracketShortcuts
        )
        vk_set_options(&options)
        vk_set_switch_key(switchKey == .optionZ ? VK_SWITCH_OPTION_Z : VK_SWITCH_CONTROL_SHIFT)
        vk_set_vietnamese(vietnamese)
    }
}
