/// Turns Vietnamese text into the keys a person would type for it in Telex or
/// VNI, e.g. "người" -> "nguwowif".
public struct KeystrokeEncoder: Sendable {
    public enum Method: String, Sendable, CaseIterable { case telex, vni }
    public enum ToneStyle: String, Sendable, CaseIterable {
        case endOfWord   // "nguwowif": tone key after the whole word
        case afterVowel  // "nguwowfi": tone key right after the toned vowel
    }

    public var method: Method
    public var toneStyle: ToneStyle
    /// Telex only: type ươ as "uow" (one w) instead of "uwow".
    public var compactHorn: Bool
    /// When > 0, every Nth word is interrupted halfway: a space is typed,
    /// deleted with Backspace, and the word goes on ("hoajc ⌫w").
    public var interruptEvery: Int

    public init(method: Method = .telex, toneStyle: ToneStyle = .endOfWord,
                compactHorn: Bool = false, interruptEvery: Int = 0) {
        self.method = method
        self.toneStyle = toneStyle
        self.compactHorn = compactHorn
        self.interruptEvery = interruptEvery
    }

    /// Keys for a whole line: letter runs are encoded, everything else is
    /// typed as is. Characters the US layout cannot type are skipped.
    public func keys(for text: String) -> String {
        var output = ""
        var word: [Character] = []
        var wordIndex = 0
        func flush() {
            guard !word.isEmpty else { return }
            wordIndex += 1
            let keys = keys(forWord: word)
            output += interruptEvery > 0 && wordIndex % interruptEvery == 0
                ? Self.interrupt(keys, seed: wordIndex) : keys
            word.removeAll()
        }
        for ch in text {
            if ch.isLetter {
                word.append(ch)
            } else {
                flush()
                if KeyboardLayout.key(for: ch) != nil { output.append(ch) }
            }
        }
        flush()
        return output
    }

    /// Puts " ⌫" inside `keys` at a position that varies with `seed`.
    static func interrupt(_ keys: String, seed: Int) -> String {
        guard keys.count >= 2 else { return keys }
        let cut = keys.index(keys.startIndex, offsetBy: 1 + (seed * 7) % (keys.count - 1))
        return String(keys[..<cut]) + " \u{8}" + String(keys[cut...])
    }

    private func keys(forWord word: [Character]) -> String {
        let letters = word.map(VietnameseLetter.init)
        // Words with letters outside Vietnamese are typed literally.
        guard letters.allSatisfy({ $0 != nil }) else {
            return String(word.filter { $0.isASCII })
        }
        let parsed = letters.map { $0! }
        let allCaps = parsed.count > 1 && parsed.allSatisfy(\.isUppercase)
        var output = ""
        var pendingTone: VietnameseLetter.Tone = .none
        for (index, letter) in parsed.enumerated() {
            output.append(letter.base)
            let skipHorn = compactHorn && method == .telex && letter.mark == .horn
                && letter.base.lowercased() == "u" && index + 1 < parsed.count
                && parsed[index + 1].mark == .horn
            if !skipHorn { output += markKeys(letter, allCaps: allCaps) }
            if letter.tone != .none {
                if toneStyle == .afterVowel {
                    output += toneKey(letter.tone, allCaps: allCaps)
                } else {
                    pendingTone = letter.tone
                }
            }
        }
        if pendingTone != .none { output += toneKey(pendingTone, allCaps: allCaps) }
        return output
    }

    private func markKeys(_ letter: VietnameseLetter, allCaps: Bool) -> String {
        let key: String
        switch (method, letter.mark) {
        case (_, .none): return ""
        case (.telex, .circumflex), (.telex, .stroke): key = String(letter.base).lowercased()
        case (.telex, .breve), (.telex, .horn): key = "w"
        case (.vni, .circumflex): key = "6"
        case (.vni, .horn): key = "7"
        case (.vni, .breve): key = "8"
        case (.vni, .stroke): key = "9"
        }
        return allCaps ? key.uppercased() : key
    }

    private func toneKey(_ tone: VietnameseLetter.Tone, allCaps: Bool) -> String {
        let telex: [VietnameseLetter.Tone: String] = [
            .acute: "s", .grave: "f", .hook: "r", .tilde: "x", .dot: "j",
        ]
        let key = method == .telex ? telex[tone, default: ""] : String(tone.rawValue)
        return allCaps ? key.uppercased() : key
    }
}
