import AppKit

enum BatteryIconRenderer {
    static let symbolPointSize: CGFloat = 18
    static let chargingImageSize = NSSize(width: 31, height: 15)
    private static let chargingFillMaximumWidth: CGFloat = 18

    static func image(
        percentage: Int,
        isConnectedToPower: Bool,
        chargingIconStyle: ChargingIconStyle,
        batteryDesign: BatteryDesign
    ) -> NSImage {
        let clampedPercentage = min(max(percentage, 0), 100)
        let showsPowerBolt = Self.showsPowerBolt(
            isConnectedToPower: isConnectedToPower
        )
        let description = isConnectedToPower
            ? "\(clampedPercentage)% battery, connected to power"
            : "\(clampedPercentage)% battery"

        if batteryDesign == .modern {
            let displayedPercentage = showsPowerBolt
                && chargingIconStyle == .original
                ? 100
                : clampedPercentage
            return modernImage(
                percentage: displayedPercentage,
                showsPowerBolt: showsPowerBolt,
                accessibilityDescription: description
            )
        }

        if showsPowerBolt, chargingIconStyle == .percentageFill {
            return chargingImage(
                percentage: clampedPercentage,
                accessibilityDescription: description
            )
        }

        let systemSymbolName = showsPowerBolt
            ? "battery.100percent.bolt"
            : symbolName(percentage: clampedPercentage)
        if let image = configuredSystemImage(
            named: systemSymbolName,
            accessibilityDescription: description
        ) {
            return image
        }

        return fallbackImage(percentage: clampedPercentage)
    }

    static func symbolName(
        percentage: Int
    ) -> String {
        let clampedPercentage = min(max(percentage, 0), 100)
        switch clampedPercentage {
        case 88...:
            return "battery.100percent"
        case 63...:
            return "battery.75percent"
        case 38...:
            return "battery.50percent"
        case 13...:
            return "battery.25percent"
        default:
            return "battery.0percent"
        }
    }

    static func showsPowerBolt(isConnectedToPower: Bool) -> Bool {
        isConnectedToPower
    }

    static func chargingFillWidth(percentage: Int) -> CGFloat {
        let clampedPercentage = min(max(percentage, 0), 100)
        return chargingFillMaximumWidth * CGFloat(clampedPercentage) / 100
    }

    static func modernFillWidth(percentage: Int, bodyWidth: CGFloat = 23) -> CGFloat {
        let clampedPercentage = min(max(percentage, 0), 100)
        let rawWidth = bodyWidth * CGFloat(clampedPercentage) / 100
        return (rawWidth * 2).rounded() / 2
    }

    private static func modernImage(
        percentage: Int,
        showsPowerBolt: Bool,
        accessibilityDescription: String
    ) -> NSImage {
        let image = NSImage(size: chargingImageSize, flipped: false) { _ in
            let bodyRect = NSRect(x: 1.5, y: 1.5, width: 23, height: 12)
            let bodyPath = NSBezierPath(
                roundedRect: bodyRect,
                xRadius: 4,
                yRadius: 4
            )
            NSColor.black.withAlphaComponent(0.5).setFill()
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(
                rect: NSRect(x: 0, y: 0, width: 13, height: chargingImageSize.height)
            ).addClip()
            bodyPath.fill()
            NSGraphicsContext.restoreGraphicsState()

            let terminalSideBodyPath = NSBezierPath(
                roundedRect: bodyRect,
                xRadius: 4.0625,
                yRadius: 4.0625
            )
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(
                rect: NSRect(
                    x: 13,
                    y: 0,
                    width: chargingImageSize.width - 13,
                    height: chargingImageSize.height
                )
            ).addClip()
            terminalSideBodyPath.fill()
            NSGraphicsContext.restoreGraphicsState()

            let fillWidth = modernFillWidth(percentage: percentage)
            if fillWidth > 0 {
                NSColor.black.setFill()
                NSGraphicsContext.saveGraphicsState()
                NSBezierPath(
                    rect: NSRect(
                        x: bodyRect.minX,
                        y: bodyRect.minY,
                        width: fillWidth,
                        height: bodyRect.height
                    )
                ).addClip()
                bodyPath.fill()
                terminalSideBodyPath.fill()
                NSGraphicsContext.restoreGraphicsState()
            }

            let terminalRect = NSRect(x: 25.5, y: 5.5, width: 1.5, height: 4)
            let terminalPath = NSBezierPath()
            terminalPath.move(to: NSPoint(x: terminalRect.minX, y: terminalRect.minY))
            terminalPath.curve(
                to: NSPoint(x: terminalRect.maxX, y: terminalRect.midY),
                controlPoint1: NSPoint(x: terminalRect.maxX, y: terminalRect.minY),
                controlPoint2: NSPoint(x: terminalRect.maxX, y: terminalRect.midY)
            )
            terminalPath.curve(
                to: NSPoint(x: terminalRect.minX, y: terminalRect.maxY),
                controlPoint1: NSPoint(x: terminalRect.maxX, y: terminalRect.midY),
                controlPoint2: NSPoint(x: terminalRect.maxX, y: terminalRect.maxY)
            )
            terminalPath.close()
            NSColor.black.withAlphaComponent(0.58).setFill()
            terminalPath.fill()
            NSColor.black.setFill()

            if showsPowerBolt {
                drawModernChargingBolt()
            }
            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    private static func configuredSystemImage(
        named symbolName: String,
        accessibilityDescription: String
    ) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        ) else {
            return nil
        }
        image.isTemplate = true
        return image
    }

