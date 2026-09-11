#!/usr/bin/env swift

import AppKit

private struct ScreenshotSpec {
    let sourceName: String
    let outputName: String
    let sourceCrop: CGRect
    let title: String
    let subtitle: String
    let textPanel: CGRect
}

private let outputSize = CGSize(width: 2880, height: 1800)
private let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sourceURL = rootURL.appendingPathComponent("AppStorePreparation/Source Captures")
private let outputURL = rootURL.appendingPathComponent("AppStorePreparation/Screenshots")

private let specs = [
    ScreenshotSpec(
        sourceName: "menu-bar.png",
        outputName: "01-clear-at-a-glance.jpg",
        sourceCrop: CGRect(x: 2140, y: 0, width: 1280, height: 800),
        title: "A clearer battery indicator.",
        subtitle: "The modern macOS 27 design, with the percentage beside it.",
        textPanel: CGRect(x: 120, y: 1090, width: 1640, height: 470)
    ),
    ScreenshotSpec(
        sourceName: "general-modern.png",
        outputName: "02-make-it-yours.jpg",
        sourceCrop: CGRect(x: 1500, y: 0, width: 1920, height: 1200),
        title: "Make it yours.",
        subtitle: "Modern or classic. Percentage left or right, with or without the symbol.",
        textPanel: CGRect(x: 75, y: 1060, width: 950, height: 500)
    ),
    ScreenshotSpec(
        sourceName: "notifications.png",
        outputName: "03-alerts-both-directions.jpg",
        sourceCrop: CGRect(x: 1500, y: 0, width: 1920, height: 1200),
        title: "Alerts in both directions.",
        subtitle: "Know when battery power drops or charging reaches your chosen level.",
        textPanel: CGRect(x: 75, y: 1060, width: 950, height: 500)
    ),
    ScreenshotSpec(
        sourceName: "battery-health.png",
        outputName: "04-battery-health.jpg",
        sourceCrop: CGRect(x: 1500, y: 0, width: 1920, height: 1200),
        title: "Battery health, without the hunt.",
        subtitle: "See condition, maximum capacity, and cycle count in one place.",
        textPanel: CGRect(x: 75, y: 1060, width: 950, height: 500)
    )
]

private func topLeftRect(_ rect: CGRect, canvasHeight: CGFloat) -> CGRect {
    CGRect(
        x: rect.origin.x,
        y: canvasHeight - rect.origin.y - rect.height,
        width: rect.width,
        height: rect.height
    )
}

private func paragraphStyle(lineSpacing: CGFloat) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.lineSpacing = lineSpacing
    return style
}

private func render(_ spec: ScreenshotSpec) throws {
    let inputURL = sourceURL.appendingPathComponent(spec.sourceName)
    let sourceData = try Data(contentsOf: inputURL)
    guard
        let sourceRepresentation = NSBitmapImageRep(data: sourceData),
        let sourceCGImage = sourceRepresentation.cgImage
    else {
        throw NSError(
            domain: "BetterBatteryScreenshots",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Unable to open \(inputURL.path)"]
        )
    }
    let sourceImage = NSImage(
        cgImage: sourceCGImage,
        size: NSSize(
            width: sourceRepresentation.pixelsWide,
            height: sourceRepresentation.pixelsHigh
        )
    )

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(outputSize.width),
        pixelsHigh: Int(outputSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(
            domain: "BetterBatteryScreenshots",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Unable to create output bitmap"]
        )
    }

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        NSGraphicsContext.restoreGraphicsState()
        throw NSError(
            domain: "BetterBatteryScreenshots",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Unable to create drawing context"]
        )
    }
    NSGraphicsContext.current = context

    sourceImage.draw(
        in: CGRect(origin: .zero, size: outputSize),
        from: topLeftRect(spec.sourceCrop, canvasHeight: sourceImage.size.height),
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: nil
    )

    let panel = topLeftRect(spec.textPanel, canvasHeight: outputSize.height)
    let panelPath = NSBezierPath(roundedRect: panel, xRadius: 38, yRadius: 38)
    NSColor(calibratedWhite: 0.08, alpha: 0.58).setFill()
    panelPath.fill()

    let titleRect = CGRect(
        x: panel.minX + 54,
        y: panel.minY + 210,
        width: panel.width - 108,
        height: panel.height - 250
    )
    let subtitleRect = CGRect(
        x: panel.minX + 56,
        y: panel.minY + 48,
        width: panel.width - 112,
        height: 170
    )

    let title = NSAttributedString(
        string: spec.title,
        attributes: [
            .font: NSFont.systemFont(ofSize: spec.outputName.hasPrefix("01") ? 88 : 76, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle(lineSpacing: 4)
        ]
    )
    title.draw(with: titleRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

    let subtitle = NSAttributedString(
        string: spec.subtitle,
        attributes: [
            .font: NSFont.systemFont(ofSize: spec.outputName.hasPrefix("01") ? 44 : 40, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.9),
            .paragraphStyle: paragraphStyle(lineSpacing: 8)
        ]
    )
    subtitle.draw(with: subtitleRect, options: [.usesLineFragmentOrigin, .usesFontLeading])

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let jpeg = bitmap.representation(
        using: .jpeg,
        properties: [.compressionFactor: 1.0]
    ) else {
        throw NSError(
            domain: "BetterBatteryScreenshots",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Unable to encode output JPEG"]
        )
    }
    try jpeg.write(to: outputURL.appendingPathComponent(spec.outputName), options: .atomic)
}

try FileManager.default.createDirectory(
    at: outputURL,
    withIntermediateDirectories: true
)

for spec in specs {
    try render(spec)
    print("Wrote AppStorePreparation/Screenshots/\(spec.outputName)")
}
