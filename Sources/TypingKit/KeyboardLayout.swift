/// Key codes of the US (ANSI / "ABC") layout, used to replay typed text as
/// real key events and to know which chars need Shift.
public enum KeyboardLayout {
    public struct Key: Sendable {
        public let code: UInt16
        public let shift: Bool
    }

    public static let returnKey = Key(code: 36, shift: false)
    public static let backspaceKey = Key(code: 51, shift: false)

    /// The key that types `ch`, or nil if the layout cannot type it.
    public static func key(for ch: Character) -> Key? {
        if ch == "\n" { return returnKey }
        if ch == "\u{8}" { return backspaceKey }
        if let code = plain[ch] { return Key(code: code, shift: false) }
        if let code = shifted[ch] { return Key(code: code, shift: true) }
        let lower = Character(ch.lowercased())
        if ch.isUppercase, let code = plain[lower] { return Key(code: code, shift: true) }
        return nil
    }

    public static func needsShift(_ ch: Character) -> Bool {
        key(for: ch)?.shift ?? false
    }

    private static let plain: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
        "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28,
        "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47,
        "\t": 48, " ": 49, "`": 50,
    ]

    private static let shifted: [Character: UInt16] = [
        "!": 18, "@": 19, "#": 20, "$": 21, "^": 22, "%": 23, "+": 24, "(": 25, "&": 26,
        "_": 27, "*": 28, ")": 29, "}": 30, "{": 33, "\"": 39, ":": 41, "|": 42, "<": 43,
        "?": 44, ">": 47, "~": 50,
    ]
}
