/// A Vietnamese letter split into its plain Latin base, its letter mark
/// (â ă ơ đ...) and its tone, e.g. "ỡ" = o + horn + tilde.
public struct VietnameseLetter: Equatable, Sendable {
    public enum Mark: Sendable { case none, circumflex, breve, horn, stroke }
    public enum Tone: Int, Sendable { case none = 0, acute, grave, hook, tilde, dot }

    public let base: Character // a-z or A-Z
    public let mark: Mark
    public let tone: Tone

    public var isUppercase: Bool { base.isUppercase }

    /// nil when `ch` is not a Latin letter used in Vietnamese.
    public init?(_ ch: Character) {
        if ch == "đ" || ch == "Đ" {
            base = ch == "đ" ? "d" : "D"
            mark = .stroke
            tone = .none
            return
        }
        let scalars = Array(String(ch).decomposedStringWithCanonicalMapping.unicodeScalars)
        guard let first = scalars.first, first.isASCII,
              first.properties.isAlphabetic else { return nil }
        var mark = Mark.none
        var tone = Tone.none
        for scalar in scalars.dropFirst() {
            switch scalar.value {
            case 0x302: mark = .circumflex
            case 0x306: mark = .breve
            case 0x31B: mark = .horn
            case 0x301: tone = .acute
            case 0x300: tone = .grave
            case 0x309: tone = .hook
            case 0x303: tone = .tilde
            case 0x323: tone = .dot
            default: return nil
            }
        }
        let base = Character(first)
        let lower = Character(base.lowercased())
        switch mark {
        case .circumflex where !"aeo".contains(lower): return nil
        case .breve where lower != "a": return nil
        case .horn where !"ou".contains(lower): return nil
        default: break
        }
        if tone != .none && !"aeiouy".contains(lower) { return nil }
        self.base = base
        self.mark = mark
        self.tone = tone
    }

    /// The letter with its tone removed, e.g. "ỡ" -> "ơ".
    public var withoutTone: String {
        var scalars = String(base).unicodeScalars.map { $0 }
        switch mark {
        case .none: break
        case .stroke: return isUppercase ? "Đ" : "đ"
        case .circumflex: scalars.append("\u{302}")
        case .breve: scalars.append("\u{306}")
        case .horn: scalars.append("\u{31B}")
        }
        var string = ""
        string.unicodeScalars.append(contentsOf: scalars)
        return string.precomposedStringWithCanonicalMapping
    }
}
