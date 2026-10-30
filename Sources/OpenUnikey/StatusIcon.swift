import AppKit

/// Monochrome V / E badges for the menu bar. They are template images, so
/// macOS tints them for light, dark and tinted menu bars automatically.
@MainActor
enum StatusIcon {
    private static let size = NSSize(width: 20, height: 16)
    private static let cornerRadius: CGFloat = 4

    static let vietnamese = makeBadge(letter: "V", filled: true)
    static let english = makeBadge(letter: "E", filled: false)

    static func image(vietnamese isVietnamese: Bool) -> NSImage {
        isVietnamese ? vietnamese : english
    }

    /// Filled badge with the letter cut out (V) or an outlined badge (E).
    private static func makeBadge(letter: String, filled: Bool) -> NSImage {
        let image = NSImage(size: size, flipped: false) { bounds in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let badge = NSBezierPath(
                roundedRect: bounds.insetBy(dx: 1.5, dy: 1),
                xRadius: cornerRadius, yRadius: cornerRadius
            )
            NSColor.black.set()
            if filled {
                badge.fill()
                context.setBlendMode(.destinationOut)
            } else {
                badge.lineWidth = 1.4
                badge.stroke()
            }
            drawLetter(letter, in: bounds)
            context.setBlendMode(.normal)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = filled ? "Tiếng Việt" : "English"
        return image
    }

    private static func drawLetter(_ letter: String, in bounds: NSRect) {
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let text = NSAttributedString(string: letter, attributes: [
            .font: font,
            .foregroundColor: NSColor.black,
        ])
        let textSize = text.size()
        let origin = NSPoint(
            x: bounds.midX - textSize.width / 2,
            y: bounds.midY - textSize.height / 2 + 0.5
        )
        text.draw(at: origin)
    }
}
