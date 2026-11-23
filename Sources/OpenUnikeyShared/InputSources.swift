import Carbon

/// The macOS input source is the V/E switch: OpenUnikey's input method types
/// Vietnamese, any other keyboard layout (ABC) types English. The switch key
/// and the menu bar item flip between the two. Main thread only.
public enum InputSources {
    public static var isVietnameseSelected: Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return false }
        return sourceID(of: source) == InputMethodIdentity.sourceID
    }

    @discardableResult
    public static func toggle() -> Bool {
        isVietnameseSelected ? selectEnglish() : selectVietnamese()
    }

    /// False when the input method is not installed or not enabled.
    @discardableResult
    public static func selectVietnamese() -> Bool {
        let filter = [kTISPropertyInputSourceID as String: InputMethodIdentity.sourceID] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource]
        guard let source = sources?.first else { return false }
        return TISSelectInputSource(source) == noErr
    }

    /// The keyboard layout used last, usually ABC.
    @discardableResult
    public static func selectEnglish() -> Bool {
        guard let layout = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        else { return false }
        return TISSelectInputSource(layout) == noErr
    }

    private static func sourceID(of source: TISInputSource) -> String? {
        guard let raw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(raw).takeUnretainedValue() as String
    }
}
