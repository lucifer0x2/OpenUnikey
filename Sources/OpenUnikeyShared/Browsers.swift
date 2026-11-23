import VietCore

/// Browsers whose address bar selects an inline suggestion while typing.
/// They all get the filler character, OpenKey's default workaround (its
/// Shift+Left variant for Chromium is an opt-in there); one path for all.
public enum Browsers {
    public static let bundleIDs: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev",
        "com.brave.Browser", "company.thebrowser.Browser", "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi", "org.chromium.Chromium",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox",
    ]

    public static func autocompleteFix(for bundleID: String?) -> VKAutocompleteFix {
        guard let bundleID, bundleIDs.contains(bundleID) else { return VK_AUTOCOMPLETE_NONE }
        return VK_AUTOCOMPLETE_FILLER
    }
}

/// OpenUnikey's input method as macOS lists it among the input sources.
public enum InputMethodIdentity {
    public static let sourceID = "io.github.openunikey.inputmethod.OpenUnikey"
    /// Where the menu bar app keeps its settings; the input method reads them.
    public static let appDefaultsDomain = "io.github.openunikey"
}
