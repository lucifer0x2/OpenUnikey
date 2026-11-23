// Draws the input method's menu bar icon as a TIFF with 1x and 2x bitmaps:
// swift scripts/make-im-icon.swift out.tiff
// A filled rounded badge with "V" cut out, the look of macOS's own "A" for ABC.
// Black on transparent: TISIconIsTemplate in the Info.plist makes macOS tint it
// for light and dark menu bars.
import AppKit

// The same size and corners as the "A" badge: 22×16 pt edge to edge, 5 pt radius.
let points = NSSize(width: 22, height: 16)

func bitmap(scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(points.width) * scale,
        pixelsHigh: Int(points.height) * scale, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = points
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let bounds = NSRect(origin: .zero, size: points)
    NSColor.black.set()
    NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
    NSGraphicsContext.current?.cgContext.setBlendMode(.destinationOut)
    let text = NSAttributedString(string: "V", attributes: [
        .font: NSFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor.black,
    ])
    let size = text.size()
    text.draw(at: NSPoint(x: (points.width - size.width) / 2, y: (points.height - size.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let image = NSImage(size: points)
image.addRepresentation(bitmap(scale: 1))
image.addRepresentation(bitmap(scale: 2))
guard let data = image.tiffRepresentation else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
