import Foundation

/// Cleans downloaded text so every character can be typed on a US keyboard
/// with a Vietnamese input method, and compares typed results.
public enum CorpusText {
    /// NFC, typographic punctuation mapped to ASCII, untypeable chars dropped,
    /// one non-empty line per paragraph.
    public static func lines(from raw: String) -> [String] {
        raw.precomposedStringWithCanonicalMapping
            .components(separatedBy: .newlines)
            .map(clean)
            .filter { !$0.isEmpty }
    }

    static func clean(_ line: String) -> String {
        var output = ""
        for ch in line {
            if let mapped = replacements[ch] {
                output += mapped
            } else if KeyboardLayout.key(for: ch) != nil, ch != "\t" {
                output.append(ch)
            } else if ch.isLetter, VietnameseLetter(ch) != nil {
                output.append(ch)
            } else if ch.isWhitespace {
                output.append(" ")
            }
        }
        return output.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    private static let replacements: [Character: String] = [
        "\u{201C}": "\"", "\u{201D}": "\"", "\u{201E}": "\"", "\u{2018}": "'", "\u{2019}": "'",
        "\u{2013}": "-", "\u{2014}": "-", "\u{2026}": "...", "\u{00A0}": " ", "\u{00AB}": "\"",
        "\u{00BB}": "\"",
    ]

    /// A word with its tone moved to a fixed place, so "hòa" and "hoà" (old
    /// and new tone placement) compare equal.
    public static func toneInsensitive(_ word: Substring) -> String {
        var letters = ""
        var tones: [Int] = []
        for ch in word {
            if let letter = VietnameseLetter(ch) {
                letters += letter.withoutTone
                if letter.tone != .none { tones.append(letter.tone.rawValue) }
            } else {
                letters.append(ch)
            }
        }
        return tones.isEmpty ? letters : letters + "#" + tones.map(String.init).joined()
    }
}
