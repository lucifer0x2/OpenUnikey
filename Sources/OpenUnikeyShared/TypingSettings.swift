import Foundation
import VietCore

public enum TypingMethod: Int, CaseIterable, Sendable {
    case telex = 0, vni = 1, simpleTelex = 2

    public var core: VKInputMethod {
        switch self {
        case .telex: VK_TELEX
        case .vni: VK_VNI
        case .simpleTelex: VK_SIMPLE_TELEX
        }
    }
}

public enum TypingSwitchKey: Int, CaseIterable, Sendable {
    case controlShift = 0, optionZ = 1

    public var core: VKSwitchKey {
        self == .optionZ ? VK_SWITCH_OPTION_Z : VK_SWITCH_CONTROL_SHIFT
    }
}

/// One decoder for both processes, including absent and unsupported values.
public struct TypingSettings: Equatable, Sendable {
    public struct Engine: Equatable, Sendable {
        public let method: TypingMethod
        public let freeMarking, modernStyle, spellCheck, autoRestore, bracketShortcuts: Bool

        public var coreOptions: VKOptions {
            VKOptions(method: method.core, freeMarking: freeMarking, modernStyle: modernStyle,
                      spellCheck: spellCheck, autoRestore: autoRestore, bracketShortcuts: bracketShortcuts)
        }
    }

    public let engine: Engine
    public let switchKey: TypingSwitchKey
    public let browserFix: Bool

    public init(defaults: UserDefaults) {
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            defaults.object(forKey: key) as? Bool ?? fallback
        }
        engine = Engine(
            method: TypingMethod(rawValue: defaults.integer(forKey: "inputMethod")) ?? .telex,
            freeMarking: flag("freeMarking", true), modernStyle: flag("modernStyle", false),
            spellCheck: flag("spellCheck", true), autoRestore: flag("autoRestore", true),
            bracketShortcuts: flag("bracketShortcuts", false)
        )
        switchKey = TypingSwitchKey(rawValue: defaults.integer(forKey: "switchKey")) ?? .controlShift
        browserFix = flag("browserFix", true)
    }

    /// Flush before notifying the other process, which synchronizes before reading.
    public static func publishChange(from defaults: UserDefaults) {
        defaults.synchronize()
        DistributedNotificationCenter.default().postNotificationName(
            changedNotification, object: nil, userInfo: nil, deliverImmediately: true)
    }

    public static let changedNotification = Notification.Name("io.github.openunikey.typingSettingsChanged")
}
