import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render_dmg_background.swift <output.png>\n", stderr)
    exit(2)
}

let size = NSSize(width: 600, height: 400)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSGradient(
    starting: NSColor(calibratedWhite: 0.985, alpha: 1),
    ending: NSColor(calibratedRed: 0.90, green: 0.95, blue: 1.0, alpha: 1)
)?.draw(in: bounds, angle: -90)

let titleStyle = NSMutableParagraphStyle()
titleStyle.alignment = .center

let title = NSAttributedString(
    string: "Install Better Battery",
    attributes: [
        .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
        .paragraphStyle: titleStyle
    ]
)
title.draw(in: NSRect(x: 40, y: 325, width: 520, height: 42))

let subtitle = NSAttributedString(
    string: "Drag Better Battery to Applications",
    attributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1),
        .paragraphStyle: titleStyle
    ]
)
subtitle.draw(in: NSRect(x: 40, y: 294, width: 520, height: 24))

let arrow = NSBezierPath()
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 252, y: 194))
arrow.line(to: NSPoint(x: 348, y: 194))
arrow.move(to: NSPoint(x: 328, y: 212))
arrow.line(to: NSPoint(x: 348, y: 194))
arrow.line(to: NSPoint(x: 328, y: 176))
NSColor.controlAccentColor.withAlphaComponent(0.72).setStroke()
arrow.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Unable to render DMG background.\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
