import Foundation
import OpenUnikeyShared
import Testing
import VietCore

struct TypingSettingsTests {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let domain = "io.github.openunikey.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        body(defaults)
    }

    @Test func missingValuesUseSharedDefaults() {
        withDefaults { defaults in
            let settings = TypingSettings(defaults: defaults)
            #expect(settings.engine.method == .telex)
            #expect(settings.engine.freeMarking && settings.engine.spellCheck && settings.engine.autoRestore)
            #expect(!settings.engine.modernStyle && !settings.engine.bracketShortcuts)
            #expect(settings.switchKey == .controlShift)
            #expect(settings.browserFix)
        }
    }

    @Test func unsupportedMethodsAndHotkeysFallBackWithoutUnsignedConversion() {
        withDefaults { defaults in
            for invalid in [-1, Int.min, 3, Int.max] {
                defaults.set(invalid, forKey: "inputMethod")
                defaults.set(invalid, forKey: "switchKey")
                let settings = TypingSettings(defaults: defaults)
                #expect(settings.engine.method == .telex)
                #expect(settings.engine.coreOptions.method == VK_TELEX)
                #expect(settings.switchKey == .controlShift)
            }
            for method in TypingMethod.allCases {
                defaults.set(method.rawValue, forKey: "inputMethod")
                #expect(TypingSettings(defaults: defaults).engine.method == method)
            }
        }
    }

    @Test func activeClientChangesDoNotResetUnchangedEngine() {
        withDefaults { defaults in
            var cache = TypingSettingsCache()
            func update() -> TypingSettingsCache.Changes {
                cache.update(TypingSettings(defaults: defaults), clientBundleID: "com.apple.Safari")
            }
            #expect(update().engine != nil)
            for _ in 0..<100 { #expect(update().engine == nil) }

            defaults.set(1, forKey: "switchKey")
            let hotkey = update()
            #expect(hotkey.switchKey == .optionZ)
            #expect(hotkey.engine == nil)

            defaults.set(false, forKey: "browserFix")
            let browser = update()
            #expect(browser.autocomplete == VK_AUTOCOMPLETE_NONE)
            #expect(browser.engine == nil)

            defaults.set(1, forKey: "inputMethod")
            #expect(update().engine?.method == .vni)
            #expect(update().engine == nil)
            defaults.set(false, forKey: "spellCheck")
            #expect(update().engine?.spellCheck == false)
            #expect(update().engine == nil)
        }
    }

    @Test func explicitFlagsReachTheCoreOptions() {
        withDefaults { defaults in
            for key in ["freeMarking", "spellCheck", "autoRestore", "browserFix"] {
                defaults.set(false, forKey: key)
            }
            for key in ["modernStyle", "bracketShortcuts"] { defaults.set(true, forKey: key) }
            let settings = TypingSettings(defaults: defaults)
            let options = settings.engine.coreOptions
            #expect(!options.freeMarking && !options.spellCheck && !options.autoRestore)
            #expect(options.modernStyle && options.bracketShortcuts)
            #expect(!settings.browserFix)
        }
    }

    @Test func clientTransitionUpdatesBrowserFixWithoutChangingEngine() {
        withDefaults { defaults in
            var cache = TypingSettingsCache()
            let settings = TypingSettings(defaults: defaults)
            _ = cache.update(settings, clientBundleID: "com.apple.TextEdit")
            let safari = cache.update(settings, clientBundleID: "com.apple.Safari")
            #expect(safari.engine == nil)
            #expect(safari.autocomplete == VK_AUTOCOMPLETE_FILLER)
            #expect(cache.update(settings, clientBundleID: "com.apple.Safari").autocomplete == nil)
        }
    }

    @Test func synchronizedDefaultsReadersSeeNewSettings() {
        withDefaults { writer in
            // The private suite is shared only by these readers, never the user's domain.
            let domain = "io.github.openunikey.tests.\(UUID().uuidString)"
            let first = UserDefaults(suiteName: domain)!
            let second = UserDefaults(suiteName: domain)!
            defer { first.removePersistentDomain(forName: domain) }
            _ = TypingSettings(defaults: second)
            first.set(2, forKey: "inputMethod")
            first.set(false, forKey: "freeMarking")
            first.synchronize()
            second.synchronize()
            #expect(TypingSettings(defaults: second).engine.method == .simpleTelex)
            #expect(!TypingSettings(defaults: second).engine.freeMarking)
            #expect(TypingSettings(defaults: writer).engine.method == .telex)
        }
    }
}