    private static func chargingImage(
        percentage: Int,
        accessibilityDescription: String
    ) -> NSImage {
        let image = NSImage(size: chargingImageSize, flipped: false) { _ in
            let bodyRect = NSRect(x: 2.25, y: 2.25, width: 22, height: 10.5)
            let bodyPath = NSBezierPath(
                roundedRect: bodyRect,
                xRadius: 2.7,
                yRadius: 2.7
            )
            bodyPath.lineWidth = 1.5

            NSColor.black.setStroke()
            bodyPath.stroke()

            let terminalPath = NSBezierPath(
                roundedRect: NSRect(x: 25.5, y: 5.5, width: 2.1, height: 4),
                xRadius: 1,
                yRadius: 1
            )
            NSColor.black.setFill()
            terminalPath.fill()

            let fillWidth = chargingFillWidth(percentage: percentage)
            if fillWidth > 0 {
                let fillPath = NSBezierPath(
                    roundedRect: NSRect(x: 4.25, y: 4.25, width: fillWidth, height: 6.5),
                    xRadius: min(1.5, fillWidth / 2),
                    yRadius: 1.5
                )
                fillPath.fill()
            }

            drawChargingBolt()

            return true
        }

        image.isTemplate = true
        image.accessibilityDescription = accessibilityDescription
        return image
    }

    private static func drawChargingBolt() {
        let boltPath = NSBezierPath()
        boltPath.move(to: NSPoint(x: 14.9, y: 14.25))
        boltPath.line(to: NSPoint(x: 9.7, y: 7.9))
        boltPath.line(to: NSPoint(x: 13, y: 7.9))
        boltPath.line(to: NSPoint(x: 11.5, y: 0.75))
        boltPath.line(to: NSPoint(x: 17.5, y: 8.55))
        boltPath.line(to: NSPoint(x: 14.15, y: 8.55))
        boltPath.close()
        boltPath.lineJoinStyle = .round

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        boltPath.lineWidth = 2.75
        boltPath.stroke()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.black.setFill()
        boltPath.fill()
    }

    private static func drawModernChargingBolt() {
        let boltPath = NSBezierPath()
        boltPath.move(to: NSPoint(x: 15.7, y: 14.7))
        boltPath.line(to: NSPoint(x: 8.8, y: 7.7))
        boltPath.line(to: NSPoint(x: 12.8, y: 7.7))
        boltPath.line(to: NSPoint(x: 10.7, y: 0.3))
        boltPath.line(to: NSPoint(x: 17.8, y: 8.7))
        boltPath.line(to: NSPoint(x: 14.3, y: 8.7))
        boltPath.close()
        boltPath.lineJoinStyle = .round

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        boltPath.lineWidth = 2.75
        boltPath.stroke()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.black.setFill()
        boltPath.fill()
    }

    private static func fallbackImage(percentage: Int) -> NSImage {
        let size = NSSize(width: 20, height: 12)
        let fraction = CGFloat(min(max(percentage, 0), 100)) / 100

        let image = NSImage(size: size, flipped: false) { _ in
            let bodyRect = NSRect(x: 0.75, y: 1.25, width: 15.5, height: 9.5)
            let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: 2.1, yRadius: 2.1)
            bodyPath.lineWidth = 1.35

            NSColor.black.setStroke()
            bodyPath.stroke()

            let terminalPath = NSBezierPath()
            terminalPath.lineWidth = 1.7
            terminalPath.lineCapStyle = .round
            terminalPath.move(to: NSPoint(x: 17.2, y: 4.4))
            terminalPath.line(to: NSPoint(x: 17.2, y: 7.6))
            terminalPath.stroke()

            guard fraction > 0 else {
                return true
            }

            let fillWidth = max(1.2, 12.5 * fraction)
            let fillRect = NSRect(x: 2.25, y: 2.75, width: fillWidth, height: 6.5)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.05, yRadius: 1.05)
            NSColor.black.setFill()
            fillPath.fill()

            return true
        }

        image.isTemplate = true
        return image
    }
}
