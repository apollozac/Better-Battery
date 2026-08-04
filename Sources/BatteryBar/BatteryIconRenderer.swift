import AppKit

enum BatteryIconRenderer {
    static let symbolPointSize: CGFloat = 18

    static func image(percentage: Int, isConnectedToPower: Bool) -> NSImage {
        let clampedPercentage = min(max(percentage, 0), 100)
        let showsPowerBolt = Self.showsPowerBolt(
            isConnectedToPower: isConnectedToPower
        )
        let description = isConnectedToPower
            ? "\(clampedPercentage)% battery, connected to power"
            : "\(clampedPercentage)% battery"

        if let image = NSImage(
            systemSymbolName: symbolName(
                percentage: clampedPercentage,
                showsPowerBolt: showsPowerBolt
            ),
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
        percentage: Int,
        showsPowerBolt: Bool
    ) -> String {
        if showsPowerBolt {
            return "battery.100percent.bolt"
        }

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
