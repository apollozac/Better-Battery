import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("usage: render_volume_icon.swift OUTPUT_PNG\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let width = 1024
let height = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create volume icon bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
defer { NSGraphicsContext.restoreGraphicsState() }
NSGraphicsContext.current?.imageInterpolation = .high

let tileRect = NSRect(x: 22, y: 22, width: 980, height: 980)
let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 220, yRadius: 220)
let gradient = NSGradient(
    starting: NSColor(calibratedRed: 1.0, green: 0.553, blue: 0.157, alpha: 1),
    ending: NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.0, alpha: 1)
)!
gradient.draw(in: tilePath, angle: -90)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
shadow.shadowBlurRadius = 24
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.set()
NSColor.white.withAlphaComponent(0.98).setStroke()

let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: 258, y: 445))
bolt.line(to: NSPoint(x: 438, y: 627))
bolt.line(to: NSPoint(x: 585, y: 535))
bolt.line(to: NSPoint(x: 755, y: 654))
bolt.line(to: NSPoint(x: 600, y: 410))
bolt.line(to: NSPoint(x: 451, y: 495))
bolt.close()
bolt.lineWidth = 30
bolt.lineJoinStyle = .round
bolt.lineCapStyle = .round
bolt.stroke()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to render volume icon\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
