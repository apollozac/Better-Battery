import AppKit

enum BatteryIconRenderer {
    static let symbolPointSize: CGFloat = 18
    static let chargingImageSize = NSSize(width: 31, height: 15)
    private static let chargingFillMaximumWidth: CGFloat = 18

    static func image(
        percentage: Int,
        isConnectedToPower: Bool,
        chargingIconStyle: ChargingIconStyle
    ) -> NSImage {
        let clampedPercentage = min(max(percentage, 0), 100)
        let showsPowerBolt = Self.showsPowerBolt(
            isConnectedToPower: isConnectedToPower
        )
        let description = isConnectedToPower
            ? "\(clampedPercentage)% battery, connected to power"
            : "\(clampedPercentage)% battery"

        if showsPowerBolt, chargingIconStyle == .percentageFill {
            return chargingImage(
                percentage: clampedPercentage,
                accessibilityDescription: description
            )
        }

        let systemSymbolName = showsPowerBolt
            ? "battery.100percent.bolt"
            : symbolName(percentage: clampedPercentage)
        if let image = NSImage(
            systemSymbolName: systemSymbolName,
            accessibilityDescription: description
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        ) {
            image.isTemplate = true
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
