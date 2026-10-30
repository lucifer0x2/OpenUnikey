import VietCore

/// Feeds keys to the engine and applies its output to a text buffer, the way
/// the event tap rewrites the focused text field.
public final class EngineTypist {
    private let engine: OpaquePointer
    public private(set) var text: [UInt16] = []

    public init(_ options: VKOptions = .standard) {
        var options = options
        engine = vk_engine_create(&options)
    }

    deinit { vk_engine_destroy(engine) }

    public var string: String { String(decoding: text, as: UTF16.self) }

    public func clear() {
        text.removeAll()
        vk_engine_reset(engine)
    }

    /// Types ASCII keys. "\u{8}" is Backspace and "\n" is Return; shifted
    /// characters (uppercase, { } ! ...) are typed with Shift.
    @discardableResult
    public func type(_ keys: String) -> String {
        for ch in keys {
            switch ch {
            case "\u{8}": backspace()
            case "\n", "\r": returnKey()
            default:
                guard let ascii = ch.asciiValue else { continue }
                key(ascii, shift: KeyboardLayout.needsShift(ch))
            }
        }
        return string
    }

    private func key(_ ch: UInt8, shift: Bool) {
        var backs: Int32 = 0
        let count = vk_engine_process(engine, ch, shift, false, &backs)
        if count == 0 && backs == 0 {
            text.append(UInt16(ch)) // passes through
        } else {
            apply(backs: backs, count: count)
        }
    }

    private func backspace() {
        var backs: Int32 = 0
        let count = vk_engine_backspace(engine, &backs)
        if count == 0 && backs <= 1 {
            if !text.isEmpty { text.removeLast() } // the real Backspace goes through
        } else {
            apply(backs: backs, count: count)
        }
    }

    private func returnKey() {
        var backs: Int32 = 0
        let count = vk_engine_end_word(engine, &backs)
        apply(backs: backs, count: count)
        vk_engine_reset(engine)
        text.append(10)
    }

    private func apply(backs: Int32, count: Int32) {
        text.removeLast(min(Int(backs), text.count))
        if count > 0, let output = vk_engine_output(engine) {
            text.append(contentsOf: UnsafeBufferPointer(start: output, count: Int(count)))
        }
    }
}

extension VKOptions {
    public static let standard = VKOptions(method: VK_TELEX, freeMarking: true, modernStyle: false,
                                           spellCheck: true, autoRestore: true, bracketShortcuts: false)

    public func with(_ change: (inout VKOptions) -> Void) -> VKOptions {
        var copy = self
        change(&copy)
        return copy
    }
}
