import VietCore

/// Only an engine configuration change should interrupt the current word.
/// Hotkey/browser changes and repeated keys must not call vk_set_options.
public struct TypingSettingsCache {
    private var previous: TypingSettings?
    private var autocomplete: VKAutocompleteFix?

    public init() {}

    public struct Changes {
        public let engine: TypingSettings.Engine?
        public let switchKey: TypingSwitchKey?
        public let autocomplete: VKAutocompleteFix?
    }

    public mutating func update(_ settings: TypingSettings, clientBundleID: String?) -> Changes {
        let fix = settings.browserFix ? Browsers.autocompleteFix(for: clientBundleID) : VK_AUTOCOMPLETE_NONE
        let changes = Changes(
            engine: previous?.engine == settings.engine ? nil : settings.engine,
            switchKey: previous?.switchKey == settings.switchKey ? nil : settings.switchKey,
            autocomplete: autocomplete == fix ? nil : fix
        )
        previous = settings
        autocomplete = fix
        return changes
    }
}
